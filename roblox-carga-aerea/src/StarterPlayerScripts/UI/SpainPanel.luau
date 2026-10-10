--[[
	Ventana ESPAÑA: regiones para desbloquear (se pintan de color en el mapa) y PASAPORTE:
	un sello por aeropuerto (la primera entrega allí paga ×1,5) y medallas por producto.
	Una región con todos sus sellos paga +3 % para siempre.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local Rules = Kit.Rules
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local SpainPanel = {}

local MEDAL = { "🥉", "🥈", "🥇" }

function SpainPanel.build(content: Frame): () -> ()
	local tab = "regions"
	local currentTab = ""
	local render: () -> ()
	local _, paintTabs = Kit.tabs(content, {
		{ id = "regions", text = "🗺️ " .. T("tab_regions") },
		{ id = "passport", text = "🛂 " .. T("tab_passport") },
	}, function() return tab end, function(id)
		tab = id
		render()
	end)
	local stampsPill = Kit.pill(content, "", Color3.fromRGB(236, 72, 153), {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 10), TextSize = 16, Size = UDim2.fromOffset(0, 28),
	})
	local area = Kit.scroll(content, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58) })
	local cache: { [any]: Kit.Entry } = {}
	local updaters: { () -> () } = {}

	local function buildRegion(r: any): Kit.Entry
		local root = Kit.card(area, { Size = UDim2.new(1, 0, 0, 96) })
		Kit.padding(14).Parent = root
		create("Frame", { Parent = root, BackgroundColor3 = r.color, Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, 2) }, {
			corner(18), Kit.stroke(C.white, 3),
		})
		local airports, goods, seen = {}, {}, {}
		for _, a in Config.Airports do
			if a.region == r.id then
				table.insert(airports, a.city)
				for _, g in a.goods do
					if not seen[g] then
						seen[g] = true
						table.insert(goods, Config.GoodById[g].emoji)
					end
				end
			end
		end
		Kit.title(root, T("r_" .. r.id), 24, C.ink, { Position = UDim2.fromOffset(80, 0), Size = UDim2.new(1, -340, 0, 28) })
		Kit.label(root, table.concat(airports, " · "), 15, C.muted, nil, { Position = UDim2.fromOffset(80, 30), Size = UDim2.new(1, -340, 0, 20) })
		Kit.label(root, table.concat(goods, " "), 20, C.ink, nil, { Position = UDim2.fromOffset(80, 50), Size = UDim2.new(1, -340, 0, 24) })
		local btn = Kit.button(root, "", "orange", UDim2.fromOffset(250, 54), function()
			local ok = ctx.act("buyRegion", r.id)
			if ok then
				ctx.closePanel()
				ctx.celebrateRegion(r.id)
			end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		ctx.targets["region_" .. r.id] = btn
		return {
			root = root,
			update = function()
				local st = ctx.state
				if st.regions[r.id] then
					Kit.setButton(btn, "✅ " .. T("owned"), false)
				elseif st.level < r.level then
					Kit.setButton(btn, "🔒 " .. T("req_level", { level = r.level }), false)
				else
					Kit.setButton(btn, "🔓 " .. Kit.fmtMoney(r.cost), st.money >= r.cost)
				end
			end,
		}
	end

	-- Pasaporte: una tarjeta por región con sus sellos y otra con las medallas de productos
	local function buildPassport()
		Kit.label(area, "💡 " .. T("passport_note"), 15, C.muted, nil, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 40), TextWrapped = true })
		for i, r in Config.Regions do
			local list = {}
			for _, a in Config.Airports do
				if a.region == r.id then
					table.insert(list, a)
				end
			end
			local rows = math.ceil(#list / 4)
			local card = Kit.card(area, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 52 + rows * 40) })
			Kit.padding(14).Parent = card
			create("Frame", { Parent = card, BackgroundColor3 = r.color, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 4) }, { corner() })
			Kit.title(card, T("r_" .. r.id), 19, C.ink, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(0.6, -28, 0, 26) })
			local status = Kit.label(card, "", 15, C.muted, Kit.FONT_BOLD, {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.new(0.4, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Right,
			})
			local grid = create("Frame", { Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, rows * 40) })
			-- Celdas un poco más estrechas que 1/4 para que los redondeos no manden una a la fila siguiente
			create("UIGridLayout", {
				Parent = grid, CellSize = UDim2.new(0.25, -8, 0, 34), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder,
			})
			local chips = {}
			for j, a in list do
				local chip = create("TextLabel", {
					Parent = grid, LayoutOrder = j, BackgroundColor3 = C.white, Text = "", FontFace = Kit.FONT_BOLD, TextSize = 15,
					TextColor3 = C.ink, TextTruncate = Enum.TextTruncate.AtEnd,
				}, { corner(10) })
				chips[a.code] = { chip = chip, city = a.city }
			end
			table.insert(updaters, function()
				local st = ctx.state
				local have = 0
				for code, x in chips do
					local ok = st.album.airports[code] == true
					if ok then
						have += 1
					end
					x.chip.Text = (ok and "✅ " or "❔ ") .. x.city
					x.chip.TextColor3 = ok and C.greenDark or C.muted
					x.chip.BackgroundColor3 = ok and Color3.fromRGB(220, 247, 230) or C.white
				end
				local complete = Rules.regionComplete(st.album.airports, r.id)
				status.Text = complete and ("🏅 " .. T("passport_complete")) or (have .. " / " .. #list)
				status.TextColor3 = complete and C.greenDark or C.muted
			end)
		end
		-- Medallas por producto
		local goodsCard = Kit.card(area, { LayoutOrder = 50, Size = UDim2.new(1, 0, 0, 44 + math.ceil(#Config.Goods / 6) * 74) })
		Kit.padding(14).Parent = goodsCard
		Kit.title(goodsCard, "🏅 " .. T("passport_goods", { a = Config.MEDALS[1], b = Config.MEDALS[2], c = Config.MEDALS[3] }), 19, C.ink, {
			Size = UDim2.new(1, 0, 0, 26),
		})
		local grid = create("Frame", {
			Parent = goodsCard, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, math.ceil(#Config.Goods / 6) * 74),
		})
		create("UIGridLayout", {
			Parent = grid, CellSize = UDim2.new(1 / 6, -9, 0, 66), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local cells = {}
		for i, g in Config.Goods do
			local cell = create("Frame", { Parent = grid, LayoutOrder = i, BackgroundColor3 = C.white }, { corner(12) })
			Kit.emoji(cell, g.emoji, 26, { Position = UDim2.fromOffset(6, 4) })
			local name = Kit.label(cell, T("good_" .. g.id), 13, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -44, 0, 18) })
			local medals = Kit.label(cell, "", 15, C.ink, nil, { Position = UDim2.fromOffset(6, 36), Size = UDim2.new(1, -12, 0, 22) })
			cells[g.id] = { name = name, medals = medals }
		end
		table.insert(updaters, function()
			local st = ctx.state
			for id, x in cells do
				local count = st.album.goods[id] or 0
				local n = Rules.medals(count)
				local text = ""
				for m = 1, 3 do
					text ..= m <= n and MEDAL[m] or "⚪"
				end
				x.medals.Text = text .. "  " .. Kit.fmtInt(count)
			end
		end)
	end

	function render()
		local st = ctx.state
		if not st then
			return
		end
		if tab ~= currentTab then
			currentTab = tab
			paintTabs()
			table.clear(cache)
			table.clear(updaters)
			for _, k in area:GetChildren() do
				if not k:IsA("UIPadding") then
					k:Destroy()
				end
			end
			Kit.list(false, 10).Parent = area
			if tab == "passport" then
				buildPassport()
			end
		end
		stampsPill.Text = "🛂 " .. T("stamps", { n = st.stamps or 0, max = st.stampsMax or 0 })
		if tab == "regions" then
			Kit.syncList(cache, Config.Regions, function(r) return r.id end, buildRegion)
		else
			for _, fn in updaters do
				fn()
			end
		end
	end
	ctx.spainTab = function(id: string)
		tab = id
		render()
	end
	return render
end

return SpainPanel
