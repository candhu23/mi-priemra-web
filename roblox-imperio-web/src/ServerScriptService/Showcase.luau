--[[
	Showcase (ModuleScript en ServerScriptService)

	Lo que se ve del imperio de cada jugador en su parcela, además del
	rascacielos:
	  · Edificio de la agencia (derecha, AgencyOffice): tus programadores
	    trabajando en su mesa detrás de la fachada de cristal; crece y
	    enseña sus salas al ampliar la oficina.
	  · Paseo de la fama (delante del rascacielos): un pedestal por tipo de
	    web que se enciende cuando la has programado. Tu mejor web, con luz.
	  · Pantalla en la fachada con tu web estrella y sus visitas.
	Todo se actualiza solo cuando cambia algo (no cada segundo).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local AgencyOffice = require(script.Parent:WaitForChild("AgencyOffice"))

local Showcase = {}

local GROUND = 0.8 -- altura del césped de la parcela
local DECK_TOP = GROUND + 0.3
-- Coordenadas dentro de la parcela (-Z = avenida)
Showcase.AGENCY_OFFSET = CFrame.new(24, GROUND, 10) -- centro del edificio de la agencia
local FAME_Z = -22 -- fila del paseo de la fama
local FAME_X0, FAME_STEP = -41, 4.6 -- primer pedestal y separación

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
	accent: Color3,
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

	-- Cartel de la agencia delante de su edificio
	local officeInfo = smallSign(model, origin * Showcase.AGENCY_OFFSET * CFrame.new(12, 0, -22), "👥 AGENCIA", Color3.fromRGB(217, 70, 239))

	-- Paseo de la fama: una fila de pedestales delante del rascacielos
	newPart(model, Vector3.new(FAME_STEP * #Config.WebTypes + 2, 0.3, 7), origin * CFrame.new(FAME_X0 + FAME_STEP * (#Config.WebTypes - 1) / 2, GROUND + 0.15, FAME_Z), Color3.fromRGB(205, 200, 190), Enum.Material.Slate)
	local fameInfo = smallSign(model, origin * CFrame.new(FAME_X0 + FAME_STEP * (#Config.WebTypes - 1) / 2, GROUND, FAME_Z - 7), "🏆 PASEO DE LA FAMA", Color3.fromRGB(250, 204, 21))
	local pedestals: { [string]: Pedestal } = {}
	for i, def in Config.WebTypes do
		local base = origin * CFrame.new(FAME_X0 + (i - 1) * FAME_STEP, DECK_TOP, FAME_Z)
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
		accent = accent,
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
-- Edificio de la agencia con el equipo
---------------------------------------------------------------------
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
	return sorted
end

local function updateTeam(handle: Handle, extra)
	local hasAgency = extra ~= nil and extra.agency == true
	local programmers = if hasAgency then bestProgrammers(extra.programmers or {}) else {}
	local parts = { if extra == nil then "-" elseif hasAgency then "A" else "S", tostring(extra and extra.officeLevel), tostring(extra and extra.capacity), tostring(extra and extra.agencyName) }
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
	local base = handle.origin * Showcase.AGENCY_OFFSET
	if not extra then
		handle.officeInfo.Text = ""
		handle.team = AgencyOffice.buildLot(handle.model, base)
		return
	end
	if not hasAgency then
		handle.officeInfo.Text = "Funda tu agencia para construir aquí tu edificio"
		handle.team = AgencyOffice.buildLot(handle.model, base)
		return
	end
	local total = #programmers
	local shown = math.min(total, AgencyOffice.floorsFor(extra.officeLevel or 1) * AgencyOffice.DESKS_PER_FLOOR)
	handle.officeInfo.Text = if total == 1 then "1 programador"
		elseif total > shown then string.format("%d programadores · se ven los %d mejores", total, shown)
		else string.format("%d programadores", total)
	handle.team = AgencyOffice.build(handle.model, base, {
		name = extra.agencyName,
		officeLevel = extra.officeLevel,
		capacity = extra.capacity,
		programmers = programmers,
	}, handle.accent)
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
