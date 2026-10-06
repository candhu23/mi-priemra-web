--[[
	PlotManager (ModuleScript en ServerScriptService)

	Construye la ciudad: una calle con parcelas. Cada jugador recibe una
	parcela con un ordenador (para abrir el menú) y un rascacielos que
	gana plantas a medida que crece su imperio.
]]

local Workspace = game:GetService("Workspace")

local PlotManager = {}

local PLOT_COUNT = 8
local PLOT_SIZE = 60
local PLOT_SPACING = 72
local FLOOR_HEIGHT = 5
local MAX_FLOORS = 40
local BUILDING_SIZE = 24

type Plot = {
	index: number,
	origin: CFrame, -- centro de la parcela, mirando hacia la calle
	model: Model,
	sign: TextLabel,
	building: Model,
	floors: number,
	owner: Player?,
}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local onComputerOpened: ((Player) -> ())? = nil

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

local function addBillboard(adornee: BasePart, text: string, offset: Vector3, size: UDim2): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 200
	gui.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	gui.Parent = adornee
	return label
end

local function buildPlot(city: Folder, index: number, origin: CFrame): Plot
	local model = Instance.new("Model")
	model.Name = "Parcela" .. index

	-- Suelo de la parcela
	newPart(model, Vector3.new(PLOT_SIZE, 1, PLOT_SIZE), origin * CFrame.new(0, 0.5, 0), Color3.fromRGB(86, 168, 92), Enum.Material.Grass)
	-- Camino hasta la calle
	newPart(model, Vector3.new(8, 1.05, PLOT_SIZE / 2), origin * CFrame.new(0, 0.52, -PLOT_SIZE / 4), Color3.fromRGB(200, 200, 205), Enum.Material.Concrete)

	-- Cartel con el nombre del dueño
	local post = newPart(model, Vector3.new(1, 8, 1), origin * CFrame.new(10, 5, -PLOT_SIZE / 2 + 4), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	local sign = addBillboard(post, "🏗️ Parcela libre", Vector3.new(0, 6, 0), UDim2.fromOffset(260, 70))

	-- Ordenador con ProximityPrompt para abrir el menú
	local desk = newPart(model, Vector3.new(6, 3, 3), origin * CFrame.new(-10, 2.5, -PLOT_SIZE / 2 + 6), Color3.fromRGB(120, 85, 60), Enum.Material.Wood)
	local screen = newPart(model, Vector3.new(4, 2.6, 0.3), desk.CFrame * CFrame.new(0, 2.8, 0.5), Color3.fromRGB(40, 120, 255), Enum.Material.Neon)
	screen.Name = "Pantalla"
	addBillboard(screen, "💻 Ordenador", Vector3.new(0, 3, 0), UDim2.fromOffset(160, 40))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir ordenador"
	prompt.ObjectText = "Imperio Web"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = desk

	local building = Instance.new("Model")
	building.Name = "Edificio"
	building.Parent = model

	model.Parent = city

	local plot: Plot = {
		index = index,
		origin = origin,
		model = model,
		sign = sign,
		building = building,
		floors = 0,
		owner = nil,
	}

	prompt.Triggered:Connect(function(player)
		if plot.owner == player and onComputerOpened then
			onComputerOpened(player)
		end
	end)

	return plot
end

-- Crea la ciudad entera. Llamar una sola vez al arrancar el servidor.
function PlotManager.init(openCallback: (Player) -> ())
	onComputerOpened = openCallback

	local city = Instance.new("Folder")
	city.Name = "CiudadImperioWeb"

	local half = PLOT_COUNT // 2
	local streetLength = half * PLOT_SPACING + 40

	-- Si el sitio no tiene suelo, ponemos uno
	if not Workspace:FindFirstChild("Baseplate") then
		newPart(city, Vector3.new(streetLength + 200, 2, 400), CFrame.new(0, -1, 0), Color3.fromRGB(70, 140, 75), Enum.Material.Grass)
	end

	-- Calle central
	newPart(city, Vector3.new(streetLength, 0.4, 26), CFrame.new(0, 0.2, 0), Color3.fromRGB(45, 45, 50), Enum.Material.Asphalt)
	for x = -streetLength / 2 + 10, streetLength / 2 - 10, 16 do
		newPart(city, Vector3.new(6, 0.45, 0.8), CFrame.new(x, 0.22, 0), Color3.fromRGB(240, 220, 90), Enum.Material.SmoothPlastic)
	end

	-- Parcelas a ambos lados de la calle, mirando hacia ella
	for i = 1, PLOT_COUNT do
		local column = (i - 1) % half
		local side = if i <= half then 1 else -1
		local x = (column - (half - 1) / 2) * PLOT_SPACING
		local z = side * (13 + PLOT_SIZE / 2)
		-- lookAt hacia la calle: el lado -Z local de la parcela da a la calle
		local origin = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0))
		table.insert(plots, buildPlot(city, i, origin))
	end

	city.Parent = Workspace
end

function PlotManager.claim(player: Player): boolean
	if plotByPlayer[player] then
		return true
	end
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.sign.Text = "🏢 " .. player.DisplayName .. " Corp."
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
	plot.sign.Text = "🏗️ Parcela libre"
	plot.building:ClearAllChildren()
	plot.floors = 0
end

function PlotManager.getSpawnCFrame(player: Player): CFrame
	local plot = plotByPlayer[player]
	if plot then
		-- Delante del edificio, mirando hacia el ordenador
		local position = (plot.origin * CFrame.new(0, 4, -PLOT_SIZE / 2 + 12)).Position
		local target = (plot.origin * CFrame.new(-10, 4, -PLOT_SIZE / 2 + 6)).Position
		return CFrame.lookAt(position, target)
	end
	return CFrame.new(0, 5, 0)
end

local FLOOR_COLORS = {
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(150, 210, 255),
	Color3.fromRGB(110, 170, 240),
}

-- Ajusta el número de plantas del rascacielos del jugador.
function PlotManager.setFloors(player: Player, floors: number)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	floors = math.clamp(math.floor(floors), 1, MAX_FLOORS)
	if floors == plot.floors then
		return
	end

	local base = plot.origin * CFrame.new(0, 1, 8)

	-- Añadir plantas
	for floor = plot.floors + 1, floors do
		local floorModel = Instance.new("Model")
		floorModel.Name = "Planta" .. floor
		local y = (floor - 1) * FLOOR_HEIGHT
		newPart(floorModel, Vector3.new(BUILDING_SIZE, 0.6, BUILDING_SIZE), base * CFrame.new(0, y + 0.3, 0), Color3.fromRGB(230, 230, 235), Enum.Material.Concrete)
		local glass = newPart(
			floorModel,
			Vector3.new(BUILDING_SIZE - 1, FLOOR_HEIGHT - 0.6, BUILDING_SIZE - 1),
			base * CFrame.new(0, y + 0.6 + (FLOOR_HEIGHT - 0.6) / 2, 0),
			FLOOR_COLORS[(floor - 1) % #FLOOR_COLORS + 1],
			Enum.Material.Glass
		)
		glass.Transparency = 0.25
		floorModel.Parent = plot.building
	end

	-- Quitar plantas (al salir a bolsa se reinicia el imperio)
	for floor = plot.floors, floors + 1, -1 do
		local floorModel = plot.building:FindFirstChild("Planta" .. floor)
		if floorModel then
			floorModel:Destroy()
		end
	end

	-- Azotea con un letrero de neón
	local roof = plot.building:FindFirstChild("Azotea")
	if roof then
		roof:Destroy()
	end
	local roofPart = newPart(
		plot.building,
		Vector3.new(BUILDING_SIZE * 0.6, 1.5, BUILDING_SIZE * 0.6),
		base * CFrame.new(0, floors * FLOOR_HEIGHT + 0.75, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Neon
	)
	roofPart.Name = "Azotea"
	addBillboard(roofPart, "🏢 " .. player.DisplayName .. " Corp. · " .. floors .. " plantas", Vector3.new(0, 5, 0), UDim2.fromOffset(320, 60))

	plot.floors = floors
end

return PlotManager
