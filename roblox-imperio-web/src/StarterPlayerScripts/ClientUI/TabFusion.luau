--[[
	TabFusion (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña 🧬 Fusión (v4, centro 📈 Inversión): la era en la que estás, lo
	que pide la Fusión para pasar a la siguiente (con su confirmación) y el
	árbol de mejoras de Legado. El progreso lo manda el servidor (state.eras).
]]

return function(ui: any)
	local Config = ui.Config
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local fmt = ui.fmt
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeProgressBar = ui.makeProgressBar
	local sendAction = ui.sendAction
	local showConfirm = ui.showConfirm
	local pages = ui.pages
	local renderers = ui.renderers

	local page = pages.fusion

	-- Era actual y Fusión
	local eraCard = makeCard(page, 196, 3, Color3.fromRGB(14, 52, 72))
	local eraTitle = makeLabel(eraCard, "", 0, 24, 19, THEME.text, true)
	local eraInfo = makeLabel(eraCard, "", 26, 18, 13, THEME.muted)
	local iposLabel = makeLabel(eraCard, "", 48, 18, 14, THEME.text)
	local _iposBack, iposFill = makeProgressBar(eraCard, UDim2.fromOffset(0, 68), UDim2.new(1, 0, 0, 10), THEME.green)
	local earnedLabel = makeLabel(eraCard, "", 82, 18, 14, THEME.text)
	local _earnedBack, earnedFill = makeProgressBar(eraCard, UDim2.fromOffset(0, 102), UDim2.new(1, 0, 0, 10), THEME.green)
	local gainLabel = makeLabel(eraCard, "", 118, 18, 14, THEME.yellow, true)
	local fusionState: any = nil
	local fusionButton = makeButton(eraCard, "🧬 Fusionar", Color3.fromRGB(8, 145, 178), UDim2.new(1, 0, 0, 44), function()
		local eras = fusionState
		if not eras then
			return
		end
		local nextEra = Config.Eras[eras.era + 1]
		if not nextEra then
			return
		end
		local lines = {
			T("Pasas a la Era %d: %s %s.", nextEra.id, nextEra.emoji, T(nextEra.name)),
			T("✅ Ganas %d 🧬 Legado para mejoras que no se pierden nunca.", eras.gain),
			T("✅ Se abren webs, apps de anuncios y empresas nuevas."),
			T("❌ Pierdes el dinero, las webs, las empresas y TODAS tus acciones."),
			T("✅ Conservas I+D, patentes, colección, carrera, agencia e historia."),
			T("Consejo: sal a bolsa justo antes para sumar las acciones de esta partida."),
		}
		showConfirm(T("🧬 ¿Hacer la Fusión?"), table.concat(lines, "\n"), T("Sí, fusionar"), Color3.fromRGB(8, 145, 178), function()
			sendAction("fusion")
		end)
	end)
	fusionButton.Position = UDim2.fromOffset(0, 144)

	-- Árbol de Legado
	local legacyHeader = makeCard(page, 64, 4, Color3.fromRGB(30, 58, 138))
	local legacyLabel = makeLabel(legacyHeader, "", 0, 22, 17, THEME.yellow, true)
	makeLabel(legacyHeader, "Mejoras para SIEMPRE: no se pierden ni al salir a bolsa ni en la Fusión. Algunas piden otra antes.", 24, 30, 13, THEME.muted).TextWrapped = true
	local rows = {}
	for b, branch in Config.LegacyBranches do
		local branchCard = makeCard(page, 30, 10 + b * 20, Color3.fromRGB(23, 37, 84))
		bindText(makeLabel(branchCard, "", 0, 14, 15, THEME.text, true), function()
			return branch.emoji .. " " .. T(branch.name)
		end)
		branchCard.Size = UDim2.new(1, -8, 0, 34)
		local order = 0
		for _, def in Config.LegacyTree do
			if def.branch == branch.id then
				order += 1
				local card = makeCard(page, 66, 10 + b * 20 + order)
				local title = makeLabel(card, "", 0, 20, 15, THEME.text, true)
				title.Size = UDim2.new(1, -170, 0, 20)
				local desc = makeLabel(card, def.desc, 22, 30, 13, THEME.muted)
				desc.Size = UDim2.new(1, -170, 0, 30)
				desc.TextWrapped = true
				desc.TextTruncate = Enum.TextTruncate.None
				local button = makeButton(card, "", THEME.accent, UDim2.fromOffset(160, 34), function()
					sendAction("buyLegacy", def.id)
				end)
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.Position = UDim2.new(1, 0, 0.5, 0)
				rows[def.id] = { title = title, button = button }
			end
		end
	end

	renderers.fusion = function(s)
		local eras = s.eras
		if not eras then
			return
		end
		fusionState = eras
		local era = Config.Eras[eras.era]
		local nextEra = Config.Eras[eras.era + 1]
		eraTitle.Text = T("Era %d de %d: %s %s", eras.era, #Config.Eras, era.emoji, T(era.name))
		eraInfo.Text = T("Dinero de la era x%d · Fusiones hechas: %d", era.moneyMult, eras.fusions)
		if nextEra then
			local ipos = math.min(eras.ipos, eras.needIpos)
			iposLabel.Text = T("🔔 Salidas a bolsa en esta era: %d / %d", ipos, eras.needIpos)
			iposFill.Size = UDim2.fromScale(ipos / math.max(eras.needIpos, 1), 1)
			local earned = math.min(eras.earned, eras.needEarned)
			earnedLabel.Text = T("💰 Ganado en esta era: %s / %s", fmt(earned), fmt(eras.needEarned))
			earnedFill.Size = UDim2.fromScale(earned / math.max(eras.needEarned, 1), 1)
			gainLabel.Text = T("Con tus %d acciones, la Fusión da %d 🧬 Legado", s.shares, eras.gain)
			local ready = eras.ipos >= eras.needIpos and eras.earned >= eras.needEarned
			setButton(fusionButton, if ready then T("🧬 Fusionar → Era %d: %s %s", nextEra.id, nextEra.emoji, T(nextEra.name))
				else T("🔒 Fusión a la Era %d: %s %s", nextEra.id, nextEra.emoji, T(nextEra.name)), ready)
		else
			iposLabel.Text = T("👑 Estás en la última era. ¡Sigue haciendo crecer tu imperio!")
			iposFill.Size = UDim2.fromScale(1, 1)
			earnedLabel.Text = ""
			earnedFill.Size = UDim2.fromScale(1, 1)
			gainLabel.Text = ""
			setButton(fusionButton, T("👑 Última era"), false)
		end

		legacyLabel.Text = T("🧬 Legado · tienes %d", eras.legacy)
		for _, def in Config.LegacyTree do
			local row = rows[def.id]
			local level = Config.legacy(s, def.id)
			row.title.Text = string.format("%s %s · %d/%d", def.emoji, T(def.name), level, def.maxLevel)
			row.title.TextColor3 = if level > 0 then THEME.green else THEME.text
			local needs = def.requires and Config.legacy(s, def.requires) < 1
			if level >= def.maxLevel then
				setButton(row.button, T("MÁX"), false, THEME.green)
				row.button:SetAttribute("PaintColor", THEME.green)
			elseif needs then
				local parent = Config.LegacyById[def.requires]
				setButton(row.button, T("🔒 Antes: %s", parent.emoji), false)
			else
				local cost = Config.legacyCost(def.id, level)
				setButton(row.button, T("Mejorar · 🧬 %d", cost), eras.legacy >= cost)
			end
		end
	end
end
