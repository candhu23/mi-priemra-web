--[[
	Cliente de Crías Míticas: TODA la interfaz. Solo enseña el estado que manda el servidor y pide acciones.
	Pantallas: HUD (monedas, próxima isla, Índice/Brillante/piedras), menú (8 botones), botón Auto, panel del
	huevo (probabilidad de cada especie y de Brillante) o de la puerta, apertura de huevo, ventanas (Crías con
	fusión, Álbum normal/Brillante, Misiones, Diario, Tienda, Mejoras, Islas, Ajustes), avisos y tutorial.
	Lo 3D (crías, carteles) está en UI/Mundo3D.
	Diseño: piezas de UI/Kit en unidades de 960×540 (Kit.root escala). Cada parte va en su bloque do…end
	(Luau: máx. 200 variables locales por función).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalizationService = game:GetService("LocalizationService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))
local UI = script.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Mundo3D = require(UI:WaitForChild("Mundo3D"))
local C, T, create = Kit.C, Kit.T, Kit.create
local ctx = Kit.ctx

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("MythicHatchlingsRemotes")
local actionRemote = remotes:WaitForChild("Action") :: RemoteFunction
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

ctx.lang = Lang.detect(LocalizationService.RobloxLocaleId)

local gui = create("ScreenGui", { Name = "MythicHatchlingsUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
Kit.setupSounds(gui)
local root = Kit.root(gui)
Mundo3D.start(Kit)

---------------------------------------------------------------------
-- Variables compartidas entre bloques (se asignan dentro de cada bloque)
---------------------------------------------------------------------
local showToast: (text: string, kind: string?, color: Color3?, seconds: number?) -> ()
local toastHolder: Frame -- los avisos (bajan cuando se ve el tutorial)
local refreshAll: () -> ()
local openWindow: (id: string) -> ()
local closeWindow: () -> ()
local showHatch: (list: { any }, auto: boolean?, note: string?) -> ()
local tutorialFlags = { equippedBest = false }
local tutorial = { step = 0, started = false }

local function petName(kind: string): string
	return T("pet_" .. kind)
end

local function rarityOf(kind: string): Config.Rarity
	return Config.Rarities[Config.PetById[kind].rarity]
end

-- Nombre de la cría con ✨ si es Brillante
local function petLabel(kind: string, shiny: boolean?): string
	return petName(kind) .. (if shiny then " ✨" else "")
end

local function coins(n: number): string
	return "🪙 " .. Kit.fmt(n)
end

-- Probabilidad en % como texto: con 1 decimal si < 10 (1,8 y no «2»: nunca redondear hacia arriba a la vista)
local function pctText(pct: number): string
	local text = if pct < 10 then string.format("%.1f", pct) else string.format("%.0f", pct)
	text = string.gsub(text, "%.0$", "") -- «6» y no «6,0»
	return if ctx.lang == "es" then (string.gsub(text, "%.", ",")) else text
end

-- Color de una rareza por su id ("mythic"…), para el aviso al servidor
local function rarityColor(id: string): Color3
	for _, r in Config.Rarities do
		if r.id == id then
			return r.color
		end
	end
	return C.blue
end

-- Traduce los parámetros que manda el servidor (números → texto bonito)
local function niceParams(params: any): { [string]: any }
	local p = table.clone(params or {})
	if type(p.value) == "number" then
		p.value = coins(p.value)
	end
	if type(p.zone) == "number" and Config.Zones[p.zone] then
		p.zone = T("zone_" .. Config.Zones[p.zone].id)
	end
	if type(p.pet) == "string" and Config.PetById[p.pet] then
		p.pet = petName(p.pet)
	end
	if type(p.rarity) == "string" then
		p.rarity = T("rar_" .. p.rarity)
	end
	if type(p.upgrade) == "string" and Config.UpgradeById[p.upgrade] then
		p.upgrade = T("up_" .. p.upgrade)
	end
	for _, k in { "before", "after" } do
		if type(p[k]) == "number" then
			p[k] = Kit.fmt(p[k])
		end
	end
	return p
end

-- Pide una acción al servidor; onDone(ok, params, texto) si hace falta la respuesta.
-- quiet = si sale bien, no hay aviso: el texto se lo pasa a onDone (p. ej. para ponerlo en la ventana grande)
local function send(action: string, a: any?, b: any?, c: any?, onDone: ((boolean, any, string?) -> ())?, quiet: boolean?)
	task.spawn(function()
		local ok, okServer, textKey, params = pcall(function()
			return actionRemote:InvokeServer(action, a, b, c)
		end)
		if not ok then
			return
		end
		local text = if textKey then T(textKey, niceParams(params)) else nil
		if text and not (quiet and okServer) then
			showToast(text, if okServer then "success" else "error")
		end
		if onDone then
			onDone(okServer == true, params, text)
		end
	end)
end

local function promptPass(key: string)
	for _, p in Config.GamePasses do
		if p.key == key and p.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, p.id)
		end
	end
end

local function passExists(key: string): boolean
	for _, p in Config.GamePasses do
		if p.key == key then
			return p.id ~= 0
		end
	end
	return false
end

---------------------------------------------------------------------
-- HUD: monedas arriba en el centro, avisos de boost/suerte debajo; próxima isla, Índice y piedras arriba a la izquierda
---------------------------------------------------------------------
local hudCoins: TextLabel
local hudRate: TextLabel
local hudChips: TextLabel
local hudRebirth: TextLabel
local hudAlbum: TextLabel
local hudAlbumBar: Frame
do
	local hud = create("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 70),
		BackgroundColor3 = C.panel, BorderSizePixel = 0,
	}, { Kit.corner(18), Kit.stroke(C.panelDark, 3) })
	hudCoins = Kit.title(hud, "🪙 0", 34, C.orangeDark, {
		Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center,
	})
	Kit.fit(hudCoins, 34)
	hudRate = Kit.label(hud, "", 16, C.muted, Kit.FONT_BOLD, {
		Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center,
	})
	hudChips = Kit.title(root, "", 18, C.white, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(420, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Kit.textStroke(2).Parent = hudChips

	local info = create("Frame", {
		Parent = root, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(250, 70), BackgroundColor3 = C.panel, BorderSizePixel = 0,
	}, { Kit.corner(16), Kit.stroke(C.panelDark, 3), Kit.padding(10, 10, 6, 6) })
	-- Línea 1: la meta siguiente (crías que pide la próxima isla) con su barra. Línea 2: Índice, ✨ y 🪨
	hudRebirth = Kit.title(info, "", 18, C.purpleDark, { Size = UDim2.new(1, 0, 0, 22) })
	Kit.fit(hudRebirth, 18)
	hudAlbum = Kit.label(info, "", 16, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18) })
	Kit.fit(hudAlbum, 16)
	local barBack = create("Frame", {
		Parent = info, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = C.panelDark, BorderSizePixel = 0,
	}, { Kit.corner(5) })
	hudAlbumBar = create("Frame", { Parent = barBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.gold, BorderSizePixel = 0 }, { Kit.corner(5) })
end

---------------------------------------------------------------------
-- Menú (izquierda, 2 columnas) con puntos rojos de aviso
---------------------------------------------------------------------
local dots: { [string]: Frame } = {}
do
	local dock = create("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 24), Size = UDim2.fromOffset(180, 350),
		BackgroundTransparency = 1,
	}, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(86, 80), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local items = {
		{ "pets", "🐾", "orange" }, { "album", "📖", "blue" }, { "missions", "🎯", "green" }, { "daily", "🎁", "gold" },
		{ "shop", "🛒", "purple" }, { "upgrades", "🌳", "green" }, { "islands", "🗺️", "blue" }, { "settings", "⚙️", "white" },
	}
	for i, it in items do
		local id = it[1]
		local holder = create("Frame", { Parent = dock, BackgroundTransparency = 1, LayoutOrder = i })
		local b = Kit.button(holder, it[2], it[3], UDim2.new(1, 0, 1, -20), function()
			openWindow(id)
		end)
		b.Name = "Menu_" .. id
		Kit.fit(b, 30)
		local label = Kit.title(holder, "", 17, C.white, {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(1, 8, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Kit.textStroke(2).Parent = label
		Kit.fit(label, 17)
		label.Name = "Etiqueta_" .. id
		dots[id] = create("Frame", {
			Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = C.red, Visible = false, ZIndex = 3,
		}, { Kit.corner(), Kit.stroke(C.white, 2) })
	end
end

local function menuLabels()
	for id in dots do
		local label = root:FindFirstChild("Etiqueta_" .. id, true)
		if label and label:IsA("TextLabel") then
			label.Text = T(id)
		end
	end
end

---------------------------------------------------------------------
-- Botón Auto (abajo a la derecha): las crías buscan solas el montón más cercano
---------------------------------------------------------------------
local autoButton: TextButton
do
	autoButton = Kit.button(root, "", "green", UDim2.fromOffset(170, 58), function()
		local s = ctx.state
		if s then
			send("setAuto", not s.settings.auto)
		end
	end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12) })
end

---------------------------------------------------------------------
-- Panel de contexto (abajo en el centro): huevo cercano o puerta cercana
---------------------------------------------------------------------
local eggPanel: Frame
local doorPanel: Frame
local updateContext: () -> ()
local autoHatchOn = false
local hatching = false -- la animación de apertura tapa el panel del huevo
do
	eggPanel = create("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(480, 206),
		BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false,
	}, { Kit.corner(18), Kit.stroke(C.panelDark, 3), Kit.padding(10) })
	local eggTitle = Kit.title(eggPanel, "", 22, C.ink, { Size = UDim2.new(1, 0, 0, 26) })
	Kit.fit(eggTitle, 22)
	local oddsRow = create("Frame", {
		Parent = eggPanel, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1,
	}, { Kit.list(true, 6, Enum.HorizontalAlignment.Center) })
	-- Una tarjeta por especie del huevo (hasta 6) + la de Brillante al final
	local oddsCards = {}
	for i = 1, 7 do
		local card = Kit.card(oddsRow, { Size = UDim2.fromOffset(60, 90), LayoutOrder = i })
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = 3
		end
		local emoji = Kit.label(card, "", 30, nil, nil, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center })
		local pct = Kit.title(card, "", 17, C.ink, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center })
		Kit.fit(pct, 17)
		local seen = Kit.label(card, "", 16, C.greenDark, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
		oddsCards[i] = { card = card, stroke = stroke, emoji = emoji, pct = pct, seen = seen }
	end
	local buttons = create("Frame", {
		Parent = eggPanel, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1,
	}, { Kit.list(true, 10, Enum.HorizontalAlignment.Center) })
	local open1 = Kit.button(buttons, "", "green", UDim2.fromOffset(190, 60), function()
		local z = Mundo3D.near.egg
		if z > 0 then
			send("hatch", z, 1, false, function(ok, params)
				if ok and params and params.hatched then
					showHatch(params.hatched)
				end
			end)
		end
	end, { LayoutOrder = 1 })
	open1.Name = "AbrirHuevo"
	local open3 = Kit.button(buttons, "", "orange", UDim2.fromOffset(130, 60), function()
		local s = ctx.state
		local z = Mundo3D.near.egg
		if s and not s.bonuses.hatch3 then
			promptPass("hatch3")
		elseif z > 0 then
			send("hatch", z, 3, false, function(ok, params)
				if ok and params and params.hatched then
					showHatch(params.hatched)
				end
			end)
		end
	end, { LayoutOrder = 2 })
	local autoEgg = Kit.button(buttons, "", "purple", UDim2.fromOffset(120, 60), function()
		local s = ctx.state
		if s and not s.bonuses.autoHatch then
			promptPass("autoHatch")
		else
			autoHatchOn = not autoHatchOn
			updateContext()
		end
	end, { LayoutOrder = 3 })

	doorPanel = create("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(380, 116),
		BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false,
	}, { Kit.corner(18), Kit.stroke(C.panelDark, 3), Kit.padding(10) })
	local doorTitle = Kit.title(doorPanel, "", 22, C.ink, { Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center })
	Kit.fit(doorTitle, 22)
	local doorButton = Kit.button(doorPanel, "", "green", UDim2.new(1, 0, 0, 60), function()
		local z = Mundo3D.near.door
		if z > 0 then
			send("unlockZone", z)
		end
	end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0) })
	doorButton.Name = "AbrirPuerta"

	function updateContext()
		local s = ctx.state
		if not s then
			return
		end
		local egg = Mundo3D.near.egg
		local door = Mundo3D.near.door
		eggPanel.Visible = egg > 0 and not hatching
		doorPanel.Visible = door > 0 and egg == 0 and not hatching
		if egg > 0 then
			local z = Config.Zones[egg]
			local eggRarity = Config.Rarities[z.eggRarity]
			eggTitle.Text = "🥚 " .. T("egg_title", { zone = T("zone_" .. z.id), rarity = T("egg_" .. eggRarity.id) }) .. (if s.luckLeft > 0 then "  🍀x2" else "")
			-- Probabilidades visibles: cada especie y la de Brillante (con suerte y mejoras, igual que el servidor)
			local odds = Config.eggOdds(egg, s, { luck = s.luckLeft > 0 })
			local n = #odds.species
			for i, card in oddsCards do
				card.card.Visible = i <= n + 1
				if i <= n then
					local sp = odds.species[i]
					card.emoji.Text = Config.PetById[sp.kind].emoji
					card.pct.Text = pctText(sp.pct) .. " %"
					card.seen.Text = if s.album[sp.kind] then "✓" else "?"
					card.seen.TextColor3 = C.greenDark
					if card.stroke then
						card.stroke.Color = eggRarity.color
					end
				elseif i == n + 1 then
					card.emoji.Text = "✨"
					card.pct.Text = pctText(odds.shinyPct) .. " %"
					card.seen.Text = "⚔️x" .. Config.SHINY_POWER
					card.seen.TextColor3 = C.orangeDark
					if card.stroke then
						card.stroke.Color = C.gold
					end
				end
			end
			-- Los botones de pase solo salen si el pase existe (si no, eran dos botones grises «Próximamente»)
			local show3 = s.bonuses.hatch3 or passExists("hatch3")
			local showAuto = s.bonuses.autoHatch or passExists("autoHatch")
			local h1, h3, hAuto = open1.Parent :: Frame, open3.Parent :: Frame, autoEgg.Parent :: Frame
			h3.Visible = show3
			hAuto.Visible = showAuto
			h1.Size = if show3 or showAuto then UDim2.fromOffset(190, 60) else UDim2.fromOffset(300, 60)
			local cost = Config.eggCost(egg, s)
			Kit.setButton(open1, T("egg_open", { value = coins(cost) }), s.coins >= cost)
			Kit.setButton(open3, if s.bonuses.hatch3 then T("egg_open3", { value = Kit.fmt(cost * 3) }) elseif passExists("hatch3") then "🔒 x3" else T("soon"),
				(s.bonuses.hatch3 and s.coins >= cost * 3) or (not s.bonuses.hatch3 and passExists("hatch3")))
			Kit.setButton(autoEgg, if s.bonuses.autoHatch then (if autoHatchOn then T("egg_auto_stop") else T("egg_auto")) elseif passExists("autoHatch") then "🔒 " .. T("egg_auto") else T("soon"),
				s.bonuses.autoHatch or passExists("autoHatch"))
		end
		if door > 0 then
			local z = Config.Zones[door]
			doorTitle.Text = T("door_title", { zone = T("zone_" .. z.id) })
			if door == s.zones + 1 and s.nextZone then
				-- No cuesta monedas: pide crías descubiertas (o puntuación Brillante en la 9)
				local nz = s.nextZone
				local text = if nz.ok then T("door_open") elseif nz.kind == "shiny" then T("door_need_shiny", { need = nz.need, have = nz.have })
					else T("door_need_index", { need = nz.need, have = nz.have })
				Kit.setButton(doorButton, text, nz.ok)
			else
				Kit.setButton(doorButton, T("door_need"), false)
			end
		end
	end

	-- Auto-abrir (pase): mientras estés al lado del huevo
	task.spawn(function()
		while true do
			task.wait(1.2)
			local s = ctx.state
			if autoHatchOn and s and s.bonuses.autoHatch and Mundo3D.near.egg > 0 then
				send("hatch", Mundo3D.near.egg, if s.bonuses.hatch3 then 3 else 1, true, function(ok, params)
					if ok and params and params.hatched then
						showHatch(params.hatched, true)
					end
				end)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Apertura de huevo (o resultado de una fusión): el huevo tiembla y aparece la cría (o 3) con su rareza
---------------------------------------------------------------------
do
	local overlay = create("TextButton", {
		Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Text = "",
		AutoButtonColor = false, Visible = false, ZIndex = 30,
	})
	overlay.Name = "Apertura"
	-- Destello del color de la rareza (Legendaria/Mítica): debajo de las tarjetas y sin texto; el toque llega al overlay
	local flash = create("Frame", {
		Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, BorderSizePixel = 0,
		Active = false, Visible = false, ZIndex = 31,
	})
	flash.Name = "Destello"
	local row = create("Frame", {
		Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20), Size = UDim2.fromOffset(660, 260),
		BackgroundTransparency = 1, ZIndex = 32,
	}, { Kit.list(true, 20, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	-- Título del momento raro («¡ÉPICA!», «¡¡MÍTICA!!») encima de las tarjetas; entra creciendo
	local rareTitle = Kit.title(overlay, "", 56, C.white, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, -122), Size = UDim2.fromOffset(600, 56),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 33,
	})
	rareTitle.Name = "MomentoRaro"
	Kit.fit(rareTitle, 56)
	Kit.textStroke(3).Parent = rareTitle
	local titleScale = create("UIScale", { Parent = rareTitle })
	local hint = Kit.title(overlay, "", 20, C.white, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(640, 26),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 33,
	})
	Kit.textStroke(2).Parent = hint
	Kit.fit(hint, 20)
	local token = 0
	-- Con título (Épica o más) el panel de monedas de arriba se esconde mientras dura (en el móvil no cabe todo)
	local function showHud(on: boolean)
		local hud = hudCoins.Parent
		if hud and hud:IsA("GuiObject") then
			hud.Visible = on
		end
		hudChips.Visible = on
	end
	local function hide()
		overlay.Visible = false
		hatching = false
		showHud(true)
		updateContext()
	end
	overlay.Activated:Connect(hide)

	-- 12 chispas que salen del centro y se desvanecen (pocas: el móvil va justo)
	local function sparks(color: Color3)
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			local spark = Kit.label(overlay, if i % 2 == 0 then "✨" else "⭐", 28, color, nil, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20), Size = UDim2.fromOffset(40, 40),
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 34,
			})
			Kit.tween(spark, 0.8, { Position = UDim2.new(0.5, math.cos(a) * 260, 0.5, 20 + math.sin(a) * 150), TextTransparency = 1 })
			task.delay(0.8, function()
				spark:Destroy()
			end)
		end
	end

	-- auto = abierto por Auto-abrir: aunque sea Brillante, la ventana dura como la mediana (no tapa el juego).
	-- Nivel del momento (Config.hatchLevel): repetida / nueva en el Índice / Brillante o Mítica
	-- note = texto extra abajo (resumen de una fusión: «¡12 fusiones! Poder …»)
	function showHatch(list: { any }, auto: boolean?, note: string?)
		token += 1
		local my = token
		for _, c in row:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		-- Nivel del momento según la mejor del lote (lo decide el servidor: nueva, Brillante, Mítica)
		local level, bestIndex = 0, 1
		for i, h in list do
			local l = Config.hatchLevel(h)
			if l > level then
				level, bestIndex = l, i
			end
		end
		level = math.max(level, 1)
		local bestH = list[bestIndex]
		local bestRarity = Config.Rarities[bestH.rarity or Config.PetById[bestH.kind].rarity]
		hint.Text = if note then note .. "  ·  " .. T("tap_continue") else T("tap_continue")
		rareTitle.Visible = false
		flash.Visible = false
		overlay.BackgroundTransparency = if level == 3 then 0.25 else 0.4
		overlay.Visible = true
		showHud(level < 2)
		hatching = true
		updateContext()
		local cards = {}
		for i, h in list do
			local card = Kit.card(row, { Size = UDim2.fromOffset(200, 250), LayoutOrder = i, ZIndex = 32 })
			local big = Kit.label(card, "🥚", 90, nil, nil, {
				Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 110), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 33,
			})
			cards[i] = { card = card, big = big, h = h }
			Kit.tween(big, 0.15, { Rotation = 12 })
		end
		-- Tiembla más rato cuanto más rara (izquierda / derecha cada 0,15 s)
		local shake = Config.HATCH_SHAKE_TIME[level]
		for k = 1, math.floor(shake / 0.15) - 1 do
			task.delay(k * 0.15, function()
				if my == token then
					for _, c in cards do
						Kit.tween(c.big, 0.15, { Rotation = if k % 2 == 0 then 12 else -12 })
					end
				end
			end)
		end
		task.delay(shake, function()
			if my ~= token then
				return
			end
			for _, c in cards do
				local rarity = rarityOf(c.h.kind)
				c.big.Rotation = 0
				c.big.Text = Config.PetById[c.h.kind].emoji
				local stroke = c.card:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if c.h.shiny then C.gold else rarity.color
					stroke.Thickness = if Config.hatchLevel(c.h) >= 2 then 8 else 5
				end
				-- Brillante: tarjeta dorada clara (si no, una Común Brillante parecía una Común normal)
				if c.h.shiny then
					c.card.BackgroundColor3 = C.gold:Lerp(C.white, 0.75)
				end
				-- Bote de la tarjeta (1 → 1,1 → 1) en las raras. La tarjeta es un Frame: su único UIScale.
				-- 1,1 y no más: en el móvil una tarjeta más grande pisa «Toca para seguir» y el título
				if Config.hatchLevel(c.h) >= 2 then
					local bounce = create("UIScale", { Parent = c.card })
					Kit.tween(bounce, 0.15, { Scale = 1.1 }, Enum.EasingStyle.Back)
					task.delay(0.15, function()
						Kit.tween(bounce, 0.2, { Scale = 1 })
					end)
				end
				local name = Kit.title(c.card, petLabel(c.h.kind, c.h.shiny), 22, C.ink, {
					Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 33,
				})
				Kit.fit(name, 22)
				local pill = Kit.title(c.card, T("rar_" .. rarity.id), 20, C.ink, {
					AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 174), Size = UDim2.fromOffset(150, 30),
					TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = rarity.color:Lerp(C.white, 0.4), BackgroundTransparency = 0, ZIndex = 33,
				})
				Kit.corner(10).Parent = pill
				if c.h.new then
					local tag = Kit.title(c.card, T("new"), 20, C.white, {
						AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(110, 30),
						TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = C.redDark, BackgroundTransparency = 0, ZIndex = 34,
					})
					Kit.corner(10).Parent = tag
				end
			end
			if level >= 2 then
				rareTitle.Text = if level == 2 then T("rare_new") elseif bestH.shiny then T("rare_big_shiny") else T("rare_big_mythic")
				rareTitle.TextColor3 = if level == 3 and bestH.shiny then C.gold else bestRarity.color
				rareTitle.Visible = true
				titleScale.Scale = 0.4
				Kit.tween(titleScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			if level == 3 then
				-- Brillante: su probabilidad real (la manda el servidor: la misma que el panel del huevo), en su tarjeta
				if bestH.shiny and bestH.chance then
					local odds = Kit.title(cards[bestIndex].card, T("rare_odds", { pct = pctText(bestH.chance) }), 18, C.ink, {
						Position = UDim2.fromOffset(6, 212), Size = UDim2.new(1, -12, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 33,
					})
					odds.Name = "ProbabilidadRara"
					Kit.fit(odds, 18)
				end
				flash.BackgroundColor3 = if bestH.shiny then C.gold else bestRarity.color
				flash.BackgroundTransparency = 0.7
				flash.Visible = true
				Kit.tween(flash, 0.5, { BackgroundTransparency = 1 })
				sparks(if bestH.shiny then C.gold else bestRarity.color)
				Kit.playRare()
			end
		end)
		local showLevel = if auto and level == 3 then 2 else level
		task.delay(Config.HATCH_SHOW_TIME[showLevel], function()
			if my == token then
				hide()
			end
		end)
	end
end

-- Grupos de fusión: clave "isla:rareza:0|1" → cuántas tiene (las Míticas no se fusionan) y cuántos están listos
local function fuseGroups(s: any): ({ [string]: number }, number)
	local counts, ready = {}, 0
	for _, p in s.pets do
		local def = Config.PetById[p.kind]
		if def and Config.Rarities[def.rarity].fuseNeed > 0 then
			local k = def.zone .. ":" .. def.rarity .. ":" .. (if p.shiny then 1 else 0)
			counts[k] = (counts[k] or 0) + 1
			if counts[k] == Config.Rarities[def.rarity].fuseNeed then
				ready += 1
			end
		end
	end
	return counts, ready
end

local function groupKey(p: any): string
	local def = Config.PetById[p.kind]
	return def.zone .. ":" .. def.rarity .. ":" .. (if p.shiny then 1 else 0)
end

-- Resultado de una fusión: si hay algo especial (nueva, Brillante, Mítica), la ventana grande con el resumen abajo
-- (se cierra la ventana de Crías para que no quede debajo); si no, el resumen en un aviso
local function onFused(ok: boolean, params: any, text: string?)
	if not ok then
		return
	end
	local made = if params and type(params.made) == "table" then params.made else {}
	local list = table.clone(made)
	table.sort(list, function(a, b)
		return Config.hatchLevel(a) > Config.hatchLevel(b)
	end)
	local show = {}
	for i = 1, math.min(3, #list) do
		if Config.hatchLevel(list[i]) >= 2 then
			table.insert(show, list[i])
		end
	end
	if #show > 0 then
		closeWindow()
		showHatch(show, false, text)
	elseif text then
		showToast(text, "success")
	end
end

---------------------------------------------------------------------
-- Ventanas (una a la vez, centradas, con fondo oscuro detrás)
---------------------------------------------------------------------
local shade: TextButton
local body: ScrollingFrame
local windowTitle: TextLabel
local currentWindow = ""
local windowSig = ""
local renderers: { [string]: () -> () } = {}
local signatures: { [string]: () -> string } = {}

local function clearBody()
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Texto de una línea dentro de la ventana
local function line(text: string, size: number, color: Color3?, order: number, height: number?): TextLabel
	local l = Kit.label(body, text, size, color or C.ink, Kit.FONT_BOLD, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or size + 8), ZIndex = 12, TextWrapped = true })
	l.TextTruncate = Enum.TextTruncate.None
	return l
end

local function section(text: string, order: number)
	Kit.title(body, text, 20, C.muted, { LayoutOrder = order, ZIndex = 12 })
end

-- Rejilla dentro de la ventana
local function grid(order: number, cell: Vector2, rows: number): Frame
	return create("Frame", {
		Parent = body, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 12,
		Size = UDim2.new(1, 0, 0, rows * (cell.Y + 8)),
	}, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

do
	shade = create("TextButton", {
		Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "",
		AutoButtonColor = false, Visible = false, ZIndex = 10,
	})
	shade.Name = "Fondo"
	local window = create("Frame", {
		Parent = shade, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 450),
		BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 11,
	}, { Kit.corner(20), Kit.stroke(C.panelDark, 3), Kit.padding(16) })
	windowTitle = Kit.title(window, "", 30, C.ink, { Size = UDim2.new(1, -60, 0, 36), ZIndex = 12 })
	local closeButton = Kit.button(window, "✕", "red", UDim2.fromOffset(56, 56), function()
		closeWindow()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4), ZIndex = 12 })
	closeButton.ZIndex = 13
	closeButton.Name = "Cerrar"
	body = create("ScrollingFrame", {
		Parent = window, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = C.grey, ZIndex = 12,
	}, { Kit.list(false, 10), Kit.padding(0, 12, 0, 4) })

	function closeWindow()
		shade.Visible = false
		currentWindow = ""
	end

	function openWindow(id: string)
		if not ctx.state then
			return
		end
		currentWindow = id
		shade.Visible = true
		windowSig = if signatures[id] then signatures[id]() else ""
		clearBody()
		body.CanvasPosition = Vector2.new(0, 0)
		renderers[id]()
	end
end

-- Tarjeta con botón a la derecha (tienda, misiones, islas…)
local function rowCard(order: number, emoji: string, titleText: string, sub: string, buttonText: string, style: string, enabled: boolean, onClick: () -> ()): (Frame, TextButton)
	local card = Kit.card(body, { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = order, ZIndex = 12 })
	Kit.label(card, emoji, 36, nil, nil, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 52, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
	local t = Kit.title(card, titleText, 20, C.ink, { Position = UDim2.fromOffset(70, 12), Size = UDim2.new(1, -230, 0, 26), ZIndex = 13 })
	Kit.fit(t, 20)
	local d = Kit.label(card, sub, 16, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(70, 42), Size = UDim2.new(1, -230, 0, 22), ZIndex = 13 })
	Kit.fit(d, 16)
	local b = Kit.button(card, buttonText, style, UDim2.fromOffset(146, 62), onClick, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 13 })
	b.ZIndex = 14
	Kit.setButton(b, nil, enabled)
	return card, b
end

---------------------------------------------------------------------
-- Ventana: Crías (inventario). Arriba «Fusionar todo» (en el altar); toca una cría → detalles y botones
---------------------------------------------------------------------
do
	local selected = 0
	signatures.pets = function()
		local s = ctx.state
		return #s.pets .. "|" .. table.concat(s.equipped, ",") .. "|" .. s.slots .. "|" .. selected .. "|" .. tostring(s.nearAltar)
	end
	renderers.pets = function()
		local s = ctx.state
		windowTitle.Text = "🐾 " .. T("pets")
		local isEquipped = {}
		for _, uid in s.equipped do
			isEquipped[uid] = true
		end
		local counts, ready = fuseGroups(s)
		local sel = nil
		for _, p in s.pets do
			if p.uid == selected then
				sel = p
			end
		end
		-- Barra de arriba
		local top = create("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 1, ZIndex = 12 })
		local best = Kit.button(top, T("equip_best"), "gold", UDim2.fromOffset(230, 58), function()
			tutorialFlags.equippedBest = true
			send("equipBest")
		end, { ZIndex = 13 })
		best.ZIndex = 14
		best.Name = "EquiparMejores"
		local info = Kit.label(top, T("equipped_count", { n = #s.equipped, max = s.slots }) .. "\n" .. T("backpack_count", { n = #s.pets, max = s.backpack }), 16, C.ink, Kit.FONT_BOLD, {
			Position = UDim2.fromOffset(244, 0), Size = UDim2.new(1, -244, 1, 0), ZIndex = 13, TextWrapped = true,
		})
		info.TextTruncate = Enum.TextTruncate.None
		-- Fusión: en el altar «Fusionar todo»; lejos, el botón lleva al altar (isla 1)
		-- Orden: barra · cría elegida (si hay; así sus botones se ven sin bajar en el móvil) · fusión · repetidas · rejilla
		local _fc, fuseBtn = rowCard(3, "✨", if ready > 0 then T("fuse_ready", { n = ready }) else T("fuse_title"),
			if s.nearAltar then T("fuse_hint") else T("altar_hint"), if s.nearAltar then T("fuse_all") else T("go_altar"), if s.nearAltar then "gold" else "blue",
			(not s.nearAltar) or ready > 0, function()
				if s.nearAltar then
					send("fuseAll", nil, nil, nil, onFused, true)
				else
					send("teleport", 1)
					closeWindow()
				end
			end)
		fuseBtn.Name = if s.nearAltar then "FusionarTodo" else "IrAltar"
		-- «Soltar repetidas» (Míticas y de islas anteriores; nunca equipadas, Brillantes ni la última de cada especie).
		-- Pide un segundo toque
		local dupes = #Config.dupesToRelease(s)
		local armedDupes = false
		local dupesBtn: TextButton
		_fc, dupesBtn = rowCard(4, "🧹", T("dupes_title", { n = dupes }), T("dupes_hint"), T("release"), "red", dupes > 0, function()
			if not armedDupes then
				armedDupes = true
				dupesBtn.Text = T("release_sure")
				task.delay(3, function()
					if armedDupes and dupesBtn.Parent then
						armedDupes = false
						dupesBtn.Text = T("release")
					end
				end)
				return
			end
			armedDupes = false
			send("releaseDupes")
		end)
		dupesBtn.Name = "SoltarRepetidas"
		-- Detalle de la elegida
		if sel then
			local def = Config.PetById[sel.kind]
			local rarity = Config.Rarities[def.rarity]
			local card = Kit.card(body, { Size = UDim2.new(1, 0, 0, 132), LayoutOrder = 2, ZIndex = 12 })
			Kit.label(card, def.emoji, 48, nil, nil, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(64, 64), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
			local name = Kit.title(card, petLabel(sel.kind, sel.shiny) .. (if sel.shiny then " · " .. T("shiny") else ""), 22, C.ink, {
				Position = UDim2.fromOffset(80, 8), Size = UDim2.new(1, -90, 0, 28), ZIndex = 13,
			})
			Kit.fit(name, 22)
			local have = counts[groupKey(sel)] or 0
			local sub = Kit.label(card, "● " .. T("rar_" .. rarity.id) .. " · ⚔️ " .. T("power", { value = Kit.fmt(Config.petPower(sel.kind, sel.shiny)) }) .. " · " .. T("pet_have", { n = have }), 16, C.ink, Kit.FONT_BOLD, {
				Position = UDim2.fromOffset(80, 38), Size = UDim2.new(1, -90, 0, 22), ZIndex = 13,
			})
			Kit.fit(sub, 16)
			local actions = create("Frame", {
				Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 58), BackgroundTransparency = 1, ZIndex = 13,
			}, { Kit.list(true, 8) })
			local eq = isEquipped[sel.uid] == true
			local b1 = Kit.button(actions, if eq then T("unequip") else T("equip"), if eq then "white" else "green", UDim2.fromOffset(150, 56), function()
				send(if eq then "unequip" else "equip", sel.uid)
			end, { ZIndex = 14, LayoutOrder = 1 })
			b1.ZIndex = 15
			-- Fusionar su grupo (misma isla, rareza y Brillante): «Fusionar 3/5 → Rara» si faltan, «Fusionar 5 → Rara» si hay.
			-- Con bastantes pero lejos del altar, el botón lleva al altar (como «Ir al altar» de arriba)
			local need = rarity.fuseNeed
			local enough = need > 0 and have >= need
			local farAway = enough and s.nearAltar ~= true
			local nextName = if need > 0 then T("rar_" .. Config.Rarities[def.rarity + 1].id) else ""
			local b2Text = if need <= 0 then "MAX" elseif farAway then T("go_altar") elseif enough then T("fuse_go", { need = need, rarity = nextName })
				else T("fuse", { have = have, need = need, rarity = nextName })
			local b2 = Kit.button(actions, b2Text, if farAway then "blue" else "gold", UDim2.fromOffset(230, 56), function()
				if farAway then
					send("teleport", 1)
					closeWindow()
				else
					send("fuse", def.zone, def.rarity, sel.shiny == true, onFused, true)
				end
			end, { ZIndex = 14, LayoutOrder = 2 })
			b2.ZIndex = 15
			b2.Name = if farAway then "FusionarIrAltar" else "Fusionar"
			Kit.setButton(b2, nil, enough)
			-- Soltar pide un segundo toque (no se puede deshacer)
			local armed = false
			local b3: TextButton
			b3 = Kit.button(actions, T("release"), "red", UDim2.fromOffset(150, 56), function()
				if not armed then
					armed = true
					b3.Text = T("release_sure")
					task.delay(3, function()
						if armed and b3.Parent then
							armed = false
							b3.Text = T("release")
						end
					end)
					return
				end
				armed = false
				send("release", sel.uid)
				selected = 0
			end, { ZIndex = 14, LayoutOrder = 3 })
			b3.ZIndex = 15
			b3.Name = "Soltar"
			Kit.setButton(b3, nil, #s.pets > 1 and not eq)
		else
			line(T("pick_pet"), 16, C.muted, 5)
		end
		-- Rejilla: equipadas primero, luego por poder
		local list = table.clone(s.pets)
		table.sort(list, function(a, b)
			local ea, eb = isEquipped[a.uid] == true, isEquipped[b.uid] == true
			if ea ~= eb then
				return ea
			end
			return Config.petPower(a.kind, a.shiny) > Config.petPower(b.kind, b.shiny)
		end)
		local shown = math.min(#list, 300)
		local g = grid(6, Vector2.new(98, 112), math.ceil(shown / 5))
		for i = 1, shown do
			local p = list[i]
			local def = Config.PetById[p.kind]
			local rarity = Config.Rarities[def.rarity]
			local card = Kit.card(g, { LayoutOrder = i, ZIndex = 13, BackgroundColor3 = if p.uid == selected then C.panelDark else C.white })
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = rarity.color
				stroke.Thickness = 3
			end
			Kit.label(card, def.emoji, 40, nil, nil, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
			local pw = Kit.title(card, "⚔️" .. Kit.fmt(Config.petPower(p.kind, p.shiny)), 16, C.ink, {
				Position = UDim2.fromOffset(2, 62), Size = UDim2.new(1, -4, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14,
			})
			Kit.fit(pw, 16)
			local tag = (if p.shiny then "✨" else "") .. (if isEquipped[p.uid] then "✅" else "")
			Kit.label(card, tag, 18, nil, nil, { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
			local hit = create("TextButton", { Parent = card, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 15 })
			hit.Name = "Cria_" .. p.uid
			hit.Activated:Connect(function()
				selected = p.uid
				openWindow("pets")
			end)
		end
	end
end

---------------------------------------------------------------------
-- Ventana: Álbum (Índice). Normales: hitos con bonus + las 72 crías por isla. Brillantes: puntuación + las 72 en ✨
---------------------------------------------------------------------
do
	local shinyView = false
	signatures.album = function()
		local s = ctx.state
		local claimed = 0
		for _ in s.albumClaimed do
			claimed += 1
		end
		return s.albumCount .. "|" .. claimed .. "|" .. s.shinyScore .. "|" .. tostring(shinyView)
	end
	renderers.album = function()
		local s = ctx.state
		local total = Config.albumTotal()
		local pct = s.albumCount / total * 100
		windowTitle.Text = "📖 " .. T("album")
		-- Pestañas: normales / Brillantes
		local tabs = create("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 0, ZIndex = 12 }, { Kit.list(true, 10) })
		for i, v in { false, true } do
			local b = Kit.button(tabs, if v then T("album_shiny") else T("album_normal"), if v == shinyView then (if v then "gold" else "blue") else "white", UDim2.fromOffset(220, 56), function()
				shinyView = v
				openWindow("album")
			end, { ZIndex = 13, LayoutOrder = i })
			b.ZIndex = 14
			b.Name = if v then "VerBrillantes" else "VerNormales"
		end
		if shinyView then
			local need = Config.Zones[#Config.Zones].needShiny or 0
			line(T("shiny_score", { n = s.shinyScore, need = need }), 18, C.orangeDark, 1)
		else
			line(T("album_progress", { n = s.albumCount, max = total }) .. string.format("  (%.0f %%)", pct), 18, C.ink, 1)
			local g = grid(2, Vector2.new(108, 92), 1)
			for i, m in Config.AlbumMilestones do
				local claimed = s.albumClaimed[tostring(i)] == true
				local holder = create("Frame", { Parent = g, BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 13 })
				local t = Kit.title(holder, m.pct .. " % → +" .. math.floor(m.bonus * 100) .. " %", 17, C.ink, {
					Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13,
				})
				Kit.fit(t, 17)
				local b = Kit.button(holder, if claimed then T("claimed") else T("claim"), "green", UDim2.new(1, 0, 0, 60), function()
					send("claimAlbum", i)
				end, { Position = UDim2.fromOffset(0, 26), ZIndex = 13 })
				b.ZIndex = 14
				Kit.setButton(b, nil, not claimed and pct >= m.pct)
			end
		end
		local index = if shinyView then s.shinyIndex else s.album
		for zi, z in Config.Zones do
			section((if zi <= s.zones then "" else "🔒 ") .. T("zone_" .. z.id), 10 + zi * 2)
			local zg = grid(11 + zi * 2, Vector2.new(60, 62), 1)
			for ri, pet in z.pets do
				local have = index[pet.id] == true
				local cell = Kit.card(zg, { LayoutOrder = ri, ZIndex = 13, BackgroundColor3 = if have then C.white else C.panelDark })
				local stroke = cell:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if shinyView then C.gold else Config.Rarities[pet.rarity].color
					stroke.Thickness = if have then 3 else 1
				end
				Kit.label(cell, if have then pet.emoji else "?", 30, if have then nil else C.muted, Kit.FONT_TITLE, {
					Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14,
				})
			end
		end
	end
end

---------------------------------------------------------------------
-- Ventanas: Misiones, Diario, Tienda, Renacer, Islas, Ajustes
---------------------------------------------------------------------
do
	signatures.missions = function()
		local s = ctx.state
		local parts = {}
		for _, m in s.missions do
			table.insert(parts, m.progress .. (if m.claimed then "c" else ""))
		end
		return table.concat(parts, ",")
	end
	renderers.missions = function()
		local s = ctx.state
		windowTitle.Text = "🎯 " .. T("missions")
		for i, m in s.missions do
			local done = m.progress >= m.n
			local r = Config.MissionReward[m.tier]
			local prize = if r then "   ·   " .. T("reward", { value = coins(Config.minutesReward(r[1], r[2], s.coinRate)) }) else ""
			local _card, b = rowCard(i, if m.claimed then "✅" else "🎯", T("mission_" .. m.tier) .. ": " .. T("mission_" .. m.stat, { n = m.n }),
				math.min(m.progress, m.n) .. " / " .. m.n .. prize, if m.claimed then T("claimed") else T("claim"), "green", done and not m.claimed, function()
					send("claimMission", i)
				end)
			b.Name = "Mision" .. i
		end
		line(T("mission_bonus"), 16, if s.missionBonus then C.greenDark else C.muted, 10, 44)
	end

	signatures.daily = function()
		local s = ctx.state
		return tostring(s.daily.available) .. s.daily.streak
	end
	renderers.daily = function()
		local s = ctx.state
		windowTitle.Text = "🎁 " .. T("daily_title")
		local g = grid(1, Vector2.new(72, 110), 1)
		local streak = s.daily.streak
		local nextDay = if s.daily.available then (streak % #Config.Daily) + 1 else -1
		for day = 1, #Config.Daily do
			local done = day <= streak and not (s.daily.available and day >= nextDay)
			local last = day == #Config.Daily
			local cell = Kit.card(g, { LayoutOrder = day, ZIndex = 13, BackgroundColor3 = if day == nextDay then C.gold elseif done then C.panelDark else C.white })
			if last then
				local stroke = cell:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = C.goldDark
					stroke.Thickness = 3
				end
			end
			Kit.title(cell, T("daily_day", { n = day }), 15, C.ink, { Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
			Kit.label(cell, if done then "✅" elseif last then "💰" else "🪙", 34, nil, nil, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
			-- Cuánto da cada día (se calcula igual que en el servidor: minutos de monedas con un mínimo)
			local amount = Kit.title(cell, Kit.fmt(Config.dailyReward(day, s.coinRate)), 16, C.ink, {
				Position = UDim2.fromOffset(2, 76), Size = UDim2.new(1, -4, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14,
			})
			Kit.fit(amount, 16)
		end
		local claim = Kit.button(body, "", "green", UDim2.new(1, 0, 0, 60), function()
			send("claimDaily")
			closeWindow()
		end, { LayoutOrder = 2, ZIndex = 13 })
		claim.ZIndex = 14
		claim.Name = "RecogerDiario"
		Kit.setButton(claim, if s.daily.available then T("daily_claim") .. "  " .. coins(Config.dailyReward(nextDay, s.coinRate)) else T("daily_done"), s.daily.available == true)
		line(T("daily_hint"), 16, C.muted, 3, 44)
	end

	local function shopItem(order: number, item: Config.ShopItem, isPass: boolean)
		local s = ctx.state
		local prefix = if isPass then "pass_" else "prod_"
		local owned = isPass and (s.bonuses :: any)[item.key] == true
		local text = if owned then "✓" elseif item.id == 0 then T("soon") else ("R$ " .. item.price)
		rowCard(order, item.emoji, T(prefix .. item.key), T(prefix .. item.key .. "_desc"), text, "green", item.id ~= 0 and not owned, function()
			if item.id == 0 or owned then
				return
			end
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, item.id)
			else
				MarketplaceService:PromptProductPurchase(player, item.id)
			end
		end)
	end
	renderers.shop = function()
		windowTitle.Text = "🛒 " .. T("shop")
		section(T("passes"), 0)
		for i, p in Config.GamePasses do
			shopItem(i, p, true)
		end
		section(T("products"), 100)
		for i, p in Config.Products do
			shopItem(100 + i, p, false)
		end
	end

	-- Mejoras (temporal hasta los pedestales del Jardín, ronda 2b): las 12 con su estado y botón de comprar
	signatures.upgrades = function()
		local s = ctx.state
		local n = 0
		for _ in s.upgrades do
			n += 1
		end
		return s.stones .. "|" .. n .. "|" .. Mundo3D.near.pedestal
	end
	renderers.upgrades = function()
		local s = ctx.state
		windowTitle.Text = "🌳 " .. T("upgrades")
		line(T("up_header", { n = s.stones }), 18, C.ink, 0)
		-- Se compran en su pedestal del Jardín (Config.UPGRADE_NEEDS_PEDESTAL): desde lejos, la ventana lleva allí
		local near = Mundo3D.near.pedestal
		if Config.UPGRADE_NEEDS_PEDESTAL then
			local _c, go = rowCard(0, "🌳", T("zone_garden"), T("up_go_hint"), T("go_garden"), "green", true, function()
				send("teleport", 0)
				closeWindow()
			end)
			go.Name = "IrJardin"
		end
		for i, u in Config.Upgrades do
			local owned = s.upgrades[u.id] == true
			local ok, why, params = Config.canBuyUpgrade(s, u.id)
			local locked = why == "n_need_upgrade"
			local here = not Config.UPGRADE_NEEDS_PEDESTAL or near == u.id
			-- Se puede pagar pero estás lejos: el botón sigue gris (se compra en el pedestal), y el texto lo dice
			local sub = if locked and params then T("up_locked", { upgrade = T("up_" .. params.upgrade) })
				elseif ok and not here then T("up_go_buy", { desc = T("up_" .. u.id .. "_desc") })
				else T("up_" .. u.id .. "_desc")
			local _c, b = rowCard(i, if owned then "✅" elseif locked then "🔒" else u.emoji, T("up_" .. u.id), sub,
				if owned then T("up_owned") else T("up_state_cost", { n = u.cost }), if owned then "green" else "gold", ok and here, function()
					send("buyUpgrade", u.id)
				end)
			b.Name = "Mejora_" .. u.id
		end
	end

	signatures.islands = function()
		local s = ctx.state
		return s.zones .. "|" .. tostring(s.nextZone and s.nextZone.ok) .. "|" .. tostring(s.nextZone and s.nextZone.have)
	end
	renderers.islands = function()
		local s = ctx.state
		windowTitle.Text = "🗺️ " .. T("islands")
		local _g, garden = rowCard(0, "🌳", T("zone_garden"), T("garden_sub"), T("go"), "green", true, function()
			send("teleport", 0)
			closeWindow()
		end)
		garden.Name = "IrJardin"
		for i, z in Config.Zones do
			local name = i .. ". " .. T("zone_" .. z.id)
			if i <= s.zones then
				local _c, b = rowCard(i, "🏝️", name, T("egg_price", { value = coins(Config.eggCost(i, s)) }), T("go"), "blue", true, function()
					send("teleport", i)
					closeWindow()
				end)
				b.Name = "Ir" .. i
			elseif i == s.zones + 1 and s.nextZone then
				-- La siguiente: «Descubre N crías (tienes X)» o la puntuación Brillante (isla 9)
				local nz = s.nextZone
				local sub = if nz.kind == "shiny" then T("door_need_shiny", { need = nz.need, have = nz.have }) else T("door_need_index", { need = nz.need, have = nz.have })
				local _c, b = rowCard(i, "🔒", name, sub, T("door_open"), "green", nz.ok, function()
					send("unlockZone", i)
				end)
				b.Name = "AbrirIsla" .. i
			else
				rowCard(i, "🔒", name, T("door_need"), T("locked"), "grey", false, function() end)
			end
		end
	end

	renderers.settings = function()
		local s = ctx.state
		windowTitle.Text = "⚙️ " .. T("settings")
		local langKey = if s.settings.lang == "es" then "lang_es" elseif s.settings.lang == "en" then "lang_en" else "lang_auto"
		local nextLang = if s.settings.lang == "" then "es" elseif s.settings.lang == "es" then "en" else ""
		local b1 = Kit.button(body, T(langKey), "blue", UDim2.new(1, 0, 0, 60), function()
			send("setLang", nextLang, nil, nil, function()
				if nextLang == "" then
					ctx.lang = Lang.detect(LocalizationService.RobloxLocaleId)
				end
				openWindow("settings")
			end)
		end, { LayoutOrder = 1, ZIndex = 13 })
		b1.ZIndex = 14
		b1.Name = "Idioma"
		local b2 = Kit.button(body, if s.settings.muted then T("sound_off") else T("sound_on"), "white", UDim2.new(1, 0, 0, 60), function()
			send("setMuted", not s.settings.muted, nil, nil, function()
				openWindow("settings")
			end)
		end, { LayoutOrder = 2, ZIndex = 13 })
		b2.ZIndex = 14
		b2.Name = "Sonido"
		local b3 = Kit.button(body, T("tutorial_again"), "gold", UDim2.new(1, 0, 0, 60), function()
			tutorial.step = 1
			closeWindow()
		end, { LayoutOrder = 3, ZIndex = 13 })
		b3.ZIndex = 14
		line("v" .. s.version, 16, C.muted, 9)
	end
end

---------------------------------------------------------------------
-- Avisos (arriba, se apilan y desaparecen)
---------------------------------------------------------------------
do
	local toasts = create("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(440, 200),
		BackgroundTransparency = 1, ZIndex = 40,
	}, { Kit.list(false, 6, Enum.HorizontalAlignment.Center) })
	toastHolder = toasts
	-- color y seconds opcionales (aviso de cría rara: color de la rareza). «gold» y «rare» duran más y son más altos
	function showToast(text: string, kind: string?, color: Color3?, seconds: number?)
		local special = kind == "gold" or kind == "rare"
		local back = color or (if kind == "error" then C.red elseif kind == "success" then C.green elseif kind == "gold" then C.gold else C.blue)
		-- Fondo claro (dorado, amarillo) → texto oscuro sin borde; fondo oscuro → texto blanco con borde
		local light = back.R * 0.3 + back.G * 0.59 + back.B * 0.11 > 0.6
		-- Los especiales van en un marco con borde blanco grueso: así un aviso Mítico (rosa) no se confunde
		-- con un error (rojo). El borde va en el marco y el del texto en la etiqueta (un UIStroke en cada uno)
		local holder: GuiObject? = nil
		if special then
			holder = create("Frame", {
				Parent = toasts, BackgroundColor3 = back, Size = UDim2.fromOffset(430, 56), ZIndex = 41,
			}, { Kit.corner(14), Kit.stroke(C.white, 3) })
		end
		local t = create("TextLabel", {
			Parent = holder or toasts, BackgroundColor3 = back, BackgroundTransparency = if holder then 1 else 0,
			Size = if holder then UDim2.fromScale(1, 1) else UDim2.fromOffset(420, 44), Text = text,
			TextColor3 = if light then C.ink else C.white, FontFace = Kit.FONT_TITLE, TextSize = 18, TextWrapped = true, ZIndex = 42,
		}, { Kit.corner(12), Kit.padding(12, 12, 4, 4) })
		if not light then
			Kit.textStroke(1.5).Parent = t
		end
		local gone = holder or t
		task.delay(seconds or (if special then 5 else 3), function()
			gone:Destroy()
		end)
	end
end

---------------------------------------------------------------------
-- Tutorial (5 pasos, una vez; se puede saltar y repetir desde Ajustes)
---------------------------------------------------------------------
local updateTutorial: () -> ()
do
	local banner = create("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(520, 84),
		BackgroundColor3 = C.ink, BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false, ZIndex = 20,
	}, { Kit.corner(16), Kit.stroke(C.gold, 3), Kit.padding(10) })
	banner.Name = "Tutorial"
	local text = Kit.title(banner, "", 20, C.white, { Size = UDim2.new(1, -130, 1, 0), ZIndex = 21, TextWrapped = true })
	text.TextTruncate = Enum.TextTruncate.None
	Kit.fit(text, 20)
	local nextButton = Kit.button(banner, "", "gold", UDim2.fromOffset(120, 58), function()
		local step = tutorial.step
		if step == 4 then
			tutorial.step = 5
		else
			tutorial.step = 0 -- «Saltar» (pasos 1-3) o «¡Listo!» (paso 5)
			send("finishTutorial")
		end
		updateTutorial()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), ZIndex = 21 })
	nextButton.ZIndex = 22
	nextButton.Name = "TutorialSiguiente"

	function updateTutorial()
		local s = ctx.state
		if not s then
			return
		end
		if tutorial.step == 0 and not s.tutorialDone and not tutorial.started then
			tutorial.step = 1
			tutorial.started = true -- solo arranca solo una vez por sesión
		end
		local step = tutorial.step
		-- Pasos que se completan solos al hacerlos
		if step == 1 and s.lifetimeCoins > 0 then
			step = 2
		end
		if step == 2 and #s.pets > 1 then
			step = 3
		end
		if step == 3 and tutorialFlags.equippedBest then
			step = 4
		end
		tutorial.step = step
		banner.Visible = step > 0 and step <= 5 and not shade.Visible and not hatching
		-- Los avisos bajan si el tutorial ocupa su sitio (si no, se tapan el uno al otro)
		toastHolder.Position = UDim2.new(0.5, 0, 0, if banner.Visible then 204 else 112)
		Mundo3D.guide(if not banner.Visible then "" elseif step == 2 then "egg" elseif step == 4 then "altar" elseif step == 5 then "door" else "", s.zones)
		if banner.Visible then
			text.Text = "(" .. step .. "/5) " .. T("tut_" .. step)
			-- «Saltar» es secundario: pequeño y blanco. «Siguiente»/«¡Listo!» es la acción principal: grande y dorado
			local skip = step <= 3
			nextButton:SetAttribute("Style", if skip then "white" else "gold")
			local holder = nextButton.Parent :: Frame
			holder.Size = if skip then UDim2.fromOffset(110, 58) else UDim2.fromOffset(120, 58)
			text.Size = UDim2.new(1, if skip then -120 else -130, 1, 0)
			Kit.setButton(nextButton, if step == 5 then T("tut_done") elseif skip then T("tut_skip") else T("tut_next"), true)
		end
	end
end

---------------------------------------------------------------------
-- Estado del servidor → pantalla
---------------------------------------------------------------------
function refreshAll()
	local s = ctx.state
	if not s then
		return
	end
	if s.settings.lang ~= "" then
		ctx.lang = s.settings.lang
	end
	ctx.muted = s.settings.muted
	hudCoins.Text = coins(s.coins)
	hudRate.Text = "⚔️ " .. T("power", { value = Kit.fmt(s.power) }) .. "  ·  ~" .. T("per_sec", { value = Kit.fmt(s.coinRate) })
	local chips = {}
	if s.boostLeft > 0 then
		table.insert(chips, T("boost_on", { time = Kit.fmtTime(s.boostLeft) }))
	end
	if s.luckLeft > 0 then
		table.insert(chips, T("luck_on", { time = Kit.fmtTime(s.luckLeft) }))
	end
	hudChips.Text = table.concat(chips, "   ")
	-- Meta: lo que pide la próxima isla (crías descubiertas o puntuación Brillante), con su barra
	local nz = s.nextZone
	if nz then
		hudRebirth.Text = "🌉 " .. T(if nz.kind == "shiny" then "hud_next_shiny" else "hud_next_index", { have = math.min(nz.have, nz.need), need = nz.need })
		hudAlbumBar.Size = UDim2.fromScale(math.clamp(nz.have / math.max(1, nz.need), 0, 1), 1)
	else
		hudRebirth.Text = "🌉 " .. T("hud_all_open")
		hudAlbumBar.Size = UDim2.fromScale(1, 1)
	end
	-- Índice, puntuación Brillante y Piedras de Renacimiento (la moneda del Jardín)
	hudAlbum.Text = "📖 " .. s.albumCount .. "/" .. s.albumTotal .. "   ✨ " .. s.shinyScore .. "   🪨 " .. s.stones
	menuLabels()
	Kit.setButton(autoButton, if s.settings.auto then T("auto_on") else T("auto_off"), true)
	-- Puntos rojos
	dots.daily.Visible = s.daily.available
	local missionReady = false
	for _, m in s.missions do
		missionReady = missionReady or (m.progress >= m.n and not m.claimed)
	end
	dots.missions.Visible = missionReady
	local albumReady = false
	for i, m in Config.AlbumMilestones do
		albumReady = albumReady or (not s.albumClaimed[tostring(i)] and s.albumCount / Config.albumTotal() * 100 >= m.pct)
	end
	dots.album.Visible = albumReady
	local canBuy = false
	for _, u in Config.Upgrades do
		canBuy = canBuy or Config.canBuyUpgrade(s, u.id)
	end
	dots.upgrades.Visible = canBuy
	dots.islands.Visible = nz ~= nil and nz.ok == true
	local _counts, ready = fuseGroups(s)
	dots.pets.Visible = ready > 0
	Mundo3D.refresh(s)
	updateContext()
	updateTutorial()
	-- Ventana abierta: se redibuja solo si ha cambiado algo suyo (así no salta el scroll)
	if shade.Visible and currentWindow ~= "" and signatures[currentWindow] then
		local sig = signatures[currentWindow]()
		if sig ~= windowSig then
			local scroll = body.CanvasPosition
			openWindow(currentWindow)
			body.CanvasPosition = scroll
		end
	end
end

-- Altar de fusión (ProximityPrompt): abre la ventana de Crías, que arriba tiene «Fusionar todo»
Mundo3D.onAltar = function()
	openWindow("pets")
end

stateRemote.OnClientEvent:Connect(function(s)
	ctx.state = s
	refreshAll()
end)

notifyRemote.OnClientEvent:Connect(function(kind: string, textKey: string, params: any)
	if kind == "coins" and params then
		Mundo3D.floatText(Vector3.new(params.x or 0, params.y or 0, params.z or 0), "+" .. coins(params.value or 0), nil, tonumber(params.rel))
		return
	end
	if kind == "rare" then
		-- Quien la saca ya tiene su gran momento: el aviso es para los demás
		if not params or params.uid == player.UserId then
			return
		end
		showToast(T(textKey, niceParams(params)), "rare", rarityColor(tostring(params.rarity)), 5)
		return
	end
	showToast(T(textKey, niceParams(params)), kind)
end)

-- El panel del huevo/puerta depende de dónde estás: se mira también entre estados
task.spawn(function()
	while true do
		task.wait(0.25)
		updateContext()
	end
end)
