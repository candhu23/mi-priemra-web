--[[
	CombatService (ModuleScript en ServerScriptService)

	Todo el combate ocurre en el servidor (así nadie hace trampas):
	  · enemigos: aparecen en su sitio, persiguen al jugador más cercano,
	    atacan, vuelven a casa si se alejan demasiado y reaparecen al morir
	  · jefes: además dan un golpe de área con aviso rojo en el suelo
	    (te da tiempo a apartarte)
	  · habilidades del jugador: comprueba nivel y tiempo de recarga y
	    reparte el daño
	  · cooperativo: todos los que golpean a un enemigo reciben premio

	Los enemigos son piezas ancladas que el servidor mueve (no usan
	física), así siempre van donde deben.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))
local EnemyModels = require(script.Parent:WaitForChild("EnemyModels"))

local CombatService = {}

type Enemy = {
	uid: number,
	def: any,
	stats: any,
	zoneId: string,
	zoneIndex: number,
	isBoss: boolean,
	model: Model,
	root: BasePart,
	height: number,
	radius: number,
	bar: Frame,
	home: Vector3,
	pos: Vector3,
	yaw: number,
	hp: number,
	alive: boolean,
	respawnAt: number,
	target: Player?,
	returning: boolean,
	nextAttack: number,
	lungeUntil: number,
	phase: number,
	contrib: { [Player]: number },
	nextSlam: number,
	slamAt: number?,
	slamPos: Vector3?,
	warning: BasePart?,
}

type Deps = {
	level: (Player) -> number?,
	stats: (Player) -> any,
	onKill: (Player, any) -> (),
	send: (Player, string, any, any?) -> (),
	fx: (Player?, string, Vector3, any?) -> (),
	zoneMessage: (string, string) -> (),
}

local deps: Deps = nil :: any
local random = Random.new()
local enemies: { Enemy } = {}
local enemyFolder: Folder = nil :: any
local cooldowns: { [Player]: { [string]: number } } = {}
local nextUid = 0

CombatService.TICK = 1 / 15 -- el servidor mueve a los enemigos 15 veces por segundo

---------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function yawFor(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

type Fighter = { player: Player, root: BasePart, humanoid: Humanoid }

local function fighterOf(player: Player): Fighter?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return { player = player, root = root, humanoid = humanoid }
end

local function updateBar(enemy: Enemy)
	local ratio = math.clamp(enemy.hp / enemy.stats.hp, 0, 1)
	enemy.bar.Size = UDim2.fromScale(ratio, 1)
	enemy.bar.BackgroundColor3 = if ratio > 0.5 then Color3.fromRGB(34, 197, 94) elseif ratio > 0.25 then Color3.fromRGB(234, 179, 8) else Color3.fromRGB(239, 68, 68)
end

local function render(enemy: Enemy, now: number)
	local bob = 0
	if enemy.def.model == "flyer" then
		bob = math.sin(enemy.phase * 3) * 0.6
	elseif enemy.def.model == "slime" then
		bob = math.abs(math.sin(enemy.phase * 5)) * 0.8
	end
	local lunge = if now < enemy.lungeUntil then CFrame.new(0, 0, -1.2) else CFrame.new()
	enemy.model:PivotTo(CFrame.new(enemy.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, enemy.yaw, 0) * lunge)
end

local function clearWarning(enemy: Enemy)
	if enemy.warning then
		enemy.warning:Destroy()
		enemy.warning = nil
	end
	enemy.slamAt = nil
	enemy.slamPos = nil
end

---------------------------------------------------------------------
-- Crear y reaparecer enemigos
---------------------------------------------------------------------
local function createEnemy(enemyId: string, zone: any, position: Vector3): Enemy
	local def = Config.Enemies[enemyId]
	local stats = Config.enemyStats(enemyId, zone.index)
	local model, height = EnemyModels.build(def)
	local root = model.PrimaryPart :: BasePart
	nextUid += 1
	model:SetAttribute("EnemyId", nextUid)

	-- Nombre, nivel y barra de vida
	local gui = Instance.new("BillboardGui")
	gui.Name = "Vida"
	gui.Size = if def.boss then UDim2.fromOffset(240, 46) else UDim2.fromOffset(130, 34)
	gui.StudsOffset = Vector3.new(0, height + 1.5, 0)
	gui.MaxDistance = if def.boss then 160 else 70
	gui.LightInfluence = 0
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.55)
	label.Text = (if def.boss then "👑 " else "") .. def.name .. " · Nv " .. stats.level
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = if def.boss then Color3.fromRGB(252, 165, 165) else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0.05, 0.6)
	back.Size = UDim2.fromScale(0.9, 0.32)
	back.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = back
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
	bar.Parent = back
	corner:Clone().Parent = bar

	local enemy: Enemy = {
		uid = nextUid,
		def = def,
		stats = stats,
		zoneId = zone.id,
		zoneIndex = zone.index,
		isBoss = def.boss == true,
		model = model,
		root = root,
		height = height,
		radius = 1.6 * def.size,
		bar = bar,
		home = position,
		pos = position,
		yaw = random:NextNumber(0, math.pi * 2),
		hp = stats.hp,
		alive = true,
		respawnAt = 0,
		target = nil,
		returning = false,
		nextAttack = 0,
		lungeUntil = 0,
		phase = random:NextNumber(0, 10),
		contrib = {},
		nextSlam = 0,
		slamAt = nil,
		slamPos = nil,
		warning = nil,
	}
	render(enemy, 0)
	model.Parent = enemyFolder
	table.insert(enemies, enemy)
	return enemy
end

local function respawn(enemy: Enemy)
	enemy.alive = true
	enemy.hp = enemy.stats.hp
	enemy.pos = enemy.home
	enemy.target = nil
	enemy.returning = false
	enemy.contrib = {}
	updateBar(enemy)
	render(enemy, 0)
	enemy.model.Parent = enemyFolder
	if enemy.isBoss then
		deps.zoneMessage(enemy.zoneId, "👑 ¡" .. enemy.def.name .. " ha aparecido en su guarida!")
	end
end

local function kill(enemy: Enemy)
	enemy.alive = false
	enemy.target = nil
	clearWarning(enemy)
	enemy.model.Parent = nil
	enemy.respawnAt = os.clock() + (if enemy.isBoss then Config.BOSS_RESPAWN else Config.ENEMY_RESPAWN)
	local info = {
		enemyId = enemy.def.id,
		zoneIndex = enemy.zoneIndex,
		isBoss = enemy.isBoss,
		stats = enemy.stats,
		position = enemy.pos + Vector3.new(0, enemy.height * 0.6, 0),
	}
	local contributors = enemy.contrib
	enemy.contrib = {}
	for player in contributors do
		if player.Parent then
			deps.onKill(player, info)
		end
	end
	deps.fx(nil, "death", info.position, enemy.def.color)
end

---------------------------------------------------------------------
-- Daño a enemigos
---------------------------------------------------------------------
local function damageEnemy(player: Player, enemy: Enemy, amount: number)
	if not enemy.alive then
		return
	end
	enemy.hp -= amount
	enemy.contrib[player] = (enemy.contrib[player] or 0) + amount
	if not enemy.target and not enemy.returning then
		enemy.target = player
	end
	if enemy.hp <= 0 then
		kill(enemy)
	else
		updateBar(enemy)
	end
end

-- Enemigos vivos cerca de un punto (distancia en horizontal), del más cercano al más lejano
local function enemiesNear(position: Vector3, radius: number): { Enemy }
	local found = {}
	for _, enemy in enemies do
		if enemy.alive and (flat(enemy.pos) - flat(position)).Magnitude <= radius + enemy.radius then
			table.insert(found, enemy)
		end
	end
	table.sort(found, function(a, b)
		return (a.pos - position).Magnitude < (b.pos - position).Magnitude
	end)
	return found
end

local function enemiesInLine(start: Vector3, direction: Vector3, length: number, width: number): { Enemy }
	local found = {}
	for _, enemy in enemies do
		if enemy.alive then
			local rel = flat(enemy.pos) - flat(start)
			local along = rel:Dot(direction)
			if along >= -2 and along <= length + enemy.radius then
				local side = (rel - direction * along).Magnitude
				if side <= width + enemy.radius then
					table.insert(found, enemy)
				end
			end
		end
	end
	return found
end

-- El jugador usa una habilidad. Devuelve si se pudo y, si no, por qué.
function CombatService.useSkill(player: Player, skillId: any): (boolean, string?)
	local skill = type(skillId) == "string" and Config.SkillById[skillId]
	if not skill then
		return false, "Habilidad desconocida"
	end
	local level = deps.level(player)
	if not level then
		return false, nil
	end
	if level < skill.level then
		return false, skill.emoji .. " " .. skill.name .. " se desbloquea en el nivel " .. skill.level
	end
	local fighter = fighterOf(player)
	if not fighter then
		return false, nil
	end
	local now = os.clock()
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	-- Un pequeño margen por el retraso de la red
	if now < (playerCooldowns[skill.id] or 0) - 0.15 then
		return false, nil
	end
	playerCooldowns[skill.id] = now + skill.cooldown

	local position = fighter.root.Position
	local look = flat(fighter.root.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	if skill.kind == "heal" then
		local humanoid = fighter.humanoid
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * skill.heal)
		deps.fx(player, skill.id, position, nil)
		return true, nil
	end

	local targets: { Enemy }
	if skill.kind == "dash" then
		targets = enemiesInLine(position, look, skill.length, skill.width)
	else
		targets = enemiesNear(position, skill.radius)
	end
	local stats = deps.stats(player)
	local hits = {}
	for i, enemy in targets do
		if i > skill.maxTargets then
			break
		end
		local crit = random:NextNumber() < stats.critChance
		local amount = math.floor(stats.damage * skill.mult * (if crit then Config.CRIT_MULT else 1) * random:NextNumber(0.9, 1.1))
		amount = math.max(1, amount)
		local hitPos = enemy.pos + Vector3.new(0, enemy.height * 0.75, 0)
		damageEnemy(player, enemy, amount)
		table.insert(hits, { p = hitPos, d = amount, c = crit })
	end
	if #hits > 0 then
		deps.send(player, "hits", hits)
	end
	deps.fx(player, skill.id, position, look)
	return true, nil
end

---------------------------------------------------------------------
-- Inteligencia de los enemigos
---------------------------------------------------------------------
local function moveTowards(enemy: Enemy, point: Vector3, speed: number, dt: number, stopAt: number)
	local delta = flat(point) - flat(enemy.pos)
	local distance = delta.Magnitude
	if distance < 0.05 then
		return
	end
	local direction = delta / distance
	enemy.yaw = yawFor(direction)
	local stepLength = math.min(speed * dt, math.max(0, distance - stopAt))
	enemy.pos += direction * stepLength
	enemy.phase += dt
end

local function startSlam(enemy: Enemy, now: number)
	local slam = enemy.def.slam
	enemy.slamAt = now + slam.warn
	enemy.slamPos = enemy.pos
	local warning = Instance.new("Part")
	warning.Name = "AvisoGolpe"
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanTouch = false
	warning.CanQuery = false
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(0.3, slam.radius * 2, slam.radius * 2)
	warning.CFrame = CFrame.new(enemy.pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	warning.Color = Color3.fromRGB(239, 68, 68)
	warning.Material = Enum.Material.Neon
	warning.Transparency = 0.55
	warning.Parent = enemyFolder
	enemy.warning = warning
end

local function resolveSlam(enemy: Enemy, fighters: { Fighter })
	local slam = enemy.def.slam
	local center = enemy.slamPos or enemy.pos
	for _, fighter in fighters do
		if (flat(fighter.root.Position) - flat(center)).Magnitude <= slam.radius then
			fighter.humanoid:TakeDamage(enemy.stats.slamDamage)
			deps.send(fighter.player, "hurt", enemy.stats.slamDamage)
		end
	end
	deps.fx(nil, "slam", center, slam.radius)
	clearWarning(enemy)
	enemy.nextSlam = os.clock() + slam.every
	enemy.lungeUntil = os.clock() + 0.3
end

local function think(enemy: Enemy, fighters: { Fighter }, dt: number, now: number)
	-- ¿Sigue siendo válido el objetivo?
	local target: Fighter? = nil
	if enemy.target then
		for _, fighter in fighters do
			if fighter.player == enemy.target then
				target = fighter
				break
			end
		end
		if target and (flat(target.root.Position) - flat(enemy.home)).Magnitude > Config.ENEMY_LEASH then
			target = nil
			enemy.returning = true
		end
		if not target then
			enemy.target = nil
		end
	end
	-- Buscar al jugador más cercano
	if not target and not enemy.returning then
		local best = Config.ENEMY_AGGRO + (if enemy.isBoss then 10 else 0)
		for _, fighter in fighters do
			local distance = (flat(fighter.root.Position) - flat(enemy.pos)).Magnitude
			if distance < best then
				best = distance
				target = fighter
			end
		end
		enemy.target = if target then target.player else nil
		if target and enemy.isBoss and enemy.nextSlam < now then
			enemy.nextSlam = now + 2
		end
	end

	-- Golpe de área del jefe
	if enemy.slamAt then
		if now >= enemy.slamAt then
			resolveSlam(enemy, fighters)
		end
		return -- quieto mientras carga el golpe
	end
	if enemy.isBoss and target and now >= enemy.nextSlam then
		startSlam(enemy, now)
		return
	end

	if target then
		local reach = 3 + enemy.radius
		local distance = (flat(target.root.Position) - flat(enemy.pos)).Magnitude
		if distance > reach then
			moveTowards(enemy, target.root.Position, enemy.def.speed, dt, reach * 0.8)
		else
			enemy.yaw = yawFor((flat(target.root.Position) - flat(enemy.pos)).Unit)
			enemy.phase += dt * 0.5
			if now >= enemy.nextAttack then
				enemy.nextAttack = now + enemy.def.cooldown
				enemy.lungeUntil = now + 0.18
				target.humanoid:TakeDamage(enemy.stats.damage)
				deps.send(target.player, "hurt", enemy.stats.damage)
			end
		end
	else
		-- Volver a casa y recuperar vida
		local away = (flat(enemy.home) - flat(enemy.pos)).Magnitude
		if away > 1 then
			moveTowards(enemy, enemy.home, enemy.def.speed * 1.3, dt, 0)
		else
			enemy.returning = false
			enemy.phase += dt * 0.4
		end
		if enemy.hp < enemy.stats.hp then
			enemy.hp = math.min(enemy.stats.hp, enemy.hp + enemy.stats.hp * Config.ENEMY_REGEN_OUT_OF_COMBAT * dt)
			updateBar(enemy)
			if enemy.hp >= enemy.stats.hp then
				enemy.contrib = {}
			end
		end
	end
end

-- Un paso de simulación (lo llama el servidor ~15 veces por segundo)
function CombatService.step(dt: number)
	local now = os.clock()
	-- Jugadores vivos agrupados por zona
	local byZone: { [string]: { Fighter } } = {}
	local zoneOf = CombatService.zoneAt
	for _, player in Players:GetPlayers() do
		local fighter = fighterOf(player)
		if fighter then
			local zoneId = zoneOf(fighter.root.Position)
			if zoneId then
				byZone[zoneId] = byZone[zoneId] or {}
				table.insert(byZone[zoneId], fighter)
			end
		end
	end
	for _, enemy in enemies do
		if not enemy.alive then
			if now >= enemy.respawnAt then
				respawn(enemy)
			end
		else
			local fighters = byZone[enemy.zoneId]
			-- Si no hay nadie en la zona, el enemigo ni se mueve (ahorra servidor)
			if fighters or enemy.target or enemy.returning or enemy.hp < enemy.stats.hp then
				think(enemy, fighters or {}, dt, now)
				render(enemy, now)
			end
		end
	end
end

---------------------------------------------------------------------
-- Arranque y utilidades
---------------------------------------------------------------------
CombatService.zoneAt = function(_position: Vector3): string?
	return nil
end

function CombatService.init(zones: { [string]: any }, zoneAt: (Vector3) -> string?, dependencies: Deps)
	deps = dependencies
	CombatService.zoneAt = zoneAt
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "Enemigos"
	enemyFolder.Parent = Workspace
	for _, zone in Config.Zones do
		local info = zones[zone.id]
		for _, spawnPoint in info.spawns do
			createEnemy(spawnPoint.enemy, zone, spawnPoint.position)
		end
		createEnemy(info.boss.enemy, zone, info.boss.position)
	end
end

function CombatService.removePlayer(player: Player)
	cooldowns[player] = nil
	for _, enemy in enemies do
		enemy.contrib[player] = nil
		if enemy.target == player then
			enemy.target = nil
		end
	end
end

-- Para las pruebas automáticas
function CombatService.debugEnemies(): { Enemy }
	return enemies
end

return CombatService
