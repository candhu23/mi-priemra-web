--[[
	TabSites (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña WEBS (lista + ficha detallada de cada web)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local Career = ui.Career
	local T = ui.T
	local THEME = ui.THEME
	local fmt = ui.fmt
	local num = ui.num
	local create = ui.create
	local corner = ui.corner
	local stroke = ui.stroke
	local padding = ui.padding
	local maxText = ui.maxText
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeButtonRow = ui.makeButtonRow
	local syncRows = ui.syncRows
	local sendAction = ui.sendAction
	local content = ui.content
	local pages = ui.pages
	local renderers = ui.renderers
	local openTab = ui.openTab
	local pulseMoney = ui.pulseMoney
	local visitHistory = ui.visitHistory
	local HISTORY_SIZE = ui.HISTORY_SIZE
	local variantTag = ui.variantTag

	local sitesPage = pages.sites
	local sitesHeader = makeCard(sitesPage, 76, 1, Color3.fromRGB(23, 37, 84))
	local sitesSummary = makeLabel(sitesHeader, "", 0, 20, 15, THEME.text, true)
	local bestNetworkButton = makeButton(sitesHeader, "📢 Poner la mejor app de anuncios en todas", THEME.purple, UDim2.new(1, 0, 0, 30), function()
		if not ui.state then
			return
		end
		local bestId, bestValue = nil, -1
		for _, network in Config.AdNetworks do
			local value = network.rpv * (1 - network.penalty)
			if ui.state.unlockedAds[network.id] and value > bestValue then
				bestId, bestValue = network.id, value
			end
		end
		if bestId then
			sendAction("setNetworkAll", bestId)
		end
	end)
	bestNetworkButton.Position = UDim2.fromOffset(0, 26)

	local emptySites = makeCard(sitesPage, 50, 2)
	makeLabel(emptySites, "Aún no tienes webs. Ve a 🖥️ Crear y programa la primera.", 0, 30, 15, THEME.muted)

	local siteRows = {}
	local openSiteDetail: (siteId: number) -> ()

	local function unlockedNetworkList(s): { any }
		local list = {}
		for _, network in Config.AdNetworks do
			if s.unlockedAds[network.id] then
				table.insert(list, network)
			end
		end
		return list
	end

	function ui.nicheLabel(nicheId: string?): string
		local niche = Career.NicheById[nicheId or Career.DEFAULT_NICHE]
		return niche.emoji .. " " .. T(niche.name)
	end

	renderers.sites = function(s)
		local totalVisits, totalIncome = 0, 0
		for _, site in s.sites do
			totalVisits += site.visits
			totalIncome += site.income
		end
		sitesSummary.Text = T("🌐 %d/%d webs · 👀 %s visitas/s · 💵 %s/s por anuncios", #s.sites, s.slots, num(totalVisits), fmt(totalIncome))
		emptySites.Visible = #s.sites == 0

		syncRows(sitesPage, siteRows, s.sites, function(site)
			return site.id
		end, function(site)
			local card = makeCard(sitesPage, 102, 0)
			local row: any = { frame = card, id = site.id }
			row.title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
			row.info = makeLabel(card, "", 24, 18, 14, THEME.muted)
			local buttons = makeButtonRow(card, 50, 32)
			row.open = makeButton(buttons, "🔍 Abrir", THEME.green, UDim2.new(0.2, -5, 1, 0), function()
				openSiteDetail(row.id)
			end)
			row.seo = makeButton(buttons, "SEO", THEME.accent, UDim2.new(0.2, -5, 1, 0), function()
				sendAction("upgradeSeo", row.id)
			end)
			row.network = makeButton(buttons, "Anuncios", THEME.purple, UDim2.new(0.2, -5, 1, 0), function()
				if not ui.state then
					return
				end
				-- Pasa a la siguiente app de anuncios desbloqueada
				local list = unlockedNetworkList(ui.state)
				local nextIndex = 1
				for i, network in list do
					if network.id == row.currentNetwork then
						nextIndex = i % #list + 1
					end
				end
				sendAction("setNetwork", row.id, list[nextIndex].id)
			end)
			row.level = makeButton(buttons, "Cantidad", THEME.orange, UDim2.new(0.2, -5, 1, 0), function()
				sendAction("setAdLevel", row.id, (row.currentLevel or 1) % #Config.AdLevels + 1)
			end)
			row.sell = makeButton(buttons, "Vender", THEME.red, UDim2.new(0.2, -5, 1, 0), function()
				sendAction("quickSell", row.id)
			end)
			return row
		end, function(row, site)
			local def = Config.WebTypeById[site.type]
			local network = Config.AdNetworkById[site.network]
			row.currentNetwork = site.network
			row.currentLevel = site.adLevel
			local tag, tagColor = variantTag(site.variant)
			row.title.Text = tag .. (if site.viral then "🔥 " else "") .. def.emoji .. " " .. site.name .. "  ·  " .. T(def.name) .. "  ·  " .. ui.nicheLabel(site.niche)
			row.title.TextColor3 = if site.viral then THEME.orange else (tagColor or THEME.text)
			row.info.Text = T("⭐ Calidad %d%% · 🔎 SEO %d/%d · 👀 %s visitas/s · 💵 %s/s",
				math.floor(site.quality * 100), site.seo, Config.MAX_SEO, num(site.visits), fmt(site.income))

			if site.seo >= Config.MAX_SEO then
				setButton(row.seo, T("SEO MÁX"), false)
			else
				setButton(row.seo, "🔎 SEO+ " .. fmt(site.seoCost), s.money >= site.seoCost)
			end
			local multiple = #unlockedNetworkList(s) > 1
			setButton(row.network, network.emoji .. " " .. T(network.name) .. (if multiple then " ▸" else ""), multiple)
			setButton(row.level, T("Anuncios: %s ▸", T(Config.AdLevels[site.adLevel].name)), true)
			if site.deal then
				setButton(row.sell, T("🤝 Vendiendo · %s", Config.formatTime(site.deal.endsIn)), false, THEME.yellow)
			else
				setButton(row.sell, if (s.quickSaleLeft or 0) > 0 then T("Venta rápida en %s", Config.formatTime(s.quickSaleLeft))
					else T("Vender %s", fmt(site.saleBase * Config.QUICK_SALE_MULT)), (s.quickSaleLeft or 0) <= 0)
			end
		end)
	end

	-- Ficha detallada ------------------------------------------------------
	ui.detail = create("ScrollingFrame", {
		Parent = content,
		Name = "FichaWeb",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = THEME.muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})

	local function closeSiteDetail()
		ui.detailSiteId = nil
		ui.detail.Visible = false
		sitesPage.Visible = ui.currentTab == "sites"
	end

	local detailHeader = makeCard(ui.detail, 70, 1, Color3.fromRGB(23, 37, 84))
	local backButton = makeButton(detailHeader, "← Volver", THEME.card, UDim2.fromOffset(110, 30), closeSiteDetail)
	backButton.Position = UDim2.fromOffset(0, 0)
	local detailTitle = makeLabel(detailHeader, "", 0, 26, 20, THEME.text, true)
	detailTitle.Position = UDim2.fromOffset(120, 0)
	detailTitle.Size = UDim2.new(1, -120, 0, 26)
	local detailSubtitle = makeLabel(detailHeader, "", 32, 18, 14, THEME.muted)

	-- Cuatro cifras grandes
	local statsRow = create("Frame", {
		Parent = ui.detail,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 74),
	}, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function statBox(order: number, caption: string, color: Color3): TextLabel
		local box = create("Frame", {
			Parent = statsRow,
			LayoutOrder = order,
			Size = UDim2.new(0.25, -6, 1, 0),
			BackgroundColor3 = THEME.card,
		}, { corner(12), padding(8), stroke(color, 2) })
		makeLabel(box, caption, 0, 16, 13, THEME.muted, true)
		local value = create("TextLabel", {
			Parent = box,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 36),
			Text = "",
			TextColor3 = color,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, { maxText(30) })
		return value
	end
	local statVisits = statBox(1, "👀 Visitas por segundo", THEME.accent)
	local statIncome = statBox(2, "💵 Dinero por segundo", THEME.green)
	local statTotalVisits = statBox(3, "📊 Visitas totales", THEME.purple)
	local statEarned = statBox(4, "💰 Ganado en total", THEME.yellow)

	-- Gráfica de visitas
	local chartCard = makeCard(ui.detail, 150, 3)
	local chartTitle = makeLabel(chartCard, "📈 Visitas en directo (último minuto)", 0, 20, 15, THEME.text, true)
	local chartArea = create("Frame", {
		Parent = chartCard,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundColor3 = THEME.bg,
	}, { corner(8) })
	local chartBars: { Frame } = {}
	for i = 1, HISTORY_SIZE do
		chartBars[i] = create("Frame", {
			Parent = chartArea,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((i - 1) / HISTORY_SIZE, 1, 1, 0),
			Size = UDim2.new(1 / HISTORY_SIZE, -2, 0, 0),
			BackgroundColor3 = THEME.accent,
			BorderSizePixel = 0,
		}, { corner(2) })
	end

	-- Comparativa de apps de anuncios
	local adsCompareCard = makeCard(ui.detail, 60 + #Config.AdNetworks * 36 + 78, 4)
	makeLabel(adsCompareCard, "📢 ¿Cuánto te pagan por visita? (esta web)", 0, 20, 15, THEME.text, true)
	makeLabel(adsCompareCard, "App · paga por visita · visitas que pierdes · lo que ganarías", 22, 16, 12, THEME.muted)
	local compareRows = {}
	for i, network in Config.AdNetworks do
		local y = 40 + (i - 1) * 36
		local label = makeLabel(adsCompareCard, "", y + 6, 20, 14, THEME.text)
		label.Size = UDim2.new(1, -150, 0, 20)
		local button = makeButton(adsCompareCard, "", THEME.purple, UDim2.fromOffset(140, 30), function()
			if not ui.state or not ui.detailSiteId then
				return
			end
			if ui.state.unlockedAds[network.id] then
				sendAction("setNetwork", ui.detailSiteId, network.id)
			else
				openTab("ads")
			end
		end)
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, 0, 0, y)
		compareRows[network.id] = { label = label, button = button }
	end
	local levelsY = 40 + #Config.AdNetworks * 36 + 4
	makeLabel(adsCompareCard, "Cantidad de anuncios en esta web:", levelsY, 18, 14, THEME.text, true)
	local levelButtons = {}
	local levelRow = makeButtonRow(adsCompareCard, levelsY + 22, 34)
	for i, level in Config.AdLevels do
		levelButtons[i] = makeButton(levelRow, level.name, THEME.orange, UDim2.new(1 / #Config.AdLevels, -5, 1, 0), function()
			if ui.detailSiteId then
				sendAction("setAdLevel", ui.detailSiteId, i)
			end
		end)
	end

	-- Mejoras
	local upgradesCard = makeCard(ui.detail, 118, 5)
	makeLabel(upgradesCard, "🛠️ Mejorar esta web", 0, 20, 15, THEME.text, true)
	local seoInfo = makeLabel(upgradesCard, "", 24, 18, 13, THEME.muted)
	local designInfo = makeLabel(upgradesCard, "", 44, 18, 13, THEME.muted)
	local upgradeRow = makeButtonRow(upgradesCard, 66, 32)
	local detailSeoButton = makeButton(upgradeRow, "SEO", THEME.accent, UDim2.new(0.5, -3, 1, 0), function()
		if ui.detailSiteId then
			sendAction("upgradeSeo", ui.detailSiteId)
		end
	end)
	local detailDesignButton = makeButton(upgradeRow, "Diseño", THEME.pink, UDim2.new(0.5, -3, 1, 0), function()
		if ui.detailSiteId then
			sendAction("upgradeDesign", ui.detailSiteId)
		end
	end)

	-- Venta
	local sellCard = makeCard(ui.detail, 112, 6)
	makeLabel(sellCard, "🤝 Vender esta web", 0, 20, 15, THEME.text, true)
	local sellInfo = makeLabel(sellCard, "", 24, 18, 13, THEME.muted)
	local sellRow = makeButtonRow(sellCard, 50, 34)
	local detailOfferButton = makeButton(sellRow, "", THEME.green, UDim2.new(0.6, -3, 1, 0), function() end)
	local detailQuickButton = makeButton(sellRow, "", THEME.red, UDim2.new(0.4, -3, 1, 0), function()
		if ui.detailSiteId then
			sendAction("quickSell", ui.detailSiteId)
			closeSiteDetail()
		end
	end)
	local detailOfferId: number? = nil
	detailOfferButton.Activated:Connect(function()
		if ui.detailSiteId and detailOfferId and detailOfferButton:GetAttribute("Enabled") then
			sendAction("sellToOffer", detailOfferId, ui.detailSiteId, function(ok)
				if ok then
					pulseMoney()
					closeSiteDetail()
				end
			end)
		end
	end)

	-- Valor que tendría la web con otra app / otra cantidad de anuncios
	local function simulateIncome(s, site, networkId: string?, adLevel: number?): (number, number)
		local copy = table.clone(site)
		copy.network = networkId or site.network
		copy.adLevel = adLevel or site.adLevel
		local visits = Config.siteVisits(s, copy, 1)
		return visits, Config.siteIncome(s, copy, visits, s.moneyMult)
	end

	local function bestOfferFor(s, site)
		local best, bestValue = nil, 0
		for _, offer in s.offers do
			if offer.type == site.type then
				local value = site.saleBase * offer.mult * (if offer.niche == site.niche then Career.NICHE_MATCH_SALE_BONUS else 1)
				if value > bestValue then
					best, bestValue = offer, value
				end
			end
		end
		return best, bestValue
	end

	function ui.renderDetail(s)
		if not ui.detailSiteId then
			return
		end
		local site = nil
		for _, candidate in s.sites do
			if candidate.id == ui.detailSiteId then
				site = candidate
			end
		end
		if not site then
			closeSiteDetail()
			return
		end
		local def = Config.WebTypeById[site.type]
		local tag, tagColor = variantTag(site.variant)
		detailTitle.Text = tag .. (if site.viral then "🔥 " else "") .. def.emoji .. " " .. site.name
		detailTitle.TextColor3 = tagColor or THEME.text
		detailSubtitle.Text = T("%s · %s · ⭐ Calidad %d%% · 🔎 SEO %d/%d · 🎨 Diseño %d/%d",
			T(def.name), ui.nicheLabel(site.niche), math.floor(site.quality * 100), site.seo, Config.MAX_SEO, site.design, Config.MAX_DESIGN)
		statVisits.Text = num(site.visits)
		statIncome.Text = fmt(site.income)
		statTotalVisits.Text = num(site.totalVisits)
		statEarned.Text = fmt(site.earned)

		-- Gráfica
		local history = visitHistory[site.id] or {}
		local maxValue = 1
		for _, v in history do
			maxValue = math.max(maxValue, v)
		end
		chartTitle.Text = T("📈 Visitas en directo · máximo %s/s", num(maxValue))
		for i, bar in chartBars do
			local value = history[#history - HISTORY_SIZE + i]
			bar.Size = UDim2.new(1 / HISTORY_SIZE, -2, if value then math.max(0.02, value / maxValue * 0.95) else 0, 0)
			bar.BackgroundColor3 = if site.viral and i == HISTORY_SIZE then THEME.orange else THEME.accent
		end

		-- Comparativa
		local _, currentIncome = simulateIncome(s, site, nil, nil)
		for _, network in Config.AdNetworks do
			local row = compareRows[network.id]
			local visits, income = simulateIncome(s, site, network.id, nil)
			local diff = if currentIncome > 0 then (income / currentIncome - 1) * 100 else 0
			local diffText = if network.id == site.network then "" elseif diff >= 0 then string.format("  (+%d%%)", math.floor(diff + 0.5)) else string.format("  (%d%%)", math.floor(diff - 0.5))
			row.label.Text = T("%s %s · %s/visita · -%d%% visitas → %s visitas/s · %s/s%s",
				network.emoji, T(network.name), fmt(network.rpv), math.floor(network.penalty * 100), num(visits), fmt(income), diffText)
			row.label.TextColor3 = if network.id == site.network then THEME.green elseif diff > 0 then THEME.text else THEME.muted
			if network.id == site.network then
				setButton(row.button, T("✓ En uso"), false, THEME.green)
				row.button:SetAttribute("PaintColor", THEME.green)
			elseif s.unlockedAds[network.id] then
				setButton(row.button, T("Usar"), true, THEME.purple)
			elseif s.reputation < network.rep then
				setButton(row.button, "🔒 ⭐" .. num(network.rep), true, THEME.disabled)
			else
				setButton(row.button, "🔓 " .. fmt(network.cost), true, THEME.accent)
			end
		end
		for i, level in Config.AdLevels do
			local _, income = simulateIncome(s, site, nil, i)
			setButton(levelButtons[i], string.format("%s%s · %s/s", if site.adLevel == i then "✓ " else "", T(level.name), fmt(income)), site.adLevel ~= i, THEME.orange)
			if site.adLevel == i then
				levelButtons[i]:SetAttribute("PaintColor", THEME.green)
			end
		end

		-- Mejoras
		if site.seo >= Config.MAX_SEO then
			seoInfo.Text = T("🔎 SEO al máximo")
			setButton(detailSeoButton, T("SEO MÁX"), false)
		else
			local copy = table.clone(site)
			copy.seo += 1
			local _, after = simulateIncome(s, copy, nil, nil)
			seoInfo.Text = T("🔎 SEO %d → %d: +25%% visitas (%s/s → %s/s)", site.seo, site.seo + 1, fmt(currentIncome), fmt(after))
			setButton(detailSeoButton, T("🔎 Mejorar SEO · %s", fmt(site.seoCost)), s.money >= site.seoCost)
		end
		if site.design >= Config.MAX_DESIGN then
			designInfo.Text = T("🎨 Diseño al máximo")
			setButton(detailDesignButton, T("DISEÑO MÁX"), false)
		else
			local copy = table.clone(site)
			copy.design += 1
			local _, after = simulateIncome(s, copy, nil, nil)
			designInfo.Text = T("🎨 Rediseño %d → %d: +10%% calidad (%s/s → %s/s)", site.design, site.design + 1, fmt(currentIncome), fmt(after))
			setButton(detailDesignButton, T("🎨 Rediseñar · %s", fmt(site.designCost)), s.money >= site.designCost)
		end

		-- Venta
		local offer, offerValue = bestOfferFor(s, site)
		detailOfferId = offer and offer.id
		if site.deal then
			detailOfferId = nil
			sellInfo.Text = T("🤝 En negociación con %s por %s", site.deal.buyer, fmt(site.deal.price))
			setButton(detailOfferButton, T("🤝 Cerrando la venta · %s", Config.formatTime(site.deal.endsIn)), false, THEME.yellow)
			setButton(detailQuickButton, T("🤝 Vendiendo"), false)
			return
		end
		if offer then
			local match = offer.niche == site.niche
			sellInfo.Text = T("Mejor oferta: %s %s (x%.2f%s)", ui.nicheLabel(offer.niche), offer.company, offer.mult, if match then T(" · ⭐ mismo nicho x1.5") else "")
			setButton(detailOfferButton, T("💰 Vender a %s por %s", offer.company, fmt(offerValue)), true, if match then THEME.yellow else THEME.green)
		else
			sellInfo.Text = T("Ahora mismo ninguna empresa busca un %s. Las ofertas cambian cada poco.", T(def.name))
			setButton(detailOfferButton, T("Sin ofertas para esta web"), false)
		end
		if (s.quickSaleLeft or 0) > 0 then
			setButton(detailQuickButton, T("Venta rápida en %s", Config.formatTime(s.quickSaleLeft)), false)
		else
			setButton(detailQuickButton, T("Venta rápida · %s", fmt(site.saleBase * Config.QUICK_SALE_MULT)), true)
		end
	end

	function openSiteDetail(siteId: number)
		ui.detailSiteId = siteId
		sitesPage.Visible = false
		ui.detail.Visible = true
		ui.detail.CanvasPosition = Vector2.zero
		if ui.state then
			ui.renderDetail(ui.state)
		end
	end
end
