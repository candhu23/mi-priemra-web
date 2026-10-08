--[[
	GameConfig (ModuleScript en ReplicatedStorage)

	TODOS los datos y fórmulas de Dungeon Ascend (estilo "survivors"):
	armas automáticas, mejoras de partida y evoluciones, clases, mapas con
	sus oleadas, enemigos, jefes, mejoras permanentes, objetos (mochila y
	forja), rarezas, recompensas y tienda.
	Lo usan el servidor y el cliente, así que los dos calculan lo mismo.
]]

local Config = {}

Config.VERSION = "0.3"
Config.CURRENCY = "Coronas" -- la moneda del juego (icono: moneda de oro con una corona)
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
Config.BOMB_FLIGHT = 0.45 -- segundos que tarda una bomba en caer
Config.REVIVE_INVULNERABLE = 3

-- XP que necesita el EQUIPO para subir del nivel L al L+1 (más jugadores → más XP)
function Config.xpToNext(level: number, players: number): number
	return math.floor((3 + 2.4 * level ^ 1.45) * (1 + 0.5 * (players - 1)))
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
	hacha = {
		name = "Hacha arrojadiza", emoji = "🪓", kind = "boomerang", color = Color3.fromRGB(203, 213, 225),
		desc = "Va hacia el enemigo más cercano y vuelve, cortando a todos.",
		levels = {
			{ damage = 16, cooldown = 1.8, count = 1, length = 22 },
			{ damage = 21, cooldown = 1.7, count = 1, length = 24 },
			{ damage = 26, cooldown = 1.6, count = 2, length = 25 },
			{ damage = 32, cooldown = 1.5, count = 2, length = 27 },
			{ damage = 40, cooldown = 1.4, count = 3, length = 30 },
		},
		evolution = { passive = "armadura", name = "Hachas del Berserker", emoji = "🪓", damage = 60, cooldown = 1.1, count = 6, length = 34 },
	},
	bomba = {
		name = "Bomba de fuego", emoji = "💣", kind = "bomb", color = Color3.fromRGB(249, 115, 22),
		desc = "Lanza bombas que explotan entre los enemigos.",
		levels = {
			{ damage = 30, cooldown = 2.6, count = 1, aoe = 5, range = 34 },
			{ damage = 40, cooldown = 2.5, count = 1, aoe = 5.6, range = 36 },
			{ damage = 50, cooldown = 2.3, count = 2, aoe = 6.2, range = 38 },
			{ damage = 62, cooldown = 2.2, count = 2, aoe = 6.8, range = 40 },
			{ damage = 78, cooldown = 2.0, count = 3, aoe = 7.5, range = 42 },
		},
		evolution = { passive = "regeneracion", name = "Lluvia de Meteoritos", emoji = "☄️", damage = 120, cooldown = 1.5, count = 5, aoe = 9, range = 48 },
	},
	martillo = {
		name = "Martillo sísmico", emoji = "🔨", kind = "quake", color = Color3.fromRGB(180, 140, 100),
		desc = "Golpea el suelo: onda que empuja y daña a tu alrededor.",
		levels = {
			{ damage = 20, cooldown = 3.0, radius = 10 },
			{ damage = 28, cooldown = 2.8, radius = 11.5 },
			{ damage = 36, cooldown = 2.6, radius = 13 },
			{ damage = 45, cooldown = 2.4, radius = 14.5 },
			{ damage = 56, cooldown = 2.2, radius = 16 },
		},
		evolution = { passive = "vida", name = "Martillo de los Titanes", emoji = "⚒️", damage = 110, cooldown = 1.6, radius = 22 },
	},
}
Config.WeaponOrder = { "espada", "varita", "dagas", "aura", "orbes", "hacha", "bomba", "rayo", "martillo" }

-- Armas que se tienen desde el principio (las de las clases); el resto sale del cofre de armas
Config.STARTER_WEAPONS = { espada = true, varita = true, dagas = true }
-- Peso de cada arma en el cofre (probabilidades visibles en el juego)
Config.WeaponChest = {
	{ id = "aura", weight = 30, rarity = "raro" },
	{ id = "orbes", weight = 28, rarity = "raro" },
	{ id = "hacha", weight = 22, rarity = "raro" },
	{ id = "bomba", weight = 12, rarity = "epico" },
	{ id = "rayo", weight = 6, rarity = "epico" },
	{ id = "martillo", weight = 2, rarity = "legendario" },
}

-- Precio del cofre de armas: sube con cada arma que ya tienes desbloqueada
function Config.weaponChestPrice(unlockedFromChest: number): number
	return math.floor(600 * 1.6 ^ unlockedFromChest)
end

-- Probabilidad de cada arma que aún no tienes
function Config.weaponChestOdds(unlocked: { [string]: boolean }): { { id: string, chance: number } }
	local total = 0
	for _, entry in Config.WeaponChest do
		if not unlocked[entry.id] then
			total += entry.weight
		end
	end
	local odds = {}
	for _, entry in Config.WeaponChest do
		if not unlocked[entry.id] then
			table.insert(odds, { id = entry.id, chance = entry.weight / total })
		end
	end
	return odds
end
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
-- Clases (se compran con Coronas)
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
-- Árbol de mejoras permanentes (se compran con Coronas en el lobby)
---------------------------------------------------------------------
-- Cada nodo se desbloquea al comprar su padre. x, y = posición en la página (0-1).
-- stat: damage, cooldown, area, health, regen, lives, speed, gold, magnet, rerolls
Config.Branches = {
	{ id = "ataque", name = "Ataque", color = Color3.fromRGB(220, 38, 38) },
	{ id = "defensa", name = "Defensa", color = Color3.fromRGB(37, 99, 235) },
	{ id = "fortuna", name = "Fortuna", color = Color3.fromRGB(202, 138, 4) },
}
Config.Tree = {
	-- Ataque
	{ id = "a1", branch = "ataque", name = "Filo afilado", icon = "fuerza", stat = "damage", value = 0.05, cost = 150, x = 0.17, y = 0.1 },
	{ id = "a2", branch = "ataque", parent = "a1", name = "Golpe certero", icon = "fuerza", stat = "damage", value = 0.05, cost = 400, x = 0.17, y = 0.3 },
	{ id = "a3", branch = "ataque", parent = "a2", name = "Manos rápidas", icon = "rapidez", stat = "cooldown", value = 0.04, cost = 800, x = 0.09, y = 0.5 },
	{ id = "a4", branch = "ataque", parent = "a2", name = "Furia", icon = "fuerza", stat = "damage", value = 0.08, cost = 1200, x = 0.25, y = 0.5 },
	{ id = "a5", branch = "ataque", parent = "a3", name = "Maestría", icon = "rapidez", stat = "cooldown", value = 0.06, cost = 2500, x = 0.09, y = 0.7 },
	{ id = "a6", branch = "ataque", parent = "a4", name = "Gran alcance", icon = "area", stat = "area", value = 0.08, cost = 2500, x = 0.25, y = 0.7 },
	{ id = "a7", branch = "ataque", parent = "a5", name = "Señor de la guerra", icon = "fuerza", stat = "damage", value = 0.12, cost = 6000, x = 0.09, y = 0.9 },
	{ id = "a8", branch = "ataque", parent = "a6", name = "Torbellino", icon = "area", stat = "area", value = 0.12, cost = 6000, x = 0.25, y = 0.9 },
	-- Defensa
	{ id = "d1", branch = "defensa", name = "Piel dura", icon = "vida", stat = "health", value = 15, cost = 150, x = 0.5, y = 0.1 },
	{ id = "d2", branch = "defensa", parent = "d1", name = "Robustez", icon = "vida", stat = "health", value = 20, cost = 400, x = 0.5, y = 0.3 },
	{ id = "d3", branch = "defensa", parent = "d2", name = "Vendas", icon = "regeneracion", stat = "regen", value = 0.3, cost = 800, x = 0.42, y = 0.5 },
	{ id = "d4", branch = "defensa", parent = "d2", name = "Coraza", icon = "armadura", stat = "health", value = 25, cost = 1200, x = 0.58, y = 0.5 },
	{ id = "d5", branch = "defensa", parent = "d3", name = "Sanación", icon = "regeneracion", stat = "regen", value = 0.5, cost = 2500, x = 0.42, y = 0.7 },
	{ id = "d6", branch = "defensa", parent = "d4", name = "Inquebrantable", icon = "armadura", stat = "health", value = 40, cost = 2500, x = 0.58, y = 0.7 },
	{ id = "d7", branch = "defensa", parent = "d5", name = "Segunda vida", icon = "revive", stat = "lives", value = 1, cost = 5000, x = 0.42, y = 0.9 },
	{ id = "d8", branch = "defensa", parent = "d6", name = "Fénix", icon = "revive", stat = "lives", value = 1, cost = 12000, x = 0.58, y = 0.9 },
	-- Fortuna
	{ id = "f1", branch = "fortuna", name = "Botas ligeras", icon = "botas", stat = "speed", value = 0.04, cost = 150, x = 0.83, y = 0.1 },
	{ id = "f2", branch = "fortuna", parent = "f1", name = "Bolsa grande", icon = "coin", stat = "gold", value = 0.06, cost = 400, x = 0.75, y = 0.3 },
	{ id = "f3", branch = "fortuna", parent = "f1", name = "Imán", icon = "iman", stat = "magnet", value = 0.15, cost = 600, x = 0.91, y = 0.3 },
	{ id = "f4", branch = "fortuna", parent = "f2", name = "Mercader", icon = "coin", stat = "gold", value = 0.08, cost = 1200, x = 0.75, y = 0.5 },
	{ id = "f5", branch = "fortuna", parent = "f3", name = "Atracción", icon = "iman", stat = "magnet", value = 0.2, cost = 2000, x = 0.91, y = 0.5 },
	{ id = "f6", branch = "fortuna", parent = "f4", name = "Golpe de suerte", icon = "gem", stat = "rerolls", value = 1, cost = 2500, x = 0.75, y = 0.7 },
	{ id = "f7", branch = "fortuna", parent = "f5", name = "Viento a favor", icon = "botas", stat = "speed", value = 0.06, cost = 5000, x = 0.91, y = 0.7 },
	{ id = "f8", branch = "fortuna", parent = "f6", name = "Tesoro real", icon = "crown", stat = "gold", value = 0.15, cost = 8000, x = 0.75, y = 0.9 },
}
Config.TreeById = {}
for _, node in Config.Tree do
	Config.TreeById[node.id] = node
end

-- Texto del efecto de un nodo: "+5 % de daño"
function Config.nodeEffect(node: any): string
	local v = node.value
	local texts = {
		damage = "+" .. math.floor(v * 100) .. " % de daño",
		cooldown = "-" .. math.floor(v * 100) .. " % de recarga",
		area = "+" .. math.floor(v * 100) .. " % de alcance",
		health = "+" .. v .. " de vida",
		regen = "+" .. v .. " de vida por segundo",
		lives = "+1 vida extra por partida",
		speed = "+" .. math.floor(v * 100) .. " % de velocidad",
		gold = "+" .. math.floor(v * 100) .. " % de Coronas",
		magnet = "+" .. math.floor(v * 100) .. " % de radio para recoger",
		rerolls = "+1 cambio de mejoras por partida",
	}
	return texts[node.stat] or ""
end

-- ¿Se puede comprar? (no comprado y con el padre comprado)
function Config.nodeAvailable(tree: { [string]: boolean }, node: any): boolean
	return not tree[node.id] and (node.parent == nil or tree[node.parent] == true)
end

---------------------------------------------------------------------
-- Dificultades (cada una se desbloquea superando la anterior en ese mapa)
---------------------------------------------------------------------
Config.Difficulties = {
	{ id = "normal", name = "Normal", color = Color3.fromRGB(34, 197, 94), hp = 1, damage = 1, speed = 1, count = 1, gold = 1, rarityBoost = 1 },
	{ id = "dificil", name = "Difícil", color = Color3.fromRGB(249, 115, 22), hp = 2.2, damage = 1.6, speed = 1.08, count = 1.3, gold = 1.8, rarityBoost = 2 },
	{ id = "pesadilla", name = "Pesadilla", color = Color3.fromRGB(190, 18, 60), hp = 4, damage = 2.4, speed = 1.15, count = 1.6, gold = 3, rarityBoost = 4 },
}
Config.DifficultyById = {}
for i, difficulty in Config.Difficulties do
	difficulty.index = i
	Config.DifficultyById[difficulty.id] = difficulty
end

-- ¿Está disponible esta dificultad en este mapa?
function Config.difficultyUnlocked(unlockedMap: number, mapWins: { [string]: any }, mapIndex: number, difficulty: number): boolean
	if mapIndex > unlockedMap then
		return false
	end
	if difficulty <= 1 then
		return true
	end
	local wins = mapWins[Config.Maps[mapIndex].id]
	local previous = Config.Difficulties[difficulty - 1].id
	return type(wins) == "table" and (wins[previous] or 0) > 0
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
	{ id = "amulet", name = "Amuleto", emoji = "📿", stat = "% de Coronas" },
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
	return "+" .. power .. " % de Coronas"
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
	rerolls: number, -- cambios de mejoras extra por partida
}

function Config.baseStats(classId: string, tree: { [string]: boolean }, equipped: { [string]: Item? }): Stats
	local class = Config.ClassById[classId] or Config.Classes[1]
	local sum: { [string]: number } = {}
	for id in tree do
		local node = Config.TreeById[id]
		if node then
			sum[node.stat] = (sum[node.stat] or 0) + node.value
		end
	end
	local function get(stat: string): number
		return sum[stat] or 0
	end
	local weapon = equipped.weapon
	local armor = equipped.armor
	local amulet = equipped.amulet
	return {
		damage = 1 + get("damage") + (if weapon then Config.itemPower(weapon) / 100 else 0),
		health = Config.BASE_HEALTH + (class.health or 0) + get("health") + (if armor then Config.itemPower(armor) else 0),
		speed = 1 + (class.speed or 0) + get("speed"),
		area = 1 + (class.area or 0) + get("area"),
		cooldown = 1 - get("cooldown"),
		magnet = 1 + get("magnet"),
		regen = get("regen"),
		gold = 1 + get("gold") + (if amulet then Config.itemPower(amulet) / 100 else 0),
		lives = get("lives"),
		rerolls = get("rerolls"),
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
Config.HP_PER_WAVE = 0.2 -- los enemigos ganan +20 % de vida en cada oleada

---------------------------------------------------------------------
-- Oleadas
---------------------------------------------------------------------
Config.WAVE_SPAWN_TIME = 40 -- segundos en los que llegan las manadas de una oleada
Config.WAVE_OVERTIME = 20 -- si quedan enemigos, la siguiente oleada empieza igualmente tras este tiempo
Config.WAVE_BREAK = 6 -- descanso entre oleadas (los cristales vuelan hacia ti)
Config.WAVE_CLEAR_LEFT = 0.12 -- la oleada se da por superada si queda menos de este % de enemigos

-- Enemigos que trae una oleada (más jugadores → más enemigos)
function Config.waveSize(wave: number, players: number, difficulty: number?): number
	local count = Config.Difficulties[difficulty or 1].count
	return math.floor((70 + 34 * (wave - 1) ^ 1.25) * (1 + 0.6 * (players - 1)) * count)
end

---------------------------------------------------------------------
-- Mapas (se desbloquean escapando del anterior)
---------------------------------------------------------------------
-- waves = oleadas (el jefe llega en la última) · timeline: desde la oleada "wave"
-- puede aparecer ese enemigo con ese peso · elites: un élite (suelta cofre) en esa oleada
Config.Maps = {
	{
		id = "bosque", name = "Bosque Encantado", emoji = "🌲", color = Color3.fromRGB(34, 197, 94),
		scale = { hp = 1, damage = 1, gold = 1 },
		waves = 10,
		timeline = { { wave = 1, enemy = "slime", weight = 10 }, { wave = 2, enemy = "lobo", weight = 7 }, { wave = 4, enemy = "goblin", weight = 5 }, { wave = 7, enemy = "goblin", weight = 5 } },
		elites = { { wave = 3, enemy = "lobo" }, { wave = 6, enemy = "goblin" }, { wave = 8, enemy = "goblin" } },
		boss = "rey_goblin",
		drops = { "espada_hierro", "cota_cuero", "amuleto_cobre" },
	},
	{
		id = "cueva", name = "Cueva de Cristal", emoji = "💎", color = Color3.fromRGB(56, 189, 248),
		scale = { hp = 1.6, damage = 1.5, gold = 3 },
		waves = 11,
		timeline = { { wave = 1, enemy = "murcielago", weight = 10 }, { wave = 2, enemy = "arana", weight = 7 }, { wave = 4, enemy = "golem", weight = 4 }, { wave = 8, enemy = "golem", weight = 5 } },
		elites = { { wave = 3, enemy = "arana" }, { wave = 6, enemy = "golem" }, { wave = 9, enemy = "golem" } },
		boss = "golem_cristal",
		drops = { "hacha_cristal", "armadura_cristal", "amuleto_amatista" },
	},
	{
		id = "castillo", name = "Castillo Maldito", emoji = "🏰", color = Color3.fromRGB(168, 85, 247),
		scale = { hp = 2.6, damage = 2.2, gold = 8 },
		waves = 12,
		timeline = { { wave = 1, enemy = "esqueleto", weight = 10 }, { wave = 2, enemy = "espectro", weight = 7 }, { wave = 4, enemy = "caballero", weight = 4 }, { wave = 8, enemy = "caballero", weight = 6 } },
		elites = { { wave = 3, enemy = "espectro" }, { wave = 6, enemy = "caballero" }, { wave = 8, enemy = "caballero" }, { wave = 10, enemy = "caballero" } },
		boss = "lich",
		drops = { "guadana_sombria", "armadura_hueso", "amuleto_almas" },
	},
}
Config.MapById = {}
for i, map in Config.Maps do
	map.index = i
	Config.MapById[map.id] = map
end

-- Tope de enemigos vivos a la vez (rendimiento y para que no sea imposible)
function Config.maxAlive(wave: number, players: number, difficulty: number?): number
	local count = Config.Difficulties[difficulty or 1].count
	return math.min(Config.MAX_ENEMIES, math.floor((90 + 16 * (wave - 1)) * (1 + 0.4 * (players - 1)) * count))
end

-- Estadísticas de un enemigo en un mapa y una oleada
function Config.enemyStats(enemyId: string, mapIndex: number, wave: number, players: number, elite: boolean?, difficulty: number?)
	local def = Config.Enemies[enemyId]
	local scale = Config.Maps[mapIndex].scale
	local diff = Config.Difficulties[difficulty or 1]
	local hp = def.hp * scale.hp * diff.hp * (1 + 0.5 * (players - 1))
	if not def.boss then
		hp *= 1 + Config.HP_PER_WAVE * (wave - 1)
	end
	local damage = def.damage * scale.damage * diff.damage
	if elite then
		hp *= Config.ELITE.hp
		damage *= Config.ELITE.damage
	end
	return {
		hp = math.floor(hp),
		damage = math.floor(damage),
		slamDamage = if def.slam then math.floor(def.slam.damage * scale.damage * diff.damage) else 0,
		xp = if elite then Config.ELITE.xp else def.xp,
		gold = (if elite then Config.ELITE.gold else def.gold) * scale.gold,
		radius = 1.4 * def.size * (if elite then Config.ELITE.size else 1),
		-- Cada oleada son un poco más rápidos (+2,5 %, máx. +30 %); el jefe no
		speed = def.speed * diff.speed * (if def.boss then 1 else 1 + math.min(0.3, 0.025 * (wave - 1))) * (if elite then 0.85 else 1),
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
		{ key = "goldPass", id = 0, name = "x2 Coronas", emoji = "👑", desc = "Ganas el doble de Coronas en cada partida, para siempre.", suggestedPrice = 149 },
		{ key = "choicePass", id = 0, name = "4 opciones", emoji = "🃏", desc = "Al subir de nivel eliges entre 4 mejoras en vez de 3.", suggestedPrice = 199 },
		{ key = "rerollPass", id = 0, name = "Rerolls +3", emoji = "🎲", desc = "3 cambios de mejoras extra en cada partida.", suggestedPrice = 99 },
		{ key = "bagPass", id = 0, name = "Mochila grande", emoji = "🎒", desc = "+" .. Config.INVENTORY_PASS_BONUS .. " huecos en la mochila.", suggestedPrice = 49 },
	},
	Products = {
		{ key = "gold_small", id = 0, kind = "gold", name = "Bolsa de Coronas", emoji = "💰", minutes = 20, desc = "Coronas de 20 minutos de tu mejor mapa.", suggestedPrice = 25 },
		{ key = "gold_big", id = 0, kind = "gold", name = "Cofre real", emoji = "🏆", minutes = 120, desc = "Coronas de 2 horas de tu mejor mapa.", suggestedPrice = 99 },
		{ key = "boost", id = 0, kind = "boost", name = "Boost x2 Coronas (15 min)", emoji = "🚀", minutes = 15, desc = "x2 de Coronas durante 15 minutos.", suggestedPrice = 39 },
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

-- Cantidad de la moneda del juego en texto: "1.2K Coronas"
function Config.money(n: number): string
	return Config.formatNumber(n) .. " " .. Config.CURRENCY
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
