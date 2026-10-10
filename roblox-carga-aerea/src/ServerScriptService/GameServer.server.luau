--!strict
-- Servidor de «AeroCarga España». Crea los remotes, carga/guarda partidas, ejecuta las acciones
-- y manda el estado a cada jugador una vez por segundo. La lógica está en Cargo/Game.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))
local cargo = script.Parent:WaitForChild("Cargo")
local Data = require(cargo:WaitForChild("Data"))
local Game = require(cargo:WaitForChild("Game"))
local Shop = require(cargo:WaitForChild("Shop"))

local remotes = Instance.new("Folder")
remotes.Name = "CargoRemotes"
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

Game.notify = function(player: Player, kind: string, key: string, params: { [string]: any }?)
	notifyRemote:FireClient(player, kind, key, params or {})
end
Game.notifyAll = function(kind: string, key: string, params: { [string]: any }?)
	notifyRemote:FireAllClients(kind, key, params or {})
end

-- Clasificación global y semanal (se refrescan cada 2 min) con nombres en caché
local top: { any } = {}
local weekTop: { any } = {}
local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if not names[userId] then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		names[userId] = ok and name or ("#" .. userId)
	end
	return names[userId]
end

---------------------------------------------------------------------
-- Estado que se manda al cliente
---------------------------------------------------------------------
local function sendState(player: Player)
	local session = Game.sessions[player]
	if not session then
		return
	end
	local data = session.data
	local now = os.time()
	local boards, refresh = {}, {}
	for _, p in data.planes do
		if not p.flight and not boards[p.airport] then
			boards[p.airport] = Game.board(session, p.airport)
			refresh[p.airport] = math.max(0, (session.refreshAt[p.airport] or 0) - now)
		end
	end
	local ex = session.express
	local level = Game.level(data)
	local cash = {}
	for key in Config.CashPacks do
		cash[key] = Game.cashPack(session, key)
	end
	local s = session.social
	local world = Game.world
	-- Contratos (solo lo que necesita la interfaz)
	local contracts = data.contracts
	-- Aviones de los demás jugadores del servidor (para verlos en el mapa)
	local traffic = {}
	for other, os2 in Game.sessions do
		if other ~= player then
			for _, p in os2.data.planes do
				local f = p.flight
				if f and f.good ~= "charter" and #traffic < 24 then
					table.insert(traffic, {
						name = os2.player.DisplayName, model = p.model, from = f.from, to = f.to, startT = f.startT,
						endT = f.endT, color = os2.data.airline.color,
					})
				end
			end
		end
	end
	local stamps, stampsMax = Rules.stamps(data.album)
	stateRemote:FireClient(player, {
		money = data.money,
		xp = data.xp,
		level = level,
		planes = data.planes,
		pilots = data.pilots,
		candidates = data.candidates,
		candidatesIn = math.max(0, data.candidatesAt + Config.CANDIDATE_REFRESH - now),
		regions = data.regions,
		upgrades = data.upgrades,
		settings = data.settings,
		stats = data.stats,
		goals = data.goals,
		missions = data.missions,
		daily = {
			available = data.daily.last ~= math.floor(now / 86400),
			streak = data.daily.streak,
			lost = data.daily.last < math.floor(now / 86400) - 1,
		},
		tutorial = data.tutorial,
		now = now,
		fuelPrice = Game.fuelPrice(data),
		boards = boards,
		refresh = refresh,
		express = ex and { code = ex.from, id = ex.id, expires = ex.express, to = ex.to, good = ex.good } or nil,
		maxPlanes = Game.maxPlanes(session),
		autoUnlocked = Game.autoUnlocked(session),
		passes = session.passes,
		moneyMult = Game.moneyMult(session),
		social = { friends = s.friends, premium = s.premium, group = s.group },
		boostLeft = math.max(0, data.boostUntil - now),
		timeMult = Game.timeMult(session),
		cash = cash,
		starterBought = data.starterBought,
		rewardScale = Game.rewardBase(session),
		canSave = session.canSave,
		version = Config.VERSION,
		-- v0.3
		incomePerMin = math.floor(session.incomePerMin),
		event = world.event and world.event.id or nil,
		eventLeft = world.eventLeft,
		wanted = world.wanted,
		wantedLeft = world.wantedLeft,
		sat = Game.satMap(session),
		album = data.album,
		stamps = stamps,
		stampsMax = stampsMax,
		contracts = {
			offers = contracts.offers, active = contracts.active, slots = Game.contractSlots(data),
			nextIn = math.max(0, contracts.nextAt - now),
		},
		charterPay = { c1 = Game.charterPay(session, "c1"), c4 = Game.charterPay(session, "c4"), c8 = Game.charterPay(session, "c8") },
		shares = data.shares,
		newShares = Game.newShares(data),
		ipoCount = data.ipoCount,
		runEarned = data.run.earned,
		airline = data.airline,
		traffic = traffic,
	})
end

Game.pushState = sendState

---------------------------------------------------------------------
-- Entrada y salida de jugadores
---------------------------------------------------------------------
local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "⭐"
	level.Parent = stats
	local earned = Instance.new("StringValue")
	earned.Name = "💰"
	earned.Parent = stats
	stats.Parent = player
end

local function updateLeaderstats(player: Player, data: any)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local level = stats:FindFirstChild("⭐") :: IntValue?
	local earned = stats:FindFirstChild("💰") :: StringValue?
	if level then
		level.Value = Game.level(data)
	end
	if earned then
		local e = data.stats.earned
		earned.Value = e >= 1e9 and string.format("$%.1fB", e / 1e9) or e >= 1e6 and string.format("$%.1fM", e / 1e6)
			or e >= 1e3 and string.format("$%.0fK", e / 1e3) or string.format("$%d", e)
	end
end

local function onPlayerAdded(player: Player)
	local data, canSave, fresh = Data.load(player.UserId)
	if not player.Parent then
		return
	end
	local session: Game.Session = {
		player = player, data = data, canSave = canSave, boards = {}, refreshAt = {}, nextLoadId = 0,
		passes = {}, social = { friends = 0, premium = false, group = false }, express = nil,
		nextExpress = os.time() + 60, dirty = false, actionWindow = 0, actionCount = 0,
		earnedWindow = 0, incomePerMin = 0, offlineLast = 0, sat = {},
	}
	Game.sessions[player] = session
	Shop.loadPasses(session)
	setupLeaderstats(player)
	Game.onJoin(session)
	task.spawn(Game.updateSocial)
	if not canSave then
		Game.notify(player, "error", "n_load_failed")
	elseif fresh then
		Game.notify(player, "info", "n_welcome")
	end
	updateLeaderstats(player, data)
	sendState(player)
end

local function save(player: Player)
	local session = Game.sessions[player]
	if session and session.canSave then
		if Data.save(player.UserId, session.data) then
			session.dirty = false
		end
		Data.submitScore(player.UserId, session.data)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	Game.sessions[player] = nil
	task.spawn(Game.updateSocial)
end)
game:BindToClose(function()
	for player in Game.sessions do
		save(player)
	end
end)
Shop.init()

---------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------
actionRemote.OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
	local session = Game.sessions[player]
	if not session or type(action) ~= "string" then
		return false, "err_generic"
	end
	if action == "getTop" then
		return true, nil, nil, { top = top, week = weekTop }
	end
	local now = os.clock()
	if now - session.actionWindow > 1 then
		session.actionWindow = now
		session.actionCount = 0
	end
	session.actionCount += 1
	if session.actionCount > 10 then
		return false, "err_slow_down"
	end
	local fn = Game.Actions[action]
	if not fn then
		return false, "err_generic"
	end
	local ok, key, params, extra = fn(session, a, b, c)
	if ok then
		sendState(player) -- si falla no ha cambiado nada (el estado llega igualmente cada segundo)
	end
	return ok, key, params, extra
end

---------------------------------------------------------------------
-- Bucle principal (1 s)
---------------------------------------------------------------------
local lastSave, lastTop = os.time(), 0
while true do
	task.wait(1)
	local now = os.time()
	Game.tick(now)
	for player, session in Game.sessions do
		updateLeaderstats(player, session.data)
		sendState(player)
	end
	if now - lastSave >= 60 then
		lastSave = now
		for player, session in Game.sessions do
			if session.dirty then
				task.spawn(save, player)
			end
		end
	end
	if now - lastTop >= 120 then
		lastTop = now
		task.spawn(function()
			for player, session in Game.sessions do
				if session.canSave then
					Data.submitScore(player.UserId, session.data)
				end
			end
			local list = {}
			for i, entry in Data.fetchTop(20) do
				list[i] = { name = nameOf(entry.userId), earned = entry.earned }
			end
			top = list
			local week = {}
			for i, entry in Data.fetchTop(20, true) do
				week[i] = { name = nameOf(entry.userId), earned = entry.earned }
			end
			weekTop = week
		end)
	end
end
