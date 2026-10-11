--!strict
-- Menús: pantalla de título (Continuar, Nueva partida, 3 ranuras, Fase especial, Logros, Opciones),
-- pausa (P), opciones, logros, confirmaciones, evaluación de la rectora al salir y la barra de la
-- habilidad definitiva en la fase especial.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Shop = require(script.Parent:WaitForChild("Shop"))

local Menus = {}
local C = Kit.C

function Menus.build(ctx: Kit.Ctx)
	local T = Kit.T
	local root = ctx.root
	Shop.build(ctx)

	-------------------------------------------------------------------
	-- Confirmación (Sí / No)
	-------------------------------------------------------------------
	local confirm = Kit.panel("confirm", 520, 240, "")
	local confirmText = Kit.label(confirm.body, "", UDim2.new(1, 0, 0, 80), nil, { TextSize = 20, ZIndex = 23, Name = "Text" })
	local onYes: (() -> ())? = nil
	local yes = Kit.button(confirm.body, T("btn_yes"), UDim2.fromOffset(180, 50), UDim2.new(0.5, -190, 1, -58), function()
		local f = onYes
		ctx.closePanel()
		if f then
			f()
		end
	end, { ZIndex = 23, Name = "Yes", BackgroundColor3 = Color3.fromRGB(150, 60, 50) })
	Kit.button(confirm.body, T("btn_no"), UDim2.fromOffset(180, 50), UDim2.new(0.5, 10, 1, -58), function()
		ctx.closePanel()
	end, { ZIndex = 23, Name = "No" })
	ctx.targets.confirm_yes = yes
	local backTo: string? = nil
	local function ask(text: string, f: () -> ())
		backTo = nil
		confirmText.Text = text
		onYes = f
		ctx.openPanel("confirm")
	end
	ctx.panels.confirm = {
		open = function()
			confirm.shell.Visible = true
		end,
		close = function()
			confirm.shell.Visible = false
			onYes = nil
			local _ = backTo
		end,
	}

	-------------------------------------------------------------------
	-- Opciones
	-------------------------------------------------------------------
	local opt = Kit.panel("options", 760, 640, T("opt_title"))
	local optRows: { [string]: TextLabel } = {}
	local function settings(): { [string]: any }
		return ctx.state.settings or {}
	end
	local function row(i: number, label: string): Frame
		local f = Kit.frame(opt.body, UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, (i - 1) * 52), C.panel2, 0)
		f.ZIndex = 23
		Kit.corner(f, 8)
		Kit.label(f, label, UDim2.new(0.45, 0, 1, 0), UDim2.fromOffset(14, 0), { TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24 })
		return f
	end
	local function value(f: Frame, name: string): TextLabel
		local v = Kit.label(f, "", UDim2.fromOffset(150, 46), UDim2.new(1, -250, 0, 0), { TextSize = 18, Font = Enum.Font.GothamBold, ZIndex = 24, Name = "Value" })
		optRows[name] = v
		return v
	end
	local function stepper(i: number, name: string, label: string, step: number, minV: number, maxV: number)
		local f = row(i, label)
		value(f, name)
		local function change(d: number)
			local cur = settings()[name] or 0
			ctx.act("setOption", name, math.clamp(cur + d, minV, maxV))
		end
		ctx.targets["opt_" .. name .. "_down"] = Kit.button(f, "−", UDim2.fromOffset(44, 38), UDim2.new(1, -300, 0, 4), function()
			change(-step)
		end, { ZIndex = 24, Name = "Down" })
		ctx.targets["opt_" .. name .. "_up"] = Kit.button(f, "+", UDim2.fromOffset(44, 38), UDim2.new(1, -96, 0, 4), function()
			change(step)
		end, { ZIndex = 24, Name = "Up" })
	end
	local function toggle(i: number, name: string, label: string)
		local f = row(i, label)
		value(f, name)
		ctx.targets["opt_" .. name] = Kit.button(f, "⇄", UDim2.fromOffset(92, 38), UDim2.new(1, -100, 0, 4), function()
			ctx.act("setOption", name, not settings()[name])
		end, { ZIndex = 24, Name = "Toggle" })
	end
	-- Idioma: Automático / Español / English
	local langRow = row(1, T("opt_lang"))
	for j, code in { "", "es", "en" } do
		local text = if code == "" then T("opt_lang_auto") elseif code == "es" then "Español" else "English"
		ctx.targets["opt_lang_" .. (if code == "" then "auto" else code)] = Kit.button(langRow, text, UDim2.fromOffset(124, 38), UDim2.new(1, -396 + (j - 1) * 132, 0, 4), function()
			ctx.act("setOption", "lang", code)
		end, { ZIndex = 24, TextSize = 15, Name = "Lang_" .. (if code == "" then "auto" else code) })
	end
	stepper(2, "sens", T("opt_sens"), 0.1, 0.2, 3)
	stepper(3, "fov", T("opt_fov"), 5, 50, 100)
	stepper(4, "music", T("opt_music"), 0.1, 0, 1)
	stepper(5, "sfx", T("opt_sfx"), 0.1, 0, 1)
	toggle(6, "bob", T("opt_bob"))
	toggle(7, "cozy", T("opt_cozy"))
	toggle(8, "left", T("opt_left"))
	Kit.label(opt.body, T("opt_cozy_d"), UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 8 * 52 + 4), {
		TextSize = 14, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23,
	})
	local function refreshOptions()
		local st = settings()
		local function onOff(b: any): string
			return if b then "✔" else "—"
		end
		if optRows.sens then
			optRows.sens.Text = string.format("%.1f", st.sens or 1)
			optRows.fov.Text = tostring(st.fov or 70)
			optRows.music.Text = string.format("%d %%", math.floor((st.music or 0) * 100 + 0.5))
			optRows.sfx.Text = string.format("%d %%", math.floor((st.sfx or 0) * 100 + 0.5))
			optRows.bob.Text = onOff(st.bob)
			optRows.cozy.Text = onOff(st.cozy)
			optRows.left.Text = onOff(st.left)
		end
	end
	ctx.panels.options = {
		open = function()
			refreshOptions()
			opt.shell.Visible = true
		end,
		close = function()
			opt.shell.Visible = false
		end,
	}
	table.insert(ctx.refreshers, function()
		if ctx.panel == "options" then
			refreshOptions()
		end
	end)

	-------------------------------------------------------------------
	-- Logros
	-------------------------------------------------------------------
	local ach = Kit.panel("achievements", 760, 620, T("menu_achievements"))
	local achList = Instance.new("ScrollingFrame")
	achList.Size = UDim2.fromScale(1, 1)
	achList.BackgroundTransparency = 1
	achList.BorderSizePixel = 0
	achList.ScrollBarThickness = 6
	achList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	achList.CanvasSize = UDim2.new()
	achList.ZIndex = 23
	achList.Parent = ach.body
	Kit.list(achList, true, 6)
	local function refreshAch()
		for _, c in achList:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local got = ctx.state.achievements or {}
		for i, id in Config.Achievements do
			local done = got[id] == true
			local f = Kit.frame(achList, UDim2.new(1, -10, 0, 52), nil, if done then Color3.fromRGB(70, 90, 50) else C.panel2, 0)
			f.LayoutOrder = i
			f.ZIndex = 24
			Kit.corner(f, 8)
			Kit.label(f, if done then "🏅" else "🔒", UDim2.fromOffset(46, 52), nil, { TextSize = 26, ZIndex = 25 })
			Kit.label(f, T("ach_" .. id), UDim2.new(1, -60, 0, 26), UDim2.fromOffset(52, 2), {
				Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 25,
			})
			Kit.label(f, T("ach_" .. id .. "_d"), UDim2.new(1, -60, 0, 22), UDim2.fromOffset(52, 27), {
				TextSize = 14, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 25,
			})
		end
	end
	ctx.panels.achievements = {
		open = function()
			refreshAch()
			ach.shell.Visible = true
		end,
		close = function()
			ach.shell.Visible = false
		end,
	}

	-------------------------------------------------------------------
	-- Pausa (P / botón Menú)
	-------------------------------------------------------------------
	local pause = Kit.panel("menu", 560, 560, T("btn_menu"))
	local pauseButtons: { { id: string, text: string, f: () -> () } } = {
		{ id = "continue", text = T("btn_continue"), f = function()
			ctx.closePanel()
		end },
		{ id = "options", text = T("menu_options"), f = function()
			ctx.openPanel("options")
		end },
		{ id = "achievements", text = T("menu_achievements"), f = function()
			ctx.openPanel("achievements")
		end },
		{ id = "tomenu", text = T("btn_to_menu"), f = function()
			ctx.closePanel()
			ctx.act("toMenu")
		end },
		{ id = "shop", text = T("btn_shop"), f = function()
			ctx.openPanel("shop")
		end },
	}
	for i, b in pauseButtons do
		ctx.targets["pause_" .. b.id] = Kit.button(pause.body, b.text, UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, (i - 1) * 60), b.f, {
			ZIndex = 23, Name = "Pause_" .. b.id, TextSize = 20,
		})
	end
	local help = Kit.label(pause.body, "", UDim2.new(1, 0, 0, 200), UDim2.fromOffset(0, 5 * 60 + 6), {
		TextSize = 13, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23, Name = "Help",
	})
	ctx.panels.menu = {
		open = function()
			ctx.targets.pause_shop.Visible = Shop.available(ctx.state)
			help.Text = T("opt_controls") .. "\n" .. (if ctx.touch then T("help_touch") elseif ctx.gamepad then T("help_pad") else T("help_pc"))
			pause.shell.Visible = true
		end,
		close = function()
			pause.shell.Visible = false
		end,
	}

	-------------------------------------------------------------------
	-- Evaluación de la rectora (al salir por la puerta)
	-------------------------------------------------------------------
	local res = Kit.panel("results", 720, 620, T("res_title"))
	local resEnding = Kit.label(res.body, "", UDim2.new(1, 0, 0, 44), nil, {
		Font = Enum.Font.Garamond, TextSize = 38, TextColor3 = C.gold, ZIndex = 23, Name = "Ending",
	})
	local resText = Kit.label(res.body, "", UDim2.new(1, 0, 0, 120), UDim2.fromOffset(0, 48), {
		Font = Enum.Font.Garamond, TextSize = 21, ZIndex = 23, Name = "Text",
	})
	local resStats = Kit.label(res.body, "", UDim2.new(1, 0, 0, 170), UDim2.fromOffset(0, 176), {
		TextSize = 18, ZIndex = 23, Name = "Stats", TextYAlignment = Enum.TextYAlignment.Top,
	})
	local resRank = Kit.label(res.body, "", UDim2.new(1, 0, 0, 56), UDim2.fromOffset(0, 350), {
		Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = C.cream, ZIndex = 23, Name = "Rank",
	})
	ctx.targets.results_menu = Kit.button(res.body, T("btn_to_menu"), UDim2.fromOffset(260, 52), UDim2.new(0.5, -270, 1, -60), function()
		ctx.closePanel()
		ctx.act("toMenu")
	end, { ZIndex = 23, Name = "ToMenu" })
	ctx.targets.results_stay = Kit.button(res.body, T("btn_continue"), UDim2.fromOffset(260, 52), UDim2.new(0.5, 10, 1, -60), function()
		ctx.closePanel()
	end, { ZIndex = 23, Name = "Stay" })
	ctx.showResults = function(r: { [string]: any })
		if r.kind == "special" then
			resEnding.Text = T("sp_done")
			resText.Text = T("sp_done_d") .. (if r.used then "\n\n" .. T("sp_badge") else "")
			local rowsText = string.gsub(T("res_rows", { n = r.rows }), "400", tostring(r.total))
			resStats.Text = rowsText
			resRank.Text = ""
		else
			resEnding.Text = T("end_" .. r.ending)
			resText.Text = T("end_" .. r.ending .. "_d")
			local lines = {
				T("res_time", { time = Lang.time(ctx.lang, r.time) }),
				T("res_rows", { n = r.rows }),
				T("res_magic", { v = T(if r.magic then "res_yes" else "res_no") }),
				T("res_keys", { n = r.keys }),
				if r.best and r.best > 0 then T("res_best", { time = Lang.time(ctx.lang, r.best) }) else T("best_none"),
			}
			if r.newBest then
				table.insert(lines, T("res_new_best"))
			end
			resStats.Text = table.concat(lines, "\n")
			resRank.Text = T("res_rank") .. ": " .. T("rank_" .. r.rank)
			resRank.TextColor3 = if r.rank <= 1 then C.red elseif r.rank >= 5 then C.gold else C.cream
		end
		ctx.openPanel("results")
	end
	ctx.panels.results = {
		open = function()
			res.shell.Visible = true
		end,
		close = function()
			res.shell.Visible = false
		end,
	}

	-------------------------------------------------------------------
	-- Pantalla de título
	-------------------------------------------------------------------
	local title = Instance.new("Frame")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.ZIndex = 10
	title.Visible = false
	title.Parent = root
	-- Botón «Modal» de fondo: suelta el ratón en el menú
	local modal = Instance.new("TextButton")
	modal.Name = "Modal"
	modal.Size = UDim2.fromScale(1, 1)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Modal = true
	modal.AutoButtonColor = false
	modal.ZIndex = 10
	modal.Parent = title
	local left = Kit.frame(title, UDim2.new(0, 470, 1, 0), nil, C.ink, 0.2)
	left.ZIndex = 11
	left.Active = true
	Kit.label(left, Config.GAME_NAME[ctx.lang] or Config.GAME_NAME.en, UDim2.new(1, -40, 0, 120), UDim2.fromOffset(20, 60), {
		Font = Enum.Font.Garamond, TextSize = 58, TextColor3 = C.gold, ZIndex = 12, Name = "GameName",
	})
	Kit.label(left, T("n_welcome"), UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 176), {
		TextSize = 17, TextColor3 = C.muted, ZIndex = 12,
	})
	local best = Kit.label(left, "", UDim2.new(1, -40, 0, 26), UDim2.fromOffset(20, 206), { TextSize = 16, TextColor3 = C.cream, ZIndex = 12, Name = "Best" })
	local warn = Kit.label(left, "", UDim2.new(1, -40, 0, 60), UDim2.new(0, 20, 1, -76), {
		TextSize = 14, TextColor3 = Color3.fromRGB(255, 150, 130), ZIndex = 12, Name = "Warning",
	})
	local choosing = false -- «Nueva partida»: las ranuras dicen «Empezar aquí»
	local menuButtons: { [string]: TextButton } = {}
	local function mb(i: number, name: string, text: string, f: () -> ())
		local b = Kit.button(left, text, UDim2.new(1, -40, 0, 54), UDim2.fromOffset(20, 246 + (i - 1) * 64), f, {
			ZIndex = 12, Name = "Menu_" .. name, TextSize = 21,
		})
		menuButtons[name] = b
		ctx.targets["menu_" .. name] = b
	end
	local refreshTitle: () -> ()
	mb(1, "continue", T("menu_continue"), function()
		local n = ctx.state.lastSlot or 0
		if n > 0 then
			ctx.act("selectSlot", n)
		end
	end)
	mb(2, "new", T("menu_new"), function()
		choosing = not choosing
		refreshTitle()
	end)
	mb(3, "special", T("menu_special"), function()
		ctx.act("startSpecial")
	end)
	mb(4, "achievements", T("menu_achievements"), function()
		ctx.openPanel("achievements")
	end)
	mb(5, "options", T("menu_options"), function()
		ctx.openPanel("options")
	end)
	mb(6, "shop", T("btn_shop"), function()
		ctx.openPanel("shop")
	end)
	-- Ranuras
	local slotsBox = Kit.frame(title, UDim2.fromOffset(520, 3 * 150), UDim2.new(1, -560, 0.5, -225), C.ink, 1)
	slotsBox.ZIndex = 11
	local slotHeader = Kit.label(title, T("menu_slots"), UDim2.fromOffset(520, 40), UDim2.new(1, -560, 0.5, -270), {
		Font = Enum.Font.Garamond, TextSize = 30, TextColor3 = C.gold, ZIndex = 12, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local cards: { { frame: Frame, info: TextLabel, play: TextButton, delete: TextButton } } = {}
	for i = 1, Config.SLOTS do
		local f = Kit.frame(slotsBox, UDim2.new(1, 0, 0, 138), UDim2.fromOffset(0, (i - 1) * 150), C.panel, 0.08)
		f.Name = "Slot" .. i
		f.ZIndex = 12
		f.Active = true
		Kit.corner(f, 12)
		Kit.stroke(f, C.goldDark, 2)
		Kit.label(f, T("slot_n", { n = i }), UDim2.new(1, -20, 0, 32), UDim2.fromOffset(16, 8), {
			Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13,
		})
		local info = Kit.label(f, "", UDim2.new(1, -32, 0, 44), UDim2.fromOffset(16, 40), {
			TextSize = 15, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 13, Name = "Info",
		})
		local play = Kit.button(f, "", UDim2.fromOffset(220, 42), UDim2.new(0, 16, 1, -52), function()
			local slots = ctx.state.slots or {}
			local exists = slots[i] ~= nil and slots[i] ~= false
			if choosing or not exists then
				if exists then
					ask(T("confirm_overwrite"), function()
						choosing = false
						ctx.act("newGame", i)
					end)
				else
					choosing = false
					ctx.act("newGame", i)
				end
			else
				ctx.act("selectSlot", i)
			end
		end, { ZIndex = 13, Name = "Play", BackgroundColor3 = Color3.fromRGB(70, 110, 60) })
		local delete = Kit.button(f, T("slot_delete"), UDim2.fromOffset(130, 42), UDim2.new(1, -146, 1, -52), function()
			ask(T("confirm_delete", { n = i }), function()
				ctx.act("deleteSlot", i)
			end)
		end, { ZIndex = 13, Name = "Delete" })
		ctx.targets["slot_play_" .. i] = play
		ctx.targets["slot_delete_" .. i] = delete
		cards[i] = { frame = f, info = info, play = play, delete = delete }
	end
	function refreshTitle()
		local st = ctx.state
		local inMenu = st.mode == "menu"
		title.Visible = inMenu
		if not inMenu then
			choosing = false
			return
		end
		local slots = st.slots or {}
		local last = st.lastSlot or 0
		menuButtons.continue.Visible = last > 0 and slots[last] ~= nil and slots[last] ~= false
		menuButtons.shop.Visible = Shop.available(ctx.state)
		menuButtons.special.Text = if st.specialUnlocked then T("menu_special") else "🔒 " .. T("menu_special")
		menuButtons.special.AutoButtonColor = st.specialUnlocked == true
		menuButtons.new.Text = if choosing then "✕ " .. T("menu_new") else T("menu_new")
		slotHeader.Text = T("menu_slots")
		best.Text = if (st.bestTime or 0) > 0 then T("best_time", { time = Lang.time(ctx.lang, st.bestTime) }) else T("best_none")
		warn.Text = if st.loadFailed then T("warn_load_failed") elseif st.canSave == false then T("warn_no_save") else ""
		for i, card in cards do
			local sl = slots[i]
			local exists = sl ~= nil and sl ~= false
			if exists then
				local line = T("slot_info", { rows = sl.rows, books = Kit.num(sl.shelved), time = Lang.time(ctx.lang, sl.time) })
				if sl.finished and (sl.rank or 0) > 0 then
					line ..= "\n" .. T("slot_finished", { rank = T("rank_" .. sl.rank) })
				end
				card.info.Text = line
			else
				card.info.Text = T("slot_empty")
			end
			card.play.Text = if choosing or not exists then T("slot_start") else T("slot_play")
			card.delete.Visible = exists and not choosing
			card.frame.BackgroundColor3 = if i == last then C.panel2 else C.panel
		end
	end
	table.insert(ctx.refreshers, refreshTitle)

	-------------------------------------------------------------------
	-- Barra de la definitiva (fase especial)
	-------------------------------------------------------------------
	local ult = Kit.frame(root, UDim2.fromOffset(420, 40), UDim2.new(0.5, -210, 0, 72), C.ink, 0.25)
	ult.Name = "Ultimate"
	Kit.corner(ult, 10)
	local ultFill = Kit.frame(ult, UDim2.fromScale(0, 1), nil, Color3.fromRGB(110, 90, 220), 0)
	ultFill.Name = "Fill"
	Kit.corner(ultFill, 10)
	local ultText = Kit.label(ult, "", UDim2.fromScale(1, 1), nil, { Font = Enum.Font.GothamBlack, TextSize = 18, ZIndex = 2, Name = "Text", TextStrokeTransparency = 0.4 })
	local ultButton: TextButton? = nil
	if ctx.touch then
		ultButton = Kit.button(root, "Z", UDim2.fromOffset(84, 84), UDim2.new(1, -460, 1, -380), function()
			ctx.input.ultimate()
		end, { Name = "Touch_ultimate", TextSize = 30, BackgroundColor3 = Color3.fromRGB(110, 90, 220) })
		ctx.targets.touch_ultimate = ultButton :: TextButton
	end
	table.insert(ctx.tickers, function()
		local st = ctx.state
		local on = st.mode == "special"
		ult.Visible = on
		if ultButton then
			ultButton.Visible = on
		end
		if on then
			local p = math.clamp(st.ult or 0, 0, 1)
			ultFill.Size = UDim2.fromScale(p, 1)
			ultText.Text = if p >= 1 then T("sp_ult_ready", { key = ctx.keyName("ultimate") }) else T("sp_ult") .. " · " .. T("sp_ult_charge", { p = math.floor(p * 100) })
		end
	end)
end

return Menus
