--[[
	Ventana MISIONES: 3 misiones diarias, cadena de objetivos y premio diario (racha de 7 días).
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local MissionsPanel = {}

local MISSION_EMOJI = { deliveries = "📦", km = "🛫", express = "⚡", tons = "⚖️", ["local"] = "🧺", earn = "💰", upgrades = "🛠️" }

function MissionsPanel.build(content: Frame): () -> ()
	local tab = "missions"
	local currentTab = ""
	local render: () -> ()
	local _, paintTabs = Kit.tabs(content, {
		{ id = "missions", text = "🎯 " .. T("tab_missions") },
		{ id = "goals", text = "🏁 " .. T("tab_goals") },
		{ id = "daily", text = "🎁 " .. T("tab_daily") },
	}, function() return tab end, function(id)
		tab = id
		render()
	end)
	local area = Kit.scroll(content, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58) })
	local cache: { [any]: Kit.Entry } = {}
	local dailyTiles: { Frame } = {}
	local dailyBtn: TextButton
	local bonusLabel: TextLabel

	local function buildMission(m: any): Kit.Entry
		local root = Kit.card(area, { Size = UDim2.new(1, 0, 0, 100) })
		Kit.padding(14).Parent = root
		local box = create("Frame", { Parent = root, BackgroundColor3 = C.white, Size = UDim2.fromOffset(72, 72) }, { corner(18) })
		Kit.emoji(box, MISSION_EMOJI[m.id] or "🎯", 36, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		local text = Kit.title(root, "", 20, C.ink, { Position = UDim2.fromOffset(88, 2), Size = UDim2.new(1, -330, 0, 26) })
		local fill = Kit.progress(root, { Position = UDim2.fromOffset(88, 36), Size = UDim2.new(1, -330, 0, 14) }, C.green)
		local prog = Kit.label(root, "", 14, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(88, 54), Size = UDim2.new(1, -330, 0, 18) })
		local btn = Kit.button(root, "", "green", UDim2.fromOffset(220, 54), function()
			ctx.act("claimMission", m.index)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		return {
			root = root,
			update = function(x: any)
				local target = x.stat == "earned" and Kit.fmtMoney(x.target) or Kit.fmtInt(x.target)
				local progress = x.stat == "earned" and Kit.fmtMoney(x.progress) or Kit.fmtInt(x.progress)
				text.Text = T("mission_" .. x.id, { n = target })
				fill.Size = UDim2.fromScale(math.clamp(x.progress / x.target, 0, 1), 1)
				prog.Text = progress .. " / " .. target
				if x.claimed then
					Kit.setButton(btn, "✅ " .. T("claimed"), false)
				else
					Kit.setButton(btn, "🎁 " .. Kit.fmtMoney(x.reward), x.progress >= x.target)
				end
			end,
		}
	end

	local function buildGoal(g: any): Kit.Entry
		local root = Kit.card(area, { Size = UDim2.new(1, 0, 0, 74) })
		Kit.padding(12).Parent = root
		local text = Kit.title(root, Hud.goalText(g), 18, C.ink, { Size = UDim2.new(1, -260, 0, 24) })
		local fill = Kit.progress(root, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, -260, 0, 12) }, C.blue)
		local btn = Kit.button(root, "", "green", UDim2.fromOffset(220, 48), function()
			ctx.act("claimGoal", g.id)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		return {
			root = root,
			update = function()
				local st = ctx.state
				local value = Hud.goalValue(st, g.stat)
				text.Text = Hud.goalText(g)
				fill.Size = UDim2.fromScale(math.clamp(value / g.target, 0, 1), 1)
				local reward = math.floor(st.rewardScale * g.reward / 100) * 100
				if st.goals[g.id] then
					Kit.setButton(btn, "✅ " .. T("claimed"), false)
				else
					Kit.setButton(btn, "🎁 " .. Kit.fmtMoney(reward), value >= g.target)
				end
			end,
		}
	end

	local function buildDaily()
		local row = create("Frame", { Parent = area, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 1 }, {
			Kit.list(true, 8),
		})
		local days = #Config.DailyRewards
		for day = 1, days do
			local tile = Kit.card(row, { LayoutOrder = day, Size = UDim2.new(1 / days, -8 * (days - 1) / days, 1, 0) })
			Kit.title(tile, T("day_n", { n = day }), 16, C.muted, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
			Kit.emoji(tile, day == #Config.DailyRewards and "🏆" or "💰", 38, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34) })
			Kit.title(tile, "", 16, C.greenDark, { Name = "Amount", Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
			if day == #Config.DailyRewards then
				Kit.label(tile, "⚡ x2 30 min", 13, C.goldDark, Kit.FONT_BOLD, { Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
			end
			dailyTiles[day] = tile
		end
		dailyBtn = Kit.button(area, "", "gold", UDim2.new(1, 0, 0, 64), function()
			ctx.act("claimDaily")
		end, { LayoutOrder = 2 })
		dailyBtn.TextSize = 26
		Kit.label(area, T("daily_note"), 15, C.muted, nil, { LayoutOrder = 3, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40) })
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
			table.clear(dailyTiles)
			for _, k in area:GetChildren() do
				if not k:IsA("UIPadding") then
					k:Destroy()
				end
			end
			Kit.list(false, 10).Parent = area
			if tab == "daily" then
				buildDaily()
			elseif tab == "missions" then
				bonusLabel = Kit.label(area, "", 16, C.goldDark, Kit.FONT_BOLD, { LayoutOrder = 99, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40) })
			end
		end
		if tab == "missions" then
			local list = {}
			for i, m in st.missions.list do
				local x = table.clone(m)
				x.index = i
				table.insert(list, x)
			end
			Kit.syncList(cache, list, function(m) return m.index .. m.id end, buildMission)
			bonusLabel.Text = st.missions.bonusGiven and ("✅ " .. T("missions_bonus_done")) or ("⚡ " .. T("missions_bonus", { min = Config.MISSIONS_BOOST_MIN }))
		elseif tab == "goals" then
			-- Primero los que se pueden reclamar, luego los que faltan y al final los hechos
			local list = {}
			for i, g in Config.Goals do
				local done = st.goals[g.id] and 2 or (Hud.goalValue(st, g.stat) >= g.target and 0 or 1)
				table.insert(list, { g = g, order = done * 1000 + i })
			end
			table.sort(list, function(a, b) return a.order < b.order end)
			local show = {}
			for i = 1, math.min(#list, 30) do
				show[i] = list[i].g
			end
			Kit.syncList(cache, show, function(g) return g.id end, buildGoal)
		else
			local nextDay = st.daily.lost and 1 or (st.daily.streak % #Config.DailyRewards + 1)
			for day, tile in dailyTiles do
				local amount = math.floor(st.rewardScale * Config.DailyRewards[day])
				local amountLabel = tile:FindFirstChild("Amount") :: TextLabel
				amountLabel.Text = Kit.fmtMoney(amount)
				local done = not st.daily.lost and day <= st.daily.streak and not (st.daily.available and st.daily.streak == #Config.DailyRewards)
				local isNext = st.daily.available and day == nextDay
				tile.BackgroundColor3 = isNext and Color3.fromRGB(255, 244, 204) or (done and Color3.fromRGB(220, 247, 230) or C.soft)
			end
			Kit.setButton(dailyBtn, st.daily.available and ("🎁 " .. T("btn_claim_day", { n = nextDay })) or ("⏳ " .. T("daily_wait")), st.daily.available)
		end
	end
	ctx.missionsTabSet = function(id: string)
		tab = id
		render()
	end
	return render
end

return MissionsPanel
