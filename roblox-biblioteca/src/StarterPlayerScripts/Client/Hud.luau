--!strict
-- HUD discreto como el original: filas correctas arriba, libros en estanterías abajo, «faltan N filas para el
-- siguiente punto», cronómetro, cruceta con lo que hará USAR, pila de libros en mano, pistas y avisos.
-- En pantallas táctiles añade los botones grandes (USAR, Soltar, Lanzar, Rotar, Lista, Mapa…).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookData = require(ReplicatedStorage:WaitForChild("BookData"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Books = require(script.Parent:WaitForChild("Books"))
local Aim = require(script.Parent:WaitForChild("Aim"))

local Hud = {}
local C = Kit.C

Hud.stateAt = os.clock() -- cuándo llegó el último estado (para el cronómetro)

function Hud.build(ctx: Kit.Ctx)
	local root = ctx.root
	local T = Kit.T

	-------------------------------------------------------------------
	-- Contadores
	-------------------------------------------------------------------
	local top = Kit.frame(root, UDim2.fromOffset(470, 62), UDim2.new(0.5, -235, 0, 6), C.ink, 0.3)
	top.Name = "TopCounter"
	Kit.corner(top, 12)
	local rowsLabel = Kit.label(top, "", UDim2.new(1, -16, 0, 32), UDim2.fromOffset(8, 4), {
		Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = C.cream, Name = "Rows",
	})
	local nextLabel = Kit.label(top, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 36), {
		Font = Enum.Font.Gotham, TextSize = 16, TextColor3 = C.muted, Name = "Next",
	})
	local points = Kit.label(root, "", UDim2.fromOffset(470, 26), UDim2.new(0.5, -235, 0, 70), {
		Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = C.gold, Name = "Points", TextStrokeTransparency = 0.5,
	})
	local bottom = Kit.frame(root, UDim2.fromOffset(420, 34), UDim2.new(0.5, -210, 1, -40), C.ink, 0.3)
	bottom.Name = "BottomCounter"
	Kit.corner(bottom, 10)
	local booksLabel = Kit.label(bottom, "", UDim2.fromScale(1, 1), nil, { Font = Enum.Font.GothamBold, TextSize = 19, Name = "Books" })
	local timer = Kit.label(root, "", UDim2.fromOffset(180, 30), UDim2.new(1, -196, 0, 10), {
		Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.4, Name = "Timer",
	})

	-------------------------------------------------------------------
	-- Cruceta y texto de lo que se apunta
	-------------------------------------------------------------------
	local cross = Kit.frame(root, UDim2.fromOffset(10, 10), UDim2.new(0.5, -5, 0.5, -5), C.white, 0.15)
	cross.Name = "Crosshair"
	Kit.corner(cross, 5)
	Kit.stroke(cross, C.black, 1.5, 0.3)
	local aimLabel = Kit.label(root, "", UDim2.fromOffset(520, 28), UDim2.new(0.5, -260, 0.5, 18), {
		Font = Enum.Font.GothamBold, TextSize = 19, TextStrokeTransparency = 0.35, Name = "AimLabel",
	})

	-------------------------------------------------------------------
	-- Pila de libros en mano (abajo a la derecha; en táctil, a media altura)
	-------------------------------------------------------------------
	-- En táctil va arriba a la izquierda y más corta (abajo están el joystick y el botón de saltar)
	local handW = 330
	local handH = if ctx.touch then 190 else 380
	local maxBars = if ctx.touch then 5 else 15
	local handBox = Kit.frame(root, UDim2.fromOffset(handW, handH), UDim2.new(1, -handW - 12, 1, -handH - 12), C.ink, 1)
	handBox.Name = "Hand"
	if ctx.touch then
		handBox.Position = UDim2.fromOffset(12, 96)
	end
	local handCount = Kit.label(handBox, "", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 1, -24), {
		Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.4, Name = "Count",
	})
	local bars: { Frame } = {}
	local function bar(i: number): Frame
		local existing = bars[i]
		if existing then
			return existing
		end
		local f = Kit.frame(handBox, UDim2.fromOffset(handW, 18), UDim2.new(), C.panel)
		f.Name = "Book" .. i
		Kit.corner(f, 4)
		local band = Kit.frame(f, UDim2.new(0, 10, 1, 0), UDim2.fromOffset(0, 0), C.gold)
		band.Name = "Band"
		Kit.label(f, "", UDim2.new(1, -18, 1, 0), UDim2.fromOffset(14, 0), {
			Name = "Text", Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, TextStrokeTransparency = 0.6,
		})
		Kit.stroke(f, C.black, 1)
		bars[i] = f
		return f
	end

	local function refreshHand()
		local st = ctx.state
		local hand = st.hand or {}
		local def = Books.def
		handCount.Text = if #hand == 0 then T("hud_hand_empty") else T("hud_hand", { n = #hand, cap = st.cap or 10 })
		local y = handH - 30
		for i = 1, math.max(#hand, #bars) do
			local id = hand[i]
			if id and def and def.books[id] and i > #hand - maxBars then
				local f = bar(i)
				local info = def.books[id]
				local s = BookData.Series[info.series]
				local isTop = i == #hand
				local h = if isTop then 46 else 18
				y -= h + 3
				f.Visible = true
				f.Size = UDim2.fromOffset(handW, h)
				f.Position = UDim2.fromOffset(0, y)
				f.BackgroundColor3 = BookData.color(s.cover.base)
				local band = f:FindFirstChild("Band") :: Frame
				band.BackgroundColor3 = BookData.color(s.cover.band)
				local text = f:FindFirstChild("Text") :: TextLabel
				local title = if ctx.lang == "es" then s.es else s.en
				text.TextColor3 = BookData.color(s.cover.text)
				text.TextSize = if isTop then 15 else 13
				text.TextWrapped = isTop
				text.Text = if isTop
					then string.format("%s %s\n%s · %s", s.cover.sym, title, T("hud_vol", { v = info.vol, n = s.volumes }), T("hud_section", { code = def.seriesSection[info.series] }))
					else string.format("%d · %s", info.vol, title)
				local stroke = f:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if isTop then C.gold else C.black
					stroke.Thickness = if isTop then 2 else 1
				end
			elseif bars[i] then
				bars[i].Visible = false
			end
		end
	end

	-------------------------------------------------------------------
	-- Pistas del tutorial (izquierda)
	-------------------------------------------------------------------
	local hint = Kit.frame(root, UDim2.fromOffset(330, 96), UDim2.new(0, 12, 0.5, -48), C.ink, 0.25)
	hint.Name = "Hint"
	Kit.corner(hint, 10)
	Kit.stroke(hint, C.gold, 1.5, 0.4)
	Kit.pad(hint, 10)
	local hintText = Kit.label(hint, "", UDim2.fromScale(1, 1), nil, { TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Name = "Text" })
	if ctx.touch then
		hint.Position = UDim2.fromOffset(12, 300)
	end

	local function refreshHint()
		local st = ctx.state
		local tut = st.tut or 0
		local useKey = ctx.keyName("use")
		local text = ""
		if st.mode == "main" then
			if tut == 0 then
				text = T("tut_letter", { key = useKey })
			elseif tut == 1 then
				text = T("tut_pick", { key = useKey })
			elseif tut == 2 then
				text = T("tut_place")
			elseif tut == 3 then
				text = T("tut_row")
			elseif tut == 4 and (st.shelved or 0) < 60 then
				text = T("tut_free", { map = ctx.keyName("map"), list = ctx.keyName("list"), manual = ctx.keyName("manual") })
			end
		end
		hint.Visible = text ~= ""
		hintText.Text = text
	end

	-------------------------------------------------------------------
	-- Avisos
	-------------------------------------------------------------------
	local toasts = Kit.frame(root, UDim2.fromOffset(520, 200), UDim2.new(0.5, -260, 0, 120), C.ink, 1)
	toasts.Name = "Toasts"
	Kit.list(toasts, true, 6, Enum.HorizontalAlignment.Center)
	local order = 0
	ctx.toast = function(text: string, kind: string?)
		if text == "" then
			return
		end
		order += 1
		local color = if kind == "error" then C.red elseif kind == "success" or kind == "row" then C.green elseif kind == "point" or kind == "goal" then C.gold else C.cream
		local t = Kit.label(toasts, text, UDim2.fromOffset(520, 34), nil, {
			Font = Enum.Font.GothamBold, TextSize = 19, TextColor3 = color, BackgroundTransparency = 0.25,
			BackgroundColor3 = C.ink, LayoutOrder = order, Name = "Toast",
		})
		Kit.corner(t, 8)
		local kids = toasts:GetChildren()
		local count = 0
		for _, k in kids do
			if k:IsA("TextLabel") then
				count += 1
			end
		end
		if count > 4 then
			for _, k in kids do
				if k:IsA("TextLabel") and k ~= t then
					k:Destroy()
					break
				end
			end
		end
		task.delay(if kind == "error" then 2.5 else 3.5, function()
			if t.Parent then
				t:Destroy()
			end
		end)
	end

	-------------------------------------------------------------------
	-- Botones táctiles
	-------------------------------------------------------------------
	local runButton: TextButton? = nil
	if ctx.touch then
		local left = ctx.state.settings ~= nil and ctx.state.settings.left == true
		-- (dx, dy) = centro del botón medido desde la esquina de abajo a la derecha (o a la izquierda para zurdos)
		local function round(name: string, text: string, size: number, dx: number, dy: number, onClick: () -> ()): TextButton
			local x = if left then UDim2.new(0, dx - size / 2, 1, -dy - size / 2) else UDim2.new(1, -dx - size / 2, 1, -dy - size / 2)
			local b = Kit.button(root, text, UDim2.fromOffset(size, size), x, function()
				onClick()
			end, { Name = "Touch_" .. name, BackgroundTransparency = 0.15, TextSize = if size > 90 then 24 else 16 })
			local corner = b:FindFirstChildOfClass("UICorner")
			if corner then
				corner.CornerRadius = UDim.new(0.5, 0)
			end
			ctx.targets["touch_" .. name] = b
			return b
		end
		round("use", T("btn_use"), 120, 180, 330, function()
			ctx.input.use()
		end)
		local drop = round("drop", T("btn_drop"), 80, 320, 250, function() end)
		-- Soltar: toque corto = el de arriba; mantener = toda la pila
		local downAt = 0
		drop.MouseButton1Down:Connect(function()
			downAt = os.clock()
		end)
		drop.MouseButton1Up:Connect(function()
			if os.clock() - downAt >= 0.45 then
				ctx.input.dropAll()
			else
				ctx.input.drop()
			end
		end)
		round("throw", T("btn_throw"), 80, 320, 410, function()
			ctx.input.throw()
		end)
		round("cycle", T("btn_cycle"), 68, 180, 470, function()
			ctx.input.cycle()
		end)
		runButton = round("run", T("btn_run"), 68, 70, 420, function()
			ctx.input.toggleRun()
		end)
		local names = { "list", "map", "manual", "menu" }
		for i, name in names do
			local x = 12 + (#names - i) * 96
			local b = Kit.button(root, T("btn_" .. name), UDim2.fromOffset(88, 40), if left then UDim2.fromOffset(x, 50) else UDim2.new(1, -x - 88, 0, 50), function()
				ctx.input[name]()
			end, { Name = "Touch_" .. name, TextSize = 15, BackgroundTransparency = 0.15 })
			ctx.targets["touch_" .. name] = b
		end
	end

	-------------------------------------------------------------------
	-- Refresco
	-------------------------------------------------------------------
	local function refresh()
		local st = ctx.state
		local inWorld = st.mode == "main" or st.mode == "special"
		top.Visible = inWorld
		bottom.Visible = inWorld
		handBox.Visible = inWorld
		rowsLabel.Text = T("hud_rows", { n = Kit.num(st.rows or 0), total = Kit.num(st.rowsTotal or 400) })
		booksLabel.Text = T("hud_books", { n = Kit.num(st.shelved or 0), total = Kit.num(st.total or 3072) })
		local nextAt = st.nextAt or 0
		nextLabel.Visible = st.mode == "main"
		if nextAt > 0 then
			nextLabel.Text = T("hud_next", { n = math.max(1, nextAt - (st.rows or 0)) })
		else
			nextLabel.Text = T("hud_next_max")
		end
		points.Visible = st.mode == "main" and (st.points or 0) > 0
		points.Text = T("hud_points", { n = st.points or 0, key = ctx.keyName("manual") })
		if runButton then
			runButton.Visible = st.run == true
		end
		refreshHand()
		refreshHint()
		Hud.stateAt = os.clock()
	end
	table.insert(ctx.refreshers, refresh)

	table.insert(ctx.tickers, function()
		local st = ctx.state
		local inWorld = st.mode == "main" or st.mode == "special"
		local open = ctx.panel ~= nil
		cross.Visible = inWorld and not open
		local target = Aim.target
		aimLabel.Visible = inWorld and not open and target ~= nil
		if target then
			aimLabel.Text = target.label
			aimLabel.TextColor3 = if target.ok then C.cream else Color3.fromRGB(255, 160, 150)
		end
		timer.Visible = st.mode == "main" and not (st.settings and st.settings.cozy)
		if timer.Visible then
			timer.Text = Lang.time(ctx.lang, (st.time or 0) + (os.clock() - Hud.stateAt))
		end
	end)
end

return Hud
