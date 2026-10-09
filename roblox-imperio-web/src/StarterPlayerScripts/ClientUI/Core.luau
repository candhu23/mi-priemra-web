--[[
	Core (ModuleScript en StarterPlayerScripts > ClientUI)

	El núcleo de la interfaz: idioma, sonidos, piezas para crear interfaz
	(botones, tarjetas, barras...), pantallas, HUD, ventana con pestañas,
	avisos y ventanas emergentes. Devuelve la tabla "ui" que comparten
	todas las pestañas (ClientUI/Tab*.luau) y TycoonClient.

	En "ui" también viven las cosas que cambian o que define una pestaña y
	usan otras (ui.state, ui.lang, ui.nicheLabel, ui.doClick...).
	v4: sacado de TycoonClient sin cambiar lo que hace.
]]

local ui: any = {}
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
local Market = require(ReplicatedStorage:WaitForChild("MarketConfig"))
local Story = require(ReplicatedStorage:WaitForChild("StoryConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))
local StatePatch = require(ReplicatedStorage:WaitForChild("StatePatch"))
local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local actionFunction = remotes:WaitForChild("Action") :: RemoteFunction
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local openComputerEvent = remotes:WaitForChild("OpenComputer") :: RemoteEvent
local visitEvent = remotes:WaitForChild("Visit") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- Idioma: el de la cuenta de Roblox hasta que llega la partida guardada
-- (allí puede haber uno elegido a mano con el botón 🌐)
---------------------------------------------------------------------
ui.lang = Locale.resolve(nil, player.LocaleId)

-- T("texto") traduce un texto fijo; T("plantilla %s", x) además la rellena
local function T(text: string, ...: any): string
	if select("#", ...) > 0 then
		return Locale.f(ui.lang, text, ...)
	end
	return Locale.t(ui.lang, text)
end

-- Texto que ya llega rellenado (del servidor o de los carteles del mundo)
local function TR(text: string): string
	return Locale.translate(ui.lang, text)
end

-- Textos fijos que se calculan al crear la interfaz: se recalculan al
-- cambiar de idioma
local boundTexts: { { obj: any, fn: () -> string } } = {}
local function bindText(obj: any, fn: () -> string)
	obj.Text = fn()
	table.insert(boundTexts, { obj = obj, fn = fn })
end

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
	-- Sin id propio, el "ping" de Roblox con otro tono
	sound.SoundId = if def.id ~= "" then def.id else Config.SOUND_FALLBACK
	sound.PlaybackSpeed = if def.id ~= "" then 1 else def.fallbackSpeed
	sound.Volume = def.volume
	sound.Parent = soundFolder
	sounds[name] = sound
end

-- Volumen, música y botones de sonido (todo en una tabla: el cliente está
-- al límite de 200 variables locales)
local audio: any = {
	volume = 1, -- 0..1, se sincroniza con la partida guardada
	musicOn = true,
	music = {} :: { [string]: Sound }, -- una pista de día y otra de noche (si tienen id)
	checkAt = 0,
}
for name, def in Config.Music do
	if def.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Musica_" .. name
		sound.SoundId = def.id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = soundFolder
		audio.music[name] = sound
	end
end

local function playSound(name: string)
	local sound = sounds[name]
	local def = Config.Sounds[name]
	if sound and def and audio.volume > 0 then
		sound.Volume = def.volume * audio.volume
		sound.TimePosition = 0
		sound:Play()
	end
end

-- Pone la pista que toca (día o noche) y apaga la otra
function audio.updateMusic()
	local clock = game:GetService("Lighting").ClockTime
	local wanted = if clock >= 6.5 and clock < 18 then "day" else "night"
	for name, sound in audio.music do
		local target = if audio.musicOn and name == wanted then Config.Music[name].volume * audio.volume else 0
		if target > 0 and not sound.IsPlaying then
			sound:Play()
		end
		if math.abs(sound.Volume - target) > 0.001 then
			TweenService:Create(sound, TweenInfo.new(2), { Volume = target }):Play()
		end
		if target == 0 and sound.IsPlaying and sound.Volume < 0.01 then
			sound:Pause()
		end
	end
end

function audio.volumeIcon(v: number): string
	return if v <= 0 then "🔇" elseif v < 1 then "🔉" else "🔊"
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
	-- Los textos fijos se traducen solos (y se recuerdan para poder
	-- cambiar de idioma sin volver a entrar)
	local text = props.Text
	if type(text) == "string" and Locale.has(text) then
		instance:SetAttribute("SrcText", text)
		instance.Text = Locale.t(ui.lang, text)
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
	if ui.lang ~= "es" and Locale.has(text) then
		text = Locale.t(ui.lang, text)
	end
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
-- baseOrder: LayoutOrder de la primera fila menos 1 (por defecto 100)
local function syncRows(container: Instance, rows: { [any]: any }, items: { any }, keyOf: (any) -> any, build: (any) -> any, update: (any, any) -> (), baseOrder: number?)
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
		row.frame.LayoutOrder = (baseOrder or 100) + i
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
	if ui.resizeWindow then
		ui.resizeWindow(size)
	end
end

---------------------------------------------------------------------
-- Pantallas (ScreenGui separados para que las capas no se mezclen)
---------------------------------------------------------------------
local mainGui = create("ScreenGui", { Name = "ImperioWebUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1, Parent = playerGui })
local toastGui = create("ScreenGui", { Name = "ImperioWebToasts", ResetOnSpawn = false, DisplayOrder = 5, Parent = playerGui })
local modalGui = create("ScreenGui", { Name = "ImperioWebModal", ResetOnSpawn = false, DisplayOrder = 10, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })

ui.state = nil
local stateTime = os.clock()
ui.pendingClickWork = 0
local showToast: (text: string, kind: string?) -> ()

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
chip("weekend", 5, Color3.fromRGB(14, 165, 233))
chip("gold", 6, Color3.fromRGB(202, 138, 4))

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

-- v4 (móvil primero): la ventana del ordenador tiene su propia escala y no
-- baja del 85 % (así los botones miden ≥ 44 px en el móvil). Si la pantalla
-- es pequeña, la ventana se hace más baja/estrecha en vez de más pequeña.
local windowScale = create("UIScale", { Parent = window })
function ui.resizeWindow(size: Vector2)
	-- La barra de arriba de Roblox ocupa sitio (esta pantalla no la ignora)
	local insetY = 0
	local ok, topLeft = pcall(function()
		return (game:GetService("GuiService"):GetGuiInset())
	end)
	if ok and typeof(topLeft) == "Vector2" then
		insetY = topLeft.Y
	end
	local height = size.Y - insetY
	local scale = math.clamp(math.min(size.X / 920, height / 600), 0.85, 1.15)
	windowScale.Scale = scale
	window.Size = UDim2.fromOffset(math.min(880, (size.X - 16) / scale), math.min(560, (height - 16) / scale))
	window.Position = UDim2.fromScale(0.5, if height < 600 then 0.5 else 0.53)
end

local header = create("Frame", {
	Parent = window,
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, { corner(16), gradient(Color3.fromRGB(37, 99, 235), Color3.fromRGB(30, 64, 175)) })

local windowTitle = create("TextLabel", {
	Parent = header,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -270, 1, 0),
	Text = "🌐 Imperio Web",
	TextColor3 = THEME.text,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, { maxText(26) })

local closeButton = makeButton(header, "✕", THEME.red, UDim2.fromOffset(48, 42), function()
	window.Visible = false
end)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -8, 0.5, 0)

-- 🔊 → 🔉 → 🔇 (Config.VOLUME_STEPS)
ui.muteButton = makeButton(header, "🔊", THEME.card, UDim2.fromOffset(48, 42), function()
	local steps = Config.VOLUME_STEPS
	local nextVolume = steps[1]
	for i, v in steps do
		if math.abs(v - audio.volume) < 0.01 then
			nextVolume = steps[i % #steps + 1]
		end
	end
	audio.volume = nextVolume
	ui.muteButton.Text = audio.volumeIcon(audio.volume)
	sendAction("setVolume", audio.volume)
	audio.updateMusic()
end)
ui.muteButton.AnchorPoint = Vector2.new(1, 0.5)
ui.muteButton.Position = UDim2.new(1, -62, 0.5, 0)

-- 🎵 música sí / no
audio.button = makeButton(header, "🎵", THEME.green, UDim2.fromOffset(48, 42), function()
	audio.musicOn = not audio.musicOn
	setButton(audio.button, "🎵", true, if audio.musicOn then THEME.green else THEME.card)
	sendAction("setMusic", audio.musicOn)
	audio.updateMusic()
end)
audio.button.AnchorPoint = Vector2.new(1, 0.5)
audio.button.Position = UDim2.new(1, -202, 0.5, 0)

-- Botón de idioma (ES / EN). Se define abajo, cuando ya existe todo.
ui.applyLanguage = function() end
local languageButton = makeButton(header, "🌐 " .. string.upper(ui.lang), THEME.card, UDim2.fromOffset(80, 42), function()
	-- ES → EN → PT → ES
	local newLang = Locale.LANGS[1]
	for i, code in Locale.LANGS do
		if code == ui.lang then
			newLang = Locale.LANGS[i % #Locale.LANGS + 1]
		end
	end
	sendAction("setLanguage", newLang)
	ui.applyLanguage(newLang)
end)
languageButton.AnchorPoint = Vector2.new(1, 0.5)
languageButton.Position = UDim2.new(1, -116, 0.5, 0)

-- v4: 5 CENTROS con sub-pestañas (pensado primero para móvil: botones grandes,
-- nunca más de 5 por fila). Arriba los centros; debajo, las pestañas del centro.
local hubBar = create("Frame", {
	Parent = window,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, 56),
	Size = UDim2.new(1, -20, 0, 54),
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local subBar = create("Frame", {
	Parent = window,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, 116),
	Size = UDim2.new(1, -20, 0, 52),
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local content = create("Frame", {
	Parent = window,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, 176),
	Size = UDim2.new(1, -20, 1, -184),
})

local TABS = {
	{ id = "create", emoji = "🖥️", name = "Crear", color = THEME.green },
	{ id = "sites", emoji = "🌐", name = "Webs", color = THEME.accent },
	{ id = "clients", emoji = "🤝", name = "Clientes", color = THEME.yellow },
	{ id = "ads", emoji = "📢", name = "Anuncios", color = THEME.purple },
	{ id = "companies", emoji = "🏢", name = "Empresas", color = THEME.orange },
	{ id = "career", emoji = "💼", name = "Carrera", color = Color3.fromRGB(14, 165, 233) },
	{ id = "agency", emoji = "👥", name = "Agencia", color = Color3.fromRGB(217, 70, 239) },
	{ id = "story", emoji = "📖", name = "Historia", color = Color3.fromRGB(124, 58, 237) },
	{ id = "missions", emoji = "🎯", name = "Misiones", color = Color3.fromRGB(245, 158, 11) },
	{ id = "achievements", emoji = "🏅", name = "Logros", color = Color3.fromRGB(234, 88, 12) },
	{ id = "season", emoji = "🎫", name = "Pase", color = Color3.fromRGB(99, 102, 241) },
	{ id = "collection", emoji = "📖", name = "Colección", color = Color3.fromRGB(16, 185, 129) },
	{ id = "ranking", emoji = "🏆", name = "Ranking", color = Color3.fromRGB(234, 179, 8) },
	{ id = "market", emoji = "📈", name = "Bolsa", color = THEME.pink },
	{ id = "research", emoji = "💡", name = "I+D", color = Color3.fromRGB(59, 130, 246) },
	{ id = "ipo", emoji = "🔔", name = "Salir a bolsa", color = THEME.pink },
	{ id = "fusion", emoji = "🧬", name = "Fusión", color = Color3.fromRGB(34, 211, 238) },
	{ id = "shop", emoji = "🛒", name = "Tienda", color = Color3.fromRGB(20, 184, 166) },
}
local TabById: { [string]: any } = {}
for _, tab in TABS do
	TabById[tab.id] = tab
end

-- Los 5 centros y sus pestañas (en orden)
local HUBS = {
	{ id = "production", emoji = "🛠️", name = "Producción", color = THEME.green, tabs = { "create", "sites", "ads" } },
	{ id = "business", emoji = "💼", name = "Negocio", color = Color3.fromRGB(14, 165, 233), tabs = { "clients", "companies", "career", "agency" } },
	{ id = "investment", emoji = "📈", name = "Inversión", color = THEME.pink, tabs = { "market", "research", "ipo", "fusion" } },
	{ id = "progress", emoji = "🎯", name = "Progreso", color = Color3.fromRGB(245, 158, 11), tabs = { "story", "missions", "achievements", "season", "collection" } },
	{ id = "social", emoji = "🛒", name = "Tienda y social", color = Color3.fromRGB(20, 184, 166), tabs = { "shop", "ranking" } },
}
local hubOfTab: { [string]: any } = {}
for _, hub in HUBS do
	for _, id in hub.tabs do
		hubOfTab[id] = hub
	end
end

local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local hubButtons: { [string]: TextButton } = {}
local lastTabOfHub: { [string]: string } = {} -- al volver a un centro, la última pestaña vista
local renderers: { [string]: (any) -> () } = {}
ui.currentTab = "create"
ui.currentHub = "production"

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

ui.onTabChanged = function() end

-- Parte del juego que tiene que estar desbloqueada para abrir cada pestaña
local TAB_FEATURES = {
	clients = "clients", ads = "ads", ranking = "ranking", companies = "companies", season = "season",
	career = "career", collection = "collection", agency = "agency", market = "market", research = "market",
	ipo = "market", fusion = "market",
}

local function tabLocked(id: string): boolean
	local feature = TAB_FEATURES[id]
	return feature ~= nil and ui.state ~= nil and not Config.isUnlocked(ui.state, feature)
end

-- Un centro está cerrado si todas sus pestañas lo están
local function hubLocked(hub): boolean
	for _, id in hub.tabs do
		if not tabLocked(id) then
			return false
		end
	end
	return true
end

-- Título de la ventana: "🛠️ Producción · 🌐 Webs"
local windowTitleText: () -> string
function windowTitleText(): string
	local hub = hubOfTab[ui.currentTab]
	local tab = TabById[ui.currentTab]
	if not hub or not tab then
		return "🌐 " .. T("Imperio Web")
	end
	return hub.emoji .. " " .. T(hub.name) .. " · " .. tab.emoji .. " " .. T(tab.name)
end
function ui.updateTitle()
	windowTitle.Text = windowTitleText()
end

-- Texto y color de los botones (🔒 si aún no se ha desbloqueado). Solo se
-- ven las pestañas del centro actual, repartidas a lo ancho.
local function refreshTabButtons()
	for _, hub in HUBS do
		local button = hubButtons[hub.id]
		if hubLocked(hub) then
			setButton(button, "🔒 " .. T(hub.name), true, THEME.disabled)
		else
			setButton(button, hub.emoji .. " " .. T(hub.name), true, if hub.id == ui.currentHub then hub.color else THEME.card)
		end
	end
	local current = HUBS[1]
	for _, hub in HUBS do
		if hub.id == ui.currentHub then
			current = hub
		end
	end
	for _, tab in TABS do
		local button = tabButtons[tab.id]
		local hub = hubOfTab[tab.id]
		button.Visible = hub == current
		if hub == current then
			button.Size = UDim2.new(1 / #current.tabs, -6 + 6 / #current.tabs, 1, 0)
		end
		if tabLocked(tab.id) then
			setButton(button, "🔒 " .. T(tab.name), true, THEME.disabled)
		else
			setButton(button, tab.emoji .. " " .. T(tab.name), true, if tab.id == ui.currentTab then tab.color else THEME.card)
		end
	end
end

local function selectTab(id: string)
	if tabLocked(id) then
		showToast(T("🔒 Se desbloquea en la planta %d de tu rascacielos.", Config.unlockFloor(TAB_FEATURES[id])), "error")
		return
	end
	ui.currentTab = id
	local hub = hubOfTab[id]
	if hub then
		ui.currentHub = hub.id
		lastTabOfHub[hub.id] = id
	end
	ui.onTabChanged()
	for _, tab in TABS do
		pages[tab.id].Visible = tab.id == id
	end
	ui.updateTitle()
	refreshTabButtons()
	if ui.state and renderers[id] then
		renderers[id](ui.state)
	end
end

-- Abrir un centro: su última pestaña vista o la primera que esté abierta
local function selectHub(hubId: string)
	for _, hub in HUBS do
		if hub.id == hubId then
			if hubLocked(hub) then
				local floor = math.huge
				for _, id in hub.tabs do
					floor = math.min(floor, Config.unlockFloor(TAB_FEATURES[id] or ""))
				end
				showToast(T("🔒 Se desbloquea en la planta %d de tu rascacielos.", floor), "error")
				return
			end
			local wanted = lastTabOfHub[hub.id]
			if not wanted or tabLocked(wanted) then
				wanted = hub.tabs[1]
				for _, id in hub.tabs do
					if not tabLocked(id) then
						wanted = id
						break
					end
				end
			end
			selectTab(wanted)
		end
	end
end

for i, hub in HUBS do
	local button = makeButton(hubBar, hub.emoji .. " " .. T(hub.name), THEME.card, UDim2.new(1 / #HUBS, -6 + 6 / #HUBS, 1, 0), function()
		selectHub(hub.id)
	end)
	button.LayoutOrder = i
	hubButtons[hub.id] = button
end
for i, tab in TABS do
	local button = makeButton(subBar, tab.emoji .. " " .. T(tab.name), THEME.card, UDim2.new(0.25, -6, 1, 0), function()
		selectTab(tab.id)
	end)
	button.LayoutOrder = i
	tabButtons[tab.id] = button
	makePage(tab.id)
end

local function openTab(id: string)
	window.Visible = true
	selectTab(id)
end


-- Para qué sirve cada pestaña (una línea arriba del todo)
local TAB_HELP = {
	create = "Elige una web y pulsa PROGRAMAR (o la tecla F). Al terminarla empieza a ganar dinero sola con sus visitas.",
	sites = "Tus webs ganan dinero cada segundo con sus visitas. Sube el SEO o rediséñalas para tener más. Toca una para ver su ficha.",
	clients = "Empresas que quieren comprarte webs: cobras mucho de golpe y un mantenimiento para siempre, pero la web deja de ser tuya.",
	ads = "Cada app paga distinto por visita. Más anuncios = más dinero por visita, pero menos visitas.",
	companies = "Negocios que compras y te ayudan para siempre. Cada uno dice qué hace ahora y qué hará al subirlo.",
	career = "Las empresas te encargan webs con un plazo. Acepta, pulsa «Programar ahora» y al terminar se entrega sola: pagan mucho más que una venta.",
	agency = "Tus programadores trabajan solos. Cada uno mejora algo según su especialidad y su rasgo, y sube de nivel con el tiempo.",
	missions = "6 misiones diarias, 6 semanales (más difíciles) y objetivos con premio.",
	achievements = "Cada nivel de un logro da un bonus PARA SIEMPRE (no se pierde ni al salir a bolsa).",
	season = "Todo lo que haces da ⭐ del pase. Cada nivel tiene premio.",
	collection = "Cada combinación de web y rareza que consigas da +1 % de dinero para siempre.",
	ranking = "Los mejores del servidor y de la semana. Visita imperios y da me gusta: ganáis los dos.",
	market = "Compra acciones baratas y véndelas caras. Los precios cambian cada 30 s. Abajo puedes salir a bolsa con tu imperio.",
	research = "Mejoras para siempre que se pagan con 💡 patentes (salir a bolsa y el pase).",
	shop = "Premios gratis por jugar, códigos y mejoras con Robux.",
	ipo = "Empiezas de cero, pero cada acción te da más dinero para siempre y patentes para 💡 I+D.",
	story = "Ada te guía paso a paso: cada misión cumplida da premio y cada capítulo, un premio especial.",
	fusion = "La Fusión te lleva a la era siguiente: webs nuevas y 🧬 Legado para mejoras que no se pierden nunca.",
}
for id, text in TAB_HELP do
	local help = create("TextLabel", {
		Parent = pages[id],
		LayoutOrder = -100,
		BackgroundColor3 = THEME.bg,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "ℹ️ " .. text,
		TextColor3 = THEME.muted,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { corner(8), padding(6) })
	help.Name = "Ayuda"
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
		openTab(ui.currentTab)
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
local hubBadges: { [string]: TextLabel } = {}
local badgeValues: { [string]: number } = {}
for _, hub in HUBS do
	hubBadges[hub.id] = create("TextLabel", {
		Parent = hubButtons[hub.id],
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = THEME.red,
		Text = "!",
		TextColor3 = THEME.text,
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		Visible = false,
		ZIndex = 3,
	}, { corner(12), stroke(THEME.text, 1.5) })
end
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
	if tabLocked(id) then
		count, value = 0, 0
	end
	badgeValues[id] = count
	badge.Visible = count > 0
	badge.Text = if type(value) == "number" then (if value > 9 then "9+" else tostring(value)) else "!"
	-- Cada centro y el botón del ordenador suman los avisos de sus pestañas
	for _, hub in HUBS do
		local sum = 0
		for _, tabId in hub.tabs do
			sum += badgeValues[tabId] or 0
		end
		hubBadges[hub.id].Visible = sum > 0
		hubBadges[hub.id].Text = if sum > 9 then "9+" else tostring(sum)
	end
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
	blog = "Consigue ⭐ 6 de reputación y crea un Blog",
	sell_1 = "Abre 🤝 Clientes y vende una web",
	company_1 = "Abre 🏢 Empresas y funda el Equipo de Programadores",
	network_2 = "Abre 📢 Anuncios y desbloquea ClickBoom",
	tienda = "Llega a ⭐ 59 vendiendo y creando webs",
	sites_5 = "Compra ☁️ Hosting para tener más huecos",
	seo_5 = "En 🌐 Webs mejora el SEO de tu mejor web",
	ipo_1 = "Abre 📈 Bolsa cuando ganes $1M",
	contract_1 = "Abre 💼 Carrera, acepta un encargo y pulsa «Programar ahora»",
	dev_8 = "Programa webs y entrega encargos para subir de nivel",
	agency = "Abre 👥 Agencia y fúndala",
	senior = "Entrega encargos y sube tu nivel de programador",
	epic = "Entrevista programadores en 👥 Agencia",
	team_10 = "Amplía la oficina y ficha más programadores",
	cto = "Sigue entregando encargos para subir de rango",
	rare_1 = "Programa webs: a veces salen ✨ raras",
	research_1 = "Abre 💡 I+D y gasta tus patentes",
	collection_20 = "Mira 📖 Colección: cada web rara nueva cuenta",
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
local missionTitle = makeLabel(missionCard, "🎯 MISIÓN", 0, 18, 15, THEME.yellow, true)
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
	-- Con la historia en marcha, la tarjeta lleva a 📖 Historia
	local story = ui.state and ui.state.story
	openTab(if story and not story.done then "story" else "missions")
end)

local function currentGoal(s)
	for _, goal in Config.Goals do
		if not s.goals[goal.id] then
			return goal
		end
	end
	return nil
end

-- Objetivos que necesitan una parte del juego desbloqueada
local GOAL_FEATURES = {
	sell_1 = "clients", network_2 = "ads", company_1 = "companies", contract_1 = "career", dev_8 = "career",
	agency = "agency", senior = "career", epic = "agency", companies_25 = "companies", ipo_1 = "market",
	research_1 = "market", team_10 = "agency", cto = "career", sell_100 = "clients", sell_10 = "clients",
	collection_20 = "collection", ipo_5 = "market",
}

-- v4: mientras dura el Modo Historia, la tarjeta enseña su misión
local function renderStoryMission(s): boolean
	local story = s.story
	local mission, chapter = Story.current(story)
	if not story or not mission or not chapter then
		missionTitle.Text = T("🎯 MISIÓN")
		return false
	end
	missionTitle.Text = T("📖 HISTORIA · %s %s", chapter.emoji, T(chapter.name))
	missionText.Text = T(mission.text)
	local target = math.max(story.target or 1, 1)
	local value = math.min(story.progress or 0, target)
	missionFill.Size = UDim2.fromScale(math.clamp(value / target, 0, 1), 1)
	missionProgress.Text = if target >= 1000 then fmt(value) .. " / " .. fmt(target) else num(value) .. " / " .. num(target)
	missionReward.Text = T("🎁 Premio: %s", fmt(story.reward or 0))
	missionHint.Text = T(mission.hint)
	if mission.feature and not Config.isUnlocked(s, mission.feature) then
		missionHint.Text = T("🔒 Se desbloquea en la planta %d de tu rascacielos.", Config.unlockFloor(mission.feature))
	end
	return true
end

local function renderMission(s)
	if renderStoryMission(s) then
		return
	end
	local goal = currentGoal(s)
	if not goal then
		missionText.Text = T("¡Has completado todos los objetivos! 👑")
		missionFill.Size = UDim2.fromScale(1, 1)
		missionProgress.Text = ""
		missionReward.Text = ""
		missionHint.Text = T("Sigue saliendo a bolsa para ser el número 1")
		return
	end
	local value = math.min(goal.value(s), goal.target)
	missionText.Text = T(goal.text)
	missionFill.Size = UDim2.fromScale(math.clamp(value / goal.target, 0, 1), 1)
	missionProgress.Text = if goal.target >= 1000 then fmt(value) .. " / " .. fmt(goal.target) else num(value) .. " / " .. num(goal.target)
	if value >= goal.target then
		missionReward.Text = T("✅ ¡Completado! Toca aquí para reclamarlo")
		missionHint.Text = T("Se reclama en 🎯 Misiones")
	else
		missionReward.Text = if goal.reward > 0 then T("🎁 Premio: %s", fmt(goal.reward)) else T("🎁 Premio: ¡acciones!")
		missionHint.Text = T(HINTS[goal.id] or "Toca aquí para ver todas las misiones")
		-- Si la pestaña que hace falta aún está cerrada, se dice cuándo se abre
		local feature = GOAL_FEATURES[goal.id]
		if feature and not Config.isUnlocked(s, feature) then
			missionHint.Text = T("🔒 Se desbloquea en la planta %d de tu rascacielos.", Config.unlockFloor(feature))
		end
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
	ui.doClick()
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
	rare = Color3.fromRGB(219, 39, 119),
	story = Color3.fromRGB(124, 58, 237), -- Ada (Modo Historia)
}
local toastOrder = 0

function showToast(text: string, kind: string?)
	text = TR(text)
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

	if kind == "rare" then
		-- Web rara: aviso más grande y con sonido especial
		toast.Size = UDim2.new(1, 0, 0, 58)
		playSound("rare")
	elseif kind == "goal" then
		playSound(if string.find(text, "🔓", 1, true) then "unlock" else "levelUp")
	elseif kind == "money" then
		playSound("money")
	elseif kind == "event" or kind == "success" or kind == "story" then
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

-- Botón "Cancelar" (solo en las ventanas de confirmación)
local modalCancel = makeButton(modalCard, "Cancelar", THEME.card, UDim2.new(0.5, -5, 0, 50), function()
	closeModal()
end)
modalCancel.AnchorPoint = Vector2.new(0, 1)
modalCancel.Position = UDim2.fromScale(0, 1)
modalCancel.Visible = false

-- cancelText: si se da, hay dos botones (Cancelar a la izquierda)
local function showModal(title: string, body: string, buttonText: string, onButton: (() -> ())?, extraBuilder: ((Frame) -> ())?, cancelText: string?, buttonColor: Color3?)
	local function open()
		modalOpen = true
		modalTitle.Text = TR(title)
		modalBody.Text = TR(body)
		modalBody.Visible = extraBuilder == nil
		modalExtra:ClearAllChildren()
		modalExtra.Visible = extraBuilder ~= nil
		if extraBuilder then
			extraBuilder(modalExtra)
		end
		setButton(modalButton, TR(buttonText), true, buttonColor or THEME.green)
		modalCancel.Visible = cancelText ~= nil
		if cancelText then
			setButton(modalCancel, TR(cancelText), true, THEME.card)
			modalButton.Size = UDim2.new(0.5, -5, 0, 50)
			modalButton.Position = UDim2.new(0.5, 5, 1, 0)
		else
			modalButton.Size = UDim2.new(1, 0, 0, 50)
			modalButton.Position = UDim2.fromScale(0, 1)
		end
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

-- Ventana de "¿Seguro?" con Cancelar / Confirmar
local function showConfirm(title: string, body: string, confirmText: string, color: Color3, onConfirm: () -> ())
	showModal(title, body, confirmText, onConfirm, nil, "Cancelar", color)
end

showSaveHelp = function()
	showModal("💾 Cómo activar el guardado", "Roblox solo guarda partidas en juegos PUBLICADOS:\n\n1. En Studio: File → Publish to Roblox.\n2. Home → Game Settings → Security → activa «Enable Studio Access to API Services» → Save.\n3. Para la partida (Stop) y vuelve a darle a Play.\n\nEn el juego publicado (jugando desde la web o la app) se guarda siempre.", "Entendido", nil, nil)
end

-- Fin de capítulo (TycoonClient lo cambia para añadir la vuelta de cámara)
ui.onChapter = function(title: string, body: string)
	playSound("levelUp")
	showModal(title, body, "¡A por el siguiente!", nil, nil)
end

notifyEvent.OnClientEvent:Connect(function(text: string, kind: string, body: string?)
	if kind == "popup" then
		if string.find(text, "🔓", 1, true) then
			playSound("unlock")
		end
		showModal(text, body or "", "¡Genial!", nil, nil)
	elseif kind == "chapter" then
		-- Fin de un capítulo de la historia: vuelta de cámara y ventana
		ui.onChapter(text, body or "")
	else
		showToast(text, kind)
	end
end)

-- Recompensa diaria: 7 casillas
ui.dailyShown = false
local function showDailyModal()
	if not ui.state or not ui.state.dailyAvailable then
		return
	end
	local day = ui.state.dailyDay
	showModal("📅 Recompensa diaria", "", T("Recoger %s", fmt(ui.state.dailyAmount)), function()
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
				Text = T("Día %d", i),
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
local visitHistory: { [number]: { number } } = {} -- historial de visitas por web
local HISTORY_SIZE = 40
ui.detailSiteId = nil
local tutorialTargets: { [string]: GuiObject } = {} -- botones que resalta el tutorial
ui.tutorialOnState = function() end
ui.renderHudExtras = function() end -- evento del servidor, meta común, combo
ui.showCombo = function() end

-- Etiqueta de web rara ("✨ Brillante ") y su color
local function variantTag(variantId: string?): (string, Color3?)
	local variant = variantId and Config.VariantById[variantId]
	if not variant then
		return "", nil
	end
	return variant.emoji .. " " .. T(variant.name) .. " · ", variant.color
end

-- Todo lo de arriba, para las pestañas
ui.Players = Players
ui.ReplicatedStorage = ReplicatedStorage
ui.RunService = RunService
ui.TweenService = TweenService
ui.UserInputService = UserInputService
ui.MarketplaceService = MarketplaceService
ui.SocialService = SocialService
ui.SoundService = SoundService
ui.Workspace = Workspace
ui.Config = Config
ui.Career = Career
ui.Market = Market
ui.Story = Story
ui.Locale = Locale
ui.StatePatch = StatePatch
ui.remotes = remotes
ui.actionFunction = actionFunction
ui.stateEvent = stateEvent
ui.notifyEvent = notifyEvent
ui.openComputerEvent = openComputerEvent
ui.visitEvent = visitEvent
ui.player = player
ui.playerGui = playerGui
ui.T = T
ui.TR = TR
ui.boundTexts = boundTexts
ui.bindText = bindText
ui.THEME = THEME
ui.fmt = fmt
ui.num = num
ui.soundFolder = soundFolder
ui.sounds = sounds
ui.audio = audio
ui.playSound = playSound
ui.create = create
ui.corner = corner
ui.stroke = stroke
ui.gradient = gradient
ui.shade = shade
ui.padding = padding
ui.maxText = maxText
ui.lighten = lighten
ui.darken = darken
ui.makeLabel = makeLabel
ui.makeButton = makeButton
ui.setButton = setButton
ui.makeCard = makeCard
ui.makeButtonRow = makeButtonRow
ui.makeProgressBar = makeProgressBar
ui.syncRows = syncRows
ui.scaledObjects = scaledObjects
ui.autoScale = autoScale
ui.updateScale = updateScale
ui.mainGui = mainGui
ui.toastGui = toastGui
ui.modalGui = modalGui
ui.stateTime = stateTime
ui.showToast = showToast
ui.sendAction = sendAction
ui.hud = hud
ui.moneyPill = moneyPill
ui.moneyScale = moneyScale
ui.moneyLabel = moneyLabel
ui.incomeLabel = incomeLabel
ui.chipsRow = chipsRow
ui.chips = chips
ui.chip = chip
ui.eventLabel = eventLabel
ui.saveBanner = saveBanner
ui.showSaveHelp = showSaveHelp
ui.window = window
ui.header = header
ui.windowTitle = windowTitle
ui.closeButton = closeButton
ui.languageButton = languageButton
ui.hubBar = hubBar
ui.subBar = subBar
ui.HUBS = HUBS
ui.hubOfTab = hubOfTab
ui.TabById = TabById
ui.hubButtons = hubButtons
ui.selectHub = selectHub
ui.hubLocked = hubLocked
ui.content = content
ui.TABS = TABS
ui.pages = pages
ui.tabButtons = tabButtons
ui.renderers = renderers
ui.makePage = makePage
ui.TAB_FEATURES = TAB_FEATURES
ui.tabLocked = tabLocked
ui.refreshTabButtons = refreshTabButtons
ui.selectTab = selectTab
ui.openTab = openTab
ui.TAB_HELP = TAB_HELP
ui.computerHolder = computerHolder
ui.computerButton = computerButton
ui.computerBadge = computerBadge
ui.tabBadges = tabBadges
ui.badgeValues = badgeValues
ui.setBadge = setBadge
ui.HINTS = HINTS
ui.missionCard = missionCard
ui.missionText = missionText
ui._missionBack = _missionBack
ui.missionFill = missionFill
ui.missionProgress = missionProgress
ui.missionReward = missionReward
ui.missionHint = missionHint
ui.currentGoal = currentGoal
ui.GOAL_FEATURES = GOAL_FEATURES
ui.renderMission = renderMission
ui.quickBar = quickBar
ui.quickTitle = quickTitle
ui._quickBack = _quickBack
ui.quickFill = quickFill
ui.quickProgress = quickProgress
ui.quickButton = quickButton
ui.toastContainer = toastContainer
ui.TOAST_COLORS = TOAST_COLORS
ui.toastOrder = toastOrder
ui.floatText = floatText
ui.pulseMoney = pulseMoney
ui.modalQueue = modalQueue
ui.modalOpen = modalOpen
ui.overlay = overlay
ui.modalCard = modalCard
ui.modalTitle = modalTitle
ui.modalBody = modalBody
ui.modalExtra = modalExtra
ui.modalAction = modalAction
ui.modalButton = modalButton
ui.closeModal = closeModal
ui.modalCancel = modalCancel
ui.showModal = showModal
ui.showConfirm = showConfirm
ui.showDailyModal = showDailyModal
ui.visitHistory = visitHistory
ui.HISTORY_SIZE = HISTORY_SIZE
ui.tutorialTargets = tutorialTargets
ui.variantTag = variantTag

return ui
