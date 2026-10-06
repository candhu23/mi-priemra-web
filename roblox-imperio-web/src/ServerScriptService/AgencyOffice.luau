--[[
	AgencyOffice (ModuleScript en ServerScriptService)

	El edificio de la agencia de cada jugador, en su parcela. Fachada de
	cristal para ver a TUS programadores trabajando en su mesa (con el color
	de su rareza, su nombre y el icono de su especialidad).
	  · 1 planta; 2 desde la oficina nivel 4; 3 desde el nivel 8
	  · 8 mesas por planta (las vacías son los puestos libres)
	  · las mejoras de la oficina se ven: ☕ cafetería, 🗣️ sala de
	    reuniones, 🛋️ zona de descanso, 🧪 laboratorio y 🌇 terraza
	El edificio mira hacia -Z (la avenida). base = centro del suelo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))

local AgencyOffice = {}

AgencyOffice.WIDTH = 36
AgencyOffice.DEPTH = 24
AgencyOffice.FLOOR_HEIGHT = 9
AgencyOffice.DESKS_PER_FLOOR = 8

local W, D, FH = AgencyOffice.WIDTH, AgencyOffice.DEPTH, AgencyOffice.FLOOR_HEIGHT
local DESK_X = { -12, -4, 4, 12 }
local DESK_Z = { -5.5, 1.5 } -- delante (junto al cristal) y detrás

local SKIN_TONES = {
	Color3.fromRGB(255, 205, 160), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 134, 96),
	Color3.fromRGB(141, 85, 54), Color3.fromRGB(255, 224, 189),
}
local HAIR = {
	Color3.fromRGB(40, 30, 24), Color3.fromRGB(110, 70, 40), Color3.fromRGB(230, 200, 120),
	Color3.fromRGB(20, 20, 22), Color3.fromRGB(170, 60, 40), Color3.fromRGB(150, 150, 155),
}
local PANTS = Color3.fromRGB(45, 55, 80)
local WOOD = Color3.fromRGB(150, 111, 70)
local DARK = Color3.fromRGB(30, 41, 59)

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

local function ball(parent: Instance, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = newPart(parent, Vector3.one * diameter, cframe, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function text(parent: Instance, value: string, color: Color3, bold: boolean, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = value
	label.TextScaled = true
	label.Font = if bold then Enum.Font.FredokaOne else Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = parent
	return label
end

local function surfaceText(part: BasePart, face: Enum.NormalId, value: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.MaxDistance = 300
	gui.Parent = part
	text(gui, value, color, true, UDim2.fromScale(0.94, 0.8), UDim2.fromScale(0.03, 0.1))
end

-- Planta en maceta
local function plant(parent: Instance, cf: CFrame)
	newPart(parent, Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, 0.7, 0), Color3.fromRGB(190, 120, 80), Enum.Material.Brick)
	ball(parent, 2.4, cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(64, 150, 70), Enum.Material.Grass)
end

---------------------------------------------------------------------
-- Personas
---------------------------------------------------------------------
-- cf = suelo bajo la persona, mirando a -Z. seated: sentada en una silla
local function person(parent: Instance, cf: CFrame, shirt: Color3, seed: number, seated: boolean): Part
	local skin = SKIN_TONES[seed % #SKIN_TONES + 1]
	local hair = HAIR[(seed * 7) % #HAIR + 1]
	local torsoY = if seated then 2.85 else 3.1
	newPart(parent, Vector3.new(1.9, 2, 1), cf * CFrame.new(0, torsoY, 0), shirt)
	local head = ball(parent, 1.3, cf * CFrame.new(0, torsoY + 1.65, 0), skin)
	newPart(parent, Vector3.new(1.35, 0.45, 1.35), cf * CFrame.new(0, torsoY + 2.15, 0.08), hair)
	if seated then
		for _, x in { -0.5, 0.5 } do
			newPart(parent, Vector3.new(0.85, 0.7, 1.6), cf * CFrame.new(x, 1.95, -0.7), PANTS)
			newPart(parent, Vector3.new(0.85, 1.6, 0.7), cf * CFrame.new(x, 0.9, -1.35), PANTS)
		end
		-- Brazos hacia el teclado
		for _, x in { -1.2, 1.2 } do
			newPart(parent, Vector3.new(0.5, 0.5, 1.4), cf * CFrame.new(x, 3.1, -0.7), shirt)
		end
	else
		for _, x in { -0.5, 0.5 } do
			newPart(parent, Vector3.new(0.85, 2.1, 0.85), cf * CFrame.new(x, 1.05, 0), PANTS)
		end
		for _, x in { -1.2, 1.2 } do
			newPart(parent, Vector3.new(0.5, 1.9, 0.5), cf * CFrame.new(x, torsoY - 0.05, 0), shirt)
		end
	end
	return head
end

local function nameTag(head: BasePart, line1: string, line2: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 42)
	billboard.StudsOffset = Vector3.new(0, 1.9, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	text(billboard, line1, Color3.new(1, 1, 1), true, UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0))
	text(billboard, line2, color, true, UDim2.fromScale(1, 0.45), UDim2.fromScale(0, 0.55))
	billboard.Parent = head
end

-- Mesa con ordenador; si hay programador, sentado detrás mirando a la calle
local function desk(parent: Instance, slot: CFrame, programmer, index: number)
	local rarity = programmer and Career.RarityById[programmer.rarity] or nil
	-- Tablero, patas y pantalla (la pantalla mira al programador, +Z)
	newPart(parent, Vector3.new(3.4, 0.3, 1.8), slot * CFrame.new(0, 2.45, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -1.5, 1.5 } do
		newPart(parent, Vector3.new(0.3, 2.3, 1.6), slot * CFrame.new(x, 1.15, 0), WOOD, Enum.Material.WoodPlanks)
	end
	newPart(parent, Vector3.new(2, 1.2, 0.2), slot * CFrame.new(0, 3.3, -0.45), DARK)
	local glow = newPart(parent, Vector3.new(1.8, 1, 0.05), slot * CFrame.new(0, 3.3, -0.33),
		if rarity then rarity.color else Color3.fromRGB(60, 64, 74), if rarity then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	glow.CastShadow = false
	newPart(parent, Vector3.new(1.6, 0.1, 0.6), slot * CFrame.new(0, 2.65, 0.2), Color3.fromRGB(60, 64, 74)) -- teclado
	-- Silla
	local chair = Color3.fromRGB(40, 44, 52)
	newPart(parent, Vector3.new(1.9, 0.3, 1.8), slot * CFrame.new(0, 1.7, 1.7), chair)
	newPart(parent, Vector3.new(1.9, 2, 0.3), slot * CFrame.new(0, 2.85, 2.55), chair)
	newPart(parent, Vector3.new(0.3, 1.55, 0.3), slot * CFrame.new(0, 0.78, 1.7), chair, Enum.Material.Metal)
	if not programmer or not rarity then
		return
	end
	local head = person(parent, slot * CFrame.new(0, 0, 1.7), rarity.color, programmer.id or index, true)
	local role = Career.RoleById[programmer.role or "dev"]
	nameTag(head, (if role then role.emoji .. " " else "") .. programmer.name, rarity.name .. " · Nv " .. (programmer.level or 1), rarity.color)
	-- Legendarios y Míticos: luz, aureola y destellos
	if rarity.order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10
		light.Brightness = 2.5
		light.Parent = head
		local halo = newPart(parent, Vector3.new(0.12, 1.5, 1.5), slot * CFrame.new(0, 6.1, 1.7) * CFrame.Angles(0, 0, math.rad(90)), rarity.color, Enum.Material.Neon)
		halo.Shape = Enum.PartType.Cylinder
		halo.Transparency = 0.2
		halo.CastShadow = false
		local attachment = Instance.new("Attachment")
		attachment.Parent = head
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Rate = 10
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(1, 2.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.3, 0)
		sparkles.LightEmission = 1
		sparkles.Color = ColorSequence.new(rarity.color, Color3.new(1, 1, 1))
		sparkles.Parent = attachment
	end
end

---------------------------------------------------------------------
-- Salas de las mejoras de la oficina (fondo de cada planta)
---------------------------------------------------------------------
local function cafe(parent: Instance, floor: CFrame)
	local base = floor * CFrame.new(-12, 0, 8.5)
	newPart(parent, Vector3.new(7, 2.6, 1.6), base * CFrame.new(0, 1.3, 0), Color3.fromRGB(120, 72, 40), Enum.Material.WoodPlanks)
	newPart(parent, Vector3.new(7.2, 0.2, 1.8), base * CFrame.new(0, 2.7, 0), Color3.fromRGB(230, 230, 230), Enum.Material.Marble)
	newPart(parent, Vector3.new(1.2, 1.6, 1), base * CFrame.new(-2, 3.6, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	newPart(parent, Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(1, 3.05, 0), Color3.fromRGB(255, 255, 255))
	local sign = newPart(parent, Vector3.new(5, 1.6, 0.2), base * CFrame.new(0, 6.2, 2.4) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(120, 72, 40))
	surfaceText(sign, Enum.NormalId.Back, "☕ CAFETERÍA", Color3.fromRGB(255, 236, 200))
	local head = person(parent, base * CFrame.new(1.5, 0, 1.6) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(240, 240, 240), 3, false)
	nameTag(head, "☕ Barista", "", Color3.new(1, 1, 1))
end

local function lounge(parent: Instance, floor: CFrame)
	local base = floor * CFrame.new(12, 0, 8)
	local fabric = Color3.fromRGB(37, 99, 235)
	newPart(parent, Vector3.new(6, 1.2, 2), base * CFrame.new(0, 0.9, 0), fabric, Enum.Material.Fabric)
	newPart(parent, Vector3.new(6, 1.6, 0.6), base * CFrame.new(0, 2, 1), fabric, Enum.Material.Fabric)
	-- Tele en la pared de un lado, con un videojuego
	local tv = newPart(parent, Vector3.new(0.3, 3, 5), floor * CFrame.new(W / 2 - 1.2, 4, 7), Color3.fromRGB(168, 85, 247), Enum.Material.Neon)
	tv.CastShadow = false
	plant(parent, floor * CFrame.new(16, 0, 10.5))
	newPart(parent, Vector3.new(1.6, 3, 1.4), floor * CFrame.new(6.5, 1.5, 9.8), Color3.fromRGB(239, 68, 68)) -- máquina arcade
	newPart(parent, Vector3.new(1.4, 1, 0.1), floor * CFrame.new(6.5, 2.6, 9.05), Color3.fromRGB(56, 189, 248), Enum.Material.Neon).CastShadow = false
end

local function meeting(parent: Instance, floor: CFrame)
	local base = floor * CFrame.new(0, 0, 8)
	newPart(parent, Vector3.new(9, 0.3, 3.4), base * CFrame.new(0, 2.45, 0), Color3.fromRGB(240, 240, 240))
	newPart(parent, Vector3.new(0.6, 2.3, 0.6), base * CFrame.new(0, 1.15, 0), Color3.fromRGB(60, 64, 74), Enum.Material.Metal)
	for _, x in { -3, 0, 3 } do
		for _, z in { -2.4, 2.4 } do
			newPart(parent, Vector3.new(1.5, 0.3, 1.5), base * CFrame.new(x, 1.7, z), Color3.fromRGB(40, 44, 52))
		end
	end
	local board = newPart(parent, Vector3.new(8, 4, 0.2), floor * CFrame.new(0, 4.5, D / 2 - 1), Color3.fromRGB(250, 250, 250))
	surfaceText(board, Enum.NormalId.Front, "📈 OBJETIVOS: ¡+1000 % DE VISITAS!", Color3.fromRGB(37, 99, 235))
end

local function lab(parent: Instance, floor: CFrame)
	for i = 0, 4 do
		local rack = floor * CFrame.new(-12 + i * 6, 0, 9.8)
		newPart(parent, Vector3.new(2.4, 7, 1.6), rack * CFrame.new(0, 3.5, 0), Color3.fromRGB(25, 25, 30), Enum.Material.Metal)
		for k = 1, 4 do
			local led = newPart(parent, Vector3.new(2, 0.15, 0.05), rack * CFrame.new(0, k * 1.4, -0.82),
				if (i + k) % 2 == 0 then Color3.fromRGB(34, 197, 94) else Color3.fromRGB(56, 189, 248), Enum.Material.Neon)
			led.CastShadow = false
		end
	end
end

local function rooftop(parent: Instance, roof: CFrame)
	for _, x in { -10, 8 } do
		newPart(parent, Vector3.new(0.3, 5, 0.3), roof * CFrame.new(x, 2.5, 4), Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
		local umbrella = newPart(parent, Vector3.new(0.4, 6, 6), roof * CFrame.new(x, 5, 4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(239, 68, 68))
		umbrella.Shape = Enum.PartType.Cylinder
		newPart(parent, Vector3.new(2.4, 0.4, 4), roof * CFrame.new(x + 3, 0.9, 4), Color3.fromRGB(245, 245, 245))
	end
	for _, x in { -16, 16 } do
		plant(parent, roof * CFrame.new(x, 0, -8))
		plant(parent, roof * CFrame.new(x, 0, 9))
	end
	-- Guirnalda de luces
	for i = 0, 8 do
		local bulb = ball(parent, 0.5, roof * CFrame.new(-16 + i * 4, 5.2 + math.sin(i) * 0.3, -2), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
		bulb.CastShadow = false
	end
end

---------------------------------------------------------------------
-- Edificio
---------------------------------------------------------------------
local function floorsFor(officeLevel: number): number
	return 1 + (if officeLevel >= 4 then 1 else 0) + (if officeLevel >= 8 then 1 else 0)
end
AgencyOffice.floorsFor = floorsFor

local function shell(model: Model, base: CFrame, floors: number, accent: Color3)
	local wall = Color3.fromRGB(236, 232, 224)
	for f = 0, floors - 1 do
		local floor = base * CFrame.new(0, f * FH, 0)
		newPart(model, Vector3.new(W, 0.6, D), floor * CFrame.new(0, 0.3, 0), Color3.fromRGB(200, 198, 192), Enum.Material.Concrete)
		newPart(model, Vector3.new(W - 1.6, 0.1, D - 1.6), floor * CFrame.new(0, 0.65, 0), Color3.fromRGB(196, 160, 120), Enum.Material.WoodPlanks)
		-- Pared del fondo con una franja del color de la parcela
		newPart(model, Vector3.new(W, FH, 0.8), floor * CFrame.new(0, FH / 2, D / 2 - 0.4), wall, Enum.Material.SmoothPlastic)
		newPart(model, Vector3.new(W - 1.6, 0.8, 0.1), floor * CFrame.new(0, FH - 1.6, D / 2 - 0.85), accent, Enum.Material.Neon).CastShadow = false
		-- Paredes laterales con ventana alargada
		for _, side in { -1, 1 } do
			local x = side * (W / 2 - 0.4)
			newPart(model, Vector3.new(0.8, 3, D), floor * CFrame.new(x, 1.5, 0), wall)
			newPart(model, Vector3.new(0.8, 2, D), floor * CFrame.new(x, FH - 1, 0), wall)
			local window = newPart(model, Vector3.new(0.3, FH - 5, D - 1.6), floor * CFrame.new(x, 3 + (FH - 5) / 2, 0), Color3.fromRGB(170, 210, 235), Enum.Material.Glass)
			window.Transparency = 0.5
		end
		-- Fachada de cristal (en la planta baja, con la puerta en medio)
		local glassColor = Color3.fromRGB(170, 210, 235)
		if f == 0 then
			local panel = (W - 1.6 - 7) / 2
			for _, side in { -1, 1 } do
				local glass = newPart(model, Vector3.new(panel, FH - 0.6, 0.3), floor * CFrame.new(side * (3.5 + panel / 2), 0.6 + (FH - 0.6) / 2, -D / 2 + 0.15), glassColor, Enum.Material.Glass)
				glass.Transparency = 0.72
			end
			newPart(model, Vector3.new(7, FH - 7.2, 0.3), floor * CFrame.new(0, 7.2 + (FH - 7.2) / 2, -D / 2 + 0.15), glassColor, Enum.Material.Glass).Transparency = 0.72
			newPart(model, Vector3.new(7.6, 0.4, 0.6), floor * CFrame.new(0, 7.2, -D / 2 + 0.15), DARK, Enum.Material.Metal)
		else
			local glass = newPart(model, Vector3.new(W - 1.6, FH - 0.6, 0.3), floor * CFrame.new(0, 0.6 + (FH - 0.6) / 2, -D / 2 + 0.15), glassColor, Enum.Material.Glass)
			glass.Transparency = 0.72
		end
		for x = -W / 2 + 0.8, W / 2 - 0.8, 6 do
			if f > 0 or math.abs(x) > 4 then
				newPart(model, Vector3.new(0.35, FH, 0.45), floor * CFrame.new(x, FH / 2, -D / 2 + 0.15), DARK, Enum.Material.Metal)
			end
		end
		-- Luces del techo
		for _, z in { -4, 4 } do
			local lamp = newPart(model, Vector3.new(W - 8, 0.15, 1), floor * CFrame.new(0, FH - 0.1, z), Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
			lamp.CastShadow = false
		end
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 244, 220)
		local bulb = newPart(model, Vector3.new(0.2, 0.2, 0.2), floor * CFrame.new(0, FH - 1, 0), Color3.new(1, 1, 1))
		bulb.Transparency = 1
		bulb.CanCollide = false
		light.Parent = bulb
		-- Plantas en las esquinas delanteras
		plant(model, floor * CFrame.new(-W / 2 + 2, 0.7, -D / 2 + 2))
		plant(model, floor * CFrame.new(W / 2 - 2, 0.7, -D / 2 + 2))
	end
	-- Azotea con peto
	local roof = base * CFrame.new(0, floors * FH, 0)
	newPart(model, Vector3.new(W + 1, 0.8, D + 1), roof * CFrame.new(0, 0.4, 0), Color3.fromRGB(180, 178, 172), Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		newPart(model, Vector3.new(W + 1, 1.2, 0.5), roof * CFrame.new(0, 1.4, side * (D / 2 + 0.25)), wall)
		newPart(model, Vector3.new(0.5, 1.2, D + 1), roof * CFrame.new(side * (W / 2 + 0.25), 1.4, 0), wall)
	end
	return roof
end

-- info = { name, officeLevel, capacity, programmers (los mejores primero) }
-- accent = color de la parcela. Devuelve el modelo.
function AgencyOffice.build(parent: Instance, base: CFrame, info, accent: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Agencia"
	local level = info.officeLevel or 1
	local floors = floorsFor(level)
	local roof = shell(model, base, floors, accent)

	-- Nombre en lo alto de la fachada
	local sign = newPart(model, Vector3.new(W - 4, 4, 0.6), roof * CFrame.new(0, 3.6, -D / 2 - 0.1), DARK)
	surfaceText(sign, Enum.NormalId.Front, "👥 " .. string.upper(info.name or "AGENCIA"), Color3.fromRGB(250, 204, 21))
	newPart(model, Vector3.new(W - 3.6, 0.3, 0.8), roof * CFrame.new(0, 5.7, -D / 2 - 0.1), accent, Enum.Material.Neon).CastShadow = false

	-- Mesas: los mejores programadores abajo; mesas vacías = puestos libres
	local programmers = info.programmers or {}
	local seats = math.min(floors * AgencyOffice.DESKS_PER_FLOOR, math.max(info.capacity or 0, #programmers))
	for i = 1, seats do
		local f = (i - 1) // AgencyOffice.DESKS_PER_FLOOR
		local k = (i - 1) % AgencyOffice.DESKS_PER_FLOOR
		local column = k % #DESK_X + 1
		local row = k // #DESK_X + 1
		local slot = base * CFrame.new(DESK_X[column], f * FH + 0.7, DESK_Z[row])
		desk(model, slot, programmers[i], i)
	end

	-- Mejoras de la oficina
	local ground = base * CFrame.new(0, 0.7, 0)
	if level >= Career.perkLevel("cafe") then
		cafe(model, ground)
	end
	if level >= Career.perkLevel("lounge") then
		lounge(model, ground)
	end
	if floors >= 2 and level >= Career.perkLevel("meeting") then
		meeting(model, base * CFrame.new(0, FH + 0.7, 0))
	end
	if floors >= 3 and level >= Career.perkLevel("lab") then
		lab(model, base * CFrame.new(0, 2 * FH + 0.7, 0))
	end
	if level >= Career.perkLevel("rooftop") then
		rooftop(model, roof * CFrame.new(0, 0.8, 0))
	end
	model.Parent = parent
	return model
end

-- Solar vacío con valla y cartel (antes de fundar la agencia)
function AgencyOffice.buildLot(parent: Instance, base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "SolarAgencia"
	newPart(model, Vector3.new(W, 0.2, D), base * CFrame.new(0, 0.1, 0), Color3.fromRGB(160, 130, 95), Enum.Material.Ground)
	local fence = Color3.fromRGB(250, 204, 21)
	for _, side in { -1, 1 } do
		newPart(model, Vector3.new(W, 1.6, 0.3), base * CFrame.new(0, 1, side * D / 2), fence, Enum.Material.SmoothPlastic)
		newPart(model, Vector3.new(0.3, 1.6, D), base * CFrame.new(side * W / 2, 1, 0), fence, Enum.Material.SmoothPlastic)
	end
	for i = 0, 2 do
		newPart(model, Vector3.new(4, 2.4, 4), base * CFrame.new(-10 + i * 5, 1.2, 4), Color3.fromRGB(180, 90, 60), Enum.Material.Brick)
	end
	model.Parent = parent
	return model
end

return AgencyOffice
