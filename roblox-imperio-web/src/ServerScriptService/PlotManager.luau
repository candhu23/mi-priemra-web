--[[
	PlotManager (ModuleScript en ServerScriptService)

	Las parcelas de Ciudad Web. Cada jugador recibe una con:
	  · un terminal con ordenador (ProximityPrompt para abrir el menú)
	  · un cartel con su nombre y su progreso
	  · su rascacielos, que crece con todo lo que ha ganado
]]

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("TycoonConfig"))
local World = require(script.Parent:WaitForChild("World"))
local Building = require(script.Parent:WaitForChild("Building"))

local PlotManager = {}

local SIZE = World.PLOT_SIZE
local HALF = SIZE / 2
local BUILDING_OFFSET = CFrame.new(0, 0.6, 10) -- centro del edificio dentro de la parcela

type Plot = {
	index: number,
	origin: CFrame,
	model: Model,
	signTitle: TextLabel,
	signInfo: TextLabel,
	building: Model?,
	floors: number,
	owner: Player?,
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

local function buildPlot(city: Instance, index: number, origin: CFrame, onOpen: (Player) -> ()): Plot
	local model = Instance.new("Model")
	model.Name = "Parcela" .. index
	local style = Building.Styles[(index - 1) % #Building.Styles + 1]

	-- Base de piedra y césped
	newPart(model, Vector3.new(SIZE + 2, 0.8, SIZE + 2), origin * CFrame.new(0, 0.2, 0), Color3.fromRGB(176, 172, 164), Enum.Material.Concrete)
	newPart(model, Vector3.new(SIZE - 2, 0.4, SIZE - 2), origin * CFrame.new(0, 0.6, 0), Color3.fromRGB(104, 172, 92), Enum.Material.Grass)
	-- Camino hasta el edificio
	newPart(model, Vector3.new(8, 0.45, 26), origin * CFrame.new(0, 0.64, -HALF + 12), Color3.fromRGB(214, 210, 200), Enum.Material.Pavement)

	-- Setos en los laterales y al fondo
	local hedge = Color3.fromRGB(58, 120, 62)
	newPart(model, Vector3.new(1.6, 3, SIZE - 6), origin * CFrame.new(-HALF + 2, 2.2, 2), hedge, Enum.Material.Grass)
	newPart(model, Vector3.new(1.6, 3, SIZE - 6), origin * CFrame.new(HALF - 2, 2.2, 2), hedge, Enum.Material.Grass)
	newPart(model, Vector3.new(SIZE - 4, 3, 1.6), origin * CFrame.new(0, 2.2, HALF - 2), hedge, Enum.Material.Grass)

	-- Árboles delanteros
	World.tree(model, (origin * CFrame.new(-HALF + 7, 0.8, -HALF + 7)).Position, 1)
	World.tree(model, (origin * CFrame.new(HALF - 7, 0.8, -HALF + 7)).Position, 1)

	-- Terminal con ordenador
	local terminalBase = origin * CFrame.new(-11, 0.8, -HALF + 14)
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
	local signBase = origin * CFrame.new(12, 0.8, -HALF + 4)
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

	model:SetAttribute("PlotIndex", index)
	model.Parent = city

	local plot: Plot = {
		index = index,
		origin = origin,
		model = model,
		signTitle = signTitle,
		signInfo = signInfo,
		building = nil,
		floors = 0,
		owner = nil,
	}

	prompt.Triggered:Connect(function(player)
		if plot.owner == player then
			onOpen(player)
		end
	end)

	return plot
end

-- Crea la ciudad y las parcelas. Llamar una sola vez al arrancar.
function PlotManager.init(onOpen: (Player) -> ())
	local origins = World.build()
	local folder = Instance.new("Folder")
	folder.Name = "Parcelas"
	for i, origin in origins do
		table.insert(plots, buildPlot(folder, i, origin, onOpen))
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
	if plot.building then
		plot.building:Destroy()
		plot.building = nil
	end
	plot.floors = 0
end

function PlotManager.getSpawnCFrame(player: Player): CFrame
	local plot = plotByPlayer[player]
	if plot then
		-- En el camino, mirando hacia el terminal
		local position = (plot.origin * CFrame.new(-3, 4, -HALF + 10)).Position
		local target = (plot.origin * CFrame.new(-11, 4, -HALF + 14)).Position
		return CFrame.lookAt(position, target)
	end
	return CFrame.new(-212, 5, 0)
end

-- Actualiza el cartel y, si cambia el número de plantas, el rascacielos.
function PlotManager.update(player: Player, lifetimeEarned: number, income: number)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local floors = Config.buildingFloors(lifetimeEarned)
	plot.signInfo.Text = string.format("%d plantas · %s/s", floors, Config.formatMoney(income))
	if floors == plot.floors then
		return
	end

	local animateFrom = if plot.floors == 0 then floors else plot.floors
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
		animateFrom
	)
	plot.floors = floors
end

function PlotManager.setLeaderboard(rows, message: string?)
	World.setLeaderboard(rows, message)
end

return PlotManager
