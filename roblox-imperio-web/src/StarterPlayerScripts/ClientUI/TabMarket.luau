--[[
	TabMarket (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña BOLSA (compra y venta de acciones, salir a bolsa y estadísticas)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local Market = ui.Market
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local fmt = ui.fmt
	local num = ui.num
	local create = ui.create
	local corner = ui.corner
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeButtonRow = ui.makeButtonRow
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers
	local pulseMoney = ui.pulseMoney
	local showConfirm = ui.showConfirm

	local marketPage = pages.market
	local marketHeader = makeCard(marketPage, 76, 1, Color3.fromRGB(80, 20, 54))
	makeLabel(marketHeader, "📈 Bolsa de Ciudad Web", 0, 22, 18, THEME.text, true)
	local marketInfo = makeLabel(marketHeader, "", 24, 18, 13, THEME.muted)
	local marketTotal = makeLabel(marketHeader, "", 44, 18, 14, THEME.green, true)

	local CHART_POINTS = Market.HISTORY
	local stockRows = {}
	for i, def in Market.Stocks do
		local card = makeCard(marketPage, 176, 1 + i, Color3.fromRGB(30, 27, 48))
		local title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
		local trend = makeLabel(card, "", 22, 18, 13, THEME.muted)
		-- Gráfica de barras con los últimos precios
		local chart = create("Frame", {
			Parent = card,
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = THEME.bg,
		}, { corner(6) })
		local bars = {}
		for k = 1, CHART_POINTS do
			bars[k] = create("Frame", {
				Parent = chart,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new((k - 1) / CHART_POINTS, 1, 1, 0),
				Size = UDim2.new(1 / CHART_POINTS, -1, 0.5, 0),
				BackgroundColor3 = THEME.green,
				BorderSizePixel = 0,
			})
		end
		local position = makeLabel(card, "", 90, 18, 13, THEME.text, true)
		local buyRow = makeButtonRow(card, 112, 26)
		local buyButtons = {}
		for _, fraction in { 0.1, 0.25, 0.5, 1 } do
			buyButtons[fraction] = makeButton(buyRow, "", THEME.green, UDim2.new(0.25, -5, 1, 0), function()
				sendAction("buyStock", def.id, fraction)
			end)
		end
		local sellRow = makeButtonRow(card, 142, 26)
		local sellHalf = makeButton(sellRow, "", THEME.orange, UDim2.new(0.5, -3, 1, 0), function()
			sendAction("sellStock", def.id, 0.5, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
		local sellAll = makeButton(sellRow, "", THEME.red, UDim2.new(0.5, -3, 1, 0), function()
			sendAction("sellStock", def.id, 1, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end)
		stockRows[def.id] = { title = title, trend = trend, bars = bars, position = position, buy = buyButtons, sellHalf = sellHalf, sellAll = sellAll }
	end

	-- Salir a bolsa (prestigio)
	-- Salir a bolsa y estadísticas: en su propia pestaña (v4: 🔔 Salir a bolsa)
	local ipoPage = pages.ipo
	local ipoCard = makeCard(ipoPage, 172, 50, Color3.fromRGB(80, 20, 54))
	makeLabel(ipoCard, "🔔 Salir a bolsa con tu imperio", 0, 22, 18, THEME.text, true)
	local ipoInfo1 = makeLabel(ipoCard, "", 24, 18, 14, THEME.muted)
	local ipoInfo2 = makeLabel(ipoCard, "", 44, 18, 15, THEME.green, true)
	makeLabel(ipoCard, "Se reinicia: dinero, webs, empresas, apps, reputación y tus acciones de la Bolsa.", 64, 18, 13, THEME.muted)
	bindText(makeLabel(ipoCard, "", 84, 18, 13, THEME.muted), function()
		return T("Te quedas: acciones (+%d%% dinero cada una hasta %d, luego algo menos), patentes e I+D, colección, carrera y tu rascacielos.",
			math.floor(Config.SHARE_BONUS * 100), Config.SHARE_SOFTCAP)
	end)
	local ipoButton: TextButton
	ipoButton = makeButton(ipoCard, "", THEME.pink, UDim2.new(1, 0, 0, 38), function()
		local s = ui.state
		if not s or s.ipoShares < 1 then
			return
		end
		-- Lo que se pierde y lo que se gana, para decidir con calma
		local companyLevels, apps, stockValue, dealCount, dealTotal = 0, 0, 0, 0, 0
		for _, level in s.companies do
			companyLevels += level
		end
		for _ in s.unlockedAds do
			apps += 1
		end
		for _, stock in s.market.stocks do
			stockValue += stock.units * stock.price
		end
		for _, site in s.sites do
			if site.deal then
				dealCount += 1
				dealTotal += site.deal.price
			end
		end
		local lines = {
			T("Pierdes:"),
			T("· 💰 %s de dinero", fmt(s.money)),
			T("· 🌐 %d webs y ⭐ %s de reputación", #s.sites, num(s.reputation)),
			T("· 🏢 %d niveles de empresas y %d apps de anuncios", companyLevels, apps),
		}
		if stockValue > 0 then
			table.insert(lines, T("· 📈 %s en acciones de la Bolsa", fmt(stockValue)))
		end
		if dealCount > 0 then
			table.insert(lines, T("🤝 Las %d ventas que negocias se cobran ya: +%s", dealCount, fmt(dealTotal)))
		end
		table.insert(lines, "")
		table.insert(lines, T("Ganas: +%d acciones (+%d%% de dinero para siempre) y +%d 💡 patentes", s.ipoShares,
			math.floor((Config.shareMult(s, s.shares + s.ipoShares) / Config.shareMult(s, s.shares) - 1) * 100 + 0.5), s.ipoPatents))
		showConfirm(T("🔔 ¿Salir a bolsa?"), table.concat(lines, "\n"), T("Sí, salir a bolsa"), THEME.pink, function()
			sendAction("ipo")
		end)
	end)
	ipoButton.Position = UDim2.fromOffset(0, 112)

	local statsCard = makeCard(ipoPage, 120, 51)
	makeLabel(statsCard, "📊 Estadísticas y guardado", 0, 22, 17, THEME.text, true)
	local statsLabel = makeLabel(statsCard, "", 24, 18, 14, THEME.muted)
	local saveLabel = makeLabel(statsCard, "", 44, 18, 13, THEME.muted)
	local saveButton = makeButton(statsCard, "💾 Guardar ahora", THEME.accent, UDim2.new(1, 0, 0, 30), function()
		sendAction("saveNow")
	end)
	saveButton.Position = UDim2.fromOffset(0, 70)

	local function percentText(value: number): string
		return string.format("%s%.1f%%", if value >= 0 then "+" else "-", math.abs(value) * 100)
	end

	renderers.market = function(s)
		local m = s.market
		local totalValue, totalInvested = 0, 0
		for _, stock in m.stocks do
			local def = Market.StockById[stock.id]
			local row = stockRows[stock.id]
			local rumor = Market.RumorDirs[stock.rumor] or Market.RumorDirs.flat
			local change = stock.price / math.max(stock.last, 0.0001) - 1
			local value = stock.units * stock.price
			totalValue += value
			totalInvested += stock.invested
			row.title.Text = string.format("%s %s (%s) · %s  %s", def.emoji, def.name, def.ticker, fmt(stock.price), percentText(change))
			row.title.TextColor3 = if change >= 0 then THEME.green else THEME.red
			row.trend.Text = T("📰 Rumor del analista: %s %s · Valor justo ~%s · Riesgo %s", rumor.emoji, T(rumor.text), fmt(def.rest),
				if def.vol >= 1.3 then T("alto") elseif def.vol <= 0.7 then T("bajo") else T("medio"))
			-- Gráfica: el historial es un anillo; head = el precio más antiguo
			local history = stock.history
			local count = #history
			local function priceAt(k: number): number?
				if k < 1 or k > count then
					return nil
				end
				return history[((stock.head or 1) + k - 2) % count + 1]
			end
			local low, high = math.huge, -math.huge
			for _, price in history do
				low = math.min(low, price)
				high = math.max(high, price)
			end
			local range = math.max(high - low, high * 0.02)
			for k, bar in row.bars do
				local price = priceAt(k)
				if price then
					bar.Visible = true
					bar.Size = UDim2.new(1 / CHART_POINTS, -1, 0.1 + 0.9 * (price - low) / range, 0)
					local previous = priceAt(k - 1) or price
					bar.BackgroundColor3 = if price >= previous then THEME.green else THEME.red
				else
					bar.Visible = false
				end
			end
			-- Tu inversión
			if stock.units > 0 then
				local profit = value - stock.invested
				row.position.Text = T("Tienes %s (pagaste %s) · %s %s", fmt(value), fmt(stock.invested), if profit >= 0 then "📈" else "📉",
					(if profit >= 0 then "+" else "-") .. fmt(math.abs(profit)))
				row.position.TextColor3 = if profit >= 0 then THEME.green else THEME.red
			else
				row.position.Text = T("No tienes acciones · máximo invertible %s", fmt(m.cap))
				row.position.TextColor3 = THEME.muted
			end
			local room = m.cap - value
			for fraction, button in row.buy do
				local amount = math.min(s.money * fraction, room)
				setButton(button, if fraction == 1 then T("Comprar MÁX") else T("Comprar %d%%", math.floor(fraction * 100)), amount >= 1, THEME.green)
			end
			setButton(row.sellHalf, T("Vender la mitad"), stock.units > 0, THEME.orange)
			setButton(row.sellAll, if stock.units > 0 then T("Vender todo (%s)", fmt(value)) else T("Vender todo"), stock.units > 0, THEME.red)
		end
		marketInfo.Text = T("Precios nuevos en %s · comisión %d%% · dividendo %.2f%% cada 30 s · el analista acierta un %d%%",
			Config.formatTime(m.nextTick), math.floor(Market.FEE * 100), Market.DIVIDEND * 100, math.floor((m.accuracy or Market.RUMOR_ACCURACY) * 100 + 0.5))
		if totalValue > 0 then
			local profit = totalValue - totalInvested
			marketTotal.Text = T("💼 Tu cartera vale %s · %s%s", fmt(totalValue), if profit >= 0 then "+" else "-", fmt(math.abs(profit)))
			marketTotal.TextColor3 = if profit >= 0 then THEME.green else THEME.red
		else
			marketTotal.Text = T("Compra cuando el precio esté por debajo de su valor justo y vende cuando suba.")
			marketTotal.TextColor3 = THEME.yellow
		end

		ipoInfo1.Text = T("Ganado en esta partida: %s · Acciones: %d (x%.2f dinero)", fmt(s.totalEarned), s.shares, Config.shareMult(s, s.shares))
		if s.ipoShares >= 1 then
			ipoInfo2.Text = T("Si sales a bolsa ahora consigues +%d acciones y +%d 💡 patentes", s.ipoShares, s.ipoPatents)
			setButton(ipoButton, T("🔔 Salir a bolsa (+%d acciones)", s.ipoShares), true)
		else
			ipoInfo2.Text = T("Necesitas ganar %s en esta partida", fmt(Config.IPO_MIN_EARNED))
			setButton(ipoButton, T("Te faltan %s", fmt(Config.IPO_MIN_EARNED - s.totalEarned)), false)
		end

		statsLabel.Text = T("Webs creadas %d · Vendidas %d · Clics %s (críticos %s) · Salidas a bolsa %d",
			s.stats.built, s.stats.sold, num(s.stats.clicks), num(s.stats.crits or 0), s.ipoCount)
		local saveText
		if not s.canSave then
			saveText = T("⚠️ Guardado DESACTIVADO: publica el juego y activa «Enable Studio Access to API Services»")
		elseif s.lastSaveAgo < 0 then
			saveText = T("💾 Se guarda solo cada %d s y al salir", Config.AUTOSAVE_INTERVAL)
		else
			saveText = T("💾 Último guardado hace %s%s", Config.formatTime(s.lastSaveAgo), if s.lastSaveOk == false then T(" (falló, se reintentará)") else " ✓")
		end
		saveLabel.Text = T("Ganado en total %s · %s", fmt(s.lifetimeEarned), saveText)
		saveLabel.TextColor3 = if s.canSave then THEME.muted else THEME.red
	end
	-- La misma función pinta las dos pestañas
	renderers.ipo = renderers.market
end
