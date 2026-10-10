--[[
	Capas superiores: ventanas (paneles) sobre el mapa, modal, avisos, pantalla de título,
	bienvenida de vuelta, subida de nivel con confeti, celebraciones y tutorial con flecha.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local PlaneArt = require(script.Parent:WaitForChild("PlaneArt"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local Screens = {}

local PANELS = {
	fleet = { emoji = "✈️", key = "nav_fleet", color = C.blue },
	cargo = { emoji = "📦", key = "nav_cargo", color = C.orange },
	pilots = { emoji = "👨‍✈️", key = "nav_pilots", color = C.green },
	contracts = { emoji = "📜", key = "nav_contracts", color = Color3.fromRGB(13, 148, 136) },
	ipo = { emoji = "🏛️", key = "nav_ipo", color = Color3.fromRGB(30, 64, 120) },
	spain = { emoji = "🗺️", key = "nav_spain", color = Color3.fromRGB(236, 72, 153) },
	missions = { emoji = "🎯", key = "nav_missions", color = C.goldDark },
	shop = { emoji = "🛒", key = "nav_shop", color = C.purple },
	ranking = { emoji = "🏆", key = "nav_ranking", color = C.goldDark },
	settings = { emoji = "⚙️", key = "nav_settings", color = C.greyDark },
}

---------------------------------------------------------------------
-- Ventanas sobre el mapa
---------------------------------------------------------------------
function Screens.buildPanels(parent: Instance, builders: { [string]: (Frame) -> () -> () })
	local dim = create("TextButton", {
		Parent = parent, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1),
		Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20,
	})
	local windows: { [string]: Frame } = {}
	local renders: { [string]: () -> () } = {}
	for id, info in PANELS do
		local win = create("Frame", {
			Parent = dim, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -60, 1, -36),
			BackgroundColor3 = C.panel, Visible = false, ZIndex = 21, Name = id, Active = true,
		}, { corner(26), create("UISizeConstraint", { MaxSize = Vector2.new(1180, math.huge) }) })
		local head = create("Frame", { Parent = win, BackgroundColor3 = info.color, Size = UDim2.new(1, 0, 0, 68), BorderSizePixel = 0, ZIndex = 21 }, {
			corner(26),
		})
		create("Frame", { Parent = head, BackgroundColor3 = info.color, Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26), BorderSizePixel = 0, ZIndex = 21 })
		Kit.emoji(head, info.emoji, 32, { Position = UDim2.fromOffset(20, 12), ZIndex = 22 })
		Kit.title(head, T(info.key), 30, C.white, { Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -140, 1, 0), ZIndex = 22, TextStrokeTransparency = 0.7 })
		local close = create("TextButton", {
			Parent = head, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = C.white, Text = "✕", TextColor3 = C.ink, FontFace = Kit.FONT_TITLE, TextSize = 24, AutoButtonColor = false, ZIndex = 22,
		}, { corner() })
		close.Activated:Connect(function()
			Kit.playSound("click")
			ctx.closePanel()
		end)
		local content = create("Frame", {
			Parent = win, BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 1, -94), ZIndex = 21, Name = "Content",
		})
		windows[id] = win
		renders[id] = builders[id](content)
	end
	dim.Activated:Connect(function()
		ctx.closePanel()
	end)

	function ctx.openPanel(id: string)
		for pid, w in windows do
			w.Visible = pid == id
		end
		dim.Visible = true
		ctx.panel = id
		local win = windows[id]
		win.Position = UDim2.new(0.5, 0, 0.5, 30)
		Kit.tween(win, 0.2, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
		if id == "missions" and ctx.missionsTab and ctx.missionsTabSet then
			ctx.missionsTabSet(ctx.missionsTab)
			ctx.missionsTab = nil
		end
		ctx.refreshPanel()
	end
	function ctx.closePanel()
		dim.Visible = false
		ctx.panel = nil
		ctx.refreshAll()
	end
	function ctx.refreshPanel()
		local id = ctx.panel
		if id and renders[id] then
			renders[id]()
		end
		if ctx.tutorialRefresh then
			ctx.tutorialRefresh()
		end
	end
end

---------------------------------------------------------------------
-- Modal y avisos
---------------------------------------------------------------------
local KIND = {
	success = { C.green, "✅" }, money = { C.green, "💰" }, error = { C.red, "⚠️" }, info = { C.blue, "💬" },
	goal = { C.goldDark, "🎯" }, express = { C.gold, "⚡" }, feed = { C.purple, "📣" }, level = { C.orange, "⭐" },
	event = { C.purple, "🎉" },
}

function Screens.buildOverlay(parent: Instance)
	local toastHolder = create("Frame", {
		Parent = parent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(520, 400), ZIndex = 40,
	}, { Kit.list(false, 8, Enum.HorizontalAlignment.Center) })
	function ctx.toast(text: string, kind: string)
		local style = KIND[kind] or KIND.info
		local t = create("Frame", {
			Parent = toastHolder, BackgroundColor3 = C.white, Size = UDim2.fromOffset(0, 48), AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = -math.floor(os.clock() * 100), ZIndex = 40,
		}, { corner(), Kit.stroke(style[1], 3), Kit.padding(16, 18, 0, 0), Kit.list(true, 10, nil, Enum.VerticalAlignment.Center) })
		Kit.emoji(t, style[2], 22, { ZIndex = 40, LayoutOrder = 1 })
		Kit.title(t, text, 18, C.ink, { ZIndex = 40, LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), TextTruncate = Enum.TextTruncate.None })
		if kind == "error" then
			Kit.playSound("error")
		elseif kind == "money" then
			Kit.playSound("money")
		elseif kind == "express" or kind == "event" then
			Kit.playSound("express")
		end
		local kids = toastHolder:GetChildren()
		if #kids > 5 then
			local oldest, order = nil, -math.huge
			for _, k in kids do
				if k:IsA("Frame") and k.LayoutOrder > order then
					oldest, order = k, k.LayoutOrder
				end
			end
			if oldest then
				oldest:Destroy()
			end
		end
		task.delay(3.5, function()
			if t.Parent then
				t:Destroy()
			end
		end)
	end

	local modalDim = create("Frame", {
		Parent = parent, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50, Active = true,
	})
	local modal = create("Frame", {
		Parent = modalDim, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel, ZIndex = 51,
	}, { corner(26), Kit.padding(26), Kit.list(false, 16) })
	local modalTitle = Kit.title(modal, "", 30, C.ink, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 38), ZIndex = 51, TextWrapped = true })
	local modalBody = create("Frame", { Parent = modal, BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 51 })
	local modalButtons = create("Frame", { Parent = modal, BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 56), ZIndex = 51 }, {
		Kit.list(true, 12, Enum.HorizontalAlignment.Right),
	})
	function ctx.closeModal()
		modalDim.Visible = false
	end
	function ctx.openModal(title: string, fill: (Frame) -> (), buttons: { { text: string, style: string, onClick: (() -> ())? } }?)
		modalTitle.Text = title
		for _, k in modalBody:GetChildren() do
			k:Destroy()
		end
		for _, k in modalButtons:GetChildren() do
			if k:IsA("Frame") then
				k:Destroy()
			end
		end
		fill(modalBody)
		local list: { { text: string, style: string, onClick: (() -> ())? } } = buttons or { { text = T("btn_ok"), style = "orange" } }
		for i, b in list do
			Kit.button(modalButtons, b.text, b.style, UDim2.fromOffset(210, 54), function()
				ctx.closeModal()
				if b.onClick then
					b.onClick()
				end
			end, { LayoutOrder = i })
		end
		modalDim.Visible = true
		modal.Position = UDim2.new(0.5, 0, 0.5, 30)
		Kit.tween(modal, 0.22, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	end

	-- Confeti para las celebraciones
	local confettiLayer = create("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 })
	function ctx.confetti()
		local colors = { C.orange, C.gold, C.blue, C.green, C.purple, C.red }
		for i = 1, 40 do
			local x = math.random()
			local piece = create("Frame", {
				Parent = confettiLayer, Position = UDim2.new(x, 0, 0, -20), Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
				BackgroundColor3 = colors[i % #colors + 1], Rotation = math.random(0, 90), BorderSizePixel = 0, ZIndex = 60,
			}, { corner(3) })
			local t = 1.4 + math.random() * 1.2
			Kit.tween(piece, t, { Position = UDim2.new(x + (math.random() - 0.5) * 0.2, 0, 1, 20), Rotation = math.random(180, 540) }, Enum.EasingStyle.Sine)
			task.delay(t + 0.1, function()
				piece:Destroy()
			end)
		end
	end
end

---------------------------------------------------------------------
-- Celebraciones y ventanas especiales
---------------------------------------------------------------------
function Screens.levelUp(level: number)
	local unlocks = {}
	for _, m in Config.Planes do
		if m.level == level then
			table.insert(unlocks, m.emoji .. " " .. Kit.planeName(m.id))
		end
	end
	for _, r in Config.Regions do
		if r.level == level then
			table.insert(unlocks, "🗺️ " .. T("r_" .. r.id))
		end
	end
	for _, u in Config.Upgrades do
		if u.level == level then
			table.insert(unlocks, u.emoji .. " " .. T("up_" .. u.id))
		end
	end
	if level == Config.AUTO_DISPATCH_LEVEL then
		table.insert(unlocks, "🤖 " .. T("auto_title"))
	end
	if level == Config.CHARTER_LEVEL then
		table.insert(unlocks, "🌙 " .. T("charter_title"))
	end
	if level == Config.CONTRACT_LEVEL then
		table.insert(unlocks, "📜 " .. T("nav_contracts"))
	end
	if level == Config.IPO_LEVEL then
		table.insert(unlocks, "🏛️ " .. T("nav_ipo"))
	end
	ctx.confetti()
	Kit.playSound("level")
	-- Sin novedades: solo un aviso (no interrumpe con una ventana)
	if #unlocks == 0 then
		ctx.toast("⭐ " .. T("level_up_title", { level = level }), "level")
		return
	end
	ctx.openModal("⭐ " .. T("level_up_title", { level = level }), function(body)
		Kit.list(false, 6).Parent = body
		Kit.label(body, #unlocks > 0 and T("level_up_unlocks") or T("level_up_keep"), 18, C.muted, nil, { LayoutOrder = 0, TextWrapped = true })
		for i, u in unlocks do
			Kit.title(body, u, 22, C.ink, { LayoutOrder = i })
		end
	end, { { text = T("btn_great"), style = "orange" } })
end

function ctx.celebratePilot(pilot: any)
	local PilotsPanel = require(script.Parent:WaitForChild("PilotsPanel")) :: any
	if pilot.stars >= 4 then
		ctx.confetti()
	end
	ctx.openModal("🤝 " .. T("hired_title"), function(body)
		local holder = create("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 110) })
		PilotsPanel.avatar(holder, pilot, 100)
		Kit.title(holder, pilot.name, 26, C.ink, { Position = UDim2.fromOffset(116, 10), Size = UDim2.new(1, -116, 0, 32) })
		Kit.label(holder, Kit.stars(pilot.stars), 28, C.goldDark, Kit.FONT_BOLD, { Position = UDim2.fromOffset(116, 40), Size = UDim2.new(1, -116, 0, 32), RichText = true })
		Kit.label(holder, Kit.traitName(pilot.trait) .. " · " .. T("trait_" .. tostring(pilot.trait) .. "_d"), 16, C.muted, Kit.FONT_BOLD, {
			Position = UDim2.fromOffset(116, 74), Size = UDim2.new(1, -116, 0, 22),
		})
	end, { { text = T("btn_great"), style = "green" } })
end

function ctx.celebrateIpo(extra: any)
	ctx.confetti()
	Kit.playSound("level")
	local perk = Config.IpoPerks[extra.count]
	ctx.openModal("🔔 " .. T("ipo_done_title"), function(body)
		Kit.list(false, 8).Parent = body
		Kit.title(body, T("ipo_done", {
			n = extra.ipo, total = extra.total, p = math.floor(extra.total * Config.SHARE_BONUS * 100 + 0.5),
			x = math.floor(extra.total * Config.SHARE_XP_BONUS * 100 + 0.5),
		}), 22, C.ink, {
			LayoutOrder = 1, TextWrapped = true, Size = UDim2.new(1, 0, 0, 60),
		})
		if perk then
			Kit.title(body, "🎁 " .. T("perk_" .. perk), 20, C.greenDark, { LayoutOrder = 2, TextWrapped = true, Size = UDim2.new(1, 0, 0, 52) })
		end
	end, { { text = T("btn_great"), style = "green" } })
end

function ctx.celebrateRegion(regionId: string)
	ctx.confetti()
	Kit.playSound("level")
	ctx.toast(T("n_region", { region = T("r_" .. regionId) }), "success")
end

function Screens.welcomeBack(params: any)
	local ShopPanel = require(script.Parent:WaitForChild("ShopPanel")) :: any
	local product = ShopPanel.findProduct("offline2x")
	local buttons = { { text = T("btn_collect"), style = "green" } }
	if params.offline > 0 and product and (product.id ~= 0 or game:GetService("RunService"):IsStudio()) then
		table.insert(buttons, 1, { text = "x2 · R$ " .. product.price, style = "gold", onClick = function()
			ShopPanel.buy(product, false)
		end })
	end
	ctx.openModal("🌙 " .. T("welcome_back"), function(body)
		Kit.list(false, 8).Parent = body
		if params.landed > 0 then
			Kit.title(body, T("welcome_landed", { n = params.landed, net = Kit.fmtMoney(params.net) }), 22, C.ink, { LayoutOrder = 1, TextWrapped = true, Size = UDim2.new(1, 0, 0, 56) })
		end
		if params.offline > 0 then
			Kit.title(body, T("welcome_offline", { amount = Kit.fmtMoney(params.offline) }), 22, C.greenDark, { LayoutOrder = 2, TextWrapped = true, Size = UDim2.new(1, 0, 0, 56) })
		end
	end, buttons)
end

---------------------------------------------------------------------
-- Aterrizaje perfecto: cuando vuelas TÚ, en los últimos segundos sale una aguja.
-- Pulsa ATERRIZA con la aguja en verde (+25 %) o en amarillo (+10 %). Un intento por vuelo.
---------------------------------------------------------------------
local landingConn: RBXScriptConnection? = nil
function Screens.landing(parent: Instance)
	local RunService = game:GetService("RunService")
	local body = Kit.float(parent, {
		-- A la izquierda (sobre el mar): no tapa el aeropuerto donde aterrizas ni la tarjeta de objetivo
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 6), Size = UDim2.fromOffset(400, 104), Name = "Landing", ZIndex = 45,
	})
	local holder = body.Parent :: Frame
	for _, d in holder:GetChildren() do
		(d :: GuiObject).ZIndex = 45
	end
	Kit.stroke(C.green, 3).Parent = body
	local title = Kit.title(body, "", 17, C.ink, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -160, 0, 24), ZIndex = 46 })
	local bar = create("Frame", {
		Parent = body, BackgroundColor3 = C.line, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -160, 0, 26), ZIndex = 46,
	}, { corner(8) })
	create("Frame", { Parent = bar, BackgroundColor3 = C.gold, Position = UDim2.fromScale(0.25, 0), Size = UDim2.fromScale(0.5, 1), ZIndex = 46, BorderSizePixel = 0 })
	create("Frame", { Parent = bar, BackgroundColor3 = C.green, Position = UDim2.fromScale(0.4, 0), Size = UDim2.fromScale(0.2, 1), ZIndex = 46, BorderSizePixel = 0 })
	local needle = create("Frame", {
		Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.ink, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 6, 1, 12), ZIndex = 47,
	}, { corner(3) })
	local hint = Kit.label(body, T("landing_hint"), 13, C.muted, Kit.FONT_BOLD, {
		Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -160, 0, 28), ZIndex = 46, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
	})
	local active: number? = nil
	local tried: { [number]: boolean } = {}
	local phase = 0
	local btn = Kit.button(body, "🛬\n" .. T("btn_land"), "green", UDim2.fromOffset(134, 84), function()
		local id = active
		if not id or tried[id] then
			return
		end
		tried[id] = true
		local x = 0.5 + 0.5 * math.sin(phase)
		local off = math.abs(x - 0.5)
		local quality = if off <= 0.1 then "perfect" elseif off <= 0.25 then "good" else nil
		if quality then
			ctx.act("land", id, quality)
			Kit.playSound(quality == "perfect" and "perfect" or "money")
			hint.Text = quality == "perfect" and ("🎯 " .. T("landing_perfect") .. " +25%") or ("👍 " .. T("landing_good") .. " +10%")
		else
			Kit.playSound("error")
			hint.Text = "😅 " .. T("landing_miss")
		end
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), ZIndex = 46 })
	btn.ZIndex = 47
	btn.TextSize = 17
	btn.TextWrapped = true
	ctx.targets.land = btn
	holder.Visible = false
	-- Al reconstruir la interfaz (cambio de idioma) se desconecta la aguja anterior
	if landingConn then
		landingConn:Disconnect()
	end
	landingConn = RunService.RenderStepped:Connect(function(dt: number)
		if holder.Visible then
			phase += dt * 3.6
			needle.Position = UDim2.fromScale(0.5 + 0.5 * math.sin(phase), 0.5)
		end
	end)
	table.insert(ctx.tickers, function()
		local st = ctx.state
		if not st or not ctx.started then
			holder.Visible = false
			return
		end
		local now = Kit.serverNow()
		local pick, left = nil, math.huge
		for _, p in st.planes do
			local f = p.flight
			if f and f.pilot == 0 and f.good ~= "ferry" and f.good ~= "charter" and f.endT - f.startT >= Config.LANDING.minSecs then
				local rest = f.endT - now
				-- Se queda visible un momento tras pulsar para ver el resultado
				if rest > 0 and rest <= Config.LANDING.window + 0.5 and rest < left and (not f.landing or tried[p.id]) then
					pick, left = p, rest
				end
			end
		end
		local was = active
		active = pick and pick.id or nil
		if active and active ~= was and not tried[active] then
			hint.Text = T("landing_hint")
		end
		holder.Visible = active ~= nil
		if pick then
			title.Text = "🛬 " .. T("landing_title", { city = Config.AirportByCode[pick.flight.to].city })
			Kit.setButton(btn, nil, not tried[pick.id] and left > 0.6)
		end
	end)
end

---------------------------------------------------------------------
-- Pantalla de título
---------------------------------------------------------------------
function Screens.title(parent: Instance, onPlay: () -> ())
	local screen = create("Frame", { Parent = parent, BackgroundColor3 = C.sea, Size = UDim2.fromScale(1, 1), ZIndex = 70, Active = true }, {
		create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150, 216, 248), Color3.fromRGB(84, 168, 226)), Rotation = 90 }),
	})
	-- Nubes
	for i = 1, 6 do
		local cloud = create("Frame", {
			Parent = screen, BackgroundColor3 = C.white, BackgroundTransparency = 0.25, Position = UDim2.fromScale((i - 1) / 6, 0.08 + (i % 3) * 0.12),
			Size = UDim2.fromOffset(140 + i * 12, 46), ZIndex = 70,
		}, { corner() })
		Kit.tween(cloud, 14 + i * 3, { Position = UDim2.fromScale((i - 1) / 6 + 0.25, 0.08 + (i % 3) * 0.12) }, Enum.EasingStyle.Linear)
	end
	local planeBox = create("Frame", {
		Parent = screen, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(460, 230), BackgroundTransparency = 1, ZIndex = 71,
	})
	PlaneArt.side(planeBox, "condor")
	for _, d in planeBox:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 71
		end
	end
	Kit.tween(planeBox, 1.6, { Position = UDim2.fromScale(0.5, 0.33) }, Enum.EasingStyle.Sine)
	Kit.title(screen, "AeroCarga", 92, C.white, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(900, 100),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, TextStrokeColor3 = C.orangeDark, ZIndex = 72,
	})
	local ribbon = create("Frame", {
		Parent = screen, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(300, 46),
		BackgroundColor3 = Color3.fromRGB(198, 11, 30), ZIndex = 72,
	}, { corner(12) })
	create("Frame", { Parent = ribbon, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 196, 0), BorderSizePixel = 0, ZIndex = 72 })
	Kit.title(ribbon, T("title_sub"), 26, C.white, {
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(150, 10, 20), ZIndex = 73,
	})
	local play = Kit.button(screen, "▶  " .. T("btn_play"), "green", UDim2.fromOffset(300, 78), function()
		Kit.tween(screen, 0.35, { BackgroundTransparency = 1 })
		for _, d in screen:GetDescendants() do
			if d:IsA("GuiObject") then
				d.Visible = false
			end
		end
		task.delay(0.35, function()
			screen:Destroy()
		end)
		onPlay()
	end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), ZIndex = 72 })
	play.TextSize = 34
	play.ZIndex = 73
	ctx.targets.play = play
	return screen
end

---------------------------------------------------------------------
-- Tutorial: bocadillo de la capitana + flecha que señala el botón
---------------------------------------------------------------------
function Screens.tutorial(parent: Instance, root: Frame)
	local bubbleBody = Kit.float(parent, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Size = UDim2.fromOffset(560, 96), ZIndex = 30, Name = "Coach",
	})
	local bubble = bubbleBody.Parent :: Frame
	for _, d in bubble:GetChildren() do
		(d :: GuiObject).ZIndex = 30
	end
	Kit.stroke(C.orange, 3).Parent = bubbleBody
	Kit.emoji(bubbleBody, "👩‍✈️", 44, { Position = UDim2.fromOffset(10, 20), ZIndex = 31 })
	local text = Kit.label(bubbleBody, "", 18, C.ink, Kit.FONT_BOLD, {
		Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -190, 1, -16), TextWrapped = true, ZIndex = 31, TextTruncate = Enum.TextTruncate.None,
	})
	local skip = create("TextButton", {
		Parent = bubbleBody, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(100, 30),
		BackgroundColor3 = C.soft, Text = T("btn_skip"), TextColor3 = C.muted, FontFace = Kit.FONT_BOLD, TextSize = 14, ZIndex = 31, AutoButtonColor = false,
	}, { corner() })
	skip.Activated:Connect(function()
		ctx.act("tutorial", "skip")
	end)
	local arrow = Kit.emoji(parent, "👇", 44, { AnchorPoint = Vector2.new(0.5, 1), ZIndex = 80, Visible = false })

	-- Qué señalar en cada paso según la ventana abierta
	local function target(step: number): (string?, string)
		local panel = ctx.panel
		if step == 1 then
			if panel == "cargo" then
				return "fly_first", "tut_fly"
			end
			return "dock_cargo", "tut_open_cargo"
		elseif step == 2 then
			return nil, "tut_wait"
		elseif step == 3 then
			if panel == "fleet" then
				return "buy_sparrow", "tut_buy"
			end
			return "dock_fleet", "tut_open_fleet"
		elseif step == 4 then
			if panel == "pilots" then
				return "hire_first", "tut_hire"
			end
			return "dock_pilots", "tut_open_pilots"
		elseif step == 5 then
			if panel then
				return nil, "tut_close"
			end
			return "goal_claim", "tut_goal"
		end
		return nil, ""
	end

	local bob = 0
	function ctx.tutorialRefresh()
		local st = ctx.state
		local step = st and st.tutorial or 99
		local active = st ~= nil and step >= 1 and step <= 5 and ctx.started
		bubble.Visible = active
		if not active then
			arrow.Visible = false
			return
		end
		-- Abre la pestaña que hace falta
		if step == 3 and ctx.panel == "fleet" and ctx.fleetTab then
			ctx.fleetTab("buy")
		elseif step == 4 and ctx.panel == "pilots" and ctx.pilotsTab then
			ctx.pilotsTab("hire")
		end
		local name, key = target(step)
		text.Text = T(key)
		-- Con una ventana abierta el bocadillo va abajo a la izquierda (zona libre de la ventana)
		bubble.Position = ctx.panel and UDim2.new(0, 60, 1, -34) or UDim2.new(0.5, 0, 1, -112)
		bubble.AnchorPoint = ctx.panel and Vector2.new(0, 1) or Vector2.new(0.5, 1)
		bubble.Size = ctx.panel and UDim2.fromOffset(440, 110) or UDim2.fromOffset(560, 96)
		local t = name and ctx.targets[name]
		if t and t.Parent and t.AbsoluteSize.X > 0 then
			local scale = ctx.scale or 1
			local pos = (t.AbsolutePosition - root.AbsolutePosition) / scale
			local size = t.AbsoluteSize / scale
			arrow.Visible = true
			arrow.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 4 - math.abs(math.sin(bob)) * 12)
		else
			arrow.Visible = false
		end
	end
	table.insert(ctx.tickers, function()
		bob += 0.6
		ctx.tutorialRefresh()
	end)
end

-- Inicio del tutorial (paso 0 → 1) con una ventana de bienvenida
function Screens.tutorialWelcome()
	ctx.openModal("👋 " .. T("tut_welcome_title"), function(body)
		Kit.label(body, T("tut_welcome"), 19, C.ink, Kit.FONT_BOLD, { TextWrapped = true, Size = UDim2.new(1, 0, 0, 90), TextYAlignment = Enum.TextYAlignment.Top })
	end, {
		{ text = T("btn_skip"), style = "white", onClick = function()
			ctx.act("tutorial", "skip")
		end },
		{ text = T("btn_start"), style = "green", onClick = function()
			ctx.act("tutorial", "start")
		end },
	})
end

return Screens
