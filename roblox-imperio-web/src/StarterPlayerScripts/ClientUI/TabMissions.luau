--[[
	TabMissions (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña MISIONES (diarias + objetivos que se reclaman)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local T = ui.T
	local THEME = ui.THEME
	local fmt = ui.fmt
	local num = ui.num
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeProgressBar = ui.makeProgressBar
	local sendAction = ui.sendAction
	local window = ui.window
	local pages = ui.pages
	local renderers = ui.renderers
	local pulseMoney = ui.pulseMoney

	local missionsPage = pages.missions

	local dailyHeader = makeCard(missionsPage, 66, 1, Color3.fromRGB(66, 52, 12))
	local dailyTitle = makeLabel(dailyHeader, "📅 Misiones diarias", 0, 22, 18, THEME.text, true)
	local dailyBonus = makeLabel(dailyHeader, "", 24, 18, 14, THEME.yellow, true)

	local TIER_COLORS = { THEME.green, THEME.accent, THEME.purple }
	local dailyCards = {}
	for i = 1, Config.DAILY_MISSION_COUNT do
		local card = makeCard(missionsPage, 96, 1 + i)
		local title = makeLabel(card, "", 0, 20, 16, THEME.text, true)
		local _back, fill, text = makeProgressBar(card, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 18), TIER_COLORS[(i + 1) // 2] or THEME.accent)
		local button = makeButton(card, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
			sendAction("claimDailyMission", i, nil, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
		button.Position = UDim2.fromOffset(0, 46)
		dailyCards[i] = { card = card, title = title, fill = fill, text = text, button = button }
	end

	-- Misiones semanales
	local weeklyHeader = makeCard(missionsPage, 66, 20, Color3.fromRGB(76, 29, 149))
	local weeklyTitle = makeLabel(weeklyHeader, "", 0, 22, 18, THEME.text, true)
	local weeklyBonus = makeLabel(weeklyHeader, "", 24, 18, 14, THEME.yellow, true)
	local weeklyCards = {}
	for i = 1, Config.WEEKLY_MISSION_COUNT do
		local card = makeCard(missionsPage, 96, 20 + i)
		local title = makeLabel(card, "", 0, 20, 16, THEME.text, true)
		local _back, fill, text = makeProgressBar(card, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 18), THEME.purple)
		local button = makeButton(card, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
			sendAction("claimWeeklyMission", i, nil, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
		button.Position = UDim2.fromOffset(0, 46)
		weeklyCards[i] = { card = card, title = title, fill = fill, text = text, button = button }
	end

	local goalsHeader = makeCard(missionsPage, 82, 50, Color3.fromRGB(30, 58, 138))
	local goalsTitle = makeLabel(goalsHeader, "🏆 Objetivos", 0, 22, 18, THEME.text, true)
	local tutorialButton = makeButton(goalsHeader, "📖 Ver el tutorial otra vez", THEME.card, UDim2.new(1, 0, 0, 30), function()
		window.Visible = false
		ui.startTutorial()
	end)
	tutorialButton.Position = UDim2.fromOffset(0, 32)

	local goalCards = {}
	for _, goal in Config.Goals do
		local card = makeCard(missionsPage, 92, 100)
		local title = makeLabel(card, goal.text, 0, 20, 16, THEME.text, true) -- se traduce solo
		local _back, fill, text = makeProgressBar(card, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 16), THEME.yellow)
		local button = makeButton(card, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
			sendAction("claimGoal", goal.id, nil, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
		button.Position = UDim2.fromOffset(0, 44)
		goalCards[goal.id] = { card = card, title = title, fill = fill, text = text, button = button }
	end

	renderers.missions = function(s)
		local daily = s.dailyMissions
		dailyTitle.Text = T("📅 Misiones diarias · nuevas en %s", Config.formatTime(daily.resetIn))
		dailyBonus.Text = if daily.bonusGiven then T("🏆 ¡Bonus de hoy conseguido!")
			else T("🎁 Completa las %d: 🚀 Boost x2 %d min", Config.DAILY_MISSION_COUNT, Config.DAILY_ALL_BONUS_BOOST_MINUTES)
		for i, slot in dailyCards do
			local mission = daily.list[i]
			slot.card.Visible = mission ~= nil
			if mission then
				local def = Config.DailyMissionById[mission.id]
				local tier = Config.DailyMissionRewards[mission.tier]
				slot.title.Text = string.format("%s · %s", T(tier.name), T(def.text, mission.target))
				slot.fill.Size = UDim2.fromScale(math.clamp(mission.progress / mission.target, 0, 1), 1)
				slot.text.Text = num(mission.progress) .. " / " .. num(mission.target)
				local amount = daily.rewards[mission.tier] or 0
				if mission.claimed then
					setButton(slot.button, T("✓ Reclamada"), false, THEME.green)
					slot.button:SetAttribute("PaintColor", THEME.green)
				elseif mission.progress >= mission.target then
					setButton(slot.button, T("🎁 Reclamar %s", fmt(amount)), true, THEME.green)
				else
					setButton(slot.button, T("Premio: %s", fmt(amount)), false)
				end
			end
		end

		-- Semanales
		local weekly = s.weeklyMissions
		weeklyTitle.Text = T("🗓️ Misiones semanales · nuevas en %s", Config.formatTime(weekly.resetIn))
		weeklyBonus.Text = if weekly.bonusGiven then T("🏆 ¡Bonus de la semana conseguido!")
			else T("🎁 Completa las %d: +%d 💡 patentes y 🚀 Boost x2 %d min", Config.WEEKLY_MISSION_COUNT, Config.WEEKLY_ALL_PATENTS, Config.WEEKLY_ALL_BOOST_MINUTES)
		for i, slot in weeklyCards do
			local mission = weekly.list[i]
			slot.card.Visible = mission ~= nil
			if mission then
				local def = Config.WeeklyMissionById[mission.id]
				slot.title.Text = T(def.text, mission.target)
				slot.fill.Size = UDim2.fromScale(math.clamp(mission.progress / mission.target, 0, 1), 1)
				slot.text.Text = num(mission.progress) .. " / " .. num(mission.target)
				if mission.claimed then
					setButton(slot.button, T("✓ Reclamada"), false, THEME.green)
					slot.button:SetAttribute("PaintColor", THEME.green)
				elseif mission.progress >= mission.target then
					setButton(slot.button, T("🎁 Reclamar %s", fmt(weekly.reward)), true, THEME.green)
				else
					setButton(slot.button, T("Premio: %s + %d ⭐", fmt(weekly.reward), Config.WeeklyMissionReward.seasonXp), false)
				end
			end
		end

		local claimable, done = 0, 0
		for i, goal in Config.Goals do
			local slot = goalCards[goal.id]
			local claimed = s.goals[goal.id] == true
			local value = math.min(goal.value(s), goal.target)
			local complete = value >= goal.target
			local rewardText = if goal.reward > 0 then fmt(goal.reward) else T("¡acciones!")
			slot.fill.Size = UDim2.fromScale(math.clamp(value / goal.target, 0, 1), 1)
			slot.text.Text = if goal.target >= 1000 then fmt(value) .. " / " .. fmt(goal.target) else num(value) .. " / " .. num(goal.target)
			if claimed then
				done += 1
				slot.card.LayoutOrder = 400 + i
				slot.title.TextColor3 = THEME.muted
				setButton(slot.button, T("✓ Reclamado"), false, THEME.green)
				slot.button:SetAttribute("PaintColor", THEME.green)
			elseif complete then
				claimable += 1
				slot.card.LayoutOrder = 100 + i
				slot.title.TextColor3 = THEME.yellow
				setButton(slot.button, T("🎁 Reclamar %s", rewardText), true, THEME.green)
			else
				slot.card.LayoutOrder = 200 + i
				slot.title.TextColor3 = THEME.text
				setButton(slot.button, T("Premio: %s", rewardText), false)
			end
		end
		goalsTitle.Text = T("🏆 Objetivos · %d/%d completados%s", done, #Config.Goals, if claimable > 0 then T(" · %d por reclamar", claimable) else "")
	end
end
