--!nonstrict
--[[
	Animar: «jugosidad» para la interfaz de Roblox (TweenService), lista para usar.
	Ponlo en ReplicatedStorage (ModuleScript «Animar») y úsalo desde LocalScripts:

		local Animar = require(ReplicatedStorage.Animar)
		Animar.aparecer(ventana)                 -- entra con rebote
		Animar.sacudir(botonComprar)             -- «no tienes dinero»
		local parar = Animar.latir(botonRegalo)  -- late hasta que llames parar()
		Animar.contar(etiqueta, 0, 1500, Animar.formatoCorto)
		Animar.textoFlotante(lienzo, "+250", posicion, Color3.fromRGB(255, 210, 60))
		Animar.confeti(lienzo)

	Reglas:
	- Las animaciones de tamaño usan un UIScale propio llamado «AnimEscala». Si el objeto ya tiene
	  OTRO UIScale (p. ej. de la escala de pantalla), anima un Frame contenedor, no ese objeto.
	- Nada de UIGradient en objetos con texto (tiñe las letras): Animar.brillo() solo en Frames/imágenes.
	- Todas las funciones que repiten devuelven una función para PARARLAS. Llámala al cerrar la pantalla.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Animar = {}

export type Parar = () -> ()

-- Tween corto: Animar.tw(obj, 0.2, { Position = ... }, "Back", "Out")
function Animar.tw(obj: Instance, segundos: number, props: { [string]: any }, estilo: string?, dir: string?): Tween
	local info = TweenInfo.new(
		segundos,
		(Enum.EasingStyle :: any)[estilo or "Quad"],
		(Enum.EasingDirection :: any)[dir or "Out"]
	)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

-- UIScale propio de las animaciones (uno por objeto)
function Animar.escala(obj: GuiObject): UIScale
	local e = obj:FindFirstChild("AnimEscala")
	if e and e:IsA("UIScale") then
		return e
	end
	local nuevo = Instance.new("UIScale")
	nuevo.Name = "AnimEscala"
	nuevo.Parent = obj
	return nuevo
end

-- Entra creciendo con rebote (ventanas, premios)
function Animar.aparecer(obj: GuiObject, segundos: number?)
	local e = Animar.escala(obj)
	obj.Visible = true
	e.Scale = 0.3
	return Animar.tw(e, segundos or 0.3, { Scale = 1 }, "Back", "Out")
end

-- Sale encogiendo y se oculta (o se destruye si destruir = true)
function Animar.desaparecer(obj: GuiObject, destruir: boolean?, segundos: number?)
	local e = Animar.escala(obj)
	local t = Animar.tw(e, segundos or 0.15, { Scale = 0 }, "Quad", "In")
	t.Completed:Connect(function()
		if destruir then
			obj:Destroy()
		else
			obj.Visible = false
			e.Scale = 1
		end
	end)
	return t
end

-- Saltito al pulsar (encoge y vuelve)
function Animar.pulsar(obj: GuiObject)
	local e = Animar.escala(obj)
	local t = Animar.tw(e, 0.06, { Scale = 0.9 })
	t.Completed:Connect(function()
		Animar.tw(e, 0.18, { Scale = 1 }, "Back", "Out")
	end)
end

-- Sacudida horizontal («no puedes», error)
function Animar.sacudir(obj: GuiObject, fuerza: number?)
	local origen = obj.Position
	local f = fuerza or 10
	task.spawn(function()
		for _, dx in { f, -f, f * 0.6, -f * 0.6, f * 0.3, 0 } do
			obj.Position = origen + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		obj.Position = origen
	end)
end

-- Latido continuo (llama la atención: regalo listo, misión completa). Devuelve parar()
function Animar.latir(obj: GuiObject, cantidad: number?, periodo: number?): Parar
	local e = Animar.escala(obj)
	local info = TweenInfo.new((periodo or 0.9) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local t = TweenService:Create(e, info, { Scale = 1 + (cantidad or 0.08) })
	t:Play()
	return function()
		t:Cancel()
		e.Scale = 1
	end
end

-- Balanceo (rotación de lado a lado), p. ej. un huevo que va a abrirse. Devuelve parar()
function Animar.balancear(obj: GuiObject, grados: number?, periodo: number?): Parar
	local g = grados or 8
	obj.Rotation = -g
	local info = TweenInfo.new((periodo or 0.5) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local t = TweenService:Create(obj, info, { Rotation = g })
	t:Play()
	return function()
		t:Cancel()
		obj.Rotation = 0
	end
end

-- Flotar arriba y abajo (iconos, flechas de tutorial). Devuelve parar()
function Animar.flotar(obj: GuiObject, px: number?, periodo: number?): Parar
	local origen = obj.Position
	local info = TweenInfo.new((periodo or 1.2) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local t = TweenService:Create(obj, info, { Position = origen - UDim2.fromOffset(0, px or 8) })
	t:Play()
	return function()
		t:Cancel()
		obj.Position = origen
	end
end

-- Girar sin parar (rayos detrás de un premio). Devuelve parar()
function Animar.girar(obj: GuiObject, vueltasPorSegundo: number?): Parar
	local vps = vueltasPorSegundo or 0.15
	local con = RunService.RenderStepped:Connect(function(dt)
		obj.Rotation = (obj.Rotation + 360 * vps * dt) % 360
	end)
	return function()
		con:Disconnect()
	end
end

-- Formato corto de números (1.5K, 2.3M…)
local SUF = { "", "K", "M", "B", "T", "Qa", "Qi" }
function Animar.formatoCorto(n: number): string
	if math.abs(n) < 1000 then
		return tostring(math.floor(n))
	end
	local i = 1
	while math.abs(n) >= 1000 and i < #SUF do
		n /= 1000
		i += 1
	end
	return (string.gsub(string.format("%.1f", n), "%.0$", "")) .. SUF[i]
end

-- Cuenta de un número a otro en la etiqueta (premios, totales)
function Animar.contar(label: TextLabel, desde: number, hasta: number, formato: ((number) -> string)?, segundos: number?)
	local fmt = formato or function(x: number): string
		return tostring(math.floor(x))
	end
	local v = Instance.new("NumberValue")
	v.Value = desde
	label.Text = fmt(desde)
	v.Changed:Connect(function(x)
		label.Text = fmt(x)
	end)
	local t = Animar.tw(v, segundos or 0.6, { Value = hasta }, "Quad", "Out")
	t.Completed:Connect(function()
		label.Text = fmt(hasta)
		v:Destroy()
	end)
	return t
end

-- Texto que sube y se desvanece («+250», «¡CRÍTICO!»). posicion: UDim2 dentro del lienzo
function Animar.textoFlotante(lienzo: Instance, texto: string, posicion: UDim2, color: Color3?, tamano: number?)
	local l = Instance.new("TextLabel")
	l.Name = "TextoFlotante"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = posicion
	l.Size = UDim2.fromOffset(300, 60)
	l.Text = texto
	l.TextSize = tamano or 36
	l.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	l.TextColor3 = color or Color3.fromRGB(255, 220, 70)
	l.ZIndex = 90
	local trazo = Instance.new("UIStroke")
	trazo.Thickness = 3
	trazo.Color = Color3.fromRGB(20, 20, 30)
	trazo.Parent = l
	l.Rotation = math.random(-8, 8)
	l.Parent = lienzo
	Animar.aparecer(l, 0.2)
	local t = Animar.tw(l, 0.9, { Position = posicion - UDim2.fromOffset(0, 90), TextTransparency = 1 }, "Quad", "Out")
	Animar.tw(trazo, 0.9, { Transparency = 1 }, "Quad", "Out")
	t.Completed:Connect(function()
		l:Destroy()
	end)
end

-- Brillo que cruza un Frame/ImageLabel SIN texto (tarjetas legendarias, botón de la tienda).
-- Devuelve parar(). Usa UIGradient: nunca lo pongas en un objeto con texto.
function Animar.brillo(obj: GuiObject, cadaSegundos: number?): Parar
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		warn("Animar.brillo: no se usa en objetos con texto (tiñe las letras). Úsalo en un Frame de fondo.")
		return function() end
	end
	local capa = Instance.new("Frame")
	capa.Name = "Brillo"
	capa.BackgroundColor3 = Color3.new(1, 1, 1)
	capa.BackgroundTransparency = 0
	capa.Size = UDim2.fromScale(1, 1)
	capa.ZIndex = 0 -- por debajo del contenido de la tarjeta y por encima de su fondo
	capa.Parent = obj
	local esquina = obj:FindFirstChildOfClass("UICorner")
	if esquina then
		esquina:Clone().Parent = capa
	end
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = capa
	local vivo = true
	task.spawn(function()
		while vivo and capa.Parent do
			g.Offset = Vector2.new(-1, 0)
			local t = Animar.tw(g, 0.7, { Offset = Vector2.new(1, 0) }, "Quad", "InOut")
			t.Completed:Wait()
			task.wait(cadaSegundos or 2.5)
		end
	end)
	return function()
		vivo = false
		capa:Destroy()
	end
end

-- Entra deslizando desde un lado ("izquierda", "derecha", "arriba", "abajo")
function Animar.deslizarEntrar(obj: GuiObject, desde: string?, segundos: number?)
	local destino = obj.Position
	local d = desde or "abajo"
	local off = ({
		izquierda = UDim2.fromScale(-1, 0),
		derecha = UDim2.fromScale(1, 0),
		arriba = UDim2.fromScale(0, -1),
		abajo = UDim2.fromScale(0, 1),
	})[d] or UDim2.fromScale(0, 1)
	obj.Position = destino + off
	obj.Visible = true
	return Animar.tw(obj, segundos or 0.35, { Position = destino }, "Back", "Out")
end

-- Confeti 2D por toda la pantalla (premio grande, nivel nuevo)
function Animar.confeti(lienzo: GuiObject, cantidad: number?)
	local colores = {
		Color3.fromRGB(255, 80, 90),
		Color3.fromRGB(255, 200, 50),
		Color3.fromRGB(80, 200, 255),
		Color3.fromRGB(120, 230, 100),
		Color3.fromRGB(200, 110, 255),
	}
	for _ = 1, cantidad or 60 do
		local p = Instance.new("Frame")
		p.Name = "Confeti"
		p.BorderSizePixel = 0
		p.BackgroundColor3 = colores[math.random(#colores)]
		p.Size = UDim2.fromOffset(math.random(8, 16), math.random(12, 22))
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.new(math.random(), 0, 0, -30)
		p.Rotation = math.random(0, 360)
		p.ZIndex = 95
		p.Parent = lienzo
		local dur = 1.6 + math.random() * 1.4
		local t = Animar.tw(p, dur, {
			Position = UDim2.new(p.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = p.Rotation + math.random(-540, 540),
		}, "Quad", "In")
		t.Completed:Connect(function()
			p:Destroy()
		end)
	end
end

-- Destello de color en todo el objeto (golpe, compra hecha)
function Animar.destello(obj: GuiObject, color: Color3?)
	local capa = Instance.new("Frame")
	capa.Name = "Destello"
	capa.BackgroundColor3 = color or Color3.new(1, 1, 1)
	capa.BackgroundTransparency = 0.3
	capa.Size = UDim2.fromScale(1, 1)
	capa.ZIndex = obj.ZIndex + 2
	capa.Parent = obj
	local esquina = obj:FindFirstChildOfClass("UICorner")
	if esquina then
		esquina:Clone().Parent = capa
	end
	local t = Animar.tw(capa, 0.35, { BackgroundTransparency = 1 })
	t.Completed:Connect(function()
		capa:Destroy()
	end)
end

return Animar
