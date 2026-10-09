--[[
	PlotManager (ModuleScript en ServerScriptService)

	Las parcelas de Ciudad Web. Cada jugador recibe una con:
	  · un terminal con ordenador (ProximityPrompt para abrir el menú)
	  · un cartel con su nombre, su progreso y "Ver imperio" (para visitas)
	  · su rascacielos, que crece con todo lo que ha ganado (dorado si ganó
	    el ranking semanal)
	  · el escaparate (Showcase): edificio de la agencia con tus
	    programadores, paseo de la fama y pantalla
	  · jardín con piscina detrás (desde la v3.1 las parcelas miden 96)
]]

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("TycoonConfig"))
local World = require(script.Parent:WaitForChild("World"))
local Building = require(script.Parent:WaitForChild("Building"))
local Showcase = require(script.Parent:WaitForChild("Showcase"))
local MentorNpc = require(script.Parent:WaitForChild("MentorNpc"))

local PlotManager = {}

local SIZE = World.PLOT_SIZE
local HALF = SIZE / 2
local BUILDING_OFFSET = CFrame.new(-20, 0.6, 12) -- centro del rascacielos dentro de la parcela
local TERMINAL_OFFSET = CFrame.new(10, 0.8, -34) -- ordenador, junto al camino de entrada

type Plot = {
	index: number,
	origin: CFrame,
	model: Model,
	signTitle: TextLabel,
	signInfo: TextLabel,
	building: Model?,
	floors: number,
	gold: boolean,
	owner: Player?,
	showcase: Showcase.Handle,
	visitPrompt: ProximityPrompt,
}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

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

local function surfaceLabel(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextScaled = true
	label.Font = if bold then Enum.Font.FredokaOne else Enum.Font.GothamBold
	label.TextColor3 = color
	label.Parent = parent
	return label
end

local function buildPlot(city: Instance, index: number, origin: CFrame, onOpen: (Player) -> (), onVisit: (Player, Player) -> (), onTalk: (Player) -> ()): Plot
	local model = Instance.new("Model")
	model.Name = "Parcela" .. index
	local style = Building.Styles[(index - 1) % #Building.Styles + 1]

	-- Base de piedra y césped
	newPart(model, Vector3.new(SIZE + 2, 0.8, SIZE + 2), origin * CFrame.new(0, 0.2, 0), Color3.fromRGB(176, 172, 164), Enum.Material.Concrete)
	newPart(model, Vector3.new(SIZE - 2, 0.4, SIZE - 2), origin * CFrame.new(0, 0.6, 0), Color3.fromRGB(104, 172, 92), Enum.Material.Grass)
	-- Caminos: de la acera al paseo que une el rascacielos y la agencia
	local paving = Color3.fromRGB(214, 210, 200)
	newPart(model, Vector3.new(8, 0.45, HALF - 9), origin * CFrame.new(0, 0.64, (-HALF + 1 - 10) / 2), paving, Enum.Material.Pavement)
	newPart(model, Vector3.new(56, 0.45, 6), origin * CFrame.new(1, 0.64, -10), paving, Enum.Material.Pavement)
	newPart(model, Vector3.new(7, 0.45, 9), origin * CFrame.new(-20, 0.64, -5), paving, Enum.Material.Pavement)

	-- Setos en los laterales y al fondo
	local hedge = Color3.fromRGB(58, 120, 62)
	newPart(model, Vector3.new(1.6, 3, SIZE - 6), origin * CFrame.new(-HALF + 2, 2.2, 2), hedge, Enum.Material.Grass)
	newPart(model, Vector3.new(1.6, 3, SIZE - 6), origin * CFrame.new(HALF - 2, 2.2, 2), hedge, Enum.Material.Grass)
	newPart(model, Vector3.new(SIZE - 4, 3, 1.6), origin * CFrame.new(0, 2.2, HALF - 2), hedge, Enum.Material.Grass)

	-- Árboles delanteros y del jardín de atrás
	for _, position in { Vector3.new(-HALF + 7, 0.8, -HALF + 7), Vector3.new(HALF - 7, 0.8, -HALF + 7), Vector3.new(2, 0.8, 38), Vector3.new(40, 0.8, 39), Vector3.new(12, 0.8, 41) } do
		World.tree(model, (origin * CFrame.new(position)).Position, 1)
	end
	-- Piscina detrás del rascacielos
	local poolCenter = origin * CFrame.new(-22, 0.8, 37)
	newPart(model, Vector3.new(22, 0.3, 13), poolCenter * CFrame.new(0, 0.15, 0), Color3.fromRGB(226, 222, 214), Enum.Material.Marble)
	local water = newPart(model, Vector3.new(18, 0.35, 9), poolCenter * CFrame.new(0, 0.2, 0), Color3.fromRGB(56, 170, 230), Enum.Material.Glass)
	water.Transparency = 0.2
	water.Reflectance = 0.2
	for _, x in { -6, 0, 6 } do
		newPart(model, Vector3.new(2, 0.5, 4.5), poolCenter * CFrame.new(x, 0.55, 8.5), Color3.fromRGB(245, 245, 245))
	end
	-- Mesa de pícnic detrás de la agencia
	local picnic = origin * CFrame.new(26, 0.8, 32)
	newPart(model, Vector3.new(7, 0.4, 3), picnic * CFrame.new(0, 2.4, 0), Color3.fromRGB(150, 111, 70), Enum.Material.WoodPlanks)
	for _, z in { -2.4, 2.4 } do
		newPart(model, Vector3.new(7, 0.3, 1.2), picnic * CFrame.new(0, 1.4, z), Color3.fromRGB(150, 111, 70), Enum.Material.WoodPlanks)
	end
	newPart(model, Vector3.new(0.6, 2.2, 0.6), picnic * CFrame.new(0, 1.1, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)

	-- Terminal con ordenador
	local terminalBase = origin * TERMINAL_OFFSET
	local desk = newPart(model, Vector3.new(6, 3, 3), terminalBase * CFrame.new(0, 1.5, 0), Color3.fromRGB(30, 41, 59), Enum.Material.SmoothPlastic)
	newPart(model, Vector3.new(6.2, 0.3, 3.2), terminalBase * CFrame.new(0, 3.15, 0), style.accent, Enum.Material.SmoothPlastic)
	local screen = newPart(model, Vector3.new(5, 3.2, 0.3), terminalBase * CFrame.new(0, 5, 0.6) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(56, 140, 255), Enum.Material.Neon)
	screen.CastShadow = false
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Front
	screenGui.LightInfluence = 0
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 40
	surfaceLabel(screenGui, "💻 ORDENADOR", UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.05, 0.25), Color3.new(1, 1, 1), true)
	screenGui.Parent = screen

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir ordenador"
	prompt.ObjectText = "Imperio Web"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = desk

	-- Cartel junto a la acera
	local signBase = origin * CFrame.new(30, 0.8, -HALF + 4)
	for _, x in { -5.5, 5.5 } do
		newPart(model, Vector3.new(0.6, 9, 0.6), signBase * CFrame.new(x, 4.5, 0), Color3.fromRGB(30, 41, 59), Enum.Material.Metal)
	end
	local board = newPart(model, Vector3.new(13, 5, 0.6), signBase * CFrame.new(0, 6.5, 0), Color3.fromRGB(15, 23, 42), Enum.Material.SmoothPlastic)
	newPart(model, Vector3.new(13.4, 0.4, 0.8), signBase * CFrame.new(0, 9.1, 0), style.accent, Enum.Material.Neon).CastShadow = false
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 30
	local signTitle = surfaceLabel(signGui, "🏗️ PARCELA LIBRE", UDim2.fromScale(0.92, 0.5), UDim2.fromScale(0.04, 0.06), Color3.fromRGB(250, 204, 21), true)
	local signInfo = surfaceLabel(signGui, "Espera a un nuevo emprendedor", UDim2.fromScale(0.92, 0.32), UDim2.fromScale(0.04, 0.6), Color3.fromRGB(226, 232, 240), false)
	signGui.Parent = board

	-- Cualquiera puede ver la ficha del imperio y darle "me gusta"
	local visitPrompt = Instance.new("ProximityPrompt")
	visitPrompt.ActionText = "Ver imperio"
	visitPrompt.ObjectText = "Imperio Web"
	visitPrompt.HoldDuration = 0
	visitPrompt.MaxActivationDistance = 12 -- (el del ordenador llega a 14: así no se pisan)
	visitPrompt.RequiresLineOfSight = false
	visitPrompt.Enabled = false
	visitPrompt.Parent = board

	model:SetAttribute("PlotIndex", index)
	local showcase = Showcase.create(model, origin, origin * BUILDING_OFFSET, style.accent)
	model.Parent = city

	local plot: Plot = {
		index = index,
		origin = origin,
		model = model,
		signTitle = signTitle,
		signInfo = signInfo,
		building = nil,
		floors = 0,
		gold = false,
		owner = nil,
		showcase = showcase,
		visitPrompt = visitPrompt,
	}

	prompt.Triggered:Connect(function(player)
		if plot.owner == player then
			onOpen(player)
		end
	end)
	-- Ada, la mentora del Modo Historia, junto al ordenador
	local _ada, adaPrompt = MentorNpc.build(model, origin * CFrame.new(17, 0.8, -32))
	adaPrompt.Triggered:Connect(onTalk)
	visitPrompt.Triggered:Connect(function(visitor)
		if plot.owner then
			onVisit(visitor, plot.owner)
		end
	end)

	return plot
end

-- Crea la ciudad y las parcelas. Llamar una sola vez al arrancar.
-- onOpen(dueño) abre su ordenador; onVisit(visitante, dueño) su ficha.
function PlotManager.init(onOpen: (Player) -> (), onVisit: ((Player, Player) -> ())?, onTalk: ((Player) -> ())?)
	local origins = World.build()
	local folder = Instance.new("Folder")
	folder.Name = "Parcelas"
	local talk = onTalk or function() end
	if World.adaPrompt then
		World.adaPrompt.Triggered:Connect(talk)
	end
	for i, origin in origins do
		table.insert(plots, buildPlot(folder, i, origin, onOpen, onVisit or function() end, talk))
	end
	folder.Parent = Workspace
end

function PlotManager.claim(player: Player): boolean
	if plotByPlayer[player] then
		return true
	end
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.signTitle.Text = "🏢 " .. string.upper(player.DisplayName) .. " CORP."
			plot.visitPrompt.ObjectText = player.DisplayName
			plot.visitPrompt.Enabled = true
			return true
		end
	end
	return false
end

function PlotManager.release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.owner = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.signTitle.Text = "🏗️ PARCELA LIBRE"
	plot.signInfo.Text = "Espera a un nuevo emprendedor"
	plot.visitPrompt.Enabled = false
	plot.visitPrompt.ObjectText = "Imperio Web"
	if plot.building then
		plot.building:Destroy()
		plot.building = nil
	end
	plot.floors = 0
	plot.gold = false
	Showcase.update(plot.showcase, nil)
end

function PlotManager.getSpawnCFrame(player: Player): CFrame
	local plot = plotByPlayer[player]
	if plot then
		-- En el camino, mirando hacia el terminal
		local position = (plot.origin * CFrame.new(3, 4, -HALF + 6)).Position
		local target = (plot.origin * TERMINAL_OFFSET * CFrame.new(0, 3.2, 0)).Position
		return CFrame.lookAt(position, target)
	end
	return CFrame.new(0, 5, 22)
end

-- Actualiza el cartel, el escaparate y, si cambia el número de plantas
-- (o si pasa a ser dorado), el rascacielos.
-- extra = { gold, likes, agency, programmers, builtTypes, bestSite }
function PlotManager.update(player: Player, lifetimeEarned: number, income: number, extra: any?)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local floors = Config.buildingFloors(lifetimeEarned)
	local gold = extra ~= nil and extra.gold == true
	local info = string.format("%d plantas · %s/s · 👍 %d", floors, Config.formatMoney(income), if extra then extra.likes or 0 else 0)
	if plot.signInfo.Text ~= info then
		plot.signInfo.Text = info
	end
	local title = (if gold then "👑 " else "🏢 ") .. string.upper(player.DisplayName) .. " CORP."
	if plot.signTitle.Text ~= title then
		plot.signTitle.Text = title
	end
	Showcase.update(plot.showcase, extra or {})
	if floors == plot.floors and gold == plot.gold then
		return
	end

	local animateFrom = if plot.floors == 0 or floors == plot.floors then floors else plot.floors
	if plot.building then
		plot.building:Destroy()
	end
	plot.building = Building.build(
		plot.model,
		plot.origin * BUILDING_OFFSET,
		floors,
		plot.index,
		player.DisplayName,
		World.isNight(),
		animateFrom,
		gold
	)
	plot.floors = floors
	plot.gold = gold
end

function PlotManager.setLeaderboard(rows, message: string?)
	World.setLeaderboard(rows, message)
end

function PlotManager.setWeeklyBoard(rows, message: string?)
	World.setWeeklyBoard(rows, message)
end

function PlotManager.isNight(): boolean
	return World.isNight()
end

-- Panel de la Bolsa de la plaza
function PlotManager.setMarketBoard(rows)
	World.setMarketBoard(rows)
end

function PlotManager.setEventTint(tint: Color3?)
	World.setEventTint(tint)
end

return PlotManager
