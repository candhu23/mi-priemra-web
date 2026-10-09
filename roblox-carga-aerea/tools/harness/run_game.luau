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
	"MaxSize",
}
local function encode(v)
	local t = typeof(v)
	if t == "UDim2" then return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then return { v.Scale, v.Offset }
	elseif t == "Vector2" then return { v.X, v.Y }
	elseif t == "Color3" then return { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
	elseif t == "ColorSequence" then
		local k = v.Keypoints
		local a, b = k[1].Value, k[#k].Value
		return { { math.floor(a.R * 255), math.floor(a.G * 255), math.floor(a.B * 255) }, { math.floor(b.R * 255), math.floor(b.G * 255), math.floor(b.B * 255) } }
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
local function dump(name)
	if not DUMP then return end
	if ctx.closeModal then ctx.closeModal() end
	W.tick(4) -- que desaparezcan los avisos
	frame()
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
for _ = 1, 60 do
	frame()
	local st = ctx.state
	if st.tutorial == 99 then break end
	steps[st.tutorial] = true
	if st.tutorial == 1 then
		if ctx.panel ~= "cargo" then press(ctx.targets.dock_cargo, "dock cargas") else dump("02_tutorial_cargas") press(ctx.targets.fly_first, "VOLAR primer vuelo") end
	elseif st.tutorial == 2 then
		if ctx.panel then ctx.closePanel() end
		dump("03_tutorial_vuelo")
		W.tick(5)
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

local PANELS = {
	fleet = { "mine", "buy", "upgrades" }, cargo = { false }, pilots = { "roster", "hire" }, spain = { false },
	missions = { "missions", "goals", "daily" }, shop = { "passes", "offers", "bonus" }, ranking = { false }, settings = { false },
}
local ORDER = { "fleet", "cargo", "pilots", "spain", "missions", "shop", "ranking", "settings" }
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
for _, a in { "dispatch", "buyPlane", "hire", "claimGoal", "tutorial", "repair", "buyUpgrade", "buyRegion", "claimDaily", "searchCandidates", "setAuto", "setLang", "setMuted", "getTop", "refreshBoard", "sellPlane" } do
	assert(counts[a], "la interfaz nunca envió la acción " .. a)
end
local _ = needed
print("JUEGO OK")
process.exit(0)
