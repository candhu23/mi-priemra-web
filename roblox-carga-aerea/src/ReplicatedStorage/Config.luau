--!strict
-- Configuración de «AeroCarga España» (EN: Spain Air Cargo Tycoon).
-- TODOS los datos y fórmulas de equilibrio. Servidor y cliente leen este módulo;
-- los textos están en Lang.luau y el mapa en MapData.luau.

local Config = {}

Config.VERSION = "0.3"
Config.TIME_SCALE = 120 -- 1 segundo real = 2 minutos de vuelo
Config.START_MONEY = 20000
Config.RATE = 8 -- $ por tonelada·km
Config.FUEL_PRICE = 2 -- $ por litro (base; varía ±25 %)
Config.PILOT_FEE = 0.1 -- los pilotos contratados cobran el 10 % de cada vuelo
Config.AUTO_DISPATCH_LEVEL = 5
Config.BOARD_SIZE = 7 -- cargas por aeropuerto
Config.BOARD_TTL = 90 -- segundos hasta renovar un tablón
Config.REFRESH_COOLDOWN = 20
Config.MAX_PILOTS = 25
Config.REPAIR_BLOCK = 25 -- con menos estado (%) el avión no vuela
Config.OFFLINE_MAX_HOURS = 8
Config.OFFLINE_RATE = 0.5 -- 50 % de lo que gana tu flota con despacho automático (100 % con el pase)
Config.GROUP_ID = 0 -- grupo de Roblox para el +10 % (0 = desactivado)
Config.START_HUB = "MAD"

-- No hay imágenes que subir: mapa, aviones e iconos (emojis) se dibujan con código.

---------------------------------------------------------------------
-- Paleta: soleada y mediterránea (claro), muy distinta de un tema oscuro
---------------------------------------------------------------------
Config.Colors = {
	sea = Color3.fromRGB(126, 200, 240),
	seaDeep = Color3.fromRGB(96, 178, 228),
	foreign = Color3.fromRGB(240, 236, 226),
	locked = Color3.fromRGB(205, 198, 182),
	panel = Color3.fromRGB(255, 255, 255),
	soft = Color3.fromRGB(242, 246, 252), -- fondo de tarjetas dentro de paneles
	line = Color3.fromRGB(222, 229, 240),
	ink = Color3.fromRGB(31, 42, 68), -- texto principal
	muted = Color3.fromRGB(110, 122, 145),
	orange = Color3.fromRGB(255, 107, 53), -- acción principal
	orangeDark = Color3.fromRGB(214, 78, 30),
	blue = Color3.fromRGB(45, 127, 249),
	blueDark = Color3.fromRGB(28, 93, 200),
	green = Color3.fromRGB(34, 177, 92),
	greenDark = Color3.fromRGB(22, 133, 66),
	gold = Color3.fromRGB(255, 196, 46),
	goldDark = Color3.fromRGB(214, 152, 10),
	red = Color3.fromRGB(235, 68, 68),
	purple = Color3.fromRGB(139, 92, 246),
	white = Color3.fromRGB(255, 255, 255),
	grey = Color3.fromRGB(196, 203, 215),
	greyDark = Color3.fromRGB(150, 158, 174),
}

---------------------------------------------------------------------
-- Regiones (orden = MapData.regions). Se pintan en el mapa al desbloquearlas.
---------------------------------------------------------------------
export type Region = { id: string, level: number, cost: number, color: Color3 }
Config.Regions = {
	{ id = "CEN", level = 1, cost = 0, color = Color3.fromRGB(255, 186, 73) },
	{ id = "LEV", level = 1, cost = 0, color = Color3.fromRGB(255, 132, 102) },
	{ id = "CAT", level = 3, cost = 40_000, color = Color3.fromRGB(252, 211, 77) },
	{ id = "AND", level = 4, cost = 90_000, color = Color3.fromRGB(132, 204, 22) },
	{ id = "NOR", level = 6, cost = 300_000, color = Color3.fromRGB(56, 189, 248) },
	{ id = "CYL", level = 7, cost = 600_000, color = Color3.fromRGB(192, 132, 252) },
	{ id = "GAL", level = 9, cost = 1_500_000, color = Color3.fromRGB(45, 212, 191) },
	{ id = "BAL", level = 11, cost = 3_500_000, color = Color3.fromRGB(244, 114, 182) },
	{ id = "CAN", level = 13, cost = 8_000_000, color = Color3.fromRGB(250, 204, 21) },
} :: { Region }
Config.RegionById = {} :: { [string]: Region }
Config.RegionIndex = {} :: { [string]: number }
for i, r in Config.Regions do
	Config.RegionById[r.id] = r
	Config.RegionIndex[r.id] = i
end

---------------------------------------------------------------------
-- Productos (lo que se transporta). cold = necesita la cámara frigorífica
---------------------------------------------------------------------
export type Good = { id: string, emoji: string, mult: number, cold: boolean? }
Config.Goods = {
	{ id = "parcel", emoji = "📦", mult = 1 },
	{ id = "mail", emoji = "📰", mult = 1.1 },
	{ id = "oranges", emoji = "🍊", mult = 1.2 },
	{ id = "veggies", emoji = "🥬", mult = 1.2 },
	{ id = "tiles", emoji = "🧱", mult = 1.15 },
	{ id = "oil", emoji = "🫒", mult = 1.3 },
	{ id = "wine", emoji = "🍷", mult = 1.3 },
	{ id = "cheese", emoji = "🧀", mult = 1.3 },
	{ id = "nougat", emoji = "🍬", mult = 1.3 },
	{ id = "steel", emoji = "🔩", mult = 1.25 },
	{ id = "bananas", emoji = "🍌", mult = 1.35 },
	{ id = "ham", emoji = "🍖", mult = 1.4 },
	{ id = "fashion", emoji = "👗", mult = 1.4 },
	{ id = "cars", emoji = "🚗", mult = 1.5 },
	{ id = "tech", emoji = "💻", mult = 1.5 },
	{ id = "fish", emoji = "🐟", mult = 1.6, cold = true },
	{ id = "medicine", emoji = "💊", mult = 1.8, cold = true },
} :: { Good }
Config.GoodById = {} :: { [string]: Good }
for _, g in Config.Goods do
	Config.GoodById[g.id] = g
end

---------------------------------------------------------------------
-- Aeropuertos (ciudades reales; códigos IATA). goods = productos típicos de la zona
-- label = lado de la etiqueta en el mapa ("left", "right", "top", "none"; por defecto debajo)
---------------------------------------------------------------------
export type Airport = {
	code: string, city: string, lat: number, lon: number, region: string, goods: { string }, label: string?,
}
Config.Airports = {
	{ code = "MAD", city = "Madrid", lat = 40.47, lon = -3.56, region = "CEN", goods = { "medicine", "tech", "fashion" } },
	{ code = "CQM", city = "Ciudad Real", lat = 38.86, lon = -3.97, region = "CEN", goods = { "cheese", "wine" } },
	{ code = "ABC", city = "Albacete", lat = 38.95, lon = -1.86, region = "CEN", goods = { "cheese", "steel" }, label = "right" },
	{ code = "VLC", city = "Valencia", lat = 39.49, lon = -0.48, region = "LEV", goods = { "oranges", "tiles" }, label = "right" },
	{ code = "CDT", city = "Castellón", lat = 40.21, lon = 0.07, region = "LEV", goods = { "tiles", "oranges" }, label = "right" },
	{ code = "ALC", city = "Alicante", lat = 38.28, lon = -0.56, region = "LEV", goods = { "nougat", "fashion" }, label = "right" },
	{ code = "RMU", city = "Murcia", lat = 37.8, lon = -1.13, region = "LEV", goods = { "veggies", "oranges" }, label = "right" },
	{ code = "BCN", city = "Barcelona", lat = 41.3, lon = 2.08, region = "CAT", goods = { "cars", "medicine", "fashion" }, label = "right" },
	{ code = "GRO", city = "Girona", lat = 41.9, lon = 2.76, region = "CAT", goods = { "ham", "veggies" }, label = "right" },
	{ code = "REU", city = "Reus", lat = 41.15, lon = 1.17, region = "CAT", goods = { "wine", "oil" }, label = "left" },
	{ code = "ZAZ", city = "Zaragoza", lat = 41.67, lon = -1.04, region = "CAT", goods = { "fashion", "cars" } },
	{ code = "HSK", city = "Huesca", lat = 42.08, lon = -0.32, region = "CAT", goods = { "ham", "veggies" }, label = "right" },
	{ code = "SVQ", city = "Sevilla", lat = 37.42, lon = -5.9, region = "AND", goods = { "oil", "oranges" }, label = "left" },
	{ code = "AGP", city = "Málaga", lat = 36.67, lon = -4.5, region = "AND", goods = { "tech", "veggies" } },
	{ code = "GRX", city = "Granada", lat = 37.19, lon = -3.78, region = "AND", goods = { "oil", "ham" } },
	{ code = "LEI", city = "Almería", lat = 36.84, lon = -2.37, region = "AND", goods = { "veggies" }, label = "right" },
	{ code = "XRY", city = "Jerez", lat = 36.74, lon = -6.06, region = "AND", goods = { "wine", "fish" }, label = "left" },
	{ code = "ODB", city = "Córdoba", lat = 37.84, lon = -4.85, region = "AND", goods = { "oil" }, label = "left" },
	{ code = "MLN", city = "Melilla", lat = 35.28, lon = -2.96, region = "AND", goods = { "parcel", "fish" } },
	{ code = "BIO", city = "Bilbao", lat = 43.3, lon = -2.91, region = "NOR", goods = { "steel", "fish" }, label = "top" },
	{ code = "EAS", city = "San Sebastián", lat = 43.36, lon = -1.79, region = "NOR", goods = { "fish", "cheese" }, label = "right" },
	{ code = "VIT", city = "Vitoria", lat = 42.88, lon = -2.72, region = "NOR", goods = { "parcel", "steel" }, label = "none" },
	{ code = "PNA", city = "Pamplona", lat = 42.77, lon = -1.65, region = "NOR", goods = { "cars", "veggies" }, label = "right" },
	{ code = "RJL", city = "Logroño", lat = 42.46, lon = -2.32, region = "NOR", goods = { "wine" } },
	{ code = "SDR", city = "Santander", lat = 43.43, lon = -3.82, region = "NOR", goods = { "cheese", "fish" }, label = "left" },
	{ code = "OVD", city = "Asturias", lat = 43.56, lon = -6.03, region = "NOR", goods = { "cheese", "steel" }, label = "top" },
	{ code = "VLL", city = "Valladolid", lat = 41.71, lon = -4.85, region = "CYL", goods = { "cars", "cheese" }, label = "right" },
	{ code = "LEN", city = "León", lat = 42.59, lon = -5.65, region = "CYL", goods = { "ham", "steel" } },
	{ code = "SLM", city = "Salamanca", lat = 40.95, lon = -5.5, region = "CYL", goods = { "ham" } },
	{ code = "RGS", city = "Burgos", lat = 42.36, lon = -3.62, region = "CYL", goods = { "ham", "cheese" }, label = "none" },
	{ code = "BJZ", city = "Badajoz", lat = 38.89, lon = -6.82, region = "CYL", goods = { "ham", "oil" } },
	{ code = "SCQ", city = "Santiago", lat = 42.9, lon = -8.42, region = "GAL", goods = { "fish", "cheese" }, label = "right" },
	{ code = "VGO", city = "Vigo", lat = 42.23, lon = -8.63, region = "GAL", goods = { "fish", "cars" } },
	{ code = "LCG", city = "A Coruña", lat = 43.3, lon = -8.38, region = "GAL", goods = { "fashion", "fish" }, label = "top" },
	{ code = "PMI", city = "Palma", lat = 39.55, lon = 2.74, region = "BAL", goods = { "parcel", "oil" } },
	{ code = "IBZ", city = "Ibiza", lat = 38.87, lon = 1.37, region = "BAL", goods = { "fashion", "parcel" } },
	{ code = "MAH", city = "Menorca", lat = 39.86, lon = 4.22, region = "BAL", goods = { "cheese" }, label = "top" },
	{ code = "TFN", city = "Tenerife", lat = 28.48, lon = -16.34, region = "CAN", goods = { "bananas", "fish" }, label = "top" },
	{ code = "LPA", city = "Gran Canaria", lat = 27.93, lon = -15.39, region = "CAN", goods = { "bananas", "parcel" } },
	{ code = "ACE", city = "Lanzarote", lat = 28.95, lon = -13.61, region = "CAN", goods = { "wine" }, label = "top" },
	{ code = "SPC", city = "La Palma", lat = 28.62, lon = -17.76, region = "CAN", goods = { "bananas" }, label = "top" },
} :: { Airport }
Config.AirportByCode = {} :: { [string]: Airport }
for _, a in Config.Airports do
	Config.AirportByCode[a.code] = a
end

-- Distancia de círculo máximo en km
function Config.distance(a: string, b: string): number
	local A, B = Config.AirportByCode[a], Config.AirportByCode[b]
	local r = math.rad
	local dLat, dLon = r(B.lat - A.lat), r(B.lon - A.lon)
	local h = math.sin(dLat / 2) ^ 2 + math.cos(r(A.lat)) * math.cos(r(B.lat)) * math.sin(dLon / 2) ^ 2
	return math.floor(6371 * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h)) + 0.5)
end

---------------------------------------------------------------------
-- Aviones (nombres de aves, inventados). cap = t, speed = km/h, range = km, burn = L/km
-- look = cómo se dibuja: props (hélices), engines, highWing, livery (color de la franja)
---------------------------------------------------------------------
export type PlaneModel = {
	id: string, emoji: string, cap: number, speed: number, range: number, burn: number,
	price: number, level: number, length: number, props: boolean, engines: number, highWing: boolean, livery: Color3,
}
Config.Planes = {
	{ id = "sparrow", emoji = "🐦", cap = 1, speed = 320, range = 1300, burn = 0.5, price = 20_000, level = 1,
		length = 0.62, props = true, engines = 1, highWing = true, livery = Color3.fromRGB(255, 107, 53) },
	{ id = "hawk", emoji = "🦅", cap = 3, speed = 420, range = 1800, burn = 1, price = 60_000, level = 3,
		length = 0.72, props = true, engines = 2, highWing = false, livery = Color3.fromRGB(45, 127, 249) },
	{ id = "albatross", emoji = "🕊️", cap = 8, speed = 520, range = 2600, burn = 2, price = 250_000, level = 6,
		length = 0.82, props = true, engines = 2, highWing = true, livery = Color3.fromRGB(34, 177, 92) },
	{ id = "crane", emoji = "🦩", cap = 16, speed = 780, range = 3000, burn = 3.5, price = 1_200_000, level = 9,
		length = 0.88, props = false, engines = 2, highWing = false, livery = Color3.fromRGB(139, 92, 246) },
	{ id = "condor", emoji = "🦚", cap = 30, speed = 840, range = 4500, burn = 6, price = 5_000_000, level = 13,
		length = 0.95, props = false, engines = 2, highWing = false, livery = Color3.fromRGB(235, 68, 68) },
	{ id = "whale", emoji = "🐋", cap = 70, speed = 800, range = 6000, burn = 12, price = 20_000_000, level = 18,
		length = 1, props = false, engines = 4, highWing = true, livery = Color3.fromRGB(255, 196, 46) },
} :: { PlaneModel }
Config.PlaneById = {} :: { [string]: PlaneModel }
for _, p in Config.Planes do
	Config.PlaneById[p.id] = p
end

---------------------------------------------------------------------
-- Mejoras de la empresa (coste = base × growth^nivel)
---------------------------------------------------------------------
export type Upgrade = { id: string, emoji: string, base: number, growth: number, max: number, level: number }
Config.Upgrades = {
	{ id = "hangar", emoji = "🏗️", base = 25_000, growth = 2.1, max = 10, level = 1 }, -- +2 aviones
	{ id = "sales", emoji = "📈", base = 50_000, growth = 2.5, max = 10, level = 2 }, -- +5 % de pago
	{ id = "fuel", emoji = "⛽", base = 40_000, growth = 2.4, max = 8, level = 3 }, -- −5 % combustible
	{ id = "fast", emoji = "⏱️", base = 100_000, growth = 3, max = 5, level = 5 }, -- −8 % tiempo de vuelo
	{ id = "cold", emoji = "❄️", base = 150_000, growth = 1, max = 1, level = 7 }, -- permite 🐟 y 💊
} :: { Upgrade }
Config.UpgradeById = {} :: { [string]: Upgrade }
for _, u in Config.Upgrades do
	Config.UpgradeById[u.id] = u
end
function Config.upgradeCost(id: string, level: number): number
	local u = Config.UpgradeById[id]
	return math.floor(u.base * u.growth ^ level)
end
function Config.maxPlanes(hangar: number, pass: boolean?): number
	return 3 + hangar * 2 + (pass and 5 or 0)
end

---------------------------------------------------------------------
-- Pilotos: candidatos a la vista (NO hay sorteo de pago: ves sus estrellas antes de ficharlos)
---------------------------------------------------------------------
Config.CANDIDATES = 3
Config.CANDIDATE_REFRESH = 240 -- segundos hasta que llegan candidatos nuevos
Config.StarChance = { 42, 30, 17, 8, 3 } -- probabilidad de que un candidato tenga 1..5 estrellas (%)
Config.StarBonus = { 0, 0.05, 0.1, 0.18, 0.3 } -- % extra de pago
Config.StarPrice = { 2_500, 6_000, 15_000, 40_000, 100_000 } -- × (1 + 0,35 × (nivel − 1))
Config.PILOT_MAX_LEVEL = 10
Config.PILOT_LEVEL_BONUS = 0.015 -- +1,5 % de pago por nivel del piloto
function Config.pilotXpForLevel(level: number): number
	return 3 * (level - 1) * level -- vuelos acumulados: 0, 6, 18, 36...
end
function Config.candidatePrice(stars: number, companyLevel: number): number
	return math.floor(Config.StarPrice[stars] * (1 + 0.35 * (companyLevel - 1)) / 100) * 100
end
function Config.searchCost(companyLevel: number): number
	return 1000 * companyLevel
end
function Config.pilotBonus(stars: number, level: number): number
	return Config.StarBonus[stars] + Config.PILOT_LEVEL_BONUS * (level - 1)
end
-- Rasgos: cada piloto tiene uno, visible ANTES de ficharlo (no es un sorteo de pago).
-- pay/time/fuel = multiplicadores cuando el rasgo se aplica a esa carga
export type Trait = {
	id: string, emoji: string, pay: number?, time: number?, fuel: number?,
	goods: { [string]: boolean }?, regions: { [string]: boolean }?, express: boolean?, special: boolean?,
}
Config.Traits = {
	{ id = "fast", emoji = "⚡", time = 0.88 }, -- vuelos un 12 % más cortos
	{ id = "saver", emoji = "⛽", fuel = 0.75 }, -- −25 % de combustible
	{ id = "island", emoji = "🏝️", pay = 1.25, regions = { BAL = true, CAN = true } }, -- +25 % si sale o llega a las islas
	{ id = "cold", emoji = "❄️", pay = 1.25, goods = { fish = true, medicine = true } },
	{ id = "gourmet", emoji = "🍷", pay = 1.15, goods = { wine = true, cheese = true, ham = true, oil = true, nougat = true } },
	{ id = "express", emoji = "⏱️", pay = 1.3, express = true }, -- +30 % en contratos exprés
	{ id = "ace", emoji = "🎖️", pay = 1.1, special = true }, -- solo el piloto estrella de la tienda
} :: { Trait }
Config.TraitById = {} :: { [string]: Trait }
for _, t in Config.Traits do
	Config.TraitById[t.id] = t
end
Config.Avatars = { "👨‍✈️", "👩‍✈️", "🧑‍✈️", "👨🏽‍✈️", "👩🏽‍✈️", "👨🏿‍✈️", "👩🏻‍✈️", "🧑🏾‍✈️" }
Config.FirstNames = {
	"Lucía", "Mateo", "Sofía", "Hugo", "Martina", "Leo", "Valeria", "Pablo", "Carmen", "Álvaro",
	"Alba", "Daniel", "Noa", "Mario", "Irene", "Javier", "Paula", "Diego", "Elena", "Marco",
	"Alex", "Sam", "Taylor", "Jordan", "Aiko", "Kenji", "Amara", "Omar", "Ingrid", "Chloé",
}
Config.LastNames = {
	"García", "Martínez", "López", "Sánchez", "Pérez", "Gómez", "Ruiz", "Díaz", "Moreno", "Álvarez",
	"Navarro", "Torres", "Domínguez", "Vázquez", "Ramos", "Gil", "Serrano", "Blanco", "Molina", "Castro",
}

---------------------------------------------------------------------
-- Contratos exprés: aparecen cada cierto tiempo, pagan mucho y caducan
---------------------------------------------------------------------
Config.Express = { every = { 90, 150 }, lasts = 80, mult = 2.5 }

---------------------------------------------------------------------
-- Generador pseudoaleatorio determinista (Park-Miller): con la misma semilla da lo mismo
-- en todos los servidores (eventos y ciudades en auge iguales para todo el mundo).
---------------------------------------------------------------------
-- Multiplicación de 32 bits sin perder precisión (los números de Luau son dobles)
local function mul32(a: number, b: number): number
	local ah, al = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	return bit32.band(al * b + bit32.lshift(bit32.band(ah * b, 0xFFFF), 16), 0xFFFFFFFF)
end
-- Mezcla tipo «murmur»: semillas seguidas (1, 2, 3…) dan valores sin relación entre sí
function Config.hash(n: number): number
	local h = bit32.band(math.floor(n), 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

function Config.prng(seed: number): (number?, number?) -> number
	local s = Config.hash(seed) % 2147483646 + 1
	local function nextValue(a: number?, b: number?): number
		s = (s * 16807) % 2147483647
		local f = (s - 1) / 2147483646
		if a and b then
			return a + math.floor(f * (b - a + 1))
		end
		return f
	end
	for _ = 1, 4 do -- calentar: semillas seguidas dan resultados muy distintos
		nextValue()
	end
	return nextValue
end

---------------------------------------------------------------------
-- Demanda viva: ciudades en auge (iguales en todos los servidores) y saturación
---------------------------------------------------------------------
Config.WANTED_PERIOD = 600 -- cada 10 min cambian las ciudades en auge
Config.WANTED_COUNT = 4
Config.WANTED_MULTS = { 1.3, 1.4, 1.5, 1.6 }
Config.SAT_STEP = 0.08 -- cada vuelo reciente al mismo destino paga un 8 % menos…
Config.SAT_MIN = 0.6 -- …hasta un mínimo del 60 %
Config.SAT_DECAY = 90 -- segundos para que se recupere un «vuelo» de saturación
Config.NEW_ROUTE_MULT = 1.5 -- primera entrega en un aeropuerto (sello nuevo del pasaporte)
Config.REGION_STAMP_BONUS = 0.03 -- región con todos sus sellos: +3 % al volar allí

---------------------------------------------------------------------
-- Eventos de España (iguales en todos los servidores). Cada 7 min: 5 min de evento y 2 de calma.
-- goods = productos afectados · to = aeropuertos de destino · region = sale o llega a esa región
-- months = meses en los que sale 4 veces más (fiestas reales)
---------------------------------------------------------------------
Config.EVENT_PERIOD = 420
Config.EVENT_LENGTH = 300
export type EventDef = {
	id: string, emoji: string, pay: number, time: number?, goods: { string }?, to: { string }?, region: string?, months: { number }?,
}
Config.Events = {
	{ id = "fallas", emoji = "🎆", pay = 2, goods = { "oranges" }, months = { 3 } },
	{ id = "sanfermin", emoji = "🐂", pay = 1.8, to = { "PNA" }, months = { 7 } },
	{ id = "feria", emoji = "💃", pay = 1.8, to = { "SVQ" }, months = { 4 } },
	{ id = "vendimia", emoji = "🍇", pay = 2, goods = { "wine" }, months = { 9, 10 } },
	{ id = "navidad", emoji = "🎄", pay = 2.2, goods = { "nougat" }, months = { 12 } },
	{ id = "rebajas", emoji = "🛍️", pay = 1.8, goods = { "fashion" }, months = { 1, 7 } },
	{ id = "calor", emoji = "🥵", pay = 1.6, goods = { "fish", "medicine" }, months = { 7, 8 } },
	{ id = "tormenta", emoji = "⛈️", pay = 1.5, time = 1.3, region = "GAL", months = { 11, 12, 1, 2 } },
	{ id = "niebla", emoji = "🌫️", pay = 1.3, time = 1.25, region = "CEN", months = { 11, 12, 1 } },
	{ id = "turistas", emoji = "🏖️", pay = 1.6, region = "BAL", months = { 6, 7, 8 } },
	{ id = "carnaval", emoji = "🎭", pay = 1.6, region = "CAN", months = { 2 } },
	{ id = "puente", emoji = "🏙️", pay = 1.4, to = { "MAD", "BCN" } },
	{ id = "motor", emoji = "🏁", pay = 1.7, goods = { "cars", "steel" } },
	{ id = "tecno", emoji = "📱", pay = 1.8, goods = { "tech" }, months = { 11 } },
	{ id = "cosecha", emoji = "🧺", pay = 1.7, goods = { "veggies", "bananas" } },
	{ id = "ibericos", emoji = "🍖", pay = 1.6, goods = { "ham", "cheese", "oil" } },
} :: { EventDef }
Config.EventById = {} :: { [string]: EventDef }
for _, e in Config.Events do
	Config.EventById[e.id] = e
end

---------------------------------------------------------------------
-- Contratos con empresas (inventadas): «lleva N cargas de X a la región R antes de T»
---------------------------------------------------------------------
Config.CONTRACT_LEVEL = 3
Config.CONTRACT_OFFERS = 3
Config.CONTRACT_SLOTS = 2
Config.CONTRACT_REFRESH = 480 -- ofertas nuevas cada 8 min
Config.CONTRACT_SECS_PER_LOAD = 240 -- 4 min por entrega
export type Company = { id: string, good: string }
Config.Companies = {
	{ id = "turia", good = "oranges" }, { id = "huerta", good = "veggies" }, { id = "ceramica", good = "tiles" },
	{ id = "betica", good = "oil" }, { id = "ribera", good = "wine" }, { id = "queseria", good = "cheese" },
	{ id = "xixona", good = "nougat" }, { id = "acero", good = "steel" }, { id = "platano", good = "bananas" },
	{ id = "sierra", good = "ham" }, { id = "galaica", good = "fashion" }, { id = "ebro", good = "cars" },
	{ id = "tecno", good = "tech" }, { id = "cantabrica", good = "fish" }, { id = "farma", good = "medicine" },
} :: { Company }
Config.CompanyById = {} :: { [string]: Company }
Config.CompanyByGood = {} :: { [string]: Company }
for _, c in Config.Companies do
	Config.CompanyById[c.id] = c
	Config.CompanyByGood[c.good] = c
end
function Config.contractSize(level: number): number
	return math.min(7, 3 + math.floor(level / 6))
end

---------------------------------------------------------------------
-- Vuelos chárter: el avión se va fuera de España horas REALES y vuelve con mucho dinero
-- (paga minutos de tus ingresos). Sin piloto (lleva la tripulación del cliente). Uno a la vez.
---------------------------------------------------------------------
Config.CHARTER_LEVEL = 2
export type Charter = { id: string, hours: number, minutes: number }
Config.Charters = {
	{ id = "c1", hours = 1, minutes = 20 },
	{ id = "c4", hours = 4, minutes = 60 },
	{ id = "c8", hours = 8, minutes = 110 },
} :: { Charter }
Config.CharterById = {} :: { [string]: Charter }
for _, c in Config.Charters do
	Config.CharterById[c.id] = c
end
Config.CharterCities = { "Lisboa", "Paris", "London", "Roma", "Berlin", "Marrakech", "Amsterdam", "Dublin" }

---------------------------------------------------------------------
-- Aterrizaje perfecto (solo cuando vuelas TÚ): en los últimos segundos sale una aguja
---------------------------------------------------------------------
Config.LANDING = { window = 4, minSecs = 12, perfect = 1.25, good = 1.1 }

---------------------------------------------------------------------
-- Salir a bolsa (prestigio): se reinicia la partida y ganas acciones (+20 % de pago y +25 % de XP cada una)
-- Acciones totales = √(ganado en toda la historia / 1 M); se cobran las que aún no tienes
---------------------------------------------------------------------
Config.IPO_LEVEL = 12
Config.IPO_MIN_SHARES = 5
Config.SHARE_BONUS = 0.2 -- +20 % de pago por acción
Config.SHARE_XP_BONUS = 0.25 -- +25 % de XP por acción (cada partida nueva sube de nivel mucho más rápido)
function Config.sharesTotal(lifetimeEarned: number): number
	return math.floor(math.sqrt(math.max(0, lifetimeEarned) / 1e6))
end
-- Ventajas permanentes según las veces que has salido a bolsa (la n.º i se activa en la salida i)
Config.IpoPerks = { "gold", "region", "contract", "hawk", "candidate" }
Config.IPO_START_MONEY = 300_000

---------------------------------------------------------------------
-- Tu aerolínea: nombre por piezas (sin texto libre, no hace falta filtro) y color
---------------------------------------------------------------------
Config.AirlineParts = {
	{ "Aero", "Vuela", "Cielo", "Sol", "Iber", "Ala", "Nube", "Rumbo" },
	{ "Toro", "Olivo", "Flamenco", "Brisa", "Faro", "Lince", "Cometa", "Naranja" },
	{ "Cargo", "Express", "Air", "Jet", "Fly", "Line", "Go", "Max" },
}
Config.AirlineColors = {
	Color3.fromRGB(255, 107, 53), Color3.fromRGB(45, 127, 249), Color3.fromRGB(34, 177, 92), Color3.fromRGB(139, 92, 246),
	Color3.fromRGB(235, 68, 68), Color3.fromRGB(236, 72, 153), Color3.fromRGB(20, 184, 166), Color3.fromRGB(31, 42, 68),
	Color3.fromRGB(132, 204, 22), Color3.fromRGB(255, 196, 46), -- el último (oro) se gana saliendo a bolsa
}
Config.GOLD_COLOR = #Config.AirlineColors
function Config.airlineName(a: any): string
	local P = Config.AirlineParts
	local i, j, k = a and a.a or 1, a and a.b or 1, a and a.c or 1
	return (P[1][i] or P[1][1]) .. " " .. (P[2][j] or P[2][1]) .. " " .. (P[3][k] or P[3][1])
end

---------------------------------------------------------------------
-- Pasaporte: un sello por aeropuerto (primera entrega) y medallas por producto (1/10/50 entregas)
---------------------------------------------------------------------
Config.MEDALS = { 1, 10, 50 }

---------------------------------------------------------------------
-- Progresión
---------------------------------------------------------------------
function Config.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(220 * (level - 1) ^ 2.35)
end
function Config.levelFromXp(xp: number): number
	local level = 1
	while level < 99 and xp >= Config.xpForLevel(level + 1) do
		level += 1
	end
	return level
end
function Config.flightXp(gross: number): number
	return math.max(1, math.floor(math.sqrt(gross)))
end
-- Duración del vuelo en segundos reales
function Config.flightSeconds(distance: number, speed: number, timeMult: number): number
	return math.max(10, math.floor(distance / speed * 3600 / Config.TIME_SCALE * timeMult + 0.5))
end
function Config.payout(weight: number, distance: number, goodMult: number): number
	return math.floor(weight * distance * Config.RATE * goodMult)
end
function Config.wear(distance: number): number
	return math.floor(distance / 1000 * 2.5 * 10 + 0.5) / 10
end
function Config.repairCost(price: number, condition: number): number
	return math.floor(price * 0.002 * (100 - condition))
end
function Config.sellPrice(price: number, condition: number): number
	return math.floor(price * 0.5 * (0.5 + condition / 200))
end
-- Escala de premios (misiones, objetivos, recompensa diaria) según el nivel
function Config.rewardScale(level: number): number
	return math.floor(1500 * level ^ 1.7 / 100) * 100
end

---------------------------------------------------------------------
-- Recompensa diaria (racha de 7 días; se pierde si pasan más de 48 h)
---------------------------------------------------------------------
Config.DailyRewards = { 1, 1.5, 2, 2.5, 3, 4, 6 } -- × rewardScale; el día 7 además da x2 30 min

---------------------------------------------------------------------
-- Misiones diarias (3 al día: fácil, media, difícil)
---------------------------------------------------------------------
export type MissionDef = { id: string, stat: string, goal: { number }, reward: number, level: number? }
Config.MissionPool = {
	{ id = "deliveries", stat = "flights", goal = { 5, 12, 25 }, reward = 1 },
	{ id = "km", stat = "km", goal = { 2000, 6000, 15000 }, reward = 1 },
	{ id = "express", stat = "express", goal = { 1, 2, 4 }, reward = 1.3 },
	{ id = "tons", stat = "tons", goal = { 5, 20, 60 }, reward = 1.1 },
	{ id = "local", stat = "localGoods", goal = { 3, 8, 15 }, reward = 1.1 },
	{ id = "earn", stat = "earned", goal = { 1, 3, 8 }, reward = 1.2 }, -- × rewardScale
	{ id = "upgrades", stat = "purchases", goal = { 1, 2, 4 }, reward = 1 },
	{ id = "contracts", stat = "contracts", goal = { 1, 2, 3 }, reward = 1.4, level = 3 }, -- level = desde ese nivel
	{ id = "perfect", stat = "perfect", goal = { 1, 3, 6 }, reward = 1.1 },
	{ id = "newroutes", stat = "newRoutes", goal = { 1, 2, 3 }, reward = 1.2, level = 3 },
} :: { MissionDef }
Config.MISSIONS_BOOST_MIN = 15 -- completar las 3 → x2 15 min

---------------------------------------------------------------------
-- Objetivos (cadena: se muestra el siguiente sin reclamar; se reclaman a mano)
---------------------------------------------------------------------
export type GoalDef = { id: string, stat: string, target: number, reward: number }
Config.Goals = {} :: { GoalDef }
-- start = ronda de la cadena en la que aparece el primer objetivo del grupo
local GOAL_TRACKS: { { stat: string, targets: { number }, start: number? } } = {
	{ stat = "flights", targets = { 1, 5, 15, 40, 100, 250, 600, 1500 } },
	{ stat = "planes", targets = { 2, 3, 5, 8, 12, 18 } },
	{ stat = "pilots", targets = { 1, 3, 6, 10, 15 } },
	{ stat = "regions", targets = { 3, 4, 5, 6, 7, 8, 9 } },
	{ stat = "level", targets = { 3, 5, 8, 12, 16, 20 } },
	{ stat = "express", targets = { 1, 5, 20, 60 } },
	{ stat = "earned", targets = { 50_000, 500_000, 5_000_000, 50_000_000, 500_000_000, 5_000_000_000 } },
	{ stat = "perfect", targets = { 1, 10, 40, 100 } },
	{ stat = "contracts", targets = { 1, 5, 15, 40 }, start = 2 },
	{ stat = "stamps", targets = { 10, 30, 60, 92 }, start = 2 },
	{ stat = "charters", targets = { 1, 5, 20 }, start = 2 },
	{ stat = "ipo", targets = { 1, 2, 3, 5 }, start = 5 },
}
-- Cadena: primero la ronda 1 de cada grupo (en el orden de arriba), luego la 2, etc.
local maxRound = 0
for _, track in GOAL_TRACKS do
	maxRound = math.max(maxRound, #track.targets + (track.start or 1) - 1)
end
for round = 1, maxRound do
	for _, track in GOAL_TRACKS do
		local i = round - (track.start or 1) + 1
		local target = track.targets[i]
		if target then
			table.insert(Config.Goals, { id = track.stat .. "_" .. i, stat = track.stat, target = target, reward = 0.6 + round * 0.4 })
		end
	end
end

---------------------------------------------------------------------
-- Tienda (Robux). id = 0 → no aparece en el juego publicado (en Studio se ve como muestra)
-- price = precio recomendado para crearlo en el Creator Hub
---------------------------------------------------------------------
export type ShopItem = { key: string, id: number, emoji: string, price: number }
Config.GamePasses = {
	{ key = "vip", id = 0, emoji = "💰", price = 199 }, -- dinero x2 para siempre
	{ key = "autopilot", id = 0, emoji = "🤖", price = 149 }, -- despacho automático desde el nivel 1 y 100 % offline
	{ key = "hangarxl", id = 0, emoji = "🏗️", price = 99 }, -- +5 aviones
	{ key = "turbo", id = 0, emoji = "🚀", price = 249 }, -- vuelos un 25 % más rápidos
} :: { ShopItem }
Config.Products = {
	{ key = "starter", id = 0, emoji = "🎁", price = 99 }, -- una vez: Halcón + $50K + x2 30 min
	{ key = "cash_s", id = 0, emoji = "💵", price = 25 },
	{ key = "cash_m", id = 0, emoji = "💰", price = 79 },
	{ key = "cash_l", id = 0, emoji = "🏦", price = 249 },
	{ key = "boost", id = 0, emoji = "⚡", price = 49 }, -- x2 30 min
	{ key = "landall", id = 0, emoji = "🛬", price = 19 }, -- todos los vuelos aterrizan ya
	{ key = "star_pilot", id = 0, emoji = "⭐", price = 99 }, -- piloto de 5 estrellas (sin sorteo)
	{ key = "offline2x", id = 0, emoji = "🌙", price = 29 }, -- duplica las ganancias offline recién cobradas
} :: { ShopItem }
-- Dinero de los maletines: minutos de ingresos (con un mínimo según nivel)
Config.CashPacks = { cash_s = 10, cash_m = 40, cash_l = 180 } :: { [string]: number }

return Config
