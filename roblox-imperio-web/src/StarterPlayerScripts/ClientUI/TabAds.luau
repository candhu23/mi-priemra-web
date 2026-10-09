--[[
	TabAds (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña ANUNCIOS
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local T = ui.T
	local bindText = ui.bindText
	local THEME = ui.THEME
	local fmt = ui.fmt
	local num = ui.num
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeCard = ui.makeCard
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers

	local adsPage = pages.ads
	local adsHeader = makeCard(adsPage, 104, 1, Color3.fromRGB(59, 30, 84))
	makeLabel(adsHeader, "📢 Apps de anuncios para tus webs", 0, 22, 17, THEME.text, true)
	makeLabel(adsHeader, "Cada app paga distinto por visita, pero algunas molestan y espantan visitas.", 22, 18, 13, THEME.muted)
	makeLabel(adsHeader, "Cantidad: Pocos (x1 dinero) · Normal (x1.7, -12% visitas) · Muchos (x2.5, -32% visitas)", 42, 18, 13, THEME.muted)
	makeLabel(adsHeader, "💡 Truco: menos visitas = la web vale menos al venderla.", 62, 18, 13, THEME.yellow)

	local networkRows = {}
	for i, network in Config.AdNetworks do
		local card = makeCard(adsPage, 92, 10 + i)
		bindText(makeLabel(card, "", 0, 22, 17, THEME.text, true), function()
			return network.emoji .. " " .. T(network.name)
		end)
		bindText(makeLabel(card, "", 24, 18, 14, THEME.muted), function()
			return T("Paga %s por visita · Pierdes %d%% de visitas · Requiere ⭐ %s", fmt(network.rpv), math.floor(network.penalty * 100), num(network.rep))
		end)
		local button = makeButton(card, "", THEME.accent, UDim2.new(1, 0, 0, 28), function()
			sendAction("unlockNetwork", network.id)
		end)
		button.Position = UDim2.fromOffset(0, 46)
		networkRows[network.id] = { button = button }
	end

	renderers.ads = function(s)
		for _, network in Config.AdNetworks do
			local row = networkRows[network.id]
			if s.unlockedAds[network.id] then
				setButton(row.button, T("✓ Desbloqueada"), false, THEME.green)
				row.button:SetAttribute("PaintColor", THEME.green)
			elseif s.reputation < network.rep then
				setButton(row.button, T("🔒 Necesitas ⭐ %s de reputación", num(network.rep)), false)
			else
				setButton(row.button, T("🔓 Desbloquear por %s", fmt(network.cost)), s.money >= network.cost)
			end
		end
	end
end
