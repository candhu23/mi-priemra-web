--!strict
-- Tienda con Robux: Game Passes y Developer Products.
-- ProcessReceipt es idempotente (data.receipts) y solo confirma la compra tras guardar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Game = require(script.Parent:WaitForChild("Game"))
local Data = require(script.Parent:WaitForChild("Data"))

local Shop = {}

local productById: { [number]: string } = {}
for _, p in Config.Products do
	if p.id ~= 0 then
		productById[p.id] = p.key
	end
end

function Shop.loadPasses(session: Game.Session)
	for _, p in Config.GamePasses do
		if p.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(session.player.UserId, p.id)
			end)
			session.passes[p.key] = ok and owns == true
		end
	end
end

-- Entrega el producto. Devuelve false si no se puede entregar ahora.
local function grant(session: Game.Session, key: string): boolean
	local data = session.data
	local now = os.time()
	if key == "starter" then
		if data.starterBought then
			data.money += 50_000 -- ya lo tenía: se compensa con dinero
		else
			data.starterBought = true
			table.insert(data.planes, { id = data.nextId, model = "hawk", airport = Config.START_HUB, condition = 100 })
			data.nextId += 1
			data.money += 50_000
			data.boostUntil = math.max(now, data.boostUntil) + 1800
		end
	elseif key == "cash_s" or key == "cash_m" or key == "cash_l" then
		data.money += Game.cashPack(session, key)
	elseif key == "boost" then
		data.boostUntil = math.max(now, data.boostUntil) + 1800
	elseif key == "landall" then
		for _, p in data.planes do
			if p.flight then
				p.flight.endT = now
			end
		end
	elseif key == "star_pilot" then
		local first = Config.FirstNames[math.random(1, #Config.FirstNames)]
		local last = Config.LastNames[math.random(1, #Config.LastNames)]
		table.insert(data.pilots, {
			id = data.nextId, name = first .. " " .. last, stars = 5, level = 1, flights = 0,
			avatar = Config.Avatars[math.random(1, #Config.Avatars)],
		})
		data.nextId += 1
	elseif key == "offline2x" then
		data.money += session.offlineLast
		session.offlineLast = 0
	else
		return false
	end
	session.dirty = true
	return true
end

function Shop.init()
	MarketplaceService.ProcessReceipt = function(receipt: any)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local session = player and Game.sessions[player]
		local key = productById[receipt.ProductId]
		if not session or not key then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = session.data
		if data.receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if not grant(session, key) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.receipts[receipt.PurchaseId] = os.time()
		-- Guardar solo los últimos 50 recibos
		local list = {}
		for id, t in data.receipts do
			table.insert(list, { id, t })
		end
		if #list > 50 then
			table.sort(list, function(a, b) return a[2] < b[2] end)
			for i = 1, #list - 50 do
				data.receipts[list[i][1]] = nil
			end
		end
		if session.canSave and not Data.save(session.player.UserId, data) then
			-- No se pudo guardar: deshacer sería complicado; Roblox reintentará y el recibo evitará el doble cobro
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Game.notify(session.player, "success", "n_purchase", { item = key })
		Game.pushState(session.player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		local session = Game.sessions[player]
		if not session or not bought then
			return
		end
		for _, p in Config.GamePasses do
			if p.id == passId then
				session.passes[p.key] = true
				Game.notify(player, "success", "n_purchase", { item = p.key })
				Game.pushState(player)
			end
		end
	end)
end

return Shop
