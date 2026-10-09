--[[
	Dibuja aviones con Frames (sin subir imágenes): de perfil para las tarjetas y vistos
	desde arriba para el mapa. Estilo dibujo animado: blanco, franja de color y cola de color.
	Solo los Frames «hoja» (sin hijos) llevan Rotation.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local create = Kit.create
local corner = Kit.corner
local C = Kit.C

local PlaneArt = {}

local DARK = Color3.fromRGB(52, 64, 92)
local GLASS = Color3.fromRGB(40, 70, 120)
local METAL = Color3.fromRGB(200, 208, 222)

local function part(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, props: { [string]: any }?): Frame
	return create("Frame", Kit.merge({
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color, BorderSizePixel = 0,
	}, props))
end

-- Avión de perfil dentro de `parent` (ocupa todo su tamaño; mejor con proporción 2:1)
function PlaneArt.side(parent: Instance, modelId: string): Frame
	local m = Config.PlaneById[modelId]
	local box = create("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		create("UIAspectRatioConstraint", { AspectRatio = 2 }),
	})
	local L = 0.86 * m.length -- largo del fuselaje
	local cx, cy = 0.5, 0.5
	local fh = 0.16 + 0.05 * m.length -- alto del fuselaje
	local nose, tail = cx - L / 2, cx + L / 2
	-- Sombra en el suelo
	local ground = part(box, cx, 0.9, L * 0.8, 0.05, Color3.new(0, 0, 0), { BackgroundTransparency = 0.85 })
	corner().Parent = ground
	-- Tren de aterrizaje
	for _, wx in { nose + L * 0.12, cx + L * 0.06 } do
		part(box, wx, cy + fh * 0.75, 0.012, fh * 0.6, DARK)
		local wheel = part(box, wx, cy + fh * 1.05, 0.03, 0.06, Color3.fromRGB(30, 34, 44))
		corner().Parent = wheel
	end
	-- Ala del fondo (más oscura)
	local wingY = m.highWing and cy - fh * 0.45 or cy + fh * 0.3
	local backWing = part(box, cx + 0.02, wingY - 0.02, L * 0.42, 0.035, METAL, { Rotation = -6 })
	corner().Parent = backWing
	-- Deriva (cola) de color
	local fin = part(box, tail - L * 0.1, cy - fh * 0.7, L * 0.12, fh * 1.25, m.livery, { Rotation = 22 })
	create("UICorner", { CornerRadius = UDim.new(0.25, 0), Parent = fin })
	-- Fuselaje
	local body = part(box, cx, cy, L, fh, C.white)
	corner().Parent = body
	-- Cono de cola que sube
	local cone = part(box, tail - L * 0.05, cy - fh * 0.12, L * 0.16, fh * 0.7, C.white, { Rotation = -10 })
	corner().Parent = cone
	-- Estabilizador horizontal
	local stab = part(box, tail - L * 0.06, cy - fh * 0.2, L * 0.16, 0.03, METAL)
	corner().Parent = stab
	-- Franja de color
	local stripe = part(box, cx + L * 0.02, cy + fh * 0.12, L * 0.82, fh * 0.16, m.livery)
	corner().Parent = stripe
	-- Cabina
	local glass = part(box, nose + L * 0.07, cy - fh * 0.18, L * 0.07, fh * 0.28, GLASS, { Rotation = -8 })
	create("UICorner", { CornerRadius = UDim.new(0.4, 0), Parent = glass })
	-- Puerta de carga
	local door = part(box, cx - L * 0.12, cy - fh * 0.05, L * 0.12, fh * 0.55, C.white)
	create("UICorner", { CornerRadius = UDim.new(0.2, 0), Parent = door })
	create("UIStroke", { Parent = door, Color = METAL, Thickness = 1.5 })
	-- Ala delantera y motores
	local wing = part(box, cx + 0.03, wingY + 0.02, L * 0.44, 0.04, Color3.fromRGB(176, 186, 204), { Rotation = -6 })
	corner().Parent = wing
	if m.props and m.engines == 1 then
		-- Hélice en el morro
		local disc = part(box, nose - 0.008, cy, 0.012, fh * 1.5, DARK, { BackgroundTransparency = 0.55 })
		corner().Parent = disc
		local hub = part(box, nose - 0.004, cy, 0.022, 0.044, DARK)
		corner().Parent = hub
	else
		local count = math.min(m.engines, 2)
		for i = 1, count do
			local ex = cx - L * 0.02 + (i - 1) * L * 0.16
			local ey = m.highWing and wingY + 0.06 or wingY + 0.075
			local len, high = (m.props and 0.1 or 0.13) * m.length, (m.props and 0.06 or 0.085)
			local alpha = i == 1 and 0 or 0.25
			local nacelle = part(box, ex, ey, len, high, METAL, { BackgroundTransparency = alpha })
			corner().Parent = nacelle
			if m.props then
				local disc = part(box, ex - len / 2, ey, 0.01, high * 2.4, DARK, { BackgroundTransparency = 0.6 + alpha })
				corner().Parent = disc
			else
				local intake = part(box, ex - len / 2 + 0.008, ey, 0.016, high * 0.8, DARK, { BackgroundTransparency = alpha })
				corner().Parent = intake
				local band = part(box, ex + len * 0.15, ey, len * 0.18, high, m.livery, { BackgroundTransparency = alpha })
				corner().Parent = band
			end
		end
	end
	return box
end

-- Avión visto desde arriba para el mapa. `size` en unidades de diseño.
-- No se gira: mira a la derecha o, con `left = true`, a la izquierda (más fiable que Rotation
-- en un contenedor con hijos).
function PlaneArt.top(parent: Instance, modelId: string, size: number, left: boolean, props: { [string]: any }?): Frame
	local m = Config.PlaneById[modelId]
	local holder = create("Frame", Kit.merge({
		Parent = parent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size * 0.8),
	}, props))
	local z = holder.ZIndex
	local function x(v: number): number
		return left and 1 - v or v
	end
	local shadow = part(holder, x(0.55), 0.62, 0.9, 0.18, Color3.new(0, 0, 0), { BackgroundTransparency = 0.78, ZIndex = z })
	corner().Parent = shadow
	local wing = part(holder, x(0.52), 0.5, 0.22, 0.96, C.white, { ZIndex = z })
	corner(4).Parent = wing
	local wingTip = part(holder, x(0.52), 0.5, 0.22, 0.96, m.livery, { ZIndex = z, BackgroundTransparency = 0.7 })
	corner(4).Parent = wingTip
	local stab = part(holder, x(0.12), 0.5, 0.12, 0.42, m.livery, { ZIndex = z })
	corner(3).Parent = stab
	local body = part(holder, 0.5, 0.5, 0.94, 0.2, C.white, { ZIndex = z })
	corner().Parent = body
	create("UIStroke", { Parent = body, Color = Color3.fromRGB(150, 160, 180), Thickness = 1 })
	local stripe = part(holder, 0.5, 0.5, 0.7, 0.07, m.livery, { ZIndex = z })
	corner().Parent = stripe
	local glass = part(holder, x(0.87), 0.5, 0.08, 0.12, GLASS, { ZIndex = z })
	corner().Parent = glass
	return holder
end

return PlaneArt
