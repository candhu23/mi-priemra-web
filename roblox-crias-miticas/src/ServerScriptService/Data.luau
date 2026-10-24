--[[
	Data: partida de cada jugador en DataStore.
	IMPORTANTE: en Studio sin publicar, GetDataStore da error → todo va en pcall y, si falla,
	se juega sin guardar (canSave = false) en vez de romper el servidor.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Data = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("MythicHatchlings_v1")
end)

function Data.newData(): any
	local generators = {}
	for _, g in Config.Generators do
		generators[g.id] = 0
	end
	return {
		money = Config.START_MONEY,
		lifetimeEarned = 0,
		generators = generators,
		clickLevel = 0,
		daily = { lastDay = 0, streak = 0 },
		receipts = {}, -- purchaseId = hora (las últimas 50): compras idempotentes
		stats = { clicks = 0, bought = 0 },
		settings = { lang = "", muted = false },
		lastOnline = 0,
		version = 1,
	}
end

-- Rellena campos nuevos en partidas viejas (añadir un campo a newData basta)
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function key(userId: number): string
	return "player_" .. userId
end

-- Devuelve (datos, sePuedeGuardar). Si falla, partida nueva SIN guardar (para no machacar la buena).
function Data.load(userId: number): (any, boolean)
	if not store then
		return Data.newData(), false
	end
	for intento = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(key(userId))
		end)
		if ok then
			local data = if type(result) == "table" then result else Data.newData()
			reconcile(data, Data.newData())
			return data, true
		end
		warn("Data.load falló (intento " .. intento .. "): " .. tostring(result))
		task.wait(intento)
	end
	return Data.newData(), false
end

function Data.save(userId: number, data: any): boolean
	if not store then
		return false
	end
	for intento = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(userId), function()
				return data
			end)
		end)
		if ok then
			return true
		end
		warn("Data.save falló (intento " .. intento .. "): " .. tostring(err))
		task.wait(intento)
	end
	return false
end

return Data
