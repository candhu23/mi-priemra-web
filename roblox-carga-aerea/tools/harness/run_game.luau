--[[
	Prueba de JUEGO COMPLETO: servidor real + interfaz real en el mismo proceso (los remotes
	funcionan de verdad). Pulsa JUGAR, sigue el tutorial pulsando lo que señala la flecha,
	abre todas las ventanas y pestañas, pulsa TODOS los botones y cambia de idioma.
	Uso: lune run run_game.luau <test.rbxl> [carpeta-de-volcado]
	Con carpeta, vuelca el árbol de la interfaz en JSON (vista previa con preview.py).
]]

local M = require("./mock")
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local DUMP = process.args[2]
local W = M.new(process.args[1], { locale = "es-es" })
local RS = W.game:GetService("ReplicatedStorage")
local SSS = W.game:GetService("ServerScriptService")
local SPS = W.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local Lang = W.require(W.wrap(RS:FindFirstChild("Lang")))

-- Servidor
W.runScript(SSS:FindFirstChild("GameServer"))
local player, realPlayer = W.addPlayer(42, "Jorge")
W.player = player
W.Players.LocalPlayer = player
W.Players.PlayerAdded:Fire(player)

-- Cliente: se copia StarterPlayerScripts en PlayerScripts y se ejecuta el LocalScript
local playerScripts = realPlayer:FindFirstChild("PlayerScripts")
for _, child in SPS:GetChildren() do
	child:Clone().Parent = playerScripts
end
local playerGui = realPlayer:FindFirstChild("PlayerGui")
W.runScript(playerScripts:FindFirstChild("GameClient"))
local Kit = W.require(W.wrap(playerScripts:FindFirstChild("UI"):FindFirstChild("Kit")))
local ctx = Kit.ctx

local function T(key, params)
	return Lang.t(ctx.lang, key, params)
end
local function frame()
	W.tick(1)
	for _ = 1, 3 do
		W.renderStepped:Fire(0.25)
	end
end
local function alive(inst)
	local ok, parent = pcall(function() return W.unwrap(inst).Parent end)
	return ok and parent ~= nil
end
local function press(btn, what)
	assert(btn, "no encuentro el botón: " .. tostring(what))
	W.signalFor(W.idOf(W.unwrap(btn)), "Activated"):Fire()
end
local function count()
	local n = 0
	for _ in playerGui:GetDescendants() do n += 1 end
	return n
end
local function findText(text)
	for _, d in playerGui:GetDescendants() do
		if (d:IsA("TextButton") or d:IsA("TextLabel")) and d.Text == text then
			local b = d:IsA("TextButton") and d or d:FindFirstAncestorWhichIsA("TextButton")
			if b then return W.wrap(b) end
		end
	end
	return nil
end

frame()
assert(ctx.state, "el cliente no recibió el estado del servidor")
print("Interfaz creada · objetos:", count(), "· idioma:", ctx.lang)

-- Volcado de la interfaz (para la vista previa)
local PROPS = {
	"Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "ZIndex", "LayoutOrder",
	"Text", "TextSize", "TextColor3", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextTransparency", "TextStrokeTransparency", "TextStrokeColor3",
	"Image", "ImageRectOffset", "ImageRectSize", "ImageColor3", "ImageTransparency", "ScaleType", "Rotation", "ClipsDescendants", "AutomaticSize",
	"CornerRadius", "Color", "Thickness", "Transparency", "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom",
	"FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment", "CellSize", "CellPadding", "AspectRatio", "Scale", "FontFace",
	"MaxSize", "RichText",
}
local function encode(v)
	local t = typeof(v)
	if t == "UDim2" then return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then return { v.Scale, v.Offset }
	elseif t == "Vector2" then return { v.X, v.Y }
	elseif t == "Color3" then return { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
	elseif t == "ColorSequence" then
		-- Todos los colores con su posición: { {t, r, g, b}, ... }
		local out = {}
		for _, kp in v.Keypoints do
			local c = kp.Value
			table.insert(out, { math.floor(kp.Time * 1000 + 0.5) / 1000, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) })
		end
		return out
	elseif t == "EnumItem" then return v.Name
	elseif t == "Font" then return { v.Family, v.Weight.Name }
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
	if inst.ClassName == "UIGradient" then
		n.Color = encode(inst.Color)
		n.Rotation = inst.Rotation
	end
	for _, c in inst:GetChildren() do
		if not c:IsA("Sound") then table.insert(n.children, node(c)) end
	end
	return n
end
local function dump(name, keepModal, now)
	if not DUMP then return end
	if ctx.closeModal and not keepModal then ctx.closeModal() end
	if not now then
		W.tick(4) -- que desaparezcan los avisos
		frame()
	end
	local guis = {}
	for _, g in playerGui:GetChildren() do table.insert(guis, node(g)) end
	fs.writeFile(DUMP .. "/" .. name .. ".json", serde.encode("json", guis))
end

dump("00_titulo")

---------------------------------------------------------------------
print("-- Pantalla de título y tutorial (siguiendo la flecha) --")
press(ctx.targets.play, "JUGAR")
frame()
press(findText(T("btn_start")), "¡Vamos!")
frame()
assert(ctx.state.tutorial == 1, "el tutorial debería empezar")
local steps = {}
local landingSeen = false
for _ = 1, 60 do
	frame()
	local st = ctx.state
	if st.tutorial == 99 then break end
	steps[st.tutorial] = true
	if st.tutorial == 1 then
		if ctx.panel ~= "cargo" then press(ctx.targets.dock_cargo, "dock cargas") else dump("02_tutorial_cargas") press(ctx.targets.fly_first, "VOLAR primer vuelo") end
	elseif st.tutorial == 2 then
		assert(ctx.panel == nil, "la ventana de CARGAS debería cerrarse sola al despegar (para ver el avión)")
		if not landingSeen then dump("03_tutorial_vuelo", false, true) end
		-- Minijuego de aterrizaje: aparece en los últimos segundos
		for _ = 1, 40 do
			frame()
			local land = ctx.targets.land
			if land and W.unwrap(land).Parent.Parent.Visible then
				landingSeen = true
				dump("03b_tutorial_aterrizaje", false, true)
				press(land, "ATERRIZA")
				break
			end
			if ctx.state.tutorial ~= 2 then break end
		end
	elseif st.tutorial == 3 then
		if ctx.panel ~= "fleet" then press(ctx.targets.dock_fleet, "dock flota") else frame() press(ctx.targets.buy_sparrow, "comprar gorrión") end
	elseif st.tutorial == 4 then
		if ctx.panel ~= "pilots" then press(ctx.targets.dock_pilots, "dock pilotos") else frame() dump("04_tutorial_fichajes") press(ctx.targets.hire_first, "fichar") end
	elseif st.tutorial == 5 then
		if ctx.panel then ctx.closePanel() frame() end
		dump("05_tutorial_objetivo")
		press(ctx.targets.goal_claim, "reclamar objetivo")
	end
end
assert(ctx.state.tutorial == 99, "el tutorial no terminó (paso " .. tostring(ctx.state.tutorial) .. ")")
assert(landingSeen, "el minijuego de aterrizaje debería salir en el primer vuelo")
-- Segundo vuelo tuyo con el MISMO avión: el minijuego tiene que volver a estar disponible
do
	local plane = ctx.state.planes[1]
	local board = ctx.state.boards[plane.airport] or {}
	local chosen
	for _, l in board do
		local _, _, _, secs = Kit.quote(plane, l, 0)
		if not Kit.flyBlock(plane, l) and secs >= 14 then chosen = l break end
	end
	assert(chosen, "no hay carga para el segundo vuelo de prueba")
	assert(ctx.act("dispatch", plane.id, chosen.id, 0), "no despegó el segundo vuelo")
	local ready = false
	for _ = 1, 60 do
		frame()
		local land = ctx.targets.land
		if land and W.unwrap(land).Parent.Parent.Visible and W.unwrap(land):GetAttribute("Enabled") then
			ready = true
			press(land, "ATERRIZA (2.º vuelo)")
			break
		end
	end
	assert(ready, "el minijuego de aterrizaje no vuelve a funcionar en el segundo vuelo del mismo avión")
	W.tick(10)
end
print("  tutorial completado siguiendo la flecha · pasos vistos:", (function() local n = 0 for _ in steps do n += 1 end return n end)())
-- Cerrar ventanas emergentes (celebraciones)
for _ = 1, 3 do
	local ok = findText(T("btn_great")) or findText(T("btn_ok"))
	if ok then press(ok) end
end
frame()

---------------------------------------------------------------------
print("-- Juego con dinero de sobra: todas las ventanas y botones --")
-- Más dinero y nivel para que los botones estén activos (se inyecta en el servidor y se reentra)
W.Players.PlayerRemoving:Fire(player)
local key = "AeroCarga_v1/player_42"
W.saved[key].money = 3e7
W.saved[key].xp = 220 * 9 ^ 2.35
W.Players.PlayerAdded:Fire(player)
frame()
for _ = 1, 3 do
	local ok = findText(T("btn_collect")) or findText(T("btn_great")) or findText(T("btn_ok"))
	if ok then press(ok) end
end
dump("10_mapa")
-- Menú ☰ con todos los apartados
press(ctx.targets.menu, "menú ☰")
frame()
dump("11_menu", true, true)
press(ctx.targets.menu_company, "menú → tu compañía")
frame()
assert(ctx.panel == "company", "el menú debería abrir «Tu compañía»")
ctx.closePanel()
-- Zoom del mapa
press(ctx.targets.zoom_1, "zoom +")
press(ctx.targets.zoom_1, "zoom +")
frame()
dump("12_mapa_zoom")
local mapArea = playerGui:FindFirstChild("MapArea", true) :: any
assert(mapArea and mapArea.CanvasSize.X.Scale > 1.2, "el zoom + no amplió el mapa")
print("  zoom: lienzo ×" .. mapArea.CanvasSize.X.Scale)
press(ctx.targets.zoom_3, "zoom normal")
frame()
assert(mapArea.CanvasSize.X.Scale == 1, "el zoom normal no volvió a ×1")

local PANELS = {
	fleet = { "mine", "buy", "upgrades" }, cargo = { false }, pilots = { "roster", "hire", "dispatcher", "mechanics" }, contracts = { false },
	spain = { "regions", "passport" }, missions = { "missions", "goals", "daily" }, shop = { "passes", "offers", "bonus" },
	ranking = { "week", "all" }, settings = { false }, ipo = { false }, company = { false }, fuel = { false }, france = { false },
}
local ORDER = { "company", "fleet", "cargo", "pilots", "fuel", "contracts", "spain", "france", "missions", "shop", "ranking", "settings", "ipo" }
local pressed = 0
local function sweep()
	local all = playerGui:GetDescendants()
	local ordered = {}
	for i = #all, 1, -1 do table.insert(ordered, all[i]) end
	for _, d in all do table.insert(ordered, d) end
	for _, d in ordered do
		local ok, isButton = pcall(function()
			return d.Parent ~= nil and d:IsA("TextButton") and not string.find(d.Text, "English") and not string.find(d.Text, "Español")
				and d.Text ~= ("🌐 " .. T("lang_auto")) and d.Text ~= T("btn_skip") and d.Text ~= ("▶  " .. T("btn_play"))
		end)
		if ok and isButton and alive(W.wrap(d)) then
			local id = W.idOf(d)
			W.signalFor(id, "MouseEnter"):Fire()
			W.signalFor(id, "MouseLeave"):Fire()
			W.signalFor(id, "Activated"):Fire()
			pressed += 1
		end
	end
end
for pass = 1, 2 do
	for _, id in ORDER do
		for _, tab in PANELS[id] do
			ctx.openPanel(id)
			if tab then
				press(ctx.targets["tab_" .. tab], "pestaña " .. tab)
			end
			frame()
			if pass == 1 then dump("20_" .. id .. (tab and ("_" .. tab) or "")) end
			sweep()
			frame()
		end
	end
	ctx.closePanel()
	frame()
	sweep() -- HUD y mapa
	frame()
end
print("  botones pulsados:", pressed, "· objetos:", count())

-- Contratar un mecánico a mano (en el barrido, pulsar otra pestaña borra las tarjetas antes de llegar a ellas)
ctx.openPanel("pilots")
press(ctx.targets.tab_mechanics, "pestaña mecánicos")
frame()
local mechBtn
for _, d in playerGui:GetDescendants() do
	if d:IsA("TextButton") and string.sub(d.Text, 1, #"🤝 $") == "🤝 $" and d:GetAttribute("Enabled") then
		mechBtn = W.wrap(d)
		break
	end
end
press(mechBtn, "contratar mecánico")
frame()
assert(W.invoked[#W.invoked] == "hireMechanic", "el botón de mecánico no llegó al servidor")
ctx.closePanel()

-- Modales con confirmación
ctx.act("setAuto", false) -- el barrido activó el despacho automático
W.tick(300) -- que aterricen los aviones que mandó el barrido
ctx.openPanel("fleet")
press(ctx.targets.tab_mine)
frame()
local sell
for _, d in playerGui:GetDescendants() do
	if d:IsA("TextButton") and d.Text == "💲" and d:GetAttribute("Enabled") then
		sell = W.wrap(d)
		break
	end
end
press(sell, "vender (algún avión en tierra)")
frame()
press(findText(T("btn_sell")), "confirmar venta")
assert(W.invoked[#W.invoked] == "sellPlane", "la venta no llegó al servidor")
frame()

---------------------------------------------------------------------
print("-- Chárter desde CARGAS --")
W.tick(300)
local function charterActive()
	for _, p in ctx.state.planes do
		if p.flight and p.flight.good == "charter" then return true end
	end
	return false
end
if charterActive() then
	print("  (el barrido de botones ya mandó un chárter)")
else
	ctx.openPanel("cargo")
	frame()
	press(findText("🌙 " .. T("btn_charter")), "botón Chárter")
	frame()
	dump("40_charter", true)
	local fly
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "✈️" and d:GetAttribute("Style") == "blue" then fly = W.wrap(d) break end
	end
	press(fly, "primer chárter")
	frame()
	assert(W.invoked[#W.invoked] == "charter", "el chárter no llegó al servidor")
end
assert(charterActive(), "debería haber un avión de chárter")
ctx.closePanel()

print("-- Salir a bolsa desde la interfaz --")
W.Players.PlayerRemoving:Fire(player)
W.saved[key].xp = 220 * 13 ^ 2.35
W.saved[key].stats.earned = 40e6
for _, p in W.saved[key].planes do
	if p.flight and p.flight.good == "charter" then p.flight.endT = p.flight.startT end -- que vuelva el chárter al entrar
end
W.Players.PlayerAdded:Fire(player)
frame()
for _ = 1, 3 do
	local ok = findText(T("btn_collect")) or findText(T("btn_great")) or findText(T("btn_ok"))
	if ok then press(ok) end
end
dump("41_mapa_bolsa")
ctx.openPanel("ipo")
frame()
dump("42_bolsa")
press(ctx.targets.ipo_go, "SALIR A BOLSA")
frame()
press(findText("🔔 " .. T("btn_ipo")), "confirmar salida a bolsa")
frame()
assert(ctx.state.ipoCount == 1 and ctx.state.level == 1, "no salió a bolsa desde la interfaz")
dump("43_bolsa_celebracion", true)
press(findText(T("btn_great")), "cerrar celebración")
frame()

---------------------------------------------------------------------
print("-- Cambio de idioma --")
ctx.openPanel("settings")
frame()
press(findText("🇬🇧 English"), "English")
frame()
assert(ctx.lang == "en", "no cambió a inglés")
assert(findText(Lang.t("en", "nav_fleet")), "la interfaz no se reconstruyó en inglés")
dump("30_ingles_mapa")
ctx.openPanel("cargo")
dump("31_ingles_cargo")
ctx.openPanel("settings")
frame()
press(findText("🇪🇸 Español"), "Español")
frame()
assert(ctx.lang == "es", "no volvió a español")

---------------------------------------------------------------------
local counts = {}
for _, a in W.invoked do counts[a] = (counts[a] or 0) + 1 end
local list = {}
for a, n in counts do table.insert(list, a .. "×" .. n) end
table.sort(list)
print("Acciones enviadas:", table.concat(list, ", "))
print("Compras lanzadas:", #W.prompts)
local needed = { "dispatch", "buyPlane", "hire", "claimGoal", "tutorial", "openPanel" }
for _, a in { "dispatch", "buyPlane", "hire", "claimGoal", "tutorial", "repair", "buyUpgrade", "buyRegion", "claimDaily", "searchCandidates", "setAuto", "setLang", "setMuted", "getTop", "refreshBoard", "sellPlane",
	"acceptContract", "setAirline", "claimGoals", "charter", "goPublic", "buyFuel", "hireDispatcher", "hireMechanic" } do
	assert(counts[a], "la interfaz nunca envió la acción " .. a)
end
local _ = needed
print("JUEGO OK")
process.exit(0)
