--[[
	GameConfig (ModuleScript en ReplicatedStorage)

	TODOS los datos y fórmulas de Dungeon Ascend (estilo "survivors"):
	armas automáticas, mejoras de partida y evoluciones, clases, mapas con
	sus oleadas, enemigos, jefes, mejoras permanentes, objetos (mochila y
	forja), rarezas, recompensas y tienda.
	Lo usan el servidor y el cliente, así que los dos calculan lo mismo.
]]

local Config = {}

Config.VERSION = "0.2"
Config.DATASTORE_NAME = "DungeonAscend_v2"
Config.LEADERBOARD_NAME = "DungeonAscendKills_v2"
Config.AUTOSAVE_INTERVAL = 60
Config.MANUAL_SAVE_COOLDOWN = 30
Config.LEADERBOARD_REFRESH = 120
Config.WALK_SPEED = 20
Config.RESPAWN_TIME = 4

---------------------------------------------------------------------
-- Partida (run)
---------------------------------------------------------------------
Config.ARENA_HALF = 140 -- la arena mide 280 × 280
Config.ARENA_SLOTS = 8 -- partidas a la vez en un servidor
Config.MAX_GROUP = 4
Config.BASE_HEALTH = 100
Config.SPAWN_DISTANCE = { 42, 58 } -- los enemigos aparecen a esta distancia de algún jugador
Config.PICKUP_RADIUS = 9
Config.CONTACT_COOLDOWN = 1 -- cada enemigo golpea como mucho una vez por segundo
Config.DASH_COOLDOWN = 2.5
Config.DASH_INVULNERABLE = 0.35
Config.CHOICE_TIMEOUT = 12 -- si no eliges mejora en 12 s, se elige sola
Config.SLOWMO = 0.15 -- velocidad de tus enemigos mientras eliges mejora
Config.PORTAL_RADIUS = 7
Config.ESCAPE_TIME = 60 -- segundos para escapar por el portal tras vencer al jefe
Config.MAX_WEAPONS = 4
Config.MAX_PASSIVES = 4
Config.MAX_ITEM_LEVEL = 5
Config.LOSS_GOLD_RATE = 0.5 -- si caes o abandonas te quedas la mitad del oro
Config.WIN_BONUS = 0.5 -- +50 % de oro al escapar
Config.BASE_REROLLS = 1
Config.MAX_ENEMIES = 200 -- tope por partida (rendimiento)
Config.MAX_GEMS = 220
Config.HEART_CHANCE = 0.008 -- corazón que cura
Config.HEART_HEAL = 0.3
Config.REVIVE_INVULNERABLE = 3

-- XP que necesita el EQUIPO para subir del nivel L al L+1 (más jugadores → más XP)
function Config.xpToNext(level: number, players: number): number
	return math.floor((3 + 2 * level ^ 1.35) * (1 + 0.5 * (players - 1)))
end

---------------------------------------------------------------------
-- Armas automáticas (niveles 1-5 + evolución)
---------------------------------------------------------------------
-- kind: slash (tajo delante) · bolt (proyectil al más cercano) · dagger (en línea,
-- atraviesa) · aura (daño continuo alrededor) · orbit (orbes que giran) · lightning (rayos)
Config.Weapons = {
	espada = {
		name = "Espada", emoji = "⚔️", kind = "slash", color = Color3.fromRGB(226, 232, 240),
		desc = "Tajo circular a tu alrededor.",
		levels = {
			{ damage = 14, cooldown = 1.1, radius = 7.5, full = true },
			{ damage = 20, cooldown = 1.05, radius = 8.2, full = true },
			{ damage = 26, cooldown = 1.0, radius = 9, full = true },
			{ damage = 33, cooldown = 0.95, radius = 10, full = true },
			{ damage = 42, cooldown = 0.9, radius = 11, full = true },
		},
		evolution = { passive = "fuerza", name = "Hoja del Rey", emoji = "👑", damage = 75, cooldown = 0.75, radius = 16, full = true },
	},
	varita = {
		name = "Varita mágica", emoji = "🪄", kind = "bolt", color = Color3.fromRGB(167, 139, 250),
		desc = "Dispara al enemigo más cercano.",
		levels = {
			{ damage = 12, cooldown = 1.2, count = 1, range = 40 },
			{ damage = 16, cooldown = 1.1, count = 1, range = 42 },
			{ damage = 20, cooldown = 1.05, count = 2, range = 44 },
			{ damage = 25, cooldown = 1.0, count = 2, range = 46 },
			{ damage = 31, cooldown = 0.9, count = 3, range = 48 },
		},
		evolution = { passive = "rapidez", name = "Bastón del Archimago", emoji = "🔮", damage = 45, cooldown = 0.5, count = 4, range = 55 },
	},
	dagas = {
		name = "Dagas", emoji = "🗡️", kind = "dagger", color = Color3.fromRGB(203, 213, 225),
		desc = "Lanza dagas al enemigo más cercano; atraviesan.",
		levels = {
			{ damage = 10, cooldown = 1.0, count = 1, pierce = 3, length = 34 },
			{ damage = 13, cooldown = 0.95, count = 2, pierce = 3, length = 36 },
			{ damage = 17, cooldown = 0.9, count = 2, pierce = 4, length = 38 },
			{ damage = 21, cooldown = 0.85, count = 3, pierce = 5, length = 40 },
			{ damage = 26, cooldown = 0.8, count = 3, pierce = 6, length = 42 },
		},
		evolution = { passive = "botas", name = "Tormenta de Dagas", emoji = "🌪️", damage = 40, cooldown = 0.45, count = 5, pierce = 99, length = 50 },
	},
	aura = {
		name = "Aura sagrada", emoji = "✨", kind = "aura", color = Color3.fromRGB(253, 224, 71),
		desc = "Quema a los enemigos que se acercan.",
		levels = {
			{ damage = 5, cooldown = 0.5, radius = 6 },
			{ damage = 7, cooldown = 0.5, radius = 6.8 },
			{ damage = 9, cooldown = 0.45, radius = 7.6 },
			{ damage = 12, cooldown = 0.45, radius = 8.4 },
			{ damage = 15, cooldown = 0.4, radius = 9.5 },
		},
		evolution = { passive = "vida", name = "Santuario", emoji = "🌟", damage = 26, cooldown = 0.35, radius = 13, heal = 1 },
	},
	orbes = {
		name = "Orbes", emoji = "🔵", kind = "orbit", color = Color3.fromRGB(56, 189, 248),
		desc = "Esferas que giran a tu alrededor.",
		levels = {
			{ damage = 11, count = 1, orbit = 7, speed = 2.6 },
			{ damage = 14, count = 2, orbit = 7.3, speed = 2.7 },
			{ damage = 18, count = 3, orbit = 7.6, speed = 2.8 },
			{ damage = 22, count = 3, orbit = 8, speed = 3 },
			{ damage = 27, count = 4, orbit = 8.5, speed = 3.1 },
		},
		evolution = { passive = "area", name = "Galaxia", emoji = "🌌", damage = 40, count = 7, orbit = 11, speed = 3.4 },
	},
	rayo = {
		name = "Relámpago", emoji = "⚡", kind = "lightning", color = Color3.fromRGB(125, 211, 252),
		desc = "Rayos que caen sobre enemigos al azar.",
		levels = {
			{ damage = 26, cooldown = 2.6, count = 1, aoe = 4, range = 36 },
			{ damage = 34, cooldown = 2.4, count = 2, aoe = 4.2, range = 38 },
			{ damage = 42, cooldown = 2.2, count = 2, aoe = 4.6, range = 40 },
			{ damage = 52, cooldown = 2.0, count = 3, aoe = 5, range = 42 },
			{ damage = 64, cooldown = 1.8, count = 3, aoe = 5.5, range = 44 },
		},
		evolution = { passive = "iman", name = "Tormenta Eterna", emoji = "🌩️", damage = 90, cooldown = 1.1, count = 6, aoe = 7, range = 50 },
	},
}
Config.WeaponOrder = { "espada", "varita", "dagas", "aura", "orbes", "rayo" }
for id, weapon in Config.Weapons do
	weapon.id = id
end

-- Estadísticas de un arma en un nivel (6 = evolucionada)
function Config.weaponStats(weaponId: string, level: number): any
	local weapon = Config.Weapons[weaponId]
	if level > Config.MAX_ITEM_LEVEL then
		return weapon.evolution
	end
	return weapon.levels[math.clamp(level, 1, Config.MAX_ITEM_LEVEL)]
end

---------------------------------------------------------------------
-- Mejoras pasivas de partida (niveles 1-5)
---------------------------------------------------------------------
-- value = efecto por nivel
Config.Passives = {
	fuerza = { name = "Fuerza", emoji = "💪", value = 0.1, desc = "+10 % de daño" },
	rapidez = { name = "Rapidez", emoji = "⏱️", value = 0.07, desc = "-7 % de recarga" },
	area = { name = "Área", emoji = "⭕", value = 0.1, desc = "+10 % de alcance" },
	vida = { name = "Vida", emoji = "❤️", value = 20, desc = "+20 de vida máxima" },
	botas = { name = "Botas", emoji = "👟", value = 0.07, desc = "+7 % de velocidad" },
	iman = { name = "Imán", emoji = "🧲", value = 0.25, desc = "+25 % de radio para recoger" },
	armadura = { name = "Armadura", emoji = "🛡️", value = 0.05, desc = "-5 % de daño recibido" },
	regeneracion = { name = "Regeneración", emoji = "💚", value = 0.5, desc = "+0,5 de vida por segundo" },
}
Config.PassiveOrder = { "fuerza", "rapidez", "area", "vida", "botas", "iman", "armadura", "regeneracion" }
for id, passive in Config.Passives do
	passive.id = id
end

---------------------------------------------------------------------
-- Clases (se compran con oro)
---------------------------------------------------------------------
Config.Classes = {
	{ id = "guerrero", name = "Guerrero", emoji = "🛡️", weapon = "espada", price = 0, health = 30, desc = "Empieza con Espada. +30 de vida." },
	{ id = "mago", name = "Mago", emoji = "🧙", weapon = "varita", price = 2000, area = 0.1, desc = "Empieza con Varita mágica. +10 % de alcance." },
	{ id = "picaro", name = "Pícaro", emoji = "🥷", weapon = "dagas", price = 5000, speed = 0.1, desc = "Empieza con Dagas. +10 % de velocidad." },
}
Config.ClassById = {}
for _, class in Config.Classes do
	Config.ClassById[class.id] = class
end

---------------------------------------------------------------------
-- Mejoras permanentes (se compran con oro en el lobby)
---------------------------------------------------------------------
Config.MetaUpgrades = {
	{ id = "fuerza", name = "Fuerza", emoji = "💪", max = 10, base = 150, value = 0.05, desc = "+5 % de daño por nivel" },
	{ id = "vida", name = "Vitalidad", emoji = "❤️", max = 10, base = 150, value = 10, desc = "+10 de vida por nivel" },
	{ id = "velocidad", name = "Agilidad", emoji = "👟", max = 10, base = 200, value = 0.03, desc = "+3 % de velocidad por nivel" },
	{ id = "iman", name = "Imán", emoji = "🧲", max = 10, base = 120, value = 0.1, desc = "+10 % de radio para recoger" },
	{ id = "recarga", name = "Concentración", emoji = "⏱️", max = 10, base = 300, value = 0.02, desc = "-2 % de recarga por nivel" },
	{ id = "regen", name = "Recuperación", emoji = "💚", max = 10, base = 200, value = 0.2, desc = "+0,2 de vida por segundo" },
	{ id = "oro", name = "Avaricia", emoji = "🪙", max = 10, base = 250, value = 0.05, desc = "+5 % de oro por nivel" },
	{ id = "vidas", name = "Segunda vida", emoji = "💖", max = 2, base = 3000, value = 1, growth = 4, desc = "Revives solo una vez más por partida" },
}
Config.MetaById = {}
for _, upgrade in Config.MetaUpgrades do
	Config.MetaById[upgrade.id] = upgrade
end

function Config.metaCost(upgradeId: string, level: number): number
	local upgrade = Config.MetaById[upgradeId]
	return math.floor(upgrade.base * (upgrade.growth or 1.6) ^ level)
end

---------------------------------------------------------------------
-- Rarezas (probabilidades visibles en el juego)
---------------------------------------------------------------------
-- bossWeight = cofre del jefe al escapar · chestWeight = cofre de la forja
Config.Rarities = {
	{ id = "comun", name = "Común", color = Color3.fromRGB(176, 186, 197), mult = 1.0, bossWeight = 0, chestWeight = 50 },
	{ id = "pococomun", name = "Poco común", color = Color3.fromRGB(74, 222, 128), mult = 1.3, bossWeight = 40, chestWeight = 30 },
	{ id = "raro", name = "Raro", color = Color3.fromRGB(56, 189, 248), mult = 1.7, bossWeight = 40, chestWeight = 14 },
	{ id = "epico", name = "Épico", color = Color3.fromRGB(192, 132, 252), mult = 2.3, bossWeight = 16, chestWeight = 5 },
	{ id = "legendario", name = "Legendario", color = Color3.fromRGB(251, 191, 36), mult = 3.2, bossWeight = 4, chestWeight = 1 },
}
Config.RarityById = {}
for i, rarity in Config.Rarities do
	rarity.index = i
	Config.RarityById[rarity.id] = rarity
end

-- Probabilidad (0-1) de cada rareza según la tabla elegida ("bossWeight", "chestWeight")
function Config.rarityChance(rarityId: string, field: string): number
	local total = 0
	for _, rarity in Config.Rarities do
		total += rarity[field]
	end
	return Config.RarityById[rarityId][field] / total
end

---------------------------------------------------------------------
-- Objetos de la mochila (bonus permanentes mientras están equipados)
---------------------------------------------------------------------
Config.Slots = {
	{ id = "weapon", name = "Arma", emoji = "⚔️", stat = "% de daño" },
	{ id = "armor", name = "Armadura", emoji = "🛡️", stat = "vida" },
	{ id = "amulet", name = "Amuleto", emoji = "📿", stat = "% de oro" },
}

-- base = % de daño (arma), vida (armadura) o % de oro (amuleto)
Config.Items = {
	espada_madera = { name = "Espada de madera", slot = "weapon", tier = 0, base = 3, color = Color3.fromRGB(161, 120, 74) },

	espada_hierro = { name = "Espada de hierro", slot = "weapon", tier = 1, base = 8, color = Color3.fromRGB(190, 196, 204) },
	cota_cuero = { name = "Armadura de cuero", slot = "armor", tier = 1, base = 15, color = Color3.fromRGB(140, 94, 58) },
	amuleto_cobre = { name = "Amuleto de cobre", slot = "amulet", tier = 1, base = 5, color = Color3.fromRGB(205, 127, 50) },

	hacha_cristal = { name = "Hacha de cristal", slot = "weapon", tier = 2, base = 18, color = Color3.fromRGB(125, 211, 252) },
	armadura_cristal = { name = "Armadura de cristal", slot = "armor", tier = 2, base = 35, color = Color3.fromRGB(103, 232, 249) },
	amuleto_amatista = { name = "Amuleto de amatista", slot = "amulet", tier = 2, base = 10, color = Color3.fromRGB(167, 139, 250) },

	guadana_sombria = { name = "Guadaña sombría", slot = "weapon", tier = 3, base = 35, color = Color3.fromRGB(88, 28, 135) },
	armadura_hueso = { name = "Armadura de hueso", slot = "armor", tier = 3, base = 70, color = Color3.fromRGB(231, 229, 228) },
	amuleto_almas = { name = "Amuleto de almas", slot = "amulet", tier = 3, base = 18, color = Color3.fromRGB(45, 212, 191) },
}
for id, item in Config.Items do
	item.id = id
end
Config.STARTER_WEAPON = "espada_madera"

Config.MAX_UPGRADE = 10
Config.UPGRADE_STEP = 0.12 -- +12 % de poder por cada mejora en la forja
Config.TierPrice = { [0] = 30, 120, 900, 6000 }
Config.UPGRADE_GROWTH = 1.4
Config.INVENTORY_SIZE = 30
Config.INVENTORY_PASS_BONUS = 40

export type Item = { id: number, def: string, rarity: string, up: number }

function Config.itemPower(item: Item): number
	local def = Config.Items[item.def]
	local rarity = Config.RarityById[item.rarity]
	if not def or not rarity then
		return 0
	end
	local power = def.base * rarity.mult * (1 + Config.UPGRADE_STEP * item.up)
	return math.floor(power * 10 + 0.5) / 10
end

-- Precio de mejorar el objeto de +up a +(up+1)
function Config.upgradeCost(item: Item): number
	local def = Config.Items[item.def]
	local rarity = Config.RarityById[item.rarity]
	return math.floor(Config.TierPrice[def.tier] * rarity.mult * Config.UPGRADE_GROWTH ^ item.up)
end

function Config.sellPrice(item: Item): number
	local def = Config.Items[item.def]
	local rarity = Config.RarityById[item.rarity]
	return math.floor(Config.TierPrice[def.tier] * rarity.mult * 0.25 * (1 + 0.6 * item.up))
end

-- Texto corto del poder: "+12 % de daño", "+30 de vida", "+8.5 % de oro"
function Config.powerText(item: Item): string
	local def = Config.Items[item.def]
	local power = Config.itemPower(item)
	if def.slot == "weapon" then
		return "+" .. power .. " % de daño"
	elseif def.slot == "armor" then
		return "+" .. power .. " de vida"
	end
	return "+" .. power .. " % de oro"
end

---------------------------------------------------------------------
-- Estadísticas permanentes del jugador (clase + mejoras + equipo)
---------------------------------------------------------------------
export type Stats = {
	damage: number, -- multiplicador
	health: number, -- vida máxima
	speed: number, -- multiplicador
	area: number, -- multiplicador
	cooldown: number, -- multiplicador (menos es mejor)
	magnet: number, -- multiplicador
	regen: number, -- vida por segundo
	gold: number, -- multiplicador
	lives: number, -- vidas extra por partida
}

function Config.baseStats(classId: string, upgrades: { [string]: number }, equipped: { [string]: Item? }): Stats
	local class = Config.ClassById[classId] or Config.Classes[1]
	local function meta(id: string): number
		return (upgrades[id] or 0) * Config.MetaById[id].value
	end
	local weapon = equipped.weapon
	local armor = equipped.armor
	local amulet = equipped.amulet
	return {
		damage = 1 + meta("fuerza") + (if weapon then Config.itemPower(weapon) / 100 else 0),
		health = Config.BASE_HEALTH + (class.health or 0) + meta("vida") + (if armor then Config.itemPower(armor) else 0),
		speed = 1 + (class.speed or 0) + meta("velocidad"),
		area = 1 + (class.area or 0),
		cooldown = 1 - meta("recarga"),
		magnet = 1 + meta("iman"),
		regen = meta("regen"),
		gold = 1 + meta("oro") + (if amulet then Config.itemPower(amulet) / 100 else 0),
		lives = meta("vidas"),
	}
end

---------------------------------------------------------------------
-- Enemigos
---------------------------------------------------------------------
-- Valores base (mapa 1, minuto 0). model: slime · beast · humanoid · spider · flyer
Config.Enemies = {
	-- Bosque
	slime = { name = "Slime", model = "slime", hp = 10, damage = 4, speed = 10, xp = 1, gold = 0.5, size = 1, color = Color3.fromRGB(74, 222, 128) },
	lobo = { name = "Lobo gris", model = "beast", hp = 16, damage = 5, speed = 16, xp = 1, gold = 0.6, size = 0.9, color = Color3.fromRGB(148, 163, 184) },
	goblin = { name = "Goblin", model = "humanoid", hp = 30, damage = 8, speed = 12, xp = 2, gold = 1, size = 0.9, color = Color3.fromRGB(101, 163, 13) },
	rey_goblin = { name = "Rey Goblin", model = "humanoid", hp = 1500, damage = 20, speed = 10, xp = 50, gold = 150, size = 2.6, color = Color3.fromRGB(77, 124, 15), crown = true, boss = true, slam = { damage = 35, radius = 13, every = 5, warn = 1.3 } },
	-- Cueva
	murcielago = { name = "Murciélago", model = "flyer", hp = 10, damage = 4, speed = 17, xp = 1, gold = 0.5, size = 0.8, color = Color3.fromRGB(76, 29, 149) },
	arana = { name = "Araña", model = "spider", hp = 18, damage = 5, speed = 13, xp = 1, gold = 0.6, size = 0.9, color = Color3.fromRGB(30, 41, 59) },
	golem = { name = "Gólem de piedra", model = "humanoid", hp = 40, damage = 9, speed = 9, xp = 2, gold = 1, size = 1.2, color = Color3.fromRGB(120, 113, 108), stone = true },
	golem_cristal = { name = "Gólem de Cristal", model = "humanoid", hp = 1800, damage = 22, speed = 9, xp = 60, gold = 180, size = 3, color = Color3.fromRGB(103, 232, 249), crystal = true, crown = true, boss = true, slam = { damage = 40, radius = 15, every = 4.5, warn = 1.2 } },
	-- Castillo
	esqueleto = { name = "Esqueleto", model = "humanoid", hp = 12, damage = 4, speed = 12, xp = 1, gold = 0.5, size = 0.9, color = Color3.fromRGB(231, 229, 228) },
	espectro = { name = "Espectro", model = "flyer", hp = 18, damage = 5, speed = 16, xp = 1, gold = 0.6, size = 1, color = Color3.fromRGB(165, 243, 252), ghost = true },
	caballero = { name = "Caballero oscuro", model = "humanoid", hp = 45, damage = 9, speed = 11, xp = 2, gold = 1, size = 1.1, color = Color3.fromRGB(39, 39, 42) },
	lich = { name = "Señor Lich", model = "humanoid", hp = 2200, damage = 24, speed = 10, xp = 70, gold = 220, size = 3, color = Color3.fromRGB(88, 28, 135), crown = true, boss = true, slam = { damage = 45, radius = 17, every = 4, warn = 1.1 } },
}
-- Lista ordenada: el índice viaja por la red en vez del nombre
Config.EnemyList = {}
for id, enemy in Config.Enemies do
	enemy.id = id
	table.insert(Config.EnemyList, id)
end
table.sort(Config.EnemyList)
Config.EnemyIndex = {}
for i, id in Config.EnemyList do
	Config.EnemyIndex[id] = i
end

Config.ELITE = { hp = 12, size = 1.7, xp = 15, gold = 10, damage = 1.5 } -- los élite sueltan un cofre
Config.HP_PER_MINUTE = 0.12 -- los enemigos ganan +12 % de vida por minuto de partida

---------------------------------------------------------------------
-- Mapas (se desbloquean escapando del anterior)
---------------------------------------------------------------------
-- timeline: a partir de "from" segundos puede aparecer ese enemigo con ese peso
Config.Maps = {
	{
		id = "bosque", name = "Bosque Encantado", emoji = "🌲", color = Color3.fromRGB(34, 197, 94),
		scale = { hp = 1, damage = 1, gold = 1 },
		bossAt = 480,
		timeline = { { from = 0, enemy = "slime", weight = 10 }, { from = 50, enemy = "lobo", weight = 7 }, { from = 150, enemy = "goblin", weight = 5 }, { from = 300, enemy = "goblin", weight = 5 } },
		elites = { { at = 150, enemy = "lobo" }, { at = 300, enemy = "goblin" }, { at = 420, enemy = "goblin" } },
		boss = "rey_goblin",
		drops = { "espada_hierro", "cota_cuero", "amuleto_cobre" },
	},
	{
		id = "cueva", name = "Cueva de Cristal", emoji = "💎", color = Color3.fromRGB(56, 189, 248),
		scale = { hp = 1.6, damage = 1.5, gold = 3 },
		bossAt = 540,
		timeline = { { from = 0, enemy = "murcielago", weight = 10 }, { from = 40, enemy = "arana", weight = 7 }, { from = 140, enemy = "golem", weight = 4 }, { from = 320, enemy = "golem", weight = 5 } },
		elites = { { at = 140, enemy = "arana" }, { at = 280, enemy = "golem" }, { at = 420, enemy = "golem" } },
		boss = "golem_cristal",
		drops = { "hacha_cristal", "armadura_cristal", "amuleto_amatista" },
	},
	{
		id = "castillo", name = "Castillo Maldito", emoji = "🏰", color = Color3.fromRGB(168, 85, 247),
		scale = { hp = 2.6, damage = 2.2, gold = 8 },
		bossAt = 600,
		timeline = { { from = 0, enemy = "esqueleto", weight = 10 }, { from = 40, enemy = "espectro", weight = 7 }, { from = 130, enemy = "caballero", weight = 4 }, { from = 330, enemy = "caballero", weight = 6 } },
		elites = { { at = 130, enemy = "espectro" }, { at = 270, enemy = "caballero" }, { at = 420, enemy = "caballero" }, { at = 520, enemy = "caballero" } },
		boss = "lich",
		drops = { "guadana_sombria", "armadura_hueso", "amuleto_almas" },
	},
}
Config.MapById = {}
for i, map in Config.Maps do
	map.index = i
	Config.MapById[map.id] = map
end

-- Ritmo de aparición (enemigos por segundo) y tope de enemigos vivos
function Config.spawnRate(seconds: number, players: number): number
	return (1.6 + 0.65 * seconds / 60) * (1 + 0.5 * (players - 1))
end

function Config.maxAlive(seconds: number, players: number): number
	return math.min(Config.MAX_ENEMIES, math.floor((80 + 20 * seconds / 60) * (1 + 0.4 * (players - 1))))
end

-- Estadísticas de un enemigo en un mapa, en el segundo "seconds" de la partida
function Config.enemyStats(enemyId: string, mapIndex: number, seconds: number, players: number, elite: boolean?)
	local def = Config.Enemies[enemyId]
	local scale = Config.Maps[mapIndex].scale
	local hp = def.hp * scale.hp * (1 + 0.5 * (players - 1))
	if not def.boss then
		hp *= 1 + Config.HP_PER_MINUTE * seconds / 60
	end
	local damage = def.damage * scale.damage
	if elite then
		hp *= Config.ELITE.hp
		damage *= Config.ELITE.damage
	end
	return {
		hp = math.floor(hp),
		damage = math.floor(damage),
		slamDamage = if def.slam then math.floor(def.slam.damage * scale.damage) else 0,
		xp = if elite then Config.ELITE.xp else def.xp,
		gold = (if elite then Config.ELITE.gold else def.gold) * scale.gold,
		radius = 1.4 * def.size * (if elite then Config.ELITE.size else 1),
		speed = def.speed * (if elite then 0.85 else 1),
	}
end

-- Precio del cofre de la forja de cada mapa
function Config.chestPrice(mapIndex: number): number
	return Config.TierPrice[mapIndex] * 3
end

-- Oro aproximado por minuto de partida en un mapa (para premios y productos)
function Config.goldPerMinute(mapIndex: number): number
	local map = Config.Maps[math.clamp(mapIndex, 1, #Config.Maps)]
	return math.floor(180 * map.scale.gold)
end

---------------------------------------------------------------------
-- Recompensas
---------------------------------------------------------------------
Config.DAILY_MINUTES = { 3, 4, 5, 6, 8, 10, 15 } -- minutos de oro de tu mejor mapa; el día 7 da además boost
Config.DAILY_BOOST_MINUTES = 15
Config.TUTORIAL_REWARD = 100
Config.FRIEND_BONUS = 0.1 -- +10 % de oro por cada amigo en el servidor
Config.MAX_FRIENDS_BONUS = 4

---------------------------------------------------------------------
-- Tienda (Robux). id = 0 → el artículo no aparece en el juego.
---------------------------------------------------------------------
Config.Monetization = {
	GamePasses = {
		{ key = "goldPass", id = 0, name = "x2 Oro", emoji = "🪙", desc = "Ganas el doble de oro en cada partida, para siempre.", suggestedPrice = 149 },
		{ key = "choicePass", id = 0, name = "4 opciones", emoji = "🃏", desc = "Al subir de nivel eliges entre 4 mejoras en vez de 3.", suggestedPrice = 199 },
		{ key = "rerollPass", id = 0, name = "Rerolls +3", emoji = "🎲", desc = "3 cambios de mejoras extra en cada partida.", suggestedPrice = 99 },
		{ key = "bagPass", id = 0, name = "Mochila grande", emoji = "🎒", desc = "+" .. Config.INVENTORY_PASS_BONUS .. " huecos en la mochila.", suggestedPrice = 49 },
	},
	Products = {
		{ key = "gold_small", id = 0, kind = "gold", name = "Bolsa de oro", emoji = "💰", minutes = 20, desc = "Oro de 20 minutos de tu mejor mapa.", suggestedPrice = 25 },
		{ key = "gold_big", id = 0, kind = "gold", name = "Cofre de oro", emoji = "🏆", minutes = 120, desc = "Oro de 2 horas de tu mejor mapa.", suggestedPrice = 99 },
		{ key = "boost", id = 0, kind = "boost", name = "Boost x2 oro (15 min)", emoji = "🚀", minutes = 15, desc = "x2 de oro durante 15 minutos.", suggestedPrice = 39 },
		{ key = "revive", id = 0, kind = "revive", name = "Revivir", emoji = "💖", desc = "Vuelves a la partida con toda la vida.", suggestedPrice = 15 },
	},
}
Config.PassByKey = {}
for _, pass in Config.Monetization.GamePasses do
	Config.PassByKey[pass.key] = pass
end
Config.ProductByKey = {}
for _, product in Config.Monetization.Products do
	Config.ProductByKey[product.key] = product
end

-- Multiplicador de oro con todos los bonus
function Config.goldMult(stats: Stats, bonuses: any): number
	local mult = stats.gold + Config.FRIEND_BONUS * math.min(bonuses.friends or 0, Config.MAX_FRIENDS_BONUS)
	if bonuses.boost then
		mult *= 2
	end
	if bonuses.goldPass then
		mult *= 2
	end
	return mult
end

---------------------------------------------------------------------
-- Sonidos (archivos que vienen dentro de Roblox: no necesitan moderación)
---------------------------------------------------------------------
Config.Sounds = {
	hit = { id = "rbxasset://sounds/swordslash.wav", volume = 0.25, speed = 1.1 },
	skill = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.35, speed = 0.8 },
	equip = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5, speed = 1 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.15, speed = 1.6 },
	levelup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 0.7 },
	loot = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, speed = 1.1 },
	click = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, speed = 1.6 },
	error = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3, speed = 0.5 },
}

---------------------------------------------------------------------
-- Formato de números
---------------------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Config.formatNumber(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local index = 1
	local value = n
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	if math.abs(value) >= 100 then
		return string.format("%d%s", math.floor(value), SUFFIXES[index])
	end
	return string.format("%.1f%s", math.floor(value * 10) / 10, SUFFIXES[index])
end

function Config.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d h %d min", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%d min %d s", seconds // 60, seconds % 60)
	end
	return seconds .. " s"
end

-- Reloj de partida: 05:07
function Config.formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

return Config
