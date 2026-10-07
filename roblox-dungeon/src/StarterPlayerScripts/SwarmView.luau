--[[
	SwarmView (ModuleScript en StarterPlayerScripts)

	Dibuja la partida en el cliente:
	  · la horda: recibe del servidor posiciones compactas 10 veces por
	    segundo y mueve los modelos suavemente (interpolando) cada fotograma
	  · cristales de XP, corazones y cofres
	  · efectos de las armas (tajos, proyectiles, dagas, rayos), aura y
	    orbes alrededor de cada jugador, avisos del jefe y el portal
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
	}
end

local function release(view: View)
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
	local pos = world(x, z, 1.5)
	for _ = 1, 3 do
		local cube = effectPart(Enum.PartType.Block, Vector3.new(0.7, 0.7, 0.7), CFrame.new(pos), color, 0.1)
		cube.Material = Enum.Material.SmoothPlastic
		local offset = Vector3.new(random:NextNumber(-3, 3), random:NextNumber(1, 3), random:NextNumber(-3, 3))
		fadeOut(cube, 0.45, { CFrame = CFrame.new(pos + offset), Size = Vector3.new(0.2, 0.2, 0.2) })
	end
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

function FX.slash(_userId: number, x: number, z: number, angle: number, radius: number, full: boolean)
	local look = Vector3.new(-math.sin(angle), 0, -math.cos(angle))
	local center = world(x, z, 0.6)
	if full then
		fadeOut(disc(center, radius * 2, Color3.fromRGB(226, 232, 240), 0.55), 0.22)
	else
		fadeOut(disc(center + look * radius * 0.5, radius * 1.2, Color3.fromRGB(226, 232, 240), 0.5), 0.2)
	end
end

function FX.bolt(x1: number, z1: number, x2: number, z2: number, evolved: boolean)
	local from, to = world(x1, z1, 2.5), world(x2, z2, 2)
	local ball = effectPart(Enum.PartType.Ball, Vector3.new(1, 1, 1) * (if evolved then 1.6 else 1), CFrame.new(from), Color3.fromRGB(167, 139, 250), 0)
	TweenService:Create(ball, TweenInfo.new(0.14, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to) }):Play()
	task.delay(0.15, function()
		fadeOut(ball, 0.1, { Size = Vector3.new(2.5, 2.5, 2.5) })
	end)
end

function FX.dagger(x: number, z: number, dx: number, dz: number, length: number)
	local direction = Vector3.new(dx, 0, dz)
	local from = world(x, z, 2)
	local to = from + direction * length
	local blade = effectPart(Enum.PartType.Block, Vector3.new(0.3, 0.3, 2), CFrame.lookAt(from, to), Color3.fromRGB(226, 232, 240), 0)
	TweenService:Create(blade, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + direction) }):Play()
	task.delay(0.26, function()
		blade:Destroy()
	end)
end

function FX.lightning(x: number, z: number, aoe: number)
	local ground = world(x, z, 0)
	local beam = effectPart(Enum.PartType.Block, Vector3.new(0.7, 30, 0.7), CFrame.new(ground + Vector3.new(0, 15, 0)), Color3.fromRGB(186, 230, 253), 0.1)
	fadeOut(beam, 0.25, { Size = Vector3.new(0.1, 30, 0.1) })
	fadeOut(disc(ground + Vector3.new(0, 0.3, 0), aoe * 2, Color3.fromRGB(125, 211, 252), 0.4), 0.3)
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
						aura.Name = "Aura"
						auraParts[mate.userId] = aura
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
							orb.Name = "Orbe"
							orbs[k] = orb
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
			views[id] = newView
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
					maxHp = Config.enemyStats(def, runState.mapIndex, runState.time, #runState.team, elite).hp
					;(scaleHp :: any)[key] = maxHp
				end
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
		local rootCFrame = CFrame.new(origin + Vector3.new(x, ENEMY_HEIGHT_OFFSET + bob, z)) * CFrame.Angles(0, view.yaw, 0)
		for i, part in view.parts do
			table.insert(parts, part)
			table.insert(cframes, rootCFrame * view.offsets[i])
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
