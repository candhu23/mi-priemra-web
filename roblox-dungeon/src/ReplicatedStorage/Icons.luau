--[[
	Icons (ModuleScript en ReplicatedStorage)

	Iconos dibujados con formas de interfaz (círculos, barras giradas,
	degradados y bordes): moneda, cristal, calavera, reloj, corona, cada
	arma, cada mejora, las clases y los botones del menú. No necesitan subir
	imágenes a Roblox ni pasar moderación.

	Uso: Icons.make("coin", 32) → Frame de 32×32 px. Opciones:
	  { bg = Color3 }   círculo de fondo (p. ej. para armas evolucionadas)
	  { glow = true }   brillo dorado detrás
	Si algún día se suben imágenes, basta con poner su id en Icons.Images
	y se usará la imagen en vez del dibujo.
]]

local Icons = {}

-- Ids de imágenes subidas (opcional): Icons.Images.coin = "rbxassetid://123"
Icons.Images = {} :: { [string]: string }

type Ctx = { root: Frame, px: number, z: number }

---------------------------------------------------------------------
-- Formas básicas (coordenadas de 0 a 1 dentro del icono)
---------------------------------------------------------------------
local function shade(frame: GuiObject, amount: number?)
	local gradient = Instance.new("UIGradient")
	local a = amount or 0.25
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - a, 1 - a, 1 - a))
	gradient.Rotation = 90
	gradient.Parent = frame
end

local function shape(ctx: Ctx, cx: number, cy: number, w: number, h: number, color: Color3, opts: any?): Frame
	local o = opts or {}
	ctx.z += 1
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = o.transparency or 0
	f.BorderSizePixel = 0
	f.Rotation = o.rot or 0
	f.ZIndex = ctx.z
	if o.round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(o.round, 0)
		corner.Parent = f
	end
	if o.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = o.stroke
		stroke.Thickness = math.max(1, ctx.px * (o.strokeWidth or 0.05))
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Transparency = o.strokeTransparency or 0
		stroke.Parent = f
	end
	if o.shade ~= false then
		shade(f, if type(o.shade) == "number" then o.shade else nil)
	end
	f.Parent = ctx.root
	return f
end

local function circle(ctx: Ctx, cx: number, cy: number, d: number, color: Color3, opts: any?): Frame
	local o = table.clone(opts or {})
	o.round = 0.5
	return shape(ctx, cx, cy, d, d, color, o)
end

-- Anillo: círculo hueco (solo el borde)
local function ring(ctx: Ctx, cx: number, cy: number, d: number, color: Color3, width: number, transparency: number?): Frame
	local f = circle(ctx, cx, cy, d, color, { transparency = 1, stroke = color, strokeWidth = width, strokeTransparency = transparency, shade = false })
	return f
end

-- Barra de un punto a otro (para espadas, rayos, manos de reloj…)
local function stick(ctx: Ctx, x1: number, y1: number, x2: number, y2: number, thickness: number, color: Color3, opts: any?): Frame
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local o = table.clone(opts or {})
	o.rot = math.deg(math.atan2(dy, dx))
	o.round = o.round or 0.5
	return shape(ctx, (x1 + x2) / 2, (y1 + y2) / 2, length + thickness * 0.4, thickness, color, o)
end

-- Rombo (cuadrado girado 45°)
local function diamond(ctx: Ctx, cx: number, cy: number, size: number, color: Color3, opts: any?): Frame
	local o = table.clone(opts or {})
	o.rot = 45
	return shape(ctx, cx, cy, size * 0.707, size * 0.707, color, o)
end

local function shine(ctx: Ctx, cx: number, cy: number, d: number)
	circle(ctx, cx, cy, d, Color3.new(1, 1, 1), { transparency = 0.45, shade = false })
end

local function glyph(ctx: Ctx, text: string, color: Color3, size: number?)
	ctx.z += 1
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(size or 0.7, size or 0.7)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.ZIndex = ctx.z
	label.Parent = ctx.root
end

---------------------------------------------------------------------
-- Colores
---------------------------------------------------------------------
local GOLD = Color3.fromRGB(251, 191, 36)
local GOLD_DARK = Color3.fromRGB(161, 98, 7)
local STEEL = Color3.fromRGB(214, 222, 234)
local STEEL_DARK = Color3.fromRGB(71, 85, 105)
local WOOD = Color3.fromRGB(146, 94, 52)
local WOOD_DARK = Color3.fromRGB(84, 52, 30)
local RED = Color3.fromRGB(239, 68, 68)
local RED_DARK = Color3.fromRGB(127, 29, 29)
local WHITE = Color3.fromRGB(250, 250, 250)
local INK = Color3.fromRGB(30, 27, 46)

---------------------------------------------------------------------
-- Dibujos
---------------------------------------------------------------------
local DRAW: { [string]: (Ctx) -> () } = {}

-- Corona (la moneda del juego): moneda de oro con una coronita grabada
DRAW.coin = function(c)
	circle(c, 0.5, 0.5, 0.9, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.06 })
	circle(c, 0.5, 0.5, 0.66, Color3.fromRGB(245, 170, 20), { stroke = Color3.fromRGB(253, 224, 71), strokeWidth = 0.035 })
	for _, spot in { { 0.34, 0.46 }, { 0.5, 0.4 }, { 0.66, 0.46 } } do
		diamond(c, spot[1], spot[2], 0.16, GOLD_DARK, { shade = false })
	end
	shape(c, 0.5, 0.57, 0.38, 0.14, GOLD_DARK, { shade = false, round = 0.2 })
	shape(c, 0.5, 0.65, 0.38, 0.05, GOLD_DARK, { shade = false })
	shine(c, 0.3, 0.28, 0.16)
end

DRAW.gem = function(c)
	local purple = Color3.fromRGB(168, 85, 247)
	diamond(c, 0.5, 0.52, 0.86, purple, { stroke = Color3.fromRGB(88, 28, 135), strokeWidth = 0.05, round = 0.12 })
	diamond(c, 0.43, 0.45, 0.36, Color3.fromRGB(216, 180, 254), { shade = false, transparency = 0.15, round = 0.15 })
	shine(c, 0.62, 0.3, 0.12)
end

DRAW.heart = function(c)
	local color = RED
	diamond(c, 0.5, 0.58, 0.62, color, { stroke = RED_DARK, strokeWidth = 0.05, round = 0.1 })
	circle(c, 0.33, 0.38, 0.42, color, { stroke = RED_DARK, strokeWidth = 0.05 })
	circle(c, 0.67, 0.38, 0.42, color, { stroke = RED_DARK, strokeWidth = 0.05 })
	diamond(c, 0.5, 0.56, 0.56, color, { shade = false, round = 0.1 })
	shape(c, 0.5, 0.45, 0.5, 0.2, color, { shade = false })
	shine(c, 0.3, 0.33, 0.14)
end

DRAW.revive = function(c)
	DRAW.heart(c)
	stick(c, 0.5, 0.36, 0.5, 0.66, 0.11, WHITE, { shade = false })
	stick(c, 0.35, 0.51, 0.65, 0.51, 0.11, WHITE, { shade = false })
end

DRAW.skull = function(c)
	local bone = Color3.fromRGB(236, 232, 220)
	circle(c, 0.5, 0.42, 0.74, bone, { stroke = Color3.fromRGB(120, 113, 108), strokeWidth = 0.05 })
	shape(c, 0.5, 0.74, 0.44, 0.24, bone, { round = 0.3, stroke = Color3.fromRGB(120, 113, 108), strokeWidth = 0.05 })
	shape(c, 0.5, 0.64, 0.42, 0.14, bone, { shade = false })
	circle(c, 0.35, 0.45, 0.2, INK, { shade = false })
	circle(c, 0.65, 0.45, 0.2, INK, { shade = false })
	diamond(c, 0.5, 0.6, 0.09, INK, { shade = false })
	for _, x in { 0.4, 0.5, 0.6 } do
		shape(c, x, 0.78, 0.035, 0.12, Color3.fromRGB(120, 113, 108), { shade = false })
	end
end

DRAW.clock = function(c)
	circle(c, 0.5, 0.5, 0.86, WHITE, { stroke = Color3.fromRGB(59, 130, 246), strokeWidth = 0.09 })
	for k = 0, 3 do
		local a = k * math.pi / 2
		circle(c, 0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3, 0.06, STEEL_DARK, { shade = false })
	end
	stick(c, 0.5, 0.5, 0.5, 0.24, 0.07, INK, { shade = false })
	stick(c, 0.5, 0.5, 0.68, 0.6, 0.07, INK, { shade = false })
	circle(c, 0.5, 0.5, 0.1, RED, { shade = false })
end

DRAW.crown = function(c)
	for _, spot in { { 0.22, 0.48 }, { 0.5, 0.38 }, { 0.78, 0.48 } } do
		diamond(c, spot[1], spot[2], 0.36, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.04 })
		circle(c, spot[1], spot[2] - 0.17, 0.1, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.03 })
	end
	shape(c, 0.5, 0.66, 0.74, 0.3, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.05, round = 0.15 })
	circle(c, 0.5, 0.66, 0.14, RED, { stroke = RED_DARK, strokeWidth = 0.03 })
	circle(c, 0.28, 0.67, 0.09, Color3.fromRGB(56, 189, 248), { shade = false })
	circle(c, 0.72, 0.67, 0.09, Color3.fromRGB(56, 189, 248), { shade = false })
end

DRAW.star = function(c)
	diamond(c, 0.5, 0.5, 0.9, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.04 })
	shape(c, 0.5, 0.5, 0.64, 0.64, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.04 })
	circle(c, 0.5, 0.5, 0.42, Color3.fromRGB(253, 224, 71), { shade = false })
	shine(c, 0.42, 0.4, 0.14)
end

DRAW.chest = function(c)
	shape(c, 0.5, 0.64, 0.78, 0.42, WOOD, { stroke = WOOD_DARK, strokeWidth = 0.05, round = 0.08 })
	shape(c, 0.5, 0.38, 0.78, 0.28, Color3.fromRGB(168, 110, 62), { stroke = WOOD_DARK, strokeWidth = 0.05, round = 0.35 })
	shape(c, 0.5, 0.52, 0.8, 0.07, GOLD, { shade = false })
	shape(c, 0.5, 0.56, 0.16, 0.2, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.04, round = 0.2 })
	circle(c, 0.5, 0.57, 0.05, INK, { shade = false })
end

-- Armas ------------------------------------------------------------
local function blade(c, x1: number, y1: number, x2: number, y2: number, width: number, color: Color3)
	stick(c, x1, y1, x2, y2, width, color, { stroke = STEEL_DARK, strokeWidth = 0.035, round = 0.2 })
	diamond(c, x2, y2, width * 1.25, color, { shade = false })
	stick(c, x1, y1, x2, y2, width * 0.22, Color3.new(1, 1, 1), { shade = false, transparency = 0.35 })
end

DRAW.espada = function(c)
	blade(c, 0.3, 0.7, 0.8, 0.2, 0.14, STEEL)
	stick(c, 0.18, 0.58, 0.42, 0.82, 0.09, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.03 })
	stick(c, 0.3, 0.7, 0.16, 0.84, 0.09, WOOD, { stroke = WOOD_DARK, strokeWidth = 0.03 })
	circle(c, 0.14, 0.86, 0.12, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.03 })
end

DRAW.varita = function(c)
	local glow = Color3.fromRGB(196, 181, 253)
	circle(c, 0.7, 0.3, 0.46, Color3.fromRGB(167, 139, 250), { transparency = 0.6, shade = false })
	stick(c, 0.2, 0.84, 0.66, 0.36, 0.09, WOOD, { stroke = WOOD_DARK, strokeWidth = 0.03 })
	stick(c, 0.2, 0.84, 0.32, 0.72, 0.1, GOLD, { shade = false })
	stick(c, 0.7, 0.12, 0.7, 0.48, 0.07, glow, { shade = false })
	stick(c, 0.52, 0.3, 0.88, 0.3, 0.07, glow, { shade = false })
	diamond(c, 0.7, 0.3, 0.2, WHITE, { shade = false })
	circle(c, 0.86, 0.12, 0.08, glow, { shade = false })
	circle(c, 0.5, 0.14, 0.06, glow, { shade = false })
end

DRAW.dagas = function(c)
	for _, side in { -1, 1 } do
		local x1, x2 = 0.5 - side * 0.32, 0.5 + side * 0.22
		blade(c, x1, 0.8, x2, 0.26, 0.11, STEEL)
		stick(c, x1 - side * 0.1, 0.7, x1 + side * 0.08, 0.86, 0.07, Color3.fromRGB(120, 113, 108), { shade = false })
		circle(c, x1 - side * 0.05, 0.88, 0.1, RED, { stroke = RED_DARK, strokeWidth = 0.03 })
	end
end

DRAW.aura = function(c)
	local yellow = Color3.fromRGB(253, 224, 71)
	circle(c, 0.5, 0.5, 0.92, yellow, { transparency = 0.75, shade = false })
	ring(c, 0.5, 0.5, 0.82, Color3.fromRGB(250, 204, 21), 0.07)
	ring(c, 0.5, 0.5, 0.56, Color3.fromRGB(254, 240, 138), 0.05, 0.2)
	circle(c, 0.5, 0.5, 0.3, WHITE, { stroke = yellow, strokeWidth = 0.05 })
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		circle(c, 0.5 + math.cos(a) * 0.41, 0.5 + math.sin(a) * 0.41, 0.09, WHITE, { shade = false })
	end
end

DRAW.orbes = function(c)
	local blue = Color3.fromRGB(56, 189, 248)
	ring(c, 0.5, 0.5, 0.72, Color3.fromRGB(125, 211, 252), 0.035, 0.4)
	circle(c, 0.5, 0.5, 0.14, Color3.fromRGB(186, 230, 253), { shade = false })
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3 - math.pi / 2
		local x, y = 0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36
		circle(c, x, y, 0.3, blue, { stroke = Color3.fromRGB(3, 105, 161), strokeWidth = 0.04 })
		shine(c, x - 0.05, y - 0.05, 0.1)
	end
end

DRAW.rayo = function(c)
	local yellow = Color3.fromRGB(250, 204, 21)
	local pts = { { 0.62, 0.08 }, { 0.34, 0.52 }, { 0.6, 0.5 }, { 0.38, 0.92 } }
	for i = 1, #pts - 1 do
		stick(c, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.17, yellow, { stroke = Color3.fromRGB(161, 98, 7), strokeWidth = 0.04, round = 0.3 })
	end
	for i = 1, #pts - 1 do
		stick(c, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.06, Color3.fromRGB(254, 249, 195), { shade = false })
	end
end

DRAW.hacha = function(c)
	stick(c, 0.22, 0.86, 0.62, 0.22, 0.09, WOOD, { stroke = WOOD_DARK, strokeWidth = 0.03 })
	-- Hoja curvada: un círculo grande recortado por el mango
	shape(c, 0.68, 0.32, 0.34, 0.5, STEEL, { rot = 32, stroke = STEEL_DARK, strokeWidth = 0.05, round = 0.5 })
	shape(c, 0.56, 0.26, 0.2, 0.16, STEEL_DARK, { rot = 32, stroke = INK, strokeWidth = 0.03, round = 0.2 })
	stick(c, 0.7, 0.1, 0.9, 0.4, 0.04, Color3.new(1, 1, 1), { shade = false, transparency = 0.3 })
	circle(c, 0.22, 0.86, 0.1, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.03 })
end

DRAW.bomba = function(c)
	circle(c, 0.46, 0.58, 0.68, Color3.fromRGB(51, 51, 64), { stroke = INK, strokeWidth = 0.05 })
	shine(c, 0.33, 0.45, 0.16)
	shape(c, 0.64, 0.3, 0.18, 0.14, STEEL_DARK, { rot = 40, stroke = INK, strokeWidth = 0.03, round = 0.2 })
	stick(c, 0.68, 0.26, 0.82, 0.14, 0.05, WOOD, { shade = false })
	circle(c, 0.85, 0.11, 0.18, Color3.fromRGB(251, 146, 60), { shade = false, transparency = 0.2 })
	circle(c, 0.85, 0.11, 0.09, Color3.fromRGB(254, 240, 138), { shade = false })
end

DRAW.martillo = function(c)
	stick(c, 0.3, 0.9, 0.56, 0.36, 0.11, WOOD, { stroke = WOOD_DARK, strokeWidth = 0.03 })
	shape(c, 0.58, 0.3, 0.62, 0.32, STEEL_DARK, { rot = 25, stroke = INK, strokeWidth = 0.04, round = 0.12 })
	shape(c, 0.58, 0.3, 0.54, 0.1, Color3.fromRGB(148, 163, 184), { rot = 25, shade = false })
	shape(c, 0.58, 0.3, 0.12, 0.36, GOLD, { rot = 25, stroke = GOLD_DARK, strokeWidth = 0.03 })
	for k = 0, 2 do
		stick(c, 0.08 + k * 0.08, 0.66 + k * 0.08, 0.18 + k * 0.08, 0.6 + k * 0.08, 0.04, Color3.fromRGB(253, 186, 116), { shade = false })
	end
end

-- Menú y lobby ------------------------------------------------------
-- Árbol de mejoras: tres nodos unidos
DRAW.tree = function(c)
	local line = Color3.fromRGB(253, 224, 71)
	stick(c, 0.5, 0.76, 0.5, 0.46, 0.07, line, { shade = false })
	stick(c, 0.5, 0.46, 0.24, 0.24, 0.07, line, { shade = false })
	stick(c, 0.5, 0.46, 0.76, 0.24, 0.07, line, { shade = false })
	circle(c, 0.5, 0.78, 0.26, Color3.fromRGB(220, 38, 38), { stroke = RED_DARK, strokeWidth = 0.04 })
	circle(c, 0.24, 0.24, 0.26, Color3.fromRGB(37, 99, 235), { stroke = Color3.fromRGB(30, 58, 138), strokeWidth = 0.04 })
	circle(c, 0.76, 0.24, 0.26, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.04 })
	circle(c, 0.5, 0.46, 0.14, WHITE, { shade = false })
end

-- Castillo (mapas / jugar)
DRAW.castle = function(c)
	local stone = Color3.fromRGB(168, 162, 158)
	local dark = Color3.fromRGB(87, 83, 78)
	shape(c, 0.5, 0.66, 0.5, 0.48, stone, { stroke = dark, strokeWidth = 0.04 })
	for _, x in { 0.2, 0.8 } do
		shape(c, x, 0.58, 0.22, 0.64, stone, { stroke = dark, strokeWidth = 0.04 })
		diamond(c, x, 0.24, 0.24, Color3.fromRGB(185, 28, 28), { stroke = RED_DARK, strokeWidth = 0.03 })
	end
	for _, x in { 0.36, 0.5, 0.64 } do
		shape(c, x, 0.4, 0.09, 0.09, stone, { stroke = dark, strokeWidth = 0.03 })
	end
	shape(c, 0.5, 0.78, 0.18, 0.26, WOOD_DARK, { round = 0.5, shade = false })
	stick(c, 0.5, 0.14, 0.5, 0.34, 0.03, INK, { shade = false })
	shape(c, 0.58, 0.17, 0.14, 0.08, GOLD, { shade = false })
end

-- Pergamino (diario / misiones)
DRAW.scroll = function(c)
	local paper = Color3.fromRGB(254, 243, 199)
	shape(c, 0.5, 0.5, 0.6, 0.66, paper, { stroke = Color3.fromRGB(180, 140, 90), strokeWidth = 0.04 })
	shape(c, 0.5, 0.18, 0.76, 0.14, Color3.fromRGB(217, 180, 120), { stroke = Color3.fromRGB(146, 94, 52), strokeWidth = 0.04, round = 0.5 })
	shape(c, 0.5, 0.82, 0.76, 0.14, Color3.fromRGB(217, 180, 120), { stroke = Color3.fromRGB(146, 94, 52), strokeWidth = 0.04, round = 0.5 })
	for k = 0, 2 do
		shape(c, 0.5, 0.36 + k * 0.13, 0.4, 0.04, Color3.fromRGB(146, 94, 52), { shade = false })
	end
	circle(c, 0.66, 0.66, 0.16, RED, { stroke = RED_DARK, strokeWidth = 0.03 })
end

-- Cofre de armas (cofre con espada encima)
DRAW.weaponchest = function(c)
	DRAW.chest(c)
	stick(c, 0.26, 0.3, 0.74, 0.06, 0.07, STEEL, { stroke = STEEL_DARK, strokeWidth = 0.025 })
	stick(c, 0.34, 0.18, 0.4, 0.34, 0.05, GOLD, { shade = false })
end

-- Mejoras pasivas ---------------------------------------------------
local function badge(c, color: Color3)
	circle(c, 0.5, 0.5, 0.92, color, { stroke = color:Lerp(Color3.new(0, 0, 0), 0.45), strokeWidth = 0.05 })
	shine(c, 0.32, 0.28, 0.16)
end

DRAW.fuerza = function(c)
	badge(c, Color3.fromRGB(234, 88, 12))
	stick(c, 0.5, 0.78, 0.5, 0.34, 0.16, WHITE, { shade = false })
	diamond(c, 0.5, 0.3, 0.36, WHITE, { shade = false })
	shape(c, 0.5, 0.42, 0.42, 0.14, Color3.fromRGB(234, 88, 12), { shade = false })
	stick(c, 0.5, 0.78, 0.5, 0.42, 0.16, WHITE, { shade = false })
end

DRAW.rapidez = function(c)
	badge(c, Color3.fromRGB(59, 130, 246))
	circle(c, 0.56, 0.52, 0.56, WHITE, { stroke = INK, strokeWidth = 0.04 })
	stick(c, 0.56, 0.52, 0.56, 0.32, 0.06, INK, { shade = false })
	stick(c, 0.56, 0.52, 0.7, 0.58, 0.06, INK, { shade = false })
	for k = 0, 2 do
		stick(c, 0.12, 0.36 + k * 0.14, 0.26, 0.36 + k * 0.14, 0.05, WHITE, { shade = false })
	end
end

DRAW.area = function(c)
	badge(c, Color3.fromRGB(22, 163, 74))
	ring(c, 0.5, 0.5, 0.66, WHITE, 0.06)
	ring(c, 0.5, 0.5, 0.4, WHITE, 0.06)
	circle(c, 0.5, 0.5, 0.14, WHITE, { shade = false })
end

DRAW.vida = function(c)
	DRAW.heart(c)
end

DRAW.botas = function(c)
	local leather = Color3.fromRGB(146, 94, 52)
	shape(c, 0.4, 0.4, 0.26, 0.5, leather, { stroke = WOOD_DARK, strokeWidth = 0.04, round = 0.2 })
	shape(c, 0.52, 0.68, 0.52, 0.22, leather, { stroke = WOOD_DARK, strokeWidth = 0.04, round = 0.45 })
	shape(c, 0.52, 0.8, 0.56, 0.07, WOOD_DARK, { shade = false, round = 0.5 })
	shape(c, 0.4, 0.2, 0.3, 0.08, GOLD, { shade = false, round = 0.5 })
	for k = 0, 2 do
		stick(c, 0.06, 0.4 + k * 0.12, 0.2, 0.4 + k * 0.12, 0.05, Color3.fromRGB(147, 197, 253), { shade = false })
	end
end

DRAW.iman = function(c)
	local pts = { { 0.3, 0.22 }, { 0.3, 0.58 }, { 0.42, 0.76 }, { 0.58, 0.76 }, { 0.7, 0.58 }, { 0.7, 0.22 } }
	for i = 1, #pts - 1 do
		stick(c, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.17, RED, { stroke = RED_DARK, strokeWidth = 0.035, round = 0.3 })
	end
	for i = 1, #pts - 1 do
		stick(c, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.12, RED, { shade = false, round = 0.3 })
	end
	shape(c, 0.3, 0.2, 0.19, 0.12, STEEL, { stroke = STEEL_DARK, strokeWidth = 0.03 })
	shape(c, 0.7, 0.2, 0.19, 0.12, STEEL, { stroke = STEEL_DARK, strokeWidth = 0.03 })
end

DRAW.armadura = function(c)
	local steel = Color3.fromRGB(96, 165, 250)
	diamond(c, 0.5, 0.58, 0.6, steel, { stroke = Color3.fromRGB(30, 64, 175), strokeWidth = 0.05, round = 0.1 })
	shape(c, 0.5, 0.38, 0.66, 0.42, steel, { stroke = Color3.fromRGB(30, 64, 175), strokeWidth = 0.05, round = 0.18 })
	diamond(c, 0.5, 0.56, 0.54, steel, { shade = false, round = 0.1 })
	shape(c, 0.5, 0.46, 0.6, 0.2, steel, { shade = false })
	stick(c, 0.5, 0.26, 0.5, 0.68, 0.08, GOLD, { shade = false })
	stick(c, 0.33, 0.42, 0.67, 0.42, 0.08, GOLD, { shade = false })
end

DRAW.regeneracion = function(c)
	badge(c, Color3.fromRGB(34, 197, 94))
	stick(c, 0.5, 0.28, 0.5, 0.72, 0.17, WHITE, { shade = false, round = 0.2 })
	stick(c, 0.28, 0.5, 0.72, 0.5, 0.17, WHITE, { shade = false, round = 0.2 })
	circle(c, 0.76, 0.24, 0.1, Color3.fromRGB(187, 247, 208), { shade = false })
end

-- Menú ---------------------------------------------------------------
DRAW.play = function(c)
	badge(c, Color3.fromRGB(34, 197, 94))
	glyph(c, "▶", WHITE, 0.5)
end

DRAW.bag = function(c)
	shape(c, 0.5, 0.6, 0.7, 0.58, WOOD, { stroke = WOOD_DARK, strokeWidth = 0.05, round = 0.25 })
	shape(c, 0.5, 0.42, 0.72, 0.24, Color3.fromRGB(168, 110, 62), { stroke = WOOD_DARK, strokeWidth = 0.05, round = 0.3 })
	ring(c, 0.5, 0.2, 0.3, WOOD_DARK, 0.06)
	shape(c, 0.5, 0.5, 0.14, 0.14, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.03, round = 0.2 })
end

DRAW.hammer = function(c)
	stick(c, 0.24, 0.82, 0.62, 0.38, 0.11, WOOD, { stroke = WOOD_DARK, strokeWidth = 0.03 })
	shape(c, 0.64, 0.34, 0.5, 0.24, STEEL_DARK, { rot = -45, stroke = INK, strokeWidth = 0.04, round = 0.12 })
	shape(c, 0.64, 0.34, 0.42, 0.08, Color3.fromRGB(148, 163, 184), { rot = -45, shade = false })
	circle(c, 0.82, 0.14, 0.1, Color3.fromRGB(251, 146, 60), { shade = false })
	circle(c, 0.9, 0.3, 0.06, Color3.fromRGB(253, 186, 116), { shade = false })
end

DRAW.cart = function(c)
	stick(c, 0.08, 0.2, 0.2, 0.2, 0.07, STEEL_DARK, { shade = false })
	stick(c, 0.2, 0.2, 0.3, 0.62, 0.07, STEEL_DARK, { shade = false })
	shape(c, 0.56, 0.44, 0.58, 0.34, Color3.fromRGB(56, 189, 248), { stroke = Color3.fromRGB(3, 105, 161), strokeWidth = 0.05, round = 0.12 })
	stick(c, 0.3, 0.64, 0.84, 0.64, 0.07, STEEL_DARK, { shade = false })
	circle(c, 0.38, 0.8, 0.16, INK, { shade = false })
	circle(c, 0.76, 0.8, 0.16, INK, { shade = false })
	circle(c, 0.5, 0.36, 0.14, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.03 })
end

DRAW.gift = function(c)
	local box = Color3.fromRGB(236, 72, 153)
	shape(c, 0.5, 0.64, 0.7, 0.46, box, { stroke = Color3.fromRGB(131, 24, 67), strokeWidth = 0.05, round = 0.08 })
	shape(c, 0.5, 0.38, 0.8, 0.18, box, { stroke = Color3.fromRGB(131, 24, 67), strokeWidth = 0.05, round = 0.12 })
	shape(c, 0.5, 0.58, 0.14, 0.62, GOLD, { shade = false })
	circle(c, 0.38, 0.22, 0.22, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.04 })
	circle(c, 0.62, 0.22, 0.22, GOLD, { stroke = GOLD_DARK, strokeWidth = 0.04 })
end

DRAW.gear = function(c)
	local steel = Color3.fromRGB(148, 163, 184)
	for k = 0, 3 do
		shape(c, 0.5, 0.5, 0.2, 0.92, steel, { rot = k * 45, stroke = STEEL_DARK, strokeWidth = 0.035, round = 0.25 })
	end
	circle(c, 0.5, 0.5, 0.66, steel, { stroke = STEEL_DARK, strokeWidth = 0.05 })
	circle(c, 0.5, 0.5, 0.26, INK, { shade = false })
end

DRAW.shield = DRAW.armadura
DRAW.mago = DRAW.varita
DRAW.picaro = DRAW.dagas
DRAW.guerrero = DRAW.armadura
-- Mejoras permanentes
DRAW.velocidad = DRAW.botas
DRAW.recarga = DRAW.rapidez
DRAW.regen = DRAW.regeneracion
DRAW.oro = DRAW.coin
DRAW.corona = DRAW.coin
DRAW.normal = DRAW.skull
DRAW.forge = DRAW.hammer
DRAW.vidas = DRAW.revive

Icons.Names = {}
for name in DRAW do
	table.insert(Icons.Names, name)
end
table.sort(Icons.Names)

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
function Icons.has(name: string): boolean
	return DRAW[name] ~= nil or Icons.Images[name] ~= nil
end

-- Crea un icono de px × px. Devuelve un Frame transparente con el dibujo dentro.
function Icons.make(name: string, px: number, opts: any?): Frame
	local o = opts or {}
	local root = Instance.new("Frame")
	root.Name = "Icono_" .. name
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(px, px)
	root.ZIndex = o.zindex or 1
	local ctx: Ctx = { root = root, px = px, z = o.zindex or 1 }
	if o.glow then
		circle(ctx, 0.5, 0.5, 1.1, GOLD, { transparency = 0.55, shade = false })
	end
	if o.bg then
		circle(ctx, 0.5, 0.5, 1, o.bg, { stroke = o.bg:Lerp(Color3.new(0, 0, 0), 0.4), strokeWidth = 0.05 })
	end
	local image = Icons.Images[name]
	if image then
		ctx.z += 1
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = image
		img.ZIndex = ctx.z
		img.Parent = root
		return root
	end
	local draw = DRAW[name] or DRAW.star
	-- Con fondo, el dibujo va un poco más pequeño para que quepa dentro
	if o.bg then
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Size = UDim2.fromScale(0.72, 0.72)
		inner.ZIndex = ctx.z
		inner.Parent = root
		draw({ root = inner, px = px * 0.72, z = ctx.z })
	else
		draw(ctx)
	end
	return root
end

-- Icono de un arma según su nivel (evolucionada = fondo dorado)
function Icons.weapon(weaponId: string, level: number, px: number): Frame
	if level > 5 then
		return Icons.make(weaponId, px, { bg = Color3.fromRGB(120, 53, 15), glow = true })
	end
	return Icons.make(weaponId, px, { bg = Color3.fromRGB(46, 42, 68) })
end

return Icons
