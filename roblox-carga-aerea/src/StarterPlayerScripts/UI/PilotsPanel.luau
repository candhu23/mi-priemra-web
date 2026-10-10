--[[
	Ventana PILOTOS: plantilla (suben de nivel volando) y fichajes.
	Sin sorteos: cada candidato muestra sus estrellas y su precio ANTES de ficharlo.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local PilotsPanel = {}

local function avatar(parent: Instance, pilot: any, size: number, props: { [string]: any }?): Frame
	local ring = pilot.stars >= 5 and C.gold or (pilot.stars >= 4 and C.purple or (pilot.stars >= 3 and C.blue or C.grey))
	local box = create("Frame", Kit.merge({ Parent = parent, BackgroundColor3 = C.white, Size = UDim2.fromOffset(size, size) }, props), {
		corner(), Kit.stroke(ring, 4),
	})
	Kit.emoji(box, pilot.avatar, math.floor(size * 0.6), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	return box
end
PilotsPanel.avatar = avatar

function PilotsPanel.build(content: Frame): () -> ()
	local tab = "roster"
	local currentTab = ""
	local cache: { [any]: Kit.Entry } = {}
	local render: () -> ()
	local _, paintTabs = Kit.tabs(content, {
		{ id = "roster", text = "👨‍✈️ " .. T("tab_roster") },
		{ id = "hire", text = "🤝 " .. T("tab_hire") },
	}, function() return tab end, function(id)
		tab = id
		render()
	end)
	local roster = Kit.pill(content, "", C.green, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 10), TextSize = 16, Size = UDim2.fromOffset(0, 28) })
	-- Cabecera de fichajes: cuenta atrás y buscar ya
	local hireBar = Kit.card(content, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 60), Visible = false })
	Kit.padding(14, 10, 0, 0).Parent = hireBar
	local nextText = Kit.label(hireBar, "", 17, C.ink, Kit.FONT_BOLD, { Size = UDim2.new(1, -260, 0, 30), Position = UDim2.fromOffset(0, 4) })
	Kit.label(hireBar, T("hire_note"), 13, C.muted, nil, { Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(0, 32) })
	local searchBtn = Kit.button(hireBar, "", "blue", UDim2.fromOffset(240, 46), function()
		ctx.act("searchCandidates")
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
	searchBtn.TextSize = 17
	local area = Kit.scroll(content, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58) })
	local emptyText = Kit.label(content, T("no_pilots"), 18, C.muted, nil, {
		Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
	})

	local function buildPilot(pilot: any): Kit.Entry
		local root = Kit.card(area)
		Kit.padding(12).Parent = root
		avatar(root, pilot, 70)
		Kit.title(root, pilot.name, 19, C.ink, { Position = UDim2.fromOffset(82, 0), Size = UDim2.new(1, -82, 0, 24) })
		Kit.label(root, Kit.stars(pilot.stars), 18, C.goldDark, Kit.FONT_BOLD, { Position = UDim2.fromOffset(82, 24), Size = UDim2.new(1, -82, 0, 22), RichText = true })
		Kit.label(root, Kit.traitName(pilot.trait), 14, C.purple, Kit.FONT_BOLD, { Position = UDim2.fromOffset(82, 82), Size = UDim2.new(1, -82, 0, 18) })
		local lvl = Kit.label(root, "", 15, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(82, 48), Size = UDim2.new(1, -82, 0, 20) })
		local xpFill = Kit.progress(root, { Position = UDim2.new(0, 82, 0, 72), Size = UDim2.new(1, -82, 0, 8) }, C.gold)
		local status = Kit.pill(root, "", C.green, { Position = UDim2.new(0, 0, 1, -28) })
		local fire = Kit.button(root, T("btn_fire"), "white", UDim2.fromOffset(110, 36), function()
			ctx.openModal(T("fire_title", { name = pilot.name }), function() end, {
				{ text = T("btn_cancel"), style = "white" },
				{ text = T("btn_fire"), style = "red", onClick = function()
					ctx.act("firePilot", pilot.id)
				end },
			})
		end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1) })
		fire.TextSize = 15
		return {
			root = root,
			update = function(p: any)
				local busy = Kit.pilotBusy(p.id)
				status.Text = busy and ("✈️ " .. T("pilot_flying")) or ("✅ " .. T("pilot_free"))
				status.BackgroundColor3 = busy and C.blue or C.green
				lvl.Text = T("pilot_level", { level = p.level, bonus = math.floor(Config.pilotBonus(p.stars, p.level) * 100 + 0.5) })
				local a, b = Config.pilotXpForLevel(p.level), Config.pilotXpForLevel(math.min(p.level + 1, Config.PILOT_MAX_LEVEL))
				xpFill.Size = UDim2.fromScale(p.level >= Config.PILOT_MAX_LEVEL and 1 or math.clamp((p.flights - a) / math.max(1, b - a), 0, 1), 1)
				Kit.setButton(fire, nil, not busy)
			end,
		}
	end

	local function buildCandidate(c: any): Kit.Entry
		local root = Kit.card(area)
		Kit.padding(14).Parent = root
		avatar(root, c, 96, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0) })
		Kit.title(root, c.name, 21, C.ink, { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center })
		Kit.label(root, Kit.stars(c.stars), 26, C.goldDark, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, RichText = true })
		Kit.label(root, Kit.traitName(c.trait) .. ": " .. T("trait_" .. tostring(c.trait) .. "_d"), 14, C.purple, Kit.FONT_BOLD, {
			Position = UDim2.fromOffset(0, 186), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
		})
		Kit.label(root, T("pilot_bonus", { p = math.floor(Config.StarBonus[c.stars] * 100) }), 16, C.greenDark, Kit.FONT_BOLD, {
			Position = UDim2.fromOffset(0, 162), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center,
		})
		local hire = Kit.button(root, "🤝 " .. T("btn_hire", { cost = Kit.fmtMoney(c.price) }), "green", UDim2.new(1, 0, 0, 50), function()
			local ok, extra = ctx.act("hire", c.id)
			if ok and extra and extra.pilot then
				ctx.celebratePilot(extra.pilot)
			end
		end, { Position = UDim2.new(0, 0, 1, -50) })
		hire.TextSize = 18
		return {
			root = root,
			update = function(x: any)
				local st = ctx.state
				Kit.setButton(hire, nil, st.money >= x.price and #st.pilots < Config.MAX_PILOTS)
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
				if k:IsA("UIGridLayout") then
					k:Destroy()
				end
			end
			Kit.grid(area, tab == "roster" and 150 or 300, 3)
			hireBar.Visible = tab == "hire"
			area.Position = UDim2.fromOffset(0, tab == "hire" and 128 or 58)
			area.Size = UDim2.new(1, 0, 1, tab == "hire" and -128 or -58)
		end
		roster.Text = "👨‍✈️ " .. T("roster", { n = #st.pilots, max = Config.MAX_PILOTS })
		if tab == "roster" then
			Kit.syncList(cache, st.pilots, function(p) return p.id end, buildPilot)
			emptyText.Visible = #st.pilots == 0
		else
			emptyText.Visible = false
			Kit.syncList(cache, st.candidates, function(c) return c.id end, buildCandidate)
			local first = st.candidates[1]
			if first and cache[first.id] then
				ctx.targets.hire_first = (cache[first.id].root :: any):FindFirstChild("Face", true)
			end
			nextText.Text = "⏱️ " .. T("hire_next", { time = Kit.fmtTime(st.candidatesIn) })
			local cost = Config.searchCost(st.level)
			Kit.setButton(searchBtn, "🔄 " .. T("btn_search", { cost = Kit.fmtMoney(cost) }), st.money >= cost)
		end
	end
	ctx.pilotsTab = function(id: string)
		tab = id
		render()
	end
	return render
end

return PilotsPanel
