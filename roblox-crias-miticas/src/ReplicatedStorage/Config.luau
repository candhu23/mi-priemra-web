--[[
	Config: TODOS los números del juego (rarezas, islas, crías, huevos, fusión, Brillantes, piedras, mejoras,
	álbum, misiones, tienda, colores) y las fórmulas que usan servidor y cliente. Para equilibrar el juego se
	toca solo este archivo. Ritmo medido con tools/harness/ritmo.luau (ver DISENO.md §5).
	Ficha: propuestas/2026-10-26-rarezas-arbol.md (8 rarezas por fusión, 72 crías, Jardín de Mejoras).
]]

local Config = {}

Config.VERSION = "0.3"
Config.GROUP_ID = 0 -- grupo de Roblox para el +10 % (0 = desactivado)

---------------------------------------------------------------------
-- Rarezas (orden fijo). Cada una tiene ×3 de poder que la anterior.
-- fuseNeed = cuántas iguales hacen falta para subir a la siguiente (0 = no se fusiona)
-- shinyPoints = lo que suma a la puntuación Brillante cada cría distinta de esa rareza en versión Brillante
---------------------------------------------------------------------
export type Rarity = {
	id: string, power: number, fuseNeed: number, color: Color3, size: number, aura: boolean, shinyPoints: number,
}
Config.Rarities = {
	{ id = "common", power = 1, fuseNeed = 5, color = Color3.fromRGB(148, 163, 184), size = 1, aura = false, shinyPoints = 1 },
	{ id = "uncommon", power = 3, fuseNeed = 5, color = Color3.fromRGB(34, 197, 94), size = 1.1, aura = false, shinyPoints = 2 },
	{ id = "rare", power = 9, fuseNeed = 5, color = Color3.fromRGB(59, 130, 246), size = 1.2, aura = false, shinyPoints = 4 },
	{ id = "epic", power = 27, fuseNeed = 5, color = Color3.fromRGB(168, 85, 247), size = 1.35, aura = true, shinyPoints = 8 },
	{ id = "legendary", power = 81, fuseNeed = 5, color = Color3.fromRGB(250, 204, 21), size = 1.5, aura = true, shinyPoints = 15 },
	{ id = "prodigious", power = 243, fuseNeed = 3, color = Color3.fromRGB(236, 72, 153), size = 1.7, aura = true, shinyPoints = 25 },
	{ id = "ascended", power = 729, fuseNeed = 3, color = Color3.fromRGB(34, 211, 238), size = 1.9, aura = true, shinyPoints = 40 },
	{ id = "mythic", power = 2187, fuseNeed = 0, color = Color3.fromRGB(244, 63, 94), size = 2.2, aura = true, shinyPoints = 60 },
} :: { Rarity }
Config.MYTHIC = #Config.Rarities -- la que da una Piedra de Renacimiento al crearla

-- Color del huevo de cada rareza (cáscara, manchas, cuántas manchas, luz). El huevo solo llega hasta Prodigioso
Config.EggColors = {
	{ shell = Color3.fromRGB(245, 245, 240), spots = Color3.fromRGB(200, 200, 195), spotCount = 5, glow = 0 },
	{ shell = Color3.fromRGB(110, 220, 120), spots = Color3.fromRGB(40, 150, 70), spotCount = 6, glow = 0 },
	{ shell = Color3.fromRGB(90, 160, 250), spots = Color3.fromRGB(30, 80, 200), spotCount = 7, glow = 0 },
	{ shell = Color3.fromRGB(180, 110, 245), spots = Color3.fromRGB(110, 40, 180), spotCount = 8, glow = 6 },
	{ shell = Color3.fromRGB(250, 205, 40), spots = Color3.fromRGB(255, 245, 190), spotCount = 9, glow = 10 },
	{ shell = Color3.fromRGB(236, 72, 153), spots = Color3.fromRGB(255, 200, 235), spotCount = 10, glow = 12 },
}

-- Brillante: 1 % al abrir, ×2 de poder. Se multiplica por la isla (zona 9 ×2), la suerte de misiones y la mejora
Config.SHINY_CHANCE = 0.01
Config.SHINY_POWER = 2
Config.LUCK_MULT = 2 -- «🍀 suerte x2» (completar las 3 misiones): duplica la probabilidad de Brillante

-- Gran momento al abrir: 1 normal (repetida) · 2 mediano (cría nueva en el Índice) · 3 grande + aviso a todos
-- (Brillante o crear una Mítica). Ver Config.hatchLevel
Config.RARE_ANNOUNCE_COOLDOWN = 10 -- s entre avisos al servidor del mismo jugador (con x3 o Auto no hace spam)
Config.HATCH_SHOW_TIME = { 2.4, 3.5, 5 } -- s que dura la ventana: normal, mediano, grande
Config.HATCH_SHAKE_TIME = { 0.6, 0.9, 1.2 } -- s que tiembla el huevo antes de salir la cría
Config.HATCH_COOLDOWN = 0.9 -- s entre aperturas (la mejora «Manos de Rocío» lo baja)

-- Fusión: fuseNeed crías de la misma isla, rareza y estado Brillante → la de la rareza siguiente de esa isla
Config.FUSE_ALL_MAX = 500 -- tope de fusiones por pulsación de «Fusionar todo»
Config.FUSE_NEEDS_ALTAR = true -- true = solo junto a un Altar de Fusión (pendiente de confirmar por el usuario)
Config.FUSE_REACH = 20 -- studs al altar

---------------------------------------------------------------------
-- Islas: huevo de UNA rareza (eggRarity) con una o varias especies; por encima, una cría por rareza (familia).
-- Puertas: needDiscovered = crías distintas en el Índice (de cualquier isla); la 9, needShiny = puntuación Brillante.
-- eggCost (monedas) de las islas 6–8: lo que más cambia cuándo llega la 1.ª Piedra (ver DISENO.md §5)
---------------------------------------------------------------------
export type PetDef = { id: string, rarity: number, emoji: string, model: string, color: Color3 }
export type Zone = {
	id: string, eggRarity: number, eggCost: number, petBase: number, needDiscovered: number?, needShiny: number?,
	shinyMult: number?, pileHp: number, pileCoins: number, crystalColors: { Color3 }, pets: { PetDef },
}
Config.Zones = ({
	{ id = "meadow", eggRarity = 1, eggCost = 50, petBase = 3, crystalColors = {
		Color3.fromRGB(120, 220, 255), Color3.fromRGB(140, 240, 120), Color3.fromRGB(255, 180, 110), Color3.fromRGB(255, 150, 200),
	}, pets = {
		{ id = "sproutchick", rarity = 1, emoji = "🐣", model = "Chick", color = Color3.fromRGB(255, 225, 90) },
		{ id = "cloverchick", rarity = 2, emoji = "🐥", model = "Chick", color = Color3.fromRGB(170, 220, 90) },
		{ id = "meadowsparrow", rarity = 3, emoji = "🐦", model = "Bird", color = Color3.fromRGB(190, 140, 90) },
		{ id = "dewblackbird", rarity = 4, emoji = "🐦", model = "Bird", color = Color3.fromRGB(70, 90, 150) },
		{ id = "sunhummer", rarity = 5, emoji = "🐦", model = "Bird", color = Color3.fromRGB(250, 190, 40) },
		{ id = "bloomeagle", rarity = 6, emoji = "🦅", model = "Eagle", color = Color3.fromRGB(240, 140, 190) },
		{ id = "dawneagle", rarity = 7, emoji = "🦅", model = "Eagle", color = Color3.fromRGB(255, 170, 110) },
		{ id = "meadowskylord", rarity = 8, emoji = "🦅", model = "Eagle", color = Color3.fromRGB(120, 230, 140) },
	} },
	{ id = "mushroom", eggRarity = 1, eggCost = 1_100, petBase = 35, needDiscovered = 3, crystalColors = {
		Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 100, 200), Color3.fromRGB(100, 150, 255), Color3.fromRGB(90, 230, 200),
	}, pets = {
		{ id = "mosskit", rarity = 1, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(200, 120, 60) },
		{ id = "capfox", rarity = 2, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(220, 70, 70) },
		{ id = "fernfox", rarity = 3, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(90, 170, 90) },
		{ id = "fireflyfox", rarity = 4, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(230, 230, 110) },
		{ id = "forestlynx", rarity = 5, emoji = "🐈", model = "Cat", color = Color3.fromRGB(190, 150, 90) },
		{ id = "sporecat", rarity = 6, emoji = "🐈", model = "Cat", color = Color3.fromRGB(180, 110, 220) },
		{ id = "shadewolf", rarity = 7, emoji = "🐺", model = "Wolf", color = Color3.fromRGB(90, 90, 130) },
		{ id = "elderwolf", rarity = 8, emoji = "🐺", model = "Wolf", color = Color3.fromRGB(150, 255, 170) },
	} },
	{ id = "coral", eggRarity = 2, eggCost = 300_000, petBase = 400, needDiscovered = 7, crystalColors = {
		Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 140, 110), Color3.fromRGB(80, 230, 220), Color3.fromRGB(200, 160, 255),
	}, pets = {
		{ id = "coralclown", rarity = 2, emoji = "🐠", model = "Fish", color = Color3.fromRGB(250, 130, 50) },
		{ id = "lagoontang", rarity = 2, emoji = "🐟", model = "Fish", color = Color3.fromRGB(60, 130, 240) },
		{ id = "bubblepuffer", rarity = 3, emoji = "🐡", model = "Fish", color = Color3.fromRGB(240, 220, 120) },
		{ id = "reefpiranha", rarity = 4, emoji = "🐟", model = "Piranha", color = Color3.fromRGB(230, 90, 90) },
		{ id = "pearlpiranha", rarity = 5, emoji = "🐟", model = "Piranha", color = Color3.fromRGB(245, 235, 250) },
		{ id = "foamcalf", rarity = 6, emoji = "🐳", model = "Whale", color = Color3.fromRGB(150, 210, 240) },
		{ id = "tidewhale", rarity = 7, emoji = "🐋", model = "Whale", color = Color3.fromRGB(60, 120, 210) },
		{ id = "coralleviathan", rarity = 8, emoji = "🐋", model = "Whale", color = Color3.fromRGB(255, 120, 200) },
	} },
	{ id = "dunes", eggRarity = 2, eggCost = 7_000_000, petBase = 4_500, needDiscovered = 11, crystalColors = {
		Color3.fromRGB(255, 160, 60), Color3.fromRGB(240, 100, 60), Color3.fromRGB(60, 210, 200), Color3.fromRGB(255, 130, 170),
	}, pets = {
		{ id = "dunellama", rarity = 2, emoji = "🦙", model = "Llama", color = Color3.fromRGB(235, 200, 140) },
		{ id = "oasisllama", rarity = 2, emoji = "🦙", model = "Llama", color = Color3.fromRGB(120, 200, 190) },
		{ id = "caravanllama", rarity = 3, emoji = "🦙", model = "Llama", color = Color3.fromRGB(200, 110, 70) },
		{ id = "sandstallion", rarity = 4, emoji = "🐎", model = "Horse", color = Color3.fromRGB(210, 170, 110) },
		{ id = "sunstallion", rarity = 5, emoji = "🐎", model = "Horse", color = Color3.fromRGB(250, 180, 40) },
		{ id = "miragezebra", rarity = 6, emoji = "🦓", model = "Zebra", color = Color3.fromRGB(120, 220, 230) },
		{ id = "amberzebra", rarity = 7, emoji = "🦓", model = "Zebra", color = Color3.fromRGB(230, 140, 40) },
		{ id = "pharaohzebra", rarity = 8, emoji = "🦓", model = "Zebra", color = Color3.fromRGB(250, 215, 90) },
	} },
	{ id = "volcano", eggRarity = 3, eggCost = 1.4e9, petBase = 50_000, needDiscovered = 16, crystalColors = {
		Color3.fromRGB(255, 90, 60), Color3.fromRGB(255, 150, 40), Color3.fromRGB(240, 60, 140), Color3.fromRGB(180, 80, 255),
	}, pets = {
		{ id = "emberpiglet", rarity = 3, emoji = "🐷", model = "Pig", color = Color3.fromRGB(250, 140, 60) },
		{ id = "ashpiglet", rarity = 3, emoji = "🐷", model = "Pig", color = Color3.fromRGB(130, 130, 140) },
		{ id = "lavapiglet", rarity = 3, emoji = "🐷", model = "Pig", color = Color3.fromRGB(220, 50, 40) },
		{ id = "magmaboar", rarity = 4, emoji = "🐗", model = "Pig", color = Color3.fromRGB(150, 50, 30) },
		{ id = "cinderbull", rarity = 5, emoji = "🐂", model = "Cow", color = Color3.fromRGB(70, 60, 60) },
		{ id = "flarebull", rarity = 6, emoji = "🐂", model = "Cow", color = Color3.fromRGB(255, 110, 40) },
		{ id = "obsidianbull", rarity = 7, emoji = "🐂", model = "Cow", color = Color3.fromRGB(60, 40, 90) },
		{ id = "volcanotitan", rarity = 8, emoji = "🐂", model = "Cow", color = Color3.fromRGB(255, 70, 30) },
	} },
	{ id = "glacier", eggRarity = 4, eggCost = 5e10, petBase = 190_000, needDiscovered = 21, crystalColors = {
		Color3.fromRGB(150, 230, 255), Color3.fromRGB(90, 150, 255), Color3.fromRGB(220, 245, 255), Color3.fromRGB(170, 140, 255),
	}, pets = {
		{ id = "frostpug", rarity = 4, emoji = "🐶", model = "Pug", color = Color3.fromRGB(190, 220, 250) },
		{ id = "snowpug", rarity = 4, emoji = "🐶", model = "Pug", color = Color3.fromRGB(245, 245, 250) },
		{ id = "sledpup", rarity = 4, emoji = "🐕", model = "Dog", color = Color3.fromRGB(170, 120, 80) },
		{ id = "icehound", rarity = 4, emoji = "🐕", model = "Dog", color = Color3.fromRGB(110, 170, 230) },
		{ id = "glacierhusky", rarity = 5, emoji = "🐕", model = "Dog", color = Color3.fromRGB(200, 215, 235) },
		{ id = "blizzardwolf", rarity = 6, emoji = "🐺", model = "Wolf", color = Color3.fromRGB(230, 240, 255) },
		{ id = "crystalwolf", rarity = 7, emoji = "🐺", model = "Wolf", color = Color3.fromRGB(140, 220, 255) },
		{ id = "polarwarden", rarity = 8, emoji = "🐺", model = "Wolf", color = Color3.fromRGB(120, 255, 220) },
	} },
	{ id = "clouds", eggRarity = 4, eggCost = 1.7e12, petBase = 2_100_000, needDiscovered = 27, crystalColors = {
		Color3.fromRGB(255, 170, 230), Color3.fromRGB(200, 170, 255), Color3.fromRGB(150, 210, 255), Color3.fromRGB(160, 250, 210),
	}, pets = {
		{ id = "cloudlamb", rarity = 4, emoji = "🐑", model = "Sheep", color = Color3.fromRGB(250, 250, 255) },
		{ id = "mistlamb", rarity = 4, emoji = "🐑", model = "Sheep", color = Color3.fromRGB(200, 210, 230) },
		{ id = "rainlamb", rarity = 4, emoji = "🐑", model = "Sheep", color = Color3.fromRGB(150, 190, 250) },
		{ id = "sunsetlamb", rarity = 4, emoji = "🐑", model = "Sheep", color = Color3.fromRGB(255, 180, 200) },
		{ id = "thunderram", rarity = 5, emoji = "🐏", model = "Sheep", color = Color3.fromRGB(255, 230, 90) },
		{ id = "skypony", rarity = 6, emoji = "🐴", model = "Horse", color = Color3.fromRGB(180, 210, 255) },
		{ id = "windpegasus", rarity = 7, emoji = "🐴", model = "Horse", color = Color3.fromRGB(230, 240, 255) },
		{ id = "stormpegasus", rarity = 8, emoji = "🐴", model = "Horse", color = Color3.fromRGB(140, 120, 255) },
	} },
	{ id = "cosmos", eggRarity = 5, eggCost = 3.6e13, petBase = 8_000_000, needDiscovered = 33, crystalColors = {
		Color3.fromRGB(170, 120, 255), Color3.fromRGB(90, 240, 255), Color3.fromRGB(255, 90, 220), Color3.fromRGB(230, 230, 255),
	}, pets = {
		{ id = "mooncat", rarity = 5, emoji = "🐱", model = "Cat", color = Color3.fromRGB(210, 210, 235) },
		{ id = "starcat", rarity = 5, emoji = "🐱", model = "Cat", color = Color3.fromRGB(255, 230, 100) },
		{ id = "cometcat", rarity = 5, emoji = "🐱", model = "Cat", color = Color3.fromRGB(100, 200, 255) },
		{ id = "nebulacat", rarity = 5, emoji = "🐱", model = "Cat", color = Color3.fromRGB(200, 120, 255) },
		{ id = "eclipsecat", rarity = 5, emoji = "🐱", model = "Cat", color = Color3.fromRGB(50, 40, 80) },
		{ id = "stardustwhale", rarity = 6, emoji = "🐋", model = "Whale", color = Color3.fromRGB(170, 130, 255) },
		{ id = "galaxywhale", rarity = 7, emoji = "🐋", model = "Whale", color = Color3.fromRGB(90, 60, 200) },
		{ id = "cosmoswhale", rarity = 8, emoji = "🐋", model = "Whale", color = Color3.fromRGB(255, 90, 220) },
	} },
	{ id = "aurora", eggRarity = 6, eggCost = 1e15, petBase = 90_000_000, needShiny = 200, shinyMult = 2, crystalColors = {
		Color3.fromRGB(90, 240, 200), Color3.fromRGB(255, 120, 220), Color3.fromRGB(120, 170, 255), Color3.fromRGB(200, 140, 255),
	}, pets = {
		{ id = "greenaurorafox", rarity = 6, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(90, 240, 160) },
		{ id = "pinkaurorafox", rarity = 6, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(255, 130, 200) },
		{ id = "blueaurorafox", rarity = 6, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(90, 170, 255) },
		{ id = "violetaurorafox", rarity = 6, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(170, 110, 255) },
		{ id = "goldaurorafox", rarity = 6, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(255, 210, 80) },
		{ id = "silveraurorafox", rarity = 6, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(220, 225, 240) },
		{ id = "borealwolf", rarity = 7, emoji = "🐺", model = "Wolf", color = Color3.fromRGB(120, 255, 230) },
		{ id = "celestialfox", rarity = 8, emoji = "🦊", model = "RedFox", color = Color3.fromRGB(255, 245, 255) },
	} },
} :: any) :: { Zone } -- la vida y las monedas de los cristales se rellenan justo debajo

-- Cristales de cada isla (k = isla - 1): monedas ×17,5 y vida ×7 → cada isla rinde ×2,5 por segundo con el mismo equipo
Config.ZONE_GROWTH = { pileHp = 7, pileCoins = 17.5 }
Config.ZONE_BASE = { pileHp = 12, pileCoins = 6 }
for i, z in Config.Zones do
	local k = i - 1
	z.pileHp = math.floor(Config.ZONE_BASE.pileHp * Config.ZONE_GROWTH.pileHp ^ k)
	z.pileCoins = math.floor(Config.ZONE_BASE.pileCoins * Config.ZONE_GROWTH.pileCoins ^ k)
end

-- Montones: tipos (solo cambia el aspecto y cuánto aguantan / dan). size = tamaño del cristal (×, el pequeño = 1)
Config.PileKinds = {
	{ id = "coins", hp = 1, coins = 1, weight = 70, size = 1 }, -- pequeño
	{ id = "chest", hp = 3, coins = 3.3, weight = 22, size = 1.3 }, -- mediano
	{ id = "crystal", hp = 8, coins = 9, weight = 8, size = 1.65 }, -- grande
}
Config.PILE_SIZE_JITTER = 0.12 -- ±12 % de tamaño al azar en cada cristal (que no sean todos iguales)
Config.GOLD_SIZE = 1.7 -- el Montón Dorado, algo mayor que el grande
-- «+🪙» flotante: tamaño de letra según lo que vale frente al premio típico de la isla (rel = 1 → base)
Config.FLOAT_TEXT = { base = 30, min = 22, max = 72, exp = 0.35 }
-- Montón Dorado: cada GOLD_INTERVAL s, uno en la isla más alta abierta de cada jugador (sin repetir isla)
Config.GOLD_INTERVAL = 180 -- s. «Algo nuevo» cada 3 min sin agobiar
Config.GOLD_LIFETIME = 60 -- s. Si no se rompe, desaparece
Config.GOLD_MAX_SECONDS = 30 -- y como mucho 30 s del poder del jugador más fuerte de esa isla (si no, en islas altas caducaba)
Config.GOLD_HP = 10 -- × pileHp de la isla (un cristal es ×8): aguanta lo bastante para llegar y verlo
Config.GOLD_COINS = 33 -- × pileCoins de la isla = ×10 lo que da un Cofre (3,3) → rinde ×3,3 por punto de vida
Config.PILES_PER_ZONE = 32 -- zonas de 200×200: misma densidad que antes (y se ven muchos cristales)
Config.PILE_RESPAWN = 6 -- segundos
-- Modelos 3D (Kenney, CC0) publicados por el usuario como Model en Roblox: su ID aquí (0 = usar ServerStorage.Modelos o piezas)
Config.MODELS_ASSET_ID = 0
Config.REACH = 70 -- distancia máxima (studs) del jugador al montón para que sus crías piquen
Config.AUTO_REACH = 45 -- el modo automático busca montones a esta distancia
Config.EGG_REACH = 18 -- hay que estar al lado del huevo para abrirlo
Config.DOOR_REACH = 30

-- Ficha de cada cría (se rellena sola a partir de las islas). power = sin Brillante ni mejoras
export type Pet = { id: string, emoji: string, color: Color3, model: string, zone: number, rarity: number, power: number }
Config.Pets = {} :: { Pet }
Config.PetById = {} :: { [string]: Pet }
for zi, z in Config.Zones do
	for _, p in z.pets do
		local pet: Pet = {
			id = p.id, emoji = p.emoji, color = p.color, model = p.model, zone = zi, rarity = p.rarity,
			power = z.petBase * Config.Rarities[p.rarity].power,
		}
		table.insert(Config.Pets, pet)
		Config.PetById[p.id] = pet
	end
end
Config.STARTER_PET = "sproutchick"

---------------------------------------------------------------------
-- Jardín de Mejoras: 12 pedestales que se compran UNA vez con Piedras de Renacimiento (1 por Mítica creada).
-- effects: coins (+% monedas), walk (+velocidad al andar), slots (+huecos), egg (−% coste de huevo),
-- bag (+mochila), power (+% poder), hatch (−s entre aperturas), shiny (+% probabilidad de Brillante).
-- req = las que hay que tener antes. pos = sitio del pedestal en el Jardín (studs desde su centro; ronda 2b)
---------------------------------------------------------------------
export type Upgrade = { id: string, emoji: string, cost: number, req: { string }, effects: { [string]: number }, pos: Vector2 }
Config.Upgrades = {
	{ id = "goldenroot", emoji = "🌱", cost = 1, req = {}, effects = { coins = 0.25 }, pos = Vector2.new(60, 0) },
	{ id = "swiftsprout", emoji = "👟", cost = 3, req = { "goldenroot" }, effects = { walk = 4 }, pos = Vector2.new(25, -45) },
	{ id = "buddybranch1", emoji = "🐾", cost = 8, req = { "goldenroot" }, effects = { slots = 1 }, pos = Vector2.new(25, 0) },
	{ id = "thriftynest", emoji = "🪺", cost = 5, req = { "goldenroot" }, effects = { egg = -0.2 }, pos = Vector2.new(25, 45) },
	{ id = "leafpouch", emoji = "🍃", cost = 10, req = { "swiftsprout" }, effects = { bag = 50 }, pos = Vector2.new(-10, -70) },
	{ id = "mightysap", emoji = "💪", cost = 20, req = { "buddybranch1" }, effects = { power = 0.25 }, pos = Vector2.new(-10, 0) },
	{ id = "dewyhands", emoji = "💧", cost = 15, req = { "thriftynest" }, effects = { hatch = -0.2 }, pos = Vector2.new(-10, 70) },
	{ id = "barkchest", emoji = "🎒", cost = 30, req = { "leafpouch" }, effects = { bag = 100 }, pos = Vector2.new(-45, -70) },
	{ id = "buddybranch2", emoji = "🐾", cost = 40, req = { "mightysap" }, effects = { slots = 1 }, pos = Vector2.new(-45, -25) },
	{ id = "goldenrain", emoji = "🌧️", cost = 50, req = { "mightysap", "thriftynest" }, effects = { coins = 0.5 }, pos = Vector2.new(-45, 25) },
	{ id = "sparklebloom", emoji = "✨", cost = 25, req = { "dewyhands" }, effects = { shiny = 0.5 }, pos = Vector2.new(-45, 70) },
	{ id = "gardencrown", emoji = "👑", cost = 100, req = { "buddybranch2", "goldenrain", "sparklebloom" }, effects = { slots = 1, power = 0.5 }, pos = Vector2.new(-80, 0) },
} :: { Upgrade }
Config.UpgradeById = {} :: { [string]: Upgrade }
for _, u in Config.Upgrades do
	Config.UpgradeById[u.id] = u
end
-- Se compran en su pedestal del Jardín (ProximityPrompt o la ventana «🌳 Mejoras» estando al lado):
-- buyUpgrade pide estar a ≤ UPGRADE_REACH del pedestal (World.pedestals). false = desde cualquier sitio
Config.UPGRADE_NEEDS_PEDESTAL = true
Config.UPGRADE_REACH = 14
Config.PROMPT_REACH = 12 -- distancia de los ProximityPrompt (pedestales y altares)

---------------------------------------------------------------------
-- Huecos, mochila, andar, álbum
---------------------------------------------------------------------
Config.SLOTS_BASE = 3
Config.SLOTS_PASS = 3
Config.BACKPACK_BASE = 50
Config.BACKPACK_PASS = 100
Config.WALK_SPEED = 16 -- la de Roblox; «Brote Veloz» la sube

-- Crías en 3D con los animales del pack (ReplicatedStorage.Modelos): altura del animal ×Rarities[r].size y giro
-- extra por si los modelos miran hacia atrás (si en Studio andan de espaldas: math.pi)
Config.PET_MODEL_HEIGHT = 2.4
Config.PET_MODEL_YAW = 0

-- Álbum (Índice): % de crías distintas descubiertas → bonus permanente de monedas al reclamar
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

-- Misiones diarias: una fácil, una media y una difícil. stat = contador de stats; reward = minutos.
-- «fused» cuenta cada fusión («Fusionar todo» puede sumar muchas de golpe)
Config.MissionPool = {
	easy = { { stat = "piles", n = 40 }, { stat = "hatched", n = 5 } },
	medium = { { stat = "piles", n = 200 }, { stat = "hatched", n = 25 }, { stat = "fused", n = 5 } },
	hard = { { stat = "piles", n = 500 }, { stat = "hatched", n = 70 }, { stat = "fused", n = 25 } },
}
Config.MissionReward = { easy = { 5, 150 }, medium = { 15, 600 }, hard = { 30, 2_000 } }
Config.MISSION_LUCK_MINUTES = 10 -- completar las 3 → suerte x2 (Brillante) durante 10 min

---------------------------------------------------------------------
-- Tienda (Robux). id = 0 → no se vende (sale «Próximamente»). price = precio recomendado
-- NO se venden huevos, suerte, piedras ni mejoras: así no hay artículos aleatorios de pago.
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
-- Fórmulas (iguales en servidor y cliente). data = partida (o el estado que recibe el cliente: lleva
-- pets, equipped, upgrades, album, shinyIndex, albumClaimed, zones).
-- bonuses = { x2, slots, hatch3, autoHatch, backpack: boolean, boost: boolean, luck: boolean,
--             friends: number, premium: boolean }
---------------------------------------------------------------------

-- Suma de un efecto de las mejoras compradas (p. ej. "coins" → 0,75 si tiene Raíz Dorada y Lluvia de Oro)
function Config.upgradeBonus(data: any, effect: string): number
	local total = 0
	local owned = data.upgrades or {}
	for _, u in Config.Upgrades do
		if owned[u.id] then
			total += u.effects[effect] or 0
		end
	end
	return total
end

function Config.petPower(kind: string, shiny: boolean?): number
	local p = Config.PetById[kind]
	if not p then
		return 0
	end
	return p.power * (if shiny then Config.SHINY_POWER else 1)
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
	local m = 1 + Config.upgradeBonus(data, "coins")
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
	return Config.SLOTS_BASE + Config.upgradeBonus(data, "slots") + (if bonuses.slots then Config.SLOTS_PASS else 0)
end

function Config.backpack(data: any, bonuses: any): number
	return Config.BACKPACK_BASE + Config.upgradeBonus(data, "bag") + (if bonuses.backpack then Config.BACKPACK_PASS else 0)
end

function Config.eggCost(zone: number, data: any): number
	local z = Config.Zones[zone]
	return math.floor(z.eggCost * (1 + Config.upgradeBonus(data, "egg")) + 0.5) -- redondeado (0,8 × 50 no debe dar 39)
end

function Config.hatchCooldown(data: any): number
	return math.max(0.3, Config.HATCH_COOLDOWN + Config.upgradeBonus(data, "hatch"))
end

function Config.walkSpeed(data: any): number
	return Config.WALK_SPEED + Config.upgradeBonus(data, "walk")
end

-- Suma de poder de las crías equipadas (con Brillante y mejoras de poder)
function Config.teamPower(data: any): number
	local byId = {}
	for _, p in data.pets do
		byId[p.uid] = p
	end
	local total = 0
	for _, uid in data.equipped do
		local p = byId[uid]
		if p then
			total += Config.petPower(p.kind, p.shiny)
		end
	end
	return total * (1 + Config.upgradeBonus(data, "power"))
end

-- Monedas por punto de vida de los montones de una isla
function Config.coinsPerHp(zone: number): number
	local z = Config.Zones[math.clamp(zone, 1, #Config.Zones)]
	return z.pileCoins / z.pileHp
end

-- Lo que da de media un montón normal de la isla (según el peso de cada tipo), sin multiplicadores
function Config.pileTypicalCoins(zone: number): number
	local z = Config.Zones[math.clamp(zone, 1, #Config.Zones)]
	local total, sum = 0, 0
	for _, k in Config.PileKinds do
		total += k.weight
		sum += k.weight * k.coins
	end
	return z.pileCoins * sum / total
end

-- Cuántas veces más monedas por punto de vida dan los cristales de una isla que los de la isla 1 (cartel de la puerta)
function Config.zoneCrystalMult(zone: number): number
	return Config.coinsPerHp(zone) / Config.coinsPerHp(1)
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

-- Especies que da el huevo de una isla (las de su rareza), en orden
function Config.eggSpecies(zone: number): { Pet }
	local z = Config.Zones[zone]
	local list = {}
	for _, p in Config.Pets do
		if p.zone == zone and p.rarity == z.eggRarity then
			table.insert(list, p)
		end
	end
	return list
end

-- Probabilidad (0–1) de que una apertura salga Brillante
function Config.shinyChance(zone: number, data: any, bonuses: any): number
	local z = Config.Zones[zone]
	local luck = if bonuses and bonuses.luck then Config.LUCK_MULT else 1
	return Config.SHINY_CHANCE * (z.shinyMult or 1) * luck * (1 + Config.upgradeBonus(data, "shiny"))
end

-- Probabilidades visibles del huevo (en %): cada especie y la de salir Brillante
function Config.eggOdds(zone: number, data: any, bonuses: any): { species: { { kind: string, pct: number } }, shinyPct: number }
	local species = {}
	local list = Config.eggSpecies(zone)
	for _, p in list do
		table.insert(species, { kind = p.id, pct = 100 / #list })
	end
	return { species = species, shinyPct = Config.shinyChance(zone, data, bonuses) * 100 }
end

-- Elige una especie del huevo de la isla. roll = número aleatorio en [0, 1) (todas igual de probables)
function Config.rollPet(zone: number, roll: number): string
	local list = Config.eggSpecies(zone)
	return list[math.clamp(math.floor(roll * #list) + 1, 1, #list)].id
end

-- ¿Sale Brillante? roll = número aleatorio en [0, 1)
function Config.rollShiny(zone: number, data: any, bonuses: any, roll: number): boolean
	return roll < Config.shinyChance(zone, data, bonuses)
end

-- La cría que sale al fusionar crías de esa isla y rareza (la única de la rareza siguiente), o nil
function Config.fuseResult(zone: number, rarity: number): string?
	if rarity >= Config.MYTHIC then
		return nil
	end
	for _, p in Config.Pets do
		if p.zone == zone and p.rarity == rarity + 1 then
			return p.id
		end
	end
	return nil
end

-- Nivel del momento al conseguir una cría: 3 = Brillante o Mítica, 2 = nueva en el Índice, 1 = repetida
function Config.hatchLevel(h: any): number
	if h.shiny or h.rarity == Config.MYTHIC then
		return 3
	elseif h.new then
		return 2
	end
	return 1
end

-- Álbum (Índice): una entrada por cría (72). Las Brillantes se cuentan aparte (shinyIndex) para la puntuación
function Config.albumTotal(): number
	return #Config.Pets
end
function Config.albumCount(data: any): number
	local n = 0
	for kind in data.album do
		if Config.PetById[kind] then
			n += 1
		end
	end
	return n
end

-- Puntuación Brillante: suma de shinyPoints de cada cría DISTINTA que has tenido Brillante (no baja nunca)
function Config.shinyScore(data: any): number
	local n = 0
	for kind in (data.shinyIndex or {}) do
		local p = Config.PetById[kind]
		if p then
			n += Config.Rarities[p.rarity].shinyPoints
		end
	end
	return n
end

-- Lo que pide la puerta de una isla: (cumple, "index"|"shiny", cuánto pide, cuánto tienes)
function Config.zoneNeed(data: any, zone: number): (boolean, string, number, number)
	local z = Config.Zones[zone]
	if z.needShiny then
		local have = Config.shinyScore(data)
		return have >= z.needShiny, "shiny", z.needShiny, have
	end
	local need = z.needDiscovered or 0
	local have = Config.albumCount(data)
	return have >= need, "index", need, have
end

-- «Soltar repetidas»: uids que se pueden soltar sin perder nada importante. Solo crías normales (nunca Brillantes),
-- sin equipar, Míticas (ya no se fusionan) o de islas anteriores a la más alta abierta; y siempre se queda al menos
-- una normal de cada especie
function Config.dupesToRelease(data: any): { number }
	local eq = {}
	for _, uid in data.equipped do
		eq[uid] = true
	end
	local normals = {}
	for _, p in data.pets do
		if not p.shiny then
			normals[p.kind] = (normals[p.kind] or 0) + 1
		end
	end
	local list = {}
	-- De atrás adelante: se sueltan las más nuevas y se queda la más antigua
	for i = #data.pets, 1, -1 do
		local p = data.pets[i]
		local def = Config.PetById[p.kind]
		if def and not p.shiny and not eq[p.uid] and (def.rarity == Config.MYTHIC or def.zone < (data.zones or 1)) and normals[p.kind] > 1 then
			normals[p.kind] -= 1
			table.insert(list, p.uid)
		end
	end
	return list
end

-- ¿Puede comprar esta mejora? (sí, clave del error si no, parámetros del error)
function Config.canBuyUpgrade(data: any, id: string): (boolean, string?, { [string]: any }?)
	local u = Config.UpgradeById[id]
	if not u then
		return false, nil, nil
	end
	local owned = data.upgrades or {}
	if owned[id] then
		return false, "n_upgrade_owned", nil
	end
	for _, r in u.req do
		if not owned[r] then
			return false, "n_need_upgrade", { upgrade = r }
		end
	end
	if (data.stones or 0) < u.cost then
		return false, "n_need_stones", { n = u.cost - (data.stones or 0) }
	end
	return true, nil, nil
end

return Config
