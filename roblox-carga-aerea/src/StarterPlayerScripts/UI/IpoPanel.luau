--[[
	Ventana BOLSA (prestigio): al salir a bolsa la partida vuelve a empezar, pero ganas acciones
	(+10 % de pago cada una, para siempre) y una ventaja permanente nueva en cada salida.
	Se conservan el pasaporte, los objetivos, la aerolínea, los pases y lo ganado en total.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T

local IpoPanel = {}

local NAVY = Color3.fromRGB(30, 64, 120)

function IpoPanel.build(content: Frame): () -> ()
	local area = Kit.scroll(content)
	Kit.list(false, 12).Parent = area

	-- Acciones actuales
	local top = Kit.card(area, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = Color3.fromRGB(226, 234, 248) })
	Kit.padding(16).Parent = top
	Kit.emoji(top, "📈", 46, { Position = UDim2.fromOffset(0, 4) })
	local sharesText = Kit.title(top, "", 26, NAVY, { Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -66, 0, 32) })
	local sharesSub = Kit.label(top, "", 16, C.muted, Kit.FONT_BOLD, { Position = UDim2.fromOffset(66, 34), Size = UDim2.new(1, -66, 0, 22) })

	-- Salir ahora
	local go = Kit.card(area, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 150) })
	Kit.padding(16).Parent = go
	local gain = Kit.title(go, "", 24, C.ink, { Size = UDim2.new(1, -300, 0, 30) })
	local req1 = Kit.label(go, "", 17, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, -300, 0, 22) })
	local req2 = Kit.label(go, "", 17, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, -300, 0, 22) })
	local nextShare = Kit.label(go, "", 14, C.muted, nil, { Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, -300, 0, 20) })
	local goBtn = Kit.button(go, "🔔 " .. T("btn_ipo"), "gold", UDim2.fromOffset(280, 70), function()
		local st = ctx.state
		ctx.openModal("🏛️ " .. T("ipo_confirm_title"), function(body)
			Kit.list(false, 8).Parent = body
			Kit.label(body, T("ipo_confirm", { n = st.newShares }), 18, C.ink, Kit.FONT_BOLD, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 50), TextWrapped = true })
			Kit.label(body, "🔄 " .. T("ipo_resets"), 16, C.red, nil, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 44), TextWrapped = true })
			Kit.label(body, "✅ " .. T("ipo_keeps"), 16, C.greenDark, nil, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 44), TextWrapped = true })
		end, {
			{ text = T("btn_cancel"), style = "white" },
			{ text = "🔔 " .. T("btn_ipo"), style = "gold", onClick = function()
				local ok, extra = ctx.act("goPublic")
				if ok and extra and extra.ipo then
					ctx.closePanel()
					ctx.celebrateIpo(extra)
				end
			end },
		})
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
	goBtn.TextSize = 24
	ctx.targets.ipo_go = goBtn

	-- Qué se reinicia y qué se queda
	local info = Kit.card(area, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 104) })
	Kit.padding(16).Parent = info
	Kit.label(info, "🔄 " .. T("ipo_resets"), 16, C.ink, nil, { Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	Kit.label(info, "✅ " .. T("ipo_keeps"), 16, C.greenDark, nil, {
		Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- Ventajas permanentes
	Kit.title(area, "🎁 " .. T("ipo_perks"), 20, C.ink, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 26) })
	local perkRows = {}
	for i, perk in Config.IpoPerks do
		local row = Kit.card(area, { LayoutOrder = 4 + i, Size = UDim2.new(1, 0, 0, 56) })
		Kit.padding(16, 16, 0, 0).Parent = row
		Kit.title(row, T("ipo_n", { n = i }), 18, NAVY, { Size = UDim2.new(0, 150, 1, 0) })
		Kit.label(row, T("perk_" .. perk), 17, C.ink, Kit.FONT_BOLD, { Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -220, 1, 0) })
		local mark = Kit.emoji(row, "🔒", 26, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		perkRows[i] = { row = row, mark = mark }
	end

	return function()
		local st = ctx.state
		if not st then
			return
		end
		local shares = st.shares or 0
		sharesText.Text = T("ipo_shares", { n = shares })
		sharesSub.Text = T("ipo_bonus", {
			p = math.floor(shares * Config.SHARE_BONUS * 100 + 0.5), x = math.floor(shares * Config.SHARE_XP_BONUS * 100 + 0.5), n = st.ipoCount or 0,
		})
		local new = st.newShares or 0
		gain.Text = T("ipo_gain", { n = new })
		local okLevel = st.level >= Config.IPO_LEVEL
		local okShares = new >= Config.IPO_MIN_SHARES
		req1.Text = (okLevel and "✅ " or "❌ ") .. T("ipo_req_level", { level = Config.IPO_LEVEL })
		req2.Text = (okShares and "✅ " or "❌ ") .. T("ipo_req_shares", { n = Config.IPO_MIN_SHARES })
		-- Cuánto falta para la siguiente acción: total = √(ganado / 1 M)
		local total = Config.sharesTotal(st.stats.earned)
		nextShare.Text = T("ipo_next_share", { amount = Kit.fmtMoney(((total + 1) ^ 2) * 1e6 - st.stats.earned) })
		Kit.setButton(goBtn, nil, okLevel and okShares)
		for i, r in perkRows do
			local done = (st.ipoCount or 0) >= i
			r.mark.Text = done and "✅" or "🔒"
			r.row.BackgroundColor3 = done and Color3.fromRGB(220, 247, 230) or C.soft
		end
	end
end

return IpoPanel
