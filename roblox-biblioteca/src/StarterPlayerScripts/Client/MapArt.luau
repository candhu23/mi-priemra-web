--!strict
-- Dibuja el mapa de una planta (el mismo dibujo en el tablón de la pared y en la ventana del mapa).
-- La entrada queda abajo y el fondo arriba, como lo ve el jugador al empezar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))

local MapArt = {}

local WOOD = Color3.fromRGB(122, 84, 52)
local DONE = Color3.fromRGB(70, 140, 255)
local PAPER = Color3.fromRGB(240, 228, 200)
local INK = Color3.fromRGB(60, 40, 26)

local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function text(parent: Instance, s: string, x: number, y: number, w: number, h: number, color: Color3, z: number?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(x, y)
	t.Size = UDim2.fromScale(w, h)
	t.Text = s
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.ZIndex = z or 2
	t.Parent = parent
	return t
end

-- Dibuja la planta `floor` (1 o 2) dentro de `frame` (relación 64 × 120). done[code] = sección completa.
-- Devuelve una función para poner el punto «tú» en una posición del mundo.
function MapArt.draw(frame: Frame, floor: number, done: { [string]: boolean }, labels: { [string]: string }): (Vector3?) -> ()
	for _, c in frame:GetChildren() do
		if not c:IsA("UIAspectRatioConstraint") and not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
	frame.BackgroundColor3 = PAPER
	local def = Layout.get("main")
	local function X(x: number): number
		return (x + 32) / 64
	end
	local function Z(z: number): number
		return (z + 120) / 120
	end
	-- Hueco central (planta 2) y escalera
	if floor == 2 then
		rect(frame, X(-18), Z(-106), 36 / 64, 92 / 120, Color3.fromRGB(70, 60, 50))
		text(frame, labels.void or "", X(-18), Z(-62), 36 / 64, 0.04, PAPER)
	end
	rect(frame, X(-4), Z(-106), 8 / 64, 36 / 120, Color3.fromRGB(150, 110, 70), 2)
	rect(frame, X(-6), Z(-92), 12 / 64, 8 / 120, Color3.fromRGB(170, 130, 85), 2)
	text(frame, labels.stairs or "", X(-6), Z(-90.5), 12 / 64, 0.035, INK, 3)
	if floor == 1 then
		rect(frame, X(-3.5), Z(-1.5), 7 / 64, 1.5 / 120, Color3.fromRGB(200, 60, 60), 2)
		text(frame, labels.door or "", X(-8), Z(-5), 16 / 64, 0.03, INK, 3)
	else
		local c = rect(frame, X(-5.6), Z(-88.8), 1.6 / 64, 1.6 / 120, Color3.fromRGB(80, 200, 255), 3)
		c.Name = "Crystal"
		text(frame, labels.crystal or "", X(-14), Z(-87), 12 / 64, 0.028, INK, 3)
	end
	-- Secciones
	for _, sec in def.sections do
		if sec.floor == floor then
			local b = sec.box
			local x0, x1, z0, z1 = b.min.X, b.max.X, b.min.Z, b.max.Z
			-- engorda el grosor para que se vea (las estanterías son finas)
			if x1 - x0 < 4 then
				if x0 < 0 then x1 = x0 + 4 else x0 = x1 - 4 end
			end
			if z1 - z0 < 4 then
				-- estanterías del fondo: engordan hacia dentro de la sala
				if z0 < -100 then z1 = z0 + 4 else z0 = z1 - 4 end
			end
			local f = rect(frame, X(x0), Z(z0), (x1 - x0) / 64, (z1 - z0) / 120, if done[sec.code] then DONE else WOOD, 2)
			f.Name = "Sec_" .. sec.code
			text(f, sec.code, 0, 0, 1, 1, Color3.fromRGB(255, 245, 225), 3)
		end
	end
	-- Punto «tú»
	local you = rect(frame, 0, 0, 0.035, 0.019, Color3.fromRGB(230, 40, 40), 5)
	you.Name = "You"
	you.AnchorPoint = Vector2.new(0.5, 0.5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = you
	return function(pos: Vector3?)
		if pos and Layout.floorAt(def, pos.Y - 3) == floor and pos.X > -40 and pos.X < 40 then
			you.Visible = true
			you.Position = UDim2.fromScale(X(pos.X), Z(pos.Z))
		else
			you.Visible = false
		end
	end
end

return MapArt
