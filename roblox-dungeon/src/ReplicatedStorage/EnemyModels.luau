--[[
	EnemyModels (ModuleScript en ReplicatedStorage)

	Construye el aspecto de cada enemigo con piezas sencillas (slime,
	bestia de 4 patas, humanoide, araña y volador). Lo usa el CLIENTE para
	dibujar la horda (el servidor solo calcula posiciones y vida).
	El modelo tiene una pieza invisible "Root" a ras de suelo: moverla mueve
	todo el enemigo. El frente del enemigo mira hacia -Z.
]]

local EnemyModels = {}

type Builder = (model: Model, def: any, s: number) -> number -- devuelve la altura

local function piece(model: Model, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false -- cientos de enemigos: sin sombras por rendimiento
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

local function eyes(model: Model, y: number, z: number, spread: number, size: number, color: Color3)
	for _, side in { -1, 1 } do
		local eye = piece(model, Vector3.new(size, size, size), CFrame.new(side * spread, y, z), color, Enum.Material.Neon, Enum.PartType.Ball)
		eye.Name = "Ojo"
	end
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function crown(model: Model, y: number, s: number)
	local gold = Color3.fromRGB(250, 204, 21)
	piece(model, Vector3.new(2.2, 0.6, 2.2) * s, CFrame.new(0, y + 0.3 * s, 0), gold, Enum.Material.Metal).Name = "Corona"
	for _, offset in { Vector3.new(-0.8, 0, 0), Vector3.new(0.8, 0, 0), Vector3.new(0, 0, -0.8), Vector3.new(0, 0, 0.8) } do
		piece(model, Vector3.new(0.4, 0.7, 0.4) * s, CFrame.new(offset * s + Vector3.new(0, y + 0.9 * s, 0)), gold, Enum.Material.Metal)
	end
	piece(model, Vector3.new(0.5, 0.5, 0.5) * s, CFrame.new(0, y + 0.4 * s, -1.15 * s), Color3.fromRGB(220, 38, 38), Enum.Material.Neon)
end

local BUILDERS: { [string]: Builder } = {}

BUILDERS.slime = function(model, def, s)
	local body = piece(model, Vector3.new(4.4, 3.6, 4.4) * s, CFrame.new(0, 1.8 * s, 0), def.color, Enum.Material.Glass, Enum.PartType.Ball)
	body.Transparency = 0.25
	body.Name = "Cuerpo"
	piece(model, Vector3.new(2, 1.6, 2) * s, CFrame.new(0, 1.4 * s, 0), darker(def.color, 0.3), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	eyes(model, 2.4 * s, -1.9 * s, 0.7 * s, 0.6 * s, Color3.fromRGB(15, 23, 42))
	return 3.6 * s
end

BUILDERS.beast = function(model, def, s)
	local color = def.color
	local body = piece(model, Vector3.new(2.4, 2.2, 5) * s, CFrame.new(0, 3 * s, 0), color)
	body.Name = "Cuerpo"
	piece(model, Vector3.new(2.1, 2, 2.2) * s, CFrame.new(0, 3.9 * s, -3.2 * s), color).Name = "Cabeza"
	piece(model, Vector3.new(1.1, 0.9, 1.4) * s, CFrame.new(0, 3.5 * s, -4.6 * s), darker(color, 0.25))
	for _, side in { -1, 1 } do
		piece(model, Vector3.new(0.5, 0.9, 0.4) * s, CFrame.new(side * 0.65 * s, 5.2 * s, -3 * s), darker(color, 0.2))
	end
	for _, pos in { Vector3.new(-0.8, 0, -1.8), Vector3.new(0.8, 0, -1.8), Vector3.new(-0.8, 0, 1.8), Vector3.new(0.8, 0, 1.8) } do
		piece(model, Vector3.new(0.7, 2, 0.7) * s, CFrame.new(pos * s + Vector3.new(0, 1 * s, 0)), darker(color, 0.15))
	end
	piece(model, Vector3.new(0.5, 0.5, 2.2) * s, CFrame.new(0, 3.6 * s, 3.2 * s) * CFrame.Angles(math.rad(-25), 0, 0), darker(color, 0.1))
	eyes(model, 4.2 * s, -4.3 * s, 0.5 * s, 0.35 * s, Color3.fromRGB(250, 204, 21))
	return 5.2 * s
end

BUILDERS.humanoid = function(model, def, s)
	local color = def.color
	local material = if def.crystal then Enum.Material.Neon elseif def.stone then Enum.Material.Slate else Enum.Material.SmoothPlastic
	local skin = color
	local cloth = if def.crystal or def.stone then color else darker(color, 0.45)
	for _, side in { -1, 1 } do
		piece(model, Vector3.new(1, 2.4, 1) * s, CFrame.new(side * 0.6 * s, 1.2 * s, 0), darker(cloth, 0.2), material)
		piece(model, Vector3.new(0.9, 2.4, 0.9) * s, CFrame.new(side * 1.7 * s, 3.7 * s, 0), skin, material)
	end
	local torso = piece(model, Vector3.new(2.4, 2.6, 1.3) * s, CFrame.new(0, 3.7 * s, 0), cloth, material)
	torso.Name = "Cuerpo"
	if def.crystal then
		torso.Transparency = 0.2
	end
	piece(model, Vector3.new(1.8, 1.8, 1.8) * s, CFrame.new(0, 5.9 * s, 0), skin, material).Name = "Cabeza"
	eyes(model, 6.05 * s, -0.92 * s, 0.4 * s, 0.32 * s, if def.boss then Color3.fromRGB(239, 68, 68) else Color3.fromRGB(250, 250, 250))
	-- Arma en la mano derecha
	local weaponColor = if def.crystal then Color3.fromRGB(224, 242, 254) else Color3.fromRGB(120, 113, 108)
	piece(model, Vector3.new(0.4, 3.4, 0.4) * s, CFrame.new(1.7 * s, 3.2 * s, -1.4 * s) * CFrame.Angles(math.rad(-70), 0, 0), weaponColor, Enum.Material.Metal).Name = "Arma"
	if def.crown then
		crown(model, 6.8 * s, s)
	end
	return 7 * s
end

BUILDERS.spider = function(model, def, s)
	local color = def.color
	local body = piece(model, Vector3.new(3.4, 2.6, 3.8) * s, CFrame.new(0, 2.2 * s, 0.6 * s), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	body.Name = "Cuerpo"
	piece(model, Vector3.new(2, 1.8, 2) * s, CFrame.new(0, 2 * s, -1.8 * s), darker(color, 0.2), Enum.Material.SmoothPlastic, Enum.PartType.Ball).Name = "Cabeza"
	for i = 0, 3 do
		local z = (-1.4 + i * 0.9) * s
		for _, side in { -1, 1 } do
			piece(model, Vector3.new(3.2, 0.35, 0.35) * s, CFrame.new(side * 2 * s, 1.6 * s, z) * CFrame.Angles(0, 0, side * math.rad(-30)), darker(color, 0.1))
		end
	end
	eyes(model, 2.3 * s, -2.7 * s, 0.4 * s, 0.35 * s, Color3.fromRGB(239, 68, 68))
	return 3.4 * s
end

BUILDERS.flyer = function(model, def, s)
	local color = def.color
	local body: Part
	if def.ghost then
		body = piece(model, Vector3.new(2.6, 3.4, 2.6) * s, CFrame.new(0, 4.6 * s, 0), color, Enum.Material.Neon, Enum.PartType.Ball)
		body.Transparency = 0.45
		piece(model, Vector3.new(1.6, 2.2, 1.6) * s, CFrame.new(0, 2.6 * s, 0.3 * s), color, Enum.Material.Neon, Enum.PartType.Ball).Transparency = 0.6
		eyes(model, 5.1 * s, -1.2 * s, 0.45 * s, 0.4 * s, Color3.fromRGB(15, 23, 42))
	else
		body = piece(model, Vector3.new(2.2, 2.2, 2.2) * s, CFrame.new(0, 4.8 * s, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			piece(model, Vector3.new(3.2, 0.25, 1.8) * s, CFrame.new(side * 2.4 * s, 5 * s, 0) * CFrame.Angles(0, 0, side * math.rad(18)), darker(color, 0.3))
			piece(model, Vector3.new(0.4, 0.8, 0.4) * s, CFrame.new(side * 0.55 * s, 6 * s, -0.2 * s), darker(color, 0.2))
		end
		eyes(model, 5 * s, -1 * s, 0.45 * s, 0.35 * s, Color3.fromRGB(239, 68, 68))
	end
	body.Name = "Cuerpo"
	return 6.4 * s
end

-- Crea el modelo en el origen (Root a ras de suelo) y lo devuelve con su altura.
-- elite = más grande y con un brillo rojo
function EnemyModels.build(def: any, elite: boolean?): (Model, number)
	local model = Instance.new("Model")
	model.Name = def.name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local builder = BUILDERS[def.model] or BUILDERS.humanoid
	local size = def.size * (if elite then 1.7 else 1)
	local height = builder(model, def, size)
	if elite then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(239, 68, 68)
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = root
	end
	if def.boss then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= root then
				part.CastShadow = true
			end
		end
	end
	return model, height
end

return EnemyModels
