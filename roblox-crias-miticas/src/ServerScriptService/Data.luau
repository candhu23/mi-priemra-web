--[[
	Data: partida de cada jugador en DataStore.
	DataStore MythicHatchlings_v2 (v1 tenía Dorada/Arcoíris y Renacer; el juego no estaba publicado: sin migración).
	IMPORTANTE: en Studio sin publicar, GetDataStore da error → todo va en pcall y, si falla,
	se juega sin guardar (canSave = false) en vez de romper el servidor.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Data = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("MythicHatchlings_v2")
end)

function Data.newData(): any
	return {
		coins = 0,
		lifetimeCoins = 0,
		zones = 1, -- islas abiertas (1 = solo la primera)
		pets = { { uid = 1, kind = Config.STARTER_PET, shiny = false } }, -- { uid, kind, shiny }
		equipped = { 1 }, -- uids de las crías equipadas
		nextUid = 2,
		album = { [Config.STARTER_PET] = true }, -- cría descubierta = true (Índice)
		shinyIndex = {}, -- cría que has tenido Brillante = true (puntuación Brillante; no baja nunca)
		albumClaimed = {}, -- "índice del hito" = true
		stones = 0, -- Piedras de Renacimiento (1 por Mítica creada)
		upgrades = {}, -- id de mejora del Jardín = true
		daily = { lastDay = 0, streak = 0 },
		missions = { day = 0, list = {}, bonusGiven = false }, -- list = { { tier, stat, n, start, claimed } }
		boosts = { coinsUntil = 0, luckUntil = 0 },
		tutorialDone = false,
		receipts = {}, -- purchaseId = hora (las últimas 50): compras idempotentes
		stats = { piles = 0, hatched = 0, fused = 0, mythics = 0, shinies = 0 },
		settings = { lang = "", muted = false, auto = true },
		lastOnline = 0,
		version = 3,
	}
end

-- Rellena campos nuevos en partidas viejas (añadir un campo a newData basta)
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and v[1] == nil then -- las listas no se tocan
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
