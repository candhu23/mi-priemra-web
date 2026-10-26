--[[
	Kit: piezas de interfaz reutilizables con el estilo del juego (guía: skill disenar-interfaz).
	- Todo se diseña en unidades de una pantalla BASE de 960×540; Kit.root() pone un UIScale que
	  ajusta a cualquier pantalla (mínimo 0,7 para que en el móvil se siga leyendo).
	- Colores SOLO de Config.Colors. Letra: FredokaOne (títulos, botones) y Builder Sans (texto).
	- Solo un UIScale por objeto: los botones se animan moviendo la cara, no con UIScale.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))

local Kit = {}
local C = Config.Colors
Kit.C = C
Kit.BASE = Vector2.new(960, 540)
Kit.FONT_TITLE = Font.fromEnum(Enum.Font.FredokaOne)
Kit.FONT_BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
Kit.FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

-- Estado compartido del cliente
Kit.ctx = { lang = "en", state = nil :: any, muted = false }

function Kit.T(key: string, params: { [string]: any }?): string
	return Lang.t(Kit.ctx.lang, key, params)
end

local SUFIJOS = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp" } -- la zona 9 pasa de 1e18
function Kit.fmtMoney(n: number): string
	n = n or 0
	if n < 10 and n ~= math.floor(n) then
		return string.format("$%.1f", math.floor(n * 10) / 10)
	end
	n = math.floor(n)
	if n < 1000 then
		return "$" .. n
	end
	local i = 1
	local v = n
	while v >= 1000 and i < #SUFIJOS do
		v /= 1000
		i += 1
	end
	-- Se recorta hacia abajo (nunca redondea hacia arriba: 999.999 sale «999K» y no «1000K»)
	local decimals = if v >= 100 then 0 elseif v >= 10 then 1 else 2
	local m = 10 ^ decimals
	v = math.floor(v * m + 1e-6) / m
	return string.format("$%." .. decimals .. "f%s", v, SUFIJOS[i])
end

-- Igual que fmtMoney pero sin «$» (para monedas 🪙)
function Kit.fmt(n: number): string
	return (string.gsub(Kit.fmtMoney(n), "%$", ""))
end

-- Segundos → «4:05»
function Kit.fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function Kit.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(instance :: any)[k] = v
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
local create = Kit.create

function Kit.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0) })
end

function Kit.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return create("UIStroke", { Color = color, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- Borde oscuro en el TEXTO (da contraste sobre colores vivos)
function Kit.textStroke(thickness: number?): UIStroke
	return create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = thickness or 2, Transparency = 0.55 })
end

-- Texto que se encoge para caber (nunca se corta): TextScaled con tope de tamaño
function Kit.fit(obj: TextLabel | TextButton, maxSize: number)
	local o = obj :: any
	o.TextScaled = true
	local c = o:FindFirstChildOfClass("UITextSizeConstraint") or create("UITextSizeConstraint", { Parent = o })
	c.MaxTextSize = maxSize
	c.MinTextSize = 9
end

function Kit.padding(l: number, r: number?, t: number?, b: number?): UIPadding
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l),
		PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l),
	})
end

function Kit.list(horizontal: boolean, gap: number, align: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return create("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left, VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

function Kit.tween(obj: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function merge(base: { [string]: any }, extra: { [string]: any }?): { [string]: any }
	if extra then
		for k, v in extra do
			base[k] = v
		end
	end
	return base
end

function Kit.label(parent: Instance?, text: string, size: number, color: Color3?, font: Font?, props: { [string]: any }?): TextLabel
	return create("TextLabel", merge({
		Parent = parent, BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color or C.ink,
		FontFace = font or Kit.FONT_BODY, Size = UDim2.new(1, 0, 0, size + 6), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, props))
end

function Kit.title(parent: Instance?, text: string, size: number, color: Color3?, props: { [string]: any }?): TextLabel
	return Kit.label(parent, text, size, color, Kit.FONT_TITLE, props)
end

function Kit.card(parent: Instance?, props: { [string]: any }?): Frame
	return create("Frame", merge({ Parent = parent, BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 64) }, props), {
		Kit.corner(14),
		Kit.stroke(C.panelDark, 2),
	})
end

---------------------------------------------------------------------
-- Botón «grueso»: base oscura debajo y cara de color encima (se hunde al pulsar)
---------------------------------------------------------------------
local STYLES = {
	orange = { C.orange, C.orangeDark },
	blue = { C.blue, C.blueDark },
	green = { C.green, C.greenDark },
	gold = { C.gold, C.goldDark },
	red = { C.red, C.redDark },
	white = { C.white, C.panelDark },
	grey = { C.grey, C.greyDark },
	purple = { C.purple, C.purpleDark },
}
local clickSound: Sound? = nil
local rareSound: Sound? = nil

function Kit.setupSounds(parent: Instance)
	clickSound = create("Sound", { Parent = parent, SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, PlaybackSpeed = 1.5 })
	-- Cría Legendaria/Mítica: el mismo sonido (seguro que existe en Roblox), más grave y más fuerte
	rareSound = create("Sound", { Parent = parent, SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, PlaybackSpeed = 0.8 })
end

function Kit.playRare()
	if rareSound and not Kit.ctx.muted then
		rareSound:Play()
	end
end

function Kit.button(parent: Instance?, text: string, style: string, size: UDim2, onClick: () -> (), props: { [string]: any }?): TextButton
	local colors = STYLES[style] or STYLES.orange
	local holder = create("Frame", merge({ Parent = parent, BackgroundColor3 = colors[2], Size = size, BorderSizePixel = 0 }, props), { Kit.corner(14) })
	local face = create("TextButton", {
		Name = "Face", Parent = holder, BackgroundColor3 = colors[1], Size = UDim2.new(1, 0, 1, -5), Text = text,
		TextColor3 = if style == "white" or style == "gold" then C.ink else C.white, FontFace = Kit.FONT_TITLE, TextSize = 20,
		AutoButtonColor = false, TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0,
	}, { Kit.corner(14), Kit.padding(8, 8, 0, 0) })
	if style ~= "white" and style ~= "gold" then
		Kit.textStroke(1.5).Parent = face
	end
	Kit.fit(face, 20)
	face:SetAttribute("Enabled", true)
	face:SetAttribute("Style", style)
	face.Activated:Connect(function()
		if face:GetAttribute("Enabled") == false then
			return
		end
		if clickSound and not Kit.ctx.muted then
			clickSound:Play()
		end
		face.Position = UDim2.fromOffset(0, 4)
		Kit.tween(face, 0.12, { Position = UDim2.fromOffset(0, 0) })
		onClick()
	end)
	return face
end

function Kit.setButton(face: TextButton, text: string?, enabled: boolean)
	if text and face.Text ~= text then
		face.Text = text
	end
	face:SetAttribute("Enabled", enabled)
	local style = face:GetAttribute("Style") :: string
	local colors = if enabled then (STYLES[style] or STYLES.orange) else STYLES.grey
	face.BackgroundColor3 = colors[1]
	local holder = face.Parent
	if holder and holder:IsA("Frame") then
		holder.BackgroundColor3 = colors[2]
	end
end

---------------------------------------------------------------------
-- Raíz escalada: todo lo que va dentro se diseña para 960×540
---------------------------------------------------------------------
function Kit.root(gui: ScreenGui): Frame
	local root = create("Frame", { Parent = gui, Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local scale = create("UIScale", { Parent = root })
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local v = camera.ViewportSize
		local s = math.clamp(math.min(v.X / Kit.BASE.X, v.Y / Kit.BASE.Y), 0.7, 1.25)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s) -- el Frame sigue llenando la pantalla tras escalar
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return root
end

return Kit
