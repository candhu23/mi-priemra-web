--!nonstrict
--[[
	Pantallas: las pantallas típicas de un juego de Roblox ya montadas con UIKit (plugin
	roblox-ui-componentes) y Animar (plugin roblox-ui-animaciones). Copia los tres módulos a
	ReplicatedStorage y llama desde un LocalScript:

		local P = require(ReplicatedStorage.Pantallas)
		local lienzo = UIKit.pantalla("Juego")
		local hud = P.hud(lienzo, { alAbrir = function(cual) ... end })   -- cual: "tienda" | "mascotas" | "misiones" | "ajustes"
		hud.monedas:poner(1500)
		local tienda = P.tienda(lienzo, articulos, function(id) comprar(id) end)
		local inv = P.inventario(lienzo, function(id) equipar(id) end)
		inv:poner(listaMascotas, huecosUsados, huecosMax)
		P.abrirHuevo(lienzo, { nombre = "Dragón", emoji = "🐉", rareza = "Legendario" }, probabilidades)
		P.recompensa(lienzo, "¡Premio diario!", "💰", 500)

	Todo el texto que ve el jugador entra por parámetro: tradúcelo antes (ES/EN).
	El servidor decide (compras, resultados de huevos); estas pantallas solo MUESTRAN y piden.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Animar = require(ReplicatedStorage:WaitForChild("Animar"))

local P = {}

local ORDEN_RAREZA = { Comun = 1, PocoComun = 2, Raro = 3, Epico = 4, Legendario = 5, Mitico = 6, Secreto = 7 }
local NOMBRE_RAREZA = {
	Comun = "Común",
	PocoComun = "Poco común",
	Raro = "Raro",
	Epico = "Épico",
	Legendario = "Legendario",
	Mitico = "Mítico",
	Secreto = "Secreto",
}
P.nombreRareza = NOMBRE_RAREZA

--[[ HUD: monedas arriba a la izquierda, gemas debajo, botones grandes a la izquierda (centro vertical,
	donde llega el pulgar en el móvil) y un botón de regalo/evento a la derecha.
	op: alAbrir(cual), textos = { tienda, mascotas, misiones, ajustes } ]]
function P.hud(lienzo: Frame, op: { [string]: any })
	local t = UIKit.tema
	local textos = op.textos or {}
	local api: { [string]: any } = {}
	-- El lienzo ya empieza debajo de la barra de Roblox (IgnoreGuiInset = false)
	api.monedas = UIKit.contador({ Parent = lienzo, icono = "💰", Position = UDim2.fromOffset(16, 12) })
	api.gemas = UIKit.contador({ Parent = lienzo, icono = "💎", color = Color3.fromRGB(120, 220, 255), Position = UDim2.fromOffset(16, 80) })

	-- Menú 2×2 a media altura a la izquierda: cabe también en el móvil horizontal (≈ 500 de alto de diseño)
	local columna = UIKit.crear("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 30),
		Size = UDim2.fromOffset(196, 196),
		Parent = lienzo,
	})
	UIKit.crear("UIGridLayout", { CellSize = UDim2.fromOffset(92, 92), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = columna })
	api.botones = {}
	api.insignias = {}
	local botones = {
		{ "tienda", "🛒", textos.tienda or "Tienda", t.aviso },
		{ "mascotas", "🐾", textos.mascotas or "Mascotas", t.primario },
		{ "misiones", "🎯", textos.misiones or "Misiones", t.exito },
		{ "ajustes", "⚙️", textos.ajustes or "Ajustes", t.panel2 },
	}
	for i, b in botones do
		local boton -- se declara antes: alPulsar lo usa y se crea en la misma llamada
		local caja
		caja, boton = UIKit.boton({
			Parent = columna,
			Name = b[1],
			texto = "",
			icono = b[2],
			tamanoTexto = 34,
			color = b[4],
			Size = UDim2.fromOffset(92, 92),
			LayoutOrder = i,
			alPulsar = function()
				Animar.pulsar(boton.boton)
				if op.alAbrir then
					op.alAbrir(b[1])
				end
			end,
		})
		-- Rótulo pequeño debajo del icono
		UIKit.texto({
			texto = b[3],
			tamano = 18,
			titulo = true,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			ZIndex = 5,
			Parent = caja,
		})
		api.botones[b[1]] = boton
		api.insignias[b[1]] = UIKit.insignia(boton.boton)
	end
	return api
end

--[[ Tienda en rejilla. articulos = { { id, nombre, icono (emoji o asset), precio (texto ya formateado),
	descripcion, destacado (bool), comprado (bool), color }, ... }
	alComprar(id). Devuelve la ventana (api:abrir()/cerrar()) y :marcarComprado(id) ]]
function P.tienda(lienzo: Frame, articulos: { { [string]: any } }, alComprar: (string) -> (), titulo: string?)
	local t = UIKit.tema
	local v = UIKit.ventana({ Parent = lienzo, titulo = titulo or "🛒 Tienda", Size = UDim2.fromOffset(900, 560) })
	local rejilla = UIKit.rejilla({ Parent = v.contenido, celda = Vector2.new(200, 270) })
	local tarjetas = {}
	for i, a in articulos do
		local tarjeta = UIKit.tarjeta({
			Name = a.id,
			Parent = rejilla,
			LayoutOrder = if a.destacado then -100 + i else i,
			color = if a.destacado then UIKit.oscurecer(t.aviso, 0.45) else t.panel,
			colorBorde = if a.destacado then t.aviso else nil,
			relleno = 8,
		})
		if a.destacado then
			Animar.brillo(tarjeta, 3)
		end
		local icono = a.icono or "🎁"
		if string.find(icono, "rbxasset") then
			UIKit.crear("ImageLabel", { BackgroundTransparency = 1, Image = icono, Size = UDim2.fromOffset(90, 90), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Parent = tarjeta })
		else
			UIKit.texto({ texto = icono, tamano = 64, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), contorno = false, Parent = tarjeta })
		end
		UIKit.texto({ texto = a.nombre or a.id, tamano = 22, titulo = true, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 98), Parent = tarjeta })
		UIKit.texto({ texto = a.descripcion or "", tamano = 18, color = if a.destacado then t.texto else t.textoSuave, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 128), Parent = tarjeta })
		local _, b = UIKit.boton({
			Parent = tarjeta,
			texto = a.precio or "",
			tamanoTexto = 24,
			color = a.color or t.exito,
			Size = UDim2.new(1, 0, 0, 64),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			alPulsar = function()
				alComprar(a.id)
			end,
		})
		if a.comprado then
			b:texto("✓")
			b:activo(false)
		end
		tarjetas[a.id] = b
	end
	function v.marcarComprado(_, id: string, texto: string?)
		local b = tarjetas[id]
		if b then
			b:texto(texto or "✓")
			b:activo(false)
		end
	end
	return v
end

--[[ Inventario de mascotas/objetos: rejilla ordenada por rareza y poder, borde del color de la rareza,
	marca de «equipada», contador de huecos y botón «Equipar mejores».
	alPulsar(id) al tocar una; alEquiparMejores() opcional.
	api:poner(lista, usados, maximo) con lista = { { id, nombre, emoji, rareza, poder, equipada }, ... } ]]
function P.inventario(lienzo: Frame, alPulsar: (string) -> (), alEquiparMejores: (() -> ())?, titulo: string?)
	local t = UIKit.tema
	local v = UIKit.ventana({ Parent = lienzo, titulo = titulo or "🐾 Mascotas", Size = UDim2.fromOffset(900, 560) })
	local barraHuecos = UIKit.barra({ Parent = v.contenido, Size = UDim2.fromOffset(300, 34), color = t.primario })
	if alEquiparMejores then
		UIKit.boton({
			Parent = v.contenido,
			texto = "Equipar mejores",
			tamanoTexto = 22,
			color = t.exito,
			Size = UDim2.fromOffset(240, 62),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, -4),
			alPulsar = alEquiparMejores,
		})
	end
	local rejilla = UIKit.rejilla({ Parent = v.contenido, celda = Vector2.new(150, 176), Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66) })
	function v.poner(_, lista: { { [string]: any } }, usados: number, maximo: number)
		for _, h in rejilla:GetChildren() do
			if h:IsA("Frame") then
				h:Destroy()
			end
		end
		barraHuecos:poner(usados, maximo, string.format("Equipadas %d / %d", usados, maximo))
		local orden = table.clone(lista)
		table.sort(orden, function(a, b)
			if (a.equipada and true or false) ~= (b.equipada and true or false) then
				return a.equipada == true
			end
			local ra, rb = ORDEN_RAREZA[a.rareza] or 0, ORDEN_RAREZA[b.rareza] or 0
			if ra ~= rb then
				return ra > rb
			end
			return (a.poder or 0) > (b.poder or 0)
		end)
		for i, m in orden do
			local color = UIKit.rarezas[m.rareza] or t.panel2
			local tarjeta = UIKit.tarjeta({ Name = m.id, Parent = rejilla, LayoutOrder = i, color = t.panel, colorBorde = color, relleno = 6 })
			local boton = UIKit.crear("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = tarjeta })
			boton.Activated:Connect(function()
				Animar.pulsar(tarjeta)
				alPulsar(m.id)
			end)
			UIKit.texto({ texto = m.emoji or "🐾", tamano = 56, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), contorno = false, Parent = tarjeta })
			UIKit.texto({ texto = m.nombre or "", tamano = 18, titulo = true, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 78), Parent = tarjeta })
			UIKit.texto({ texto = NOMBRE_RAREZA[m.rareza] or m.rareza or "", tamano = 18, titulo = true, color = color, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 102), Parent = tarjeta })
			UIKit.texto({ texto = "⚡ " .. UIKit.numero(m.poder or 0), tamano = 20, titulo = true, color = t.oro, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 128), Parent = tarjeta })
			if m.equipada then
				local marca = UIKit.crear("Frame", { BackgroundColor3 = t.exito, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(-4, -4), ZIndex = 11, Parent = tarjeta })
				UIKit.esquina(marca, 100)
				UIKit.texto({ texto = "✓", tamano = 20, titulo = true, Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = marca })
			end
			if (ORDEN_RAREZA[m.rareza] or 0) >= 5 then
				Animar.brillo(tarjeta, 2)
			end
		end
	end
	return v
end

--[[ Apertura de huevo: el huevo se balancea, tiembla cada vez más, destello y aparece la mascota con
	su rareza, confeti si es rara. Muestra las PROBABILIDADES (obligatorio en Roblox si se paga con Robux,
	y recomendable siempre). resultado = { nombre, emoji, rareza }; probabilidades = { { nombre, emoji, rareza, pct }, ... }
	alTerminar() opcional (cuando el jugador pulsa «¡Genial!») ]]
function P.abrirHuevo(lienzo: Frame, resultado: { [string]: any }, probabilidades: { { [string]: any } }?, alTerminar: (() -> ())?, emojiHuevo: string?)
	local t = UIKit.tema
	local velo = UIKit.crear("Frame", { Name = "AbrirHuevo", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 70, Parent = lienzo })
	-- Rayos detrás (Frame con texto vacío: se puede girar)
	local rayos = UIKit.texto({ texto = "✦", tamano = 300, color = t.oro, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -105), ZIndex = 71, contorno = false, Parent = velo })
	rayos.TextTransparency = 0.75
	local pararRayos = Animar.girar(rayos, 0.1)
	local huevo = UIKit.texto({ texto = emojiHuevo or "🥚", tamano = 150, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -105), ZIndex = 72, contorno = false, Parent = velo })
	if probabilidades then
		local caja = UIKit.tarjeta({ Parent = velo, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(720, 64), ZIndex = 72, relleno = 6 })
		UIKit.lista(caja, 14, true)
		for i, pr in probabilidades do
			UIKit.texto({
				texto = string.format("%s %s%%", pr.emoji or "", tostring(pr.pct)),
				tamano = 20,
				titulo = true,
				color = UIKit.rarezas[pr.rareza] or t.texto,
				LayoutOrder = i,
				ZIndex = 73,
				Parent = caja,
			})
		end
	end
	task.spawn(function()
		local parar = Animar.balancear(huevo, 6, 0.6)
		task.wait(1)
		parar()
		parar = Animar.balancear(huevo, 14, 0.25)
		task.wait(0.9)
		parar()
		Animar.destello(velo, Color3.new(1, 1, 1))
		huevo.Text = resultado.emoji or "🐾"
		Animar.aparecer(huevo, 0.35)
		local color = UIKit.rarezas[resultado.rareza] or t.texto
		rayos.TextColor3 = color
		local nombre = UIKit.texto({ texto = resultado.nombre or "", tamano = 48, titulo = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -20), ZIndex = 73, Parent = velo })
		local rareza = UIKit.texto({ texto = NOMBRE_RAREZA[resultado.rareza] or resultado.rareza or "", tamano = 32, titulo = true, color = color, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 32), ZIndex = 73, Parent = velo })
		Animar.aparecer(nombre)
		Animar.aparecer(rareza)
		if (ORDEN_RAREZA[resultado.rareza] or 0) >= 4 then
			Animar.confeti(velo, 80)
		end
		local caja = UIKit.boton({
			Parent = velo,
			texto = "¡Genial!",
			color = t.exito,
			Position = UDim2.new(0.5, 0, 0.5, 112),
			alPulsar = function()
				pararRayos()
				velo:Destroy()
				if alTerminar then
					alTerminar()
				end
			end,
		})
		caja.ZIndex = 74
		for _, d in caja:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 74
			end
		end
	end)
	return velo
end

-- Ventana de recompensa: icono grande, cantidad que cuenta hacia arriba y botón para recoger
function P.recompensa(lienzo: Frame, titulo: string, icono: string, cantidad: number, alRecoger: (() -> ())?)
	local t = UIKit.tema
	local v = UIKit.ventana({ Parent = lienzo, titulo = titulo, Size = UDim2.fromOffset(520, 420) })
	local ic = UIKit.texto({ texto = icono, tamano = 110, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), contorno = false, Parent = v.contenido })
	local cifra = UIKit.texto({ texto = "0", tamano = 56, titulo = true, color = t.oro, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Parent = v.contenido })
	UIKit.boton({
		Parent = v.contenido,
		texto = "Recoger",
		color = t.exito,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		alPulsar = function()
			v:cerrar()
			if alRecoger then
				alRecoger()
			end
		end,
	})
	v:abrir()
	Animar.flotar(ic, 6)
	Animar.contar(cifra, 0, cantidad, function(x: number): string
		return "+" .. UIKit.numero(x)
	end, 0.8)
	return v
end

--[[ Flecha de tutorial que señala un botón y un globo de texto. Devuelve quitar() ]]
function P.senalar(lienzo: Frame, objetivo: GuiObject, mensaje: string): () -> ()
	local t = UIKit.tema
	local flecha = UIKit.texto({ texto = "👉", tamano = 64, AnchorPoint = Vector2.new(1, 0.5), ZIndex = 85, contorno = false, Parent = lienzo })
	local globo = UIKit.tarjeta({ Parent = lienzo, color = t.fondo, colorBorde = t.aviso, Size = UDim2.fromOffset(320, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 85, relleno = 10 })
	UIKit.texto({ texto = mensaje, tamano = 20, titulo = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 86, Parent = globo })
	local function colocar()
		local escala = lienzo.AbsoluteSize.X / math.max(1, lienzo.Size.X.Offset)
		local pos = (objetivo.AbsolutePosition - lienzo.AbsolutePosition) / escala
		local tam = objetivo.AbsoluteSize / escala
		flecha.Position = UDim2.fromOffset(pos.X - 4, pos.Y + tam.Y / 2)
		globo.Position = UDim2.fromOffset(pos.X + tam.X + 16, pos.Y)
	end
	colocar()
	local con = objetivo:GetPropertyChangedSignal("AbsolutePosition"):Connect(colocar)
	local pararFlecha = Animar.flotar(flecha, 10, 0.8)
	return function()
		con:Disconnect()
		pararFlecha()
		flecha:Destroy()
		globo:Destroy()
	end
end

return P
