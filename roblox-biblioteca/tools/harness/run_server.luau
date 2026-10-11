--[[
	Prueba del SERVIDOR real con un jugador falso (bot) que juega sin interfaz.
	Uso: lune run run_server.luau <test.rbxl> [normal|sin-datastore]
	- Tutorial (carta, montón de inicio, primeras filas), errores esperados, soltar/lanzar/rotar/reordenar,
	  y una partida ENTERA: el bot coloca bien los 3.072 libros (teletransportándose cerca) → 400/400.
	Termina con «TODO OK»; cualquier fallo lanza un error.
]]

local M = require("./mock")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local MODE = process.args[2] or "normal"
local W = M.new(process.args[1], { datastoreInitFails = MODE == "sin-datastore" })
local RS = W.game:GetService("ReplicatedStorage")
local SSS = W.game:GetService("ServerScriptService")
local Config = W.require(W.wrap(RS:FindFirstChild("Config")))
local Lang = W.require(W.wrap(RS:FindFirstChild("Lang")))
local Layout = W.require(W.wrap(RS:FindFirstChild("Layout")))
local BookData = W.require(W.wrap(RS:FindFirstChild("BookData")))
local Codec = W.require(W.wrap(RS:FindFirstChild("Codec")))

local function check(cond, msg)
	if not cond then
		error("FALLO: " .. msg, 2)
	end
end

W.runScript(SSS:FindFirstChild("LibraryServer"))
local Game = W.require(W.wrap(SSS:FindFirstChild("Lib"):FindFirstChild("Game")))
local player = W.addPlayer(42, "Jorge")
W.player = player
local def = Layout.get("main")
W.addCharacter(player, def.spawn.Position + Vector3.new(0, 3, 0))
W.Players.PlayerAdded:Fire(player)
local invoke = assert(W.callbacks.Action, "el servidor no creó la acción")
local session = assert(Game.sessions[player], "no hay sesión")

local function lastState()
	for i = #W.fired, 1, -1 do
		local f = W.fired[i]
		if f[1] == "State" and f[2] == player then
			return f[3]
		end
	end
	error("no ha llegado ningún estado")
end
local seen = 0
local function notes()
	local out = {}
	for i = seen + 1, #W.fired do
		local f = W.fired[i]
		if f[1] == "Notify" then
			table.insert(out, f[3] .. ": " .. Lang.t("es", f[4], f[5]))
		end
	end
	seen = #W.fired
	return out
end
local quiet = false
local function act(name, a, b, c)
	W.fakeTime += 0.05
	local ok, key, params, extra = invoke(player, name, a, b, c)
	if not quiet then
		print(string.format("  %-12s -> %-5s %s", name, tostring(ok), key and Lang.t("es", key, params) or ""))
	end
	return ok, key, extra
end
local function stand(pos, look)
	local l = look or Vector3.new(0, 0, -1)
	W.teleport(pos)
	W.root.CFrame = Layout.face(pos, l)
end
local lib = function()
	return session.lib
end
-- Se pone al lado de un libro y lo coge
local function pick(id)
	local p = lib():posOf(id)
	check(p, "el libro " .. id .. " no está en el mundo")
	stand(p + Vector3.new(1.5, 2, 0))
	return act("pick", id)
end
-- Se pone delante de un hueco y coloca el de arriba
local function place(slot)
	local cf = def.slotCF[slot]
	stand(cf.Position + cf.LookVector * 3, -cf.LookVector)
	return act("place", slot)
end

---------------------------------------------------------------------
print("-- Inicio y tutorial --")
local s = lastState()
check(s.mode == "main" and s.shelved == 0 and s.rows == 0 and #s.hand == 0 and s.tut == 0, "estado inicial incorrecto")
check(s.cap == 10 and s.total == 3072 and s.rowsTotal == 400, "capacidad 10, 3.072 libros, 400 filas")
act("readLetter")
check(lastState().tut == 1, "tras leer la carta, el tutorial va al paso 1")
local owl, dragon = def.tutorialSeries[1], def.tutorialSeries[2]
local function seriesBooks(sid)
	local list = {}
	for v = 1, BookData.Series[sid].volumes do
		table.insert(list, def.seriesFirst[sid] + v - 1)
	end
	return list
end
-- Coge los 10 tomos del búho (del montón de la mesa: el servidor deja bajar los de encima)
for _, id in seriesBooks(owl) do
	local ok = pick(id)
	check(ok, "no se pudo coger un libro del montón de inicio")
end
s = lastState()
check(#s.hand == 10 and s.tut == 2, "debería llevar 10 libros y estar en el paso 2 del tutorial")
-- Primera fila larga de 1A: coloca del de arriba hacia abajo, cada uno en el hueco de su tomo
local sec1A = def.sectionByCode["1A"]
local function freeRow(code, len)
	for _, rowId in def.sectionByCode[code].rows do
		local row = def.rows[rowId]
		if row.len == len then
			local empty = true
			for i = 1, row.len do
				if lib().slotBook[row.first + i - 1] then
					empty = false
				end
			end
			if empty then
				return row
			end
		end
	end
	return nil
end
local function placeHandInRow(row)
	while #lib().hand > 0 do
		local top = lib().hand[#lib().hand]
		local vol = def.books[top].vol
		local ok = place(row.first + vol - 1)
		check(ok, "no se pudo colocar el tomo " .. vol)
	end
end
quiet = true
placeHandInRow(freeRow("1A", 10))
quiet = false
s = lastState()
check(s.rows == 1 and s.shelved == 10 and s.tut == 3, "tras la primera serie: 1 fila correcta y paso 3 (rows=" .. s.rows .. ", tut=" .. s.tut .. ")")
quiet = true
for _, id in seriesBooks(dragon) do
	pick(id)
end
placeHandInRow(freeRow("1A", 10))
quiet = false
s = lastState()
check(s.rows == 2 and s.tut == 4 and s.points == 1, "tras las dos series: 2 filas, paso 4 y 1 punto")
local n = notes()
local gotPoint = false
for _, line in n do
	if string.find(line, "punto") then
		gotPoint = true
	end
	print("  aviso:", line)
end
check(gotPoint, "debería avisar del primer punto")
print("  tutorial completo · filas", s.rows, "· puntos", s.points, "· siguiente punto a las", s.nextAt, "filas")

---------------------------------------------------------------------
print("-- Errores esperados --")
local row1 = def.rows[sec1A.rows[1]]
local ok, key = act("place", row1.first)
check(not ok and key == "err_empty", "colocar sin libros")
pick(def.seriesFirst[owl]) -- saca el tomo 1 de su fila (la rompe)
check(lastState().rows == 1, "sacar un libro rompe la fila")
ok, key = place(def.rows[sec1A.rows[2]].first + 1)
check(not ok and key == "err_taken", "colocar en un hueco ocupado")
place(def.rows[sec1A.rows[1]].first) -- lo devuelve
check(lastState().rows == 2, "devolverlo arregla la fila")
stand(Vector3.new(0, 3, -6))
local farId, farD = 1, 0
for id = 1, #def.books do
	local p = lib():posOf(id)
	if p and (p - Vector3.new(0, 3, -6)).Magnitude > farD then
		farId, farD = id, (p - Vector3.new(0, 3, -6)).Magnitude
	end
end
ok, key = act("pick", farId)
check(not ok and key == "err_reach", "coger algo lejos")
ok, key = act("pick", 99999)
check(not ok and key == "err_gone", "coger un libro que no existe")
ok, key = act("bogus")
check(not ok and key == "err_generic", "acción desconocida")
ok, key = act("place", "x")
check(not ok, "hueco no válido")
-- Ritmo: más de 25 acciones por segundo
quiet = true
local slowed = false
for _ = 1, 40 do
	local okR, keyR = invoke(player, "cycle")
	if not okR and keyR == "err_slow" then
		slowed = true
	end
end
quiet = false
W.fakeTime += 1.1
check(slowed, "debería frenar a más de 25 acciones por segundo")
print("  límite de acciones por segundo: OK")
-- Manos llenas
quiet = true
local loose = {}
for id = 1, #def.books do
	if lib():isLoose(id) and def.books[id].series ~= owl and def.books[id].series ~= dragon then
		table.insert(loose, id)
	end
	if #loose >= 11 then
		break
	end
end
for i = 1, 10 do
	pick(loose[i])
end
quiet = false
ok, key = pick(loose[11])
check(not ok and key == "err_full", "coger con las manos llenas")

---------------------------------------------------------------------
print("-- Soltar, lanzar, rotar y reordenar --")
local hand = lib().hand
local topBefore = hand[#hand]
act("cycle")
check(lib().hand[1] == topBefore, "rotar: el de arriba pasa abajo")
local second = lib().hand[2]
act("reorder", 2, 10)
check(lib().hand[10] == second, "reordenar: el 2.º pasa a ser el de arriba")
-- Soltar uno delante (en el suelo de la planta 1, lejos de muebles)
stand(Vector3.new(0, 3, -20), Vector3.new(0, 0, -1))
local dropped = lib().hand[#lib().hand]
act("drop")
local dp = lib():posOf(dropped)
check(dp and math.abs(dp.Y - 0.2) < 0.01 and (dp - Vector3.new(0, 0.2, -22.2)).Magnitude < 0.3, "soltar: el libro debe quedar en el suelo delante (" .. tostring(dp) .. ")")
-- Soltar toda la pila: montón ordenado en el mismo sitio
stand(Vector3.new(6, 3, -64), Vector3.new(0, 0, -1))
local before = table.clone(lib().hand)
act("dropAll")
check(#lib().hand == 0, "soltar todo vacía la mano")
local y0 = lib():posOf(before[1]).Y
for i, id in before do
	local p = lib():posOf(id)
	check(math.abs(p.Y - (y0 + (i - 1) * 0.4)) < 0.01, "soltar todo: montón ordenado de abajo arriba")
end
print("  soltar todo: montón de", #before, "libros de", y0, "a", lib():posOf(before[#before]).Y)
-- Coger del medio del montón: los de encima bajan
local mid = before[3]
local above = before[4]
local yAbove = lib():posOf(above).Y
pick(mid)
check(math.abs(lib():posOf(above).Y - (yAbove - 0.4)) < 0.01, "al sacar un libro de un montón, los de encima bajan")
-- Lanzar por la barandilla desde la planta 2 al hueco central → cae en la planta 1
stand(Vector3.new(-20, 17, -50), Vector3.new(1, 0, 0))
local thrown = lib().hand[#lib().hand]
act("throw", Vector3.new(1, 0.1, 0).Unit)
local tp = lib():posOf(thrown)
check(tp and tp.Y < 6 and tp.X > -18 and tp.X < 18, "lanzar por la barandilla: debe caer en la planta 1 (" .. tostring(tp) .. ")")
print("  lanzado por la barandilla: cae en", tp)
-- Lanzar contra una estantería: cae al suelo delante
stand(Vector3.new(-26, 3, -14), Vector3.new(-1, 0, 0))
pick(dropped)
stand(Vector3.new(-26, 3, -14), Vector3.new(-1, 0, 0))
act("throw", Vector3.new(-1, 0, 0))
local tp2 = lib():posOf(dropped)
check(tp2 and tp2.X > -30.6 and tp2.Y < 4, "lanzar contra una estantería: cae delante (" .. tostring(tp2) .. ")")
-- Un libro fuera del mapa vuelve a su sitio inicial
lib():take(dropped)
lib():reset(dropped)
check(lib():posOf(dropped) == def.initial[dropped].pos, "un libro fuera del mapa vuelve a su sitio inicial")
lib():flush()

---------------------------------------------------------------------
print("-- Partida entera: el bot coloca bien los 3.072 libros --")
quiet = true
local t0 = os.clock()
local placed = 0
-- Primero vacía la mano
stand(Vector3.new(6, 3, -40), Vector3.new(0, 0, -1))
act("dropAll")
for _, sid in def.seriesList do
	local code = def.seriesSection[sid]
	local len = BookData.Series[sid].volumes
	-- ¿ya está bien?
	local first = def.seriesFirst[sid]
	local loc = lib().locs[first]
	local done = loc.k == 1 and lib().rowOk[def.slotRow[loc.s]]
	if not done then
		for v = 1, len do
			local id = first + v - 1
			if lib().locs[id].k ~= 3 then
				local okP, keyP = pick(id)
				check(okP, "no pudo coger " .. id .. " (" .. tostring(keyP) .. ")")
			end
		end
		local row = freeRow(code, len)
		check(row, "no hay fila libre de " .. len .. " en " .. code)
		placeHandInRow(row)
		placed += len
	end
	if #W.fired > 2000 then
		table.clear(W.fired)
	end
end
quiet = false
s = lastState()
print(string.format("  colocados %d libros en %.1f s de prueba", placed, os.clock() - t0))
check(s.rows == 400 and s.shelved == 3072 and #s.hand == 0, string.format("deberían ser 400/400 filas y 3.072 libros (%d, %d)", s.rows, s.shelved))
check(s.door == true, "con todo en estanterías la puerta se abre")
check(s.points == 45 - 0 or s.earned == 45, "con 400 filas se ganan los 45 puntos")
print("  [partida] 400/400 filas · 3.072/3.072 libros · " .. s.earned .. " puntos ganados · puerta abierta")

print("TODO OK")
