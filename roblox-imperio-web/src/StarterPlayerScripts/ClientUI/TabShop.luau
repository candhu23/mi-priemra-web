--[[
	TabShop (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña TIENDA (regalos gratis, bonus y Robux)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local RunService = ui.RunService
	local MarketplaceService = ui.MarketplaceService
	local SocialService = ui.SocialService
	local Config = ui.Config
	local player = ui.player
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local fmt = ui.fmt
	local create = ui.create
	local corner = ui.corner
	local stroke = ui.stroke
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeButtonRow = ui.makeButtonRow
	local showToast = ui.showToast
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers
	local pulseMoney = ui.pulseMoney
	local showDailyModal = ui.showDailyModal

	local shopPage = pages.shop

	local giftCard = makeCard(shopPage, 78, 1, Color3.fromRGB(19, 78, 74))
	bindText(makeLabel(giftCard, "", 0, 22, 17, THEME.text, true), function()
		return T("🎁 Regalo gratis (cada %d min jugando)", math.floor(Config.GIFT_INTERVAL / 60))
	end)
	local giftButton = makeButton(giftCard, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
		sendAction("claimGift", nil, nil, function(ok)
			if ok then
				pulseMoney()
			end
		end)
	end)
	giftButton.Position = UDim2.fromOffset(0, 28)

	local dailyCard = makeCard(shopPage, 78, 2, Color3.fromRGB(19, 78, 74))
	local dailyTitle = makeLabel(dailyCard, "📅 Recompensa diaria", 0, 22, 17, THEME.text, true)
	local dailyButton = makeButton(dailyCard, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
		showDailyModal()
	end)
	dailyButton.Position = UDim2.fromOffset(0, 28)

	-- Premios por tiempo jugado hoy
	local playtimeCard = makeCard(shopPage, 100, 3, Color3.fromRGB(19, 78, 74))
	local playtimeTitle = makeLabel(playtimeCard, "", 0, 22, 17, THEME.text, true)
	local playtimeRow = makeButtonRow(playtimeCard, 26, 40)
	local playtimeButtons = {}
	for i, reward in Config.PlaytimeRewards do
		playtimeButtons[i] = makeButton(playtimeRow, reward.atMinutes .. "m", THEME.card, UDim2.new(1 / #Config.PlaytimeRewards, -6, 1, 0), function()
			sendAction("claimPlaytime", i, nil, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
	end
	local playtimeNext = makeLabel(playtimeCard, "", 72, 18, 13, THEME.muted)

	-- Códigos (los que publiques en TikTok, Discord...)
	local codesCard = makeCard(shopPage, 74, 4, Color3.fromRGB(19, 78, 74))
	makeLabel(codesCard, "🎟️ Códigos", 0, 20, 17, THEME.text, true)
	local codeBox = create("TextBox", {
		Parent = codesCard,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(0.65, -6, 0, 32),
		BackgroundColor3 = THEME.bg,
		Text = "",
		PlaceholderText = "🎟️ CÓDIGO / CODE",
		PlaceholderColor3 = THEME.muted,
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		ClearTextOnFocus = false,
	}, { corner(8), stroke(THEME.stroke, 1) })
	local codeButton = makeButton(codesCard, "🎟️ Canjear", THEME.green, UDim2.new(0.35, 0, 0, 32), function()
		sendAction("redeemCode", codeBox.Text, nil, function(ok)
			if ok then
				codeBox.Text = ""
				pulseMoney()
			end
		end)
	end)
	codeButton.Position = UDim2.new(0.65, 0, 0, 26)

	local bonusCard = makeCard(shopPage, 124, 5)
	makeLabel(bonusCard, "✨ Tus bonus de dinero", 0, 22, 17, THEME.text, true)
	local bonusLabel = makeLabel(bonusCard, "", 24, 40, 14, THEME.muted)
	bonusLabel.TextWrapped = true
	bonusLabel.TextYAlignment = Enum.TextYAlignment.Top
	bonusLabel.TextTruncate = Enum.TextTruncate.None
	local inviteButton = makeButton(bonusCard, "👫 Invitar amigos (+10 % cada uno, hasta 4)", THEME.pink, UDim2.new(1, 0, 0, 30), function()
		local ok, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		else
			showToast(T("No se pueden enviar invitaciones ahora mismo"), "error")
		end
	end)
	inviteButton.Position = UDim2.fromOffset(0, 70)

	local robuxItems = {}
	for _, pass in Config.Monetization.GamePasses do
		if pass.id ~= 0 then
			table.insert(robuxItems, { kind = "pass", def = pass })
		end
	end
	for _, product in Config.Monetization.Products do
		if product.id ~= 0 then
			table.insert(robuxItems, { kind = "product", def = product })
		end
	end

	local robuxTitle = makeCard(shopPage, 40, 6, Color3.fromRGB(76, 29, 149))
	makeLabel(robuxTitle, "💎 Tienda (Robux)", 0, 20, 17, THEME.text, true)
	robuxTitle.Visible = #robuxItems > 0 or RunService:IsStudio()

	if #robuxItems == 0 and RunService:IsStudio() then
		local info = makeCard(shopPage, 70, 7)
		local label = makeLabel(info, "Solo lo ves tú en Studio: crea Game Passes y Developer Products en el Creator Hub y pon sus IDs en TycoonConfig → Monetization para activar la tienda.", 0, 50, 14, THEME.muted)
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
	end

	local prices: { [number]: number } = {}
	local robuxRows = {}
	for i, item in robuxItems do
		local def = item.def
		local card = makeCard(shopPage, 92, 10 + i, Color3.fromRGB(46, 16, 101))
		bindText(makeLabel(card, "", 0, 22, 17, THEME.text, true), function()
			return def.emoji .. " " .. T(def.name) .. (if item.kind == "pass" then T("  ·  para siempre") else "")
		end)
		local desc = makeLabel(card, def.desc, 24, 18, 14, THEME.muted)
		if def.random then
			bindText(desc, function()
				return T(def.desc) .. T(" Probabilidades: %s", ui.oddsText("premium"))
			end)
		end
		local button = makeButton(card, "Comprar", THEME.purple, UDim2.new(1, 0, 0, 30), function()
			if item.kind == "pass" then
				MarketplaceService:PromptGamePassPurchase(player, def.id)
			else
				MarketplaceService:PromptProductPurchase(player, def.id)
			end
		end)
		button.Position = UDim2.fromOffset(0, 46)
		table.insert(robuxRows, { item = item, button = button, desc = desc, card = card })

		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(def.id, if item.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				prices[def.id] = info.PriceInRobux
			end
		end)
	end

	renderers.shop = function(s)
		if s.giftLeft <= 0 then
			setButton(giftButton, T("🎁 ¡Recoger %s!", fmt(s.giftAmount)), true, THEME.green)
		else
			setButton(giftButton, T("Próximo regalo en %s", Config.formatTime(s.giftLeft)), false)
		end
		dailyTitle.Text = T("📅 Recompensa diaria · día %d de 7", s.dailyDay)
		if s.dailyAvailable then
			setButton(dailyButton, T("📅 ¡Recoger %s!", fmt(s.dailyAmount)), true, THEME.green)
		else
			setButton(dailyButton, T("Ya la has recogido. ¡Vuelve mañana!"), false)
		end

		-- Premios por tiempo jugado
		local played = s.playtime.seconds
		playtimeTitle.Text = T("⏱️ Premios por jugar hoy · llevas %s", Config.formatTime(played))
		local nextText = nil
		for i, reward in Config.PlaytimeRewards do
			local claimed = s.playtime.claimed[tostring(i)] == true
			local ready = played >= reward.atMinutes * 60
			if claimed then
				setButton(playtimeButtons[i], "✓", false, THEME.green)
				playtimeButtons[i]:SetAttribute("PaintColor", THEME.green)
			elseif ready then
				setButton(playtimeButtons[i], "🎁 " .. reward.atMinutes .. "m", true, THEME.yellow)
			else
				setButton(playtimeButtons[i], reward.atMinutes .. "m", false, THEME.card)
			end
			if not claimed and not nextText then
				local what = if reward.kind == "cash" then T("💰 %d min de ingresos", reward.minutes)
					elseif reward.kind == "boost" then T("🚀 Boost x2 %d min", reward.minutes)
					else T("🎯 Headhunter Premium")
				nextText = if ready then T("🎁 ¡Listo! A los %d min: %s", reward.atMinutes, what)
					else T("Siguiente a los %d min (%s): %s", reward.atMinutes, Config.formatTime(reward.atMinutes * 60 - played), what)
			end
		end
		playtimeNext.Text = nextText or T("¡Has recogido todos los de hoy! Mañana más.")

		local b = s.bonuses
		local parts = {}
		table.insert(parts, T("📈 Acciones x%.2f", 1 + s.shares * Config.SHARE_BONUS))
		local collectionBonus = Config.collectionBonus(s)
		if collectionBonus > 0 then
			table.insert(parts, T("📖 Colección +%d%%", math.floor(collectionBonus * 100 + 0.5)))
		end
		if b.pass then
			table.insert(parts, T("💎 Pase x2"))
		end
		if b.boost then
			table.insert(parts, T("🚀 Boost x2 (%s)", Config.formatTime(s.boostLeft)))
		end
		if s.weekend.id then
			local event = Config.WeekendEventById[s.weekend.id]
			table.insert(parts, event.emoji .. " " .. T(event.short))
		end
		table.insert(parts, T("👫 Amigos: %d (+%d%%)", b.friends, math.floor(math.min(b.friends, Config.Monetization.MAX_FRIENDS) * Config.Monetization.FRIEND_BONUS * 100)))
		if b.premium then
			table.insert(parts, T("⭐ Premium +%d%%", math.floor(Config.Monetization.PREMIUM_BONUS * 100)))
		end
		if Config.Monetization.GROUP_ID ~= 0 then
			table.insert(parts, if b.group then T("👥 Grupo +10%") else T("👥 Únete al grupo: +10%"))
		end
		bonusLabel.Text = table.concat(parts, " · ") .. T("\nTotal: x%.2f a todo tu dinero", s.moneyMult)

		for _, row in robuxRows do
			local def = row.item.def
			row.card.Visible = not (def.random and b.randomRestricted)
				and not (def.kind == "starter" and s.starterLeft <= 0)
				and not (def.kind == "season" and s.season.premium)
			local price = prices[def.id]
			local priceText = if price then " (R$ " .. price .. ")" else ""
			if row.item.kind == "pass" and b[def.key] then
				setButton(row.button, T("✓ Ya lo tienes"), false, THEME.green)
				row.button:SetAttribute("PaintColor", THEME.green)
			elseif row.item.kind == "product" and def.kind == "cash" then
				row.desc.Text = T(def.desc) .. T(" Ahora: +%s", fmt(math.max(def.min, s.income * def.minutes * 60)))
				setButton(row.button, T("Comprar") .. priceText, true)
			elseif row.item.kind == "product" and def.kind == "starter" then
				row.desc.Text = T(def.desc) .. T(" · Se acaba en %s", Config.formatTime(s.starterLeft))
				setButton(row.button, T("Comprar") .. priceText, true, THEME.yellow)
			elseif row.item.kind == "product" and def.kind == "finish" then
				setButton(row.button, if s.project then T("Comprar") .. priceText else T("Empieza una web primero"), s.project ~= nil)
			else
				setButton(row.button, T("Comprar") .. priceText, true)
			end
		end
	end
end
