--!strict
-- Dónde está cada libro, codificado en 8 caracteres (guardado compacto y foto inicial al cliente).
--   [tipo][a][b][c][d][e][f][g]
--   tipo "0" = en su sitio inicial · "1" = en un hueco (a b = nº de hueco)
--        "2" = suelto (a b = x, c d = y, e f = z con precisión 0,1 studs; g = giro en 64 pasos)
--        "3" = en la mano (el orden de la pila se guarda aparte)
-- 3.072 libros × 8 = 24.576 caracteres por ranura (el límite de DataStore es 4 MB).

local Codec = {}

local ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local VALUE: { [string]: number } = {}
local CHAR: { [number]: string } = {}
for i = 1, 64 do
	local c = string.sub(ALPHABET, i, i)
	VALUE[c] = i - 1
	CHAR[i - 1] = c
end

Codec.SIZE = 8
Codec.STEP = 0.1
Codec.YAW_STEPS = 64
-- Rangos (studs): x [-204,8 … 204,7] · y [-50 … 359,5] · z [-300 … 109,5]
local OFFSET_X, OFFSET_Y, OFFSET_Z = 2048, 500, 3000

export type Loc = { k: number, s: number?, p: Vector3?, yaw: number? }

local function two(n: number): string
	n = math.clamp(math.floor(n), 0, 4095)
	return CHAR[n // 64] .. CHAR[n % 64]
end

local function readTwo(str: string, i: number): number
	return (VALUE[string.sub(str, i, i)] or 0) * 64 + (VALUE[string.sub(str, i + 1, i + 1)] or 0)
end

-- Redondea a lo que se puede guardar (servidor y cliente tienen así EXACTAMENTE la misma posición)
function Codec.qn(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

function Codec.quantize(p: Vector3, yaw: number): (Vector3, number)
	local step = 2 * math.pi / Codec.YAW_STEPS
	local i = math.floor(yaw / step + 0.5) % Codec.YAW_STEPS
	return Vector3.new(Codec.qn(p.X), Codec.qn(p.Y), Codec.qn(p.Z)), i * step
end

function Codec.encode(loc: Loc): string
	if loc.k == 1 then
		return "1" .. two(loc.s :: number) .. "00000"
	elseif loc.k == 2 then
		local p = loc.p :: Vector3
		local step = 2 * math.pi / Codec.YAW_STEPS
		local yi = math.floor((loc.yaw or 0) / step + 0.5) % Codec.YAW_STEPS
		return "2"
			.. two(math.floor(p.X * 10 + 0.5) + OFFSET_X)
			.. two(math.floor(p.Y * 10 + 0.5) + OFFSET_Y)
			.. two(math.floor(p.Z * 10 + 0.5) + OFFSET_Z)
			.. CHAR[yi]
	elseif loc.k == 3 then
		return "30000000"
	end
	return "00000000"
end

function Codec.decode(str: string, i: number?): Loc
	local o = i or 1
	local kind = string.sub(str, o, o)
	if kind == "1" then
		return { k = 1, s = readTwo(str, o + 1) }
	elseif kind == "2" then
		local x = (readTwo(str, o + 1) - OFFSET_X) / 10
		local y = (readTwo(str, o + 3) - OFFSET_Y) / 10
		local z = (readTwo(str, o + 5) - OFFSET_Z) / 10
		local yaw = (VALUE[string.sub(str, o + 7, o + 7)] or 0) * 2 * math.pi / Codec.YAW_STEPS
		return { k = 2, p = Vector3.new(x, y, z), yaw = yaw }
	elseif kind == "3" then
		return { k = 3 }
	end
	return { k = 0 }
end

function Codec.encodeAll(locs: { Loc }): string
	local parts = table.create(#locs)
	for i, loc in locs do
		parts[i] = Codec.encode(loc)
	end
	return table.concat(parts)
end

-- Devuelve nil si la cadena no tiene la longitud esperada (partida corrupta o de otra versión)
function Codec.decodeAll(str: string, count: number): { Loc }?
	if type(str) ~= "string" or #str ~= count * Codec.SIZE then
		return nil
	end
	local out = table.create(count)
	for b = 1, count do
		out[b] = Codec.decode(str, (b - 1) * Codec.SIZE + 1)
	end
	return out
end

return Codec
