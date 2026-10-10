--!strict
-- Datos del jugador: partida nueva, migración de partidas viejas, carga, guardado y clasificación.
-- IMPORTANTE: en Studio sin publicar, GetDataStore da error. Todo va dentro de pcall para que el
-- juego funcione igual (sin guardar) en vez de pararse.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Data = {}

local store: DataStore? = nil
local topStore: OrderedDataStore? = nil
local weekStores: { [number]: OrderedDataStore } = {}
pcall(function()
	store = DataStoreService:GetDataStore("AeroCarga_v1")
	topStore = DataStoreService:GetOrderedDataStore("AeroCargaTop_v1")
end)

-- Semana actual (empieza el lunes a las 00:00 UTC)
function Data.weekId(now: number): number
	return math.floor((now - 345600) / 604800)
end

local function weekStore(id: number): OrderedDataStore?
	if not topStore then
		return nil
	end
	if not weekStores[id] then
		pcall(function()
			weekStores[id] = DataStoreService:GetOrderedDataStore("AeroCargaWeek_" .. id)
		end)
	end
	return weekStores[id]
end

function Data.newData(): any
	return {
		money = Config.START_MONEY,
		xp = 0,
		planes = { { id = 1, model = "sparrow", airport = Config.START_HUB, condition = 100 } },
		nextId = 2,
		pilots = {},
		candidates = {},
		candidatesAt = 0,
		regions = { CEN = true, LEV = true },
		upgrades = { hangar = 0, sales = 0, fuel = 0, fast = 0, cold = 0, tank = 0 },
		settings = { lang = "", muted = false, auto = false },
		stats = {
			flights = 0, km = 0, tons = 0, earned = 0, express = 0, localGoods = 0, purchases = 0,
			contracts = 0, perfect = 0, charters = 0, newRoutes = 0,
		},
		goals = {}, -- id = true → reclamado
		missions = { day = 0, list = {}, bonusGiven = false },
		daily = { last = 0, streak = 0 },
		tutorial = 0, -- paso actual; 99 = terminado
		boostUntil = 0,
		rate = 0, -- dinero/s medio con despacho automático (para las ganancias offline)
		receipts = {},
		starterBought = false,
		lastOnline = 0,
		-- v0.3
		album = { airports = {}, goods = {} }, -- pasaporte: aeropuertos visitados y entregas por producto
		contracts = { offers = {}, active = {}, nextAt = 0 },
		shares = 0, -- acciones cobradas (+10 % de pago cada una)
		ipoCount = 0, -- veces que has salido a bolsa
		run = { earned = 0 }, -- lo ganado desde la última salida a bolsa
		airline = { a = math.random(1, 8), b = math.random(1, 8), c = math.random(1, 8), color = math.random(1, 9) },
		week = { id = 0, earned = 0 }, -- ranking semanal
		-- v0.4
		fuel = Config.FUEL_START, -- litros en el depósito
		rep = Config.REP_START, -- reputación 0–100
		staff = { dispatcher = 0 }, -- nivel del despachador (0 = sin contratar)
		mechanics = {}, -- { id, name, avatar, stars }
		mechCandidates = {},
	}
end

-- Rellena campos nuevos en partidas antiguas (solo tablas tipo diccionario)
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v)
		end
	end
end

-- Devuelve (datos, sePuedeGuardar, esNueva)
function Data.load(userId: number): (any, boolean, boolean)
	local raw, ok = nil, false
	if store then
		for attempt = 1, 3 do
			ok = pcall(function()
				raw = (store :: DataStore):GetAsync("player_" .. userId)
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
	end
	local fresh = raw == nil
	-- Partidas anteriores a la v0.4 (sin depósito): se marcan para darles el depósito lleno y el despachador
	local beforeV4 = raw ~= nil and raw.fuel == nil
	local data = raw or Data.newData()
	reconcile(data, Data.newData())
	if beforeV4 then
		data.migrateV4 = true
	end
	return data, ok, fresh
end

function Data.save(userId: number, data: any): boolean
	if not store then
		return false
	end
	data.lastOnline = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync("player_" .. userId, function()
			return data
		end)
	end)
	if not ok then
		warn("No se pudo guardar", userId, err)
	end
	return ok
end

-- Clasificación: el valor guardado comprime cifras enormes (log10) para que quepan
local function encode(earned: number): number
	return math.floor(math.log10(1 + math.max(0, earned)) * 1e12)
end

function Data.submitScore(userId: number, data: any)
	if not topStore then
		return
	end
	pcall(function()
		(topStore :: OrderedDataStore):SetAsync(tostring(userId), encode(data.stats.earned))
	end)
	local ws = data.week and data.week.earned > 0 and weekStore(data.week.id)
	if ws then
		pcall(function()
			ws:SetAsync(tostring(userId), encode(data.week.earned))
		end)
	end
end

-- weekly = true → ranking de esta semana; si no, el de siempre
function Data.fetchTop(count: number, weekly: boolean?): { { userId: number, earned: number } }
	local out = {}
	local source = if weekly then weekStore(Data.weekId(os.time())) else topStore
	if not source then
		return out
	end
	pcall(function()
		local page = (source :: OrderedDataStore):GetSortedAsync(false, count):GetCurrentPage()
		for _, entry in page do
			table.insert(out, { userId = tonumber(entry.key) or 0, earned = 10 ^ (entry.value / 1e12) - 1 })
		end
	end)
	return out
end

return Data
