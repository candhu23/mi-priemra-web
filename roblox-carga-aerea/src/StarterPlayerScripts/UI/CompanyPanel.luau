--[[
	Ventana TU COMPAÑÍA (resumen): aerolínea, nivel, reputación y las cifras clave de un vistazo,
	con accesos directos a personal, combustible y bolsa.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local CompanyPanel = {}

local TILES = {
	{ id = "money", emoji = "💵", key = "ov_money" },
	{ id = "income", emoji = "📈", key = "ov_income" },
	{ id = "fuel", emoji = "⛽", key = "ov_fuel" },
	{ id = "planes", emoji = "✈️", key = "ov_planes" },
	{ id = "staff", emoji = "👥", key = "ov_staff" },
	{ id = "dispatcher", emoji = "🧭", key = "dispatcher_title" },
	{ id = "shares", emoji = "🏛️", key = "ov_shares" },
	{ id = "stamps", emoji = "🛂", key = "ov_stamps" },
	{ id = "flights", emoji = "📦", key = "ov_flights" },
	{ id = "km", emoji = "🛫", key = "ov_km" },
	{ id = "earned", emoji = "💰", key = "ov_earned" },
	{ id = "contracts", emoji = "📜", key = "ov_contracts" },
}

function CompanyPanel.build(content: Frame): () -> ()
	local area = Kit.scroll(content)
	Kit.list(false, 12).Parent = area

	-- Cabecera: aerolínea, nivel y reputación
	local head = Kit.card(area, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 132), BackgroundColor3 = Color3.fromRGB(232, 236, 250) })
	Kit.padding(16).Parent = head
	local badge = create("Frame", { Parent = head, BackgroundColor3 = C.orange, Size = UDim2.fromOffset(96, 96) }, { corner(24), Kit.stroke(C.white, 4) })
	Kit.emoji(badge, "✈️", 48, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local name = Kit.title(head, "", 30, C.ink, { Position = UDim2.fromOffset(114, 0), Size = UDim2.new(0.55, -114, 0, 36) })
	local levelText = Kit.label(head, "", 17, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(114, 40), Size = UDim2.new(0.55, -114, 0, 22) })
	local xpFill = Kit.progress(head, { Position = UDim2.fromOffset(114, 68), Size = UDim2.new(0.55, -114, 0, 12) }, C.gold)
	local repTitle = Kit.title(head, "", 20, C.ink, { Position = UDim2.fromScale(0.58, 0), Size = UDim2.new(0.42, 0, 0, 28) })
	local repFill = Kit.progress(head, { Position = UDim2.new(0.58, 0, 0, 36), Size = UDim2.new(0.42, 0, 0, 14) }, C.gold)
	local repNote = Kit.label(head, "", 14, C.muted, nil, {
		Position = UDim2.new(0.58, 0, 0, 56), Size = UDim2.new(0.42, 0, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- Cifras
	local grid = create("Frame", { Parent = area, LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 4 * 96) })
	create("UIGridLayout", {
		Parent = grid, CellSize = UDim2.new(1 / 3, -12, 0, 86), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local values = {}
	for i, t in TILES do
		local tile = Kit.card(grid, { LayoutOrder = i })
		Kit.padding(14).Parent = tile
		Kit.emoji(tile, t.emoji, 30, { Position = UDim2.fromOffset(0, 8) })
		Kit.label(tile, T(t.key), 14, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 0, 20) })
		values[t.id] = Kit.title(tile, "", 22, C.ink, { Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -46, 0, 30) })
	end

	-- Accesos directos
	local row = create("Frame", { Parent = area, LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56) }, { Kit.list(true, 10) })
	for i, link in { { "pilots", "👥 " .. T("nav_pilots"), "green" }, { "fuel", "⛽ " .. T("nav_fuel"), "blue" }, { "ipo", "🏛️ " .. T("nav_ipo"), "gold" } } do
		local b = Kit.button(row, link[2], link[3], UDim2.new(1 / 3, -7, 1, -2), function()
			ctx.openPanel(link[1])
		end, { LayoutOrder = i })
		b.TextSize = 18
	end

	return function()
		local st = ctx.state
		if not st then
			return
		end
		badge.BackgroundColor3 = Kit.airlineColor(st)
		name.Text = Config.airlineName(st.airline)
		local base, nextXp = Config.xpForLevel(st.level), Config.xpForLevel(st.level + 1)
		levelText.Text = "⭐ " .. T("top_level", { level = st.level }) .. "  ·  " .. Kit.fmtInt(st.xp - base) .. " / " .. Kit.fmtInt(nextXp - base) .. " XP"
		xpFill.Size = UDim2.fromScale(math.clamp((st.xp - base) / math.max(1, nextXp - base), 0, 1), 1)
		local rep = st.rep or 0
		repTitle.Text = "🏅 " .. T("ov_rep", { n = math.floor(rep) })
		repFill.Size = UDim2.fromScale(math.clamp(rep / 100, 0, 1), 1)
		repNote.Text = T("ov_rep_note", { mult = string.format("%.2f", Config.repMult(rep)) })
		local flying, repair = 0, 0
		for _, p in st.planes do
			if p.flight then
				flying += 1
			elseif p.condition < Config.REPAIR_BLOCK then
				repair += 1
			end
		end
		values.money.Text = Kit.fmtMoney(st.money)
		values.income.Text = (st.incomePerMin or 0) > 0 and T("per_min", { amount = Kit.fmtMoney(st.incomePerMin) }) or "—"
		values.fuel.Text = Kit.fmtInt(st.fuel or 0) .. " / " .. Kit.fmtInt(st.fuelCap or 0) .. " L"
		values.planes.Text = #st.planes .. "  (🛫 " .. flying .. (repair > 0 and ("  🔧 " .. repair) or "") .. ")"
		values.staff.Text = "👨‍✈️ " .. #st.pilots .. "   🧑‍🔧 " .. #(st.mechanics or {})
		values.dispatcher.Text = (st.dispatcher or 0) > 0 and T("dispatcher_lv", { n = st.dispatcher }) or "—"
		values.shares.Text = tostring(st.shares or 0)
		values.stamps.Text = (st.stamps or 0) .. " / " .. (st.stampsMax or 0)
		values.flights.Text = Kit.fmtInt(st.stats.flights)
		values.km.Text = Kit.fmtInt(st.stats.km)
		values.earned.Text = Kit.fmtMoney(st.stats.earned)
		values.contracts.Text = Kit.fmtInt(st.stats.contracts or 0)
	end
end

return CompanyPanel
