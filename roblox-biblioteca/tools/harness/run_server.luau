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
print("-- Magia menor: llaves y cofres --")
local Building = W.require(W.wrap(SSS:FindFirstChild("Lib"):FindFirstChild("Building")))
local libModel = W.game:GetService("Workspace"):FindFirstChild("Library")
local function partVisible(name)
	for _, d in libModel:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") then
			return d.Transparency < 1
		end
	end
	return nil
end
local function hum()
	return W.unwrap(player.Character):FindFirstChildOfClass("Humanoid")
end
check(hum().JumpHeight == 0, "al empezar no se puede saltar")
ok, key = act("openChest", "red")
check(not ok and key == "err_need_key", "abrir un cofre sin su llave")
-- Roja: junto al escudo de la entrada, se coge de pie
stand(Vector3.new(5.4, 3, -1.8), Vector3.new(0, 0, 1))
ok = act("takeKey", "red")
check(ok and partVisible("Key_red") == false, "coger la llave roja (y desaparece)")
stand(Vector3.new(-12, 3, -6), Vector3.new(0, 0, 1))
ok = act("openChest", "red")
s = lastState()
check(ok and s.jump == true and hum().JumpHeight == Config.JUMP_HEIGHT, "el cofre rojo da el salto alto")
check(partVisible("ChestLid_red") == false, "el cofre abierto pierde la tapa")
-- Verde: bajo un montón en el banco; hay que quitar los libros de encima
local gk = def.interact.key_green
stand(gk + Vector3.new(1.5, 1.5, 0))
ok, key = act("takeKey", "green")
check(not ok and key == "err_key_covered", "la llave verde está tapada")
quiet = true
act("dropAll")
for id = 1, #def.books do
	local p = lib():posOf(id)
	if p and lib():isLoose(id) and math.abs(p.X - gk.X) < 1 and math.abs(p.Z - gk.Z) < 1 and p.Y > gk.Y - 0.3 then
		pick(id)
	end
end
quiet = false
stand(gk + Vector3.new(1.5, 1.5, 0))
ok = act("takeKey", "green")
check(ok, "coger la llave verde tras quitar los libros")
stand(Vector3.new(12, 3, -6), Vector3.new(0, 0, 1))
act("openChest", "green")
check(lastState().run == true, "el cofre verde da correr")
-- Amarilla: en el jarrón del pilar del rellano: de pie no llega; saltando sí
local yk = def.interact.key_yellow
stand(Vector3.new(4.5, 10, -85.6))
ok, key = act("takeKey", "yellow")
check(not ok and key == "err_key_high", "la llave amarilla no se alcanza de pie")
stand(Vector3.new(4.5, 13.5, -85.2)) -- en mitad del salto
ok = act("takeKey", "yellow")
check(ok, "la llave amarilla se coge saltando")
stand(Vector3.new(-10, 17, -6), Vector3.new(0, 0, 1))
act("openChest", "yellow")
check(lastState().cap == 13, "el cofre amarillo da +3 de capacidad")
-- Azul: encima de las estanterías del fondo de la planta 2
local bk = def.interact.key_blue
stand(Vector3.new(bk.X, 17, -116.5))
ok, key = act("takeKey", "blue")
check(not ok, "la llave azul no se alcanza de pie")
stand(Vector3.new(bk.X, 21.5, -117.5))
ok = act("takeKey", "blue")
check(ok, "la llave azul se coge saltando")
stand(Vector3.new(10, 17, -6), Vector3.new(0, 0, 1))
act("openChest", "blue")
s = lastState()
check(s.cap == 15 and s.chests.red and s.chests.green and s.chests.yellow and s.chests.blue, "con los 4 cofres: capacidad 15")
check(s.magic == false, "la magia menor no cuenta como magia")
print("  [llaves] roja de pie · verde tras despejar el banco · amarilla y azul saltando · capacidad 10 → 15")

---------------------------------------------------------------------
print("-- Cristal de recuperación --")
-- Un libro lanzado encima de una estantería queda «perdido»
local lostId
for id = 1, #def.books do
	if lib():isLoose(id) then
		lostId = id
		break
	end
end
lib():take(lostId)
local caseTop = def.sectionByCode["1C"].box
lib():dropBook(lostId, (caseTop.min.X + caseTop.max.X) / 2, (caseTop.min.Z + caseTop.max.Z) / 2, 40, 0)
lib():flush()
stand(Vector3.new(0, 3, -20))
ok, key = act("useCrystal")
check(not ok and key == "err_reach", "el cristal se usa en el rellano")
stand(Vector3.new(-3, 10, -88), Vector3.new(-1, 0, 0))
ok = act("useCrystal")
local lp = lib():posOf(lostId)
check(ok and lp and (Vector3.new(lp.X, 0, lp.Z) - Vector3.new(-5, 0, -90.6)).Magnitude < 3 and lp.Y > 7, "el cristal trae el libro perdido al podio (" .. tostring(lp) .. ")")
ok, key = act("useCrystal")
check(not ok and key == "err_crystal_none", "sin libros perdidos")
check(lastState().magic == false, "el cristal no cuenta como magia")

---------------------------------------------------------------------
print("-- Magia mayor: manual y hechizos --")
s = lastState()
check(s.points == 1, "tras el tutorial hay 1 punto")
ok = act("buySkill", "sort")
check(ok and lastState().skills.sort == 1 and lastState().points == 0 and lastState().magic == true, "aprender Ordenar gasta el punto y marca magia")
ok, key = act("buySkill", "guide")
check(not ok and key == "err_no_points", "sin puntos no se aprende")
ok, key = act("cast", "guide")
check(not ok and key == "err_not_learned", "no se lanza lo no aprendido")
-- Ordenar
quiet = true
local some = {}
for id = 1, #def.books do
	if lib():isLoose(id) and #some < 6 then
		table.insert(some, id)
	end
end
for _, id in some do pick(id) end
quiet = false
act("cast", "sort")
local h = lib().hand
for i = 2, #h do
	local a, b = def.books[h[i - 1]], def.books[h[i]]
	check(a.series > b.series or (a.series == b.series and a.vol > b.vol), "Ordenar: pila por serie y tomo (el de arriba primero)")
end
ok, key = act("cast", "sort")
check(not ok and key == "err_cooldown", "enfriamiento de Ordenar")
-- Para probarlo todo: el bot «tiene» el récord de 200 filas (45 puntos) y lo sube todo al máximo
session.slot.best = 200
quiet = true
for _, sk in Config.Skills do
	for _ = 1, sk.max do
		act("buySkill", sk.id)
	end
end
quiet = false
s = lastState()
for _, sk in Config.Skills do
	check(s.skills[sk.id] == sk.max, sk.id .. " al máximo")
end
check(s.points == 0, "subirlo todo al máximo cuesta exactamente los 45 puntos")
ok, key = act("buySkill", "guide")
check(not ok and key == "err_maxed", "no se pasa del máximo")
-- Guía y Revelar: duran y luego enfrían
ok = act("cast", "guide")
s = lastState()
check(ok and s.active.guide > 59 and s.cd.guide > 64, "Guía nivel 10: 60 s activa + 5 s de enfriamiento")
ok, key = act("cast", "guide")
check(not ok and key == "err_active", "no se relanza mientras dura")
ok = act("cast", "reveal")
check(ok and lastState().active.reveal > 39, "Revelar nivel 10: 40 s")
-- Reunir: con un tomo en la mano, atrae los demás de su serie que estén sueltos
quiet = true
act("dropAll")
quiet = false
local gs
for _, sid in def.seriesList do
	local loose = 0
	for v = 1, BookData.Series[sid].volumes do
		if lib():isLoose(def.seriesFirst[sid] + v - 1) then loose += 1 end
	end
	if loose == 10 then gs = sid break end
end
pick(def.seriesFirst[gs])
ok = act("cast", "gather")
s = lastState()
check(ok and #s.hand == 10, "Reunir nivel 10 atrae 9 tomos más (" .. #s.hand .. ")")
for _, id in s.hand do
	check(def.books[id].series == gs, "Reunir solo atrae tomos de la misma serie")
end
-- Autocolocar: activo + apuntar a la sección coloca todo lo de esa sección
ok, key = act("autoPlace", def.seriesSection[gs])
check(not ok, "Autocolocar sin activar falla")
ok = act("cast", "auto")
check(ok and lastState().active.auto > 54, "Autocolocar nivel 10: 55 s")
local sec = def.sectionByCode[def.seriesSection[gs]]
stand((sec.box.min + sec.box.max) / 2 + Vector3.new(0, 3, 0) + sec.facing * 8)
ok = act("autoPlace", def.seriesSection[gs])
s = lastState()
check(ok and #s.hand == 0, "Autocolocar coloca los 10 tomos")
local first = lib().locs[def.seriesFirst[gs]]
check(first.k == 1 and lib().rowOk[def.slotRow[first.s]], "Autocolocar deja la fila correcta")
ok, key = act("autoPlace", def.seriesSection[gs])
check(not ok and key == "err_no_section_books", "Autocolocar sin libros de esa sección")
print("  [magia] Ordenar, Guía, Revelar, Reunir (9 libros) y Autocolocar (fila correcta) · 45 puntos = todo al máximo")

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
