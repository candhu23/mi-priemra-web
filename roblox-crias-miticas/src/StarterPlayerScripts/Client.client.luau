--[[
	Cliente de Crías Míticas: TODA la interfaz. Solo enseña el estado que manda el servidor y pide acciones.
	Pantallas: HUD (monedas, renacer, álbum), menú (8 botones), botón Auto, panel del huevo (con
	probabilidades) o de la puerta, apertura de huevo, ventanas (Crías, Álbum, Misiones, Diario, Tienda,
	Renacer, Islas, Ajustes), avisos y tutorial. Lo 3D (crías, carteles) está en UI/Mundo3D.
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
local showToast: (text: string, kind: string?) -> ()
local refreshAll: () -> ()
local openWindow: (id: string) -> ()
local closeWindow: () -> ()
local showHatch: (list: { any }) -> ()
local tutorialFlags = { equippedBest = false }
local tutorial = { step = 0, started = false }

local function petName(kind: string): string
	return T("pet_" .. kind)
end

local function rarityOf(kind: string): Config.Rarity
	return Config.Rarities[Config.PetById[kind].rarity]
end

local function tierName(tier: number): string
	return if tier > 0 then T("tier_" .. tier) else ""
end

local function coins(n: number): string
	return "🪙 " .. Kit.fmt(n)
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
	return p
end

-- Pide una acción al servidor; onDone(ok, params) si hace falta la respuesta
local function send(action: string, a: any?, b: any?, c: any?, onDone: ((boolean, any) -> ())?)
	task.spawn(function()
		local ok, okServer, textKey, params = pcall(function()
			return actionRemote:InvokeServer(action, a, b, c)
		end)
		if not ok then
			return
		end
		if textKey then
			showToast(T(textKey, niceParams(params)), if okServer then "success" else "error")
		end
		if onDone then
			onDone(okServer == true, params)
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
-- HUD: monedas arriba en el centro, avisos de boost/suerte debajo; renacer y álbum arriba a la izquierda
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
		Parent = root, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(200, 70), BackgroundColor3 = C.panel, BorderSizePixel = 0,
	}, { Kit.corner(16), Kit.stroke(C.panelDark, 3), Kit.padding(10, 10, 6, 6) })
	hudRebirth = Kit.title(info, "", 18, C.purpleDark, { Size = UDim2.new(1, 0, 0, 22) })
	hudAlbum = Kit.label(info, "", 16, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18) })
	Kit.fit(hudAlbum, 16)
	local barBack = create("Frame", {
		Parent = info, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = C.panelDark, BorderSizePixel = 0,
	}, { Kit.corner(5) })
	hudAlbumBar = create("Frame", { Parent = barBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, BorderSizePixel = 0 }, { Kit.corner(5) })
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
		{ "shop", "🛒", "purple" }, { "rebirth", "🔁", "purple" }, { "islands", "🗺️", "blue" }, { "settings", "⚙️", "white" },
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
	local oddsCards = {}
	for i = 1, #Config.Rarities do
		local card = Kit.card(oddsRow, { Size = UDim2.fromOffset(60, 90), LayoutOrder = i })
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Config.Rarities[i].color
			stroke.Thickness = 3
		end
		local emoji = Kit.label(card, "", 30, nil, nil, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center })
		local pct = Kit.title(card, "", 17, C.ink, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center })
		Kit.fit(pct, 17)
		local seen = Kit.label(card, "", 16, C.greenDark, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
		oddsCards[i] = { emoji = emoji, pct = pct, seen = seen }
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
			eggTitle.Text = "🥚 " .. T("egg_title", { zone = T("zone_" .. z.id) }) .. (if s.luckLeft > 0 then "  🍀x2" else "")
			local odds = Config.eggOdds(egg, s.luckLeft > 0)
			for i, card in oddsCards do
				local pet = z.pets[i]
				card.emoji.Text = pet.emoji
				card.pct.Text = (if odds[i] < 1 then string.format("%.1f", odds[i]) else string.format("%.0f", odds[i])) .. " %"
				card.seen.Text = if s.album[Config.albumKey(pet.id, 0)] then "✓" else "?"
			end
			Kit.setButton(open1, T("egg_open", { value = coins(z.eggCost) }), s.coins >= z.eggCost)
			Kit.setButton(open3, if s.bonuses.hatch3 then T("egg_open3", { value = Kit.fmt(z.eggCost * 3) }) elseif passExists("hatch3") then "🔒 x3" else T("soon"),
				(s.bonuses.hatch3 and s.coins >= z.eggCost * 3) or (not s.bonuses.hatch3 and passExists("hatch3")))
			Kit.setButton(autoEgg, if s.bonuses.autoHatch then (if autoHatchOn then T("egg_auto_stop") else T("egg_auto")) elseif passExists("autoHatch") then "🔒 " .. T("egg_auto") else T("soon"),
				s.bonuses.autoHatch or passExists("autoHatch"))
		end
		if door > 0 then
			local z = Config.Zones[door]
			doorTitle.Text = T("door_title", { zone = T("zone_" .. z.id) })
			if door == s.zones + 1 then
				Kit.setButton(doorButton, T("door_open", { value = coins(z.doorCost) }), s.coins >= z.doorCost)
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
						showHatch(params.hatched)
					end
				end)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Apertura de huevo: el huevo tiembla y aparece la cría (o 3) con su rareza
---------------------------------------------------------------------
do
	local overlay = create("TextButton", {
		Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Text = "",
		AutoButtonColor = false, Visible = false, ZIndex = 30,
	})
	overlay.Name = "Apertura"
	local row = create("Frame", {
		Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(660, 260),
		BackgroundTransparency = 1, ZIndex = 31,
	}, { Kit.list(true, 20, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local hint = Kit.title(overlay, "", 20, C.white, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(400, 26),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 31,
	})
	Kit.textStroke(2).Parent = hint
	local token = 0
	local function hide()
		overlay.Visible = false
		hatching = false
		updateContext()
	end
	overlay.Activated:Connect(hide)

	function showHatch(list: { any })
		token += 1
		local my = token
		for _, c in row:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		hint.Text = T("tap_continue")
		overlay.Visible = true
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
		task.delay(0.6, function()
			if my ~= token then
				return
			end
			for _, c in cards do
				local rarity = rarityOf(c.h.kind)
				c.big.Rotation = 0
				c.big.Text = Config.PetById[c.h.kind].emoji
				local stroke = c.card:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = rarity.color
					stroke.Thickness = 5
				end
				local name = Kit.title(c.card, petName(c.h.kind), 22, C.ink, {
					Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 33,
				})
				Kit.fit(name, 22)
				local pill = Kit.title(c.card, T("rar_" .. rarity.id), 20, C.ink, {
					AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 174), Size = UDim2.fromOffset(150, 30),
					TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = rarity.color, BackgroundTransparency = 0, ZIndex = 33,
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
		end)
		task.delay(2.4, function()
			if my == token then
				hide()
			end
		end)
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
-- Ventana: Crías (inventario). Toca una cría → detalles y botones
---------------------------------------------------------------------
do
	local selected = 0
	signatures.pets = function()
		local s = ctx.state
		return #s.pets .. "|" .. table.concat(s.equipped, ",") .. "|" .. s.slots .. "|" .. selected
	end
	renderers.pets = function()
		local s = ctx.state
		windowTitle.Text = "🐾 " .. T("pets")
		local isEquipped = {}
		for _, uid in s.equipped do
			isEquipped[uid] = true
		end
		local counts = {}
		local sel = nil
		for _, p in s.pets do
			local k = p.kind .. ":" .. p.tier
			counts[k] = (counts[k] or 0) + 1
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
		-- Detalle de la elegida
		if sel then
			local def = Config.PetById[sel.kind]
			local rarity = Config.Rarities[def.rarity]
			local card = Kit.card(body, { Size = UDim2.new(1, 0, 0, 132), LayoutOrder = 2, ZIndex = 12 })
			Kit.label(card, def.emoji, 48, nil, nil, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(64, 64), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
			local name = Kit.title(card, petName(sel.kind) .. (if sel.tier > 0 then " · " .. tierName(sel.tier) else ""), 22, C.ink, {
				Position = UDim2.fromOffset(80, 8), Size = UDim2.new(1, -90, 0, 28), ZIndex = 13,
			})
			Kit.fit(name, 22)
			local sub = Kit.label(card, "● " .. T("rar_" .. rarity.id) .. " · ⚔️ " .. T("power", { value = Kit.fmt(Config.petPower(sel.kind, sel.tier)) }) .. " · " .. T("pet_have", { n = counts[sel.kind .. ":" .. sel.tier] or 0 }), 16, C.ink, Kit.FONT_BOLD, {
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
			local canFuse = sel.tier < Config.MAX_TIER and (counts[sel.kind .. ":" .. sel.tier] or 0) >= Config.FUSE_COUNT
			local b2 = Kit.button(actions, if sel.tier < Config.MAX_TIER then T("fuse", { tier = tierName(sel.tier + 1) }) else "MAX", "gold", UDim2.fromOffset(230, 56), function()
				send("fuse", sel.kind, sel.tier)
			end, { ZIndex = 14, LayoutOrder = 2 })
			b2.ZIndex = 15
			b2.Name = "Fusionar"
			Kit.setButton(b2, nil, canFuse)
			local b3 = Kit.button(actions, T("release"), "red", UDim2.fromOffset(150, 56), function()
				send("release", sel.uid)
				selected = 0
			end, { ZIndex = 14, LayoutOrder = 3 })
			b3.ZIndex = 15
			b3.Name = "Soltar"
			Kit.setButton(b3, nil, #s.pets > 1)
		else
			line(T("pick_pet"), 16, C.muted, 2)
		end
		-- Rejilla: equipadas primero, luego por poder
		local list = table.clone(s.pets)
		table.sort(list, function(a, b)
			local ea, eb = isEquipped[a.uid] == true, isEquipped[b.uid] == true
			if ea ~= eb then
				return ea
			end
			return Config.petPower(a.kind, a.tier) > Config.petPower(b.kind, b.tier)
		end)
		local shown = math.min(#list, 300)
		local g = grid(3, Vector2.new(98, 112), math.ceil(shown / 5))
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
			local pw = Kit.title(card, "⚔️" .. Kit.fmt(Config.petPower(p.kind, p.tier)), 16, C.ink, {
				Position = UDim2.fromOffset(2, 62), Size = UDim2.new(1, -4, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14,
			})
			Kit.fit(pw, 16)
			local tag = (if p.tier == 1 then "⭐" elseif p.tier == 2 then "🌈" else "") .. (if isEquipped[p.uid] then "✅" else "")
			Kit.label(card, tag, 18, nil, nil, { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
			local hit = create("TextButton", { Parent = card, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 15 })
			hit.Activated:Connect(function()
				selected = p.uid
				openWindow("pets")
			end)
		end
	end
end

---------------------------------------------------------------------
-- Ventana: Álbum (Colecciónalas todas). Hitos con bonus + todas las crías por isla
---------------------------------------------------------------------
do
	signatures.album = function()
		local s = ctx.state
		local claimed = 0
		for _ in s.albumClaimed do
			claimed += 1
		end
		return s.albumCount .. "|" .. claimed
	end
	renderers.album = function()
		local s = ctx.state
		local total = Config.albumTotal()
		local pct = s.albumCount / total * 100
		windowTitle.Text = "📖 " .. T("album")
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
		for zi, z in Config.Zones do
			section((if zi <= s.zones or s.rebirths > 0 then "" else "🔒 ") .. T("zone_" .. z.id), 10 + zi * 2)
			local zg = grid(11 + zi * 2, Vector2.new(60, 62), 3)
			for tier = 0, Config.MAX_TIER do
				for ri, pet in z.pets do
					local have = s.album[Config.albumKey(pet.id, tier)] == true
					local cell = Kit.card(zg, { LayoutOrder = tier * 10 + ri, ZIndex = 13, BackgroundColor3 = if have then C.white else C.panelDark })
					local stroke = cell:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Color = if tier == 1 then C.gold elseif tier == 2 then C.purple else Config.Rarities[ri].color
						stroke.Thickness = if have then 3 else 1
					end
					Kit.label(cell, if have then pet.emoji else "?", 30, if have then nil else C.muted, Kit.FONT_TITLE, {
						Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14,
					})
				end
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
			local _card, b = rowCard(i, if m.claimed then "✅" else "🎯", T("mission_" .. m.tier) .. ": " .. T("mission_" .. m.stat, { n = m.n }),
				m.progress .. " / " .. m.n, if m.claimed then T("claimed") else T("claim"), "green", done and not m.claimed, function()
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
			local cell = Kit.card(g, { LayoutOrder = day, ZIndex = 13, BackgroundColor3 = if day == nextDay then C.gold elseif done then C.panelDark else C.white })
			Kit.title(cell, T("daily_day", { n = day }), 15, C.ink, { Position = UDim2.fromOffset(0, 8), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
			Kit.label(cell, if done then "✅" else "🪙", 34, nil, nil, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
		end
		local claim = Kit.button(body, "", "green", UDim2.new(1, 0, 0, 60), function()
			send("claimDaily")
			closeWindow()
		end, { LayoutOrder = 2, ZIndex = 13 })
		claim.ZIndex = 14
		claim.Name = "RecogerDiario"
		Kit.setButton(claim, if s.daily.available then T("daily_claim") else T("daily_done"), s.daily.available == true)
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

	signatures.rebirth = function()
		local s = ctx.state
		return s.rebirths .. "|" .. s.zones .. "|" .. tostring(s.coins >= s.rebirthCost)
	end
	renderers.rebirth = function()
		local s = ctx.state
		windowTitle.Text = "🔁 " .. T("rebirth")
		line(T("rebirth_count", { n = s.rebirths }), 22, C.purpleDark, 1)
		line(T("rebirth_info"), 18, C.ink, 2, 52)
		local now = 1 + Config.REBIRTH_BONUS * s.rebirths
		line(T("rebirth_gain", { now = now, next = now + Config.REBIRTH_BONUS }), 18, C.greenDark, 3)
		local zoneOk = s.zones >= s.rebirthZone
		line(T("rebirth_req", { zone = s.rebirthZone, value = coins(s.rebirthCost) }), 18, if zoneOk and s.coins >= s.rebirthCost then C.greenDark else C.red, 4, 48)
		local b = Kit.button(body, T("rebirth_go"), "purple", UDim2.new(1, 0, 0, 64), function()
			send("rebirth")
			closeWindow()
		end, { LayoutOrder = 5, ZIndex = 13 })
		b.ZIndex = 14
		b.Name = "Renacer"
		Kit.setButton(b, nil, zoneOk and s.coins >= s.rebirthCost)
	end

	signatures.islands = function()
		local s = ctx.state
		local nextZone = Config.Zones[s.zones + 1]
		return s.zones .. "|" .. tostring(nextZone ~= nil and s.coins >= nextZone.doorCost)
	end
	renderers.islands = function()
		local s = ctx.state
		windowTitle.Text = "🗺️ " .. T("islands")
		for i, z in Config.Zones do
			local name = i .. ". " .. T("zone_" .. z.id)
			if i <= s.zones then
				local _c, b = rowCard(i, "🏝️", name, "🥚 " .. coins(z.eggCost), T("go"), "blue", true, function()
					send("teleport", i)
					closeWindow()
				end)
				b.Name = "Ir" .. i
			elseif i == s.zones + 1 then
				local _c, b = rowCard(i, "🔒", name, "", coins(z.doorCost), "green", s.coins >= z.doorCost, function()
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
	function showToast(text: string, kind: string?)
		local color = if kind == "error" then C.red elseif kind == "success" then C.green else C.blue
		local t = create("TextLabel", {
			Parent = toasts, BackgroundColor3 = color, Size = UDim2.fromOffset(420, 44), Text = text, TextColor3 = C.white,
			FontFace = Kit.FONT_TITLE, TextSize = 18, TextWrapped = true, ZIndex = 41,
		}, { Kit.corner(12), Kit.padding(10, 10, 4, 4), Kit.textStroke(1.5) })
		task.delay(3, function()
			t:Destroy()
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
	local text = Kit.title(banner, "", 18, C.white, { Size = UDim2.new(1, -130, 1, 0), ZIndex = 21, TextWrapped = true })
	text.TextTruncate = Enum.TextTruncate.None
	Kit.fit(text, 18)
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
		if banner.Visible then
			text.Text = T("tut_" .. step)
			Kit.setButton(nextButton, if step == 5 then T("tut_done") elseif step <= 3 then T("tut_skip") else T("tut_next"), true)
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
	hudRebirth.Text = "🔁 " .. T("rebirth_count", { n = s.rebirths })
	hudAlbum.Text = "📖 " .. T("album_progress", { n = s.albumCount, max = Config.albumTotal() })
	hudAlbumBar.Size = UDim2.fromScale(s.albumCount / Config.albumTotal(), 1)
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
	dots.rebirth.Visible = s.zones >= s.rebirthZone and s.coins >= s.rebirthCost
	local nextZone = Config.Zones[s.zones + 1]
	dots.islands.Visible = nextZone ~= nil and s.coins >= nextZone.doorCost
	local fusable = false
	local counts = {}
	for _, p in s.pets do
		if p.tier < Config.MAX_TIER then
			local k = p.kind .. ":" .. p.tier
			counts[k] = (counts[k] or 0) + 1
			fusable = fusable or counts[k] >= Config.FUSE_COUNT
		end
	end
	dots.pets.Visible = fusable
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

stateRemote.OnClientEvent:Connect(function(s)
	ctx.state = s
	refreshAll()
end)

notifyRemote.OnClientEvent:Connect(function(kind: string, textKey: string, params: any)
	if kind == "coins" and params then
		Mundo3D.floatText(Vector3.new(params.x or 0, params.y or 0, params.z or 0), "+" .. coins(params.value or 0))
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
