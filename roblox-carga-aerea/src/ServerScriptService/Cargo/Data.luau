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
pcall(function()
	store = DataStoreService:GetDataStore("AeroCarga_v1")
	topStore = DataStoreService:GetOrderedDataStore("AeroCargaTop_v1")
end)

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
		upgrades = { hangar = 0, sales = 0, fuel = 0, fast = 0, cold = 0 },
		settings = { lang = "", muted = false, auto = false },
		stats = { flights = 0, km = 0, tons = 0, earned = 0, express = 0, localGoods = 0, purchases = 0 },
		goals = {}, -- id = true → reclamado
		missions = { day = 0, list = {}, bonusGiven = false },
		daily = { last = 0, streak = 0 },
		tutorial = 0, -- paso actual; 99 = terminado
		boostUntil = 0,
		rate = 0, -- dinero/s medio con despacho automático (para las ganancias offline)
		receipts = {},
		starterBought = false,
		lastOnline = 0,
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
	local data = raw or Data.newData()
	reconcile(data, Data.newData())
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
function Data.submitScore(userId: number, earned: number)
	if not topStore then
		return
	end
	pcall(function()
		(topStore :: OrderedDataStore):SetAsync(tostring(userId), math.floor(math.log10(1 + earned) * 1e12))
	end)
end

function Data.fetchTop(count: number): { { userId: number, earned: number } }
	local out = {}
	if not topStore then
		return out
	end
	pcall(function()
		local page = (topStore :: OrderedDataStore):GetSortedAsync(false, count):GetCurrentPage()
		for _, entry in page do
			table.insert(out, { userId = tonumber(entry.key) or 0, earned = 10 ^ (entry.value / 1e12) - 1 })
		end
	end)
	return out
end

return Data
