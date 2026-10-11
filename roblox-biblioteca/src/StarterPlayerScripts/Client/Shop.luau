--!strict
-- Tienda: pases decorativos (mecenas, mascota, temas de luz) y propinas. Las compras las hace Roblox
-- (MarketplaceService); el servidor activa el pase. Con el pase, aquí mismo se elige color, mascota o tema.
-- Un artículo con id = 0 no sale en el juego publicado; en Studio sale como «Muestra» para probarlo.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Shop = {}
local C = Kit.C

-- ¿Hay algo que enseñar? (si no, el botón Tienda no sale)
function Shop.available(st: { [string]: any }): boolean
	if st.studio then
		return true
	end
	for _, p in Config.GamePasses do
		if p.id ~= 0 then
			return true
		end
	end
	for _, p in Config.Products do
		if p.id ~= 0 then
			return true
		end
	end
	return false
end

type Row = {
	item: Config.ShopItem,
	pass: boolean,
	frame: Frame,
	buy: TextButton,
	choices: { { value: any, button: TextButton } },
	option: string?,
}

function Shop.build(ctx: Kit.Ctx)
	local T = Kit.T
	local panel = Kit.panel("shop", 760, 640, T("shop_title"))
	local hint = Kit.label(panel.body, T("shop_hint"), UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), {
		TextSize = 15, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Name = "Hint",
	})
	local rows: { Row } = {}

	local function buy(row: Row)
		local id = row.item.id
		if row.pass and (ctx.state.passes or {})[row.item.key] == true then
			return
		end
		if id == 0 then
			ctx.toast(T("shop_studio"), "info")
			return
		end
		local player = Kit.localPlayer()
		pcall(function()
			if row.pass then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end

	local function addRow(item: Config.ShopItem, pass: boolean, option: string?, values: { any }, labels: { string })
		local f = Kit.frame(panel.body, UDim2.new(1, 0, 0, 96), nil, C.panel2, 0)
		f.Name = "Item_" .. item.key
		f.ZIndex = 23
		Kit.corner(f, 10)
		Kit.label(f, T("item_" .. item.key), UDim2.new(0.55, 0, 0, 28), UDim2.fromOffset(14, 6), {
			Font = Enum.Font.GothamBold, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24,
		})
		Kit.label(f, T("item_" .. item.key .. "_d"), UDim2.new(0.5, 0, 0, 54), UDim2.fromOffset(14, 36), {
			TextSize = 14, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 24,
		})
		local row: Row = { item = item, pass = pass, frame = f, buy = nil :: any, choices = {}, option = option }
		row.buy = Kit.button(f, "", UDim2.fromOffset(220, 38), UDim2.new(1, -232, 0, 8), function()
			buy(row)
		end, { ZIndex = 24, TextSize = 16, Name = "Buy" })
		ctx.targets["shop_" .. item.key] = row.buy
		local n = #values
		for j, v in values do
			local b = Kit.button(f, labels[j], UDim2.fromOffset(104, 36), UDim2.new(1, -12 - (n - j + 1) * 110, 0, 52), function()
				ctx.act("setOption", option, v)
			end, { ZIndex = 24, TextSize = 14, Name = "Choice_" .. tostring(v) })
			ctx.targets["shop_" .. item.key .. "_" .. tostring(v)] = b
			table.insert(row.choices, { value = v, button = b })
		end
		table.insert(rows, row)
	end

	for _, p in Config.GamePasses do
		if p.key == "patron" then
			addRow(p, true, "glow", { "gold", "green", "violet" }, { T("glow_gold"), T("glow_green"), T("glow_violet") })
		elseif p.key == "pet" then
			addRow(p, true, "pet", { true, false }, { T("shop_on"), T("shop_off") })
		elseif p.key == "themes" then
			addRow(p, true, "theme", Config.THEMES, { T("theme_normal"), T("theme_stars"), T("theme_autumn") })
		else
			addRow(p, true, nil, {}, {})
		end
	end
	for _, p in Config.Products do
		addRow(p, false, nil, {}, {})
	end

	local function refresh()
		local st = ctx.state
		local owned = st.passes or {}
		local set = st.settings or {}
		local y = 40
		for _, row in rows do
			local visible = row.item.id ~= 0 or st.studio == true
			row.frame.Visible = visible
			if visible then
				row.frame.Position = UDim2.fromOffset(0, y)
				y += 104
			end
			local has = row.pass and owned[row.item.key] == true
			if has then
				row.buy.Text = T("shop_owned")
				row.buy.AutoButtonColor = false
				row.buy.BackgroundColor3 = Color3.fromRGB(60, 95, 60)
			elseif row.item.id == 0 then
				row.buy.Text = T("shop_sample")
				row.buy.BackgroundColor3 = C.panel
			else
				row.buy.Text = T("shop_buy", { price = row.item.price })
				row.buy.BackgroundColor3 = C.goldDark
			end
			for _, c in row.choices do
				c.button.Visible = has
				local current = if row.option then set[row.option] else nil
				c.button.BackgroundColor3 = if current == c.value then C.goldDark else C.panel
			end
		end
		hint.Text = T("shop_hint") .. (if st.studio then "  " .. T("shop_studio") else "")
	end

	ctx.panels.shop = {
		open = function()
			refresh()
			panel.shell.Visible = true
		end,
		close = function()
			panel.shell.Visible = false
		end,
	}
	table.insert(ctx.refreshers, function()
		if ctx.panel == "shop" then
			refresh()
		end
	end)
end

return Shop
