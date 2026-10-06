--[[
	World (ModuleScript en ServerScriptService)

	Construye "Ciudad Web": iluminación y efectos, suelo, avenida con
	aceras y farolas, árboles, plaza con fuente y zona de aparición,
	arco de bienvenida, panel de clasificación global, horizonte de
	edificios al fondo, el panel del ranking semanal en mitad de la avenida
	y el ciclo de día y noche.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("TycoonConfig"))
local Building = require(script.Parent:WaitForChild("Building"))

local World = {}

World.PLOT_COUNT = 8
World.PLOT_SIZE = 64
World.PLOT_SPACING = 80
local STREET_WIDTH = 28
local SIDEWALK = 8
local AVENUE_START = -200
local AVENUE_END = 190
local PLAZA_CENTER = Vector3.new(-240, 0, 0)
local TAG_LAMP = "ImperioStreetLamp"

local random = Random.new(2024)
local isNight = false
local leaderboardRows: { TextLabel } = {}
local leaderboardStatus: TextLabel? = nil
-- El panel semanal tiene dos caras (una para cada lado de la avenida)
local weeklyRows: { { TextLabel } } = {}
local weeklyStatus: { TextLabel } = {}
local colorEffect: ColorCorrectionEffect? = nil
local NORMAL_TINT = Color3.fromRGB(255, 250, 244)

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

local function verticalCylinder(parent: Instance, height: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = newPart(parent, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function surfaceLabel(part: BasePart, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = part
	return label
end

---------------------------------------------------------------------
-- Iluminación y efectos
---------------------------------------------------------------------
local function getOrCreate(className: string, parent: Instance): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Parent = parent
	return instance
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 72, 84)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 130, 145)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.15

	local sky = getOrCreate("Sky", Lighting)
	sky.StarCount = 3000
	sky.SunAngularSize = 14

	local atmosphere = getOrCreate("Atmosphere", Lighting)
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(199, 214, 235)
	atmosphere.Decay = Color3.fromRGB(110, 118, 135)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.4

	local bloom = getOrCreate("BloomEffect", Lighting)
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 1.4

	local color = getOrCreate("ColorCorrectionEffect", Lighting)
	color.Brightness = 0.02
	color.Contrast = 0.1
	color.Saturation = 0.15
	color.TintColor = NORMAL_TINT
	colorEffect = color

	local rays = getOrCreate("SunRaysEffect", Lighting)
	rays.Intensity = 0.05
	rays.Spread = 0.6
end

---------------------------------------------------------------------
-- Piezas de ciudad
---------------------------------------------------------------------
local function streetLamp(parent: Instance, position: Vector3, facing: number)
	local metal = Color3.fromRGB(38, 42, 50)
	newPart(parent, Vector3.new(1.2, 0.6, 1.2), CFrame.new(position + Vector3.new(0, 0.3, 0)), metal, Enum.Material.Metal)
	newPart(parent, Vector3.new(0.5, 13, 0.5), CFrame.new(position + Vector3.new(0, 6.5, 0)), metal, Enum.Material.Metal)
	newPart(parent, Vector3.new(0.4, 0.4, 3.4), CFrame.new(position + Vector3.new(0, 12.8, facing * 1.5)), metal, Enum.Material.Metal)
	local head = newPart(parent, Vector3.new(1.4, 0.5, 2), CFrame.new(position + Vector3.new(0, 12.5, facing * 3)), Color3.fromRGB(255, 226, 170), Enum.Material.SmoothPlastic)
	head.CastShadow = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 30
	light.Angle = 120
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Enabled = false
	light.Parent = head
	CollectionService:AddTag(head, TAG_LAMP)
end

function World.tree(parent: Instance, position: Vector3, scale: number)
	local trunkHeight = 6 * scale
	verticalCylinder(parent, trunkHeight, 1.2 * scale, position + Vector3.new(0, trunkHeight / 2, 0), Color3.fromRGB(110, 78, 52), Enum.Material.Wood)
	local greens = { Color3.fromRGB(64, 140, 70), Color3.fromRGB(80, 160, 80), Color3.fromRGB(52, 120, 64) }
	local blobs = {
		{ offset = Vector3.new(0, trunkHeight + 2 * scale, 0), size = 7 },
		{ offset = Vector3.new(1.8 * scale, trunkHeight + 0.8 * scale, 1 * scale), size = 5 },
		{ offset = Vector3.new(-1.6 * scale, trunkHeight + 1.2 * scale, -1.2 * scale), size = 5.4 },
	}
	for i, blob in blobs do
		local leaves = newPart(parent, Vector3.one * blob.size * scale, CFrame.new(position + blob.offset), greens[i], Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end
end

local function buildAvenue(city: Folder)
	local length = AVENUE_END - AVENUE_START
	local centerX = (AVENUE_START + AVENUE_END) / 2
	newPart(city, Vector3.new(length, 0.3, STREET_WIDTH), CFrame.new(centerX, 0.15, 0), Color3.fromRGB(48, 50, 56), Enum.Material.Asphalt)
	-- Líneas de la calzada
	for x = AVENUE_START + 8, AVENUE_END - 8, 14 do
		newPart(city, Vector3.new(6, 0.32, 0.6), CFrame.new(x, 0.16, 0), Color3.fromRGB(245, 222, 100), Enum.Material.SmoothPlastic)
	end
	for _, side in { -1, 1 } do
		local z = side * (STREET_WIDTH / 2 + SIDEWALK / 2)
		newPart(city, Vector3.new(length, 0.6, SIDEWALK), CFrame.new(centerX, 0.3, z), Color3.fromRGB(196, 196, 202), Enum.Material.Concrete)
		-- Bordillo
		newPart(city, Vector3.new(length, 0.7, 0.6), CFrame.new(centerX, 0.35, side * (STREET_WIDTH / 2 + 0.3)), Color3.fromRGB(150, 150, 158), Enum.Material.Concrete)
		for x = AVENUE_START + 20, AVENUE_END - 10, 40 do
			streetLamp(city, Vector3.new(x, 0.6, side * (STREET_WIDTH / 2 + 1.6)), -side)
		end
	end
end

local function buildPlaza(city: Folder)
	local c = PLAZA_CENTER
	verticalCylinder(city, 0.6, 96, c + Vector3.new(0, 0.3, 0), Color3.fromRGB(214, 206, 192), Enum.Material.Pavement)
	verticalCylinder(city, 0.62, 70, c + Vector3.new(0, 0.31, 0), Color3.fromRGB(190, 182, 168), Enum.Material.Pavement)

	-- Fuente
	verticalCylinder(city, 2.2, 22, c + Vector3.new(0, 1.1, 0), Color3.fromRGB(220, 220, 225), Enum.Material.Marble)
	local water = verticalCylinder(city, 2.3, 20, c + Vector3.new(0, 1.15, 0), Color3.fromRGB(70, 160, 230), Enum.Material.Glass)
	water.Transparency = 0.25
	water.Reflectance = 0.3
	verticalCylinder(city, 7, 2.4, c + Vector3.new(0, 3.5, 0), Color3.fromRGB(220, 220, 225), Enum.Material.Marble)
	local bowl = verticalCylinder(city, 1, 8, c + Vector3.new(0, 7, 0), Color3.fromRGB(220, 220, 225), Enum.Material.Marble)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0.6, 0, 0) -- eje X local = arriba (cilindro girado)
	attachment.Orientation = Vector3.new(0, 0, -90)
	attachment.Parent = bowl
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 60
	spray.Lifetime = NumberRange.new(0.9, 1.3)
	spray.Speed = NumberRange.new(14, 18)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -40, 0)
	spray.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
	spray.Size = NumberSequence.new(0.6, 0.2)
	spray.Transparency = NumberSequence.new(0.2, 0.8)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = attachment

	-- Zona de aparición
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(c + Vector3.new(28, 0.5, 0))
	spawn.Color = Color3.fromRGB(37, 99, 235)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = city

	-- Bancos y árboles alrededor
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + math.pi / 8
		local pos = c + Vector3.new(math.cos(angle) * 40, 0.6, math.sin(angle) * 40)
		if math.abs(math.sin(angle)) > 0.3 then
			World.tree(city, pos, 1.1)
		end
	end
	for _, z in { -16, 16 } do
		newPart(city, Vector3.new(6, 0.5, 2), CFrame.new(c + Vector3.new(-14, 1.6, z)), Color3.fromRGB(140, 96, 60), Enum.Material.WoodPlanks)
		newPart(city, Vector3.new(0.5, 1.4, 1.6), CFrame.new(c + Vector3.new(-16.5, 0.9, z)), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
		newPart(city, Vector3.new(0.5, 1.4, 1.6), CFrame.new(c + Vector3.new(-11.5, 0.9, z)), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	end
end

local function buildWelcomeArch(city: Folder)
	local x = AVENUE_START + 6
	local half = STREET_WIDTH / 2 + SIDEWALK
	local pillarColor = Color3.fromRGB(30, 41, 59)
	for _, side in { -1, 1 } do
		newPart(city, Vector3.new(3, 22, 3), CFrame.new(x, 11, side * half), pillarColor, Enum.Material.Metal)
	end
	local beam = newPart(city, Vector3.new(3, 5, half * 2 + 3), CFrame.new(x, 24, 0), Color3.fromRGB(37, 99, 235), Enum.Material.SmoothPlastic)
	surfaceLabel(beam, Enum.NormalId.Right, "🌐 CIUDAD WEB 🌐", Color3.new(1, 1, 1))
	surfaceLabel(beam, Enum.NormalId.Left, "💰 ¡HAZTE MILLONARIO! 💰", Color3.new(1, 1, 1))
	local glow = newPart(city, Vector3.new(3.2, 0.5, half * 2 + 3.2), CFrame.new(x, 21.3, 0), Color3.fromRGB(96, 165, 250), Enum.Material.Neon)
	glow.CastShadow = false
end

local function buildLeaderboard(city: Folder)
	local position = PLAZA_CENTER + Vector3.new(-34, 9, 0)
	local frameColor = Color3.fromRGB(30, 41, 59)
	newPart(city, Vector3.new(1.5, 18, 1.5), CFrame.new(position + Vector3.new(0, -4.5, -10)), frameColor, Enum.Material.Metal)
	newPart(city, Vector3.new(1.5, 18, 1.5), CFrame.new(position + Vector3.new(0, -4.5, 10)), frameColor, Enum.Material.Metal)
	-- El panel mira hacia +X (hacia la plaza y la avenida)
	local board = newPart(city, Vector3.new(22, 16, 1), CFrame.lookAt(position, position + Vector3.new(1, 0, 0)), Color3.fromRGB(15, 23, 42), Enum.Material.SmoothPlastic)
	board.Name = "Clasificacion"

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local list = Instance.new("Frame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = list

	local function row(order: number, height: number, text: string, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = color
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = list
		return label
	end

	row(0, 56, "🏆 LOS MÁS RICOS DE CIUDAD WEB", Color3.fromRGB(250, 204, 21)).TextXAlignment = Enum.TextXAlignment.Center
	leaderboardStatus = row(1, 26, "Cargando...", Color3.fromRGB(148, 163, 184))
	for i = 1, 10 do
		local color = if i == 1 then Color3.fromRGB(250, 204, 21)
			elseif i == 2 then Color3.fromRGB(203, 213, 225)
			elseif i == 3 then Color3.fromRGB(251, 146, 60)
			else Color3.fromRGB(226, 232, 240)
		table.insert(leaderboardRows, row(10 + i, 34, "", color))
	end
end

-- rows = { { name = "Ana", value = 12345 }, ... } o un mensaje
function World.setLeaderboard(rows: { { name: string, value: number } }?, message: string?)
	if leaderboardStatus then
		leaderboardStatus.Text = message or "Dinero ganado en total · se actualiza cada 2 min"
	end
	for i, label in leaderboardRows do
		local entry = rows and rows[i]
		label.Text = if entry then string.format("%d. %s — %s", i, entry.name, Config.formatMoney(entry.value)) else ""
	end
end

-- Panel del ranking semanal en mitad de la avenida, con dos caras
local function buildWeeklyBoard(city: Folder)
	local center = Vector3.new(0, 16, 0)
	local frameColor = Color3.fromRGB(30, 41, 59)
	for _, x in { -12.5, 12.5 } do
		newPart(city, Vector3.new(1.4, 23.5, 1.4), CFrame.new(x, 11.75, 0), frameColor, Enum.Material.Metal)
	end
	local board = newPart(city, Vector3.new(24, 15, 1), CFrame.new(center), Color3.fromRGB(15, 23, 42), Enum.Material.SmoothPlastic)
	board.Name = "RankingSemanal"
	local glow = newPart(city, Vector3.new(24.4, 0.5, 1.2), CFrame.new(center + Vector3.new(0, 7.75, 0)), Color3.fromRGB(250, 204, 21), Enum.Material.Neon)
	glow.CastShadow = false

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = board
		local list = Instance.new("Frame")
		list.Size = UDim2.fromScale(1, 1)
		list.BackgroundTransparency = 1
		list.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 3)
		layout.Parent = list
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 12)
		padding.PaddingLeft = UDim.new(0, 24)
		padding.PaddingRight = UDim.new(0, 24)
		padding.Parent = list
		local function row(order: number, height: number, text: string, color: Color3): TextLabel
			local label = Instance.new("TextLabel")
			label.LayoutOrder = order
			label.Size = UDim2.new(1, 0, 0, height)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextScaled = true
			label.Font = Enum.Font.FredokaOne
			label.TextColor3 = color
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = list
			return label
		end
		row(0, 52, "🏆 TOP SEMANAL", Color3.fromRGB(250, 204, 21)).TextXAlignment = Enum.TextXAlignment.Center
		table.insert(weeklyStatus, row(1, 24, "Cargando...", Color3.fromRGB(148, 163, 184)))
		local rows = {}
		for i = 1, 10 do
			local color = if i == 1 then Color3.fromRGB(250, 204, 21)
				elseif i == 2 then Color3.fromRGB(203, 213, 225)
				elseif i == 3 then Color3.fromRGB(251, 146, 60)
				else Color3.fromRGB(226, 232, 240)
			table.insert(rows, row(10 + i, 33, "", color))
		end
		table.insert(weeklyRows, rows)
	end
end

function World.setWeeklyBoard(rows: { { name: string, value: number } }?, message: string?)
	for _, status in weeklyStatus do
		status.Text = message or "Dinero ganado esta semana · premios para el top 100"
	end
	for _, list in weeklyRows do
		for i, label in list do
			local entry = rows and rows[i]
			label.Text = if entry then string.format("%d. %s — %s", i, entry.name, Config.formatMoney(entry.value)) else ""
		end
	end
end

local function buildSkyline(city: Folder)
	local colors = { Color3.fromRGB(70, 82, 104), Color3.fromRGB(84, 96, 120), Color3.fromRGB(60, 70, 90) }
	for i = 1, 44 do
		local angle = i / 44 * math.pi * 2
		local radius = random:NextNumber(330, 400)
		local width = random:NextNumber(26, 46)
		local height = random:NextNumber(50, 190)
		local position = Vector3.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
		local tower = newPart(city, Vector3.new(width, height, width), CFrame.new(position) * CFrame.Angles(0, angle, 0), colors[i % #colors + 1], Enum.Material.Glass)
		tower.Reflectance = 0.15
		tower.CastShadow = false
	end
end

local function scatterTrees(city: Folder)
	for _ = 1, 70 do
		local x = random:NextNumber(-300, 280)
		local z = random:NextNumber(110, 280) * (if random:NextNumber() < 0.5 then -1 else 1)
		World.tree(city, Vector3.new(x, 0, z), random:NextNumber(0.9, 1.6))
	end
end

---------------------------------------------------------------------
-- Día y noche
---------------------------------------------------------------------
local function applyNight(night: boolean)
	isNight = night
	for _, head in CollectionService:GetTagged(TAG_LAMP) do
		if head:IsA("BasePart") then
			head.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local light = head:FindFirstChildOfClass("SpotLight")
			if light then
				light.Enabled = night
			end
		end
	end
	for _, core in CollectionService:GetTagged(Building.TAG_WINDOW) do
		if core:IsA("BasePart") then
			Building.applyWindowLight(core, night)
		end
	end
end

-- Tiñe el cielo durante un evento del servidor (nil = color normal)
function World.setEventTint(tint: Color3?)
	if colorEffect then
		colorEffect.TintColor = tint or NORMAL_TINT
	end
end

function World.isNight(): boolean
	return isNight
end

local function startDayNight()
	task.spawn(function()
		local blink = false
		while true do
			task.wait(0.5)
			local hours = Lighting.ClockTime
			local night = hours < 6.2 or hours >= 18
			-- La noche pasa el doble de rápido para que no se haga pesada
			local rate = 24 / (Config.DAY_LENGTH_MINUTES * 60) * 0.5
			Lighting.ClockTime = (hours + rate * (if night then 2 else 1)) % 24
			if night ~= isNight then
				applyNight(night)
			end
			-- Balizas de los rascacielos parpadeando
			blink = not blink
			for _, ball in CollectionService:GetTagged(Building.TAG_BEACON) do
				if ball:IsA("BasePart") then
					ball.Transparency = if blink then 0 else 0.7
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- Construcción de la ciudad. Devuelve el origen de cada parcela
-- (CFrame en el centro, con el lado -Z mirando a la avenida).
---------------------------------------------------------------------
function World.build(): { CFrame }
	setupLighting()

	local city = Instance.new("Folder")
	city.Name = "CiudadWeb"

	if not Workspace:FindFirstChild("Baseplate") then
		local ground = newPart(city, Vector3.new(900, 2, 900), CFrame.new(0, -1, 0), Color3.fromRGB(96, 158, 88), Enum.Material.Grass)
		ground.Name = "Suelo"
	end

	buildAvenue(city)
	buildPlaza(city)
	buildWelcomeArch(city)
	buildLeaderboard(city)
	buildWeeklyBoard(city)
	buildSkyline(city)
	scatterTrees(city)
	World.setLeaderboard(nil, "Cargando...")
	World.setWeeklyBoard(nil, "Cargando...")

	local origins = {}
	local half = World.PLOT_COUNT // 2
	for i = 1, World.PLOT_COUNT do
		local column = (i - 1) % half
		local side = if i <= half then 1 else -1
		local x = (column - (half - 1) / 2) * World.PLOT_SPACING
		local z = side * (STREET_WIDTH / 2 + SIDEWALK + World.PLOT_SIZE / 2)
		table.insert(origins, CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0)))
	end

	city.Parent = Workspace
	startDayNight()
	return origins
end

return World
