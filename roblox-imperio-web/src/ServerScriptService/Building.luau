--[[
	Building (ModuleScript en ServerScriptService)

	Genera el rascacielos de un jugador a partir de su número de plantas:
	  · vestíbulo con entrada, marquesina y letrero con el nombre
	  · plantas con forjado, ventanal de cristal e interior (que se ilumina
	    de noche)
	  · retranqueos: a partir de 16 y 28 plantas la torre se estrecha
	  · montantes y pilares continuos (pocas piezas = buen rendimiento)
	  · azotea que evoluciona: máquinas → depósito → helipuerto → corona
	    con aguja y baliza
	Las plantas nuevas aparecen con una animación.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Building = {}

local LOBBY_H = 9
local FLOOR_H = 5
local SLAB_H = 0.8
local BASE_WIDTH = 26

Building.TAG_WINDOW = "ImperioWindowCore"
Building.TAG_BEACON = "ImperioBeacon"

-- Estilos de cristal / acento (uno por parcela)
Building.Styles = {
	{ glass = Color3.fromRGB(96, 156, 214), accent = Color3.fromRGB(37, 99, 235), frame = Color3.fromRGB(44, 52, 66) },
	{ glass = Color3.fromRGB(88, 190, 180), accent = Color3.fromRGB(13, 148, 136), frame = Color3.fromRGB(40, 56, 60) },
	{ glass = Color3.fromRGB(196, 150, 92), accent = Color3.fromRGB(180, 83, 9), frame = Color3.fromRGB(58, 46, 40) },
	{ glass = Color3.fromRGB(150, 128, 214), accent = Color3.fromRGB(124, 58, 237), frame = Color3.fromRGB(48, 42, 66) },
	{ glass = Color3.fromRGB(110, 190, 120), accent = Color3.fromRGB(22, 163, 74), frame = Color3.fromRGB(40, 58, 46) },
	{ glass = Color3.fromRGB(214, 110, 130), accent = Color3.fromRGB(225, 29, 72), frame = Color3.fromRGB(62, 40, 48) },
	{ glass = Color3.fromRGB(120, 140, 160), accent = Color3.fromRGB(71, 85, 105), frame = Color3.fromRGB(30, 34, 40) },
	{ glass = Color3.fromRGB(210, 190, 110), accent = Color3.fromRGB(202, 138, 4), frame = Color3.fromRGB(56, 50, 36) },
}

local SLAB_COLOR = Color3.fromRGB(232, 232, 236)
local INTERIOR_DAY = Color3.fromRGB(58, 66, 80)
local INTERIOR_NIGHT = Color3.fromRGB(255, 214, 150)

type Section = { from: number, to: number, width: number }

local function sectionsFor(floors: number): { Section }
	local list: { Section } = {}
	local function add(from: number, to: number, width: number)
		if to >= from then
			table.insert(list, { from = from, to = to, width = width })
		end
	end
	if floors >= 28 then
		add(1, 12, BASE_WIDTH)
		add(13, 24, BASE_WIDTH - 5)
		add(25, floors, BASE_WIDTH - 10)
	elseif floors >= 16 then
		add(1, 12, BASE_WIDTH)
		add(13, floors, BASE_WIDTH - 5)
	else
		add(1, floors, BASE_WIDTH)
	end
	return list
end

local function widthAt(sections: { Section }, floor: number): number
	for _, section in sections do
		if floor >= section.from and floor <= section.to then
			return section.width
		end
	end
	return BASE_WIDTH
end

local function floorBottom(floor: number): number
	return LOBBY_H + (floor - 1) * FLOOR_H
end

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

local function verticalCylinder(parent: Instance, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	-- Los cilindros de Roblox van a lo largo del eje X: los giramos 90°
	local part = newPart(parent, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, background: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 400

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = label

	gui.Parent = part
	return label
end

-- Aplica el aspecto de día o de noche a un interior de ventana
function Building.applyWindowLight(core: BasePart, isNight: boolean)
	if isNight and core:GetAttribute("Lit") then
		core.Material = Enum.Material.Neon
		core.Color = INTERIOR_NIGHT
	else
		core.Material = Enum.Material.SmoothPlastic
		core.Color = INTERIOR_DAY
	end
end

local function buildLobby(model: Model, base: CFrame, style)
	local w = BASE_WIDTH
	local half = w / 2
	-- Podio de piedra alrededor
	newPart(model, Vector3.new(w + 8, 0.6, w + 8), base * CFrame.new(0, 0.3, 0), Color3.fromRGB(205, 200, 190), Enum.Material.Slate)
	-- Escalones de entrada
	newPart(model, Vector3.new(12, 0.3, 3), base * CFrame.new(0, 0.15, -half - 5), Color3.fromRGB(205, 200, 190), Enum.Material.Slate)

	-- Vestíbulo de cristal
	local glass = newPart(model, Vector3.new(w - 0.4, LOBBY_H - 0.6, w - 0.4), base * CFrame.new(0, 0.6 + (LOBBY_H - 0.6) / 2, 0), style.glass, Enum.Material.Glass)
	glass.Transparency = 0.35
	glass.Reflectance = 0.15
	local lobbyCore = newPart(model, Vector3.new(w - 3, LOBBY_H - 1.6, w - 3), base * CFrame.new(0, 0.6 + (LOBBY_H - 1.6) / 2, 0), Color3.fromRGB(240, 236, 228), Enum.Material.SmoothPlastic)
	lobbyCore.CastShadow = false

	-- Puertas
	newPart(model, Vector3.new(7, 6, 0.4), base * CFrame.new(0, 3.6, -half + 0.1), Color3.fromRGB(25, 28, 34), Enum.Material.Glass).Reflectance = 0.3
	newPart(model, Vector3.new(0.4, 6, 0.6), base * CFrame.new(0, 3.6, -half), style.frame, Enum.Material.Metal)

	-- Marquesina con letrero
	local canopy = newPart(model, Vector3.new(14, 0.6, 6), base * CFrame.new(0, LOBBY_H - 2.2, -half - 3), style.accent, Enum.Material.SmoothPlastic)
	canopy.CastShadow = true
	for _, x in { -6, 6 } do
		newPart(model, Vector3.new(0.4, LOBBY_H - 2.5, 0.4), base * CFrame.new(x, (LOBBY_H - 2.5) / 2, -half - 5.6), style.frame, Enum.Material.Metal)
	end
	-- Luz bajo la marquesina
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 16
	light.Brightness = 1.5
	light.Angle = 100
	light.Color = Color3.fromRGB(255, 225, 180)
	light.Parent = canopy
end

local function buildFloors(model: Model, base: CFrame, sections: { Section }, floors: number, style, isNight: boolean, animateFrom: number)
	local animated: { { part: BasePart, cframe: CFrame, transparency: number } } = {}

	for floor = 1, floors do
		local w = widthAt(sections, floor)
		local y = floorBottom(floor)
		local floorModel = Instance.new("Model")
		floorModel.Name = "Planta" .. floor

		local slab = newPart(floorModel, Vector3.new(w + 0.8, SLAB_H, w + 0.8), base * CFrame.new(0, y + SLAB_H / 2, 0), SLAB_COLOR, Enum.Material.SmoothPlastic)
		local bandH = FLOOR_H - SLAB_H
		local glass = newPart(floorModel, Vector3.new(w, bandH, w), base * CFrame.new(0, y + SLAB_H + bandH / 2, 0), style.glass, Enum.Material.Glass)
		glass.Transparency = 0.2
		glass.Reflectance = 0.2
		local core = newPart(floorModel, Vector3.new(w - 1.6, bandH - 0.5, w - 1.6), base * CFrame.new(0, y + SLAB_H + bandH / 2, 0), INTERIOR_DAY, Enum.Material.SmoothPlastic)
		core.CastShadow = false
		-- ~70 % de las plantas tienen la luz encendida por la noche
		core:SetAttribute("Lit", ((floor * 7919) % 10) < 7)
		CollectionService:AddTag(core, Building.TAG_WINDOW)
		Building.applyWindowLight(core, isNight)

		floorModel.Parent = model

		if floor > animateFrom then
			for _, part in { slab, glass, core } do
				table.insert(animated, { part = part, cframe = part.CFrame, transparency = part.Transparency })
			end
		end
	end

	-- Montantes verticales y pilares de esquina, uno por tramo
	for _, section in sections do
		local w = section.width
		local half = w / 2
		local bottom = floorBottom(section.from)
		local top = floorBottom(section.to + 1)
		local height = top - bottom
		local mid = bottom + height / 2
		local count = 5
		for i = 1, count do
			local offset = -half + i * (w / (count + 1))
			newPart(model, Vector3.new(0.45, height, 0.45), base * CFrame.new(offset, mid, -half - 0.12), style.frame, Enum.Material.Metal)
			newPart(model, Vector3.new(0.45, height, 0.45), base * CFrame.new(offset, mid, half + 0.12), style.frame, Enum.Material.Metal)
			newPart(model, Vector3.new(0.45, height, 0.45), base * CFrame.new(-half - 0.12, mid, offset), style.frame, Enum.Material.Metal)
			newPart(model, Vector3.new(0.45, height, 0.45), base * CFrame.new(half + 0.12, mid, offset), style.frame, Enum.Material.Metal)
		end
		for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
			newPart(model, Vector3.new(1.4, height, 1.4), base * CFrame.new(corner.X * half, mid, corner.Y * half), SLAB_COLOR, Enum.Material.SmoothPlastic)
		end
	end

	return animated
end

local function beacon(parent: Instance, cframe: CFrame, color: Color3)
	local ball = newPart(parent, Vector3.new(1.4, 1.4, 1.4), cframe, color, Enum.Material.Neon)
	ball.Shape = Enum.PartType.Ball
	ball.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 2
	light.Parent = ball
	CollectionService:AddTag(ball, Building.TAG_BEACON)
end

local function buildRoof(model: Model, base: CFrame, sections: { Section }, floors: number, style, ownerName: string): BasePart
	local w = widthAt(sections, floors)
	local roofY = floorBottom(floors + 1)
	local roof = newPart(model, Vector3.new(w + 1.2, 1, w + 1.2), base * CFrame.new(0, roofY + 0.5, 0), SLAB_COLOR, Enum.Material.SmoothPlastic)
	roof.Name = "Azotea"
	local top = base * CFrame.new(0, roofY + 1, 0)
	local machine = Color3.fromRGB(150, 155, 165)

	if floors < 6 then
		-- Máquinas de aire acondicionado
		newPart(model, Vector3.new(4, 2, 3), top * CFrame.new(-5, 1, 4), machine, Enum.Material.DiamondPlate)
		newPart(model, Vector3.new(4, 2, 3), top * CFrame.new(5, 1, 4), machine, Enum.Material.DiamondPlate)
		newPart(model, Vector3.new(0.3, 5, 0.3), top * CFrame.new(8, 2.5, -6), style.frame, Enum.Material.Metal)
	elseif floors < 16 then
		-- Depósito de agua y máquinas
		for _, p in { Vector2.new(-2, -2), Vector2.new(2, -2), Vector2.new(-2, 2), Vector2.new(2, 2) } do
			newPart(model, Vector3.new(0.4, 3, 0.4), top * CFrame.new(-4 + p.X, 1.5, 3 + p.Y), style.frame, Enum.Material.Metal)
		end
		verticalCylinder(model, 5, 6, top * CFrame.new(-4, 5.5, 3), Color3.fromRGB(150, 110, 80), Enum.Material.WoodPlanks)
		newPart(model, Vector3.new(5, 2, 4), top * CFrame.new(5, 1, -3), machine, Enum.Material.DiamondPlate)
	elseif floors < 28 then
		-- Helipuerto y antena con baliza
		local pad = verticalCylinder(model, 0.4, w - 4, top * CFrame.new(0, 0.2, 0), Color3.fromRGB(55, 58, 66), Enum.Material.Concrete)
		local mark = newPart(model, Vector3.new(7, 0.05, 7), top * CFrame.new(0, 0.43, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		mark.Transparency = 1
		surfaceText(mark, Enum.NormalId.Top, "H", Color3.fromRGB(250, 204, 21))
		pad.CastShadow = false
		newPart(model, Vector3.new(0.6, 12, 0.6), top * CFrame.new(w / 2 - 2, 6, w / 2 - 2), style.frame, Enum.Material.Metal)
		beacon(model, top * CFrame.new(w / 2 - 2, 12.4, w / 2 - 2), Color3.fromRGB(255, 40, 40))
	else
		-- Corona escalonada con aguja y baliza
		local crownColor = style.glass
		local tiers = { { size = w - 3, height = 4 }, { size = w - 7, height = 4 }, { size = w - 11, height = 4 } }
		local y = 0
		for _, tier in tiers do
			local part = newPart(model, Vector3.new(tier.size, tier.height, tier.size), top * CFrame.new(0, y + tier.height / 2, 0), crownColor, Enum.Material.Glass)
			part.Reflectance = 0.25
			newPart(model, Vector3.new(tier.size + 0.6, 0.5, tier.size + 0.6), top * CFrame.new(0, y + tier.height, 0), style.accent, Enum.Material.Neon).CastShadow = false
			y += tier.height
		end
		verticalCylinder(model, 26, 1, top * CFrame.new(0, y + 13, 0), Color3.fromRGB(220, 222, 228), Enum.Material.Metal)
		beacon(model, top * CFrame.new(0, y + 26.5, 0), Color3.fromRGB(255, 255, 255))
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Top
		spot.Range = 60
		spot.Angle = 30
		spot.Brightness = 3
		spot.Color = style.glass
		spot.Parent = roof
	end

	-- Logotipo en lo alto de la fachada principal
	local logoY = floorBottom(floors + 1) - 1.6
	if floors >= 3 then
		local logo = newPart(model, Vector3.new(math.min(w - 2, 18), 2.6, 0.4), base * CFrame.new(0, logoY, -w / 2 - 0.5), style.accent, Enum.Material.SmoothPlastic)
		surfaceText(logo, Enum.NormalId.Front, string.upper(ownerName) .. " CORP.", Color3.new(1, 1, 1))
	end
	return roof
end

-- Construye el edificio entero. Las plantas por encima de animateFrom
-- aparecen con animación (para cuando el edificio crece).
function Building.build(parent: Instance, base: CFrame, floors: number, styleIndex: number, ownerName: string, isNight: boolean, animateFrom: number): Model
	local style = Building.Styles[(styleIndex - 1) % #Building.Styles + 1]
	local sections = sectionsFor(floors)

	local model = Instance.new("Model")
	model.Name = "Rascacielos"

	buildLobby(model, base, style)
	local animated = buildFloors(model, base, sections, floors, style, isNight, animateFrom)
	local roof = buildRoof(model, base, sections, floors, style, ownerName)

	-- Rótulo flotante con nombre y plantas
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(360, 56)
	billboard.StudsOffset = Vector3.new(0, if floors >= 28 then 34 else 10, 0)
	billboard.MaxDistance = 350
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🏢 " .. ownerName .. " Corp. · " .. floors .. (if floors == 1 then " planta" else " plantas")
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = roof

	model.Parent = parent

	-- Animación de las plantas nuevas: bajan desde arriba y aparecen
	if #animated > 0 then
		local info = TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for _, item in animated do
			item.part.CFrame = item.cframe + Vector3.new(0, 8, 0)
			item.part.Transparency = 1
			TweenService:Create(item.part, info, { CFrame = item.cframe, Transparency = item.transparency }):Play()
		end
		-- Destellos en la azotea
		local attachment = Instance.new("Attachment")
		attachment.Parent = roof
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Rate = 0
		sparkles.Lifetime = NumberRange.new(1, 1.8)
		sparkles.Speed = NumberRange.new(14, 24)
		sparkles.SpreadAngle = Vector2.new(60, 60)
		sparkles.Acceleration = Vector3.new(0, -25, 0)
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255))
		sparkles.Size = NumberSequence.new(0.8, 0)
		sparkles.LightEmission = 1
		sparkles.Parent = attachment
		task.delay(0.5, function()
			sparkles:Emit(60)
		end)
	end

	return model
end

-- Altura total del edificio (para colocar cosas encima)
function Building.height(floors: number): number
	return floorBottom(floors + 1)
end

return Building
