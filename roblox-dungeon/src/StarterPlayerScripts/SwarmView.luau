--[[
	SwarmView (ModuleScript en StarterPlayerScripts)

	Dibuja la partida en el cliente:
	  · la horda: recibe del servidor posiciones compactas 10 veces por
	    segundo y mueve los modelos suavemente (interpolando) cada fotograma
	  · cristales de XP, corazones y cofres
	  · efectos de las armas: espada que gira con estela, bolas mágicas con
	    cola, dagas y hachas que vuelan girando, bombas en parábola que
	    explotan, rayos en zigzag, ondas del martillo, aura con chispas y
	    orbes con estela; avisos del jefe y el portal
	  · enemigos con sombra, que salen del suelo, parpadean en blanco al
	    recibir un golpe y estallan en trocitos al morir
	  · números de daño (calculados por la bajada de vida de cada enemigo)
	Solo dibuja: todo lo importante lo decide el servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local EnemyModels = require(ReplicatedStorage:WaitForChild("EnemyModels"))

local SwarmView = {}

type View = {
	id: number,
	key: string,
	typeIndex: number,
	elite: boolean,
	boss: boolean,
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	height: number,
	bar: Frame?,
	prevX: number,
	prevZ: number,
	x: number,
	z: number,
	yaw: number,
	hp: number,
	phase: number,
	shadow: BasePart,
	shadowSize: number,
	colors: { Color3 },
	bornAt: number,
	flashUntil: number,
}

local player = Players.LocalPlayer
local random = Random.new()
local folder: Folder = nil :: any
local views: { [number]: View } = {}
local pool: { [string]: { View } } = {}
local gems: { [number]: BasePart } = {}
local origin = Vector3.new()
local runState: any = nil
local runStateAt = 0
local snapshotAt = 0
local snapshotInterval = 0.1
local activeNumbers = 0
local deathPuffsThisFrame = 0
local auraParts: { [number]: BasePart } = {}
local orbParts: { [number]: { BasePart } } = {}
local portalModel: Model? = nil
local warnings: { BasePart } = {}
local playSound: (string) -> () = function() end
local flashesThisSnapshot = 0
local spawnPuffsThisSnapshot = 0

-- Animaciones cortas que se actualizan cada fotograma (alpha de 0 a 1)
type Anim = { startAt: number, duration: number, step: (number) -> (), done: (() -> ())? }
local anims: { Anim } = {}
local function animate(duration: number, step: (number) -> (), done: (() -> ())?)
	table.insert(anims, { startAt = os.clock(), duration = duration, step = step, done = done })
	step(0)
end

local ENEMY_HEIGHT_OFFSET = 0

---------------------------------------------------------------------
-- Piezas de efectos
---------------------------------------------------------------------
local function effectPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Parent = folder
	return part
end

local function fadeOut(part: BasePart, duration: number, goal: { [string]: any }?)
	local props = goal or {}
	props.Transparency = 1
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	task.delay(duration + 0.05, function()
		part:Destroy()
	end)
end

-- Disco plano (los cilindros de Roblox van a lo largo de X: se giran 90° en Z)
local function disc(position: Vector3, diameter: number, color: Color3, transparency: number): Part
	return effectPart(Enum.PartType.Cylinder, Vector3.new(0.2, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, transparency)
end

local function world(x: number, z: number, y: number?): Vector3
	return origin + Vector3.new(x, y or 0, z)
end

local function rootOf(userId: number): BasePart?
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------------
-- Números de daño
---------------------------------------------------------------------
local function floatingText(position: Vector3, text: string, color: Color3, size: number, duration: number)
	if activeNumbers > 30 then
		return
	end
	activeNumbers += 1
	local anchor = effectPart(Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position + Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))), color, 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 5, size * 1.5)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, duration * 0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(duration + 0.05, function()
		activeNumbers -= 1
		anchor:Destroy()
	end)
end
SwarmView.floatingText = floatingText

---------------------------------------------------------------------
-- Enemigos
---------------------------------------------------------------------
local function acquire(typeIndex: number, elite: boolean, boss: boolean): View
	local key = typeIndex .. (if elite then "e" else "")
	local list = pool[key]
	local view = list and table.remove(list)
	if view then
		view.model.Parent = folder
		return view
	end
	local def = Config.Enemies[Config.EnemyList[typeIndex]]
	local model, height = EnemyModels.build(def, elite)
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, d.CFrame)
		end
	end
	-- Sombra redonda bajo el enemigo (no se balancea con él)
	local shadowSize = math.max(2.4, def.size * (if elite then 1.7 else 1) * 3.2)
	local shadow = Instance.new("Part")
	shadow.Name = "Sombra"
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanTouch = false
	shadow.CanQuery = false
	shadow.CastShadow = false
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Size = Vector3.new(0.1, shadowSize, shadowSize)
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Transparency = 0.6
	shadow.Parent = model
	local colors: { Color3 } = {}
	for _, part in parts do
		table.insert(colors, part.Color)
	end
	local bar: Frame? = nil
	if elite or boss then
		local gui = Instance.new("BillboardGui")
		gui.Size = if boss then UDim2.fromOffset(200, 16) else UDim2.fromOffset(90, 10)
		gui.StudsOffset = Vector3.new(0, height + 1.2, 0)
		gui.LightInfluence = 0
		gui.MaxDistance = 200
		gui.Parent = model.PrimaryPart
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
		back.BorderSizePixel = 0
		back.Parent = gui
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = if boss then Color3.fromRGB(239, 68, 68) else Color3.fromRGB(251, 146, 60)
		fill.BorderSizePixel = 0
		fill.Parent = back
		bar = fill
	end
	model.Parent = folder
	return {
		id = 0,
		key = key,
		typeIndex = typeIndex,
		elite = elite,
		boss = boss,
		model = model,
		parts = parts,
		offsets = offsets,
		height = height,
		bar = bar,
		prevX = 0,
		prevZ = 0,
		x = 0,
		z = 0,
		yaw = 0,
		hp = 255,
		phase = random:NextNumber(0, 10),
		shadow = shadow,
		shadowSize = shadowSize,
		colors = colors,
		bornAt = 0,
		flashUntil = 0,
	}
end

-- Parpadeo blanco al recibir un golpe
local WHITE = Color3.new(1, 1, 1)
local function flash(view: View, now: number)
	if view.flashUntil > now or flashesThisSnapshot > 40 then
		return
	end
	flashesThisSnapshot += 1
	view.flashUntil = now + 0.09
	for _, part in view.parts do
		if part.Transparency < 1 then
			part.Color = WHITE
		end
	end
end

local function unflash(view: View)
	for i, part in view.parts do
		part.Color = view.colors[i]
	end
end

local function release(view: View)
	if view.flashUntil > 0 then
		unflash(view)
		view.flashUntil = 0
	end
	view.model.Parent = nil
	local list = pool[view.key]
	if not list then
		list = {}
		pool[view.key] = list
	end
	if #list < 60 then
		table.insert(list, view)
	else
		view.model:Destroy()
	end
end

local function deathPuff(x: number, z: number, typeIndex: number)
	if deathPuffsThisFrame > 12 then
		return
	end
	deathPuffsThisFrame += 1
	local def = Config.Enemies[Config.EnemyList[typeIndex]]
	local color = if def then def.color else Color3.new(1, 1, 1)
	local size = if def then def.size else 1
	local pos = world(x, z, 1.5 * size)
	-- Destello blanco + trocitos del color del enemigo que saltan y caen
	fadeOut(effectPart(Enum.PartType.Ball, Vector3.new(1, 1, 1) * 1.5 * size, CFrame.new(pos), Color3.fromRGB(255, 250, 230), 0.2), 0.25, { Size = Vector3.new(1, 1, 1) * 4 * size })
	for _ = 1, 5 do
		local cube = effectPart(Enum.PartType.Block, Vector3.new(0.6, 0.6, 0.6) * size, CFrame.new(pos) * CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0), color, 0)
		cube.Material = Enum.Material.SmoothPlastic
		local vx, vz = random:NextNumber(-7, 7), random:NextNumber(-7, 7)
		local vy = random:NextNumber(6, 11)
		local spin = random:NextNumber(4, 10)
		animate(0.55, function(a)
			local t = a * 0.55
			cube.CFrame = CFrame.new(pos + Vector3.new(vx * t, vy * t - 30 * t * t, vz * t)) * CFrame.Angles(spin * t, spin * t * 0.7, 0)
			cube.Transparency = math.max(0, a - 0.5) * 2
		end, function()
			cube:Destroy()
		end)
	end
end

-- Polvo al salir del suelo
local function spawnPuff(x: number, z: number)
	if spawnPuffsThisSnapshot > 6 then
		return
	end
	spawnPuffsThisSnapshot += 1
	local ring = disc(world(x, z, 0.15), 1.5, Color3.fromRGB(120, 100, 80), 0.4)
	ring.Material = Enum.Material.SmoothPlastic
	fadeOut(ring, 0.4, { Size = Vector3.new(0.1, 5, 5) })
end

---------------------------------------------------------------------
-- Cristales
---------------------------------------------------------------------
local GEM_STYLE = {
	[1] = { size = Vector3.new(0.9, 0.9, 0.9), color = Color3.fromRGB(168, 85, 247), shape = Enum.PartType.Block },
	[2] = { size = Vector3.new(1.4, 1.4, 1.4), color = Color3.fromRGB(239, 68, 68), shape = Enum.PartType.Ball },
	[3] = { size = Vector3.new(2.2, 1.6, 1.6), color = Color3.fromRGB(251, 191, 36), shape = Enum.PartType.Block },
}

local function addGem(id: number, kind: number, x: number, z: number)
	local style = GEM_STYLE[kind] or GEM_STYLE[1]
	local part = effectPart(style.shape, style.size, CFrame.new(world(x, z, 1)) * CFrame.Angles(math.rad(45), math.rad(45), 0), style.color, 0.05)
	part.Name = "Cristal"
	if kind == 3 then
		part.Material = Enum.Material.Wood
		local light = Instance.new("PointLight")
		light.Color = style.color
		light.Range = 10
		light.Parent = part
	end
	local old = gems[id]
	if old then
		old:Destroy()
	end
	gems[id] = part
end

local function removeGem(id: number, collector: number)
	local part = gems[id]
	if not part then
		return
	end
	gems[id] = nil
	local target = rootOf(collector)
	if target then
		TweenService:Create(part, TweenInfo.new(0.15), { CFrame = target.CFrame }):Play()
		task.delay(0.16, function()
			part:Destroy()
		end)
	else
		part:Destroy()
	end
	if collector == player.UserId then
		playSound("coin")
	end
end

---------------------------------------------------------------------
-- Efectos que manda el servidor
---------------------------------------------------------------------
local FX: { [string]: (...any) -> () } = {}

-- Estela: una parte con Trail (dos puntos) que deja una cola al moverse
local function addTrail(part: BasePart, color: Color3, width: number, lifetime: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = lifetime
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Parent = part
end

-- Chispas pequeñas al impactar
local function sparks(position: Vector3, color: Color3, count: number, spread: number)
	for _ = 1, count do
		local spark = effectPart(Enum.PartType.Block, Vector3.new(0.25, 0.25, 0.25), CFrame.new(position), color, 0)
		local offset = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0.2, 1), random:NextNumber(-1, 1)) * spread
		fadeOut(spark, 0.25, { CFrame = CFrame.new(position + offset), Size = Vector3.new(0.05, 0.05, 0.05) })
	end
end

local STEEL = Color3.fromRGB(226, 232, 240)
local GOLDEN = Color3.fromRGB(251, 191, 36)

-- Espada: gira alrededor del jugador (o barre por delante) dejando estela
function FX.slash(userId: number, x: number, z: number, angle: number, radius: number, full: boolean, _hit: boolean?, level: number?)
	local evolved = (level or 1) > Config.MAX_ITEM_LEVEL
	local bladeColor = if evolved then GOLDEN else STEEL
	local length = math.max(3, radius * 0.85)
	local blade = effectPart(Enum.PartType.Block, Vector3.new(0.5, 0.18, length), CFrame.new(), bladeColor, 0)
	blade.Material = if evolved then Enum.Material.Neon else Enum.Material.Metal
	blade.Reflectance = 0.2
	local guard = effectPart(Enum.PartType.Block, Vector3.new(1.6, 0.3, 0.3), CFrame.new(), GOLDEN, 0)
	guard.Material = Enum.Material.Metal
	addTrail(blade, if evolved then GOLDEN else Color3.fromRGB(186, 230, 253), 0.4, 0.12)
	local startAngle = angle + (if full then 0 else math.rad(70))
	local sweep = if full then -math.pi * 2 else -math.rad(140)
	local duration = if full then 0.28 else 0.18
	animate(duration, function(a)
		local root = rootOf(userId)
		local center = if root then root.Position - Vector3.new(0, 1.2, 0) else world(x, z, 1.4)
		local yaw = startAngle + sweep * a
		local dir = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		local frame = CFrame.lookAt(center, center + dir)
		blade.CFrame = frame * CFrame.new(0, 0, -(1.6 + length / 2))
		guard.CFrame = frame * CFrame.new(0, 0, -1.4)
		blade.Transparency = math.max(0, a - 0.7) / 0.3
		guard.Transparency = blade.Transparency
	end, function()
		blade:Destroy()
		guard:Destroy()
	end)
end

-- Varita: bola mágica con cola y chispas al dar
function FX.bolt(x1: number, z1: number, x2: number, z2: number, evolved: boolean)
	local from, to = world(x1, z1, 2.5), world(x2, z2, 2)
	local color = if evolved then Color3.fromRGB(244, 114, 182) else Color3.fromRGB(167, 139, 250)
	local ball = effectPart(Enum.PartType.Ball, Vector3.new(1, 1, 1) * (if evolved then 1.6 else 1.1), CFrame.new(from), color, 0)
	addTrail(ball, color, 0.8, 0.18)
	animate(0.15, function(a)
		ball.CFrame = CFrame.new(from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 1.2, 0))
	end, function()
		sparks(to, color, 4, 2.5)
		fadeOut(ball, 0.1, { Size = Vector3.new(2.5, 2.5, 2.5) })
	end)
end

-- Dagas: vuelan girando y dejan una estela fina
function FX.dagger(x: number, z: number, dx: number, dz: number, length: number, level: number?)
	local evolved = (level or 1) > Config.MAX_ITEM_LEVEL
	local direction = Vector3.new(dx, 0, dz)
	local from = world(x, z, 2)
	local to = from + direction * length
	local blade = effectPart(Enum.PartType.Block, Vector3.new(0.2, 0.5, 1.8), CFrame.lookAt(from, to), if evolved then GOLDEN else STEEL, 0)
	blade.Material = Enum.Material.Metal
	local hilt = effectPart(Enum.PartType.Block, Vector3.new(0.3, 0.3, 0.6), CFrame.new(), Color3.fromRGB(185, 28, 28), 0)
	addTrail(blade, Color3.fromRGB(226, 232, 240), 0.25, 0.1)
	animate(0.25, function(a)
		local cf = CFrame.lookAt(from:Lerp(to, a), to + direction) * CFrame.Angles(0, 0, a * 12)
		blade.CFrame = cf
		hilt.CFrame = cf * CFrame.new(0, 0, 1.1)
	end, function()
		blade:Destroy()
		hilt:Destroy()
	end)
end

-- Rayo: zigzag desde el cielo, destello en el suelo y chispas
function FX.lightning(x: number, z: number, aoe: number, level: number?)
	local evolved = (level or 1) > Config.MAX_ITEM_LEVEL
	local color = if evolved then Color3.fromRGB(196, 181, 253) else Color3.fromRGB(186, 230, 253)
	local ground = world(x, z, 0)
	local top = ground + Vector3.new(random:NextNumber(-3, 3), 34, random:NextNumber(-3, 3))
	local prev = top
	for k = 1, 6 do
		local t = k / 6
		local nextPoint = top:Lerp(ground, t) + (if k < 6 then Vector3.new(random:NextNumber(-2.2, 2.2), 0, random:NextNumber(-2.2, 2.2)) else Vector3.new())
		local length = (nextPoint - prev).Magnitude
		local segment = effectPart(Enum.PartType.Block, Vector3.new(0.6, 0.6, length), CFrame.lookAt((prev + nextPoint) / 2, nextPoint), color, 0)
		fadeOut(segment, 0.22, { Size = Vector3.new(0.1, 0.1, length) })
		prev = nextPoint
	end
	fadeOut(disc(ground + Vector3.new(0, 0.3, 0), aoe * 2, Color3.fromRGB(125, 211, 252), 0.35), 0.3)
	fadeOut(effectPart(Enum.PartType.Ball, Vector3.new(2, 2, 2), CFrame.new(ground + Vector3.new(0, 1, 0)), Color3.new(1, 1, 1), 0.2), 0.2, { Size = Vector3.new(1, 1, 1) * aoe * 1.2 })
	sparks(ground + Vector3.new(0, 0.8, 0), color, 5, aoe)
end

-- Hacha: sale girando hacia delante y vuelve al jugador
function FX.axe(userId: number, dx: number, dz: number, length: number, level: number?)
	local evolved = (level or 1) > Config.MAX_ITEM_LEVEL
	local root = rootOf(userId)
	if not root then
		return
	end
	local start = root.Position - Vector3.new(0, 1, 0)
	local direction = Vector3.new(dx, 0, dz)
	local size = if evolved then 1.5 else 1
	local handle = effectPart(Enum.PartType.Block, Vector3.new(0.3, 0.3, 3) * size, CFrame.new(start), Color3.fromRGB(120, 72, 36), 0)
	handle.Material = Enum.Material.Wood
	local head = effectPart(Enum.PartType.Block, Vector3.new(0.25, 1.6, 1.2) * size, CFrame.new(start), if evolved then Color3.fromRGB(239, 68, 68) else STEEL, 0)
	head.Material = Enum.Material.Metal
	addTrail(head, if evolved then Color3.fromRGB(252, 165, 165) else Color3.fromRGB(203, 213, 225), 1.2 * size, 0.15)
	animate(0.9, function(a)
		local r = rootOf(userId)
		local home = if r then r.Position - Vector3.new(0, 1, 0) else start
		local out = math.sin(a * math.pi) * length
		local pos = home + direction * out
		local cf = CFrame.new(pos) * CFrame.Angles(0, a * 26, 0)
		handle.CFrame = cf
		head.CFrame = cf * CFrame.new(0, 0, -1.3 * size)
	end, function()
		handle:Destroy()
		head:Destroy()
	end)
end

-- Bomba: vuela en parábola, mecha encendida y explosión al caer
function FX.bomb(x1: number, z1: number, x2: number, z2: number, aoe: number, level: number?)
	local evolved = (level or 1) > Config.MAX_ITEM_LEVEL
	local from, to = world(x1, z1, 2.5), world(x2, z2, 0.8)
	local bomb = effectPart(Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4) * (if evolved then 1.4 else 1), CFrame.new(from), if evolved then Color3.fromRGB(194, 65, 12) else Color3.fromRGB(38, 38, 48), 0)
	bomb.Material = if evolved then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local fuse = effectPart(Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), CFrame.new(from), Color3.fromRGB(253, 224, 71), 0)
	addTrail(fuse, Color3.fromRGB(251, 146, 60), 0.4, 0.2)
	local warn = disc(to - Vector3.new(0, 0.5, 0), aoe * 2, Color3.fromRGB(249, 115, 22), 0.75)
	animate(Config.BOMB_FLIGHT, function(a)
		local pos = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 9, 0)
		bomb.CFrame = CFrame.new(pos) * CFrame.Angles(a * 6, 0, a * 4)
		fuse.CFrame = bomb.CFrame * CFrame.new(0, 0.8, 0)
	end, function()
		bomb:Destroy()
		fuse:Destroy()
		warn:Destroy()
		local center = to + Vector3.new(0, 0.5, 0)
		fadeOut(effectPart(Enum.PartType.Ball, Vector3.new(2, 2, 2), CFrame.new(center), Color3.fromRGB(253, 186, 116), 0.1), 0.35, { Size = Vector3.new(1, 1, 1) * aoe * 2.2 })
		fadeOut(effectPart(Enum.PartType.Ball, Vector3.new(1, 1, 1), CFrame.new(center), Color3.fromRGB(254, 240, 138), 0), 0.2, { Size = Vector3.new(1, 1, 1) * aoe * 1.2 })
		local scorch = disc(to - Vector3.new(0, 0.6, 0), aoe * 1.8, Color3.fromRGB(30, 20, 15), 0.4)
		scorch.Material = Enum.Material.SmoothPlastic
		fadeOut(scorch, 1.2)
		sparks(center, Color3.fromRGB(251, 146, 60), 6, aoe)
		playSound("hit")
	end)
end

-- Martillo: onda de tierra con rocas que saltan
function FX.quake(x: number, z: number, radius: number, level: number?)
	local evolved = (level or 1) > Config.MAX_ITEM_LEVEL
	local center = world(x, z, 0.3)
	local ring = disc(center, 2, if evolved then Color3.fromRGB(251, 191, 36) else Color3.fromRGB(180, 140, 100), 0.3)
	fadeOut(ring, 0.35, { Size = Vector3.new(0.2, radius * 2, radius * 2) })
	local rocks = if evolved then 12 else 8
	for k = 1, rocks do
		local a = k / rocks * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local d = radius * random:NextNumber(0.55, 0.95)
		local base = center + Vector3.new(math.cos(a) * d, -0.5, math.sin(a) * d)
		local rock = effectPart(Enum.PartType.Block, Vector3.new(1, 1, 1) * random:NextNumber(0.8, 1.6), CFrame.new(base), Color3.fromRGB(120, 100, 80), 0)
		rock.Material = Enum.Material.Slate
		local delay = d / radius * 0.15
		local total = 0.5 + delay
		animate(total, function(t)
			local local_ = math.clamp((t * total - delay) / 0.5, 0, 1)
			rock.CFrame = CFrame.new(base + Vector3.new(0, math.sin(local_ * math.pi) * 2.2, 0)) * CFrame.Angles(local_ * 3, local_ * 2, 0)
		end, function()
			rock:Destroy()
		end)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - center).Magnitude < 6 then
		playSound("hit")
	end
end

-- Oleadas: aro dorado al empezar; al acabar suena el botín
function FX.wave(_wave: number, _total: number)
	if not runState then
		return
	end
	for _, mate in runState.team do
		local root = rootOf(mate.userId)
		if root then
			fadeOut(disc(root.Position - Vector3.new(0, 2.8, 0), 3, GOLDEN, 0.3), 0.6, { Size = Vector3.new(0.2, 40, 40) })
		end
	end
end

function FX.wavedone(_wave: number)
	playSound("coin")
end

function FX.slamwarn(x: number, z: number, radius: number, warn: number)
	local part = disc(world(x, z, 0.35), radius * 2, Color3.fromRGB(239, 68, 68), 0.55)
	part.Name = "AvisoGolpe"
	table.insert(warnings, part)
	task.delay(warn, function()
		part:Destroy()
	end)
end

function FX.slam(x: number, z: number, radius: number)
	local center = world(x, z, 0.4)
	fadeOut(disc(center, 2, Color3.fromRGB(251, 146, 60), 0.2), 0.4, { Size = Vector3.new(0.2, radius * 2.2, radius * 2.2) })
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and (root.Position - center).Magnitude < radius + 14 then
		task.spawn(function()
			for i = 1, 8 do
				humanoid.CameraOffset = Vector3.new(random:NextNumber(-0.6, 0.6), random:NextNumber(-0.6, 0.6), 0) * (1 - i / 9)
				task.wait(0.03)
			end
			humanoid.CameraOffset = Vector3.new()
		end)
	end
end

function FX.death(x: number, z: number, typeIndex: number)
	deathPuff(x, z, typeIndex)
end

function FX.levelup(x: number, z: number)
	local column = effectPart(Enum.PartType.Cylinder, Vector3.new(14, 5, 5), CFrame.new(world(x, z, 4)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(251, 191, 36), 0.4)
	fadeOut(column, 0.8, { Size = Vector3.new(26, 1, 1) })
end

function FX.revive(x: number, z: number)
	fadeOut(effectPart(Enum.PartType.Ball, Vector3.new(3, 3, 3), CFrame.new(world(x, z, 2)), Color3.fromRGB(244, 114, 182), 0.3), 0.6, { Size = Vector3.new(14, 14, 14) })
end

function FX.evolve(x: number, z: number)
	fadeOut(effectPart(Enum.PartType.Ball, Vector3.new(3, 3, 3), CFrame.new(world(x, z, 2)), Color3.fromRGB(251, 191, 36), 0.2), 0.8, { Size = Vector3.new(20, 20, 20) })
end

function FX.portal(_x: number, _z: number)
	playSound("levelup")
end

---------------------------------------------------------------------
-- Portal de escape (mientras exista en el estado)
---------------------------------------------------------------------
local function updatePortal()
	local portal = runState and runState.portal
	if not portal then
		if portalModel then
			portalModel:Destroy()
			portalModel = nil
		end
		return
	end
	if not portalModel then
		local model = Instance.new("Model")
		model.Name = "PortalEscape"
		local center = world(portal.x, portal.z, 0)
		local ring = effectPart(Enum.PartType.Cylinder, Vector3.new(0.3, Config.PORTAL_RADIUS * 2, Config.PORTAL_RADIUS * 2), CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(56, 189, 248), 0.3)
		ring.Parent = model
		local beam = effectPart(Enum.PartType.Cylinder, Vector3.new(60, 4, 4), CFrame.new(center + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(125, 211, 252), 0.5)
		beam.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(56, 189, 248)
		light.Range = 30
		light.Brightness = 3
		light.Parent = ring
		model.Parent = folder
		portalModel = model
	end
end

---------------------------------------------------------------------
-- Aura y orbes (se dibujan aquí a partir de las armas de cada jugador)
---------------------------------------------------------------------
local function updateWeaponsVisuals(now: number)
	local seen: { [number]: boolean } = {}
	if runState then
		local runTime = runState.time + (now - runStateAt)
		for _, mate in runState.team do
			local root = mate.alive and rootOf(mate.userId)
			if root then
				seen[mate.userId] = true
				local areaMult = if mate.userId == player.UserId then runState.areaMult or 1 else 1
				local base = root.Position - Vector3.new(0, 2.6, 0)
				-- Aura
				local auraLevel = mate.weapons.aura
				local aura = auraParts[mate.userId]
				if auraLevel then
					local st = Config.weaponStats("aura", auraLevel)
					local d = st.radius * areaMult * 2
					if not aura then
						aura = disc(base, d, Color3.fromRGB(253, 224, 71), 0.75)
						local newAura = aura :: BasePart
						newAura.Name = "Aura"
						-- Chispas doradas que suben desde el suelo
						local emitter = Instance.new("ParticleEmitter")
						emitter.EmissionDirection = Enum.NormalId.Right -- el disco está girado: su "derecha" mira arriba
						emitter.Rate = 14
						emitter.Lifetime = NumberRange.new(0.6, 1.1)
						emitter.Speed = NumberRange.new(2, 4)
						emitter.Size = NumberSequence.new(0.35, 0)
						emitter.Color = ColorSequence.new(Color3.fromRGB(254, 240, 138))
						emitter.LightEmission = 1
						emitter.Transparency = NumberSequence.new(0.1, 1)
						emitter.Parent = newAura
						auraParts[mate.userId] = newAura
					end
					local a = aura :: BasePart
					a.Size = Vector3.new(0.2, d, d)
					a.CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
				elseif aura then
					aura:Destroy()
					auraParts[mate.userId] = nil
				end
				-- Orbes
				local orbLevel = mate.weapons.orbes
				local orbs = orbParts[mate.userId] or {}
				orbParts[mate.userId] = orbs
				local count = 0
				if orbLevel then
					local st = Config.weaponStats("orbes", orbLevel)
					count = st.count
					for k = 1, count do
						local orb = orbs[k]
						if not orb then
							orb = effectPart(Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(base), Color3.fromRGB(56, 189, 248), 0)
							local newOrb = orb :: BasePart
							newOrb.Name = "Orbe"
							addTrail(newOrb, Color3.fromRGB(125, 211, 252), 1.2, 0.25)
							orbs[k] = newOrb
						end
						local angle = runTime * st.speed + (k - 1) / count * math.pi * 2
						local r = st.orbit * areaMult
						;(orb :: BasePart).CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * r, -1, math.sin(angle) * r))
					end
				end
				for k = #orbs, count + 1, -1 do
					orbs[k]:Destroy()
					orbs[k] = nil
				end
			end
		end
	end
	for userId, aura in auraParts do
		if not seen[userId] then
			aura:Destroy()
			auraParts[userId] = nil
		end
	end
	for userId, orbs in orbParts do
		if not seen[userId] then
			for _, orb in orbs do
				orb:Destroy()
			end
			orbParts[userId] = nil
		end
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
function SwarmView.init(soundPlayer: (string) -> ())
	playSound = soundPlayer
	folder = Instance.new("Folder")
	folder.Name = "HordaLocal"
	folder.Parent = Workspace
end

local function clearAll()
	for id, view in views do
		release(view)
		views[id] = nil
	end
	for id, part in gems do
		part:Destroy()
		gems[id] = nil
	end
	for _, part in warnings do
		part:Destroy()
	end
	warnings = {}
	for _, anim in anims do
		if anim.done then
			anim.done()
		end
	end
	anims = {}
end

-- Estado de la partida (o nil en el lobby)
function SwarmView.setRun(state: any)
	local wasInRun = runState ~= nil
	runState = state
	runStateAt = os.clock()
	if state then
		origin = state.origin
	elseif wasInRun then
		clearAll()
	end
	updatePortal()
end

-- Llega una foto de la horda del servidor
function SwarmView.onSnapshot(data: buffer, gemAdds: { number }, gemRemoves: { number }, fx: { any })
	if not runState then
		return
	end
	local now = os.clock()
	snapshotInterval = math.clamp(now - snapshotAt, 0.05, 0.3)
	snapshotAt = now
	flashesThisSnapshot = 0
	spawnPuffsThisSnapshot = 0
	local count = buffer.readu16(data, 0)
	local seen: { [number]: boolean } = {}
	local offset = 2
	local scaleHp = nil
	for _ = 1, count do
		local id = buffer.readu16(data, offset)
		local typeIndex = buffer.readu8(data, offset + 2)
		local hp = buffer.readu8(data, offset + 3)
		local flags = buffer.readu8(data, offset + 4)
		local x = buffer.readi16(data, offset + 5) / 4
		local z = buffer.readi16(data, offset + 7) / 4
		offset += 9
		seen[id] = true
		local view = views[id]
		local elite = bit32.band(flags, 1) ~= 0
		local boss = bit32.band(flags, 2) ~= 0
		if view and view.typeIndex ~= typeIndex then
			release(view)
			view = nil
		end
		if not view then
			local newView = acquire(typeIndex, elite, boss)
			newView.id = id
			newView.prevX, newView.prevZ, newView.x, newView.z = x, z, x, z
			newView.hp = hp
			newView.bornAt = now
			views[id] = newView
			spawnPuff(x, z)
		else
			local v = view :: View
			v.prevX, v.prevZ = v.x, v.z
			v.x, v.z = x, z
			if hp < v.hp then
				-- Número de daño aproximado (vida máxima estimada en el cliente)
				if not scaleHp then
					scaleHp = {}
				end
				local def = Config.EnemyList[typeIndex]
				local key = typeIndex * 2 + (if elite then 1 else 0)
				local maxHp = (scaleHp :: any)[key]
				if not maxHp then
					maxHp = Config.enemyStats(def, runState.mapIndex, math.max(1, runState.wave or 1), #runState.team, elite, runState.difficulty).hp
					;(scaleHp :: any)[key] = maxHp
				end
				flash(v, now)
				local amount = (v.hp - hp) / 255 * maxHp
				if amount >= 1 then
					floatingText(world(x, z, v.height + 0.5), Config.formatNumber(amount), Color3.fromRGB(255, 255, 255), 18, 0.6)
				end
			end
			v.hp = hp
		end
		local current = views[id]
		if current.bar then
			current.bar.Size = UDim2.fromScale(hp / 255, 1)
		end
	end
	for id, view in views do
		if not seen[id] then
			release(view)
			views[id] = nil
		end
	end
	for i = 1, #gemAdds, 4 do
		addGem(gemAdds[i], gemAdds[i + 1], gemAdds[i + 2] / 4, gemAdds[i + 3] / 4)
	end
	for i = 1, #gemRemoves, 2 do
		removeGem(gemRemoves[i], gemRemoves[i + 1])
	end
	for _, entry in fx do
		local handler = FX[entry[1]]
		if handler then
			handler(table.unpack(entry, 2))
		end
	end
end

-- Cada fotograma: mover la horda (interpolando) y los efectos continuos
function SwarmView.update(dt: number)
	deathPuffsThisFrame = 0
	local now = os.clock()
	if not runState then
		return
	end
	-- Animaciones de efectos
	if #anims > 0 then
		local keep = {}
		for _, anim in anims do
			local a = (now - anim.startAt) / anim.duration
			anim.step(math.min(1, a))
			if a >= 1 then
				if anim.done then
					anim.done()
				end
			else
				table.insert(keep, anim)
			end
		end
		anims = keep
	end
	local alpha = math.clamp((now - snapshotAt) / snapshotInterval, 0, 1)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, view in views do
		local x = view.prevX + (view.x - view.prevX) * alpha
		local z = view.prevZ + (view.z - view.prevZ) * alpha
		local dx, dz = view.x - view.prevX, view.z - view.prevZ
		if dx * dx + dz * dz > 0.0004 then
			local target = math.atan2(-dx, -dz)
			local diff = (target - view.yaw + math.pi) % (math.pi * 2) - math.pi
			view.yaw += diff * math.min(1, dt * 10)
		end
		view.phase += dt
		local model = Config.Enemies[Config.EnemyList[view.typeIndex]].model
		local bob = if model == "flyer" then math.sin(view.phase * 3) * 0.5 elseif model == "slime" then math.abs(math.sin(view.phase * 6)) * 0.6 else 0
		-- Al aparecer salen del suelo
		local rise = math.clamp((now - view.bornAt) / 0.35, 0, 1)
		local sink = (1 - rise) * view.height
		local rootCFrame = CFrame.new(origin + Vector3.new(x, ENEMY_HEIGHT_OFFSET + bob - sink, z)) * CFrame.Angles(0, view.yaw, 0)
		for i, part in view.parts do
			table.insert(parts, part)
			table.insert(cframes, rootCFrame * view.offsets[i])
		end
		table.insert(parts, view.shadow)
		table.insert(cframes, CFrame.new(origin + Vector3.new(x, 0.06, z)) * CFrame.Angles(0, 0, math.rad(90)))
		if view.flashUntil > 0 and now >= view.flashUntil then
			view.flashUntil = 0
			unflash(view)
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- Cristales girando
	for _, gem in gems do
		gem.CFrame = gem.CFrame * CFrame.Angles(0, dt * 2, 0)
	end
	updateWeaponsVisuals(now)
end

-- Para las pruebas automáticas
function SwarmView.debugCounts(): (number, number)
	local enemies, gemCount = 0, 0
	for _ in views do
		enemies += 1
	end
	for _ in gems do
		gemCount += 1
	end
	return enemies, gemCount
end

return SwarmView
