--!strict
--[[
	Probabilidades de la cinta. La misma función la usan:
	  - el servidor, para elegir qué alien aparece;
	  - la interfaz, para enseñar las probabilidades exactas (obligatorio en Roblox
	    cuando se vende algo que cambia probabilidades, como "Server Luck").
]]

local Probabilidades = {}

-- Se aceptan las tablas de Config tal cual (con más campos), por eso el tipo es abierto.
-- Campos usados: rareza.peso, rareza.afectadaPorSuerte, alien.id, alien.rareza.
type Rareza = any
type Alien = any

export type Entrada = { id: string, rareza: number, probabilidad: number }

-- Devuelve la probabilidad (0-1) de cada rareza.
function Probabilidades.porRareza(rarezas: { Rareza }, suerte: boolean, multiplicadorSuerte: number): { number }
	local pesos = {}
	local total = 0
	for i, rareza in rarezas do
		local peso = rareza.peso
		if suerte and rareza.afectadaPorSuerte then
			peso *= multiplicadorSuerte
		end
		pesos[i] = peso
		total += peso
	end
	for i in pesos do
		pesos[i] /= total
	end
	return pesos
end

-- Probabilidad final de cada alien: la de su rareza repartida a partes iguales
-- entre los aliens de esa rareza. Las probabilidades suman exactamente 1.
function Probabilidades.porAlien(rarezas: { Rareza }, aliens: { Alien }, suerte: boolean, multiplicadorSuerte: number): { Entrada }
	local porRareza = Probabilidades.porRareza(rarezas, suerte, multiplicadorSuerte)
	local cuantos: { [number]: number } = {}
	for _, alien in aliens do
		cuantos[alien.rareza] = (cuantos[alien.rareza] or 0) + 1
	end
	-- Si una rareza no tiene aliens, su probabilidad se reparte entre las demás.
	local totalValido = 0
	for i, p in porRareza do
		if cuantos[i] then
			totalValido += p
		end
	end
	local resultado: { Entrada } = {}
	for _, alien in aliens do
		local p = porRareza[alien.rareza] / totalValido / cuantos[alien.rareza]
		table.insert(resultado, { id = alien.id, rareza = alien.rareza, probabilidad = p })
	end
	return resultado
end

-- Elige un alien con un número aleatorio "tirada" en [0, 1).
function Probabilidades.elegir(rarezas: { Rareza }, aliens: { Alien }, suerte: boolean, multiplicadorSuerte: number, tirada: number): string
	local tabla = Probabilidades.porAlien(rarezas, aliens, suerte, multiplicadorSuerte)
	local acumulado = 0
	for _, entrada in tabla do
		acumulado += entrada.probabilidad
		if tirada < acumulado then
			return entrada.id
		end
	end
	return tabla[#tabla].id -- por si el redondeo deja la suma en 0.99999
end

return Probabilidades
