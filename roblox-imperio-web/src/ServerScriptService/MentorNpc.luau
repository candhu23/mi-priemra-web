--[[
	MentorNpc (ModuleScript en ServerScriptService)

	Ada, la mentora del Modo Historia (v4): una figura hecha con piezas
	(sin mallas externas) con su portátil, un cartel encima y un
	ProximityPrompt «Hablar con Ada». Está en la plaza y en cada parcela,
	junto al ordenador.

	MentorNpc.build(parent, cframe) → (modelo, prompt). cframe = dónde está
	(de pie, mirando hacia -Z del cframe... es decir, hacia LookVector).
]]

local MentorNpc = {}

local SKIN = Color3.fromRGB(198, 134, 98)
local HAIR = Color3.fromRGB(46, 30, 24)
local JACKET = Color3.fromRGB(124, 58, 237)
local SHIRT = Color3.fromRGB(240, 240, 245)
local TROUSERS = Color3.fromRGB(30, 41, 59)

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function MentorNpc.build(parent: Instance, cframe: CFrame): (Model, ProximityPrompt)
	local model = Instance.new("Model")
	model.Name = "Ada"
	local base = cframe -- los pies
	-- Piernas y cuerpo
	part(model, "PiernaI", Vector3.new(0.9, 2.6, 0.9), base * CFrame.new(-0.5, 1.3, 0), TROUSERS)
	part(model, "PiernaD", Vector3.new(0.9, 2.6, 0.9), base * CFrame.new(0.5, 1.3, 0), TROUSERS)
	local torso = part(model, "Torso", Vector3.new(2, 2.4, 1), base * CFrame.new(0, 3.8, 0), JACKET)
	part(model, "Camisa", Vector3.new(0.8, 2, 0.05), base * CFrame.new(0, 3.9, -0.52), SHIRT)
	-- Brazos: uno sujeta el portátil
	part(model, "BrazoI", Vector3.new(0.7, 2.3, 0.7), base * CFrame.new(-1.35, 3.75, 0), JACKET)
	part(model, "BrazoD", Vector3.new(0.7, 2.2, 0.7), base * CFrame.new(1.2, 3.9, -0.6) * CFrame.Angles(math.rad(70), 0, 0), JACKET)
	-- Cabeza, pelo y gafas
	local head = part(model, "Head", Vector3.new(1.4, 1.4, 1.4), base * CFrame.new(0, 5.75, 0), SKIN)
	part(model, "Pelo", Vector3.new(1.5, 0.6, 1.5), base * CFrame.new(0, 6.45, 0.05), HAIR)
	part(model, "Coleta", Vector3.new(0.6, 1.2, 0.5), base * CFrame.new(0, 5.9, 0.85), HAIR)
	part(model, "Gafas", Vector3.new(1.2, 0.25, 0.1), base * CFrame.new(0, 5.85, -0.72), Color3.fromRGB(20, 20, 20))
	-- Portátil (con la pantalla encendida)
	local laptop = base * CFrame.new(0.9, 3.4, -1.3)
	part(model, "Portatil", Vector3.new(1.6, 0.12, 1.1), laptop, Color3.fromRGB(148, 163, 184), Enum.Material.Metal)
	local screen = part(model, "Pantalla", Vector3.new(1.6, 1, 0.08), laptop * CFrame.new(0, 0.5, 0.55) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(56, 140, 255), Enum.Material.Neon)
	screen.CastShadow = false
	-- Peana para que se vea que es "alguien especial"
	part(model, "Peana", Vector3.new(4, 0.3, 4), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(250, 204, 21), Enum.Material.Neon).CastShadow = false

	-- Cartel con su nombre
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nombre"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = 90
	billboard.AlwaysOnTop = false
	billboard.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "👩‍💻 Ada · Mentora"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(250, 204, 21)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = head

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hablar con Ada"
	prompt.ObjectText = "Ada"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	model.PrimaryPart = torso
	model.Parent = parent
	return model, prompt
end

return MentorNpc
