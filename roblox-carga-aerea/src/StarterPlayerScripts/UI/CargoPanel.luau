--[[
	Ventana CARGAS: eliges avión, quién vuela y una carga del tablón del aeropuerto.
	Los contratos exprés salen en dorado y arriba del todo.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local PlaneArt = require(script.Parent:WaitForChild("PlaneArt"))
local FleetPanel = require(script.Parent:WaitForChild("FleetPanel"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local CargoPanel = {}

function CargoPanel.build(content: Frame): () -> ()
	local selectedPilot = 0
	local afterTakeoff: () -> ()
	local render: () -> ()

	-- Columna izquierda: aviones + interruptor automático
	local left = Kit.card(content, { Size = UDim2.new(0, 330, 1, 0) })
	Kit.title(left, T("cargo_planes"), 18, C.muted, { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -180, 0, 24) })
	local autoBtn = Kit.button(left, "", "white", UDim2.fromOffset(150, 40), function()
		if ctx.state.autoUnlocked then
			ctx.act("setAuto", not ctx.state.settings.auto)
		elseif ctx.pilotsTab then
			-- Sin despachador: se abre su pestaña para contratarlo
			ctx.openPanel("pilots")
			ctx.pilotsTab("dispatcher")
		end
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6) })
	autoBtn.TextSize = 15
	local planeList = Kit.scroll(left, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) })
	Kit.list(false, 8).Parent = planeList
	local planeCache: { [any]: Kit.Entry } = {}

	-- Columna derecha: tablón
	local right = create("Frame", { Parent = content, BackgroundTransparency = 1, Position = UDim2.fromOffset(346, 0), Size = UDim2.new(1, -346, 1, 0) })
	local header = Kit.title(right, "", 24, C.ink, { Size = UDim2.new(1, -450, 0, 30) })
	local products = Kit.label(right, "", 15, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -450, 0, 20) })
	local function selected(): any
		local st = ctx.state
		if not st then
			return nil
		end
		for _, p in st.planes do
			if p.id == ctx.selectPlane then
				return p
			end
		end
		return nil
	end
	local refreshBtn = Kit.button(right, "🔄 " .. T("btn_refresh"), "white", UDim2.fromOffset(140, 44), function()
		local p = selected()
		if p then
			ctx.act("refreshBoard", p.airport)
		end
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, 0) })
	refreshBtn.TextSize = 15
	-- Chárter: viaje largo de horas reales (uno a la vez)
	local charterBtn = Kit.button(right, "🌙 " .. T("btn_charter"), "white", UDim2.fromOffset(140, 44), function()
		local plane = selected()
		if not plane or plane.flight then
			return
		end
		ctx.openModal("🌙 " .. T("charter_title"), function(body)
			Kit.list(false, 10).Parent = body
			Kit.label(body, T("charter_body"), 16, C.muted, nil, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 44), TextWrapped = true })
			for i, c in Config.Charters do
				local row = Kit.card(body, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 60) })
				Kit.padding(14, 8, 0, 0).Parent = row
				Kit.title(row, T("charter_hours", { h = c.hours }), 20, C.ink, { Size = UDim2.new(0.45, 0, 1, 0) })
				Kit.title(row, "+" .. Kit.fmtMoney(ctx.state.charterPay and ctx.state.charterPay[c.id] or 0), 22, C.greenDark, {
					Position = UDim2.fromScale(0.4, 0), Size = UDim2.new(0.6, -130, 1, 0),
				})
				Kit.button(row, "✈️", "blue", UDim2.fromOffset(110, 44), function()
					ctx.closeModal()
					local ok = ctx.act("charter", plane.id, c.id)
					if ok then
						Kit.playSound("takeoff")
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
			end
		end, { { text = T("btn_close"), style = "white" } })
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -300, 0, 0) })
	charterBtn.TextSize = 15
	local ferryBtn = Kit.button(right, "🧭 " .. T("btn_ferry"), "white", UDim2.fromOffset(140, 44), function()
		local plane = selected()
		if not plane or plane.flight then
			return
		end
		local model = Config.PlaneById[plane.model]
		ctx.openModal(T("ferry_title", { name = Kit.planeName(plane.model) }), function(body)
			Kit.label(body, T("ferry_body"), 16, C.muted, nil, { Size = UDim2.new(1, 0, 0, 22), TextWrapped = true })
			local list = Kit.scroll(body, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 300) })
			Kit.list(false, 6).Parent = list
			local options = {}
			for _, a in Config.Airports do
				if a.code ~= plane.airport and ctx.state.regions[a.region] then
					local d = Config.distance(plane.airport, a.code)
					if d <= model.range then
						table.insert(options, { a = a, d = d })
					end
				end
			end
			table.sort(options, function(x, y) return x.d < y.d end)
			for i, o in options do
				local row = Kit.card(list, { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 52) })
				Kit.padding(12, 6, 0, 0).Parent = row
				Kit.title(row, o.a.city, 18, C.ink, { Size = UDim2.new(0.4, 0, 1, 0) })
				Kit.label(row, string.format("%s km · ⏱️ %s · ⛽ %s", Kit.fmtInt(o.d), Kit.fmtTime(Config.flightSeconds(o.d, model.speed, ctx.state.timeMult)),
					Kit.fmtMoney(math.floor(o.d * model.burn * ctx.state.fuelPrice))), 15, C.muted, nil, {
					Position = UDim2.fromScale(0.38, 0), Size = UDim2.new(0.62, -110, 1, 0),
				})
				Kit.button(row, "✈️", "blue", UDim2.fromOffset(90, 40), function()
					ctx.closeModal()
					ctx.act("ferry", plane.id, o.a.code)
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
			end
		end)
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) })
	ferryBtn.TextSize = 15
	local pilotTitle = Kit.title(right, T("cargo_who"), 15, C.muted, { Position = UDim2.fromOffset(0, 58), Size = UDim2.fromOffset(300, 20) })
	local pilotRow = create("ScrollingFrame", {
		Parent = right, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 48),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0,
	}, { Kit.list(true, 8) })
	local loadList = Kit.scroll(right, { Position = UDim2.fromOffset(0, 134), Size = UDim2.new(1, 0, 1, -134) })
	Kit.list(false, 8).Parent = loadList
	local loadCache: { [any]: Kit.Entry } = {}
	local empty = Kit.label(right, "", 18, C.muted, nil, {
		Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
	})

	local function buildPlaneRow(plane: any): Kit.Entry
		local root = create("TextButton", { Parent = planeList, BackgroundColor3 = C.white, Size = UDim2.new(1, 0, 0, 76), Text = "", AutoButtonColor = false }, {
			corner(14),
		})
		local border = Kit.stroke(C.line, 2)
		border.Parent = root
		local art = create("Frame", { Parent = root, BackgroundColor3 = Color3.fromRGB(214, 238, 252), Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(108, 60) }, {
			corner(10),
		})
		PlaneArt.side(art, plane.model)
		local name = Kit.title(root, "", 17, C.ink, { Position = UDim2.fromOffset(124, 6), Size = UDim2.new(1, -130, 0, 22) })
		local where = Kit.label(root, "", 14, C.muted, nil, { Position = UDim2.fromOffset(124, 28), Size = UDim2.new(1, -130, 0, 18) })
		local status = Kit.label(root, "", 13, C.green, Kit.FONT_BOLD, { Position = UDim2.fromOffset(124, 48), Size = UDim2.new(1, -130, 0, 18) })
		root.Activated:Connect(function()
			Kit.playSound("click")
			ctx.selectPlane = plane.id
			ctx.refreshPanel()
		end)
		return {
			root = root,
			update = function(p: any)
				name.Text = Kit.planeName(p.model) .. " · " .. string.format("EC-%03d", p.id)
				where.Text = FleetPanel.where(p)
				local st, col = FleetPanel.statusOf(p)
				status.Text = st
				status.TextColor3 = col
				local sel = p.id == ctx.selectPlane
				border.Color = sel and C.orange or C.line
				border.Thickness = sel and 3 or 2
			end,
		}
	end

	local function buildLoadRow(load: any): Kit.Entry
		local ex = load.express ~= nil
		local root = Kit.card(loadList, { Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = ex and Color3.fromRGB(255, 244, 204) or C.soft })
		if ex then
			Kit.stroke(C.gold, 3).Parent = root
		end
		local good = Config.GoodById[load.good]
		local bubble = create("Frame", { Parent = root, BackgroundColor3 = C.white, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(60, 60) }, {
			corner(),
		})
		Kit.emoji(bubble, good.emoji, 32, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		local to = Config.AirportByCode[load.to]
		Kit.title(root, T("good_" .. load.good) .. " · " .. Kit.fmtTons(load.weight), 19, C.ink, { Position = UDim2.fromOffset(84, 10), Size = UDim2.new(0.42, -84, 0, 24) })
		Kit.label(root, "→ " .. to.city .. " · " .. Kit.fmtInt(load.dist) .. " km", 15, C.muted, nil, { Position = UDim2.fromOffset(84, 36), Size = UDim2.new(0.42, -84, 0, 20) })
		local tag = Kit.label(root, "", 14, C.goldDark, Kit.FONT_BOLD, { Position = UDim2.fromOffset(84, 58), Size = UDim2.new(0.42, -84, 0, 18) })
		local net = Kit.title(root, "", 26, C.green, { Position = UDim2.new(0.42, 0, 0, 10), Size = UDim2.new(0.32, 0, 0, 32) })
		local detail = Kit.label(root, "", 13, C.muted, nil, { Position = UDim2.new(0.42, 0, 0, 44), Size = UDim2.new(0.32, 0, 0, 32), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		local noFuel = false
		local fly = Kit.button(root, "✈️ " .. T("btn_fly"), ex and "gold" or "orange", UDim2.new(0.24, -12, 0, 56), function()
			if noFuel then
				ctx.openPanel("fuel")
				return
			end
			local ok = ctx.act("dispatch", ctx.selectPlane, load.id, selectedPilot)
			if ok then
				Kit.playSound("takeoff")
				afterTakeoff()
			end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) })
		local reason = Kit.label(root, "", 14, C.red, Kit.FONT_BOLD, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0.24, -12, 0, 56),
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
		})
		if load.tutorial then
			ctx.targets.fly_first = fly
		end
		return {
			root = root,
			update = function(l: any)
				local plane = selected()
				if not plane then
					return
				end
				local gross, fuel, fee, secs, mods, litres = Kit.quote(plane, l, selectedPilot)
				local n = gross - fuel - fee
				net.Text = (n >= 0 and "+" or "") .. Kit.fmtMoney(n)
				net.TextColor3 = n >= 0 and C.greenDark or C.red
				detail.Text = "⏱️ " .. Kit.fmtTime(secs) .. "  ·  ⛽ " .. Kit.fmtInt(litres) .. " L" .. (fee > 0 and ("  ·  👨‍✈️ −" .. Kit.fmtMoney(fee)) or "")
				-- Etiquetas: exprés, contrato, evento, ciudad en auge, ruta nueva, saturación, rasgo del piloto
				local parts = {}
				if l.express then
					table.insert(parts, "⚡ ×" .. Config.Express.mult .. " " .. Kit.fmtTime(l.express - Kit.serverNow()))
				elseif l.tutorial then
					table.insert(parts, "⭐ " .. T("first_flight"))
				end
				local dest = Config.AirportByCode[l.to]
				for _, c in ctx.state.contracts and ctx.state.contracts.active or {} do
					if c.good == l.good and dest.region == c.region then
						table.insert(parts, "📜")
						break
					end
				end
				for _, m in mods do
					table.insert(parts, Kit.modText(m))
				end
				tag.Text = table.concat(parts, "  ")
				tag.TextColor3 = #mods > 0 and C.orangeDark or C.goldDark
				local block = Kit.flyBlock(plane, l)
				if not block and selectedPilot > 0 and Kit.pilotBusy(selectedPilot) then
					block = "err_pilot_busy"
				elseif not block and selectedPilot == 0 and Kit.pilotBusy(0) then
					block = "err_you_busy"
				end
				-- Sin combustible: el botón lleva a comprarlo
				noFuel = block == "err_no_fuel"
				fly.Parent.Visible = block == nil or noFuel
				Kit.setButton(fly, noFuel and ("⛽ " .. T("btn_buy_fuel")) or ("✈️ " .. T("btn_fly")), true)
				reason.Visible = block ~= nil and not noFuel
				reason.Text = block and T(block) or ""
			end,
		}
	end

	local chips: { [number]: TextButton } = {}
	local function renderPilots()
		local st = ctx.state
		local list = { { id = 0, name = T("pilot_you"), stars = 0, avatar = "🧑‍✈️", level = 1 } }
		for _, p in st.pilots do
			table.insert(list, p)
		end
		-- Si el elegido está volando o ya no existe, se elige uno libre (tú primero)
		if (selectedPilot ~= 0 and not Kit.findPilot(selectedPilot)) or Kit.pilotBusy(selectedPilot) then
			local best, rank = nil, -1
			for _, p in list do
				local r = p.id == 0 and 99 or Config.pilotBonus(p.stars, p.level)
				if not Kit.pilotBusy(p.id) and r > rank then
					best, rank = p.id, r
				end
			end
			selectedPilot = best or 0
		end
		local seen = {}
		for i, p in list do
			seen[p.id] = true
			local chip = chips[p.id]
			if not chip then
				chip = create("TextButton", {
					Parent = pilotRow, Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, AutoButtonColor = false,
					BackgroundColor3 = C.white, Text = "", FontFace = Kit.FONT_TITLE, TextSize = 16, TextColor3 = C.ink,
				}, { corner(), Kit.stroke(C.line, 2), Kit.padding(14, 14, 0, 0) })
				chip.Activated:Connect(function()
					Kit.playSound("click")
					selectedPilot = p.id
					ctx.refreshPanel()
				end)
				chips[p.id] = chip
			end
			chip.LayoutOrder = i
			local busy = Kit.pilotBusy(p.id)
			local bonus = p.id > 0 and string.format(" +%d%%", math.floor(Config.pilotBonus(p.stars, p.level) * 100 + 0.5)) or ""
			local trait = p.trait and Config.TraitById[p.trait]
			chip.Text = p.avatar .. " " .. p.name .. (p.id > 0 and (" " .. string.rep("★", p.stars)) or "") .. bonus .. (trait and (" " .. trait.emoji) or "") .. (busy and " ✈️" or "")
			chip.TextColor3 = busy and C.greyDark or C.ink
			chip.BackgroundColor3 = p.id == selectedPilot and Color3.fromRGB(255, 233, 220) or C.white
			chip:FindFirstChildOfClass("UIStroke").Color = p.id == selectedPilot and C.orange or C.line
		end
		for id, chip in chips do
			if not seen[id] then
				chip:Destroy()
				chips[id] = nil
			end
		end
	end

	function render()
		local st = ctx.state
		if not st then
			return
		end
		if st.autoUnlocked then
			Kit.setButton(autoBtn, "🤖 " .. T("auto_short", { v = st.settings.auto and T("on") or T("off") }), true)
			autoBtn.BackgroundColor3 = st.settings.auto and C.green or C.white
			autoBtn.TextColor3 = st.settings.auto and C.white or C.ink
		else
			Kit.setButton(autoBtn, "🤖 🔒 " .. T("tab_dispatcher"), false)
		end
		local planes = table.clone(st.planes)
		table.sort(planes, function(a, b)
			local ia, ib = a.flight and 1 or 0, b.flight and 1 or 0
			if ia ~= ib then
				return ia < ib
			end
			return a.id < b.id
		end)
		local sel = selected()
		if not sel or sel.flight then
			ctx.selectPlane = nil
			for _, p in planes do
				if not p.flight then
					ctx.selectPlane = p.id
					break
				end
			end
			sel = selected()
		end
		Kit.syncList(planeCache, planes, function(p) return p.id end, buildPlaneRow)
		renderPilots()
		pilotTitle.Visible = sel ~= nil
		pilotRow.Visible = sel ~= nil
		if not sel then
			header.Text = T("cargo_none")
			products.Text = ""
			empty.Text = ""
			Kit.syncList(loadCache, {}, function(l) return l.id end, buildLoadRow)
			Kit.setButton(refreshBtn, nil, false)
			Kit.setButton(ferryBtn, nil, false)
			Kit.setButton(charterBtn, nil, false)
			return
		end
		local a = Config.AirportByCode[sel.airport]
		header.Text = "📍 " .. a.city
		local goods = {}
		for _, g in a.goods do
			table.insert(goods, Config.GoodById[g].emoji)
		end
		products.Text = T("cargo_local", { goods = table.concat(goods, " ") })
		local cooldown = st.refresh[sel.airport] or 0
		Kit.setButton(refreshBtn, cooldown > 0 and ("⏳ " .. cooldown .. " s") or ("🔄 " .. T("btn_refresh")), cooldown <= 0)
		Kit.setButton(ferryBtn, nil, sel.condition >= Config.REPAIR_BLOCK)
		local charterBusy = false
		for _, p in st.planes do
			if p.flight and p.flight.good == "charter" then
				charterBusy = true
			end
		end
		charterBtn.Parent.Visible = st.level >= Config.CHARTER_LEVEL
		Kit.setButton(charterBtn, "🌙 " .. T(charterBusy and "charter_busy" or "btn_charter"), sel.condition >= Config.REPAIR_BLOCK and not charterBusy)
		local loads = table.clone(st.boards[sel.airport] or {})
		table.sort(loads, function(x, y)
			local ex, ey = (x.express or x.tutorial) and 1 or 0, (y.express or y.tutorial) and 1 or 0
			if ex ~= ey then
				return ex > ey
			end
			local bx, by = Kit.flyBlock(sel, x) == nil, Kit.flyBlock(sel, y) == nil
			if bx ~= by then
				return bx
			end
			local gx, fx, ox = Kit.quote(sel, x, selectedPilot)
			local gy, fy, oy = Kit.quote(sel, y, selectedPilot)
			return gx - fx - ox > gy - fy - oy
		end)
		Kit.syncList(loadCache, loads, function(l) return l.id end, buildLoadRow)
		empty.Text = #loads == 0 and T("board_empty") or ""
	end
	-- Tras despegar: si quedan aviones libres se elige el siguiente; si no, se cierra para ver el despegue
	function afterTakeoff()
		local st = ctx.state
		local nextPlane
		for _, p in st.planes do
			if not p.flight and p.id ~= ctx.selectPlane and p.condition >= Config.REPAIR_BLOCK then
				nextPlane = p.id
				break
			end
		end
		if nextPlane then
			ctx.selectPlane = nextPlane
			render()
		else
			ctx.closePanel()
		end
	end
	table.insert(ctx.tickers, function()
		if ctx.panel == "cargo" then
			render()
		end
	end)
	return render
end

return CargoPanel
