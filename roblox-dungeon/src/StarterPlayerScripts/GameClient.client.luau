--[[
	GameClient (LocalScript en StarterPlayer > StarterPlayerScripts)

	Toda la interfaz de Dungeon Ascend (estilo medieval: madera y oro):
	  · lobby: Coronas, botón JUGAR, menú lateral y ventana con pestañas
	    (Jugar, Clases, Árbol de mejoras, Armas, Mochila, Forja, Tienda,
	    Diario, Ajustes)
	  · partida: oleada, reloj, nivel y XP del equipo, vida, Coronas, armas
	    con su icono, barra del jefe, aviso del portal, botón de esquivar,
	    cartas para elegir mejora (con cambio/reroll), pantalla al caer y
	    resumen final
	  · tutorial, avisos y ventanas emergentes
	La horda y los efectos los dibuja SwarmView. El servidor decide todo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Ambience = require(ReplicatedStorage:WaitForChild("Ambience"))
local Icons = require(ReplicatedStorage:WaitForChild("Icons"))
local SwarmView = require(script.Parent:WaitForChild("SwarmView"))
local remotes = ReplicatedStorage:WaitForChild("DungeonRemotes")
local actionFunction = remotes:WaitForChild("Action") :: RemoteFunction
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local swarmEvent = remotes:WaitForChild("Swarm") :: RemoteEvent
local openMenuEvent = remotes:WaitForChild("OpenMenu") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Sin herramientas en este juego: ocultamos la barra de la mochila de Roblox
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- Colores medievales: madera oscura, pergamino y oro
local THEME = {
	bg = Color3.fromRGB(28, 19, 12),
	panel = Color3.fromRGB(56, 37, 23),
	card = Color3.fromRGB(84, 58, 36),
	stroke = Color3.fromRGB(150, 110, 58),
	accent = Color3.fromRGB(165, 42, 42),
	green = Color3.fromRGB(46, 160, 67),
	yellow = Color3.fromRGB(234, 179, 8),
	gold = Color3.fromRGB(251, 191, 36),
	red = Color3.fromRGB(220, 38, 38),
	blue = Color3.fromRGB(37, 99, 235),
	orange = Color3.fromRGB(217, 119, 6),
	purple = Color3.fromRGB(147, 51, 234),
	text = Color3.fromRGB(255, 248, 235),
	muted = Color3.fromRGB(214, 190, 150),
	disabled = Color3.fromRGB(92, 80, 68),
}
local TITLE_FONT = Enum.Font.GrenzeGotisch -- letra gótica para títulos grandes
local SLOT_EMOJI = { weapon = "⚔️", armor = "🛡️", amulet = "📿" }
local num = Config.formatNumber

-- Sonidos
---------------------------------------------------------------------
local soundFolder = Instance.new("Folder")
soundFolder.Name = "DungeonSounds"
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
-- TEXTO. Para objetos con texto usamos un degradado gris y el color va en
-- BackgroundColor3: así el texto sigue siendo blanco.
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

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3?, bold: boolean?): TextLabel
	return create("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = text,
		TextSize = textSize,
		TextColor3 = color or THEME.text,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
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
		playSound("click")
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

local function makeBar(parent: Instance, position: UDim2, size: UDim2, color: Color3): (Frame, Frame, TextLabel)
	local back = create("Frame", {
		Parent = parent,
		Position = position,
		Size = size,
		BackgroundColor3 = THEME.bg,
	}, { corner(7), stroke(THEME.stroke, 1) })
	local fill = create("Frame", {
		Parent = back,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(7), gradient(lighten(color, 0.2), darken(color, 0.15)) })
	local text = create("TextLabel", {
		Parent = back,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = THEME.text,
		TextStrokeTransparency = 0.5,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		ZIndex = 2,
	}, { maxText(14), padding(2) })
	return back, fill, text
end

local function scrollList(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local list = create("ScrollingFrame", {
		Parent = parent,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = THEME.stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	create("UIListLayout", { Parent = list, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return list
end

local function clearChildren(parent: Instance, keepClass: string?)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") and (not keepClass or not child:IsA(keepClass)) then
			child:Destroy()
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

-- Coloca un icono dibujado (ver Icons) dentro de un objeto
local function icon(parent: Instance, name: string, px: number, position: UDim2?, opts: any?): Frame
	local frame = Icons.make(name, px, opts)
	frame.Position = position or UDim2.new()
	frame.Parent = parent
	return frame
end

-- Etiqueta con icono delante (p. ej. moneda + cantidad)
local function iconLabel(parent: Instance, iconName: string, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3?): TextLabel
	local holder = create("Frame", { Parent = parent, Position = position, Size = size, BackgroundTransparency = 1 })
	local h = size.Y.Offset
	icon(holder, iconName, h, UDim2.new())
	local text_ = label(holder, text, UDim2.fromOffset(h + 6, 0), UDim2.new(1, -(h + 6), 1, 0), textSize, color, true)
	text_.TextStrokeTransparency = 0.6
	return text_
end

-- Coloca un icono a la izquierda de un botón (el texto se aparta)
local function buttonIcon(button: TextButton, name: string, px: number)
	local pad = button:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingLeft = UDim.new(0, px + 8)
	end
	-- El UIPadding también mueve a los hijos: se compensa con posición negativa
	local frame = icon(button, name, px, UDim2.new(0, -(px + 4), 0.5, 0))
	frame.AnchorPoint = Vector2.new(0, 0.5)
end

local function rarityOf(item: any): any
	return Config.RarityById[item.rarity]
end

local function itemName(item: any): string
	return Config.Items[item.def].name .. (if item.up > 0 then " +" .. item.up else "")
end

---------------------------------------------------------------------
-- Pantallas (ScreenGui separados para que las capas no se mezclen)
---------------------------------------------------------------------
local mainGui = create("ScreenGui", { Name = "DungeonUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1, Parent = playerGui })
local toastGui = create("ScreenGui", { Name = "DungeonToasts", ResetOnSpawn = false, DisplayOrder = 5, Parent = playerGui })
local modalGui = create("ScreenGui", { Name = "DungeonModal", ResetOnSpawn = false, DisplayOrder = 10, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
local flashGui = create("ScreenGui", { Name = "DungeonFlash", ResetOnSpawn = false, DisplayOrder = 0, IgnoreGuiInset = true, Parent = playerGui })

local state: any = nil
local selectedMap = 1
local selectedDifficulty = 1
local lastHealth = 0
local dashReadyAt = 0

-- Variables compartidas entre bloques (se asignan más abajo)
local showToast: (text: string, kind: string?) -> ()
local showPopup: (title: string, body: string) -> ()
local openWindow: (tab: string) -> ()
local refreshWindow: () -> ()
local dash: () -> ()

local function sendAction(action: string, a: any?, b: any?, onResult: ((boolean, string?, any) -> ())?)
	task.spawn(function()
		local ok, success, message, extra = pcall(function()
			return actionFunction:InvokeServer(action, a, b)
		end)
		if not ok then
			showToast("❌ Sin conexión con el servidor", "error")
			return
		end
		if message and message ~= "" then
			showToast(message, if success then "success" else "error")
		end
		if success and type(extra) == "table" then
			if extra.gold then
				playSound("coin")
			elseif extra.equip then
				playSound("equip")
			elseif extra.forge then
				playSound("skill")
			end
		elseif not success then
			playSound("error")
		end
		if onResult then
			onResult(success, message, extra)
		end
	end)
end

---------------------------------------------------------------------
-- Avisos y ventanas emergentes
---------------------------------------------------------------------
do
	local toastHolder = create("Frame", {
		Parent = toastGui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(440, 300),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	autoScale(toastHolder)
	local KIND_COLORS = {
		success = THEME.green,
		error = THEME.red,
		info = THEME.blue,
		loot = THEME.gold,
		boss = THEME.orange,
		level = THEME.accent,
	}
	local order = 0
	function showToast(text: string, kind: string?)
		order += 1
		local color = KIND_COLORS[kind or "info"] or THEME.blue
		local toast = create("TextLabel", {
			Parent = toastHolder,
			Size = UDim2.fromOffset(420, 38),
			BackgroundColor3 = darken(color, 0.55),
			BackgroundTransparency = 0.1,
			Text = text,
			TextColor3 = THEME.text,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			LayoutOrder = order,
		}, { corner(10), stroke(color, 2), maxText(16), padding(6) })
		if #toastHolder:GetChildren() > 6 then
			local oldest, oldestOrder = nil, math.huge
			for _, child in toastHolder:GetChildren() do
				if child:IsA("TextLabel") and child.LayoutOrder < oldestOrder then
					oldest, oldestOrder = child, child.LayoutOrder
				end
			end
			if oldest then
				oldest:Destroy()
			end
		end
		task.delay(3.5, function()
			if toast.Parent then
				TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
				task.delay(0.45, function()
					toast:Destroy()
				end)
			end
		end)
	end

	-- Ventana emergente con cola (no se pisan unas a otras)
	local overlay = create("Frame", {
		Parent = modalGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
	})
	local box = create("Frame", {
		Parent = overlay,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 260),
		BackgroundColor3 = THEME.panel,
	}, { corner(16), stroke(THEME.accent, 3), padding(16) })
	autoScale(box)
	local title = label(box, "", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 40), 24, THEME.gold, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local body = label(box, "", UDim2.fromOffset(0, 48), UDim2.new(1, 0, 1, -110), 17, THEME.text)
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextYAlignment = Enum.TextYAlignment.Top
	local queue: { { string } } = {}
	local okButton: TextButton
	local function showNext()
		local nextItem = table.remove(queue, 1)
		if nextItem then
			title.Text = nextItem[1]
			body.Text = nextItem[2]
			modalGui.Enabled = true
		else
			modalGui.Enabled = false
		end
	end
	okButton = makeButton(box, "¡Genial!", THEME.green, UDim2.fromOffset(180, 46), showNext)
	okButton.AnchorPoint = Vector2.new(0.5, 1)
	okButton.Position = UDim2.fromScale(0.5, 1)
	function showPopup(t: string, b: string)
		table.insert(queue, { t, b })
		if not modalGui.Enabled then
			showNext()
		end
	end
end

---------------------------------------------------------------------
-- HUD del lobby: Coronas, clase y botón JUGAR
---------------------------------------------------------------------
local lobbyHud: { [string]: any } = {}
do
	local panel = create("Frame", {
		Parent = mainGui,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(300, 74),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
	}, { corner(14), stroke(THEME.gold, 2), padding(10), gradient(THEME.card, THEME.panel) })
	autoScale(panel)
	lobbyHud.panel = panel
	lobbyHud.gold = iconLabel(panel, "coin", "0", UDim2.new(), UDim2.new(1, 0, 0, 32), 24, THEME.gold)
	lobbyHud.info = label(panel, "", UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 20), 14, THEME.muted)
	local holder = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(250, 66),
		BackgroundTransparency = 1,
	})
	autoScale(holder)
	lobbyHud.play = holder
	local play = makeButton(holder, "JUGAR", THEME.green, UDim2.fromScale(1, 1), function()
		openWindow("jugar")
	end)
	play:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 30
	buttonIcon(play, "castle", 44)
	lobbyHud.saveWarning = create("TextLabel", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(520, 30),
		BackgroundColor3 = THEME.red,
		Text = "⚠️ Guardado desactivado: publica el juego y activa «Enable Studio Access to API Services»",
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Visible = false,
	}, { corner(8), maxText(14), padding(4) })
end

---------------------------------------------------------------------
-- HUD de partida
---------------------------------------------------------------------
local runHud: { [string]: any } = {}
do
	local top = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(640, 104),
		BackgroundTransparency = 1,
		Visible = false,
	})
	autoScale(top)
	runHud.top = top
	-- Oleada (centro) y reloj debajo
	runHud.wave = create("TextLabel", {
		Parent = top,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(240, 34),
		BackgroundTransparency = 1,
		Text = "OLEADA 1",
		TextColor3 = THEME.gold,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.fromRGB(60, 30, 0),
		Font = TITLE_FONT,
		TextScaled = true,
	})
	local clockHolder = create("Frame", { Parent = top, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(110, 20), BackgroundTransparency = 1 })
	runHud.clock = iconLabel(clockHolder, "clock", "00:00", UDim2.new(), UDim2.new(1, 0, 0, 20), 16, THEME.text)
	runHud.kills = iconLabel(top, "skull", "0", UDim2.fromOffset(0, 4), UDim2.fromOffset(170, 30), 20, THEME.text)
	local goldHolder = create("Frame", { Parent = top, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(170, 30), BackgroundTransparency = 1 })
	runHud.gold = iconLabel(goldHolder, "coin", "0", UDim2.new(), UDim2.new(1, 0, 0, 30), 20, THEME.gold)
	-- Barra de experiencia del equipo con un cristal delante
	local _, xpFill, xpText = makeBar(top, UDim2.fromOffset(30, 60), UDim2.new(1, -30, 0, 20), THEME.purple)
	icon(top, "gem", 28, UDim2.fromOffset(0, 56))
	runHud.xpFill = xpFill
	runHud.xpText = xpText
	runHud.info = label(top, "", UDim2.fromOffset(0, 82), UDim2.new(1, 0, 0, 22), 14, THEME.muted, true)
	runHud.info.TextXAlignment = Enum.TextXAlignment.Center
	runHud.info.TextStrokeTransparency = 0.5

	-- Cartel grande al empezar cada oleada / cuenta atrás del descanso
	local banner = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(520, 120),
		BackgroundTransparency = 1,
		Visible = false,
	})
	autoScale(banner)
	runHud.banner = banner
	runHud.bannerTitle = create("TextLabel", {
		Parent = banner,
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = THEME.gold,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(60, 25, 0),
		Font = TITLE_FONT,
		TextScaled = true,
	})
	runHud.bannerSub = create("TextLabel", {
		Parent = banner,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = THEME.text,
		TextStrokeTransparency = 0.3,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	})
	runHud.bannerScale = create("UIScale", { Parent = runHud.bannerTitle })

	-- Jefe
	local bossFrame = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 116),
		Size = UDim2.fromOffset(480, 34),
		BackgroundTransparency = 1,
		Visible = false,
	})
	autoScale(bossFrame)
	runHud.boss = bossFrame
	local _, bossFill, bossText = makeBar(bossFrame, UDim2.fromOffset(40, 4), UDim2.new(1, -40, 1, -8), THEME.red)
	icon(bossFrame, "crown", 36, UDim2.fromOffset(0, -2))
	runHud.bossFill = bossFill
	runHud.bossText = bossText

	-- Vida, armas y mejoras (abajo a la izquierda)
	local bottom = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(330, 150),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		Visible = false,
	}, { corner(12), stroke(THEME.gold, 2), padding(8), gradient(THEME.card, THEME.panel) })
	autoScale(bottom)
	runHud.bottom = bottom
	local _, hpFill, hpText = makeBar(bottom, UDim2.fromOffset(30, 2), UDim2.new(1, -30, 0, 22), THEME.red)
	icon(bottom, "heart", 26, UDim2.fromOffset(0, 0))
	runHud.hpFill = hpFill
	runHud.hpText = hpText
	runHud.weapons = create("Frame", {
		Parent = bottom,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	runHud.passives = create("Frame", {
		Parent = bottom,
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	runHud.passivesHint = label(bottom, "Sube de nivel para conseguir mejoras", UDim2.fromOffset(0, 104), UDim2.new(1, 0, 0, 24), 13, THEME.muted)

	-- Esquivar y abandonar
	local dashHolder = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -150, 1, -30),
		Size = UDim2.fromOffset(96, 96),
		BackgroundTransparency = 1,
		Visible = false,
	})
	autoScale(dashHolder)
	runHud.dash = dashHolder
	local dashButton = makeButton(dashHolder, "💨", THEME.blue, UDim2.fromScale(1, 1), function()
		dash()
	end)
	dashButton:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 40
	runHud.dashButton = dashButton
	runHud.dashCooldown = create("Frame", {
		Parent = dashButton,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 2,
	}, { corner(10) })
	label(dashButton, "Q / Shift", UDim2.new(0, 0, 1, -18), UDim2.new(1, 0, 0, 16), 11, THEME.text, true).TextXAlignment = Enum.TextXAlignment.Center

	local leaveHolder = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(120, 36),
		BackgroundTransparency = 1,
		Visible = false,
	})
	autoScale(leaveHolder)
	runHud.leave = leaveHolder
	makeButton(leaveHolder, "🏳️ Abandonar", THEME.card, UDim2.fromScale(1, 1), function()
		sendAction("leaveRun")
	end)

	-- Destello rojo al recibir daño
	runHud.flash = create("Frame", {
		Parent = flashGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.red,
		BackgroundTransparency = 1,
	})
end

---------------------------------------------------------------------
-- Ventana principal con pestañas
---------------------------------------------------------------------
local window: Frame
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local currentTab = "jugar"
local TABS = {
	{ id = "jugar", name = "Jugar", icon = "castle" },
	{ id = "clases", name = "Clases", icon = "guerrero" },
	{ id = "mejoras", name = "Árbol", icon = "tree" },
	{ id = "armas", name = "Armas", icon = "weaponchest" },
	{ id = "mochila", name = "Mochila", icon = "bag" },
	{ id = "forja", name = "Forja", icon = "hammer" },
	{ id = "tienda", name = "Tienda", icon = "cart" },
	{ id = "diario", name = "Diario", icon = "gift" },
	{ id = "ajustes", name = "Ajustes", icon = "gear" },
}
do
	window = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(880, 540),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
	}, { corner(16), stroke(THEME.gold, 3), gradient(THEME.panel, THEME.bg) })
	autoScale(window)
	-- Remaches dorados en las esquinas (toque medieval)
	for _, spot in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		create("Frame", {
			Parent = window,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(spot[1], if spot[1] == 0 then 10 else -10, spot[2], if spot[2] == 0 then 10 else -10),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = THEME.gold,
			ZIndex = 3,
		}, { corner(5), stroke(Color3.fromRGB(120, 70, 10), 1) })
	end
	local tabBar = create("Frame", {
		Parent = window,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -72, 0, 40),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, tab in TABS do
		local button = makeButton(tabBar, tab.name, THEME.card, UDim2.fromOffset(87, 38), function()
			openWindow(tab.id)
		end)
		button.LayoutOrder = i
		button:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 14
		buttonIcon(button, tab.icon, 24)
		tabButtons[tab.id] = button
		pages[tab.id] = create("Frame", {
			Parent = window,
			Position = UDim2.fromOffset(14, 60),
			Size = UDim2.new(1, -28, 1, -74),
			BackgroundTransparency = 1,
			Visible = false,
		})
	end
	local close = makeButton(window, "✕", THEME.red, UDim2.fromOffset(40, 40), function()
		window.Visible = false
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)

	function openWindow(tab: string)
		if state and state.run then
			return -- en partida no se abren menús
		end
		currentTab = tab
		window.Visible = true
		for id, page in pages do
			page.Visible = id == tab
			setButton(tabButtons[id], tabButtons[id].Text, true, if id == tab then THEME.accent else THEME.card)
		end
		refreshWindow()
	end
end

-- Menú lateral (botones con icono)
local menu: Frame
local menuDots: { [string]: Frame } = {}
do
	menu = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 30),
		Size = UDim2.fromOffset(64, #TABS * 52),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	autoScale(menu)
	for i, tab in TABS do
		local button = makeButton(menu, "", THEME.card, UDim2.fromOffset(56, 48), function()
			if window.Visible and currentTab == tab.id then
				window.Visible = false
			else
				openWindow(tab.id)
			end
		end)
		button.LayoutOrder = i
		local frame = icon(button, tab.icon, 34, UDim2.fromScale(0.5, 0.5))
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		menuDots[tab.id] = create("Frame", {
			Parent = button,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = THEME.red,
			Visible = false,
			ZIndex = 50,
		}, { corner(8), stroke(THEME.text, 2) })
	end
end

---------------------------------------------------------------------
-- Pestaña: Jugar (mapas, solo o en grupo)
---------------------------------------------------------------------
local refreshJugar: () -> ()
do
	local page = pages.jugar
	-- Mapas (izquierda)
	local mapList = scrollList(page, UDim2.new(), UDim2.new(0.5, -6, 1, 0))
	local mapCards = {}
	for i, map in Config.Maps do
		local card = makeCard(mapList, 116, i, darken(map.color, 0.72))
		local title = label(card, map.emoji .. " <b>" .. map.name .. "</b>", UDim2.new(), UDim2.new(1, 0, 0, 24), 18, lighten(map.color, 0.3))
		title.Font = Enum.Font.GothamBold
		local names = {}
		for _, entry in map.timeline do
			local enemyName = Config.Enemies[entry.enemy].name
			if not table.find(names, enemyName) then
				table.insert(names, enemyName)
			end
		end
		label(card, "Enemigos: " .. table.concat(names, ", "), UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 30), 12, THEME.text)
		iconLabel(card, "crown", map.waves .. " oleadas · jefe: " .. Config.Enemies[map.boss].name, UDim2.fromOffset(0, 56), UDim2.new(1, 0, 0, 18), 12, THEME.gold)
		local status = label(card, "", UDim2.fromOffset(0, 76), UDim2.new(1, -110, 0, 20), 12, THEME.muted)
		local button = makeButton(card, "Elegir", THEME.blue, UDim2.fromOffset(100, 32), function()
			selectedMap = i
			refreshJugar()
		end)
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.fromScale(1, 1)
		mapCards[i] = { card = card, status = status, button = button, title = title }
	end

	-- Dificultad, jugar y grupos (derecha)
	local right = create("Frame", { Parent = page, Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1 })
	local selectedLabel = label(right, "", UDim2.new(), UDim2.new(1, 0, 0, 26), 18, THEME.gold, true)
	local diffButtons: { TextButton } = {}
	for d, diff in Config.Difficulties do
		local button = makeButton(right, diff.name, diff.color, UDim2.new(1 / 3, -4, 0, 36), function()
			selectedDifficulty = d
			refreshJugar()
		end)
		button.Position = UDim2.new((d - 1) / 3, 0, 0, 30)
		diffButtons[d] = button
	end
	local diffInfo = label(right, "", UDim2.fromOffset(0, 70), UDim2.new(1, 0, 0, 34), 12, THEME.muted)
	local soloButton = makeButton(right, "▶ Jugar solo", THEME.green, UDim2.new(0.5, -4, 0, 46), function()
		sendAction("playSolo", selectedMap, selectedDifficulty, function(ok)
			if ok then
				window.Visible = false
			end
		end)
	end)
	soloButton.Position = UDim2.fromOffset(0, 106)
	local groupButton = makeButton(right, "👥 Crear grupo", THEME.accent, UDim2.new(0.5, -4, 0, 46), function()
		sendAction("createGroup", selectedMap, selectedDifficulty)
	end)
	groupButton.Position = UDim2.new(0.5, 4, 0, 106)
	local myGroupCard = makeCard(right, 104, 1, THEME.bg)
	myGroupCard.Position = UDim2.fromOffset(0, 160)
	myGroupCard.Size = UDim2.new(1, 0, 0, 104)
	local myGroupText = label(myGroupCard, "", UDim2.new(), UDim2.new(1, 0, 0, 46), 14, THEME.text)
	local startButton = makeButton(myGroupCard, "▶ Empezar", THEME.green, UDim2.new(0.5, -4, 0, 36), function()
		sendAction("startGroup", nil, nil, function(ok)
			if ok then
				window.Visible = false
			end
		end)
	end)
	startButton.Position = UDim2.new(0, 0, 1, -36)
	local leaveButton = makeButton(myGroupCard, "Salir del grupo", THEME.card, UDim2.new(0.5, -4, 0, 36), function()
		sendAction("leaveGroup")
	end)
	leaveButton.Position = UDim2.new(0.5, 4, 1, -36)
	local groupsTitle = label(right, "<b>Grupos abiertos</b> (hasta " .. Config.MAX_GROUP .. " jugadores)", UDim2.fromOffset(0, 270), UDim2.new(1, 0, 0, 22), 14, THEME.muted)
	local groupList = scrollList(right, UDim2.fromOffset(0, 294), UDim2.new(1, 0, 1, -294))
	local lastGroups = ""

	local function winsOf(mapId: string): { [string]: number }
		local wins = state.mapWins[mapId]
		return if type(wins) == "table" then wins else {}
	end

	function refreshJugar()
		selectedMap = math.clamp(selectedMap, 1, state.unlockedMap)
		if not Config.difficultyUnlocked(state.unlockedMap, state.mapWins, selectedMap, selectedDifficulty) then
			selectedDifficulty = 1
		end
		for i, map in Config.Maps do
			local c = mapCards[i]
			local unlocked = state.unlockedMap >= i
			local wins = winsOf(map.id)
			local parts = {}
			for _, diff in Config.Difficulties do
				if (wins[diff.id] or 0) > 0 then
					table.insert(parts, string.format("<font color=\"#%s\">%s ✓%d</font>", diff.color:ToHex(), diff.name, wins[diff.id]))
				end
			end
			c.status.Text = if not unlocked then "🔒 Escapa de " .. Config.Maps[i - 1].name .. " para abrirlo" elseif #parts > 0 then table.concat(parts, "  ") else "⚔️ Aún no has escapado"
			setButton(c.button, if selectedMap == i then "✓ Elegido" else "Elegir", unlocked and selectedMap ~= i, THEME.blue)
		end
		local map = Config.Maps[selectedMap]
		local diff = Config.Difficulties[selectedDifficulty]
		selectedLabel.Text = map.emoji .. " " .. map.name .. "  ·  " .. diff.name
		for d, button in diffButtons do
			local open = Config.difficultyUnlocked(state.unlockedMap, state.mapWins, selectedMap, d)
			local other = Config.Difficulties[d]
			local text = if not open then "🔒 " .. other.name elseif d == selectedDifficulty then "✓ " .. other.name else other.name
			setButton(button, text, open and d ~= selectedDifficulty, other.color)
			if d == selectedDifficulty then
				button:SetAttribute("PaintColor", other.color)
			end
		end
		diffInfo.Text = if selectedDifficulty == 1
			then "Enemigos normales. Supera esta dificultad para abrir <b>Difícil</b>."
			else string.format("Enemigos con x%.1f de vida y x%.1f de daño · <font color=\"#fbbf24\"><b>x%.1f Coronas</b></font> y mejor botín", diff.hp, diff.damage, diff.gold)
		local group = state.myGroup
		setButton(soloButton, "▶ Jugar solo", group == nil, THEME.green)
		setButton(groupButton, "👥 Crear grupo", group == nil, THEME.accent)
		myGroupCard.Visible = group ~= nil
		groupsTitle.Visible = true
		if group then
			local members = {}
			for _, g in state.groups do
				if g.id == group.id then
					members = g.members
				end
			end
			local groupDiff = Config.Difficulties[group.difficulty or 1]
			myGroupText.Text = string.format("<b>Tu grupo</b> · %s %s · %s\n%s", Config.Maps[group.map].emoji, Config.Maps[group.map].name, groupDiff.name, table.concat(members, ", "))
			setButton(startButton, if group.leader then "▶ Empezar" else "Espera al líder", group.leader, THEME.green)
		end
		-- Lista de grupos (solo se rehace si cambia)
		local parts = { tostring(group and group.id) }
		for _, g in state.groups do
			table.insert(parts, g.id .. ":" .. #g.members)
		end
		local signature = table.concat(parts, ",")
		if signature ~= lastGroups then
			lastGroups = signature
			clearChildren(groupList, "UIListLayout")
			if #state.groups == 0 then
				label(groupList, "No hay grupos. ¡Crea uno e invita a tus amigos!", UDim2.new(), UDim2.new(1, -8, 0, 40), 13, THEME.muted).LayoutOrder = 1
			end
			for i, g in state.groups do
				local card = makeCard(groupList, 52, i)
				local gDiff = Config.Difficulties[g.difficulty or 1]
				label(card, string.format("%s <b>%s</b> · %s · %d/%d", Config.Maps[g.map].emoji, g.leader, gDiff.name, #g.members, Config.MAX_GROUP), UDim2.new(), UDim2.new(1, -110, 1, 0), 14, THEME.text)
				local join = makeButton(card, "Unirse", THEME.blue, UDim2.fromOffset(100, 32), function()
					sendAction("joinGroup", g.id)
				end)
				join.AnchorPoint = Vector2.new(1, 0.5)
				join.Position = UDim2.fromScale(1, 0.5)
				local mine = group and group.id == g.id
				local can = Config.difficultyUnlocked(state.unlockedMap, state.mapWins, g.map, g.difficulty or 1)
				setButton(join, if mine then "Tu grupo" elseif not can then "🔒" else "Unirse", not mine and can and #g.members < Config.MAX_GROUP, THEME.blue)
			end
		end
	end
end

---------------------------------------------------------------------
-- Pestaña: Clases
---------------------------------------------------------------------
local refreshClases: () -> ()
do
	local page = pages.clases
	local list = scrollList(page, UDim2.new(), UDim2.fromScale(1, 1))
	local rows = {}
	for i, class in Config.Classes do
		local card = makeCard(list, 84, i)
		icon(card, class.id, 60, UDim2.fromOffset(0, 2), { bg = THEME.panel })
		local weapon = Config.Weapons[class.weapon]
		label(card, "<b>" .. class.name .. "</b>\n" .. class.desc .. "\nArma inicial: " .. weapon.name .. " — " .. weapon.desc, UDim2.fromOffset(70, 0), UDim2.new(1, -260, 1, 0), 13, THEME.text)
		icon(card, class.weapon, 44, UDim2.new(1, -236, 0.5, -22), { bg = THEME.bg })
		local button = makeButton(card, "", THEME.gold, UDim2.fromOffset(170, 40), function()
			sendAction("buyClass", class.id)
		end)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		rows[class.id] = button
	end

	function refreshClases()
		for _, class in Config.Classes do
			local button = rows[class.id]
			if state.selectedClass == class.id then
				setButton(button, "✓ Elegida", false)
			elseif state.classes[class.id] then
				setButton(button, "Elegir", true, THEME.green)
			else
				setButton(button, Config.money(class.price), state.gold >= class.price, THEME.gold)
			end
		end
	end
end

---------------------------------------------------------------------
-- Pestaña: Árbol de mejoras (todo en una página; cada nodo se abre al
-- comprar el anterior)
---------------------------------------------------------------------
local refreshMejoras: () -> ()
do
	local page = pages.mejoras
	local CANVAS_W, CANVAS_H = 600, 466
	local NODE = 54
	local canvas = create("Frame", {
		Parent = page,
		Size = UDim2.fromOffset(CANVAS_W, CANVAS_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
	}, { corner(12), stroke(THEME.stroke, 2), gradient(Color3.fromRGB(70, 48, 30), Color3.fromRGB(36, 24, 15)) })
	local function nodePos(node: any): (number, number)
		return node.x * CANVAS_W, 46 + node.y * (CANVAS_H - 82)
	end
	local branchById = {}
	for _, branch in Config.Branches do
		branchById[branch.id] = branch
	end
	-- Nombre de cada rama arriba
	for _, branch in Config.Branches do
		local xs = 0
		local n = 0
		for _, node in Config.Tree do
			if node.branch == branch.id then
				xs += node.x
				n += 1
			end
		end
		local title = create("TextLabel", {
			Parent = canvas,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(xs / n * CANVAS_W, 6),
			Size = UDim2.fromOffset(180, 30),
			BackgroundTransparency = 1,
			Text = branch.name,
			TextColor3 = lighten(branch.color, 0.35),
			TextStrokeTransparency = 0.3,
			Font = TITLE_FONT,
			TextScaled = true,
		})
		title.ZIndex = 2
	end
	-- Líneas entre nodos (debajo de los botones)
	local lines: { [string]: Frame } = {}
	for _, node in Config.Tree do
		if node.parent then
			local parent = Config.TreeById[node.parent]
			local x1, y1 = nodePos(parent)
			local x2, y2 = nodePos(node)
			local dx, dy = x2 - x1, y2 - y1
			lines[node.id] = create("Frame", {
				Parent = canvas,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
				Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 6),
				Rotation = math.deg(math.atan2(dy, dx)),
				BackgroundColor3 = THEME.disabled,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, { corner(3) })
		end
	end
	-- Detalle del nodo elegido (derecha)
	local detail = create("Frame", {
		Parent = page,
		Position = UDim2.fromOffset(CANVAS_W + 12, 0),
		Size = UDim2.new(1, -(CANVAS_W + 12), 1, 0),
		BackgroundColor3 = THEME.card,
	}, { corner(12), stroke(THEME.gold, 2), padding(12) })
	local detailIcon = create("Frame", { Parent = detail, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1 })
	local detailName = label(detail, "", UDim2.fromOffset(0, 78), UDim2.new(1, 0, 0, 28), 18, THEME.gold, true)
	detailName.TextXAlignment = Enum.TextXAlignment.Center
	local detailText = label(detail, "", UDim2.fromOffset(0, 108), UDim2.new(1, 0, 0, 80), 14, THEME.text)
	detailText.TextXAlignment = Enum.TextXAlignment.Center
	detailText.TextYAlignment = Enum.TextYAlignment.Top
	local selectedNode = Config.Tree[1].id
	local buyButton = makeButton(detail, "", THEME.green, UDim2.new(1, 0, 0, 46), function()
		sendAction("buyNode", selectedNode)
	end)
	buyButton.Position = UDim2.fromOffset(0, 192)
	buttonIcon(buyButton, "coin", 28)
	local totals = label(detail, "", UDim2.new(0, 0, 1, -170), UDim2.new(1, 0, 0, 170), 13, THEME.muted)
	totals.TextYAlignment = Enum.TextYAlignment.Bottom
	local lastDetail = ""

	-- Nodos
	local nodes: { [string]: any } = {}
	for _, node in Config.Tree do
		local x, y = nodePos(node)
		local branch = branchById[node.branch]
		local button = makeButton(canvas, "", darken(branch.color, 0.4), UDim2.fromOffset(NODE, NODE), function()
			selectedNode = node.id
			refreshMejoras()
		end)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromOffset(x, y)
		button.ZIndex = 3
		button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
		local art = icon(button, node.icon, 36, UDim2.fromScale(0.5, 0.5), { zindex = 4 })
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		local veil = create("Frame", {
			Parent = button,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 40,
		}, { corner(30) })
		local price = create("TextLabel", {
			Parent = canvas,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(x, y + NODE / 2 + 1),
			Size = UDim2.fromOffset(96, 16),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = THEME.gold,
			TextStrokeTransparency = 0.3,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			ZIndex = 5,
		})
		nodes[node.id] = { button = button, veil = veil, price = price, border = button:FindFirstChildOfClass("UIStroke") }
	end

	function refreshMejoras()
		local tree = state.tree
		for _, node in Config.Tree do
			local n = nodes[node.id]
			local branch = branchById[node.branch]
			local owned = tree[node.id] == true
			local available = Config.nodeAvailable(tree, node)
			local color = if owned then branch.color elseif available then darken(branch.color, 0.35) else THEME.disabled
			n.button.BackgroundColor3 = color -- directo: el borde lo pintamos nosotros
			n.veil.Visible = not owned and not available
			n.price.Text = if owned then "✓ " .. node.name elseif available then num(node.cost) .. " Coronas" else "🔒"
			n.price.TextColor3 = if owned then lighten(branch.color, 0.5) elseif state.gold >= node.cost then THEME.gold else THEME.muted
			n.border.Color = if node.id == selectedNode then Color3.new(1, 1, 1) elseif owned then THEME.gold elseif available then lighten(branch.color, 0.2) else darken(THEME.disabled, 0.3)
			n.border.Thickness = if node.id == selectedNode then 4 elseif available then 3 else 2
			local line = lines[node.id]
			if line then
				line.BackgroundColor3 = if owned then branch.color elseif available then darken(branch.color, 0.2) else THEME.disabled
			end
		end
		-- Detalle
		local node = Config.TreeById[selectedNode]
		local branch = branchById[node.branch]
		if lastDetail ~= node.id then
			lastDetail = node.id
			clearChildren(detailIcon)
			icon(detailIcon, node.icon, 72, UDim2.new(), { bg = darken(branch.color, 0.3) })
		end
		detailName.Text = node.name
		local owned = tree[node.id] == true
		local available = Config.nodeAvailable(tree, node)
		local need = if node.parent then Config.TreeById[node.parent].name else nil
		detailText.Text = string.format("Rama de <b>%s</b>\n<font color=\"#4ade80\"><b>%s</b></font>%s", branch.name, Config.nodeEffect(node), if not owned and not available and need then "\n\n🔒 Compra antes <b>" .. need .. "</b>" else "")
		if owned then
			setButton(buyButton, "✓ Comprada", false)
		elseif not available then
			setButton(buyButton, "🔒 Bloqueada", false)
		else
			setButton(buyButton, "Comprar · " .. num(node.cost), state.gold >= node.cost, THEME.green)
		end
		local stats = state.stats
		local bought = 0
		for _ in tree do
			bought += 1
		end
		totals.Text = string.format("<b>Tus mejoras (%d/%d)</b>\n⚔️ Daño x%.2f · ⏱️ Recarga x%.2f\n⭕ Alcance x%.2f · ❤️ Vida %s\n💚 Regeneración %.1f/s · 💖 Vidas extra %d\n👟 Velocidad x%.2f · 🧲 Imán x%.2f\n👑 Coronas x%.2f · 🎲 Cambios +%d", bought, #Config.Tree, stats.damage, stats.cooldown, stats.area, num(stats.health), stats.regen, stats.lives, stats.speed, stats.magnet, stats.gold, stats.rerolls)
	end
end

---------------------------------------------------------------------
-- Pestaña: Armas (cofre de armas y colección)
---------------------------------------------------------------------
local refreshArmas: () -> ()
do
	local page = pages.armas
	local left = create("Frame", {
		Parent = page,
		Size = UDim2.new(0, 290, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(12), stroke(THEME.gold, 2), padding(12), gradient(Color3.fromRGB(96, 64, 36), Color3.fromRGB(48, 30, 18)) })
	local chestTitle = label(left, "Cofre de armas", UDim2.new(), UDim2.new(1, 0, 0, 34), 26, THEME.gold, true)
	chestTitle.Font = TITLE_FONT
	chestTitle.TextXAlignment = Enum.TextXAlignment.Center
	local chestHolder = create("Frame", { Parent = left, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(104, 104), BackgroundTransparency = 1 })
	icon(chestHolder, "weaponchest", 104, UDim2.new(), { glow = true })
	local chestScale = create("UIScale", { Parent = chestHolder })
	local note = label(left, "Siempre te da un arma <b>que aún no tienes</b>. Se paga con Coronas, no con Robux.", UDim2.fromOffset(0, 144), UDim2.new(1, 0, 0, 34), 12, THEME.muted)
	note.TextXAlignment = Enum.TextXAlignment.Center
	local openButton = makeButton(left, "", THEME.green, UDim2.new(1, 0, 0, 44), function()
		sendAction("buyWeaponChest", nil, nil, function(ok, _, extra)
			if ok and type(extra) == "table" and extra.weapon then
				chestScale.Scale = 1.3
				TweenService:Create(chestScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				local weapon = Config.Weapons[extra.weapon]
				playSound("loot")
				showPopup("¡Nueva arma: " .. weapon.name .. "!", weapon.desc .. "\n\nYa puede salirte al subir de nivel en tus partidas.")
			end
		end)
	end)
	openButton.Position = UDim2.fromOffset(0, 182)
	buttonIcon(openButton, "coin", 28)
	label(left, "<b>Probabilidades</b>", UDim2.fromOffset(0, 232), UDim2.new(1, 0, 0, 20), 14, THEME.text)
	local oddsList = create("Frame", {
		Parent = left,
		Position = UDim2.fromOffset(0, 254),
		Size = UDim2.new(1, 0, 1, -254),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Colección de armas (derecha)
	local grid = create("ScrollingFrame", {
		Parent = page,
		Position = UDim2.fromOffset(302, 0),
		Size = UDim2.new(1, -302, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = THEME.stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(176, 146), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local cards: { [string]: any } = {}
	local starterOf = {}
	for _, class in Config.Classes do
		starterOf[class.weapon] = class.name
	end
	local chestRarity = {}
	for _, entry in Config.WeaponChest do
		chestRarity[entry.id] = Config.RarityById[entry.rarity]
	end
	for i, id in Config.WeaponOrder do
		local weapon = Config.Weapons[id]
		local rarity = chestRarity[id] or Config.RarityById.comun
		local card = create("Frame", {
			Parent = grid,
			BackgroundColor3 = darken(rarity.color, 0.7),
			LayoutOrder = i,
		}, { corner(12), padding(8) })
		local border = stroke(rarity.color, 2)
		border.Parent = card
		icon(card, id, 52, UDim2.fromOffset(0, 0), { bg = THEME.bg })
		label(card, "<b>" .. weapon.name .. "</b>", UDim2.fromOffset(58, 0), UDim2.new(1, -58, 0, 34), 14, rarity.color)
		label(card, weapon.evolution.emoji .. " " .. weapon.evolution.name, UDim2.fromOffset(58, 34), UDim2.new(1, -58, 0, 20), 10, THEME.gold)
		label(card, weapon.desc, UDim2.fromOffset(0, 58), UDim2.new(1, 0, 0, 44), 11, THEME.text)
		local status = label(card, "", UDim2.new(0, 0, 1, -22), UDim2.new(1, 0, 0, 22), 12, THEME.muted, true)
		local veil = create("Frame", {
			Parent = card,
			Size = UDim2.new(1, 16, 1, 16),
			Position = UDim2.fromOffset(-8, -8),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			ZIndex = 30,
		}, { corner(12) })
		cards[id] = { status = status, veil = veil }
	end
	local lastOdds = ""

	function refreshArmas()
		local unlocked = state.weapons
		for id, c in cards do
			local has = unlocked[id] == true
			c.veil.Visible = not has
			if starterOf[id] then
				c.status.Text = "✓ Inicial (" .. starterOf[id] .. ")"
			elseif has then
				c.status.Text = "✓ Desbloqueada"
			else
				c.status.Text = "🔒 Sale en el cofre"
			end
			c.status.TextColor3 = if has then THEME.green else THEME.muted
			c.status.ZIndex = 31
		end
		local odds = Config.weaponChestOdds(unlocked)
		if #odds == 0 then
			setButton(openButton, "¡Las tienes todas!", false)
		else
			setButton(openButton, "Abrir · " .. num(state.weaponChestPrice), state.gold >= state.weaponChestPrice, THEME.green)
		end
		local parts = {}
		for _, entry in odds do
			table.insert(parts, entry.id)
		end
		local signature = table.concat(parts, ",")
		if signature ~= lastOdds then
			lastOdds = signature
			clearChildren(oddsList, "UIListLayout")
			for i, entry in odds do
				local weapon = Config.Weapons[entry.id]
				local rarity = chestRarity[entry.id]
				local row = create("Frame", { Parent = oddsList, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i })
				icon(row, entry.id, 24, UDim2.new())
				label(row, string.format("%s  <font color=\"#%s\">(%s)</font>", weapon.name, rarity.color:ToHex(), rarity.name), UDim2.fromOffset(30, 0), UDim2.new(1, -86, 1, 0), 12, THEME.text)
				local pct = label(row, string.format("%.1f %%", entry.chance * 100), UDim2.new(1, -56, 0, 0), UDim2.new(0, 56, 1, 0), 13, THEME.gold, true)
				pct.TextXAlignment = Enum.TextXAlignment.Right
			end
			if #odds == 0 then
				label(oddsList, "Ya tienes todas las armas. ¡Bien hecho!", UDim2.new(), UDim2.new(1, 0, 0, 30), 12, THEME.muted)
			end
		end
	end
end

---------------------------------------------------------------------
-- Pestaña: Mochila
---------------------------------------------------------------------
local refreshMochila: () -> ()
do
	local page = pages.mochila
	local selectedId: number? = nil
	local lastSignature = ""

	-- Equipado (izquierda)
	local left = create("Frame", { Parent = page, Size = UDim2.new(0, 250, 1, 0), BackgroundTransparency = 1 })
	label(left, "<b>Equipado</b>", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 22), 16, THEME.gold)
	local slotLabels: { [string]: TextLabel } = {}
	for i, slot in Config.Slots do
		local card = makeCard(left, 58, i)
		card.Position = UDim2.fromOffset(0, 26 + (i - 1) * 64)
		card.Size = UDim2.new(1, 0, 0, 58)
		slotLabels[slot.id] = label(card, "", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 14, THEME.text)
	end
	local statsLabel = label(left, "", UDim2.fromOffset(0, 222), UDim2.new(1, 0, 0, 70), 14, THEME.muted)

	-- Detalle del objeto seleccionado
	local detail = makeCard(left, 130, 9, THEME.bg)
	detail.Position = UDim2.new(0, 0, 1, -130)
	detail.Size = UDim2.new(1, 0, 0, 130)
	local detailText = label(detail, "Toca un objeto para verlo", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 62), 14, THEME.muted)
	local equipButton = makeButton(detail, "Equipar", THEME.green, UDim2.new(0.5, -3, 0, 40), function()
		if selectedId then
			sendAction("equip", selectedId)
		end
	end)
	equipButton.Position = UDim2.new(0, 0, 1, -40)
	local sellButton = makeButton(detail, "Vender", THEME.orange, UDim2.new(0.5, -3, 0, 40), function()
		if selectedId then
			local id = selectedId
			selectedId = nil
			sendAction("sell", id)
		end
	end)
	sellButton.Position = UDim2.new(0.5, 3, 1, -40)

	-- Objetos (derecha)
	local right = create("Frame", { Parent = page, Position = UDim2.fromOffset(262, 0), Size = UDim2.new(1, -262, 1, 0), BackgroundTransparency = 1 })
	local countLabel = label(right, "", UDim2.fromOffset(0, 0), UDim2.new(0.4, 0, 0, 30), 16, THEME.text, true)
	local junk1 = makeButton(right, "Vender comunes", THEME.card, UDim2.fromOffset(140, 30), function()
		sendAction("sellJunk", 1)
	end)
	junk1.Position = UDim2.new(1, -290, 0, 0)
	local junk2 = makeButton(right, "Vender ≤ poco común", THEME.card, UDim2.fromOffset(144, 30), function()
		sendAction("sellJunk", 2)
	end)
	junk2.Position = UDim2.new(1, -144, 0, 0)
	local grid = create("ScrollingFrame", {
		Parent = right,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -38),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = THEME.stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(88, 88), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local function equippedItem(slot: string): any
		local id = state.equipped[slot]
		for _, item in state.inventory do
			if item.id == id then
				return item
			end
		end
		return nil
	end

	local function isEquipped(item: any): boolean
		return state.equipped[Config.Items[item.def].slot] == item.id
	end

	local function isBetter(item: any): boolean
		local current = equippedItem(Config.Items[item.def].slot)
		return not current or Config.itemPower(item) > Config.itemPower(current)
	end

	local function updateDetail()
		local item = nil
		for _, it in state.inventory do
			if it.id == selectedId then
				item = it
			end
		end
		if not item then
			selectedId = nil
			detailText.Text = "Toca un objeto para verlo"
			setButton(equipButton, "Equipar", false)
			setButton(sellButton, "Vender", false)
			return
		end
		local rarity = rarityOf(item)
		local def = Config.Items[item.def]
		local current = equippedItem(def.slot)
		local diff = ""
		if current and current.id ~= item.id then
			local delta = Config.itemPower(item) - Config.itemPower(current)
			diff = if delta > 0 then string.format("  <font color=\"#4ade80\">(+%s)</font>", num(delta)) elseif delta < 0 then string.format("  <font color=\"#f87171\">(%s)</font>", num(delta)) else ""
		end
		detailText.Text = string.format("<font color=\"#%s\"><b>%s</b></font>\n%s · %s\n%s%s", rarity.color:ToHex(), itemName(item), rarity.name, def.name, Config.powerText(item), diff)
		local equipped = isEquipped(item)
		setButton(equipButton, if equipped then "✓ Puesto" else "Equipar", not equipped, THEME.green)
		setButton(sellButton, "Vender · " .. Config.money(Config.sellPrice(item)), not equipped, THEME.orange)
	end

	local function buildGrid()
		clearChildren(grid, "UIGridLayout")
		local items = table.clone(state.inventory)
		table.sort(items, function(a, b)
			local ea, eb = isEquipped(a), isEquipped(b)
			if ea ~= eb then
				return ea
			end
			local ra, rb = rarityOf(a).index, rarityOf(b).index
			if ra ~= rb then
				return ra > rb
			end
			return Config.itemPower(a) > Config.itemPower(b)
		end)
		for i, item in items do
			local rarity = rarityOf(item)
			local def = Config.Items[item.def]
			local tile = create("TextButton", {
				Parent = grid,
				BackgroundColor3 = darken(rarity.color, 0.6),
				Text = "",
				AutoButtonColor = true,
				LayoutOrder = i,
			}, { corner(10), stroke(rarity.color, if item.id == selectedId then 4 else 2) })
			create("TextLabel", {
				Parent = tile,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.new(1, 0, 0, 34),
				Text = SLOT_EMOJI[def.slot],
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = THEME.text,
			})
			create("TextLabel", {
				Parent = tile,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(4, 40),
				Size = UDim2.new(1, -8, 0, 22),
				Text = def.name,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = rarity.color,
			})
			create("TextLabel", {
				Parent = tile,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(4, 62),
				Size = UDim2.new(1, -8, 0, 20),
				Text = (if item.up > 0 then "+" .. item.up .. " · " else "") .. num(Config.itemPower(item)),
				TextScaled = true,
				Font = Enum.Font.GothamMedium,
				TextColor3 = THEME.text,
			})
			if isEquipped(item) then
				create("TextLabel", {
					Parent = tile,
					Position = UDim2.fromOffset(4, 4),
					Size = UDim2.fromOffset(22, 22),
					BackgroundColor3 = THEME.green,
					Text = "✓",
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					TextColor3 = THEME.text,
				}, { corner(11) })
			elseif isBetter(item) then
				create("TextLabel", {
					Parent = tile,
					Position = UDim2.new(1, -26, 0, 4),
					Size = UDim2.fromOffset(22, 22),
					BackgroundColor3 = THEME.green,
					Text = "⬆",
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					TextColor3 = THEME.text,
				}, { corner(11) })
			end
			tile.Activated:Connect(function()
				selectedId = item.id
				playSound("click")
				lastSignature = ""
				refreshMochila()
			end)
		end
	end

	function refreshMochila()
		for _, slot in Config.Slots do
			local item = equippedItem(slot.id)
			if item then
				local rarity = rarityOf(item)
				slotLabels[slot.id].Text = string.format("%s <font color=\"#%s\"><b>%s</b></font>\n%s · %s", slot.emoji, rarity.color:ToHex(), itemName(item), rarity.name, Config.powerText(item))
			else
				slotLabels[slot.id].Text = slot.emoji .. " <b>" .. slot.name .. "</b>\n<font color=\"#a1a1be\">Vacío: consíguelo en el cofre del jefe</font>"
			end
		end
		local stats = state.stats
		statsLabel.Text = string.format("⚔️ Daño: <b>x%.2f</b>\n❤️ Vida: <b>%s</b>\n👟 Velocidad: <b>x%.2f</b>  ·  👑 Coronas: <b>x%.2f</b>", stats.damage, num(stats.health), stats.speed, stats.gold)
		countLabel.Text = string.format("Mochila %d/%d", #state.inventory, state.capacity)
		local parts = { tostring(selectedId) }
		for _, item in state.inventory do
			table.insert(parts, item.id .. ":" .. item.up)
		end
		for slot, id in state.equipped do
			table.insert(parts, slot .. "=" .. tostring(id))
		end
		local signature = table.concat(parts, ",")
		if signature ~= lastSignature then
			lastSignature = signature
			buildGrid()
		end
		updateDetail()
	end
end

---------------------------------------------------------------------
-- Pestaña: Forja (mejoras y cofres)
---------------------------------------------------------------------
local refreshForja: () -> ()
do
	local page = pages.forja
	local list = scrollList(page, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	label(list, "<b>🔨 Mejora tu equipo</b>  ·  cada mejora da +" .. math.floor(Config.UPGRADE_STEP * 100) .. " % de poder (máx. +" .. Config.MAX_UPGRADE .. ")", UDim2.new(), UDim2.new(1, -8, 0, 24), 16, THEME.gold).LayoutOrder = 0
	local rows: { [string]: any } = {}
	for i, slot in Config.Slots do
		local card = makeCard(list, 64, i)
		local text = label(card, "", UDim2.fromOffset(0, 0), UDim2.new(1, -190, 1, 0), 14, THEME.text)
		local button = makeButton(card, "Mejorar", THEME.orange, UDim2.fromOffset(180, 42), function()
			local id = state.equipped[slot.id]
			if id then
				sendAction("upgrade", id)
			end
		end)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		rows[slot.id] = { text = text, button = button }
	end
	label(list, "<b>🎁 Cofres del herrero</b>  ·  un objeto al azar de la zona (se paga con Coronas, no con Robux)", UDim2.new(), UDim2.new(1, -8, 0, 24), 16, THEME.gold).LayoutOrder = 10
	local odds = {}
	for _, rarity in Config.Rarities do
		table.insert(odds, string.format("<font color=\"#%s\">%s %s %%</font>", rarity.color:ToHex(), rarity.name, tostring(math.floor(Config.rarityChance(rarity.id, "chestWeight") * 1000 + 0.5) / 10)))
	end
	label(list, "Probabilidades: " .. table.concat(odds, " · "), UDim2.new(), UDim2.new(1, -8, 0, 36), 13, THEME.muted).LayoutOrder = 11
	local chestButtons: { TextButton } = {}
	for i, zone in Config.Maps do
		local card = makeCard(list, 56, 11 + i)
		icon(card, "chest", 36, UDim2.fromOffset(0, 0))
		label(card, zone.emoji .. " <b>Cofre: " .. zone.name .. "</b>", UDim2.fromOffset(44, 0), UDim2.new(1, -234, 1, 0), 15, THEME.text)
		local button = makeButton(card, "", THEME.gold, UDim2.fromOffset(180, 38), function()
			sendAction("buyChest", i)
		end)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		chestButtons[i] = button
	end

	function refreshForja()
		for _, slot in Config.Slots do
			local row = rows[slot.id]
			local id = state.equipped[slot.id]
			local item = nil
			for _, it in state.inventory do
				if it.id == id then
					item = it
				end
			end
			if not item then
				row.text.Text = slot.emoji .. " <b>" .. slot.name .. "</b>: nada equipado"
				setButton(row.button, "—", false)
			elseif item.up >= Config.MAX_UPGRADE then
				row.text.Text = string.format("%s <b>%s</b>\n%s · ¡al máximo!", slot.emoji, itemName(item), Config.powerText(item))
				setButton(row.button, "✓ Máximo", false)
			else
				local nextItem = table.clone(item)
				nextItem.up += 1
				local cost = Config.upgradeCost(item)
				row.text.Text = string.format("%s <font color=\"#%s\"><b>%s</b></font>\n%s → <font color=\"#4ade80\"><b>%s</b></font>", slot.emoji, rarityOf(item).color:ToHex(), itemName(item), Config.powerText(item), Config.powerText(nextItem))
				setButton(row.button, "Mejorar · " .. Config.money(cost), state.gold >= cost, THEME.orange)
			end
		end
		for i, button in chestButtons do
			local price = Config.chestPrice(i)
			if state.unlockedMap < i then
				setButton(button, "🔒 Bloqueado", false)
			else
				setButton(button, Config.money(price), state.gold >= price, THEME.gold)
			end
		end
	end
end

---------------------------------------------------------------------
-- Pestaña: Tienda
---------------------------------------------------------------------
local refreshTienda: () -> ()
do
	local page = pages.tienda
	local list = scrollList(page, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	local passRows = {}
	local any = false
	label(list, "<b>Pases (para siempre)</b>", UDim2.new(), UDim2.new(1, -8, 0, 24), 16, THEME.gold).LayoutOrder = 0
	for i, pass in Config.Monetization.GamePasses do
		if pass.id ~= 0 then
			any = true
			local card = makeCard(list, 60, i)
			label(card, pass.emoji .. " <b>" .. pass.name .. "</b>\n" .. pass.desc, UDim2.new(), UDim2.new(1, -170, 1, 0), 14, THEME.text)
			local button = makeButton(card, "Comprar", THEME.green, UDim2.fromOffset(150, 40), function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.fromScale(1, 0.5)
			passRows[pass.key] = button
		end
	end
	label(list, "<b>Mejoras al momento</b>", UDim2.new(), UDim2.new(1, -8, 0, 24), 16, THEME.gold).LayoutOrder = 20
	for i, product in Config.Monetization.Products do
		if product.id ~= 0 and product.kind ~= "revive" then
			any = true
			local card = makeCard(list, 60, 20 + i)
			label(card, product.emoji .. " <b>" .. product.name .. "</b>\n" .. product.desc, UDim2.new(), UDim2.new(1, -170, 1, 0), 14, THEME.text)
			local button = makeButton(card, "Comprar", THEME.gold, UDim2.fromOffset(150, 40), function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.fromScale(1, 0.5)
		end
	end
	if not any then
		label(list, "🛠️ La tienda abrirá muy pronto. ¡Gracias por jugar!", UDim2.new(), UDim2.new(1, -8, 0, 40), 16, THEME.muted).LayoutOrder = 1
	end

	function refreshTienda()
		for key, button in passRows do
			local owned = state.bonuses[key] == true
			setButton(button, if owned then "✓ Ya lo tienes" else "Comprar", not owned, THEME.green)
		end
	end
end

---------------------------------------------------------------------
-- Pestaña: Diario
---------------------------------------------------------------------
local refreshDiario: () -> ()
do
	local page = pages.diario
	label(page, "<b>🎁 Recompensa diaria</b>  ·  entra cada día para mantener la racha. ¡El día 7 trae boost x2!", UDim2.new(), UDim2.new(1, 0, 0, 40), 16, THEME.gold)
	local days = create("Frame", {
		Parent = page,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	local dayCards = {}
	for i, minutes in Config.DAILY_MINUTES do
		local card = create("Frame", {
			Parent = days,
			Size = UDim2.fromOffset(92, 104),
			BackgroundColor3 = THEME.card,
			LayoutOrder = i,
		}, { corner(12), padding(6) })
		local cardStroke = stroke(THEME.stroke, 2)
		cardStroke.Parent = card
		label(card, "<b>Día " .. i .. "</b>", UDim2.new(), UDim2.new(1, 0, 0, 22), 15, THEME.text).TextXAlignment = Enum.TextXAlignment.Center
		local art = icon(card, if i == #Config.DAILY_MINUTES then "chest" else "coin", 36, UDim2.new(0.5, 0, 0, 24))
		art.AnchorPoint = Vector2.new(0.5, 0)
		local amount = label(card, minutes .. " min", UDim2.fromOffset(0, 62), UDim2.new(1, 0, 0, 30), 13, THEME.muted)
		amount.TextXAlignment = Enum.TextXAlignment.Center
		dayCards[i] = { card = card, stroke = cardStroke, amount = amount }
	end
	local claimButton = makeButton(page, "Recoger", THEME.green, UDim2.fromOffset(260, 54), function()
		sendAction("claimDaily")
	end)
	claimButton.AnchorPoint = Vector2.new(0.5, 0)
	claimButton.Position = UDim2.new(0.5, 0, 0, 180)
	local note = label(page, "", UDim2.fromOffset(0, 246), UDim2.new(1, 0, 0, 40), 14, THEME.muted)
	note.TextXAlignment = Enum.TextXAlignment.Center

	function refreshDiario()
		local perMinute = Config.goldPerMinute(state.unlockedMap)
		for i, card in dayCards do
			card.amount.Text = num(perMinute * Config.DAILY_MINUTES[i]) .. (if i == #Config.DAILY_MINUTES then "\n+ 🚀 boost" else "")
			local isToday = i == state.dailyDay
			card.stroke.Color = if isToday then THEME.gold else THEME.stroke
			card.card.BackgroundColor3 = if i < state.dailyDay or (isToday and not state.dailyAvailable) then darken(THEME.green, 0.5) else THEME.card
		end
		if state.dailyAvailable then
			setButton(claimButton, "Recoger " .. Config.money(state.dailyReward), true, THEME.green)
			note.Text = "La recompensa crece con tu mejor mapa desbloqueado."
		else
			setButton(claimButton, "✓ Recogida hoy", false)
			note.Text = "Vuelve mañana para el día " .. (state.dailyDay % #Config.DAILY_MINUTES + 1) .. "."
		end
	end
end

---------------------------------------------------------------------
-- Pestaña: Ajustes
---------------------------------------------------------------------
local refreshAjustes: () -> ()
local startTutorial: () -> ()
do
	local page = pages.ajustes
	local list = scrollList(page, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	local function row(order: number, text: string, buttonText: string, color: Color3, onClick: () -> ()): (TextLabel, TextButton)
		local card = makeCard(list, 56, order)
		local t = label(card, text, UDim2.new(), UDim2.new(1, -190, 1, 0), 15, THEME.text)
		local button = makeButton(card, buttonText, color, UDim2.fromOffset(170, 38), onClick)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		return t, button
	end
	local _, soundButton = row(1, "🔊 <b>Sonido</b>", "", THEME.blue, function()
		sendAction("setMuted", not muted)
		muted = not muted
	end)
	local _, autoSellButton = row(2, "♻️ <b>Vender solos los objetos Comunes</b>\n(si no mejoran lo que llevas)", "", THEME.blue, function()
		sendAction("setAutoSell", not state.settings.autoSell)
	end)
	local saveText = row(3, "💾 <b>Guardar partida</b>", "Guardar ahora", THEME.green, function()
		sendAction("saveNow")
	end)
	row(4, "🎓 <b>Tutorial</b>", "Repetir", THEME.accent, function()
		window.Visible = false
		startTutorial()
	end)
	local info = label(list, "", UDim2.new(), UDim2.new(1, -8, 0, 60), 13, THEME.muted)
	info.LayoutOrder = 10

	function refreshAjustes()
		setButton(soundButton, if muted then "🔇 Apagado" else "🔊 Encendido", true, if muted then THEME.card else THEME.blue)
		setButton(autoSellButton, if state.settings.autoSell then "✓ Activado" else "Desactivado", true, if state.settings.autoSell then THEME.green else THEME.card)
		saveText.Text = "💾 <b>Guardar partida</b>\n" .. (if not state.canSave then "<font color=\"#f87171\">Desactivado en esta prueba</font>" elseif state.saveOk == false then "<font color=\"#f87171\">Último guardado falló</font>" else "Se guarda sola cada minuto")
		info.Text = string.format("Partidas: %s · Victorias: %s · Enemigos derrotados: %s · Versión %s", num(state.totals.runs), num(state.totals.wins), num(state.totals.kills), state.version)
	end
end


function refreshWindow()
	if not state or not window.Visible then
		return
	end
	if currentTab == "jugar" then
		refreshJugar()
	elseif currentTab == "clases" then
		refreshClases()
	elseif currentTab == "mejoras" then
		refreshMejoras()
	elseif currentTab == "armas" then
		refreshArmas()
	elseif currentTab == "mochila" then
		refreshMochila()
	elseif currentTab == "forja" then
		refreshForja()
	elseif currentTab == "tienda" then
		refreshTienda()
	elseif currentTab == "diario" then
		refreshDiario()
	else
		refreshAjustes()
	end
end

---------------------------------------------------------------------
-- Tutorial (una vez por jugador; se puede repetir en Ajustes)
---------------------------------------------------------------------
do
	local STEPS = {
		{ "⚔️ ¡Bienvenido a Dungeon Ascend!", "Sobrevive a las oleadas de monstruos, vence al jefe y escapa por el portal con tus Coronas." },
		{ "▶ Jugar", "Pulsa JUGAR (o acércate a un portal), elige mapa y dificultad. Puedes jugar solo o crear un grupo con amigos." },
		{ "🗡️ Las armas atacan solas", "Tú solo te mueves y esquivas con Q, Shift o el botón 💨. ¡No te dejes rodear!" },
		{ "🌊 Oleadas", "Cada oleada trae más enemigos. Entre oleadas tienes unos segundos de respiro. En la última llega el jefe." },
		{ "💎 Sube de nivel", "Recoge los cristales morados. Al subir de nivel eliges 1 de 3 mejoras. Arma al nivel 5 + su mejora pareja = ¡EVOLUCIÓN!" },
		{ "🌳 Hazte más fuerte", "Con las Coronas compra ramas del Árbol de mejoras, abre el Cofre de armas para conseguir armas nuevas y desbloquea clases." },
	}
	local tutorialGui = create("ScreenGui", { Name = "DungeonTutorial", ResetOnSpawn = false, DisplayOrder = 8, Enabled = false, Parent = playerGui })
	local card = create("Frame", {
		Parent = tutorialGui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(480, 170),
		BackgroundColor3 = THEME.panel,
	}, { corner(14), stroke(THEME.gold, 3), padding(14) })
	autoScale(card)
	local title = label(card, "", UDim2.new(), UDim2.new(1, 0, 0, 30), 20, THEME.gold, true)
	local body = label(card, "", UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 70), 16, THEME.text)
	local stepLabel = label(card, "", UDim2.new(0, 0, 1, -36), UDim2.new(0.4, 0, 0, 36), 13, THEME.muted)
	local step = 1
	local nextButton: TextButton
	local function show()
		title.Text = STEPS[step][1]
		body.Text = STEPS[step][2]
		stepLabel.Text = "Paso " .. step .. " de " .. #STEPS
		setButton(nextButton, if step == #STEPS then "¡A jugar!" else "Siguiente ▶", true, THEME.green)
	end
	nextButton = makeButton(card, "Siguiente ▶", THEME.green, UDim2.fromOffset(170, 40), function()
		if step >= #STEPS then
			tutorialGui.Enabled = false
			sendAction("finishTutorial")
			return
		end
		step += 1
		show()
	end)
	nextButton.AnchorPoint = Vector2.new(1, 1)
	nextButton.Position = UDim2.fromScale(1, 1)
	function startTutorial()
		step = 1
		show()
		tutorialGui.Enabled = true
	end
end

---------------------------------------------------------------------
-- Cartas de mejora al subir de nivel
---------------------------------------------------------------------
local refreshOffer: () -> ()
do
	local offerGui = create("ScreenGui", { Name = "DungeonOffer", ResetOnSpawn = false, DisplayOrder = 7, Enabled = false, Parent = playerGui })
	local holder = create("Frame", {
		Parent = offerGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(4 * 200 + 3 * 12, 350),
		BackgroundTransparency = 1,
	})
	autoScale(holder)
	local title = label(holder, "¡Subes de nivel!", UDim2.new(), UDim2.new(1, 0, 0, 44), 36, THEME.gold, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = TITLE_FONT
	title.TextStrokeTransparency = 0.2
	local cardsFrame = create("Frame", {
		Parent = holder,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 236),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	local rerollButton = makeButton(holder, "🎲 Cambiar", THEME.card, UDim2.fromOffset(200, 44), function()
		sendAction("reroll")
	end)
	rerollButton.AnchorPoint = Vector2.new(0.5, 1)
	rerollButton.Position = UDim2.fromScale(0.5, 1)
	local lastSignature = ""

	local function describe(option: any): (string, string, Color3)
		if option.kind == "weapon" then
			local weapon = Config.Weapons[option.id]
			if option.level == 1 then
				return weapon.name, "¡NUEVA ARMA!\n" .. weapon.desc, THEME.blue
			end
			return weapon.name, "Nivel " .. option.level .. "\nMás daño y alcance", THEME.blue
		elseif option.kind == "evolve" then
			local evolution = Config.Weapons[option.id].evolution
			return evolution.name, "¡EVOLUCIÓN!\nTu " .. Config.Weapons[option.id].name .. " se transforma", THEME.gold
		elseif option.kind == "passive" then
			local passive = Config.Passives[option.id]
			return passive.name, (if option.level == 1 then "¡NUEVA!\n" else "Nivel " .. option.level .. "\n") .. passive.desc, THEME.green
		elseif option.kind == "gold" then
			return "Coronas", "Un puñado de Coronas extra", THEME.orange
		end
		return "Curación", "Recuperas toda la vida", THEME.red
	end

	-- Icono grande de cada carta
	local function optionIcon(option: any, px: number): Frame
		if option.kind == "weapon" or option.kind == "evolve" then
			return Icons.weapon(option.id, option.level, px)
		elseif option.kind == "passive" then
			return Icons.make(option.id, px, { bg = THEME.bg })
		elseif option.kind == "gold" then
			return Icons.make("coin", px, { glow = true })
		end
		return Icons.make("heart", px, { bg = THEME.bg })
	end

	function refreshOffer()
		local run = state and state.run
		local offer = run and run.offer
		offerGui.Enabled = offer ~= nil
		if not offer then
			lastSignature = ""
			return
		end
		local parts = {}
		for _, option in offer do
			table.insert(parts, option.kind .. tostring(option.id) .. tostring(option.level))
		end
		local signature = table.concat(parts, ",")
		setButton(rerollButton, "🎲 Cambiar (" .. run.rerolls .. ")", run.rerolls > 0, THEME.card)
		title.Text = if run.pending > 1 then "¡Subes de nivel! (" .. run.pending .. " mejoras)" else "¡Subes de nivel!"
		if signature == lastSignature then
			return
		end
		lastSignature = signature
		playSound("levelup")
		clearChildren(cardsFrame, "UIListLayout")
		for i, option in offer do
			local head, body, color = describe(option)
			local cardButton = makeButton(cardsFrame, "", darken(color, 0.55), UDim2.fromOffset(200, 236), function()
				sendAction("choose", i)
			end)
			cardButton.LayoutOrder = i
			cardButton:FindFirstChildOfClass("UIStroke").Color = lighten(color, 0.2)
			local art = optionIcon(option, 76)
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.new(0.5, 0, 0, 4)
			art.Parent = cardButton
			local headLabel = label(cardButton, "<b>" .. head .. "</b>", UDim2.fromOffset(0, 84), UDim2.new(1, 0, 0, 40), 18, THEME.text)
			headLabel.TextXAlignment = Enum.TextXAlignment.Center
			local bodyLabel = label(cardButton, body, UDim2.fromOffset(0, 126), UDim2.new(1, 0, 0, 64), 13, THEME.text)
			bodyLabel.TextXAlignment = Enum.TextXAlignment.Center
			bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
			-- Puntos de nivel (1 a 5) para armas y mejoras
			if (option.kind == "weapon" or option.kind == "passive") and option.level then
				local pips = create("Frame", {
					Parent = cardButton,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -4),
					Size = UDim2.fromOffset(5 * 18, 12),
					BackgroundTransparency = 1,
				}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
				for k = 1, Config.MAX_ITEM_LEVEL do
					create("Frame", {
						Parent = pips,
						Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = if k <= option.level then THEME.gold else Color3.fromRGB(40, 30, 20),
						LayoutOrder = k,
					}, { corner(6), stroke(Color3.fromRGB(20, 12, 6), 1) })
				end
			end
			-- Tecla para elegir
			label(cardButton, "<b>" .. i .. "</b>", UDim2.fromOffset(2, 2), UDim2.fromOffset(20, 20), 14, THEME.muted)
		end
	end
end

---------------------------------------------------------------------
-- Pantalla al caer en partida y resumen final
---------------------------------------------------------------------
local refreshDeath: () -> ()
local showSummary: (summary: any) -> ()
do
	local deathGui = create("ScreenGui", { Name = "DungeonDeath", ResetOnSpawn = false, DisplayOrder = 9, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
	local shadow = create("Frame", { Parent = deathGui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5 })
	local box = create("Frame", {
		Parent = shadow,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 220),
		BackgroundColor3 = THEME.panel,
	}, { corner(16), stroke(THEME.red, 3), padding(16) })
	autoScale(box)
	local title = label(box, "💀 Has caído", UDim2.new(), UDim2.new(1, 0, 0, 40), 28, THEME.red, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local info = label(box, "", UDim2.fromOffset(0, 46), UDim2.new(1, 0, 0, 70), 15, THEME.text)
	info.TextXAlignment = Enum.TextXAlignment.Center
	local revive = Config.ProductByKey.revive
	local reviveButton = makeButton(box, revive.emoji .. " Revivir", THEME.green, UDim2.new(0.5, -4, 0, 46), function()
		MarketplaceService:PromptProductPurchase(player, revive.id)
	end)
	reviveButton.Position = UDim2.new(0, 0, 1, -46)
	local leaveButton = makeButton(box, "Volver al lobby", THEME.card, UDim2.new(0.5, -4, 0, 46), function()
		sendAction("leaveRun")
	end)
	leaveButton.Position = UDim2.new(0.5, 4, 1, -46)
	local deadSince = 0

	function refreshDeath()
		local run = state and state.run
		local dead = run ~= nil and not run.alive
		if dead and not deathGui.Enabled then
			deadSince = os.clock()
		end
		deathGui.Enabled = dead
		if dead then
			reviveButton.Visible = revive.id ~= 0
			if revive.id == 0 then
				leaveButton.Position = UDim2.new(0.25, 0, 1, -46)
			end
			local left = math.max(0, 20 - (os.clock() - deadSince))
			info.Text = string.format("Tu equipo sigue luchando.\nSi no revives en %d s, vuelves al lobby con la mitad de las Coronas (%s).", math.ceil(left), Config.money(run.gold * Config.LOSS_GOLD_RATE))
		end
	end

	-- Resumen al terminar la partida
	local summaryGui = create("ScreenGui", { Name = "DungeonSummary", ResetOnSpawn = false, DisplayOrder = 11, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
	local back = create("Frame", { Parent = summaryGui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4 })
	local panel = create("Frame", {
		Parent = back,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 330),
		BackgroundColor3 = THEME.panel,
	}, { corner(16), stroke(THEME.gold, 3), padding(16) })
	autoScale(panel)
	local summaryTitle = label(panel, "", UDim2.new(), UDim2.new(1, 0, 0, 44), 30, THEME.gold, true)
	summaryTitle.TextXAlignment = Enum.TextXAlignment.Center
	summaryTitle.Font = TITLE_FONT
	summaryTitle.TextStrokeTransparency = 0.3
	local summaryBody = label(panel, "", UDim2.fromOffset(0, 52), UDim2.new(1, 0, 1, -110), 16, THEME.text)
	summaryBody.TextXAlignment = Enum.TextXAlignment.Center
	summaryBody.TextYAlignment = Enum.TextYAlignment.Top
	local okButton = makeButton(panel, "Continuar", THEME.green, UDim2.fromOffset(200, 46), function()
		summaryGui.Enabled = false
	end)
	okButton.AnchorPoint = Vector2.new(0.5, 1)
	okButton.Position = UDim2.fromScale(0.5, 1)

	function showSummary(summary: any)
		local map = Config.MapById[summary.map]
		local titles = { win = "🏆 ¡HAS ESCAPADO!", dead = "💀 Has caído", left = "🏳️ Partida abandonada" }
		summaryTitle.Text = titles[summary.result] or "Fin de la partida"
		summaryTitle.TextColor3 = if summary.result == "win" then THEME.gold else THEME.red
		local diff = Config.DifficultyById[summary.difficulty or "normal"] or Config.Difficulties[1]
		local lines = {
			map.emoji .. " " .. map.name .. "  ·  " .. string.format("<font color=\"#%s\">%s</font>", diff.color:ToHex(), diff.name),
			"🌊 Oleada " .. (summary.wave or 0) .. "   ·   ⏱️ " .. Config.formatClock(summary.time) .. "   ·   ⭐ Nivel " .. summary.level,
			"💀 Enemigos derrotados: " .. num(summary.kills),
			"👑 Coronas ganadas: <b>" .. num(summary.gold) .. "</b>" .. (if summary.result == "win" then " (+" .. math.floor(Config.WIN_BONUS * 100) .. " % por escapar)" else " (la mitad)"),
		}
		if summary.item then
			local rarity = Config.RarityById[summary.item.rarity]
			table.insert(lines, string.format("🎁 Cofre del jefe: <font color=\"#%s\"><b>%s</b> (%s)</font>", rarity.color:ToHex(), Config.Items[summary.item.def].name, rarity.name))
		end
		if summary.unlocked then
			local unlocked = Config.MapById[summary.unlocked]
			table.insert(lines, "🔓 ¡Nuevo mapa: " .. unlocked.emoji .. " " .. unlocked.name .. "!")
		end
		if summary.unlockedDifficulty then
			local unlockedDiff = Config.DifficultyById[summary.unlockedDifficulty]
			table.insert(lines, "🔓 ¡Nueva dificultad en este mapa: " .. unlockedDiff.name .. "!")
		end
		summaryBody.Text = table.concat(lines, "\n")
		summaryGui.Enabled = true
		playSound(if summary.result == "win" then "levelup" else "error")
	end
end

---------------------------------------------------------------------
-- Esquivar
---------------------------------------------------------------------
local function myCharacter(): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

function dash()
	if not state or not state.run or not state.run.alive then
		return
	end
	local now = os.clock()
	if now < dashReadyAt then
		return
	end
	local root, humanoid = myCharacter()
	if not root or not humanoid then
		return
	end
	dashReadyAt = now + Config.DASH_COOLDOWN
	swarmEvent:FireServer("dash")
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, -1)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e6
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = direction * 85
	velocity.Parent = root
	task.delay(0.2, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
	playSound("skill")
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Q or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift or key == Enum.KeyCode.ButtonB then
		dash()
	elseif state and state.run and state.run.offer then
		-- Elegir mejora con 1-4
		local choices = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
		local index = choices[key]
		if index and state.run.offer[index] then
			sendAction("choose", index)
		end
	end
end)

---------------------------------------------------------------------
-- Cámara: en partida se aleja para ver la horda
---------------------------------------------------------------------
local defaultZoom = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
local inRunCamera = false
local function updateCamera(inRun: boolean)
	if inRun == inRunCamera then
		return
	end
	inRunCamera = inRun
	if inRun then
		player.CameraMaxZoomDistance = 75
		player.CameraMinZoomDistance = 32
	else
		player.CameraMinZoomDistance = defaultZoom[1]
		player.CameraMaxZoomDistance = defaultZoom[2]
	end
end

---------------------------------------------------------------------
-- Eventos del servidor
---------------------------------------------------------------------
local firstState = true
-- Luz y ambiente del lugar donde está el jugador (solo lo ve él)
local currentAmbience = ""
local function updateAmbience(name: string)
	if name ~= currentAmbience then
		currentAmbience = name
		Ambience.apply(name)
	end
end

-- Cartel grande de oleada (aparece y se va solo)
local lastWave = 0
local bannerToken = 0
local function showBanner(title: string, sub: string, color: Color3, seconds: number)
	bannerToken += 1
	local token = bannerToken
	runHud.bannerTitle.Text = title
	runHud.bannerTitle.TextColor3 = color
	runHud.bannerSub.Text = sub
	runHud.banner.Visible = true
	runHud.bannerScale.Scale = 1.6
	TweenService:Create(runHud.bannerScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(seconds, function()
		if token == bannerToken then
			runHud.banner.Visible = false
		end
	end)
end

-- Ranuras de armas (icono + puntos de nivel) y mejoras pasivas
local lastSlots = ""
local function refreshSlots(run: any)
	local parts = {}
	for _, id in run.weaponOrder do
		table.insert(parts, id .. run.weapons[id])
	end
	table.insert(parts, "|")
	for _, id in run.passiveOrder do
		table.insert(parts, id .. run.passives[id])
	end
	local signature = table.concat(parts, ",")
	if signature == lastSlots then
		return
	end
	lastSlots = signature
	clearChildren(runHud.weapons, "UIListLayout")
	clearChildren(runHud.passives, "UIListLayout")
	for i, id in run.weaponOrder do
		local level = run.weapons[id]
		local slot = create("Frame", { Parent = runHud.weapons, Size = UDim2.fromOffset(52, 62), BackgroundTransparency = 1, LayoutOrder = i })
		Icons.weapon(id, level, 50).Parent = slot
		local pips = create("Frame", {
			Parent = slot,
			Position = UDim2.fromOffset(1, 52),
			Size = UDim2.fromOffset(50, 8),
			BackgroundTransparency = 1,
		}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local evolved = level > Config.MAX_ITEM_LEVEL
		for k = 1, Config.MAX_ITEM_LEVEL do
			create("Frame", {
				Parent = pips,
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = if evolved then Color3.fromRGB(250, 120, 20) elseif k <= level then THEME.gold else Color3.fromRGB(40, 30, 20),
				LayoutOrder = k,
			}, { corner(4) })
		end
	end
	for i, id in run.passiveOrder do
		local slot = create("Frame", { Parent = runHud.passives, Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, LayoutOrder = i })
		Icons.make(id, 32, { bg = THEME.bg }).Parent = slot
		local levelText = create("TextLabel", {
			Parent = slot,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = THEME.gold,
			Text = tostring(run.passives[id]),
			TextColor3 = Color3.fromRGB(40, 20, 0),
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			ZIndex = 20,
		}, { corner(8) })
		levelText.Name = "Nivel"
	end
	runHud.passivesHint.Visible = #run.passiveOrder == 0
end

local function refreshHud()
	local inRun = state.run ~= nil
	updateAmbience(if inRun then Config.Maps[state.run.mapIndex].id else "lobby")
	lobbyHud.panel.Visible = not inRun
	lobbyHud.play.Visible = not inRun
	menu.Visible = not inRun
	if inRun then
		window.Visible = false
	end
	lobbyHud.saveWarning.Visible = not state.canSave and not inRun
	for _, key in { "top", "bottom", "dash", "leave" } do
		runHud[key].Visible = inRun
	end
	updateCamera(inRun)
	if not inRun then
		local class = Config.ClassById[state.selectedClass]
		lobbyHud.gold.Text = num(state.gold) .. " <font size=\"15\" color=\"#d6be96\">Coronas</font>"
		lobbyHud.info.Text = class.emoji .. " " .. class.name .. (if state.boostLeft > 0 then "   ·   🚀 x2 " .. Config.formatTime(state.boostLeft) else "")
		runHud.boss.Visible = false
		runHud.banner.Visible = false
		lastWave = 0
		lastSlots = ""
		return
	end
	local run = state.run
	local diff = Config.Difficulties[run.difficulty or 1]
	runHud.wave.Text = if run.wave > 0 then "OLEADA " .. run.wave .. " / " .. run.waves else "¡PREPÁRATE!"
	runHud.clock.Text = Config.formatClock(run.time)
	runHud.kills.Text = num(run.kills)
	runHud.gold.Text = num(run.gold)
	runHud.xpFill.Size = UDim2.fromScale(math.clamp(run.xp / math.max(1, run.xpNeeded), 0, 1), 1)
	runHud.xpText.Text = "Nivel " .. run.level
	local map = Config.Maps[run.mapIndex]
	local lives = if run.lives > 0 then "  ·  💖 x" .. run.lives else ""
	if run.portal then
		runHud.info.Text = "🌀 ¡ENTRA EN EL PORTAL! Quedan " .. math.max(0, math.ceil(run.portal.left)) .. " s"
		runHud.info.TextColor3 = Color3.fromRGB(125, 211, 252)
	elseif run.boss then
		runHud.info.Text = "👑 ¡Derrota al jefe para abrir el portal!" .. lives
		runHud.info.TextColor3 = THEME.orange
	elseif run.wavePhase == "break" then
		runHud.info.Text = "⏳ Siguiente oleada en " .. math.ceil(run.breakLeft) .. " s · ¡recoge los cristales!" .. lives
		runHud.info.TextColor3 = THEME.gold
	else
		runHud.info.Text = map.emoji .. " " .. map.name .. " · " .. diff.name .. "  ·  quedan " .. num(run.waveLeft) .. " enemigos" .. lives
		runHud.info.TextColor3 = THEME.muted
	end
	-- Cartel al empezar una oleada nueva
	if run.wave ~= lastWave then
		if run.wave > lastWave and run.wave > 0 then
			if run.wave == run.waves then
				showBanner("OLEADA FINAL", "👑 ¡Llega " .. Config.Enemies[map.boss].name .. "!", THEME.red, 3)
			else
				showBanner("OLEADA " .. run.wave, map.emoji .. " " .. map.name .. " · " .. diff.name, THEME.gold, 2.4)
			end
			playSound("levelup")
		end
		lastWave = run.wave
	end
	runHud.boss.Visible = run.boss ~= nil
	if run.boss then
		runHud.bossFill.Size = UDim2.fromScale(math.clamp(run.boss.hp, 0, 1), 1)
		runHud.bossText.Text = run.boss.name
	end
	refreshSlots(run)
end

stateEvent.OnClientEvent:Connect(function(newState: any)
	local wasInRun = state and state.run ~= nil
	state = newState
	muted = newState.settings.muted == true
	SwarmView.setRun(newState.run)
	refreshHud()
	refreshOffer()
	refreshDeath()
	if newState.run and not wasInRun then
		dashReadyAt = 0
	end
	-- Puntos rojos del menú
	menuDots.diario.Visible = newState.dailyAvailable
	local better = false
	for _, item in newState.inventory do
		local def = Config.Items[item.def]
		local currentId = newState.equipped[def.slot]
		local current = nil
		for _, it in newState.inventory do
			if it.id == currentId then
				current = it
			end
		end
		if item.id ~= currentId and (not current or Config.itemPower(item) > Config.itemPower(current)) then
			better = true
			break
		end
	end
	menuDots.mochila.Visible = better
	local canUpgrade = false
	for _, node in Config.Tree do
		if Config.nodeAvailable(newState.tree, node) and newState.gold >= node.cost then
			canUpgrade = true
		end
	end
	menuDots.mejoras.Visible = canUpgrade
	menuDots.armas.Visible = #Config.weaponChestOdds(newState.weapons) > 0 and newState.gold >= newState.weaponChestPrice
	if firstState then
		firstState = false
		if not newState.tutorialDone then
			startTutorial()
		end
	end
	refreshWindow()
end)

notifyEvent.OnClientEvent:Connect(function(text: string, kind: string, body: any)
	if kind == "popup" then
		showPopup(text, body or "")
		playSound("loot")
	elseif kind == "summary" then
		showSummary(body)
	elseif kind == "loot_item" then
		local item = body.item
		local rarity = Config.RarityById[item.rarity]
		showToast("🎁 Nuevo: " .. Config.Items[item.def].name .. " (" .. rarity.name .. ")" .. (if body.better then " ⬆ ¡mejor que el tuyo!" else ""), "loot")
		playSound("loot")
	else
		showToast(text, kind)
		if kind == "loot" or kind == "boss" then
			playSound("loot")
		elseif kind == "error" then
			playSound("error")
		end
	end
end)

openMenuEvent.OnClientEvent:Connect(function(tab: string, mapId: string?)
	if mapId and Config.MapById[mapId] then
		local map = Config.MapById[mapId]
		if state and state.unlockedMap >= map.index then
			selectedMap = map.index
		else
			showToast("🔒 " .. map.name .. ": escapa antes del mapa anterior", "error")
		end
	end
	openWindow(tab)
end)

swarmEvent.OnClientEvent:Connect(function(enemies: buffer, gemAdds: { number }, gemRemoves: { number }, fx: { any })
	SwarmView.onSnapshot(enemies, gemAdds, gemRemoves, fx)
end)

---------------------------------------------------------------------
-- Cada fotograma: vida, recarga del esquive y la horda
---------------------------------------------------------------------
SwarmView.init(playSound)
RunService.RenderStepped:Connect(function(dt: number)
	SwarmView.update(dt)
	if not state or not state.run then
		return
	end
	local _, humanoid = myCharacter()
	if humanoid then
		runHud.hpFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
		runHud.hpText.Text = "❤️ " .. num(math.ceil(humanoid.Health)) .. " / " .. num(humanoid.MaxHealth)
		if humanoid.Health < lastHealth - 0.5 then
			runHud.flash.BackgroundTransparency = 0.78
			TweenService:Create(runHud.flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
		lastHealth = humanoid.Health
	else
		runHud.hpFill.Size = UDim2.fromScale(0, 1)
		runHud.hpText.Text = "❤️ 0"
	end
	local left = math.max(0, dashReadyAt - os.clock())
	runHud.dashCooldown.Size = UDim2.fromScale(1, left / Config.DASH_COOLDOWN)
	refreshDeath()
end)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()
