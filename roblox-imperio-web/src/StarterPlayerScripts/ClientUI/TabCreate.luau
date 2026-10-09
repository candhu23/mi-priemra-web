--[[
	TabCreate (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña CREAR
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local Career = ui.Career
	local T = ui.T
	local THEME = ui.THEME
	local fmt = ui.fmt
	local num = ui.num
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeButtonRow = ui.makeButtonRow
	local makeProgressBar = ui.makeProgressBar
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers
	local tutorialTargets = ui.tutorialTargets

	local createPage = pages.create

	local projectCard = makeCard(createPage, 172, 1, Color3.fromRGB(22, 52, 40))
	local projectTitle = makeLabel(projectCard, "Elige qué web programar 👇", 0, 24, 19, THEME.text, true)
	projectTitle.Size = UDim2.new(1, -110, 0, 24)
	local cancelButton = makeButton(projectCard, "Cancelar", THEME.red, UDim2.fromOffset(100, 26), function()
		sendAction("cancelProject")
	end)
	cancelButton.AnchorPoint = Vector2.new(1, 0)
	cancelButton.Position = UDim2.new(1, 0, 0, 0)
	local _progressBack, createFill, createText = makeProgressBar(projectCard, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 24), THEME.green)
	ui.progressFill, ui.progressText = createFill, createText
	local programButton = makeButton(projectCard, "⌨️ PROGRAMAR", THEME.green, UDim2.new(1, 0, 0, 58), function()
		ui.doClick()
	end)
	programButton.Position = UDim2.fromOffset(0, 60)
	tutorialTargets.program = programButton
	local projectInfo = makeLabel(projectCard, "", 126, 20, 14, THEME.muted)

	local nicheCard = makeCard(createPage, 82, 2, Color3.fromRGB(23, 37, 84))
	local nicheTitle = makeLabel(nicheCard, "", 0, 20, 15, THEME.text, true)
	local nicheRow = makeButtonRow(nicheCard, 26, 34)
	local nicheButtons = {}
	for _, niche in Career.Niches do
		nicheButtons[niche.id] = makeButton(nicheRow, niche.emoji, THEME.card, UDim2.new(0.1, -6, 1, 0), function()
			sendAction("setNiche", niche.id)
		end)
	end

	local typeRows: { [string]: any } = {}
	for i, def in Config.WebTypes do
		-- Los productos de las eras 2 y 3 enseñan además su mecánica propia
		local mech = def.mech and Config.Mechanics[def.mech]
		local card = makeCard(createPage, if mech then 132 else 92, 10 + i)
		local title = makeLabel(card, def.emoji .. " " .. T(def.name), 0, 24, 18, THEME.text, true)
		local info = makeLabel(card, "", 26, 18, 14, THEME.muted)
		if mech then
			local mechLabel = makeLabel(card, mech.text, 46, 36, 13, THEME.yellow)
			mechLabel.TextWrapped = true
			mechLabel.TextTruncate = Enum.TextTruncate.None
		end
		local buttons = makeButtonRow(card, if mech then 86 else 46, 26)
		local createButton = makeButton(buttons, "Crear", THEME.accent, UDim2.new(0.62, -3, 1, 0), function()
			sendAction("startProject", def.id)
		end)
		local autoButton = makeButton(buttons, "🤖 Auto", THEME.purple, UDim2.new(0.38, -3, 1, 0), function()
			sendAction("setAuto", def.id)
		end)
		typeRows[def.id] = { title = title, info = info, create = createButton, auto = autoButton }
	end

	renderers.create = function(s)
		local project = s.project
		if project then
			local def = Config.WebTypeById[project.type]
			local forContract = false
			for _, contract in s.career.contracts do
				if contract.working then
					forContract = true
				end
			end
			projectTitle.Text = T("Programando: %s %s", def.emoji, T(def.name)) .. (if forContract then T(" · 🧾 encargo") else "")
			setButton(programButton, T("⌨️ PROGRAMAR  (+%s por clic · tecla F)", num(s.clickPower)), true)
			cancelButton.Visible = true
		else
			projectTitle.Text = T("Elige qué web programar 👇")
			ui.progressFill.Size = UDim2.fromScale(0, 1)
			ui.progressText.Text = ""
			setButton(programButton, T("Elige una web de la lista"), false)
			cancelButton.Visible = false
		end
		local autoText = if s.autoType then T(" · 🤖 Auto: %s", T(Config.WebTypeById[s.autoType].name)) else ""
		projectInfo.Text = T("👩‍💻 %s trabajo/s · 🌐 Webs %d/%d · ⭐ %s rep%s", num(s.workPerSec), #s.sites, s.slots, num(s.reputation), autoText)

		local selected = s.selectedNiche or Career.DEFAULT_NICHE
		local nicheLevel = s.career.nicheLevels[selected]
		nicheTitle.Text = T("🎯 Nicho de tus webs: %s · nivel %d (+%d%% calidad, x1.5 vendiendo a su nicho)",
			Career.NicheById[selected].emoji .. " " .. T(Career.NicheById[selected].name), nicheLevel, math.floor((Career.qualityBonus(s.career, selected) - 1) * 100 + 0.5))
		for id, button in nicheButtons do
			setButton(button, Career.NicheById[id].emoji, true, if id == selected then THEME.accent else THEME.card)
		end

		local hasLab = (s.companies.ia_lab or 0) >= 1
		local full = #s.sites >= s.slots
		for _, def in Config.WebTypes do
			local row = typeRows[def.id]
			local eraLocked = not Config.eraAllows(s, def)
			local locked = eraLocked or s.reputation < def.rep
			row.title.Text = def.emoji .. " " .. T(def.name) .. (if eraLocked then T("  🔒 Era %d (🧬 Fusión)", def.era)
				elseif locked then T("  🔒 necesitas ⭐ %s", num(def.rep)) else "")
			row.title.TextColor3 = if locked then THEME.muted else THEME.text
			row.info.Text = T("Coste %s · Trabajo %s · 👀 ~%s visitas/s · ⭐ +%d rep", fmt(def.cost), num(def.work), num(def.visits), def.repReward)

			local canCreate = not locked and not project and not full and s.money >= def.cost
			local createText = if locked then T("🔒 Bloqueada")
				elseif project then T("Ya programas otra")
				elseif full then T("Sin huecos (vende o compra Hosting)")
				elseif s.money < def.cost then T("Te faltan %s", fmt(def.cost - s.money))
				else T("➕ Crear (%s)", fmt(def.cost))
			setButton(row.create, createText, canCreate)

			row.auto.Visible = hasLab
			local isAuto = s.autoType == def.id
			setButton(row.auto, if isAuto then T("🤖 ACTIVO") else T("🤖 Auto"), hasLab and not locked, if isAuto then THEME.orange else THEME.purple)
		end
	end
end
