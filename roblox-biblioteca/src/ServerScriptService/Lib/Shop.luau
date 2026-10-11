--!strict
-- Tienda: pases decorativos (mecenas, mascota, temas de luz) y propinas. Nada da ventaja ni es aleatorio.
-- ProcessReceipt es idempotente (recibos guardados) y solo confirma la compra tras guardar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Game = require(script.Parent:WaitForChild("Game"))
local Data = require(script.Parent:WaitForChild("Data"))

local Shop = {}

-- Pase que hace falta para cada opción decorativa
Shop.OPTION_PASS = { glow = "patron", pet = "pet", theme = "themes" } :: { [string]: string }

local function passByKey(key: string): Config.ShopItem?
	for _, p in Config.GamePasses do
		if p.key == key then
			return p
		end
	end
	return nil
end

local function isStudio(): boolean
	local ok, v = pcall(function()
		return RunService:IsStudio()
	end)
	return ok and v == true
end

-- Al entrar: qué pases tiene (en Studio, todos, para poder probarlos)
function Shop.join(s: any)
	s.passes = {}
	s.studio = isStudio()
	for _, p in Config.GamePasses do
		if s.studio then
			s.passes[p.key] = true
		elseif p.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(s.player.UserId, p.id)
			end)
			s.passes[p.key] = ok and owns == true
		end
	end
end

function Shop.owns(s: any, pass: string): boolean
	return s.passes ~= nil and s.passes[pass] == true
end

-- Las opciones decorativas solo se activan con su pase
function Shop.checkOption(s: any, key: string): (boolean, string?, { [string]: any }?)
	local pass = Shop.OPTION_PASS[key]
	if pass and not Shop.owns(s, pass) then
		return false, "err_need_pass", { item = "item_" .. pass }
	end
	return true
end

table.insert(Game.stateHooks, function(s: any, st: { [string]: any })
	st.passes = table.clone(s.passes or {})
	st.studio = s.studio == true
	local passes, products = {}, {}
	for _, p in Config.GamePasses do
		table.insert(passes, { key = p.key, id = p.id, price = p.price })
	end
	for _, p in Config.Products do
		table.insert(products, { key = p.key, id = p.id, price = p.price })
	end
	st.shop = { passes = passes, products = products }
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, id: number, purchased: boolean)
	local s = Game.sessions[player] :: any
	if not s or not purchased then
		return
	end
	for _, p in Config.GamePasses do
		if p.id == id and id ~= 0 then
			s.passes = s.passes or {}
			s.passes[p.key] = true
			Game.notify(s, "goal", "n_pass", { item = "item_" .. p.key })
			Game.sendState(s)
		end
	end
end)

-- Propinas: se apuntan en el perfil (sin efecto en el juego) y se confirman tras guardar
function Shop.processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and Game.sessions[player] :: any
	if not s then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = s.profile.receipts
	if receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local item: Config.ShopItem? = nil
	for _, p in Config.Products do
		if p.id == info.ProductId and p.id ~= 0 then
			item = p
		end
	end
	if not item then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	receipts[info.PurchaseId] = os.time()
	s.profile.tips += (item :: Config.ShopItem).price
	-- solo los últimos 50 recibos
	local list = {}
	for id, t in receipts do
		table.insert(list, { id = id, t = t })
	end
	if #list > 50 then
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
		for i = 1, #list - 50 do
			receipts[list[i].id] = nil
		end
	end
	if s.canSave and not Data.save(player.UserId, s.profile) then
		receipts[info.PurchaseId] = nil
		s.profile.tips -= (item :: Config.ShopItem).price
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Game.notify(s, "goal", "n_tip")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = Shop.processReceipt

local _ = passByKey
return Shop
