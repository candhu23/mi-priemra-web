--!strict
--[[
	Estructura de los datos guardados de cada jugador y su limpieza.
	Es un módulo "puro" (no usa servicios de Roblox) para poder probarlo fuera de Studio.

	Si en el futuro añades un campo nuevo, añádelo en Perfil.nuevo: los jugadores
	antiguos lo recibirán automáticamente con su valor por defecto.
]]

export type AlienGuardado = { s: number, id: string, sh: boolean? }

export type Datos = {
	version: number,
	dinero: number,
	pendiente: number,
	rebirths: number,
	velocidad: number,
	aliens: { AlienGuardado },
	indice: { [string]: number }, -- 1 = descubierto, 2 = descubierto también en versión shiny
	compras: { string }, -- últimos PurchaseId procesados (evita entregar dos veces)
	codigos: { [string]: boolean },
	diario: { dia: number, racha: number },
	ultimaConexion: number,
	boostHasta: number,
	tutorialHecho: boolean,
	stats: { robos: number, ganadoTotal: number },
}

local Perfil = {}

Perfil.VERSION = 1
Perfil.MAX_COMPRAS = 50

function Perfil.nuevo(dineroInicial: number): Datos
	return {
		version = Perfil.VERSION,
		dinero = dineroInicial,
		pendiente = 0,
		rebirths = 0,
		velocidad = 0,
		aliens = {},
		indice = {},
		compras = {},
		codigos = {},
		diario = { dia = 0, racha = 0 },
		ultimaConexion = 0,
		boostHasta = 0,
		tutorialHecho = false,
		stats = { robos = 0, ganadoTotal = 0 },
	}
end

local function numero(valor: any, defecto: number, minimo: number?, maximo: number?): number
	if type(valor) ~= "number" or valor ~= valor or valor == math.huge or valor == -math.huge then
		return defecto
	end
	if minimo and valor < minimo then
		return minimo
	end
	if maximo and valor > maximo then
		return maximo
	end
	return valor
end

local function entero(valor: any, defecto: number, minimo: number?, maximo: number?): number
	return math.floor(numero(valor, defecto, minimo, maximo))
end

-- Convierte cualquier cosa guardada (datos viejos, corruptos o nil) en datos válidos.
-- esAlienValido: función que dice si un id de alien existe en Config.
function Perfil.reconciliar(guardado: any, dineroInicial: number, maxSlots: number, esAlienValido: (string) -> boolean): Datos
	local datos = Perfil.nuevo(dineroInicial)
	if type(guardado) ~= "table" then
		return datos
	end

	datos.dinero = numero(guardado.dinero, dineroInicial, 0)
	datos.pendiente = numero(guardado.pendiente, 0, 0)
	datos.rebirths = entero(guardado.rebirths, 0, 0)
	datos.velocidad = entero(guardado.velocidad, 0, 0, 100)
	datos.ultimaConexion = entero(guardado.ultimaConexion, 0, 0)
	datos.boostHasta = entero(guardado.boostHasta, 0, 0)
	datos.tutorialHecho = guardado.tutorialHecho == true

	if type(guardado.aliens) == "table" then
		local ocupados: { [number]: boolean } = {}
		for _, a in guardado.aliens do
			if type(a) == "table" and type(a.id) == "string" and esAlienValido(a.id) then
				local s = entero(a.s, 0)
				if s >= 1 and s <= maxSlots and not ocupados[s] then
					ocupados[s] = true
					table.insert(datos.aliens, { s = s, id = a.id, sh = if a.sh == true then true else nil })
				end
			end
		end
	end

	if type(guardado.indice) == "table" then
		for id, valor in guardado.indice do
			if type(id) == "string" and esAlienValido(id) then
				datos.indice[id] = if valor == 2 then 2 else 1
			end
		end
	end

	if type(guardado.compras) == "table" then
		for _, idCompra in guardado.compras do
			if type(idCompra) == "string" then
				table.insert(datos.compras, idCompra)
			end
		end
		while #datos.compras > Perfil.MAX_COMPRAS do
			table.remove(datos.compras, 1)
		end
	end

	if type(guardado.codigos) == "table" then
		for codigo, usado in guardado.codigos do
			if type(codigo) == "string" and usado == true then
				datos.codigos[codigo] = true
			end
		end
	end

	if type(guardado.diario) == "table" then
		datos.diario.dia = entero(guardado.diario.dia, 0, 0)
		datos.diario.racha = entero(guardado.diario.racha, 0, 0)
	end

	if type(guardado.stats) == "table" then
		datos.stats.robos = entero(guardado.stats.robos, 0, 0)
		datos.stats.ganadoTotal = numero(guardado.stats.ganadoTotal, 0, 0)
	end

	return datos
end

-- Racha de días seguidos. hoy = número de día (os.time() // 86400).
-- Devuelve la nueva racha, o nil si hoy ya se cobró.
function Perfil.siguienteRacha(diario: { dia: number, racha: number }, hoy: number): number?
	if diario.dia == hoy then
		return nil
	end
	if diario.dia == hoy - 1 then
		return diario.racha + 1
	end
	return 1
end

-- Marca un PurchaseId como procesado. Devuelve false si ya lo estaba.
function Perfil.registrarCompra(datos: Datos, idCompra: string): boolean
	for _, id in datos.compras do
		if id == idCompra then
			return false
		end
	end
	table.insert(datos.compras, idCompra)
	while #datos.compras > Perfil.MAX_COMPRAS do
		table.remove(datos.compras, 1)
	end
	return true
end

function Perfil.yaComprado(datos: Datos, idCompra: string): boolean
	return table.find(datos.compras, idCompra) ~= nil
end

return Perfil
