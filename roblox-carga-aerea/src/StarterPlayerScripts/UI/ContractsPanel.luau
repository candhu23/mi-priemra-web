--[[
	Ventana CONTRATOS: encargos de empresas españolas (inventadas). «Lleva N cargas de un producto
	a una región antes de que se acabe el tiempo» → premio grande. Ofertas nuevas cada 8 minutos.
	Las cargas que cuentan para un contrato salen marcadas con 📜 en CARGAS.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local ContractsPanel = {}

local TEAL = Color3.fromRGB(20, 184, 166)

local function describe(c: any): string
	local g = Config.GoodById[c.good]
	return T("contract_task", { n = c.count, good = g.emoji .. " " .. T("good_" .. c.good), region = T("r_" .. c.region) })
end

function ContractsPanel.build(content: Frame): () -> ()
	local area = Kit.scroll(content)
	Kit.list(false, 12).Parent = area
	local locked = Kit.label(area, "", 20, C.muted, Kit.FONT_BOLD, {
		LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 90), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
	})
	local activeTitle = Kit.title(area, "", 20, C.ink, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26) })
	local activeBox = create("Frame", {
		Parent = area, LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, { Kit.list(false, 8) })
	local emptyActive = Kit.label(activeBox, T("contracts_none"), 16, C.muted, nil, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30) })
	local offersTitle = Kit.title(area, "", 20, C.ink, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26) })
	local offersBox = create("Frame", {
		Parent = area, LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, { Kit.list(false, 8) })
	Kit.label(area, "💡 " .. T("contracts_note"), 15, C.muted, nil, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 44), TextWrapped = true })
	local activeCache: { [any]: Kit.Entry } = {}
	local offerCache: { [any]: Kit.Entry } = {}

	local function companyBox(parent: Instance, c: any)
		local box = create("Frame", { Parent = parent, BackgroundColor3 = C.white, Size = UDim2.fromOffset(72, 72) }, { corner(18) })
		Kit.emoji(box, Config.GoodById[c.good].emoji, 38, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end

	local function buildActive(c: any): Kit.Entry
		local root = Kit.card(activeBox, { Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = Color3.fromRGB(224, 247, 243) })
		Kit.stroke(TEAL, 2).Parent = root
		Kit.padding(14).Parent = root
		companyBox(root, c)
		Kit.title(root, T("company_" .. c.company), 20, C.ink, { Position = UDim2.fromOffset(88, 0), Size = UDim2.new(1, -340, 0, 24) })
		Kit.label(root, describe(c), 15, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(88, 24), Size = UDim2.new(1, -340, 0, 20) })
		local fill = Kit.progress(root, { Position = UDim2.fromOffset(88, 50), Size = UDim2.new(1, -340, 0, 14) }, TEAL)
		local prog = Kit.label(root, "", 14, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(88, 66), Size = UDim2.new(1, -340, 0, 18) })
		local reward = Kit.title(root, "", 22, C.greenDark, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -120, 0, 4), Size = UDim2.fromOffset(200, 28), TextXAlignment = Enum.TextXAlignment.Right,
		})
		local time = Kit.label(root, "", 16, C.ink, Kit.FONT_BOLD, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -120, 0, 38), Size = UDim2.fromOffset(200, 22), TextXAlignment = Enum.TextXAlignment.Right,
		})
		local quit = Kit.button(root, "✕", "white", UDim2.fromOffset(100, 44), function()
			ctx.openModal(T("contract_quit_title"), function(body)
				Kit.label(body, T("contract_quit_body"), 17, C.muted, nil, { Size = UDim2.new(1, 0, 0, 44), TextWrapped = true })
			end, {
				{ text = T("btn_cancel"), style = "white" },
				{ text = T("btn_quit"), style = "red", onClick = function()
					ctx.act("abandonContract", c.id)
				end },
			})
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		quit.TextSize = 18
		return {
			root = root,
			update = function(x: any)
				fill.Size = UDim2.fromScale(math.clamp(x.progress / x.count, 0, 1), 1)
				prog.Text = x.progress .. " / " .. x.count
				reward.Text = "🎁 " .. Kit.fmtMoney(x.reward)
				local left = x.expires - Kit.serverNow()
				time.Text = "⏱️ " .. Kit.fmtTime(left)
				time.TextColor3 = left < 60 and C.red or C.ink
			end,
		}
	end

	local function buildOffer(o: any): Kit.Entry
		local root = Kit.card(offersBox, { Size = UDim2.new(1, 0, 0, 100) })
		Kit.padding(14).Parent = root
		companyBox(root, o)
		Kit.title(root, T("company_" .. o.company), 20, C.ink, { Position = UDim2.fromOffset(88, 0), Size = UDim2.new(1, -350, 0, 24) })
		Kit.label(root, describe(o), 15, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(88, 26), Size = UDim2.new(1, -350, 0, 20) })
		Kit.label(root, "⏱️ " .. T("contract_time", { time = Kit.fmtTime(o.secs) }), 15, C.ink, Kit.FONT_BOLD, {
			Position = UDim2.fromOffset(88, 50), Size = UDim2.new(1, -350, 0, 20),
		})
		Kit.title(root, "🎁 " .. Kit.fmtMoney(o.reward), 22, C.greenDark, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -230, 0.5, 0), Size = UDim2.fromOffset(160, 30), TextXAlignment = Enum.TextXAlignment.Right,
		})
		local accept = Kit.button(root, "✍️ " .. T("btn_accept"), "green", UDim2.fromOffset(210, 54), function()
			ctx.act("acceptContract", o.id)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		accept.TextSize = 18
		return {
			root = root,
			update = function()
				local st = ctx.state
				Kit.setButton(accept, nil, #st.contracts.active < st.contracts.slots)
			end,
		}
	end

	local function render()
		local st = ctx.state
		if not st or not st.contracts then
			return
		end
		local open = st.level >= Config.CONTRACT_LEVEL and st.tutorial == 99
		locked.Visible = not open
		locked.Text = "🔒 " .. T("contracts_locked", { level = Config.CONTRACT_LEVEL })
		activeTitle.Visible = open
		activeBox.Visible = open
		offersTitle.Visible = open
		offersBox.Visible = open
		if not open then
			return
		end
		local c = st.contracts
		activeTitle.Text = "📜 " .. T("contracts_active", { n = #c.active, max = c.slots })
		offersTitle.Text = "📨 " .. T("contracts_offers", { time = Kit.fmtTime(c.nextIn) })
		emptyActive.Visible = #c.active == 0
		Kit.syncList(activeCache, c.active, function(x) return x.id end, buildActive)
		Kit.syncList(offerCache, c.offers, function(x) return x.id end, buildOffer)
	end
	table.insert(ctx.tickers, function()
		if ctx.panel == "contracts" then
			render()
		end
	end)
	return render
end

return ContractsPanel
