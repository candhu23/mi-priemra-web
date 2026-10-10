--[[
	HUD sobre el mapa: dinero, nivel y turbo arriba; botones redondos (premio diario, ranking,
	ajustes); tarjeta de objetivo; aviso de contrato exprés; barra inferior con 6 botones.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local Hud = {}

Hud.DOCK = {
	{ id = "fleet", emoji = "✈️", key = "nav_fleet", color = C.blue, dark = C.blueDark },
	{ id = "cargo", emoji = "📦", key = "nav_cargo", color = C.orange, dark = C.orangeDark },
	{ id = "pilots", emoji = "👨‍✈️", key = "nav_pilots", color = C.green, dark = C.greenDark },
	{ id = "contracts", emoji = "📜", key = "nav_contracts", color = Color3.fromRGB(20, 184, 166), dark = Color3.fromRGB(13, 132, 120) },
	{ id = "spain", emoji = "🗺️", key = "nav_spain", color = Color3.fromRGB(236, 72, 153), dark = Color3.fromRGB(190, 40, 115) },
	{ id = "missions", emoji = "🎯", key = "nav_missions", color = C.gold, dark = C.goldDark },
	{ id = "shop", emoji = "🛒", key = "nav_shop", color = C.purple, dark = Color3.fromRGB(105, 60, 205) },
}

-- Objetivo que se muestra: el primero que ya se puede reclamar o, si no, el siguiente de la cadena
function Hud.nextGoal(st: any): (any, number)
	local first, firstValue = nil, 0
	for _, g in Config.Goals do
		if not st.goals[g.id] then
			local v = Hud.goalValue(st, g.stat)
			if v >= g.target then
				return g, v
			end
			if not first then
				first, firstValue = g, v
			end
		end
	end
	return first, firstValue
end

function Hud.goalValue(st: any, stat: string): number
	if stat == "planes" then
		return #st.planes
	elseif stat == "pilots" then
		return #st.pilots
	elseif stat == "level" then
		return st.level
	elseif stat == "regions" then
		local n = 0
		for _ in st.regions do
			n += 1
		end
		return n
	elseif stat == "stamps" then
		return st.stamps or 0
	elseif stat == "ipo" then
		return st.ipoCount or 0
	end
	return st.stats[stat] or 0
end

function Hud.goalText(g: any): string
	local target = g.target
	if g.stat == "earned" then
		target = Kit.fmtMoney(target)
	end
	return T("goal_" .. g.stat, { n = target })
end

-- Cuántas cosas hay para reclamar (misiones, objetivos, premio diario)
function Hud.claimables(st: any): number
	local n = st.daily.available and 1 or 0
	for _, m in st.missions.list do
		if not m.claimed and m.progress >= m.target then
			n += 1
		end
	end
	for _, g in Config.Goals do
		if not st.goals[g.id] and Hud.goalValue(st, g.stat) >= g.target then
			n += 1
		end
	end
	return n
end

local function roundButton(parent: Instance, emoji: string, order: number, onClick: () -> ()): (TextButton, TextLabel)
	local holder = create("Frame", { Parent = parent, LayoutOrder = order, BackgroundColor3 = C.grey, Size = UDim2.fromOffset(56, 60), BorderSizePixel = 0 }, { corner() })
	local b = create("TextButton", {
		Parent = holder, BackgroundColor3 = C.white, Size = UDim2.fromOffset(56, 56), Text = emoji, TextSize = 28,
		FontFace = Kit.FONT_BODY, AutoButtonColor = false, BorderSizePixel = 0,
	}, { corner() })
	local dot = create("TextLabel", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = C.red, TextColor3 = C.white, Text = "!", FontFace = Kit.FONT_TITLE, TextSize = 13, Visible = false, ZIndex = 3,
	}, { corner(), Kit.stroke(C.white, 2) })
	b.Activated:Connect(function()
		Kit.playSound("click")
		onClick()
	end)
	return b, dot
end

function Hud.build(parent: Instance)
	-- Arriba a la izquierda: dinero, nivel y turbo
	local topLeft = create("Frame", { Parent = parent, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(0.6, 0, 0, 56) }, {
		Kit.list(true, 10, nil, Enum.VerticalAlignment.Center),
	})
	local moneyHolder = Kit.float(topLeft, { Size = UDim2.fromOffset(230, 54), LayoutOrder = 1 })
	Kit.emoji(moneyHolder, "💵", 26, { Position = UDim2.fromOffset(10, 11) })
	local moneyText = Kit.title(moneyHolder, "$0", 26, C.greenDark, { Position = UDim2.fromOffset(48, 2), Size = UDim2.new(1, -56, 0, 32) })
	local incomeText = Kit.label(moneyHolder, "", 13, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(48, 32), Size = UDim2.new(1, -56, 0, 16) })
	local moneyBump = create("UIScale", { Parent = moneyHolder.Parent })
	ctx.targets.money = moneyHolder
	-- Monedas que vuelan desde un aeropuerto hasta el contador de dinero
	function ctx.coinsFrom(from: GuiObject)
		if not from.Parent then
			return
		end
		local scale = ctx.scale or 1
		local origin = (parent :: GuiObject).AbsolutePosition
		local a = (from.AbsolutePosition + from.AbsoluteSize / 2 - origin) / scale
		local b = (moneyHolder.AbsolutePosition - origin) / scale + Vector2.new(24, 26)
		for i = 1, 4 do
			local coin = Kit.emoji(parent, "🪙", 22, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X + (i - 2.5) * 10, a.Y), ZIndex = 35,
			})
			task.delay(i * 0.06, function()
				if coin.Parent then
					Kit.tween(coin, 0.55, { Position = UDim2.fromOffset(b.X, b.Y) }, Enum.EasingStyle.Quad)
				end
			end)
			task.delay(0.65 + i * 0.06, function()
				coin:Destroy()
				Kit.playSound("coin")
				moneyBump.Scale = 1.08
				Kit.tween(moneyBump, 0.2, { Scale = 1 })
			end)
		end
	end

	local levelHolder = Kit.float(topLeft, { Size = UDim2.fromOffset(170, 54), LayoutOrder = 2 })
	Kit.emoji(levelHolder, "⭐", 24, { Position = UDim2.fromOffset(10, 6) })
	local levelText = Kit.title(levelHolder, "", 20, C.ink, { Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -56, 0, 26) })
	local levelFill = Kit.progress(levelHolder, { Position = UDim2.new(0, 46, 0, 34), Size = UDim2.new(1, -60, 0, 9) }, C.gold)

	local boostHolder = Kit.float(topLeft, { Size = UDim2.fromOffset(150, 54), LayoutOrder = 3 })
	boostHolder.BackgroundColor3 = C.gold
	local boostText = Kit.title(boostHolder, "", 20, C.ink, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local boostRoot = boostHolder.Parent :: Frame

	local multHolder = Kit.float(topLeft, { Size = UDim2.fromOffset(110, 54), LayoutOrder = 4 })
	local multText = Kit.title(multHolder, "", 18, C.purple, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local multRoot = multHolder.Parent :: Frame

	-- Arriba a la derecha: botones redondos
	local topRight = create("Frame", {
		Parent = parent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(300, 60),
	}, { Kit.list(true, 10, Enum.HorizontalAlignment.Right) })
	local ipoBtn, ipoDot = roundButton(topRight, "🏛️", 0, function()
		ctx.openPanel("ipo")
	end)
	local ipoRoot = ipoBtn.Parent :: Frame
	ctx.targets.ipo = ipoBtn
	local dailyBtn, dailyDot = roundButton(topRight, "🎁", 1, function()
		ctx.missionsTab = "daily"
		ctx.openPanel("missions")
	end)
	ctx.targets.daily = dailyBtn
	roundButton(topRight, "🏆", 2, function()
		ctx.openPanel("ranking")
	end)
	roundButton(topRight, "⚙️", 3, function()
		ctx.openPanel("settings")
	end)

	-- Barra inferior
	local dock = create("Frame", {
		Parent = parent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(#Hud.DOCK * 100 + (#Hud.DOCK - 1) * 10, 92), Name = "Dock",
	}, { Kit.list(true, 10, Enum.HorizontalAlignment.Center) })
	local badges = {}
	for i, d in Hud.DOCK do
		local holder = create("Frame", { Parent = dock, LayoutOrder = i, BackgroundColor3 = d.dark, Size = UDim2.fromOffset(100, 88), BorderSizePixel = 0 }, {
			corner(20),
		})
		local face = create("TextButton", {
			Parent = holder, BackgroundColor3 = d.color, Size = UDim2.new(1, 0, 1, -6), Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		}, { corner(20), Kit.stroke(C.white, 3) })
		Kit.emoji(face, d.emoji, 34, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4) })
		Kit.title(face, T(d.key), 16, C.white, {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -6, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6,
		})
		local badge = create("TextLabel", {
			Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = C.red, TextColor3 = C.white, FontFace = Kit.FONT_TITLE, TextSize = 15, Visible = false, ZIndex = 3,
		}, { corner(), Kit.stroke(C.white, 2) })
		face.Activated:Connect(function()
			Kit.playSound("click")
			face.Position = UDim2.fromOffset(0, 4)
			Kit.tween(face, 0.12, { Position = UDim2.fromOffset(0, 0) })
			ctx.openPanel(d.id)
		end)
		badges[d.id] = badge
		ctx.targets["dock_" .. d.id] = face
	end

	-- Evento de España (arriba a la derecha, bajo los botones redondos)
	local evBody = Kit.float(parent, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 76), Size = UDim2.fromOffset(330, 76), Name = "EventCard",
	})
	evBody.BackgroundColor3 = Color3.fromRGB(243, 237, 255)
	Kit.stroke(C.purple, 3).Parent = evBody
	local evRoot = evBody.Parent :: Frame
	local evEmoji = Kit.emoji(evBody, "", 32, { Position = UDim2.fromOffset(8, 12) })
	local evTitle = Kit.title(evBody, "", 17, C.purple, { Position = UDim2.fromOffset(52, 6), Size = UDim2.new(1, -60, 0, 22) })
	local evText = Kit.label(evBody, "", 14, C.ink, Kit.FONT_BOLD, {
		Position = UDim2.fromOffset(52, 30), Size = UDim2.new(1, -60, 0, 38), TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	evRoot.Visible = false
	local nextEvent = Kit.pill(parent, "", C.purple, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 80), Size = UDim2.fromOffset(0, 26), TextSize = 14, Visible = false,
	})

	-- Contratos en marcha (arriba a la izquierda, bajo el dinero)
	local contractsBox = create("Frame", {
		Parent = parent, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 74), Size = UDim2.fromOffset(330, 120), Name = "ActiveContracts",
	}, { Kit.list(false, 6) })
	local contractRows: { [number]: any } = {}

	-- «Aviones esperando»: acceso rápido a CARGAS con el siguiente avión libre
	local waiting = Kit.button(parent, "", "orange", UDim2.fromOffset(270, 52), function()
		for _, p in ctx.state.planes do
			if not p.flight and p.condition >= Config.REPAIR_BLOCK then
				ctx.selectPlane = p.id
				break
			end
		end
		ctx.openPanel("cargo")
	end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -112), Name = "Waiting" })
	local waitingRoot = waiting.Parent :: Frame
	waiting.TextSize = 19
	ctx.targets.waiting = waiting

	-- Tarjeta de objetivo (abajo a la izquierda, encima de la barra)
	local goalBody = Kit.float(parent, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -112), Size = UDim2.fromOffset(330, 82), Name = "GoalCard",
	})
	local goalRoot = goalBody.Parent :: Frame
	Kit.emoji(goalBody, "🎯", 28, { Position = UDim2.fromOffset(10, 10) })
	Kit.title(goalBody, T("goal_title"), 13, C.muted, { Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -60, 0, 16) })
	local goalText = Kit.label(goalBody, "", 17, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(52, 24), Size = UDim2.new(1, -130, 0, 22) })
	local goalFill = Kit.progress(goalBody, { Position = UDim2.new(0, 52, 0, 56), Size = UDim2.new(1, -130, 0, 12) }, C.green)
	local goalClaim = Kit.button(goalBody, "🎁", "green", UDim2.fromOffset(64, 44), function()
		local g = Hud.nextGoal(ctx.state)
		if g then
			ctx.act("claimGoal", g.id)
		end
	end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -6) })
	ctx.targets.goal_claim = goalClaim

	-- Aviso de contrato exprés (abajo a la derecha)
	local exBody = Kit.float(parent, {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -112), Size = UDim2.fromOffset(330, 82), Name = "ExpressCard",
	})
	exBody.BackgroundColor3 = Color3.fromRGB(255, 244, 204)
	Kit.stroke(C.gold, 3).Parent = exBody
	local exRoot = exBody.Parent :: Frame
	Kit.title(exBody, "⚡ " .. T("express_title", { mult = Config.Express.mult }), 18, C.goldDark, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -120, 0, 24) })
	local exRoute = Kit.label(exBody, "", 16, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -120, 0, 20) })
	local exTime = Kit.label(exBody, "", 14, C.muted, nil, { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -120, 0, 18) })
	Kit.button(exBody, T("btn_go"), "gold", UDim2.fromOffset(96, 48), function()
		local st = ctx.state
		if st.express then
			for _, p in st.planes do
				if not p.flight and p.airport == st.express.code then
					ctx.selectPlane = p.id
				end
			end
			ctx.openPanel("cargo")
		end
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) })

	local shownMoney = 0
	local function refresh()
		local st = ctx.state
		if not st then
			return
		end
		local base, nextXp = Config.xpForLevel(st.level), Config.xpForLevel(st.level + 1)
		levelText.Text = T("top_level", { level = st.level })
		levelFill.Size = UDim2.fromScale(math.clamp((st.xp - base) / math.max(1, nextXp - base), 0, 1), 1)
		boostRoot.Visible = st.boostLeft > 0
		boostText.Text = "⚡ x2  " .. Kit.fmtTime(st.boostLeft)
		multRoot.Visible = st.moneyMult > 1 and st.boostLeft <= 0
		multText.Text = "💰 x" .. string.format("%.1f", st.moneyMult)
		incomeText.Text = (st.incomePerMin or 0) > 0 and ("📈 " .. T("per_min", { amount = Kit.fmtMoney(st.incomePerMin) })) or ""
		-- Bolsa: se ve cuando se acerca (o si ya saliste alguna vez)
		ipoRoot.Visible = st.level >= Config.IPO_LEVEL - 4 or (st.ipoCount or 0) > 0
		ipoDot.Visible = st.level >= Config.IPO_LEVEL and (st.newShares or 0) >= Config.IPO_MIN_SHARES
		-- Evento
		local ev = st.event and Config.EventById[st.event]
		evRoot.Visible = ev ~= nil and st.tutorial == 99
		nextEvent.Visible = ev == nil and st.tutorial == 99
		if ev then
			evEmoji.Text = ev.emoji
			evTitle.Text = T("ev_" .. ev.id) .. " · " .. Kit.fmtTime(st.eventLeft or 0)
			evText.Text = T("ev_" .. ev.id .. "_d", { mult = Kit.modText({ kind = "event", icon = "", mult = ev.pay }) })
		else
			nextEvent.Text = "🎉 " .. T("event_next", { time = Kit.fmtTime(st.eventLeft or 0) })
		end
		-- Contratos en marcha
		local active = st.contracts and st.contracts.active or {}
		local seenRows = {}
		for i, c in active do
			seenRows[c.id] = true
			local row = contractRows[c.id]
			if not row then
				local body = Kit.float(contractsBox, { Size = UDim2.fromOffset(330, 46), LayoutOrder = i })
				local face = create("TextButton", { Parent = body, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "" })
				face.Activated:Connect(function()
					Kit.playSound("click")
					ctx.openPanel("contracts")
				end)
				local label = Kit.label(body, "", 15, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -90, 0, 22) })
				local time = Kit.label(body, "", 14, C.muted, Kit.FONT_BOLD, {
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 3), Size = UDim2.fromOffset(80, 22), TextXAlignment = Enum.TextXAlignment.Right,
				})
				local fill = Kit.progress(body, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 8) }, Color3.fromRGB(20, 184, 166))
				row = { root = body.Parent, label = label, time = time, fill = fill }
				contractRows[c.id] = row
			end
			row.root.LayoutOrder = i
			local g = Config.GoodById[c.good]
			row.label.Text = "📜 " .. g.emoji .. " → " .. T("r_" .. c.region) .. "  " .. c.progress .. "/" .. c.count
			row.time.Text = "⏱️ " .. Kit.fmtTime(c.expires - Kit.serverNow())
			row.fill.Size = UDim2.fromScale(math.clamp(c.progress / c.count, 0, 1), 1)
		end
		for id, row in contractRows do
			if not seenRows[id] then
				row.root:Destroy()
				contractRows[id] = nil
			end
		end
		-- Aviones esperando (solo si no vuelan solos)
		local ready = 0
		for _, p in st.planes do
			if not p.flight and p.condition >= Config.REPAIR_BLOCK then
				ready += 1
			end
		end
		waitingRoot.Visible = ready > 0 and not (st.settings.auto and st.autoUnlocked) and st.tutorial == 99 and ctx.panel == nil
		-- Si está el aviso de exprés (mismo rincón), el botón va encima
		waitingRoot.Position = UDim2.new(1, -16, 1, st.express and -204 or -112)
		waiting.Text = "🛫 " .. T(ready == 1 and "waiting_one" or "waiting_many", { n = ready })
		-- Insignias de la barra
		local idle, repair, regions = 0, 0, 0
		for _, p in st.planes do
			if not p.flight then
				idle += 1
			end
			if p.condition < Config.REPAIR_BLOCK and not p.flight then
				repair += 1
			end
		end
		for _, r in Config.Regions do
			if not st.regions[r.id] and st.level >= r.level and st.money >= r.cost then
				regions += 1
			end
		end
		local claim = Hud.claimables(st)
		-- La «!» de la tienda solo si el pack de inicio existe de verdad (o en Studio, como muestra)
		local starter = 0
		for _, item in Config.Products do
			if item.key == "starter" and (item.id ~= 0 or game:GetService("RunService"):IsStudio()) and not st.starterBought then
				starter = 1
			end
		end
		local offers = 0
		if st.contracts and st.level >= Config.CONTRACT_LEVEL and #st.contracts.active < st.contracts.slots then
			offers = #st.contracts.offers
		end
		local counts = { cargo = idle, fleet = repair, spain = regions, missions = claim, pilots = 0, shop = starter, contracts = offers }
		for id, b in badges do
			local n = counts[id] or 0
			b.Visible = n > 0
			b.Text = id == "shop" and "!" or tostring(n)
		end
		dailyDot.Visible = st.daily.available
		-- Objetivo
		local g, value = Hud.nextGoal(st)
		goalRoot.Visible = g ~= nil and st.tutorial >= 5
		if g then
			goalText.Text = Hud.goalText(g)
			goalFill.Size = UDim2.fromScale(math.clamp(value / g.target, 0, 1), 1)
			Kit.setButton(goalClaim, nil, value >= g.target)
		end
		-- Exprés
		local ex = st.express
		exRoot.Visible = ex ~= nil
		if ex then
			local a, b = Config.AirportByCode[ex.code], Config.AirportByCode[ex.to]
			exRoute.Text = Config.GoodById[ex.good].emoji .. " " .. a.city .. " → " .. b.city
			exTime.Text = "⏱️ " .. Kit.fmtTime(ex.expires - Kit.serverNow())
		end
	end
	table.insert(ctx.refreshers, refresh)

	-- El dinero sube contando (más vistoso que saltar de golpe)
	table.insert(ctx.tickers, function()
		local st = ctx.state
		if not st then
			return
		end
		if math.abs(st.money - shownMoney) < 1 then
			shownMoney = st.money
		else
			shownMoney += (st.money - shownMoney) * 0.35
		end
		moneyText.Text = Kit.fmtMoney(math.floor(shownMoney + 0.5))
		if st.express then
			exTime.Text = "⏱️ " .. Kit.fmtTime(st.express.expires - Kit.serverNow())
		end
		for _, c in st.contracts and st.contracts.active or {} do
			local row = contractRows[c.id]
			if row then
				row.time.Text = "⏱️ " .. Kit.fmtTime(c.expires - Kit.serverNow())
			end
		end
	end)
end

return Hud
