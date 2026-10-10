--[[
	Ventanas pequeñas: RANKING (top 20 de la semana y de siempre) y AJUSTES (tu aerolínea, idioma,
	sonido, tutorial y créditos).
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local PlaneArt = require(script.Parent:WaitForChild("PlaneArt"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create

local SystemPanels = {}

function SystemPanels.ranking(content: Frame): () -> ()
	local tab = "week"
	local lists: { week: { any }, all: { any } } = { week = {}, all = {} }
	local draw: () -> ()
	local _, paintTabs = Kit.tabs(content, {
		{ id = "week", text = "📅 " .. T("tab_week") },
		{ id = "all", text = "🏆 " .. T("tab_alltime") },
	}, function() return tab end, function(id)
		tab = id
		draw()
	end)
	local area = Kit.scroll(content, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58) })
	Kit.list(false, 8).Parent = area
	local mine = Kit.card(area, { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 0, BackgroundColor3 = Color3.fromRGB(255, 244, 204) })
	Kit.padding(16, 16, 0, 0).Parent = mine
	local mineText = Kit.title(mine, "", 20, C.ink, { Size = UDim2.fromScale(1, 1) })
	local rows: { GuiObject } = {}
	local loaded = 0
	function draw()
		paintTabs()
		for _, r in rows do
			r:Destroy()
		end
		table.clear(rows)
		local list = tab == "week" and lists.week or lists.all
		if #list == 0 then
			table.insert(rows, Kit.label(area, T("ranking_empty"), 17, C.muted, nil, { LayoutOrder = 1, TextWrapped = true, Size = UDim2.new(1, 0, 0, 50) }))
		end
		for i, e in list do
			local row = Kit.card(area, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = i + 1 })
			Kit.padding(16, 16, 0, 0).Parent = row
			local medal = ({ "🥇", "🥈", "🥉" })[i] or ("#" .. i)
			Kit.title(row, medal, 22, C.ink, { Size = UDim2.new(0, 60, 1, 0) })
			Kit.title(row, e.name, 20, C.ink, { Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -260, 1, 0) })
			Kit.title(row, Kit.fmtMoney(e.earned), 20, C.greenDark, {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 190, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
			})
			table.insert(rows, row)
		end
	end
	local function load()
		if os.clock() - loaded < 20 then
			return
		end
		loaded = os.clock()
		local ok, extra = ctx.act("getTop")
		lists.all = ok and extra and extra.top or {}
		lists.week = ok and extra and extra.week or {}
		draw()
	end
	return function()
		local st = ctx.state
		if st then
			local airline = Config.airlineName(st.airline)
			mineText.Text = "✈️ " .. airline .. " · " .. T("ranking_you", { amount = Kit.fmtMoney(st.stats.earned) })
			if ctx.panel == "ranking" then
				load()
			end
		end
	end
end

function SystemPanels.settings(content: Frame): () -> ()
	local area = Kit.scroll(content)
	Kit.list(false, 12).Parent = area
	local warn = Kit.card(area, { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(255, 226, 226), LayoutOrder = 0, Visible = false })
	Kit.label(warn, "⚠️ " .. T("warn_nosave"), 17, C.red, Kit.FONT_BOLD, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), TextWrapped = true })

	-- Tu aerolínea: nombre por piezas y color de los aviones (lo ven los demás en el mapa)
	local airCard = Kit.card(area, { Size = UDim2.new(1, 0, 0, 196), LayoutOrder = 1 })
	Kit.padding(16).Parent = airCard
	Kit.title(airCard, "✈️ " .. T("set_airline"), 22, C.ink, { Size = UDim2.new(1, -200, 0, 28) })
	local planeBox = create("Frame", {
		Parent = airCard, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(150, 92),
		BackgroundColor3 = Color3.fromRGB(214, 238, 252),
	}, { Kit.corner(14) })
	local airName = Kit.title(airCard, "", 26, C.ink, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, -170, 0, 32) })
	local partRow = create("Frame", { Parent = airCard, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, -170, 0, 44) }, {
		Kit.list(true, 8),
	})
	local colorRow = create("Frame", { Parent = airCard, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 0, 40) }, {
		Kit.list(true, 8),
	})
	local function current(): { number }
		local a = ctx.state and ctx.state.airline or {}
		return { a.a or 1, a.b or 1, a.c or 1, a.color or 1 }
	end
	local function send(v: { number })
		ctx.act("setAirline", { v[1], v[2], v[3] }, v[4])
	end
	local partButtons = {}
	for i = 1, 3 do
		partButtons[i] = Kit.button(partRow, "", "white", UDim2.new(1 / 3, -6, 1, 0), function()
			local v = current()
			v[i] = v[i] % #Config.AirlineParts[i] + 1
			send(v)
		end, { LayoutOrder = i })
		partButtons[i].TextSize = 17
	end
	local swatches = {}
	for i, color in Config.AirlineColors do
		local sw = create("TextButton", {
			Parent = colorRow, LayoutOrder = i, BackgroundColor3 = color, Size = UDim2.fromOffset(40, 40), Text = "", AutoButtonColor = false,
			FontFace = Kit.FONT_BODY, TextSize = 18,
		}, { Kit.corner(), Kit.stroke(C.white, 3) })
		sw.Activated:Connect(function()
			Kit.playSound("click")
			local v = current()
			v[4] = i
			send(v)
		end)
		swatches[i] = sw
	end
	local planeModel, planeColor = "", 0

	local langCard = Kit.card(area, { Size = UDim2.new(1, 0, 0, 112), LayoutOrder = 2 })
	Kit.padding(16).Parent = langCard
	Kit.title(langCard, "🌍 " .. T("set_language"), 22, C.ink, { Size = UDim2.new(1, 0, 0, 28) })
	local langRow = create("Frame", { Parent = langCard, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 48) }, {
		Kit.list(true, 10),
	})
	local langButtons = {}
	for i, opt in { { "", "🌐 " .. T("lang_auto") }, { "en", "🇬🇧 English" }, { "es", "🇪🇸 Español" } } do
		local b = Kit.button(langRow, opt[2], "white", UDim2.fromOffset(220, 48), function()
			ctx.act("setLang", opt[1])
			ctx.lang = opt[1] ~= "" and opt[1] or ctx.detectLang()
			ctx.rebuild()
		end, { LayoutOrder = i })
		langButtons[opt[1]] = b
	end

	local soundCard = Kit.card(area, { Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 3 })
	Kit.padding(16).Parent = soundCard
	Kit.title(soundCard, "🔊 " .. T("set_sound"), 22, C.ink, { Size = UDim2.new(0.5, 0, 1, 0) })
	local soundBtn = Kit.button(soundCard, "", "white", UDim2.fromOffset(130, 46), function()
		ctx.act("setMuted", not ctx.state.settings.muted)
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })

	local tutorialCard = Kit.card(area, { Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 4 })
	Kit.padding(16).Parent = tutorialCard
	Kit.title(tutorialCard, "🎓 " .. T("set_tutorial"), 22, C.ink, { Size = UDim2.new(0.6, 0, 1, 0) })
	local tutBtn = Kit.button(tutorialCard, T("btn_skip"), "white", UDim2.fromOffset(200, 46), function()
		ctx.act("tutorial", "skip")
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })

	local about = Kit.card(area, { Size = UDim2.new(1, 0, 0, 96), LayoutOrder = 5 })
	Kit.padding(16).Parent = about
	local version = Kit.title(about, "", 18, C.ink, { Size = UDim2.new(1, 0, 0, 24) })
	Kit.label(about, T("credits"), 15, C.muted, nil, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })

	return function()
		local st = ctx.state
		if not st then
			return
		end
		warn.Visible = st.canSave == false
		local v = current()
		airName.Text = Config.airlineName(st.airline)
		for i, b in partButtons do
			Kit.setButton(b, "🔄 " .. Config.AirlineParts[i][v[i]], true)
		end
		for i, sw in swatches do
			local locked = i == Config.GOLD_COLOR and (st.ipoCount or 0) < 1
			sw.Text = locked and "🔒" or (i == v[4] and "✔" or "")
			sw.TextColor3 = C.white
			local stroke = sw:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = i == v[4] and C.ink or C.white
			end
		end
		-- Avión de muestra con tu color (se redibuja solo si cambia)
		local best = "sparrow"
		for _, p in st.planes do
			if Config.PlaneById[p.model].price > Config.PlaneById[best].price then
				best = p.model
			end
		end
		if best ~= planeModel or v[4] ~= planeColor then
			planeModel, planeColor = best, v[4]
			for _, k in planeBox:GetChildren() do
				if not k:IsA("UICorner") then
					k:Destroy()
				end
			end
			PlaneArt.top(planeBox, best, 84, false, { Position = UDim2.fromScale(0.5, 0.5) }, Config.AirlineColors[v[4]])
		end
		for code, b in langButtons do
			local active = (st.settings.lang or "") == code
			b.BackgroundColor3 = active and C.orange or C.white
			b.TextColor3 = active and C.white or C.ink
		end
		Kit.setButton(soundBtn, st.settings.muted and ("🔇 " .. T("off")) or ("🔊 " .. T("on")), true)
		Kit.setButton(tutBtn, nil, st.tutorial ~= 99)
		version.Text = "AeroCarga · " .. T("set_version", { v = st.version })
	end
end

return SystemPanels
