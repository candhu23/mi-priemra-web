--[[
	SaveService (ModuleScript en ServerScriptService)

	Guardado: DataStore, partida nueva, reconcile/migrate, bloqueo de sesión
	(F1), carga, guardado, puntuaciones de las clasificaciones.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))

local sessions = ServerState.sessions
type Session = ServerState.Session

local SaveService = {}
local Actions = {}

local store: DataStore? = nil

local leaderboardStore: OrderedDataStore? = nil

local weeklyStores: { [number]: OrderedDataStore } = {}

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[ImperioWeb] DataStore no disponible, no se guardará la partida:", result)
	end
	local okBoard, board = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_NAME)
	end)
	if okBoard then
		leaderboardStore = board
	end
end

-- Clasificación de una semana concreta (una por semana)
local function weeklyStore(week: number): OrderedDataStore?
	if weeklyStores[week] then
		return weeklyStores[week]
	end
	if not leaderboardStore then
		return nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.WEEKLY_STORE_PREFIX .. week)
	end)
	if ok then
		weeklyStores[week] = result
		return result
	end
	return nil
end

local function newData()
	return {
		money = Config.STARTING_MONEY,
		totalEarned = 0, -- ganado en esta partida (se reinicia al salir a bolsa)
		lifetimeEarned = 0, -- ganado desde siempre
		reputation = 0,
		shares = 0,
		ipoCount = 0,
		sites = {},
		project = nil,
		autoType = nil,
		companies = {},
		unlockedAds = { adsimple = true },
		maintenance = 0, -- $/s de contratos de mantenimiento
		goals = {},
		nextSiteId = 1,
		stats = { built = 0, sold = 0, clicks = 0, crits = 0, byType = {}, missions = 0, marketProfit = 0 },
		daily = { lastDay = -1, streak = 0 },
		boostUntil = 0,
		receipts = {},
		selectedNiche = Career.DEFAULT_NICHE,
		career = CareerService.newData(),
		tutorialDone = false,
		dailyMissions = { day = -1, list = {}, bonusGiven = false },
		settings = { muted = false, lang = "auto", volume = 1, music = true },
		lastOnline = os.time(),
		-- Ranking semanal: lo ganado esta semana y la anterior (para el premio)
		weekly = { week = -1, earned = 0, prevWeek = -1, prevEarned = 0, rewardedWeek = -1 },
		goldUntil = 0, -- rascacielos dorado (premio del ranking semanal)
		likes = 0, -- "me gusta" que ha recibido tu imperio
		likesGiven = { day = -1, ids = {} }, -- a quién has dado "me gusta" hoy
		-- v2.0
		collection = {}, -- [tipo] = { normal = true, brillante = true, ... }
		research = {}, -- [mejora] = nivel (I+D, no se pierde nunca)
		patents = 0, -- 💡 patentes sin gastar
		season = { id = -1, xp = 0, free = {}, premiumClaimed = {}, premium = false },
		playtime = { day = -1, seconds = 0, claimed = {} },
		codes = {}, -- [CÓDIGO] = true
		firstJoin = os.time(),
		starterBought = false,
		bestCombo = 0,
		-- v2.1
		weeklyMissions = { week = -1, list = {}, bonusGiven = false },
		-- v3.0
		portfolio = {}, -- Bolsa: [empresa] = { units, invested }
		peakIncome = 0, -- mejores ingresos/s de la partida (máximo invertible)
		-- v4.0
		dataVersion = Config.DATA_VERSION,
		badges = {}, -- [clave de Config.Badges] = true cuando ya se ha dado
		analytics = { onboarding = {} }, -- pasos del embudo ya enviados
	}
end

-- Campos que son listas o mapas "id → valor": si faltan se crean, pero no se
-- rellenan con lo que tenga la plantilla (no son registros con campos fijos)
local RECONCILE_MAPS = {
	sites = true, receipts = true, goals = true, codes = true, portfolio = true,
	companies = true, research = true, collection = true, programmers = true, contracts = true,
	badges = true, onboarding = true,
}

-- Rellena campos que falten en partidas guardadas con versiones antiguas
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" and not RECONCILE_MAPS[key] then
			reconcile(data[key], value)
		end
	end
	return data
end

-- Cambios de formato entre versiones de la partida guardada. Se ejecuta
-- después de reconcile; fromVersion = la versión con la que se guardó.
local function migrate(data, fromVersion: number)
	if fromVersion < 4 then
		-- v4: el máximo invertible en Bolsa ya no cuenta los boosts temporales
		-- (en la v3.1 un boost x2 lo subía para siempre): se recalcula solo
		data.peakIncome = 0
	end
	data.dataVersion = Config.DATA_VERSION
end

local function dataKey(player: Player): string
	return "player_" .. player.UserId
end

---------------------------------------------------------------------
-- Sesiones de jugador
---------------------------------------------------------------------

local saveData: (Player, Session) -> boolean

-- Guardados de salida en marcha en ESTE servidor (por UserId): si el jugador
-- vuelve a entrar antes de que acaben, se espera a que terminen
local releasing: { [number]: boolean } = {}

-- ¿Tiene la partida abierta OTRO servidor que sigue vivo?
local function lockedByOther(lock: any): boolean
	return type(lock) == "table" and lock.jobId ~= game.JobId
		and type(lock.t) == "number" and os.time() - lock.t < Config.SESSION_LOCK_STALE
end

-- Carga la partida y la bloquea para este servidor (todo dentro de
-- UpdateAsync, así dos servidores no pueden cogerla a la vez).
-- Devuelve (datos, se puede guardar, "locked" si otro servidor la tiene).
local function loadData(player: Player): (any, boolean, string?)
	if not store then
		return newData(), false, nil
	end
	local waited = 0
	while releasing[player.UserId] and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end
	local failures, lockedTries = 0, 0
	while true do
		local locked, loaded, fromVersion = false, nil, 0
		local ok, err = pcall(function()
			store:UpdateAsync(dataKey(player), function(old)
				locked, loaded = false, nil
				if type(old) == "table" and lockedByOther(old._lock) then
					locked = true
					return nil -- no se escribe nada
				end
				local data = if type(old) == "table" then old else newData()
				fromVersion = if type(old) == "table" then (tonumber(old.dataVersion) or 0) else Config.DATA_VERSION
				data._lock = { jobId = game.JobId, t = os.time() }
				loaded = data
				return data
			end)
		end)
		if ok and loaded then
			reconcile(loaded, newData())
			migrate(loaded, fromVersion)
			return loaded, true, nil
		elseif ok and locked then
			lockedTries += 1
			if lockedTries >= Config.LOCK_RETRIES then
				return nil, false, "locked"
			end
			task.wait(Config.LOCK_RETRY_WAIT)
		else
			failures += 1
			warn("[ImperioWeb] Error cargando datos (intento " .. failures .. "):", err)
			if failures >= 3 then
				return newData(), false, nil
			end
			task.wait(2)
		end
	end
end

local pendingSaves = 0

-- Puntuación para la clasificación: logaritmo para que quepan cifras enormes
local function leaderboardScore(amount: number): number
	return math.floor(math.log10(1 + math.max(0, amount)) * 1e14)
end

local function leaderboardValue(score: number): number
	return 10 ^ (score / 1e14) - 1
end

-- Texto en el idioma del jugador (para Kick, que no pasa por el cliente)
local function kickText(player: Player, text: string): string
	local ok, localeId = pcall(function()
		return player.LocaleId
	end)
	local setting = if sessions[player] then sessions[player].data.settings.lang else nil
	return Locale.translate(Locale.resolve(setting, if ok then localeId else nil), text)
end

-- release = true al salir: guarda por última vez y quita el bloqueo
function saveData(player: Player, session: Session, release: boolean?): boolean
	if not session.canSave or not store then
		return false
	end
	if session.closed and not release then
		return false -- el jugador ya se fue: lo último lo guarda la salida
	end
	local data = session.data
	data.lastOnline = os.time()
	pendingSaves += 1
	local lost = false
	local ok, err = pcall(function()
		store:UpdateAsync(dataKey(player), function(old)
			lost = false
			-- Otro servidor se ha quedado la partida: no la machacamos
			if type(old) == "table" and type(old._lock) == "table" and old._lock.jobId ~= game.JobId then
				lost = true
				return nil
			end
			data._lock = if release then nil else { jobId = game.JobId, t = os.time() }
			return data
		end)
	end)
	if ok and lost then
		ok = false
		session.canSave = false
		warn("[ImperioWeb] La partida de " .. player.Name .. " está abierta en otro servidor: este ya no la guarda")
		if not release and player.Parent then
			player:Kick(kickText(player, "Tu partida se ha abierto en otro servidor. Vuelve a entrar para seguir jugando."))
		end
		pendingSaves -= 1
		session.lastSaveOk = false
		return false
	end
	if leaderboardStore then
		pcall(function()
			leaderboardStore:SetAsync("u_" .. player.UserId, leaderboardScore(session.data.lifetimeEarned))
		end)
	end
	local weekly = session.data.weekly
	local weekStore = if weekly.earned > 0 then weeklyStore(weekly.week) else nil
	if weekStore then
		pcall(function()
			weekStore:SetAsync("u_" .. player.UserId, leaderboardScore(weekly.earned))
		end)
	end
	pendingSaves -= 1
	session.lastSaveOk = ok
	if ok then
		session.lastSaveAt = os.time()
	else
		warn("[ImperioWeb] Error guardando datos de " .. player.Name .. ":", err)
	end
	return ok
end

---------------------------------------------------------------------
-- Ranking semanal: cambio de semana y premios
---------------------------------------------------------------------

Actions.saveNow = function(player: Player, session: Session)
	if not session.canSave then
		return false, "⚠️ El guardado está desactivado: publica el juego y activa «Enable Studio Access to API Services»."
	end
	local now = os.clock()
	if now - session.lastManualSave < Config.MANUAL_SAVE_COOLDOWN then
		return false, "Espera " .. math.ceil(Config.MANUAL_SAVE_COOLDOWN - (now - session.lastManualSave)) .. " s para volver a guardar."
	end
	session.lastManualSave = now
	if saveData(player, session) then
		return true, "💾 Partida guardada"
	end
	return false, "❌ No se pudo guardar. Se volverá a intentar solo."
end

-- Quita el bloqueo si el jugador se fue mientras cargaba
local function releaseLock(player: Player)
	if not store then
		return
	end
	pcall(function()
		store:UpdateAsync(dataKey(player), function(old)
			if type(old) == "table" and type(old._lock) == "table" and old._lock.jobId == game.JobId then
				old._lock = nil
				return old
			end
			return nil
		end)
	end)
end

SaveService.dataKey = dataKey
SaveService.kickText = kickText
SaveService.leaderboardScore = leaderboardScore
SaveService.leaderboardStore = leaderboardStore
SaveService.leaderboardValue = leaderboardValue
SaveService.loadData = loadData
SaveService.lockedByOther = lockedByOther
SaveService.migrate = migrate
SaveService.newData = newData
SaveService.reconcile = reconcile
SaveService.releaseLock = releaseLock
SaveService.saveData = saveData
SaveService.releasing = releasing
SaveService.weeklyStore = weeklyStore
SaveService.Actions = Actions

-- Guardados en marcha (BindToClose espera a que acaben)
function SaveService.pending(): number
	return pendingSaves
end

return SaveService
