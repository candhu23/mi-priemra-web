--[[
	Tutorial (ModuleScript en StarterPlayerScripts > ClientUI)

	Tutorial interactivo (sale a todos la primera vez)
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

return function(ui: any)
	local RunService = ui.RunService
	local playerGui = ui.playerGui
	local T = ui.T
	local THEME = ui.THEME
	local playSound = ui.playSound
	local create = ui.create
	local corner = ui.corner
	local stroke = ui.stroke
	local padding = ui.padding
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local setButton = ui.setButton
	local makeButtonRow = ui.makeButtonRow
	local autoScale = ui.autoScale
	local sendAction = ui.sendAction
	local moneyPill = ui.moneyPill
	local window = ui.window
	local computerButton = ui.computerButton
	local missionCard = ui.missionCard
	local quickButton = ui.quickButton
	local tutorialTargets = ui.tutorialTargets

	local tutorialGui = create("ScreenGui", { Name = "ImperioWebTutorial", ResetOnSpawn = false, DisplayOrder = 8, Enabled = false, Parent = playerGui })

	-- Marco amarillo que resalta el botón del paso actual
	local highlight = create("Frame", {
		Parent = tutorialGui,
		BackgroundTransparency = 1,
		Visible = false,
	}, { corner(16) })
	local highlightStroke = create("UIStroke", { Parent = highlight, Color = THEME.yellow, Thickness = 5 })
	local pointer = create("TextLabel", {
		Parent = tutorialGui,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(60, 60),
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "👇",
		TextScaled = true,
		Visible = false,
	})

	local tutorialCard = create("Frame", {
		Parent = tutorialGui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(540, 168),
		BackgroundColor3 = THEME.panel,
	}, { corner(16), padding(14), stroke(THEME.yellow, 3) })
	autoScale(tutorialCard)
	local stepLabel = makeLabel(tutorialCard, "", 0, 16, 13, THEME.muted, true)
	local titleLabel = makeLabel(tutorialCard, "", 18, 28, 22, THEME.yellow, true)
	local bodyLabel = makeLabel(tutorialCard, "", 50, 52, 15, THEME.text)
	bodyLabel.TextWrapped = true
	bodyLabel.TextTruncate = Enum.TextTruncate.None
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	local tutorialRow = makeButtonRow(tutorialCard, 106, 34)
	local skipButton = makeButton(tutorialRow, "Saltar tutorial", THEME.card, UDim2.new(0.35, -3, 1, 0), function() end)
	local nextButton = makeButton(tutorialRow, "Siguiente ▶", THEME.green, UDim2.new(0.65, -3, 1, 0), function() end)

	type Step = {
		title: string,
		body: string,
		target: (() -> GuiObject?)?,
		waitFor: ((any) -> boolean)?,
	}

	local STEPS: { Step } = {
		{
			title = "👋 ¡Bienvenido a Web Empire!",
			body = "Eres un emprendedor que crea páginas web. Tu objetivo: convertirlas en un imperio y ganar todo el dinero posible.",
		},
		{
			title = "➕ Tu primera web",
			body = "Pulsa «➕ Nueva web» y elige la Landing Page en la lista (botón «➕ Crear»).",
			target = function()
				return if window.Visible then nil else quickButton
			end,
			waitFor = function(s)
				return s.project ~= nil or s.stats.built > 0
			end,
		},
		{
			title = "⌨️ ¡A programar!",
			body = "Pulsa PROGRAMAR (o la tecla F) hasta terminar la web. ¡A veces sale un golpe crítico x5!",
			target = function()
				return if window.Visible then tutorialTargets.program else quickButton
			end,
			waitFor = function(s)
				return s.stats.built > 0
			end,
		},
		{
			title = "💰 ¡Ya ganas dinero!",
			body = "Tu web recibe visitas y gana dinero con anuncios cada segundo. Tu dinero aparece aquí arriba.",
			target = function()
				return moneyPill
			end,
		},
		{
			title = "💻 Tu ordenador",
			body = "Desde aquí lo controlas todo: tus webs, los clientes que las compran, anuncios, empresas, tu carrera, tu agencia y la tienda.",
			target = function()
				return computerButton
			end,
		},
		{
			title = "🎯 Misiones",
			body = "Esta tarjeta te dice qué hacer a continuación. Completa misiones diarias y objetivos para ganar premios.",
			target = function()
				return missionCard
			end,
		},
		{
			title = "🚀 ¡Todo listo!",
			body = "Haz crecer tu rascacielos hasta que sea el más alto de la ciudad. ¡Suerte, magnate!",
		},
	}

	local stepIndex = 0
	local running = false

	local function finish()
		running = false
		tutorialGui.Enabled = false
		sendAction("finishTutorial")
	end

	local function showStep(index: number)
		stepIndex = index
		local step = STEPS[index]
		if not step then
			finish()
			return
		end
		-- Si ya se cumple lo que pide el paso, se salta solo
		if step.waitFor and ui.state and step.waitFor(ui.state) then
			showStep(index + 1)
			return
		end
		stepLabel.Text = T("TUTORIAL · PASO %d DE %d", index, #STEPS)
		sendAction("tutorialStep", index) -- para el embudo de la analítica
		titleLabel.Text = T(step.title)
		bodyLabel.Text = T(step.body)
		local last = index == #STEPS
		nextButton.Visible = step.waitFor == nil
		setButton(nextButton, if last then T("🎉 ¡Empezar!") else T("Siguiente ▶"), true, THEME.green)
		skipButton.Visible = not last
		playSound("success")
	end

	nextButton.Activated:Connect(function()
		if running then
			showStep(stepIndex + 1)
		end
	end)
	skipButton.Activated:Connect(function()
		if running then
			finish()
		end
	end)

	function ui.startTutorial()
		running = true
		tutorialGui.Enabled = true
		showStep(1)
	end

	function ui.tutorialOnState(s)
		if running then
			local step = STEPS[stepIndex]
			if step and step.waitFor and step.waitFor(s) then
				showStep(stepIndex + 1)
			end
		end
	end

	-- El marco amarillo sigue al botón del paso y late
	RunService.RenderStepped:Connect(function()
		if not running then
			return
		end
		local step = STEPS[stepIndex]
		local target = step and step.target and step.target()
		if target and target.Parent and target.Visible then
			local pos, size = target.AbsolutePosition, target.AbsoluteSize
			highlight.Visible = true
			highlight.Position = UDim2.fromOffset(pos.X - 8, pos.Y - 8)
			highlight.Size = UDim2.fromOffset(size.X + 16, size.Y + 16)
			highlightStroke.Transparency = 0.25 + 0.25 * math.sin(os.clock() * 6)
			pointer.Visible = true
			pointer.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 10 + 6 * math.sin(os.clock() * 5))
		else
			highlight.Visible = false
			pointer.Visible = false
		end
	end)
end
