--!nonstrict
--[[
	STEAL AN ALIEN — interfaz del jugador
	Marcador, tienda, Índice y probabilidades, códigos, invitaciones, tutorial,
	recompensa diaria, eventos, sonidos y animación de los aliens.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local AdService = game:GetService("AdService")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local Compartido = ReplicatedStorage:WaitForChild("Compartido")
local Config = require(Compartido:WaitForChild("Config"))
local Formato = require(Compartido:WaitForChild("Formato"))
local Probabilidades = require(Compartido:WaitForChild("Probabilidades"))

local remotos = ReplicatedStorage:WaitForChild("Remotos")
local eAviso = remotos:WaitForChild("Aviso")
local eGolpeado = remotos:WaitForChild("Golpeado")
local eDiario = remotos:WaitForChild("RecompensaDiaria")
local eEfecto = remotos:WaitForChild("Efecto")
local ePedirCompra = remotos:WaitForChild("PedirCompra")
local eAnuncio = remotos:WaitForChild("VerAnuncio")
local fCodigo = remotos:WaitForChild("CanjearCodigo")

local jugador = Players.LocalPlayer
local abreviar = Formato.abreviar

local function rgb(c): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function ahora(): number
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------
-- PROMPTS: "Steal" solo en bases ajenas, "Sell" solo en la tuya
---------------------------------------------------------------------
local function ajustarPrompt(prompt: ProximityPrompt, esRobar: boolean)
	local function actualizar()
		local esMio = prompt:GetAttribute("Dueno") == jugador.UserId
		prompt.Enabled = if esRobar then not esMio else esMio
	end
	actualizar()
	prompt:GetAttributeChangedSignal("Dueno"):Connect(actualizar)
end

for etiqueta, esRobar in { PromptRobar = true, PromptVender = false } do
	for _, prompt in CollectionService:GetTagged(etiqueta) do
		ajustarPrompt(prompt, esRobar)
	end
	CollectionService:GetInstanceAddedSignal(etiqueta):Connect(function(prompt)
		ajustarPrompt(prompt, esRobar)
	end)
end

---------------------------------------------------------------------
-- ANIMACIÓN: aliens de la cinta (movidos aquí, en el cliente) y aliens flotando
---------------------------------------------------------------------
local CINTA_INICIO = Vector3.new(Config.CINTA.X_INICIO, Config.CINTA.ALTURA, 0)
local CINTA_FIN = Vector3.new(Config.CINTA.X_FIN, Config.CINTA.ALTURA, 0)
local GIRO_CINTA = CFrame.Angles(0, -math.pi / 2, 0)

RunService.RenderStepped:Connect(function()
	local t = ahora()
	local reloj = os.clock()
	for _, modelo in CollectionService:GetTagged("AlienCinta") do
		local raiz = modelo.PrimaryPart
		local inicio = modelo:GetAttribute("CintaInicio")
		if raiz and inicio then
			local progreso = math.clamp((t - inicio) / Config.JUEGO.SEGUNDOS_EN_CINTA, 0, 1)
			local alto = modelo:GetAttribute("CintaAlto") or 2
			local saltito = math.abs(math.sin(reloj * 6 + inicio)) * 0.4
			raiz.CFrame = CFrame.new(CINTA_INICIO:Lerp(CINTA_FIN, progreso) + Vector3.new(0, alto + saltito, 0)) * GIRO_CINTA
		end
	end
	for _, modelo in CollectionService:GetTagged("AlienFlotante") do
		local raiz = modelo.PrimaryPart
		local base = modelo:GetAttribute("PosBase")
		if raiz and base then
			local fase = base.Position.X + base.Position.Z
			raiz.CFrame = base * CFrame.new(0, math.sin(reloj * 2 + fase) * 0.35, 0) * CFrame.Angles(0, math.sin(reloj * 0.8 + fase) * 0.4, 0)
		end
	end
end)

---------------------------------------------------------------------
-- SONIDOS
---------------------------------------------------------------------
local sonidos: { [string]: Sound } = {}
for nombre, id in Config.SONIDOS do
	if id ~= 0 then
		local sonido = Instance.new("Sound")
		sonido.Name = nombre
		sonido.SoundId = "rbxassetid://" .. id
		sonido.Volume = if nombre == "MUSICA" then 0.25 else 0.6
		sonido.Looped = nombre == "MUSICA"
		sonido.Parent = SoundService
		sonidos[nombre] = sonido
	end
end
if sonidos.MUSICA then
	sonidos.MUSICA:Play()
end

local function sonar(nombre: string)
	local sonido = sonidos[nombre]
	if sonido then
		SoundService:PlayLocalSound(sonido)
	end
end

---------------------------------------------------------------------
-- GOLPE RECIBIDO (empujón)
---------------------------------------------------------------------
eGolpeado.OnClientEvent:Connect(function(direccion: Vector3)
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local humanoid = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if not raiz or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	raiz.AssemblyLinearVelocity = direccion * 55 + Vector3.new(0, 35, 0)
	task.delay(0.7, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)

---------------------------------------------------------------------
-- ESTILO DE LA INTERFAZ
---------------------------------------------------------------------
local COLOR_PANEL = Color3.fromRGB(28, 22, 52)
local COLOR_CIAN = Color3.fromRGB(0, 255, 200)
local COLOR_ORO = Color3.fromRGB(255, 200, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = jugador:WaitForChild("PlayerGui")

-- Escala para pantallas pequeñas (móviles)
local escala = Instance.new("UIScale")
escala.Parent = gui
local function ajustarEscala()
	local camara = workspace.CurrentCamera
	if camara then
		local lado = math.min(camara.ViewportSize.X, camara.ViewportSize.Y)
		escala.Scale = math.clamp(lado / 720, 0.6, 1.2)
	end
end
ajustarEscala()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala)
end

local function redondear(objeto: GuiObject, radio: number?)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio or 12)
	esquina.Parent = objeto
end

local function borde(objeto: GuiObject, color: Color3?, grosor: number?)
	local trazo = Instance.new("UIStroke")
	trazo.Thickness = grosor or 3
	trazo.Color = color or Color3.new(0, 0, 0)
	trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	trazo.Parent = objeto
end

local function texto(padre: Instance, props: { [string]: any }): TextLabel
	local etiqueta = Instance.new("TextLabel")
	etiqueta.BackgroundTransparency = 1
	etiqueta.Font = Enum.Font.FredokaOne
	etiqueta.TextScaled = true
	etiqueta.TextColor3 = Color3.new(1, 1, 1)
	etiqueta.TextStrokeTransparency = 0.2
	etiqueta.RichText = true
	for k, v in props do
		etiqueta[k] = v
	end
	etiqueta.Parent = padre
	return etiqueta
end

local function boton(padre: Instance, props: { [string]: any }, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.2
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	for k, v in props do
		b[k] = v
	end
	b.Parent = padre
	redondear(b, 10)
	borde(b, Color3.new(0, 0, 0), 2)
	return b
end

---------------------------------------------------------------------
-- MARCADOR DE DINERO
---------------------------------------------------------------------
local panelDinero = Instance.new("Frame")
panelDinero.AnchorPoint = Vector2.new(0.5, 1)
panelDinero.Position = UDim2.new(0.5, 0, 1, -10)
panelDinero.Size = UDim2.fromOffset(280, 78)
panelDinero.BackgroundColor3 = COLOR_PANEL
panelDinero.BackgroundTransparency = 0.15
panelDinero.Parent = gui
redondear(panelDinero, 14)
borde(panelDinero, COLOR_CIAN)

local etiquetaDinero = texto(panelDinero, {
	Size = UDim2.new(1, -16, 0.58, 0),
	Position = UDim2.fromOffset(8, 4),
	Text = "$0",
	TextColor3 = Color3.fromRGB(130, 255, 160),
})
local etiquetaIngreso = texto(panelDinero, {
	Size = UDim2.new(1, -16, 0.32, 0),
	Position = UDim2.new(0, 8, 0.62, 0),
	Text = "+$0/s",
	TextColor3 = Color3.fromRGB(210, 255, 225),
})

local function actualizarMarcador()
	etiquetaDinero.Text = "$" .. abreviar(jugador:GetAttribute("Dinero") or 0)
	local multiplicador = jugador:GetAttribute("Multiplicador") or 1
	local extra = if multiplicador > 1.001 then string.format('  <font color="#FFD54A">x%.1f</font>', multiplicador) else ""
	etiquetaIngreso.Text = "+$" .. abreviar(jugador:GetAttribute("Ingreso") or 0) .. "/s" .. extra
end
for _, atributo in { "Dinero", "Ingreso", "Multiplicador" } do
	jugador:GetAttributeChangedSignal(atributo):Connect(actualizarMarcador)
end
actualizarMarcador()

---------------------------------------------------------------------
-- AVISOS
---------------------------------------------------------------------
local listaAvisos = Instance.new("Frame")
listaAvisos.AnchorPoint = Vector2.new(0.5, 0)
listaAvisos.Position = UDim2.new(0.5, 0, 0, 96)
listaAvisos.Size = UDim2.new(0.7, 0, 0, 230)
listaAvisos.BackgroundTransparency = 1
listaAvisos.Parent = gui
local ordenAvisos = Instance.new("UIListLayout")
ordenAvisos.HorizontalAlignment = Enum.HorizontalAlignment.Center
ordenAvisos.Padding = UDim.new(0, 2)
ordenAvisos.Parent = listaAvisos

local function mostrarAviso(mensaje: string, color: Color3?)
	local etiqueta = texto(listaAvisos, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = mensaje,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
	})
	local hijos = {}
	for _, hijo in listaAvisos:GetChildren() do
		if hijo:IsA("TextLabel") then
			table.insert(hijos, hijo)
		end
	end
	if #hijos > 6 then
		hijos[1]:Destroy()
	end
	task.delay(4, function()
		if etiqueta.Parent then
			local desvanecer = TweenService:Create(etiqueta, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			desvanecer:Play()
			desvanecer.Completed:Wait()
			etiqueta:Destroy()
		end
	end)
end
eAviso.OnClientEvent:Connect(mostrarAviso)

eEfecto.OnClientEvent:Connect(sonar)

---------------------------------------------------------------------
-- BANNERS: eventos, boost y "llevando"
---------------------------------------------------------------------
local bannerEventos = texto(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(520, 34),
	Text = "",
	TextStrokeTransparency = 0,
})
local bannerProximo = texto(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.fromOffset(420, 22),
	Text = "",
	TextColor3 = Color3.fromRGB(200, 200, 230),
})
local bannerLlevando = texto(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -98),
	Size = UDim2.fromOffset(480, 38),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 220, 80),
	TextStrokeTransparency = 0,
	Visible = false,
})

task.spawn(function()
	while true do
		local t = ahora()
		local lineas = {}
		local suerte = (remotos:GetAttribute("SuerteHasta") or 0) - t
		if suerte > 0 then
			table.insert(lineas, '<font color="#78FF78">🍀 LUCKY BELT ' .. Formato.tiempo(suerte) .. "</font>")
		end
		local meteoros = (remotos:GetAttribute("MeteoritosHasta") or 0) - t
		if meteoros > 0 then
			table.insert(lineas, '<font color="#FFAA50">☄️ METEOR SHOWER ' .. Formato.tiempo(meteoros) .. "</font>")
		end
		local boost = (jugador:GetAttribute("BoostHasta") or 0) - t
		if boost > 0 then
			table.insert(lineas, '<font color="#FFD54A">⚡ 2x ' .. Formato.tiempo(boost) .. "</font>")
		end
		bannerEventos.Text = table.concat(lineas, "   ")

		local proximos = {}
		local proximaSuerte = (remotos:GetAttribute("ProximaSuerte") or 0) - t
		if suerte <= 0 and proximaSuerte > 0 then
			table.insert(proximos, "🍀 in " .. Formato.tiempo(proximaSuerte))
		end
		local proximosMeteoros = (remotos:GetAttribute("ProximosMeteoritos") or 0) - t
		if meteoros <= 0 and proximosMeteoros > 0 then
			table.insert(proximos, "☄️ in " .. Formato.tiempo(proximosMeteoros))
		end
		bannerProximo.Text = table.concat(proximos, "   ")

		local llevando = jugador:GetAttribute("Llevando")
		bannerLlevando.Visible = llevando ~= nil
		if llevando then
			bannerLlevando.Text = "🏃 Carrying " .. llevando .. " — run to your base!"
		end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------
-- PANELES (solo uno abierto a la vez)
---------------------------------------------------------------------
local paneles: { Frame } = {}

local function crearPanel(titulo: string, colorBorde: Color3): (Frame, ScrollingFrame)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 440)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.Visible = false
	panel.ZIndex = 5
	panel.Parent = gui
	redondear(panel, 16)
	borde(panel, colorBorde)
	texto(panel, { Size = UDim2.new(1, -70, 0, 40), Position = UDim2.fromOffset(16, 8), Text = titulo, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	local cerrar = boton(panel, { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -48, 0, 8), Text = "X", ZIndex = 6 }, Color3.fromRGB(230, 60, 70))
	cerrar.Activated:Connect(function()
		panel.Visible = false
	end)
	local lista = Instance.new("ScrollingFrame")
	lista.Position = UDim2.fromOffset(12, 56)
	lista.Size = UDim2.new(1, -24, 1, -68)
	lista.BackgroundTransparency = 1
	lista.ScrollBarThickness = 6
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.CanvasSize = UDim2.new()
	lista.BorderSizePixel = 0
	lista.ZIndex = 6
	lista.Parent = panel
	local orden = Instance.new("UIListLayout")
	orden.Padding = UDim.new(0, 8)
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = lista
	table.insert(paneles, panel)
	return panel, lista
end

local function abrir(panel: Frame)
	local abierto = panel.Visible
	for _, p in paneles do
		p.Visible = false
	end
	panel.Visible = not abierto
end

---------------------------------------------------------------------
-- ÍNDICE Y PROBABILIDADES
-- Roblox exige mostrar las probabilidades exactas (en %) de todo lo que cambie
-- un objeto de pago como "Server Luck", antes de comprarlo y mientras está activo.
---------------------------------------------------------------------
local panelIndice, listaIndice = crearPanel("📖 INDEX & ODDS", Color3.fromRGB(150, 120, 255))
local cabeceraIndice = texto(listaIndice, { Size = UDim2.new(1, -8, 0, 48), Text = "", TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, ZIndex = 7 })
local filasIndice: { [string]: TextLabel } = {}

for orden, alien in Config.ALIENS do
	local rareza = Config.RAREZAS[alien.rareza]
	local fila = Instance.new("Frame")
	fila.Size = UDim2.new(1, -8, 0, 46)
	fila.BackgroundColor3 = Color3.fromRGB(45, 38, 80)
	fila.LayoutOrder = orden
	fila.ZIndex = 7
	fila.Parent = listaIndice
	redondear(fila, 10)
	local muestra = Instance.new("Frame")
	muestra.Size = UDim2.fromOffset(30, 30)
	muestra.Position = UDim2.new(0, 8, 0.5, -15)
	muestra.BackgroundColor3 = rgb(alien.color)
	muestra.ZIndex = 8
	muestra.Parent = fila
	redondear(muestra, 15)
	borde(muestra, rgb(rareza.color), 2)
	filasIndice[alien.id] = texto(fila, {
		Size = UDim2.new(1, -54, 1, -8),
		Position = UDim2.fromOffset(46, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 8,
	})
end

texto(listaIndice, {
	Size = UDim2.new(1, -8, 0, 40),
	LayoutOrder = 100,
	TextColor3 = Color3.fromRGB(190, 190, 220),
	ZIndex = 7,
	Text = string.format(
		"Each alien has a %s chance to spawn Shiny (x%d income), not affected by luck. Probabilities are rounded; the total of displayed probabilities may not equal 100%%.",
		Formato.porcentaje(Config.SHINY.PROBABILIDAD),
		Config.SHINY.MULTIPLICADOR_INGRESO
	),
})

local botonSuerteIndice = boton(listaIndice, { Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 101, Text = "🍀 Buy Server Luck", ZIndex = 7 }, Color3.fromRGB(40, 160, 80))
botonSuerteIndice.Activated:Connect(function()
	ePedirCompra:FireServer("PRODUCTO_SUERTE_SERVIDOR")
end)

local function actualizarIndice()
	local indice = {}
	local json = jugador:GetAttribute("Indice")
	if json then
		local ok, resultado = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if ok and type(resultado) == "table" then
			indice = resultado
		end
	end
	local suerteActiva = ahora() < (remotos:GetAttribute("SuerteHasta") or 0)
	local normal = Probabilidades.porAlien(Config.RAREZAS, Config.ALIENS, false, Config.EVENTOS.MULTIPLICADOR_SUERTE)
	local conSuerte = Probabilidades.porAlien(Config.RAREZAS, Config.ALIENS, true, Config.EVENTOS.MULTIPLICADOR_SUERTE)
	local descubiertos = 0
	for i, alien in Config.ALIENS do
		local rareza = Config.RAREZAS[alien.rareza]
		local estado = indice[alien.id]
		if estado then
			descubiertos += 1
		end
		local marca = if estado == 2 then "✨" elseif estado then "✅" else "❔"
		local probabilidad = if suerteActiva
			then string.format('<font color="#78FF78">%s</font> <font color="#9A96B8">(normal %s)</font>', Formato.porcentaje(conSuerte[i].probabilidad), Formato.porcentaje(normal[i].probabilidad))
			else string.format('%s <font color="#9A96B8">(luck: %s)</font>', Formato.porcentaje(normal[i].probabilidad), Formato.porcentaje(conSuerte[i].probabilidad))
		filasIndice[alien.id].Text = string.format(
			'%s <font color="#%s">%s</font> · %s · $%s/s\n<font size="14">Chance: %s</font>',
			marca,
			rgb(rareza.color):ToHex(),
			alien.nombre,
			rareza.nombre,
			abreviar(alien.ingreso),
			probabilidad
		)
	end
	cabeceraIndice.Text = string.format(
		"Discovered %d/%d\n%s",
		descubiertos,
		#Config.ALIENS,
		if suerteActiva then '<font color="#78FF78">🍀 LUCK ACTIVE: Epic and rarer x' .. Config.EVENTOS.MULTIPLICADOR_SUERTE .. "</font>" else "Spawn chance per alien on the belt"
	)
	local articulo = Config.articuloPorClave("PRODUCTO_SUERTE_SERVIDOR")
	local restringido = jugador:GetAttribute("SuerteRestringida") ~= false
	botonSuerteIndice.Visible = articulo ~= nil and articulo.id ~= 0
	if restringido then
		botonSuerteIndice.Text = "🍀 Server Luck: unavailable in your region"
		botonSuerteIndice.AutoButtonColor = false
		botonSuerteIndice.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	else
		botonSuerteIndice.Text = "🍀 Buy Server Luck: Epic and rarer x" .. Config.EVENTOS.MULTIPLICADOR_SUERTE .. " for everyone (3 min)"
		botonSuerteIndice.AutoButtonColor = true
		botonSuerteIndice.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	end
end
jugador:GetAttributeChangedSignal("Indice"):Connect(actualizarIndice)
jugador:GetAttributeChangedSignal("SuerteRestringida"):Connect(actualizarIndice)
remotos:GetAttributeChangedSignal("SuerteHasta"):Connect(actualizarIndice)
task.spawn(function()
	-- refresca al acabar la suerte
	while true do
		task.wait(5)
		if panelIndice.Visible then
			actualizarIndice()
		end
	end
end)
actualizarIndice()

---------------------------------------------------------------------
-- TIENDA
---------------------------------------------------------------------
local panelTienda, listaTienda = crearPanel("🛒 SHOP", COLOR_ORO)

local botonAnuncio = boton(listaTienda, {
	Size = UDim2.new(1, -8, 0, 52),
	LayoutOrder = 0,
	Text = "📺 Watch an ad → 2x income for 10 min",
	Visible = false,
	ZIndex = 7,
}, Color3.fromRGB(60, 120, 220))
botonAnuncio.Activated:Connect(function()
	botonAnuncio.Visible = false
	eAnuncio:FireServer()
end)

local function comprobarAnuncio()
	if Config.ANUNCIO_RECOMPENSA_PRODUCTO == 0 then
		return
	end
	task.spawn(function()
		local ok, resultado = pcall(function()
			return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
		end)
		botonAnuncio.Visible = ok and resultado ~= nil and resultado.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
	end)
end
eAnuncio.OnClientEvent:Connect(function()
	task.wait(1)
	if panelTienda.Visible then
		comprobarAnuncio()
	end
end)

for orden, articulo in Config.TIENDA do
	local disponible = articulo.id ~= 0
	local fila = boton(listaTienda, {
		Size = UDim2.new(1, -8, 0, 68),
		LayoutOrder = orden,
		Text = "",
		AutoButtonColor = disponible,
		ZIndex = 7,
	}, if disponible then Color3.fromRGB(60, 50, 105) else Color3.fromRGB(55, 55, 62))
	texto(fila, {
		Size = UDim2.new(0.68, -10, 0.55, 0),
		Position = UDim2.fromOffset(10, 4),
		Text = articulo.titulo,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
	})
	texto(fila, {
		Size = UDim2.new(0.68, -10, 0.36, 0),
		Position = UDim2.new(0, 10, 0.58, 0),
		Text = if disponible then articulo.descripcion else "Coming soon",
		TextColor3 = Color3.fromRGB(205, 205, 235),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
	})
	local precio = texto(fila, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.3, 0, 0.5, 0),
		Text = if disponible then "..." else "",
		TextColor3 = Color3.fromRGB(130, 255, 160),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
	})
	if disponible then
		task.spawn(function()
			local tipo = if articulo.tipo == "pase" then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(articulo.id, tipo)
			end)
			if ok and info and info.PriceInRobux then
				precio.Text = "R$ " .. tostring(info.PriceInRobux)
			else
				precio.Text = "R$"
			end
		end)
		local atributoPase = if articulo.clave == "PASE_DOBLE_DINERO"
			then "PaseDoble"
			elseif articulo.clave == "PASE_VIP" then "VIP"
			elseif articulo.clave == "PASE_CANDADO_PLUS" then "PaseCandado"
			else nil
		if atributoPase then
			local function marcarComprado()
				if jugador:GetAttribute(atributoPase) then
					precio.Text = "OWNED ✅"
				end
			end
			jugador:GetAttributeChangedSignal(atributoPase):Connect(marcarComprado)
			marcarComprado()
		end
	end
	fila.Activated:Connect(function()
		if not disponible then
			return
		end
		if articulo.clave == "PRODUCTO_SUERTE_SERVIDOR" then
			-- Primero se enseñan las probabilidades (norma de Roblox).
			actualizarIndice()
			abrir(panelIndice)
			return
		end
		ePedirCompra:FireServer(articulo.clave)
	end)
end

---------------------------------------------------------------------
-- CÓDIGOS
---------------------------------------------------------------------
local panelCodigos, listaCodigos = crearPanel("🎁 CODES", Color3.fromRGB(255, 120, 200))
panelCodigos.Size = UDim2.fromOffset(420, 250)
texto(listaCodigos, { Size = UDim2.new(1, -8, 0, 26), Text = "Follow us for new codes!", TextColor3 = Color3.fromRGB(200, 200, 230), LayoutOrder = 1, ZIndex = 7 })
local cajaCodigo = Instance.new("TextBox")
cajaCodigo.Size = UDim2.new(1, -8, 0, 48)
cajaCodigo.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
cajaCodigo.TextColor3 = Color3.new(1, 1, 1)
cajaCodigo.PlaceholderText = "Enter code..."
cajaCodigo.Font = Enum.Font.FredokaOne
cajaCodigo.TextScaled = true
cajaCodigo.ClearTextOnFocus = false
cajaCodigo.Text = ""
cajaCodigo.LayoutOrder = 2
cajaCodigo.ZIndex = 7
cajaCodigo.Parent = listaCodigos
redondear(cajaCodigo, 10)
local resultadoCodigo = texto(listaCodigos, { Size = UDim2.new(1, -8, 0, 26), Text = "", LayoutOrder = 4, ZIndex = 7 })
local canjear = boton(listaCodigos, { Size = UDim2.new(1, -8, 0, 46), Text = "REDEEM", LayoutOrder = 3, ZIndex = 7 }, Color3.fromRGB(255, 100, 190))
local canjeando = false
canjear.Activated:Connect(function()
	if canjeando or cajaCodigo.Text == "" then
		return
	end
	canjeando = true
	local ok, exito, mensaje = pcall(function()
		return fCodigo:InvokeServer(cajaCodigo.Text)
	end)
	if ok then
		resultadoCodigo.Text = mensaje or ""
		resultadoCodigo.TextColor3 = if exito then Color3.fromRGB(120, 255, 150) else Color3.fromRGB(255, 120, 120)
	end
	canjeando = false
end)

---------------------------------------------------------------------
-- BOTONES DEL MENÚ
---------------------------------------------------------------------
local menu = Instance.new("Frame")
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 10, 0.5, 0)
menu.Size = UDim2.fromOffset(110, 260)
menu.BackgroundTransparency = 1
menu.Parent = gui
local ordenMenu = Instance.new("UIListLayout")
ordenMenu.Padding = UDim.new(0, 8)
ordenMenu.Parent = menu

local function botonMenu(textoBoton: string, color: Color3, alPulsar: () -> ())
	local b = boton(menu, { Size = UDim2.fromOffset(110, 52), Text = textoBoton }, color)
	b.Activated:Connect(alPulsar)
	return b
end

botonMenu("🛒 SHOP", COLOR_ORO, function()
	abrir(panelTienda)
	if panelTienda.Visible then
		comprobarAnuncio()
	end
end)
botonMenu("📖 INDEX\nODDS", Color3.fromRGB(150, 120, 255), function()
	actualizarIndice()
	abrir(panelIndice)
end)
botonMenu("🎁 CODES", Color3.fromRGB(255, 100, 190), function()
	abrir(panelCodigos)
end)
botonMenu("👥 INVITE", Color3.fromRGB(60, 160, 255), function()
	task.spawn(function()
		local ok, puede = pcall(function()
			return SocialService:CanSendGameInviteAsync(jugador)
		end)
		if ok and puede then
			pcall(function()
				SocialService:PromptGameInvite(jugador)
			end)
		else
			mostrarAviso("Invites are not available right now.", Color3.fromRGB(255, 150, 150))
		end
	end)
end)

---------------------------------------------------------------------
-- RECOMPENSA DIARIA
---------------------------------------------------------------------
eDiario.OnClientEvent:Connect(function(racha: number, cantidad: number)
	local ventana = Instance.new("Frame")
	ventana.AnchorPoint = Vector2.new(0.5, 0.5)
	ventana.Position = UDim2.fromScale(0.5, 0.45)
	ventana.Size = UDim2.fromOffset(360, 210)
	ventana.BackgroundColor3 = COLOR_PANEL
	ventana.ZIndex = 20
	ventana.Parent = gui
	redondear(ventana, 18)
	borde(ventana, COLOR_ORO, 4)
	texto(ventana, { Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 10), Text = "🎁 DAILY REWARD", TextColor3 = COLOR_ORO, ZIndex = 21 })
	texto(ventana, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 58), Text = "Day " .. racha .. " streak 🔥", ZIndex = 21 })
	texto(ventana, { Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 92), Text = "+$" .. abreviar(cantidad), TextColor3 = Color3.fromRGB(130, 255, 160), ZIndex = 21 })
	local ok = boton(ventana, { Size = UDim2.new(0.6, 0, 0, 44), Position = UDim2.new(0.2, 0, 1, -56), Text = "AWESOME!", ZIndex = 21 }, Color3.fromRGB(40, 180, 90))
	ok.Activated:Connect(function()
		ventana:Destroy()
	end)
	sonar("EVENTO")
	task.delay(12, function()
		if ventana.Parent then
			ventana:Destroy()
		end
	end)
end)

---------------------------------------------------------------------
-- TUTORIAL: rayo que señala el siguiente objetivo
---------------------------------------------------------------------
local TEXTOS_TUTORIAL = {
	"👇 BUY AN ALIEN",
	"💰 COLLECT YOUR CASH",
	"🔒 LOCK YOUR BASE",
}
local objetivoTutorial = Instance.new("Part")
objetivoTutorial.Name = "ObjetivoTutorial"
objetivoTutorial.Anchored = true
objetivoTutorial.CanCollide = false
objetivoTutorial.CanQuery = false
objetivoTutorial.CanTouch = false
objetivoTutorial.Transparency = 1
objetivoTutorial.Size = Vector3.one
local adjuntoObjetivo = Instance.new("Attachment")
adjuntoObjetivo.Parent = objetivoTutorial
local cartelTutorial = Instance.new("BillboardGui")
cartelTutorial.Size = UDim2.fromOffset(260, 60)
cartelTutorial.StudsOffset = Vector3.new(0, 4, 0)
cartelTutorial.AlwaysOnTop = true
cartelTutorial.Parent = objetivoTutorial
local textoTutorial = texto(cartelTutorial, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = COLOR_CIAN, TextStrokeTransparency = 0 })
local rayo = Instance.new("Beam")
rayo.Color = ColorSequence.new(COLOR_CIAN)
rayo.Width0 = 0.6
rayo.Width1 = 0.6
rayo.FaceCamera = true
rayo.LightEmission = 1
rayo.Transparency = NumberSequence.new(0.2)
rayo.Attachment1 = adjuntoObjetivo
rayo.Parent = objetivoTutorial

local function actualizarTutorial()
	local paso = jugador:GetAttribute("Tutorial") or 0
	local destino = jugador:GetAttribute("TutorialObjetivo")
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if paso > 0 and destino and raiz then
		objetivoTutorial.Position = destino
		textoTutorial.Text = TEXTOS_TUTORIAL[paso] or ""
		local adjunto = raiz:FindFirstChild("AdjuntoTutorial")
		if not adjunto then
			adjunto = Instance.new("Attachment")
			adjunto.Name = "AdjuntoTutorial"
			adjunto.Parent = raiz
		end
		rayo.Attachment0 = adjunto
		objetivoTutorial.Parent = workspace
	else
		objetivoTutorial.Parent = nil
	end
end
jugador:GetAttributeChangedSignal("Tutorial"):Connect(actualizarTutorial)
jugador:GetAttributeChangedSignal("TutorialObjetivo"):Connect(actualizarTutorial)
jugador.CharacterAdded:Connect(function(personaje)
	personaje:WaitForChild("HumanoidRootPart", 10)
	actualizarTutorial()
end)
actualizarTutorial()

---------------------------------------------------------------------
-- CARTELES PERSONALES EN LOS PUESTOS (precio según tu progreso)
---------------------------------------------------------------------
task.spawn(function()
	local puestos = workspace:WaitForChild("Mapa"):WaitForChild("Puestos")
	local cartelVelocidad = puestos:WaitForChild("Velocidad"):WaitForChild("Cartel"):WaitForChild("Texto")
	local cartelRebirth = puestos:WaitForChild("Rebirth"):WaitForChild("Cartel"):WaitForChild("Texto")
	local function actualizar()
		local nivel = jugador:GetAttribute("NivelVelocidad") or 0
		if nivel >= Config.JUEGO.NIVEL_VELOCIDAD_MAX then
			cartelVelocidad.Text = "⚡ SPEED\nMAX"
		else
			cartelVelocidad.Text = string.format("⚡ SPEED\nLv %d → %d: $%s", nivel, nivel + 1, abreviar(Config.costeVelocidad(nivel)))
		end
		local rebirths = jugador:GetAttribute("Rebirths") or 0
		cartelRebirth.Text = string.format("🌌 REBIRTH %d\n$%s → +50%% income", rebirths + 1, abreviar(Config.costeRebirth(rebirths)))
	end
	jugador:GetAttributeChangedSignal("NivelVelocidad"):Connect(actualizar)
	jugador:GetAttributeChangedSignal("Rebirths"):Connect(actualizar)
	actualizar()
end)

---------------------------------------------------------------------
-- ETIQUETA VIP EN EL CHAT
---------------------------------------------------------------------
TextChatService.OnIncomingMessage = function(mensaje: TextChatMessage)
	local propiedades = Instance.new("TextChatMessageProperties")
	local fuente = mensaje.TextSource
	if fuente then
		local autor = Players:GetPlayerByUserId(fuente.UserId)
		if autor and autor:GetAttribute("VIP") then
			propiedades.PrefixText = '<font color="#FFC828">[VIP]</font> ' .. mensaje.PrefixText
		end
	end
	return propiedades
end
