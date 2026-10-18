--[[
	Servidor de {{NOMBRE}}. EL SERVIDOR MANDA: el cliente solo enseña y pide acciones.
	Remotes (ReplicatedStorage.{{PREFIJO}}Remotes):
	  Action (RemoteFunction): InvokeServer(acción, a, b) → (ok, claveTexto?, params?)
	  State  (RemoteEvent): estado completo cada segundo y tras cada acción
	  Notify (RemoteEvent): (tipo, claveTexto, params) — el cliente traduce con Lang
	Para añadir una acción: función en Actions + botón en el cliente + harness (run_juego.luau).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = require(ServerScriptService:WaitForChild("Data"))

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "{{PREFIJO}}Remotes"
local actionRemote = Instance.new("RemoteFunction")
actionRemote.Name = "Action"
actionRemote.Parent = remotes
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = remotes
local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Sesiones
---------------------------------------------------------------------
type Session = {
	data: any,
	canSave: boolean,
	bonuses: { x2: boolean, auto: boolean, boost: boolean, friends: number, premium: boolean },
	boostUntil: number,
	actionTimes: { number },
	clickTimes: { number },
	dirty: boolean,
}
local sessions: { [Player]: Session } = {}

local function passByKey(k: string): Config.ShopItem?
	for _, p in Config.GamePasses do
		if p.key == k then
			return p
		end
	end
	return nil
end

local function notify(player: Player, kind: string, textKey: string, params: { [string]: any }?)
	notifyRemote:FireClient(player, kind, textKey, params or {})
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function earn(s: Session, amount: number)
	s.data.money += amount
	s.data.lifetimeEarned += amount
	s.dirty = true
end

local function buildState(s: Session): any
	local d = s.data
	return {
		money = d.money,
		lifetimeEarned = d.lifetimeEarned,
		generators = d.generators,
		clickLevel = d.clickLevel,
		incomePerSec = Config.incomePerSec(d, s.bonuses),
		clickValue = Config.clickValue(d, s.bonuses),
		bonuses = s.bonuses,
		daily = { available = d.daily.lastDay < today(), streak = d.daily.streak },
		settings = d.settings,
		canSave = s.canSave,
		version = Config.VERSION,
	}
end

local function sendState(player: Player)
	local s = sessions[player]
	if s then
		stateRemote:FireClient(player, buildState(s))
	end
end

-- Límite de peticiones: devuelve true si se pasa (ventana de 1 s)
local function tooFast(times: { number }, limit: number): boolean
	local now = os.clock()
	while times[1] and now - times[1] > 1 do
		table.remove(times, 1)
	end
	if #times >= limit then
		return true
	end
	table.insert(times, now)
	return false
end

---------------------------------------------------------------------
-- Acciones (valida SIEMPRE los argumentos: vienen del cliente)
---------------------------------------------------------------------
local Actions = {}

function Actions.click(_player: Player, s: Session)
	earn(s, Config.clickValue(s.data, s.bonuses))
	s.data.stats.clicks += 1
	return true
end

function Actions.buy(_player: Player, s: Session, id: any)
	if type(id) ~= "string" or not Config.GeneratorById[id] then
		return false
	end
	local owned = s.data.generators[id] or 0
	local cost = Config.genCost(id, owned)
	if s.data.money < cost then
		return false, "n_no_money"
	end
	s.data.money -= cost
	s.data.generators[id] = owned + 1
	s.data.stats.bought += 1
	s.dirty = true
	return true, "n_bought", { item = "gen_" .. id }
end

function Actions.upgradeClick(_player: Player, s: Session)
	if s.data.clickLevel >= Config.ClickUpgrade.max then
		return false
	end
	local cost = Config.clickUpgradeCost(s.data.clickLevel)
	if s.data.money < cost then
		return false, "n_no_money"
	end
	s.data.money -= cost
	s.data.clickLevel += 1
	s.dirty = true
	return true
end

function Actions.claimDaily(_player: Player, s: Session)
	local d = s.data.daily
	local t = today()
	if d.lastDay >= t then
		return false, "daily_done"
	end
	d.streak = if d.lastDay == t - 1 then (d.streak % #Config.Daily) + 1 else 1
	d.lastDay = t
	local reward = Config.dailyReward(d.streak, Config.incomePerSec(s.data, s.bonuses))
	earn(s, reward)
	return true, "n_daily", { value = reward }
end

function Actions.setLang(_player: Player, s: Session, lang: any)
	if lang ~= "" and lang ~= "es" and lang ~= "en" then
		return false
	end
	s.data.settings.lang = lang
	s.dirty = true
	return true
end

function Actions.setMuted(_player: Player, s: Session, muted: any)
	if type(muted) ~= "boolean" then
		return false
	end
	s.data.settings.muted = muted
	return true
end

actionRemote.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
	local s = sessions[player]
	if not s or type(action) ~= "string" then
		return false
	end
	local fn = (Actions :: any)[action]
	if not fn then
		return false
	end
	if action == "click" then
		if tooFast(s.clickTimes, 15) then
			return false
		end
	elseif tooFast(s.actionTimes, 10) then
		return false, "n_too_fast"
	end
	local ok, textKey, params = fn(player, s, a, b)
	sendState(player)
	return ok, textKey, params
end

---------------------------------------------------------------------
-- Entrar y salir
---------------------------------------------------------------------
local function ownsPass(player: Player, item: Config.ShopItem?): boolean
	if not item or item.id == 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.id)
	end)
	return ok and owns == true
end

local function save(player: Player)
	local s = sessions[player]
	if s and s.canSave then
		s.data.lastOnline = os.time()
		Data.save(player.UserId, s.data)
		s.dirty = false
	end
end

local function onPlayerAdded(player: Player)
	local data, canSave = Data.load(player.UserId)
	if not player.Parent then
		return
	end
	local s: Session = {
		data = data,
		canSave = canSave,
		bonuses = {
			x2 = ownsPass(player, passByKey("x2")),
			auto = ownsPass(player, passByKey("auto")),
			boost = false,
			friends = 0,
			premium = player.MembershipType == Enum.MembershipType.Premium,
		},
		boostUntil = 0,
		actionTimes = {},
		clickTimes = {},
		dirty = false,
	}
	sessions[player] = s

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Parent = stats
	stats.Parent = player

	-- Ganancias mientras no estaba
	if data.lastOnline > 0 then
		local away = math.clamp(os.time() - data.lastOnline, 0, Config.OFFLINE_MAX_HOURS * 3600)
		local offline = math.floor(Config.incomePerSec(data, s.bonuses) * away * Config.OFFLINE_RATE)
		if offline > 0 then
			earn(s, offline)
			notify(player, "welcome", "welcome_back", { value = offline })
		end
	end
	if not canSave then
		notify(player, "error", "n_no_save")
	end
	sendState(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
end)
game:BindToClose(function()
	for player in sessions do
		save(player)
	end
end)

---------------------------------------------------------------------
-- Compras
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
	local s = sessions[player]
	if not (s and bought) then
		return
	end
	for _, p in Config.GamePasses do
		if p.id == passId then
			(s.bonuses :: any)[p.key] = true
			notify(player, "success", "n_purchase")
			sendState(player)
		end
	end
end)

MarketplaceService.ProcessReceipt = function(info: any)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and sessions[player]
	if not (player and s) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = tostring(info.PurchaseId)
	if s.data.receipts[id] then -- ya entregado (Roblox puede repetir el aviso)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local item: Config.ShopItem? = nil
	for _, p in Config.Products do
		if p.id ~= 0 and p.id == info.ProductId then
			item = p
		end
	end
	if not item then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local minutes = Config.CashMinutes[item.key]
	if minutes then
		earn(s, math.max(Config.CASH_MIN, math.floor(Config.incomePerSec(s.data, s.bonuses) * 60 * minutes)))
	end
	s.data.receipts[id] = os.time()
	-- Solo las últimas 50
	local list = {}
	for k, t in s.data.receipts do
		table.insert(list, { k, t })
	end
	table.sort(list, function(x, y)
		return x[2] > y[2]
	end)
	for i = 51, #list do
		s.data.receipts[list[i][1]] = nil
	end
	-- Confirmar SOLO si se ha guardado (si no, Roblox lo reintenta más tarde)
	if s.canSave and not Data.save(player.UserId, s.data) then
		s.data.receipts[id] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	notify(player, "success", "n_purchase")
	sendState(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------
-- Bucle principal (1 s)
---------------------------------------------------------------------
local saveTimer = 0
while true do
	task.wait(1)
	saveTimer += 1
	for player, s in sessions do
		s.bonuses.boost = os.time() < s.boostUntil
		local income = Config.incomePerSec(s.data, s.bonuses)
		if income > 0 then
			earn(s, income)
		end
		if s.bonuses.auto then
			earn(s, 2 * Config.clickValue(s.data, s.bonuses))
		end
		local stats = player:FindFirstChild("leaderstats")
		local money = stats and stats:FindFirstChild("Money")
		if money and money:IsA("NumberValue") then
			money.Value = math.floor(s.data.money)
		end
		sendState(player)
	end
	if saveTimer >= 60 then
		saveTimer = 0
		for player, s in sessions do
			if s.dirty then
				task.spawn(save, player)
			end
		end
	end
end
