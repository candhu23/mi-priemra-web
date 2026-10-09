--[[
	TabSeason (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña PASE (pase de temporada: 30 niveles gratis y premium)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local MarketplaceService = ui.MarketplaceService
	local Config = ui.Config
	local player = ui.player
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeProgressBar = ui.makeProgressBar
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers
	local pulseMoney = ui.pulseMoney

	local seasonPage = pages.season
	local seasonProduct = Config.ProductByKey.seasonPremium

	local seasonHeader = makeCard(seasonPage, 156, 1, Color3.fromRGB(49, 46, 129))
	local seasonTitle = makeLabel(seasonHeader, "", 0, 24, 19, THEME.text, true)
	local seasonInfo = makeLabel(seasonHeader, "", 26, 18, 14, THEME.yellow, true)
	local _seasonBack, seasonFill, seasonText = makeProgressBar(seasonHeader, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 18), Color3.fromRGB(129, 140, 248))
	makeLabel(seasonHeader, "Ganas ⭐ con misiones diarias, objetivos, premios por tiempo, ventas y metas del servidor.", 70, 18, 13, THEME.muted)
	local premiumLabel = makeLabel(seasonHeader, "", 90, 18, 13, THEME.muted, true)
	local premiumButton = makeButton(seasonHeader, "", THEME.yellow, UDim2.new(1, 0, 0, 30), function()
		if seasonProduct.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, seasonProduct.id)
		end
	end)
	premiumButton.Position = UDim2.fromOffset(0, 112)

	-- Cómo se llama un premio
	local function rewardText(reward): string
		if reward.kind == "cash" then
			return T("💰 %d min de ingresos", reward.minutes)
		elseif reward.kind == "boost" then
			return T("🚀 Boost x2 %d min", reward.minutes)
		elseif reward.kind == "patents" then
			return T("💡 %d patentes", reward.amount)
		elseif reward.ticket == "legendary" then
			return T("👑 Contrato Legendario")
		end
		return T("🎯 Headhunter Premium")
	end

	local tierRows = {}
	for tier = 1, Config.SEASON_TIERS do
		local card = makeCard(seasonPage, 46, 10 + tier)
		local label = makeLabel(card, "", 0, 26, 16, THEME.text, true)
		label.Size = UDim2.new(0.16, 0, 0, 26)
		bindText(label, function()
			return T("Nivel %d", tier)
		end)
		local free = makeButton(card, "", THEME.green, UDim2.new(0.42, -6, 0, 26), function()
			sendAction("claimSeason", tier, false, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
		free.Position = UDim2.fromScale(0.16, 0)
		local premium = makeButton(card, "", THEME.yellow, UDim2.new(0.42, 0, 0, 26), function()
			sendAction("claimSeason", tier, true, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
		premium.Position = UDim2.fromScale(0.58, 0)
		tierRows[tier] = { label = label, free = free, premium = premium }
	end

	renderers.season = function(s)
		local season = s.season
		local tier = math.min(Config.SEASON_TIERS, season.xp // Config.SEASON_XP_PER_TIER)
		seasonTitle.Text = T("🎫 %s · termina en %s", T(Config.seasonName(season.id)), Config.formatTime(season.endsIn))
		if tier >= Config.SEASON_TIERS then
			seasonInfo.Text = T("¡Nivel máximo! %d ⭐ en total", season.xp)
			seasonFill.Size = UDim2.fromScale(1, 1)
			seasonText.Text = T("MÁX")
		else
			local into = season.xp - tier * Config.SEASON_XP_PER_TIER
			seasonInfo.Text = T("Nivel %d de %d · %d ⭐ en total", tier, Config.SEASON_TIERS, season.xp)
			seasonFill.Size = UDim2.fromScale(into / Config.SEASON_XP_PER_TIER, 1)
			seasonText.Text = T("%d / %d ⭐ para el nivel %d", into, Config.SEASON_XP_PER_TIER, tier + 1)
		end
		if season.premium then
			premiumLabel.Text = T("🎫 Tienes el Premium de esta temporada: recoge también la columna dorada")
			premiumButton.Visible = false
		elseif seasonProduct.id ~= 0 then
			premiumLabel.Text = T("🎫 Premium: el doble de premios (patentes, boosts y 3 Contratos Legendarios)")
			premiumButton.Visible = true
			setButton(premiumButton, T("🎫 Conseguir el Premium"), true, THEME.yellow)
		else
			premiumLabel.Text = T("🎫 La columna dorada (Premium) estará disponible pronto")
			premiumButton.Visible = false
		end
		for t, row in tierRows do
			local reached = tier >= t
			row.label.TextColor3 = if reached then THEME.green else THEME.muted
			local key = tostring(t)
			local freeReward = rewardText(Config.seasonReward(t, false))
			if season.free[key] then
				setButton(row.free, "✓ " .. freeReward, false, THEME.green)
				row.free:SetAttribute("PaintColor", THEME.green)
			else
				setButton(row.free, (if reached then "🎁 " else "🔒 ") .. freeReward, reached, THEME.accent)
			end
			local premiumReward = rewardText(Config.seasonReward(t, true))
			if season.premiumClaimed[key] then
				setButton(row.premium, "✓ " .. premiumReward, false, THEME.green)
				row.premium:SetAttribute("PaintColor", THEME.green)
			else
				setButton(row.premium, (if reached and season.premium then "🎁 " else "🔒 ") .. premiumReward, reached and season.premium, Color3.fromRGB(202, 138, 4))
			end
		end
	end
end
