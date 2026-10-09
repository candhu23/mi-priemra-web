--[[
	TabClients (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña CLIENTES
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local Career = ui.Career
	local T = ui.T
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
	local pulseMoney = ui.pulseMoney

	local clientsPage = pages.clients
	local clientsHeader = makeCard(clientsPage, 84, 1, Color3.fromRGB(66, 52, 12))
	makeLabel(clientsHeader, "🤝 Empresas que quieren comprar webs", 0, 22, 17, THEME.text, true)
	makeLabel(clientsHeader, "Pagan según las visitas (x1.5 si es de SU nicho). Cerrar la venta lleva tiempo: más cuanto mayor es la web.", 22, 18, 13, THEME.muted)
	local maintenanceLabel = makeLabel(clientsHeader, "", 42, 18, 14, THEME.green, true)

	local offerRows = {}

	-- La web que más te pagarían en esa oferta (teniendo en cuenta el nicho).
	-- Las que ya están en negociación no cuentan.
	function ui.bestSiteFor(s, offer)
		local best, bestValue = nil, 0
		for _, site in s.sites do
			if site.type == offer.type and not site.deal then
				local value = site.saleBase * offer.mult * (if offer.niche == site.niche then Career.NICHE_MATCH_SALE_BONUS else 1)
				if value > bestValue then
					best, bestValue = site, value
				end
			end
		end
		return best, bestValue
	end

	renderers.clients = function(s)
		local deals = 0
		for _, site in s.sites do
			if site.deal then
				deals += 1
			end
		end
		maintenanceLabel.Text = T("🔧 Mantenimiento: +%s/s · 🤝 Negociaciones: %d/%d", fmt(s.maintenance), deals, s.maxDeals)
		local full = deals >= s.maxDeals

		syncRows(clientsPage, offerRows, s.offers, function(offer)
			return offer.id
		end, function(offer)
			local card = makeCard(clientsPage, 96, 0)
			local row: any = { frame = card, id = offer.id }
			row.title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
			row.info = makeLabel(card, "", 24, 18, 14, THEME.muted)
			row.sell = makeButton(card, "Vender", THEME.green, UDim2.new(1, 0, 0, 30), function()
				if row.siteId then
					sendAction("sellToOffer", row.id, row.siteId, function(ok)
						if ok then
							pulseMoney()
						end
					end)
				end
			end)
			row.sell.Position = UDim2.fromOffset(0, 46)
			return row
		end, function(row, offer)
			local def = Config.WebTypeById[offer.type]
			local vip = offer.mult >= 3
			row.title.Text = (if vip then "👑 " else "🏢 ") .. T("%s quiere: %s %s", offer.company, def.emoji, T(def.name))
			row.title.TextColor3 = if vip then THEME.yellow else THEME.text
			row.info.Text = T("%s · paga x%.2f del valor · ⏱ %s", ui.nicheLabel(offer.niche), offer.mult, Config.formatTime(offer.timeLeft))
			local site, value = ui.bestSiteFor(s, offer)
			row.siteId = site and site.id
			if site and full then
				setButton(row.sell, T("🤝 Máximo de negociaciones: espera a que acabe una"), false)
			elseif site then
				local match = site.niche == offer.niche
				setButton(row.sell, T("🤝 Negociar %s por %s (%s)", site.name, fmt(value), Config.formatTime(Config.dealSeconds(s, site.type)))
					.. (if match then "  ⭐ x1.5" else ""), true, if vip or match then THEME.yellow else THEME.green)
			else
				setButton(row.sell, T("No tienes ninguna %s", T(def.name)), false)
			end
		end)
	end
end
