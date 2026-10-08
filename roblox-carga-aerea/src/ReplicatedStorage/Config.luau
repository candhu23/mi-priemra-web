--!strict
-- Configuración de «Air Cargo Empire»: TODOS los datos y fórmulas de equilibrio.
-- El servidor y el cliente leen este módulo; los textos están en Lang.luau.

local Config = {}

Config.VERSION = "0.1"
-- 1 segundo real = 2 minutos de vuelo
Config.TIME_SCALE = 120
Config.START_MONEY = 15000
Config.RATE = 4 -- $ por tonelada·km
Config.FUEL_PRICE = 2.5 -- $ por litro (base; varía ±30 %)
Config.PILOT_FEE = 0.1 -- los pilotos contratados cobran el 10 % de cada vuelo
Config.AUTO_DISPATCH_LEVEL = 5
Config.BOARD_SIZE = 8 -- cargas por aeropuerto
Config.BOARD_TTL = 90 -- segundos hasta renovar un tablón
Config.REFRESH_COOLDOWN = 20
Config.WEATHER_PERIOD = 180
Config.MAX_PILOTS = 20
Config.REPAIR_BLOCK = 25 -- con menos estado (%) el avión no puede volar

---------------------------------------------------------------------
-- Assets (sube los PNG de assets/ y pega aquí sus IDs: "rbxassetid://123")
-- Mientras estén vacíos, la interfaz usa sustitutos de texto.
---------------------------------------------------------------------
Config.Assets = {
	icons = "", -- assets/iconos.png (1024x1024, celdas de 128)
	planes = "", -- assets/aviones.png (1024x768, celdas de 512x256)
	mapWest = "", -- assets/mapa_oeste.png
	mapEast = "", -- assets/mapa_este.png
}

-- Posición de cada icono en la hoja (mismo orden que tools/assets/build_icons.js)
Config.Icons = {} :: { [string]: number }
for i, name in {
	"menu", "map", "plane", "plane-takeoff", "plane-landing", "users", "user-round", "building-2",
	"settings", "wrench", "fuel", "landmark", "star", "package", "globe", "warehouse",
	"trending-up", "cloud-rain", "snowflake", "cloud-lightning", "sun", "clock", "gauge", "route",
	"coins", "banknote", "trophy", "languages", "volume-2", "volume-x", "x", "chevron-down",
	"check", "lock", "award", "refresh-cw", "zap", "shield-check", "thermometer-snowflake", "flame",
	"paw-print", "cpu", "mail", "apple", "container", "map-pin", "shopping-cart", "arrow-right",
	"info", "gift", "dices", "id-card", "chart-column", "circle-dollar-sign", "weight",
} do
	Config.Icons[name] = i - 1
end

-- Mapa equirrectangular: longitud -180..180, latitud 80..-60
Config.Map = { latTop = 80, latBottom = -60, aspect = 360 / 140 }

---------------------------------------------------------------------
-- Paleta (azul marino + naranja; distinta del juego de referencia)
---------------------------------------------------------------------
Config.Colors = {
	bg = Color3.fromRGB(9, 14, 27),
	panel = Color3.fromRGB(15, 22, 40),
	card = Color3.fromRGB(20, 29, 51),
	cardHi = Color3.fromRGB(28, 40, 68),
	stroke = Color3.fromRGB(40, 54, 86),
	text = Color3.fromRGB(236, 241, 250),
	muted = Color3.fromRGB(140, 154, 184),
	accent = Color3.fromRGB(255, 138, 61), -- naranja: acción principal
	accentDark = Color3.fromRGB(64, 38, 24),
	blue = Color3.fromRGB(59, 130, 246),
	sky = Color3.fromRGB(56, 189, 248), -- pestaña activa
	green = Color3.fromRGB(52, 211, 153),
	red = Color3.fromRGB(248, 113, 113),
	yellow = Color3.fromRGB(250, 204, 21),
	purple = Color3.fromRGB(167, 139, 250),
}

---------------------------------------------------------------------
-- Regiones y aeropuertos (ciudades reales; códigos IATA)
---------------------------------------------------------------------
export type Region = { id: string, level: number, cost: number }
Config.Regions = {
	{ id = "NA", level = 1, cost = 0 },
	{ id = "EU", level = 4, cost = 150_000 },
	{ id = "SA", level = 6, cost = 600_000 },
	{ id = "AS", level = 8, cost = 2_000_000 },
	{ id = "AF", level = 10, cost = 5_000_000 },
	{ id = "OC", level = 13, cost = 15_000_000 },
} :: { Region }

export type Airport = { code: string, city: string, lat: number, lon: number, region: string, label: string? }
-- label: lado de la etiqueta en el mapa ("top", "left", "right"; por defecto debajo)
Config.Airports = {
	{ code = "JFK", city = "New York", lat = 40.64, lon = -73.78, region = "NA" },
	{ code = "LAX", city = "Los Angeles", lat = 33.94, lon = -118.41, region = "NA" },
	{ code = "ORD", city = "Chicago", lat = 41.98, lon = -87.9, region = "NA", label = "left" },
	{ code = "MIA", city = "Miami", lat = 25.79, lon = -80.29, region = "NA" },
	{ code = "DFW", city = "Dallas", lat = 32.9, lon = -97.04, region = "NA", label = "left" },
	{ code = "SEA", city = "Seattle", lat = 47.45, lon = -122.31, region = "NA" },
	{ code = "YYZ", city = "Toronto", lat = 43.68, lon = -79.63, region = "NA", label = "top" },
	{ code = "MEX", city = "Mexico City", lat = 19.44, lon = -99.07, region = "NA" },
	{ code = "ANC", city = "Anchorage", lat = 61.17, lon = -149.99, region = "NA" },
	{ code = "MEM", city = "Memphis", lat = 35.04, lon = -89.98, region = "NA", label = "bottom" },
	{ code = "LHR", city = "London", lat = 51.47, lon = -0.45, region = "EU", label = "left" },
	{ code = "FRA", city = "Frankfurt", lat = 50.03, lon = 8.56, region = "EU" },
	{ code = "MAD", city = "Madrid", lat = 40.47, lon = -3.56, region = "EU" },
	{ code = "CDG", city = "Paris", lat = 49.01, lon = 2.55, region = "EU", label = "left" },
	{ code = "AMS", city = "Amsterdam", lat = 52.31, lon = 4.76, region = "EU", label = "top" },
	{ code = "IST", city = "Istanbul", lat = 41.28, lon = 28.75, region = "EU" },
	{ code = "LEJ", city = "Leipzig", lat = 51.42, lon = 12.24, region = "EU", label = "right" },
	{ code = "GRU", city = "São Paulo", lat = -23.43, lon = -46.47, region = "SA" },
	{ code = "BOG", city = "Bogotá", lat = 4.7, lon = -74.15, region = "SA" },
	{ code = "SCL", city = "Santiago", lat = -33.39, lon = -70.79, region = "SA" },
	{ code = "EZE", city = "Buenos Aires", lat = -34.82, lon = -58.54, region = "SA" },
	{ code = "LIM", city = "Lima", lat = -12.02, lon = -77.11, region = "SA" },
	{ code = "HKG", city = "Hong Kong", lat = 22.31, lon = 113.91, region = "AS" },
	{ code = "PVG", city = "Shanghai", lat = 31.14, lon = 121.81, region = "AS", label = "right" },
	{ code = "NRT", city = "Tokyo", lat = 35.77, lon = 140.39, region = "AS", label = "right" },
	{ code = "ICN", city = "Seoul", lat = 37.46, lon = 126.44, region = "AS", label = "right" },
	{ code = "SIN", city = "Singapore", lat = 1.36, lon = 103.99, region = "AS" },
	{ code = "DEL", city = "Delhi", lat = 28.56, lon = 77.1, region = "AS" },
	{ code = "BKK", city = "Bangkok", lat = 13.69, lon = 100.75, region = "AS" },
	{ code = "DXB", city = "Dubai", lat = 25.25, lon = 55.36, region = "AF", label = "right" },
	{ code = "DOH", city = "Doha", lat = 25.27, lon = 51.61, region = "AF", label = "left" },
	{ code = "JNB", city = "Johannesburg", lat = -26.14, lon = 28.25, region = "AF" },
	{ code = "NBO", city = "Nairobi", lat = -1.32, lon = 36.93, region = "AF" },
	{ code = "CAI", city = "Cairo", lat = 30.12, lon = 31.41, region = "AF" },
	{ code = "LOS", city = "Lagos", lat = 6.58, lon = 3.32, region = "AF" },
	{ code = "SYD", city = "Sydney", lat = -33.95, lon = 151.18, region = "OC" },
	{ code = "AKL", city = "Auckland", lat = -37.01, lon = 174.79, region = "OC" },
	{ code = "PER", city = "Perth", lat = -31.94, lon = 115.97, region = "OC" },
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
-- Aviones (nombres inventados: nada de marcas reales)
-- cap = toneladas, speed = km/h, range = km, burn = litros/km
-- sheet = celda en assets/aviones.png
---------------------------------------------------------------------
export type PlaneModel = {
	id: string, name: string, class: string, cap: number, speed: number, range: number,
	burn: number, price: number, level: number, license: string?, sheet: number,
}
Config.Planes = {
	{ id = "courier", name = "SkyHopper C1", class = "prop", cap = 1.5, speed = 340, range = 1800, burn = 0.6, price = 25_000, level = 1, sheet = 0 },
	{ id = "turboprop", name = "Coastline T8", class = "prop", cap = 8, speed = 500, range = 2600, burn = 1.6, price = 75_000, level = 3, license = "turboprop", sheet = 1 },
	{ id = "narrowbody", name = "Jetline N20", class = "jet", cap = 20, speed = 820, range = 4200, burn = 3.7, price = 1_500_000, level = 6, license = "jet", sheet = 2 },
	{ id = "widebody", name = "Horizon W55", class = "jet", cap = 55, speed = 870, range = 7500, burn = 7, price = 8_000_000, level = 10, license = "jet", sheet = 3 },
	{ id = "jumbo", name = "Titan J110", class = "jet", cap = 110, speed = 900, range = 8800, burn = 13, price = 25_000_000, level = 15, license = "heavy", sheet = 4 },
	{ id = "heavy", name = "Goliath H150", class = "jet", cap = 150, speed = 780, range = 5500, burn = 19, price = 45_000_000, level = 20, license = "heavy", sheet = 5 },
} :: { PlaneModel }
Config.PlaneById = {} :: { [string]: PlaneModel }
for _, p in Config.Planes do
	Config.PlaneById[p.id] = p
end

---------------------------------------------------------------------
-- Tipos de carga
---------------------------------------------------------------------
export type Cargo = { id: string, mult: number, weight: number, icon: string, level: number, license: string?, planes: { string }? }
Config.Cargo = {
	{ id = "general", mult = 1, weight = 30, icon = "package", level = 1 },
	{ id = "mail", mult = 1.15, weight = 20, icon = "mail", level = 1 },
	{ id = "perishable", mult = 1.25, weight = 15, icon = "apple", level = 2 },
	{ id = "electronics", mult = 1.3, weight = 12, icon = "cpu", level = 3 },
	{ id = "livestock", mult = 1.4, weight = 6, icon = "paw-print", level = 5, license = "livestock" },
	{ id = "pharma", mult = 1.6, weight = 8, icon = "thermometer-snowflake", level = 7, license = "pharma" },
	{ id = "dangerous", mult = 1.8, weight = 6, icon = "flame", level = 9, license = "dangerous" },
	{ id = "oversize", mult = 2, weight = 4, icon = "container", level = 20, planes = { "heavy" } },
} :: { Cargo }
Config.CargoById = {} :: { [string]: Cargo }
for _, c in Config.Cargo do
	Config.CargoById[c.id] = c
end

---------------------------------------------------------------------
-- Licencias (habilitan clases de avión y cargas especiales)
---------------------------------------------------------------------
export type License = { id: string, level: number, cost: number, icon: string }
Config.Licenses = {
	{ id = "turboprop", level = 3, cost = 12_000, icon = "plane" },
	{ id = "livestock", level = 5, cost = 60_000, icon = "paw-print" },
	{ id = "jet", level = 6, cost = 250_000, icon = "plane-takeoff" },
	{ id = "pharma", level = 7, cost = 400_000, icon = "thermometer-snowflake" },
	{ id = "dangerous", level = 9, cost = 1_200_000, icon = "flame" },
	{ id = "heavy", level = 15, cost = 5_000_000, icon = "award" },
} :: { License }
Config.LicenseById = {} :: { [string]: License }
for _, l in Config.Licenses do
	Config.LicenseById[l.id] = l
end

---------------------------------------------------------------------
-- Mejoras de la empresa (coste = base × growth^nivel)
---------------------------------------------------------------------
export type Upgrade = { id: string, icon: string, base: number, growth: number, max: number }
Config.Upgrades = {
	{ id = "hangar", icon = "warehouse", base = 30_000, growth = 2.2, max = 10 }, -- +2 aviones
	{ id = "fuel", icon = "fuel", base = 50_000, growth = 2.5, max = 8 }, -- −5 % combustible
	{ id = "broker", icon = "trending-up", base = 80_000, growth = 2.6, max = 10 }, -- +4 % pago
} :: { Upgrade }
Config.UpgradeById = {} :: { [string]: Upgrade }
for _, u in Config.Upgrades do
	Config.UpgradeById[u.id] = u
end
function Config.upgradeCost(id: string, level: number): number
	local u = Config.UpgradeById[id]
	return math.floor(u.base * u.growth ^ level)
end
function Config.maxPlanes(hangar: number): number
	return 3 + hangar * 2
end

---------------------------------------------------------------------
-- Pilotos: rarezas y agencias de contratación (probabilidades visibles)
---------------------------------------------------------------------
export type Rarity = { id: string, bonus: number, color: Color3 }
Config.Rarities = {
	{ id = "common", bonus = 0, color = Color3.fromRGB(160, 170, 190) },
	{ id = "uncommon", bonus = 0.05, color = Color3.fromRGB(52, 211, 153) },
	{ id = "rare", bonus = 0.12, color = Color3.fromRGB(59, 130, 246) },
	{ id = "epic", bonus = 0.22, color = Color3.fromRGB(167, 139, 250) },
	{ id = "legendary", bonus = 0.4, color = Color3.fromRGB(250, 204, 21) },
} :: { Rarity }
Config.RarityIndex = {} :: { [string]: number }
for i, r in Config.Rarities do
	Config.RarityIndex[r.id] = i
end

export type Agency = { id: string, level: number, cost: number, odds: { number }, icon: string }
-- odds en el orden de Config.Rarities (suman 100)
Config.Agencies = {
	{ id = "school", level = 1, cost = 5_000, odds = { 60, 28, 10, 1.8, 0.2 }, icon = "users" },
	{ id = "academy", level = 8, cost = 250_000, odds = { 0, 38, 46, 14, 2 }, icon = "award" },
	{ id = "aces", level = 15, cost = 3_000_000, odds = { 0, 0, 55, 38, 7 }, icon = "star" },
} :: { Agency }
Config.AgencyById = {} :: { [string]: Agency }
for _, a in Config.Agencies do
	Config.AgencyById[a.id] = a
end

Config.FirstNames = {
	"Alex", "Sam", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Jamie", "Avery", "Quinn",
	"Lucía", "Mateo", "Sofía", "Diego", "Valentina", "Hugo", "Aiko", "Kenji", "Amara", "Kwame",
	"Priya", "Arjun", "Mei", "Wei", "Leila", "Omar", "Ingrid", "Lars", "Chloé", "Luca",
}
Config.LastNames = {
	"Reyes", "Walker", "Silva", "Kim", "Nakamura", "Okafor", "Patel", "Novak", "Rossi", "Müller",
	"García", "Brooks", "Haddad", "Larsen", "Moreau", "Costa", "Chen", "Singh", "Mensah", "Ortega",
}

---------------------------------------------------------------------
-- Clima (cambia por aeropuerto cada WEATHER_PERIOD s)
---------------------------------------------------------------------
export type Weather = { id: string, chance: number, pay: number, time: number, wear: number, icon: string }
Config.Weather = {
	{ id = "clear", chance = 60, pay = 1, time = 1, wear = 1, icon = "sun" },
	{ id = "rain", chance = 25, pay = 1.05, time = 1.05, wear = 1.2, icon = "cloud-rain" },
	{ id = "snow", chance = 8, pay = 1.15, time = 1.15, wear = 1.5, icon = "snowflake" },
	{ id = "storm", chance = 7, pay = 1.3, time = 1.25, wear = 2, icon = "cloud-lightning" },
} :: { Weather }
Config.WeatherById = {} :: { [string]: Weather }
for _, w in Config.Weather do
	Config.WeatherById[w.id] = w
end

---------------------------------------------------------------------
-- Progresión
---------------------------------------------------------------------
-- XP total necesaria para llegar al nivel L
function Config.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(150 * (level - 1) ^ 2)
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
function Config.flightSeconds(distance: number, speed: number, weatherTime: number): number
	return math.max(15, math.floor(distance / speed * 3600 / Config.TIME_SCALE * weatherTime + 0.5))
end
-- Pago bruto de una carga
function Config.payout(weight: number, distance: number, cargoMult: number, weatherPay: number): number
	return math.floor(weight * distance * Config.RATE * cargoMult * weatherPay)
end
-- Desgaste del avión (% de estado) por vuelo
function Config.wear(distance: number, weatherWear: number): number
	return math.floor(distance / 1000 * 1.5 * weatherWear * 10 + 0.5) / 10
end
function Config.repairCost(price: number, condition: number): number
	return math.floor(price * 0.002 * (100 - condition))
end
function Config.sellPrice(price: number, condition: number): number
	return math.floor(price * 0.5 * (0.5 + condition / 200))
end

---------------------------------------------------------------------
-- Monetización (id = 0 → no aparece). Se rellenará más adelante.
---------------------------------------------------------------------
Config.Monetization = {
	GamePasses = {
		{ key = "x2", id = 0, icon = "coins" }, -- dinero x2
		{ key = "autopilot", id = 0, icon = "zap" }, -- despacho automático desde nivel 1
		{ key = "hangar", id = 0, icon = "warehouse" }, -- +4 aviones
	},
	Products = {},
}

return Config
