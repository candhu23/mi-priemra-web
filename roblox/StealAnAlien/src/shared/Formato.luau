--!strict
-- Formato de números y tiempos para mostrarlos en pantalla.

local Formato = {}

local SUFIJOS = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.2K", 2500000 -> "2.5M"
function Formato.abreviar(n: number): string
	if n ~= n then
		return "0"
	end
	local negativo = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFIJOS do
		n /= 1000
		i += 1
	end
	local texto
	if i == 1 then
		texto = tostring(math.floor(n))
	elseif n >= 100 then
		texto = string.format("%d%s", math.floor(n), SUFIJOS[i])
	else
		-- Truncamos (no redondeamos) para no mostrar nunca más dinero del que hay.
		texto = string.format("%.1f%s", math.floor(n * 10) / 10, SUFIJOS[i])
	end
	return if negativo then "-" .. texto else texto
end

-- 75 -> "1:15"
function Formato.tiempo(segundos: number): string
	segundos = math.max(0, math.ceil(segundos))
	local minutos = segundos // 60
	if minutos >= 60 then
		return string.format("%d:%02d:%02d", minutos // 60, minutos % 60, segundos % 60)
	end
	return string.format("%d:%02d", minutos, segundos % 60)
end

-- 0.012345 -> "1.23%" ; usa decimales suficientes para que no salga 0 %.
function Formato.porcentaje(probabilidad: number): string
	local p = probabilidad * 100
	if p >= 10 then
		return string.format("%.1f%%", p)
	elseif p >= 1 then
		return string.format("%.2f%%", p)
	elseif p >= 0.1 then
		return string.format("%.3f%%", p)
	end
	return string.format("%.4f%%", p)
end

return Formato
