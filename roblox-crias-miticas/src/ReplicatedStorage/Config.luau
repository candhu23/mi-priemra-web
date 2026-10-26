--[[
	Config: TODOS los números del juego (islas, crías, huevos, fusión, renacer, álbum, misiones, tienda,
	colores) y las fórmulas que usan servidor y cliente. Para equilibrar el juego se toca solo este archivo.
	Ritmo medido con tools/harness/ritmo.luau (ver DISENO.md §5).
]]

local Config = {}

Config.VERSION = "0.3"
Config.GROUP_ID = 0 -- grupo de Roblox para el +10 % (0 = desactivado)

---------------------------------------------------------------------
-- Rarezas (orden fijo). weight = probabilidad en % dentro de cada huevo
---------------------------------------------------------------------
export type Rarity = { id: string, weight: number, power: number, color: Color3, size: number }
Config.Rarities = {
	{ id = "common", weight = 35, power = 1, color = Color3.fromRGB(148, 163, 184), size = 1 },
	{ id = "common", weight = 25, power = 1.25, color = Color3.fromRGB(148, 163, 184), size = 1 },
	{ id = "uncommon", weight = 20, power = 1.7, color = Color3.fromRGB(34, 197, 94), size = 1.1 },
	{ id = "rare", weight = 12, power = 2.6, color = Color3.fromRGB(59, 130, 246), size = 1.2 },
	{ id = "epic", weight = 6, power = 4.2, color = Color3.fromRGB(168, 85, 247), size = 1.35 },
	{ id = "legendary", weight = 1.8, power = 8, color = Color3.fromRGB(250, 204, 21), size = 1.5 },
	{ id = "mythic", weight = 0.2, power = 18, color = Color3.fromRGB(244, 63, 94), size = 1.7 },
} :: { Rarity }
-- Con suerte x2 (misiones), las 3 más raras pesan el doble
Config.LUCK_MULT = 2
Config.LUCK_FROM_INDEX = 5

-- Gran momento al abrir un huevo (índices de Config.Rarities: 5 = Épica, 6 = Legendaria, 7 = Mítica)
Config.HATCH_MEDIUM_FROM = 5 -- desde Épica: momento mediano (casi todos lo ven en ~3 min)
Config.HATCH_BIG_FROM = 6 -- desde Legendaria: gran momento + aviso a todo el servidor
Config.RARE_ANNOUNCE_COOLDOWN = 10 -- s entre avisos al servidor del mismo jugador (con x3 o Auto no hace spam)
Config.HATCH_SHOW_TIME = { 2.4, 3.5, 5 } -- s que dura la ventana: normal, mediano, grande
Config.HATCH_SHAKE_TIME = { 0.6, 0.9, 1.2 } -- s que tiembla el huevo antes de salir la cría

-- Fusión: 5 crías iguales → la siguiente versión. tier 0 normal, 1 Dorada, 2 Arcoíris
Config.FUSE_COUNT = 5
Config.TIER_MULT = { [0] = 1, [1] = 3, [2] = 9 } :: { [number]: number }
Config.MAX_TIER = 2

---------------------------------------------------------------------
-- Islas: cada una con su huevo de 7 crías (una por rareza, en el orden de Config.Rarities)
---------------------------------------------------------------------
export type Zone = {
	id: string, doorCost: number, pileHp: number, pileCoins: number, eggCost: number, petBase: number,
	grass: Color3, dirt: Color3, pets: { { id: string, emoji: string, color: Color3 } },
}
Config.Zones = ({
	{ id = "meadow", grass = Color3.fromRGB(110, 205, 95), dirt = Color3.fromRGB(150, 105, 70), pets = {
		{ id = "sprouty", emoji = "🌱", color = Color3.fromRGB(120, 210, 100) },
		{ id = "bunbun", emoji = "🐰", color = Color3.fromRGB(240, 235, 225) },
		{ id = "ladybop", emoji = "🐞", color = Color3.fromRGB(230, 60, 60) },
		{ id = "mosshog", emoji = "🦔", color = Color3.fromRGB(120, 150, 80) },
		{ id = "dewfrog", emoji = "🐸", color = Color3.fromRGB(80, 200, 140) },
		{ id = "cloverfawn", emoji = "🦌", color = Color3.fromRGB(200, 150, 90) },
		{ id = "dawngriffin", emoji = "🦅", color = Color3.fromRGB(255, 190, 110) },
	} },
	{ id = "mushroom", grass = Color3.fromRGB(70, 160, 90), dirt = Color3.fromRGB(110, 80, 60), pets = {
		{ id = "shroomlet", emoji = "🍄", color = Color3.fromRGB(220, 70, 70) },
		{ id = "acornowl", emoji = "🦉", color = Color3.fromRGB(160, 110, 70) },
		{ id = "mossfox", emoji = "🦊", color = Color3.fromRGB(230, 130, 60) },
		{ id = "rootmole", emoji = "🐹", color = Color3.fromRGB(140, 100, 80) },
		{ id = "sparksquirrel", emoji = "🐿️", color = Color3.fromRGB(200, 120, 60) },
		{ id = "fireflywolf", emoji = "🐺", color = Color3.fromRGB(120, 130, 160) },
		{ id = "forestspirit", emoji = "🧚", color = Color3.fromRGB(150, 255, 170) },
	} },
	{ id = "coral", grass = Color3.fromRGB(245, 220, 150), dirt = Color3.fromRGB(210, 170, 110), pets = {
		{ id = "crabby", emoji = "🦀", color = Color3.fromRGB(240, 90, 70) },
		{ id = "bubbleseal", emoji = "🦭", color = Color3.fromRGB(170, 180, 200) },
		{ id = "inkyocto", emoji = "🐙", color = Color3.fromRGB(200, 90, 200) },
		{ id = "shellturtle", emoji = "🐢", color = Color3.fromRGB(90, 170, 90) },
		{ id = "wavedolphin", emoji = "🐬", color = Color3.fromRGB(80, 160, 240) },
		{ id = "pearlhorse", emoji = "🦄", color = Color3.fromRGB(250, 220, 240) },
		{ id = "babykraken", emoji = "🦑", color = Color3.fromRGB(120, 60, 180) },
	} },
	{ id = "dunes", grass = Color3.fromRGB(240, 200, 110), dirt = Color3.fromRGB(200, 150, 80), pets = {
		{ id = "scarablet", emoji = "🐜", color = Color3.fromRGB(60, 140, 120) },
		{ id = "sandfennec", emoji = "🦊", color = Color3.fromRGB(240, 200, 140) },
		{ id = "datecamel", emoji = "🐫", color = Color3.fromRGB(200, 150, 90) },
		{ id = "sunlizard", emoji = "🦎", color = Color3.fromRGB(250, 170, 50) },
		{ id = "amberscorpion", emoji = "🦂", color = Color3.fromRGB(230, 140, 40) },
		{ id = "minisphinx", emoji = "🐈", color = Color3.fromRGB(230, 190, 90) },
		{ id = "miragebird", emoji = "🦚", color = Color3.fromRGB(80, 220, 220) },
	} },
	{ id = "volcano", grass = Color3.fromRGB(90, 80, 80), dirt = Color3.fromRGB(60, 50, 50), pets = {
		{ id = "sparky", emoji = "🔥", color = Color3.fromRGB(255, 140, 40) },
		{ id = "salamander", emoji = "🦎", color = Color3.fromRGB(230, 70, 40) },
		{ id = "lavamole", emoji = "🐹", color = Color3.fromRGB(180, 60, 40) },
		{ id = "ashbat", emoji = "🦇", color = Color3.fromRGB(90, 90, 100) },
		{ id = "magmabull", emoji = "🐂", color = Color3.fromRGB(200, 50, 30) },
		{ id = "emberdrake", emoji = "🐉", color = Color3.fromRGB(250, 100, 30) },
		{ id = "volcanophoenix", emoji = "🦜", color = Color3.fromRGB(255, 180, 40) },
	} },
	{ id = "glacier", grass = Color3.fromRGB(230, 245, 255), dirt = Color3.fromRGB(150, 190, 220), pets = {
		{ id = "pengy", emoji = "🐧", color = Color3.fromRGB(60, 70, 90) },
		{ id = "arcticfox", emoji = "🦊", color = Color3.fromRGB(245, 250, 255) },
		{ id = "frostwalrus", emoji = "🦭", color = Color3.fromRGB(170, 140, 120) },
		{ id = "snowowl", emoji = "🦉", color = Color3.fromRGB(240, 240, 250) },
		{ id = "icebear", emoji = "🐻", color = Color3.fromRGB(220, 235, 250) },
		{ id = "crystalyeti", emoji = "❄️", color = Color3.fromRGB(150, 220, 255) },
		{ id = "auroradragon", emoji = "🐲", color = Color3.fromRGB(120, 255, 200) },
	} },
	{ id = "clouds", grass = Color3.fromRGB(250, 250, 255), dirt = Color3.fromRGB(200, 210, 240), pets = {
		{ id = "puffy", emoji = "☁️", color = Color3.fromRGB(250, 250, 255) },
		{ id = "cloudlamb", emoji = "🐑", color = Color3.fromRGB(245, 240, 235) },
		{ id = "kitebird", emoji = "🐦", color = Color3.fromRGB(120, 180, 255) },
		{ id = "pegasling", emoji = "🐴", color = Color3.fromRGB(250, 230, 255) },
		{ id = "skywhale", emoji = "🐋", color = Color3.fromRGB(110, 150, 230) },
		{ id = "thundergriffin", emoji = "⚡", color = Color3.fromRGB(255, 230, 80) },
		{ id = "rainbowqilin", emoji = "🌈", color = Color3.fromRGB(255, 150, 200) },
	} },
	{ id = "cosmos", grass = Color3.fromRGB(70, 60, 130), dirt = Color3.fromRGB(40, 35, 80), pets = {
		{ id = "starlet", emoji = "⭐", color = Color3.fromRGB(255, 230, 100) },
		{ id = "mooncat", emoji = "🐱", color = Color3.fromRGB(200, 200, 230) },
		{ id = "jellyalien", emoji = "👽", color = Color3.fromRGB(130, 255, 130) },
		{ id = "robopup", emoji = "🤖", color = Color3.fromRGB(180, 190, 210) },
		{ id = "nebulajelly", emoji = "💫", color = Color3.fromRGB(200, 120, 255) },
		{ id = "cometdragon", emoji = "☄️", color = Color3.fromRGB(100, 200, 255) },
		{ id = "galaxytitan", emoji = "🌌", color = Color3.fromRGB(120, 80, 220) },
	} },
} :: any) :: { Zone } -- los números de cada isla se rellenan justo debajo

-- Números de cada isla (k = isla - 1): crecen igual en todas
Config.ZONE_GROWTH = { pileHp = 7, pileCoins = 9, eggCost = 8, petBase = 6, doorCost = 23 }
Config.ZONE_BASE = { pileHp = 12, pileCoins = 6, eggCost = 35, petBase = 3, doorCost = 1_800 }
for i, z in Config.Zones do
	local k = i - 1
	z.pileHp = math.floor(Config.ZONE_BASE.pileHp * Config.ZONE_GROWTH.pileHp ^ k)
	z.pileCoins = math.floor(Config.ZONE_BASE.pileCoins * Config.ZONE_GROWTH.pileCoins ^ k)
	z.eggCost = math.floor(Config.ZONE_BASE.eggCost * Config.ZONE_GROWTH.eggCost ^ k)
	z.petBase = Config.ZONE_BASE.petBase * Config.ZONE_GROWTH.petBase ^ k
	z.doorCost = if i == 1 then 0 else math.floor(Config.ZONE_BASE.doorCost * Config.ZONE_GROWTH.doorCost ^ (k - 1))
end

-- Montones: tipos (solo cambia el aspecto y cuánto aguantan / dan)
Config.PileKinds = {
	{ id = "coins", hp = 1, coins = 1, weight = 70 },
	{ id = "chest", hp = 3, coins = 3.3, weight = 22 },
	{ id = "crystal", hp = 8, coins = 9, weight = 8 },
}
-- Montón Dorado: cada GOLD_INTERVAL s, uno en la isla más alta abierta de cada jugador (sin repetir isla)
Config.GOLD_INTERVAL = 180 -- s. «Algo nuevo» cada 3 min sin agobiar
Config.GOLD_LIFETIME = 60 -- s. Si no se rompe, desaparece
Config.GOLD_MAX_SECONDS = 30 -- y como mucho 30 s del poder del jugador más fuerte de esa isla (si no, en islas altas caducaba)
Config.GOLD_HP = 10 -- × pileHp de la isla (un cristal es ×8): aguanta lo bastante para llegar y verlo
Config.GOLD_COINS = 33 -- × pileCoins de la isla = ×10 lo que da un Cofre (3,3) → rinde ×3,3 por punto de vida
Config.PILES_PER_ZONE = 32 -- zonas de 200×200: misma densidad que antes (y se ven muchos cristales)
Config.PILE_RESPAWN = 6 -- segundos
Config.REACH = 70 -- distancia máxima (studs) del jugador al montón para que sus crías piquen
Config.AUTO_REACH = 45 -- el modo automático busca montones a esta distancia
Config.EGG_REACH = 18 -- hay que estar al lado del huevo para abrirlo
Config.DOOR_REACH = 30

-- Ficha de cada cría (se rellena sola a partir de las islas)
export type Pet = { id: string, emoji: string, color: Color3, zone: number, rarity: number, power: number }
Config.Pets = {} :: { Pet }
Config.PetById = {} :: { [string]: Pet }
for zi, z in Config.Zones do
	for ri, p in z.pets do
		local pet: Pet = { id = p.id, emoji = p.emoji, color = p.color, zone = zi, rarity = ri, power = z.petBase * Config.Rarities[ri].power }
		table.insert(Config.Pets, pet)
		Config.PetById[p.id] = pet
	end
end
Config.STARTER_PET = "sprouty"

---------------------------------------------------------------------
-- Huecos, mochila, renacer, álbum
---------------------------------------------------------------------
Config.SLOTS_BASE = 3
Config.SLOTS_PASS = 3
Config.SLOTS_REBIRTH = { 1, 3, 5 } -- +1 hueco al llegar a estos renacimientos
Config.BACKPACK_BASE = 50
Config.BACKPACK_PER_REBIRTH = 25
Config.BACKPACK_PASS = 100
Config.REBIRTH_BONUS = 0.5 -- monedas x(1 + 0,5 por renacimiento)
Config.REBIRTH_MIN_ZONE = 4 -- 1.er renacer: isla 4; luego una isla más cada vez (máx. 8)
Config.REBIRTH_COST_MULT = 2 -- además cuesta monedas: 2 × la puerta de esa isla × 4^renacimientos
Config.REBIRTH_COST_GROWTH = 4

-- Álbum: % de entradas (cría × versión) descubiertas → bonus permanente de monedas al reclamar
Config.AlbumMilestones = {
	{ pct = 10, bonus = 0.05 },
	{ pct = 25, bonus = 0.10 },
	{ pct = 50, bonus = 0.15 },
	{ pct = 75, bonus = 0.20 },
	{ pct = 100, bonus = 0.50 },
}

---------------------------------------------------------------------
-- Diario, misiones, tutorial, sin conexión
---------------------------------------------------------------------
Config.OFFLINE_RATE = 0.25
Config.OFFLINE_MAX_HOURS = 8
Config.EFFICIENCY = 0.6 -- para premios en «minutos de monedas»: parte del tiempo se va en andar
-- Recompensa diaria (racha de 7): { minutos de monedas, mínimo }
Config.Daily = { { 5, 100 }, { 10, 250 }, { 15, 500 }, { 20, 1_000 }, { 30, 2_000 }, { 45, 4_000 }, { 60, 10_000 } }
Config.TUTORIAL_REWARD = 100

-- Misiones diarias: una fácil, una media y una difícil. stat = contador de stats; reward = minutos
Config.MissionPool = {
	easy = { { stat = "piles", n = 40 }, { stat = "hatched", n = 5 } },
	medium = { { stat = "piles", n = 200 }, { stat = "hatched", n = 25 }, { stat = "fused", n = 1 } },
	hard = { { stat = "piles", n = 500 }, { stat = "hatched", n = 70 }, { stat = "fused", n = 4 } },
}
Config.MissionReward = { easy = { 5, 150 }, medium = { 15, 600 }, hard = { 30, 2_000 } }
Config.MISSION_LUCK_MINUTES = 10 -- completar las 3 → suerte x2 durante 10 min

---------------------------------------------------------------------
-- Tienda (Robux). id = 0 → no se vende (sale «Próximamente»). price = precio recomendado
-- NO se venden huevos ni suerte: así no hay artículos aleatorios de pago.
---------------------------------------------------------------------
export type ShopItem = { key: string, id: number, emoji: string, price: number }
Config.GamePasses = {
	{ key = "x2", id = 0, emoji = "💰", price = 199 }, -- monedas x2 para siempre
	{ key = "slots", id = 0, emoji = "🐾", price = 249 }, -- +3 crías equipadas
	{ key = "hatch3", id = 0, emoji = "🥚", price = 199 }, -- abrir 3 huevos a la vez
	{ key = "autoHatch", id = 0, emoji = "🤖", price = 149 }, -- abrir huevos solo
	{ key = "backpack", id = 0, emoji = "🎒", price = 99 }, -- +100 de mochila
} :: { ShopItem }
Config.Products = {
	{ key = "cash_s", id = 0, emoji = "💵", price = 25 },
	{ key = "cash_l", id = 0, emoji = "🏦", price = 99 },
	{ key = "boost", id = 0, emoji = "⚡", price = 39 },
} :: { ShopItem }
Config.CashMinutes = { cash_s = 15, cash_l = 90 } :: { [string]: number }
Config.CASH_MIN = 500
Config.BOOST_MINUTES = 30

---------------------------------------------------------------------
-- Colores (tokens de diseño: úsalos siempre, no pongas colores sueltos)
---------------------------------------------------------------------
Config.Colors = {
	ink = Color3.fromRGB(30, 41, 59), -- texto principal sobre claro
	muted = Color3.fromRGB(100, 116, 139),
	white = Color3.fromRGB(255, 255, 255),
	panel = Color3.fromRGB(248, 250, 252),
	panelDark = Color3.fromRGB(226, 232, 240),
	sky = Color3.fromRGB(56, 189, 248),
	orange = Color3.fromRGB(249, 115, 22),
	orangeDark = Color3.fromRGB(194, 65, 12),
	blue = Color3.fromRGB(59, 130, 246),
	blueDark = Color3.fromRGB(29, 78, 216),
	green = Color3.fromRGB(34, 197, 94),
	greenDark = Color3.fromRGB(21, 128, 61),
	gold = Color3.fromRGB(250, 204, 21),
	goldDark = Color3.fromRGB(202, 138, 4),
	red = Color3.fromRGB(239, 68, 68),
	redDark = Color3.fromRGB(185, 28, 28),
	grey = Color3.fromRGB(148, 163, 184),
	greyDark = Color3.fromRGB(100, 116, 139),
	purple = Color3.fromRGB(168, 85, 247),
	purpleDark = Color3.fromRGB(107, 33, 168),
}

---------------------------------------------------------------------
-- Fórmulas (iguales en servidor y cliente)
-- bonuses = { x2, slots, hatch3, autoHatch, backpack: boolean, boost: boolean, luck: boolean,
--             friends: number, premium: boolean }
---------------------------------------------------------------------
function Config.petPower(kind: string, tier: number): number
	local p = Config.PetById[kind]
	if not p then
		return 0
	end
	return p.power * (Config.TIER_MULT[tier] or 1)
end

function Config.albumBonus(data: any): number
	local b = 0
	for i, m in Config.AlbumMilestones do
		if data.albumClaimed and data.albumClaimed[tostring(i)] then
			b += m.bonus
		end
	end
	return b
end

function Config.coinMult(data: any, bonuses: any): number
	local m = 1 + Config.REBIRTH_BONUS * (data.rebirths or 0)
	m *= 1 + Config.albumBonus(data)
	if bonuses.x2 then
		m *= 2
	end
	if bonuses.boost then
		m *= 2
	end
	m *= 1 + 0.1 * math.min(bonuses.friends or 0, 4)
	if bonuses.premium then
		m *= 1.1
	end
	return m
end

function Config.slots(data: any, bonuses: any): number
	local n = Config.SLOTS_BASE
	for _, r in Config.SLOTS_REBIRTH do
		if (data.rebirths or 0) >= r then
			n += 1
		end
	end
	if bonuses.slots then
		n += Config.SLOTS_PASS
	end
	return n
end

function Config.backpack(data: any, bonuses: any): number
	return Config.BACKPACK_BASE + Config.BACKPACK_PER_REBIRTH * (data.rebirths or 0) + (if bonuses.backpack then Config.BACKPACK_PASS else 0)
end

-- Isla que hay que tener abierta para el siguiente renacer
function Config.rebirthZone(rebirths: number): number
	return math.min(Config.REBIRTH_MIN_ZONE + rebirths, #Config.Zones)
end

-- Monedas que cuesta el siguiente renacer
function Config.rebirthCost(rebirths: number): number
	local z = Config.Zones[Config.rebirthZone(rebirths)]
	return math.floor(Config.REBIRTH_COST_MULT * z.doorCost * Config.REBIRTH_COST_GROWTH ^ rebirths)
end

-- Suma de poder de las crías equipadas
function Config.teamPower(data: any): number
	local byId = {}
	for _, p in data.pets do
		byId[p.uid] = p
	end
	local total = 0
	for _, uid in data.equipped do
		local p = byId[uid]
		if p then
			total += Config.petPower(p.kind, p.tier)
		end
	end
	return total
end

-- Monedas por punto de vida de los montones de una isla
function Config.coinsPerHp(zone: number): number
	local z = Config.Zones[math.clamp(zone, 1, #Config.Zones)]
	return z.pileCoins / z.pileHp
end

-- Monedas por segundo «típicas» (para premios en minutos y ganancias sin conexión)
function Config.coinRate(data: any, bonuses: any): number
	return Config.teamPower(data) * Config.coinsPerHp(data.zones or 1) * Config.coinMult(data, bonuses) * Config.EFFICIENCY
end

function Config.minutesReward(minutes: number, minimum: number, rate: number): number
	return math.max(minimum, math.floor(rate * 60 * minutes))
end

function Config.dailyReward(day: number, rate: number): number
	local d = Config.Daily[math.clamp(day, 1, #Config.Daily)]
	return Config.minutesReward(d[1], d[2], rate)
end

-- Probabilidades (en %) de cada cría de un huevo; con suerte las más raras pesan el doble
function Config.eggOdds(zone: number, luck: boolean): { number }
	local weights = {}
	local total = 0
	for i, r in Config.Rarities do
		local w = r.weight
		if luck and i >= Config.LUCK_FROM_INDEX then
			w *= Config.LUCK_MULT
		end
		weights[i] = w
		total += w
	end
	for i, w in weights do
		weights[i] = w / total * 100
	end
	return weights
end

-- Elige una cría del huevo de la isla. roll = número aleatorio en [0, 1)
function Config.rollPet(zone: number, luck: boolean, roll: number): string
	local odds = Config.eggOdds(zone, luck)
	local acc = 0
	local pets = Config.Zones[zone].pets
	for i, pct in odds do
		acc += pct / 100
		if roll < acc then
			return pets[i].id
		end
	end
	return pets[#pets].id
end

-- Álbum: total de entradas y cuántas tiene el jugador
function Config.albumTotal(): number
	return #Config.Pets * (Config.MAX_TIER + 1)
end
function Config.albumKey(kind: string, tier: number): string
	return kind .. ":" .. tier
end
function Config.albumCount(data: any): number
	local n = 0
	for _ in data.album do
		n += 1
	end
	return n
end

return Config
