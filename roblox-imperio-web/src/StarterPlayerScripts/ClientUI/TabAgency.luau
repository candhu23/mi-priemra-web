--[[
	TabAgency (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña AGENCIA (tu empresa de programadores)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local TweenService = ui.TweenService
	local Career = ui.Career
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local fmt = ui.fmt
	local num = ui.num
	local playSound = ui.playSound
	local create = ui.create
	local corner = ui.corner
	local stroke = ui.stroke
	local padding = ui.padding
	local maxText = ui.maxText
	local darken = ui.darken
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local makeButtonRow = ui.makeButtonRow
	local syncRows = ui.syncRows
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers
	local showModal = ui.showModal
	local showConfirm = ui.showConfirm

	local agencyPage = pages.agency

	local foundCard = makeCard(agencyPage, 104, 1, Color3.fromRGB(30, 58, 138))
	makeLabel(foundCard, "🏢 Funda tu propia agencia", 0, 22, 18, THEME.text, true)
	local foundInfo = makeLabel(foundCard, "", 26, 34, 14, THEME.muted)
	foundInfo.TextWrapped = true
	foundInfo.TextTruncate = Enum.TextTruncate.None
	local foundButton = makeButton(foundCard, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
		sendAction("foundAgency")
	end)
	foundButton.Position = UDim2.fromOffset(0, 64)

	local agencyCard = makeCard(agencyPage, 132, 2, Color3.fromRGB(30, 58, 138))
	local agencyTitle = makeLabel(agencyCard, "", 0, 22, 18, THEME.text, true)
	local agencyInfo = makeLabel(agencyCard, "", 26, 18, 14, THEME.green, true)
	local agencyStats = makeLabel(agencyCard, "", 46, 18, 13, THEME.yellow, true)
	local agencyInfo2 = makeLabel(agencyCard, "", 66, 18, 13, THEME.muted)
	local officeButton = makeButton(agencyCard, "", THEME.orange, UDim2.new(1, 0, 0, 30), function()
		sendAction("upgradeOffice")
	end)
	officeButton.Position = UDim2.fromOffset(0, 90)

	-- Mejoras de la oficina (se ven en tu edificio) y equipo completo
	local perksCard = makeCard(agencyPage, 30 + #Career.OfficePerks * 18 + 24, 5, Color3.fromRGB(20, 83, 45))
	makeLabel(perksCard, "🏗️ Mejoras de la oficina (se ven en tu edificio)", 0, 20, 15, THEME.text, true)
	local perkLabels = {}
	for i in Career.OfficePerks do
		perkLabels[i] = makeLabel(perksCard, "", 4 + i * 18, 18, 12, THEME.muted)
	end
	local teamLabel = makeLabel(perksCard, "", 8 + (#Career.OfficePerks + 1) * 18, 18, 13, THEME.yellow, true)

	-- Especialidades y rasgos (para que se entienda qué hace cada uno)
	local rolesCard = makeCard(agencyPage, 34 + #Career.Roles * 18 + 22 + math.ceil(#Career.Traits / 2) * 18, 6, Color3.fromRGB(23, 37, 84))
	perksCard.Visible = false
	makeLabel(rolesCard, "📚 Especialidades y rasgos", 0, 20, 15, THEME.text, true)
	for i, role in Career.Roles do
		bindText(makeLabel(rolesCard, "", 4 + i * 18, 18, 12, THEME.muted), function()
			return role.emoji .. " " .. T(role.name) .. ": " .. T(role.desc)
		end)
	end
	local traitsY = 4 + (#Career.Roles + 1) * 18 + 4
	for i, trait in Career.Traits do
		local label = makeLabel(rolesCard, "", traitsY + ((i - 1) // 2) * 18, 18, 12, THEME.muted)
		label.Size = UDim2.new(0.5, -4, 0, 18)
		label.Position = UDim2.new(if i % 2 == 1 then 0 else 0.5, if i % 2 == 1 then 0 else 4, 0, traitsY + ((i - 1) // 2) * 18)
		bindText(label, function()
			return trait.emoji .. " " .. T(trait.name) .. ": " .. T(trait.desc)
		end)
	end

	-- "+12% visitas · +3% dinero · +5 trabajo/s"
	function ui.programmerStatsText(work: number, stats): string
		local parts = {}
		local labels = {
			{ "quality", "+%.1f%% calidad" }, { "visits", "+%.1f%% visitas" }, { "sale", "+%.1f%% al vender" },
			{ "rare", "+%.1f%% webs raras" }, { "money", "+%.1f%% dinero" },
		}
		for _, entry in labels do
			local value = stats[entry[1]] or 0
			if value > 0.0005 then
				table.insert(parts, T(entry[2], value * 100))
			end
		end
		table.insert(parts, T("+%s trabajo/s", num(work)))
		return table.concat(parts, " · ")
	end

	function ui.oddsText(field: string): string
		local parts = {}
		for _, entry in Career.odds(field) do
			local percent = entry.percent
			table.insert(parts, string.format(if percent < 1 then "%s %.1f%%" else "%s %d%%", T(entry.rarity.name), if percent < 1 then percent else math.floor(percent + 0.5)))
		end
		return table.concat(parts, " · ")
	end

	local recruitCard = makeCard(agencyPage, 112, 3, Color3.fromRGB(76, 29, 149))
	makeLabel(recruitCard, "🎲 Entrevistar programadores", 0, 22, 17, THEME.text, true)
	local oddsLabel = makeLabel(recruitCard, "", 24, 18, 12, THEME.muted)
	bindText(oddsLabel, function()
		return T("Probabilidades: %s", ui.oddsText("weight"))
	end)
	local pityLabel = makeLabel(recruitCard, "", 44, 18, 13, THEME.yellow, true)
	local recruitButton = makeButton(recruitCard, "", THEME.purple, UDim2.new(1, 0, 0, 34), function() end)
	recruitButton.Position = UDim2.fromOffset(0, 66)

	local ticketsCard = makeCard(agencyPage, 150, 4, Color3.fromRGB(76, 29, 149))
	makeLabel(ticketsCard, "🎟️ Tus tickets", 0, 22, 17, THEME.text, true)
	local premiumLabel = makeLabel(ticketsCard, "", 24, 18, 13, THEME.muted)
	local premiumButton = makeButton(ticketsCard, "", THEME.purple, UDim2.new(1, 0, 0, 30), function() end)
	premiumButton.Position = UDim2.fromOffset(0, 44)
	local legendaryNiche = Career.DEFAULT_NICHE
	local legendaryRow = makeButtonRow(ticketsCard, 82, 30)
	local legendaryNicheButton = makeButton(legendaryRow, "", THEME.card, UDim2.new(0.4, -3, 1, 0), function()
		local index = Career.NicheById[legendaryNiche].order
		legendaryNiche = Career.Niches[index % #Career.Niches + 1].id
		if ui.state then
			renderers.agency(ui.state)
		end
	end)
	local legendaryButton = makeButton(legendaryRow, "", THEME.yellow, UDim2.new(0.6, -3, 1, 0), function() end)
	local ticketsHint = makeLabel(ticketsCard, "Los tickets se consiguen en 🛒 Tienda.", 118, 16, 12, THEME.muted)

	local teamTitle = makeCard(agencyPage, 40, 7)
	local teamTitleLabel = makeLabel(teamTitle, "👥 Tu equipo", 0, 20, 17, THEME.text, true)

	-- Revelación de un fichaje
	local function showRecruit(programmer)
		local rarity = Career.RarityById[programmer.rarity]
		local niche = Career.NicheById[programmer.niche]
		local work, stats = Career.programmerPower(programmer, ui.state and ui.state.bonuses.agencyPro, false)
		local role = Career.RoleById[programmer.role or "dev"] or Career.Roles[1]
		local trait = Career.TraitById[programmer.trait or ""]
		playSound(if rarity.order >= 4 then "rare" else "recruit")
		showModal("🎉 ¡Nuevo fichaje!", "", "¡Bienvenido al equipo!", nil, function(frame)
			local cardFrame = create("Frame", {
				Parent = frame,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0.8, 0, 1, -6),
				BackgroundColor3 = darken(rarity.color, 0.55),
			}, { corner(16), stroke(rarity.color, 4), padding(10) })
			local scale = create("UIScale", { Parent = cardFrame, Scale = 0.3 })
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			create("TextLabel", {
				Parent = cardFrame,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 40),
				Text = string.upper(T(rarity.name)),
				TextColor3 = rarity.color,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
			}, { maxText(36) })
			create("TextLabel", {
				Parent = cardFrame,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 44),
				Size = UDim2.new(1, 0, 0, 50),
				Text = "👩‍💻 " .. programmer.name,
				TextColor3 = THEME.text,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
			}, { maxText(40) })
			create("TextLabel", {
				Parent = cardFrame,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 96),
				Size = UDim2.new(1, 0, 0, 84),
				Text = string.format("%s %s · %s %s%s\n%s", role.emoji, T(role.name), niche.emoji, T(niche.name),
					if trait then " · " .. trait.emoji .. " " .. T(trait.name) else "", ui.programmerStatsText(work, stats)),
				TextColor3 = THEME.text,
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				TextWrapped = true,
			})
		end)
	end

	local function recruitResult(ok: boolean, _message: string?, extra: any)
		if ok and type(extra) == "table" and extra.recruit then
			showRecruit(extra.recruit)
		end
	end
	recruitButton.Activated:Connect(function()
		if recruitButton:GetAttribute("Enabled") then
			sendAction("recruit", nil, nil, recruitResult)
		end
	end)
	premiumButton.Activated:Connect(function()
		if premiumButton:GetAttribute("Enabled") then
			sendAction("redeemTicket", "premium", nil, recruitResult)
		end
	end)
	legendaryButton.Activated:Connect(function()
		if legendaryButton:GetAttribute("Enabled") then
			sendAction("redeemTicket", "legendary", legendaryNiche, recruitResult)
		end
	end)

	local programmerRows = {}

	renderers.agency = function(s)
		local c = s.career
		local agency = c.agency
		foundCard.Visible = agency == nil
		agencyCard.Visible = agency ~= nil
		recruitCard.Visible = agency ~= nil
		ticketsCard.Visible = agency ~= nil
		teamTitle.Visible = agency ~= nil
		perksCard.Visible = agency ~= nil

		if not agency then
			foundInfo.Text = T("Necesitas nivel de programador %d (tienes %d) y %s. Cada programador trabaja para ti y mejora algo según su especialidad.",
				Career.AGENCY_LEVEL_REQUIRED, c.devLevel, fmt(Career.AGENCY_COST))
			local can = c.devLevel >= Career.AGENCY_LEVEL_REQUIRED and s.money >= Career.AGENCY_COST
			setButton(foundButton, if c.devLevel < Career.AGENCY_LEVEL_REQUIRED then T("🔒 Sube a nivel %d en 💼 Carrera", Career.AGENCY_LEVEL_REQUIRED) else T("🏢 Fundar agencia (%s)", fmt(Career.AGENCY_COST)), can)
			syncRows(agencyPage, programmerRows, {}, function(p) return p.id end, function() return nil end, function() end)
			return
		end

		local full = #c.programmers >= agency.capacity
		agencyTitle.Text = T("🏢 %s · Oficina nivel %d", agency.name, agency.officeLevel)
		local totals = agency.totals or {}
		agencyInfo.Text = T("+%d%% a todo tu dinero · +%s trabajo/s", math.floor((totals.money or 0) * 100 + 0.5), num(totals.work or 0))
		agencyStats.Text = T("🎨 +%d%% calidad · 📣 +%d%% visitas · 🤝 +%d%% al vender · 📊 +%d%% webs raras",
			math.floor((totals.quality or 0) * 100 + 0.5), math.floor((totals.visits or 0) * 100 + 0.5),
			math.floor((totals.sale or 0) * 100 + 0.5), math.floor((totals.rare or 0) * 100 + 0.5))
		agencyInfo2.Text = T("Puestos ocupados: %d/%d%s", #c.programmers, agency.capacity, if s.bonuses.agencyPro then T(" · 🏙️ Agencia Pro") else "")
		-- Mejoras de la oficina y equipo completo
		local nextPerk = nil
		for i, perk in Career.OfficePerks do
			local has = agency.officeLevel >= perk.level
			perkLabels[i].Text = T("%s %s %s (nivel %d): %s", if has then "✅" else "🔒", perk.emoji, T(perk.name), perk.level, T(perk.desc))
			perkLabels[i].TextColor3 = if has then THEME.green else THEME.muted
			if not has and not nextPerk then
				nextPerk = perk
			end
		end
		local roles = Career.rolesInTeam(c)
		local missingRoles = {}
		for _, role in Career.Roles do
			if not roles[role.id] then
				table.insert(missingRoles, role.emoji)
			end
		end
		teamLabel.Text = if #missingRoles == 0 then T("👥 ¡Equipo completo! +%d%% a todo lo que aporta tu equipo", math.floor(Career.FULL_TEAM_BONUS * 100))
			else T("👥 Equipo completo (una de cada especialidad): +%d%% · te faltan %s", math.floor(Career.FULL_TEAM_BONUS * 100), table.concat(missingRoles, " "))
		teamLabel.TextColor3 = if #missingRoles == 0 then THEME.green else THEME.yellow
		if agency.upgradeCost then
			local perkText = if nextPerk and nextPerk.level == agency.officeLevel + 1 then " · " .. nextPerk.emoji .. " " .. T(nextPerk.name) else ""
			setButton(officeButton, T("🏗️ Ampliar oficina (+2 puestos) · %s", fmt(agency.upgradeCost)) .. perkText, s.money >= agency.upgradeCost)
		else
			setButton(officeButton, T("Oficina al máximo"), false)
		end

		pityLabel.Text = T("⭐ Legendario garantizado en %d entrevistas", math.max(1, Career.PITY_INTERVIEWS - c.pity))
		if full then
			setButton(recruitButton, T("Oficina llena: amplíala o despide a alguien"), false)
		else
			setButton(recruitButton, T("🎲 Entrevistar · %s", fmt(c.recruitCost)), s.money >= c.recruitCost)
		end

		-- Tickets
		local restricted = s.bonuses.randomRestricted
		premiumLabel.Text = if restricted then T("🎯 Headhunter Premium no disponible en tu país.")
			else string.format("🎯 Headhunter Premium: %d · %s", c.tickets.premium or 0, ui.oddsText("premium"))
		premiumButton.Visible = not restricted
		setButton(premiumButton, T("🎯 Usar Headhunter Premium"), (c.tickets.premium or 0) > 0 and not full)
		setButton(legendaryNicheButton, T("Nicho: %s ▸", Career.NicheById[legendaryNiche].emoji), true, THEME.card)
		setButton(legendaryButton, T("👑 Usar Contrato Legendario (%d)", c.tickets.legendary or 0), (c.tickets.legendary or 0) > 0 and not full)
		ticketsHint.Text = T("Consigue tickets en 🛒 Tienda · %s", if full then T("⚠️ oficina llena") else T("Hay sitio en la oficina"))

		teamTitleLabel.Text = T("👥 Tu equipo (%d)", #c.programmers)
		-- Los mejores primero (el servidor los manda por orden de fichaje)
		local team = table.clone(c.programmers)
		table.sort(team, function(a, b)
			local ra, rb = Career.RarityById[a.rarity].order, Career.RarityById[b.rarity].order
			if ra ~= rb then
				return ra > rb
			end
			if a.level ~= b.level then
				return a.level > b.level
			end
			return a.id < b.id
		end)
		syncRows(agencyPage, programmerRows, team, function(p)
			return p.id
		end, function(p)
			local rarity = Career.RarityById[p.rarity]
			local card = create("Frame", {
				Parent = agencyPage,
				Size = UDim2.new(1, -8, 0, 104),
				BackgroundColor3 = darken(rarity.color, 0.6),
			}, { corner(12), padding(10), stroke(rarity.color, 2) })
			local row: any = { frame = card, id = p.id, data = p }
			row.title = makeLabel(card, "", 0, 20, 16, rarity.color, true)
			row.info = makeLabel(card, "", 22, 18, 13, THEME.text)
			row.stats = makeLabel(card, "", 42, 18, 13, THEME.yellow, true)
			local buttons = makeButtonRow(card, 64, 28)
			row.train = makeButton(buttons, "", THEME.accent, UDim2.new(0.7, -3, 1, 0), function()
				sendAction("trainProgrammer", row.id)
			end)
			row.fire = makeButton(buttons, "Despedir", THEME.red, UDim2.new(0.3, -3, 1, 0), function()
				local info = row.data
				local rarityDef = Career.RarityById[info.rarity]
				local body = T("Vas a despedir a %s (%s, nivel %d). No se puede deshacer.", info.name, T(rarityDef.name), info.level)
					.. "\n\n" .. T("Pierdes: %s", ui.programmerStatsText(info.work, info.stats))
				if rarityDef.order >= 5 then
					local chance = 0
					for _, entry in Career.odds("weight") do
						if entry.rarity == rarityDef then
							chance = entry.percent
						end
					end
					body ..= "\n\n" .. T("⚠️ ¡Es %s! En una entrevista normal solo sale un %.1f%% de las veces.", T(rarityDef.name), chance)
				end
				showConfirm(T("👋 ¿Despedir a %s?", info.name), body, T("Sí, despedir"), THEME.red, function()
					sendAction("fireProgrammer", row.id)
				end)
			end)
			return row
		end, function(row, p)
			local rarity = Career.RarityById[p.rarity]
			local role = Career.RoleById[p.role] or Career.Roles[1]
			local trait = Career.TraitById[p.trait or ""]
			local xpText = if p.level >= Career.PROGRAMMER_MAX_LEVEL then "" else string.format(" (%d%%)", math.floor(math.clamp(p.xp / math.max(p.xpNeeded, 1), 0, 1) * 100))
			row.title.Text = T("👩‍💻 %s · %s · Nv %d/%d", p.name, T(rarity.name), p.level, Career.PROGRAMMER_MAX_LEVEL) .. xpText
			row.info.Text = string.format("%s %s · %s%s", role.emoji, T(role.name), ui.nicheLabel(p.niche),
				if trait then " · " .. trait.emoji .. " " .. T(trait.name) else "")
			row.stats.Text = ui.programmerStatsText(p.work, p.stats)
			if p.level >= Career.PROGRAMMER_MAX_LEVEL then
				setButton(row.train, T("Nivel máximo"), false)
			else
				setButton(row.train, T("📚 Entrenar · %s", fmt(p.trainCost)), s.money >= p.trainCost)
			end
			row.data = p
			setButton(row.fire, T("Despedir"), true, THEME.red)
		end)
	end
end
