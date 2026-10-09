--[[
	StatePatch (ModuleScript en ReplicatedStorage)

	Para no mandar el estado completo cada segundo (F7): el servidor recuerda
	lo último que envió a cada jugador y solo manda lo que ha cambiado (un
	"parche"); el cliente lo aplica sobre su copia.

	Formato del parche (todo con claves de texto, para que viaje bien por un
	RemoteEvent, que no admite tablas mezcladas):
	  · tabla con __p = true → parche de un diccionario: solo las claves que
	    cambian; una clave con valor NIL significa "ya no existe"
	  · tabla con __a = n    → parche de una lista de n elementos: las
	    posiciones que cambian van como texto ("3" = elemento 3)
	  · cualquier otro valor  → sustituye al anterior tal cual
]]

local StatePatch = {}

StatePatch.NIL = "\0nil" -- marca de "este campo se ha borrado"

-- ¿Es una lista 1..n sin huecos? (una tabla vacía cuenta como lista)
local function isArray(t: { [any]: any }): boolean
	local count = 0
	for _ in t do
		count += 1
	end
	return count == #t
end

local diffValue: (old: any, new: any) -> any

local function diffTable(old: { [any]: any }, new: { [any]: any }): any
	local array = isArray(new)
	if array ~= isArray(old) then
		return new -- cambió de tipo: se manda entera
	end
	local changed = false
	local patch: { [string]: any } = {}
	if array then
		patch.__a = #new
		changed = #new ~= #old
		for i = 1, #new do
			local d = diffValue(old[i], new[i])
			if d ~= nil then
				patch[tostring(i)] = d
				changed = true
			end
		end
	else
		patch.__p = true
		for key, value in new do
			local d = diffValue(old[key], value)
			if d ~= nil then
				patch[key] = d
				changed = true
			end
		end
		for key in old do
			if new[key] == nil then
				patch[key] = StatePatch.NIL
				changed = true
			end
		end
	end
	return if changed then patch else nil
end

-- Parche para pasar de old a new (nil = no ha cambiado nada)
function diffValue(old: any, new: any): any
	if type(new) == "table" then
		if type(old) == "table" then
			return diffTable(old, new)
		end
		return new
	end
	if old == new then
		return nil
	end
	return new
end

function StatePatch.diff(old: any, new: any): any
	return diffValue(old, new)
end

-- 3 cifras significativas (lo que se ve en pantalla: 1.25K). Para valores
-- que cambian un poco cada segundo: así solo se reenvían cuando cambia lo que
-- se ve.
function StatePatch.sig3(x: number): number
	if x == 0 or x ~= x or x == math.huge or x == -math.huge then
		return if x == x then x else 0
	end
	local scale = 10 ^ (math.floor(math.log10(math.abs(x))) - 2)
	return math.floor(x / scale + 0.5) * scale
end

-- Temporizador en segundos enteros; si queda más de una hora, al minuto
-- (Config.formatTime ya no enseña los segundos): así no cambia cada segundo
function StatePatch.timer(seconds: number): number
	seconds = math.max(0, math.floor(seconds))
	return if seconds >= 3600 then seconds - seconds % 60 else seconds
end

-- Copia profunda (el servidor guarda una copia de lo enviado: el estado
-- apunta a tablas vivas de la partida que cambian solas)
function StatePatch.copy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value :: any do
		out[key] = StatePatch.copy(item)
	end
	return out :: any
end

local function isPatch(value: any): boolean
	return type(value) == "table" and (value.__p == true or type(value.__a) == "number")
end

-- Aplica un parche sobre "target" (lo modifica) y devuelve el resultado
function StatePatch.apply(target: any, patch: any): any
	if not isPatch(patch) then
		return patch
	end
	if type(target) ~= "table" then
		target = {}
	end
	if patch.__a then
		for key, value in patch do
			local index = tonumber(key)
			if index then
				target[index] = StatePatch.apply(target[index], value)
			end
		end
		for i = #target, patch.__a + 1, -1 do
			target[i] = nil
		end
	else
		for key, value in patch do
			if key ~= "__p" then
				if value == StatePatch.NIL then
					target[key] = nil
				else
					target[key] = StatePatch.apply(target[key], value)
				end
			end
		end
	end
	return target
end

return StatePatch
