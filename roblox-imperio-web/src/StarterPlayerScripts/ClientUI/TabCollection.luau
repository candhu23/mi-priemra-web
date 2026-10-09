--[[
	TabCollection (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña COLECCIÓN (índice de webs raras)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local Config = ui.Config
	local T = ui.T
	local THEME = ui.THEME
	local create = ui.create
	local corner = ui.corner
	local padding = ui.padding
	local maxText = ui.maxText
	local darken = ui.darken
	local makeLabel = ui.makeLabel
	local makeCard = ui.makeCard
	local makeButtonRow = ui.makeButtonRow
	local pages = ui.pages
	local renderers = ui.renderers

	local collectionPage = pages.collection
	local collectionHeader = makeCard(collectionPage, 96, 1, Color3.fromRGB(6, 78, 59))
	makeLabel(collectionHeader, "📖 Colección de webs", 0, 22, 18, THEME.text, true)
	local collectionInfo = makeLabel(collectionHeader, "", 24, 18, 14, THEME.green, true)
	local oddsInfo = makeLabel(collectionHeader, "", 44, 18, 13, THEME.yellow, true)
	makeLabel(collectionHeader, "Cada casilla nueva: +1 % de dinero para siempre. Tipo completo: +10 % más. No se pierde al salir a bolsa.", 64, 18, 12, THEME.muted)

	local COLUMNS = { { id = "normal", emoji = "⚪", mult = 1 } }
	for _, variant in Config.Variants do
		table.insert(COLUMNS, variant)
	end
	local typeCards = {}
	for i, def in Config.WebTypes do
		local card = makeCard(collectionPage, 78, 10 + i)
		local title = makeLabel(card, "", 0, 20, 15, THEME.text, true)
		local row = makeButtonRow(card, 24, 34)
		local cells = {}
		for c, column in COLUMNS do
			local cell = create("TextLabel", {
				Parent = row,
				LayoutOrder = c,
				Size = UDim2.new(1 / #COLUMNS, -6, 1, 0),
				BackgroundColor3 = THEME.bg,
				Text = "",
				TextColor3 = THEME.text,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}, { corner(8), padding(4), maxText(15) })
			cells[column.id] = cell
		end
		typeCards[def.id] = { title = title, cells = cells }
	end

	renderers.collection = function(s)
		local entries, rows = Config.collectionStats(s)
		collectionInfo.Text = T("%d/%d casillas · %d tipos completos · +%d%% de dinero para siempre", entries, #Config.WebTypes * #COLUMNS, rows,
			math.floor(Config.collectionBonus(s) * 100 + 0.5))
		local chanceMult = Config.variantChanceMult(s, if s.serverEvent and s.serverEvent.id == "datastorm" then 5 else 1)
		local parts = {}
		for _, variant in Config.Variants do
			local chance = variant.chance * chanceMult * 100
			table.insert(parts, string.format(if chance < 1 then "%s %.1f%%" else "%s %d%%", variant.emoji, if chance < 1 then chance else math.floor(chance + 0.5)))
		end
		oddsInfo.Text = T("Probabilidad al terminar una web: %s", table.concat(parts, " · "))
		for _, def in Config.WebTypes do
			local card = typeCards[def.id]
			local owned = s.collection[def.id] or {}
			local complete = true
			for _, column in COLUMNS do
				local cell = card.cells[column.id]
				if owned[column.id] then
					cell.Text = column.emoji .. " x" .. column.mult
					cell.BackgroundColor3 = if column.color then darken(column.color, 0.35) else THEME.card
				else
					complete = false
					cell.Text = "❓"
					cell.BackgroundColor3 = THEME.bg
				end
			end
			card.title.Text = def.emoji .. " " .. T(def.name) .. (if complete then T("  ·  ✅ ¡completo! +10 %") else "")
			card.title.TextColor3 = if complete then THEME.yellow else THEME.text
		end
	end
end
