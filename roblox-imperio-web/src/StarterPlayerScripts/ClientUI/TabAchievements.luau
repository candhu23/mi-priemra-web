--[[
	TabAchievements (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña LOGROS (bonus permanentes por niveles)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local T = ui.T
	local THEME = ui.THEME
	local fmt = ui.fmt
	local num = ui.num
	local makeLabel = ui.makeLabel
	local makeCard = ui.makeCard
	local makeProgressBar = ui.makeProgressBar
	local pages = ui.pages
	local renderers = ui.renderers

	local achievementsPage = pages.achievements
	local achievementsHeader = makeCard(achievementsPage, 66, 1, Color3.fromRGB(120, 53, 15))
	local achievementsTitle = makeLabel(achievementsHeader, "", 0, 22, 18, THEME.text, true)
	local achievementsInfo = makeLabel(achievementsHeader, "", 24, 30, 13, THEME.yellow, true)
	achievementsInfo.TextWrapped = true
	achievementsInfo.TextTruncate = Enum.TextTruncate.None
	local BONUS_NAMES = { money = "dinero", click = "clic", visits = "visitas", sale = "ventas", work = "trabajo", rare = "webs raras" }
	local achievementCards = {}
	for i, achievement in Config.Achievements do
		local card = makeCard(achievementsPage, 70, 1 + i)
		local title = makeLabel(card, "", 0, 20, 15, THEME.text, true)
		local _back, fill, text = makeProgressBar(card, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 16), THEME.orange)
		local info = makeLabel(card, "", 44, 16, 12, THEME.muted)
		achievementCards[achievement.id] = { title = title, fill = fill, text = text, info = info }
	end

	renderers.achievements = function(s)
		local tiersDone, tiersTotal = 0, 0
		local totals = {}
		for _, achievement in Config.Achievements do
			local slot = achievementCards[achievement.id]
			local tier = Config.achievementTier(s, achievement)
			local value = achievement.value(s)
			tiersDone += tier
			tiersTotal += #achievement.tiers
			totals[achievement.bonus] = (totals[achievement.bonus] or 0) + tier * achievement.per
			local medal = if tier > 0 then Config.ACHIEVEMENT_TIER_EMOJIS[tier] .. " " else ""
			slot.title.Text = string.format("%s%s %s · %d/%d", medal, achievement.emoji, T(achievement.name), tier, #achievement.tiers)
			slot.title.TextColor3 = if tier >= #achievement.tiers then THEME.yellow else THEME.text
			local nextTarget = achievement.tiers[tier + 1]
			local bonusName = T(BONUS_NAMES[achievement.bonus])
			if nextTarget then
				local previous = if tier > 0 then achievement.tiers[tier] else 0
				slot.fill.Size = UDim2.fromScale(math.clamp((value - previous) / math.max(nextTarget - previous, 1), 0, 1), 1)
				slot.text.Text = (if nextTarget >= 1e5 then fmt(value) .. " / " .. fmt(nextTarget) else num(value) .. " / " .. num(nextTarget))
				slot.info.Text = T("%s · siguiente nivel: +%d%% %s (ahora +%d%%)", T(achievement.text), math.floor(achievement.per * 100 + 0.5), bonusName,
					math.floor(tier * achievement.per * 100 + 0.5))
			else
				slot.fill.Size = UDim2.fromScale(1, 1)
				slot.text.Text = T("MÁX")
				slot.info.Text = T("%s · ¡completo! +%d%% %s para siempre", T(achievement.text), math.floor(tier * achievement.per * 100 + 0.5), bonusName)
			end
		end
		achievementsTitle.Text = T("🏅 Logros · %d/%d niveles", tiersDone, tiersTotal)
		local bonusParts = {}
		for _, kind in { "money", "click", "visits", "sale", "work", "rare" } do
			if (totals[kind] or 0) > 0 then
				table.insert(bonusParts, string.format("+%d%% %s", math.floor(totals[kind] * 100 + 0.5), T(BONUS_NAMES[kind])))
			end
		end
		achievementsInfo.Text = if #bonusParts > 0 then T("Bonus permanentes: %s", table.concat(bonusParts, " · "))
			else T("Cada nivel de logro da un bonus PERMANENTE que no se pierde nunca.")

	end
end
