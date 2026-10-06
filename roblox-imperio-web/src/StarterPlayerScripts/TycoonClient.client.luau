--[[
	TycoonClient (LocalScript en StarterPlayer > StarterPlayerScripts)

	Toda la interfaz del juego:
	  · HUD superior con el dinero y los bonus activos
	  · menú lateral con avisos (!) cuando hay algo que hacer
	  · misión actual con barra de progreso
	  · botón PROGRAMAR siempre visible abajo (tecla F)
	  · ventana con pestañas (Crear, Webs, Clientes, Anuncios, Empresas,
	    Bolsa, Tienda)
	  · ventanas emergentes (bienvenida, recompensa diaria) y avisos
	  · marcador "TU IMPERIO" sobre tu parcela
	El cliente solo muestra cosas y pide acciones: el servidor decide.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local actionFunction = remotes:WaitForChild("Action") :: RemoteFunction
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local openComputerEvent = remotes:WaitForChild("OpenComputer") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local THEME = {
	bg = Color3.fromRGB(15, 23, 42),
	panel = Color3.fromRGB(30, 41, 59),
	card = Color3.fromRGB(51, 65, 85),
	stroke = Color3.fromRGB(71, 85, 105),
	accent = Color3.fromRGB(59, 130, 246),
	green = Color3.fromRGB(34, 197, 94),
	yellow = Color3.fromRGB(234, 179, 8),
	red = Color3.fromRGB(239, 68, 68),
	purple = Color3.fromRGB(168, 85, 247),
	orange = Color3.fromRGB(249, 115, 22),
	pink = Color3.fromRGB(236, 72, 153),
	text = Color3.fromRGB(248, 250, 252),
	muted = Color3.fromRGB(148, 163, 184),
	disabled = Color3.fromRGB(71, 85, 105),
}

local fmt = Config.formatMoney
local num = Config.formatNumber

---------------------------------------------------------------------
-- Sonidos
---------------------------------------------------------------------
local soundFolder = Instance.new("Folder")
soundFolder.Name = "ImperioWebSounds"
soundFolder.Parent = SoundService
local sounds: { [string]: Sound } = {}
for name, def in Config.Sounds do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.speed
	sound.Parent = soundFolder
	sounds[name] = sound
end

local muted = false -- se sincroniza con la partida guardada

local function playSound(name: string)
	local sound = sounds[name]
	if sound and not muted then
		sound.TimePosition = 0
		sound:Play()
	end
end

---------------------------------------------------------------------
-- Ayudas para crear interfaz
---------------------------------------------------------------------
local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, thickness: number?): UIStroke
	return create("UIStroke", { Color = color, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function gradient(top: Color3, bottom: Color3): UIGradient
	return create("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

-- OJO: un UIGradient dentro de un TextLabel/TextButton también tiñe el
-- TEXTO. Para objetos con texto usamos un degradado gris (blanco → gris)
-- y el color va en BackgroundColor3: así el texto sigue siendo blanco.
local function shade(): UIGradient
	return gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 205))
end

local function padding(px: number): UIPadding
	return create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function maxText(size: number): UITextSizeConstraint
	return create("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 8 })
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function makeLabel(parent: Instance, text: string, y: number, height: number, textSize: number, color: Color3?, bold: boolean?): TextLabel
	return create("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		Text = text,
		TextSize = textSize,
		TextColor3 = color or THEME.text,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

-- Botón con degradado, borde y efecto al pulsar
local function makeButton(parent: Instance?, text: string, color: Color3, size: UDim2, onClick: () -> ()): TextButton
	local button = create("TextButton", {
		Parent = parent,
		Size = size,
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = THEME.text,
		TextStrokeTransparency = 0.75,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = false,
	}, { corner(10), maxText(17), padding(5), shade() })
	local border = stroke(darken(color, 0.35), 2)
	border.Parent = button
	local scale = create("UIScale", { Parent = button })
	button:SetAttribute("Enabled", true)
	button:SetAttribute("BaseColor", color)

	button:GetAttributeChangedSignal("PaintColor"):Connect(function()
		local c = button:GetAttribute("PaintColor")
		if typeof(c) == "Color3" then
			button.BackgroundColor3 = c
			border.Color = darken(c, 0.35)
		end
	end)

	button.MouseEnter:Connect(function()
		if button:GetAttribute("Enabled") ~= false then
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.04 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Enabled") == false then
			playSound("error")
			return
		end
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	return button
end

-- Cambia texto, color y si se puede pulsar (gris = no disponible)
local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3?)
	if button.Text ~= text then
		button.Text = text
	end
	button:SetAttribute("Enabled", enabled)
	local base = color or button:GetAttribute("BaseColor") or THEME.accent
	button:SetAttribute("PaintColor", if enabled then base else THEME.disabled)
	button.TextTransparency = if enabled then 0 else 0.25
end

local function makeCard(parent: Instance, height: number, order: number, color: Color3?): Frame
	return create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = color or THEME.card,
		LayoutOrder = order,
	}, { corner(12), padding(10), stroke(THEME.stroke, 1) })
end

local function makeButtonRow(parent: Instance, y: number, height: number): Frame
	return create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function makeProgressBar(parent: Instance, position: UDim2, size: UDim2, color: Color3): (Frame, Frame, TextLabel)
	local back = create("Frame", {
		Parent = parent,
		Position = position,
		Size = size,
		BackgroundColor3 = THEME.bg,
	}, { corner(8), stroke(THEME.stroke, 1) })
	local fill = create("Frame", {
		Parent = back,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(8), gradient(lighten(color, 0.2), darken(color, 0.1)) })
	local text = create("TextLabel", {
		Parent = back,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		ZIndex = 2,
	}, { maxText(14), padding(2) })
	return back, fill, text
end

-- Mantiene una lista de filas sincronizada con los datos sin recrearla
-- entera cada segundo (así no parpadea ni pierde el scroll).
local function syncRows(container: Instance, rows: { [any]: any }, items: { any }, keyOf: (any) -> any, build: (any) -> any, update: (any, any) -> ())
	local seen = {}
	for i, item in items do
		local key = keyOf(item)
		seen[key] = true
		local row = rows[key]
		if not row then
			row = build(item)
			rows[key] = row
			row.frame.Parent = container
		end
		row.frame.LayoutOrder = 100 + i
		update(row, item)
	end
	for key, row in rows do
		if not seen[key] then
			row.frame:Destroy()
			rows[key] = nil
		end
	end
end

-- Escala toda la interfaz según el tamaño de la pantalla (móvil, tablet, PC)
local scaledObjects: { UIScale } = {}
local function autoScale(guiObject: GuiObject)
	local scale = create("UIScale", { Parent = guiObject })
	table.insert(scaledObjects, scale)
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	local value = math.clamp(math.min(size.X / 1150, size.Y / 720), 0.55, 1.15)
	for _, scale in scaledObjects do
		scale.Scale = value
	end
end

---------------------------------------------------------------------
-- Pantallas (ScreenGui separados para que las capas no se mezclen)
---------------------------------------------------------------------
local mainGui = create("ScreenGui", { Name = "ImperioWebUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1, Parent = playerGui })
local toastGui = create("ScreenGui", { Name = "ImperioWebToasts", ResetOnSpawn = false, DisplayOrder = 5, Parent = playerGui })
local modalGui = create("ScreenGui", { Name = "ImperioWebModal", ResetOnSpawn = false, DisplayOrder = 10, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })

local state: any = nil
local stateTime = os.clock()
local pendingClickWork = 0
local showToast: (text: string, kind: string?) -> ()
local doClick: () -> ()

local function sendAction(action: string, a: any?, b: any?, onResult: ((boolean, string?, any) -> ())?)
	task.spawn(function()
		local ok, success, message, extra = pcall(function()
			return actionFunction:InvokeServer(action, a, b)
		end)
		if not ok then
			return
		end
		-- El servidor responde con un texto cuando hay algo que contar
		if type(message) == "string" then
			showToast(message, if success then "success" else "error")
		end
		if type(extra) == "table" and extra.money then
			playSound("money")
		end
		if onResult then
			onResult(success == true, message, extra)
		end
	end)
end

---------------------------------------------------------------------
-- HUD superior: dinero, ingresos y bonus
---------------------------------------------------------------------
local hud = create("Frame", {
	Parent = mainGui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.fromOffset(440, 96),
	BackgroundTransparency = 1,
})
autoScale(hud)

local moneyPill = create("Frame", {
	Parent = hud,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(340, 50),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, { corner(25), gradient(Color3.fromRGB(34, 197, 94), Color3.fromRGB(21, 128, 61)), stroke(Color3.fromRGB(20, 83, 45), 3) })
local moneyScale = create("UIScale", { Parent = moneyPill })
local moneyLabel = create("TextLabel", {
	Parent = moneyPill,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Text = "💰 $0",
	TextColor3 = THEME.text,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextStrokeTransparency = 0.6,
}, { maxText(34), padding(6) })

local incomeLabel = create("TextLabel", {
	Parent = hud,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(420, 20),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = THEME.text,
	TextStrokeTransparency = 0.4,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
}, { maxText(16) })

local chipsRow = create("Frame", {
	Parent = hud,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(440, 22),
	BackgroundTransparency = 1,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local chips: { [string]: TextLabel } = {}
local function chip(key: string, order: number, color: Color3)
	chips[key] = create("TextLabel", {
		Parent = chipsRow,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = color,
		Text = "",
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Visible = false,
	}, { corner(11), create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
end
chip("pass", 1, THEME.purple)
chip("boost", 2, THEME.orange)
chip("social", 3, THEME.pink)
chip("turbo", 4, THEME.yellow)

local eventLabel = create("TextLabel", {
	Parent = mainGui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 104),
	Size = UDim2.fromOffset(460, 32),
	BackgroundColor3 = THEME.purple,
	Text = "",
	TextColor3 = THEME.text,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	Visible = false,
}, { corner(10), padding(5), maxText(16), shade(), stroke(darken(THEME.purple, 0.5), 2) })
autoScale(eventLabel)

local saveBanner = create("TextButton", {
	Parent = mainGui,
	Position = UDim2.fromOffset(10, 52),
	Size = UDim2.fromOffset(330, 44),
	BackgroundColor3 = THEME.red,
	Text = "⚠️ Tu progreso NO se guarda. Pulsa para ver cómo activarlo",
	TextColor3 = THEME.text,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextWrapped = true,
	Visible = false,
	AutoButtonColor = true,
}, { corner(10), padding(6), maxText(15), stroke(darken(THEME.red, 0.4), 2) })
autoScale(saveBanner)
local showSaveHelp: () -> () = function() end
saveBanner.Activated:Connect(function()
	showSaveHelp()
end)

---------------------------------------------------------------------
-- Ventana principal con pestañas
---------------------------------------------------------------------
local window = create("Frame", {
	Parent = mainGui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromOffset(880, 560),
	BackgroundColor3 = THEME.panel,
	Visible = false,
	ZIndex = 5,
}, { corner(16), stroke(Color3.fromRGB(96, 165, 250), 3) })
autoScale(window)

local header = create("Frame", {
	Parent = window,
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, { corner(16), gradient(Color3.fromRGB(37, 99, 235), Color3.fromRGB(30, 64, 175)) })

local windowTitle = create("TextLabel", {
	Parent = header,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -80, 1, 0),
	Text = "🌐 Imperio Web",
	TextColor3 = THEME.text,
	Font = Enum.Font.FredokaOne,
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local closeButton = makeButton(header, "✕", THEME.red, UDim2.fromOffset(40, 36), function()
	window.Visible = false
end)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -8, 0.5, 0)

local muteButton: TextButton
muteButton = makeButton(header, "🔊", THEME.card, UDim2.fromOffset(44, 36), function()
	muted = not muted
	muteButton.Text = if muted then "🔇" else "🔊"
	sendAction("setMuted", muted)
end)
muteButton.AnchorPoint = Vector2.new(1, 0.5)
muteButton.Position = UDim2.new(1, -56, 0.5, 0)

local tabBar = create("Frame", {
	Parent = window,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, 58),
	Size = UDim2.new(1, -20, 0, 74),
}, {
	create("UIGridLayout", {
		CellSize = UDim2.new(0.2, -6, 0, 34),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local content = create("Frame", {
	Parent = window,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, 140),
	Size = UDim2.new(1, -20, 1, -150),
})

local TABS = {
	{ id = "create", emoji = "🖥️", name = "Crear", color = THEME.green },
	{ id = "sites", emoji = "🌐", name = "Webs", color = THEME.accent },
	{ id = "clients", emoji = "🤝", name = "Clientes", color = THEME.yellow },
	{ id = "ads", emoji = "📢", name = "Anuncios", color = THEME.purple },
	{ id = "companies", emoji = "🏢", name = "Empresas", color = THEME.orange },
	{ id = "career", emoji = "💼", name = "Carrera", color = Color3.fromRGB(14, 165, 233) },
	{ id = "agency", emoji = "👥", name = "Agencia", color = Color3.fromRGB(217, 70, 239) },
	{ id = "missions", emoji = "🎯", name = "Misiones", color = Color3.fromRGB(245, 158, 11) },
	{ id = "market", emoji = "📈", name = "Bolsa", color = THEME.pink },
	{ id = "shop", emoji = "🛒", name = "Tienda", color = Color3.fromRGB(20, 184, 166) },
}

local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local renderers: { [string]: (any) -> () } = {}
local currentTab = "create"

local function makePage(id: string): ScrollingFrame
	local page = create("ScrollingFrame", {
		Parent = content,
		Name = id,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = THEME.muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Visible = false,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})
	pages[id] = page
	return page
end

local onTabChanged: () -> () = function() end

local function selectTab(id: string)
	currentTab = id
	onTabChanged()
	for _, tab in TABS do
		pages[tab.id].Visible = tab.id == id
		setButton(tabButtons[tab.id], tab.emoji .. " " .. tab.name, true, if tab.id == id then tab.color else THEME.card)
		if tab.id == id then
			windowTitle.Text = tab.emoji .. " " .. tab.name
		end
	end
	if state and renderers[id] then
		renderers[id](state)
	end
end

local function openTab(id: string)
	window.Visible = true
	selectTab(id)
end

for i, tab in TABS do
	local button = makeButton(tabBar, tab.emoji .. " " .. tab.name, THEME.card, UDim2.new(1 / #TABS, -6, 1, 0), function()
		selectTab(tab.id)
	end)
	button.LayoutOrder = i
	tabButtons[tab.id] = button
	makePage(tab.id)
end

---------------------------------------------------------------------
-- Botón del ordenador (único botón lateral) y avisos de las pestañas
---------------------------------------------------------------------
local computerHolder = create("Frame", {
	Parent = mainGui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.55, 0),
	Size = UDim2.fromOffset(112, 112),
	BackgroundTransparency = 1,
})
autoScale(computerHolder)
local computerButton = makeButton(computerHolder, "", THEME.accent, UDim2.fromScale(1, 1), function()
	if window.Visible then
		window.Visible = false
	else
		openTab(currentTab)
	end
end)
create("TextLabel", {
	Parent = computerButton,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0.66, 0),
	Text = "💻",
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.text,
})
create("TextLabel", {
	Parent = computerButton,
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 0.66),
	Size = UDim2.new(1, 0, 0.34, 0),
	Text = "Ordenador (M)",
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.text,
	TextStrokeTransparency = 0.5,
})
local computerBadge = create("TextLabel", {
	Parent = computerHolder,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = THEME.red,
	Text = "",
	TextColor3 = THEME.text,
	Font = Enum.Font.FredokaOne,
	TextSize = 20,
	Visible = false,
	ZIndex = 5,
}, { corner(17), stroke(THEME.text, 2) })

local tabBadges: { [string]: TextLabel } = {}
local badgeValues: { [string]: number } = {}
for _, tab in TABS do
	tabBadges[tab.id] = create("TextLabel", {
		Parent = tabButtons[tab.id],
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = THEME.red,
		Text = "!",
		TextColor3 = THEME.text,
		Font = Enum.Font.FredokaOne,
		TextSize = 14,
		Visible = false,
		ZIndex = 3,
	}, { corner(10), stroke(THEME.text, 1.5) })
end

local function setBadge(id: string, value: (number | boolean)?)
	local badge = tabBadges[id]
	if not badge then
		return
	end
	local count = if type(value) == "number" then value elseif value == true then 1 else 0
	badgeValues[id] = count
	badge.Visible = count > 0
	badge.Text = if type(value) == "number" then (if value > 9 then "9+" else tostring(value)) else "!"
	-- El botón del ordenador suma todos los avisos
	local total = 0
	for _, n in badgeValues do
		total += n
	end
	computerBadge.Visible = total > 0
	computerBadge.Text = if total > 9 then "9+" else tostring(total)
end

---------------------------------------------------------------------
-- Misión actual (a la derecha)
---------------------------------------------------------------------
local HINTS = {
	first_site = "Pulsa ➕ Nueva web abajo y luego ⌨️ PROGRAMAR",
	earn_1k = "Ten varias webs y deja que ganen dinero",
	blog = "Consigue ⭐ 3 de reputación y crea un Blog",
	sell_1 = "Abre 🤝 Clientes y vende una web",
	company_1 = "Abre 🏢 Empresas y funda el Equipo de Programadores",
	network_2 = "Abre 📢 Anuncios y desbloquea ClickBoom",
	tienda = "Llega a ⭐ 30 vendiendo y creando webs",
	sites_5 = "Compra ☁️ Hosting para tener más huecos",
	seo_5 = "En 🌐 Webs mejora el SEO de tu mejor web",
	ipo_1 = "Abre 📈 Bolsa cuando ganes $1M",
	job_1 = "Abre 💼 Carrera y acepta una oferta de empleo",
	dev_8 = "Programa webs y trabaja para subir de nivel",
	agency = "Abre 👥 Agencia y fúndala",
	senior = "Sigue trabajando y sube el nivel de ese nicho",
	epic = "Entrevista programadores en 👥 Agencia",
	team_10 = "Amplía la oficina y ficha más programadores",
	cto = "Sigue ascendiendo en tu trabajo",
}

local missionCard = create("Frame", {
	Parent = mainGui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.45, 0),
	Size = UDim2.fromOffset(250, 118),
	BackgroundColor3 = THEME.bg,
	BackgroundTransparency = 0.1,
}, { corner(14), padding(10), stroke(THEME.yellow, 2) })
autoScale(missionCard)
makeLabel(missionCard, "🎯 MISIÓN", 0, 18, 15, THEME.yellow, true)
local missionText = makeLabel(missionCard, "", 20, 20, 15, THEME.text, true)
local _missionBack, missionFill, missionProgress = makeProgressBar(missionCard, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 18), THEME.yellow)
local missionReward = makeLabel(missionCard, "", 66, 16, 13, THEME.green, true)
local missionHint = makeLabel(missionCard, "", 82, 16, 12, THEME.muted)
missionHint.TextWrapped = true
missionHint.TextTruncate = Enum.TextTruncate.None
create("TextButton", {
	Parent = missionCard,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	ZIndex = 5,
}).Activated:Connect(function()
	openTab("missions")
end)

local function currentGoal(s)
	for _, goal in Config.Goals do
		if not s.goals[goal.id] then
			return goal
		end
	end
	return nil
end

local function renderMission(s)
	local goal = currentGoal(s)
	if not goal then
		missionText.Text = "¡Has completado todos los objetivos! 👑"
		missionFill.Size = UDim2.fromScale(1, 1)
		missionProgress.Text = ""
		missionReward.Text = ""
		missionHint.Text = "Sigue saliendo a bolsa para ser el número 1"
		return
	end
	local value = math.min(goal.value(s), goal.target)
	missionText.Text = goal.text
	missionFill.Size = UDim2.fromScale(math.clamp(value / goal.target, 0, 1), 1)
	missionProgress.Text = if goal.target >= 1000 then fmt(value) .. " / " .. fmt(goal.target) else num(value) .. " / " .. num(goal.target)
	if value >= goal.target then
		missionReward.Text = "✅ ¡Completado! Toca aquí para reclamarlo"
		missionHint.Text = "Se reclama en 🎯 Misiones"
	else
		missionReward.Text = if goal.reward > 0 then "🎁 Premio: " .. fmt(goal.reward) else "🎁 Premio: ¡acciones!"
		missionHint.Text = HINTS[goal.id] or "Toca aquí para ver todas las misiones"
	end
end

---------------------------------------------------------------------
-- Botón PROGRAMAR siempre visible (abajo)
---------------------------------------------------------------------
local quickBar = create("Frame", {
	Parent = mainGui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(380, 110),
	BackgroundColor3 = THEME.bg,
	BackgroundTransparency = 0.15,
}, { corner(16), padding(8), stroke(THEME.green, 2) })
autoScale(quickBar)

local quickTitle = makeLabel(quickBar, "", 0, 18, 14, THEME.text, true)
quickTitle.TextXAlignment = Enum.TextXAlignment.Center
local _quickBack, quickFill, quickProgress = makeProgressBar(quickBar, UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 16), THEME.green)
local quickButton = makeButton(quickBar, "⌨️ PROGRAMAR", THEME.green, UDim2.new(1, 0, 0, 50), function()
	doClick()
end)
quickButton.Position = UDim2.fromOffset(0, 44)
quickButton:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 30

---------------------------------------------------------------------
-- Avisos (toasts) y números flotantes
---------------------------------------------------------------------
local toastContainer = create("Frame", {
	Parent = toastGui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -140),
	Size = UDim2.fromOffset(460, 230),
	BackgroundTransparency = 1,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})
autoScale(toastContainer)

local TOAST_COLORS = {
	success = THEME.green,
	error = THEME.red,
	event = THEME.purple,
	goal = THEME.yellow,
	money = Color3.fromRGB(22, 163, 74),
	info = THEME.accent,
}
local toastOrder = 0

function showToast(text: string, kind: string?)
	toastOrder += 1
	local color = TOAST_COLORS[kind or "info"] or THEME.accent
	local toast = create("TextLabel", {
		Parent = toastContainer,
		LayoutOrder = toastOrder,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		TextStrokeTransparency = 0.7,
	}, { corner(12), padding(7), maxText(17), shade(), stroke(darken(color, 0.45), 2) })
	local scale = create("UIScale", { Parent = toast, Scale = 0.6 })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	if kind == "goal" or kind == "money" then
		playSound("money")
	elseif kind == "event" or kind == "success" then
		playSound("success")
	elseif kind == "error" then
		playSound("error")
	end

	-- Máximo 4 a la vez
	local toasts = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 4 do
		toasts[i]:Destroy()
	end

	task.delay(4, function()
		if toast.Parent then
			TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 0 }):Play()
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

local function floatText(parent: GuiObject, text: string, color: Color3, size: number)
	local label = create("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.25 + math.random() * 0.5, 0, 0, 0),
		Size = UDim2.fromOffset(220, 40),
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		Font = Enum.Font.FredokaOne,
		TextSize = size,
		ZIndex = 10,
	})
	local tween = TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

local function pulseMoney()
	moneyScale.Scale = 1.12
	TweenService:Create(moneyScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

---------------------------------------------------------------------
-- Ventanas emergentes (con cola)
---------------------------------------------------------------------
local modalQueue: { () -> () } = {}
local modalOpen = false

local overlay = create("Frame", {
	Parent = modalGui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
})
local modalCard = create("Frame", {
	Parent = overlay,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 360),
	BackgroundColor3 = THEME.panel,
}, { corner(18), padding(16), stroke(THEME.yellow, 3) })
autoScale(modalCard)
local modalTitle = create("TextLabel", {
	Parent = modalCard,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 40),
	Text = "",
	TextColor3 = THEME.yellow,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
}, { maxText(32) })
local modalBody = create("TextLabel", {
	Parent = modalCard,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 48),
	Size = UDim2.new(1, 0, 1, -110),
	Text = "",
	TextColor3 = THEME.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 18,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local modalExtra = create("Frame", {
	Parent = modalCard,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 48),
	Size = UDim2.new(1, 0, 1, -110),
	Visible = false,
})
local modalAction: () -> () = function() end
local modalButton = makeButton(modalCard, "¡Vamos!", THEME.green, UDim2.new(1, 0, 0, 50), function()
	modalAction()
end)
modalButton.AnchorPoint = Vector2.new(0, 1)
modalButton.Position = UDim2.fromScale(0, 1)

local function closeModal()
	modalGui.Enabled = false
	modalOpen = false
	local nextModal = table.remove(modalQueue, 1)
	if nextModal then
		task.delay(0.3, nextModal)
	end
end

local function showModal(title: string, body: string, buttonText: string, onButton: (() -> ())?, extraBuilder: ((Frame) -> ())?)
	local function open()
		modalOpen = true
		modalTitle.Text = title
		modalBody.Text = body
		modalBody.Visible = extraBuilder == nil
		modalExtra:ClearAllChildren()
		modalExtra.Visible = extraBuilder ~= nil
		if extraBuilder then
			extraBuilder(modalExtra)
		end
		setButton(modalButton, buttonText, true, THEME.green)
		modalAction = function()
			if onButton then
				onButton()
			end
			closeModal()
		end
		modalGui.Enabled = true
		modalCard.Position = UDim2.fromScale(0.5, 0.58)
		overlay.BackgroundTransparency = 1
		TweenService:Create(modalCard, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
		playSound("success")
	end
	if modalOpen then
		table.insert(modalQueue, open)
	else
		open()
	end
end

showSaveHelp = function()
	showModal("💾 Cómo activar el guardado", "Roblox solo guarda partidas en juegos PUBLICADOS:\n\n1. En Studio: File → Publish to Roblox.\n2. Home → Game Settings → Security → activa «Enable Studio Access to API Services» → Save.\n3. Para la partida (Stop) y vuelve a darle a Play.\n\nEn el juego publicado (jugando desde la web o la app) se guarda siempre.", "Entendido", nil, nil)
end

notifyEvent.OnClientEvent:Connect(function(text: string, kind: string, body: string?)
	if kind == "popup" then
		showModal(text, body or "", "¡Genial!", nil, nil)
	else
		showToast(text, kind)
	end
end)

-- Recompensa diaria: 7 casillas
local dailyShown = false
local function showDailyModal()
	if not state or not state.dailyAvailable then
		return
	end
	local day = state.dailyDay
	showModal("📅 Recompensa diaria", "", "Recoger " .. fmt(state.dailyAmount), function()
		sendAction("claimDaily", nil, nil, function(ok)
			if ok then
				pulseMoney()
			end
		end)
	end, function(frame)
		create("TextLabel", {
			Parent = frame,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			Text = "¡Entra cada día para que tu racha suba! El día 7 incluye un 🚀 Boost x2.",
			TextColor3 = THEME.text,
			Font = Enum.Font.GothamMedium,
			TextSize = 16,
			TextWrapped = true,
		})
		local row = create("Frame", {
			Parent = frame,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 54),
			Size = UDim2.new(1, 0, 0, 96),
		}, {
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for i, reward in Config.DailyRewards do
			local color = if i < day then THEME.disabled elseif i == day then THEME.green else THEME.card
			local box = create("Frame", {
				Parent = row,
				LayoutOrder = i,
				Size = UDim2.new(1 / 7, -6, 1, 0),
				BackgroundColor3 = color,
			}, { corner(10), stroke(if i == day then THEME.yellow else THEME.stroke, if i == day then 3 else 1) })
			create("TextLabel", {
				Parent = box,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0.35, 0),
				Text = "Día " .. i,
				TextColor3 = THEME.text,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}, { maxText(14) })
			create("TextLabel", {
				Parent = box,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 0.35),
				Size = UDim2.new(1, 0, 0.65, 0),
				Text = if i < day then "✅" elseif reward.boostMinutes then "🚀" else "💰",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = THEME.text,
			}, { padding(6) })
		end
	end)
end

-- Variables compartidas entre pestañas. Cada pestaña va dentro de su
-- propio bloque do ... end: Luau solo admite 200 variables locales por
-- función y la interfaz completa tiene muchas más.
local progressFill: Frame
local progressText: TextLabel
local nicheLabel: (nicheId: string?) -> string
local visitHistory: { [number]: { number } } = {} -- historial de visitas por web
local HISTORY_SIZE = 40
local renderDetail: (any) -> ()
local detailSiteId: number? = nil
local detail: ScrollingFrame
local bestSiteFor: (any, any) -> (any, number)
local oddsText: (field: string) -> string
local tutorialTargets: { [string]: GuiObject } = {} -- botones que resalta el tutorial
local startTutorial: () -> ()
local tutorialOnState: (any) -> () = function() end

---------------------------------------------------------------------
-- Pestaña CREAR
---------------------------------------------------------------------
do
local createPage = pages.create

local projectCard = makeCard(createPage, 172, 1, Color3.fromRGB(22, 52, 40))
local projectTitle = makeLabel(projectCard, "Elige qué web programar 👇", 0, 24, 19, THEME.text, true)
projectTitle.Size = UDim2.new(1, -110, 0, 24)
local cancelButton = makeButton(projectCard, "Cancelar", THEME.red, UDim2.fromOffset(100, 26), function()
	sendAction("cancelProject")
end)
cancelButton.AnchorPoint = Vector2.new(1, 0)
cancelButton.Position = UDim2.new(1, 0, 0, 0)
local _progressBack, createFill, createText = makeProgressBar(projectCard, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 24), THEME.green)
progressFill, progressText = createFill, createText
local programButton = makeButton(projectCard, "⌨️ PROGRAMAR", THEME.green, UDim2.new(1, 0, 0, 58), function()
	doClick()
end)
programButton.Position = UDim2.fromOffset(0, 60)
tutorialTargets.program = programButton
local projectInfo = makeLabel(projectCard, "", 126, 20, 14, THEME.muted)

local nicheCard = makeCard(createPage, 82, 2, Color3.fromRGB(23, 37, 84))
local nicheTitle = makeLabel(nicheCard, "", 0, 20, 15, THEME.text, true)
local nicheRow = makeButtonRow(nicheCard, 26, 34)
local nicheButtons = {}
for _, niche in Career.Niches do
	nicheButtons[niche.id] = makeButton(nicheRow, niche.emoji, THEME.card, UDim2.new(0.1, -6, 1, 0), function()
		sendAction("setNiche", niche.id)
	end)
end

local typeRows: { [string]: any } = {}
for i, def in Config.WebTypes do
	local card = makeCard(createPage, 92, 10 + i)
	local title = makeLabel(card, def.emoji .. " " .. def.name, 0, 24, 18, THEME.text, true)
	local info = makeLabel(card, "", 26, 18, 14, THEME.muted)
	local buttons = makeButtonRow(card, 46, 26)
	local createButton = makeButton(buttons, "Crear", THEME.accent, UDim2.new(0.62, -3, 1, 0), function()
		sendAction("startProject", def.id)
	end)
	local autoButton = makeButton(buttons, "🤖 Auto", THEME.purple, UDim2.new(0.38, -3, 1, 0), function()
		sendAction("setAuto", def.id)
	end)
	typeRows[def.id] = { title = title, info = info, create = createButton, auto = autoButton }
end

renderers.create = function(s)
	local project = s.project
	if project then
		local def = Config.WebTypeById[project.type]
		projectTitle.Text = "Programando: " .. def.emoji .. " " .. def.name
		setButton(programButton, "⌨️ PROGRAMAR  (+" .. num(s.clickPower) .. " por clic · tecla F)", true)
		cancelButton.Visible = true
	else
		projectTitle.Text = "Elige qué web programar 👇"
		progressFill.Size = UDim2.fromScale(0, 1)
		progressText.Text = ""
		setButton(programButton, "Elige una web de la lista", false)
		cancelButton.Visible = false
	end
	local autoText = if s.autoType then " · 🤖 Auto: " .. Config.WebTypeById[s.autoType].name else ""
	projectInfo.Text = string.format("👩‍💻 %s trabajo/s · 🌐 Webs %d/%d · ⭐ %s rep%s", num(s.workPerSec), #s.sites, s.slots, num(s.reputation), autoText)

	local selected = s.selectedNiche or Career.DEFAULT_NICHE
	local nicheLevel = s.career.nicheLevels[selected]
	nicheTitle.Text = string.format("🎯 Nicho de tus webs: %s · nivel %d (+%d%% calidad, x1.5 vendiendo a su nicho)",
		Career.NicheById[selected].emoji .. " " .. Career.NicheById[selected].name, nicheLevel, math.floor((Career.qualityBonus(s.career, selected) - 1) * 100 + 0.5))
	for id, button in nicheButtons do
		setButton(button, Career.NicheById[id].emoji, true, if id == selected then THEME.accent else THEME.card)
	end

	local hasLab = (s.companies.ia_lab or 0) >= 1
	local full = #s.sites >= s.slots
	for _, def in Config.WebTypes do
		local row = typeRows[def.id]
		local locked = s.reputation < def.rep
		row.title.Text = def.emoji .. " " .. def.name .. (if locked then "  🔒 necesitas ⭐ " .. num(def.rep) else "")
		row.title.TextColor3 = if locked then THEME.muted else THEME.text
		row.info.Text = string.format("Coste %s · Trabajo %s · 👀 ~%s visitas/s · ⭐ +%d rep", fmt(def.cost), num(def.work), num(def.visits), def.repReward)

		local canCreate = not locked and not project and not full and s.money >= def.cost
		local createText = if locked then "🔒 Bloqueada"
			elseif project then "Ya programas otra"
			elseif full then "Sin huecos (vende o compra Hosting)"
			elseif s.money < def.cost then "Te faltan " .. fmt(def.cost - s.money)
			else "➕ Crear (" .. fmt(def.cost) .. ")"
		setButton(row.create, createText, canCreate)

		row.auto.Visible = hasLab
		local isAuto = s.autoType == def.id
		setButton(row.auto, if isAuto then "🤖 ACTIVO" else "🤖 Auto", hasLab and not locked, if isAuto then THEME.orange else THEME.purple)
	end
end
end

---------------------------------------------------------------------
-- Pestaña WEBS (lista + ficha detallada de cada web)
---------------------------------------------------------------------
do
local sitesPage = pages.sites
local sitesHeader = makeCard(sitesPage, 76, 1, Color3.fromRGB(23, 37, 84))
local sitesSummary = makeLabel(sitesHeader, "", 0, 20, 15, THEME.text, true)
local bestNetworkButton = makeButton(sitesHeader, "📢 Poner la mejor app de anuncios en todas", THEME.purple, UDim2.new(1, 0, 0, 30), function()
	if not state then
		return
	end
	local bestId, bestValue = nil, -1
	for _, network in Config.AdNetworks do
		local value = network.rpv * (1 - network.penalty)
		if state.unlockedAds[network.id] and value > bestValue then
			bestId, bestValue = network.id, value
		end
	end
	if bestId then
		sendAction("setNetworkAll", bestId)
	end
end)
bestNetworkButton.Position = UDim2.fromOffset(0, 26)

local emptySites = makeCard(sitesPage, 50, 2)
makeLabel(emptySites, "Aún no tienes webs. Ve a 🖥️ Crear y programa la primera.", 0, 30, 15, THEME.muted)

local siteRows = {}
local openSiteDetail: (siteId: number) -> ()

local function unlockedNetworkList(s): { any }
	local list = {}
	for _, network in Config.AdNetworks do
		if s.unlockedAds[network.id] then
			table.insert(list, network)
		end
	end
	return list
end

function nicheLabel(nicheId: string?): string
	local niche = Career.NicheById[nicheId or Career.DEFAULT_NICHE]
	return niche.emoji .. " " .. niche.name
end


renderers.sites = function(s)
	local totalVisits, totalIncome = 0, 0
	for _, site in s.sites do
		totalVisits += site.visits
		totalIncome += site.income
	end
	sitesSummary.Text = string.format("🌐 %d/%d webs · 👀 %s visitas/s · 💵 %s/s por anuncios", #s.sites, s.slots, num(totalVisits), fmt(totalIncome))
	emptySites.Visible = #s.sites == 0

	syncRows(sitesPage, siteRows, s.sites, function(site)
		return site.id
	end, function(site)
		local card = makeCard(sitesPage, 102, 0)
		local row: any = { frame = card, id = site.id }
		row.title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
		row.info = makeLabel(card, "", 24, 18, 14, THEME.muted)
		local buttons = makeButtonRow(card, 50, 32)
		row.open = makeButton(buttons, "🔍 Abrir", THEME.green, UDim2.new(0.2, -5, 1, 0), function()
			openSiteDetail(row.id)
		end)
		row.seo = makeButton(buttons, "SEO", THEME.accent, UDim2.new(0.2, -5, 1, 0), function()
			sendAction("upgradeSeo", row.id)
		end)
		row.network = makeButton(buttons, "Anuncios", THEME.purple, UDim2.new(0.2, -5, 1, 0), function()
			if not state then
				return
			end
			-- Pasa a la siguiente app de anuncios desbloqueada
			local list = unlockedNetworkList(state)
			local nextIndex = 1
			for i, network in list do
				if network.id == row.currentNetwork then
					nextIndex = i % #list + 1
				end
			end
			sendAction("setNetwork", row.id, list[nextIndex].id)
		end)
		row.level = makeButton(buttons, "Cantidad", THEME.orange, UDim2.new(0.2, -5, 1, 0), function()
			sendAction("setAdLevel", row.id, (row.currentLevel or 1) % #Config.AdLevels + 1)
		end)
		row.sell = makeButton(buttons, "Vender", THEME.red, UDim2.new(0.2, -5, 1, 0), function()
			sendAction("quickSell", row.id)
		end)
		return row
	end, function(row, site)
		local def = Config.WebTypeById[site.type]
		local network = Config.AdNetworkById[site.network]
		row.currentNetwork = site.network
		row.currentLevel = site.adLevel
		row.title.Text = (if site.viral then "🔥 " else "") .. def.emoji .. " " .. site.name .. "  ·  " .. def.name .. "  ·  " .. nicheLabel(site.niche)
		row.title.TextColor3 = if site.viral then THEME.orange else THEME.text
		row.info.Text = string.format("⭐ Calidad %d%% · 🔎 SEO %d/%d · 👀 %s visitas/s · 💵 %s/s",
			math.floor(site.quality * 100), site.seo, Config.MAX_SEO, num(site.visits), fmt(site.income))

		if site.seo >= Config.MAX_SEO then
			setButton(row.seo, "SEO MÁX", false)
		else
			setButton(row.seo, "🔎 SEO+ " .. fmt(site.seoCost), s.money >= site.seoCost)
		end
		local multiple = #unlockedNetworkList(s) > 1
		setButton(row.network, network.emoji .. " " .. network.name .. (if multiple then " ▸" else ""), multiple)
		setButton(row.level, "Anuncios: " .. Config.AdLevels[site.adLevel].name .. " ▸", true)
		setButton(row.sell, "Vender " .. fmt(site.saleBase * Config.QUICK_SALE_MULT), true)
	end)
end

-- Ficha detallada ------------------------------------------------------
detail = create("ScrollingFrame", {
	Parent = content,
	Name = "FichaWeb",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = THEME.muted,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 2,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
})

local function closeSiteDetail()
	detailSiteId = nil
	detail.Visible = false
	sitesPage.Visible = currentTab == "sites"
end

local detailHeader = makeCard(detail, 70, 1, Color3.fromRGB(23, 37, 84))
local backButton = makeButton(detailHeader, "← Volver", THEME.card, UDim2.fromOffset(110, 30), closeSiteDetail)
backButton.Position = UDim2.fromOffset(0, 0)
local detailTitle = makeLabel(detailHeader, "", 0, 26, 20, THEME.text, true)
detailTitle.Position = UDim2.fromOffset(120, 0)
detailTitle.Size = UDim2.new(1, -120, 0, 26)
local detailSubtitle = makeLabel(detailHeader, "", 32, 18, 14, THEME.muted)

-- Cuatro cifras grandes
local statsRow = create("Frame", {
	Parent = detail,
	LayoutOrder = 2,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -8, 0, 74),
}, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function statBox(order: number, caption: string, color: Color3): TextLabel
	local box = create("Frame", {
		Parent = statsRow,
		LayoutOrder = order,
		Size = UDim2.new(0.25, -6, 1, 0),
		BackgroundColor3 = THEME.card,
	}, { corner(12), padding(8), stroke(color, 2) })
	makeLabel(box, caption, 0, 16, 13, THEME.muted, true)
	local value = create("TextLabel", {
		Parent = box,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextColor3 = color,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxText(30) })
	return value
end
local statVisits = statBox(1, "👀 Visitas por segundo", THEME.accent)
local statIncome = statBox(2, "💵 Dinero por segundo", THEME.green)
local statTotalVisits = statBox(3, "📊 Visitas totales", THEME.purple)
local statEarned = statBox(4, "💰 Ganado en total", THEME.yellow)

-- Gráfica de visitas
local chartCard = makeCard(detail, 150, 3)
local chartTitle = makeLabel(chartCard, "📈 Visitas en directo (último minuto)", 0, 20, 15, THEME.text, true)
local chartArea = create("Frame", {
	Parent = chartCard,
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 1, -26),
	BackgroundColor3 = THEME.bg,
}, { corner(8) })
local chartBars: { Frame } = {}
for i = 1, HISTORY_SIZE do
	chartBars[i] = create("Frame", {
		Parent = chartArea,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new((i - 1) / HISTORY_SIZE, 1, 1, 0),
		Size = UDim2.new(1 / HISTORY_SIZE, -2, 0, 0),
		BackgroundColor3 = THEME.accent,
		BorderSizePixel = 0,
	}, { corner(2) })
end

-- Comparativa de apps de anuncios
local adsCompareCard = makeCard(detail, 60 + #Config.AdNetworks * 36 + 78, 4)
makeLabel(adsCompareCard, "📢 ¿Cuánto te pagan por visita? (esta web)", 0, 20, 15, THEME.text, true)
makeLabel(adsCompareCard, "App · paga por visita · visitas que pierdes · lo que ganarías", 22, 16, 12, THEME.muted)
local compareRows = {}
for i, network in Config.AdNetworks do
	local y = 40 + (i - 1) * 36
	local label = makeLabel(adsCompareCard, "", y + 6, 20, 14, THEME.text)
	label.Size = UDim2.new(1, -150, 0, 20)
	local button = makeButton(adsCompareCard, "", THEME.purple, UDim2.fromOffset(140, 30), function()
		if not state or not detailSiteId then
			return
		end
		if state.unlockedAds[network.id] then
			sendAction("setNetwork", detailSiteId, network.id)
		else
			openTab("ads")
		end
	end)
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, 0, 0, y)
	compareRows[network.id] = { label = label, button = button }
end
local levelsY = 40 + #Config.AdNetworks * 36 + 4
makeLabel(adsCompareCard, "Cantidad de anuncios en esta web:", levelsY, 18, 14, THEME.text, true)
local levelButtons = {}
local levelRow = makeButtonRow(adsCompareCard, levelsY + 22, 34)
for i, level in Config.AdLevels do
	levelButtons[i] = makeButton(levelRow, level.name, THEME.orange, UDim2.new(1 / #Config.AdLevels, -5, 1, 0), function()
		if detailSiteId then
			sendAction("setAdLevel", detailSiteId, i)
		end
	end)
end

-- Mejoras
local upgradesCard = makeCard(detail, 118, 5)
makeLabel(upgradesCard, "🛠️ Mejorar esta web", 0, 20, 15, THEME.text, true)
local seoInfo = makeLabel(upgradesCard, "", 24, 18, 13, THEME.muted)
local designInfo = makeLabel(upgradesCard, "", 44, 18, 13, THEME.muted)
local upgradeRow = makeButtonRow(upgradesCard, 66, 32)
local detailSeoButton = makeButton(upgradeRow, "SEO", THEME.accent, UDim2.new(0.5, -3, 1, 0), function()
	if detailSiteId then
		sendAction("upgradeSeo", detailSiteId)
	end
end)
local detailDesignButton = makeButton(upgradeRow, "Diseño", THEME.pink, UDim2.new(0.5, -3, 1, 0), function()
	if detailSiteId then
		sendAction("upgradeDesign", detailSiteId)
	end
end)

-- Venta
local sellCard = makeCard(detail, 112, 6)
makeLabel(sellCard, "🤝 Vender esta web", 0, 20, 15, THEME.text, true)
local sellInfo = makeLabel(sellCard, "", 24, 18, 13, THEME.muted)
local sellRow = makeButtonRow(sellCard, 50, 34)
local detailOfferButton = makeButton(sellRow, "", THEME.green, UDim2.new(0.6, -3, 1, 0), function() end)
local detailQuickButton = makeButton(sellRow, "", THEME.red, UDim2.new(0.4, -3, 1, 0), function()
	if detailSiteId then
		sendAction("quickSell", detailSiteId)
		closeSiteDetail()
	end
end)
local detailOfferId: number? = nil
detailOfferButton.Activated:Connect(function()
	if detailSiteId and detailOfferId and detailOfferButton:GetAttribute("Enabled") then
		sendAction("sellToOffer", detailOfferId, detailSiteId, function(ok)
			if ok then
				pulseMoney()
				closeSiteDetail()
			end
		end)
	end
end)

-- Valor que tendría la web con otra app / otra cantidad de anuncios
local function simulateIncome(s, site, networkId: string?, adLevel: number?): (number, number)
	local copy = table.clone(site)
	copy.network = networkId or site.network
	copy.adLevel = adLevel or site.adLevel
	local visits = Config.siteVisits(s, copy, 1)
	return visits, Config.siteIncome(s, copy, visits, s.moneyMult)
end

local function bestOfferFor(s, site)
	local best, bestValue = nil, 0
	for _, offer in s.offers do
		if offer.type == site.type then
			local value = site.saleBase * offer.mult * (if offer.niche == site.niche then Career.NICHE_MATCH_SALE_BONUS else 1)
			if value > bestValue then
				best, bestValue = offer, value
			end
		end
	end
	return best, bestValue
end

function renderDetail(s)
	if not detailSiteId then
		return
	end
	local site = nil
	for _, candidate in s.sites do
		if candidate.id == detailSiteId then
			site = candidate
		end
	end
	if not site then
		closeSiteDetail()
		return
	end
	local def = Config.WebTypeById[site.type]
	detailTitle.Text = (if site.viral then "🔥 " else "") .. def.emoji .. " " .. site.name
	detailSubtitle.Text = string.format("%s · %s · ⭐ Calidad %d%% · 🔎 SEO %d/%d · 🎨 Diseño %d/%d",
		def.name, nicheLabel(site.niche), math.floor(site.quality * 100), site.seo, Config.MAX_SEO, site.design, Config.MAX_DESIGN)
	statVisits.Text = num(site.visits)
	statIncome.Text = fmt(site.income)
	statTotalVisits.Text = num(site.totalVisits)
	statEarned.Text = fmt(site.earned)

	-- Gráfica
	local history = visitHistory[site.id] or {}
	local maxValue = 1
	for _, v in history do
		maxValue = math.max(maxValue, v)
	end
	chartTitle.Text = "📈 Visitas en directo · máximo " .. num(maxValue) .. "/s"
	for i, bar in chartBars do
		local value = history[#history - HISTORY_SIZE + i]
		bar.Size = UDim2.new(1 / HISTORY_SIZE, -2, if value then math.max(0.02, value / maxValue * 0.95) else 0, 0)
		bar.BackgroundColor3 = if site.viral and i == HISTORY_SIZE then THEME.orange else THEME.accent
	end

	-- Comparativa
	local _, currentIncome = simulateIncome(s, site, nil, nil)
	for _, network in Config.AdNetworks do
		local row = compareRows[network.id]
		local visits, income = simulateIncome(s, site, network.id, nil)
		local diff = if currentIncome > 0 then (income / currentIncome - 1) * 100 else 0
		local diffText = if network.id == site.network then "" elseif diff >= 0 then string.format("  (+%d%%)", math.floor(diff + 0.5)) else string.format("  (%d%%)", math.floor(diff - 0.5))
		row.label.Text = string.format("%s %s · %s/visita · -%d%% visitas → %s visitas/s · %s/s%s",
			network.emoji, network.name, fmt(network.rpv), math.floor(network.penalty * 100), num(visits), fmt(income), diffText)
		row.label.TextColor3 = if network.id == site.network then THEME.green elseif diff > 0 then THEME.text else THEME.muted
		if network.id == site.network then
			setButton(row.button, "✓ En uso", false, THEME.green)
			row.button:SetAttribute("PaintColor", THEME.green)
		elseif s.unlockedAds[network.id] then
			setButton(row.button, "Usar", true, THEME.purple)
		elseif s.reputation < network.rep then
			setButton(row.button, "🔒 ⭐" .. num(network.rep), true, THEME.disabled)
		else
			setButton(row.button, "🔓 " .. fmt(network.cost), true, THEME.accent)
		end
	end
	for i, level in Config.AdLevels do
		local _, income = simulateIncome(s, site, nil, i)
		setButton(levelButtons[i], string.format("%s%s · %s/s", if site.adLevel == i then "✓ " else "", level.name, fmt(income)), site.adLevel ~= i, THEME.orange)
		if site.adLevel == i then
			levelButtons[i]:SetAttribute("PaintColor", THEME.green)
		end
	end

	-- Mejoras
	if site.seo >= Config.MAX_SEO then
		seoInfo.Text = "🔎 SEO al máximo"
		setButton(detailSeoButton, "SEO MÁX", false)
	else
		local copy = table.clone(site)
		copy.seo += 1
		local _, after = simulateIncome(s, copy, nil, nil)
		seoInfo.Text = string.format("🔎 SEO %d → %d: +25%% visitas (%s/s → %s/s)", site.seo, site.seo + 1, fmt(currentIncome), fmt(after))
		setButton(detailSeoButton, "🔎 Mejorar SEO · " .. fmt(site.seoCost), s.money >= site.seoCost)
	end
	if site.design >= Config.MAX_DESIGN then
		designInfo.Text = "🎨 Diseño al máximo"
		setButton(detailDesignButton, "DISEÑO MÁX", false)
	else
		local copy = table.clone(site)
		copy.design += 1
		local _, after = simulateIncome(s, copy, nil, nil)
		designInfo.Text = string.format("🎨 Rediseño %d → %d: +10%% calidad (%s/s → %s/s)", site.design, site.design + 1, fmt(currentIncome), fmt(after))
		setButton(detailDesignButton, "🎨 Rediseñar · " .. fmt(site.designCost), s.money >= site.designCost)
	end

	-- Venta
	local offer, offerValue = bestOfferFor(s, site)
	detailOfferId = offer and offer.id
	if offer then
		local match = offer.niche == site.niche
		sellInfo.Text = string.format("Mejor oferta: %s %s (x%.2f%s)", nicheLabel(offer.niche), offer.company, offer.mult, if match then " · ⭐ mismo nicho x1.5" else "")
		setButton(detailOfferButton, "💰 Vender a " .. offer.company .. " por " .. fmt(offerValue), true, if match then THEME.yellow else THEME.green)
	else
		sellInfo.Text = "Ahora mismo ninguna empresa busca un " .. def.name .. ". Las ofertas cambian cada poco."
		setButton(detailOfferButton, "Sin ofertas para esta web", false)
	end
	setButton(detailQuickButton, "Venta rápida · " .. fmt(site.saleBase * Config.QUICK_SALE_MULT), true)
end

function openSiteDetail(siteId: number)
	detailSiteId = siteId
	sitesPage.Visible = false
	detail.Visible = true
	detail.CanvasPosition = Vector2.zero
	if state then
		renderDetail(state)
	end
end
end

---------------------------------------------------------------------
-- Pestaña CLIENTES
---------------------------------------------------------------------
do
local clientsPage = pages.clients
local clientsHeader = makeCard(clientsPage, 84, 1, Color3.fromRGB(66, 52, 12))
makeLabel(clientsHeader, "🤝 Empresas que quieren comprar webs", 0, 22, 17, THEME.text, true)
makeLabel(clientsHeader, "Pagan según las visitas. Si la web es de SU nicho pagan x1.5. Cada venta da reputación y mantenimiento.", 22, 18, 13, THEME.muted)
local maintenanceLabel = makeLabel(clientsHeader, "", 42, 18, 14, THEME.green, true)

local offerRows = {}

-- La web que más te pagarían en esa oferta (teniendo en cuenta el nicho)
function bestSiteFor(s, offer)
	local best, bestValue = nil, 0
	for _, site in s.sites do
		if site.type == offer.type then
			local value = site.saleBase * offer.mult * (if offer.niche == site.niche then Career.NICHE_MATCH_SALE_BONUS else 1)
			if value > bestValue then
				best, bestValue = site, value
			end
		end
	end
	return best, bestValue
end

renderers.clients = function(s)
	maintenanceLabel.Text = "🔧 Contratos de mantenimiento: +" .. fmt(s.maintenance) .. "/s para siempre"

	syncRows(clientsPage, offerRows, s.offers, function(offer)
		return offer.id
	end, function(offer)
		local card = makeCard(clientsPage, 96, 0)
		local row: any = { frame = card, id = offer.id }
		row.title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
		row.info = makeLabel(card, "", 24, 18, 14, THEME.muted)
		row.sell = makeButton(card, "Vender", THEME.green, UDim2.new(1, 0, 0, 30), function()
			if row.siteId then
				sendAction("sellToOffer", row.id, row.siteId, function(ok)
					if ok then
						pulseMoney()
					end
				end)
			end
		end)
		row.sell.Position = UDim2.fromOffset(0, 46)
		return row
	end, function(row, offer)
		local def = Config.WebTypeById[offer.type]
		local vip = offer.mult >= 3
		row.title.Text = (if vip then "👑 " else "🏢 ") .. offer.company .. " quiere: " .. def.emoji .. " " .. def.name
		row.title.TextColor3 = if vip then THEME.yellow else THEME.text
		row.info.Text = string.format("%s · paga x%.2f del valor · ⏱ %s", nicheLabel(offer.niche), offer.mult, Config.formatTime(offer.timeLeft))
		local site, value = bestSiteFor(s, offer)
		row.siteId = site and site.id
		if site then
			local match = site.niche == offer.niche
			setButton(row.sell, "💰 Vender " .. site.name .. " por " .. fmt(value) .. (if match then "  ⭐ x1.5" else ""), true, if vip or match then THEME.yellow else THEME.green)
		else
			setButton(row.sell, "No tienes ninguna " .. def.name, false)
		end
	end)
end
end

---------------------------------------------------------------------
-- Pestaña ANUNCIOS
---------------------------------------------------------------------
do
local adsPage = pages.ads
local adsHeader = makeCard(adsPage, 104, 1, Color3.fromRGB(59, 30, 84))
makeLabel(adsHeader, "📢 Apps de anuncios para tus webs", 0, 22, 17, THEME.text, true)
makeLabel(adsHeader, "Cada app paga distinto por visita, pero algunas molestan y espantan visitas.", 22, 18, 13, THEME.muted)
makeLabel(adsHeader, "Cantidad: Pocos (x1 dinero) · Normal (x1.7, -12% visitas) · Muchos (x2.5, -32% visitas)", 42, 18, 13, THEME.muted)
makeLabel(adsHeader, "💡 Truco: menos visitas = la web vale menos al venderla.", 62, 18, 13, THEME.yellow)

local networkRows = {}
for i, network in Config.AdNetworks do
	local card = makeCard(adsPage, 92, 10 + i)
	makeLabel(card, network.emoji .. " " .. network.name, 0, 22, 17, THEME.text, true)
	makeLabel(card, string.format("Paga %s por visita · Pierdes %d%% de visitas · Requiere ⭐ %s",
		fmt(network.rpv), math.floor(network.penalty * 100), num(network.rep)), 24, 18, 14, THEME.muted)
	local button = makeButton(card, "", THEME.accent, UDim2.new(1, 0, 0, 28), function()
		sendAction("unlockNetwork", network.id)
	end)
	button.Position = UDim2.fromOffset(0, 46)
	networkRows[network.id] = { button = button }
end

renderers.ads = function(s)
	for _, network in Config.AdNetworks do
		local row = networkRows[network.id]
		if s.unlockedAds[network.id] then
			setButton(row.button, "✓ Desbloqueada", false, THEME.green)
			row.button:SetAttribute("PaintColor", THEME.green)
		elseif s.reputation < network.rep then
			setButton(row.button, "🔒 Necesitas ⭐ " .. num(network.rep) .. " de reputación", false)
		else
			setButton(row.button, "🔓 Desbloquear por " .. fmt(network.cost), s.money >= network.cost)
		end
	end
end
end

---------------------------------------------------------------------
-- Pestaña EMPRESAS
---------------------------------------------------------------------
do
local companiesPage = pages.companies
local companiesHeader = makeCard(companiesPage, 56, 1, Color3.fromRGB(84, 46, 18))
makeLabel(companiesHeader, "🏢 Tus empresas", 0, 22, 17, THEME.text, true)
local companiesSummary = makeLabel(companiesHeader, "", 22, 18, 14, THEME.green, true)

local companyRows = {}
for i, def in Config.Companies do
	local card = makeCard(companiesPage, 96, 10 + i)
	local title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
	makeLabel(card, def.desc, 24, 18, 14, THEME.muted)
	local button = makeButton(card, "", THEME.orange, UDim2.new(1, 0, 0, 30), function()
		sendAction("buyCompany", def.id)
	end)
	button.Position = UDim2.fromOffset(0, 46)
	companyRows[def.id] = { title = title, button = button }
end

renderers.companies = function(s)
	companiesSummary.Text = "💵 Tus empresas generan " .. fmt(Config.companiesIncome(s, s.moneyMult)) .. "/s"
	for _, def in Config.Companies do
		local row = companyRows[def.id]
		local level = s.companies[def.id] or 0
		local incomeText = if def.income > 0 then " · +" .. fmt(def.income * s.moneyMult) .. "/s por nivel" else ""
		row.title.Text = def.emoji .. " " .. def.name .. "  —  Nivel " .. level .. incomeText
		if level >= def.maxLevel then
			setButton(row.button, "NIVEL MÁXIMO", false)
		else
			local cost = Config.companyCost(def.id, level)
			setButton(row.button, (if level == 0 then "🏗️ Fundar por " else "⬆️ Mejorar por ") .. fmt(cost), s.money >= cost)
		end
	end
end
end

---------------------------------------------------------------------
-- Pestaña CARRERA (niveles por nicho, trabajo y bolsa de empleo)
---------------------------------------------------------------------
do
local careerPage = pages.career

local profileCard = makeCard(careerPage, 76, 1, Color3.fromRGB(30, 58, 138))
local profileTitle = makeLabel(profileCard, "", 0, 26, 20, THEME.text, true)
local profileInfo = makeLabel(profileCard, "Subes de nivel programando webs del nicho elegido, trabajando y resolviendo tareas.", 30, 18, 13, THEME.muted)
profileInfo.TextWrapped = true
profileInfo.TextTruncate = Enum.TextTruncate.None

-- Rejilla de nichos con su nivel
local nicheGrid = create("Frame", {
	Parent = careerPage,
	LayoutOrder = 2,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -8, 0, 5 * 46),
}, {
	create("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 40), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local nicheCells = {}
for i, niche in Career.Niches do
	local cell = create("Frame", {
		Parent = nicheGrid,
		LayoutOrder = i,
		BackgroundColor3 = THEME.card,
	}, { corner(10), padding(6), stroke(THEME.stroke, 1) })
	local label = makeLabel(cell, niche.emoji .. " " .. niche.name, 0, 14, 13, THEME.text, true)
	local _back, fill, text = makeProgressBar(cell, UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 12), THEME.accent)
	nicheCells[niche.id] = { label = label, fill = fill, text = text, cell = cell }
end

-- Trabajo actual
local jobCard = makeCard(careerPage, 132, 3, Color3.fromRGB(20, 83, 45))
local jobTitle = makeLabel(jobCard, "", 0, 22, 17, THEME.text, true)
local jobInfo = makeLabel(jobCard, "", 24, 18, 14, THEME.muted)
local jobPromotion = makeLabel(jobCard, "", 44, 18, 13, THEME.yellow, true)
local jobRow = makeButtonRow(jobCard, 72, 36)
local taskButton = makeButton(jobRow, "", THEME.green, UDim2.new(0.7, -3, 1, 0), function()
	sendAction("solveTask", nil, nil, function(ok)
		if ok then
			pulseMoney()
		end
	end)
end)
local quitConfirm = 0
local quitButton: TextButton
quitButton = makeButton(jobRow, "Dimitir", THEME.red, UDim2.new(0.3, -3, 1, 0), function()
	if os.clock() < quitConfirm then
		quitConfirm = 0
		sendAction("quitJob")
	else
		quitConfirm = os.clock() + 3
		quitButton.Text = "¿Seguro?"
	end
end)

-- Ofertas de empleo que te llegan (cada una con su sueldo aleatorio)
local offersHeader = makeCard(careerPage, 96, 4, Color3.fromRGB(23, 37, 84))
makeLabel(offersHeader, "📨 Ofertas de empleo", 0, 20, 17, THEME.text, true)
local offersInfo = makeLabel(offersHeader, "Te llegan solas cada poco. Cada empresa paga distinto y cada oferta tiene sus condiciones.", 22, 18, 13, THEME.muted)
local cvButton = makeButton(offersHeader, "", THEME.accent, UDim2.new(1, 0, 0, 30), function()
	sendAction("sendCV")
end)
cvButton.Position = UDim2.fromOffset(0, 46)

local emptyOffers = makeCard(careerPage, 50, 5)
makeLabel(emptyOffers, "No tienes ofertas ahora mismo. Envía un currículum o espera a que te escriban.", 0, 30, 14, THEME.muted)

local offerJobRows = {}

local function multText(mult: number): string
	local percent = math.floor((mult - 1) * 100 + 0.5)
	return if percent >= 0 then "+" .. percent .. "%" else tostring(percent) .. "%"
end

renderers.career = function(s)
	local c = s.career
	profileTitle.Text = string.format("🎓 Nivel de programador %d%s", c.devLevel, if s.bonuses.xpPass then "  ·  🎓 x2 XP" else "")

	for _, niche in Career.Niches do
		local cell = nicheCells[niche.id]
		local level = c.nicheLevels[niche.id]
		local xp = c.xp[niche.id] or 0
		local from, to = Career.xpForLevel(level), Career.xpForLevel(level + 1)
		local ratio = if level >= Career.MAX_NICHE_LEVEL then 1 else math.clamp((xp - from) / math.max(to - from, 1), 0, 1)
		cell.label.Text = string.format("%s %s · Nv %d", niche.emoji, niche.name, level)
		cell.fill.Size = UDim2.fromScale(ratio, 1)
		cell.text.Text = if level >= Career.MAX_NICHE_LEVEL then "MÁX" else string.format("%d / %d XP", math.floor(xp - from), math.floor(to - from))
	end

	-- Trabajo
	local job = c.job
	if job then
		local company = Career.company(job.companyId)
		local rank = Career.Ranks[job.rank]
		jobTitle.Text = string.format("💼 %s · %s %s", company.name, company.tier.emoji, company.tier.name)
		jobInfo.Text = string.format("%s · Puesto: %s · Sueldo %s/s (%s) · +%s XP/s", nicheLabel(company.niche), rank.name, fmt(job.salary), multText(job.salaryMult or 1), num(job.xpRate))
		jobPromotion.Text = if job.promotion then "⬆️ Próximo ascenso: " .. job.promotion else "⬆️ ¡Ascenso inminente!"
		if job.taskLeft <= 0 then
			setButton(taskButton, string.format("✅ Resolver tarea (+%s)", fmt(job.salary * Career.TASK_SALARY_SECONDS)), true, THEME.green)
		else
			setButton(taskButton, "Próxima tarea en " .. Config.formatTime(job.taskLeft), false)
		end
		quitButton.Visible = true
		if os.clock() >= quitConfirm then
			setButton(quitButton, "Dimitir", true, THEME.red)
		end
	else
		jobTitle.Text = "💼 Sin trabajo"
		jobInfo.Text = "Acepta una de las ofertas de abajo: cobrarás un sueldo y subirás de nivel."
		jobPromotion.Text = ""
		setButton(taskButton, "Acepta una oferta de empleo 👇", false)
		quitButton.Visible = false
	end

	-- Currículum
	if c.cvLeft > 0 then
		setButton(cvButton, "📨 Enviar currículum (en " .. Config.formatTime(c.cvLeft) .. ")", false)
	else
		setButton(cvButton, "📨 Enviar currículum a una empresa", true, THEME.accent)
	end
	offersInfo.Text = string.format("Te llegan solas cada poco (máx. %d). Cada empresa paga distinto y cada oferta tiene sus condiciones.", Career.JOB_OFFER_MAX)
	emptyOffers.Visible = #c.jobOffers == 0

	syncRows(careerPage, offerJobRows, c.jobOffers, function(offer)
		return offer.id
	end, function(offer)
		local card = makeCard(careerPage, 104, 0)
		local row: any = { frame = card, id = offer.id }
		row.title = makeLabel(card, "", 0, 20, 16, THEME.text, true)
		row.info = makeLabel(card, "", 22, 18, 13, THEME.muted)
		row.info2 = makeLabel(card, "", 42, 18, 13, THEME.text)
		row.button = makeButton(card, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
			sendAction("acceptJobOffer", row.id)
		end)
		row.button.Position = UDim2.fromOffset(0, 64)
		return row
	end, function(row, offer)
		local company = Career.company(offer.companyId)
		local rank = Career.Ranks[offer.rank]
		local better = job == nil or offer.salary > job.salary
		row.title.Text = string.format("%s %s · %s · %s", company.tier.emoji, company.name, company.tier.name, nicheLabel(company.niche))
		row.title.TextColor3 = if offer.salaryMult >= 1.3 then THEME.yellow else THEME.text
		row.info.Text = string.format("Puesto: %s · caduca en %s", rank.name, Config.formatTime(offer.timeLeft))
		row.info2.Text = string.format("💵 %s/s (%s) · 🎓 %s XP/s (%s)%s", fmt(offer.salary), multText(offer.salaryMult), num(offer.xpRate), multText(offer.xpMult),
			if job then (if better then "  ·  ⬆️ mejor que tu sueldo" else "  ·  ⬇️ menos que tu sueldo") else "")
		setButton(row.button, if job then "Cambiar a este trabajo" else "✅ Aceptar oferta", true, if better then THEME.green else THEME.orange)
	end)
end
end

---------------------------------------------------------------------
-- Pestaña AGENCIA (tu empresa de programadores)
---------------------------------------------------------------------
do
local agencyPage = pages.agency

local foundCard = makeCard(agencyPage, 104, 1, Color3.fromRGB(30, 58, 138))
makeLabel(foundCard, "🏢 Funda tu propia agencia", 0, 22, 18, THEME.text, true)
local foundInfo = makeLabel(foundCard, "", 26, 34, 14, THEME.muted)
foundInfo.TextWrapped = true
foundInfo.TextTruncate = Enum.TextTruncate.None
local foundButton = makeButton(foundCard, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
	sendAction("foundAgency")
end)
foundButton.Position = UDim2.fromOffset(0, 64)

local agencyCard = makeCard(agencyPage, 112, 2, Color3.fromRGB(30, 58, 138))
local agencyTitle = makeLabel(agencyCard, "", 0, 22, 18, THEME.text, true)
local agencyInfo = makeLabel(agencyCard, "", 26, 18, 14, THEME.green, true)
local agencyInfo2 = makeLabel(agencyCard, "", 46, 18, 13, THEME.muted)
local officeButton = makeButton(agencyCard, "", THEME.orange, UDim2.new(1, 0, 0, 30), function()
	sendAction("upgradeOffice")
end)
officeButton.Position = UDim2.fromOffset(0, 70)

function oddsText(field: string): string
	local parts = {}
	for _, entry in Career.odds(field) do
		local percent = entry.percent
		table.insert(parts, string.format(if percent < 1 then "%s %.1f%%" else "%s %d%%", entry.rarity.name, if percent < 1 then percent else math.floor(percent + 0.5)))
	end
	return table.concat(parts, " · ")
end

local recruitCard = makeCard(agencyPage, 112, 3, Color3.fromRGB(76, 29, 149))
makeLabel(recruitCard, "🎲 Entrevistar programadores", 0, 22, 17, THEME.text, true)
local _oddsLabel = makeLabel(recruitCard, "Probabilidades: " .. oddsText("weight"), 24, 18, 12, THEME.muted)
local pityLabel = makeLabel(recruitCard, "", 44, 18, 13, THEME.yellow, true)
local recruitButton = makeButton(recruitCard, "", THEME.purple, UDim2.new(1, 0, 0, 34), function() end)
recruitButton.Position = UDim2.fromOffset(0, 66)

local ticketsCard = makeCard(agencyPage, 150, 4, Color3.fromRGB(76, 29, 149))
makeLabel(ticketsCard, "🎟️ Tus tickets", 0, 22, 17, THEME.text, true)
local premiumLabel = makeLabel(ticketsCard, "", 24, 18, 13, THEME.muted)
local premiumButton = makeButton(ticketsCard, "", THEME.purple, UDim2.new(1, 0, 0, 30), function() end)
premiumButton.Position = UDim2.fromOffset(0, 44)
local legendaryNiche = Career.DEFAULT_NICHE
local legendaryRow = makeButtonRow(ticketsCard, 82, 30)
local legendaryNicheButton = makeButton(legendaryRow, "", THEME.card, UDim2.new(0.4, -3, 1, 0), function()
	local index = Career.NicheById[legendaryNiche].order
	legendaryNiche = Career.Niches[index % #Career.Niches + 1].id
	if state then
		renderers.agency(state)
	end
end)
local legendaryButton = makeButton(legendaryRow, "", THEME.yellow, UDim2.new(0.6, -3, 1, 0), function() end)
local ticketsHint = makeLabel(ticketsCard, "Los tickets se consiguen en 🛒 Tienda.", 118, 16, 12, THEME.muted)

local teamTitle = makeCard(agencyPage, 40, 5)
local teamTitleLabel = makeLabel(teamTitle, "👥 Tu equipo", 0, 20, 17, THEME.text, true)

-- Revelación de un fichaje
local function showRecruit(programmer)
	local rarity = Career.RarityById[programmer.rarity]
	local niche = Career.NicheById[programmer.niche]
	local work, bonus = Career.programmerPower(programmer, state and state.bonuses.agencyPro)
	if rarity.order >= 4 then
		playSound("crit")
	end
	showModal("🎉 ¡Nuevo fichaje!", "", "¡Bienvenido al equipo!", nil, function(frame)
		local cardFrame = create("Frame", {
			Parent = frame,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.8, 0, 1, -6),
			BackgroundColor3 = darken(rarity.color, 0.55),
		}, { corner(16), stroke(rarity.color, 4), padding(10) })
		local scale = create("UIScale", { Parent = cardFrame, Scale = 0.3 })
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		create("TextLabel", {
			Parent = cardFrame,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			Text = string.upper(rarity.name),
			TextColor3 = rarity.color,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
		}, { maxText(36) })
		create("TextLabel", {
			Parent = cardFrame,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 50),
			Text = "👩‍💻 " .. programmer.name,
			TextColor3 = THEME.text,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
		}, { maxText(40) })
		create("TextLabel", {
			Parent = cardFrame,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 100),
			Size = UDim2.new(1, 0, 0, 60),
			Text = string.format("%s %s\n+%d%% a todo tu dinero · +%s trabajo/s", niche.emoji, niche.name, math.floor(bonus * 100 + 0.5), num(work)),
			TextColor3 = THEME.text,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextWrapped = true,
		})
	end)
end

local function recruitResult(ok: boolean, _message: string?, extra: any)
	if ok and type(extra) == "table" and extra.recruit then
		showRecruit(extra.recruit)
	end
end
recruitButton.Activated:Connect(function()
	if recruitButton:GetAttribute("Enabled") then
		sendAction("recruit", nil, nil, recruitResult)
	end
end)
premiumButton.Activated:Connect(function()
	if premiumButton:GetAttribute("Enabled") then
		sendAction("redeemTicket", "premium", nil, recruitResult)
	end
end)
legendaryButton.Activated:Connect(function()
	if legendaryButton:GetAttribute("Enabled") then
		sendAction("redeemTicket", "legendary", legendaryNiche, recruitResult)
	end
end)

local programmerRows = {}

renderers.agency = function(s)
	local c = s.career
	local agency = c.agency
	foundCard.Visible = agency == nil
	agencyCard.Visible = agency ~= nil
	recruitCard.Visible = agency ~= nil
	ticketsCard.Visible = agency ~= nil
	teamTitle.Visible = agency ~= nil

	if not agency then
		foundInfo.Text = string.format("Necesitas nivel de programador %d (tienes %d) y %s. Tus programadores programarán por ti y te darán un %% extra de TODO tu dinero.",
			Career.AGENCY_LEVEL_REQUIRED, c.devLevel, fmt(Career.AGENCY_COST))
		local can = c.devLevel >= Career.AGENCY_LEVEL_REQUIRED and s.money >= Career.AGENCY_COST
		setButton(foundButton, if c.devLevel < Career.AGENCY_LEVEL_REQUIRED then "🔒 Sube a nivel " .. Career.AGENCY_LEVEL_REQUIRED .. " en 💼 Carrera" else "🏢 Fundar agencia (" .. fmt(Career.AGENCY_COST) .. ")", can)
		syncRows(agencyPage, programmerRows, {}, function(p) return p.id end, function() return nil end, function() end)
		return
	end

	local full = #c.programmers >= agency.capacity
	agencyTitle.Text = string.format("🏢 %s · Oficina nivel %d", agency.name, agency.officeLevel)
	agencyInfo.Text = string.format("+%d%% a todo tu dinero · +%s trabajo/s", math.floor(s.bonuses.agencyBonus * 100 + 0.5), num(s.bonuses.agencyWork))
	agencyInfo2.Text = string.format("Puestos ocupados: %d/%d%s", #c.programmers, agency.capacity, if s.bonuses.agencyPro then " · 🏙️ Agencia Pro" else "")
	if agency.upgradeCost then
		setButton(officeButton, "🏗️ Ampliar oficina (+2 puestos) · " .. fmt(agency.upgradeCost), s.money >= agency.upgradeCost)
	else
		setButton(officeButton, "Oficina al máximo", false)
	end

	pityLabel.Text = string.format("⭐ Legendario garantizado en %d entrevistas", math.max(1, Career.PITY_INTERVIEWS - c.pity))
	if full then
		setButton(recruitButton, "Oficina llena: amplíala o despide a alguien", false)
	else
		setButton(recruitButton, "🎲 Entrevistar · " .. fmt(c.recruitCost), s.money >= c.recruitCost)
	end

	-- Tickets
	local restricted = s.bonuses.randomRestricted
	premiumLabel.Text = if restricted then "🎯 Headhunter Premium no disponible en tu país."
		else string.format("🎯 Headhunter Premium: %d · %s", c.tickets.premium or 0, oddsText("premium"))
	premiumButton.Visible = not restricted
	setButton(premiumButton, "🎯 Usar Headhunter Premium", (c.tickets.premium or 0) > 0 and not full)
	setButton(legendaryNicheButton, "Nicho: " .. Career.NicheById[legendaryNiche].emoji .. " ▸", true, THEME.card)
	setButton(legendaryButton, string.format("👑 Usar Contrato Legendario (%d)", c.tickets.legendary or 0), (c.tickets.legendary or 0) > 0 and not full)
	ticketsHint.Text = "Consigue tickets en 🛒 Tienda · " .. (if full then "⚠️ oficina llena" else "Hay sitio en la oficina")

	teamTitleLabel.Text = string.format("👥 Tu equipo (%d)", #c.programmers)
	syncRows(agencyPage, programmerRows, c.programmers, function(p)
		return p.id
	end, function(p)
		local rarity = Career.RarityById[p.rarity]
		local card = create("Frame", {
			Parent = agencyPage,
			Size = UDim2.new(1, -8, 0, 84),
			BackgroundColor3 = darken(rarity.color, 0.6),
		}, { corner(12), padding(10), stroke(rarity.color, 2) })
		local row: any = { frame = card, id = p.id, confirm = 0 }
		row.title = makeLabel(card, "", 0, 20, 16, rarity.color, true)
		row.info = makeLabel(card, "", 22, 18, 13, THEME.text)
		local buttons = makeButtonRow(card, 44, 28)
		row.train = makeButton(buttons, "", THEME.accent, UDim2.new(0.7, -3, 1, 0), function()
			sendAction("trainProgrammer", row.id)
		end)
		row.fire = makeButton(buttons, "Despedir", THEME.red, UDim2.new(0.3, -3, 1, 0), function()
			if os.clock() < row.confirm then
				row.confirm = 0
				sendAction("fireProgrammer", row.id)
			else
				row.confirm = os.clock() + 3
				row.fire.Text = "¿Seguro?"
			end
		end)
		return row
	end, function(row, p)
		local rarity = Career.RarityById[p.rarity]
		row.title.Text = string.format("👩‍💻 %s · %s · Nv %d/%d", p.name, rarity.name, p.level, Career.PROGRAMMER_MAX_LEVEL)
		row.info.Text = string.format("%s · +%.1f%% dinero · +%s trabajo/s (x1.5 en webs de su nicho)", nicheLabel(p.niche), p.bonus * 100, num(p.work))
		if p.level >= Career.PROGRAMMER_MAX_LEVEL then
			setButton(row.train, "Nivel máximo", false)
		else
			setButton(row.train, "📚 Entrenar · " .. fmt(p.trainCost), s.money >= p.trainCost)
		end
		if os.clock() >= row.confirm then
			setButton(row.fire, "Despedir", true, THEME.red)
		end
	end)
end
end

---------------------------------------------------------------------
-- Pestaña MISIONES (diarias + objetivos que se reclaman)
---------------------------------------------------------------------
do
local missionsPage = pages.missions

local dailyHeader = makeCard(missionsPage, 66, 1, Color3.fromRGB(66, 52, 12))
local dailyTitle = makeLabel(dailyHeader, "📅 Misiones diarias", 0, 22, 18, THEME.text, true)
local dailyBonus = makeLabel(dailyHeader, "", 24, 18, 14, THEME.yellow, true)

local TIER_COLORS = { THEME.green, THEME.accent, THEME.purple }
local dailyCards = {}
for i = 1, Config.DAILY_MISSION_COUNT do
	local card = makeCard(missionsPage, 96, 1 + i)
	local title = makeLabel(card, "", 0, 20, 16, THEME.text, true)
	local _back, fill, text = makeProgressBar(card, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 18), TIER_COLORS[i] or THEME.accent)
	local button = makeButton(card, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
		sendAction("claimDailyMission", i, nil, function(ok)
			if ok then
				pulseMoney()
			end
		end)
	end)
	button.Position = UDim2.fromOffset(0, 46)
	dailyCards[i] = { card = card, title = title, fill = fill, text = text, button = button }
end

local goalsHeader = makeCard(missionsPage, 82, 10, Color3.fromRGB(30, 58, 138))
local goalsTitle = makeLabel(goalsHeader, "🏆 Objetivos", 0, 22, 18, THEME.text, true)
local tutorialButton = makeButton(goalsHeader, "📖 Ver el tutorial otra vez", THEME.card, UDim2.new(1, 0, 0, 30), function()
	window.Visible = false
	startTutorial()
end)
tutorialButton.Position = UDim2.fromOffset(0, 32)

local goalCards = {}
for _, goal in Config.Goals do
	local card = makeCard(missionsPage, 92, 100)
	local title = makeLabel(card, goal.text, 0, 20, 16, THEME.text, true)
	local _back, fill, text = makeProgressBar(card, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 16), THEME.yellow)
	local button = makeButton(card, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
		sendAction("claimGoal", goal.id, nil, function(ok)
			if ok then
				pulseMoney()
			end
		end)
	end)
	button.Position = UDim2.fromOffset(0, 44)
	goalCards[goal.id] = { card = card, title = title, fill = fill, text = text, button = button }
end

renderers.missions = function(s)
	local daily = s.dailyMissions
	dailyTitle.Text = "📅 Misiones diarias · nuevas en " .. Config.formatTime(daily.resetIn)
	dailyBonus.Text = if daily.bonusGiven then "🏆 ¡Bonus de hoy conseguido!"
		else "🎁 Completa las " .. Config.DAILY_MISSION_COUNT .. ": 🚀 Boost x2 " .. Config.DAILY_ALL_BONUS_BOOST_MINUTES .. " min"
	for i, slot in dailyCards do
		local mission = daily.list[i]
		slot.card.Visible = mission ~= nil
		if mission then
			local def = Config.DailyMissionById[mission.id]
			local tier = Config.DailyMissionRewards[mission.tier]
			slot.title.Text = string.format("%s · %s", tier.name, string.format(def.text, mission.target))
			slot.fill.Size = UDim2.fromScale(math.clamp(mission.progress / mission.target, 0, 1), 1)
			slot.text.Text = num(mission.progress) .. " / " .. num(mission.target)
			local amount = daily.rewards[mission.tier] or 0
			if mission.claimed then
				setButton(slot.button, "✓ Reclamada", false, THEME.green)
				slot.button:SetAttribute("PaintColor", THEME.green)
			elseif mission.progress >= mission.target then
				setButton(slot.button, "🎁 Reclamar " .. fmt(amount), true, THEME.green)
			else
				setButton(slot.button, "Premio: " .. fmt(amount), false)
			end
		end
	end

	local claimable, done = 0, 0
	for i, goal in Config.Goals do
		local slot = goalCards[goal.id]
		local claimed = s.goals[goal.id] == true
		local value = math.min(goal.value(s), goal.target)
		local complete = value >= goal.target
		local rewardText = if goal.reward > 0 then fmt(goal.reward) else "¡acciones!"
		slot.fill.Size = UDim2.fromScale(math.clamp(value / goal.target, 0, 1), 1)
		slot.text.Text = if goal.target >= 1000 then fmt(value) .. " / " .. fmt(goal.target) else num(value) .. " / " .. num(goal.target)
		if claimed then
			done += 1
			slot.card.LayoutOrder = 400 + i
			slot.title.TextColor3 = THEME.muted
			setButton(slot.button, "✓ Reclamado", false, THEME.green)
			slot.button:SetAttribute("PaintColor", THEME.green)
		elseif complete then
			claimable += 1
			slot.card.LayoutOrder = 100 + i
			slot.title.TextColor3 = THEME.yellow
			setButton(slot.button, "🎁 Reclamar " .. rewardText, true, THEME.green)
		else
			slot.card.LayoutOrder = 200 + i
			slot.title.TextColor3 = THEME.text
			setButton(slot.button, "Premio: " .. rewardText, false)
		end
	end
	goalsTitle.Text = string.format("🏆 Objetivos · %d/%d completados%s", done, #Config.Goals, if claimable > 0 then " · " .. claimable .. " por reclamar" else "")
end
end

---------------------------------------------------------------------
-- Pestaña BOLSA (prestigio, objetivos y estadísticas)
---------------------------------------------------------------------
do
local marketPage = pages.market
local ipoCard = makeCard(marketPage, 172, 1, Color3.fromRGB(80, 20, 54))
makeLabel(ipoCard, "📈 Salir a bolsa", 0, 22, 18, THEME.text, true)
local ipoInfo1 = makeLabel(ipoCard, "", 24, 18, 14, THEME.muted)
local ipoInfo2 = makeLabel(ipoCard, "", 44, 18, 15, THEME.green, true)
makeLabel(ipoCard, "Se reinicia: dinero, webs, empresas, apps y reputación.", 64, 18, 13, THEME.muted)
makeLabel(ipoCard, "Te quedas: acciones (+" .. math.floor(Config.SHARE_BONUS * 100) .. "% dinero cada una), objetivos y tu rascacielos.", 84, 18, 13, THEME.muted)
local confirmUntil = 0
local ipoButton: TextButton
ipoButton = makeButton(ipoCard, "", THEME.pink, UDim2.new(1, 0, 0, 38), function()
	if os.clock() < confirmUntil then
		confirmUntil = 0
		sendAction("ipo")
	else
		confirmUntil = os.clock() + 3
		ipoButton.Text = "¿Seguro? Pulsa otra vez para confirmar"
	end
end)
ipoButton.Position = UDim2.fromOffset(0, 112)

local statsCard = makeCard(marketPage, 120, 2)
makeLabel(statsCard, "📊 Estadísticas y guardado", 0, 22, 17, THEME.text, true)
local statsLabel = makeLabel(statsCard, "", 24, 18, 14, THEME.muted)
local saveLabel = makeLabel(statsCard, "", 44, 18, 13, THEME.muted)
local saveButton = makeButton(statsCard, "💾 Guardar ahora", THEME.accent, UDim2.new(1, 0, 0, 30), function()
	sendAction("saveNow")
end)
saveButton.Position = UDim2.fromOffset(0, 70)


renderers.market = function(s)
	ipoInfo1.Text = string.format("Ganado en esta partida: %s · Acciones: %d (x%.2f dinero)", fmt(s.totalEarned), s.shares, 1 + s.shares * Config.SHARE_BONUS)
	if s.ipoShares >= 1 then
		ipoInfo2.Text = "Si sales a bolsa ahora consigues +" .. s.ipoShares .. " acciones"
		if os.clock() >= confirmUntil then
			setButton(ipoButton, "📈 Salir a bolsa (+" .. s.ipoShares .. " acciones)", true)
		end
	else
		ipoInfo2.Text = "Necesitas ganar " .. fmt(Config.IPO_MIN_EARNED) .. " en esta partida"
		setButton(ipoButton, "Te faltan " .. fmt(Config.IPO_MIN_EARNED - s.totalEarned), false)
	end

	statsLabel.Text = string.format("Webs creadas %d · Vendidas %d · Clics %s (críticos %s) · Salidas a bolsa %d",
		s.stats.built, s.stats.sold, num(s.stats.clicks), num(s.stats.crits or 0), s.ipoCount)
	local saveText
	if not s.canSave then
		saveText = "⚠️ Guardado DESACTIVADO: publica el juego y activa «Enable Studio Access to API Services»"
	elseif s.lastSaveAgo < 0 then
		saveText = "💾 Se guarda solo cada " .. Config.AUTOSAVE_INTERVAL .. " s y al salir"
	else
		saveText = string.format("💾 Último guardado hace %s%s", Config.formatTime(s.lastSaveAgo), if s.lastSaveOk == false then " (falló, se reintentará)" else " ✓")
	end
	saveLabel.Text = "Ganado en total " .. fmt(s.lifetimeEarned) .. " · " .. saveText
	saveLabel.TextColor3 = if s.canSave then THEME.muted else THEME.red
end
end

---------------------------------------------------------------------
-- Pestaña TIENDA (regalos gratis, bonus y Robux)
---------------------------------------------------------------------
do
local shopPage = pages.shop

local giftCard = makeCard(shopPage, 78, 1, Color3.fromRGB(19, 78, 74))
makeLabel(giftCard, "🎁 Regalo gratis (cada " .. math.floor(Config.GIFT_INTERVAL / 60) .. " min jugando)", 0, 22, 17, THEME.text, true)
local giftButton = makeButton(giftCard, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
	sendAction("claimGift", nil, nil, function(ok)
		if ok then
			pulseMoney()
		end
	end)
end)
giftButton.Position = UDim2.fromOffset(0, 28)

local dailyCard = makeCard(shopPage, 78, 2, Color3.fromRGB(19, 78, 74))
local dailyTitle = makeLabel(dailyCard, "📅 Recompensa diaria", 0, 22, 17, THEME.text, true)
local dailyButton = makeButton(dailyCard, "", THEME.green, UDim2.new(1, 0, 0, 30), function()
	showDailyModal()
end)
dailyButton.Position = UDim2.fromOffset(0, 28)

local bonusCard = makeCard(shopPage, 124, 3)
makeLabel(bonusCard, "✨ Tus bonus de dinero", 0, 22, 17, THEME.text, true)
local bonusLabel = makeLabel(bonusCard, "", 24, 40, 14, THEME.muted)
bonusLabel.TextWrapped = true
bonusLabel.TextYAlignment = Enum.TextYAlignment.Top
bonusLabel.TextTruncate = Enum.TextTruncate.None
local inviteButton = makeButton(bonusCard, "👫 Invitar amigos (+10 % cada uno, hasta 4)", THEME.pink, UDim2.new(1, 0, 0, 30), function()
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and canInvite then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	else
		showToast("No se pueden enviar invitaciones ahora mismo", "error")
	end
end)
inviteButton.Position = UDim2.fromOffset(0, 70)

local robuxItems = {}
for _, pass in Config.Monetization.GamePasses do
	if pass.id ~= 0 then
		table.insert(robuxItems, { kind = "pass", def = pass })
	end
end
for _, product in Config.Monetization.Products do
	if product.id ~= 0 then
		table.insert(robuxItems, { kind = "product", def = product })
	end
end

local robuxTitle = makeCard(shopPage, 40, 4, Color3.fromRGB(76, 29, 149))
makeLabel(robuxTitle, "💎 Tienda (Robux)", 0, 20, 17, THEME.text, true)
robuxTitle.Visible = #robuxItems > 0 or RunService:IsStudio()

if #robuxItems == 0 and RunService:IsStudio() then
	local info = makeCard(shopPage, 70, 5)
	local label = makeLabel(info, "Solo lo ves tú en Studio: crea Game Passes y Developer Products en el Creator Hub y pon sus IDs en TycoonConfig → Monetization para activar la tienda.", 0, 50, 14, THEME.muted)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
end

local prices: { [number]: number } = {}
local robuxRows = {}
for i, item in robuxItems do
	local def = item.def
	local card = makeCard(shopPage, 92, 10 + i, Color3.fromRGB(46, 16, 101))
	makeLabel(card, def.emoji .. " " .. def.name .. (if item.kind == "pass" then "  ·  para siempre" else ""), 0, 22, 17, THEME.text, true)
	local desc = makeLabel(card, def.desc, 24, 18, 14, THEME.muted)
	if def.random then
		desc.Text = def.desc .. " Probabilidades: " .. oddsText("premium")
	end
	local button = makeButton(card, "Comprar", THEME.purple, UDim2.new(1, 0, 0, 30), function()
		if item.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, def.id)
		else
			MarketplaceService:PromptProductPurchase(player, def.id)
		end
	end)
	button.Position = UDim2.fromOffset(0, 46)
	table.insert(robuxRows, { item = item, button = button, desc = desc, card = card })

	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(def.id, if item.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			prices[def.id] = info.PriceInRobux
		end
	end)
end

renderers.shop = function(s)
	if s.giftLeft <= 0 then
		setButton(giftButton, "🎁 ¡Recoger " .. fmt(s.giftAmount) .. "!", true, THEME.green)
	else
		setButton(giftButton, "Próximo regalo en " .. Config.formatTime(s.giftLeft), false)
	end
	dailyTitle.Text = "📅 Recompensa diaria · día " .. s.dailyDay .. " de 7"
	if s.dailyAvailable then
		setButton(dailyButton, "📅 ¡Recoger " .. fmt(s.dailyAmount) .. "!", true, THEME.green)
	else
		setButton(dailyButton, "Ya la has recogido. ¡Vuelve mañana!", false)
	end

	local b = s.bonuses
	local parts = {}
	table.insert(parts, string.format("📈 Acciones x%.2f", 1 + s.shares * Config.SHARE_BONUS))
	if b.pass then
		table.insert(parts, "💎 Pase x2")
	end
	if b.boost then
		table.insert(parts, "🚀 Boost x2 (" .. Config.formatTime(s.boostLeft) .. ")")
	end
	table.insert(parts, "👫 Amigos: " .. b.friends .. " (+" .. math.floor(math.min(b.friends, Config.Monetization.MAX_FRIENDS) * Config.Monetization.FRIEND_BONUS * 100) .. "%)")
	if b.premium then
		table.insert(parts, "⭐ Premium +" .. math.floor(Config.Monetization.PREMIUM_BONUS * 100) .. "%")
	end
	if Config.Monetization.GROUP_ID ~= 0 then
		table.insert(parts, if b.group then "👥 Grupo +10%" else "👥 Únete al grupo: +10%")
	end
	bonusLabel.Text = table.concat(parts, " · ") .. string.format("\nTotal: x%.2f a todo tu dinero", s.moneyMult)

	for _, row in robuxRows do
		local def = row.item.def
		row.card.Visible = not (def.random and b.randomRestricted)
		local price = prices[def.id]
		local priceText = if price then " (R$ " .. price .. ")" else ""
		if row.item.kind == "pass" and b[def.key] then
			setButton(row.button, "✓ Ya lo tienes", false, THEME.green)
			row.button:SetAttribute("PaintColor", THEME.green)
		elseif row.item.kind == "product" and def.kind == "cash" then
			row.desc.Text = def.desc .. " Ahora: +" .. fmt(math.max(def.min, s.income * def.minutes * 60))
			setButton(row.button, "Comprar" .. priceText, true)
		elseif row.item.kind == "product" and def.kind == "finish" then
			setButton(row.button, if s.project then "Comprar" .. priceText else "Empieza una web primero", s.project ~= nil)
		else
			setButton(row.button, "Comprar" .. priceText, true)
		end
	end
end
end

---------------------------------------------------------------------
-- Clic de programar (botón de abajo, pestaña Crear y tecla F)
---------------------------------------------------------------------
function doClick()
	if not state then
		return
	end
	if not state.project then
		openTab("create")
		return
	end
	local power = state.clickPower
	pendingClickWork += power
	playSound("click")
	floatText(quickBar, "+" .. num(power), THEME.yellow, 28)
	sendAction("click", nil, nil, function(ok, _message, extra)
		if ok and type(extra) == "table" and extra.crit then
			pendingClickWork += (extra.power or power) - power
			playSound("crit")
			floatText(quickBar, "💥 ¡CRÍTICO! +" .. num(extra.power or power), THEME.orange, 36)
		end
	end)
end

---------------------------------------------------------------------
-- Marcador "TU IMPERIO" sobre tu parcela
---------------------------------------------------------------------
local plotMarker = create("BillboardGui", {
	Name = "TuImperio",
	Size = UDim2.fromOffset(240, 60),
	StudsOffset = Vector3.new(0, 22, 0),
	AlwaysOnTop = true,
	MaxDistance = 1000,
	Enabled = false,
	Parent = playerGui,
})
create("TextLabel", {
	Parent = plotMarker,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "⬇️ TU IMPERIO ⬇️",
	TextScaled = true,
	Font = Enum.Font.FredokaOne,
	TextColor3 = THEME.yellow,
	TextStrokeTransparency = 0,
})
local myPlotPart: BasePart? = nil

local function findMyPlot()
	local folder = Workspace:FindFirstChild("Parcelas")
	if not folder then
		return
	end
	for _, plot in folder:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local part = plot:FindFirstChildWhichIsA("BasePart")
			if part then
				myPlotPart = part
				plotMarker.Adornee = part
			end
			return
		end
	end
end

---------------------------------------------------------------------
-- Tutorial interactivo (sale a todos la primera vez)
---------------------------------------------------------------------
do
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
	if step.waitFor and state and step.waitFor(state) then
		showStep(index + 1)
		return
	end
	stepLabel.Text = string.format("TUTORIAL · PASO %d DE %d", index, #STEPS)
	titleLabel.Text = step.title
	bodyLabel.Text = step.body
	local last = index == #STEPS
	nextButton.Visible = step.waitFor == nil
	setButton(nextButton, if last then "🎉 ¡Empezar!" else "Siguiente ▶", true, THEME.green)
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

function startTutorial()
	running = true
	tutorialGui.Enabled = true
	showStep(1)
end

function tutorialOnState(s)
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

---------------------------------------------------------------------
-- Recibir estado del servidor
---------------------------------------------------------------------
local function renderAlways(s)
	-- Avisos del menú
	local canFulfill = 0
	for _, offer in s.offers do
		if bestSiteFor(s, offer) then
			canFulfill += 1
		end
	end
	setBadge("clients", canFulfill)

	local canCreate = false
	if not s.project and #s.sites < s.slots then
		for _, def in Config.WebTypes do
			if s.reputation >= def.rep and s.money >= def.cost then
				canCreate = true
			end
		end
	end
	setBadge("create", canCreate)

	local canBuy = false
	for _, def in Config.Companies do
		local level = s.companies[def.id] or 0
		if level < def.maxLevel and s.money >= Config.companyCost(def.id, level) then
			canBuy = true
		end
	end
	setBadge("companies", canBuy)

	local canUnlock = false
	for _, network in Config.AdNetworks do
		if not s.unlockedAds[network.id] and s.reputation >= network.rep and s.money >= network.cost then
			canUnlock = true
		end
	end
	setBadge("ads", canUnlock)
	setBadge("market", s.ipoShares >= 1)
	local c = s.career
	setBadge("career", (c.job ~= nil and c.job.taskLeft <= 0) or (c.job == nil and #c.jobOffers > 0))
	local agencyReady = false
	if c.agency then
		local space = #c.programmers < c.agency.capacity
		agencyReady = space and (s.money >= c.recruitCost or (c.tickets.legendary or 0) > 0 or ((c.tickets.premium or 0) > 0 and not s.bonuses.randomRestricted))
	else
		agencyReady = c.devLevel >= Career.AGENCY_LEVEL_REQUIRED and s.money >= Career.AGENCY_COST
	end
	setBadge("agency", agencyReady)
	saveBanner.Visible = not s.canSave
	setBadge("shop", s.giftLeft <= 0 or s.dailyAvailable)
	local claimable = 0
	for _, goal in Config.Goals do
		if not s.goals[goal.id] and goal.value(s) >= goal.target then
			claimable += 1
		end
	end
	for _, mission in s.dailyMissions.list do
		if not mission.claimed and mission.progress >= mission.target then
			claimable += 1
		end
	end
	setBadge("missions", claimable)

	-- Bonus activos
	chips.pass.Visible = s.bonuses.pass
	chips.pass.Text = "💎 x2"
	chips.boost.Visible = s.bonuses.boost
	chips.boost.Text = "🚀 x2 " .. Config.formatTime(s.boostLeft)
	chips.social.Visible = s.socialBonus > 0
	chips.social.Text = "👫 +" .. math.floor(s.socialBonus * 100 + 0.5) .. "%"
	chips.turbo.Visible = s.bonuses.turbo
	chips.turbo.Text = "⚡ Turbo"

	-- Evento
	if s.event then
		eventLabel.Visible = true
		eventLabel.Text = s.event.name .. "  (" .. Config.formatTime(s.event.timeLeft) .. ")"
	else
		eventLabel.Visible = false
	end

	-- Barra rápida
	if s.project then
		local def = Config.WebTypeById[s.project.type]
		quickTitle.Text = def.emoji .. " Programando " .. def.name .. (if s.autoType then "  · 🤖" else "") .. "  ·  tecla F"
		setButton(quickButton, "⌨️ PROGRAMAR", true, THEME.green)
	else
		quickFill.Size = UDim2.fromScale(0, 1)
		quickProgress.Text = ""
		if #s.sites >= s.slots then
			quickTitle.Text = "🌐 Sin huecos: vende una web o compra ☁️ Hosting"
		else
			quickTitle.Text = "¿Qué web vas a crear ahora?"
		end
		setButton(quickButton, "➕ Nueva web", true, THEME.accent)
	end

	renderMission(s)
	if not myPlotPart then
		findMyPlot()
	end
end

stateEvent.OnClientEvent:Connect(function(newState)
	local first = state == nil
	state = newState
	for _, site in newState.sites do
		local history = visitHistory[site.id] or {}
		table.insert(history, site.visits)
		if #history > HISTORY_SIZE then
			table.remove(history, 1)
		end
		visitHistory[site.id] = history
	end
	if detailSiteId and window.Visible then
		renderDetail(newState)
	end
	stateTime = os.clock()
	pendingClickWork = 0

	renderAlways(newState)
	if window.Visible and renderers[currentTab] then
		renderers[currentTab](newState)
	end
	tutorialOnState(newState)

	if first then
		muted = newState.settings and newState.settings.muted == true
		muteButton.Text = if muted then "🔇" else "🔊"
		if not newState.tutorialDone then
			task.delay(1.5, startTutorial)
		end
		task.delay(4, function()
			if not dailyShown and state and state.dailyAvailable and state.stats.built > 0 then
				dailyShown = true
				showDailyModal()
			end
		end)
	end
end)

-- Animación suave del dinero y de las barras de progreso
RunService.RenderStepped:Connect(function()
	if not state then
		return
	end
	local elapsed = math.min(os.clock() - stateTime, 1.5)
	moneyLabel.Text = "💰 " .. fmt(state.money + state.income * elapsed)
	incomeLabel.Text = string.format("+%s/s  ·  ⭐ %s  ·  📈 %d acciones", fmt(state.income), num(state.reputation), state.shares)

	local project = state.project
	if project then
		local progress = math.min(project.progress + pendingClickWork + state.workPerSec * elapsed, project.required)
		local ratio = progress / project.required
		quickFill.Size = UDim2.fromScale(ratio, 1)
		quickProgress.Text = num(progress) .. " / " .. num(project.required)
		if window.Visible and currentTab == "create" then
			progressFill.Size = UDim2.fromScale(ratio, 1)
			progressText.Text = quickProgress.Text
		end
	end

	-- El marcador solo se ve cuando estás lejos de tu parcela
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if myPlotPart and root and root:IsA("BasePart") then
		plotMarker.Enabled = (root.Position - myPlotPart.Position).Magnitude > 60
	end
end)

---------------------------------------------------------------------
-- Abrir y cerrar
---------------------------------------------------------------------
onTabChanged = function()
	if detailSiteId then
		detailSiteId = nil
		detail.Visible = false
	end
end

window:GetPropertyChangedSignal("Visible"):Connect(function()
	quickBar.Visible = not window.Visible
	missionCard.Visible = not window.Visible
	if window.Visible and state and renderers[currentTab] then
		renderers[currentTab](state)
	end
end)

openComputerEvent.OnClientEvent:Connect(function()
	openTab(currentTab)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		window.Visible = not window.Visible
	elseif input.KeyCode == Enum.KeyCode.F then
		doClick()
	end
end)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()
selectTab("create")
