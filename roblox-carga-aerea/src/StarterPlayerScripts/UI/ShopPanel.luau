--[[
	Ventana TIENDA (Robux): pases para siempre, ofertas de un solo uso y bonus gratis.
	Los artículos con id = 0 no aparecen en el juego publicado; en Studio se ven como muestra.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local ShopPanel = {}

local function visible(item: any): boolean
	return item.id ~= 0 or RunService:IsStudio()
end

local function buy(item: any, isPass: boolean)
	if item.id == 0 then
		ctx.toast(T("shop_not_configured"), "error")
		return
	end
	local player = Players.LocalPlayer
	if isPass then
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	else
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
end
ShopPanel.buy = buy

function ShopPanel.findProduct(key: string): any
	for _, p in Config.Products do
		if p.key == key then
			return p
		end
	end
	return nil
end

function ShopPanel.build(content: Frame): () -> ()
	local tab = "passes"
	local currentTab = ""
	local render: () -> ()
	local _, paintTabs = Kit.tabs(content, {
		{ id = "passes", text = "💎 " .. T("tab_passes") },
		{ id = "offers", text = "🔥 " .. T("tab_offers") },
		{ id = "bonus", text = "🤝 " .. T("tab_bonus") },
	}, function() return tab end, function(id)
		tab = id
		render()
	end)
	local area = Kit.scroll(content, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58) })
	local updaters: { () -> () } = {}

	local function itemCard(parent: Instance, item: any, isPass: boolean, order: number)
		local root = Kit.card(parent, { LayoutOrder = order })
		Kit.padding(14).Parent = root
		local box = create("Frame", { Parent = root, BackgroundColor3 = C.white, Size = UDim2.fromOffset(88, 88) }, { corner(22) })
		Kit.emoji(box, item.emoji, 48, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		Kit.title(root, T("item_" .. item.key), 21, C.ink, { Position = UDim2.fromOffset(102, 0), Size = UDim2.new(1, -102, 0, 26) })
		local desc = Kit.label(root, T("item_" .. item.key .. "_d"), 15, C.muted, nil, {
			Position = UDim2.fromOffset(102, 28), Size = UDim2.new(1, -102, 0, 58), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})
		local btn = Kit.button(root, "R$ " .. item.price, "green", UDim2.new(1, 0, 0, 48), function()
			buy(item, isPass)
		end, { Position = UDim2.new(0, 0, 1, -48) })
		if item.id == 0 then
			Kit.label(root, "⚠️ " .. T("shop_sample"), 12, C.red, Kit.FONT_BOLD, { Position = UDim2.new(0, 0, 1, -66), Size = UDim2.new(1, 0, 0, 16) })
		end
		table.insert(updaters, function()
			local st = ctx.state
			if isPass then
				local owned = st.passes[item.key] == true
				Kit.setButton(btn, owned and ("✅ " .. T("owned")) or ("R$ " .. item.price), not owned)
			elseif item.key == "starter" then
				Kit.setButton(btn, st.starterBought and ("✅ " .. T("owned")) or ("R$ " .. item.price), not st.starterBought)
			end
			if st.cash[item.key] then
				desc.Text = T("item_cash_d", { amount = Kit.fmtMoney(st.cash[item.key]) })
			end
		end)
	end

	local function bonusRow(parent: Instance, emoji: string, text: string, order: number): TextLabel
		local row = Kit.card(parent, { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = order })
		Kit.padding(14, 14, 0, 0).Parent = row
		Kit.emoji(row, emoji, 30, { Position = UDim2.new(0, 0, 0.5, -18) })
		Kit.title(row, text, 19, C.ink, { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -200, 1, 0) })
		return Kit.title(row, "", 22, C.greenDark, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 140, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	function render()
		local st = ctx.state
		if not st then
			return
		end
		if tab ~= currentTab then
			currentTab = tab
			paintTabs()
			table.clear(updaters)
			for _, k in area:GetChildren() do
				if not k:IsA("UIPadding") then
					k:Destroy()
				end
			end
			if tab == "passes" then
				Kit.grid(area, 220, 2)
				for i, p in Config.GamePasses do
					if visible(p) then
						itemCard(area, p, true, i)
					end
				end
			elseif tab == "offers" then
				Kit.grid(area, 220, 2)
				for i, p in Config.Products do
					if visible(p) and p.key ~= "offline2x" then
						itemCard(area, p, false, i)
					end
				end
			else
				Kit.list(false, 10).Parent = area
				local friends = bonusRow(area, "👥", T("bonus_friends"), 1)
				local premium = bonusRow(area, "⭐", T("bonus_premium"), 2)
				local group = Config.GROUP_ID ~= 0 and bonusRow(area, "🏢", T("bonus_group"), 3) or nil
				local vip = bonusRow(area, "💰", T("bonus_vip"), 4)
				local total = bonusRow(area, "📈", T("bonus_total"), 5)
				local invite = Kit.button(area, "📨 " .. T("btn_invite"), "blue", UDim2.new(1, 0, 0, 60), function()
					pcall(function()
						SocialService:PromptGameInvite(Players.LocalPlayer)
					end)
				end, { LayoutOrder = 6 })
				invite.TextSize = 22
				table.insert(updaters, function()
					local s = ctx.state.social
					friends.Text = "+" .. math.min(s.friends, 4) * 10 .. "%"
					premium.Text = s.premium and "+10%" or "—"
					if group then
						group.Text = s.group and "+10%" or "—"
					end
					vip.Text = ctx.state.passes.vip and "x2" or "—"
					total.Text = "x" .. string.format("%.2f", ctx.state.moneyMult)
				end)
			end
		end
		for _, fn in updaters do
			fn()
		end
	end
	return render
end

return ShopPanel
