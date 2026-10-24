--!nonstrict
--[[
	UIKit: componentes de interfaz para Roblox con buen estilo, listos para usar.
	Ponlo en ReplicatedStorage (ModuleScript «UIKit») y úsalo desde un LocalScript:

		local UIKit = require(ReplicatedStorage.UIKit)
		local gui = UIKit.pantalla("MiInterfaz")
		local boton = UIKit.boton({ Parent = gui, texto = "¡JUGAR!", color = UIKit.tema.primario,
			Position = UDim2.fromScale(0.5, 0.85), alPulsar = function() print("hola") end })

	Reglas que respeta (no las rompas al tocarlo):
	- Solo un UIScale por objeto: los botones se animan moviendo la «cara», no con UIScale.
	- Nada de UIGradient en objetos con texto (también tiñe las letras).
	- Los botones usan Activated (funciona con ratón, dedo y mando), nunca MouseButton1Click.
	- Tamaños pensados para una pantalla BASE de 1280×720; UIKit.pantalla() añade la escala.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

-- Tema por defecto (cámbialo con UIKit.usarTema(Tema) — ver plugin roblox-ui-estilo)
UIKit.tema = {
	fondo = Color3.fromRGB(24, 28, 48),
	panel = Color3.fromRGB(38, 44, 72),
	panel2 = Color3.fromRGB(52, 60, 96),
	borde = Color3.fromRGB(16, 18, 32),
	texto = Color3.fromRGB(255, 255, 255),
	textoSuave = Color3.fromRGB(190, 198, 230),
	primario = Color3.fromRGB(64, 156, 255),
	exito = Color3.fromRGB(70, 200, 90),
	peligro = Color3.fromRGB(235, 70, 80),
	aviso = Color3.fromRGB(255, 196, 40),
	oro = Color3.fromRGB(255, 205, 60),
	fuenteTitulo = Font.fromEnum(Enum.Font.FredokaOne),
	fuenteTexto = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	esquina = 14,
	trazo = 3,
	base = Vector2.new(1280, 720),
	escalaMinima = 0.7,
}

function UIKit.usarTema(t: { [string]: any })
	for k, v in t do
		UIKit.tema[k] = v
	end
end

local function oscurecer(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end
UIKit.oscurecer = oscurecer

local function aclarar(c: Color3, f: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), f)
end
UIKit.aclarar = aclarar

-- Crea una instancia con propiedades e hijos. Las claves en minúscula se ignoran
-- (así los componentes pueden recibir opciones propias mezcladas con propiedades).
function UIKit.crear(clase: string, props: { [string]: any }?, hijos: { Instance }?): any
	local inst = Instance.new(clase)
	local padre = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				padre = v
			elseif type(k) == "string" and string.match(k, "^%u") then
				(inst :: any)[k] = v
			end
		end
	end
	if hijos then
		for _, h in hijos do
			h.Parent = inst
		end
	end
	inst.Parent = padre
	return inst
end
local crear = UIKit.crear

function UIKit.esquina(padre: Instance, radio: number?): UICorner
	return crear("UICorner", { CornerRadius = UDim.new(0, radio or UIKit.tema.esquina), Parent = padre })
end

function UIKit.borde(padre: Instance, color: Color3?, grosor: number?): UIStroke
	return crear("UIStroke", {
		Color = color or UIKit.tema.borde,
		Thickness = grosor or UIKit.tema.trazo,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = padre,
	})
end

-- Contorno de las LETRAS (para texto encima de fondos claros o de colores)
function UIKit.contornoTexto(padre: Instance, color: Color3?, grosor: number?): UIStroke
	return crear("UIStroke", {
		Color = color or UIKit.tema.borde,
		Thickness = grosor or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = padre,
	})
end

function UIKit.relleno(padre: Instance, px: number)
	return crear("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = padre,
	})
end

function UIKit.lista(padre: Instance, separacion: number?, horizontal: boolean?, alinear: Enum.HorizontalAlignment?)
	return crear("UIListLayout", {
		Padding = UDim.new(0, separacion or 8),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = alinear or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = padre,
	})
end

-- Texto con estilo. opciones: texto, tamano, color, titulo (bool), alinear
function UIKit.texto(op: { [string]: any }): TextLabel
	local t = UIKit.tema
	local label = crear("TextLabel", op)
	label.BackgroundTransparency = 1
	label.Text = op.texto or ""
	label.TextSize = op.tamano or 22
	label.TextColor3 = op.color or t.texto
	label.FontFace = if op.titulo then t.fuenteTitulo else t.fuenteTexto
	label.TextWrapped = true
	label.TextXAlignment = op.alinear or Enum.TextXAlignment.Center
	if op.Size == nil then
		label.AutomaticSize = Enum.AutomaticSize.XY
	end
	if op.contorno ~= false and op.titulo then
		UIKit.contornoTexto(label)
	end
	return label
end

--[[ Pantalla (ScreenGui) con escala automática.
	Todo lo que metas dentro se diseña para UIKit.tema.base (1280×720) y se escala solo.
	Devuelve el Frame «Lienzo» donde colocar las cosas. ]]
function UIKit.pantalla(nombre: string, orden: number?): Frame
	local jugador = Players.LocalPlayer
	local gui = crear("ScreenGui", {
		Name = nombre,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = orden or 0,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = jugador:WaitForChild("PlayerGui"),
	})
	local base = UIKit.tema.base
	local lienzo = crear("Frame", {
		Name = "Lienzo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(base.X, base.Y),
		Parent = gui,
	})
	local escala = crear("UIScale", { Parent = lienzo })
	local function ajustar()
		local camara = Workspace.CurrentCamera
		if not camara then
			return
		end
		local vista = gui.AbsoluteSize
		if vista.X <= 0 then
			vista = camara.ViewportSize
		end
		local s = math.min(vista.X / base.X, vista.Y / base.Y)
		s = math.max(s, math.min(UIKit.tema.escalaMinima, vista.X / base.X))
		escala.Scale = s
		-- El lienzo ocupa toda la pantalla aunque no tenga la proporción 16:9
		lienzo.Size = UDim2.fromOffset(vista.X / s, vista.Y / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustar)
	ajustar()
	return lienzo
end

--[[ Botón «grueso» con sombra que se hunde al pulsar.
	op: texto, color, tamanoTexto, icono (texto/emoji o rbxassetid), alPulsar, Size, Position, AnchorPoint, Parent
	Devuelve el contenedor (Frame) y una tabla con :texto(s), :color(c), :activo(bool), .boton ]]
function UIKit.boton(op: { [string]: any })
	local t = UIKit.tema
	local color = op.color or t.primario
	local alto = 6
	local caja = crear("Frame", {
		Name = op.Name or "Boton",
		BackgroundTransparency = 1,
		Size = op.Size or UDim2.fromOffset(220, 72),
		Position = op.Position or UDim2.new(),
		AnchorPoint = op.AnchorPoint or Vector2.new(0.5, 0.5),
		LayoutOrder = op.LayoutOrder or 0,
		Parent = op.Parent,
	})
	local sombra = crear("Frame", {
		Name = "Sombra",
		BackgroundColor3 = oscurecer(color, 0.6),
		Size = UDim2.new(1, 0, 1, -alto),
		Position = UDim2.fromOffset(0, alto),
		Parent = caja,
	})
	UIKit.esquina(sombra)
	local boton = crear("TextButton", {
		Name = "Cara",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = UDim2.new(1, 0, 1, -alto),
		Text = "",
		Parent = caja,
	})
	UIKit.esquina(boton)
	local trazo = UIKit.borde(boton, oscurecer(color, 0.45))
	-- Brillo superior (Frame sin texto: aquí sí se puede usar degradado)
	local brillo = crear("Frame", {
		Name = "Brillo",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.fromOffset(4, 3),
		ZIndex = 2,
		Parent = boton,
	})
	UIKit.esquina(brillo, t.esquina - 4)
	local fila = crear("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = boton,
	})
	UIKit.lista(fila, 8, true)
	if op.icono then
		if string.find(op.icono, "rbxasset") then
			crear("ImageLabel", {
				BackgroundTransparency = 1,
				Image = op.icono,
				Size = UDim2.fromOffset(40, 40),
				ZIndex = 3,
				Parent = fila,
			})
		else
			UIKit.texto({ texto = op.icono, tamano = (op.tamanoTexto or 30) + 4, Parent = fila, ZIndex = 3, contorno = false })
		end
	end
	local etiqueta = UIKit.texto({
		texto = op.texto or "",
		tamano = op.tamanoTexto or 30,
		titulo = true,
		Parent = fila,
		ZIndex = 3,
		LayoutOrder = 2,
	})

	local activo = true
	local function hundir(abajo: boolean)
		local y = if abajo then alto - 1 else 0
		TweenService:Create(boton, TweenInfo.new(0.07), { Position = UDim2.fromOffset(0, y) }):Play()
	end
	boton.MouseButton1Down:Connect(function() hundir(true) end)
	boton.MouseButton1Up:Connect(function() hundir(false) end)
	boton.MouseLeave:Connect(function()
		hundir(false)
		boton.BackgroundColor3 = color
	end)
	boton.MouseEnter:Connect(function()
		if activo then
			boton.BackgroundColor3 = aclarar(color, 0.12)
		end
	end)
	boton.Activated:Connect(function()
		if activo and op.alPulsar then
			op.alPulsar()
		end
	end)

	local api = { boton = boton, caja = caja, etiqueta = etiqueta }
	function api.texto(_, s: string)
		etiqueta.Text = s
	end
	function api.color(_, c: Color3)
		color = c
		boton.BackgroundColor3 = c
		sombra.BackgroundColor3 = oscurecer(c, 0.6)
		trazo.Color = oscurecer(c, 0.45)
	end
	function api.activo(_, si: boolean)
		activo = si
		boton.BackgroundColor3 = if si then color else Color3.fromRGB(120, 120, 130)
		sombra.BackgroundColor3 = oscurecer(boton.BackgroundColor3, 0.6)
		etiqueta.TextTransparency = if si then 0 else 0.35
	end
	return caja, api
end

-- Tarjeta: panel redondeado con borde. op: color, Size, Position, Parent, relleno
function UIKit.tarjeta(op: { [string]: any }): Frame
	local t = UIKit.tema
	local f = crear("Frame", op)
	f.BackgroundColor3 = op.color or t.panel
	UIKit.esquina(f)
	UIKit.borde(f, op.colorBorde)
	if op.relleno ~= false then
		UIKit.relleno(f, op.relleno or 12)
	end
	return f
end

--[[ Ventana modal con título, botón X y fondo oscuro. Se abre/cierra con animación.
	op: titulo, Size (por defecto 760×480), Parent (el lienzo), color
	Devuelve api: .contenido (Frame donde poner cosas), :abrir(), :cerrar(), :abierta(), .alCerrar ]]
function UIKit.ventana(op: { [string]: any })
	local t = UIKit.tema
	local velo = crear("TextButton", {
		Name = "Velo_" .. (op.titulo or "Ventana"),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
		Parent = op.Parent,
	})
	local tam = op.Size or UDim2.fromOffset(760, 480)
	-- La ventana es un botón sin texto: así los toques DENTRO no llegan al velo (que cierra al tocar fuera)
	local marco = crear("TextButton", {
		Name = "Ventana",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = tam,
		BackgroundColor3 = op.color or t.fondo,
		ZIndex = 51,
		Parent = velo,
	})
	UIKit.esquina(marco, t.esquina + 4)
	UIKit.borde(marco, t.borde, 4)
	local escala = crear("UIScale", { Parent = marco })
	local barra = crear("Frame", {
		Name = "Titulo",
		BackgroundColor3 = t.panel2,
		Size = UDim2.new(1, 0, 0, 64),
		ZIndex = 52,
		Parent = marco,
	})
	UIKit.esquina(barra, t.esquina + 4)
	UIKit.texto({
		texto = op.titulo or "",
		tamano = 34,
		titulo = true,
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.fromOffset(24, 0),
		alinear = Enum.TextXAlignment.Left,
		ZIndex = 53,
		Parent = barra,
	})
	local api: { [string]: any } = {}
	local _, cerrar = UIKit.boton({
		Parent = barra,
		texto = "X",
		color = t.peligro,
		Size = UDim2.fromOffset(64, 62),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 2),
		tamanoTexto = 28,
		alPulsar = function()
			api:cerrar()
		end,
	})
	cerrar.caja.ZIndex = 54
	local contenido = crear("Frame", {
		Name = "Contenido",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 1, -92),
		ZIndex = 52,
		Parent = marco,
	})
	api.contenido = contenido
	api.marco = marco
	function api.abrir(_)
		-- Si la pantalla es baja (móvil), la ventana se encoge para caber entera
		local lienzo = velo.Parent
		if lienzo and lienzo:IsA("GuiObject") and lienzo.Size.X.Offset > 0 then
			local maxW = lienzo.Size.X.Offset - 24
			local maxH = lienzo.Size.Y.Offset - 16
			marco.Size = UDim2.fromOffset(math.min(tam.X.Offset, maxW), math.min(tam.Y.Offset, maxH))
		end
		velo.Visible = true
		escala.Scale = 0.6
		TweenService:Create(escala, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	function api.cerrar(_)
		local tw = TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
		tw.Completed:Connect(function()
			velo.Visible = false
		end)
		tw:Play()
		if api.alCerrar then
			api.alCerrar()
		end
	end
	function api.abierta(_): boolean
		return velo.Visible
	end
	-- Pulsar fuera de la ventana la cierra
	velo.Activated:Connect(function()
		api:cerrar()
	end)
	return api
end

--[[ Pestañas. op: Parent, nombres = {"Tienda", "Pases"}, alCambiar(i)
	Devuelve api: .paginas[i] (Frame de cada pestaña), :ir(i) ]]
function UIKit.pestanas(op: { [string]: any })
	local t = UIKit.tema
	local barra = crear("Frame", {
		Name = "Pestanas",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Parent = op.Parent,
	})
	UIKit.lista(barra, 8, true, Enum.HorizontalAlignment.Left)
	local api: { [string]: any } = { paginas = {}, botones = {} }
	for i, nombre in op.nombres do
		local pagina = crear("Frame", {
			Name = "Pagina_" .. nombre,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 64),
			Size = UDim2.new(1, 0, 1, -64),
			Visible = i == 1,
			Parent = op.Parent,
		})
		api.paginas[i] = pagina
		local _, b = UIKit.boton({
			Parent = barra,
			texto = nombre,
			tamanoTexto = 24,
			color = if i == 1 then t.primario else t.panel2,
			Size = UDim2.fromOffset(170, 56),
			AnchorPoint = Vector2.new(0, 0),
			LayoutOrder = i,
			alPulsar = function()
				api:ir(i)
			end,
		})
		api.botones[i] = b
	end
	function api.ir(_, n: number)
		for i, pagina in api.paginas do
			pagina.Visible = i == n
			api.botones[i]:color(if i == n then t.primario else t.panel2)
		end
		if op.alCambiar then
			op.alCambiar(n)
		end
	end
	return api
end

--[[ Barra de progreso. op: Parent, Size, Position, color, texto (bool: muestra «x / y»)
	api:poner(valor, maximo) ]]
function UIKit.barra(op: { [string]: any })
	local t = UIKit.tema
	local fondo = crear("Frame", {
		Name = op.Name or "Barra",
		BackgroundColor3 = t.borde,
		Size = op.Size or UDim2.fromOffset(300, 28),
		Position = op.Position or UDim2.new(),
		AnchorPoint = op.AnchorPoint or Vector2.new(),
		Parent = op.Parent,
	})
	UIKit.esquina(fondo, 100)
	local relleno = crear("Frame", {
		Name = "Relleno",
		BackgroundColor3 = op.color or t.exito,
		Size = UDim2.fromScale(0, 1),
		Parent = fondo,
	})
	UIKit.esquina(relleno, 100)
	local etiqueta = UIKit.texto({ texto = "", tamano = 18, titulo = true, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = fondo })
	local api = { marco = fondo }
	function api.poner(_, valor: number, maximo: number, textoExtra: string?)
		local f = if maximo > 0 then math.clamp(valor / maximo, 0, 1) else 0
		TweenService:Create(relleno, TweenInfo.new(0.25), { Size = UDim2.fromScale(f, 1) }):Play()
		if op.texto ~= false then
			etiqueta.Text = textoExtra or string.format("%s / %s", UIKit.numero(valor), UIKit.numero(maximo))
		end
	end
	return api
end

-- Número corto: 1500 → 1.5K, 2300000 → 2.3M
local SUFIJOS = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }
function UIKit.numero(n: number): string
	n = n or 0
	if math.abs(n) < 1000 then
		return tostring(math.floor(n))
	end
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFIJOS do
		n /= 1000
		i += 1
	end
	local s = if math.abs(n) >= 100 then string.format("%.0f", n) else string.format("%.1f", n)
	s = string.gsub(s, "%.0$", "")
	return s .. SUFIJOS[i]
end

--[[ Contador de moneda (arriba a la izquierda del HUD). op: Parent, icono (emoji/asset), color, Position
	api:poner(valor) — anima la cifra y da un saltito cuando sube ]]
function UIKit.contador(op: { [string]: any })
	local t = UIKit.tema
	local marco = UIKit.tarjeta({
		Name = op.Name or "Contador",
		Parent = op.Parent,
		Size = op.Size or UDim2.fromOffset(250, 60),
		Position = op.Position or UDim2.fromOffset(16, 16),
		color = t.panel,
		relleno = 6,
	})
	UIKit.lista(marco, 8, true, Enum.HorizontalAlignment.Left)
	if op.icono and string.find(op.icono, "rbxasset") then
		crear("ImageLabel", { BackgroundTransparency = 1, Image = op.icono, Size = UDim2.fromOffset(44, 44), Parent = marco })
	else
		UIKit.texto({ texto = op.icono or "💰", tamano = 34, Parent = marco, contorno = false })
	end
	local cifra = UIKit.texto({ texto = "0", tamano = 32, titulo = true, color = op.color or t.oro, Parent = marco, LayoutOrder = 2 })
	local actual = 0
	local api = { marco = marco }
	function api.poner(_, valor: number)
		local antes = actual
		actual = valor
		if valor > antes then
			local v = Instance.new("NumberValue")
			v.Value = antes
			v.Changed:Connect(function(x)
				cifra.Text = UIKit.numero(x)
			end)
			local tw = TweenService:Create(v, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = valor })
			tw.Completed:Connect(function()
				cifra.Text = UIKit.numero(valor)
				v:Destroy()
			end)
			tw:Play()
			cifra.Rotation = -4
			TweenService:Create(cifra, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), { Rotation = 0 }):Play()
		else
			cifra.Text = UIKit.numero(valor)
		end
	end
	return api
end

-- Insignia (puntito rojo con número) en la esquina de un botón. api:poner(n) — 0 la oculta
function UIKit.insignia(padre: GuiObject)
	local t = UIKit.tema
	local punto = crear("Frame", {
		Name = "Insignia",
		BackgroundColor3 = t.peligro,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 20,
		Visible = false,
		Parent = padre,
	})
	UIKit.esquina(punto, 100)
	UIKit.borde(punto, Color3.new(1, 1, 1), 2)
	local n = UIKit.texto({ texto = "", tamano = 18, titulo = true, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = punto })
	return {
		poner = function(_, valor: number)
			punto.Visible = valor > 0
			n.Text = if valor > 9 then "9+" else tostring(valor)
		end,
	}
end

--[[ Rejilla con scroll (para tiendas e inventarios). op: Parent, celda (Vector2), Size, Position
	Devuelve el ScrollingFrame; mete tarjetas dentro y se colocan solas. ]]
function UIKit.rejilla(op: { [string]: any }): ScrollingFrame
	local t = UIKit.tema
	local celda = op.celda or Vector2.new(150, 180)
	local sf = crear("ScrollingFrame", {
		Name = op.Name or "Rejilla",
		BackgroundTransparency = 1,
		Size = op.Size or UDim2.fromScale(1, 1),
		Position = op.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = t.textoSuave,
		Parent = op.Parent,
	})
	crear("UIGridLayout", {
		CellSize = UDim2.fromOffset(celda.X, celda.Y),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sf,
	})
	UIKit.relleno(sf, 8)
	return sf
end

--[[ Interruptor sí/no (ajustes). op: Parent, texto, valor, alCambiar(bool), LayoutOrder ]]
function UIKit.interruptor(op: { [string]: any })
	local t = UIKit.tema
	local fila = crear("Frame", {
		BackgroundTransparency = 1,
		Size = op.Size or UDim2.new(1, 0, 0, 56),
		LayoutOrder = op.LayoutOrder or 0,
		Parent = op.Parent,
	})
	UIKit.texto({
		texto = op.texto or "",
		tamano = 24,
		Size = UDim2.new(1, -110, 1, 0),
		alinear = Enum.TextXAlignment.Left,
		Parent = fila,
	})
	local valor = op.valor == true
	local carril = crear("TextButton", {
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(92, 46),
		Parent = fila,
	})
	UIKit.esquina(carril, 100)
	local bola = crear("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(38, 38),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = carril,
	})
	UIKit.esquina(bola, 100)
	local function pintar(animar: boolean)
		carril.BackgroundColor3 = if valor then t.exito else Color3.fromRGB(110, 110, 125)
		local destino = if valor then UDim2.new(1, -42, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
		if animar then
			TweenService:Create(bola, TweenInfo.new(0.15), { Position = destino }):Play()
		else
			bola.Position = destino
		end
	end
	carril.Activated:Connect(function()
		valor = not valor
		pintar(true)
		if op.alCambiar then
			op.alCambiar(valor)
		end
	end)
	pintar(false)
	return {
		poner = function(_, v: boolean)
			valor = v
			pintar(false)
		end,
	}
end

--[[ Avisos (toasts) que aparecen arriba en el centro y se van solos.
	UIKit.aviso(lienzo, "¡Has conseguido un Dragón!", "exito"|"peligro"|"aviso"|"info", segundos) ]]
local pilaAvisos: { [Instance]: Frame } = {}
function UIKit.aviso(lienzo: Instance, mensaje: string, tipo: string?, segundos: number?)
	local t = UIKit.tema
	local pila = pilaAvisos[lienzo]
	if not pila or not pila.Parent then
		pila = crear("Frame", {
			Name = "Avisos",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 90),
			Size = UDim2.fromOffset(560, 300),
			ZIndex = 80,
			Parent = lienzo,
		})
		UIKit.lista(pila, 8)
		local l = pila:FindFirstChildOfClass("UIListLayout")
		if l then
			l.VerticalAlignment = Enum.VerticalAlignment.Top
		end
		pilaAvisos[lienzo] = pila
	end
	local colores = { exito = t.exito, peligro = t.peligro, aviso = t.aviso, info = t.primario }
	local color = colores[tipo or "info"] or t.primario
	local caja = crear("Frame", {
		BackgroundColor3 = t.fondo,
		Size = UDim2.fromOffset(540, 58),
		ZIndex = 81,
		Parent = pila,
	})
	UIKit.esquina(caja)
	UIKit.borde(caja, color, 4)
	local esc = crear("UIScale", { Scale = 0.5, Parent = caja })
	UIKit.texto({ texto = mensaje, tamano = 24, titulo = true, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), ZIndex = 82, Parent = caja })
	TweenService:Create(esc, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(segundos or 3, function()
		local tw = TweenService:Create(esc, TweenInfo.new(0.15), { Scale = 0 })
		tw.Completed:Connect(function()
			caja:Destroy()
		end)
		tw:Play()
	end)
end

-- Colores de rareza (para bordes de tarjetas de mascotas/objetos)
UIKit.rarezas = {
	Comun = Color3.fromRGB(170, 175, 185),
	PocoComun = Color3.fromRGB(80, 200, 90),
	Raro = Color3.fromRGB(60, 140, 255),
	Epico = Color3.fromRGB(170, 80, 255),
	Legendario = Color3.fromRGB(255, 170, 30),
	Mitico = Color3.fromRGB(255, 60, 120),
	Secreto = Color3.fromRGB(20, 20, 20),
}

return UIKit
