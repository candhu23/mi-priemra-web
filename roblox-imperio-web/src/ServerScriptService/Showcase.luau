--[[
	Showcase (ModuleScript en ServerScriptService)

	Lo que se ve del imperio de cada jugador en su parcela, además del
	rascacielos:
	  · Oficina de la agencia al aire libre (derecha): tus 8 mejores
	    programadores trabajando en su mesa, con el color de su rareza.
	    Los Legendarios y Míticos brillan y llevan aureola.
	  · Paseo de la fama (izquierda): un pedestal por tipo de web que se
	    enciende cuando la has programado alguna vez. Tu mejor web, con luz.
	  · Pantalla en la fachada con tu web estrella y sus visitas.
	Todo se actualiza solo cuando cambia algo (no cada segundo).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))

local Showcase = {}

local MAX_DESKS = 8
local GROUND = 0.8 -- altura del césped de la parcela
local DECK_TOP = GROUND + 0.3
local SLOT_X = { 20.75, 26.25 } -- columnas (lado derecho de la parcela)
local SLOT_Z = { 0, 7, 14, 21 } -- filas, de delante (avenida) hacia atrás

-- Color de cada tipo de web en el paseo de la fama
local TYPE_COLORS = {
	landing = Color3.fromRGB(148, 163, 184),
	blog = Color3.fromRGB(34, 197, 94),
	tienda = Color3.fromRGB(249, 115, 22),
	noticias = Color3.fromRGB(14, 165, 233),
	red_social = Color3.fromRGB(59, 130, 246),
	streaming = Color3.fromRGB(239, 68, 68),
	app_ia = Color3.fromRGB(168, 85, 247),
	metaverso = Color3.fromRGB(236, 72, 153),
}
local LOCKED_COLOR = Color3.fromRGB(60, 64, 74)
local SKIN_TONES = {
	Color3.fromRGB(255, 205, 160),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 134, 96),
	Color3.fromRGB(141, 85, 54),
	Color3.fromRGB(255, 224, 189),
}

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

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, bold: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Text = text
	l.TextScaled = true
	l.Font = if bold then Enum.Font.FredokaOne else Enum.Font.GothamBold
	l.TextColor3 = color
	l.Parent = parent
	return l
end

local function surfaceGui(part: BasePart, face: Enum.NormalId, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.MaxDistance = 250
	gui.Parent = part
	return gui
end

-- Cartel bajo con dos patas (título + una línea de información). Es bajo
-- para que desde la avenida se vea lo que hay detrás.
local function smallSign(parent: Instance, cframe: CFrame, title: string, color: Color3): TextLabel
	for _, x in { -3.8, 3.8 } do
		newPart(parent, Vector3.new(0.4, 1.6, 0.4), cframe * CFrame.new(x, 0.8, 0), Color3.fromRGB(30, 41, 59), Enum.Material.Metal)
	end
	local board = newPart(parent, Vector3.new(8.6, 2.4, 0.4), cframe * CFrame.new(0, 2.3, 0), Color3.fromRGB(15, 23, 42))
	newPart(parent, Vector3.new(8.8, 0.25, 0.5), cframe * CFrame.new(0, 3.6, 0), color, Enum.Material.Neon).CastShadow = false
	local gui = surfaceGui(board, Enum.NormalId.Front, 30)
	label(gui, title, UDim2.fromScale(0.94, 0.5), UDim2.fromScale(0.03, 0.06), color, true)
	return label(gui, "", UDim2.fromScale(0.94, 0.34), UDim2.fromScale(0.03, 0.6), Color3.fromRGB(226, 232, 240), false)
end

type Pedestal = { cube: Part, emoji: TextLabel, count: TextLabel, light: PointLight, sparkles: ParticleEmitter }
export type Handle = {
	origin: CFrame,
	model: Model,
	team: Model?,
	teamKey: string,
	fameKey: string,
	officeInfo: TextLabel,
	fameInfo: TextLabel,
	pedestals: { [string]: Pedestal },
	screen: Part,
	screenGui: SurfaceGui,
	screenTitle: TextLabel,
	screenText: TextLabel,
	frame: Part,
}

-- Crea la parte fija (suelo de la oficina, pedestales, pantalla). Llamar
-- una vez por parcela. buildingBase = centro del rascacielos.
function Showcase.create(plotModel: Model, origin: CFrame, buildingBase: CFrame, accent: Color3): Handle
	local model = Instance.new("Model")
	model.Name = "Escaparate"

	-- Oficina al aire libre (lado derecho)
	local officeCenter = origin * CFrame.new(23.5, 0, 11)
	newPart(model, Vector3.new(11, 0.3, 30), officeCenter * CFrame.new(0, GROUND + 0.15, 0), Color3.fromRGB(176, 140, 104), Enum.Material.WoodPlanks)
	local officeInfo = smallSign(model, origin * CFrame.new(23.5, GROUND, -6), "👥 AGENCIA", Color3.fromRGB(217, 70, 239))

	-- Paseo de la fama (lado izquierdo): un pedestal por tipo de web
	local fameCenter = origin * CFrame.new(-23.5, 0, 11)
	newPart(model, Vector3.new(11, 0.3, 30), fameCenter * CFrame.new(0, GROUND + 0.15, 0), Color3.fromRGB(205, 200, 190), Enum.Material.Slate)
	local fameInfo = smallSign(model, origin * CFrame.new(-23.5, GROUND, -6), "🏆 PASEO DE LA FAMA", Color3.fromRGB(250, 204, 21))
	local pedestals: { [string]: Pedestal } = {}
	for i, def in Config.WebTypes do
		local column = (i - 1) % 2 + 1
		local row = (i - 1) // 2 + 1
		local base = origin * CFrame.new(-SLOT_X[3 - column], DECK_TOP, SLOT_Z[row])
		local stand = newPart(model, Vector3.new(3.2, 1.4, 3.2), base * CFrame.new(0, 0.7, 0), Color3.fromRGB(226, 222, 214), Enum.Material.Marble)
		local standGui = surfaceGui(stand, Enum.NormalId.Front, 40)
		label(standGui, def.name, UDim2.fromScale(0.96, 0.7), UDim2.fromScale(0.02, 0.15), Color3.fromRGB(30, 41, 59), true)
		local cube = newPart(model, Vector3.new(2.4, 2.4, 2.4), base * CFrame.new(0, 1.4 + 0.3 + 1.2, 0), LOCKED_COLOR)
		cube.CastShadow = false
		local cubeGui = surfaceGui(cube, Enum.NormalId.Front, 50)
		local emoji = label(cubeGui, "🔒", UDim2.fromScale(0.8, 0.62), UDim2.fromScale(0.1, 0.06), Color3.new(1, 1, 1), true)
		local count = label(cubeGui, "", UDim2.fromScale(0.9, 0.28), UDim2.fromScale(0.05, 0.68), Color3.new(1, 1, 1), true)
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 2
		light.Color = TYPE_COLORS[def.id] or Color3.new(1, 1, 1)
		light.Enabled = false
		light.Parent = cube
		local attachment = Instance.new("Attachment")
		attachment.Parent = cube
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Rate = 8
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.Speed = NumberRange.new(1.5, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.LightEmission = 1
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 236, 150))
		sparkles.Enabled = false
		sparkles.Parent = attachment
		pedestals[def.id] = { cube = cube, emoji = emoji, count = count, light = light, sparkles = sparkles }
	end

	-- Pantalla en la fachada (primera planta del rascacielos)
	local screenCFrame = buildingBase * CFrame.new(0, 9 + 0.8 + 2.1, -13.75)
	local frame = newPart(model, Vector3.new(16.6, 4, 0.2), screenCFrame * CFrame.new(0, 0, 0.12), accent, Enum.Material.Neon)
	frame.CastShadow = false
	local screen = newPart(model, Vector3.new(16, 3.4, 0.3), screenCFrame, Color3.fromRGB(15, 23, 42))
	screen.CastShadow = false
	local screenGui = surfaceGui(screen, Enum.NormalId.Front, 30)
	local screenTitle = label(screenGui, "📺 WEB ESTRELLA", UDim2.fromScale(0.9, 0.32), UDim2.fromScale(0.05, 0.06), Color3.fromRGB(250, 204, 21), true)
	local screenText = label(screenGui, "", UDim2.fromScale(0.94, 0.5), UDim2.fromScale(0.03, 0.42), Color3.new(1, 1, 1), true)

	model.Parent = plotModel
	local handle: Handle = {
		origin = origin,
		model = model,
		team = nil,
		teamKey = "",
		fameKey = "",
		officeInfo = officeInfo,
		fameInfo = fameInfo,
		pedestals = pedestals,
		screen = screen,
		screenGui = screenGui,
		screenTitle = screenTitle,
		screenText = screenText,
		frame = frame,
	}
	Showcase.update(handle, nil)
	return handle
end

---------------------------------------------------------------------
-- Programadores en su mesa
---------------------------------------------------------------------
local function buildDesk(parent: Instance, slot: CFrame, programmer, index: number)
	local rarity = Career.RarityById[programmer.rarity] or Career.Rarities[1]
	local wood = Color3.fromRGB(150, 111, 70)
	newPart(parent, Vector3.new(3.2, 2.5, 1.6), slot * CFrame.new(0, 1.25, 0), wood, Enum.Material.WoodPlanks)
	local monitor = newPart(parent, Vector3.new(1.8, 1.1, 0.15), slot * CFrame.new(0, 2.5 + 0.6, -0.1), rarity.color, Enum.Material.Neon)
	monitor.CastShadow = false
	-- Silla
	local chair = Color3.fromRGB(40, 44, 52)
	newPart(parent, Vector3.new(1.8, 0.3, 1.6), slot * CFrame.new(0, 1.6, 1.9), chair)
	newPart(parent, Vector3.new(1.8, 1.8, 0.3), slot * CFrame.new(0, 2.6, 2.75), chair)
	-- Programador: cuerpo del color de su rareza, cabeza y brazos tecleando
	local skin = SKIN_TONES[(programmer.id or index) % #SKIN_TONES + 1]
	local torso = newPart(parent, Vector3.new(2, 2, 1), slot * CFrame.new(0, 2.75, 1.9), rarity.color)
	local head = newPart(parent, Vector3.new(1.3, 1.3, 1.3), slot * CFrame.new(0, 4.4, 1.9), skin)
	head.Shape = Enum.PartType.Ball
	for _, x in { -0.75, 0.75 } do
		newPart(parent, Vector3.new(0.5, 0.5, 1.3), slot * CFrame.new(x, 2.7, 1.15), rarity.color)
	end

	-- Nombre y rareza encima
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 42)
	billboard.StudsOffset = Vector3.new(0, 1.7, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	-- Icono de su especialidad (💻 🎨 📣 🤝 📊) delante del nombre
	local role = Career.RoleById[programmer.role or "dev"]
	local nameLabel = label(billboard, (if role then role.emoji .. " " else "") .. programmer.name, UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), Color3.new(1, 1, 1), true)
	nameLabel.TextStrokeTransparency = 0.3
	local rarityLabel = label(billboard, rarity.name, UDim2.fromScale(1, 0.45), UDim2.fromScale(0, 0.55), rarity.color, true)
	rarityLabel.TextStrokeTransparency = 0.3
	billboard.Parent = head

	-- Legendarios y Míticos: luz, aureola y destellos
	if rarity.order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10
		light.Brightness = 2.5
		light.Parent = torso
		local halo = newPart(parent, Vector3.new(0.12, 1.5, 1.5), slot * CFrame.new(0, 5.35, 1.9) * CFrame.Angles(0, 0, math.rad(90)), rarity.color, Enum.Material.Neon)
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

-- Los mejores primero (rareza y luego nivel)
local function bestProgrammers(list): { any }
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b)
		local ra = (Career.RarityById[a.rarity] or Career.Rarities[1]).order
		local rb = (Career.RarityById[b.rarity] or Career.Rarities[1]).order
		if ra ~= rb then
			return ra > rb
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		return (a.id or 0) < (b.id or 0)
	end)
	local top = {}
	for i = 1, math.min(MAX_DESKS, #sorted) do
		top[i] = sorted[i]
	end
	return top
end

local function updateTeam(handle: Handle, extra)
	local programmers = if extra and extra.agency then bestProgrammers(extra.programmers or {}) else {}
	local parts = { if extra and extra.agency then "A" else "-" }
	for _, p in programmers do
		table.insert(parts, string.format("%s:%s:%s:%d:%s", tostring(p.id), p.name, p.rarity, p.level, tostring(p.role)))
	end
	local key = table.concat(parts, "|")
	if key == handle.teamKey then
		return
	end
	handle.teamKey = key
	if handle.team then
		handle.team:Destroy()
		handle.team = nil
	end
	if not extra then
		handle.officeInfo.Text = ""
		return
	end
	if not extra.agency then
		handle.officeInfo.Text = "Funda tu agencia para ver aquí a tus programadores"
		return
	end
	local total = #(extra.programmers or {})
	handle.officeInfo.Text = if total == 1 then "1 programador"
		elseif total > MAX_DESKS then string.format("%d programadores · se ven los %d mejores", total, MAX_DESKS)
		else string.format("%d programadores", total)
	local team = Instance.new("Model")
	team.Name = "Equipo"
	for i, programmer in programmers do
		local column = (i - 1) % 2 + 1
		local row = (i - 1) // 2 + 1
		buildDesk(team, handle.origin * CFrame.new(SLOT_X[column], DECK_TOP, SLOT_Z[row]), programmer, i)
	end
	team.Parent = handle.model
	handle.team = team
end

---------------------------------------------------------------------
-- Paseo de la fama y pantalla
---------------------------------------------------------------------
local function updateFame(handle: Handle, extra)
	local built = if extra then extra.builtTypes or {} else {}
	local parts = {}
	local best = nil
	for _, def in Config.WebTypes do
		local count = built[def.id] or 0
		table.insert(parts, tostring(count))
		if count > 0 then
			best = def.id
		end
	end
	local key = (if extra then "o" else "-") .. table.concat(parts, ",")
	if key == handle.fameKey then
		return
	end
	handle.fameKey = key
	local unlocked = 0
	for _, def in Config.WebTypes do
		local pedestal = handle.pedestals[def.id]
		local count = built[def.id] or 0
		if count > 0 then
			unlocked += 1
			pedestal.cube.Material = Enum.Material.Neon
			pedestal.cube.Color = TYPE_COLORS[def.id] or Color3.new(1, 1, 1)
			pedestal.emoji.Text = def.emoji
			pedestal.count.Text = "×" .. Config.formatNumber(count)
		else
			pedestal.cube.Material = Enum.Material.SmoothPlastic
			pedestal.cube.Color = LOCKED_COLOR
			pedestal.emoji.Text = "🔒"
			pedestal.count.Text = ""
		end
		pedestal.light.Enabled = def.id == best
		pedestal.sparkles.Enabled = def.id == best
	end
	handle.fameInfo.Text = if extra then string.format("%d de %d tipos de web creados", unlocked, #Config.WebTypes) else ""
end

local function updateScreen(handle: Handle, extra)
	local visible = extra ~= nil
	handle.screen.Transparency = if visible then 0 else 1
	handle.frame.Transparency = if visible then 0 else 1
	handle.screenGui.Enabled = visible
	if not extra then
		return
	end
	local site = extra.bestSite
	local text = "Aún no tiene webs"
	if site then
		local def = Config.WebTypeById[site.type]
		local variant = site.variant and Config.VariantById[site.variant]
		text = string.format("%s %s · %s visitas/s", (if variant then variant.emoji .. " " else "") .. (if def then def.emoji else "🌐"), site.name, Config.formatNumber(site.visits))
	end
	if handle.screenText.Text ~= text then
		handle.screenText.Text = text
	end
end

-- extra = nil → parcela libre (se apaga todo)
function Showcase.update(handle: Handle, extra)
	updateTeam(handle, extra)
	updateFame(handle, extra)
	updateScreen(handle, extra)
end

return Showcase
