--!strict
-- Estado compartido de la interfaz (ctx) y piezas reutilizables: etiquetas, botones, paneles, avisos, sonidos.
-- Diseño en unidades de 1280 × 720; un UIScale lo adapta a cada pantalla (ctx.scale).
-- Los paneles llevan un botón «Modal» para soltar el ratón en primera persona.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))

local Kit = {}

Kit.C = {
	ink = Color3.fromRGB(34, 26, 20),
	panel = Color3.fromRGB(40, 31, 24),
	panel2 = Color3.fromRGB(58, 45, 34),
	parchment = Color3.fromRGB(244, 233, 208),
	cream = Color3.fromRGB(255, 244, 220),
	gold = Color3.fromRGB(224, 182, 82),
	goldDark = Color3.fromRGB(150, 112, 40),
	green = Color3.fromRGB(96, 200, 120),
	red = Color3.fromRGB(222, 90, 80),
	blue = Color3.fromRGB(90, 150, 255),
	muted = Color3.fromRGB(196, 180, 150),
	black = Color3.fromRGB(0, 0, 0),
	white = Color3.fromRGB(255, 255, 255),
}

export type Ctx = {
	state: { [string]: any },
	lang: string,
	gui: ScreenGui,
	root: Frame,
	scale: number,
	touch: boolean,
	gamepad: boolean,
	panel: string?,
	refreshers: { () -> () },
	tickers: { (number) -> () },
	panels: { [string]: { open: () -> (), close: (() -> ())? } },
	input: { [string]: (...any) -> () },
	act: (string, any?, any?, any?) -> (boolean, { [string]: any }?),
	toast: (string, string?) -> (),
	openPanel: (string) -> (),
	closePanel: () -> (),
	keyName: (string) -> string,
	targets: { [string]: GuiObject },
	showResults: ({ [string]: any }) -> (),
	rebuild: () -> (),
}

Kit.ctx = {
	state = {},
	lang = "es",
	scale = 1,
	touch = false,
	gamepad = false,
	panel = nil,
	refreshers = {},
	tickers = {},
	panels = {},
	input = {},
	targets = {},
} :: any

function Kit.T(key: string, params: { [string]: any }?): string
	return Lang.t(Kit.ctx.lang, key, params)
end

---------------------------------------------------------------------
-- Piezas
---------------------------------------------------------------------
function Kit.corner(inst: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = inst
end

function Kit.stroke(inst: GuiObject, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Kit.C.goldDark
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
end

function Kit.pad(inst: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = inst
end

function Kit.list(inst: GuiObject, vertical: boolean, padding: number?, align: Enum.HorizontalAlignment?)
	local l = Instance.new("UIListLayout")
	l.FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, padding or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.Parent = inst
	return l
end

function Kit.frame(parent: Instance, size: UDim2, pos: UDim2?, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos or UDim2.new()
	f.BackgroundColor3 = color or Kit.C.panel
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Kit.label(parent: Instance, text: string, size: UDim2, pos: UDim2?, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos or UDim2.new()
	l.Text = text
	l.TextColor3 = Kit.C.cream
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 18
	l.TextWrapped = true
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

-- Botón con el estilo del juego. onClick recibe el botón.
function Kit.button(parent: Instance, text: string, size: UDim2, pos: UDim2?, onClick: (TextButton) -> (), props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos or UDim2.new()
	b.BackgroundColor3 = Kit.C.panel2
	b.AutoButtonColor = true
	b.Text = text
	b.TextColor3 = Kit.C.cream
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextWrapped = true
	b.BorderSizePixel = 0
	Kit.corner(b, 8)
	Kit.stroke(b, Kit.C.goldDark, 2)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	b.Activated:Connect(function()
		Kit.sound("ui")
		onClick(b)
	end)
	b.Parent = parent
	return b
end

---------------------------------------------------------------------
-- Paneles (ventanas sobre el juego; sueltan el ratón)
---------------------------------------------------------------------
export type Panel = { shell: Frame, card: Frame, body: Frame, title: TextLabel }

function Kit.panel(name: string, width: number, height: number, title: string): Panel
	local ctx = Kit.ctx
	local shell = Instance.new("Frame")
	shell.Name = "Panel_" .. name
	shell.Size = UDim2.fromScale(1, 1)
	shell.BackgroundTransparency = 1
	shell.Visible = false
	shell.ZIndex = 20
	shell.Parent = ctx.root
	-- Fondo oscuro: botón «Modal» (libera el ratón en primera persona y cierra al tocar fuera)
	local back = Instance.new("TextButton")
	back.Name = "Backdrop"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Kit.C.black
	back.BackgroundTransparency = 0.45
	back.AutoButtonColor = false
	back.Text = ""
	back.Modal = true
	back.ZIndex = 20
	back.Parent = shell
	back.Activated:Connect(function()
		ctx.closePanel()
	end)
	local card = Kit.frame(shell, UDim2.fromOffset(width, height), UDim2.new(0.5, -width / 2, 0.5, -height / 2), Kit.C.panel)
	card.Name = "Card"
	card.ZIndex = 21
	card.Active = true -- los clics dentro de la ventana no llegan al fondo (que la cierra)
	Kit.corner(card, 14)
	Kit.stroke(card, Kit.C.gold, 3)
	local t = Kit.label(card, title, UDim2.new(1, -110, 0, 44), UDim2.fromOffset(20, 10), {
		Font = Enum.Font.Garamond, TextSize = 32, TextColor3 = Kit.C.gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	})
	local close = Kit.button(card, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 10), function()
		ctx.closePanel()
	end, { ZIndex = 22, TextSize = 22 })
	close.Name = "Close"
	local body = Kit.frame(card, UDim2.new(1, -40, 1, -76), UDim2.fromOffset(20, 62), Kit.C.panel, 1)
	body.Name = "Body"
	body.ZIndex = 22
	return { shell = shell, card = card, body = body, title = t }
end

---------------------------------------------------------------------
-- Sonidos (Config.Sounds; "" = sin sonido)
---------------------------------------------------------------------
local soundCache: { [string]: Sound } = {}
Kit.sfxVolume = 0.6
function Kit.sound(name: string, pitch: number?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local s = soundCache[name]
	if not s then
		local newSound = Instance.new("Sound")
		newSound.Name = "Sfx_" .. name
		newSound.SoundId = id
		newSound.Parent = SoundService
		soundCache[name] = newSound
		s = newSound
	end
	local snd = s :: Sound
	snd.Volume = Kit.sfxVolume
	snd.PlaybackSpeed = pitch or 1
	snd:Play()
end

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
function Kit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Kit.viewport(): Vector2
	local cam = Workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

function Kit.localPlayer(): Player
	return Players.LocalPlayer
end

-- Formato 3.072 / 3,072
function Kit.num(n: number): string
	local s = tostring(math.floor(n))
	local sep = if Kit.ctx.lang == "es" then "." else ","
	local out = string.reverse(s):gsub("(%d%d%d)", "%1" .. sep)
	out = string.reverse(out)
	if string.sub(out, 1, 1) == sep then
		out = string.sub(out, 2)
	end
	return out
end

return Kit
