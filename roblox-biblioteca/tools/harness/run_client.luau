--[[
	Prueba del CLIENTE con el servidor real en el mismo proceso (remotes simulados en mock.luau).
	Uso: lune run run_client.luau <test.rbxl> [pc|movil]
	Crea toda la interfaz, recibe la foto real de los 3.072 libros, apunta con la cruceta (rayo simulado),
	coge y coloca con la tecla E, abre la carta, la lista y el mapa, y pulsa TODOS los botones.
	Termina con «CLIENTE OK».
]]

local M = require("./mock")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, CFrame, Enum = roblox.Vector3, roblox.CFrame, roblox.Enum

local DEVICE = process.args[2] or "pc"
local DUMP = process.args[3] -- carpeta para la vista previa (opcional)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local W = M.new(process.args[1], { touch = DEVICE == "movil", width = if DEVICE == "movil" then 844 else 1280, height = if DEVICE == "movil" then 390 else 720 })
local RS = W.game:GetService("ReplicatedStorage")
local SSS = W.game:GetService("ServerScriptService")
local Layout = W.require(W.wrap(RS:FindFirstChild("Layout")))
local Lang = W.require(W.wrap(RS:FindFirstChild("Lang")))

local function check(cond, msg)
	if not cond then
		error("FALLO: " .. msg, 2)
	end
end

-- Servidor
W.runScript(SSS:FindFirstChild("LibraryServer"))
local Game = W.require(W.wrap(SSS:FindFirstChild("Lib"):FindFirstChild("Game")))
local player = W.addPlayer(42, "Jorge")
W.player = player
W.mocks.Players.LocalPlayer = player
local def = Layout.get("main")
W.addCharacter(player, def.spawn.Position + Vector3.new(0, 3, 0))
W.Players.PlayerAdded:Fire(player)
local session = Game.sessions[player]

-- Cliente
local SPS = W.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local t0 = os.clock()
W.runScript(SPS:FindFirstChild("LibraryClient"))
local Client = SPS:FindFirstChild("Client")
local Books = W.require(W.wrap(Client:FindFirstChild("Books")))
local Aim = W.require(W.wrap(Client:FindFirstChild("Aim")))
local Kit = W.require(W.wrap(Client:FindFirstChild("Kit")))
local ctx = Kit.ctx
check(Books.def and #Books.def.books == 3072, "el cliente debe haber recibido la foto con 3.072 libros")
print(string.format("  [arranque] interfaz y 3.072 libros creados en %.2f s", os.clock() - t0))

local function frame(n)
	for _ = 1, n or 1 do
		W.renderStepped:Fire(1 / 60)
		W.heartbeat:Fire(1 / 60)
	end
end
local function key(code)
	W.fakeTime += 0.1 -- (el servidor limita a 25 acciones por segundo)
	local io = { KeyCode = code, UserInputType = Enum.UserInputType.Keyboard }
	W.UIS.InputBegan:Fire(io, false)
	W.UIS.InputEnded:Fire(io)
end
-- Apunta la cámara a un punto desde `from`
local function look(from, at)
	W.camera.CFrame = CFrame.new(from) * CFrame.Angles(0, 0, 0)
	local d = (at - from).Unit
	local yaw = math.atan2(-d.X, -d.Z)
	local pitch = math.asin(d.Y)
	W.camera.CFrame = CFrame.new(from) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	W.teleport(from - Vector3.new(0, 1.5, 0))
	frame(1)
end
local gui = player:FindFirstChild("PlayerGui"):FindFirstChild("LibraryGui")
check(gui, "falta la interfaz")

-- Volcado de la interfaz (vista previa con preview.py)
local PROPS = {
	"Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "ZIndex", "LayoutOrder",
	"Text", "TextSize", "TextColor3", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextTransparency", "TextStrokeTransparency", "TextStrokeColor3",
	"Rotation", "ClipsDescendants", "AutomaticSize", "CornerRadius", "Color", "Thickness", "Transparency",
	"PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom", "FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment",
	"AspectRatio", "Scale", "Font", "MaxSize",
}
local function encode(v)
	local t = typeof(v)
	if t == "UDim2" then return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then return { v.Scale, v.Offset }
	elseif t == "Vector2" then return { v.X, v.Y }
	elseif t == "Color3" then return { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
	elseif t == "EnumItem" then return v.Name
	elseif t == "number" then return v ~= v and 0 or (v == math.huge and 1e9 or v)
	elseif t == "string" or t == "boolean" then return v
	end
	return nil
end
local function node(inst)
	local n = { class = inst.ClassName, name = inst.Name, children = {} }
	for _, p in PROPS do
		local ok, v = pcall(function() return inst[p] end)
		if ok and v ~= nil then n[p] = encode(v) end
	end
	for _, c in inst:GetChildren() do
		table.insert(n.children, node(c))
	end
	return n
end
local function dump(name)
	if not DUMP then return end
	frame(1)
	fs.writeFile(DUMP .. "/" .. DEVICE .. "_" .. name .. ".json", serde.encode("json", { node(W.unwrap(gui)) }))
end

---------------------------------------------------------------------
-- Menú de título → nueva partida en la ranura 1
---------------------------------------------------------------------
local function press(b)
	check(b, "botón inexistente")
	W.fakeTime += 0.1
	W.signalFor(W.idOf(W.unwrap(b)), "Activated"):Fire()
	frame(1)
end
check(ctx.state.mode == "menu", "el cliente empieza en el menú de título")
local titleFrame = gui:FindFirstChild("Root"):FindFirstChild("Title")
check(titleFrame and titleFrame.Visible, "se ve la pantalla de título")
check(W.unwrap(ctx.targets.menu_continue).Visible == false, "sin partidas no se ofrece Continuar")
dump("10_titulo")
press(ctx.targets.menu_new)
press(ctx.targets.slot_play_1)
check(ctx.state.mode == "main" and not titleFrame.Visible, "«Empezar aquí» abre la biblioteca")

---------------------------------------------------------------------
-- Carta, coger y colocar con la cruceta
---------------------------------------------------------------------
local letter = def.interact.letter
look(letter + Vector3.new(0, 1.5, -2.5), letter)
check(Aim.target and Aim.target.interact == "letter", "la cruceta debe marcar la carta")
dump("00_inicio")
key(Enum.KeyCode.E)
check(ctx.panel == "message", "E sobre la carta abre la carta")
dump("01_carta")
check(session.slot.tut == 1, "leer la carta avanza el tutorial")
ctx.closePanel()
-- Coger el libro de arriba de un montón de la mesa del tutorial
local owl = def.tutorialSeries[1]
local best, bestY = nil, -1
for v = 1, 10 do
	local id = def.seriesFirst[owl] + v - 1
	local p = session.lib:posOf(id)
	if p.Y > bestY then
		best, bestY = id, p.Y
	end
end
-- El de más arriba de su montón (puede ser de la otra serie): apuntamos a ese montón desde arriba
local target = session.lib:posOf(best)
look(target + Vector3.new(2.2, 2.2, 0), target)
check(Aim.target and Aim.target.kind == "book" and Aim.target.ok, "la cruceta debe marcar un libro del montón")
local picked = Aim.target.book
key(Enum.KeyCode.E)
check(#ctx.state.hand == 1 and ctx.state.hand[1] == picked, "E coge el libro marcado")
frame(3)
-- Colocarlo en una fila vacía de su sección
local info = def.books[picked]
local code = def.seriesSection[info.series]
local row
for _, rowId in def.sectionByCode[code].rows do
	local r = def.rows[rowId]
	if r.len == 10 and not Books.slotBook[r.first] then
		row = r
		break
	end
end
local slotCF = def.slotCF[row.first + info.vol - 1]
look(slotCF.Position + slotCF.LookVector * 2.5, slotCF.Position)
check(Aim.target and Aim.target.kind == "slot" and Aim.target.slot == row.first + info.vol - 1, "la cruceta debe marcar el hueco de su tomo")
-- Con varios libros en la mano para ver la pila
for _, id in session.lib.hand do end
local extra = {}
for id = 1, #def.books do
	if session.lib:isLoose(id) and #extra < 6 then
		table.insert(extra, id)
	end
end
for _, id in extra do
	session.lib:take(id)
end
session.lib:flush()
Game.sendState(session)
frame(1)
dump("02_mano")
key(Enum.KeyCode.Tab)
dump("03_lista")
ctx.closePanel()
key(Enum.KeyCode.M)
dump("04_mapa")
ctx.closePanel()
for _, id in extra do
	local idx = table.find(session.lib.hand, id)
	table.remove(session.lib.hand, idx)
	session.lib.locs[id] = { k = 0 }
end
Game.sendState(session)
frame(1)
key(Enum.KeyCode.E)
frame(3)
check(Books.slotBook[row.first + info.vol - 1] == picked and ctx.state.shelved == 1, "E coloca el libro en el hueco")
print("  [cruceta] carta, coger del montón y colocar en su hueco: OK")

---------------------------------------------------------------------
-- Ventanas y TODOS los botones
---------------------------------------------------------------------
key(Enum.KeyCode.Tab)
check(ctx.panel == "list", "Tab abre la lista")
key(Enum.KeyCode.Tab)
check(ctx.panel == nil, "Tab la cierra")
key(Enum.KeyCode.M)
check(ctx.panel == "map", "M abre el mapa")
ctx.closePanel()
local pressed = 0
local function pressAll(container)
	for _, b in container:GetDescendants() do
		if (b:IsA("TextButton") or b:IsA("ImageButton")) and b.Parent then
			W.fakeTime += 0.1
			W.signalFor(W.idOf(W.unwrap(b)), "Activated"):Fire()
			pressed += 1
			frame(1)
		end
	end
end
for _, name in { "list", "map", "message", "menu", "achievements", "results", "confirm" } do
	if name == "message" then
		ctx.toast("prueba", "info")
		local Panels = W.require(W.wrap(Client:FindFirstChild("Panels")))
		Panels.message("Título", "Texto")
	else
		ctx.openPanel(name)
	end
	local shell = gui:FindFirstChild("Root"):FindFirstChild("Panel_" .. name)
	check(shell and shell.Visible, "la ventana " .. name .. " debe abrirse")
	if name ~= "results" and name ~= "menu" and name ~= "confirm" then
		pressAll(shell)
	end
	ctx.closePanel()
	if ctx.state.mode ~= "main" then
		ctx.act("selectSlot", 1)
	end
end
-- Magia: el bot «tiene» 45 puntos; el manual permite aprender y la barra lanza
session.slot.best = 200
Game.sendState(session)
frame(1)
key(Enum.KeyCode.B)
check(ctx.panel == "manual", "B abre el manual")
dump("05_manual")
local manualShell = gui:FindFirstChild("Root"):FindFirstChild("Panel_manual")
for _ = 1, 3 do
	for _, b in manualShell:GetDescendants() do
		if b:IsA("TextButton") and b.Name == "Buy" then
			W.fakeTime += 0.1
			W.signalFor(W.idOf(W.unwrap(b)), "Activated"):Fire()
			pressed += 1
		end
	end
end
check(ctx.state.skills.sort == 3 and ctx.state.skills.gather == 3 and ctx.state.points == 30, "los botones del manual aprenden y suben niveles")
ctx.closePanel()
local paintings = 0
for _, g in player:FindFirstChild("PlayerGui"):GetChildren() do
	if string.sub(g.Name, 1, 12) == "PaintingGui_" then paintings += 1 end
end
check(paintings == 4, "los 4 cuadros con pistas deben tener su dibujo")
-- Cofre rojo con su llave: E abre el cofre y sale la nota de la rectora
session.slot.keys.red = true
Game.sendState(session)
local chest = def.interact.chest_red
look(chest + Vector3.new(0, 2.5, -3), chest)
check(Aim.target and Aim.target.interact == "chest_red" and Aim.target.ok, "la cruceta marca el cofre rojo")
key(Enum.KeyCode.E)
check(ctx.panel == "message" and session.slot.chests.red, "abrir el cofre muestra la nota de la rectora (panel " .. tostring(ctx.panel) .. ", abierto " .. tostring(session.slot.chests.red) .. ")")
dump("06_cofre")
ctx.closePanel()
-- Hechizos con la tecla y con la barra
key(Enum.KeyCode.Two)
check(ctx.state.active.guide > 0, "la tecla 2 lanza Guía")
frame(15)
dump("07_hechizos")

-- Pausa, opciones y logros
key(Enum.KeyCode.P)
check(ctx.panel == "menu", "P abre la pausa")
dump("11_pausa")
press(ctx.targets.pause_options)
check(ctx.panel == "options", "pausa → opciones")
local fov0 = ctx.state.settings.fov
press(ctx.targets.opt_fov_up)
check(ctx.state.settings.fov == fov0 + 5, "subir el campo de visión")
press(ctx.targets.opt_cozy)
check(ctx.state.settings.cozy == true, "activar el modo acogedor")
frame(2)
check(not gui:FindFirstChild("Root"):FindFirstChild("Timer").Visible, "el modo acogedor oculta el cronómetro")
dump("12_opciones")
-- (el botón de zurdos rehace la interfaz: se prueba aparte)
local leftToggle = W.unwrap(ctx.targets.opt_left)
for _, b in gui:FindFirstChild("Root"):FindFirstChild("Panel_options"):GetDescendants() do
	if b:IsA("TextButton") and b.Name ~= "Close" and not string.find(b.Name, "Lang_") and b.Name ~= "Backdrop" and b ~= leftToggle then
		press(b)
		pressed += 1
	end
end
press(ctx.targets.opt_cozy)
press(ctx.targets.opt_left)
check(ctx.state.settings.left == true, "botones para zurdos")
gui = player:FindFirstChild("PlayerGui"):FindFirstChild("LibraryGui")
ctx.openPanel("options")
press(ctx.targets.opt_left)
check(ctx.state.settings.left == false, "quitar botones para zurdos")
gui = player:FindFirstChild("PlayerGui"):FindFirstChild("LibraryGui")
ctx.closePanel()
key(Enum.KeyCode.P)
press(ctx.targets.pause_achievements)
check(ctx.panel == "achievements", "pausa → logros")
dump("13_logros")
ctx.closePanel()
-- Cambio de idioma: toda la interfaz se rehace en inglés
key(Enum.KeyCode.P)
press(ctx.targets.pause_options)
press(ctx.targets.opt_lang_en)
check(ctx.lang == "en", "el idioma cambia a inglés")
gui = player:FindFirstChild("PlayerGui"):FindFirstChild("LibraryGui")
local rowsEn = gui:FindFirstChild("Root"):FindFirstChild("TopCounter"):FindFirstChild("Rows").Text
check(string.find(rowsEn, "Correct rows"), "el contador sale en inglés tras rehacer la interfaz (" .. rowsEn .. ")")
dump("14_ingles")
ctx.openPanel("options")
press(ctx.targets.opt_lang_es)
check(ctx.lang == "es", "vuelta al español")
ctx.closePanel()
-- Evaluación: el servidor lo coloca todo (atajo de prueba) y se sale por la puerta
local targets = {}
for id = 1, #def.books do targets[id] = id end
session.lib:solveAll(targets)
Game.flush(session)
Game.sendState(session)
frame(2)
check(Books.countCorrect() == 400 and ctx.state.door, "con todo colocado, el cliente ve 400 filas y la puerta abierta")
local door = def.interact.door
look(door + Vector3.new(0, 0, -3.5), door)
check(Aim.target and Aim.target.interact == "door" and Aim.target.ok, "la cruceta marca la puerta abierta")
key(Enum.KeyCode.E)
check(ctx.panel == "results", "salir por la puerta muestra la evaluación")
dump("15_evaluacion")
press(ctx.targets.results_menu)
titleFrame = gui:FindFirstChild("Root"):FindFirstChild("Title")
check(ctx.state.mode == "menu" and titleFrame.Visible, "«Volver al menú» lleva al título")
dump("16_titulo_terminada")
-- Fase especial (desbloqueada al terminar)
press(ctx.targets.menu_special)
check(ctx.state.mode == "special" and Books.def.name == "special" and #Books.def.books == 300, "Fase especial: el Archivo con 300 libros")
session.special.charge = 600
Game.sendState(session)
frame(2)
dump("17_especial")
key(Enum.KeyCode.Z)
frame(2)
check(ctx.state.rows == 30, "Z coloca todo el Archivo")
press(ctx.targets.pause_tomenu or ctx.targets.results_menu)
ctx.act("toMenu")
press(ctx.targets.menu_continue)
check(ctx.state.mode == "main", "Continuar vuelve a la última partida")

-- Botones del HUD (en móvil: USAR, Soltar, Lanzar, Rotar, Correr, Lista, Mapa…) y de la barra de hechizos
for _, b in gui:FindFirstChild("Root"):GetDescendants() do
	if b:IsA("TextButton") and not string.find(b:GetFullName(), "Panel_") then
		W.fakeTime += 0.1
		W.signalFor(W.idOf(W.unwrap(b)), "Activated"):Fire()
		W.signalFor(W.idOf(W.unwrap(b)), "MouseButton1Down"):Fire()
		W.signalFor(W.idOf(W.unwrap(b)), "MouseButton1Up"):Fire()
		pressed += 1
		ctx.closePanel()
		frame(1)
	end
end
if DEVICE == "movil" then
	for _, name in { "use", "drop", "throw", "cycle", "run", "list", "map", "manual", "menu" } do
		check(ctx.targets["touch_" .. name], "falta el botón táctil " .. name)
	end
end
-- Lanzar y soltar con teclado (con un libro en la mano)
look(target + Vector3.new(2.2, 2.2, 0), target)
if Aim.target and Aim.target.ok then
	key(Enum.KeyCode.E)
end
key(Enum.KeyCode.F)
key(Enum.KeyCode.R)
-- Botón derecho (rotar) y números (magia: aún no hay)
W.UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton2 }, false)
key(Enum.KeyCode.One)
-- Cambio de idioma: las placas se rehacen
Books.setLang("en")
check(Lang.t("en", "hud_rows", { n = 1, total = 400 }) == "Correct rows 1/400", "texto en inglés")
Books.setLang("es")
frame(5)
-- Etiquetas de lomo y textos del HUD
local top = gui:FindFirstChild("Root"):FindFirstChild("TopCounter")
check(string.find(top:FindFirstChild("Rows").Text, "Filas correctas"), "el contador de filas debe estar en español")
local books = gui:FindFirstChild("Root"):FindFirstChild("BottomCounter"):FindFirstChild("Books")
check(string.find(books.Text, "3.072"), "el contador de libros debe mostrar 3.072 (" .. books.Text .. ")")
print(string.format("  [botones] %d botones pulsados (%s) · ventanas: título, lista, mapa, carta, manual, cofre, pausa, opciones, logros, evaluación, especial", pressed, DEVICE))
print("CLIENTE OK")
