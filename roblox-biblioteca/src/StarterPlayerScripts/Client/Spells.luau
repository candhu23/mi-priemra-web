--!strict
-- Magia mayor en el cliente: barra de 5 hechizos (teclas 1–5, enfriamiento visible), manual personal
-- (aprender y subir niveles) y efectos: Guía (resalta la estantería) y Revelar (los tomos brillan).
-- El servidor decide si se puede; aquí solo se pide y se dibuja.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Books = require(script.Parent:WaitForChild("Books"))
local Aim = require(script.Parent:WaitForChild("Aim"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local Spells = {}
local C = Kit.C

local ICON = { sort = "⇅", guide = "➜", reveal = "✦", auto = "⇲", gather = "✋" }
Spells.ICON = ICON

-- Segundos que faltan (enfriamiento o efecto) según el último estado recibido
local function left(kind: string, id: string): number
	local st = Kit.ctx.state
	local t = st[kind] and st[kind][id] or 0
	return math.max(0, t - (os.clock() - Hud.stateAt))
end
Spells.left = left

-- Texto con los valores de un hechizo a un nivel
function Spells.stats(id: string, level: number): string
	local T = Kit.T
	if level < 1 then
		return T("sk_locked")
	end
	local parts = {}
	local dur = Rules.skill(id, level, "duration")
	if dur > 0 then
		table.insert(parts, T("sk_dur", { s = dur }))
	elseif id == "gather" then
		table.insert(parts, T("sk_count", { n = Rules.skill(id, level, "count") }))
	else
		table.insert(parts, T("sk_instant"))
	end
	if id == "reveal" then
		table.insert(parts, T("sk_range", { n = Rules.skill(id, level, "range") }))
	end
	table.insert(parts, T("sk_cd", { s = Rules.skill(id, level, "cooldown") }))
	return table.concat(parts, " · ")
end

function Spells.build(ctx: Kit.Ctx)
	local T = Kit.T
	local root = ctx.root

	-------------------------------------------------------------------
	-- Lanzar: Autocolocar con el efecto activo coloca en la sección apuntada
	-------------------------------------------------------------------
	ctx.input.castSkill = function(i: number)
		local sk = Config.Skills[i]
		if not sk then
			return
		end
		if sk.id == "auto" and left("active", "auto") > 0 then
			if Aim.sectionCode then
				ctx.act("autoPlace", Aim.sectionCode)
			else
				ctx.toast(T("err_aim_section"), "error")
			end
			return
		end
		ctx.act("cast", sk.id)
	end

	-------------------------------------------------------------------
	-- Barra de hechizos (abajo, encima del contador de libros)
	-------------------------------------------------------------------
	local SIZE = if ctx.touch then 70 else 62
	local bar = Kit.frame(root, UDim2.fromOffset(5 * (SIZE + 8), SIZE + 18), UDim2.new(0.5, -5 * (SIZE + 8) / 2, 1, -SIZE - 66), C.ink, 1)
	bar.Name = "SpellBar"
	local slots: { { button: TextButton, shade: Frame, active: Frame, level: TextLabel, timer: TextLabel } } = {}
	for i, sk in Config.Skills do
		local b = Kit.button(bar, "", UDim2.fromOffset(SIZE, SIZE), UDim2.fromOffset((i - 1) * (SIZE + 8) + 4, 0), function()
			ctx.input.cast(i)
		end, { Name = "Spell_" .. sk.id, BackgroundColor3 = C.panel, BackgroundTransparency = 0.1, ClipsDescendants = true })
		ctx.targets["spell_" .. sk.id] = b
		Kit.label(b, ICON[sk.id], UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0.12), { TextSize = 28, Font = Enum.Font.GothamBlack, Name = "Icon", TextColor3 = C.gold })
		Kit.label(b, tostring(sk.key), UDim2.fromOffset(18, 18), UDim2.fromOffset(4, 2), { TextSize = 14, Font = Enum.Font.GothamBold, Name = "Key", TextXAlignment = Enum.TextXAlignment.Left })
		local level = Kit.label(b, "", UDim2.new(1, -4, 0, 16), UDim2.new(0, 2, 1, -18), { TextSize = 12, Name = "Level", TextColor3 = C.muted })
		local shade = Kit.frame(b, UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), C.black, 0.35)
		shade.Name = "Cooldown"
		shade.AnchorPoint = Vector2.new(0, 1)
		shade.ZIndex = 3
		local active = Kit.frame(b, UDim2.new(1, 0, 0, 5), UDim2.fromScale(0, 0), C.blue, 0)
		active.Name = "Active"
		active.ZIndex = 4
		local timer = Kit.label(b, "", UDim2.fromScale(1, 1), nil, { TextSize = 20, Font = Enum.Font.GothamBlack, ZIndex = 5, Name = "Timer", TextStrokeTransparency = 0.3 })
		slots[i] = { button = b, shade = shade, active = active, level = level, timer = timer }
	end

	table.insert(ctx.tickers, function()
		local st = ctx.state
		bar.Visible = st.mode == "main" and ctx.panel == nil
		if not bar.Visible then
			return
		end
		local skills = st.skills or {}
		for i, sk in Config.Skills do
			local s = slots[i]
			local lv = skills[sk.id] or 0
			s.level.Text = if lv > 0 then T("sk_level", { l = lv, max = sk.max }) else "🔒"
			s.button.BackgroundTransparency = if lv > 0 then 0.1 else 0.55
			local act = left("active", sk.id)
			local cd = left("cd", sk.id)
			local dur = Rules.skill(sk.id, lv, "duration")
			if act > 0 then
				s.active.Visible = true
				s.active.Size = UDim2.new(math.clamp(act / math.max(dur, 1), 0, 1), 0, 0, 5)
				s.shade.Size = UDim2.fromScale(1, 0)
				s.timer.Text = tostring(math.ceil(act))
				s.timer.TextColor3 = C.blue
			elseif cd > 0 then
				s.active.Visible = false
				local total = Rules.skill(sk.id, lv, "cooldown")
				s.shade.Size = UDim2.fromScale(1, math.clamp(cd / math.max(total, 1), 0, 1))
				s.timer.Text = tostring(math.ceil(cd))
				s.timer.TextColor3 = C.cream
			else
				s.active.Visible = false
				s.shade.Size = UDim2.fromScale(1, 0)
				s.timer.Text = ""
			end
		end
	end)

	-------------------------------------------------------------------
	-- Efectos de Guía y Revelar (siguen al libro de arriba de la pila)
	-------------------------------------------------------------------
	local guided: number? = nil
	local revealed: number? = nil
	local t = 0
	table.insert(ctx.tickers, function(dt: number)
		t += dt or 0
		if t < 0.2 then
			return
		end
		t = 0
		local st = ctx.state
		local hand = st.hand or {}
		local def = Books.def
		local top = hand[#hand]
		local series = if top and def and def.books[top] then def.books[top].series else nil
		local g = if st.mode == "main" and left("active", "guide") > 0 then series else nil
		if g ~= guided then
			guided = g
			Books.guide(g)
		end
		local r = if st.mode == "main" and left("active", "reveal") > 0 then series else nil
		local char = Players.LocalPlayer and Players.LocalPlayer.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		local origin = if rootPart and rootPart:IsA("BasePart") then rootPart.CFrame.Position else (Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position)
		local range = Rules.skill("reveal", (st.skills or {}).reveal or 0, "range")
		if r ~= revealed or r then
			revealed = r
			Books.reveal(r, origin, range)
		end
	end)

	-------------------------------------------------------------------
	-- Manual personal (tecla B)
	-------------------------------------------------------------------
	local manual = Kit.panel("manual", 860, 640, T("manual_title"))
	local points = Kit.label(manual.body, "", UDim2.new(1, 0, 0, 30), nil, {
		Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Name = "Points",
	})
	Kit.label(manual.body, T("manual_hint"), UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 32), {
		TextSize = 15, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23,
	})
	local rows: { { level: TextLabel, stats: TextLabel, nextL: TextLabel, button: TextButton, pips: Frame } } = {}
	for i, sk in Config.Skills do
		local y = 64 + (i - 1) * 98
		local card = Kit.frame(manual.body, UDim2.new(1, 0, 0, 90), UDim2.fromOffset(0, y), C.panel2, 0)
		card.Name = "Skill_" .. sk.id
		card.ZIndex = 23
		Kit.corner(card, 10)
		local icon = Kit.label(card, ICON[sk.id], UDim2.fromOffset(64, 64), UDim2.fromOffset(12, 13), {
			TextSize = 34, Font = Enum.Font.GothamBlack, TextColor3 = C.gold, BackgroundTransparency = 0, BackgroundColor3 = C.ink, ZIndex = 24,
		})
		Kit.corner(icon, 32)
		Kit.label(card, string.format("%d · %s", sk.key, T("sk_" .. sk.id)), UDim2.new(0.5, 0, 0, 26), UDim2.fromOffset(90, 6), {
			Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24,
		})
		Kit.label(card, T("sk_" .. sk.id .. "_d"), UDim2.new(1, -330, 0, 34), UDim2.fromOffset(90, 30), {
			TextSize = 13, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 24,
		})
		local stats = Kit.label(card, "", UDim2.new(1, -330, 0, 20), UDim2.fromOffset(90, 66), {
			TextSize = 13, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Name = "Stats",
		})
		local level = Kit.label(card, "", UDim2.fromOffset(110, 22), UDim2.new(1, -232, 0, 8), {
			Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 24, Name = "Level",
		})
		local pips = Kit.frame(card, UDim2.fromOffset(110, 8), UDim2.new(1, -232, 0, 34), C.ink, 0)
		pips.Name = "Pips"
		pips.ZIndex = 24
		Kit.corner(pips, 4)
		local fill = Kit.frame(pips, UDim2.fromScale(0, 1), nil, C.gold, 0)
		fill.Name = "Fill"
		fill.ZIndex = 25
		Kit.corner(fill, 4)
		local nextL = Kit.label(card, "", UDim2.fromOffset(220, 30), UDim2.new(1, -232, 0, 48), {
			TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 24, Name = "Next",
		})
		local button = Kit.button(card, T("btn_learn"), UDim2.fromOffset(104, 44), UDim2.new(1, -114, 0, 8), function()
			ctx.act("buySkill", sk.id)
		end, { ZIndex = 24, Name = "Buy", TextSize = 16 })
		ctx.targets["buy_" .. sk.id] = button
		rows[i] = { level = level, stats = stats, nextL = nextL, button = button, pips = pips }
	end
	local function refreshManual()
		local st = ctx.state
		local skills = st.skills or {}
		points.Text = T("manual_points", { n = st.points or 0 })
		for i, sk in Config.Skills do
			local r = rows[i]
			local lv = skills[sk.id] or 0
			r.level.Text = if lv > 0 then T("sk_level", { l = lv, max = sk.max }) else T("sk_locked")
			r.stats.Text = Spells.stats(sk.id, lv)
			local fill = r.pips:FindFirstChild("Fill") :: Frame
			fill.Size = UDim2.fromScale(lv / sk.max, 1)
			if lv >= sk.max then
				r.nextL.Text = ""
				r.button.Text = "✔"
				r.button.Active = false
				r.button.AutoButtonColor = false
				r.button.BackgroundColor3 = C.goldDark
			else
				r.nextL.Text = T("sk_next", { text = Spells.stats(sk.id, lv + 1) })
				r.button.Text = if lv == 0 then T("btn_learn") else T("btn_upgrade")
				local can = (st.points or 0) > 0
				r.button.Active = can
				r.button.AutoButtonColor = can
				r.button.BackgroundColor3 = if can then Color3.fromRGB(70, 110, 60) else C.panel
			end
		end
	end
	ctx.panels.manual = {
		open = function()
			refreshManual()
			manual.shell.Visible = true
		end,
		close = function()
			manual.shell.Visible = false
		end,
	}
	table.insert(ctx.refreshers, function()
		if ctx.panel == "manual" then
			refreshManual()
		end
	end)
end

return Spells
