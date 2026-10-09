--[[
	Validate (ModuleScript en ReplicatedStorage)

	Comprobaciones de lo que manda el cliente. Un exploiter puede mandar
	cualquier cosa (NaN, infinito, textos enormes, tablas...): toda acción
	del servidor que reciba números o textos debe pasar por aquí.
]]

local Validate = {}

-- Número de verdad: no NaN, no infinito y dentro de [min, max] si se dan
function Validate.number(x: any, min: number?, max: number?): boolean
	if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then
		return false
	end
	if min and x < min then
		return false
	end
	if max and x > max then
		return false
	end
	return true
end

-- Número entero (índices, niveles, ids)
function Validate.integer(x: any, min: number?, max: number?): boolean
	return Validate.number(x, min, max) and x % 1 == 0
end

-- Texto corto
function Validate.text(x: any, maxLength: number?): boolean
	return type(x) == "string" and #x <= (maxLength or 100)
end

-- Ningún argumento numérico raro (se usa antes de cualquier acción)
function Validate.args(...: any): boolean
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "number" and not Validate.number(v) then
			return false
		end
		if type(v) == "string" and #v > 200 then
			return false
		end
	end
	return true
end

return Validate
