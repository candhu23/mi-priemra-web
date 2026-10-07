--[[
	GameClient (LocalScript en StarterPlayer > StarterPlayerScripts)

	Toda la interfaz y los efectos de Dungeon Ascend:
	  · HUD: nivel, barra de XP, barra de vida y oro
	  · barra de habilidades (clic, Q, E, R) con tiempos de recarga
	  · menú lateral y ventana con pestañas: Mochila, Forja, Zonas,
	    Tienda, Diario y Ajustes
	  · números de daño, recompensas flotantes, efectos de habilidades,
	    aviso al subir de nivel, pantalla al caer y tutorial
	El cliente solo muestra cosas y pide acciones: el servidor decide.
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
local remotes = ReplicatedStorage:WaitForChild("DungeonRemotes")
local actionFunction = remotes:WaitForChild("Action") :: RemoteFunction
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local combatEvent = remotes:WaitForChild("Combat") :: RemoteEvent
local openMenuEvent = remotes:WaitForChild("OpenMenu") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Sin herramientas en este juego: ocultamos la barra de la mochila de Roblox
-- (así las teclas 1-4 son solo para las habilidades)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local THEME = {
	bg = Color3.fromRGB(17, 15, 28),
	panel = Color3.fromRGB(30, 27, 46),
	card = Color3.fromRGB(46, 42, 68),
	stroke = Color3.fromRGB(82, 76, 112),
	accent = Color3.fromRGB(139, 92, 246),
	green = Color3.fromRGB(34, 197, 94),
	yellow = Color3.fromRGB(234, 179, 8),
	gold = Color3.fromRGB(251, 191, 36),
	red = Color3.fromRGB(239, 68, 68),
	blue = Color3.fromRGB(59, 130, 246),
	orange = Color3.fromRGB(249, 115, 22),
	text = Color3.fromRGB(248, 250, 252),
	muted = Color3.fromRGB(161, 161, 190),
	disabled = Color3.fromRGB(71, 69, 92),
}
local SLOT_EMOJI = { weapon = "⚔️", armor = "🛡️", amulet = "📿" }
local num = Config.formatNumber

---------------------------------------------------------------------
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

local fxFolder = Instance.new("Folder")
fxFolder.Name = "EfectosLocales"
fxFolder.Parent = Workspace

local state: any = nil
local skillReadyAt: { [string]: number } = {}
local autoAttack = true

-- Variables compartidas entre bloques (se asignan más abajo)
local showToast: (text: string, kind: string?) -> ()
local showPopup: (title: string, body: string) -> ()
local openWindow: (tab: string) -> ()
local refreshWindow: () -> ()
local useSkill: (skillId: string) -> ()

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
				playSound("crit")
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
-- Efectos en el mundo (solo los ve este jugador)
---------------------------------------------------------------------
local fx: { [string]: any } = {}
do
	local random = Random.new()

	local function effectPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, transparency: number): Part
		return create("Part", {
			Parent = fxFolder,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
			Shape = shape,
			Size = size,
			CFrame = cframe,
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = transparency,
		})
	end

	local function fadeOut(part: BasePart, duration: number, goal: { [string]: any }?)
		local props = goal or {}
		props.Transparency = 1
		TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
		task.delay(duration + 0.05, function()
			part:Destroy()
		end)
	end

	-- Disco plano (los cilindros van a lo largo de X: se giran 90° en Z)
	local function disc(position: Vector3, diameter: number, color: Color3, transparency: number): Part
		return effectPart(Enum.PartType.Cylinder, Vector3.new(0.2, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, transparency)
	end

	function fx.floatingText(position: Vector3, text: string, color: Color3, size: number, duration: number)
		local anchor = effectPart(Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position + Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))), color, 1)
		local gui = create("BillboardGui", {
			Parent = anchor,
			Size = UDim2.fromOffset(size * 6, size * 1.6),
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 140,
		})
		local textLabel = create("TextLabel", {
			Parent = gui,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = color,
			TextStrokeTransparency = 0.2,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
		})
		TweenService:Create(gui, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
		TweenService:Create(textLabel, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, duration * 0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(duration + 0.05, function()
			anchor:Destroy()
		end)
	end

	function fx.attack(position: Vector3, look: Vector3?)
		local direction = look or Vector3.new(0, 0, -1)
		local center = position + direction * 4 + Vector3.new(0, -1.5, 0)
		fadeOut(disc(center, 11, Color3.fromRGB(226, 232, 240), 0.5), 0.2, { Size = Vector3.new(0.2, 14, 14) })
	end

	function fx.spin(position: Vector3)
		local skill = Config.SkillById.spin
		fadeOut(disc(position + Vector3.new(0, -2.4, 0), 4, Color3.fromRGB(167, 139, 250), 0.3), 0.35, { Size = Vector3.new(0.2, skill.radius * 2, skill.radius * 2) })
	end

	function fx.dash(position: Vector3, look: Vector3?)
		local direction = look or Vector3.new(0, 0, -1)
		local length = Config.SkillById.dash.length
		local center = position + direction * (length / 2)
		local part = effectPart(Enum.PartType.Block, Vector3.new(3, 0.4, length), CFrame.lookAt(center, center + direction), Color3.fromRGB(125, 211, 252), 0.35)
		fadeOut(part, 0.35, { Size = Vector3.new(0.2, 0.2, length) })
	end

	function fx.heal(position: Vector3)
		fadeOut(effectPart(Enum.PartType.Ball, Vector3.new(4, 4, 4), CFrame.new(position), THEME.green, 0.4), 0.5, { Size = Vector3.new(11, 11, 11) })
	end

	function fx.levelup(position: Vector3)
		local column = effectPart(Enum.PartType.Cylinder, Vector3.new(16, 6, 6), CFrame.new(position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)), THEME.gold, 0.35)
		fadeOut(column, 1, { Size = Vector3.new(30, 1, 1) })
	end

	function fx.slam(position: Vector3, radius: number?)
		local r = radius or 12
		fadeOut(disc(position + Vector3.new(0, 0.4, 0), 2, Color3.fromRGB(251, 146, 60), 0.2), 0.4, { Size = Vector3.new(0.2, r * 2.2, r * 2.2) })
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and (root.Position - position).Magnitude < r + 14 then
			task.spawn(function()
				for i = 1, 8 do
					humanoid.CameraOffset = Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5), 0) * (1 - i / 9)
					task.wait(0.03)
				end
				humanoid.CameraOffset = Vector3.new()
			end)
		end
	end

	function fx.death(position: Vector3, color: Color3?)
		for _ = 1, 6 do
			local cube = effectPart(Enum.PartType.Block, Vector3.new(0.8, 0.8, 0.8), CFrame.new(position), color or THEME.muted, 0.1)
			cube.Material = Enum.Material.SmoothPlastic
			local offset = Vector3.new(random:NextNumber(-5, 5), random:NextNumber(1, 5), random:NextNumber(-5, 5))
			fadeOut(cube, 0.6, { CFrame = CFrame.new(position + offset) * CFrame.Angles(random:NextNumber(0, 3), random:NextNumber(0, 3), 0), Size = Vector3.new(0.2, 0.2, 0.2) })
		end
	end
end

---------------------------------------------------------------------
-- HUD: nivel, XP, vida y oro
---------------------------------------------------------------------
local hud: { [string]: any } = {}
do
	local panel = create("Frame", {
		Parent = mainGui,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(330, 104),
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.1,
	}, { corner(14), stroke(THEME.stroke, 2) })
	autoScale(panel)
	local badge = create("TextLabel", {
		Parent = panel,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = THEME.accent,
		Text = "1",
		TextColor3 = THEME.text,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
	}, { corner(31), stroke(THEME.gold, 3), padding(10), shade() })
	label(panel, "NIVEL", UDim2.fromOffset(10, 74), UDim2.fromOffset(62, 20), 12, THEME.muted, true).TextXAlignment = Enum.TextXAlignment.Center
	local _, hpFill, hpText = makeBar(panel, UDim2.fromOffset(82, 12), UDim2.fromOffset(236, 24), THEME.red)
	local _, xpFill, xpText = makeBar(panel, UDim2.fromOffset(82, 42), UDim2.fromOffset(236, 18), THEME.accent)
	local gold = label(panel, "🪙 0", UDim2.fromOffset(82, 66), UDim2.fromOffset(140, 28), 20, THEME.gold, true)
	local boost = label(panel, "", UDim2.fromOffset(200, 66), UDim2.fromOffset(120, 28), 13, THEME.orange, true)
	boost.TextXAlignment = Enum.TextXAlignment.Right
	hud.badge = badge
	hud.hpFill = hpFill
	hud.hpText = hpText
	hud.xpFill = xpFill
	hud.xpText = xpText
	hud.gold = gold
	hud.boost = boost

	-- Aviso de guardado desactivado (Studio sin publicar)
	hud.saveWarning = create("TextLabel", {
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

	-- Destello rojo al recibir daño
	hud.flash = create("Frame", {
		Parent = flashGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.red,
		BackgroundTransparency = 1,
	})

	-- Cartel grande al subir de nivel
	hud.banner = create("TextLabel", {
		Parent = toastGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(520, 90),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = THEME.gold,
		TextStrokeTransparency = 0,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Visible = false,
	})
end

---------------------------------------------------------------------
-- Barra de habilidades
---------------------------------------------------------------------
local skillButtons: { [string]: any } = {}
local autoButton: TextButton
do
	local bar = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(4 * 84 + 3 * 10, 96),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	autoScale(bar)
	for i, skill in Config.Skills do
		local holder = create("Frame", {
			Parent = bar,
			Size = UDim2.fromOffset(84, if i == 1 then 96 else 84),
			BackgroundTransparency = 1,
			LayoutOrder = i,
		})
		local button = makeButton(holder, skill.emoji, if i == 1 then THEME.red else THEME.accent, UDim2.fromScale(1, 1), function()
			useSkill(skill.id)
		end)
		button:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 40
		local key = create("TextLabel", {
			Parent = button,
			Position = UDim2.new(0, 2, 1, -20),
			Size = UDim2.new(1, -4, 0, 18),
			BackgroundTransparency = 1,
			Text = skill.key,
			TextColor3 = THEME.text,
			TextStrokeTransparency = 0.4,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			ZIndex = 3,
		})
		local cooldown = create("Frame", {
			Parent = button,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 2,
		}, { corner(10) })
		local timer = create("TextLabel", {
			Parent = button,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = THEME.text,
			TextStrokeTransparency = 0.2,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			ZIndex = 4,
		}, { padding(16) })
		skillButtons[skill.id] = { button = button, key = key, cooldown = cooldown, timer = timer }
	end
	autoButton = makeButton(mainGui, "🤖 AUTO: SÍ", THEME.green, UDim2.fromOffset(130, 36), function()
		autoAttack = not autoAttack
	end)
	autoButton.AnchorPoint = Vector2.new(0.5, 1)
	autoButton.Position = UDim2.new(0.5, 0, 1, -118)
	autoButton.Visible = false
end

---------------------------------------------------------------------
-- Ventana principal con pestañas
---------------------------------------------------------------------
local window: Frame
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local currentTab = "mochila"
local TABS = {
	{ id = "mochila", name = "🎒 Mochila" },
	{ id = "forja", name = "🔨 Forja" },
	{ id = "zonas", name = "🗺️ Zonas" },
	{ id = "tienda", name = "🛒 Tienda" },
	{ id = "diario", name = "🎁 Diario" },
	{ id = "ajustes", name = "⚙️ Ajustes" },
}
do
	window = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 500),
		BackgroundColor3 = THEME.panel,
		Visible = false,
	}, { corner(16), stroke(THEME.accent, 2) })
	autoScale(window)
	local tabBar = create("Frame", {
		Parent = window,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -70, 0, 40),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, tab in TABS do
		local button = makeButton(tabBar, tab.name, THEME.card, UDim2.fromOffset(108, 38), function()
			openWindow(tab.id)
		end)
		button.LayoutOrder = i
		tabButtons[tab.id] = button
		pages[tab.id] = create("Frame", {
			Parent = window,
			Position = UDim2.fromOffset(12, 60),
			Size = UDim2.new(1, -24, 1, -72),
			BackgroundTransparency = 1,
			Visible = false,
		})
	end
	local close = makeButton(window, "✕", THEME.red, UDim2.fromOffset(40, 40), function()
		window.Visible = false
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)

	function openWindow(tab: string)
		currentTab = tab
		window.Visible = true
		for id, page in pages do
			page.Visible = id == tab
			setButton(tabButtons[id], tabButtons[id].Text, true, if id == tab then THEME.accent else THEME.card)
		end
		refreshWindow()
	end
end

-- Menú lateral
local menuDots: { [string]: Frame } = {}
do
	local menu = create("Frame", {
		Parent = mainGui,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.fromOffset(74, 6 * 62),
		BackgroundTransparency = 1,
	}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	autoScale(menu)
	for i, tab in TABS do
		local emoji = string.split(tab.name, " ")[1]
		local button = makeButton(menu, emoji, THEME.card, UDim2.fromOffset(62, 54), function()
			if window.Visible and currentTab == tab.id then
				window.Visible = false
			else
				openWindow(tab.id)
			end
		end)
		button.LayoutOrder = i
		button:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 30
		menuDots[tab.id] = create("Frame", {
			Parent = button,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = THEME.red,
			Visible = false,
			ZIndex = 5,
		}, { corner(8), stroke(THEME.text, 2) })
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
		setButton(sellButton, "Vender 🪙" .. num(Config.sellPrice(item)), not equipped, THEME.orange)
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
				slotLabels[slot.id].Text = slot.emoji .. " <b>" .. slot.name .. "</b>\n<font color=\"#a1a1be\">Vacío: consíguelo en las zonas</font>"
			end
		end
		local stats = state.stats
		statsLabel.Text = string.format("⚔️ Daño: <b>%s</b>\n❤️ Vida: <b>%s</b>\n📿 Oro y XP: <b>+%s %%</b>", num(stats.damage), num(stats.maxHealth), tostring(stats.bonusPct))
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
	label(list, "<b>🎁 Cofres del herrero</b>  ·  un objeto al azar de la zona (se paga con oro, no con Robux)", UDim2.new(), UDim2.new(1, -8, 0, 24), 16, THEME.gold).LayoutOrder = 10
	local odds = {}
	for _, rarity in Config.Rarities do
		table.insert(odds, string.format("<font color=\"#%s\">%s %s %%</font>", rarity.color:ToHex(), rarity.name, tostring(math.floor(Config.rarityChance(rarity.id, "chestWeight") * 1000 + 0.5) / 10)))
	end
	label(list, "Probabilidades: " .. table.concat(odds, " · "), UDim2.new(), UDim2.new(1, -8, 0, 36), 13, THEME.muted).LayoutOrder = 11
	local chestButtons: { TextButton } = {}
	for i, zone in Config.Zones do
		local card = makeCard(list, 56, 11 + i)
		label(card, zone.emoji .. " <b>Cofre: " .. zone.name .. "</b>", UDim2.fromOffset(0, 0), UDim2.new(1, -190, 1, 0), 15, THEME.text)
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
				setButton(row.button, "Mejorar 🪙" .. num(cost), state.gold >= cost, THEME.orange)
			end
		end
		for i, button in chestButtons do
			local price = Config.chestPrice(i)
			if state.unlockedZone < i then
				setButton(button, "🔒 Bloqueado", false)
			else
				setButton(button, "Comprar 🪙" .. num(price), state.gold >= price, THEME.gold)
			end
		end
	end
end

---------------------------------------------------------------------
-- Pestaña: Zonas
---------------------------------------------------------------------
local refreshZonas: () -> ()
do
	local page = pages.zonas
	local list = scrollList(page, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	local lobbyCard = makeCard(list, 52, 0)
	label(lobbyCard, "🏙️ <b>Ciudad</b>  ·  forja, tienda y portales", UDim2.new(), UDim2.new(1, -170, 1, 0), 15, THEME.text)
	local lobbyButton = makeButton(lobbyCard, "Volver", THEME.blue, UDim2.fromOffset(150, 34), function()
		sendAction("teleport", "lobby")
		window.Visible = false
	end)
	lobbyButton.AnchorPoint = Vector2.new(1, 0.5)
	lobbyButton.Position = UDim2.fromScale(1, 0.5)
	local rows = {}
	for i, zone in Config.Zones do
		local card = makeCard(list, 104, i, darken(zone.color, 0.72))
		local names = {}
		for _, enemyId in zone.enemies do
			table.insert(names, Config.Enemies[enemyId].name)
		end
		label(card, string.format("%s <b>%s</b>  ·  nivel recomendado %d", zone.emoji, zone.name, zone.level), UDim2.new(), UDim2.new(1, -170, 0, 24), 17, lighten(zone.color, 0.3))
		label(card, "Enemigos: " .. table.concat(names, ", ") .. "\n👑 Jefe: " .. Config.Enemies[zone.boss].name, UDim2.fromOffset(0, 26), UDim2.new(1, -170, 0, 40), 13, THEME.text)
		local status = label(card, "", UDim2.fromOffset(0, 66), UDim2.new(1, -170, 0, 18), 13, THEME.muted)
		local button = makeButton(card, "Viajar", THEME.green, UDim2.fromOffset(150, 44), function()
			sendAction("teleport", zone.id, nil, function(ok)
				if ok then
					window.Visible = false
				end
			end)
		end)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		rows[i] = { status = status, button = button }
	end

	function refreshZonas()
		for i, zone in Config.Zones do
			local row = rows[i]
			local unlocked = state.unlockedZone >= i
			local kills = state.bossKills[zone.id] or 0
			if unlocked then
				row.status.Text = if kills > 0 then "✅ Jefe vencido " .. kills .. " veces" else "⚔️ Vence al jefe para abrir la siguiente zona"
				setButton(row.button, "Viajar", true, THEME.green)
			else
				local previous = Config.Zones[i - 1]
				row.status.Text = "🔒 Vence a " .. Config.Enemies[previous.boss].name .. " para desbloquearla"
				setButton(row.button, "🔒 Bloqueada", false)
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
		label(card, if i == #Config.DAILY_MINUTES then "🪙 + 🚀" else "🪙", UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 34), 26, THEME.gold).TextXAlignment = Enum.TextXAlignment.Center
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
		local perMinute = Config.goldPerMinute(state.unlockedZone)
		for i, card in dayCards do
			card.amount.Text = "🪙" .. num(perMinute * Config.DAILY_MINUTES[i])
			local isToday = i == state.dailyDay
			card.stroke.Color = if isToday then THEME.gold else THEME.stroke
			card.card.BackgroundColor3 = if i < state.dailyDay or (isToday and not state.dailyAvailable) then darken(THEME.green, 0.5) else THEME.card
		end
		if state.dailyAvailable then
			setButton(claimButton, "Recoger 🪙" .. num(state.dailyReward), true, THEME.green)
			note.Text = "La recompensa crece con tu mejor zona desbloqueada."
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
		info.Text = string.format("Enemigos derrotados: %s · Versión %s", num(state.kills), state.version)
	end
end

function refreshWindow()
	if not state or not window.Visible then
		return
	end
	if currentTab == "mochila" then
		refreshMochila()
	elseif currentTab == "forja" then
		refreshForja()
	elseif currentTab == "zonas" then
		refreshZonas()
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
		{ "⚔️ ¡Bienvenido a Dungeon Ascend!", "Sube de nivel, consigue botín y vence a los jefes para abrir zonas nuevas." },
		{ "🌀 Los portales", "Camina hasta el portal del Bosque Encantado (al fondo de la plaza) o pulsa 🗺️ Zonas para viajar." },
		{ "⚔️ El combate", "Haz clic o pulsa el botón rojo para atacar. Q, E y R son habilidades que se desbloquean al subir de nivel." },
		{ "🎒 El botín", "Los enemigos sueltan armas, armaduras y amuletos. Equipa los que tengan la flecha verde ⬆ en la Mochila." },
		{ "🔨 La forja", "Mejora tu equipo con oro hasta +10. Es la clave para vencer a cada jefe." },
		{ "👑 Los jefes", "Esperan al fondo de cada zona. ¡Apártate de los círculos rojos del suelo! Con amigos es más fácil." },
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
-- Habilidades
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

function useSkill(skillId: string)
	local skill = Config.SkillById[skillId]
	if not skill or not state then
		return
	end
	if state.level < skill.level then
		showToast(skill.emoji .. " " .. skill.name .. " se desbloquea en el nivel " .. skill.level, "error")
		playSound("error")
		return
	end
	local now = os.clock()
	if now < (skillReadyAt[skill.id] or 0) then
		return
	end
	local root = myCharacter()
	if not root then
		return
	end
	skillReadyAt[skill.id] = now + skill.cooldown
	combatEvent:FireServer("skill", skill.id)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	if skill.kind == "dash" then
		-- Impulso hacia delante (el personaje lo mueve este cliente)
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.MaxForce = 1e6
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VectorVelocity = look * 90
		velocity.Parent = root
		task.delay(0.22, function()
			velocity:Destroy()
			attachment:Destroy()
		end)
	end
	local effect = fx[skill.id]
	if effect then
		effect(root.Position, look)
	end
	playSound(if skill.kind == "melee" then "hit" else "skill")
end

-- Ataque más cercano para el pase de auto-ataque
local function enemyNearby(radius: number): boolean
	local root = myCharacter()
	local folder = Workspace:FindFirstChild("Enemigos")
	if not root or not folder then
		return false
	end
	for _, model in folder:GetChildren() do
		local enemyRoot = model:IsA("Model") and model.PrimaryPart
		if enemyRoot then
			local offset = enemyRoot.Position - root.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
				return true
			end
		end
	end
	return false
end

local KEY_SKILLS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Q] = "spin",
	[Enum.KeyCode.E] = "dash",
	[Enum.KeyCode.R] = "heal",
	[Enum.KeyCode.One] = "attack",
	[Enum.KeyCode.Two] = "spin",
	[Enum.KeyCode.Three] = "dash",
	[Enum.KeyCode.Four] = "heal",
	[Enum.KeyCode.ButtonX] = "attack",
	[Enum.KeyCode.ButtonY] = "spin",
	[Enum.KeyCode.ButtonB] = "dash",
}

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		useSkill("attack")
		return
	end
	local skillId = KEY_SKILLS[input.KeyCode]
	if skillId then
		useSkill(skillId)
	end
end)

---------------------------------------------------------------------
-- Pantalla al caer
---------------------------------------------------------------------
local showDeath: (zoneId: string?, seconds: number) -> ()
do
	local deathGui = create("ScreenGui", { Name = "DungeonDeath", ResetOnSpawn = false, DisplayOrder = 9, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
	local shadow = create("Frame", { Parent = deathGui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5 })
	local box = create("Frame", {
		Parent = shadow,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(420, 200),
		BackgroundColor3 = THEME.panel,
	}, { corner(16), stroke(THEME.red, 3), padding(16) })
	autoScale(box)
	local title = label(box, "💀 Has caído", UDim2.new(), UDim2.new(1, 0, 0, 40), 28, THEME.red, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local info = label(box, "", UDim2.fromOffset(0, 46), UDim2.new(1, 0, 0, 50), 16, THEME.text)
	info.TextXAlignment = Enum.TextXAlignment.Center
	local revive = Config.ProductByKey.revive
	local reviveButton = makeButton(box, revive.emoji .. " Revivir aquí", THEME.green, UDim2.fromOffset(220, 46), function()
		MarketplaceService:PromptProductPurchase(player, revive.id)
	end)
	reviveButton.AnchorPoint = Vector2.new(0.5, 1)
	reviveButton.Position = UDim2.fromScale(0.5, 1)
	local token = 0
	function showDeath(zoneId: string?, seconds: number)
		token += 1
		local myToken = token
		reviveButton.Visible = revive.id ~= 0 and zoneId ~= nil
		deathGui.Enabled = true
		task.spawn(function()
			for left = math.ceil(seconds), 1, -1 do
				if token ~= myToken then
					return
				end
				info.Text = "Vuelves a la Ciudad en " .. left .. " s.\nTu equipo y tu nivel están a salvo."
				task.wait(1)
			end
			if token == myToken then
				deathGui.Enabled = false
			end
		end)
	end
	player.CharacterAdded:Connect(function()
		token += 1
		deathGui.Enabled = false
	end)
end

---------------------------------------------------------------------
-- Eventos del servidor
---------------------------------------------------------------------
local firstState = true
stateEvent.OnClientEvent:Connect(function(newState: any)
	local previous = state
	state = newState
	muted = newState.settings.muted == true
	hud.badge.Text = tostring(newState.level)
	hud.xpFill.Size = UDim2.fromScale(math.clamp(newState.xp / math.max(1, newState.xpNeeded), 0, 1), 1)
	hud.xpText.Text = if newState.level >= Config.MAX_LEVEL then "NIVEL MÁXIMO" else string.format("XP %s / %s", num(newState.xp), num(newState.xpNeeded))
	hud.gold.Text = "🪙 " .. num(newState.gold)
	hud.boost.Text = if newState.boostLeft > 0 then "🚀 x2 " .. Config.formatTime(newState.boostLeft) else ""
	hud.saveWarning.Visible = not newState.canSave
	autoButton.Visible = newState.bonuses.autoPass == true
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
	if previous and newState.gold > previous.gold and newState.gold - previous.gold >= 1 then
		hud.gold.TextColor3 = THEME.text
		TweenService:Create(hud.gold, TweenInfo.new(0.4), { TextColor3 = THEME.gold }):Play()
	end
	if firstState then
		firstState = false
		if not newState.tutorialDone then
			startTutorial()
		end
	end
	refreshWindow()
end)

notifyEvent.OnClientEvent:Connect(function(text: string, kind: string, body: string?)
	if kind == "popup" then
		showPopup(text, body or "")
		playSound("loot")
	else
		showToast(text, kind)
		if kind == "loot" then
			playSound("loot")
		elseif kind == "error" then
			playSound("error")
		end
	end
end)

openMenuEvent.OnClientEvent:Connect(function(tab: string)
	openWindow(tab)
end)

combatEvent.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any)
	if kind == "hits" then
		local crit = false
		for _, hit in a do
			fx.floatingText(hit.p, (if hit.c then "💥" else "") .. num(hit.d), if hit.c then THEME.orange else THEME.text, if hit.c then 34 else 26, 0.8)
			crit = crit or hit.c
		end
		if crit then
			playSound("crit")
		end
	elseif kind == "hurt" then
		hud.flash.BackgroundTransparency = 0.75
		TweenService:Create(hud.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	elseif kind == "reward" then
		fx.floatingText(a + Vector3.new(0, 2, 0), "+" .. num(b) .. " XP  +🪙" .. num(c), THEME.gold, 22, 1.2)
		playSound("coin")
	elseif kind == "loot" then
		local item = a
		local rarity = rarityOf(item)
		showToast("🎁 Nuevo: " .. Config.Items[item.def].name .. " (" .. rarity.name .. ")" .. (if b then " ⬆ ¡mejor que el tuyo!" else ""), "loot")
		playSound("loot")
		if rarity.index >= 4 then
			showPopup("🌟 ¡Objeto " .. rarity.name .. "!", Config.Items[item.def].name .. "\n" .. Config.powerText(item) .. "\n\nEquípalo en 🎒 Mochila.")
		end
	elseif kind == "levelup" then
		hud.banner.Text = "⭐ ¡NIVEL " .. tostring(a) .. "! ⭐"
		hud.banner.Visible = true
		hud.banner.TextTransparency = 0
		hud.banner.TextStrokeTransparency = 0
		playSound("levelup")
		task.delay(1.6, function()
			TweenService:Create(hud.banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end)
	elseif kind == "died" then
		showDeath(a, b or Config.RESPAWN_TIME)
	elseif kind == "fx" then
		local source = d
		local skill = Config.SkillById[a]
		if skill and source == player.UserId then
			return -- ya lo dibujamos al pulsar
		end
		local effect = fx[a]
		if effect then
			effect(b, c)
		end
	end
end)

---------------------------------------------------------------------
-- Cada fotograma: vida, recargas y auto-ataque
---------------------------------------------------------------------
local lastAutoCheck = 0
RunService.RenderStepped:Connect(function()
	local _, humanoid = myCharacter()
	if humanoid then
		hud.hpFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
		hud.hpText.Text = "❤️ " .. num(math.ceil(humanoid.Health)) .. " / " .. num(humanoid.MaxHealth)
	else
		hud.hpFill.Size = UDim2.fromScale(0, 1)
		hud.hpText.Text = "❤️ 0"
	end
	if not state then
		return
	end
	local now = os.clock()
	for _, skill in Config.Skills do
		local widgets = skillButtons[skill.id]
		local locked = state.level < skill.level
		local left = math.max(0, (skillReadyAt[skill.id] or 0) - now)
		widgets.cooldown.Size = UDim2.fromScale(1, if locked then 1 else left / skill.cooldown)
		widgets.timer.Text = if locked then "🔒" .. skill.level elseif left > 0.95 then tostring(math.ceil(left)) else ""
	end
	if state.bonuses.autoPass then
		setButton(autoButton, if autoAttack then "🤖 AUTO: SÍ" else "🤖 AUTO: NO", true, if autoAttack then THEME.green else THEME.card)
		if autoAttack and now - lastAutoCheck > 0.1 then
			lastAutoCheck = now
			if now >= (skillReadyAt.attack or 0) and enemyNearby(Config.SkillById.attack.radius) then
				useSkill("attack")
			end
		end
	end
end)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()
