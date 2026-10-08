--[[
	World (ModuleScript en ServerScriptService)

	Construye el mundo con TERRENO de Roblox (hierba animada, agua con olas,
	roca, nieve, arena, adoquines…) y piezas para los edificios y detalles:
	  · el lobby: una isla con playa, montañas nevadas alrededor, plaza con
	    fuente y estatua, terraza con los 3 portales en arcos de piedra, forja
	    con tejado y chimenea, mercado con toldos, estanque con muelle,
	    bosquecillos, farolas y el panel de clasificación
	  · las arenas de partida (una por partida en marcha; se crean al empezar
	    y se borran al terminar). El suelo jugable es llano (y = 0) y los
	    bordes son naturales: colinas con árboles (Bosque), acantilados con
	    cristales gigantes (Cueva) o murallas con torres (Castillo)
	La luz de cada lugar está en Ambience.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Ambience = require(ReplicatedStorage:WaitForChild("Ambience"))

local World = {}

World.ARENA_SPACING = 600 -- las arenas están lejos del lobby (en +X)
World.ARENA_START = 2000

local random = Random.new(1234)
local leaderboardRows: { TextLabel } = {}
local leaderboardStatus: TextLabel? = nil
local callbacks: any = nil
local mundo: Folder = nil :: any
local terrain: Terrain = nil :: any
local arenas: { [number]: Folder } = {}
local arenaMap: { [number]: number } = {} -- qué mapa tiene construido cada hueco

local M = Enum.Material
local WOOD = Color3.fromRGB(110, 74, 46)
local DARK_WOOD = Color3.fromRGB(74, 50, 34)
local STONE = Color3.fromRGB(150, 146, 140)
local DARK_STONE = Color3.fromRGB(96, 92, 90)
local WARM_LIGHT = Color3.fromRGB(255, 196, 130)

---------------------------------------------------------------------
-- Ayudas: piezas
---------------------------------------------------------------------
local function newPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or M.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function decor(part: BasePart): BasePart
	-- Detalles que no estorban al andar
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Cilindro de pie (los cilindros de Roblox van a lo largo del eje X)
local function column(parent: Instance, height: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
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

local function pointLight(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
end

local function fire(parent: Instance, size: number, color: Color3?)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.5
	if color then
		f.Color = color
		f.SecondaryColor = color:Lerp(Color3.new(1, 1, 1), 0.4)
	end
	f.Parent = parent
end

local function sparkles(parent: Instance, color: Color3, rate: number, size: number, speed: number)
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.LightInfluence = 0
	particles.Size = NumberSequence.new(size, 0)
	particles.Transparency = NumberSequence.new(0.1, 1)
	particles.Lifetime = NumberRange.new(1.5, 3)
	particles.Rate = rate
	particles.Speed = NumberRange.new(speed * 0.5, speed)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = parent
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
	p.KeyboardKeyCode = Enum.KeyCode.F -- Q y Shift son para esquivar
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Parent = parent
	p.Triggered:Connect(onTriggered)
	return p
end

-- Paredes invisibles alrededor de un rectángulo
local function boundary(parent: Instance, center: Vector3, width: number, length: number)
	local height = 80
	for _, side in { { width + 8, 4, 0, length / 2 + 2 }, { width + 8, 4, 0, -length / 2 - 2 }, { 4, length + 8, width / 2 + 2, 0 }, { 4, length + 8, -width / 2 - 2, 0 } } do
		local wall = newPart(parent, Vector3.new(side[1], height, side[2]), CFrame.new(center + Vector3.new(side[3], height / 2 - 10, side[4])), Color3.new(1, 1, 1))
		wall.Transparency = 1
		wall.Name = "Limite"
	end
end

---------------------------------------------------------------------
-- Ayudas: terreno (la parte de arriba del suelo llano queda en y = 0)
---------------------------------------------------------------------
local function tBlock(cframe: CFrame, size: Vector3, material: Enum.Material)
	terrain:FillBlock(cframe, size, material)
end

local function tBall(position: Vector3, radius: number, material: Enum.Material)
	terrain:FillBall(position, radius, material)
end

local function tCylinder(position: Vector3, height: number, radius: number, material: Enum.Material)
	terrain:FillCylinder(CFrame.new(position), height, radius, material)
end

-- Cambia el material de la capa de arriba (caminos, manchas de barro…)
local function tPatch(position: Vector3, sizeX: number, sizeZ: number, angle: number, material: Enum.Material)
	tBlock(CFrame.new(position.X, -2, position.Z) * CFrame.Angles(0, angle, 0), Vector3.new(sizeX, 4, sizeZ), material)
end

local function tRound(position: Vector3, radius: number, material: Enum.Material)
	tCylinder(Vector3.new(position.X, -2, position.Z), 4, radius, material)
end

-- Mancha de forma natural (varios círculos solapados)
local function tBlob(center: Vector3, size: number, material: Enum.Material)
	tRound(center, size * 0.6, material)
	for _ = 1, 4 do
		local angle = random:NextNumber(0, math.pi * 2)
		local d = random:NextNumber(0.3, 0.75) * size
		tRound(center + Vector3.new(math.cos(angle) * d, 0, math.sin(angle) * d), size * random:NextNumber(0.3, 0.5), material)
	end
end

-- Camino serpenteante de un punto a otro
local function tTrail(from: Vector3, to: Vector3, width: number, material: Enum.Material)
	local steps = math.max(2, math.floor((to - from).Magnitude / (width * 0.6)))
	local side = Vector3.new(-(to - from).Unit.Z, 0, (to - from).Unit.X)
	local phase = random:NextNumber(0, 6.28)
	for i = 0, steps do
		local t = i / steps
		local wave = math.sin(t * math.pi * 3 + phase) * width * 1.4
		tRound(from:Lerp(to, t) + side * wave, width / 2 * random:NextNumber(0.85, 1.15), material)
	end
end

---------------------------------------------------------------------
-- Decoración reutilizable
---------------------------------------------------------------------
local LEAF_GREENS = { Color3.fromRGB(58, 125, 52), Color3.fromRGB(76, 140, 58), Color3.fromRGB(46, 108, 60), Color3.fromRGB(98, 148, 62) }

local function pick(list: { any }): any
	return list[random:NextInteger(1, #list)]
end

-- Roble: tronco, ramas y varias copas redondas
local function oak(parent: Instance, position: Vector3, s: number, leafColor: Color3?)
	local model = Instance.new("Model")
	model.Name = "Roble"
	local green = leafColor or pick(LEAF_GREENS)
	column(model, 10 * s, 2 * s, position + Vector3.new(0, 5 * s, 0), WOOD, M.Wood)
	for _, side in { -1, 1 } do
		decor(newPart(model, Vector3.new(0.9, 4.5, 0.9) * s, CFrame.new(position + Vector3.new(side * 1.4 * s, 8.5 * s, 0)) * CFrame.Angles(0, 0, side * math.rad(-40)), WOOD, M.Wood))
	end
	local crowns = {
		{ Vector3.new(0, 12.5, 0), 9 },
		{ Vector3.new(3.2, 10.8, 1.5), 6.5 },
		{ Vector3.new(-3, 11, -1.4), 6.5 },
		{ Vector3.new(0.8, 10.4, -3.2), 6 },
		{ Vector3.new(-1, 15, 1), 5.5 },
	}
	for i, crown in crowns do
		local tint = green:Lerp(Color3.new(1, 1, 0.6), if i == 5 then 0.12 else random:NextNumber(0, 0.06))
		decor(ball(model, crown[2] * s, position + crown[1] * s, tint, M.LeafyGrass))
	end
	model.Parent = parent
end

-- Pino: tronco y pisos de ramas cada vez más pequeños
local function pine(parent: Instance, position: Vector3, s: number, snow: boolean?)
	local model = Instance.new("Model")
	model.Name = "Pino"
	column(model, 5 * s, 1.5 * s, position + Vector3.new(0, 2.5 * s, 0), DARK_WOOD, M.Wood)
	local green = Color3.fromRGB(38, 92, 58):Lerp(Color3.fromRGB(56, 110, 66), random:NextNumber())
	local tiers = { { 3.5, 10 }, { 6, 8 }, { 8.4, 6 }, { 10.6, 4 }, { 12.5, 2.2 } }
	for i, tier in tiers do
		local part = decor(column(model, 2.4 * s, tier[2] * s, position + Vector3.new(0, tier[1] * s, 0), green:Lerp(Color3.new(0, 0, 0), i * 0.03), M.LeafyGrass))
		part.CFrame = part.CFrame * CFrame.Angles(random:NextNumber(0, 6.28), 0, 0)
		if snow and i <= 4 then
			decor(column(model, 0.5 * s, tier[2] * 0.85 * s, position + Vector3.new(0, (tier[1] + 1.3) * s, 0), Color3.fromRGB(240, 246, 255), M.Snow))
		end
	end
	model.Parent = parent
end

-- Árbol seco (para el Castillo)
local function deadTree(parent: Instance, position: Vector3, s: number)
	local model = Instance.new("Model")
	model.Name = "ArbolSeco"
	local color = Color3.fromRGB(58, 46, 44)
	column(model, 11 * s, 1.6 * s, position + Vector3.new(0, 5.5 * s, 0), color, M.Wood)
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2 + random:NextNumber(-0.4, 0.4)
		local height = random:NextNumber(6, 10.5) * s
		local length = random:NextNumber(3.5, 6) * s
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = position + Vector3.new(0, height, 0)
		local tip = base + dir * length + Vector3.new(0, length * 0.6, 0)
		decor(newPart(model, Vector3.new(0.5 * s, 0.5 * s, (tip - base).Magnitude), CFrame.lookAt((base + tip) / 2, tip), color, M.Wood))
	end
	model.Parent = parent
end

local function bush(parent: Instance, position: Vector3, s: number)
	local green = pick(LEAF_GREENS)
	for k = 1, 3 do
		local offset = Vector3.new(random:NextNumber(-1.2, 1.2), 0.9, random:NextNumber(-1.2, 1.2)) * s
		decor(ball(parent, random:NextNumber(2.4, 3.4) * s, position + offset, green:Lerp(Color3.new(0, 0, 0), k * 0.04), M.LeafyGrass)).Name = "Arbusto"
	end
end

local FLOWER_COLORS = { Color3.fromRGB(244, 114, 182), Color3.fromRGB(250, 204, 21), Color3.fromRGB(255, 255, 255), Color3.fromRGB(167, 139, 250), Color3.fromRGB(248, 113, 113) }

local function flowers(parent: Instance, center: Vector3, radius: number, count: number)
	local color = pick(FLOWER_COLORS)
	for _ = 1, count do
		local angle = random:NextNumber(0, math.pi * 2)
		local r = math.sqrt(random:NextNumber()) * radius
		local pos = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		decor(newPart(parent, Vector3.new(0.15, 0.9, 0.15), CFrame.new(pos + Vector3.new(0, 0.45, 0)), Color3.fromRGB(70, 130, 60), M.Grass))
		decor(ball(parent, 0.55, pos + Vector3.new(0, 1, 0), color, M.SmoothPlastic)).Name = "Flor"
	end
end

local function lamppost(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Farola"
	local iron = Color3.fromRGB(38, 38, 44)
	column(model, 0.8, 2.2, position + Vector3.new(0, 0.4, 0), iron, M.Metal)
	column(model, 10, 0.55, position + Vector3.new(0, 5, 0), iron, M.Metal)
	newPart(model, Vector3.new(2.6, 0.35, 0.35), CFrame.new(position + Vector3.new(0.9, 9.8, 0)), iron, M.Metal)
	local box = newPart(model, Vector3.new(1.4, 1.8, 1.4), CFrame.new(position + Vector3.new(2, 8.8, 0)), Color3.fromRGB(255, 236, 200), M.Glass)
	box.Transparency = 0.35
	local bulb = decor(ball(model, 0.9, position + Vector3.new(2, 8.8, 0), WARM_LIGHT, M.Neon))
	pointLight(bulb, WARM_LIGHT, 20, 1.6)
	newPart(model, Vector3.new(1.7, 0.3, 1.7), CFrame.new(position + Vector3.new(2, 9.8, 0)), iron, M.Metal)
	model.Parent = parent
end

local function brazier(parent: Instance, position: Vector3, color: Color3?)
	local iron = Color3.fromRGB(46, 42, 40)
	for k = 0, 2 do
		local angle = k / 3 * math.pi * 2
		newPart(parent, Vector3.new(0.4, 3.4, 0.4), CFrame.new(position + Vector3.new(math.cos(angle) * 1.1, 1.7, math.sin(angle) * 1.1)) * CFrame.Angles(math.sin(angle) * 0.2, 0, -math.cos(angle) * 0.2), iron, M.Metal)
	end
	column(parent, 0.9, 3.4, position + Vector3.new(0, 3.6, 0), iron, M.Metal)
	local coals = decor(column(parent, 0.3, 2.8, position + Vector3.new(0, 4.1, 0), color or Color3.fromRGB(251, 146, 60), M.Neon))
	coals.Name = "Brasero"
	fire(coals, 4, color)
	pointLight(coals, color or Color3.fromRGB(255, 160, 80), 24, 2.2)
end

local function barrel(parent: Instance, position: Vector3)
	column(parent, 3, 2.4, position + Vector3.new(0, 1.5, 0), Color3.fromRGB(120, 78, 44), M.WoodPlanks).Name = "Barril"
	for _, y in { 0.6, 2.4 } do
		decor(column(parent, 0.25, 2.5, position + Vector3.new(0, y, 0), Color3.fromRGB(60, 60, 64), M.Metal))
	end
end

local function crate(parent: Instance, position: Vector3, size: number)
	newPart(parent, Vector3.new(size, size, size), CFrame.new(position + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, random:NextNumber(-0.3, 0.3), 0), Color3.fromRGB(150, 104, 62), M.WoodPlanks).Name = "Caja"
end

local function banner(parent: Instance, position: Vector3, color: Color3, height: number, facing: number)
	local pole = column(parent, height, 0.45, position + Vector3.new(0, height / 2, 0), DARK_WOOD, M.Wood)
	pole.Name = "Mastil"
	local rot = CFrame.Angles(0, facing, 0)
	decor(newPart(parent, Vector3.new(3, 0.3, 0.3), CFrame.new(position + Vector3.new(0, height - 0.4, 0)) * rot * CFrame.new(1.3, 0, 0), DARK_WOOD, M.Wood))
	local cloth = decor(newPart(parent, Vector3.new(2.6, 5, 0.15), CFrame.new(position + Vector3.new(0, height - 3.2, 0)) * rot * CFrame.new(1.4, 0, 0), color, M.Fabric))
	cloth.Name = "Estandarte"
	decor(newPart(parent, Vector3.new(1, 1, 0.2), cloth.CFrame * CFrame.new(0, 0.6, -0.12) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(250, 204, 21), M.Metal))
end

local function crystal(parent: Instance, position: Vector3, height: number, color: Color3, light: boolean)
	local part = decor(newPart(parent, Vector3.new(height * 0.28, height, height * 0.28), CFrame.new(position + Vector3.new(0, height * 0.35, 0)) * CFrame.Angles(random:NextNumber(-0.45, 0.45), random:NextNumber(0, 6.28), random:NextNumber(-0.45, 0.45)), color, M.Neon))
	part.Name = "Cristal"
	part.Transparency = 0.12
	if light then
		pointLight(part, color, math.min(40, height * 3), 1.8)
	end
	return part
end

local function crystalCluster(parent: Instance, position: Vector3, s: number, color: Color3)
	crystal(parent, position, 9 * s, color, true)
	for k = 1, 4 do
		local angle = k / 4 * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		crystal(parent, position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2.2 * s, random:NextNumber(3, 6) * s, color:Lerp(Color3.new(1, 1, 1), 0.15), false)
	end
end

local function grave(parent: Instance, position: Vector3)
	local rot = CFrame.Angles(0, random:NextNumber(-0.25, 0.25), random:NextNumber(-0.12, 0.12))
	decor(newPart(parent, Vector3.new(2.6, 3.4, 0.7), CFrame.new(position + Vector3.new(0, 1.5, 0)) * rot, Color3.fromRGB(128, 124, 120), M.Slate)).Name = "Lapida"
	decor(newPart(parent, Vector3.new(2.8, 0.3, 4), CFrame.new(position + Vector3.new(0, 0.1, 2.2)), Color3.fromRGB(80, 66, 56), M.Ground))
end

-- Arco de piedra semicircular (en el plano X-Y, mirando a +Z). Devuelve su altura.
local function stoneArch(parent: Instance, base: CFrame, width: number, pillarHeight: number, color: Color3): number
	local radius = width / 2
	for _, side in { -1, 1 } do
		newPart(parent, Vector3.new(3.4, pillarHeight, 3.4), base * CFrame.new(side * radius, pillarHeight / 2, 0), color, M.Cobblestone)
		newPart(parent, Vector3.new(4.4, 1.2, 4.4), base * CFrame.new(side * radius, 0.6, 0), color:Lerp(Color3.new(0, 0, 0), 0.15), M.Slate)
		newPart(parent, Vector3.new(4.2, 1, 4.2), base * CFrame.new(side * radius, pillarHeight + 0.5, 0), color:Lerp(Color3.new(0, 0, 0), 0.15), M.Slate)
	end
	local segments = 11
	for k = 0, segments do
		local theta = k / segments * math.pi
		local offset = Vector3.new(math.cos(theta) * radius, pillarHeight + 1 + math.sin(theta) * radius, 0)
		newPart(parent, Vector3.new(3.2, math.pi * radius / segments * 1.25, 3.4), base * CFrame.new(offset) * CFrame.Angles(0, 0, theta), color, M.Cobblestone)
	end
	return pillarHeight + 1 + radius
end

---------------------------------------------------------------------
-- Construcciones medievales (cabañas, taberna, pozo, castillo)
---------------------------------------------------------------------
local PLASTER = Color3.fromRGB(232, 220, 196)
local THATCH = Color3.fromRGB(196, 156, 84)
local WINDOW_GLOW = Color3.fromRGB(255, 200, 120)

local function wedge(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local part = Instance.new("WedgePart")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or M.SmoothPlastic
	part.Parent = parent
	return part
end

-- Tejado a dos aguas sobre una caja de L (a lo largo de X) × D (Z), con
-- los triángulos de los lados. top = altura donde empieza el tejado.
local function gableRoof(parent: Instance, base: CFrame, length: number, depth: number, top: number, rise: number, roofColor: Color3, roofMaterial: Enum.Material, gableColor: Color3)
	local halfD = depth / 2
	local angle = math.atan2(rise, halfD)
	local slope = math.sqrt(halfD * halfD + rise * rise) + 1.4
	for _, side in { -1, 1 } do
		local cf = base * CFrame.new(0, top + rise / 2 + 0.35, side * halfD / 2) * CFrame.Angles(side * angle, 0, 0)
		local slab = newPart(parent, Vector3.new(length + 2.2, 0.8, slope), cf, roofColor, roofMaterial)
		slab.Name = "Tejado"
		-- Triángulos de los extremos (dos cuñas cada uno)
		for _, endX in { -1, 1 } do
			local w = wedge(parent, Vector3.new(0.6, rise, halfD), base * CFrame.new(endX * (length / 2 - 0.3), top + rise / 2, side * halfD / 2) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0), gableColor, M.WoodPlanks)
			w.Name = "Hastial"
		end
	end
	-- Viga de la cumbrera
	newPart(parent, Vector3.new(length + 2.6, 0.9, 0.9), base * CFrame.new(0, top + rise + 0.5, 0), DARK_WOOD, M.Wood).Name = "Cumbrera"
end

-- Ventana con marco de madera y luz cálida (en la cara +Z de "cf")
local function window(parent: Instance, cf: CFrame, w: number, h: number)
	local glass = decor(newPart(parent, Vector3.new(w, h, 0.3), cf, WINDOW_GLOW, M.Neon))
	glass.Name = "Ventana"
	glass.Transparency = 0.15
	newPart(parent, Vector3.new(w + 0.6, 0.4, 0.5), cf * CFrame.new(0, h / 2 + 0.2, 0), DARK_WOOD, M.Wood)
	newPart(parent, Vector3.new(w + 0.6, 0.4, 0.5), cf * CFrame.new(0, -h / 2 - 0.2, 0), DARK_WOOD, M.Wood)
	newPart(parent, Vector3.new(0.3, h, 0.45), cf, DARK_WOOD, M.Wood)
	newPart(parent, Vector3.new(w, 0.3, 0.45), cf, DARK_WOOD, M.Wood)
end

-- Humo de chimenea
local function smoke(parent: Instance)
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	particles.LightInfluence = 1
	particles.Size = NumberSequence.new(1.2, 4)
	particles.Transparency = NumberSequence.new(0.4, 1)
	particles.Lifetime = NumberRange.new(3, 5)
	particles.Rate = 4
	particles.Speed = NumberRange.new(2, 3.5)
	particles.SpreadAngle = Vector2.new(12, 12)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Parent = parent
end

-- Cabaña de entramado con tejado de paja. base mira hacia +Z (puerta).
local function cottage(parent: Instance, base: CFrame, length: number, depth: number, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local wallH = 9
	-- Zócalo de piedra y paredes encaladas
	newPart(model, Vector3.new(length + 0.6, 1.2, depth + 0.6), base * CFrame.new(0, 0.6, 0), DARK_STONE, M.Cobblestone)
	newPart(model, Vector3.new(length, wallH, depth), base * CFrame.new(0, 1.2 + wallH / 2, 0), PLASTER, M.Plaster).Name = "Pared"
	-- Vigas del entramado (esquinas, horizontal y diagonales)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			newPart(model, Vector3.new(0.9, wallH, 0.9), base * CFrame.new(x * length / 2, 1.2 + wallH / 2, z * depth / 2), DARK_WOOD, M.Wood)
		end
	end
	for _, z in { -1, 1 } do
		newPart(model, Vector3.new(length + 0.4, 0.7, 0.5), base * CFrame.new(0, 1.2 + wallH * 0.55, z * (depth / 2 + 0.1)), DARK_WOOD, M.Wood)
		newPart(model, Vector3.new(length + 0.4, 0.7, 0.5), base * CFrame.new(0, 1.2 + wallH - 0.3, z * (depth / 2 + 0.1)), DARK_WOOD, M.Wood)
		for _, x in { -0.3, 0.3 } do
			local brace = newPart(model, Vector3.new(0.5, wallH * 0.62, 0.45), base * CFrame.new(x * length, 1.2 + wallH * 0.28, z * (depth / 2 + 0.12)) * CFrame.Angles(0, 0, x * 1.6), DARK_WOOD, M.Wood)
			brace.Name = "Viga"
		end
	end
	for _, x in { -1, 1 } do
		newPart(model, Vector3.new(0.5, 0.7, depth + 0.4), base * CFrame.new(x * (length / 2 + 0.1), 1.2 + wallH * 0.55, 0), DARK_WOOD, M.Wood)
	end
	-- Puerta, ventanas y farolillo
	newPart(model, Vector3.new(3.4, 6, 0.4), base * CFrame.new(0, 1.2 + 3, depth / 2 + 0.2), Color3.fromRGB(92, 58, 34), M.WoodPlanks).Name = "Puerta"
	newPart(model, Vector3.new(4.2, 0.6, 0.6), base * CFrame.new(0, 1.2 + 6.2, depth / 2 + 0.3), DARK_WOOD, M.Wood)
	for _, x in { -1, 1 } do
		window(model, base * CFrame.new(x * length * 0.3, 1.2 + wallH * 0.7, depth / 2 + 0.25), 2.4, 2)
		window(model, base * CFrame.new(x * length * 0.3, 1.2 + wallH * 0.7, -depth / 2 - 0.25) * CFrame.Angles(0, math.pi, 0), 2.4, 2)
	end
	local lantern = decor(newPart(model, Vector3.new(0.8, 1.2, 0.8), base * CFrame.new(2.6, 1.2 + 6.4, depth / 2 + 0.8), WINDOW_GLOW, M.Neon))
	pointLight(lantern, WARM_LIGHT, 14, 1)
	-- Tejado de paja y chimenea humeante
	gableRoof(model, base, length, depth, 1.2 + wallH, depth * 0.45, THATCH, M.Grass, Color3.fromRGB(120, 82, 50))
	local chimney = newPart(model, Vector3.new(2.2, 7, 2.2), base * CFrame.new(length * 0.3, 1.2 + wallH + depth * 0.32, -depth * 0.18), STONE, M.Cobblestone)
	chimney.Name = "Chimenea"
	smoke(chimney)
	model.Parent = parent
	return model
end

-- Taberna: planta baja de piedra, piso de entramado que vuela y cartel colgante
local function tavern(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Taberna"
	local length, depth = 22, 14
	newPart(model, Vector3.new(length, 8, depth), base * CFrame.new(0, 4, 0), STONE, M.Cobblestone).Name = "Pared"
	newPart(model, Vector3.new(length + 2, 0.8, depth + 2), base * CFrame.new(0, 8.4, 0), DARK_WOOD, M.WoodPlanks)
	newPart(model, Vector3.new(length + 1.6, 7.5, depth + 1.6), base * CFrame.new(0, 12.55, 0), PLASTER, M.Plaster).Name = "Pared"
	for _, x in { -1, -0.33, 0.33, 1 } do
		for _, z in { -1, 1 } do
			newPart(model, Vector3.new(0.8, 7.5, 0.6), base * CFrame.new(x * (length / 2 + 0.8), 12.55, z * (depth / 2 + 0.85)), DARK_WOOD, M.Wood)
		end
	end
	for k = 1, 3 do
		window(model, base * CFrame.new(-length / 2 + k * length / 4, 12.6, depth / 2 + 1.05), 2.6, 2.4)
	end
	for _, x in { -6, 6 } do
		window(model, base * CFrame.new(x, 4.5, depth / 2 + 0.2), 3, 2.6)
	end
	newPart(model, Vector3.new(4.4, 6.4, 0.5), base * CFrame.new(0, 3.2, depth / 2 + 0.25), Color3.fromRGB(92, 58, 34), M.WoodPlanks).Name = "Puerta"
	gableRoof(model, base, length + 1.6, depth + 1.6, 16.3, 6.5, Color3.fromRGB(150, 70, 50), M.Slate, Color3.fromRGB(120, 82, 50))
	local chimney = newPart(model, Vector3.new(2.6, 9, 2.6), base * CFrame.new(-length * 0.32, 21, -2), STONE, M.Cobblestone)
	smoke(chimney)
	-- Cartel colgante con una jarra
	local arm = newPart(model, Vector3.new(0.5, 0.5, 4), base * CFrame.new(length / 2 - 2, 10, depth / 2 + 2.9), DARK_WOOD, M.Wood)
	arm.Name = "Brazo"
	local sign = decor(newPart(model, Vector3.new(4.4, 3, 0.3), base * CFrame.new(length / 2 - 2, 8, depth / 2 + 4.4) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 82, 50), M.WoodPlanks))
	sign.Name = "Cartel"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = sign
		local text = textLabel(gui, "🍺 Taberna", UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), Color3.fromRGB(253, 224, 71))
		text.Font = Enum.Font.GrenzeGotisch
	end
	-- Barriles, mesa y bancos en la puerta
	for k = 0, 2 do
		barrel(model, (base * CFrame.new(-length / 2 + 1.5 + k * 2.4, 0, depth / 2 + 2)).Position)
	end
	local tablePos = base * CFrame.new(5.5, 0, depth / 2 + 5)
	newPart(model, Vector3.new(6, 0.5, 3), tablePos * CFrame.new(0, 3, 0), WOOD, M.WoodPlanks).Name = "Mesa"
	for _, x in { -2.4, 2.4 } do
		newPart(model, Vector3.new(0.6, 3, 0.6), tablePos * CFrame.new(x, 1.5, 0), DARK_WOOD, M.Wood)
	end
	for _, z in { -2.6, 2.6 } do
		newPart(model, Vector3.new(6, 0.5, 1.2), tablePos * CFrame.new(0, 1.8, z), WOOD, M.WoodPlanks).Name = "Banco"
	end
	local mug = decor(column(model, 0.9, 0.7, (tablePos * CFrame.new(1, 3.7, 0)).Position, Color3.fromRGB(253, 224, 71), M.Glass))
	mug.Name = "Jarra"
	model.Parent = parent
end

-- Pozo de piedra con tejadillo, polea y cubo
local function well(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Pozo"
	for k = 0, 9 do
		local angle = k / 10 * math.pi * 2
		newPart(model, Vector3.new(2.2, 3, 1.2), CFrame.new(position + Vector3.new(math.cos(angle) * 3.2, 1.5, math.sin(angle) * 3.2)) * CFrame.Angles(0, -angle + math.pi / 2, 0), STONE, M.Cobblestone)
	end
	decor(column(model, 0.2, 5.6, position + Vector3.new(0, 1.6, 0), Color3.fromRGB(40, 90, 130), M.Glass)).Name = "Agua"
	for _, x in { -3.4, 3.4 } do
		newPart(model, Vector3.new(0.7, 8, 0.7), CFrame.new(position + Vector3.new(x, 4, 0)), DARK_WOOD, M.Wood)
	end
	decor(column(model, 7.6, 0.6, position + Vector3.new(0, 7, 0), WOOD, M.Wood)).CFrame = CFrame.new(position + Vector3.new(0, 7, 0))
	gableRoof(model, CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0), 3, 8.4, 8, 2.6, THATCH, M.Grass, Color3.fromRGB(120, 82, 50))
	decor(newPart(model, Vector3.new(0.1, 3.5, 0.1), CFrame.new(position + Vector3.new(0, 5.2, 0)), Color3.fromRGB(150, 130, 100), M.Fabric)).Name = "Cuerda"
	decor(column(model, 1.2, 1.2, position + Vector3.new(0, 3.2, 0), WOOD, M.WoodPlanks)).Name = "Cubo"
	model.Parent = parent
end

-- Torre redonda con almenas y tejado cónico (con bandera)
local function castleTower(parent: Instance, position: Vector3, diameter: number, height: number, stone: Color3, roof: Color3, flag: Color3)
	decor(column(parent, height, diameter, position + Vector3.new(0, height / 2, 0), stone, M.Cobblestone)).Name = "Torre"
	decor(column(parent, 1.2, diameter + 1.4, position + Vector3.new(0, height + 0.6, 0), stone, M.Cobblestone))
	local count = math.max(6, math.floor(diameter * 0.9))
	for k = 0, count - 1 do
		local angle = k / count * math.pi * 2
		decor(newPart(parent, Vector3.new(1.6, 2.2, 1.6), CFrame.new(position + Vector3.new(math.cos(angle) * (diameter / 2 + 0.3), height + 2.3, math.sin(angle) * (diameter / 2 + 0.3))) * CFrame.Angles(0, -angle, 0), stone, M.Cobblestone))
	end
	local d = diameter * 1.05
	local y = height + 2
	for k = 1, 7 do
		decor(column(parent, diameter * 0.22, d, position + Vector3.new(0, y + diameter * 0.11, 0), roof, M.Slate))
		y += diameter * 0.2
		d *= 0.74
	end
	decor(newPart(parent, Vector3.new(0.3, 6, 0.3), CFrame.new(position + Vector3.new(0, y + 3, 0)), DARK_WOOD, M.Wood))
	decor(newPart(parent, Vector3.new(0.15, 2.4, 4), CFrame.new(position + Vector3.new(0, y + 4.6, 2)), flag, M.Fabric)).Name = "Bandera"
	-- Ventanas encendidas
	for k = 0, 2 do
		local angle = k / 3 * math.pi * 2 + 0.4
		local glow = decor(newPart(parent, Vector3.new(1, 2.4, 1), CFrame.new(position + Vector3.new(math.cos(angle) * diameter / 2, height * 0.65, math.sin(angle) * diameter / 2)), WINDOW_GLOW, M.Neon))
		glow.Name = "Ventana"
	end
end

-- Lienzo de muralla de "a" a "b" con almenas
local function castleWall(parent: Instance, a: Vector3, b: Vector3, height: number, thickness: number, stone: Color3)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local frame = CFrame.lookAt(mid, b)
	decor(newPart(parent, Vector3.new(thickness, height, length), frame * CFrame.new(0, height / 2, 0), stone, M.Cobblestone)).Name = "Muralla"
	local n = math.floor(length / 4)
	for k = 0, n - 1 do
		for _, side in { -1, 1 } do
			decor(newPart(parent, Vector3.new(1, 2, 2), frame * CFrame.new(side * (thickness / 2 - 0.5), height + 1, -length / 2 + 2 + k * 4), stone, M.Cobblestone))
		end
	end
end

-- Castillo grande al norte, sobre una colina de roca en el lago, con puente
local function buildCastle(lobby: Instance)
	local model = Instance.new("Model")
	model.Name = "Castillo"
	local center = Vector3.new(0, 18, -236)
	local stone = Color3.fromRGB(176, 170, 160)
	local roofBlue = Color3.fromRGB(44, 72, 140)
	local roofRed = Color3.fromRGB(150, 40, 40)
	-- Colina rocosa con hierba arriba
	tCylinder(Vector3.new(0, 1, -236), 34, 50, M.Rock)
	tCylinder(Vector3.new(0, 17, -236), 2, 47, M.Grass)
	for k = 0, 9 do
		local angle = k / 10 * math.pi * 2
		tBall(Vector3.new(math.cos(angle) * 48, random:NextNumber(-8, 6), -236 + math.sin(angle) * 48), random:NextNumber(14, 22), M.Rock)
	end
	-- Murallas y torres de las esquinas
	local half = 30
	local corners = {
		center + Vector3.new(-half, 0, -half),
		center + Vector3.new(half, 0, -half),
		center + Vector3.new(half, 0, half),
		center + Vector3.new(-half, 0, half),
	}
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		if i == 3 then
			-- Muralla sur (la que mira al lobby) con hueco para la puerta
			castleWall(model, a, center + Vector3.new(7, 0, half), 16, 4, stone)
			castleWall(model, center + Vector3.new(-7, 0, half), b, 16, 4, stone)
		else
			castleWall(model, a, b, 16, 4, stone)
		end
	end
	for _, corner in corners do
		castleTower(model, corner, 11, 26, stone, roofBlue, Color3.fromRGB(220, 38, 38))
	end
	-- Puerta: dos torrecillas, arco y rastrillo
	local gate = center + Vector3.new(0, 0, half)
	for _, x in { -8, 8 } do
		castleTower(model, gate + Vector3.new(x, 0, 2), 7, 20, stone, roofRed, Color3.fromRGB(251, 191, 36))
	end
	local archTop = stoneArch(model, CFrame.new(gate + Vector3.new(0, 0, 2.5)), 10, 9, stone)
	decor(newPart(model, Vector3.new(12, 16 - archTop + 2, 4), CFrame.new(gate + Vector3.new(0, archTop + (16 - archTop + 2) / 2 - 1, 0)), stone, M.Cobblestone))
	for k = -2, 2 do
		decor(newPart(model, Vector3.new(0.4, 10, 0.4), CFrame.new(gate + Vector3.new(k * 1.8, 6, 1)), Color3.fromRGB(40, 40, 44), M.Metal)).Name = "Rastrillo"
	end
	for k = 0, 3 do
		decor(newPart(model, Vector3.new(9, 0.4, 0.4), CFrame.new(gate + Vector3.new(0, 2 + k * 2.6, 1)), Color3.fromRGB(40, 40, 44), M.Metal))
	end
	-- Torre del homenaje en el centro (la más alta)
	local keep = center + Vector3.new(0, 0, -6)
	decor(newPart(model, Vector3.new(22, 34, 22), CFrame.new(keep + Vector3.new(0, 17, 0)), stone, M.Cobblestone)).Name = "Homenaje"
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local along = Vector3.new(side.Z, 0, side.X)
		for k = -2, 2 do
			decor(newPart(model, Vector3.new(2, 2.4, 2), CFrame.new(keep + side * 10.5 + along * (k * 4.4) + Vector3.new(0, 35.2, 0)), stone, M.Cobblestone))
			if math.abs(k) == 1 then
				local glow = decor(newPart(model, Vector3.new(if side.X ~= 0 then 0.4 else 1.6, 3, if side.X ~= 0 then 1.6 else 0.4), CFrame.new(keep + side * 11.05 + along * (k * 5) + Vector3.new(0, 24, 0)), WINDOW_GLOW, M.Neon))
				glow.Name = "Ventana"
			end
		end
	end
	for _, spot in { Vector3.new(-9, 0, -9), Vector3.new(9, 0, -9), Vector3.new(-9, 0, 9), Vector3.new(9, 0, 9) } do
		castleTower(model, keep + spot + Vector3.new(0, 30, 0), 6, 12, stone, roofBlue, Color3.fromRGB(56, 189, 248))
	end
	castleTower(model, keep + Vector3.new(0, 34, 0), 9, 10, stone, roofRed, Color3.fromRGB(251, 191, 36))
	local beacon = decor(newPart(model, Vector3.new(2, 2, 2), CFrame.new(keep + Vector3.new(0, 30, 11.6)), WINDOW_GLOW, M.Neon))
	pointLight(beacon, WARM_LIGHT, 40, 2)
	-- Estandartes grandes en la muralla sur
	for _, x in { -20, 20 } do
		banner(model, center + Vector3.new(x, 4, half + 2.3), Color3.fromRGB(150, 30, 40), 11, 0)
	end
	-- Puente de piedra desde la orilla hasta la puerta (con arcos)
	local from = Vector3.new(0, 0.6, -134)
	local to = gate + Vector3.new(0, 0.6, 5)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	local deck = CFrame.lookAt(mid, to)
	newPart(model, Vector3.new(10, 1.2, length), deck, Color3.fromRGB(150, 142, 130), M.Cobblestone).Name = "Puente"
	for _, side in { -1, 1 } do
		newPart(model, Vector3.new(1, 2.2, length), deck * CFrame.new(side * 4.6, 1.6, 0), stone, M.Cobblestone).Name = "Pretil"
	end
	for k = 1, 4 do
		local t = k / 5
		local p = from:Lerp(to, t)
		decor(newPart(model, Vector3.new(7, p.Y + 20, 4), CFrame.new(Vector3.new(p.X, (p.Y - 20) / 2 - 0.6, p.Z)), stone, M.Cobblestone)).Name = "Pilar"
		lamppost(model, p + Vector3.new(4.6, 2.7, 0))
	end
	model.Parent = lobby
end

-- Aldea: taberna, cabañas y pozo
local function buildVillage(lobby: Instance)
	local village = Instance.new("Model")
	village.Name = "Aldea"
	tavern(village, CFrame.new(-50, 0, 52) * CFrame.Angles(0, math.rad(90), 0))
	tBlob(Vector3.new(-40, 0, 52), 9, M.Ground)
	cottage(village, CFrame.new(-34, 0, 90) * CFrame.Angles(0, math.rad(200), 0), 14, 10, "Cabaña")
	cottage(village, CFrame.new(24, 0, 98) * CFrame.Angles(0, math.rad(160), 0), 12, 10, "Cabaña")
	cottage(village, CFrame.new(48, 0, 34) * CFrame.Angles(0, math.rad(-120), 0), 12, 9, "Cabaña")
	cottage(village, CFrame.new(116, 0, 22) * CFrame.Angles(0, math.rad(-100), 0), 12, 9, "Cabaña")
	well(village, Vector3.new(-26, 0, 42))
	tRound(Vector3.new(-26, 0, 42), 7, M.Cobblestone)
	-- Huertos con vallas junto a las cabañas
	for _, spot in { Vector3.new(-16, 0, 100), Vector3.new(41, 0, 95) } do
		tPatch(spot, 10, 8, 0, M.Mud)
		for k = -2, 2 do
			decor(newPart(village, Vector3.new(0.4, 1.8, 0.4), CFrame.new(spot + Vector3.new(k * 2.4, 0.9, -4.2)), WOOD, M.Wood))
			decor(newPart(village, Vector3.new(0.4, 1.8, 0.4), CFrame.new(spot + Vector3.new(k * 2.4, 0.9, 4.2)), WOOD, M.Wood))
		end
		for _, z in { -4.2, 4.2 } do
			decor(newPart(village, Vector3.new(10, 0.3, 0.3), CFrame.new(spot + Vector3.new(0, 1.4, z)), WOOD, M.Wood))
		end
		for k = -1, 1 do
			for j = -1, 1 do
				decor(ball(village, 1.2, spot + Vector3.new(k * 3, 0.5, j * 2.4), Color3.fromRGB(74, 160, 60), M.Grass))
			end
		end
	end
	village.Parent = lobby
end

---------------------------------------------------------------------
-- Lobby: la isla
---------------------------------------------------------------------
local function buildIsland()
	-- Agua y fondo del lago
	tBlock(CFrame.new(0, -26, 0), Vector3.new(1100, 12, 1100), M.Sand)
	tBlock(CFrame.new(0, -12, 0), Vector3.new(1100, 16, 1100), M.Water)
	-- Playa y la isla (arriba en y = 0)
	tCylinder(Vector3.new(0, -9, 0), 14, 156, M.Sand)
	tCylinder(Vector3.new(0, -8, 0), 16, 140, M.Grass)
	-- Montañas nevadas alrededor
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2 + random:NextNumber(-0.12, 0.12)
		local distance = random:NextNumber(310, 380)
		local radius = random:NextNumber(55, 95)
		local center = Vector3.new(math.cos(angle) * distance, -radius * 0.3, math.sin(angle) * distance)
		tBall(center, radius, M.Rock)
		-- Laderas verdes abajo, picos irregulares y nieve arriba
		for _ = 1, 3 do
			local a = random:NextNumber(0, math.pi * 2)
			tBall(center + Vector3.new(math.cos(a) * radius * 0.7, -radius * 0.25, math.sin(a) * radius * 0.7), radius * random:NextNumber(0.4, 0.55), M.Grass)
		end
		local peak = center
		local r = radius
		for level = 1, 3 do
			r *= random:NextNumber(0.5, 0.62)
			peak += Vector3.new(random:NextNumber(-0.25, 0.25) * r, r * 1.25, random:NextNumber(-0.25, 0.25) * r)
			tBall(peak, r, if level == 3 then M.Snow else M.Rock)
			if level == 2 then
				tBall(peak + Vector3.new(0, r * 0.55, 0), r * 0.55, M.Snow)
			end
		end
	end
	-- Islotes con árboles
	for _, spot in { Vector3.new(-205, 0, 120), Vector3.new(215, 0, -60), Vector3.new(60, 0, 215), Vector3.new(-120, 0, -205) } do
		tBall(spot + Vector3.new(0, -21, 0), 27, M.Sand)
		tBall(spot + Vector3.new(0, -13, 0), 20, M.Grass)
	end
end

local function buildPlaza(lobby: Instance)
	-- Caminos (cambian la capa de arriba del terreno)
	tRound(Vector3.new(0, 0, 0), 38, M.Cobblestone)
	tRound(Vector3.new(0, 0, 0), 30, M.Pavement)
	tPatch(Vector3.new(0, 0, -58), 16, 44, 0, M.Cobblestone)
	tPatch(Vector3.new(-56, 0, 0), 44, 12, 0, M.Ground)
	tPatch(Vector3.new(56, 0, 0), 44, 12, 0, M.Ground)
	tPatch(Vector3.new(0, 0, 54), 12, 34, 0, M.Cobblestone)
	tPatch(Vector3.new(44, 0, 64), 10, 46, math.rad(-35), M.Ground)

	-- Aparición invisible en el sur de la plaza
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Aparicion"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 20)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Parent = lobby

	-- Fuente
	local fountain = Instance.new("Model")
	fountain.Name = "Fuente"
	column(fountain, 2.6, 22, Vector3.new(0, 1.3, 0), STONE, M.Slate)
	local water = column(fountain, 0.4, 19.5, Vector3.new(0, 2.4, 0), Color3.fromRGB(80, 170, 220), M.Glass)
	water.Name = "Agua"
	water.Transparency = 0.25
	water.Reflectance = 0.3
	column(fountain, 6, 3, Vector3.new(0, 3, 0), STONE, M.Marble)
	column(fountain, 1, 9, Vector3.new(0, 6.5, 0), STONE, M.Marble)
	local top = decor(column(fountain, 0.3, 8, Vector3.new(0, 7.1, 0), Color3.fromRGB(80, 170, 220), M.Glass))
	top.Transparency = 0.25
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Rate = 60
	spray.Speed = NumberRange.new(10, 13)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = top
	pointLight(water, Color3.fromRGB(140, 210, 255), 16, 0.8)
	fountain.Parent = lobby

	-- Estatua del héroe (al norte de la fuente, mirando al sur)
	local statue = Instance.new("Model")
	statue.Name = "Estatua"
	local marble = Color3.fromRGB(226, 224, 218)
	local base = Vector3.new(0, 0, -20)
	newPart(statue, Vector3.new(9, 3, 9), CFrame.new(base + Vector3.new(0, 1.5, 0)), DARK_STONE, M.Slate)
	newPart(statue, Vector3.new(7, 2, 7), CFrame.new(base + Vector3.new(0, 4, 0)), STONE, M.Marble)
	for _, side in { -1, 1 } do
		newPart(statue, Vector3.new(1.3, 4, 1.4), CFrame.new(base + Vector3.new(side * 0.8, 7, 0)), marble, M.Marble)
	end
	newPart(statue, Vector3.new(3.2, 3.6, 1.8), CFrame.new(base + Vector3.new(0, 10.8, 0)), marble, M.Marble)
	newPart(statue, Vector3.new(2.2, 2.2, 2.2), CFrame.new(base + Vector3.new(0, 13.7, 0)), marble, M.Marble)
	newPart(statue, Vector3.new(1.1, 3.6, 1.1), CFrame.new(base + Vector3.new(-2.2, 11, 0)) * CFrame.Angles(0, 0, math.rad(-15)), marble, M.Marble)
	newPart(statue, Vector3.new(1.1, 3.6, 1.1), CFrame.new(base + Vector3.new(2.1, 13.6, 0)) * CFrame.Angles(0, 0, math.rad(20)), marble, M.Marble)
	local sword = newPart(statue, Vector3.new(0.6, 9, 0.25), CFrame.new(base + Vector3.new(3.4, 19.4, 0)) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(210, 220, 235), M.Metal)
	sword.Name = "Espada"
	newPart(statue, Vector3.new(2.6, 0.5, 0.6), CFrame.new(base + Vector3.new(2.3, 15.4, 0)) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(202, 138, 4), M.Metal)
	newPart(statue, Vector3.new(3.4, 4.2, 0.5), CFrame.new(base + Vector3.new(-2.8, 10.2, -0.8)), Color3.fromRGB(180, 178, 172), M.Marble)
	local title = billboard(sword, UDim2.fromOffset(460, 120), Vector3.new(0, 9, 0), 260)
	textLabel(title, "⚔️ DUNGEON ASCEND", UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0), Color3.fromRGB(251, 191, 36))
	textLabel(title, "Sobrevive a la horda · vence al jefe · escapa por el portal", UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0.62), Color3.new(1, 1, 1))
	statue.Parent = lobby

	-- Farolas, bancos y flores alrededor de la plaza
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + math.pi / 8
		local pos = Vector3.new(math.cos(angle) * 34, 0, math.sin(angle) * 34)
		lamppost(lobby, pos)
		local benchAngle = angle + math.pi / 8
		local benchPos = Vector3.new(math.cos(benchAngle) * 33, 0, math.sin(benchAngle) * 33)
		if i % 2 == 0 then
			local facing = CFrame.lookAt(benchPos, Vector3.new(0, 0, 0)).Rotation
			local bench = Instance.new("Model")
			bench.Name = "Banco"
			newPart(bench, Vector3.new(6, 0.5, 1.8), CFrame.new(benchPos + Vector3.new(0, 1.6, 0)) * facing, WOOD, M.WoodPlanks)
			newPart(bench, Vector3.new(6, 1.6, 0.4), CFrame.new(benchPos + Vector3.new(0, 2.6, 0)) * facing * CFrame.new(0, 0, 0.8), WOOD, M.WoodPlanks)
			for _, x in { -2.4, 2.4 } do
				newPart(bench, Vector3.new(0.5, 1.4, 1.6), CFrame.new(benchPos + Vector3.new(0, 0.7, 0)) * facing * CFrame.new(x, 0, 0), Color3.fromRGB(40, 40, 44), M.Metal)
			end
			bench.Parent = lobby
		else
			flowers(lobby, benchPos * 1.12, 3, 10)
		end
	end
	-- Parterres de flores junto a los caminos
	for _, spot in { Vector3.new(-14, 0, -48), Vector3.new(14, 0, -48), Vector3.new(-30, 0, 14), Vector3.new(30, 0, -14), Vector3.new(-14, 0, 44), Vector3.new(14, 0, 44) } do
		tRound(spot, 5, M.Mud)
		flowers(lobby, spot, 4, 18)
		bush(lobby, spot, 1)
	end
end

local function buildPortalTerrace(lobby: Instance)
	-- Terraza elevada al norte (arriba en y = 8) con rampa desde la plaza
	tBlock(CFrame.new(0, 2, -104), Vector3.new(140, 12, 44), M.Limestone)
	tBlock(CFrame.new(0, 6, -104), Vector3.new(132, 4, 36), M.Pavement)
	-- Escalones de terreno (el terreno los suaviza en una rampa)
	for k = 1, 4 do
		tBlock(CFrame.new(0, k - 2, -66 - (k - 0.5) * 4), Vector3.new(18, 2 * k + 4, 4), M.Cobblestone)
	end
	-- Barandilla de piedra con braseros
	for _, x in { -50, -34, 34, 50 } do
		newPart(lobby, Vector3.new(16, 1.6, 1.4), CFrame.new(x, 8.8, -82.5), STONE, M.Cobblestone).Name = "Barandilla"
	end
	for _, x in { -60, -18, 18, 60 } do
		newPart(lobby, Vector3.new(8, 1.6, 1.4), CFrame.new(x + (if x < 0 then 4 else -4) * (if math.abs(x) == 18 then -1 else 1), 8.8, -82.5), STONE, M.Cobblestone).Name = "Barandilla"
	end
	for _, x in { -66, -11, 11, 66 } do
		column(lobby, 4.5, 2.4, Vector3.new(x, 10.2, -82.5), DARK_STONE, M.Slate)
		brazier(lobby, Vector3.new(x, 12.4, -82.5))
	end

	-- Los tres portales
	for i, map in Config.Maps do
		local x = (i - (#Config.Maps + 1) / 2) * 40
		local base = CFrame.new(x, 8, -112)
		local arch = Instance.new("Model")
		arch.Name = "Portal_" .. map.id
		newPart(arch, Vector3.new(26, 1.4, 12), base * CFrame.new(0, 0.7, 0), DARK_STONE, M.Slate)
		newPart(arch, Vector3.new(22, 1, 9), base * CFrame.new(0, 1.9, 0), STONE, M.Cobblestone)
		local archTop = stoneArch(arch, base * CFrame.new(0, 2.4, 0), 16, 12, STONE)
		-- Gema en la clave del arco
		local gem = decor(newPart(arch, Vector3.new(2.4, 2.4, 2.4), base * CFrame.new(0, archTop + 3, 1.9) * CFrame.Angles(0, 0, math.rad(45)), map.color, M.Neon))
		pointLight(gem, map.color, 14, 1.5)
		-- Disco del portal (cilindro girado para mirar a la plaza)
		local disc = newPart(arch, Vector3.new(0.6, 15, 15), base * CFrame.new(0, 10.4, 0) * CFrame.Angles(0, math.rad(90), 0), map.color, M.Neon)
		disc.Shape = Enum.PartType.Cylinder
		disc.Name = "Disco"
		disc.Transparency = 0.3
		disc.CanCollide = false
		local inner = decor(newPart(arch, Vector3.new(0.7, 9, 9), disc.CFrame, map.color:Lerp(Color3.new(1, 1, 1), 0.5), M.Neon))
		inner.Shape = Enum.PartType.Cylinder
		inner.Transparency = 0.5
		pointLight(disc, map.color, 28, 3)
		sparkles(disc, map.color:Lerp(Color3.new(1, 1, 1), 0.3), 24, 0.7, 4)
		-- Placa con el nombre
		local plaque = newPart(arch, Vector3.new(14, 3.4, 0.6), base * CFrame.new(0, 3.6, 5.6), DARK_STONE, M.Slate)
		plaque.Name = "Placa"
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = plaque
		textLabel(gui, map.emoji .. " " .. map.name, UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0.04), map.color:Lerp(Color3.new(1, 1, 1), 0.45))
		textLabel(gui, map.waves .. " oleadas · jefe final", UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.64), Color3.fromRGB(226, 232, 240))
		prompt(disc, "Jugar", map.name, function(player)
			callbacks.onOpen(player, "jugar", map.id)
		end)
		banner(arch, Vector3.new(x - 12.5, 8, -106), map.color, 13, 0)
		banner(arch, Vector3.new(x + 12.5, 8, -106), map.color, 13, math.pi)
		arch.Parent = lobby
	end
	-- Cristales flotantes de ambiente sobre la terraza
	for k = 1, 6 do
		local c = crystal(lobby, Vector3.new(-70 + k * 20, 26 + random:NextNumber(-2, 3), -122), 4, Color3.fromRGB(196, 181, 253), false)
		c.Transparency = 0.25
	end
	-- Pinos detrás de los portales
	for k = 0, 10 do
		pine(lobby, Vector3.new(-75 + k * 15 + random:NextNumber(-3, 3), 8, -122 + random:NextNumber(-1.5, 1.5)), random:NextNumber(1.1, 1.5))
	end
end

local function buildForge(lobby: Instance)
	local model = Instance.new("Model")
	model.Name = "Forja"
	local origin = Vector3.new(-78, 0, 0)
	local wall = Color3.fromRGB(130, 120, 110)
	tRound(origin, 15, M.Cobblestone)
	-- Paredes (atrás y lados) y vigas; la fachada abierta mira a la plaza (+X)
	newPart(model, Vector3.new(1.6, 11, 22), CFrame.new(origin + Vector3.new(-8, 5.5, 0)), wall, M.Cobblestone)
	for _, z in { -11, 11 } do
		newPart(model, Vector3.new(16, 11, 1.6), CFrame.new(origin + Vector3.new(0, 5.5, z)), wall, M.Cobblestone)
		newPart(model, Vector3.new(1.4, 11.5, 1.4), CFrame.new(origin + Vector3.new(8, 5.75, z)), DARK_WOOD, M.Wood)
	end
	newPart(model, Vector3.new(1.2, 1.2, 23.4), CFrame.new(origin + Vector3.new(8, 11, 0)), DARK_WOOD, M.Wood)
	-- Tejado a dos aguas
	local angle = math.rad(32)
	local halfSpan = 12.5
	for _, side in { -1, 1 } do
		local slab = newPart(model, Vector3.new(19, 1, halfSpan / math.cos(angle) + 1), CFrame.new(origin + Vector3.new(0, 11.2 + halfSpan * math.tan(angle) / 2, side * halfSpan / 2)) * CFrame.Angles(side * angle, 0, 0), Color3.fromRGB(122, 52, 40), M.WoodPlanks)
		slab.Name = "Tejado"
	end
	newPart(model, Vector3.new(19.4, 1, 1.2), CFrame.new(origin + Vector3.new(0, 11.4 + halfSpan * math.tan(angle), 0)), DARK_WOOD, M.Wood)
	-- Chimenea con humo
	local chimney = newPart(model, Vector3.new(4, 20, 4), CFrame.new(origin + Vector3.new(-5, 10, -6)), Color3.fromRGB(120, 60, 46), M.Brick)
	chimney.Name = "Chimenea"
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(120, 120, 120)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = newPart(model, Vector3.new(3, 0.4, 3), CFrame.new(origin + Vector3.new(-5, 20.2, -6)), Color3.fromRGB(30, 30, 30), M.Slate)
	-- Horno brillante, yunque, armas y barriles
	newPart(model, Vector3.new(5, 6, 6), CFrame.new(origin + Vector3.new(-5, 3, -6)), Color3.fromRGB(110, 54, 40), M.Brick)
	local embers = decor(newPart(model, Vector3.new(0.4, 2.6, 3.4), CFrame.new(origin + Vector3.new(-2.4, 2.2, -6)), Color3.fromRGB(255, 120, 40), M.Neon))
	embers.Name = "Brasas"
	fire(embers, 4)
	pointLight(embers, Color3.fromRGB(255, 150, 70), 26, 3, true)
	newPart(model, Vector3.new(2.6, 2.6, 2), CFrame.new(origin + Vector3.new(3, 1.3, 2)), Color3.fromRGB(46, 42, 40), M.Metal)
	local anvil = newPart(model, Vector3.new(4.6, 1.3, 2), CFrame.new(origin + Vector3.new(3, 3.25, 2)), Color3.fromRGB(70, 70, 78), M.Metal)
	anvil.Name = "Yunque"
	newPart(model, Vector3.new(1.4, 0.8, 1.2), CFrame.new(origin + Vector3.new(5.6, 3.3, 2)), Color3.fromRGB(70, 70, 78), M.Metal)
	newPart(model, Vector3.new(0.4, 0.4, 3), CFrame.new(origin + Vector3.new(2.6, 4.2, 2.2)) * CFrame.Angles(0, 0.6, 0), Color3.fromRGB(150, 150, 160), M.Metal)
	for k = 0, 3 do
		decor(newPart(model, Vector3.new(0.3, 5, 0.6), CFrame.new(origin + Vector3.new(-6.8, 3.4, 4 + k * 1.6)) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(200, 205, 215), M.Metal))
	end
	newPart(model, Vector3.new(0.6, 0.6, 7), CFrame.new(origin + Vector3.new(-6.6, 5.4, 6.4)), DARK_WOOD, M.Wood)
	barrel(model, origin + Vector3.new(10, 0, -9))
	barrel(model, origin + Vector3.new(12.4, 0, -7.4))
	crate(model, origin + Vector3.new(10.5, 0, 9.5), 3)
	crate(model, origin + Vector3.new(11, 3, 9.5), 2.2)
	-- Cartel
	local sign = newPart(model, Vector3.new(0.4, 2.6, 8), CFrame.new(origin + Vector3.new(9.2, 9, 0)), WOOD, M.WoodPlanks)
	sign.Name = "Cartel"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	gui.Parent = sign
	textLabel(gui, "🔨 FORJA", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(253, 186, 116))
	prompt(anvil, "Mejorar equipo", "Forja", function(player)
		callbacks.onOpen(player, "forja", nil)
	end)
	model.Parent = lobby
	lamppost(lobby, origin + Vector3.new(14, 0, 12))
end

local function buildMarket(lobby: Instance)
	local model = Instance.new("Model")
	model.Name = "Mercado"
	local center = Vector3.new(80, 0, 0)
	tRound(center, 18, M.Cobblestone)
	local stripes = { { Color3.fromRGB(220, 38, 38), Color3.fromRGB(250, 245, 235) }, { Color3.fromRGB(37, 99, 235), Color3.fromRGB(250, 245, 235) }, { Color3.fromRGB(22, 163, 74), Color3.fromRGB(253, 224, 71) } }
	local shopCounter: BasePart? = nil
	for i, offsetZ in { -12, 0, 12 } do
		local pos = center + Vector3.new(if i == 2 then -3 else 2, 0, offsetZ)
		-- Mostrador y postes; los puestos miran a la plaza (-X)
		local counter = newPart(model, Vector3.new(3, 3.4, 9), CFrame.new(pos + Vector3.new(-2, 1.7, 0)), Color3.fromRGB(140, 94, 56), M.WoodPlanks)
		counter.Name = "Mostrador"
		for _, dz in { -4.4, 4.4 } do
			newPart(model, Vector3.new(0.7, 9, 0.7), CFrame.new(pos + Vector3.new(-3.6, 4.5, dz)), DARK_WOOD, M.Wood)
			newPart(model, Vector3.new(0.7, 11, 0.7), CFrame.new(pos + Vector3.new(3, 5.5, dz)), DARK_WOOD, M.Wood)
		end
		-- Toldo a rayas, inclinado hacia la plaza
		for k = 0, 5 do
			local color = stripes[i][k % 2 + 1]
			newPart(model, Vector3.new(8.6, 0.3, 1.6), CFrame.new(pos + Vector3.new(-0.3, 10.4, -4 + k * 1.6)) * CFrame.Angles(0, 0, math.rad(14)), color, M.Fabric).Name = "Toldo"
		end
		-- Mercancía
		if i == 1 then
			for k = 0, 5 do
				decor(ball(model, 1, pos + Vector3.new(-2 + (k % 2) * 0.9, 3.9, -3 + k), pick({ Color3.fromRGB(220, 38, 38), Color3.fromRGB(250, 204, 21), Color3.fromRGB(132, 204, 22) }), M.SmoothPlastic))
			end
		elseif i == 2 then
			for k = 0, 5 do
				local potion = decor(column(model, 1.4, 0.8, pos + Vector3.new(-2, 4.1, -3 + k * 1.2), pick({ Color3.fromRGB(244, 63, 94), Color3.fromRGB(56, 189, 248), Color3.fromRGB(168, 85, 247) }), M.Neon))
				potion.Transparency = 0.2
			end
			shopCounter = counter
		else
			for k = 0, 2 do
				decor(newPart(model, Vector3.new(0.3, 4.4, 0.6), CFrame.new(pos + Vector3.new(-2, 5.6, -2.5 + k * 2.5)) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(203, 213, 225), M.Metal))
			end
		end
		crate(model, pos + Vector3.new(4.5, 0, 3), 2.6)
		barrel(model, pos + Vector3.new(4.8, 0, -3))
	end
	-- Guirnalda de farolillos
	for k = 0, 8 do
		local lantern = decor(ball(model, 0.8, center + Vector3.new(-6.5, 11.6 - math.abs(k - 4) * 0.25, -16 + k * 4), pick({ Color3.fromRGB(253, 186, 116), Color3.fromRGB(252, 211, 77) }), M.Neon))
		if k % 3 == 1 then
			pointLight(lantern, WARM_LIGHT, 14, 1)
		end
	end
	local sign = newPart(model, Vector3.new(0.5, 3, 12), CFrame.new(center + Vector3.new(-7.2, 13, 0)), WOOD, M.WoodPlanks)
	sign.Name = "Cartel"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	gui.Parent = sign
	textLabel(gui, "🛒 TIENDA", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(253, 224, 71))
	if shopCounter then
		prompt(shopCounter, "Ver tienda", "Tienda", function(player)
			callbacks.onOpen(player, "tienda", nil)
		end)
	end
	model.Parent = lobby
	lamppost(lobby, center + Vector3.new(-12, 0, 16))
	lamppost(lobby, center + Vector3.new(-12, 0, -16))
end

local function buildLeaderboard(lobby: Instance)
	local origin = Vector3.new(0, 0, 76)
	tRound(origin, 13, M.Pavement)
	newPart(lobby, Vector3.new(30, 2, 6), CFrame.new(origin + Vector3.new(0, 1, 0)), DARK_STONE, M.Slate)
	for _, x in { -12.5, 12.5 } do
		newPart(lobby, Vector3.new(3, 22, 3), CFrame.new(origin + Vector3.new(x, 12, 0)), STONE, M.Cobblestone)
		newPart(lobby, Vector3.new(4, 1.2, 4), CFrame.new(origin + Vector3.new(x, 23.6, 0)), DARK_STONE, M.Slate)
		brazier(lobby, origin + Vector3.new(x, 24.2, 0))
	end
	-- La cara delantera (Front = -Z) mira hacia la plaza
	local board = newPart(lobby, Vector3.new(22, 17, 1), CFrame.new(origin + Vector3.new(0, 11.5, 0)), Color3.fromRGB(30, 27, 46), M.SmoothPlastic)
	board.Name = "Clasificacion"
	newPart(lobby, Vector3.new(24, 1.2, 1.6), CFrame.new(origin + Vector3.new(0, 20.6, 0)), Color3.fromRGB(202, 138, 4), M.Metal)
	newPart(lobby, Vector3.new(24, 1.2, 1.6), CFrame.new(origin + Vector3.new(0, 2.6, 0)), Color3.fromRGB(202, 138, 4), M.Metal)
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
end

local function buildPond(lobby: Instance)
	-- Estanque con muelle de madera (sureste)
	local center = Vector3.new(80, 0, 90)
	tRound(center, 20, M.Sand)
	tCylinder(center + Vector3.new(0, -3, 0), 6, 16, M.Air)
	tCylinder(center + Vector3.new(0, -6.5, 0), 3, 17, M.Mud)
	tCylinder(center + Vector3.new(0, -3, 0), 4, 16, M.Water)
	local dock = Instance.new("Model")
	dock.Name = "Muelle"
	for k = 0, 6 do
		newPart(dock, Vector3.new(1.3, 0.4, 4.6), CFrame.new(center + Vector3.new(-17 + k * 1.45, 0.4, -2)), Color3.fromRGB(150, 110, 70), M.WoodPlanks)
	end
	for k = 0, 2 do
		column(dock, 3.4, 0.6, center + Vector3.new(-16.6 + k * 3.6, -1, -4.4), DARK_WOOD, M.Wood)
		column(dock, 3.4, 0.6, center + Vector3.new(-16.6 + k * 3.6, -1, 0.4), DARK_WOOD, M.Wood)
	end
	dock.Parent = lobby
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2
		decor(column(lobby, 0.15, 3, center + Vector3.new(math.cos(angle) * 9, -1.05, math.sin(angle) * 9), Color3.fromRGB(74, 160, 74), M.Grass)).Name = "Nenufar"
	end
	for k = 1, 6 do
		local angle = k / 6 * math.pi * 2 + 0.6
		decor(column(lobby, 2.4, 0.3, center + Vector3.new(math.cos(angle) * 17.5, 1.2, math.sin(angle) * 17.5), Color3.fromRGB(120, 140, 60), M.Grass)).Name = "Junco"
	end
end

local function hayBale(parent: Instance, position: Vector3, angle: number)
	local bale = column(parent, 3, 2.6, position + Vector3.new(0, 1.3, 0), Color3.fromRGB(214, 180, 90), M.Grass)
	bale.CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, angle, 0)
	bale.Name = "Heno"
end

-- Campo de entrenamiento: muñecos de paja, dianas y heno
local function buildTraining(lobby: Instance)
	local center = Vector3.new(92, 0, -42)
	tBlob(center, 14, M.Ground)
	local model = Instance.new("Model")
	model.Name = "Entrenamiento"
	for k = 0, 2 do
		local pos = center + Vector3.new(-8 + k * 8, 0, -2 + (k % 2) * 3)
		column(model, 6, 0.6, pos + Vector3.new(0, 3, 0), DARK_WOOD, M.Wood)
		newPart(model, Vector3.new(4.5, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, 4.6, 0)), DARK_WOOD, M.Wood)
		column(model, 3, 2.4, pos + Vector3.new(0, 4.4, 0), Color3.fromRGB(214, 180, 90), M.Grass).Name = "Muneco"
		ball(model, 1.9, pos + Vector3.new(0, 6.6, 0), Color3.fromRGB(196, 160, 84), M.Fabric)
		decor(newPart(model, Vector3.new(2.5, 0.3, 0.3), CFrame.new(pos + Vector3.new(0, 4.9, -1.22)) * CFrame.Angles(0, 0, math.rad(30)), Color3.fromRGB(180, 40, 40), M.Fabric))
	end
	for k = 0, 1 do
		local pos = center + Vector3.new(-6 + k * 12, 0, -11)
		newPart(model, Vector3.new(0.5, 6, 0.5), CFrame.new(pos + Vector3.new(0, 3, 0.6)) * CFrame.Angles(math.rad(-15), 0, 0), DARK_WOOD, M.Wood)
		local target = newPart(model, Vector3.new(0.5, 5, 5), CFrame.new(pos + Vector3.new(0, 4.4, 0)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 235, 220), M.Fabric)
		target.Shape = Enum.PartType.Cylinder
		target.Name = "Diana"
		for r, color in { [3.4] = Color3.fromRGB(220, 38, 38), [1.8] = Color3.fromRGB(240, 235, 220), [0.8] = Color3.fromRGB(220, 38, 38) } do
			local ring = decor(newPart(model, Vector3.new(0.55, r, r), target.CFrame, color, M.Fabric))
			ring.Shape = Enum.PartType.Cylinder
		end
	end
	hayBale(model, center + Vector3.new(11, 0, 5), 0.3)
	hayBale(model, center + Vector3.new(12.5, 0, 8), 1.4)
	hayBale(model, center + Vector3.new(11.8, 2.6, 6.4), 0.9)
	for k = -2, 2 do
		column(model, 3, 0.5, center + Vector3.new(-14, 1.5, k * 4), DARK_WOOD, M.Wood)
	end
	newPart(model, Vector3.new(0.3, 0.4, 16.5), CFrame.new(center + Vector3.new(-14, 2.4, 0)), WOOD, M.Wood)
	newPart(model, Vector3.new(0.3, 0.4, 16.5), CFrame.new(center + Vector3.new(-14, 1.2, 0)), WOOD, M.Wood)
	model.Parent = lobby
end

-- Campamento: tiendas de campaña y hoguera
local function buildCamp(lobby: Instance)
	local center = Vector3.new(-94, 0, -42)
	tBlob(center, 13, M.Ground)
	local model = Instance.new("Model")
	model.Name = "Campamento"
	local tentColors = { Color3.fromRGB(180, 140, 90), Color3.fromRGB(120, 80, 140) }
	for k, offset in { Vector3.new(-6, 0, -6), Vector3.new(7, 0, -5) } do
		local pos = center + offset
		local angle = math.rad(40)
		local half = 3.6
		for _, side in { -1, 1 } do
			newPart(model, Vector3.new(8, 0.3, half / math.cos(angle) + 0.4), CFrame.new(pos + Vector3.new(0, half * math.tan(angle) / 2, side * half / 2)) * CFrame.Angles(side * angle, 0, 0), tentColors[k], M.Fabric).Name = "Tienda"
		end
		decor(newPart(model, Vector3.new(0.2, 2.4, 2.2), CFrame.new(pos + Vector3.new(4.05, 1, 0)), Color3.fromRGB(40, 30, 24), M.Fabric))
	end
	-- Hoguera con piedras y troncos para sentarse
	local fireCenter = center + Vector3.new(0, 0, 4)
	for k = 0, 7 do
		local angle = k / 8 * math.pi * 2
		decor(ball(model, 1.1, fireCenter + Vector3.new(math.cos(angle) * 2.2, 0.3, math.sin(angle) * 2.2), Color3.fromRGB(110, 106, 100), M.Slate))
	end
	for k = 0, 2 do
		local log = decor(column(model, 2.8, 0.5, fireCenter, DARK_WOOD, M.Wood))
		log.CFrame = CFrame.new(fireCenter + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, k * math.pi / 3, math.rad(15))
	end
	local flame = decor(ball(model, 0.8, fireCenter + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 150, 60), M.Neon))
	flame.Name = "Hoguera"
	fire(flame, 3)
	pointLight(flame, Color3.fromRGB(255, 160, 80), 22, 2.5, true)
	for k = 0, 2 do
		local angle = k / 3 * math.pi * 2 + 0.5
		local seat = column(model, 5, 1.4, fireCenter, WOOD, M.Wood)
		seat.CFrame = CFrame.new(fireCenter + Vector3.new(math.cos(angle) * 5.5, 0.7, math.sin(angle) * 5.5)) * CFrame.Angles(0, -angle + math.pi / 2, 0)
	end
	crate(model, center + Vector3.new(-11, 0, 3), 2.4)
	barrel(model, center + Vector3.new(-10, 0, 6.5))
	banner(model, center + Vector3.new(0, 0, -11), Color3.fromRGB(56, 189, 248), 11, 0)
	model.Parent = lobby
end

local function buildGroves(lobby: Instance)
	-- Bosquecillos alrededor (lejos de caminos y edificios)
	local groves = {
		{ Vector3.new(-112, 0, -78), 10 },
		{ Vector3.new(114, 0, -76), 10 },
		{ Vector3.new(-104, 0, 46), 18 },
		{ Vector3.new(-62, 0, 98), 16 },
		{ Vector3.new(114, 0, 44), 12 },
		{ Vector3.new(-30, 0, 118), 10 },
		{ Vector3.new(34, 0, 118), 8 },
		{ Vector3.new(-124, 0, -6), 10 },
		{ Vector3.new(126, 0, -12), 8 },
	}
	for _, grove in groves do
		local center, radius = grove[1], grove[2]
		local count = math.floor(radius / 3)
		for _ = 1, count do
			local angle = random:NextNumber(0, math.pi * 2)
			local r = math.sqrt(random:NextNumber()) * radius
			local pos = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			if pos.Magnitude < 132 then
				if random:NextNumber() < 0.6 then
					oak(lobby, pos, random:NextNumber(0.9, 1.4))
				else
					pine(lobby, pos, random:NextNumber(1, 1.4))
				end
			end
		end
		for _ = 1, 3 do
			local angle = random:NextNumber(0, math.pi * 2)
			local pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + random:NextNumber(1, 5))
			if pos.Magnitude < 132 then
				bush(lobby, pos, random:NextNumber(0.9, 1.3))
				flowers(lobby, pos + Vector3.new(3, 0, 0), 3, 8)
			end
		end
		tBall(center + Vector3.new(radius * 0.6, -2.5, -radius * 0.4), 4.5, M.Rock)
	end
	-- Rocas en la orilla
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2 + random:NextNumber(-0.1, 0.1)
		local r = random:NextNumber(138, 150)
		tBall(Vector3.new(math.cos(angle) * r, random:NextNumber(-4, -1), math.sin(angle) * r), random:NextNumber(3, 6.5), M.Rock)
	end
end

local function buildLobby(root: Instance)
	local lobby = folder("Ciudad", root)
	buildIsland()
	buildPlaza(lobby)
	buildPortalTerrace(lobby)
	buildForge(lobby)
	buildMarket(lobby)
	buildLeaderboard(lobby)
	buildPond(lobby)
	buildTraining(lobby)
	buildCamp(lobby)
	buildVillage(lobby)
	buildCastle(lobby)
	buildGroves(lobby)
	boundary(lobby, Vector3.new(0, 0, 0), 290, 290)
end

---------------------------------------------------------------------
-- Arenas de partida
---------------------------------------------------------------------
type Theme = { floor: Enum.Material, patches: { Enum.Material }, accent: Color3 }
local THEMES: { [string]: Theme } = {
	bosque = { floor = M.Grass, patches = { M.LeafyGrass, M.Ground, M.Mud, M.LeafyGrass }, accent = Color3.fromRGB(74, 222, 128) },
	cueva = { floor = M.Slate, patches = { M.Basalt, M.Salt, M.Glacier, M.Basalt }, accent = Color3.fromRGB(56, 189, 248) },
	castillo = { floor = M.Cobblestone, patches = { M.Pavement, M.Mud, M.Slate, M.Pavement }, accent = Color3.fromRGB(168, 85, 247) },
}

-- Punto en el anillo exterior: "distance" se mide desde el centro hacia el borde cuadrado
local function ringSpot(origin: Vector3, minDistance: number, maxDistance: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local d = random:NextNumber(minDistance, maxDistance)
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local scale = 1 / math.max(math.abs(dir.X), math.abs(dir.Z))
	return origin + dir * d * scale
end

local function fieldSpot(origin: Vector3, margin: number): Vector3
	local half = Config.ARENA_HALF - margin
	return origin + Vector3.new(random:NextNumber(-half, half), 0, random:NextNumber(-half, half))
end

local function decorateBosque(arena: Instance, origin: Vector3)
	local half = Config.ARENA_HALF
	-- Colinas alrededor con árboles encima
	for _ = 1, 34 do
		local radius = random:NextNumber(26, 42)
		local spot = ringSpot(origin, half + radius * 0.85 + 4, half + radius * 0.85 + 30)
		tBall(spot + Vector3.new(0, -radius * 0.55, 0), radius, M.Grass)
		tBall(spot + Vector3.new(0, -radius * 0.75, 0), radius * 0.75, M.Rock)
	end
	-- Caminos de tierra que cruzan el claro
	tTrail(origin + Vector3.new(-half - 10, 0, -40), origin + Vector3.new(half + 10, 0, 30), 9, M.Ground)
	tTrail(origin + Vector3.new(20, 0, -half - 10), origin + Vector3.new(-30, 0, half + 10), 7, M.Ground)
	for _ = 1, 70 do
		local spot = ringSpot(origin, half + 6, half + 48)
		local lift = math.clamp((spot - origin).Magnitude - half * 1.15, 0, 40) * 0.2
		if random:NextNumber() < 0.55 then
			oak(arena, spot + Vector3.new(0, lift, 0), random:NextNumber(1.2, 1.9))
		else
			pine(arena, spot + Vector3.new(0, lift, 0), random:NextNumber(1.3, 2))
		end
	end
	-- Detalles en el claro (no estorban)
	for _ = 1, 12 do
		flowers(arena, fieldSpot(origin, 10), random:NextNumber(2, 4), 8)
	end
	for _ = 1, 14 do
		local spot = fieldSpot(origin, 12)
		for k = 1, 3 do
			local stem = decor(column(arena, 1.2, 0.45, spot + Vector3.new(k * 1.2, 0.6, (k % 2) * 1.1), Color3.fromRGB(245, 240, 230), M.SmoothPlastic))
			stem.Name = "Seta"
			decor(ball(arena, 1.5, spot + Vector3.new(k * 1.2, 1.3, (k % 2) * 1.1), Color3.fromRGB(220, 38, 38), M.SmoothPlastic))
		end
	end
	for _ = 1, 8 do
		local spot = fieldSpot(origin, 20)
		local log = decor(column(arena, random:NextNumber(6, 10), 1.6, spot, WOOD, M.Wood))
		log.CFrame = CFrame.new(spot + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0)
		log.Name = "Tronco"
	end
	-- Campamento de leñadores: cabañas en el borde del claro, mirando al centro
	for k = 0, 3 do
		local angle = k / 4 * math.pi * 2 + 0.6
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local scale = 1 / math.max(math.abs(dir.X), math.abs(dir.Z))
		local pos = origin + dir * (half + 12) * scale
		local facing = math.atan2(-dir.X, -dir.Z)
		tRound(pos, 11, M.Ground)
		cottage(arena, CFrame.new(pos) * CFrame.Angles(0, facing, 0), 12, 9, "CabañaLeñador")
		-- Leña apilada y un tocón con hacha
		local side = CFrame.new(pos) * CFrame.Angles(0, facing, 0) * CFrame.new(9, 0, 3)
		for row = 0, 2 do
			for j = 0, 2 - row do
				decor(column(arena, 4, 1.2, (side * CFrame.new(0, 0.6 + row * 1.05, (j - (2 - row) / 2) * 1.2)).Position, WOOD, M.Wood)).CFrame = side * CFrame.new(0, 0.6 + row * 1.05, (j - (2 - row) / 2) * 1.2)
			end
		end
		local stump = (CFrame.new(pos) * CFrame.Angles(0, facing, 0) * CFrame.new(-9, 0, 4)).Position
		decor(column(arena, 1.4, 2.4, stump + Vector3.new(0, 0.7, 0), WOOD, M.Wood)).Name = "Tocón"
		decor(newPart(arena, Vector3.new(0.3, 2.6, 0.3), CFrame.new(stump + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(20)), DARK_WOOD, M.Wood))
		decor(newPart(arena, Vector3.new(0.2, 0.9, 1.1), CFrame.new(stump + Vector3.new(-0.3, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(200, 205, 215), M.Metal))
	end
	-- Ruinas de una torre vieja en una esquina (fuera del paso)
	local ruin = origin + Vector3.new(-1, 0, -1) * (half + 8)
	for k = 0, 5 do
		local angle = k / 6 * math.pi * 2
		local h = random:NextNumber(4, 13)
		column(arena, h, 3, ruin + Vector3.new(math.cos(angle) * 7, h / 2, math.sin(angle) * 7), Color3.fromRGB(170, 164, 150), M.Limestone).Name = "Columna"
	end
end

local function decorateCueva(arena: Instance, origin: Vector3)
	local half = Config.ARENA_HALF
	-- Acantilados altos de roca alrededor
	for _ = 1, 40 do
		local radius = random:NextNumber(24, 40)
		local spot = ringSpot(origin, half + radius + 3, half + radius + 22)
		tBall(spot + Vector3.new(0, random:NextNumber(-4, 10), 0), radius, if random:NextNumber() < 0.65 then M.Rock else M.Basalt)
	end
	-- Paredes de fondo altas (apoyadas en el suelo)
	for _ = 1, 24 do
		local radius = random:NextNumber(30, 44)
		local spot = ringSpot(origin, half + radius + 18, half + radius + 34)
		tBall(spot + Vector3.new(0, radius * 0.6, 0), radius, M.Slate)
		tBall(spot + Vector3.new(0, radius * 1.3, 0), radius * 0.55, M.Rock)
	end
	-- Vetas de hielo brillante en el suelo
	for _ = 1, 4 do
		tTrail(fieldSpot(origin, 20), fieldSpot(origin, 20), 4, M.Glacier)
	end
	-- Cristales gigantes en el borde
	local colors = { Color3.fromRGB(56, 189, 248), Color3.fromRGB(167, 139, 250), Color3.fromRGB(45, 212, 191), Color3.fromRGB(244, 114, 182) }
	for _ = 1, 22 do
		crystalCluster(arena, ringSpot(origin, half + 2, half + 16), random:NextNumber(1.3, 2.4), pick(colors))
	end
	-- Cristalitos en el suelo (no estorban)
	for _ = 1, 30 do
		local c = crystal(arena, fieldSpot(origin, 8), random:NextNumber(1.6, 3), pick(colors), false)
		c.Transparency = 0.2
	end
	-- Estalagmitas junto al borde
	for _ = 1, 18 do
		local spot = ringSpot(origin, half - 6, half - 1)
		for k, d in { 4, 3, 2 } do
			decor(column(arena, 3, d, spot + Vector3.new(0, k * 2.6 - 1, 0), Color3.fromRGB(88, 96, 112), M.Rock))
		end
	end
	-- Charcos de luz
	for _ = 1, 5 do
		local pool = decor(column(arena, 0.15, random:NextNumber(8, 14), fieldSpot(origin, 30) + Vector3.new(0, 0.08, 0), Color3.fromRGB(56, 189, 248), M.Neon))
		pool.Transparency = 0.7
		pool.Name = "Charco"
	end
	-- Mina: entibados de madera con farolillos en el borde
	for k = 0, 15 do
		local t = k / 16
		local angle = t * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local scale = 1 / math.max(math.abs(dir.X), math.abs(dir.Z))
		local pos = origin + dir * (half + 3) * scale
		local frame = CFrame.new(pos) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
		for _, x in { -4, 4 } do
			decor(newPart(arena, Vector3.new(1.4, 12, 1.4), frame * CFrame.new(x, 6, 0), WOOD, M.Wood)).Name = "Entibado"
		end
		decor(newPart(arena, Vector3.new(10.4, 1.4, 1.6), frame * CFrame.new(0, 12.4, 0), DARK_WOOD, M.Wood))
		local lantern = decor(newPart(arena, Vector3.new(0.9, 1.3, 0.9), frame * CFrame.new(0, 10.8, -0.6), WINDOW_GLOW, M.Neon))
		lantern.Name = "Farolillo"
		if k % 2 == 0 then
			pointLight(lantern, WARM_LIGHT, 18, 1.1)
		end
	end
	-- Vías de vagoneta que cruzan la cueva (de adorno, no estorban)
	for _, line in { { Vector3.new(-1, 0, -0.35), Vector3.new(1, 0, 0.2) }, { Vector3.new(-0.3, 0, 1), Vector3.new(0.25, 0, -1) } } do
		local a = origin + line[1] * (half + 2)
		local b = origin + line[2] * (half + 2)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local frame = CFrame.lookAt(mid, b)
		for _, x in { -1.3, 1.3 } do
			decor(newPart(arena, Vector3.new(0.3, 0.3, length), frame * CFrame.new(x, 0.35, 0), Color3.fromRGB(110, 110, 118), M.Metal)).Name = "Raíl"
		end
		for k = 0, math.floor(length / 3) do
			decor(newPart(arena, Vector3.new(4, 0.2, 0.8), frame * CFrame.new(0, 0.12, -length / 2 + k * 3), DARK_WOOD, M.Wood)).Name = "Traviesa"
		end
		-- Vagonetas con mineral brillante en los extremos
		for _, endZ in { -length / 2 + 6, length / 2 - 6 } do
			local cart = frame * CFrame.new(0, 0, endZ)
			decor(newPart(arena, Vector3.new(3.6, 2.4, 4.6), cart * CFrame.new(0, 1.9, 0), Color3.fromRGB(90, 70, 50), M.WoodPlanks)).Name = "Vagoneta"
			for _, x in { -1.9, 1.9 } do
				for _, z in { -1.5, 1.5 } do
					decor(column(arena, 0.3, 1.2, (cart * CFrame.new(x, 0.6, z)).Position, Color3.fromRGB(50, 50, 56), M.Metal)).CFrame = cart * CFrame.new(x, 0.6, z)
				end
			end
			local oreColors = { Color3.fromRGB(56, 189, 248), Color3.fromRGB(167, 139, 250), Color3.fromRGB(251, 191, 36) }
			for j = 1, 4 do
				decor(newPart(arena, Vector3.new(1, 1, 1), cart * CFrame.new(random:NextNumber(-1, 1), 3.3, random:NextNumber(-1.5, 1.5)) * CFrame.Angles(0.6, j, 0.3), pick(oreColors), M.Neon)).Name = "Mineral"
			end
		end
	end
end

local function decorateCastillo(arena: Instance, origin: Vector3)
	local half = Config.ARENA_HALF
	local brick = Color3.fromRGB(70, 62, 66)
	local roof = Color3.fromRGB(70, 40, 92)
	-- Colinas oscuras y bosque muerto fuera de las murallas
	for _ = 1, 28 do
		local radius = random:NextNumber(24, 40)
		local spot = ringSpot(origin, half + radius * 0.9 + 12, half + radius * 0.9 + 34)
		tBall(spot + Vector3.new(0, -radius * 0.5, 0), radius, M.Rock)
	end
	-- Patio: plaza central y caminos en cruz
	tRound(origin, 30, M.Pavement)
	tRound(origin, 22, M.Slate)
	tPatch(origin, 14, half * 2, 0, M.Pavement)
	tPatch(origin, half * 2, 14, 0, M.Pavement)
	for _ = 1, 30 do
		deadTree(arena, ringSpot(origin, half + 16, half + 50), random:NextNumber(1.2, 1.8))
	end
	-- Murallas con almenas, estandartes y braseros
	local wallHeight = 20
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local normal = Vector3.new(side[1], 0, side[2])
		local along = Vector3.new(side[2], 0, side[1])
		local center = origin + normal * (half + 6)
		local size = if side[1] ~= 0 then Vector3.new(6, wallHeight, half * 2 + 24) else Vector3.new(half * 2 + 24, wallHeight, 6)
		newPart(arena, size, CFrame.new(center + Vector3.new(0, wallHeight / 2, 0)), brick, M.Brick).Name = "Muralla"
		for k = -21, 21, 2 do
			newPart(arena, Vector3.new(3, 3, 3), CFrame.new(center + along * (k * 6.5) + Vector3.new(0, wallHeight + 1.5, 0) - normal * 1.5), brick, M.Brick).Name = "Almena"
		end
		for k = -3, 3 do
			local pos = center + along * (k * 36) - normal * 3.4
			local cloth = decor(newPart(arena, Vector3.new(if side[1] ~= 0 then 0.2 else 5, 9, if side[1] ~= 0 then 5 else 0.2), CFrame.new(pos + Vector3.new(0, 12, 0)), Color3.fromRGB(110, 40, 160), M.Fabric))
			cloth.Name = "Estandarte"
			brazier(arena, pos - normal * 3 + along * 18, Color3.fromRGB(196, 120, 255))
		end
	end
	-- Torres en las esquinas con tejado cónico y ventana encendida
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local pos = origin + corner * (half + 6)
		column(arena, 34, 20, pos + Vector3.new(0, 17, 0), brick, M.Brick).Name = "Torre"
		for k = 0, 9 do
			local angle = k / 10 * math.pi * 2
			newPart(arena, Vector3.new(2.6, 3, 2.6), CFrame.new(pos + Vector3.new(math.cos(angle) * 9.5, 35.5, math.sin(angle) * 9.5)), brick, M.Brick)
		end
		for k, d in { 22, 17, 12, 7, 3 } do
			column(arena, 3.2, d, pos + Vector3.new(0, 34 + k * 3, 0), roof, M.Slate)
		end
		local window = decor(newPart(arena, Vector3.new(1.6, 3, 1.6), CFrame.new(pos - corner * 9.6 + Vector3.new(0, 24, 0)), Color3.fromRGB(253, 186, 116), M.Neon))
		pointLight(window, WARM_LIGHT, 20, 1.2)
	end
	-- Cementerio y lava agrietada dentro del patio (no estorban)
	for _ = 1, 24 do
		grave(arena, fieldSpot(origin, 14))
	end
	for _ = 1, 6 do
		local from = fieldSpot(origin, 30)
		local angle = random:NextNumber(0, math.pi * 2)
		tTrail(from, from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(20, 34), 3, M.CrackedLava)
	end
end

-- Centro de la arena de un hueco (1..ARENA_SLOTS)
function World.arenaOrigin(slot: number): Vector3
	return Vector3.new(World.ARENA_START + (slot - 1) * World.ARENA_SPACING, 0, 0)
end

-- Mapa que tiene construido un hueco (nil = vacío)
function World.arenaMapOf(slot: number): number?
	return arenaMap[slot]
end

-- Crea la arena de un mapa en un hueco y devuelve su centro.
-- Si ese hueco ya tiene ese mapa, se reutiliza (crear terreno cuesta).
function World.buildArena(slot: number, mapIndex: number): Vector3
	if arenas[slot] and arenaMap[slot] == mapIndex then
		return World.arenaOrigin(slot)
	end
	World.destroyArena(slot)
	local map = Config.Maps[mapIndex]
	local theme = THEMES[map.id]
	local origin = World.arenaOrigin(slot)
	local arena = folder("Arena_" .. slot, mundo)
	-- Suelo llano de terreno (arriba en y = 0), más grande que la zona jugable
	tBlock(CFrame.new(origin + Vector3.new(0, -10, 0)), Vector3.new(480, 20, 480), theme.floor)
	for _ = 1, 22 do
		tBlob(fieldSpot(origin, -10), random:NextNumber(10, 22), pick(theme.patches))
	end
	if map.id == "bosque" then
		decorateBosque(arena, origin)
	elseif map.id == "cueva" then
		decorateCueva(arena, origin)
	else
		decorateCastillo(arena, origin)
	end
	-- Círculo mágico donde empieza la partida
	local ring = decor(column(arena, 0.2, 26, origin + Vector3.new(0, 0.1, 0), theme.accent, M.Neon))
	ring.Name = "Inicio"
	ring.Transparency = 0.55
	local inner = decor(column(arena, 0.22, 20, origin + Vector3.new(0, 0.11, 0), Color3.fromRGB(20, 20, 30), M.Slate))
	inner.Transparency = 0.2
	boundary(arena, origin, Config.ARENA_HALF * 2, Config.ARENA_HALF * 2)
	arenas[slot] = arena
	arenaMap[slot] = mapIndex
	return origin
end

function World.destroyArena(slot: number)
	local arena = arenas[slot]
	if arena then
		arena:Destroy()
		arenas[slot] = nil
		arenaMap[slot] = nil
		local origin = World.arenaOrigin(slot)
		terrain:FillBlock(CFrame.new(origin + Vector3.new(0, 40, 0)), Vector3.new(520, 160, 520), M.Air)
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
function World.build(handlers: { onOpen: (Player, string, string?) -> () })
	callbacks = handlers
	terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(38, 130, 168)
	terrain.WaterReflectance = 0.6
	terrain.WaterTransparency = 0.55
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 9
	pcall(function()
		(terrain :: any).Decoration = true -- hierba animada
	end)
	Ambience.apply("lobby")
	mundo = Workspace:FindFirstChild("Mundo") or folder("Mundo", Workspace)
	buildLobby(mundo)
	-- La arena del primer mapa ya preparada (la primera partida empieza al instante)
	World.buildArena(1, 1)
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
