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
	{ id = "spain", emoji = "🗺️", key = "nav_spain", color = Color3.fromRGB(236, 72, 153), dark = Color3.fromRGB(190, 40, 115) },
	{ id = "missions", emoji = "🎯", key = "nav_missions", color = C.gold, dark = C.goldDark },
	{ id = "shop", emoji = "🛒", key = "nav_shop", color = C.purple, dark = Color3.fromRGB(105, 60, 205) },
}

-- Siguiente objetivo sin reclamar (en el orden de la cadena)
function Hud.nextGoal(st: any): (any, number)
	for _, g in Config.Goals do
		if not st.goals[g.id] then
			return g, Hud.goalValue(st, g.stat)
		end
	end
	return nil, 0
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
	local moneyText = Kit.title(moneyHolder, "$0", 28, C.greenDark, { Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -56, 1, 0) })
	ctx.targets.money = moneyHolder

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
		Parent = parent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(220, 60),
	}, { Kit.list(true, 10, Enum.HorizontalAlignment.Right) })
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
		Size = UDim2.fromOffset(6 * 100 + 5 * 10, 92), Name = "Dock",
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
		local counts = { cargo = idle, fleet = repair, spain = regions, missions = claim, pilots = 0, shop = st.starterBought and 0 or 1 }
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
	end)
end

return Hud
