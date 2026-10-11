--[[
	Prueba del MUNDO: construye la biblioteca real (servidor) y dibuja los libros reales (cliente) en Lune.
	Uso: lune run run_world.luau <test.rbxl>
	Comprueba: 31 secciones, 400 filas con su nº de huecos, 3.072 libros con sitio inicial, ningún libro dentro
	de paredes o muebles, libros en las dos plantas, llaves que exigen saltar, punto de salto a la planta 2 y el
	total de piezas (< 15.000). Termina con «MUNDO OK».
]]

local M = require("./mock")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local process = require("@lune/process")

local W = M.new(process.args[1])
local RS = W.game:GetService("ReplicatedStorage")
local SSS = W.game:GetService("ServerScriptService")
local WS = W.game:GetService("Workspace")
local Config = W.require(W.wrap(RS:FindFirstChild("Config")))
local BookData = W.require(W.wrap(RS:FindFirstChild("BookData")))
local Layout = W.require(W.wrap(RS:FindFirstChild("Layout")))
local Geo = W.require(W.wrap(RS:FindFirstChild("Geo")))

local function check(cond, msg)
	if not cond then
		error("FALLO: " .. msg, 2)
	end
end
local function count(inst, pred)
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") and (not pred or pred(d)) then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------
-- Servidor: construye el edificio
---------------------------------------------------------------------
local t0 = os.clock()
local Building = W.require(W.wrap(SSS:FindFirstChild("Lib"):FindFirstChild("Building")))
local main = Layout.get("main")
local special = Layout.get("special")
Building.build(main, W.wrap(WS))
Building.build(special, W.wrap(WS))
local library = WS:FindFirstChild("Library")
local archive = WS:FindFirstChild("Archive")
check(library and archive, "no se creó el edificio")
local buildingParts = count(library) + count(archive)
print(string.format("  · edificio: %d piezas (biblioteca %d + Archivo %d) en %.2f s", buildingParts, count(library), count(archive), os.clock() - t0))

---------------------------------------------------------------------
-- Estructura: secciones, filas y huecos
---------------------------------------------------------------------
check(#main.sections == 31, "31 secciones")
check(#main.rows == 400, "400 filas")
check(#main.slotCF == 3072 and #main.books == 3072, "3.072 huecos y libros")
local perLen = { [10] = 0, [5] = 0, [3] = 0 }
for _, sec in BookData.Sections do
	local ls = main.sectionByCode[sec.code]
	check(ls, "falta la sección " .. sec.code)
	local want = { [10] = sec.n10, [5] = sec.n5, [3] = sec.n3 }
	local got = { [10] = 0, [5] = 0, [3] = 0 }
	for _, rowId in ls.rows do
		local row = main.rows[rowId]
		check(row.section == sec.code, "fila en sección equivocada")
		got[row.len] += 1
		perLen[row.len] += 1
		-- los huecos de la fila son consecutivos, de izquierda a derecha visto de frente
		for i = 1, row.len do
			local slot = row.first + i - 1
			check(main.slotRow[slot] == rowId and main.slotIndex[slot] == i, "huecos mal numerados")
			if i > 1 then
				local prev = main.slotCF[slot - 1]
				local right = -row.cf.RightVector -- derecha del que mira la estantería
				check((main.slotCF[slot].Position - prev.Position):Dot(right) > 0.4, "el tomo " .. i .. " no está a la derecha del anterior en " .. sec.code)
			end
		end
	end
	for _, len in { 10, 5, 3 } do
		check(got[len] == want[len], string.format("%s: %d filas de %d (deben ser %d)", sec.code, got[len], len, want[len]))
	end
	-- la placa existe en el mundo
	check(library:FindFirstChild("plates"):FindFirstChild("Plate_" .. sec.code), "falta la placa de " .. sec.code)
end
check(perLen[10] == 256 and perLen[5] == 40 and perLen[3] == 104, "256 filas de 10, 40 de 5 y 104 de 3")
print(string.format("  · 31 secciones · 400 filas (256 de 10, 40 de 5, 104 de 3) · 3.072 huecos"))

-- Ninguna estantería se solapa con otra ni con la escalera
for i, a in main.sections do
	for j, b in main.sections do
		if i < j and a.floor == b.floor then
			local overlap = a.box.min.X < b.box.max.X and b.box.min.X < a.box.max.X and a.box.min.Z < b.box.max.Z and b.box.min.Z < a.box.max.Z
			check(not overlap, "las secciones " .. a.code .. " y " .. b.code .. " se solapan")
		end
	end
end

---------------------------------------------------------------------
-- Libros: sitio inicial, dentro de paredes, plantas
---------------------------------------------------------------------
local inside, floating, perFloor, crossFloor = 0, 0, { 0, 0 }, 0
for id = 1, #main.books do
	local init = main.initial[id]
	check(init, "libro sin sitio inicial " .. id)
	local cf = Layout.flatCF(init.pos, init.yaw)
	for _, c in { Vector3.new(0, 0.68, 0.48), Vector3.new(0, -0.68, 0.48), Vector3.new(0, 0.68, -0.48), Vector3.new(0, -0.68, -0.48), Vector3.zero } do
		local box = Geo.inside(main.solids, cf * c, 0.02)
		if box then
			inside += 1
			if inside <= 5 then
				print("    dentro de", box.kind, "libro", id, init.pos)
			end
			break
		end
	end
	local top = Geo.surfaceBelow(main.solids, init.pos.X, init.pos.Z, init.pos.Y)
	if not top or init.pos.Y - top > 0.2 + 0.4 * 12 then
		floating += 1
	end
	local f = Layout.floorAt(main, init.pos.Y - 0.2)
	perFloor[f] += 1
	local sec = BookData.SectionByCode[BookData.Series[main.books[id].series].section]
	if sec.floor ~= f then
		crossFloor += 1
	end
end
check(inside == 0, inside .. " libros empiezan dentro de paredes o muebles")
check(floating == 0, floating .. " libros flotan")
check(perFloor[1] > 800 and perFloor[2] > 800, "debe haber libros en las dos plantas")
check(crossFloor > 600, "debe haber libros de la planta 1 arriba y al revés")
print(string.format("  · 3.072 libros con sitio inicial: %d en la planta 1, %d en la planta 2 (%d en la otra planta) · 0 dentro de paredes", perFloor[1], perFloor[2], crossFloor))

-- Montones: nunca dos tomos de la misma serie juntos
local stacks = {}
for id = 1, #main.books do
	local p = main.initial[id].pos
	local key = string.format("%.0f:%.0f", p.X * 2, p.Z * 2)
	stacks[key] = stacks[key] or {}
	table.insert(stacks[key], id)
end
local clash = 0
for _, list in stacks do
	table.sort(list, function(a, b) return main.initial[a].pos.Y < main.initial[b].pos.Y end)
	for k = 2, #list do
		local a, b = main.books[list[k - 1]], main.books[list[k]]
		if a.series == b.series and math.abs(main.initial[list[k - 1]].pos.Y - main.initial[list[k]].pos.Y) < 0.5 then
			clash += 1
		end
	end
end
check(clash == 0, clash .. " parejas de la misma serie empiezan juntas")
-- Montón de inicio: las 2 series de 1A en la mesa de junto a la sección
for _, sid in main.tutorialSeries do
	check(BookData.Series[sid].section == "1A" and BookData.Series[sid].volumes == 10, "el montón de inicio debe ser de 1A")
	for v = 1, 10 do
		local p = main.initial[main.seriesFirst[sid] + v - 1].pos
		check((Vector3.new(p.X, 0, p.Z) - Vector3.new(-24, 0, -14)).Magnitude < 5 and p.Y > 3, "el montón de inicio no está en su mesa")
	end
end
print("  · montones: ningún tomo empieza junto a otro de su serie · montón de inicio (búho y dragones) en su mesa")

---------------------------------------------------------------------
-- Llaves, saltos y objetos
---------------------------------------------------------------------
local function standingDist(key, spots)
	local best = math.huge
	for _, p in spots do
		best = math.min(best, (p - key).Magnitude)
	end
	return best
end
local KEY = Config.KEY_REACH
local red = main.interact.key_red
check(standingDist(red, { Vector3.new(5.4, 3, -1.6) }) <= KEY, "la llave roja debe cogerse de pie")
local yellow = main.interact.key_yellow
local landing = { Vector3.new(4.4, 10, -84.6), Vector3.new(4.4, 10, -86), Vector3.new(5.6, 10, -85.6) }
check(standingDist(yellow, landing) > KEY, "la llave amarilla no debe alcanzarse sin saltar")
check(standingDist(yellow, { Vector3.new(4.4, 10 + Config.JUMP_HEIGHT * 0.6, -84.6) }) <= KEY, "la llave amarilla debe alcanzarse saltando")
local blue = main.interact.key_blue
check(standingDist(blue, { Vector3.new(blue.X, 17, -117.9) }) > KEY, "la llave azul no debe alcanzarse sin saltar")
check(standingDist(blue, { Vector3.new(blue.X, 17 + Config.JUMP_HEIGHT * 0.6, -117.9) }) <= KEY, "la llave azul debe alcanzarse saltando")
-- Llave verde bajo un montón de libros
local covered = 0
local green = main.interact.key_green
for id = 1, #main.books do
	local p = main.initial[id].pos
	if math.abs(p.X - green.X) < 1 and math.abs(p.Z - green.Z) < 1 and p.Y > green.Y then
		covered += 1
	end
end
check(covered >= 3, "la llave verde debe empezar tapada por libros")
-- Punto de salto a la planta 2: reloj (6) + salto alto llega a la galería y la barandilla tiene hueco
check(6 + Config.JUMP_HEIGHT >= Layout.FLOOR2 + 1, "el salto alto no llega a la planta 2 desde el reloj")
for _, b in main.solids do
	if b.kind == "rail" and b.min.X >= 17.9 and b.max.X <= 18.5 then
		check(b.max.Z <= -44 or b.min.Z >= -40, "la barandilla no deja hueco junto al reloj")
	end
end
for _, name in { "Door", "Crystal", "Letter", "MapBoard1", "MapBoard2", "Chest_red", "Chest_green", "Chest_yellow", "Chest_blue", "Key_red", "Key_blue", "Spawn" } do
	local found = false
	for _, d in library:GetDescendants() do
		if d.Name == name then
			found = true
			break
		end
	end
	check(found, "falta " .. name)
end
print(string.format("  · llaves: roja de pie, amarilla y azul solo saltando, verde tapada por %d libros · salto alto a la planta 2 desde el reloj", covered))

---------------------------------------------------------------------
-- Cliente: dibuja los libros y cuenta piezas
---------------------------------------------------------------------
local player = W.addPlayer(7, "Lector")
W.player = player
W.mocks.Players.LocalPlayer = player
local SPS = W.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local Books = W.require(W.wrap(SPS:FindFirstChild("Client"):FindFirstChild("Books")))
local Codec = W.require(W.wrap(RS:FindFirstChild("Codec")))
local t1 = os.clock()
Books.init()
local locs = {}
for id = 1, #main.books do
	locs[id] = { k = 0 }
end
Books.load(main, locs)
local clientBooks = WS:FindFirstChild("ClientBooks")
local clientParts = count(clientBooks)
check(clientParts == 3072 * 2 + 400, "el cliente debe crear 2 piezas por libro + 400 cajas de fila (hay " .. clientParts .. ")")
-- Peor caso: todos los libros en su sitio y brillando (una pieza de brillo por hueco)
local allShelved = {}
for id = 1, #main.books do
	allShelved[id] = { k = 1, s = id }
end
Books.load(main, allShelved)
local glowParts = count(clientBooks:FindFirstChild("Glows"))
check(Books.countCorrect() == 400, "con cada libro en su hueco, las 400 filas deben ser correctas (hay " .. Books.countCorrect() .. ")")
check(glowParts == 3072, "debe haber un brillo dorado por libro")
local total = buildingParts + clientParts + glowParts
check(total < 15000, "demasiadas piezas: " .. total)
print(string.format("  · cliente: %d piezas de libros + %d brillos (peor caso) en %.2f s · TOTAL %d piezas (< 15.000)", clientParts, glowParts, os.clock() - t1, total))
-- Etiquetas reutilizables: como mucho 36 activas
W.camera.CFrame = Layout.face(Vector3.new(-26, 4.5, -14), Vector3.new(-1, 0, 0))
Books.updateLabels(W.camera.CFrame)
local active = 0
for _, g in player:FindFirstChild("PlayerGui"):GetChildren() do
	if g.Name == "BookLabel" and g.Enabled then
		active += 1
	end
end
check(active > 0 and active <= 36, "etiquetas de lomo activas: " .. active)
print("  · etiquetas de lomo reutilizables: " .. active .. " activas de 36")
-- Codec: ida y vuelta exacta
local sample = {}
for id = 1, #main.books do
	local init = main.initial[id]
	sample[id] = if id % 3 == 0 then { k = 1, s = id } elseif id % 3 == 1 then { k = 2, p = init.pos, yaw = init.yaw } else { k = 0 }
end
local str = Codec.encodeAll(sample)
check(#str == 3072 * 8, "la foto debe ocupar 8 caracteres por libro")
local back = Codec.decodeAll(str, 3072)
for id = 1, #main.books do
	local a, b = sample[id], back[id]
	check(a.k == b.k and a.s == b.s, "codec: tipo/hueco distinto en " .. id)
	if a.k == 2 then
		check((a.p - b.p).Magnitude < 1e-6 and math.abs(a.yaw - b.yaw) < 1e-6, "codec: posición distinta en " .. id)
	end
end
print(string.format("  · guardado compacto: %d caracteres por ranura, ida y vuelta exacta", #str))
-- El Archivo
check(#special.rows == 30 and #special.books == 300, "el Archivo debe tener 30 filas y 300 libros")
-- Volcado para dibujar la planta (tools/harness/plan.py)
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local dump = { pieces = {}, books = {}, sections = {}, interact = {} }
for _, piece in main.pieces do
	local c, sz = piece.cf.Position, piece.size
	local rx = piece.cf.RightVector
	local ex = math.abs(rx.X) * sz.X + math.abs(piece.cf.UpVector.X) * sz.Y + math.abs(piece.cf.LookVector.X) * sz.Z
	local ez = math.abs(rx.Z) * sz.X + math.abs(piece.cf.UpVector.Z) * sz.Y + math.abs(piece.cf.LookVector.Z) * sz.Z
	local ey = math.abs(rx.Y) * sz.X + math.abs(piece.cf.UpVector.Y) * sz.Y + math.abs(piece.cf.LookVector.Y) * sz.Z
	table.insert(dump.pieces, { x = c.X, y = c.Y, z = c.Z, sx = ex, sy = ey, sz = ez, r = piece.color.R, g = piece.color.G, b = piece.color.B, t = piece.transp or 0, n = piece.name or "" })
end
for id = 1, #main.books do
	local p = main.initial[id].pos
	local cover = BookData.Series[main.books[id].series].cover
	table.insert(dump.books, { x = p.X, y = p.Y, z = p.Z, c = cover.base })
end
for _, sec in main.sections do
	table.insert(dump.sections, { code = sec.code, floor = sec.floor, x0 = sec.box.min.X, x1 = sec.box.max.X, z0 = sec.box.min.Z, z1 = sec.box.max.Z })
end
for k, v in main.interact do
	dump.interact[k] = { x = v.X, y = v.Y, z = v.Z }
end
fs.writeFile("world.json", serde.encode("json", dump))
print("MUNDO OK")
