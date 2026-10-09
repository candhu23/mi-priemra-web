--[[
	TabRanking (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña RANKING (eventos de fin de semana, top semanal y vecinos)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local player = ui.player
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local fmt = ui.fmt
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local syncRows = ui.syncRows
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers

	local rankingPage = pages.ranking

	-- Evento de fin de semana (activo o el próximo)
	local weekendCard = makeCard(rankingPage, 92, 1, Color3.fromRGB(12, 74, 110))
	local weekendTitle = makeLabel(weekendCard, "", 0, 22, 17, THEME.text, true)
	local weekendDesc = makeLabel(weekendCard, "", 24, 18, 14, THEME.muted)
	local weekendTime = makeLabel(weekendCard, "", 46, 18, 14, THEME.yellow, true)
	makeLabel(weekendCard, "Cada fin de semana (viernes 20:00 → lunes 04:00 UTC) toca un evento distinto.", 66, 16, 12, THEME.muted)

	-- Ranking semanal
	local weeklyCard = makeCard(rankingPage, 70 + 10 * 21 + 8 + #Config.WeeklyPrizes * 18 + 22, 2, Color3.fromRGB(66, 52, 12))
	local weeklyTitle = makeLabel(weeklyCard, "", 0, 22, 17, THEME.text, true)
	local weeklyInfo = makeLabel(weeklyCard, "", 24, 18, 14, THEME.green, true)
	local goldInfo = makeLabel(weeklyCard, "", 44, 18, 13, THEME.yellow, true)
	local weeklyRows: { TextLabel } = {}
	for i = 1, Config.WEEKLY_TOP_SIZE do
		weeklyRows[i] = makeLabel(weeklyCard, "", 66 + (i - 1) * 21, 20, 14, THEME.text, i <= 3)
	end
	local prizesY = 66 + Config.WEEKLY_TOP_SIZE * 21 + 8
	makeLabel(weeklyCard, "🎁 Premios al acabar la semana:", prizesY, 18, 14, THEME.yellow, true)
	for i, prize in Config.WeeklyPrizes do
		bindText(makeLabel(weeklyCard, "", prizesY + 4 + i * 18, 18, 13, THEME.muted), function()
			local from = if i == 1 then 1 else Config.WeeklyPrizes[i - 1].upTo + 1
			local range = if from == prize.upTo then "#" .. from else "#" .. from .. "–" .. prize.upTo
			local parts = {}
			if prize.legendary > 0 then
				table.insert(parts, T("👑 %d Contrato Legendario", prize.legendary))
			end
			if prize.goldDays > 0 then
				table.insert(parts, T("🏆 rascacielos dorado %d días", prize.goldDays))
			end
			table.insert(parts, T("💰 %s de ingresos", Config.formatTime(prize.minutes * 60)))
			return string.format("%s %s: %s", prize.emoji, range, table.concat(parts, " + "))
		end)
	end

	-- Vecinos: los demás jugadores del servidor
	local neighborsHeader = makeCard(rankingPage, 64, 3, Color3.fromRGB(23, 37, 84))
	makeLabel(neighborsHeader, "🏙️ Imperios en este servidor", 0, 22, 17, THEME.text, true)
	local likesLabel = makeLabel(neighborsHeader, "", 24, 18, 13, THEME.muted)
	local emptyNeighbors = makeCard(rankingPage, 50, 4)
	makeLabel(emptyNeighbors, "No hay nadie más en el servidor. ¡Invita a tus amigos desde 🛒 Tienda!", 0, 30, 14, THEME.muted)
	local neighborRows = {}

	-- Clasificación de siempre
	local globalCard = makeCard(rankingPage, 36 + 10 * 21, 300, Color3.fromRGB(30, 41, 59))
	makeLabel(globalCard, "🌍 Los más ricos de Ciudad Web (de siempre)", 0, 22, 17, THEME.text, true)
	local globalRows: { TextLabel } = {}
	for i = 1, 10 do
		globalRows[i] = makeLabel(globalCard, "", 28 + (i - 1) * 21, 20, 14, THEME.text, i <= 3)
	end

	local RANK_COLORS = { THEME.yellow, Color3.fromRGB(203, 213, 225), THEME.orange }

	local function fillBoard(labels: { TextLabel }, rows: { any }, emptyText: string)
		for i, label in labels do
			local row = rows[i]
			if row then
				local mine = row.userId == player.UserId
				label.Text = string.format("%d. %s — %s%s", i, row.name, fmt(row.value), if mine then T("  ← tú") else "")
				label.TextColor3 = if mine then THEME.green else (RANK_COLORS[i] or THEME.text)
			else
				label.Text = if i == 1 then emptyText else ""
				label.TextColor3 = THEME.muted
			end
		end
	end

	renderers.ranking = function(s)
		local weekend = s.weekend
		local active = weekend.id and Config.WeekendEventById[weekend.id]
		if active then
			weekendTitle.Text = T("🎉 Evento activo: %s %s", active.emoji, T(active.name))
			weekendDesc.Text = T(active.desc)
			weekendTime.Text = T("⏱ Termina en %s", Config.formatTime(weekend.endsIn))
		else
			local nextEvent = Config.WeekendEventById[weekend.nextId]
			weekendTitle.Text = T("📅 Próximo evento: %s %s", nextEvent.emoji, T(nextEvent.name))
			weekendDesc.Text = T(nextEvent.desc)
			weekendTime.Text = T("⏱ Empieza en %s", Config.formatTime(weekend.startsIn))
		end

		weeklyTitle.Text = T("🏆 Ranking semanal · se reinicia en %s", Config.formatTime(s.weekly.resetIn))
		local top = s.weekly.top
		local tenth = top[Config.WEEKLY_TOP_SIZE]
		weeklyInfo.Text = T("Esta semana has ganado %s", fmt(s.weekly.earned))
			.. (if tenth and s.weekly.earned < tenth.value then T(" · para el top 10 necesitas %s", fmt(tenth.value)) else "")
		goldInfo.Text = if s.goldLeft > 0 then T("👑 Tu rascacielos es dorado: quedan %s", Config.formatTime(s.goldLeft))
			else T("La clasificación se actualiza cada 2 minutos.")
		fillBoard(weeklyRows, top, T("Aún no hay nadie esta semana. ¡Sé el primero!"))
		fillBoard(globalRows, s.globalTop, T("Clasificación disponible al publicar el juego"))

		likesLabel.Text = T("👍 Tu imperio tiene %d me gusta · da me gusta a otros y ganáis los dos", s.likes)
		emptyNeighbors.Visible = #s.neighbors == 0
		syncRows(rankingPage, neighborRows, s.neighbors, function(n)
			return n.userId
		end, function(n)
			local card = makeCard(rankingPage, 50, 0)
			local row: any = { frame = card, userId = n.userId }
			row.label = makeLabel(card, "", 0, 30, 15, THEME.text, true)
			row.label.Size = UDim2.new(1, -150, 0, 30)
			row.button = makeButton(card, "👀 Ver imperio", THEME.accent, UDim2.fromOffset(140, 30), function()
				sendAction("visitPlot", row.userId)
			end)
			row.button.AnchorPoint = Vector2.new(1, 0)
			row.button.Position = UDim2.new(1, 0, 0, 0)
			return row
		end, function(row, n)
			row.label.Text = T("🏢 %s · %d plantas · 👍 %d", n.name, n.floors, n.likes) .. (if n.liked then " ✓" else "")
			setButton(row.button, T("👀 Ver imperio"), true, THEME.accent)
		end)
	end
end
