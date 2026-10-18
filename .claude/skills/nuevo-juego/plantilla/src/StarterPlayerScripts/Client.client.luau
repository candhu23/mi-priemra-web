--[[
	Cliente de {{NOMBRE}}: TODA la interfaz. Solo enseña el estado que manda el servidor y pide acciones.
	Pantallas: HUD (dinero), botón TOCA, panel de negocios, Tienda y Diario (ventanas), avisos.
	Diseño: piezas de UI/Kit (botón grueso, tarjetas) en unidades de 960×540 (Kit.root escala).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalizationService = game:GetService("LocalizationService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))
local Kit = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local C, T, create = Kit.C, Kit.T, Kit.create
local ctx = Kit.ctx

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("{{PREFIJO}}Remotes")
local actionRemote = remotes:WaitForChild("Action") :: RemoteFunction
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

ctx.lang = Lang.detect(LocalizationService.RobloxLocaleId)

local gui = create("ScreenGui", { Name = "{{PREFIJO}}UI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
Kit.setupSounds(gui)
local root = Kit.root(gui)

local showToast: (text: string, kind: string?) -> ()
local refreshAll: () -> ()

local function send(action: string, a: any?, b: any?)
	task.spawn(function()
		local ok, okServer, textKey, params = pcall(function()
			return actionRemote:InvokeServer(action, a, b)
		end)
		if ok and textKey then
			local p = params or {}
			if p.item then
				p.item = T(p.item)
			end
			showToast(T(textKey, p), if okServer then "success" else "error")
		end
	end)
end

---------------------------------------------------------------------
-- HUD: dinero arriba en el centro
---------------------------------------------------------------------
local hud = create("Frame", {
	Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 70),
	BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, { Kit.corner(18), Kit.stroke(C.panelDark, 3) })
local moneyLabel = Kit.title(hud, "$0", 34, C.greenDark, {
	Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center,
})
local incomeLabel = Kit.label(hud, "", 16, C.muted, Kit.FONT_BOLD, {
	Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center,
})

---------------------------------------------------------------------
-- Botón principal: TOCA (con «+$X» flotante)
---------------------------------------------------------------------
local tapHolder = create("Frame", {
	Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.33, 0, 0.55, 0), Size = UDim2.fromOffset(200, 200),
	BackgroundTransparency = 1,
})
local tapButton = Kit.button(tapHolder, "💵", "green", UDim2.fromScale(1, 1), function()
	send("click")
	local s = ctx.state
	local value = if s then s.clickValue else 1
	local float = Kit.title(tapHolder, "+" .. Kit.fmtMoney(value), 30, C.gold, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.random(-50, 50), 0.2, 0), Size = UDim2.fromOffset(160, 36),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
	})
	Kit.textStroke(2).Parent = float
	Kit.tween(float, 0.8, { Position = float.Position - UDim2.fromOffset(0, 80), TextTransparency = 1 })
	task.delay(0.8, function()
		float:Destroy()
	end)
end)
Kit.fit(tapButton, 90)
local tapBase = tapButton.Parent :: Frame
for _, d in tapBase:GetChildren() do
	if d:IsA("UICorner") then
		d.CornerRadius = UDim.new(0.5, 0)
	end
end
for _, d in tapButton:GetChildren() do
	if d:IsA("UICorner") then
		d.CornerRadius = UDim.new(0.5, 0)
	end
end
local tapHint = Kit.title(tapHolder, "", 24, C.white, {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.fromOffset(260, 30), TextXAlignment = Enum.TextXAlignment.Center,
})
Kit.textStroke(2).Parent = tapHint
Kit.fit(tapHint, 24)

---------------------------------------------------------------------
-- Panel de negocios (derecha)
---------------------------------------------------------------------
local panel = create("Frame", {
	Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 92), Size = UDim2.new(0, 370, 1, -104),
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0,
}, { Kit.corner(18), Kit.stroke(C.panelDark, 3), Kit.padding(12) })
local panelTitle = Kit.title(panel, "", 26, C.ink, { Size = UDim2.new(1, 0, 0, 32) })
local scroll = create("ScrollingFrame", {
	Parent = panel, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = C.grey,
}, { Kit.list(false, 8), Kit.padding(0, 8, 0, 4) })

type Row = { name: TextLabel, info: TextLabel, buy: TextButton, update: (any) -> () }
local rows: { Row } = {}

local function makeRow(order: number, emoji: string, onBuy: () -> ()): Row
	local card = Kit.card(scroll, { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = order })
	Kit.label(card, emoji, 34, nil, nil, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 46, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
	local name = Kit.title(card, "", 19, C.ink, { Position = UDim2.fromOffset(58, 10), Size = UDim2.new(1, -172, 0, 26) })
	Kit.fit(name, 19)
	local info = Kit.label(card, "", 16, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(58, 40), Size = UDim2.new(1, -172, 0, 24) })
	Kit.fit(info, 16)
	local buy = Kit.button(card, "", "orange", UDim2.fromOffset(104, 58), onBuy, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
	})
	Kit.fit(buy, 18)
	return { name = name, info = info, buy = buy, update = function() end }
end

for i, g in Config.Generators do
	local row = makeRow(i, g.emoji, function()
		send("buy", g.id)
	end)
	row.update = function(s)
		local owned = s.generators[g.id] or 0
		local cost = Config.genCost(g.id, owned)
		row.name.Text = T("gen_" .. g.id)
		row.info.Text = T("owned", { n = owned }) .. " · " .. T("income_each", { value = Kit.fmtMoney(g.income * Config.moneyMult(s.bonuses)) })
		Kit.setButton(row.buy, Kit.fmtMoney(cost), s.money >= cost)
	end
	table.insert(rows, row)
end
do
	local row = makeRow(#Config.Generators + 1, "👆", function()
		send("upgradeClick")
	end)
	row.update = function(s)
		local maxed = s.clickLevel >= Config.ClickUpgrade.max
		local cost = Config.clickUpgradeCost(s.clickLevel)
		row.name.Text = T("click_upgrade")
		row.info.Text = T("click_level", { n = s.clickLevel }) .. " · +" .. Kit.fmtMoney(s.clickValue)
		Kit.setButton(row.buy, if maxed then "MAX" else Kit.fmtMoney(cost), not maxed and s.money >= cost)
	end
	table.insert(rows, row)
end

---------------------------------------------------------------------
-- Botones de abajo a la izquierda: Tienda y Diario (con punto rojo)
---------------------------------------------------------------------
local dock = create("Frame", {
	Parent = root, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(250, 64), BackgroundTransparency = 1,
}, { Kit.list(true, 10) })
local openWindow: (id: string) -> ()
local shopButton = Kit.button(dock, "", "blue", UDim2.fromOffset(120, 60), function()
	openWindow("shop")
end)
local dailyButton = Kit.button(dock, "", "gold", UDim2.fromOffset(120, 60), function()
	openWindow("daily")
end)
local dailyDot = create("Frame", {
	Parent = dailyButton, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = C.red, Visible = false, ZIndex = 3,
}, { Kit.corner(), Kit.stroke(C.white, 2) })

---------------------------------------------------------------------
-- Ventanas (una a la vez, centradas, con fondo oscuro detrás)
---------------------------------------------------------------------
local shade = create("TextButton", {
	Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "",
	AutoButtonColor = false, Visible = false, ZIndex = 10,
})
local window = create("Frame", {
	Parent = shade, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 420),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 11,
}, { Kit.corner(20), Kit.stroke(C.panelDark, 3), Kit.padding(16) })
local windowTitle = Kit.title(window, "", 30, C.ink, { Size = UDim2.new(1, -60, 0, 36), ZIndex = 12 })
local closeButton = Kit.button(window, "✕", "red", UDim2.fromOffset(56, 56), function()
	shade.Visible = false
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4), ZIndex = 12 })
closeButton.ZIndex = 13
local body = create("ScrollingFrame", {
	Parent = window, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 12,
}, { Kit.list(false, 10), Kit.padding(0, 8, 0, 4) })
local currentWindow = ""

local function clearBody()
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function shopItem(order: number, item: Config.ShopItem, isPass: boolean)
	local card = Kit.card(body, { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = order, ZIndex = 12 })
	local prefix = if isPass then "pass_" else "prod_"
	Kit.label(card, item.emoji, 38, nil, nil, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 52, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
	Kit.title(card, T(prefix .. item.key), 20, C.ink, { Position = UDim2.fromOffset(70, 12), Size = UDim2.new(1, -210, 0, 26), ZIndex = 13 })
	Kit.label(card, T(prefix .. item.key .. "_desc"), 15, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(70, 40), Size = UDim2.new(1, -210, 0, 20), ZIndex = 13 })
	local owned = isPass and ctx.state and (ctx.state.bonuses :: any)[item.key] == true
	local text = if owned then "✓" elseif item.id == 0 then T("soon") else ("R$ " .. item.price)
	local buy = Kit.button(card, text, "green", UDim2.fromOffset(136, 62), function()
		if item.id == 0 or owned then
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.id)
		end
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 13 })
	buy.ZIndex = 14
	Kit.setButton(buy, nil, item.id ~= 0 and not owned)
end

local function renderShop()
	windowTitle.Text = "🛒 " .. T("shop")
	clearBody()
	Kit.title(body, T("passes"), 18, C.muted, { LayoutOrder = 0, ZIndex = 12 })
	for i, p in Config.GamePasses do
		shopItem(i, p, true)
	end
	Kit.title(body, T("products"), 18, C.muted, { LayoutOrder = 100, ZIndex = 12 })
	for i, p in Config.Products do
		shopItem(100 + i, p, false)
	end
end

local function renderDaily()
	local s = ctx.state
	windowTitle.Text = "🎁 " .. T("daily_title")
	clearBody()
	local grid = create("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), LayoutOrder = 1, ZIndex = 12 }, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(68, 110), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local streak = if s then s.daily.streak else 0
	local nextDay = if s and s.daily.available then (streak % #Config.Daily) + 1 else -1
	for day = 1, #Config.Daily do
		local done = day <= streak and not (s and s.daily.available and day >= nextDay)
		local cell = Kit.card(grid, { LayoutOrder = day, ZIndex = 13, BackgroundColor3 = if day == nextDay then C.gold elseif done then C.panelDark else C.white })
		Kit.title(cell, T("daily_day", { n = day }), 15, C.ink, { Position = UDim2.fromOffset(0, 8), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
		Kit.label(cell, if done then "✅" else "💰", 34, nil, nil, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
	end
	local claim = Kit.button(body, "", "green", UDim2.new(1, 0, 0, 60), function()
		send("claimDaily")
		shade.Visible = false
	end, { LayoutOrder = 2, ZIndex = 13 })
	claim.ZIndex = 14
	local available = s and s.daily.available
	Kit.setButton(claim, if available then T("daily_claim") else T("daily_done"), available == true)
end

function openWindow(id: string)
	currentWindow = id
	shade.Visible = true
	if id == "shop" then
		renderShop()
	else
		renderDaily()
	end
end

---------------------------------------------------------------------
-- Avisos (arriba, se apilan y desaparecen)
---------------------------------------------------------------------
local toasts = create("Frame", {
	Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(420, 200),
	BackgroundTransparency = 1, ZIndex = 20,
}, { Kit.list(false, 6, Enum.HorizontalAlignment.Center) })

function showToast(text: string, kind: string?)
	local color = if kind == "error" then C.red elseif kind == "success" then C.green else C.blue
	local t = create("TextLabel", {
		Parent = toasts, BackgroundColor3 = color, Size = UDim2.fromOffset(400, 44), Text = text, TextColor3 = C.white,
		FontFace = Kit.FONT_TITLE, TextSize = 18, TextWrapped = true, ZIndex = 21,
	}, { Kit.corner(12), Kit.padding(10, 10, 4, 4), Kit.textStroke(1.5) })
	task.delay(3, function()
		t:Destroy()
	end)
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
	moneyLabel.Text = "💰 " .. Kit.fmtMoney(s.money)
	incomeLabel.Text = T("per_sec", { value = Kit.fmtMoney(s.incomePerSec) })
	tapHint.Text = if s.lifetimeEarned < 50 then T("tap_hint") else T("tap")
	panelTitle.Text = "🏢 " .. T("generators")
	shopButton.Text = "🛒 " .. T("shop")
	dailyButton.Text = "🎁 " .. T("daily")
	dailyDot.Visible = s.daily.available
	for _, row in rows do
		row.update(s)
	end
	if shade.Visible and currentWindow == "daily" then
		renderDaily()
	end
end

stateRemote.OnClientEvent:Connect(function(s)
	ctx.state = s
	refreshAll()
end)

notifyRemote.OnClientEvent:Connect(function(kind: string, textKey: string, params: any)
	local p = params or {}
	if p.value then
		p.value = Kit.fmtMoney(p.value)
	end
	showToast(T(textKey, p), kind)
end)
