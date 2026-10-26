--[[
	World: el mapa (estilo «juego de mascotas»): UN terreno continuo dividido en 8 zonas cuadradas que se
	encadenan en zigzag por una rejilla de 3×3. Cada zona tiene su suelo y su decoración low-poly, está rodeada
	de acantilados de roca y se pasa a la siguiente por una PUERTA en la pared que las separa.
	También fabrica los cristales (los «montones» que rompen las crías) con World.crystal.
	Los textos (precios, nombres) los pone el CLIENTE encima, traducidos. Aquí solo hay piezas con atributos:
	Zone en huevos y puertas. Los nombres «Isla<n>», «Suelo», «Huevo», «Puerta» los usan el cliente y el bot.
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
World.GRID = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 2, 1 }, { 1, 1 }, { 0, 1 }, { 0, 2 }, { 1, 2 } }

-- Aspecto de cada zona (mismo orden que Config.Zones)
local THEMES = {
	{ ground = Color3.fromRGB(110, 200, 90), mat = Enum.Material.Grass, rock = Color3.fromRGB(90, 95, 105), crystal = Color3.fromRGB(120, 220, 255), deco = "meadow" },
	{ ground = Color3.fromRGB(95, 150, 110), mat = Enum.Material.Grass, rock = Color3.fromRGB(80, 70, 100), crystal = Color3.fromRGB(190, 110, 255), deco = "mushroom" },
	{ ground = Color3.fromRGB(240, 220, 160), mat = Enum.Material.Sand, rock = Color3.fromRGB(170, 150, 120), crystal = Color3.fromRGB(255, 120, 200), deco = "beach" },
	{ ground = Color3.fromRGB(235, 190, 110), mat = Enum.Material.Sand, rock = Color3.fromRGB(190, 120, 70), crystal = Color3.fromRGB(255, 220, 80), deco = "desert" },
	{ ground = Color3.fromRGB(80, 70, 70), mat = Enum.Material.Basalt, rock = Color3.fromRGB(55, 45, 45), crystal = Color3.fromRGB(255, 90, 60), deco = "volcano" },
	{ ground = Color3.fromRGB(235, 245, 255), mat = Enum.Material.Snow, rock = Color3.fromRGB(140, 160, 185), crystal = Color3.fromRGB(150, 230, 255), deco = "glacier" },
	{ ground = Color3.fromRGB(250, 235, 250), mat = Enum.Material.SmoothPlastic, rock = Color3.fromRGB(200, 190, 230), crystal = Color3.fromRGB(255, 170, 230), deco = "clouds" },
	{ ground = Color3.fromRGB(60, 50, 110), mat = Enum.Material.Slate, rock = Color3.fromRGB(40, 35, 75), crystal = Color3.fromRGB(170, 120, 255), deco = "cosmos" },
}
World.THEMES = THEMES

export type ZoneInfo = { center: Vector3, egg: BasePart, door: BasePart?, spawn: CFrame, entry: Vector3?, exit: Vector3? }
World.zones = {} :: { ZoneInfo }

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
local function decorate(m: Instance, theme: string, pos: Vector3, rng: Random, big: boolean, rockColor: Color3)
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

function World.build(): Folder
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
			if other == 0 then
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
		local egg = part(m, {
			Name = "Huevo", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 9, 7), CFrame = CFrame.new(eggBase + Vector3.new(0, 10.5, 0)),
			Color = zone.pets[1].color:Lerp(Color3.new(1, 1, 1), 0.55), Material = Enum.Material.SmoothPlastic,
		})
		egg:SetAttribute("Zone", i)
		egg:AddTag("Egg")

		-- Caminos de losas: entrada → centro → salida
		local pathColor = Color3.fromRGB(185, 190, 205)
		path(m, entry, center, rng, pathColor)
		if exit then
			path(m, center, exit, rng, pathColor)
		end

		-- Decoración: muchas cosas pegadas a las paredes y unas pocas dentro
		local function freeSpot(p: Vector3): boolean
			if (p - eggBase).Magnitude < 16 then
				return false
			end
			for _, gate in { entry, exit } do
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
				decorate(m, theme.deco, p, rng, true, theme.rock)
			end
		end
		for _ = 1, 18 do
			local p = center + Vector3.new(rng:NextNumber(-half + 40, half - 40), 0, rng:NextNumber(-half + 40, half - 40))
			if freeSpot(p) and (p - center).Magnitude > 20 then
				if rng:NextNumber() < 0.45 then
					decorate(m, theme.deco, p, rng, false, theme.rock)
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
		end

		m.Parent = folder
		World.zones[i] = World.zones[i] or ({} :: any)
		local info = World.zones[i] :: any
		info.center = center
		info.egg = egg
		info.door = door
		info.entry = entry
		info.exit = exit
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

-- Punto al azar para un cristal dentro de la zona (lejos de paredes, huevo y puertas)
function World.pilePosition(zone: number, rng: Random): Vector3
	local info = World.zones[zone]
	local half = World.CELL / 2 - 30
	for _ = 1, 30 do
		local pos = info.center + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		local ok = (pos - Vector3.new(info.egg.Position.X, pos.Y, info.egg.Position.Z)).Magnitude > 16
		for _, gate in { info.entry, info.exit } do
			if gate and (pos - gate).Magnitude < 22 then
				ok = false
			end
		end
		if ok then
			return pos
		end
	end
	return info.center + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20))
end

-- Cristal (lo que rompen las crías): devuelve la pieza principal (con los cristales pequeños y la losa dentro).
-- kind: "coins" | "chest" | "crystal" | "gold". La pieza principal lleva el ClickDetector y los atributos.
function World.crystal(kind: string, zone: number, pos: Vector3, rng: Random): Part
	local theme = THEMES[zone] or THEMES[1]
	local color = if kind == "gold" then Config.Colors.gold
		elseif kind == "crystal" then Color3.fromRGB(255, 70, 90)
		elseif kind == "chest" then Color3.fromRGB(110, 230, 120)
		else theme.crystal
	local scale = if kind == "gold" then 1.7 elseif kind == "crystal" then 1.4 elseif kind == "chest" then 1.15 else 1
	local material = if kind == "gold" then Enum.Material.Neon else Enum.Material.Glass
	local h = 5 * scale
	local main = Instance.new("Part")
	main.Name = "Monton"
	main.Anchored = true
	main.CanCollide = false
	main.CastShadow = false
	main.Size = Vector3.new(2 * scale, h, 2 * scale)
	main.CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12))
	main.Color = color
	main.Material = material
	main.Transparency = 0
	-- Cristales pequeños inclinados hacia fuera
	local n = if kind == "coins" then 3 else 4
	for k = 1, n do
		local a = k / n * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local sh = h * rng:NextNumber(0.45, 0.75)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * 1.4 * scale
		local c = deco(part(main, {
			Name = "Punta", Size = Vector3.new(1.3 * scale, sh, 1.3 * scale),
			CFrame = CFrame.new(pos + off + Vector3.new(0, sh * 0.42, 0)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -0.45),
			Color = color:Lerp(Color3.new(1, 1, 1), 0.15), Material = material,
		}))
		c.Transparency = 0
	end
	-- Losa hexagonal (aprox.) debajo
	deco(part(main, {
		Name = "Losa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7 * scale, 7 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(175, 185, 205), Material = Enum.Material.Slate,
	}))
	return main
end

return World
