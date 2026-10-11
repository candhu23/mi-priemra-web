--!strict
-- Construye el edificio (todo lo que no se mueve) a partir de Layout. Lo crea el servidor y Roblox lo
-- replica a los clientes. Los LIBROS no están aquí: los dibuja el cliente (ver Client/Books.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))

local Building = {}

function Building.build(def: Layout.Def, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = if def.name == "main" then "Library" else "Archive"
	local folders: { [string]: Folder } = {}
	local function folder(name: string): Folder
		local existing = folders[name]
		if existing then
			return existing
		end
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		folders[name] = f
		return f
	end
	for _, p in def.pieces do
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = p.size
		part.CFrame = p.cf
		part.Color = p.color
		part.Material = p.mat
		part.CanCollide = p.collide
		part.CanTouch = false
		part.Transparency = p.transp or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if p.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		if p.query == false then
			part.CanQuery = false
		end
		if p.mat == Enum.Material.Neon or p.mat == Enum.Material.Glass or p.transp then
			part.CastShadow = false
		end
		part.Name = p.name or "Part"
		if p.interact then
			part:SetAttribute("Interact", p.interact)
		end
		part.Parent = folder(p.group or "Structure")
	end
	for i, l in def.lights do
		local holder = Instance.new("Part")
		holder.Name = "Light" .. i
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(l.pos)
		local light = Instance.new("PointLight")
		light.Range = l.range
		light.Brightness = l.brightness
		light.Color = l.color
		light.Shadows = l.shadows
		light.Parent = holder
		holder.Parent = folder("Lights")
	end
	if def.name == "main" then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(4, 0.1, 4)
		spawn.CFrame = def.spawn + Vector3.new(0, 0.05, 0)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = model
	end
	model.Parent = parent
	return model
end

-- Quita del mundo las piezas de un objeto (llave cogida, tapa de cofre abierta…)
function Building.setVisible(model: Model, name: string, visible: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			d.Transparency = if visible then 0 else 1
			d.CanQuery = visible
			d.CanCollide = false
		end
	end
end

return Building
