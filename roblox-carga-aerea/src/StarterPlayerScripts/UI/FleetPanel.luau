--[[
	Ventana FLOTA: mis aviones · comprar · mejoras de la empresa.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local PlaneArt = require(script.Parent:WaitForChild("PlaneArt"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local FleetPanel = {}

local function statusOf(plane: any): (string, Color3)
	if plane.flight then
		if plane.flight.good == "ferry" then
			return T("st_ferry"), C.purple
		end
		return T("st_flying"), C.blue
	elseif plane.condition < Config.REPAIR_BLOCK then
		return T("st_repair"), C.red
	end
	return T("st_ready"), C.green
end
FleetPanel.statusOf = statusOf

function FleetPanel.where(plane: any): string
	if plane.flight then
		local a, b = Config.AirportByCode[plane.flight.from], Config.AirportByCode[plane.flight.to]
		return a.city .. " → " .. b.city .. " · " .. Kit.fmtTime(plane.flight.endT - Kit.serverNow())
	end
	return "📍 " .. Config.AirportByCode[plane.airport].city
end

function FleetPanel.build(content: Frame): () -> ()
	local tab = "mine"
	local area: ScrollingFrame
	local cache: { [any]: Kit.Entry } = {}
	local currentTab = ""
	local render: () -> ()
	local _, paintTabs = Kit.tabs(content, {
		{ id = "mine", text = "✈️ " .. T("tab_my_planes") },
		{ id = "buy", text = "🛒 " .. T("tab_buy") },
		{ id = "upgrades", text = "🔧 " .. T("tab_upgrades") },
	}, function() return tab end, function(id)
		tab = id
		render()
	end)
	local hangar = Kit.pill(content, "", C.blue, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 10), TextSize = 16, Size = UDim2.fromOffset(0, 28) })
	area = Kit.scroll(content, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58) })

	local function artBox(parent: Instance, model: string, h: number): Frame
		local box = create("Frame", { Parent = parent, BackgroundColor3 = Color3.fromRGB(214, 238, 252), Size = UDim2.new(1, 0, 0, h), BorderSizePixel = 0 }, {
			corner(14),
		})
		PlaneArt.side(box, model)
		return box
	end

	local function buildMine(plane: any): Kit.Entry
		local root = Kit.card(area)
		Kit.padding(12).Parent = root
		artBox(root, plane.model, 120)
		local reg = Kit.pill(root, string.format("EC-%03d", plane.id), C.ink, { Position = UDim2.fromOffset(8, 8), TextSize = 13 })
		reg.ZIndex = 2
		local name = Kit.title(root, "", 22, C.ink, { Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, -120, 0, 28) })
		local status = Kit.pill(root, "", C.green, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 130) })
		local where = Kit.label(root, "", 16, C.muted, nil, { Position = UDim2.fromOffset(0, 158), Size = UDim2.new(1, 0, 0, 20) })
		local stats = Kit.label(root, "", 15, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 180), Size = UDim2.new(1, 0, 0, 20) })
		local cond = Kit.label(root, "", 14, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, 0, 0, 18) })
		local condFill = Kit.progress(root, { Position = UDim2.fromOffset(0, 224) }, C.green)
		local row = create("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -46), Size = UDim2.new(1, 0, 0, 46) }, {
			Kit.list(true, 8),
		})
		local fly = Kit.button(row, "📦 " .. T("btn_fly"), "orange", UDim2.new(0.4, -6, 1, 0), function()
			ctx.selectPlane = plane.id
			ctx.openPanel("cargo")
		end, { LayoutOrder = 1 })
		local repair = Kit.button(row, "", "blue", UDim2.new(0.4, -6, 1, 0), function()
			ctx.act("repair", plane.id)
		end, { LayoutOrder = 2 })
		local sell = Kit.button(row, "💲", "white", UDim2.new(0.2, -4, 1, 0), function()
			local p
			for _, x in ctx.state.planes do
				if x.id == plane.id then
					p = x
				end
			end
			if not p then
				return
			end
			local model = Config.PlaneById[p.model]
			ctx.openModal(T("sell_title", { name = Kit.planeName(p.model) }), function(body)
				Kit.title(body, Kit.fmtMoney(Config.sellPrice(model.price, p.condition)), 40, C.green, { Size = UDim2.new(1, 0, 0, 50) })
			end, {
				{ text = T("btn_cancel"), style = "white" },
				{ text = T("btn_sell"), style = "red", onClick = function()
					ctx.act("sellPlane", plane.id)
				end },
			})
		end, { LayoutOrder = 3 })
		for _, b in { fly, repair, sell } do
			b.TextSize = 17
		end
		return {
			root = root,
			update = function(p: any)
				local m = Config.PlaneById[p.model]
				name.Text = m.emoji .. " " .. Kit.planeName(p.model)
				local st, col = statusOf(p)
				status.Text = st
				status.BackgroundColor3 = col
				where.Text = FleetPanel.where(p)
				stats.Text = string.format("⚖️ %s   🚀 %d km/h   📏 %s km", Kit.fmtTons(m.cap), m.speed, Kit.fmtInt(m.range))
				cond.Text = T("condition", { p = math.floor(p.condition) })
				condFill.Size = UDim2.fromScale(p.condition / 100, 1)
				condFill.BackgroundColor3 = p.condition >= 60 and C.green or (p.condition >= Config.REPAIR_BLOCK and C.gold or C.red)
				Kit.setButton(fly, nil, not p.flight)
				local cost = Config.repairCost(m.price, p.condition)
				Kit.setButton(repair, cost > 0 and ("🔧 " .. Kit.fmtMoney(cost)) or "🔧 ✅", not p.flight and cost > 0 and ctx.state.money >= cost)
				Kit.setButton(sell, nil, not p.flight and #ctx.state.planes > 1)
			end,
		}
	end

	local function buildBuy(model: any): Kit.Entry
		local root = Kit.card(area)
		Kit.padding(12).Parent = root
		artBox(root, model.id, 120)
		Kit.title(root, model.emoji .. " " .. Kit.planeName(model.id), 22, C.ink, { Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 28) })
		Kit.label(root, T("plane_" .. model.id .. "_d"), 15, C.muted, nil, {
			Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})
		Kit.label(root, string.format("⚖️ %s   🚀 %d km/h   📏 %s km   ⛽ %s L/km", Kit.fmtTons(model.cap), model.speed, Kit.fmtInt(model.range), tostring(model.burn)), 14, C.ink, Kit.FONT_BOLD, {
			Position = UDim2.fromOffset(0, 194), Size = UDim2.new(1, 0, 0, 20),
		})
		local price = Kit.title(root, Kit.fmtMoney(model.price), 26, C.green, { Position = UDim2.fromOffset(0, 216), Size = UDim2.new(0.5, 0, 0, 32) })
		local req = Kit.label(root, "", 14, C.red, Kit.FONT_BOLD, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 222), Size = UDim2.new(0.5, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right,
		})
		local buy = Kit.button(root, "🛒 " .. T("btn_buy"), "green", UDim2.new(1, 0, 0, 46), function()
			ctx.act("buyPlane", model.id)
		end, { Position = UDim2.new(0, 0, 1, -46) })
		ctx.targets["buy_" .. model.id] = buy
		return {
			root = root,
			update = function()
				local st = ctx.state
				local locked = st.level < model.level
				req.Text = locked and ("🔒 " .. T("req_level", { level = model.level })) or ""
				price.TextColor3 = st.money >= model.price and C.green or C.red
				Kit.setButton(buy, nil, not locked and st.money >= model.price and #st.planes < st.maxPlanes)
			end,
		}
	end

	local function buildUpgrade(up: any): Kit.Entry
		local root = Kit.card(area, { Size = UDim2.new(1, 0, 0, 108) })
		Kit.padding(14).Parent = root
		local box = create("Frame", { Parent = root, BackgroundColor3 = C.white, Size = UDim2.fromOffset(80, 80), BorderSizePixel = 0 }, { corner(18) })
		Kit.emoji(box, up.emoji, 40, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		Kit.title(root, T("up_" .. up.id), 22, C.ink, { Position = UDim2.fromOffset(96, 0), Size = UDim2.new(1, -350, 0, 28) })
		Kit.label(root, T("up_" .. up.id .. "_d"), 16, C.muted, nil, { Position = UDim2.fromOffset(96, 28), Size = UDim2.new(1, -350, 0, 22) })
		local dots = create("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 58), Size = UDim2.new(1, -350, 0, 14) }, {
			Kit.list(true, 4),
		})
		local pieces = {}
		for i = 1, up.max do
			pieces[i] = create("Frame", { Parent = dots, LayoutOrder = i, BackgroundColor3 = C.line, Size = UDim2.new(1 / up.max, -4, 1, 0), BorderSizePixel = 0 }, {
				corner(),
			})
		end
		local buy = Kit.button(root, "", "orange", UDim2.fromOffset(230, 52), function()
			ctx.act("buyUpgrade", up.id)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		return {
			root = root,
			update = function()
				local st = ctx.state
				local lvl = st.upgrades[up.id] or 0
				for i, piece in pieces do
					piece.BackgroundColor3 = i <= lvl and C.orange or C.line
				end
				if lvl >= up.max then
					Kit.setButton(buy, "✅ " .. T("maxed"), false)
				elseif st.level < up.level then
					Kit.setButton(buy, "🔒 " .. T("req_level", { level = up.level }), false)
				else
					local cost = Config.upgradeCost(up.id, lvl)
					Kit.setButton(buy, "⬆️ " .. Kit.fmtMoney(cost), st.money >= cost)
				end
			end,
		}
	end

	function render()
		local st = ctx.state
		if not st then
			return
		end
		if tab ~= currentTab then
			currentTab = tab
			paintTabs()
			for _, e in cache do
				e.root:Destroy()
			end
			table.clear(cache)
			for _, k in area:GetChildren() do
				if k:IsA("UIGridLayout") or k:IsA("UIListLayout") then
					k:Destroy()
				end
			end
			if tab == "upgrades" then
				Kit.list(false, 12).Parent = area
			else
				Kit.grid(area, tab == "mine" and 306 or 330, 3)
			end
		end
		hangar.Text = "🏗️ " .. T("hangar", { n = #st.planes, max = st.maxPlanes })
		if tab == "mine" then
			Kit.syncList(cache, st.planes, function(p) return p.id end, buildMine)
		elseif tab == "buy" then
			Kit.syncList(cache, Config.Planes, function(m) return m.id end, buildBuy)
		else
			Kit.syncList(cache, Config.Upgrades, function(u) return u.id end, buildUpgrade)
		end
	end
	ctx.fleetTab = function(id: string)
		tab = id
		render()
	end
	table.insert(ctx.tickers, function()
		if ctx.panel == "fleet" and tab == "mine" then
			render()
		end
	end)
	return render
end

return FleetPanel
