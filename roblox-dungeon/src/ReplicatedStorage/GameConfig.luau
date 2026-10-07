--[[
	GameConfig (ModuleScript en ReplicatedStorage)

	TODOS los datos y fórmulas de Dungeon Ascend: zonas, enemigos, jefes,
	objetos, rarezas, habilidades, forja, recompensas y tienda.
	Lo usan el servidor y el cliente, así que los dos calculan lo mismo.
]]

local Config = {}

Config.VERSION = "0.1"
Config.DATASTORE_NAME = "DungeonAscend_v1"
Config.LEADERBOARD_NAME = "DungeonAscendTop_v1"
Config.AUTOSAVE_INTERVAL = 60
Config.MANUAL_SAVE_COOLDOWN = 30
Config.LEADERBOARD_REFRESH = 120
Config.WALK_SPEED = 20
Config.RESPAWN_TIME = 4

---------------------------------------------------------------------
-- Nivel del jugador
---------------------------------------------------------------------
Config.MAX_LEVEL = 100

-- XP que hace falta para pasar del nivel L al L+1
function Config.xpToNext(level: number): number
	return math.floor(20 * level ^ 2.1)
end

Config.BASE_DAMAGE = 8
Config.DAMAGE_PER_LEVEL = 2
Config.BASE_HEALTH = 100
Config.HEALTH_PER_LEVEL = 15
Config.CRIT_CHANCE = 0.08
Config.CRIT_MULT = 2

---------------------------------------------------------------------
-- Rarezas (probabilidades visibles en el juego)
---------------------------------------------------------------------
-- weight = botín normal · bossWeight = botín del jefe · chestWeight = cofre de la forja
Config.Rarities = {
	{ id = "comun", name = "Común", color = Color3.fromRGB(176, 186, 197), mult = 1.0, weight = 60, bossWeight = 0, chestWeight = 50 },
	{ id = "pococomun", name = "Poco común", color = Color3.fromRGB(74, 222, 128), mult = 1.3, weight = 25, bossWeight = 0, chestWeight = 30 },
	{ id = "raro", name = "Raro", color = Color3.fromRGB(56, 189, 248), mult = 1.7, weight = 10, bossWeight = 70, chestWeight = 14 },
	{ id = "epico", name = "Épico", color = Color3.fromRGB(192, 132, 252), mult = 2.3, weight = 4, bossWeight = 25, chestWeight = 5 },
	{ id = "legendario", name = "Legendario", color = Color3.fromRGB(251, 191, 36), mult = 3.2, weight = 1, bossWeight = 5, chestWeight = 1 },
}
Config.RarityById = {}
for i, rarity in Config.Rarities do
	rarity.index = i
	Config.RarityById[rarity.id] = rarity
end

-- Probabilidad (0-1) de cada rareza según la tabla elegida ("weight", "bossWeight"...)
function Config.rarityChance(rarityId: string, field: string): number
	local total = 0
	for _, rarity in Config.Rarities do
		total += rarity[field]
	end
	return Config.RarityById[rarityId][field] / total
end

---------------------------------------------------------------------
-- Objetos
---------------------------------------------------------------------
Config.Slots = {
	{ id = "weapon", name = "Arma", emoji = "⚔️", stat = "daño" },
	{ id = "armor", name = "Armadura", emoji = "🛡️", stat = "vida" },
	{ id = "amulet", name = "Amuleto", emoji = "📿", stat = "% oro y XP" },
}

-- base = daño (arma), vida (armadura) o % de oro y XP (amuleto)
Config.Items = {
	espada_madera = { name = "Espada de madera", slot = "weapon", tier = 0, base = 5, color = Color3.fromRGB(161, 120, 74) },

	espada_hierro = { name = "Espada de hierro", slot = "weapon", tier = 1, base = 12, color = Color3.fromRGB(190, 196, 204) },
	cota_cuero = { name = "Armadura de cuero", slot = "armor", tier = 1, base = 70, color = Color3.fromRGB(140, 94, 58) },
	amuleto_cobre = { name = "Amuleto de cobre", slot = "amulet", tier = 1, base = 6, color = Color3.fromRGB(205, 127, 50) },

	hacha_cristal = { name = "Hacha de cristal", slot = "weapon", tier = 2, base = 70, color = Color3.fromRGB(125, 211, 252) },
	armadura_cristal = { name = "Armadura de cristal", slot = "armor", tier = 2, base = 380, color = Color3.fromRGB(103, 232, 249) },
	amuleto_amatista = { name = "Amuleto de amatista", slot = "amulet", tier = 2, base = 12, color = Color3.fromRGB(167, 139, 250) },

	guadana_sombria = { name = "Guadaña sombría", slot = "weapon", tier = 3, base = 420, color = Color3.fromRGB(88, 28, 135) },
	armadura_hueso = { name = "Armadura de hueso", slot = "armor", tier = 3, base = 2000, color = Color3.fromRGB(231, 229, 228) },
	amuleto_almas = { name = "Amuleto de almas", slot = "amulet", tier = 3, base = 22, color = Color3.fromRGB(45, 212, 191) },
}
for id, item in Config.Items do
	item.id = id
end
Config.STARTER_WEAPON = "espada_madera"

Config.MAX_UPGRADE = 10
Config.UPGRADE_STEP = 0.12 -- +12 % de poder por cada mejora
Config.TierPrice = { [0] = 15, 40, 350, 3000 } -- precio de referencia de cada nivel de objeto
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
	if def.slot == "amulet" then
		return math.floor(power * 10 + 0.5) / 10
	end
	return math.floor(power + 0.5)
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

-- Texto corto del poder: "45 daño", "320 vida", "+8.5 % oro y XP"
function Config.powerText(item: Item): string
	local def = Config.Items[item.def]
	local power = Config.itemPower(item)
	if def.slot == "weapon" then
		return Config.formatNumber(power) .. " daño"
	elseif def.slot == "armor" then
		return Config.formatNumber(power) .. " vida"
	end
	return "+" .. power .. " % oro y XP"
end

---------------------------------------------------------------------
-- Estadísticas del jugador (nivel + equipo)
---------------------------------------------------------------------
export type Stats = { damage: number, maxHealth: number, bonusPct: number, critChance: number }

function Config.playerStats(level: number, equipped: { [string]: Item? }): Stats
	local weapon = equipped.weapon
	local armor = equipped.armor
	local amulet = equipped.amulet
	return {
		damage = Config.BASE_DAMAGE + Config.DAMAGE_PER_LEVEL * (level - 1) + (if weapon then Config.itemPower(weapon) else 0),
		maxHealth = Config.BASE_HEALTH + Config.HEALTH_PER_LEVEL * (level - 1) + (if armor then Config.itemPower(armor) else 0),
		bonusPct = if amulet then Config.itemPower(amulet) else 0,
		critChance = Config.CRIT_CHANCE,
	}
end

---------------------------------------------------------------------
-- Habilidades
---------------------------------------------------------------------
-- kind: "melee" golpea a los enemigos cercanos · "spin" área alrededor
-- "dash" embestida en línea recta · "heal" cura un % de la vida máxima
Config.Skills = {
	{ id = "attack", key = "Clic", name = "Atacar", emoji = "⚔️", kind = "melee", level = 1, cooldown = 0.5, mult = 1, radius = 10, maxTargets = 3 },
	{ id = "spin", key = "Q", name = "Torbellino", emoji = "🌀", kind = "spin", level = 3, cooldown = 6, mult = 2.2, radius = 15, maxTargets = 12 },
	{ id = "dash", key = "E", name = "Embestida", emoji = "💨", kind = "dash", level = 6, cooldown = 8, mult = 3, length = 24, width = 7, maxTargets = 12 },
	{ id = "heal", key = "R", name = "Curación", emoji = "💚", kind = "heal", level = 10, cooldown = 25, heal = 0.4 },
}
Config.SkillById = {}
for i, skill in Config.Skills do
	skill.index = i
	Config.SkillById[skill.id] = skill
end

---------------------------------------------------------------------
-- Enemigos
---------------------------------------------------------------------
-- Valores base de la zona 1: cada zona los multiplica con su "scale".
-- model: slime · beast (4 patas) · humanoid · spider · flyer (flota)
Config.Enemies = {
	-- Bosque Encantado
	slime = { name = "Slime", model = "slime", hp = 30, damage = 4, cooldown = 1.4, speed = 9, xp = 10, gold = 3, size = 1, color = Color3.fromRGB(74, 222, 128) },
	lobo = { name = "Lobo gris", model = "beast", hp = 55, damage = 7, cooldown = 1.2, speed = 15, xp = 16, gold = 5, size = 1, color = Color3.fromRGB(148, 163, 184) },
	goblin = { name = "Goblin", model = "humanoid", hp = 90, damage = 11, cooldown = 1.5, speed = 12, xp = 26, gold = 9, size = 1, color = Color3.fromRGB(101, 163, 13) },
	rey_goblin = { name = "Rey Goblin", model = "humanoid", hp = 3000, damage = 16, cooldown = 1.6, speed = 11, xp = 700, gold = 500, size = 2.6, color = Color3.fromRGB(77, 124, 15), crown = true, boss = true, slam = { damage = 45, radius = 14, every = 5, warn = 1.3 } },
	-- Cueva de Cristal
	murcielago = { name = "Murciélago", model = "flyer", hp = 30, damage = 4, cooldown = 1.1, speed = 16, xp = 10, gold = 3, size = 0.9, color = Color3.fromRGB(76, 29, 149) },
	arana = { name = "Araña de cueva", model = "spider", hp = 55, damage = 7, cooldown = 1.2, speed = 14, xp = 16, gold = 5, size = 1, color = Color3.fromRGB(30, 41, 59) },
	golem = { name = "Gólem de piedra", model = "humanoid", hp = 90, damage = 11, cooldown = 1.7, speed = 9, xp = 26, gold = 9, size = 1.4, color = Color3.fromRGB(120, 113, 108), stone = true },
	golem_cristal = { name = "Gólem de Cristal", model = "humanoid", hp = 3000, damage = 16, cooldown = 1.7, speed = 10, xp = 700, gold = 500, size = 3, color = Color3.fromRGB(103, 232, 249), crystal = true, crown = true, boss = true, slam = { damage = 45, radius = 16, every = 4.5, warn = 1.2 } },
	-- Castillo Maldito
	esqueleto = { name = "Esqueleto", model = "humanoid", hp = 30, damage = 4, cooldown = 1.3, speed = 13, xp = 10, gold = 3, size = 1, color = Color3.fromRGB(231, 229, 228) },
	espectro = { name = "Espectro", model = "flyer", hp = 55, damage = 7, cooldown = 1.2, speed = 15, xp = 16, gold = 5, size = 1.2, color = Color3.fromRGB(165, 243, 252), ghost = true },
	caballero = { name = "Caballero oscuro", model = "humanoid", hp = 90, damage = 11, cooldown = 1.5, speed = 12, xp = 26, gold = 9, size = 1.2, color = Color3.fromRGB(39, 39, 42) },
	lich = { name = "Señor Lich", model = "humanoid", hp = 3000, damage = 16, cooldown = 1.5, speed = 11, xp = 700, gold = 500, size = 3, color = Color3.fromRGB(88, 28, 135), crown = true, boss = true, slam = { damage = 45, radius = 18, every = 4, warn = 1.1 } },
}
for id, enemy in Config.Enemies do
	enemy.id = id
end

Config.ENEMY_AGGRO = 34 -- distancia a la que te ven
Config.ENEMY_LEASH = 70 -- si se alejan tanto de su sitio, vuelven
Config.ENEMY_RESPAWN = 6
Config.BOSS_RESPAWN = 75
Config.DROP_CHANCE = 0.12 -- probabilidad de que un enemigo normal suelte un objeto
Config.ENEMY_REGEN_OUT_OF_COMBAT = 0.25 -- % de vida por segundo al volver a casa

---------------------------------------------------------------------
-- Zonas
---------------------------------------------------------------------
-- Se desbloquean derrotando al jefe de la zona anterior.
Config.Zones = {
	{
		id = "bosque",
		name = "Bosque Encantado",
		emoji = "🌲",
		level = 1,
		color = Color3.fromRGB(34, 197, 94),
		scale = { hp = 1, damage = 1, xp = 1, gold = 1 },
		enemies = { "slime", "lobo", "goblin" },
		boss = "rey_goblin",
		drops = { "espada_hierro", "cota_cuero", "amuleto_cobre" },
	},
	{
		id = "cueva",
		name = "Cueva de Cristal",
		emoji = "💎",
		level = 15,
		color = Color3.fromRGB(56, 189, 248),
		scale = { hp = 8, damage = 5, xp = 6, gold = 7 },
		enemies = { "murcielago", "arana", "golem" },
		boss = "golem_cristal",
		drops = { "hacha_cristal", "armadura_cristal", "amuleto_amatista" },
	},
	{
		id = "castillo",
		name = "Castillo Maldito",
		emoji = "🏰",
		level = 30,
		color = Color3.fromRGB(168, 85, 247),
		scale = { hp = 45, damage = 14, xp = 15, gold = 40 },
		enemies = { "esqueleto", "espectro", "caballero" },
		boss = "lich",
		drops = { "guadana_sombria", "armadura_hueso", "amuleto_almas" },
	},
}
Config.ZoneById = {}
for i, zone in Config.Zones do
	zone.index = i
	Config.ZoneById[zone.id] = zone
end

-- Estadísticas reales de un enemigo dentro de su zona
function Config.enemyStats(enemyId: string, zoneIndex: number)
	local def = Config.Enemies[enemyId]
	local scale = Config.Zones[zoneIndex].scale
	return {
		hp = math.floor(def.hp * scale.hp),
		damage = math.floor(def.damage * scale.damage),
		slamDamage = if def.slam then math.floor(def.slam.damage * scale.damage) else 0,
		xp = math.floor(def.xp * scale.xp),
		gold = math.floor(def.gold * scale.gold),
		level = Config.Zones[zoneIndex].level + (if def.boss then 10 else 0),
	}
end

-- Precio del cofre de la forja de cada zona
function Config.chestPrice(zoneIndex: number): number
	return Config.TierPrice[zoneIndex] * 3
end

-- Oro aproximado por minuto en una zona (para premios y productos)
Config.KILLS_PER_MINUTE = 12
function Config.goldPerMinute(zoneIndex: number): number
	local zone = Config.Zones[math.clamp(zoneIndex, 1, #Config.Zones)]
	local total = 0
	for _, enemyId in zone.enemies do
		total += Config.Enemies[enemyId].gold
	end
	return math.floor(total / #zone.enemies * zone.scale.gold * Config.KILLS_PER_MINUTE)
end

---------------------------------------------------------------------
-- Recompensas
---------------------------------------------------------------------
Config.DAILY_MINUTES = { 3, 4, 5, 6, 8, 10, 15 } -- minutos de oro de tu mejor zona; el día 7 da además boost
Config.DAILY_BOOST_MINUTES = 15
Config.TUTORIAL_REWARD = 100
Config.FRIEND_BONUS = 0.1 -- +10 % de oro y XP por cada amigo en el servidor
Config.MAX_FRIENDS_BONUS = 4

---------------------------------------------------------------------
-- Tienda (Robux). id = 0 → el artículo no aparece en el juego.
---------------------------------------------------------------------
Config.Monetization = {
	GamePasses = {
		{ key = "goldPass", id = 0, name = "x2 Oro", emoji = "🪙", desc = "Ganas el doble de oro para siempre.", suggestedPrice = 149 },
		{ key = "xpPass", id = 0, name = "x2 XP", emoji = "⭐", desc = "Subes de nivel el doble de rápido para siempre.", suggestedPrice = 149 },
		{ key = "autoPass", id = 0, name = "Auto-ataque", emoji = "🤖", desc = "Tu personaje ataca solo a los enemigos cercanos.", suggestedPrice = 99 },
		{ key = "bagPass", id = 0, name = "Mochila grande", emoji = "🎒", desc = "+" .. Config.INVENTORY_PASS_BONUS .. " huecos en la mochila.", suggestedPrice = 49 },
	},
	Products = {
		{ key = "gold_small", id = 0, kind = "gold", name = "Bolsa de oro", emoji = "💰", minutes = 20, desc = "Oro de 20 minutos de tu mejor zona.", suggestedPrice = 25 },
		{ key = "gold_big", id = 0, kind = "gold", name = "Cofre de oro", emoji = "🏆", minutes = 120, desc = "Oro de 2 horas de tu mejor zona.", suggestedPrice = 99 },
		{ key = "boost", id = 0, kind = "boost", name = "Boost x2 (15 min)", emoji = "🚀", minutes = 15, desc = "x2 oro y XP durante 15 minutos.", suggestedPrice = 39 },
		{ key = "revive", id = 0, kind = "revive", name = "Revivir aquí", emoji = "💖", desc = "Vuelves a la vida en la zona donde caíste.", suggestedPrice = 15 },
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

-- Multiplicadores de oro y XP con todos los bonus
function Config.rewardMults(stats: Stats, bonuses: any): (number, number)
	local common = 1 + stats.bonusPct / 100 + Config.FRIEND_BONUS * math.min(bonuses.friends or 0, Config.MAX_FRIENDS_BONUS)
	if bonuses.boost then
		common *= 2
	end
	local gold = common * (if bonuses.goldPass then 2 else 1)
	local xp = common * (if bonuses.xpPass then 2 else 1)
	return gold, xp
end

---------------------------------------------------------------------
-- Sonidos (archivos que vienen dentro de Roblox: no necesitan moderación)
---------------------------------------------------------------------
Config.Sounds = {
	hit = { id = "rbxasset://sounds/swordslash.wav", volume = 0.35, speed = 1.1 },
	crit = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.5, speed = 1 },
	skill = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.45, speed = 0.8 },
	equip = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5, speed = 1 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3, speed = 1.4 },
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

return Config
