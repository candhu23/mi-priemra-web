--[[
	TabCareer (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña CARRERA (encargos de empresas, rangos y niveles por nicho)
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
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeButtonRow = ui.makeButtonRow
	local makeProgressBar = ui.makeProgressBar
	local syncRows = ui.syncRows
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers

	local careerPage = pages.career

	local profileCard = makeCard(careerPage, 96, 1, Color3.fromRGB(30, 58, 138))
	local profileTitle = makeLabel(profileCard, "", 0, 26, 20, THEME.text, true)
	local profileInfo = makeLabel(profileCard, "", 28, 18, 14, THEME.green, true)
	local profileNext = makeLabel(profileCard, "", 48, 30, 13, THEME.yellow, true)
	profileNext.TextWrapped = true
	profileNext.TextTruncate = Enum.TextTruncate.None

	-- Rangos y lo que da cada uno
	local ranksCard = makeCard(careerPage, 30 + #Career.Ranks * 20, 2, Color3.fromRGB(23, 37, 84))
	makeLabel(ranksCard, "🪜 Rangos (suben con encargos entregados y tu nivel de programador)", 0, 20, 14, THEME.text, true)
	local rankLabels = {}
	for i in Career.Ranks do
		rankLabels[i] = makeLabel(ranksCard, "", 4 + i * 20, 18, 13, THEME.muted)
	end

	-- Encargos aceptados
	local mineHeader = makeCard(careerPage, 40, 3, Color3.fromRGB(20, 83, 45))
	local mineTitle = makeLabel(mineHeader, "", 0, 20, 17, THEME.text, true)
	local emptyMine = makeCard(careerPage, 50, 4)
	makeLabel(emptyMine, "No tienes encargos. Acepta uno del tablón de abajo 👇", 0, 30, 14, THEME.muted)

	-- Tablón de encargos
	local boardHeader = makeCard(careerPage, 96, 50, Color3.fromRGB(23, 37, 84))
	makeLabel(boardHeader, "📨 Tablón de encargos", 0, 20, 17, THEME.text, true)
	local boardInfo = makeLabel(boardHeader, "", 22, 18, 13, THEME.muted)
	local askButton = makeButton(boardHeader, "", THEME.accent, UDim2.new(1, 0, 0, 30), function()
		sendAction("askContract")
	end)
	askButton.Position = UDim2.fromOffset(0, 46)
	local emptyBoard = makeCard(careerPage, 50, 51)
	makeLabel(emptyBoard, "No hay encargos ahora mismo. Pide uno o espera a que te escriban.", 0, 30, 14, THEME.muted)

	-- Niveles por nicho (al final)
	local nicheHeader = makeCard(careerPage, 54, 80, Color3.fromRGB(30, 58, 138))
	makeLabel(nicheHeader, "🎓 Tus nichos", 0, 20, 17, THEME.text, true)
	makeLabel(nicheHeader, "Subes de nivel programando webs de ese nicho y entregando encargos. +2 % de calidad por nivel.", 22, 18, 12, THEME.muted)
	local nicheGrid = create("Frame", {
		Parent = careerPage,
		LayoutOrder = 81,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 5 * 46),
	}, {
		create("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 40), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local nicheCells = {}
	for i, niche in Career.Niches do
		local cell = create("Frame", {
			Parent = nicheGrid,
			LayoutOrder = i,
			BackgroundColor3 = THEME.card,
		}, { corner(10), padding(6), stroke(THEME.stroke, 1) })
		local label = makeLabel(cell, niche.emoji .. " " .. T(niche.name), 0, 14, 13, THEME.text, true)
		local _back, fill, text = makeProgressBar(cell, UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 12), THEME.accent)
		nicheCells[niche.id] = { label = label, fill = fill, text = text, cell = cell }
	end

	local mineRows = {}
	local boardRows = {}

	-- "🛒 Tienda Online · 🎮 Videojuegos"
	local function wantText(contract): string
		local def = Config.WebTypeById[contract.type]
		return string.format("%s %s · %s", def.emoji, T(def.name), ui.nicheLabel(contract.niche))
	end

	local function contractCard(order: number, color: Color3): any
		local card = makeCard(careerPage, 108, order, color)
		local row: any = { frame = card }
		row.title = makeLabel(card, "", 0, 20, 16, THEME.text, true)
		row.want = makeLabel(card, "", 22, 18, 14, THEME.yellow, true)
		row.info = makeLabel(card, "", 42, 18, 13, THEME.muted)
		row.buttons = makeButtonRow(card, 66, 30)
		return row
	end

	renderers.career = function(s)
		local c = s.career
		local rank = Career.Ranks[c.rank]
		local nextRank = Career.Ranks[c.rank + 1]
		profileTitle.Text = T("💼 Rango: %s · Nivel de programador %d%s", T(rank.name), c.devLevel, if s.bonuses.xpPass then "  ·  🎓 x2 XP" else "")
		profileInfo.Text = T("🧾 Encargos entregados: %d · A la vez: %d · Paga x%.2f", c.stats.contracts or 0, c.slots, rank.payMult)
		if nextRank then
			profileNext.Text = T("⬆️ Para ser %s: %d encargos (tienes %d) y nivel de programador %d (tienes %d)",
				T(nextRank.name), nextRank.contracts, c.stats.contracts or 0, nextRank.devLevel, c.devLevel)
		else
			profileNext.Text = T("👑 ¡Has llegado al rango más alto!")
		end
		for i, def in Career.Ranks do
			local label = rankLabels[i]
			label.Text = T("%s %s · %d encargos y nivel %d → %d a la vez, paga x%.2f", if i <= c.rank then "✅" else "🔒", T(def.name), def.contracts, def.devLevel, def.slots, def.payMult)
			label.TextColor3 = if i == c.rank then THEME.green elseif i < c.rank then THEME.text else THEME.muted
		end

		-- Mis encargos
		mineTitle.Text = T("🧾 Tus encargos (%d/%d)", #c.contracts, c.slots)
		emptyMine.Visible = #c.contracts == 0
		local full = #c.contracts >= c.slots
		syncRows(careerPage, mineRows, c.contracts, function(contract)
			return contract.id
		end, function(contract)
			local row = contractCard(5, Color3.fromRGB(20, 60, 40))
			row.id = contract.id
			row.confirm = 0
			row.work = makeButton(row.buttons, "", THEME.green, UDim2.new(0.7, -3, 1, 0), function()
				sendAction("workOnContract", row.id)
			end)
			row.drop = makeButton(row.buttons, "Dejar", THEME.red, UDim2.new(0.3, -3, 1, 0), function()
				if os.clock() < row.confirm then
					row.confirm = 0
					sendAction("abandonContract", row.id)
				else
					row.confirm = os.clock() + 3
					row.drop.Text = T("¿Seguro?")
				end
			end)
			return row
		end, function(row, contract)
			local company = Career.company(contract.companyId)
			row.title.Text = string.format("%s %s · %s", company.tier.emoji, company.name, T(company.tier.name))
			row.want.Text = T("Quiere: %s", wantText(contract))
			row.info.Text = T("💵 %s · ⭐ +%s reputación · ⌛ quedan %s", fmt(contract.pay), num(contract.rep), Config.formatTime(contract.timeLeft))
			row.info.TextColor3 = if contract.timeLeft < 60 then THEME.red else THEME.muted
			if contract.working then
				setButton(row.work, T("⌨️ Programándola... (pestaña Crear)"), false)
			elseif s.project then
				setButton(row.work, T("Termina antes la web que estás programando"), false)
			else
				local def = Config.WebTypeById[contract.type]
				setButton(row.work, T("💻 Programar ahora (%s)", fmt(def.cost)), s.money >= def.cost, THEME.green)
			end
			if os.clock() >= row.confirm then
				setButton(row.drop, T("Dejar"), true, THEME.red)
			end
		end, 5)

		-- Tablón
		boardInfo.Text = T("Llega uno nuevo cada 1-2 min%s. Pagan %.1f veces lo que vale vender esa web.", if c.fair then T(" (¡Feria de Encargos: x1.5!)") else "", Career.CONTRACT_PAY)
		if c.askLeft > 0 then
			setButton(askButton, T("📨 Pedir un encargo (en %s)", Config.formatTime(c.askLeft)), false)
		else
			setButton(askButton, T("📨 Pedir un encargo a una empresa"), true, THEME.accent)
		end
		emptyBoard.Visible = #c.board == 0
		syncRows(careerPage, boardRows, c.board, function(contract)
			return contract.id
		end, function(contract)
			local row = contractCard(52, Color3.fromRGB(23, 37, 84))
			row.id = contract.id
			row.accept = makeButton(row.buttons, "", THEME.green, UDim2.new(1, 0, 1, 0), function()
				sendAction("acceptContract", row.id)
			end)
			return row
		end, function(row, contract)
			local company = Career.company(contract.companyId)
			local def = Config.WebTypeById[contract.type]
			row.title.Text = string.format("%s %s · %s", company.tier.emoji, company.name, T(company.tier.name))
			row.want.Text = T("Quiere: %s", wantText(contract))
			row.info.Text = T("💵 %s · ⭐ +%s reputación · plazo %s · se va en %s", fmt(contract.pay), num(contract.rep), Config.formatTime(contract.duration), Config.formatTime(contract.timeLeft))
			if full then
				setButton(row.accept, T("Ya tienes %d encargo(s): entrega uno o sube de rango", c.slots), false)
			else
				setButton(row.accept, T("✅ Aceptar encargo (la web cuesta %s)", fmt(def.cost)), true, THEME.green)
			end
		end, 52)

		for _, niche in Career.Niches do
			local cell = nicheCells[niche.id]
			local level = c.nicheLevels[niche.id]
			local xp = c.xp[niche.id] or 0
			local from, to = Career.xpForLevel(level), Career.xpForLevel(level + 1)
			local ratio = if level >= Career.MAX_NICHE_LEVEL then 1 else math.clamp((xp - from) / math.max(to - from, 1), 0, 1)
			cell.label.Text = T("%s %s · Nv %d", niche.emoji, T(niche.name), level)
			cell.fill.Size = UDim2.fromScale(ratio, 1)
			cell.text.Text = if level >= Career.MAX_NICHE_LEVEL then T("MÁX") else string.format("%d / %d XP", math.floor(xp - from), math.floor(to - from))
		end
	end
end
