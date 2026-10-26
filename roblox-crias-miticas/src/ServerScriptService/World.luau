--[[
	World: construye las 8 islas flotantes (en fila por el eje X), los puentes con su puerta, el
	pedestal del huevo de cada isla, decoración y el punto de aparición.
	Los textos (precios, nombres) los pone el CLIENTE encima, traducidos. Aquí solo hay piezas con
	atributos: Zone en huevos, puertas y centros de isla.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local World = {}

World.SPACING = 200 -- distancia entre centros de isla
World.RADIUS = 62 -- radio de la parte plana de cada isla
World.TOP = 20 -- altura del suelo de las islas

export type ZoneInfo = { center: Vector3, egg: BasePart, door: BasePart?, spawn: CFrame }
World.zones = {} :: { ZoneInfo }

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Cilindro de pie (los cilindros de Roblox van a lo largo de X: se giran 90° en Z)
local function disc(parent: Instance, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	return part(parent, {
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function tree(parent: Instance, base: Vector3, zone: Config.Zone, rng: Random)
	local h = rng:NextNumber(9, 14)
	part(parent, {
		Name = "Tronco", Size = Vector3.new(2.4, h, 2.4), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)),
		Color = zone.dirt, Material = Enum.Material.Wood,
	})
	local r = rng:NextNumber(8, 12)
	part(parent, {
		Name = "Copa", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), CFrame = CFrame.new(base + Vector3.new(0, h + r * 0.3, 0)),
		Color = zone.grass:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Grass,
	})
end

local function rock(parent: Instance, base: Vector3, rng: Random)
	local s = rng:NextNumber(3, 7)
	part(parent, {
		Name = "Roca", Size = Vector3.new(s * 1.3, s, s), CFrame = CFrame.new(base + Vector3.new(0, s * 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.2),
		Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Slate,
	})
end

function World.build(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Mundo"
	local rng = Random.new(7)

	for i, zone in Config.Zones do
		local isle = Instance.new("Model")
		isle.Name = "Isla" .. i
		local center = Vector3.new((i - 1) * World.SPACING, World.TOP, 0)
		-- Suelo (disco), tierra debajo y una punta para que parezca flotante
		local ground = disc(isle, center - Vector3.new(0, 2, 0), 4, World.RADIUS * 2, zone.grass, Enum.Material.Grass)
		ground.Name = "Suelo"
		disc(isle, center - Vector3.new(0, 9, 0), 10, World.RADIUS * 1.8, zone.dirt, Enum.Material.Ground)
		disc(isle, center - Vector3.new(0, 20, 0), 12, World.RADIUS * 1.1, zone.dirt:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Rock)

		-- Pedestal y huevo
		local eggPos = center + Vector3.new(0, 0, -40)
		disc(isle, eggPos + Vector3.new(0, 1, 0), 2, 16, Config.Colors.panelDark, Enum.Material.Marble)
		local egg = part(isle, {
			Name = "Huevo", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 9, 7), CFrame = CFrame.new(eggPos + Vector3.new(0, 6.5, 0)),
			Color = zone.pets[1].color:Lerp(Color3.new(1, 1, 1), 0.55), Material = Enum.Material.SmoothPlastic,
		})
		-- Aro brillante para encontrar el huevo de lejos
		disc(isle, eggPos + Vector3.new(0, 2.1, 0), 0.2, 18, Config.Colors.gold, Enum.Material.Neon).Name = "Aro"
		egg:SetAttribute("Zone", i)
		egg:AddTag("Egg")

		-- Decoración en el borde (deja libre el centro para los montones)
		for n = 1, 9 do
			local a = n / 9 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local d = rng:NextNumber(World.RADIUS - 10, World.RADIUS - 4)
			local pos = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			if math.abs(math.sin(a)) > 0.25 and (pos - eggPos).Magnitude > 22 then -- no tapar puentes ni huevo
				if n % 3 == 0 then
					rock(isle, pos, rng)
				else
					tree(isle, pos, zone, rng)
				end
			end
		end

		-- Puente y puerta hacia la isla siguiente
		local door: BasePart? = nil
		if i > 1 then
			local from = center - Vector3.new(World.SPACING - World.RADIUS + 2, 0, 0)
			local to = center - Vector3.new(World.RADIUS - 2, 0, 0)
			local mid = (from + to) / 2
			local length = (to - from).Magnitude
			part(isle, { Name = "Puente", Size = Vector3.new(length, 2, 18), CFrame = CFrame.new(mid - Vector3.new(0, 1, 0)), Color = Color3.fromRGB(180, 130, 80), Material = Enum.Material.WoodPlanks })
			for _, side in { -1, 1 } do
				part(isle, { Name = "Baranda", Size = Vector3.new(length, 3, 1), CFrame = CFrame.new(mid + Vector3.new(0, 1.5, side * 9)), Color = Color3.fromRGB(140, 95, 60), Material = Enum.Material.Wood })
			end
			local d = part(isle, {
				Name = "Puerta", Size = Vector3.new(2, 40, 18), CFrame = CFrame.new(mid + Vector3.new(0, 20, 0)),
				Color = Config.Colors.sky, Material = Enum.Material.ForceField, Transparency = 0.2,
			})
			d:SetAttribute("Zone", i)
			d:AddTag("Door")
			door = d
		end

		isle.Parent = folder
		World.zones[i] = { center = center, egg = egg, door = door, spawn = CFrame.new(center + Vector3.new(0, 4, 20)) }
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Aparicion"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(World.zones[1].center + Vector3.new(0, 0.5, 25))
	spawn.Color = Config.Colors.gold
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Parent = folder

	local piles = Instance.new("Folder")
	piles.Name = "Montones"
	piles.Parent = folder
	folder.Parent = Workspace

	-- Cielo luminoso y colores vivos
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 170)
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(150, 190, 255)
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Parent = Lighting
	return folder
end

-- Punto al azar para un montón dentro de la isla (lejos del huevo)
function World.pilePosition(zone: number, rng: Random): Vector3
	local info = World.zones[zone]
	for _ = 1, 20 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(10, World.RADIUS - 14)
		local pos = info.center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if (pos - info.egg.Position).Magnitude > 16 then
			return pos
		end
	end
	return info.center + Vector3.new(rng:NextNumber(-20, 20), 0, 20)
end

return World
