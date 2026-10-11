--!strict
-- Datos del jugador en DataStore: opciones, logros, mejor tiempo, fase especial y 3 ranuras de partida.
-- IMPORTANTE: en Studio sin publicar, GetDataStore da error. TODO va dentro de pcall: el juego funciona igual
-- (sin guardar) en vez de pararse. Si la carga falla, no se guarda (para no machacar la partida buena).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Data = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("EstanteriasHechizadas_v1")
end)

function Data.available(): boolean
	return store ~= nil
end

-- Partida nueva de una ranura (los libros se guardan como cadena: 8 caracteres por libro)
function Data.newSlot(): any
	return {
		books = "", hand = {}, best = 0, spent = 0,
		skills = { sort = 0, guide = 0, reveal = 0, auto = 0, gather = 0 },
		keys = { red = false, green = false, yellow = false, blue = false },
		chests = { red = false, green = false, yellow = false, blue = false },
		time = 0, magic = false, tut = 0, pos = nil, finished = false, ending = "", rank = 0,
		rows = 0, shelved = 0, created = os.time(), updated = os.time(),
	}
end

function Data.newProfile(): any
	return {
		v = 1,
		settings = {
			lang = "", sens = 1, fov = 70, bob = true, music = 0.5, sfx = 0.6, cozy = false, left = false,
			glow = "gold", pet = false, theme = "normal", -- decorativas (con pase)
		},
		achievements = {}, -- id = true
		bestTime = 0, -- 0 = sin récord (solo partidas con la biblioteca entera bien)
		special = false, -- fase especial desbloqueada
		slots = { false, false, false }, -- false = vacía
		lastSlot = 0,
		lastOnline = 0,
		receipts = {}, -- propinas ya cobradas (PurchaseId = hora)
		tips = 0,
	}
end

-- Rellena campos nuevos en partidas antiguas (solo diccionarios; las listas no se tocan)
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v)
		end
	end
end

function Data.fixSlot(slot: any): any
	if type(slot) ~= "table" then
		return false
	end
	reconcile(slot, Data.newSlot())
	return slot
end

-- Devuelve (perfil, sePuedeGuardar)
function Data.load(userId: number): (any, boolean)
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
	local profile = if type(raw) == "table" then raw else Data.newProfile()
	reconcile(profile, Data.newProfile())
	for i = 1, Config.SLOTS do
		profile.slots[i] = Data.fixSlot(profile.slots[i])
	end
	return profile, ok
end

function Data.save(userId: number, profile: any): boolean
	if not store then
		return false
	end
	profile.lastOnline = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync("player_" .. userId, function()
			return profile
		end)
	end)
	if not ok then
		warn("No se pudo guardar", userId, err)
	end
	return ok
end

return Data
