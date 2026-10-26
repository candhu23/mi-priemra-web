--[[
	World: el mapa (estilo «juego de mascotas»): UN terreno continuo dividido en 9 zonas cuadradas que se
	encadenan en zigzag por una rejilla de 3×3. Cada zona tiene su suelo y su decoración low-poly, está rodeada
	de acantilados de roca y se pasa a la siguiente por una PUERTA en la pared que las separa.
	También fabrica los cristales (los «montones» que rompen las crías) con World.crystal.
	Además: el Jardín de Mejoras (casilla (-1,0), pegado a la zona 1 por un arco sin puerta) con 12 pedestales unidos
	por caminos de neón, los Altares de Fusión (zona 1 y Jardín) y el cielo de aurora de la zona 9.
	Los textos (precios, nombres) los pone el CLIENTE encima, traducidos. Aquí solo hay piezas con atributos:
	Zone en huevos y puertas, UpgradeId en pedestales, From/To en caminos. Los nombres «Isla<n>», «Jardin», «Suelo»,
	«Huevo», «Puerta», «Pedestal», «Orbe», «Anillo», «Camino», «Altar», «CartelJardin» los usan el cliente y el bot.
	Nota: no se usa CFrame.lookAt (en Lune sale girado al revés): facing() hace lo mismo con fromMatrix.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local World = {}

World.CELL = 200 -- lado de cada zona (studs)
World.TOP = 20 -- altura del suelo
World.GATE = 28 -- ancho del hueco de cada puerta
-- Casilla (columna, fila) de cada zona en la rejilla: un zigzag continuo
-- La 9 (Santuario Aurora) en (2,2): vecina de la 8 → la pared 8|9 sale con puerta; la 4|9, acantilado
World.GRID = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 2, 1 }, { 1, 1 }, { 0, 1 }, { 0, 2 }, { 1, 2 }, { 2, 2 } }

-- Aspecto de cada zona (mismo orden que Config.Zones)
local THEMES = {
	{ ground = Color3.fromRGB(110, 200, 90), mat = Enum.Material.Grass, rock = Color3.fromRGB(90, 95, 105), deco = "meadow" },
	{ ground = Color3.fromRGB(95, 150, 110), mat = Enum.Material.Grass, rock = Color3.fromRGB(80, 70, 100), deco = "mushroom" },
	{ ground = Color3.fromRGB(240, 220, 160), mat = Enum.Material.Sand, rock = Color3.fromRGB(170, 150, 120), deco = "beach" },
	{ ground = Color3.fromRGB(235, 190, 110), mat = Enum.Material.Sand, rock = Color3.fromRGB(190, 120, 70), deco = "desert" },
	{ ground = Color3.fromRGB(80, 70, 70), mat = Enum.Material.Basalt, rock = Color3.fromRGB(55, 45, 45), deco = "volcano" },
	{ ground = Color3.fromRGB(235, 245, 255), mat = Enum.Material.Snow, rock = Color3.fromRGB(140, 160, 185), deco = "glacier" },
	{ ground = Color3.fromRGB(250, 235, 250), mat = Enum.Material.SmoothPlastic, rock = Color3.fromRGB(200, 190, 230), deco = "clouds" },
	{ ground = Color3.fromRGB(60, 50, 110), mat = Enum.Material.Slate, rock = Color3.fromRGB(40, 35, 75), deco = "cosmos" },
	{ ground = Color3.fromRGB(40, 60, 80), mat = Enum.Material.Slate, rock = Color3.fromRGB(30, 40, 60), deco = "aurora" },
}
World.THEMES = THEMES

---------------------------------------------------------------------
-- Modelos 3D de verdad (Kenney Nature Kit, CC0). Los importa el usuario UNA vez en Studio (modelos/LEEME.md) y quedan
-- en ServerStorage.Modelos, o se cargan con Config.MODELS_ASSET_ID (InsertService). Cada modelo «Alias» tiene piezas
-- «Alias__material»: aquí se pintan según el material y la zona. Si no hay modelos, se usan piezas básicas.
---------------------------------------------------------------------
local ServerStorage = game:GetService("ServerStorage")
local ModelColors = require(ReplicatedStorage:WaitForChild("ModelColors")) -- colores de cada pieza (generado)
local modelos: Instance? = nil

local MAT_COLORS: { [string]: Color3 } = {
	leafsGreen = Color3.fromRGB(110, 195, 70), leafsDark = Color3.fromRGB(60, 145, 75), grass = Color3.fromRGB(115, 205, 80),
	dirt = Color3.fromRGB(150, 105, 70), woodBark = Color3.fromRGB(135, 88, 55), woodBarkDark = Color3.fromRGB(100, 66, 45),
	woodInner = Color3.fromRGB(225, 195, 145), stone = Color3.fromRGB(150, 155, 165), _defaultMat = Color3.fromRGB(240, 235, 225),
	colorRed = Color3.fromRGB(225, 60, 60), colorTan = Color3.fromRGB(235, 170, 100), colorYellow = Color3.fromRGB(250, 205, 60),
	colorPurple = Color3.fromRGB(150, 100, 220),
}
-- Cambios de color por zona (mismo orden que Config.Zones)
local ZONE_MATS: { { [string]: Color3 } } = {
	{},
	{ colorRed = Color3.fromRGB(185, 100, 235), colorTan = Color3.fromRGB(110, 140, 240), leafsGreen = Color3.fromRGB(90, 170, 110), grass = Color3.fromRGB(100, 170, 110), stone = Color3.fromRGB(130, 120, 160) },
	{ stone = Color3.fromRGB(215, 190, 150), dirt = Color3.fromRGB(200, 160, 110), leafsGreen = Color3.fromRGB(100, 200, 80) },
	{ stone = Color3.fromRGB(220, 140, 80), dirt = Color3.fromRGB(200, 120, 70), grass = Color3.fromRGB(170, 190, 80), leafsGreen = Color3.fromRGB(90, 170, 80) },
	{ stone = Color3.fromRGB(80, 65, 65), dirt = Color3.fromRGB(90, 60, 55), grass = Color3.fromRGB(255, 110, 40), woodBark = Color3.fromRGB(60, 45, 40) },
	{ leafsDark = Color3.fromRGB(70, 130, 110), stone = Color3.fromRGB(170, 200, 225), grass = Color3.fromRGB(240, 248, 255), leafsGreen = Color3.fromRGB(200, 230, 240) },
	{ leafsGreen = Color3.fromRGB(255, 180, 220), grass = Color3.fromRGB(250, 220, 240), stone = Color3.fromRGB(230, 220, 245), colorRed = Color3.fromRGB(255, 150, 200) },
	{ stone = Color3.fromRGB(90, 70, 150), dirt = Color3.fromRGB(70, 55, 120), grass = Color3.fromRGB(170, 120, 255), leafsGreen = Color3.fromRGB(150, 110, 240) },
	{ stone = Color3.fromRGB(60, 90, 120), dirt = Color3.fromRGB(40, 60, 80), grass = Color3.fromRGB(90, 240, 200), leafsGreen = Color3.fromRGB(255, 130, 220), leafsDark = Color3.fromRGB(90, 200, 230) },
}

local function loadModels()
	-- En ReplicatedStorage (los clientes los necesitan para dibujar las crías); se acepta también ServerStorage
	modelos = ReplicatedStorage:FindFirstChild("Modelos") or ServerStorage:FindFirstChild("Modelos")
	if not modelos and Config.MODELS_ASSET_ID ~= 0 then
		local ok, asset = pcall(function()
			return game:GetService("InsertService"):LoadAsset(Config.MODELS_ASSET_ID)
		end)
		if ok and asset then
			asset.Name = "Modelos"
			asset.Parent = ReplicatedStorage
			modelos = asset
		else
			warn("No se pudieron cargar los modelos 3D (" .. tostring(asset) .. "): se usan piezas básicas")
		end
	end
end

function World.hasModels(): boolean
	return modelos ~= nil
end

-- Coloca una copia del modelo «alias» con la base en «base», girada «yaw» y escalada para que su lado más largo
-- (o su altura, si byHeight) mida «size». Devuelve el modelo y su tamaño final, o nil si no existe.
local function place(alias: string, parent: Instance, base: Vector3, size: number, yaw: number, zone: number, byHeight: boolean, colors: { [string]: Color3 }?, material: Enum.Material?): (Model?, Vector3)
	local tpl = modelos and modelos:FindFirstChild(alias, true)
	if not tpl then
		return nil, Vector3.zero
	end
	local m = tpl:Clone()
	local parts: { BasePart } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		m:Destroy()
		return nil, Vector3.zero
	end
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in parts do
		local h = p.Size / 2
		mn = mn:Min(p.Position - h)
		mx = mx:Max(p.Position + h)
	end
	local ext = mx - mn
	local s = if byHeight then size / math.max(ext.Y, 0.01) else size / math.max(ext.X, ext.Z, 0.01)
	local origin = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	local rot = CFrame.Angles(0, yaw, 0)
	local zoneMats = ZONE_MATS[zone] or {}
	for _, p in parts do
		local rel = (p.Position - origin) * s
		local r = p.CFrame - p.Position
		p.Size = p.Size * s
		p.CFrame = CFrame.new(base + (rot * rel)) * rot * r
		p.Anchored = true
		local key = string.match(p.Name, "__(.+)$") or ""
		local c = (colors and colors[key]) or zoneMats[key] or MAT_COLORS[key] or ModelColors[p.Name]
		if c then
			p.Color = c
			for _, child in p:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			pcall(function()
				(p :: any).TextureID = ""
			end)
		end
		if material then
			p.Material = material
		end
	end
	m.Parent = parent
	return m :: Model, ext * s
end

export type ZoneInfo = { center: Vector3, egg: BasePart, door: BasePart?, spawn: CFrame, entry: Vector3?, exit: Vector3?, gate: Vector3? }
World.zones = {} :: { ZoneInfo }
-- Altares de fusión: de momento solo el PUNTO (zona 1, junto a la aparición) para validar Config.FUSE_REACH.
-- El altar de piedra visible y el del Jardín los pone la ronda 2b
World.altars = {} :: { Vector3 }
-- Pedestales del Jardín de Mejoras: id → punto (a la altura del jugador) para Config.UPGRADE_REACH, y su pieza
World.pedestals = {} :: { [string]: Vector3 }
World.pedestalParts = {} :: { [string]: BasePart }
World.altarParts = {} :: { BasePart }
-- Jardín de Mejoras (casilla (-1,0)): centro y punto de llegada al viajar (teleport 0)
World.garden = nil :: { center: Vector3, spawn: CFrame }?
World.GARDEN_CELL = Vector2.new(-1, 0)
local ALTAR_ZONE1 = Vector3.new(-16, 0, 26) -- desde el centro de la zona 1 (~16 studs de la aparición)
local ALTAR_GARDEN = Vector3.new(70, 0, -60) -- desde el centro del Jardín

---------------------------------------------------------------------
-- Piezas básicas
---------------------------------------------------------------------
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

-- Decoración pequeña: sin colisión ni sombra (rendimiento y para no estorbar)
local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

-- Mirando de «from» hacia «to» (como CFrame.lookAt)
local function facing(from: Vector3, to: Vector3): CFrame
	local forward = (to - from).Unit
	local up = Vector3.new(0, 1, 0)
	if math.abs(forward:Dot(up)) > 0.99 then
		up = Vector3.new(0, 0, 1)
	end
	local right = forward:Cross(up).Unit
	return CFrame.fromMatrix(from, right, right:Cross(forward))
end
World.facing = facing

-- Cilindro de pie (los cilindros de Roblox van a lo largo de X: se giran 90° en Z)
local function disc(parent: Instance, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	return part(parent, {
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function ball(parent: Instance, center: Vector3, d: number, color: Color3, material: Enum.Material?): Part
	return part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(center), Color = color, Material = material or Enum.Material.SmoothPlastic })
end

-- Viga entre dos puntos (troncos inclinados, hojas de palmera)
local function beam(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, color: Color3, material: Enum.Material?): Part
	return part(parent, { Size = Vector3.new(w, h, (b - a).Magnitude), CFrame = facing((a + b) / 2, b), Color = color, Material = material or Enum.Material.SmoothPlastic })
end

---------------------------------------------------------------------
-- Decoración low-poly (base = punto del suelo)
---------------------------------------------------------------------
local LEAF = Color3.fromRGB(120, 200, 70)
local LEAF_DARK = Color3.fromRGB(80, 160, 60)
local WOOD = Color3.fromRGB(120, 80, 50)

local function roundTree(m: Instance, base: Vector3, rng: Random, leaf: Color3?)
	local h = rng:NextNumber(10, 16)
	part(m, { Name = "Tronco", Size = Vector3.new(1.8, h, 1.8), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color = WOOD, Material = Enum.Material.Wood })
	local c = leaf or LEAF
	-- Copa facetada: bloques girados (parece low-poly)
	for i = 1, 3 do
		local s = rng:NextNumber(7, 11) * (1 - i * 0.12)
		deco(part(m, {
			Name = "Copa", Size = Vector3.new(s * 1.3, s * 0.8, s * 1.2),
			CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2), h + i * 1.2, rng:NextNumber(-2, 2))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
			Color = if i == 2 then c:Lerp(Color3.new(1, 1, 0.6), 0.25) else c, Material = Enum.Material.SmoothPlastic,
		}))
	end
end

local function pineTree(m: Instance, base: Vector3, rng: Random, color: Color3?, snow: boolean?)
	local h = rng:NextNumber(14, 22)
	part(m, { Name = "Tronco", Size = Vector3.new(1.6, h * 0.3, 1.6), CFrame = CFrame.new(base + Vector3.new(0, h * 0.15, 0)), Color = WOOD, Material = Enum.Material.Wood })
	for i = 0, 2 do
		local w = h * (0.55 - i * 0.14)
		local y = h * 0.25 + i * h * 0.22
		-- Cada piso: dos bloques en cruz algo inclinados = pirámide low-poly
		for g = 0, 1 do
			deco(part(m, {
				Name = "Pino", Size = Vector3.new(w, h * 0.22, w),
				CFrame = CFrame.new(base + Vector3.new(0, y + h * 0.11, 0)) * CFrame.Angles(0, math.rad(45 * g + 10 * i), 0),
				Color = if snow and i == 2 then Color3.fromRGB(245, 250, 255) else (color or LEAF_DARK), Material = Enum.Material.SmoothPlastic,
			}))
		end
	end
end

local function palm(m: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(14, 20)
	local top = base + Vector3.new(rng:NextNumber(-3, 3), h, rng:NextNumber(-3, 3))
	beam(m, base, top, 1.4, 1.4, Color3.fromRGB(170, 120, 70), Enum.Material.Wood)
	for g = 0, 5 do
		local a = math.rad(60 * g + rng:NextNumber(-10, 10))
		local tip = top + Vector3.new(math.cos(a) * 8, -3, math.sin(a) * 8)
		deco(beam(m, top, tip, 3, 0.4, Color3.fromRGB(90, 180, 70), Enum.Material.SmoothPlastic))
	end
end

local function rock(m: Instance, base: Vector3, rng: Random, color: Color3, size: number?)
	local t = size or rng:NextNumber(3, 7)
	for i = 1, 3 do
		local s = t * (1 - i * 0.18)
		part(m, {
			Name = "Roca", Size = Vector3.new(s * 1.2, s * 0.7, s),
			CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-0.3, 0.3) * t, s * 0.3, rng:NextNumber(-0.3, 0.3) * t))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
			Color = if i == 2 then color:Lerp(Color3.new(0, 0, 0), 0.15) else color, Material = Enum.Material.Rock,
		})
	end
end

local function mushroom(m: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(10, 22)
	local d = h * rng:NextNumber(1.1, 1.5)
	local cap = if rng:NextNumber() < 0.7 then Color3.fromRGB(190, 110, 230) else Color3.fromRGB(110, 140, 240)
	part(m, { Name = "Pie", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, h * 0.18, h * 0.18), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(240, 235, 225) })
	disc(m, base + Vector3.new(0, h, 0), h * 0.14, d, cap).Name = "Sombrero"
	disc(m, base + Vector3.new(0, h + h * 0.1, 0), h * 0.1, d * 0.68, cap:Lerp(Color3.new(1, 1, 1), 0.1)).Name = "Sombrero"
	for _ = 1, 5 do
		local a = rng:NextNumber(0, 6.28)
		local r = rng:NextNumber(0.15, 0.4) * d
		deco(part(m, { Name = "Mancha", Size = Vector3.new(d * 0.12, 0.3, d * 0.12), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, h + h * 0.07 + 0.16, math.sin(a) * r)) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(250, 250, 255) }))
	end
end

local function cactus(m: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(8, 14)
	local green = Color3.fromRGB(80, 160, 80)
	part(m, { Name = "Cactus", Size = Vector3.new(2.4, h, 2.4), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)), Color = green, Material = Enum.Material.SmoothPlastic })
	for _, side in { -1, 1 } do
		local y = h * rng:NextNumber(0.35, 0.6)
		deco(part(m, { Name = "Brazo", Size = Vector3.new(3, 1.8, 1.8), CFrame = CFrame.new(base + Vector3.new(side * 2.4, y, 0)), Color = green }))
		deco(part(m, { Name = "Brazo", Size = Vector3.new(1.8, h * 0.3, 1.8), CFrame = CFrame.new(base + Vector3.new(side * 3.6, y + h * 0.15 - 0.9, 0)), Color = green }))
	end
end

local function cloud(m: Instance, base: Vector3, rng: Random, high: boolean?)
	local y = if high then rng:NextNumber(25, 45) else 2
	for _ = 1, 4 do
		deco(ball(m, base + Vector3.new(rng:NextNumber(-5, 5), y + rng:NextNumber(0, 3), rng:NextNumber(-5, 5)), rng:NextNumber(5, 9), Color3.fromRGB(255, 255, 255)))
	end
end

local function iceSpike(m: Instance, base: Vector3, rng: Random, color: Color3, neon: boolean?)
	for _ = 1, 3 do
		local h = rng:NextNumber(5, 11)
		part(m, {
			Name = "Hielo", Size = Vector3.new(h * 0.3, h, h * 0.3),
			CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2), h * 0.4, rng:NextNumber(-2, 2))) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35)),
			Color = color, Material = if neon then Enum.Material.Neon else Enum.Material.Glass, Transparency = if neon then 0 else 0.15,
		})
	end
end

local function lavaPool(m: Instance, base: Vector3, rng: Random)
	local d = rng:NextNumber(10, 18)
	deco(disc(m, base + Vector3.new(0, 0.15, 0), 0.3, d + 3, Color3.fromRGB(45, 35, 35), Enum.Material.Basalt))
	deco(disc(m, base + Vector3.new(0, 0.25, 0), 0.3, d, Color3.fromRGB(255, 110, 30), Enum.Material.Neon)).Name = "Lava"
end

local function volcanoCone(m: Instance, base: Vector3)
	for i = 0, 4 do
		local d = 60 - i * 11
		disc(m, base + Vector3.new(0, 4 + i * 8, 0), 8.2, d, Color3.fromRGB(70, 55, 55), Enum.Material.Basalt).Name = "Volcan"
	end
	deco(disc(m, base + Vector3.new(0, 4 + 4 * 8 + 4.3, 0), 0.4, 13, Color3.fromRGB(255, 120, 30), Enum.Material.Neon)).Name = "Lava"
end

local function water(m: Instance, base: Vector3, sx: number, sz: number)
	deco(part(m, { Name = "Agua", Size = Vector3.new(sx, 0.4, sz), CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)), Color = Color3.fromRGB(80, 180, 240), Material = Enum.Material.Glass, Transparency = 0.25 }))
end

local function log(m: Instance, base: Vector3, rng: Random)
	deco(part(m, { Name = "Tronco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(rng:NextNumber(4, 7), 1.6, 1.6), CFrame = CFrame.new(base + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(140, 80, 50), Material = Enum.Material.Wood }))
end

local function flowers(m: Instance, base: Vector3, rng: Random)
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 220, 80), Color3.fromRGB(120, 140, 255), Color3.fromRGB(255, 150, 220) }
	for _ = 1, 3 do
		local p = base + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		deco(part(m, { Name = "Tallo", Size = Vector3.new(0.3, 2, 0.3), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)), Color = LEAF_DARK }))
		deco(part(m, { Name = "Flor", Size = Vector3.new(1.2, 0.5, 1.2), CFrame = CFrame.new(p + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = colors[rng:NextInteger(1, #colors)] }))
	end
end

-- Losas de piedra irregulares a lo largo de un camino
local function path(m: Instance, a: Vector3, b: Vector3, rng: Random, color: Color3)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local n = math.floor(len / 5)
	for i = 0, n do
		local p = a + dir * (i * 5) + side * rng:NextNumber(-3, 3)
		deco(part(m, {
			Name = "Losa", Size = Vector3.new(rng:NextNumber(3.5, 6), 0.3, rng:NextNumber(3.5, 6)),
			CFrame = CFrame.new(p + Vector3.new(0, 0.15 + (i % 3) * 0.01, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			Color = color, Material = Enum.Material.Slate,
		}))
	end
end

-- Decoración según el tema, en el punto dado. big = cosas grandes (borde de la zona)
-- Qué modelos de Kenney van en cada tema: { alias, tamaño mín., tamaño máx. } (tamaño = altura)
local DECO_MODELS: { [string]: { { any } } } = {
	meadow = { { "Roble", 14, 20 }, { "Arbol", 16, 22 }, { "ArbolDetallado", 14, 20 }, { "ArbolGordo", 12, 16 }, { "Arbusto", 3, 5 }, { "FlorRoja", 2, 3 }, { "FlorAmarilla", 2, 3 }, { "RocaDeco", 3, 5 }, { "Tronco", 3, 4 }, { "Tocon", 2, 3 }, { "Hierba", 2, 3 } },
	mushroom = { { "SetaRoja", 10, 18 }, { "SetaAlta", 12, 24 }, { "SetaTan", 10, 20 }, { "SetaAlta", 8, 14 }, { "Arbusto", 3, 5 }, { "FlorMorada", 2, 3 }, { "RocaDeco", 3, 5 } },
	beach = { { "Palmera", 16, 24 }, { "PalmeraCurva", 16, 22 }, { "Palmera", 14, 20 }, { "RocaDeco", 3, 6 }, { "Arbusto2", 3, 4 }, { "Hierba", 2, 3 } },
	desert = { { "CactusAlto", 8, 14 }, { "CactusBajo", 6, 9 }, { "RocaAlta", 10, 18 }, { "RocaDeco", 4, 7 }, { "PiedraC", 3, 5 } },
	volcano = { { "RocaAlta", 10, 20 }, { "PiedraAlta", 8, 14 }, { "PiedraB", 3, 5 }, { "Tocon", 2, 3 } },
	glacier = { { "Pino", 16, 26 }, { "PinoRedondo", 14, 22 }, { "ArbolCono", 12, 18 }, { "PiedraAlta", 6, 10 } },
	clouds = { { "ArbolGordo", 10, 16 }, { "Arbusto", 3, 5 }, { "FlorRoja", 2, 3 }, { "FlorMorada", 2, 3 } },
	cosmos = { { "PiedraAlta", 8, 16 }, { "PiedraAltaB", 8, 14 }, { "RocaAlta", 10, 18 } },
	aurora = { { "Pino", 14, 22 }, { "ArbolCono", 12, 18 }, { "PiedraAlta", 8, 14 }, { "RocaAlta", 10, 16 } },
}

local function decorate(m: Instance, theme: string, pos: Vector3, rng: Random, big: boolean, rockColor: Color3, zone: number?)
	local list = DECO_MODELS[theme]
	-- Con modelos: casi todo es un modelo de verdad; algunas cosas especiales (lava, nubes, cristales) siguen con piezas
	local special = (theme == "volcano" and rng:NextNumber() < 0.3) or (theme == "clouds" and rng:NextNumber() < 0.4) or (theme == "cosmos" and rng:NextNumber() < 0.35)
		or (theme == "aurora" and rng:NextNumber() < 0.4)
	if modelos and list and not special then
		local pick = list[rng:NextInteger(1, #list)]
		local placed = place(pick[1], m, pos, rng:NextNumber(pick[2], pick[3]), rng:NextNumber(0, 6.28), zone or 1, true)
		if placed then
			return
		end
	end
	local r = rng:NextNumber()
	if theme == "meadow" then
		if r < 0.5 then roundTree(m, pos, rng) elseif r < 0.7 then rock(m, pos, rng, rockColor) elseif r < 0.85 then log(m, pos, rng) else flowers(m, pos, rng) end
	elseif theme == "mushroom" then
		if r < 0.65 then mushroom(m, pos, rng) elseif r < 0.85 then rock(m, pos, rng, rockColor) else flowers(m, pos, rng) end
	elseif theme == "beach" then
		if r < 0.55 then palm(m, pos, rng) elseif r < 0.8 then rock(m, pos, rng, rockColor) else iceSpike(m, pos, rng, Color3.fromRGB(255, 160, 190)) end
	elseif theme == "desert" then
		if r < 0.55 then cactus(m, pos, rng) else rock(m, pos, rng, rockColor, if big then rng:NextNumber(6, 11) else nil) end
	elseif theme == "volcano" then
		if r < 0.45 then rock(m, pos, rng, rockColor, rng:NextNumber(4, 9)) elseif r < 0.8 then lavaPool(m, pos, rng) else iceSpike(m, pos, rng, Color3.fromRGB(255, 110, 40), true) end
	elseif theme == "glacier" then
		if r < 0.55 then pineTree(m, pos, rng, Color3.fromRGB(70, 130, 100), true) elseif r < 0.8 then iceSpike(m, pos, rng, Color3.fromRGB(170, 225, 255)) else rock(m, pos, rng, rockColor) end
	elseif theme == "clouds" then
		if r < 0.5 then cloud(m, pos, rng, false) elseif r < 0.75 then cloud(m, pos, rng, true) else iceSpike(m, pos, rng, Color3.fromRGB(255, 200, 240)) end
	elseif theme == "aurora" then
		-- Cristales de adorno turquesa/rosa (el aspecto bonito lo pule la ronda 2b)
		if r < 0.5 then iceSpike(m, pos, rng, if rng:NextNumber() < 0.5 then Color3.fromRGB(90, 240, 200) else Color3.fromRGB(255, 120, 220), true) elseif r < 0.8 then pineTree(m, pos, rng, Color3.fromRGB(60, 150, 140), false) else rock(m, pos, rng, rockColor) end
	else -- cosmos
		if r < 0.45 then iceSpike(m, pos, rng, Color3.fromRGB(170, 120, 255), true) elseif r < 0.75 then rock(m, pos, rng, rockColor) else deco(ball(m, pos + Vector3.new(0, rng:NextNumber(20, 40), 0), rng:NextNumber(4, 10), Color3.fromRGB(120, 100, 200), Enum.Material.Slate)) end
	end
end

---------------------------------------------------------------------
-- Acantilados y puertas
---------------------------------------------------------------------
-- Pared de roca a lo largo de un borde (de a a b), con un hueco central si gap > 0
local function cliffWall(m: Instance, a: Vector3, b: Vector3, height: number, color: Color3, rng: Random, gap: number)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local outward = Vector3.new(-dir.Z, 0, dir.X)
	local t = 0
	while t < len do
		local w = rng:NextNumber(18, 32)
		local mid = t + w / 2
		local inGap = gap > 0 and math.abs(mid - len / 2) < (gap / 2 + w / 2)
		if inGap then
			t = len / 2 + gap / 2 -- saltar el hueco
		else
			local h = height * rng:NextNumber(0.8, 1.2)
			local depth = rng:NextNumber(14, 24)
			local c = a + dir * mid + outward * rng:NextNumber(-3, 3)
			part(m, {
				Name = "Acantilado", Size = Vector3.new(w + 6, h, depth),
				CFrame = CFrame.fromMatrix(c + Vector3.new(0, h / 2 - 2, 0), dir, Vector3.new(0, 1, 0)) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.06, 0.06)),
				Color = color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)), Material = Enum.Material.Rock,
			})
			t += w
		end
	end
end

---------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------
local function cellCenter(i: number): Vector3
	local g = World.GRID[i]
	return Vector3.new(g[1] * World.CELL, World.TOP, g[2] * World.CELL)
end

local function zoneAt(col: number, row: number): number
	for i, g in World.GRID do
		if g[1] == col and g[2] == row and Config.Zones[i] then
			return i
		end
	end
	return 0
end

-- ProximityPrompt (el texto lo traduce cada cliente)
local function prompt(parent: Instance, name: string, hold: number): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = name
	pp.MaxActivationDistance = Config.PROMPT_REACH
	pp.HoldDuration = hold
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

-- Altar de Fusión: plataforma redonda de piedra con un círculo mágico morado, 4 cristales y un orbe flotando.
-- La pieza «Altar» (la base) lleva la etiqueta FuseStation y el ProximityPrompt que abre la ventana de fusión
local function makeAltar(parent: Instance, pos: Vector3): BasePart
	local m = Instance.new("Model")
	m.Name = "AltarFusion"
	local base = disc(m, pos + Vector3.new(0, 0.5, 0), 1, 16, Color3.fromRGB(125, 120, 140), Enum.Material.Slate)
	base.Name = "Altar"
	deco(disc(m, pos + Vector3.new(0, 1.05, 0), 0.12, 14, Config.Colors.purple, Enum.Material.Neon)).Name = "Circulo"
	deco(disc(m, pos + Vector3.new(0, 1.1, 0), 0.12, 12.4, Color3.fromRGB(60, 50, 95), Enum.Material.Slate))
	deco(disc(m, pos + Vector3.new(0, 1.15, 0), 0.12, 8, Color3.fromRGB(200, 140, 255), Enum.Material.Neon)).Name = "Circulo"
	deco(disc(m, pos + Vector3.new(0, 1.2, 0), 0.12, 6.6, Color3.fromRGB(60, 50, 95), Enum.Material.Slate))
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local c = pos + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		deco(part(m, {
			Name = "Cristal", Size = Vector3.new(1.1, 4.5, 1.1), CFrame = CFrame.new(c + Vector3.new(0, 3, 0)) * CFrame.Angles(0, a, 0.15),
			Color = if k % 2 == 0 then Color3.fromRGB(190, 120, 255) else Color3.fromRGB(110, 220, 255), Material = Enum.Material.Neon,
		}))
	end
	local orb = deco(ball(m, pos + Vector3.new(0, 6, 0), 2.6, Color3.fromRGB(220, 170, 255), Enum.Material.Neon))
	orb.Name = "OrbeAltar"
	local light = Instance.new("PointLight")
	light.Color = Config.Colors.purple
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = orb
	base:AddTag("FuseStation")
	prompt(base, "Fusionar", 0)
	m.Parent = parent
	table.insert(World.altars, pos)
	table.insert(World.altarParts, base)
	return base
end

-- Huevo del color de su rareza sobre el pilar (base = arriba del pilar). Devuelve la pieza «Huevo» (atributo Zone y
-- etiqueta Egg la pone quien llama): con modelos, caja invisible con el modelo «Huevo» dentro; sin modelos, un
-- elipsoide con manchas. Desde Épica, luz; Legendario y Prodigioso, manchas de neón
local function makeEgg(parent: Instance, base: Vector3, rarity: number, rng: Random): BasePart
	local ec = Config.EggColors[rarity] or Config.EggColors[1]
	local center = base + Vector3.new(0, 4.5, 0)
	local egg = part(parent, {
		Name = "Huevo", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 9, 7), CFrame = CFrame.new(center),
		Color = ec.shell, Material = Enum.Material.SmoothPlastic,
	})
	local spotsNeon = ec.glow >= 10
	local model = if modelos then place("Huevo", egg, base, 9, rng:NextNumber(0, 6.28), 1, true, { eggShell = ec.shell, eggSpots = ec.spots }) else nil
	if model then
		egg.Transparency = 1
		egg.CanCollide = false
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				if spotsNeon and string.match(d.Name, "eggSpots$") then
					d.Material = Enum.Material.Neon
				end
			end
		end
	else
		-- Manchas medio hundidas en la cáscara (posición fija: el rng del mundo tiene semilla)
		for k = 1, ec.spotCount do
			local a = k / ec.spotCount * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local y = rng:NextNumber(-0.55, 0.6)
			local r = math.sqrt(math.max(0.05, 1 - y * y))
			local d = rng:NextNumber(1.2, 2.2)
			deco(ball(egg, center + Vector3.new(math.cos(a) * r * 3.4, y * 4.4, math.sin(a) * r * 3.4), d, ec.spots,
				if spotsNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic)).Name = "Mancha"
		end
	end
	if ec.glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = ec.shell
		light.Range = ec.glow
		light.Brightness = 1.2
		light.Parent = egg
	end
	return egg
end

-- Cielo de la zona 9: cintas de aurora, anillo-portal de neón, estrellas e islotes flotantes con cristales
local function auroraSky(m: Instance, center: Vector3, rng: Random)
	local tints = { Color3.fromRGB(90, 240, 200), Color3.fromRGB(120, 170, 255), Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 120, 220) }
	for r = 1, 3 do
		local z0 = -60 + r * 30
		local y0 = 55 + r * 8
		for k = 0, 11 do
			local x = -88 + k * 16
			local p = center + Vector3.new(x, y0 + math.sin(k * 0.7 + r) * 6, z0 + math.cos(k * 0.5 + r) * 10)
			deco(part(m, {
				Name = "Aurora", Size = Vector3.new(16, 12, 0.4), CFrame = CFrame.new(p) * CFrame.Angles(0, math.sin(k + r) * 0.3, 0),
				Color = tints[(k + r) % #tints + 1], Material = Enum.Material.Neon, Transparency = 0.45,
			}))
		end
	end
	-- Anillo-portal en el centro de la isla (16 bloques de neón en círculo, de pie)
	local ring = center + Vector3.new(-45, 0, -45)
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		deco(part(m, {
			Name = "Portal", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(ring + Vector3.new(math.cos(a) * 14, 16 + math.sin(a) * 14, 0)) * CFrame.Angles(0, 0, a),
			Color = tints[k % #tints + 1], Material = Enum.Material.Neon,
		}))
	end
	disc(m, ring + Vector3.new(0, 0.5, 0), 1, 22, Color3.fromRGB(60, 80, 110), Enum.Material.Slate).Name = "PortalBase"
	-- Estrellas e islotes flotantes
	for _ = 1, 18 do
		deco(ball(m, center + Vector3.new(rng:NextNumber(-90, 90), rng:NextNumber(30, 70), rng:NextNumber(-90, 90)), rng:NextNumber(0.8, 1.8), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)).Name = "Estrella"
	end
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * 60, rng:NextNumber(24, 40), math.sin(a) * 60)
		deco(part(m, { Name = "Islote", Size = Vector3.new(10, 4, 9), CFrame = CFrame.new(p) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(50, 65, 90), Material = Enum.Material.Slate }))
		deco(part(m, { Name = "Islote", Size = Vector3.new(6, 5, 5), CFrame = CFrame.new(p - Vector3.new(0, 4, 0)) * CFrame.Angles(0, a + 0.5, 0.3), Color = Color3.fromRGB(40, 50, 75), Material = Enum.Material.Slate }))
		deco(part(m, { Name = "Cristal", Size = Vector3.new(1.4, 6, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 5, 0)) * CFrame.Angles(0.1, a, 0.15), Color = tints[k % #tints + 1], Material = Enum.Material.Neon }))
	end
end

-- Distancia de un punto a un segmento (en el suelo), para no poner adornos encima de los caminos del Jardín
local function segDist(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (ap - ab * t).Magnitude
end

-- Jardín de Mejoras: suelo de césped, 3 paredes de acantilado (la 4.ª es la de la zona 1, con el arco), 12 pedestales
-- (cilindro de piedra + anillo + orbe; el cliente los pinta: verde comprado, amarillo se puede, gris bloqueado), caminos
-- de neón entre ellos (Config.Upgrades[i].req), un Altar de Fusión, cartel de entrada y árboles en los bordes
local function buildGarden(folder: Instance, rng: Random)
	local half = World.CELL / 2
	local center = Vector3.new(World.GARDEN_CELL.X * World.CELL, World.TOP, World.GARDEN_CELL.Y * World.CELL)
	local m = Instance.new("Model")
	m.Name = "Jardin"
	local ground = part(m, {
		Name = "Suelo", Size = Vector3.new(World.CELL, 4, World.CELL), CFrame = CFrame.new(center - Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(80, 170, 90), Material = Enum.Material.Grass,
	})
	ground.CanQuery = true
	local rockColor = Color3.fromRGB(95, 105, 100)
	for _, s in { { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local nrm = Vector3.new(s[1], 0, s[2])
		local along = Vector3.new(-s[2], 0, s[1])
		local edge = center + nrm * half
		cliffWall(m, edge - along * half, edge + along * half, rng:NextNumber(55, 70), rockColor, rng, 0)
	end
	-- Pedestales
	local spots: { Vector3 } = {}
	for _, u in Config.Upgrades do
		local pos = center + Vector3.new(u.pos.X, 0, u.pos.Y)
		spots[#spots + 1] = pos
		local base = disc(m, pos + Vector3.new(0, 1.5, 0), 3, 10, Color3.fromRGB(150, 150, 160), Enum.Material.Rock)
		base.Name = "Pedestal"
		base:SetAttribute("UpgradeId", u.id)
		base:AddTag("Upgrade")
		local ring = deco(disc(m, pos + Vector3.new(0, 3.05, 0), 0.2, 11, Color3.fromRGB(100, 116, 139), Enum.Material.SmoothPlastic))
		ring.Name = "Anillo"
		ring:SetAttribute("UpgradeId", u.id)
		local orb = deco(ball(m, pos + Vector3.new(0, 5.6, 0), 4, Color3.fromRGB(100, 116, 139), Enum.Material.SmoothPlastic))
		orb.Name = "Orbe"
		orb:SetAttribute("UpgradeId", u.id)
		prompt(base, "Comprar", 0.5)
		World.pedestals[u.id] = pos + Vector3.new(0, 3, 0)
		World.pedestalParts[u.id] = base
	end
	-- Caminos de neón (de centro a centro; el 4–10 sale en diagonal)
	local segs: { { Vector3 } } = {}
	for _, u in Config.Upgrades do
		for _, r in u.req do
			local a = (World.pedestals[r] :: Vector3) - Vector3.new(0, 3, 0)
			local b = (World.pedestals[u.id] :: Vector3) - Vector3.new(0, 3, 0)
			local link = deco(part(m, {
				Name = "Camino", Size = Vector3.new(3, 0.3, (b - a).Magnitude), CFrame = facing((a + b) / 2 + Vector3.new(0, 0.2, 0), b + Vector3.new(0, 0.2, 0)),
				Color = Color3.fromRGB(100, 116, 139), Material = Enum.Material.Neon,
			}))
			link:SetAttribute("From", r)
			link:SetAttribute("To", u.id)
			link:AddTag("UpgradeLink")
			table.insert(segs, { a, b })
		end
	end
	-- Altar de fusión del Jardín y cartel de entrada (el cliente pone el texto y las piedras que tienes)
	local altarPos = center + ALTAR_GARDEN
	makeAltar(m, altarPos)
	local signPos = center + Vector3.new(half - 14, 0, -22)
	part(m, { Name = "Poste", Size = Vector3.new(1, 8, 1), CFrame = CFrame.new(signPos + Vector3.new(0, 4, 0)), Color = WOOD, Material = Enum.Material.Wood })
	part(m, { Name = "CartelJardin", Size = Vector3.new(0.6, 4, 9), CFrame = CFrame.new(signPos + Vector3.new(0, 9, 0)), Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.WoodPlanks })
	-- Árboles y flores en los bordes, sin tapar pedestales, caminos, altar ni la entrada
	local entrance = center + Vector3.new(half - 10, 0, 0)
	local function free(p: Vector3): boolean
		if (p - entrance).Magnitude < 30 or (p - altarPos).Magnitude < 16 or (p - signPos).Magnitude < 8 then
			return false
		end
		for _, q in spots do
			if (p - q).Magnitude < 14 then
				return false
			end
		end
		for _, sg in segs do
			if segDist(p, sg[1], sg[2]) < 6 then
				return false
			end
		end
		return true
	end
	for _ = 1, 40 do
		local s = rng:NextInteger(1, 4)
		local t = rng:NextNumber(-half + 22, half - 22)
		local inset = rng:NextNumber(18, 30)
		local p = if s == 1 then center + Vector3.new(half - inset, 0, t)
			elseif s == 2 then center + Vector3.new(-half + inset, 0, t)
			elseif s == 3 then center + Vector3.new(t, 0, half - inset)
			else center + Vector3.new(t, 0, -half + inset)
		if free(p) then
			decorate(m, "meadow", p, rng, true, rockColor, 1)
		end
	end
	for _ = 1, 30 do
		local p = center + Vector3.new(rng:NextNumber(-half + 20, half - 20), 0, rng:NextNumber(-half + 20, half - 20))
		if free(p) then
			flowers(m, p, rng)
		end
	end
	m.Parent = folder
	World.garden = { center = center, spawn = CFrame.new(entrance + Vector3.new(-12, 4, 0)) }
end

-- Arco de hojas en el hueco de la pared oeste de la zona 1 (paso al Jardín, sin puerta)
local function gardenArch(m: Instance, edge: Vector3, along: Vector3)
	for _, sgn in { -1, 1 } do
		part(m, { Name = "Columna", Size = Vector3.new(5, 30, 5), CFrame = CFrame.new(edge + along * sgn * (World.GATE / 2 + 2.5) + Vector3.new(0, 15, 0)), Color = Color3.fromRGB(150, 140, 130), Material = Enum.Material.Cobblestone })
	end
	for k = -3, 3 do
		deco(part(m, {
			Name = "ArcoJardin", Size = Vector3.new(7, 6, 7), CFrame = CFrame.new(edge + along * k * 5 + Vector3.new(0, 31 - math.abs(k) * 0.8, 0)) * CFrame.Angles(0.2 * k, k, 0),
			Color = if k % 2 == 0 then LEAF else LEAF_DARK, Material = Enum.Material.SmoothPlastic,
		}))
	end
end

function World.build(): Folder
	loadModels()
	local folder = Instance.new("Folder")
	folder.Name = "Mundo"
	local rng = Random.new(7)
	local half = World.CELL / 2

	for i, zone in Config.Zones do
		local theme = THEMES[i] or THEMES[1]
		local m = Instance.new("Model")
		m.Name = "Isla" .. i
		local center = cellCenter(i)
		local ground = part(m, {
			Name = "Suelo", Size = Vector3.new(World.CELL, 4, World.CELL), CFrame = CFrame.new(center - Vector3.new(0, 2, 0)),
			Color = theme.ground, Material = theme.mat,
		})
		ground.CanQuery = true

		-- Por dónde se entra (desde la zona anterior) y se sale (a la siguiente): puntos en el borde
		local function edgeToward(other: number): Vector3
			local d = cellCenter(other) - center
			return center + Vector3.new(math.sign(d.X), 0, math.sign(d.Z)) * (half - 12)
		end
		local entry = if i > 1 then edgeToward(i - 1) else center + Vector3.new(0, 0, half - 30)
		local exit = if Config.Zones[i + 1] then edgeToward(i + 1) else nil

		-- Paredes: los 4 lados. Sin vecino o vecino no encadenado = acantilado entero;
		-- vecino encadenado (i ± 1) = pared con puerta. Cada lado compartido lo construye la zona de número menor.
		local g = World.GRID[i]
		local door: BasePart? = nil
		for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local other = zoneAt(g[1] + s[1], g[2] + s[2])
			local nrm = Vector3.new(s[1], 0, s[2])
			local along = Vector3.new(-s[2], 0, s[1])
			local edge = center + nrm * half
			local a, b = edge - along * half, edge + along * half
			local toGarden = g[1] + s[1] == World.GARDEN_CELL.X and g[2] + s[2] == World.GARDEN_CELL.Y
			if toGarden then
				-- Paso al Jardín de Mejoras: hueco sin puerta (siempre abierto) con un arco de hojas
				cliffWall(m, a, b, rng:NextNumber(55, 70), theme.rock, rng, World.GATE)
				gardenArch(m, edge, along)
			elseif other == 0 then
				cliffWall(m, a, b, rng:NextNumber(55, 70), theme.rock, rng, 0)
			elseif other > i then
				local chained = other == i + 1
				cliffWall(m, a, b, 34, theme.rock:Lerp(THEMES[other].rock, 0.5), rng, if chained then World.GATE else 0)
				if chained then
					-- Puerta de la zona siguiente en el hueco (ancho del hueco, de pie, perpendicular al paso)
					local d = part(m, {
						Name = "Puerta", Size = Vector3.new(World.GATE, 40, 2),
						CFrame = CFrame.fromMatrix(edge + Vector3.new(0, 20, 0), along, Vector3.new(0, 1, 0)),
						Color = Config.Colors.sky, Material = Enum.Material.ForceField, Transparency = 0.2,
					})
					d:SetAttribute("Zone", other)
					d:AddTag("Door")
					-- Columnas de la puerta
					for _, sgn in { -1, 1 } do
						part(m, { Name = "Columna", Size = Vector3.new(5, 42, 5), CFrame = CFrame.new(edge + along * sgn * (World.GATE / 2 + 2.5) + Vector3.new(0, 19, 0)), Color = Color3.fromRGB(150, 140, 130), Material = Enum.Material.Cobblestone })
					end
					part(m, { Name = "Dintel", Size = Vector3.new(World.GATE + 14, 5, 6), CFrame = CFrame.fromMatrix(edge + Vector3.new(0, 42.5, 0), along, Vector3.new(0, 1, 0)), Color = Color3.fromRGB(130, 90, 60), Material = Enum.Material.WoodPlanks })
					World.zones[other] = World.zones[other] or ({} :: any)
					;(World.zones[other] :: any).door = d
				end
			end
		end
		door = (World.zones[i] and World.zones[i].door) or nil

		-- Huevo sobre un pilar de piedra, a un lado de la entrada (se ve nada más entrar)
		local inDir = (center - entry)
		inDir = Vector3.new(inDir.X, 0, inDir.Z).Unit
		local sideDir = Vector3.new(-inDir.Z, 0, inDir.X)
		local eggBase = entry + inDir * 30 + sideDir * 26
		part(m, { Name = "Pilar", Size = Vector3.new(10, 6, 10), CFrame = CFrame.new(eggBase + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Rock })
		deco(disc(m, eggBase + Vector3.new(0, 6.1, 0), 0.2, 12, Config.Colors.gold, Enum.Material.Neon)).Name = "Aro"
		local egg = makeEgg(m, eggBase + Vector3.new(0, 6, 0), zone.eggRarity, rng) -- color de su rareza
		egg:SetAttribute("Zone", i)
		egg:AddTag("Egg")

		-- Caminos de losas: entrada → centro → salida
		local pathColor = Color3.fromRGB(185, 190, 205)
		path(m, entry, center, rng, pathColor)
		if exit then
			path(m, center, exit, rng, pathColor)
		end

		-- Decoración: muchas cosas pegadas a las paredes y unas pocas dentro
		local gardenGate = if i == 1 then center + Vector3.new(-half + 12, 0, 0) else nil
		local altarSpot = if i == 1 then center + ALTAR_ZONE1 else nil
		local function freeSpot(p: Vector3): boolean
			if (p - eggBase).Magnitude < 16 or (altarSpot and (p - altarSpot).Magnitude < 16) then
				return false
			end
			for _, gate in { entry, exit, gardenGate } do
				if gate and (p - gate).Magnitude < 26 then
					return false
				end
			end
			return true
		end
		for _ = 1, 48 do
			local s = rng:NextInteger(1, 4)
			local t = rng:NextNumber(-half + 22, half - 22)
			local inset = rng:NextNumber(20, 38) -- las rocas de la pared entran ~15 studs: más dentro no se ve
			local p = if s == 1 then center + Vector3.new(half - inset, 0, t)
				elseif s == 2 then center + Vector3.new(-half + inset, 0, t)
				elseif s == 3 then center + Vector3.new(t, 0, half - inset)
				else center + Vector3.new(t, 0, -half + inset)
			if freeSpot(p) then
				decorate(m, theme.deco, p, rng, true, theme.rock, i)
			end
		end
		for _ = 1, 18 do
			local p = center + Vector3.new(rng:NextNumber(-half + 40, half - 40), 0, rng:NextNumber(-half + 40, half - 40))
			if freeSpot(p) and (p - center).Magnitude > 20 then
				if rng:NextNumber() < 0.45 then
					decorate(m, theme.deco, p, rng, false, theme.rock, i)
				elseif theme.deco == "meadow" or theme.deco == "mushroom" then
					flowers(m, p, rng)
				else
					rock(m, p, rng, theme.rock, rng:NextNumber(2, 4))
				end
			end
		end
		-- Algo grande que se reconozca de lejos en algunas zonas
		if theme.deco == "beach" then
			water(m, center + Vector3.new(half - 35, 0, -half + 35), 50, 50)
		elseif theme.deco == "volcano" then
			volcanoCone(m, center + Vector3.new(-half + 45, 0, -half + 45))
		elseif theme.deco == "aurora" then
			auroraSky(m, center, rng)
		end
		if altarSpot then
			makeAltar(m, altarSpot)
		end

		m.Parent = folder
		World.zones[i] = World.zones[i] or ({} :: any)
		local info = World.zones[i] :: any
		info.center = center
		info.egg = egg
		info.door = door
		info.entry = entry
		info.exit = exit
		info.gate = gardenGate
		-- Al viajar se aparece cerca del centro, mirando hacia dentro
		info.spawn = CFrame.new(center + Vector3.new(0, 4, 0) + (entry - center) * 0.3)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Aparicion"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(World.zones[1].center + Vector3.new(0, 0.5, 30))
	spawn.Color = Config.Colors.gold
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Parent = folder
	-- Jardín de Mejoras (con su altar); el de la zona 1 ya se puso con la isla (~16 studs de la aparición)
	buildGarden(folder, rng)

	local piles = Instance.new("Folder")
	piles.Name = "Montones"
	piles.Parent = folder
	folder.Parent = Workspace

	-- Cielo luminoso y colores vivos (como los juegos de mascotas)
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 180)
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.2
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(150, 190, 255)
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.05
	cc.Parent = Lighting
	return folder
end

-- ¿Está esta posición junto a algún Altar de Fusión?
function World.nearAltar(pos: Vector3): boolean
	for _, a in World.altars do
		if (Vector3.new(pos.X, a.Y, pos.Z) - a).Magnitude <= Config.FUSE_REACH then
			return true
		end
	end
	return false
end

-- Punto al azar para un cristal dentro de la zona (lejos de paredes, huevo y puertas)
function World.pilePosition(zone: number, rng: Random): Vector3
	local info = World.zones[zone]
	local half = World.CELL / 2 - 30
	for _ = 1, 30 do
		local pos = info.center + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		local ok = (pos - Vector3.new(info.egg.Position.X, pos.Y, info.egg.Position.Z)).Magnitude > 16
		for _, gate in { info.entry, info.exit, info.gate } do
			if gate and (pos - gate).Magnitude < 22 then
				ok = false
			end
		end
		for _, a in World.altars do
			if (Vector3.new(pos.X, a.Y, pos.Z) - a).Magnitude < 14 then
				ok = false
			end
		end
		if ok then
			return pos
		end
	end
	return info.center + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20))
end

-- Cristal de una pieza con punta (cuerpo + dos cuñas espalda con espalda) — se usa sin modelos 3D
local function crystalPiece(parent: Instance, cf: CFrame, w: number, h: number, color: Color3, material: Enum.Material): Part
	local body = part(parent, { Name = "Cuerpo", Size = Vector3.new(w, h, w), CFrame = cf * CFrame.new(0, h / 2, 0), Color = color, Material = material })
	local tipH = w * 0.9
	for _, side in { -1, 1 } do
		local wdg = Instance.new("WedgePart")
		wdg.Name = "Punta"
		wdg.Anchored = true
		wdg.Size = Vector3.new(w, tipH, w / 2)
		-- La cuña sube hacia +Z local: dos espalda con espalda forman un tejadillo en punta
		wdg.CFrame = cf * CFrame.new(0, h + tipH / 2, side * w / 4) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
		wdg.Color = color:Lerp(Color3.new(1, 1, 1), 0.2)
		wdg.Material = material
		wdg.Parent = parent
		deco(wdg)
	end
	return body
end

-- Cristal (lo que rompen las crías). Devuelve la pieza principal: con modelos 3D es una caja INVISIBLE que lleva el
-- ClickDetector y los atributos (el racimo va dentro); sin modelos, un racimo de piezas con punta y sin base.
-- kind: "coins" | "chest" | "crystal" | "gold". Atributo Radius: a qué distancia lo rodean las crías.
function World.crystal(kind: string, zone: number, pos: Vector3, rng: Random): Part
	local yaw = rng:NextNumber(0, 6.28)
	-- Color: uno de la paleta de la isla (Config.Zones[i].crystalColors), con un toque al azar hacia blanco
	local palette = (Config.Zones[zone] or Config.Zones[1]).crystalColors
	local color = if kind == "gold" then Config.Colors.gold
		else palette[rng:NextInteger(1, #palette)]:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.15))
	-- Tamaño: el del tipo (Config.PileKinds[k].size) ± un poco al azar; el dorado aparte
	local size = Config.GOLD_SIZE
	if kind ~= "gold" then
		size = 1
		for _, k in Config.PileKinds do
			if k.id == kind then
				size = k.size
			end
		end
		size *= 1 + rng:NextNumber(-Config.PILE_SIZE_JITTER, Config.PILE_SIZE_JITTER)
	end
	local material = if kind == "gold" then Enum.Material.Neon else Enum.Material.SmoothPlastic -- Glass pesa en móvil
	if modelos then
		local alias = if kind == "coins" then ({ "Cristal1", "Cristal2" })[rng:NextInteger(1, 2)] elseif kind == "chest" then "Cristal2" else "CristalGrande"
		local height = if kind == "gold" then 11 else 6 * size -- el pequeño mide 6 studs; el dorado, como antes
		local hit = Instance.new("Part")
		hit.Name = "Monton"
		hit.Anchored = true
		hit.CanCollide = false
		hit.CastShadow = false
		hit.Transparency = 1
		local model, ext = place(alias, hit, pos, height, yaw, zone, true, { crystal = color }, material)
		if model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanQuery = false -- el toque lo recibe la caja invisible
					d.CanCollide = false
					d.CanTouch = false
				end
			end
			hit.Size = Vector3.new(math.max(ext.X, 3), math.max(ext.Y, 3), math.max(ext.Z, 3))
			hit.CFrame = CFrame.new(pos + Vector3.new(0, hit.Size.Y / 2, 0))
			hit:SetAttribute("Radius", math.max(ext.X, ext.Z) / 2 + 2)
			return hit
		end
		hit:Destroy()
	end
	-- Sin modelos: cristal central con punta + 2–3 pequeños inclinados hacia fuera
	local scale = size
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local main = crystalPiece(Instance.new("Folder"), base * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)), 1.8 * scale, 4.2 * scale, color, material)
	main.Name = "Monton"
	main.CanCollide = false
	main.CastShadow = false
	-- las puntas del central (creadas en la carpeta temporal) pasan dentro de la pieza principal
	local tmp = main.Parent
	main.Parent = nil
	if tmp then
		for _, c in tmp:GetChildren() do
			c.Parent = main
		end
		tmp:Destroy()
	end
	local n = if kind == "coins" then 2 else 3
	for k = 1, n do
		local a = k / n * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * 1.3 * scale
		local tilt = CFrame.new(pos + off) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -0.5)
		local body = crystalPiece(main, tilt, 1.1 * scale, rng:NextNumber(1.8, 2.8) * scale, color:Lerp(Color3.new(1, 1, 1), 0.1), material)
		deco(body)
	end
	main:SetAttribute("Radius", 4.5 * scale)
	return main
end

return World
