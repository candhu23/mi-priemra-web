-- Simulador de equilibrio de Dungeon Ascend: un "jugador bot" razonable.
-- No mueve personajes: estima el ritmo de muertes con el daño, la vida y
-- las habilidades del jugador. Uso: luau sim.luau [-a horas]
Color3 = { fromRGB = function() return {} end }
local Config = require("./GameConfig")
local HOURS = tonumber((...)) or 4
local EFFICIENCY = 0.7 -- un humano no encadena todo perfecto
local WALK_BETWEEN = 3 -- segundos andando entre enemigos
local AVG_TARGETS = 1.3 -- enemigos golpeados a la vez de media
local SLAM_HIT = 0.4 -- probabilidad de comerse el golpe del jefe
math.randomseed(7)

local d = { level = 1, xp = 0, gold = 0, unlocked = 1, items = {}, equipped = {}, nextId = 1, kills = 0 }
local function newItem(def, rarity)
	local item = { id = d.nextId, def = def, rarity = rarity, up = 0 }
	d.nextId += 1
	return item
end
d.equipped.weapon = newItem(Config.STARTER_WEAPON, "comun")

local function stats()
	return Config.playerStats(d.level, d.equipped)
end
local function rollRarity(field)
	local total = 0
	for _, r in Config.Rarities do total += r[field] end
	local x = math.random() * total
	for _, r in Config.Rarities do
		x -= r[field]
		if x <= 0 then return r.id end
	end
	return "comun"
end
local function maybeEquip(item)
	local slot = Config.Items[item.def].slot
	local cur = d.equipped[slot]
	if not cur or Config.itemPower(item) > Config.itemPower(cur) then
		d.equipped[slot] = item
		return true
	end
	return false
end
local function dps(st, targets)
	local perSec = 2 * 1 -- ataque básico
	if d.level >= 3 then perSec += 2.2 / 6 * math.min(targets, 3) / targets end
	if d.level >= 6 then perSec += 3 / 8 * math.min(targets, 3) / targets end
	return st.damage * (1 + Config.CRIT_CHANCE * (Config.CRIT_MULT - 1)) * perSec * EFFICIENCY
end
local function zoneEnemies(z)
	local list = {}
	for _, id in Config.Zones[z].enemies do
		table.insert(list, { id = id, def = Config.Enemies[id], s = Config.enemyStats(id, z) })
	end
	return list
end
-- Devuelve segundos por muerte y si se puede farmear sin morir
local function farmInfo(z)
	local st = stats()
	local totalTime, totalLoss = 0, 0
	for _, e in zoneEnemies(z) do
		local kill = e.s.hp / dps(st, AVG_TARGETS) / AVG_TARGETS * 1.0
		local taken = e.s.damage / e.def.cooldown * kill * AVG_TARGETS
		totalTime += kill + WALK_BETWEEN
		totalLoss += taken
	end
	local n = #Config.Zones[z].enemies
	local cycle, loss = totalTime / n, totalLoss / n
	local regen = st.maxHealth * 0.01 * cycle + (if d.level >= 10 then st.maxHealth * 0.4 * cycle / 25 else 0)
	local net = loss - regen
	local cyclesToDie = if net <= 0 then math.huge else st.maxHealth / net
	return cycle, cyclesToDie >= 25 and loss < st.maxHealth * 0.6
end
local function bossWin(z)
	local st = stats()
	local boss = Config.Zones[z].boss
	local def = Config.Enemies[boss]
	local s = Config.enemyStats(boss, z)
	local t = s.hp / dps(st, 1)
	local bossDps = s.damage / def.cooldown + s.slamDamage / def.slam.every * SLAM_HIT
	local taken = bossDps * t
	local heals = if d.level >= 10 then st.maxHealth * 0.4 * (1 + math.floor(t / 25)) else 0
	local available = st.maxHealth + st.maxHealth * 0.01 * t + heals
	return taken < available * 0.8, t
end

local function gainXp(x)
	d.xp += x
	while d.level < Config.MAX_LEVEL and d.xp >= Config.xpToNext(d.level) do
		d.xp -= Config.xpToNext(d.level)
		d.level += 1
	end
end
local function spend()
	for _ = 1, 50 do
		local best, cost = nil, math.huge
		for _, item in d.equipped do
			if item.up < Config.MAX_UPGRADE and Config.Items[item.def].tier > 0 then
				local c = Config.upgradeCost(item)
				if c < cost then best, cost = item, c end
			end
		end
		if best and d.gold >= cost then
			d.gold -= cost
			best.up += 1
		else
			local price = Config.chestPrice(d.unlocked)
			if d.gold >= price and (not best or cost > price * 1.5) then
				d.gold -= price
				local drops = Config.Zones[d.unlocked].drops
				maybeEquip(newItem(drops[math.random(#drops)], rollRarity("chestWeight")))
			else
				return
			end
		end
	end
end
local function gearText()
	local parts = {}
	for _, slot in Config.Slots do
		local it = d.equipped[slot.id]
		if it then
			table.insert(parts, string.format("%s %s+%d", Config.Items[it.def].name, Config.RarityById[it.rarity].name, it.up))
		end
	end
	return table.concat(parts, " · ")
end
local function clock(t)
	return string.format("%3d min", math.floor(t / 60))
end

local zone = 1
local nextBossTry = 0
local reported = {}
local t = 0
while t < HOURS * 3600 do
	-- elegir la mejor zona farmeable (la más alta que no te mata)
	zone = 1
	for z = d.unlocked, 1, -1 do
		local _, ok = farmInfo(z)
		if ok then zone = z break end
	end
	local cycle = farmInfo(zone)
	local enemies = zoneEnemies(zone)
	local e = enemies[math.random(#enemies)]
	local st = stats()
	local goldMult, xpMult = Config.rewardMults(st, {})
	gainXp(e.s.xp * xpMult)
	d.gold += e.s.gold * goldMult
	d.kills += 1
	if math.random() < Config.DROP_CHANCE then
		local drops = Config.Zones[zone].drops
		maybeEquip(newItem(drops[math.random(#drops)], rollRarity("weight")))
	end
	t += cycle
	spend()
	-- jefe de la zona más alta desbloqueada
	if t >= nextBossTry then
		nextBossTry = t + 60
		local z = d.unlocked
		local win, fight = bossWin(z)
		if win then
			t += fight
			local boss = Config.Zones[z].boss
			local s = Config.enemyStats(boss, z)
			gainXp(s.xp * xpMult)
			d.gold += s.gold * goldMult
			local drops = Config.Zones[z].drops
			maybeEquip(newItem(drops[math.random(#drops)], rollRarity("bossWeight")))
			if not reported["boss" .. z] then
				reported["boss" .. z] = true
				print(string.format("%s  JEFE %s derrotado (nivel %d, combate %d s) · %s", clock(t), Config.Enemies[boss].name, d.level, math.floor(fight), gearText()))
				if z < #Config.Zones then
					d.unlocked = z + 1
				end
			end
		end
	end
	for _, l in { 5, 10, 15, 20, 25, 30, 40, 50, 60 } do
		if d.level >= l and not reported[l] then
			reported[l] = true
			local s = stats()
			print(string.format("%s  nivel %2d · zona %d · daño %s · vida %s · oro %s", clock(t), l, zone, Config.formatNumber(s.damage), Config.formatNumber(s.maxHealth), Config.formatNumber(d.gold)))
		end
	end
end
print(string.format("Fin (%d h): nivel %d · zona desbloqueada %d · muertes de enemigos %d · %s", HOURS, d.level, d.unlocked, d.kills, gearText()))
