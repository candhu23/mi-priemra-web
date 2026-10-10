--[[
	Ventana COMBUSTIBLE: los aviones gastan el combustible de tu depósito, así que hay que comprarlo.
	El precio cambia cada 2 minutos (gráfica de los últimos precios): conviene llenar cuando está barato.
	El despachador de nivel 2 compra solo cuando queda poco.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local FuelPanel = {}

function FuelPanel.build(content: Frame): () -> ()
	local area = Kit.scroll(content)
	Kit.list(false, 12).Parent = area

	-- Depósito
	local tank = Kit.card(area, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 132) })
	Kit.padding(16).Parent = tank
	Kit.emoji(tank, "🛢️", 46, { Position = UDim2.fromOffset(0, 8) })
	local tankText = Kit.title(tank, "", 28, C.ink, { Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -330, 0, 34) })
	local tankFill = Kit.progress(tank, { Position = UDim2.fromOffset(66, 42), Size = UDim2.new(1, -330, 0, 22) }, C.blue)
	local tankNote = Kit.label(tank, "", 15, C.muted, nil, { Position = UDim2.fromOffset(66, 72), Size = UDim2.new(1, -330, 0, 28), TextWrapped = true })
	local upgradeBtn = Kit.button(tank, "", "orange", UDim2.fromOffset(250, 60), function()
		ctx.act("buyUpgrade", "tank")
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
	upgradeBtn.TextSize = 16
	upgradeBtn.TextWrapped = true

	-- Precio y gráfica
	local price = Kit.card(area, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 150) })
	Kit.padding(16).Parent = price
	local priceText = Kit.title(price, "", 28, C.ink, { Size = UDim2.new(0.5, 0, 0, 34) })
	local trendText = Kit.title(price, "", 18, C.green, { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0.5, 0, 0, 24) })
	local nextText = Kit.label(price, "", 15, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(0.5, 0, 0, 20) })
	Kit.label(price, T("fuel_tip"), 14, C.muted, nil, {
		Position = UDim2.fromOffset(0, 88), Size = UDim2.new(0.5, -10, 0, 34), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})
	local chart = create("Frame", {
		Parent = price, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.48, 0, 1, 0),
		BackgroundColor3 = C.white,
	}, { corner(12), Kit.padding(10, 10, 10, 10) })
	local bars = {}
	for i = 1, 8 do
		bars[i] = create("Frame", {
			Parent = chart, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / 8, 3, 1, 0), Size = UDim2.new(1 / 8, -6, 0.5, 0),
			BackgroundColor3 = C.grey, BorderSizePixel = 0,
		}, { corner(4) })
	end

	-- Comprar
	local buyRow = create("Frame", { Parent = area, LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70) }, {
		Kit.list(true, 10),
	})
	local buttons = {}
	for i, frac in { 1, 0.25, 0.1 } do
		local b = Kit.button(buyRow, "", i == 1 and "green" or "blue", UDim2.new(1 / 3, -7, 1, -2), function()
			local st = ctx.state
			local room = (st.fuelCap or 0) - (st.fuel or 0)
			local want = if frac == 1 then room else math.floor((st.fuelCap or 0) * frac)
			ctx.act("buyFuel", math.max(1, math.min(room, want)))
		end, { LayoutOrder = i })
		b.TextSize = 18
		b.TextWrapped = true
		buttons[i] = { btn = b, frac = frac }
	end
	ctx.targets.fuel_fill = buttons[1].btn

	-- Despachador
	local auto = Kit.card(area, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 64) })
	Kit.padding(16, 16, 0, 0).Parent = auto
	local autoText = Kit.label(auto, "", 16, C.ink, Kit.FONT_BOLD, { Size = UDim2.new(1, -230, 1, 0), TextWrapped = true })
	Kit.button(auto, "🧭 " .. T("dispatcher_title"), "white", UDim2.fromOffset(210, 46), function()
		if ctx.pilotsTab then
			ctx.openPanel("pilots")
			ctx.pilotsTab("dispatcher")
		end
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })

	return function()
		local st = ctx.state
		if not st then
			return
		end
		local cap = math.max(1, st.fuelCap or 1)
		local fuel = st.fuel or 0
		tankText.Text = Kit.fmtInt(fuel) .. " / " .. Kit.fmtInt(cap) .. " L"
		tankFill.Size = UDim2.fromScale(math.clamp(fuel / cap, 0, 1), 1)
		tankFill.BackgroundColor3 = fuel < cap * Config.FUEL_LOW and C.red or C.blue
		tankNote.Text = fuel < cap * Config.FUEL_LOW and ("⚠️ " .. T("fuel_low_note")) or T("fuel_tank_note")
		local lvl = st.upgrades.tank or 0
		local up = Config.UpgradeById.tank
		if lvl >= up.max then
			Kit.setButton(upgradeBtn, "✅ " .. T("maxed"), false)
		else
			local cost = Config.upgradeCost("tank", lvl)
			Kit.setButton(upgradeBtn, "🛢️ " .. T("fuel_bigger", { n = Kit.fmtInt(Config.tankCapacity(lvl + 1)), cost = Kit.fmtMoney(cost) }), st.money >= cost)
		end
		-- Precio de ahora y tendencia
		local p = st.fuelPrice
		priceText.Text = T("fuel_price", { price = string.gsub(string.format("%.2f", p), "%.", ctx.lang == "es" and "," or ".") })
		local hist = st.fuelHistory or {}
		local last, prev = hist[#hist] or 1, hist[#hist - 1] or 1
		local change = math.floor((last / prev - 1) * 100 + 0.5)
		trendText.Text = change > 0 and ("▲ +" .. change .. " %  " .. T("fuel_up")) or (change < 0 and ("▼ " .. change .. " %  " .. T("fuel_down")) or ("▬ " .. T("fuel_same")))
		trendText.TextColor3 = change > 0 and C.red or (change < 0 and C.greenDark or C.muted)
		nextText.Text = "⏱️ " .. T("fuel_next", { time = Kit.fmtTime(st.fuelNextIn or 0) })
		for i, bar in bars do
			local m = hist[i] or 1
			bar.Size = UDim2.new(1 / 8, -6, math.clamp((m - 0.7) / 0.6, 0.08, 1), 0)
			bar.BackgroundColor3 = i == #hist and (m <= 1 and C.green or C.orange) or C.grey
		end
		-- Botones de compra
		local room = cap - fuel
		for i, b in buttons do
			local litres = if b.frac == 1 then room else math.min(room, math.floor(cap * b.frac))
			local cost = math.ceil(litres * p)
			local label = if i == 1 then T("fuel_fill") else ("+" .. math.floor(b.frac * 100) .. " %")
			Kit.setButton(b.btn, "⛽ " .. label .. "\n" .. Kit.fmtInt(litres) .. " L · " .. Kit.fmtMoney(cost), litres >= 1 and st.money >= 1)
		end
		local d = st.dispatcher or 0
		autoText.Text = d >= 2 and ("✅ " .. T("fuel_auto_on")) or ("💡 " .. T("fuel_auto_off"))
	end
end

return FuelPanel
