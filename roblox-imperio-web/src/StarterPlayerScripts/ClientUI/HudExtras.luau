--[[
	HudExtras (ModuleScript en StarterPlayerScripts > ClientUI)

	Evento del servidor, meta común y combo (encima de todo)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local RunService = ui.RunService
	local Config = ui.Config
	local T = ui.T
	local THEME = ui.THEME
	local fmt = ui.fmt
	local create = ui.create
	local corner = ui.corner
	local stroke = ui.stroke
	local shade = ui.shade
	local padding = ui.padding
	local maxText = ui.maxText
	local makeLabel = ui.makeLabel
	local makeProgressBar = ui.makeProgressBar
	local autoScale = ui.autoScale
	local mainGui = ui.mainGui
	local window = ui.window
	local quickBar = ui.quickBar

	local serverEventLabel = create("TextLabel", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(520, 30),
		BackgroundColor3 = Color3.fromRGB(14, 116, 144),
		Text = "",
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Visible = false,
	}, { corner(10), padding(5), maxText(16), shade(), stroke(Color3.fromRGB(8, 51, 68), 2) })
	autoScale(serverEventLabel)

	-- Meta del servidor (arriba a la izquierda)
	local communityCard = create("Frame", {
		Parent = mainGui,
		Position = UDim2.fromOffset(10, 100),
		Size = UDim2.fromOffset(270, 62),
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, { corner(12), padding(8), stroke(THEME.pink, 2) })
	autoScale(communityCard)
	local communityTitle = makeLabel(communityCard, "", 0, 18, 13, THEME.text, true)
	local _communityBack, communityFill, communityText = makeProgressBar(communityCard, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 20), THEME.pink)

	-- Combo de clics (encima del botón PROGRAMAR)
	local comboLabel = create("TextLabel", {
		Parent = quickBar,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = THEME.orange,
		TextStrokeTransparency = 0.2,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Visible = false,
	})
	local comboUntil = 0

	function ui.showCombo(combo: number, mult: number)
		if combo < 3 then
			comboLabel.Visible = false
			return
		end
		comboUntil = os.clock() + Config.COMBO_WINDOW + 0.2
		comboLabel.Visible = true
		comboLabel.Text = T("🔥 COMBO %d · x%.1f", combo, mult)
		comboLabel.TextColor3 = if combo >= Config.COMBO_MAX then THEME.red elseif combo >= Config.COMBO_MAX / 2 then THEME.orange else THEME.yellow
	end

	RunService.RenderStepped:Connect(function()
		if comboLabel.Visible and os.clock() > comboUntil then
			comboLabel.Visible = false
		end
	end)

	function ui.renderHudExtras(s)
		local event = s.serverEvent and Config.ServerEventById[s.serverEvent.id]
		serverEventLabel.Visible = event ~= nil
		if event then
			serverEventLabel.Text = string.format("%s %s · %s (%s)", event.emoji, T(event.name), T(event.desc), Config.formatTime(s.serverEvent.endsIn))
		end
		local goal = s.community
		communityCard.Visible = goal ~= nil and not window.Visible
		if goal then
			communityTitle.Text = T("🤝 Meta del servidor · %s", Config.formatTime(goal.endsIn))
			communityFill.Size = UDim2.fromScale(math.clamp(goal.progress / goal.target, 0, 1), 1)
			communityText.Text = fmt(goal.progress) .. " / " .. fmt(goal.target)
		end
	end
end
