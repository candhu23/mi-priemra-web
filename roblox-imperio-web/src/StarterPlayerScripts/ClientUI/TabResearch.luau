--[[
	TabResearch (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña I+D (mejoras para siempre que se pagan con patentes)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers

	local researchPage = pages.research
	local researchHeader = makeCard(researchPage, 64, 3, Color3.fromRGB(30, 58, 138))
	local patentsLabel = makeLabel(researchHeader, "", 0, 22, 17, THEME.yellow, true)
	makeLabel(researchHeader, "Mejoras para SIEMPRE (no se pierden al salir a bolsa). Las patentes se ganan al salir a bolsa y en el 🎫 Pase.", 24, 30, 13, THEME.muted).TextWrapped = true
	local researchRows = {}
	for b, branch in Config.ResearchBranches do
		local branchCard = makeCard(researchPage, 30, 10 + b * 20, Color3.fromRGB(23, 37, 84))
		bindText(makeLabel(branchCard, "", 0, 14, 15, THEME.text, true), function()
			return branch.emoji .. " " .. T(branch.name)
		end)
		branchCard.Size = UDim2.new(1, -8, 0, 34)
		local order = 0
		for _, def in Config.Research do
			if def.branch == branch.id then
				order += 1
				local card = makeCard(researchPage, 66, 10 + b * 20 + order)
				local title = makeLabel(card, "", 0, 20, 15, THEME.text, true)
				title.Size = UDim2.new(1, -170, 0, 20)
				local desc = makeLabel(card, def.desc, 22, 30, 13, THEME.muted)
				desc.Size = UDim2.new(1, -170, 0, 30)
				desc.TextWrapped = true
				desc.TextTruncate = Enum.TextTruncate.None
				local button = makeButton(card, "", THEME.accent, UDim2.fromOffset(160, 34), function()
					sendAction("buyResearch", def.id)
				end)
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.Position = UDim2.new(1, 0, 0.5, 0)
				researchRows[def.id] = { title = title, button = button }
			end
		end
	end

	renderers.research = function(s)
		patentsLabel.Text = T("💡 I+D · tienes %d patentes", s.patents)
		for _, def in Config.Research do
			local row = researchRows[def.id]
			local level = Config.research(s, def.id)
			row.title.Text = string.format("%s %s · %d/%d", def.emoji, T(def.name), level, def.maxLevel)
			row.title.TextColor3 = if level > 0 then THEME.green else THEME.text
			if level >= def.maxLevel then
				setButton(row.button, T("MÁX"), false, THEME.green)
				row.button:SetAttribute("PaintColor", THEME.green)
			else
				local cost = Config.researchCost(def.id, level)
				setButton(row.button, T("Mejorar · 💡 %d", cost), s.patents >= cost)
			end
		end
	end
end
