--[[
	Traffic (ModuleScript en ReplicatedStorage)

	Coches que circulan sin parar por la avenida y la glorieta. Los crea y
	los mueve CADA CLIENTE en su pantalla (TrafficClient), así van suaves y
	no gastan red. No chocan con nadie (CanCollide = false).

	  Traffic.start(parent) → crea los coches
	  Traffic.step(dt)      → los mueve (llamar cada frame)
]]

local City = require(script.Parent:WaitForChild("CityLayout"))

local Traffic = {}

Traffic.CAR_COUNT = 16
Traffic.SPEED = 26 -- studs por segundo

-- pieces = cada pieza con su posición respecto al centro del coche
type Car = { model: Model, pieces: { { part: BasePart, offset: CFrame } }, cframe: CFrame, distance: number, segment: number }

local path: { Vector3 } = {}
local cumulative: { number } = {} -- distancia desde el inicio hasta cada punto
local total = 0
local cars: { Car } = {}

local COLORS = {
	Color3.fromRGB(220, 38, 38), Color3.fromRGB(37, 99, 235), Color3.fromRGB(245, 245, 245),
	Color3.fromRGB(30, 30, 34), Color3.fromRGB(34, 197, 94), Color3.fromRGB(249, 115, 22),
	Color3.fromRGB(148, 163, 184), Color3.fromRGB(168, 85, 247),
}

local function newPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Coche mirando hacia -Z (como un CFrame normal). kind: "coche", "taxi", "bus", "furgo"
local function buildCar(parent: Instance, kind: string, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Coche"
	local length = if kind == "bus" then 18 elseif kind == "furgo" then 10 else 8.5
	local width = if kind == "bus" then 5 else 4.2
	local bodyHeight = if kind == "bus" then 5.5 elseif kind == "furgo" then 4.2 else 1.8
	local body = newPart(model, Vector3.new(width, bodyHeight, length), CFrame.new(0, 0.9 + bodyHeight / 2, 0), color)
	model.PrimaryPart = body
	local glass = Color3.fromRGB(140, 180, 210)
	if kind == "bus" then
		-- Ventanas a los lados y cartel de línea
		for _, x in { -1, 1 } do
			local windows = newPart(model, Vector3.new(0.1, 1.8, length - 3), CFrame.new(x * (width / 2 + 0.05), 4.6, 0.5), glass, Enum.Material.Glass)
			windows.Transparency = 0.15
		end
		newPart(model, Vector3.new(width - 0.6, 2.2, 0.1), CFrame.new(0, 4.4, -length / 2 - 0.05), glass, Enum.Material.Glass).Transparency = 0.15
	elseif kind == "furgo" then
		newPart(model, Vector3.new(width - 0.4, 1.6, 0.1), CFrame.new(0, 4, -length / 2 - 0.05), glass, Enum.Material.Glass).Transparency = 0.15
	else
		local cabin = newPart(model, Vector3.new(width - 0.4, 1.6, 4.6), CFrame.new(0, 3.5, 0.4), glass, Enum.Material.Glass)
		cabin.Transparency = 0.2
		newPart(model, Vector3.new(width - 0.3, 0.2, 4.4), CFrame.new(0, 4.35, 0.4), color)
		if kind == "taxi" then
			newPart(model, Vector3.new(1.6, 0.6, 0.8), CFrame.new(0, 4.75, 0.4), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		end
	end
	-- Ruedas
	local wheelX = width / 2 - 0.2
	local wheelZ = length / 2 - 1.6
	for _, x in { -wheelX, wheelX } do
		for _, z in { -wheelZ, wheelZ } do
			local wheel = newPart(model, Vector3.new(0.8, 1.7, 1.7), CFrame.new(x, 0.85, z), Color3.fromRGB(25, 25, 28))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	-- Faros (delante, -Z) y pilotos (detrás)
	for _, x in { -width / 2 + 0.6, width / 2 - 0.6 } do
		newPart(model, Vector3.new(0.8, 0.4, 0.1), CFrame.new(x, 1.6, -length / 2 - 0.05), Color3.fromRGB(255, 244, 200), Enum.Material.Neon).CastShadow = false
		newPart(model, Vector3.new(0.8, 0.4, 0.1), CFrame.new(x, 1.6, length / 2 + 0.05), Color3.fromRGB(239, 68, 68), Enum.Material.Neon).CastShadow = false
	end
	model.Parent = parent
	return model
end

-- Punto del recorrido a "distance" studs del inicio (y el segmento donde cae)
local function pointAt(distance: number, segment: number): (Vector3, number)
	distance %= total
	local n = #path
	-- Busca el segmento avanzando desde el último (los coches solo avanzan)
	local guard = 0
	while guard <= n do
		local i = (segment - 1) % n + 1
		local fromD = cumulative[i]
		local toD = if i == n then total else cumulative[i + 1]
		if distance >= fromD and distance < toD then
			local a = path[i]
			local b = path[i % n + 1]
			local t = (distance - fromD) / math.max(toD - fromD, 1e-6)
			return a:Lerp(b, t), i
		end
		segment = i + 1
		guard += 1
	end
	return path[1], 1
end

local function place(car: Car)
	local position, segment = pointAt(car.distance, car.segment)
	car.segment = segment
	-- Mira un poco hacia delante para girar suave en las curvas
	local ahead = pointAt(car.distance + 3, segment)
	if (ahead - position).Magnitude > 0.01 then
		local cf = CFrame.lookAt(position, ahead)
		car.cframe = cf
		for _, piece in car.pieces do
			piece.part.CFrame = cf * piece.offset
		end
	end
end

function Traffic.path(): { Vector3 }
	return path
end

function Traffic.length(): number
	return total
end

function Traffic.cars(): { Car }
	return cars
end

function Traffic.start(parent: Instance)
	path = City.trafficPath()
	cumulative = {}
	total = 0
	for i, point in path do
		cumulative[i] = total
		total += (path[i % #path + 1] - point).Magnitude
	end
	local folder = Instance.new("Folder")
	folder.Name = "Trafico"
	for i = 1, Traffic.CAR_COUNT do
		local kind = if i % 7 == 0 then "bus" elseif i % 5 == 0 then "taxi" elseif i % 4 == 0 then "furgo" else "coche"
		local color = if kind == "taxi" then Color3.fromRGB(250, 204, 21) elseif kind == "bus" then Color3.fromRGB(37, 99, 235) else COLORS[i % #COLORS + 1]
		local model = buildCar(folder, kind, color)
		local pieces = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(pieces, { part = child, offset = child.CFrame })
			end
		end
		local car: Car = { model = model, pieces = pieces, cframe = CFrame.new(), distance = (i - 1) / Traffic.CAR_COUNT * total, segment = 1 }
		table.insert(cars, car)
		place(car)
	end
	folder.Parent = parent
end

function Traffic.step(dt: number)
	for _, car in cars do
		car.distance = (car.distance + Traffic.SPEED * math.min(dt, 0.25)) % total
		place(car)
	end
end

return Traffic
