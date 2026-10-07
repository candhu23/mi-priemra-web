--[[
	World (ModuleScript en ServerScriptService)

	Construye el mundo de Dungeon Ascend:
	  · el lobby (la Ciudad): plaza, zona de aparición, portales de partida,
	    forja, tienda y panel de clasificación
	  · las arenas de las partidas: una por partida en marcha, con la
	    decoración de su mapa (Bosque, Cueva, Castillo) y muros alrededor.
	    Se crean al empezar la partida y se borran al terminar.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

local World = {}

World.ARENA_SPACING = 600 -- las arenas están lejos del lobby (en +X)
World.ARENA_START = 2000

local random = Random.new(1234)
local leaderboardRows: { TextLabel } = {}
local leaderboardStatus: TextLabel? = nil
local callbacks: any = nil
local mundo: Folder = nil :: any
local arenas: { [number]: Folder } = {}

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
	textLabel(title, "Sobrevive a la horda · vence al jefe · escapa por el portal", UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), Color3.new(1, 1, 1))

	-- Portales de partida: abren la pestaña Jugar con ese mapa elegido
	for i, map in Config.Maps do
		local x = (i - (#Config.Maps + 1) / 2) * 34
		local disc = portal(lobby, CFrame.new(x, 0.4, -80), map.color, map.emoji .. " " .. map.name, "Partida de " .. math.floor(map.bossAt / 60) .. " min + jefe")
		prompt(disc, "Jugar", map.name, function(player)
			callbacks.onOpen(player, "jugar", map.id)
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
		callbacks.onOpen(player, "forja", nil)
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
		callbacks.onOpen(player, "tienda", nil)
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
	textLabel(gui, "🏆 MÁS ENEMIGOS DERROTADOS", UDim2.fromScale(1, 0.13), UDim2.fromScale(0, 0.02), Color3.fromRGB(251, 191, 36))
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
-- Arenas de partida
---------------------------------------------------------------------
type Theme = { floor: Color3, floorMaterial: Enum.Material, wall: Color3, wallMaterial: Enum.Material, accent: Color3 }
local THEMES: { [string]: Theme } = {
	bosque = { floor = Color3.fromRGB(74, 140, 60), floorMaterial = Enum.Material.Grass, wall = Color3.fromRGB(64, 92, 52), wallMaterial = Enum.Material.Rock, accent = Color3.fromRGB(34, 197, 94) },
	cueva = { floor = Color3.fromRGB(51, 65, 85), floorMaterial = Enum.Material.Slate, wall = Color3.fromRGB(30, 41, 59), wallMaterial = Enum.Material.Rock, accent = Color3.fromRGB(56, 189, 248) },
	castillo = { floor = Color3.fromRGB(68, 64, 60), floorMaterial = Enum.Material.Cobblestone, wall = Color3.fromRGB(41, 37, 36), wallMaterial = Enum.Material.Brick, accent = Color3.fromRGB(168, 85, 247) },
}

-- Detalles que no estorban (no chocan) repartidos por el suelo
local function noCollide(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function decorateArena(arena: Instance, map: any, origin: Vector3, theme: Theme)
	local half = Config.ARENA_HALF
	local deco = folder("Decoracion", arena)
	-- Muros del borde
	for _, side in { -1, 1 } do
		newPart(deco, Vector3.new(6, 18, half * 2 + 12), CFrame.new(origin + Vector3.new(side * (half + 3), 9, 0)), theme.wall, theme.wallMaterial)
		newPart(deco, Vector3.new(half * 2 + 12, 18, 6), CFrame.new(origin + Vector3.new(0, 9, side * (half + 3))), theme.wall, theme.wallMaterial)
	end
	local function edgeSpot(): Vector3
		-- Una franja de 14 studs junto a los muros
		local along = random:NextNumber(-half + 4, half - 4)
		local depth = half - random:NextNumber(3, 14)
		local side = random:NextInteger(1, 4)
		local p = if side == 1 then Vector3.new(along, 0, depth) elseif side == 2 then Vector3.new(along, 0, -depth) elseif side == 3 then Vector3.new(depth, 0, along) else Vector3.new(-depth, 0, along)
		return origin + p
	end
	local function fieldSpot(): Vector3
		return origin + Vector3.new(random:NextNumber(-half + 16, half - 16), 0, random:NextNumber(-half + 16, half - 16))
	end
	if map.id == "bosque" then
		for _ = 1, 40 do
			tree(deco, edgeSpot(), random:NextNumber(1, 1.7), Color3.fromRGB(22, 101, 52):Lerp(Color3.fromRGB(77, 124, 15), random:NextNumber()))
		end
		for _ = 1, 40 do
			local tuft = newPart(deco, Vector3.new(2, 0.3, 2), CFrame.new(fieldSpot() + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0), Color3.fromRGB(101, 163, 13), Enum.Material.Grass)
			tuft.Name = "Hierba"
			noCollide(tuft)
		end
		for _ = 1, 14 do
			local pos = fieldSpot()
			local stem = verticalCylinder(deco, 1.4, 0.5, pos + Vector3.new(0, 0.7, 0), Color3.fromRGB(245, 245, 244), Enum.Material.SmoothPlastic)
			local cap = ball(deco, 1.8, pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(220, 38, 38), Enum.Material.SmoothPlastic)
			cap.Name = "Seta"
			noCollide(stem)
			noCollide(cap)
		end
	elseif map.id == "cueva" then
		for _ = 1, 36 do
			crystal(deco, edgeSpot(), random:NextNumber(5, 13), if random:NextNumber() < 0.6 then Color3.fromRGB(56, 189, 248) else Color3.fromRGB(167, 139, 250))
		end
		for _ = 1, 24 do
			local c = newPart(deco, Vector3.new(0.8, 1.6, 0.8), CFrame.new(fieldSpot() + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0.3, random:NextNumber(0, 6.28), 0.2), Color3.fromRGB(125, 211, 252), Enum.Material.Neon)
			c.Name = "CristalPequeno"
			noCollide(c)
		end
		for _ = 1, 16 do
			rock(deco, edgeSpot(), random:NextNumber(4, 9), Color3.fromRGB(71, 85, 105))
		end
	else
		for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			local pos = origin + Vector3.new(corner.X * (half - 4), 0, corner.Z * (half - 4))
			verticalCylinder(deco, 36, 16, pos + Vector3.new(0, 18, 0), theme.wall, Enum.Material.Brick)
			newPart(deco, Vector3.new(18, 2, 18), CFrame.new(pos + Vector3.new(0, 37, 0)), Color3.fromRGB(28, 25, 23), Enum.Material.Slate)
		end
		for i = 0, 15 do
			local angle = i / 16 * math.pi * 2
			torch(deco, origin + Vector3.new(math.cos(angle) * (half - 8), 0, math.sin(angle) * (half - 8)))
		end
		for _ = 1, 18 do
			local lapida = newPart(deco, Vector3.new(2.4, 3, 0.8), CFrame.new(fieldSpot() + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), random:NextNumber(-0.15, 0.15)), Color3.fromRGB(120, 113, 108), Enum.Material.Slate)
			lapida.Name = "Lapida"
			noCollide(lapida)
		end
		for _ = 1, 10 do
			local banner = newPart(deco, Vector3.new(4, 7, 0.3), CFrame.new(edgeSpot() + Vector3.new(0, 6, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0), theme.accent, Enum.Material.Fabric)
			banner.Name = "Estandarte"
		end
	end
	-- Círculo central donde empieza la partida
	local ring = verticalCylinder(deco, 0.2, 24, origin + Vector3.new(0, 0.1, 0), theme.accent, Enum.Material.Neon)
	ring.Name = "Inicio"
	ring.Transparency = 0.6
	noCollide(ring)
end

-- Centro de la arena de un hueco (1..ARENA_SLOTS)
function World.arenaOrigin(slot: number): Vector3
	return Vector3.new(World.ARENA_START + (slot - 1) * World.ARENA_SPACING, 0, 0)
end

-- Crea la arena de un mapa en un hueco y devuelve su centro
function World.buildArena(slot: number, mapIndex: number): Vector3
	World.destroyArena(slot)
	local map = Config.Maps[mapIndex]
	local theme = THEMES[map.id]
	local origin = World.arenaOrigin(slot)
	local arena = folder("Arena_" .. slot, mundo)
	local size = Config.ARENA_HALF * 2
	local floor = newPart(arena, Vector3.new(size + 12, 2, size + 12), CFrame.new(origin + Vector3.new(0, -1, 0)), theme.floor, theme.floorMaterial)
	floor.Name = "Suelo"
	decorateArena(arena, map, origin, theme)
	boundary(arena, origin, size, size)
	arenas[slot] = arena
	return origin
end

function World.destroyArena(slot: number)
	local arena = arenas[slot]
	if arena then
		arena:Destroy()
		arenas[slot] = nil
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
function World.build(handlers: { onOpen: (Player, string, string?) -> () })
	callbacks = handlers
	setupLighting()
	mundo = Workspace:FindFirstChild("Mundo") or folder("Mundo", Workspace)
	buildLobby(mundo)
end

function World.lobbySpawn(): CFrame
	return CFrame.new(0, 4, 18)
end

function World.setLeaderboard(rows: { { name: string, value: number } }?, message: string?)
	for i, label in leaderboardRows do
		local row = rows and rows[i]
		label.Text = if row then string.format("%d. %s — %s", i, row.name, Config.formatNumber(row.value)) else ""
	end
	if leaderboardStatus then
		leaderboardStatus.Text = message or (if rows and #rows == 0 then "¡Sé el primero!" else "")
	end
end

return World
