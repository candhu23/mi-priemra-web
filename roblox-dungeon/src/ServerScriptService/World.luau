--[[
	World (ModuleScript en ServerScriptService)

	Construye el mundo de Dungeon Ascend:
	  · la Ciudad (inicio): plaza, zona de aparición, portales a las zonas,
	    forja, tienda y panel de clasificación
	  · las zonas de combate (Bosque, Cueva, Castillo), cada una con su
	    decoración, puntos de aparición de enemigos, arena del jefe y
	    portal de vuelta
	Devuelve dónde aparece cada enemigo para que CombatService los cree.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

local World = {}

World.ZONE_SPACING = 1000 -- las zonas están lejos de la ciudad (en -Z)
World.ZONE_WIDTH = 240
World.ZONE_LENGTH = 320

export type SpawnPoint = { enemy: string, position: Vector3 }
export type ZoneInfo = {
	id: string,
	index: number,
	origin: Vector3,
	entry: CFrame,
	spawns: { SpawnPoint },
	boss: SpawnPoint,
}

local random = Random.new(1234)
local zonesInfo: { [string]: ZoneInfo } = {}
local leaderboardRows: { TextLabel } = {}
local leaderboardStatus: TextLabel? = nil
local callbacks: any = nil

---------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------
local function newPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Los cilindros de Roblox van a lo largo del eje X: se giran para ponerlos de pie
local function verticalCylinder(parent: Instance, height: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = newPart(parent, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function ball(parent: Instance, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = newPart(parent, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function billboard(parent: Instance, size: UDim2, offset: Vector3, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

local function textLabel(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

local function prompt(parent: Instance, action: string, object: string, onTriggered: (Player) -> ())
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.KeyboardKeyCode = Enum.KeyCode.F -- la E es la Embestida
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	p.Triggered:Connect(onTriggered)
	return p
end

local function pointLight(parent: Instance, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
end

-- Paredes invisibles alrededor de un rectángulo
local function boundary(parent: Instance, center: Vector3, width: number, length: number)
	local height = 60
	for _, side in { { width + 8, 4, 0, length / 2 + 2 }, { width + 8, 4, 0, -length / 2 - 2 }, { 4, length + 8, width / 2 + 2, 0 }, { 4, length + 8, -width / 2 - 2, 0 } } do
		local wall = newPart(parent, Vector3.new(side[1], height, side[2]), CFrame.new(center + Vector3.new(side[3], height / 2, side[4])), Color3.new(1, 1, 1))
		wall.Transparency = 1
		wall.Name = "Limite"
	end
end

---------------------------------------------------------------------
-- Iluminación
---------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 70, 85)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 135)
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(199, 210, 254)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.06
	color.Parent = Lighting
end

---------------------------------------------------------------------
-- Decoración reutilizable
---------------------------------------------------------------------
local function tree(parent: Instance, position: Vector3, scale: number, leafColor: Color3)
	local model = Instance.new("Model")
	model.Name = "Arbol"
	verticalCylinder(model, 10 * scale, 2.2 * scale, position + Vector3.new(0, 5 * scale, 0), Color3.fromRGB(110, 72, 44), Enum.Material.Wood)
	ball(model, 11 * scale, position + Vector3.new(0, 12 * scale, 0), leafColor, Enum.Material.Grass)
	ball(model, 8 * scale, position + Vector3.new(2.5 * scale, 15 * scale, 1 * scale), leafColor:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Grass)
	model.Parent = parent
end

local function rock(parent: Instance, position: Vector3, size: number, color: Color3)
	local part = newPart(parent, Vector3.new(size, size * 0.7, size * 0.9), CFrame.new(position + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6.28), random:NextNumber(-0.3, 0.3)), color, Enum.Material.Slate)
	part.Name = "Roca"
end

local function crystal(parent: Instance, position: Vector3, height: number, color: Color3)
	local part = newPart(parent, Vector3.new(height * 0.35, height, height * 0.35), CFrame.new(position + Vector3.new(0, height * 0.4, 0)) * CFrame.Angles(random:NextNumber(-0.35, 0.35), random:NextNumber(0, 6.28), random:NextNumber(-0.35, 0.35)), color, Enum.Material.Neon)
	part.Name = "Cristal"
	part.Transparency = 0.15
	pointLight(part, color, 22, 1.6)
end

local function torch(parent: Instance, position: Vector3)
	verticalCylinder(parent, 6, 0.8, position + Vector3.new(0, 3, 0), Color3.fromRGB(68, 50, 36), Enum.Material.Wood)
	local flame = ball(parent, 1.4, position + Vector3.new(0, 6.6, 0), Color3.fromRGB(251, 146, 60), Enum.Material.Neon)
	flame.Name = "Antorcha"
	pointLight(flame, Color3.fromRGB(253, 186, 116), 24, 2)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Parent = flame
end

local function lamp(parent: Instance, position: Vector3)
	verticalCylinder(parent, 12, 0.8, position + Vector3.new(0, 6, 0), Color3.fromRGB(51, 65, 85), Enum.Material.Metal)
	local bulb = ball(parent, 2, position + Vector3.new(0, 12.6, 0), Color3.fromRGB(254, 240, 138), Enum.Material.Neon)
	bulb.Name = "Farola"
	pointLight(bulb, Color3.fromRGB(254, 240, 138), 26, 1.4)
end

-- Portal de piedra con un disco brillante y un cartel encima
local function portal(parent: Instance, cframe: CFrame, color: Color3, title: string, subtitle: string): Part
	local model = Instance.new("Model")
	model.Name = "Portal"
	local stone = Color3.fromRGB(87, 83, 78)
	newPart(model, Vector3.new(3, 16, 3), cframe * CFrame.new(-7, 8, 0), stone, Enum.Material.Cobblestone)
	newPart(model, Vector3.new(3, 16, 3), cframe * CFrame.new(7, 8, 0), stone, Enum.Material.Cobblestone)
	newPart(model, Vector3.new(18, 3, 3.4), cframe * CFrame.new(0, 17, 0), stone, Enum.Material.Cobblestone)
	local gem = newPart(model, Vector3.new(2.4, 2.4, 2.4), cframe * CFrame.new(0, 17, -1.9) * CFrame.Angles(0, 0, math.rad(45)), color, Enum.Material.Neon)
	gem.Name = "Gema"
	local disc = newPart(model, Vector3.new(11, 14, 0.6), cframe * CFrame.new(0, 8, 0), color, Enum.Material.Neon)
	disc.Name = "Disco"
	disc.Transparency = 0.35
	disc.CanCollide = false
	pointLight(disc, color, 20, 2.5)
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.6, 0)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 18
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = disc
	local gui = billboard(disc, UDim2.fromOffset(260, 80), Vector3.new(0, 12, 0), 140)
	textLabel(gui, title, UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0), Color3.new(1, 1, 1))
	textLabel(gui, subtitle, UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.6), color:Lerp(Color3.new(1, 1, 1), 0.4))
	model.Parent = parent
	return disc
end

---------------------------------------------------------------------
-- Ciudad (inicio)
---------------------------------------------------------------------
local function buildLobby(root: Instance)
	local lobby = folder("Ciudad", root)
	local grass = Color3.fromRGB(86, 160, 72)
	local ground = newPart(lobby, Vector3.new(220, 2, 220), CFrame.new(0, -1, 0), grass, Enum.Material.Grass)
	ground.Name = "Suelo"
	local plaza = verticalCylinder(lobby, 0.4, 96, Vector3.new(0, 0.2, 0), Color3.fromRGB(168, 162, 158), Enum.Material.Cobblestone)
	plaza.Name = "Plaza"
	-- Camino hacia los portales
	newPart(lobby, Vector3.new(20, 0.4, 40), CFrame.new(0, 0.2, -58), Color3.fromRGB(168, 162, 158), Enum.Material.Cobblestone)
	newPart(lobby, Vector3.new(120, 0.4, 16), CFrame.new(0, 0.21, -72), Color3.fromRGB(168, 162, 158), Enum.Material.Cobblestone)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Aparicion"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 18)
	spawn.Color = Color3.fromRGB(56, 189, 248)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Parent = lobby

	-- Estatua central con el nombre del juego
	local base = newPart(lobby, Vector3.new(12, 3, 12), CFrame.new(0, 1.5, -12), Color3.fromRGB(120, 113, 108), Enum.Material.Marble)
	base.Name = "Pedestal"
	local sword = newPart(lobby, Vector3.new(1.4, 16, 0.5), CFrame.new(0, 11, -12) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(203, 213, 225), Enum.Material.Metal)
	sword.Name = "EspadaGigante"
	newPart(lobby, Vector3.new(6, 1, 1.2), CFrame.new(0.6, 4.6, -12) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(202, 138, 4), Enum.Material.Metal)
	local title = billboard(base, UDim2.fromOffset(420, 110), Vector3.new(0, 22, 0), 200)
	textLabel(title, "⚔️ DUNGEON ASCEND", UDim2.fromScale(1, 0.65), UDim2.fromScale(0, 0), Color3.fromRGB(251, 191, 36))
	textLabel(title, "Sube de nivel · consigue botín · vence a los jefes", UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), Color3.new(1, 1, 1))

	-- Portales a las zonas
	for i, zone in Config.Zones do
		local x = (i - (#Config.Zones + 1) / 2) * 34
		local disc = portal(lobby, CFrame.new(x, 0.4, -80), zone.color, zone.emoji .. " " .. zone.name, "Nivel recomendado " .. zone.level)
		prompt(disc, "Entrar", zone.name, function(player)
			callbacks.onPortal(player, zone.id)
		end)
	end

	-- Forja (oeste)
	local forge = Instance.new("Model")
	forge.Name = "Forja"
	local fx = Vector3.new(-62, 0, 6)
	newPart(forge, Vector3.new(22, 0.6, 18), CFrame.new(fx + Vector3.new(0, 0.3, 0)), Color3.fromRGB(87, 83, 78), Enum.Material.Slate)
	local furnace = newPart(forge, Vector3.new(8, 9, 7), CFrame.new(fx + Vector3.new(-5, 4.5, -4)), Color3.fromRGB(120, 53, 15), Enum.Material.Brick)
	furnace.Name = "Horno"
	local embers = newPart(forge, Vector3.new(5, 3, 0.4), CFrame.new(fx + Vector3.new(-5, 3, -0.4)), Color3.fromRGB(249, 115, 22), Enum.Material.Neon)
	pointLight(embers, Color3.fromRGB(251, 146, 60), 24, 3)
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Parent = embers
	newPart(forge, Vector3.new(3, 3, 2), CFrame.new(fx + Vector3.new(4, 1.5, 0)), Color3.fromRGB(41, 37, 36), Enum.Material.Metal)
	local anvil = newPart(forge, Vector3.new(6, 1.6, 2.6), CFrame.new(fx + Vector3.new(4, 3.8, 0)), Color3.fromRGB(63, 63, 70), Enum.Material.Metal)
	anvil.Name = "Yunque"
	local sign = billboard(anvil, UDim2.fromOffset(220, 60), Vector3.new(0, 7, 0), 90)
	textLabel(sign, "🔨 Forja", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(251, 146, 60))
	prompt(anvil, "Mejorar equipo", "Forja", function(player)
		callbacks.onOpen(player, "forja")
	end)
	forge.Parent = lobby

	-- Tienda (este)
	local shop = Instance.new("Model")
	shop.Name = "Tienda"
	local sx = Vector3.new(62, 0, 6)
	newPart(shop, Vector3.new(16, 4, 6), CFrame.new(sx + Vector3.new(0, 2, 0)), Color3.fromRGB(146, 64, 14), Enum.Material.Wood)
	for _, dx in { -7, 7 } do
		newPart(shop, Vector3.new(1, 12, 1), CFrame.new(sx + Vector3.new(dx, 6, -2.5)), Color3.fromRGB(120, 53, 15), Enum.Material.Wood)
		newPart(shop, Vector3.new(1, 12, 1), CFrame.new(sx + Vector3.new(dx, 6, 2.5)), Color3.fromRGB(120, 53, 15), Enum.Material.Wood)
	end
	for k = 0, 3 do
		newPart(shop, Vector3.new(18, 0.6, 2), CFrame.new(sx + Vector3.new(0, 12.4, -3 + k * 2)), if k % 2 == 0 then Color3.fromRGB(220, 38, 38) else Color3.fromRGB(248, 250, 252), Enum.Material.Fabric)
	end
	local chest = newPart(shop, Vector3.new(3, 2, 2), CFrame.new(sx + Vector3.new(-3, 5, 0)), Color3.fromRGB(202, 138, 4), Enum.Material.Wood)
	chest.Name = "Cofre"
	local counter = newPart(shop, Vector3.new(2, 2, 2), CFrame.new(sx + Vector3.new(3, 5, 0)), Color3.fromRGB(251, 191, 36), Enum.Material.Neon)
	counter.Name = "Moneda"
	local shopSign = billboard(counter, UDim2.fromOffset(220, 60), Vector3.new(0, 10, 0), 90)
	textLabel(shopSign, "🛒 Tienda", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(251, 191, 36))
	prompt(counter, "Ver tienda", "Tienda", function(player)
		callbacks.onOpen(player, "tienda")
	end)
	shop.Parent = lobby

	-- Panel de clasificación (sur)
	-- La cara delantera (Front = -Z) mira hacia la plaza
	local board = newPart(lobby, Vector3.new(22, 16, 1), CFrame.new(0, 10, 62), Color3.fromRGB(30, 41, 59), Enum.Material.SmoothPlastic)
	board.Name = "Clasificacion"
	newPart(lobby, Vector3.new(1.4, 18, 1.4), CFrame.new(-11.5, 9, 62), Color3.fromRGB(63, 63, 70), Enum.Material.Metal)
	newPart(lobby, Vector3.new(1.4, 18, 1.4), CFrame.new(11.5, 9, 62), Color3.fromRGB(63, 63, 70), Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = board
	textLabel(gui, "🏆 MEJORES AVENTUREROS", UDim2.fromScale(1, 0.13), UDim2.fromScale(0, 0.02), Color3.fromRGB(251, 191, 36))
	for i = 1, 10 do
		local row = textLabel(gui, "", UDim2.fromScale(0.9, 0.075), UDim2.fromScale(0.05, 0.15 + (i - 1) * 0.08), Color3.new(1, 1, 1))
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.GothamBold
		leaderboardRows[i] = row
	end
	leaderboardStatus = textLabel(gui, "Cargando…", UDim2.fromScale(0.9, 0.08), UDim2.fromScale(0.05, 0.5), Color3.fromRGB(148, 163, 184))

	-- Árboles y farolas alrededor
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local radius = 96 + random:NextNumber(-4, 4)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if math.abs(pos.X) > 70 or pos.Z > -60 then
			tree(lobby, pos, random:NextNumber(0.9, 1.3), Color3.fromRGB(34, 120, 50))
		end
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + 0.39
		lamp(lobby, Vector3.new(math.cos(angle) * 50, 0, math.sin(angle) * 50))
	end
	boundary(lobby, Vector3.new(0, 0, 0), 216, 216)
end

---------------------------------------------------------------------
-- Zonas de combate
---------------------------------------------------------------------
type Theme = { floor: Color3, floorMaterial: Enum.Material, wall: Color3, wallMaterial: Enum.Material, accent: Color3 }
local THEMES: { [string]: Theme } = {
	bosque = { floor = Color3.fromRGB(74, 140, 60), floorMaterial = Enum.Material.Grass, wall = Color3.fromRGB(64, 92, 52), wallMaterial = Enum.Material.Rock, accent = Color3.fromRGB(34, 197, 94) },
	cueva = { floor = Color3.fromRGB(51, 65, 85), floorMaterial = Enum.Material.Slate, wall = Color3.fromRGB(30, 41, 59), wallMaterial = Enum.Material.Rock, accent = Color3.fromRGB(56, 189, 248) },
	castillo = { floor = Color3.fromRGB(68, 64, 60), floorMaterial = Enum.Material.Cobblestone, wall = Color3.fromRGB(41, 37, 36), wallMaterial = Enum.Material.Brick, accent = Color3.fromRGB(168, 85, 247) },
}

local function decorateZone(zoneFolder: Instance, zone: any, origin: Vector3, theme: Theme)
	local halfW, halfL = World.ZONE_WIDTH / 2, World.ZONE_LENGTH / 2
	local deco = folder("Decoracion", zoneFolder)
	-- Muros del borde
	for _, side in { -1, 1 } do
		newPart(deco, Vector3.new(6, 24, World.ZONE_LENGTH + 12), CFrame.new(origin + Vector3.new(side * (halfW + 3), 12, 0)), theme.wall, theme.wallMaterial)
		newPart(deco, Vector3.new(World.ZONE_WIDTH + 12, 24, 6), CFrame.new(origin + Vector3.new(0, 12, side * (halfL + 3))), theme.wall, theme.wallMaterial)
	end
	-- Objetos repartidos (evitando el camino central y la arena del jefe)
	local function randomSpot(): Vector3
		for _ = 1, 20 do
			local x = random:NextNumber(-halfW + 8, halfW - 8)
			local z = random:NextNumber(-halfL + 8, halfL - 8)
			local nearBoss = (Vector3.new(x, 0, z) - Vector3.new(0, 0, -halfL + 50)).Magnitude < 44
			if math.abs(x) > 14 and not nearBoss then
				return origin + Vector3.new(x, 0, z)
			end
		end
		return origin + Vector3.new(halfW - 10, 0, 0)
	end
	if zone.id == "bosque" then
		for _ = 1, 26 do
			tree(deco, randomSpot(), random:NextNumber(0.9, 1.6), Color3.fromRGB(22, 101, 52):Lerp(Color3.fromRGB(77, 124, 15), random:NextNumber()))
		end
		for _ = 1, 14 do
			rock(deco, randomSpot(), random:NextNumber(2, 5), Color3.fromRGB(120, 113, 108))
		end
		for _ = 1, 12 do
			local pos = randomSpot()
			verticalCylinder(deco, 1.6, 0.6, pos + Vector3.new(0, 0.8, 0), Color3.fromRGB(245, 245, 244), Enum.Material.SmoothPlastic)
			ball(deco, 2.2, pos + Vector3.new(0, 1.8, 0), Color3.fromRGB(220, 38, 38), Enum.Material.SmoothPlastic).Name = "Seta"
		end
	elseif zone.id == "cueva" then
		local ceiling = newPart(deco, Vector3.new(World.ZONE_WIDTH + 12, 4, World.ZONE_LENGTH + 12), CFrame.new(origin + Vector3.new(0, 26, 0)), theme.wall, theme.wallMaterial)
		ceiling.Name = "Techo"
		for _ = 1, 30 do
			crystal(deco, randomSpot(), random:NextNumber(4, 11), if random:NextNumber() < 0.6 then Color3.fromRGB(56, 189, 248) else Color3.fromRGB(167, 139, 250))
		end
		for _ = 1, 18 do
			rock(deco, randomSpot(), random:NextNumber(3, 8), Color3.fromRGB(71, 85, 105))
		end
		-- Luz suave en el camino
		for z = -halfL + 20, halfL - 20, 40 do
			crystal(deco, origin + Vector3.new(-9, 0, z), 4, Color3.fromRGB(125, 211, 252))
			crystal(deco, origin + Vector3.new(9, 0, z + 20), 4, Color3.fromRGB(125, 211, 252))
		end
	else
		-- Torres en las esquinas y antorchas a lo largo del camino
		for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			local pos = origin + Vector3.new(corner.X * (halfW - 4), 0, corner.Z * (halfL - 4))
			verticalCylinder(deco, 40, 16, pos + Vector3.new(0, 20, 0), theme.wall, Enum.Material.Brick)
			newPart(deco, Vector3.new(18, 2, 18), CFrame.new(pos + Vector3.new(0, 41, 0)), Color3.fromRGB(28, 25, 23), Enum.Material.Slate)
		end
		for z = -halfL + 20, halfL - 20, 30 do
			torch(deco, origin + Vector3.new(-12, 0, z))
			torch(deco, origin + Vector3.new(12, 0, z))
		end
		for _ = 1, 14 do
			local pos = randomSpot()
			newPart(deco, Vector3.new(4, random:NextNumber(4, 10), 4), CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), random:NextNumber(-0.2, 0.2)), Color3.fromRGB(87, 83, 78), Enum.Material.Cobblestone).Name = "Ruina"
		end
		for _ = 1, 8 do
			local pos = randomSpot()
			newPart(deco, Vector3.new(3, 4, 1), CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0), Color3.fromRGB(120, 113, 108), Enum.Material.Slate).Name = "Lapida"
		end
		-- Muros derruidos con almenas y estandartes morados
		for _ = 1, 10 do
			local pos = randomSpot()
			local length = random:NextNumber(14, 26)
			local wall = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0)
			newPart(deco, Vector3.new(length, 8, 2.5), wall, theme.wall, Enum.Material.Brick).Name = "Muro"
			for k = -1, 1, 2 do
				newPart(deco, Vector3.new(2.5, 2, 2.5), wall * CFrame.new(k * (length / 2 - 1.5), 5, 0), theme.wall, Enum.Material.Brick)
			end
			local banner = newPart(deco, Vector3.new(3, 5, 0.2), wall * CFrame.new(0, 0.5, -1.4), theme.accent, Enum.Material.Fabric)
			banner.Name = "Estandarte"
		end
		for _ = 1, 6 do
			local pos = randomSpot()
			newPart(deco, Vector3.new(3, 9, 3), CFrame.new(pos + Vector3.new(0, 4.5, 0)), Color3.fromRGB(87, 83, 78), Enum.Material.Cobblestone).Name = "Pilar"
			local gem = newPart(deco, Vector3.new(1.6, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0.7, 0.7), theme.accent, Enum.Material.Neon)
			pointLight(gem, theme.accent, 16, 1.5)
		end
	end
end

local function buildZone(root: Instance, zone: any): ZoneInfo
	local origin = Vector3.new(0, 0, -World.ZONE_SPACING * zone.index)
	local theme = THEMES[zone.id]
	local zoneFolder = folder("Zona_" .. zone.id, root)
	local halfL = World.ZONE_LENGTH / 2

	local floor = newPart(zoneFolder, Vector3.new(World.ZONE_WIDTH, 2, World.ZONE_LENGTH), CFrame.new(origin + Vector3.new(0, -1, 0)), theme.floor, theme.floorMaterial)
	floor.Name = "Suelo"
	-- Camino central
	newPart(zoneFolder, Vector3.new(16, 0.3, World.ZONE_LENGTH - 20), CFrame.new(origin + Vector3.new(0, 0.15, 0)), theme.floor:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Cobblestone).Name = "Camino"
	decorateZone(zoneFolder, zone, origin, theme)
	boundary(zoneFolder, origin, World.ZONE_WIDTH, World.ZONE_LENGTH)

	-- Entrada con portal de vuelta
	local entryPos = origin + Vector3.new(0, 0, halfL - 22)
	local back = portal(zoneFolder, CFrame.new(origin + Vector3.new(0, 0.3, halfL - 8)), Color3.fromRGB(56, 189, 248), "🏙️ Volver a la Ciudad", zone.emoji .. " " .. zone.name)
	prompt(back, "Volver", "Ciudad", function(player)
		callbacks.onReturn(player)
	end)
	local entry = CFrame.lookAt(entryPos + Vector3.new(0, 3, 0), entryPos + Vector3.new(0, 3, -10))

	-- Arena del jefe al fondo
	local bossCenter = origin + Vector3.new(0, 0, -halfL + 50)
	local arena = verticalCylinder(zoneFolder, 0.4, 76, bossCenter + Vector3.new(0, 0.2, 0), theme.floor:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Slate)
	arena.Name = "ArenaJefe"
	local ring = verticalCylinder(zoneFolder, 0.3, 80, bossCenter + Vector3.new(0, 0.1, 0), theme.accent, Enum.Material.Neon)
	ring.Name = "AnilloArena"
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local pos = bossCenter + Vector3.new(math.cos(angle) * 42, 0, math.sin(angle) * 42)
		if math.abs(math.cos(angle) * 42) > 8 or math.sin(angle) < 0 then
			newPart(zoneFolder, Vector3.new(4, 16, 4), CFrame.new(pos + Vector3.new(0, 8, 0)), theme.wall, theme.wallMaterial).Name = "Columna"
			local top = newPart(zoneFolder, Vector3.new(2, 2, 2), CFrame.new(pos + Vector3.new(0, 17, 0)), theme.accent, Enum.Material.Neon)
			pointLight(top, theme.accent, 18, 1.5)
		end
	end
	local bossSign = newPart(zoneFolder, Vector3.new(1, 1, 1), CFrame.new(bossCenter + Vector3.new(0, 0, 44)), theme.accent)
	bossSign.Transparency = 1
	bossSign.CanCollide = false
	bossSign.Name = "CartelJefe"
	local bossGui = billboard(bossSign, UDim2.fromOffset(300, 70), Vector3.new(0, 14, 0), 120)
	textLabel(bossGui, "⚠️ Guarida del jefe", UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), Color3.fromRGB(248, 113, 113))
	textLabel(bossGui, Config.Enemies[zone.boss].name, UDim2.fromScale(1, 0.45), UDim2.fromScale(0, 0.55), Color3.new(1, 1, 1))

	-- Puntos de aparición: los enemigos flojos cerca de la entrada, los fuertes al fondo
	local spawns: { SpawnPoint } = {}
	local rows = { halfL - 70, halfL - 135, halfL - 200 }
	for i, enemyId in zone.enemies do
		for k, x in { -72, -28, 28, 72 } do
			local z = rows[i] + (if k % 2 == 0 then 10 else -10)
			table.insert(spawns, { enemy = enemyId, position = origin + Vector3.new(x + random:NextNumber(-6, 6), 0, z) })
		end
	end
	local info: ZoneInfo = {
		id = zone.id,
		index = zone.index,
		origin = origin,
		entry = entry,
		spawns = spawns,
		boss = { enemy = zone.boss, position = bossCenter },
	}
	return info
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
function World.build(handlers: { onPortal: (Player, string) -> (), onReturn: (Player) -> (), onOpen: (Player, string) -> () }): { [string]: ZoneInfo }
	callbacks = handlers
	setupLighting()
	local root = Workspace:FindFirstChild("Mundo") or folder("Mundo", Workspace)
	buildLobby(root)
	for _, zone in Config.Zones do
		zonesInfo[zone.id] = buildZone(root, zone)
	end
	return zonesInfo
end

-- Zona en la que está una posición (nil = la ciudad)
function World.zoneAt(position: Vector3): string?
	for id, info in zonesInfo do
		local rel = position - info.origin
		if math.abs(rel.X) <= World.ZONE_WIDTH / 2 + 10 and math.abs(rel.Z) <= World.ZONE_LENGTH / 2 + 10 then
			return id
		end
	end
	return nil
end

function World.zoneEntry(zoneId: string): CFrame?
	local info = zonesInfo[zoneId]
	return info and info.entry
end

function World.lobbySpawn(): CFrame
	return CFrame.new(0, 4, 18)
end

function World.setLeaderboard(rows: { { name: string, level: number } }?, message: string?)
	for i, label in leaderboardRows do
		local row = rows and rows[i]
		label.Text = if row then string.format("%d. %s — Nivel %d", i, row.name, row.level) else ""
	end
	if leaderboardStatus then
		leaderboardStatus.Text = message or (if rows and #rows == 0 then "¡Sé el primero!" else "")
	end
end

return World
