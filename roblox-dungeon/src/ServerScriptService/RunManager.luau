--[[
	RunManager (ModuleScript en ServerScriptService)

	Las partidas estilo "survivors". Todo se calcula en el servidor:
	  · oleadas: cada vez más enemigos, élites con cofre y un jefe final
	  · enemigos: son solo datos (posición, vida…); los dibuja el cliente.
	    Persiguen al jugador más cercano, se empujan entre ellos y golpean
	    al tocarte
	  · armas automáticas de cada jugador (tajo, proyectiles, dagas, aura,
	    orbes, rayos) y mejoras al subir de nivel (1 de 3, o 4 con el pase)
	  · cristales de XP compartidos por el equipo, corazones y cofres
	  · tras vencer al jefe aparece un portal: hay que escapar a tiempo
	Al acabar, cada jugador recibe su oro (completo si escapa, la mitad si
	cae o abandona) a través de deps.onFinish.
]]

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

local RunManager = {}

RunManager.TICK = 1 / 15 -- simulación 15 veces por segundo
RunManager.SNAPSHOT = 0.1 -- posiciones a los clientes 10 veces por segundo
RunManager.REVIVE_WINDOW = 20 -- segundos para revivir antes de salir de la partida

type Enemy = {
	id: number,
	type: string,
	typeIndex: number,
	x: number,
	z: number,
	hp: number,
	maxHp: number,
	damage: number,
	slamDamage: number,
	speed: number,
	radius: number,
	xp: number,
	gold: number,
	elite: boolean,
	boss: boolean,
	dead: boolean,
	nextAttack: number,
	kbx: number,
	kbz: number,
	orbHits: { [number]: number }?,
	nextSlam: number,
	slamAt: number?,
	slamX: number,
	slamZ: number,
}

type Gem = { id: number, kind: number, x: number, z: number, value: number }

type Offer = { kind: string, id: string?, level: number? }

type Member = {
	player: Player,
	userId: number,
	name: string,
	alive: boolean,
	finished: boolean,
	deadAt: number,
	weapons: { [string]: number },
	weaponOrder: { string },
	passives: { [string]: number },
	passiveOrder: { string },
	cooldowns: { [string]: number },
	base: Config.Stats,
	damageMult: number,
	cooldownMult: number,
	areaMult: number,
	maxHealth: number,
	speedMult: number,
	magnet: number,
	armor: number,
	regen: number,
	goldMult: number,
	choiceCount: number,
	pendingChoices: number,
	offer: { Offer }?,
	offerAt: number,
	rerolls: number,
	lives: number,
	invulnerableUntil: number,
	dashReadyAt: number,
	gold: number,
	kills: number,
	x: number,
	z: number,
	lookX: number,
	lookZ: number,
	vx: number,
	vz: number,
}

type Run = {
	id: number,
	slot: number,
	mapIndex: number,
	map: any,
	origin: Vector3,
	members: { Member },
	byPlayer: { [Player]: Member },
	time: number,
	enemies: { Enemy },
	nextEnemyId: number,
	gems: { [number]: Gem },
	gemCount: number,
	nextGemId: number,
	gemAdds: { number },
	gemRemoves: { number },
	fx: { any },
	level: number,
	xp: number,
	kills: number,
	spawnAcc: number,
	elitesDone: { [number]: boolean },
	boss: Enemy?,
	bossSpawned: boolean,
	bossDead: boolean,
	portalX: number,
	portalZ: number,
	portalEndsAt: number?,
	snapshotAcc: number,
	ended: boolean,
}

type Deps = {
	buildArena: (slot: number, mapIndex: number) -> Vector3,
	destroyArena: (slot: number) -> (),
	baseStats: (Player) -> Config.Stats,
	classWeapon: (Player) -> string,
	bonuses: (Player) -> any,
	teleport: (Player, CFrame) -> (),
	onFinish: (Player, any) -> (),
	notify: (Player, string, string) -> (),
	markDirty: (Player) -> (),
	sendSwarm: (Player, buffer, { number }, { number }, { any }) -> (),
}

local deps: Deps = nil :: any
local random = Random.new()
local runs: { [number]: Run } = {}
local runOfPlayer: { [Player]: Run } = {}
local slots: { [number]: boolean } = {}
local nextRunId = 0

---------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------
local function characterOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function addFx(run: Run, ...: any)
	if #run.fx < 60 then
		table.insert(run.fx, { ... })
	end
end

local function activeMembers(run: Run): { Member }
	local list = {}
	for _, member in run.members do
		if member.alive and not member.finished then
			table.insert(list, member)
		end
	end
	return list
end

local function countWeapons(member: Member): number
	return #member.weaponOrder
end

-- Recalcula las estadísticas de partida de un jugador (pasivas + permanentes)
local function refreshStats(member: Member)
	local p = member.passives
	local base = member.base
	member.damageMult = base.damage * (1 + Config.Passives.fuerza.value * (p.fuerza or 0))
	member.cooldownMult = math.max(0.4, base.cooldown * (1 - Config.Passives.rapidez.value * (p.rapidez or 0)))
	member.areaMult = base.area * (1 + Config.Passives.area.value * (p.area or 0))
	member.maxHealth = base.health + Config.Passives.vida.value * (p.vida or 0)
	member.speedMult = base.speed * (1 + Config.Passives.botas.value * (p.botas or 0))
	member.magnet = Config.PICKUP_RADIUS * base.magnet * (1 + Config.Passives.iman.value * (p.iman or 0))
	member.armor = math.min(0.6, Config.Passives.armadura.value * (p.armadura or 0))
	member.regen = base.regen + Config.Passives.regeneracion.value * (p.regeneracion or 0)
	local _, humanoid = characterOf(member.player)
	if humanoid and humanoid.Health > 0 then
		local ratio = humanoid.Health / math.max(1, humanoid.MaxHealth)
		humanoid.MaxHealth = member.maxHealth
		humanoid.Health = math.max(1, ratio * member.maxHealth)
		humanoid.WalkSpeed = Config.WALK_SPEED * member.speedMult
	end
end

---------------------------------------------------------------------
-- Enemigos y cristales
---------------------------------------------------------------------
local function spawnEnemy(run: Run, enemyId: string, x: number, z: number, elite: boolean?): Enemy
	local def = Config.Enemies[enemyId]
	local stats = Config.enemyStats(enemyId, run.mapIndex, run.time, #run.members, elite)
	run.nextEnemyId = run.nextEnemyId % 65535 + 1
	local enemy: Enemy = {
		id = run.nextEnemyId,
		type = enemyId,
		typeIndex = Config.EnemyIndex[enemyId],
		x = x,
		z = z,
		hp = stats.hp,
		maxHp = stats.hp,
		damage = stats.damage,
		slamDamage = stats.slamDamage,
		speed = stats.speed,
		radius = stats.radius,
		xp = stats.xp,
		gold = stats.gold,
		elite = elite == true,
		boss = def.boss == true,
		dead = false,
		nextAttack = 0,
		kbx = 0,
		kbz = 0,
		orbHits = nil,
		nextSlam = os.clock() + 3,
		slamAt = nil,
		slamX = x,
		slamZ = z,
	}
	table.insert(run.enemies, enemy)
	return enemy
end

local function clampToArena(run: Run, x: number, z: number, margin: number): (number, number)
	local half = Config.ARENA_HALF - margin
	return math.clamp(x, run.origin.X - half, run.origin.X + half), math.clamp(z, run.origin.Z - half, run.origin.Z + half)
end

-- Punto de aparición alrededor de un jugador al azar, fuera de la vista inmediata
local function spawnPoint(run: Run, players: { Member }, distance: number?): (number, number)
	local x, z = run.origin.X, run.origin.Z
	for _ = 1, 6 do
		local member = players[random:NextInteger(1, #players)]
		local angle = random:NextNumber(0, math.pi * 2)
		-- La mitad aparece por delante de hacia donde corre el jugador
		local speed2 = member.vx * member.vx + member.vz * member.vz
		if speed2 > 25 and speed2 < 2500 and random:NextNumber() < 0.5 then
			angle = math.atan2(member.vz, member.vx) + random:NextNumber(-0.9, 0.9)
		end
		local d = distance or random:NextNumber(Config.SPAWN_DISTANCE[1], Config.SPAWN_DISTANCE[2])
		x, z = clampToArena(run, member.x + math.cos(angle) * d, member.z + math.sin(angle) * d, 3)
		local tooClose = false
		for _, other in players do
			local dx, dz = other.x - x, other.z - z
			if dx * dx + dz * dz < 22 * 22 then
				tooClose = true
				break
			end
		end
		if not tooClose then
			break
		end
	end
	return x, z
end

local function pickEnemyType(run: Run): string
	local total = 0
	for _, entry in run.map.timeline do
		if run.time >= entry.from then
			total += entry.weight
		end
	end
	local roll = random:NextNumber() * total
	for _, entry in run.map.timeline do
		if run.time >= entry.from then
			roll -= entry.weight
			if roll <= 0 then
				return entry.enemy
			end
		end
	end
	return run.map.timeline[1].enemy
end

local function addGem(run: Run, kind: number, x: number, z: number, value: number)
	if run.gemCount >= Config.MAX_GEMS and kind == 1 then
		-- Demasiados cristales: se suma a uno que ya existe
		for _, gem in run.gems do
			if gem.kind == 1 then
				gem.value += value
				return
			end
		end
	end
	run.nextGemId = run.nextGemId % 65535 + 1
	local gem = { id = run.nextGemId, kind = kind, x = x, z = z, value = value }
	run.gems[gem.id] = gem
	run.gemCount += 1
	table.insert(run.gemAdds, gem.id)
	table.insert(run.gemAdds, kind)
	table.insert(run.gemAdds, math.floor((x - run.origin.X) * 4))
	table.insert(run.gemAdds, math.floor((z - run.origin.Z) * 4))
end

local function killEnemy(run: Run, enemy: Enemy, killer: Member?)
	if enemy.dead then
		return
	end
	enemy.dead = true
	run.kills += 1
	if killer then
		killer.kills += 1
	end
	-- El oro es para todos los del equipo que siguen en la partida
	for _, member in run.members do
		if not member.finished then
			member.gold += enemy.gold * member.goldMult
		end
	end
	if enemy.boss then
		run.bossDead = true
		run.boss = nil
		-- El portal aparece lejos (hay que cruzar la horda para llegar)
		local portalAngle = random:NextNumber(0, math.pi * 2)
		run.portalX, run.portalZ = clampToArena(run, enemy.x + math.cos(portalAngle) * 45, enemy.z + math.sin(portalAngle) * 45, 15)
		run.portalEndsAt = run.time + Config.ESCAPE_TIME
		for i = 1, 12 do
			local angle = i / 12 * math.pi * 2
			addGem(run, 1, enemy.x + math.cos(angle) * 4, enemy.z + math.sin(angle) * 4, enemy.xp / 12)
		end
		addFx(run, "portal", run.portalX - run.origin.X, run.portalZ - run.origin.Z)
		for _, member in run.members do
			if not member.finished then
				deps.notify(member.player, "🌀 ¡Jefe derrotado! Corre al portal antes de " .. Config.ESCAPE_TIME .. " s", "boss")
			end
		end
	elseif enemy.elite then
		addGem(run, 3, enemy.x, enemy.z, 1)
	else
		addGem(run, 1, enemy.x, enemy.z, enemy.xp)
		if random:NextNumber() < Config.HEART_CHANCE then
			addGem(run, 2, enemy.x + 1, enemy.z, 1)
		end
	end
	addFx(run, "death", enemy.x - run.origin.X, enemy.z - run.origin.Z, enemy.typeIndex)
end

local function damageEnemy(run: Run, enemy: Enemy, amount: number, member: Member, knockback: number?)
	if enemy.dead then
		return
	end
	enemy.hp -= amount
	if knockback and not enemy.boss then
		local dx, dz = enemy.x - member.x, enemy.z - member.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d > 0.01 then
			enemy.kbx += dx / d * knockback
			enemy.kbz += dz / d * knockback
		end
	end
	if enemy.hp <= 0 then
		killEnemy(run, enemy, member)
	end
end

---------------------------------------------------------------------
-- Daño al jugador
---------------------------------------------------------------------
local function hurt(run: Run, member: Member, amount: number)
	local now = os.clock()
	if not member.alive or member.finished or now < member.invulnerableUntil or member.offer then
		return
	end
	local _, humanoid = characterOf(member.player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	amount *= 1 - member.armor
	if humanoid.Health - amount <= 0 and member.lives > 0 then
		member.lives -= 1
		humanoid.Health = member.maxHealth * 0.5
		member.invulnerableUntil = now + 2
		addFx(run, "revive", member.x - run.origin.X, member.z - run.origin.Z)
		deps.notify(member.player, "💖 ¡Segunda vida! Te quedan " .. member.lives, "success")
		deps.markDirty(member.player)
		return
	end
	humanoid:TakeDamage(amount)
end

---------------------------------------------------------------------
-- Mejoras al subir de nivel
---------------------------------------------------------------------
local function buildOffer(member: Member): { Offer }
	local forced: { Offer } = {}
	local pool: { { offer: Offer, weight: number } } = {}
	for _, weaponId in member.weaponOrder do
		local level = member.weapons[weaponId]
		local weapon = Config.Weapons[weaponId]
		if level < Config.MAX_ITEM_LEVEL then
			table.insert(pool, { offer = { kind = "weapon", id = weaponId, level = level + 1 }, weight = 3 })
		elseif level == Config.MAX_ITEM_LEVEL and (member.passives[weapon.evolution.passive] or 0) > 0 then
			table.insert(forced, { kind = "evolve", id = weaponId, level = Config.MAX_ITEM_LEVEL + 1 })
		end
	end
	if countWeapons(member) < Config.MAX_WEAPONS then
		for _, weaponId in Config.WeaponOrder do
			if not member.weapons[weaponId] then
				table.insert(pool, { offer = { kind = "weapon", id = weaponId, level = 1 }, weight = 2 })
			end
		end
	end
	for _, passiveId in member.passiveOrder do
		local level = member.passives[passiveId]
		if level < Config.MAX_ITEM_LEVEL then
			table.insert(pool, { offer = { kind = "passive", id = passiveId, level = level + 1 }, weight = 2.5 })
		end
	end
	if #member.passiveOrder < Config.MAX_PASSIVES then
		for _, passiveId in Config.PassiveOrder do
			if not member.passives[passiveId] then
				table.insert(pool, { offer = { kind = "passive", id = passiveId, level = 1 }, weight = 1.5 })
			end
		end
	end
	local offer: { Offer } = {}
	for _, o in forced do
		if #offer < member.choiceCount then
			table.insert(offer, o)
		end
	end
	while #offer < member.choiceCount and #pool > 0 do
		local total = 0
		for _, entry in pool do
			total += entry.weight
		end
		local roll = random:NextNumber() * total
		for i, entry in pool do
			roll -= entry.weight
			if roll <= 0 or i == #pool then
				table.insert(offer, entry.offer)
				table.remove(pool, i)
				break
			end
		end
	end
	if #offer == 0 then
		offer = { { kind = "gold" }, { kind = "heal" } }
	end
	return offer
end

local function applyChoice(run: Run, member: Member, choice: Offer)
	if choice.kind == "weapon" or choice.kind == "evolve" then
		local id = choice.id :: string
		if not member.weapons[id] then
			table.insert(member.weaponOrder, id)
		end
		member.weapons[id] = choice.level :: number
		if choice.kind == "evolve" then
			addFx(run, "evolve", member.x - run.origin.X, member.z - run.origin.Z)
			deps.notify(member.player, Config.Weapons[id].evolution.emoji .. " ¡" .. Config.Weapons[id].evolution.name .. "!", "loot")
		end
	elseif choice.kind == "passive" then
		local id = choice.id :: string
		if not member.passives[id] then
			table.insert(member.passiveOrder, id)
		end
		member.passives[id] = choice.level :: number
	elseif choice.kind == "gold" then
		member.gold += 25 * run.map.scale.gold * member.goldMult
	elseif choice.kind == "heal" then
		local _, humanoid = characterOf(member.player)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
	end
	refreshStats(member)
end

---------------------------------------------------------------------
-- Armas
---------------------------------------------------------------------
local function enemiesAround(run: Run, x: number, z: number, radius: number): { Enemy }
	local found = {}
	for _, enemy in run.enemies do
		if not enemy.dead then
			local dx, dz = enemy.x - x, enemy.z - z
			local r = radius + enemy.radius
			if dx * dx + dz * dz <= r * r then
				table.insert(found, enemy)
			end
		end
	end
	return found
end

local function fireWeapon(run: Run, member: Member, weaponId: string, level: number, now: number)
	local weapon = Config.Weapons[weaponId]
	local st = Config.weaponStats(weaponId, level)
	local damage = st.damage * member.damageMult
	local ox, oz = run.origin.X, run.origin.Z
	if weapon.kind == "orbit" then
		-- Los orbes golpean continuamente (cada enemigo, como mucho cada 0,5 s)
		local orbit = st.orbit * member.areaMult
		for k = 0, st.count - 1 do
			local angle = run.time * st.speed + k / st.count * math.pi * 2
			local px, pz = member.x + math.cos(angle) * orbit, member.z + math.sin(angle) * orbit
			for _, enemy in enemiesAround(run, px, pz, 2.2 * member.areaMult) do
				local hits = enemy.orbHits
				if not hits then
					hits = {}
					enemy.orbHits = hits
				end
				if now >= ((hits :: any)[member.userId] or 0) then
					(hits :: any)[member.userId] = now + 0.5
					damageEnemy(run, enemy, damage, member, 3)
				end
			end
		end
		return
	end
	if now < (member.cooldowns[weaponId] or 0) then
		return
	end
	local cooldown = st.cooldown * member.cooldownMult
	if weapon.kind == "slash" then
		local radius = st.radius * member.areaMult
		local hit = false
		for _, enemy in enemiesAround(run, member.x, member.z, radius) do
			local dx, dz = enemy.x - member.x, enemy.z - member.z
			if st.full or dx * member.lookX + dz * member.lookZ >= -0.2 * math.sqrt(dx * dx + dz * dz) then
				damageEnemy(run, enemy, damage, member, 4)
				hit = true
			end
		end
		member.cooldowns[weaponId] = now + cooldown
		addFx(run, "slash", member.userId, member.x - ox, member.z - oz, math.atan2(-member.lookX, -member.lookZ), radius, st.full, hit)
	elseif weapon.kind == "aura" then
		local radius = st.radius * member.areaMult
		for _, enemy in enemiesAround(run, member.x, member.z, radius) do
			damageEnemy(run, enemy, damage, member, 1.5)
		end
		if st.heal then
			local _, humanoid = characterOf(member.player)
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + st.heal)
			end
		end
		member.cooldowns[weaponId] = now + cooldown
	elseif weapon.kind == "bolt" then
		local targets = enemiesAround(run, member.x, member.z, st.range)
		if #targets == 0 then
			member.cooldowns[weaponId] = now + 0.2
			return
		end
		table.sort(targets, function(a, b)
			return (a.x - member.x) ^ 2 + (a.z - member.z) ^ 2 < (b.x - member.x) ^ 2 + (b.z - member.z) ^ 2
		end)
		for i = 1, math.min(st.count, #targets) do
			local enemy = targets[i]
			addFx(run, "bolt", member.x - ox, member.z - oz, enemy.x - ox, enemy.z - oz, level > Config.MAX_ITEM_LEVEL)
			damageEnemy(run, enemy, damage, member, 2)
		end
		member.cooldowns[weaponId] = now + cooldown
	elseif weapon.kind == "dagger" then
		-- Apuntan al enemigo más cercano (o hacia delante si no hay nadie)
		local baseAngle = math.atan2(member.lookZ, member.lookX)
		local best = st.length * st.length
		for _, enemy in run.enemies do
			if not enemy.dead then
				local dx, dz = enemy.x - member.x, enemy.z - member.z
				local d2 = dx * dx + dz * dz
				if d2 < best then
					best = d2
					baseAngle = math.atan2(dz, dx)
				end
			end
		end
		for k = 1, st.count do
			local angle = baseAngle + (k - (st.count + 1) / 2) * 0.22
			local dirX, dirZ = math.cos(angle), math.sin(angle)
			local hits = {}
			for _, enemy in run.enemies do
				if not enemy.dead then
					local rx, rz = enemy.x - member.x, enemy.z - member.z
					local along = rx * dirX + rz * dirZ
					if along > 0 and along <= st.length then
						local sx, sz = rx - dirX * along, rz - dirZ * along
						local width = 1.6 + enemy.radius
						if sx * sx + sz * sz <= width * width then
							table.insert(hits, { enemy = enemy, along = along })
						end
					end
				end
			end
			table.sort(hits, function(a, b)
				return a.along < b.along
			end)
			for i = 1, math.min(st.pierce, #hits) do
				damageEnemy(run, hits[i].enemy, damage, member, 2)
			end
			addFx(run, "dagger", member.x - ox, member.z - oz, dirX, dirZ, st.length)
		end
		member.cooldowns[weaponId] = now + cooldown
	elseif weapon.kind == "lightning" then
		local targets = enemiesAround(run, member.x, member.z, st.range)
		if #targets == 0 then
			member.cooldowns[weaponId] = now + 0.3
			return
		end
		local aoe = st.aoe * member.areaMult
		for _ = 1, st.count do
			local target = targets[random:NextInteger(1, #targets)]
			local tx, tz = target.x, target.z
			for _, enemy in enemiesAround(run, tx, tz, aoe) do
				damageEnemy(run, enemy, damage, member, 2)
			end
			addFx(run, "lightning", tx - ox, tz - oz, aoe)
		end
		member.cooldowns[weaponId] = now + cooldown
	end
end

---------------------------------------------------------------------
-- Terminar la partida de un jugador
---------------------------------------------------------------------
local function cleanupRun(run: Run)
	if run.ended then
		return
	end
	run.ended = true
	runs[run.id] = nil
	slots[run.slot] = nil
	deps.destroyArena(run.slot)
end

-- result: "win" (escapó), "dead" (cayó) o "left" (abandonó o salió del juego)
local function finishMember(run: Run, member: Member, result: string, teleport: boolean)
	if member.finished then
		return
	end
	member.finished = true
	runOfPlayer[member.player] = nil
	run.byPlayer[member.player] = nil
	local rate = if result == "win" then 1 + Config.WIN_BONUS else Config.LOSS_GOLD_RATE
	deps.onFinish(member.player, {
		result = result,
		mapIndex = run.mapIndex,
		time = run.time,
		kills = member.kills,
		teamKills = run.kills,
		level = run.level,
		gold = math.floor(member.gold * rate),
		weapons = member.weapons,
	})
	if teleport then
		deps.teleport(member.player, CFrame.new(0, 4, 18))
	end
	-- Quedan jugadores en la partida?
	for _, other in run.members do
		if not other.finished then
			return
		end
	end
	cleanupRun(run)
end

---------------------------------------------------------------------
-- Paso de simulación
---------------------------------------------------------------------
local function stepRun(run: Run, dt: number, now: number)
	run.time += dt
	-- Posición y orientación de cada jugador
	for _, member in run.members do
		if not member.finished and member.alive then
			local root, humanoid = characterOf(member.player)
			if root and humanoid and humanoid.Health > 0 then
				local p = root.Position
				-- Velocidad (suavizada) para que aparezcan enemigos por delante
				member.vx += ((p.X - member.x) / dt - member.vx) * 0.2
				member.vz += ((p.Z - member.z) / dt - member.vz) * 0.2
				member.x, member.z = p.X, p.Z
				local look = root.CFrame.LookVector
				local len = math.sqrt(look.X * look.X + look.Z * look.Z)
				if len > 0.01 then
					member.lookX, member.lookZ = look.X / len, look.Z / len
				end
				if member.regen > 0 and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + member.regen * dt)
				end
			end
		end
	end
	local players = activeMembers(run)

	-- Jugadores caídos: tienen un rato para revivir; luego salen de la partida
	for _, member in run.members do
		if not member.finished and not member.alive and now - member.deadAt > RunManager.REVIVE_WINDOW then
			finishMember(run, member, "dead", false)
		end
	end
	if run.ended then
		return
	end

	if #players > 0 then
		-- Oleadas
		local rateMult = if run.boss then 0.3 elseif run.bossDead then 1.6 else 1
		run.spawnAcc = math.min(run.spawnAcc + Config.spawnRate(run.time, #run.members) * rateMult * dt, 5)
		local cap = Config.maxAlive(run.time, #run.members)
		while run.spawnAcc >= 1 do
			run.spawnAcc -= 1
			if #run.enemies < cap then
				local x, z = spawnPoint(run, players, nil)
				spawnEnemy(run, pickEnemyType(run), x, z, false)
			end
		end
		for i, elite in run.map.elites do
			if not run.elitesDone[i] and run.time >= elite.at then
				run.elitesDone[i] = true
				local x, z = spawnPoint(run, players, nil)
				spawnEnemy(run, elite.enemy, x, z, true)
			end
		end
		if not run.bossSpawned and run.time >= run.map.bossAt then
			run.bossSpawned = true
			local x, z = spawnPoint(run, players, 38)
			run.boss = spawnEnemy(run, run.map.boss, x, z, false)
			for _, member in players do
				deps.notify(member.player, "👑 ¡" .. Config.Enemies[run.map.boss].name .. " ha llegado!", "boss")
			end
		end
	end

	-- Enemigos: perseguir, empujarse y golpear
	local cellSize = 4
	local grid: { [number]: { Enemy } } = {}
	for _, enemy in run.enemies do
		if not enemy.dead then
			local key = math.floor((enemy.x - run.origin.X + 1000) / cellSize) * 4096 + math.floor((enemy.z - run.origin.Z + 1000) / cellSize)
			local cell = grid[key]
			if not cell then
				cell = {}
				grid[key] = cell
			end
			table.insert(cell, enemy)
		end
	end
	for _, enemy in run.enemies do
		if not enemy.dead then
			-- Objetivo: el jugador vivo más cercano
			local target: Member? = nil
			local best = math.huge
			for _, member in players do
				local dx, dz = member.x - enemy.x, member.z - enemy.z
				local d = dx * dx + dz * dz
				if d < best then
					best = d
					target = member
				end
			end
			local factor = 1
			if target and target.offer then
				factor = Config.SLOWMO
			end
			-- Golpe de área del jefe
			if enemy.boss and enemy.slamAt then
				if now >= enemy.slamAt then
					local slam = Config.Enemies[enemy.type].slam
					for _, member in players do
						local dx, dz = member.x - enemy.slamX, member.z - enemy.slamZ
						if dx * dx + dz * dz <= slam.radius * slam.radius then
							hurt(run, member, enemy.slamDamage)
						end
					end
					addFx(run, "slam", enemy.slamX - run.origin.X, enemy.slamZ - run.origin.Z, slam.radius)
					enemy.slamAt = nil
					enemy.nextSlam = now + slam.every
				end
			elseif target then
				if enemy.boss and now >= enemy.nextSlam and best < 30 * 30 then
					local slam = Config.Enemies[enemy.type].slam
					enemy.slamAt = now + slam.warn
					enemy.slamX, enemy.slamZ = enemy.x, enemy.z
					addFx(run, "slamwarn", enemy.x - run.origin.X, enemy.z - run.origin.Z, slam.radius, slam.warn)
				else
					local dx, dz = target.x - enemy.x, target.z - enemy.z
					local d = math.sqrt(best)
					local reach = enemy.radius + 1.6
					if d > reach * 0.8 then
						local stepLength = math.min(enemy.speed * factor * dt, d - reach * 0.8)
						enemy.x += dx / d * stepLength
						enemy.z += dz / d * stepLength
					end
					if d <= reach and now >= enemy.nextAttack and factor == 1 then
						enemy.nextAttack = now + Config.CONTACT_COOLDOWN
						hurt(run, target, enemy.damage)
					end
				end
			end
			-- Empujón de las armas
			if enemy.kbx ~= 0 or enemy.kbz ~= 0 then
				enemy.x += enemy.kbx * dt * 8
				enemy.z += enemy.kbz * dt * 8
				local decay = math.max(0, 1 - dt * 8)
				enemy.kbx *= decay
				enemy.kbz *= decay
				if math.abs(enemy.kbx) + math.abs(enemy.kbz) < 0.05 then
					enemy.kbx, enemy.kbz = 0, 0
				end
			end
			-- Separación: no se amontonan en un solo punto
			local cx = math.floor((enemy.x - run.origin.X + 1000) / cellSize)
			local cz = math.floor((enemy.z - run.origin.Z + 1000) / cellSize)
			for ix = cx - 1, cx + 1 do
				for iz = cz - 1, cz + 1 do
					local cell = grid[ix * 4096 + iz]
					if cell then
						for _, other in cell do
							if other ~= enemy and not other.dead then
								local sx, sz = enemy.x - other.x, enemy.z - other.z
								local minDist = (enemy.radius + other.radius) * 0.8
								local d2 = sx * sx + sz * sz
								if d2 < minDist * minDist and d2 > 0.0001 then
									local d = math.sqrt(d2)
									local push = (minDist - d) * 0.5
									local weight = if enemy.boss then 0.1 elseif other.boss then 1 else 0.5
									enemy.x += sx / d * push * weight
									enemy.z += sz / d * push * weight
								end
							end
						end
					end
				end
			end
			enemy.x, enemy.z = clampToArena(run, enemy.x, enemy.z, 1)
		end
	end

	-- Armas de cada jugador
	for _, member in players do
		if not member.offer then
			for _, weaponId in member.weaponOrder do
				fireWeapon(run, member, weaponId, member.weapons[weaponId], now)
			end
		end
	end

	-- Quitar enemigos muertos
	local alive = {}
	for _, enemy in run.enemies do
		if not enemy.dead then
			table.insert(alive, enemy)
		end
	end
	run.enemies = alive

	-- Recoger cristales, corazones y cofres
	for _, member in players do
		local r2 = member.magnet * member.magnet
		for id, gem in run.gems do
			local dx, dz = gem.x - member.x, gem.z - member.z
			if dx * dx + dz * dz <= r2 then
				run.gems[id] = nil
				run.gemCount -= 1
				table.insert(run.gemRemoves, id)
				table.insert(run.gemRemoves, member.userId)
				if gem.kind == 1 then
					run.xp += gem.value
				elseif gem.kind == 2 then
					local _, humanoid = characterOf(member.player)
					if humanoid and humanoid.Health > 0 then
						humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.HEART_HEAL)
					end
				else
					member.pendingChoices += 1
					member.gold += 15 * run.map.scale.gold * member.goldMult
					deps.notify(member.player, "🎁 ¡Cofre! Elige una mejora extra", "loot")
				end
			end
		end
	end

	-- Subir de nivel (la XP es del equipo; cada jugador elige su mejora)
	local needed = Config.xpToNext(run.level, #run.members)
	while run.xp >= needed do
		run.xp -= needed
		run.level += 1
		needed = Config.xpToNext(run.level, #run.members)
		for _, member in run.members do
			if not member.finished then
				member.pendingChoices += 1
				addFx(run, "levelup", member.x - run.origin.X, member.z - run.origin.Z)
			end
		end
	end
	for _, member in run.members do
		if not member.finished then
			if member.offer and now - member.offerAt > Config.CHOICE_TIMEOUT then
				RunManager.choose(member.player, 1)
			end
			if not member.offer and member.pendingChoices > 0 and member.alive then
				member.offer = buildOffer(member)
				member.offerAt = now
				deps.markDirty(member.player)
			end
		end
	end

	-- Portal de escape
	if run.portalEndsAt then
		for _, member in players do
			local dx, dz = member.x - run.portalX, member.z - run.portalZ
			if dx * dx + dz * dz <= Config.PORTAL_RADIUS * Config.PORTAL_RADIUS then
				finishMember(run, member, "win", true)
			end
		end
		if not run.ended and run.time >= (run.portalEndsAt :: number) then
			for _, member in run.members do
				if not member.finished then
					finishMember(run, member, "dead", true)
				end
			end
		end
	end
end

-- Envía a cada jugador de la partida las posiciones de los enemigos (compacto)
local function sendSnapshot(run: Run)
	local count = 0
	for _, enemy in run.enemies do
		if not enemy.dead then
			count += 1
		end
	end
	local b = buffer.create(2 + count * 9)
	buffer.writeu16(b, 0, count)
	local offset = 2
	for _, enemy in run.enemies do
		if not enemy.dead then
			buffer.writeu16(b, offset, enemy.id)
			buffer.writeu8(b, offset + 2, enemy.typeIndex)
			buffer.writeu8(b, offset + 3, math.clamp(math.ceil(enemy.hp / enemy.maxHp * 255), 0, 255))
			buffer.writeu8(b, offset + 4, (if enemy.elite then 1 else 0) + (if enemy.boss then 2 else 0) + (if enemy.slamAt then 4 else 0))
			buffer.writei16(b, offset + 5, math.clamp(math.floor((enemy.x - run.origin.X) * 4), -32768, 32767))
			buffer.writei16(b, offset + 7, math.clamp(math.floor((enemy.z - run.origin.Z) * 4), -32768, 32767))
			offset += 9
		end
	end
	for _, member in run.members do
		if not member.finished then
			deps.sendSwarm(member.player, b, run.gemAdds, run.gemRemoves, run.fx)
		end
	end
	run.gemAdds = {}
	run.gemRemoves = {}
	run.fx = {}
end

function RunManager.step(dt: number)
	local now = os.clock()
	for _, run in runs do
		stepRun(run, dt, now)
		if not run.ended then
			run.snapshotAcc += dt
			if run.snapshotAcc >= RunManager.SNAPSHOT then
				run.snapshotAcc = 0
				sendSnapshot(run)
			end
		end
	end
end

---------------------------------------------------------------------
-- API para el servidor
---------------------------------------------------------------------
function RunManager.init(dependencies: Deps)
	deps = dependencies
end

function RunManager.runOf(player: Player): any
	return runOfPlayer[player]
end

-- Empieza una partida con estos jugadores (1 a 4) en un mapa
function RunManager.startRun(players: { Player }, mapIndex: number): (boolean, string?)
	local slot = nil
	for i = 1, Config.ARENA_SLOTS do
		if not slots[i] then
			slot = i
			break
		end
	end
	if not slot then
		return false, "Todas las arenas están ocupadas. Espera un momento."
	end
	for _, player in players do
		if runOfPlayer[player] then
			return false, player.DisplayName .. " ya está en una partida"
		end
	end
	slots[slot] = true
	nextRunId += 1
	local origin = deps.buildArena(slot, mapIndex)
	local run: Run = {
		id = nextRunId,
		slot = slot,
		mapIndex = mapIndex,
		map = Config.Maps[mapIndex],
		origin = origin,
		members = {},
		byPlayer = {},
		time = 0,
		enemies = {},
		nextEnemyId = 0,
		gems = {},
		gemCount = 0,
		nextGemId = 0,
		gemAdds = {},
		gemRemoves = {},
		fx = {},
		level = 1,
		xp = 0,
		kills = 0,
		spawnAcc = 0,
		elitesDone = {},
		boss = nil,
		bossSpawned = false,
		bossDead = false,
		portalX = 0,
		portalZ = 0,
		portalEndsAt = nil,
		snapshotAcc = 0,
		ended = false,
	}
	runs[run.id] = run
	for i, player in players do
		local base = deps.baseStats(player)
		local bonuses = deps.bonuses(player)
		local weapon = deps.classWeapon(player)
		local member: Member = {
			player = player,
			userId = player.UserId,
			name = player.DisplayName,
			alive = true,
			finished = false,
			deadAt = 0,
			weapons = { [weapon] = 1 },
			weaponOrder = { weapon },
			passives = {},
			passiveOrder = {},
			cooldowns = {},
			base = base,
			damageMult = 1,
			cooldownMult = 1,
			areaMult = 1,
			maxHealth = base.health,
			speedMult = 1,
			magnet = Config.PICKUP_RADIUS,
			armor = 0,
			regen = 0,
			goldMult = Config.goldMult(base, bonuses),
			choiceCount = if bonuses.choicePass then 4 else 3,
			pendingChoices = 0,
			offer = nil,
			offerAt = 0,
			rerolls = Config.BASE_REROLLS + (if bonuses.rerollPass then 3 else 0),
			lives = base.lives,
			invulnerableUntil = os.clock() + 2,
			dashReadyAt = 0,
			gold = 0,
			kills = 0,
			x = origin.X,
			z = origin.Z,
			lookX = 0,
			lookZ = -1,
			vx = 0,
			vz = 0,
		}
		table.insert(run.members, member)
		run.byPlayer[player] = member
		runOfPlayer[player] = run
		local angle = (i - 1) / #players * math.pi * 2
		local spawn = origin + Vector3.new(math.cos(angle) * 4, 4, math.sin(angle) * 4)
		member.x, member.z = spawn.X, spawn.Z
		deps.teleport(player, CFrame.new(spawn))
		refreshStats(member)
		local _, humanoid = characterOf(player)
		if humanoid then
			humanoid.Health = member.maxHealth
		end
		deps.markDirty(player)
	end
	return true, nil
end

function RunManager.choose(player: Player, index: any): (boolean, string?)
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if not run or not member or not member.offer then
		return false, "No hay ninguna mejora que elegir"
	end
	local choice = type(index) == "number" and member.offer[index]
	if not choice then
		return false, "Opción no válida"
	end
	member.offer = nil
	member.pendingChoices = math.max(0, member.pendingChoices - 1)
	member.invulnerableUntil = math.max(member.invulnerableUntil, os.clock() + 0.5)
	applyChoice(run, member, choice)
	deps.markDirty(player)
	return true, nil
end

function RunManager.reroll(player: Player): (boolean, string?)
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if not member or not member.offer then
		return false, "No hay ninguna mejora que cambiar"
	end
	if member.rerolls <= 0 then
		return false, "🎲 No te quedan cambios en esta partida"
	end
	member.rerolls -= 1
	member.offer = buildOffer(member)
	deps.markDirty(player)
	return true, nil
end

function RunManager.dash(player: Player): boolean
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	local now = os.clock()
	if not member or not member.alive or now < member.dashReadyAt - 0.15 then
		return false
	end
	member.dashReadyAt = now + Config.DASH_COOLDOWN
	member.invulnerableUntil = math.max(member.invulnerableUntil, now + Config.DASH_INVULNERABLE)
	return true
end

-- El jugador abandona (se queda la mitad del oro)
function RunManager.leave(player: Player): (boolean, string?)
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if not run or not member then
		return false, "No estás en ninguna partida"
	end
	finishMember(run, member, "left", true)
	return true, nil
end

function RunManager.playerRemoving(player: Player)
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if run and member then
		finishMember(run, member, "left", false)
	end
end

function RunManager.onDied(player: Player)
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if member and member.alive then
		member.alive = false
		member.deadAt = os.clock()
		member.offer = nil
		deps.markDirty(player)
	end
end

-- Producto "Revivir": vuelve a la partida junto a un compañero (o al centro)
function RunManager.revive(player: Player): boolean
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if not run or not member or member.alive then
		return false
	end
	member.alive = true
	member.invulnerableUntil = os.clock() + Config.REVIVE_INVULNERABLE
	local x, z = run.origin.X, run.origin.Z
	for _, other in activeMembers(run) do
		if other ~= member then
			x, z = other.x + 3, other.z
			break
		end
	end
	member.x, member.z = x, z
	task.spawn(function()
		local _, humanoid = characterOf(player)
		if not humanoid or humanoid.Health <= 0 then
			player:LoadCharacterAsync()
			task.wait(0.2)
		end
		deps.teleport(player, CFrame.new(x, 4, z))
		refreshStats(member)
		local _, newHumanoid = characterOf(player)
		if newHumanoid then
			newHumanoid.Health = member.maxHealth
		end
	end)
	deps.markDirty(player)
	return true
end

-- Al reaparecer el personaje (p. ej. tras revivir) se le aplican las estadísticas de partida
function RunManager.onCharacter(player: Player): boolean
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if member and member.alive then
		refreshStats(member)
		return true
	end
	return false
end

-- Información de la partida para la interfaz del jugador
function RunManager.stateFor(player: Player): any
	local run = runOfPlayer[player]
	local member = run and run.byPlayer[player]
	if not run or not member then
		return nil
	end
	local team = {}
	for _, other in run.members do
		if not other.finished then
			table.insert(team, {
				userId = other.userId,
				name = other.name,
				alive = other.alive,
				weapons = other.weapons,
				weaponOrder = other.weaponOrder,
			})
		end
	end
	local boss = nil
	if run.boss and not run.boss.dead then
		boss = { name = Config.Enemies[run.boss.type].name, hp = run.boss.hp / run.boss.maxHp }
	end
	return {
		map = run.map.id,
		mapIndex = run.mapIndex,
		time = run.time,
		bossAt = run.map.bossAt,
		level = run.level,
		xp = run.xp,
		xpNeeded = Config.xpToNext(run.level, #run.members),
		kills = member.kills,
		teamKills = run.kills,
		gold = math.floor(member.gold),
		alive = member.alive,
		lives = member.lives,
		weapons = member.weapons,
		weaponOrder = member.weaponOrder,
		passives = member.passives,
		passiveOrder = member.passiveOrder,
		offer = member.offer,
		pending = member.pendingChoices,
		rerolls = member.rerolls,
		team = team,
		boss = boss,
		portal = if run.portalEndsAt then { x = run.portalX - run.origin.X, z = run.portalZ - run.origin.Z, left = (run.portalEndsAt :: number) - run.time } else nil,
		origin = run.origin,
		magnet = member.magnet,
		areaMult = member.areaMult,
		dashCooldown = Config.DASH_COOLDOWN,
	}
end

-- Para las pruebas automáticas
function RunManager.debugRuns(): { [number]: any }
	return runs
end

return RunManager
