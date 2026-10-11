--!strict
-- Geometría de la biblioteca: planta, estanterías, filas, huecos, muebles, montones iniciales y cajas sólidas.
-- Es IDÉNTICA en servidor y cliente: no usa Random de Roblox sino un generador propio con semilla fija,
-- así todas las partidas empiezan igual y el cliente puede reconstruir la posición inicial de cada libro.
-- Coordenadas (studs): biblioteca X [-32, 32] · Z [-120, 0] (la entrada en Z = 0) · planta 1 en Y = 0,
-- planta 2 (galería en anillo) en Y = 14, techo en Y = 30. El Archivo (fase especial) está en X ≈ 110–146.

local RS = script.Parent
local BookData = require(RS:WaitForChild("BookData"))
local Config = require(RS:WaitForChild("Config"))
local Codec = require(RS:WaitForChild("Codec"))
local Geo = require(RS:WaitForChild("Geo"))

local Layout = {}

-- Medidas
Layout.BOOK = Vector3.new(0.4, 1.4, 1.0) -- grosor, alto, fondo
Layout.PITCH = 0.44 -- distancia entre huecos
Layout.CASE_DEPTH = 1.4
Layout.SIDE = 0.3
Layout.DIVIDER = 0.2
Layout.BAY_INNER = { [10] = 4.6, [5] = 2.4, [3] = 1.52 } :: { [number]: number }
Layout.LEVELS = { 0.5, 2.3, 4.1, 5.9, 7.7 }
Layout.FLOOR2 = 14
Layout.SEED = 20260430
Layout.FLAT_H = 0.4 -- alto de un libro tumbado

export type Box = Geo.Box
export type Piece = {
	cf: CFrame,
	size: Vector3,
	color: Color3,
	mat: Enum.Material,
	collide: boolean,
	transp: number?,
	name: string?,
	interact: string?,
	shape: string?,
	group: string?,
	query: boolean?,
}
export type Row = { id: number, section: string, len: number, first: number, cf: CFrame, size: Vector3, level: number }
export type Section = {
	code: string,
	theme: string,
	floor: number,
	levels: number,
	cf: CFrame,
	width: number,
	height: number,
	facing: Vector3,
	rows: { number },
	plate: CFrame,
	plateSize: Vector3,
	box: Box,
	series: { number },
}
export type BookInfo = { series: number, vol: number }
export type Spot = { pos: Vector3, yaw: number, kind: string, max: number }
export type Def = {
	name: string,
	sections: { Section },
	sectionByCode: { [string]: Section },
	rows: { Row },
	slotCF: { CFrame },
	slotRow: { number },
	slotIndex: { number },
	books: { BookInfo },
	seriesSection: { [number]: string },
	seriesFirst: { [number]: number },
	seriesList: { number },
	pieces: { Piece },
	solids: { Box },
	keepout: { Box },
	spots: { Spot },
	initial: { { pos: Vector3, yaw: number } },
	interact: { [string]: Vector3 },
	lights: { { pos: Vector3, range: number, brightness: number, color: Color3, shadows: boolean } },
	bounds: Box,
	floors: { number },
	spawn: CFrame,
	podium: { Vector3 },
	tutorialSeries: { number },
}

---------------------------------------------------------------------
-- Generador pseudoaleatorio propio (Park–Miller): mismo resultado en cualquier máquina
---------------------------------------------------------------------
local function rng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local r = {}
	function r.next(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	function r.int(a: number, b: number): number
		return a + math.floor(r.next() * (b - a + 1))
	end
	function r.range(a: number, b: number): number
		return a + r.next() * (b - a)
	end
	function r.shuffle(list: { any })
		for i = #list, 2, -1 do
			local j = r.int(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	return r
end
Layout.rng = rng

---------------------------------------------------------------------
-- Colores y piezas
---------------------------------------------------------------------
local C = {
	floor = Color3.fromRGB(122, 84, 52),
	floor2 = Color3.fromRGB(132, 92, 58),
	plaster = Color3.fromRGB(226, 214, 190),
	panel = Color3.fromRGB(92, 60, 38),
	case = Color3.fromRGB(96, 62, 38),
	caseDark = Color3.fromRGB(70, 44, 27),
	board = Color3.fromRGB(118, 80, 50),
	rail = Color3.fromRGB(84, 54, 33),
	stair = Color3.fromRGB(112, 76, 46),
	marble = Color3.fromRGB(214, 210, 200),
	glass = Color3.fromRGB(170, 205, 235),
	roof = Color3.fromRGB(60, 44, 34),
	carpet = Color3.fromRGB(118, 34, 44),
	gold = Color3.fromRGB(212, 175, 55),
	table = Color3.fromRGB(104, 68, 40),
	bench = Color3.fromRGB(88, 58, 36),
	cushion = Color3.fromRGB(46, 70, 110),
	grass = Color3.fromRGB(86, 120, 64),
	chest = Color3.fromRGB(110, 70, 36),
	metal = Color3.fromRGB(70, 70, 76),
	plate = Color3.fromRGB(60, 52, 44),
}
Layout.Colors = C

local function newDef(name: string): Def
	return {
		name = name, sections = {}, sectionByCode = {}, rows = {}, slotCF = {}, slotRow = {}, slotIndex = {},
		books = {}, seriesSection = {}, seriesFirst = {}, seriesList = {}, pieces = {}, solids = {}, keepout = {},
		spots = {}, initial = {}, interact = {}, lights = {}, bounds = Geo.box(Vector3.zero, Vector3.zero, "bounds"),
		floors = { 0 }, spawn = CFrame.new(), podium = {}, tutorialSeries = {},
	}
end

-- Pieza alineada con los ejes entre dos esquinas
local function P(def: Def, a: Vector3, b: Vector3, color: Color3, mat: Enum.Material, opts: { [string]: any }?): Piece
	local lo = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local piece: Piece = { cf = CFrame.new((lo + hi) / 2), size = hi - lo, color = color, mat = mat, collide = true }
	if opts then
		for k, v in opts do
			(piece :: any)[k] = v
		end
	end
	table.insert(def.pieces, piece)
	return piece
end

-- Pieza orientada (cf + tamaño en sus ejes)
local function PC(def: Def, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, opts: { [string]: any }?): Piece
	local piece: Piece = { cf = cf, size = size, color = color, mat = mat, collide = true }
	if opts then
		for k, v in opts do
			(piece :: any)[k] = v
		end
	end
	table.insert(def.pieces, piece)
	return piece
end

-- Caja sólida para soltar/lanzar libros (kind: floor, stair, furniture, case, rail, wall, deco)
local function S(def: Def, a: Vector3, b: Vector3, kind: string)
	table.insert(def.solids, Geo.box(a, b, kind))
end

-- Pieza + caja sólida a la vez
local function PS(def: Def, a: Vector3, b: Vector3, color: Color3, mat: Enum.Material, kind: string, opts: { [string]: any }?): Piece
	S(def, a, b, kind)
	return P(def, a, b, color, mat, opts)
end

local function keep(def: Def, a: Vector3, b: Vector3)
	table.insert(def.keepout, Geo.box(a, b, "keep"))
end

local function spot(def: Def, pos: Vector3, kind: string, maxBooks: number, yaw: number?)
	table.insert(def.spots, { pos = pos, yaw = yaw or 0, kind = kind, max = maxBooks })
end

-- CFrame en `pos` mirando en la dirección horizontal `dir` (equivale a CFrame.lookAt, pero sin el fallo de
-- Lune con la dirección +Z, así Roblox y las pruebas dan exactamente lo mismo)
function Layout.face(pos: Vector3, dir: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
end
local face = Layout.face

-- CFrame de un libro tumbado (la tapa mira arriba: el eje X local del libro apunta hacia +Y)
function Layout.flatCF(pos: Vector3, yaw: number): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.pi / 2)
end

---------------------------------------------------------------------
-- Estanterías
---------------------------------------------------------------------
type Bay = { len: number, count: number }

local function baysFor(n10: number, n5: number, n3: number, levels: number): { Bay }
	local bays: { Bay } = {}
	for _, pair in { { 10, n10 }, { 5, n5 }, { 3, n3 } } do
		local len, n = pair[1], pair[2]
		assert(n % levels == 0, "las filas no llenan las baldas")
		for _ = 1, n // levels do
			table.insert(bays, { len = len, count = levels })
		end
	end
	return bays
end

function Layout.caseWidth(n10: number, n5: number, n3: number, levels: number): number
	local bays = baysFor(n10, n5, n3, levels)
	local w = 2 * Layout.SIDE + Layout.DIVIDER * (#bays - 1)
	for _, b in bays do
		w += Layout.BAY_INNER[b.len]
	end
	return w
end

local function caseHeight(levels: number): number
	return Layout.LEVELS[levels] + Layout.BOOK.Y + 0.5
end

-- Crea el mueble de una sección y sus filas/huecos. cf = centro del frente, a ras de suelo, mirando hacia fuera.
-- Ejes locales del mueble: u = de izquierda a derecha visto de frente, v = altura, w = profundidad hacia la pared.
local function addCase(def: Def, code: string, theme: string, floor: number, levels: number, series: { number }, cf: CFrame)
	local n = { [10] = 0, [5] = 0, [3] = 0 }
	for _, sid in series do
		local s = BookData.Series[sid]
		n[s.volumes] += 1
	end
	local bays = baysFor(n[10], n[5], n[3], levels)
	local W = Layout.caseWidth(n[10], n[5], n[3], levels)
	local H = caseHeight(levels)
	local D = Layout.CASE_DEPTH
	local function world(u: number, v: number, w: number): Vector3
		return cf * Vector3.new(W / 2 - u, v, w)
	end
	local function box(u0: number, u1: number, v0: number, v1: number, w0: number, w1: number, color: Color3, mat: Enum.Material?)
		P(def, world(u0, v0, w0), world(u1, v1, w1), color, mat or Enum.Material.Wood)
	end
	-- Estructura: laterales, fondo, tapa, zócalo, baldas y separadores
	box(0, Layout.SIDE, 0, H, 0, D, C.case)
	box(W - Layout.SIDE, W, 0, H, 0, D, C.case)
	box(0, W, 0, H, D - 0.2, D, C.caseDark)
	box(0, W, H - 0.2, H, 0, D + 0.05, C.case)
	box(Layout.SIDE, W - Layout.SIDE, 0, Layout.LEVELS[1], 0, D - 0.2, C.caseDark)
	for k = 2, levels do
		box(Layout.SIDE, W - Layout.SIDE, Layout.LEVELS[k] - 0.15, Layout.LEVELS[k], 0, D - 0.2, C.board)
	end
	local u = Layout.SIDE
	local section: Section = {
		code = code, theme = theme, floor = floor, levels = levels, cf = cf, width = W, height = H,
		facing = cf.LookVector, rows = {}, plate = CFrame.new(), plateSize = Vector3.one, box = Geo.box(world(0, 0, 0), world(W, H, D), "case"),
		series = series,
	}
	for bi, bay in bays do
		if bi > 1 then
			box(u, u + Layout.DIVIDER, Layout.LEVELS[1], H - 0.2, 0, D - 0.2, C.case)
			u += Layout.DIVIDER
		end
		local inner = Layout.BAY_INNER[bay.len]
		-- Filas de arriba abajo dentro de cada hueco del mueble
		for level = levels, 1, -1 do
			local rowId = #def.rows + 1
			local first = #def.slotCF + 1
			local boardTop = Layout.LEVELS[level]
			local mid = u + inner / 2
			local rowCF = face(world(mid, boardTop + Layout.BOOK.Y / 2, 0.55), cf.LookVector)
			table.insert(def.rows, {
				id = rowId, section = code, len = bay.len, first = first, level = level,
				cf = rowCF, size = Vector3.new(bay.len * Layout.PITCH + 0.06, Layout.BOOK.Y + 0.08, Layout.BOOK.Z + 0.1),
			})
			table.insert(section.rows, rowId)
			for i = 1, bay.len do
				local pos = world(u + 0.1 + Layout.PITCH * (i - 0.5), boardTop + Layout.BOOK.Y / 2, 0.6)
				table.insert(def.slotCF, face(pos, cf.LookVector))
				table.insert(def.slotRow, rowId)
				table.insert(def.slotIndex, i)
			end
		end
		u += inner
	end
	-- Placa encima del mueble (el cliente le pone el texto y la vuelve azul)
	local plateW = math.min(W - 0.8, 7)
	section.plate = face(world(W / 2, H + 0.75, 0.25), cf.LookVector)
	section.plateSize = Vector3.new(plateW, 1.1, 0.16)
	PC(def, section.plate, section.plateSize, C.plate, Enum.Material.SmoothPlastic, { name = "Plate_" .. code, group = "plates" })
	PC(def, section.plate * CFrame.new(0, -0.62, 0.02), Vector3.new(plateW + 0.2, 0.14, 0.2), C.gold, Enum.Material.Metal)
	S(def, section.box.min, section.box.max, "case")
	table.insert(def.sections, section)
	def.sectionByCode[code] = section
end

-- Reparte secciones a lo largo de una pared con huecos iguales. Devuelve code → CFrame del frente.
-- wall: "left" (x = -32, miran a +X), "right" (x = +32, miran a -X), "back" (z = -120, miran a +Z)
local function wallRun(codes: { string }, wall: string, y: number, from: number, to: number, widths: { [string]: number }): { [string]: CFrame }
	local total = 0
	for _, code in codes do
		total += widths[code]
	end
	local span = math.abs(to - from)
	local gap = if #codes > 1 then (span - total) / (#codes - 1) else 0
	assert(gap >= 1, "no caben las secciones en la pared " .. wall)
	local out = {}
	local cursor = from
	local front = 32 - Layout.CASE_DEPTH
	for _, code in codes do
		local w = widths[code]
		if wall == "left" then
			local zc = cursor - w / 2
			out[code] = face(Vector3.new(-front, y, zc), Vector3.new(1, 0, 0))
			cursor -= w + gap
		elseif wall == "right" then
			local zc = cursor - w / 2
			out[code] = face(Vector3.new(front, y, zc), Vector3.new(-1, 0, 0))
			cursor -= w + gap
		else
			local xc = cursor + w / 2
			local zf = -120 + Layout.CASE_DEPTH
			out[code] = face(Vector3.new(xc, y, zf), Vector3.new(0, 0, 1))
			cursor += w + gap
		end
	end
	return out
end

---------------------------------------------------------------------
-- Muebles
---------------------------------------------------------------------
-- Mesa de lectura (largo en Z si alongZ). Encima: huecos para montones.
local function readingTable(def: Def, cx: number, y: number, cz: number, alongZ: boolean, lamp: boolean)
	local hx, hz = if alongZ then 1.5 else 4, if alongZ then 4 else 1.5
	S(def, Vector3.new(cx - hx, y, cz - hz), Vector3.new(cx + hx, y + 3, cz + hz), "furniture")
	P(def, Vector3.new(cx - hx, y + 2.75, cz - hz), Vector3.new(cx + hx, y + 3, cz + hz), C.table, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local lx, lz = cx + sx * (hx - 0.4), cz + sz * (hz - 0.4)
			P(def, Vector3.new(lx - 0.2, y, lz - 0.2), Vector3.new(lx + 0.2, y + 2.75, lz + 0.2), C.caseDark, Enum.Material.Wood)
		end
	end
	local n = 3
	for i = 1, n do
		local t = (i - (n + 1) / 2) * 2.4
		local p = if alongZ then Vector3.new(cx, y + 3, cz + t) else Vector3.new(cx + t, y + 3, cz)
		if not (lamp and i == 2) then
			spot(def, p, "table", 6)
		end
	end
	if lamp then
		local lp = Vector3.new(cx, y + 3, cz)
		P(def, lp + Vector3.new(-0.3, 0, -0.3), lp + Vector3.new(0.3, 1.4, 0.3), C.metal, Enum.Material.Metal)
		P(def, lp + Vector3.new(-0.7, 1.4, -0.7), lp + Vector3.new(0.7, 2.1, 0.7), Color3.fromRGB(255, 214, 150), Enum.Material.Neon, { collide = false })
		table.insert(def.lights, { pos = lp + Vector3.new(0, 1.6, 0), range = 14, brightness = 1.1, color = Color3.fromRGB(255, 200, 140), shadows = false })
	end
end

local function bench(def: Def, cx: number, y: number, cz: number, alongZ: boolean, spots: boolean)
	local hx, hz = if alongZ then 0.6 else 3, if alongZ then 3 else 0.6
	S(def, Vector3.new(cx - hx, y, cz - hz), Vector3.new(cx + hx, y + 1.6, cz + hz), "furniture")
	P(def, Vector3.new(cx - hx, y + 1.2, cz - hz), Vector3.new(cx + hx, y + 1.6, cz + hz), C.cushion, Enum.Material.Fabric)
	P(def, Vector3.new(cx - hx + 0.1, y, cz - hz + 0.1), Vector3.new(cx + hx - 0.1, y + 1.2, cz + hz - 0.1), C.bench, Enum.Material.Wood)
	if spots then
		for _, t in { -1.4, 1.4 } do
			spot(def, if alongZ then Vector3.new(cx, y + 1.6, cz + t) else Vector3.new(cx + t, y + 1.6, cz), "bench", 5)
		end
	end
end

-- Jarrón decorativo sobre una peana
local function vase(def: Def, x: number, y: number, z: number, h: number)
	S(def, Vector3.new(x - 0.6, y, z - 0.6), Vector3.new(x + 0.6, y + h + 1.8, z + 0.6), "deco")
	P(def, Vector3.new(x - 0.6, y, z - 0.6), Vector3.new(x + 0.6, y + h, z + 0.6), C.marble, Enum.Material.Marble)
	PC(def, CFrame.new(x, y + h + 0.7, z), Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(46, 96, 140), Enum.Material.SmoothPlastic, { shape = "Ball" })
end

-- Cofre con tapa (interact = "chest_<color>") y cuadro con la pista encima
local function chest(def: Def, color: string, x: number, y: number, z: number, wallZ: number)
	S(def, Vector3.new(x - 1.3, y, z - 0.8), Vector3.new(x + 1.3, y + 1.7, z + 0.8), "deco")
	P(def, Vector3.new(x - 1.3, y, z - 0.8), Vector3.new(x + 1.3, y + 1.2, z + 0.8), C.chest, Enum.Material.Wood, { name = "Chest_" .. color, interact = "chest_" .. color })
	P(def, Vector3.new(x - 1.35, y + 1.2, z - 0.85), Vector3.new(x + 1.35, y + 1.7, z + 0.85), C.chest, Enum.Material.Wood, { name = "ChestLid_" .. color, interact = "chest_" .. color })
	P(def, Vector3.new(x - 0.25, y + 0.8, z - 0.9), Vector3.new(x + 0.25, y + 1.3, z - 0.82), C.gold, Enum.Material.Metal, { name = "ChestLock_" .. color, interact = "chest_" .. color })
	def.interact["chest_" .. color] = Vector3.new(x, y + 1, z)
	-- Cuadro en la pared de detrás
	local pcf = face(Vector3.new(x, y + 5.2, wallZ - 0.12), Vector3.new(0, 0, -1))
	PC(def, pcf, Vector3.new(4.4, 3.2, 0.12), C.gold, Enum.Material.Metal)
	PC(def, pcf * CFrame.new(0, 0, -0.07), Vector3.new(4, 2.8, 0.05), Color3.fromRGB(235, 225, 200), Enum.Material.SmoothPlastic,
		{ name = "Painting_" .. color, interact = "painting_" .. color, group = "paintings" })
	keep(def, Vector3.new(x - 2.2, y, z - 2.6), Vector3.new(x + 2.2, y + 3, z + 1.2))
end

-- Llave (forma propia por color: rombo, hoja, sol, gota) con un poco de luz
local KEY_COLORS = {
	red = Color3.fromRGB(230, 60, 60), green = Color3.fromRGB(70, 200, 90),
	yellow = Color3.fromRGB(250, 210, 60), blue = Color3.fromRGB(70, 140, 250),
}
Layout.KeyColors = KEY_COLORS
local function key(def: Def, color: string, pos: Vector3, lying: boolean)
	local base = if lying then CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0) else CFrame.new(pos)
	local kc = KEY_COLORS[color]
	local opts = { name = "Key_" .. color, interact = "key_" .. color, collide = false, group = "keys" }
	PC(def, base * CFrame.new(0, -0.25, 0), Vector3.new(0.14, 0.7, 0.14), kc, Enum.Material.Neon, opts)
	local head = base * CFrame.new(0, 0.25, 0)
	if color == "red" then
		PC(def, head * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(0.38, 0.38, 0.12), kc, Enum.Material.Neon, opts)
	elseif color == "green" then
		PC(def, head * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(0.22, 0.5, 0.1), kc, Enum.Material.Neon, opts)
	elseif color == "yellow" then
		PC(def, head, Vector3.new(0.5, 0.5, 0.12), kc, Enum.Material.Neon, { name = opts.name, interact = opts.interact, collide = false, group = "keys", shape = "Ball" })
	else
		PC(def, head, Vector3.new(0.3, 0.45, 0.12), kc, Enum.Material.Neon, opts)
	end
	PC(def, base * CFrame.new(0.13, -0.5, 0), Vector3.new(0.14, 0.1, 0.12), kc, Enum.Material.Neon, opts)
	def.interact["key_" .. color] = pos
	table.insert(def.lights, { pos = pos, range = 5, brightness = 1.4, color = kc, shadows = false })
end

-- Tablón con el mapa de una planta (el cliente le dibuja el mapa)
local function mapBoard(def: Def, floor: number, pos: Vector3, look: Vector3)
	-- Tablón vertical (el mapa es más alto que ancho: 64 × 120 studs)
	local cf = face(pos + Vector3.new(0, 4, 0), look)
	PC(def, cf, Vector3.new(3.8, 6, 0.25), C.caseDark, Enum.Material.Wood)
	PC(def, cf * CFrame.new(0, 0, -0.14), Vector3.new(3.4, 5.6, 0.05), Color3.fromRGB(240, 230, 205), Enum.Material.SmoothPlastic,
		{ name = "MapBoard" .. floor, interact = "map" .. floor, group = "maps" })
	for _, sx in { -1.5, 1.5 } do
		local leg = cf * CFrame.new(sx, 0, 0.1)
		PC(def, CFrame.new(leg.Position.X, pos.Y + 0.5, leg.Position.Z), Vector3.new(0.3, 1, 0.3), C.caseDark, Enum.Material.Wood)
	end
	local right = cf.RightVector
	S(def, pos - right * 2 - Vector3.new(0.3, 0, 0.3), pos + right * 2 + Vector3.new(0.3, 7, 0.3), "deco")
	def.interact["map" .. floor] = cf.Position
	keep(def, pos - right * 3 - Vector3.new(1.5, 0, 1.5), pos + right * 3 + Vector3.new(1.5, 4, 1.5))
end

---------------------------------------------------------------------
-- Paredes con ventanales
---------------------------------------------------------------------
-- Pared a lo largo de Z (lado izquierdo/derecho) o de X (delante/fondo) con franjas de ventanas.
local function windowWall(def: Def, alongX: boolean, fixed0: number, fixed1: number, from: number, to: number,
	centers: { number }, bands: { { number } }, solidBands: { { number } }, holes: { { number } }?)
	local function piece(a0: number, a1: number, y0: number, y1: number, color: Color3, mat: Enum.Material, transp: number?)
		local p0 = if alongX then Vector3.new(a0, y0, fixed0) else Vector3.new(fixed0, y0, a0)
		local p1 = if alongX then Vector3.new(a1, y1, fixed1) else Vector3.new(fixed1, y1, a1)
		if transp then
			P(def, p0, p1, color, mat, { transp = transp, collide = true })
		else
			PS(def, p0, p1, color, mat, "wall")
		end
	end
	for _, sb in solidBands do
		local cuts = {}
		local holeList: { { number } } = holes or {}
		for _, h in holeList do
			if h[3] < sb[2] and h[4] > sb[1] then
				table.insert(cuts, h)
			end
		end
		if #cuts == 0 then
			piece(from, to, sb[1], sb[2], if sb[1] < 0 then C.panel else C.plaster, Enum.Material.SmoothPlastic)
		else
			-- Hueco (puerta): trozos a los lados y encima
			local h = cuts[1]
			piece(from, h[1], sb[1], sb[2], C.plaster, Enum.Material.SmoothPlastic)
			piece(h[2], to, sb[1], sb[2], C.plaster, Enum.Material.SmoothPlastic)
			if h[4] < sb[2] then
				piece(h[1], h[2], h[4], sb[2], C.plaster, Enum.Material.SmoothPlastic)
			end
		end
	end
	for _, band in bands do
		local y0, y1, w = band[1], band[2], band[3]
		local cursor = from
		for _, c in centers do
			piece(cursor, c - w / 2, y0, y1, C.plaster, Enum.Material.SmoothPlastic)
			local g0 = if alongX then Vector3.new(c - w / 2, y0, (fixed0 + fixed1) / 2 - 0.1) else Vector3.new((fixed0 + fixed1) / 2 - 0.1, y0, c - w / 2)
			local g1 = if alongX then Vector3.new(c + w / 2, y1, (fixed0 + fixed1) / 2 + 0.1) else Vector3.new((fixed0 + fixed1) / 2 + 0.1, y1, c + w / 2)
			S(def, g0, g1, "wall")
			P(def, g0, g1, C.glass, Enum.Material.Glass, { transp = 0.55, group = "glass" })
			cursor = c + w / 2
		end
		piece(cursor, to, y0, y1, C.plaster, Enum.Material.SmoothPlastic)
	end
end

---------------------------------------------------------------------
-- Montones iniciales
---------------------------------------------------------------------
-- ¿Hay sitio para un montón en (x, y, z)? (sin muebles, paredes ni zonas reservadas cerca)
local function freeSpot(def: Def, x: number, y: number, z: number, margin: number): boolean
	for _, b in def.solids do
		if b.min.Y < y + 3 and b.max.Y > y + 0.05 then
			local m = if b.kind == "case" then margin + 0.6 else margin
			if x > b.min.X - m and x < b.max.X + m and z > b.min.Z - m and z < b.max.Z + m then
				return false
			end
		end
	end
	for _, b in def.keepout do
		if y >= b.min.Y - 0.1 and y <= b.max.Y and x > b.min.X and x < b.max.X and z > b.min.Z and z < b.max.Z then
			return false
		end
	end
	return true
end

local function gridSpots(def: Def, r: any, y: number, x0: number, x1: number, z0: number, z1: number, step: number, keepP: number, inside: (number, number) -> boolean)
	local x = x0
	while x <= x1 do
		local z = z0
		while z >= z1 do
			local px, pz = x + r.range(-0.5, 0.5), z + r.range(-0.5, 0.5)
			local roll = r.next()
			if inside(px, pz) and roll < keepP and freeSpot(def, px, y, pz, 0.9) then
				spot(def, Vector3.new(px, y, pz), "floor", 9, r.range(0, math.pi))
			end
			z -= step
		end
		x += step
	end
end

-- Reparte los libros (ya barajados) en los montones: ninguno empieza junto a otro de su misma serie.
local function fillSpots(def: Def, r: any, books: { number }, reserved: { [number]: { number } })
	local weights = { floor = 1.25, table = 0.95, bench = 0.75, step = 0.4, special = 0 }
	local spots = def.spots
	local counts = table.create(#spots, 0)
	local total = 0
	for i, s in spots do
		if reserved[i] then
			counts[i] = #reserved[i]
		else
			local w = weights[s.kind] * r.range(0.55, 1.45)
			counts[i] = w
			total += w
		end
	end
	local nFree = #books
	local assigned = 0
	for i, s in spots do
		if not reserved[i] then
			local c = math.clamp(math.floor(nFree * counts[i] / total), 1, s.max)
			counts[i] = c
			assigned += c
		end
	end
	-- Ajuste fino: sumar o quitar de uno en uno hasta cuadrar
	local guard = 0
	while assigned ~= nFree do
		guard += 1
		assert(guard < 200000, "no caben los libros en los montones")
		local i = r.int(1, #spots)
		if not reserved[i] then
			if assigned < nFree and counts[i] < spots[i].max + (if guard > 50000 then 3 else 0) then
				counts[i] += 1
				assigned += 1
			elseif assigned > nFree and counts[i] > 1 then
				counts[i] -= 1
				assigned -= 1
			end
		end
	end
	-- Montones: listas de libros de abajo arriba
	local stacks: { { number } } = table.create(#spots)
	local cursor = 0
	for i in spots do
		if reserved[i] then
			stacks[i] = reserved[i]
		else
			local list = table.create(counts[i])
			for k = 1, counts[i] do
				list[k] = books[cursor + k]
			end
			cursor += counts[i]
			stacks[i] = list
		end
	end
	-- Ningún libro empieza encima de otro de su misma serie (se intercambia con otro montón)
	local function seriesOf(b: number): number
		return def.books[b].series
	end
	local function clash(list: { number }, k: number): boolean
		local s = seriesOf(list[k])
		return (k > 1 and seriesOf(list[k - 1]) == s) or (k < #list and seriesOf(list[k + 1]) == s)
	end
	for pass = 1, 50 do
		local fixed = true
		for i, list in stacks do
			if not reserved[i] then
				for k = 1, #list do
					if clash(list, k) then
						fixed = false
						for _ = 1, 40 do
							local j = r.int(1, #stacks)
							local other = stacks[j]
							if not reserved[j] and #other > 0 then
								local m = r.int(1, #other)
								list[k], other[m] = other[m], list[k]
								if not clash(list, k) and not clash(other, m) then
									break
								end
								list[k], other[m] = other[m], list[k]
							end
						end
					end
				end
			end
		end
		if fixed then
			break
		end
		assert(pass < 50, "no se pudo separar los tomos de la misma serie")
	end
	-- Posiciones finales (cuantizadas para que el guardado sea exacto)
	for i, list in stacks do
		local s = spots[i]
		-- En los escalones, alineados con el escalón (si no, asoman dentro del siguiente)
		local jit = if s.kind == "step" then 0 else 0.08
		local turn = if s.kind == "step" then 0.08 else 0.25
		for k, b in list do
			local p = s.pos + Vector3.new(r.range(-jit, jit), 0.2 + Layout.FLAT_H * (k - 1), r.range(-jit, jit))
			local pos, yaw = Codec.quantize(p, s.yaw + r.range(-turn, turn))
			def.initial[b] = { pos = pos, yaw = yaw }
		end
	end
end

---------------------------------------------------------------------
-- Biblioteca principal
---------------------------------------------------------------------
local function buildMain(): Def
	local def = newDef("main")
	local r = rng(Layout.SEED)
	def.floors = { 0, Layout.FLOOR2 }
	def.bounds = Geo.box(Vector3.new(-32, -1, -120), Vector3.new(32, 30, 0), "bounds")
	def.spawn = face(Vector3.new(0, 0, -6), Vector3.new(0, 0, -1))
	for _, s in BookData.Series do
		def.seriesSection[s.id] = s.section
		def.seriesFirst[s.id] = #def.books + 1
		table.insert(def.seriesList, s.id)
		for v = 1, s.volumes do
			table.insert(def.books, { series = s.id, vol = v })
		end
	end
	local F2 = Layout.FLOOR2
	local SM = Enum.Material.SmoothPlastic

	-- Suelo, galería, techo y exterior
	PS(def, Vector3.new(-34, -1, -122), Vector3.new(34, 0, 2), C.floor, Enum.Material.WoodPlanks, "floor")
	P(def, Vector3.new(-260, -2, -300), Vector3.new(260, -1, 120), C.grass, Enum.Material.Grass)
	P(def, Vector3.new(-2.2, 0, -66), Vector3.new(2.2, 0.06, -1), C.carpet, Enum.Material.Fabric, { collide = false })
	for _, g in {
		{ Vector3.new(-32, F2 - 1, -120), Vector3.new(-18, F2, 0) },
		{ Vector3.new(18, F2 - 1, -120), Vector3.new(32, F2, 0) },
		{ Vector3.new(-18, F2 - 1, -14), Vector3.new(18, F2, 0) },
		{ Vector3.new(-18, F2 - 1, -120), Vector3.new(18, F2, -106) },
	} do
		PS(def, g[1], g[2], C.floor2, Enum.Material.WoodPlanks, "floor")
	end
	-- Techo con claraboya sobre el hueco central
	PS(def, Vector3.new(-34, 30, -122), Vector3.new(34, 31, -100), C.roof, Enum.Material.Wood, "wall")
	PS(def, Vector3.new(-34, 30, -20), Vector3.new(34, 31, 2), C.roof, Enum.Material.Wood, "wall")
	PS(def, Vector3.new(-34, 30, -100), Vector3.new(-14, 31, -20), C.roof, Enum.Material.Wood, "wall")
	PS(def, Vector3.new(14, 30, -100), Vector3.new(34, 31, -20), C.roof, Enum.Material.Wood, "wall")
	S(def, Vector3.new(-14, 30.4, -100), Vector3.new(14, 30.6, -20), "wall")
	P(def, Vector3.new(-14, 30.4, -100), Vector3.new(14, 30.6, -20), C.glass, Enum.Material.Glass, { transp = 0.6, group = "glass" })
	for z = -90, -30, 10 do
		P(def, Vector3.new(-14, 29.6, z - 0.4), Vector3.new(14, 30.4, z + 0.4), C.roof, Enum.Material.Wood)
	end

	-- Paredes: franjas macizas y de ventanas
	local sideCenters = { -6, -18, -30, -42, -54, -66, -78, -90, -102, -114 }
	local bands = { { 8.5, 12, 4 }, { 22.5, 27, 4 } }
	local solid = { { -1, 8.5 }, { 12, 22.5 }, { 27, 31 } }
	windowWall(def, false, -34, -32, 2, -122, sideCenters, bands, solid)
	windowWall(def, false, 32, 34, 2, -122, sideCenters, bands, solid)
	windowWall(def, true, -122, -120, -32, 32, { -20, -8, 8, 20 }, bands, solid)
	windowWall(def, true, 0, 2, -32, 32, { -20, -8, 8, 20 }, { { 22.5, 27, 4 } }, { { -1, 22.5 }, { 27, 31 } }, { { -3.5, 3.5, -1, 9 } })
	-- Zócalo de madera en las paredes de la planta 1
	for _, w in { { -32, -31.9 }, { 31.9, 32 } } do
		P(def, Vector3.new(w[1], 0, -120), Vector3.new(w[2], 1.2, 0), C.panel, Enum.Material.Wood, { collide = false })
	end

	-- Puerta encantada y escudo encima
	P(def, Vector3.new(-3.5, 0, 0.3), Vector3.new(0, 9, 0.9), C.caseDark, Enum.Material.Wood, { name = "Door", interact = "door" })
	P(def, Vector3.new(0, 0, 0.3), Vector3.new(3.5, 9, 0.9), C.caseDark, Enum.Material.Wood, { name = "Door", interact = "door" })
	P(def, Vector3.new(-3.9, 9, 0), Vector3.new(3.9, 9.6, 0.4), C.gold, Enum.Material.Metal)
	S(def, Vector3.new(-3.5, 0, 0.3), Vector3.new(3.5, 9, 0.9), "wall")
	def.interact.door = Vector3.new(0, 4.5, 0)
	local crest = face(Vector3.new(0, 11.2, -0.2), Vector3.new(0, 0, -1))
	PC(def, crest, Vector3.new(3, 3.4, 0.3), Color3.fromRGB(40, 60, 120), SM, { name = "Crest" })
	PC(def, crest * CFrame.new(0, 0, -0.18), Vector3.new(2.2, 2.6, 0.06), C.gold, Enum.Material.Metal)
	PC(def, crest * CFrame.new(0, -1.5, 0.05) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(1.9, 1.9, 0.28), Color3.fromRGB(40, 60, 120), SM)
	keep(def, Vector3.new(-6, -1, -13), Vector3.new(6, 5, 1))

	-- Columnas bajo la galería
	for _, z in { -14.5, -37, -60, -83, -105.5 } do
		PS(def, Vector3.new(-19.1, 0, z - 0.5), Vector3.new(-18.1, F2 - 1, z + 0.5), C.marble, Enum.Material.Marble, "deco")
		PS(def, Vector3.new(18.1, 0, z - 0.5), Vector3.new(19.1, F2 - 1, z + 0.5), C.marble, Enum.Material.Marble, "deco")
	end
	for _, x in { -9, 9 } do
		PS(def, Vector3.new(x - 0.5, 0, -14.1), Vector3.new(x + 0.5, F2 - 1, -13.1), C.marble, Enum.Material.Marble, "deco")
		PS(def, Vector3.new(x - 0.5, 0, -106.9), Vector3.new(x + 0.5, F2 - 1, -105.9), C.marble, Enum.Material.Marble, "deco")
	end

	-- Barandilla de la galería (hueco a la derecha junto al reloj de pie: punto para el salto alto)
	local RH = 3
	local function rail(a: Vector3, b: Vector3)
		PS(def, a, b, C.rail, Enum.Material.Wood, "rail")
	end
	rail(Vector3.new(-18.4, F2, -106.4), Vector3.new(-18, F2 + RH, -13.6))
	rail(Vector3.new(18, F2, -106.4), Vector3.new(18.4, F2 + RH, -44))
	rail(Vector3.new(18, F2, -40), Vector3.new(18.4, F2 + RH, -13.6))
	rail(Vector3.new(-18, F2, -14), Vector3.new(18, F2 + RH, -13.6))
	rail(Vector3.new(-18, F2, -106.4), Vector3.new(-4, F2 + RH, -106))
	rail(Vector3.new(4, F2, -106.4), Vector3.new(18, F2 + RH, -106))
	-- Reloj de pie (planta 1) junto al hueco de la barandilla
	PS(def, Vector3.new(15.6, 0, -43), Vector3.new(17, 6, -41), C.caseDark, Enum.Material.Wood, "deco", { name = "Clock" })
	P(def, Vector3.new(15.5, 4, -42.6), Vector3.new(15.6, 5.4, -41.4), Color3.fromRGB(240, 230, 200), SM)
	keep(def, Vector3.new(13, -1, -46), Vector3.new(18, 7, -38))

	-- Escalera: tramo 1 (z -70 → -84), rellano trasero (y = 7), tramo 2 (z -92 → -106)
	for k = 1, 10 do
		local z0, z1 = -70 - 1.4 * (k - 1), -70 - 1.4 * k
		PS(def, Vector3.new(-4, 0, z1), Vector3.new(4, 0.7 * k, z0), C.stair, Enum.Material.WoodPlanks, "stair")
		spot(def, Vector3.new(if k % 2 == 0 then 2.4 else -2.4, 0.7 * k, (z0 + z1) / 2), "step", 3, 0)
		local z2, z3 = -92 - 1.4 * (k - 1), -92 - 1.4 * k
		PS(def, Vector3.new(-4, 0, z3), Vector3.new(4, 7 + 0.7 * k, z2), C.stair, Enum.Material.WoodPlanks, "stair")
		spot(def, Vector3.new(if k % 2 == 0 then -2.4 else 2.4, 7 + 0.7 * k, (z2 + z3) / 2), "step", 3, 0)
		for _, sx in { -1, 1 } do
			local x0 = if sx < 0 then -4.4 else 4
			PS(def, Vector3.new(x0, 0, z1), Vector3.new(x0 + 0.4, 0.7 * k + RH, z0), C.rail, Enum.Material.Wood, "rail")
			PS(def, Vector3.new(x0, 0, z3), Vector3.new(x0 + 0.4, 7 + 0.7 * k + RH, z2), C.rail, Enum.Material.Wood, "rail")
		end
	end
	PS(def, Vector3.new(-6, 0, -92), Vector3.new(6, 7, -84), C.stair, Enum.Material.WoodPlanks, "stair")
	for _, sx in { -1, 1 } do
		local x0 = if sx < 0 then -6.4 else 6
		PS(def, Vector3.new(x0, 0, -92), Vector3.new(x0 + 0.4, 7 + RH, -84), C.rail, Enum.Material.Wood, "rail")
		PS(def, Vector3.new(if sx < 0 then -6.4 else 4.4, 0, -84.4), Vector3.new(if sx < 0 then -4.4 else 6.4, 7 + RH, -84), C.rail, Enum.Material.Wood, "rail")
		PS(def, Vector3.new(if sx < 0 then -6.4 else 4.4, 0, -92), Vector3.new(if sx < 0 then -4.4 else 6.4, 7 + RH, -91.6), C.rail, Enum.Material.Wood, "rail")
	end
	-- Podio con el cristal de recuperación
	PS(def, Vector3.new(-5.6, 7, -88.8), Vector3.new(-4.4, 8.4, -87.2), C.marble, Enum.Material.Marble, "deco")
	PC(def, CFrame.new(-5, 9.2, -88) * CFrame.Angles(math.pi / 4, math.pi / 4, 0), Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(120, 230, 255), Enum.Material.Neon,
		{ name = "Crystal", interact = "crystal", collide = false })
	S(def, Vector3.new(-5.5, 8.4, -88.5), Vector3.new(-4.5, 10, -87.5), "deco")
	def.interact.crystal = Vector3.new(-5, 9.2, -88)
	table.insert(def.lights, { pos = Vector3.new(-5, 9.6, -88), range = 10, brightness = 1.5, color = Color3.fromRGB(140, 230, 255), shadows = false })
	def.podium = { Vector3.new(-5, 7, -90.6), Vector3.new(-5, 7, -85.6) }
	keep(def, Vector3.new(-6, 6.9, -92), Vector3.new(-3.6, 9, -84))
	-- Pilar con jarrón (llave amarilla dentro) en la esquina del rellano
	PS(def, Vector3.new(5, 7, -85), Vector3.new(6, 14, -84), C.marble, Enum.Material.Marble, "deco")
	PC(def, CFrame.new(5.5, 14.75, -84.5), Vector3.new(1.5, 1.5, 1.5), Color3.fromRGB(200, 120, 50), SM, { shape = "Ball", collide = false, query = false, name = "Vase" })
	S(def, Vector3.new(4.85, 14, -85.15), Vector3.new(6.15, 15.4, -83.85), "deco")
	keep(def, Vector3.new(3.5, 6.9, -86.5), Vector3.new(6.4, 9, -84))

	-- Mapas al pie de la escalera de cada planta
	mapBoard(def, 1, Vector3.new(8.5, 0, -67.5), Vector3.new(0, 0, 1))
	mapBoard(def, 2, Vector3.new(-9, F2, -109), Vector3.new(0, 0, 1))

	-- Carta de la rectora en un atril junto a la salida, y mesa con el montón de inicio junto a 1A
	PS(def, Vector3.new(-4.2, 0, -9.6), Vector3.new(-2.8, 3, -8.4), C.caseDark, Enum.Material.Wood, "deco")
	PC(def, CFrame.new(-3.5, 3.15, -9) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(1.8, 0.1, 1.4), C.caseDark, Enum.Material.Wood)
	PC(def, CFrame.new(-3.5, 3.24, -9) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(1.2, 0.04, 0.9), Color3.fromRGB(250, 245, 230), SM,
		{ name = "Letter", interact = "letter", collide = false })
	def.interact.letter = Vector3.new(-3.5, 3.2, -9)

	-- Cofres (con su cuadro-pista) y llaves
	chest(def, "red", -12, 0, -2.5, 0)
	chest(def, "green", 12, 0, -2.5, 0)
	chest(def, "yellow", -10, F2, -2.5, 0)
	chest(def, "blue", 10, F2, -2.5, 0)
	key(def, "red", Vector3.new(5.4, 4.6, -0.25), false)
	key(def, "green", Vector3.new(8, 1.68, -12), true)
	key(def, "yellow", Vector3.new(5.5, 15.1, -84.5), false)
	key(def, "blue", Vector3.new(4, 14 + caseHeight(4) + 0.45, -119.2), true)

	-- Muebles de la planta 1: mesas con bancos y lámparas, banco de la llave verde
	local tutorialSpot = #def.spots + 1
	readingTable(def, -24, 0, -14, true, false)
	bench(def, 8, 0, -12, true, false)
	local greenSpot = #def.spots + 1
	spot(def, Vector3.new(8, 1.6, -12), "special", 6, 0.3)
	for i, z in { -26, -42, -58 } do
		for _, x in { -10, 10 } do
			readingTable(def, x, 0, z, true, i ~= 2)
			bench(def, x - 2.6, 0, z, true, true)
			bench(def, x + 2.6, 0, z, true, true)
		end
	end
	for _, z in { -80, -98 } do
		for _, x in { -12, 12 } do
			readingTable(def, x, 0, z, true, false)
		end
	end
	for _, z in { -30, -66, -100 } do
		bench(def, -24, 0, z, true, true)
		bench(def, 24, 0, z, true, true)
	end
	vase(def, -16.5, 0, -12.5, 1.2)
	vase(def, 16.5, 0, -12.5, 1.2)
	vase(def, -16.5, 0, -108, 1.2)
	vase(def, 16.5, 0, -108, 1.2)
	-- Planta 2
	for _, x in { -6, 6 } do
		readingTable(def, x, F2, -8.5, false, true)
	end
	for _, z in { -32, -62, -92 } do
		readingTable(def, -24.5, F2, z, true, z == -62)
		readingTable(def, 24.5, F2, z, true, z == -62)
	end
	for _, z in { -46, -78 } do
		bench(def, -22, F2, z, true, true)
		bench(def, 22, F2, z, true, true)
	end

	-- Lámparas de techo sobre el hueco central (luz cálida)
	for _, z in { -28, -52, -76 } do
		PC(def, CFrame.new(0, 24, z), Vector3.new(4, 0.6, 4), C.gold, Enum.Material.Metal, { collide = false })
		PC(def, CFrame.new(0, 23.4, z), Vector3.new(3, 0.8, 3), Color3.fromRGB(255, 220, 160), Enum.Material.Neon, { collide = false })
		P(def, Vector3.new(-0.1, 24.3, z - 0.1), Vector3.new(0.1, 30, z + 0.1), C.metal, Enum.Material.Metal, { collide = false })
		table.insert(def.lights, { pos = Vector3.new(0, 22.8, z), range = 48, brightness = 1.3, color = Color3.fromRGB(255, 214, 160), shadows = true })
	end
	for _, p in { Vector3.new(-25, 11, -60), Vector3.new(25, 11, -60), Vector3.new(0, 11, -113), Vector3.new(-25, 11, -20), Vector3.new(25, 11, -20) } do
		table.insert(def.lights, { pos = p, range = 26, brightness = 0.8, color = Color3.fromRGB(255, 205, 150), shadows = false })
	end

	-- Secciones en las paredes (zigzag: impares a la izquierda, pares a la derecha, otras al fondo)
	local widths: { [string]: number } = {}
	for _, sec in BookData.Sections do
		widths[sec.code] = Layout.caseWidth(sec.n10, sec.n5, sec.n3, sec.levels)
	end
	local placement: { [string]: CFrame } = {}
	local function merge(t: { [string]: CFrame })
		for k, v in t do
			placement[k] = v
		end
	end
	merge(wallRun({ "1A", "1C", "1E", "1G", "1I", "1K" }, "left", 0, -8, -118, widths))
	merge(wallRun({ "1B", "1D", "1F", "1H", "1J", "1L" }, "right", 0, -8, -118, widths))
	merge(wallRun({ "1M", "1N" }, "back", 0, -23, 23, widths))
	merge(wallRun({ "2A", "2C", "2E", "2G", "2I", "2K" }, "left", F2, -2, -118, widths))
	merge(wallRun({ "2B", "2D", "2F", "2H", "2J", "2L" }, "right", F2, -2, -118, widths))
	merge(wallRun({ "2M", "2N", "2O", "2P", "2Q" }, "back", F2, -26.8, 26.8, widths))
	for _, sec in BookData.Sections do
		local cf = placement[sec.code]
		assert(cf, sec.code)
		addCase(def, sec.code, sec.code, sec.floor, sec.levels, sec.series, cf)
	end
	assert(#def.sections == 31, "deben ser 31 secciones")
	assert(#def.rows == Config.TOTAL_SERIES, "deben ser 400 filas")
	assert(#def.slotCF == Config.TOTAL_BOOKS, "deben ser 3.072 huecos")
	assert(#def.books == Config.TOTAL_BOOKS, "deben ser 3.072 libros")

	-- Huecos para montones en los suelos (planta 1 entera y anillo de la planta 2)
	gridSpots(def, r, 0, -29.2, 29.2, -2.6, -117.6, 2.6, 0.5, function()
		return true
	end)
	gridSpots(def, r, F2, -29.2, 29.2, -2.6, -117.6, 2.6, 0.55, function(x, z)
		return x < -18.9 or x > 18.9 or z > -13 or z < -107
	end)

	-- Montón de inicio: las 2 series reconocibles de 1A, alternadas (búho, dragón, búho…) en los 3 huecos
	-- de la mesa junto a la sección: 7 + 7 + 6 libros, nunca dos de la misma serie juntos.
	local tut = { BookData.SectionByCode["1A"].series[1], BookData.SectionByCode["1A"].series[2] }
	def.tutorialSeries = tut
	local reserved: { [number]: { number } } = {}
	local a, b = {}, {}
	for v = 1, 10 do
		table.insert(a, def.seriesFirst[tut[1]] + v - 1)
		table.insert(b, def.seriesFirst[tut[2]] + v - 1)
	end
	r.shuffle(a)
	r.shuffle(b)
	local mixed = {}
	for v = 1, 10 do
		table.insert(mixed, a[v])
		table.insert(mixed, b[v])
	end
	local used: { [number]: boolean } = {}
	local sizes = { 7, 7, 6 }
	local cursor = 0
	for k = 1, 3 do
		local list = {}
		for j = 1, sizes[k] do
			list[j] = mixed[cursor + j]
			used[mixed[cursor + j]] = true
		end
		cursor += sizes[k]
		reserved[tutorialSpot + k - 1] = list
	end
	-- Banco de la llave verde: un montón encima de la llave
	local pool = {}
	for id = 1, #def.books do
		if not used[id] then
			table.insert(pool, id)
		end
	end
	r.shuffle(pool)
	local greenPile = {}
	for _ = 1, 6 do
		table.insert(greenPile, table.remove(pool) :: number)
	end
	reserved[greenSpot] = greenPile
	fillSpots(def, r, pool, reserved)
	assert(#def.initial == Config.TOTAL_BOOKS, "todos los libros necesitan sitio inicial")
	for id = 1, #def.books do
		assert(def.initial[id], "libro sin sitio inicial " .. id)
	end
	return def
end

---------------------------------------------------------------------
-- El Archivo (fase especial): 300 libros, 3 estanterías de 10 series de 10
---------------------------------------------------------------------
local function buildSpecial(): Def
	local def = newDef("special")
	local r = rng(Layout.SEED + 7)
	local X0, X1, Z0, Z1 = 110, 146, -40, -70
	def.bounds = Geo.box(Vector3.new(X0, -1, Z1), Vector3.new(X1, 14, Z0), "bounds")
	def.spawn = face(Vector3.new(128, 0, -43), Vector3.new(0, 0, -1))
	PS(def, Vector3.new(X0 - 2, -1, Z1 - 2), Vector3.new(X1 + 2, 0, Z0 + 2), C.floor, Enum.Material.WoodPlanks, "floor")
	PS(def, Vector3.new(X0 - 2, 14, Z1 - 2), Vector3.new(X1 + 2, 15, Z0 + 2), C.roof, Enum.Material.Wood, "wall")
	local bands = { { 9.5, 12.5, 4 } }
	local solid = { { -1, 9.5 }, { 12.5, 15 } }
	windowWall(def, false, X0 - 2, X0, Z0 + 2, Z1 - 2, { -48, -62 }, bands, solid)
	windowWall(def, false, X1, X1 + 2, Z0 + 2, Z1 - 2, { -48, -62 }, bands, solid)
	windowWall(def, true, Z1 - 2, Z1, X0, X1, { 118, 138 }, bands, solid)
	windowWall(def, true, Z0, Z0 + 2, X0, X1, {}, {}, { { -1, 15 } }, { { 125.5, 130.5, -1, 8 } })
	P(def, Vector3.new(125.5, 0, Z0 + 0.3), Vector3.new(130.5, 8, Z0 + 0.9), C.caseDark, Enum.Material.Wood, { name = "Door", interact = "door" })
	S(def, Vector3.new(125.5, 0, Z0 + 0.3), Vector3.new(130.5, 8, Z0 + 0.9), "wall")
	def.interact.door = Vector3.new(128, 4, Z0)
	keep(def, Vector3.new(124, -1, -48), Vector3.new(132, 4, Z0))
	PC(def, CFrame.new(128, 11, Z0 - 0.2), Vector3.new(6, 1.4, 0.2), C.gold, Enum.Material.Metal, { name = "ArchiveSign" })
	-- Series: copias de 10 series de 1A, 1I y 2E
	local themes = { { "X1", "1A" }, { "X2", "1I" }, { "X3", "2E" } }
	local seriesOf: { [string]: { number } } = {}
	for _, t in themes do
		local list = {}
		for i = 1, 10 do
			local sid = BookData.SectionByCode[t[2]].series[i]
			table.insert(list, sid)
			def.seriesSection[sid] = t[1]
			def.seriesFirst[sid] = #def.books + 1
			table.insert(def.seriesList, sid)
			for v = 1, BookData.Series[sid].volumes do
				table.insert(def.books, { series = sid, vol = v })
			end
		end
		seriesOf[t[1]] = list
	end
	local depth = Layout.CASE_DEPTH
	addCase(def, "X1", "1A", 1, 5, seriesOf.X1, face(Vector3.new(X0 + depth, 0, -55), Vector3.new(1, 0, 0)))
	addCase(def, "X2", "1I", 1, 5, seriesOf.X2, face(Vector3.new(128, 0, Z1 + depth), Vector3.new(0, 0, 1)))
	addCase(def, "X3", "2E", 1, 5, seriesOf.X3, face(Vector3.new(X1 - depth, 0, -55), Vector3.new(-1, 0, 0)))
	assert(#def.rows == 30 and #def.slotCF == 300 and #def.books == 300, "el Archivo debe tener 30 filas y 300 libros")
	readingTable(def, 122, 0, -55, true, true)
	readingTable(def, 134, 0, -55, true, true)
	table.insert(def.lights, { pos = Vector3.new(128, 12, -55), range = 40, brightness = 1.2, color = Color3.fromRGB(255, 214, 160), shadows = true })
	gridSpots(def, r, 0, X0 + 3, X1 - 3, Z0 - 3, Z1 + 3, 2.6, 0.75, function()
		return true
	end)
	local pool = {}
	for id = 1, #def.books do
		table.insert(pool, id)
	end
	r.shuffle(pool)
	fillSpots(def, r, pool, {})
	return def
end

local cache: { [string]: Def } = {}
function Layout.get(name: string): Def
	if not cache[name] then
		cache[name] = if name == "special" then buildSpecial() else buildMain()
	end
	return cache[name]
end

-- Planta en la que está un punto (1 o 2) según su altura
function Layout.floorAt(def: Def, y: number): number
	if #def.floors > 1 and y >= def.floors[2] - 1.5 then
		return 2
	end
	return 1
end

-- Posición (centro) de un libro según su sitio
function Layout.bookCF(def: Def, bookId: number, loc: Codec.Loc): CFrame
	if loc.k == 1 then
		return def.slotCF[loc.s :: number]
	elseif loc.k == 2 then
		return Layout.flatCF(loc.p :: Vector3, loc.yaw or 0)
	end
	local init = def.initial[bookId]
	return Layout.flatCF(init.pos, init.yaw)
end

return Layout
