--[[
	TabCompanies (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña EMPRESAS
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
	local makeButtonRow = ui.makeButtonRow
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers

	local companiesPage = pages.companies
	local companiesHeader = makeCard(companiesPage, 92, 1, Color3.fromRGB(84, 46, 18))
	makeLabel(companiesHeader, "🏢 Tus empresas", 0, 22, 17, THEME.text, true)
	local companiesSummary = makeLabel(companiesHeader, "", 22, 18, 14, THEME.green, true)
	-- Cuántos niveles compra cada botón
	local buyAmount: number | string = 1
	local amountRow = makeButtonRow(companiesHeader, 46, 28)
	local amountButtons = {}
	for _, option in { 1, 10, "max" } do
		amountButtons[option] = makeButton(amountRow, if option == "max" then "MÁX" else "x" .. option, THEME.card, UDim2.new(1 / 3, -4, 1, 0), function()
			buyAmount = option
			if ui.state then
				renderers.companies(ui.state)
			end
		end)
	end

	-- Lo que hace una empresa con "level" niveles (en total)
	local function companyEffect(s, id: string, level: number): string
		if id == "devs" then
			return T("%s de trabajo/s", num(level * 1.5 * Config.companyMult(s, "devs")))
		elseif id == "hosting" then
			return T("+%d huecos para webs", level)
		elseif id == "marketing" then
			return T("+%d%% de visitas", level * 10)
		elseif id == "design" then
			return T("+%d%% de calidad", level * 8)
		elseif id == "comercial" then
			return T("+%d%% al vender", level * 12)
		elseif id == "ia_lab" then
			return T("+%d%% de velocidad", level * 25)
		elseif id == "adnet" then
			return T("+%d%% por anuncios", level * 15)
		elseif id == "fintech" then
			return T("+%d%% de mantenimiento", level * 5)
		elseif id == "gamestudio" then
			return T("+%d%% de visitas", level * 5)
		elseif id == "quantumlab" then
			return T("+%d%% de velocidad", level * 20)
		end
		return T("+%d%% a todo el dinero", level * 5)
	end

	local companyRows = {}
	for i, def in Config.Companies do
		local card = makeCard(companiesPage, 114, 10 + i)
		local title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
		makeLabel(card, def.desc, 24, 18, 14, THEME.muted) -- texto fijo: se traduce solo
		local effect = makeLabel(card, "", 44, 18, 14, THEME.green, true)
		local button = makeButton(card, "", THEME.orange, UDim2.new(1, 0, 0, 30), function()
			sendAction("buyCompany", def.id, buyAmount)
		end)
		button.Position = UDim2.fromOffset(0, 66)
		companyRows[def.id] = { title = title, button = button, effect = effect }
	end

	renderers.companies = function(s)
		companiesSummary.Text = T("💵 Tus empresas generan %s/s", fmt(Config.companiesIncome(s, s.moneyMult)))
		for _, def in Config.Companies do
			local row = companyRows[def.id]
			local level = s.companies[def.id] or 0
			local mult = Config.companyMult(s, def.id)
			local incomeText = if def.income > 0 then T(" · +%s/s por nivel", fmt(def.income * mult * s.moneyMult)) else ""
			local nextMilestone = Config.nextMilestone(level)
			local milestoneText = (if mult > 1 then string.format(" · 🏅 x%.1f", mult) else "")
				.. (if nextMilestone then T(" · hito en nivel %d", nextMilestone) else "")
			row.title.Text = def.emoji .. " " .. T("%s  —  Nivel %d", T(def.name), level) .. incomeText .. milestoneText
			if not Config.eraAllows(s, def) then
				row.title.Text = def.emoji .. " " .. T(def.name)
				row.effect.Text = ""
				setButton(row.button, T("🔒 Se desbloquea en la Era %d (🧬 Fusión)", def.era), false)
				continue
			end
			row.effect.Text = if level >= def.maxLevel then T("Ahora: %s (máximo)", companyEffect(s, def.id, level))
				else T("Ahora: %s  →  al subir: %s", companyEffect(s, def.id, level), companyEffect(s, def.id, level + 1))
			if level >= def.maxLevel then
				setButton(row.button, T("NIVEL MÁXIMO"), false)
			else
				local remaining = def.maxLevel - level
				local count, cost
				if buyAmount == "max" then
					count, cost = Config.companyAffordable(def.id, level, s.money, remaining)
					if count == 0 then
						count, cost = 1, Config.companyCost(def.id, level)
					end
				else
					count = math.min(buyAmount :: number, remaining)
					cost = Config.companyBulkCost(def.id, level, count)
				end
				local text = if level == 0 and count == 1 then T("🏗️ Fundar por %s", fmt(cost))
					elseif count == 1 then T("⬆️ Mejorar por %s", fmt(cost))
					else T("⬆️ +%d niveles por %s", count, fmt(cost))
				setButton(row.button, text, s.money >= cost)
			end
		end
		for option, button in amountButtons do
			setButton(button, if option == "max" then T("MÁX") else "x" .. option, true, if option == buyAmount then THEME.orange else THEME.card)
		end
	end
end
