--[[
	PurchaseService (ModuleScript en ServerScriptService)

	Compras con Robux: Developer Products (ProcessReceipt) y Game Passes.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local SaveService = require(ServerScriptService:WaitForChild("SaveService"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local SiteService = require(ServerScriptService:WaitForChild("SiteService"))
local StateService = require(ServerScriptService:WaitForChild("StateService"))

local gain = ServerState.gain
local notify = ServerState.notify
local popup = ServerState.popup
local sessions = ServerState.sessions
type Bonuses = ServerState.Bonuses
type Session = ServerState.Session
local computeIncome = Economy.computeIncome
local paidReward = Economy.paidReward
local refreshBoost = Economy.refreshBoost
local saveData = SaveService.saveData
local ensureSeason = RewardService.ensureSeason
local addWork = SiteService.addWork
local sendState = StateService.sendState
local Monetization = Config.Monetization

local PurchaseService = {}

local passKeyById: { [number]: string } = {}

for _, pass in Monetization.GamePasses do
	if pass.id ~= 0 then
		passKeyById[pass.id] = pass.key
	end
end

local productById: { [number]: any } = {}

for _, product in Monetization.Products do
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

local function grantProduct(player: Player, session: Session, product)
	local data = session.data
	if product.kind == "cash" then
		local amount = paidReward(session, product.minutes, product.min)
		gain(data, amount, "robux")
		notify(player, product.emoji .. " ¡" .. product.name .. "! +" .. Config.formatMoney(amount), "money")
	elseif product.kind == "boost" then
		data.boostUntil = math.max(data.boostUntil, os.time()) + product.minutes * 60
		refreshBoost(session)
		notify(player, "🚀 ¡Boost x2 activado durante " .. product.minutes .. " minutos!", "money")
	elseif product.kind == "ticket" then
		CareerService.grantTickets(player, session, product.ticket, product.amount)
	elseif product.kind == "starter" then
		data.starterBought = true
		local amount = paidReward(session, product.minutes, product.min)
		gain(data, amount, "robux")
		data.boostUntil = math.max(data.boostUntil, os.time()) + product.boostMinutes * 60
		refreshBoost(session)
		data.career.tickets.legendary = (data.career.tickets.legendary or 0) + 1
		popup(player, "🎁 ¡Pack de inicio!", "💰 +" .. Config.formatMoney(amount) .. "\n🚀 Boost x2 durante " .. product.boostMinutes .. " minutos\n👑 +1 Contrato Legendario\n\n¡Gracias por apoyar el juego!")
	elseif product.kind == "season" then
		ensureSeason(session)
		data.season.premium = true
		notify(player, "🎫 ¡Pase de temporada Premium activado! Recoge tus premios en 🎫 Pase", "money")
	elseif product.kind == "finish" then
		if data.project then
			addWork(player, session, data.project.required)
			notify(player, "⏩ ¡Web terminada al instante!", "success")
		else
			local amount = paidReward(session, 10, 1000)
			gain(data, amount, "robux")
			notify(player, "⏩ No programabas nada: te damos +" .. Config.formatMoney(amount), "money")
		end
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and sessions[player]
	local product = productById[receipt.ProductId]
	if not player or not session or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Si la partida no se pudo cargar no se puede guardar: no se entrega
	-- (Roblox lo vuelve a intentar cuando el jugador vuelva). En Studio sin
	-- publicar sí, para poder probar la tienda.
	if not session.canSave and not RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = session.data
	local purchaseId = tostring(receipt.PurchaseId)
	if not data.receipts[purchaseId] then
		grantProduct(player, session, product)
		data.receipts[purchaseId] = os.time()
		-- Guardamos solo las 50 compras más recientes
		local entries = {}
		for id, time in data.receipts do
			table.insert(entries, { id = id, time = time })
		end
		if #entries > 50 then
			table.sort(entries, function(x, y)
				return x.time < y.time
			end)
			for i = 1, #entries - 50 do
				data.receipts[entries[i].id] = nil
			end
		end
		sendState(player)
	end
	-- Solo confirmamos la compra cuando está guardada
	if session.canSave and not saveData(player, session) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local key = passKeyById[passId]
	local session = sessions[player]
	if purchased and key and session then
		(session.bonuses :: any)[key] = true
		local def = Config.PassByKey[key]
		notify(player, def.emoji .. " ¡Gracias! Ya tienes " .. def.name .. ".", "money")
		session.income = computeIncome(session, true)
		sendState(player)
	end
end)

---------------------------------------------------------------------
-- Amigos en el servidor (bonus por jugar juntos)
---------------------------------------------------------------------

local function checkPasses(player: Player, bonuses: Bonuses)
	for _, pass in Monetization.GamePasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				(bonuses :: any)[pass.key] = true
			end
		end
	end
end

PurchaseService.checkPasses = checkPasses
PurchaseService.grantProduct = grantProduct

return PurchaseService
