--!strict
--[[
	CONFIGURACIÓN DE STEAL AN ALIEN
	===============================
	Este es el único archivo que necesitas tocar para equilibrar el juego,
	añadir aliens o poner los IDs de monetización. Lo usan el servidor y el cliente.

	Los colores van como {R, G, B} (0-255) para que el módulo no dependa de Roblox
	y se pueda probar fuera de Studio.
]]

export type RGB = { number }

export type Rareza = {
	id: string,
	nombre: string,
	color: RGB,
	peso: number, -- probabilidad relativa de salir en la cinta
	afectadaPorSuerte: boolean,
}

export type Estilo = {
	cuerpo: string, -- "bola" | "capsula" | "cubo"
	ojos: number,
	extras: { string }, -- "antenas" | "tentaculos" | "alas" | "corona" | "cuernos" | "aleta" | "pinzas" | "halo" | "orejas"
}

export type Alien = {
	id: string,
	nombre: string,
	rareza: number, -- índice en RAREZAS
	precio: number,
	ingreso: number, -- dinero por segundo
	color: RGB,
	tamano: number,
	estilo: Estilo,
}

export type ArticuloTienda = {
	clave: string,
	tipo: string, -- "pase" | "producto"
	id: number, -- 0 = todavía no creado (se muestra "Coming soon")
	precioSugerido: number, -- solo orientativo, el precio real se pone en el Creator Hub
	titulo: string,
	descripcion: string,
}

local Config = {}

Config.VERSION = "1.0.0"

---------------------------------------------------------------------
-- RITMO DEL JUEGO
---------------------------------------------------------------------
Config.JUEGO = {
	DINERO_INICIAL = 100,
	SEGUNDOS_ENTRE_ALIENS = 2,
	SEGUNDOS_EN_CINTA = 30,
	SLOTS_INICIALES = 10,
	SLOTS_MAXIMOS = 15, -- cada rebirth desbloquea un pedestal más
	SEGUNDOS_CANDADO = 60,
	SEGUNDOS_CANDADO_VIP = 90,
	VELOCIDAD_BASE = 16,
	VELOCIDAD_POR_NIVEL = 2,
	VELOCIDAD_VIP = 4,
	NIVEL_VELOCIDAD_MAX = 8,
	FACTOR_VELOCIDAD_CARGANDO = 0.75,
	ALCANCE_GOLPE = 9,
	ENFRIAMIENTO_GOLPE = 0.8,
	FACTOR_VENTA = 0.5, -- vender devuelve la mitad del precio
	BONUS_POR_REBIRTH = 0.5, -- +50 % de ingresos por rebirth
	BONUS_POR_AMIGO = 0.1, -- +10 % por cada amigo en el servidor...
	BONUS_AMIGOS_MAX = 0.5, -- ...hasta +50 %
	BONUS_GRUPO = 0.1, -- +10 % si estás en el grupo de Roblox del juego
	OFFLINE_FRACCION = 0.25, -- mientras no juegas generas el 25 %...
	OFFLINE_HORAS_MAX = 3, -- ...durante un máximo de 3 horas
	BOOST_X2_MINUTOS = 15,
}

-- Posición de la cinta (la usan el servidor y el cliente para mover los aliens igual).
Config.CINTA = {
	X_INICIO = -98,
	X_FIN = 98,
	ALTURA = 1.5,
}

Config.EVENTOS = {
	SUERTE_CADA = 600, -- evento gratuito "Lucky Belt" cada 10 min
	SUERTE_DURA = 60,
	SUERTE_PAGADA_DURA = 180,
	MULTIPLICADOR_SUERTE = 4,
	METEORITOS_CADA = 900, -- "Meteor Shower" cada 15 min
	METEORITOS_PRIMERO = 300, -- el primero a los 5 min de abrir el servidor
	METEORITOS_DURA = 45,
	METEORITOS_CANTIDAD = 25,
	METEORITO_SEGUNDOS_INGRESO = 20, -- cada cristal da 20 s de tus ingresos (mínimo 150)
	METEORITO_MINIMO = 150,
}

Config.SHINY = {
	PROBABILIDAD = 0.04, -- 4 % de los aliens de la cinta salen brillantes (no lo cambia la suerte)
	MULTIPLICADOR_INGRESO = 3,
	MULTIPLICADOR_PRECIO = 2.5,
}

---------------------------------------------------------------------
-- RAREZAS Y ALIENS
---------------------------------------------------------------------
Config.RAREZAS = {
	{ id = "common", nombre = "Common", color = { 200, 200, 210 }, peso = 60, afectadaPorSuerte = false },
	{ id = "rare", nombre = "Rare", color = { 70, 160, 255 }, peso = 25, afectadaPorSuerte = false },
	{ id = "epic", nombre = "Epic", color = { 180, 80, 255 }, peso = 10, afectadaPorSuerte = true },
	{ id = "legendary", nombre = "Legendary", color = { 255, 190, 30 }, peso = 4, afectadaPorSuerte = true },
	{ id = "mythic", nombre = "Mythic", color = { 255, 60, 90 }, peso = 0.9, afectadaPorSuerte = true },
	{ id = "secret", nombre = "Secret", color = { 40, 255, 220 }, peso = 0.1, afectadaPorSuerte = true },
} :: { Rareza }

-- Añadir un alien = añadir una línea. El "id" no debe cambiar nunca una vez publicado
-- (es lo que se guarda en los datos de los jugadores).
Config.ALIENS = {
	{ id = "blorp", nombre = "Blorp", rareza = 1, precio = 25, ingreso = 1, color = { 120, 230, 120 }, tamano = 2.4, estilo = { cuerpo = "bola", ojos = 2, extras = { "antenas" } } },
	{ id = "zib", nombre = "Zib Zib", rareza = 1, precio = 90, ingreso = 3, color = { 120, 220, 255 }, tamano = 2.6, estilo = { cuerpo = "capsula", ojos = 1, extras = { "antenas" } } },
	{ id = "squishy", nombre = "Squishy", rareza = 1, precio = 220, ingreso = 6, color = { 255, 170, 220 }, tamano = 2.8, estilo = { cuerpo = "bola", ojos = 2, extras = { "orejas" } } },
	{ id = "moonmoo", nombre = "Moonmoo", rareza = 2, precio = 500, ingreso = 11, color = { 240, 240, 200 }, tamano = 3, estilo = { cuerpo = "bola", ojos = 2, extras = { "cuernos" } } },
	{ id = "glarbo", nombre = "Glarbo", rareza = 2, precio = 1200, ingreso = 24, color = { 255, 150, 60 }, tamano = 3.2, estilo = { cuerpo = "cubo", ojos = 3, extras = { "antenas" } } },
	{ id = "wobbletron", nombre = "Wobbletron", rareza = 2, precio = 2600, ingreso = 46, color = { 150, 160, 180 }, tamano = 3.3, estilo = { cuerpo = "cubo", ojos = 1, extras = { "antenas", "pinzas" } } },
	{ id = "nebulacat", nombre = "Nebula Cat", rareza = 3, precio = 8000, ingreso = 115, color = { 170, 100, 255 }, tamano = 3.5, estilo = { cuerpo = "bola", ojos = 2, extras = { "orejas", "halo" } } },
	{ id = "tentacle", nombre = "Sir Tentacle", rareza = 3, precio = 20000, ingreso = 250, color = { 255, 100, 180 }, tamano = 3.8, estilo = { cuerpo = "capsula", ojos = 3, extras = { "tentaculos", "corona" } } },
	{ id = "crystalcrab", nombre = "Crystal Crab", rareza = 3, precio = 45000, ingreso = 480, color = { 120, 255, 255 }, tamano = 3.8, estilo = { cuerpo = "cubo", ojos = 2, extras = { "pinzas", "cuernos" } } },
	{ id = "cosmowhale", nombre = "Cosmo Whale", rareza = 4, precio = 150000, ingreso = 1300, color = { 60, 120, 255 }, tamano = 4.5, estilo = { cuerpo = "capsula", ojos = 2, extras = { "aleta", "halo" } } },
	{ id = "ufoking", nombre = "UFO Overlord", rareza = 4, precio = 400000, ingreso = 3200, color = { 180, 255, 80 }, tamano = 4.6, estilo = { cuerpo = "bola", ojos = 1, extras = { "halo", "antenas", "corona" } } },
	{ id = "astroaxolotl", nombre = "Astro Axolotl", rareza = 4, precio = 900000, ingreso = 6500, color = { 255, 140, 200 }, tamano = 4.6, estilo = { cuerpo = "capsula", ojos = 2, extras = { "tentaculos", "aleta" } } },
	{ id = "galaxydragon", nombre = "Galaxy Dragon", rareza = 5, precio = 2500000, ingreso = 16000, color = { 255, 50, 80 }, tamano = 5.2, estilo = { cuerpo = "capsula", ojos = 2, extras = { "alas", "cuernos" } } },
	{ id = "quasarqueen", nombre = "Quasar Queen", rareza = 5, precio = 6000000, ingreso = 35000, color = { 255, 230, 120 }, tamano = 5.2, estilo = { cuerpo = "bola", ojos = 3, extras = { "alas", "corona" } } },
	{ id = "voidking", nombre = "Void King", rareza = 6, precio = 20000000, ingreso = 110000, color = { 40, 0, 70 }, tamano = 6, estilo = { cuerpo = "bola", ojos = 3, extras = { "corona", "cuernos", "halo" } } },
	{ id = "glitch", nombre = "GLITCH", rareza = 6, precio = 75000000, ingreso = 350000, color = { 0, 255, 120 }, tamano = 6, estilo = { cuerpo = "cubo", ojos = 3, extras = { "antenas", "alas", "halo" } } },
} :: { Alien }

---------------------------------------------------------------------
-- MONETIZACIÓN
-- 1. Crea los pases y productos en el Creator Hub (ver GUIA_LANZAMIENTO.md).
-- 2. Copia aquí cada ID. Con id = 0 el botón sale como "Coming soon".
---------------------------------------------------------------------
Config.TIENDA = {
	{ clave = "PASE_DOBLE_DINERO", tipo = "pase", id = 0, precioSugerido = 199, titulo = "💰 2x Cash", descripcion = "Double income forever" },
	{ clave = "PASE_VIP", tipo = "pase", id = 0, precioSugerido = 399, titulo = "👑 VIP", descripcion = "+50% income, +4 speed, 90s lock, VIP tag" },
	{ clave = "PASE_CANDADO_PLUS", tipo = "pase", id = 0, precioSugerido = 149, titulo = "🛡️ Super Lock", descripcion = "Your base lock lasts twice as long" },
	{ clave = "PRODUCTO_BOOST_X2", tipo = "producto", id = 0, precioSugerido = 39, titulo = "⚡ 2x Boost", descripcion = "Double income for 15 minutes" },
	{ clave = "PRODUCTO_SUERTE_SERVIDOR", tipo = "producto", id = 0, precioSugerido = 99, titulo = "🍀 Server Luck", descripcion = "Rare aliens x4 for EVERYONE (3 min). Tap ODDS for details" },
	{ clave = "PRODUCTO_DINERO_PEQUENO", tipo = "producto", id = 0, precioSugerido = 49, titulo = "💵 Cash Pack", descripcion = "10 minutes of your income" },
	{ clave = "PRODUCTO_DINERO_GRANDE", tipo = "producto", id = 0, precioSugerido = 199, titulo = "💎 Mega Cash", descripcion = "1 hour of your income" },
} :: { ArticuloTienda }

Config.VIP_BONUS_INGRESO = 0.5

-- Anuncio de vídeo con recompensa: ID del Developer Product que se entrega al verlo
-- (normalmente el mismo que PRODUCTO_BOOST_X2). 0 = desactivado.
Config.ANUNCIO_RECOMPENSA_PRODUCTO = 0

-- ID del grupo de Roblox del juego (da +10 % de ingresos a sus miembros). 0 = desactivado.
Config.GRUPO_ID = 0

-- Sonidos (IDs de audio del Creator Store). 0 = sin sonido.
Config.SONIDOS = {
	MUSICA = 0,
	COMPRAR = 0,
	COBRAR = 0,
	ROBAR = 0,
	GOLPE = 0,
	EVENTO = 0,
	ALARMA = 0,
}

---------------------------------------------------------------------
-- FÓRMULAS DE ECONOMÍA (las usan el servidor y la interfaz)
---------------------------------------------------------------------
function Config.costeVelocidad(nivel: number): number
	return math.floor(300 * 3 ^ nivel)
end

function Config.costeRebirth(rebirths: number): number
	return math.floor(1000000 * 4 ^ rebirths)
end

function Config.slotsDesbloqueados(rebirths: number): number
	return math.min(Config.JUEGO.SLOTS_INICIALES + rebirths, Config.JUEGO.SLOTS_MAXIMOS)
end

function Config.ingresoAlien(alien: Alien, shiny: boolean?): number
	return alien.ingreso * (if shiny then Config.SHINY.MULTIPLICADOR_INGRESO else 1)
end

function Config.precioAlien(alien: Alien, shiny: boolean?): number
	return math.floor(alien.precio * (if shiny then Config.SHINY.MULTIPLICADOR_PRECIO else 1))
end

function Config.precioVenta(alien: Alien, shiny: boolean?): number
	return math.floor(Config.precioAlien(alien, shiny) * Config.JUEGO.FACTOR_VENTA)
end

export type Bonos = {
	rebirths: number,
	dobleDinero: boolean,
	vip: boolean,
	amigos: number,
	grupo: boolean,
	boost: boolean,
}

-- Los bonos aditivos se suman y los pases 2x/boost multiplican.
function Config.multiplicadorIngresos(b: Bonos): number
	local aditivo = 1 + b.rebirths * Config.JUEGO.BONUS_POR_REBIRTH
	aditivo += math.min(b.amigos * Config.JUEGO.BONUS_POR_AMIGO, Config.JUEGO.BONUS_AMIGOS_MAX)
	if b.grupo then
		aditivo += Config.JUEGO.BONUS_GRUPO
	end
	if b.vip then
		aditivo += Config.VIP_BONUS_INGRESO
	end
	local m = aditivo
	if b.dobleDinero then
		m *= 2
	end
	if b.boost then
		m *= 2
	end
	return m
end

-- Recompensa diaria: crece con la racha (día 1 a 7) y con tus ingresos.
function Config.recompensaDiaria(racha: number, ingresoPorSegundo: number): number
	local dia = math.clamp(racha, 1, 7)
	return math.floor(math.max(500 * dia, ingresoPorSegundo * 120 * dia))
end

function Config.gananciaOffline(segundosFuera: number, ingresoPorSegundo: number): number
	local segundos = math.clamp(segundosFuera, 0, Config.JUEGO.OFFLINE_HORAS_MAX * 3600)
	return math.floor(segundos * ingresoPorSegundo * Config.JUEGO.OFFLINE_FRACCION)
end

function Config.alienPorId(id: string): Alien?
	for _, alien in Config.ALIENS do
		if alien.id == id then
			return alien
		end
	end
	return nil
end

function Config.articuloPorClave(clave: string): ArticuloTienda?
	for _, articulo in Config.TIENDA do
		if articulo.clave == clave then
			return articulo
		end
	end
	return nil
end

return Config
