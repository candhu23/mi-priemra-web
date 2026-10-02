--!nonstrict
--[[
	STEAL AN ALIEN — servidor principal

	Bucle de juego:
	  1. Compra aliens en la cinta central.
	  2. Tus aliens generan dinero por segundo: pisa la placa verde para cobrarlo.
	  3. Roba aliens de otras bases y llévalos a la tuya. Usa SLAP para frenar a los ladrones.
	  4. Cierra tu base con la placa roja.
	  5. Mejora la velocidad y haz Rebirth (+50 % de ingresos y +1 pedestal).
	  Eventos: Lucky Belt (suerte) y Meteor Shower (cristales con dinero).

	Toda la configuración está en ReplicatedStorage/Compartido/Config.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local PolicyService = game:GetService("PolicyService")
local AdService = game:GetService("AdService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local Compartido = ReplicatedStorage:WaitForChild("Compartido")
local Config = require(Compartido:WaitForChild("Config"))
local Formato = require(Compartido:WaitForChild("Formato"))
local Probabilidades = require(Compartido:WaitForChild("Probabilidades"))
local Perfil = require(script.Parent:WaitForChild("Perfil"))
local Datos = require(script.Parent:WaitForChild("Datos"))
local Modelos = require(script.Parent:WaitForChild("Modelos"))
local Mapa = require(script.Parent:WaitForChild("Mapa"))
local Codigos = require(script.Parent:WaitForChild("Codigos"))

local J = Config.JUEGO
local E = Config.EVENTOS
local abreviar = Formato.abreviar

local VERDE = Color3.fromRGB(120, 255, 150)
local ROJO = Color3.fromRGB(255, 110, 110)
local AMARILLO = Color3.fromRGB(255, 220, 80)

---------------------------------------------------------------------
-- COMUNICACIÓN CON LOS CLIENTES
---------------------------------------------------------------------
local remotos = Instance.new("Folder")
remotos.Name = "Remotos"

local function nuevoEvento(nombre: string): RemoteEvent
	local evento = Instance.new("RemoteEvent")
	evento.Name = nombre
	evento.Parent = remotos
	return evento
end

local eAviso = nuevoEvento("Aviso") -- servidor -> cliente: (texto, color)
local eGolpeado = nuevoEvento("Golpeado") -- servidor -> cliente: (dirección del empujón)
local eDiario = nuevoEvento("RecompensaDiaria") -- servidor -> cliente: (racha, cantidad)
local eEfecto = nuevoEvento("Efecto") -- servidor -> cliente: (nombre del sonido/efecto)
local ePedirCompra = nuevoEvento("PedirCompra") -- cliente -> servidor: (clave de la tienda)
local eAnuncio = nuevoEvento("VerAnuncio") -- cliente -> servidor; servidor -> cliente: (ok, resultado)
local fCodigo = Instance.new("RemoteFunction")
fCodigo.Name = "CanjearCodigo"
fCodigo.Parent = remotos

remotos:SetAttribute("SuerteHasta", 0)
remotos:SetAttribute("MeteoritosHasta", 0)
remotos:SetAttribute("ProximaSuerte", 0)
remotos:SetAttribute("ProximosMeteoritos", 0)
remotos.Parent = ReplicatedStorage

local function ahora(): number
	return workspace:GetServerTimeNow()
end

local function avisar(jugador: Player, texto: string, color: Color3?)
	eAviso:FireClient(jugador, texto, color)
end

local function avisarATodos(texto: string, color: Color3?)
	eAviso:FireAllClients(texto, color)
end

local function efecto(jugador: Player, nombre: string)
	eEfecto:FireClient(jugador, nombre)
end

local function personajeVivo(jugador: Player?): (Model?, Humanoid?, BasePart?)
	local personaje = jugador and jugador.Character
	if not personaje then
		return nil, nil, nil
	end
	local humanoid = personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if humanoid and raiz and raiz:IsA("BasePart") and humanoid.Health > 0 then
		return personaje, humanoid, raiz
	end
	return nil, nil, nil
end

local function jugadorDesdeToque(golpe: BasePart): Player?
	local modelo = golpe:FindFirstAncestorOfClass("Model")
	return if modelo then Players:GetPlayerFromCharacter(modelo) else nil
end

---------------------------------------------------------------------
-- MAPA
---------------------------------------------------------------------
local mapa = Mapa.construir()
local carpetaCinta = Instance.new("Folder")
carpetaCinta.Name = "Cinta"
carpetaCinta.Parent = workspace

---------------------------------------------------------------------
-- SESIONES
---------------------------------------------------------------------
type Carga = { id: string, shiny: boolean, victima: Player?, base: any, slot: number, modelo: Model }

type Sesion = {
	datos: Perfil.Datos,
	base: any,
	llevando: Carga?,
	pases: { doble: boolean, vip: boolean, candadoPlus: boolean },
	amigos: number,
	grupo: boolean,
	cargado: boolean,
	sinGuardado: boolean,
	suerteRestringida: boolean,
	ultimaAccion: { [string]: number },
	ultimaPos: Vector3?,
	ultimaPosT: number,
	tutorial: number,
	boostAvisado: boolean,
}

local sesiones: { [Player]: Sesion } = {}

-- Limita cuántas veces por segundo puede hacer algo un jugador (protege de spam y trampas).
local function permitido(sesion: Sesion, accion: string, segundos: number): boolean
	local t = os.clock()
	local ultima = sesion.ultimaAccion[accion]
	if ultima and t - ultima < segundos then
		return false
	end
	sesion.ultimaAccion[accion] = t
	return true
end

local function bonos(sesion: Sesion): Config.Bonos
	return {
		rebirths = sesion.datos.rebirths,
		dobleDinero = sesion.pases.doble,
		vip = sesion.pases.vip,
		amigos = sesion.amigos,
		grupo = sesion.grupo,
		boost = sesion.datos.boostHasta > os.time(),
	}
end

local function ingresoBase(sesion: Sesion): number
	local total = 0
	for _, slot in sesion.base.slots do
		if slot.id then
			local alien = Config.alienPorId(slot.id)
			if alien then
				total += Config.ingresoAlien(alien, slot.shiny)
			end
		end
	end
	return total
end

local function ingresoPorSegundo(sesion: Sesion): number
	return ingresoBase(sesion) * Config.multiplicadorIngresos(bonos(sesion))
end

local function actualizarStats(jugador: Player)
	local sesion = sesiones[jugador]
	local stats = jugador:FindFirstChild("leaderstats")
	if not sesion or not stats then
		return
	end
	local datos = sesion.datos
	stats.Cash.Value = math.floor(datos.dinero)
	stats.Rebirths.Value = datos.rebirths
	stats.Steals.Value = datos.stats.robos
	jugador:SetAttribute("Ingreso", ingresoPorSegundo(sesion))
	jugador:SetAttribute("Multiplicador", Config.multiplicadorIngresos(bonos(sesion)))
	jugador:SetAttribute("NivelVelocidad", datos.velocidad)
	jugador:SetAttribute("Rebirths", datos.rebirths)
	jugador:SetAttribute("Dinero", datos.dinero)
	jugador:SetAttribute("Amigos", sesion.amigos)
	jugador:SetAttribute("Grupo", sesion.grupo)
	local restanteBoost = datos.boostHasta - os.time()
	jugador:SetAttribute("BoostHasta", if restanteBoost > 0 then ahora() + restanteBoost else 0)
end

local function sumarDinero(jugador: Player, cantidad: number)
	local sesion = sesiones[jugador]
	if not sesion then
		return
	end
	sesion.datos.dinero = math.max(0, sesion.datos.dinero + cantidad)
	if cantidad > 0 then
		sesion.datos.stats.ganadoTotal += cantidad
	end
	actualizarStats(jugador)
end

local function actualizarVelocidad(jugador: Player)
	local sesion = sesiones[jugador]
	local _, humanoid = personajeVivo(jugador)
	if not sesion or not humanoid then
		return
	end
	local v = J.VELOCIDAD_BASE + sesion.datos.velocidad * J.VELOCIDAD_POR_NIVEL
	if sesion.pases.vip then
		v += J.VELOCIDAD_VIP
	end
	if sesion.llevando then
		v *= J.FACTOR_VELOCIDAD_CARGANDO
	end
	humanoid.WalkSpeed = v
end

local function actualizarIndiceAtributo(jugador: Player, sesion: Sesion)
	jugador:SetAttribute("Indice", HttpService:JSONEncode(sesion.datos.indice))
end

-- Apunta un alien en el Índice (colección) del jugador.
local function registrarIndice(jugador: Player, sesion: Sesion, id: string, shiny: boolean)
	local antes = sesion.datos.indice[id]
	local nuevo = if shiny then 2 else 1
	if antes == nil or (antes or 0) < nuevo then
		sesion.datos.indice[id] = nuevo
		actualizarIndiceAtributo(jugador, sesion)
		local alien = Config.alienPorId(id)
		if alien then
			avisar(jugador, "📖 NEW in your Index: " .. (if shiny then "✨ Shiny " else "") .. alien.nombre .. "!", Color3.fromRGB(180, 200, 255))
		end
	end
end

---------------------------------------------------------------------
-- TUTORIAL (primeros minutos: lo que más pesa en el algoritmo de Roblox)
---------------------------------------------------------------------
local function ponerPasoTutorial(jugador: Player, sesion: Sesion, paso: number)
	sesion.tutorial = paso
	local base = sesion.base
	jugador:SetAttribute("Tutorial", paso)
	if paso == 1 then
		jugador:SetAttribute("TutorialObjetivo", Vector3.new(base.x, 4, 0))
	elseif paso == 2 then
		jugador:SetAttribute("TutorialObjetivo", base.placaCobro.Position + Vector3.new(0, 2, 0))
	elseif paso == 3 then
		jugador:SetAttribute("TutorialObjetivo", base.placaCandado.Position + Vector3.new(0, 2, 0))
	else
		jugador:SetAttribute("TutorialObjetivo", nil)
	end
end

local function avanzarTutorial(jugador: Player, sesion: Sesion, pasoCompletado: number)
	if sesion.tutorial ~= pasoCompletado then
		return
	end
	if pasoCompletado >= 3 then
		sesion.datos.tutorialHecho = true
		ponerPasoTutorial(jugador, sesion, 0)
		avisar(jugador, "🦹 Now sneak into other bases and STEAL their aliens!", AMARILLO)
		task.delay(3, function()
			if jugador.Parent then
				avisar(jugador, "👋 Use SLAP on thieves to make them drop your aliens!", AMARILLO)
			end
		end)
	else
		ponerPasoTutorial(jugador, sesion, pasoCompletado + 1)
	end
end

---------------------------------------------------------------------
-- PEDESTALES Y ALIENS DE LAS BASES
---------------------------------------------------------------------
local robarAlien: (Player, any, number) -> ()
local venderAlien: (Player, any, number) -> ()

local function pintarPedestales(base: any, desbloqueados: number)
	for i, slot in base.slots do
		local bloqueado = i > desbloqueados
		slot.pedestal.Color = if bloqueado then Color3.fromRGB(45, 40, 60) else Color3.fromRGB(100, 90, 150)
		slot.pedestal.Transparency = if bloqueado then 0.5 else 0
		if bloqueado and base.dueno then
			slot.etiqueta.Text = "🔒 Rebirth"
		else
			slot.etiqueta.Text = ""
		end
	end
end

local function slotLibre(sesion: Sesion): number?
	local desbloqueados = Config.slotsDesbloqueados(sesion.datos.rebirths)
	for i = 1, desbloqueados do
		if not sesion.base.slots[i].id then
			return i
		end
	end
	return nil
end

local function colocarAlien(base: any, indice: number, id: string, shiny: boolean): boolean
	local slot = base.slots[indice]
	local alien = Config.alienPorId(id)
	if not slot or slot.id or not alien then
		return false
	end
	slot.id = id
	slot.shiny = shiny
	slot.etiqueta.Text = ""

	local modelo = Modelos.crear(alien, shiny)
	local giro = if base.lado == 1 then 0 else math.pi
	local cf = CFrame.new(slot.pedestal.Position + Vector3.new(0, 0.6 + alien.tamano * 0.65, 0)) * CFrame.Angles(0, giro, 0)
	modelo:PivotTo(cf)
	modelo:SetAttribute("PosBase", cf)
	CollectionService:AddTag(modelo, "AlienFlotante")
	slot.modelo = modelo

	local duenoId = if base.dueno then base.dueno.UserId else 0
	local raiz = modelo.PrimaryPart

	local promptRobar = Instance.new("ProximityPrompt")
	promptRobar.Name = "Robar"
	promptRobar.ActionText = "Steal"
	promptRobar.ObjectText = alien.nombre
	promptRobar.HoldDuration = 1.2
	promptRobar.RequiresLineOfSight = false
	promptRobar.MaxActivationDistance = 9
	promptRobar:SetAttribute("Dueno", duenoId)
	CollectionService:AddTag(promptRobar, "PromptRobar")
	promptRobar.Parent = raiz
	promptRobar.Triggered:Connect(function(jugador)
		robarAlien(jugador, base, indice)
	end)

	local promptVender = Instance.new("ProximityPrompt")
	promptVender.Name = "Vender"
	promptVender.ActionText = "Sell $" .. abreviar(Config.precioVenta(alien, shiny))
	promptVender.ObjectText = alien.nombre
	promptVender.HoldDuration = 1
	promptVender.RequiresLineOfSight = false
	promptVender.MaxActivationDistance = 9
	promptVender.KeyboardKeyCode = Enum.KeyCode.F
	promptVender:SetAttribute("Dueno", duenoId)
	CollectionService:AddTag(promptVender, "PromptVender")
	promptVender.Parent = raiz
	promptVender.Triggered:Connect(function(jugador)
		venderAlien(jugador, base, indice)
	end)

	modelo.Parent = base.carpeta
	if base.dueno then
		actualizarStats(base.dueno)
	end
	return true
end

local function quitarAlien(base: any, indice: number): (string?, boolean)
	local slot = base.slots[indice]
	local id, shiny = slot.id, slot.shiny
	if slot.modelo then
		slot.modelo:Destroy()
	end
	slot.id = nil
	slot.shiny = false
	slot.modelo = nil
	if base.dueno then
		actualizarStats(base.dueno)
	end
	return id, shiny
end

function venderAlien(jugador: Player, base: any, indice: number)
	local sesion = sesiones[jugador]
	if not sesion or base.dueno ~= jugador or not base.slots[indice].id or not permitido(sesion, "vender", 0.3) then
		return
	end
	local id, shiny = quitarAlien(base, indice)
	local alien = Config.alienPorId(id :: string)
	if not alien then
		return
	end
	local precio = Config.precioVenta(alien, shiny)
	sumarDinero(jugador, precio)
	avisar(jugador, "Sold " .. alien.nombre .. " for $" .. abreviar(precio), VERDE)
	efecto(jugador, "COBRAR")
end

-- Pasa los aliens de los pedestales a la lista que se guarda.
local function serializar(sesion: Sesion)
	local lista = {}
	for i, slot in sesion.base.slots do
		if slot.id then
			table.insert(lista, { s = i, id = slot.id, sh = if slot.shiny then true else nil })
		end
	end
	sesion.datos.aliens = lista
end

local function guardar(jugador: Player, liberar: boolean): boolean
	local sesion = sesiones[jugador]
	if not sesion or not sesion.cargado or sesion.sinGuardado then
		return false
	end
	serializar(sesion)
	sesion.datos.ultimaConexion = os.time()
	return Datos.guardar(jugador.UserId, sesion.datos, liberar)
end

---------------------------------------------------------------------
-- ROBAR
---------------------------------------------------------------------
local function soltarCarga(jugador: Player): Carga?
	local sesion = sesiones[jugador]
	local carga = sesion and sesion.llevando
	if not carga then
		return nil
	end
	sesion.llevando = nil
	carga.modelo:Destroy()
	jugador:SetAttribute("Llevando", nil)
	actualizarVelocidad(jugador)
	return carga
end

-- Devuelve el alien a su dueño (si sigue en el servidor y tiene sitio).
local function devolverCarga(jugador: Player, motivo: string?)
	local carga = soltarCarga(jugador)
	if not carga then
		return
	end
	local victima = carga.victima
	local sesionVictima = victima and sesiones[victima]
	if victima and sesionVictima and sesionVictima.base == carga.base then
		local indice = if carga.base.slots[carga.slot].id == nil then carga.slot else slotLibre(sesionVictima)
		if indice then
			colocarAlien(carga.base, indice, carga.id, carga.shiny)
			local alien = Config.alienPorId(carga.id)
			avisar(victima, "✅ Your " .. (if alien then alien.nombre else "alien") .. " is back home!", VERDE)
		end
	end
	if motivo and jugador.Parent then
		avisar(jugador, motivo, ROJO)
	end
end

local function entregarCarga(jugador: Player, sesion: Sesion)
	local carga = sesion.llevando
	if not carga then
		return
	end
	local indice = slotLibre(sesion)
	if not indice then
		devolverCarga(jugador, "Your base is full! Sell an alien or Rebirth for more space.")
		return
	end
	soltarCarga(jugador)
	colocarAlien(sesion.base, indice, carga.id, carga.shiny)
	sesion.datos.stats.robos += 1
	registrarIndice(jugador, sesion, carga.id, carga.shiny)
	actualizarStats(jugador)
	local alien = Config.alienPorId(carga.id)
	local nombre = if alien then alien.nombre else "alien"
	avisar(jugador, "🦹 STOLEN! " .. nombre .. " is yours now!", VERDE)
	efecto(jugador, "ROBAR")
	if carga.victima and carga.victima.Parent then
		avisar(carga.victima, "😱 " .. jugador.DisplayName .. " stole your " .. nombre .. "!", ROJO)
	end
	if alien and alien.rareza >= 4 then
		avisarATodos("🦹 " .. jugador.DisplayName .. " stole a " .. Config.RAREZAS[alien.rareza].nombre .. " " .. nombre .. "!", Modelos.rgb(Config.RAREZAS[alien.rareza].color))
	end
end

function robarAlien(ladron: Player, base: any, indice: number)
	local sesion = sesiones[ladron]
	local slot = base.slots[indice]
	if not sesion or not sesion.cargado or not slot.id or not base.dueno or base.dueno == ladron then
		return
	end
	if not permitido(sesion, "robar", 0.5) then
		return
	end
	if sesion.llevando then
		avisar(ladron, "You are already carrying an alien!")
		return
	end
	if ahora() < base.bloqueadaHasta then
		avisar(ladron, "🔒 This base is locked!", ROJO)
		return
	end
	local personaje, _, raiz = personajeVivo(ladron)
	local cabeza = personaje and personaje:FindFirstChild("Head")
	if not cabeza or not cabeza:IsA("BasePart") or not raiz or (raiz.Position - slot.pedestal.Position).Magnitude > 14 then
		return
	end

	local victima = base.dueno
	local id, shiny = quitarAlien(base, indice)
	local alien = Config.alienPorId(id :: string)
	if not alien then
		return
	end
	local modelo = Modelos.crear(alien, shiny)
	Modelos.prepararParaLlevar(modelo)
	modelo:PivotTo(cabeza.CFrame * CFrame.new(0, alien.tamano * 0.5 + 1.2, 0))
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cabeza
	soldadura.Part1 = modelo.PrimaryPart
	soldadura.Parent = modelo.PrimaryPart
	modelo.Parent = personaje

	sesion.llevando = { id = id :: string, shiny = shiny, victima = victima, base = base, slot = indice, modelo = modelo }
	sesion.ultimaPos = raiz.Position
	sesion.ultimaPosT = os.clock()
	ladron:SetAttribute("Llevando", alien.nombre)
	actualizarVelocidad(ladron)
	avisar(ladron, "🏃 Run back to your base!", AMARILLO)
	efecto(ladron, "ROBAR")
	avisar(victima, "⚠️ " .. ladron.DisplayName .. " is stealing your " .. alien.nombre .. "! SLAP them!", ROJO)
	efecto(victima, "ALARMA")
end

-- Vigila a los ladrones: entrega, caída, muerte y teletransportes (anti-trampas).
task.spawn(function()
	while true do
		task.wait(0.1)
		for jugador, sesion in sesiones do
			local carga = sesion.llevando
			if carga then
				local _, humanoid, raiz = personajeVivo(jugador)
				if not raiz or not humanoid then
					devolverCarga(jugador, "You lost the alien!")
				else
					local t = os.clock()
					local anterior = sesion.ultimaPos or raiz.Position
					local dt = t - sesion.ultimaPosT
					local horizontal = Vector3.new(raiz.Position.X - anterior.X, 0, raiz.Position.Z - anterior.Z).Magnitude
					local maximo = humanoid.WalkSpeed * dt * 1.6 + 8
					sesion.ultimaPos = raiz.Position
					sesion.ultimaPosT = t
					if horizontal > maximo then
						devolverCarga(jugador, "The alien slipped away!")
					elseif Mapa.dentroDeBase(sesion.base, raiz.Position) then
						entregarCarga(jugador, sesion)
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- SLAP (golpe para frenar ladrones)
---------------------------------------------------------------------
local plantillaSlap = Instance.new("Tool")
plantillaSlap.Name = "Slap"
plantillaSlap.ToolTip = "Slap thieves to make them drop stolen aliens!"
plantillaSlap.CanBeDropped = false
plantillaSlap.RequiresHandle = true
plantillaSlap.Grip = CFrame.new(0, -0.6, 0)
do
	local mango = Instance.new("Part")
	mango.Name = "Handle"
	mango.Shape = Enum.PartType.Ball
	mango.Size = Vector3.new(1.8, 1.8, 1.8)
	mango.Color = Color3.fromRGB(80, 255, 170)
	mango.Material = Enum.Material.Neon
	mango.CanCollide = false
	mango.Massless = true
	mango.Parent = plantillaSlap
	local brillo = Instance.new("PointLight")
	brillo.Color = mango.Color
	brillo.Range = 6
	brillo.Parent = mango
end

local function onda(posicion: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 2
	p.Position = posicion
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.2
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.35), { Size = Vector3.one * 8, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.4)
end

local function golpear(atacante: Player)
	local sesion = sesiones[atacante]
	if not sesion or not permitido(sesion, "golpe", J.ENFRIAMIENTO_GOLPE) then
		return
	end
	local _, _, raiz = personajeVivo(atacante)
	if not raiz then
		return
	end
	local mira = raiz.CFrame.LookVector
	local mejor: Player? = nil
	local mejorDistancia = math.huge
	for otro in sesiones do
		if otro ~= atacante then
			local _, _, raizOtro = personajeVivo(otro)
			if raizOtro then
				local diferencia = raizOtro.Position - raiz.Position
				local distancia = diferencia.Magnitude
				if distancia <= J.ALCANCE_GOLPE and distancia < mejorDistancia and (distancia < 4 or mira:Dot(diferencia.Unit) > 0.3) then
					mejor = otro
					mejorDistancia = distancia
				end
			end
		end
	end
	efecto(atacante, "GOLPE")
	if not mejor then
		return
	end
	local _, _, raizObjetivo = personajeVivo(mejor)
	if not raizObjetivo then
		return
	end
	local direccion = (raizObjetivo.Position - raiz.Position) * Vector3.new(1, 0, 1)
	direccion = if direccion.Magnitude > 0.01 then direccion.Unit else mira
	eGolpeado:FireClient(mejor, direccion)
	efecto(mejor, "GOLPE")
	onda(raizObjetivo.Position, Color3.fromRGB(80, 255, 170))
	local sesionObjetivo = sesiones[mejor]
	if sesionObjetivo and sesionObjetivo.llevando then
		devolverCarga(mejor, "💥 " .. atacante.DisplayName .. " slapped you! You dropped the alien.")
		avisar(atacante, "💥 Slapped " .. mejor.DisplayName .. "! The alien went back home.", VERDE)
	end
end

local function darSlap(jugador: Player)
	local mochila = jugador:FindFirstChildOfClass("Backpack")
	if not mochila or mochila:FindFirstChild("Slap") or (jugador.Character and jugador.Character:FindFirstChild("Slap")) then
		return
	end
	local herramienta = plantillaSlap:Clone()
	herramienta.Activated:Connect(function()
		golpear(jugador)
	end)
	herramienta.Parent = mochila
end

---------------------------------------------------------------------
-- PLACAS DE COBRO Y CANDADO
---------------------------------------------------------------------
local function cobrar(jugador: Player, sesion: Sesion)
	local cantidad = sesion.datos.pendiente
	if cantidad < 1 then
		return
	end
	sesion.datos.pendiente = 0
	sumarDinero(jugador, cantidad)
	sesion.base.textoCobro.Text = "$0"
	avisar(jugador, "+$" .. abreviar(cantidad), VERDE)
	efecto(jugador, "COBRAR")
	avanzarTutorial(jugador, sesion, 2)
end

local function bloquear(jugador: Player, sesion: Sesion)
	local base = sesion.base
	if ahora() < base.bloqueadaHasta then
		return
	end
	local duracion = if sesion.pases.vip then J.SEGUNDOS_CANDADO_VIP else J.SEGUNDOS_CANDADO
	if sesion.pases.candadoPlus then
		duracion *= 2
	end
	base.bloqueadaHasta = ahora() + duracion
	base.barrera.Transparency = 0.35
	base.barrera.CanTouch = true
	avisar(jugador, "🔒 Base locked for " .. duracion .. "s", Color3.fromRGB(255, 160, 170))
	avanzarTutorial(jugador, sesion, 3)
end

for _, base in mapa.bases do
	base.placaCobro.Touched:Connect(function(golpe)
		local jugador = jugadorDesdeToque(golpe)
		local sesion = jugador and sesiones[jugador]
		if jugador and sesion and sesion.cargado and base.dueno == jugador then
			cobrar(jugador, sesion)
		end
	end)
	base.placaCandado.Touched:Connect(function(golpe)
		local jugador = jugadorDesdeToque(golpe)
		local sesion = jugador and sesiones[jugador]
		if jugador and sesion and sesion.cargado and base.dueno == jugador then
			bloquear(jugador, sesion)
		end
	end)
	-- La barrera expulsa a quien no sea el dueño mientras la base está cerrada.
	base.barrera.Touched:Connect(function(golpe)
		local jugador = jugadorDesdeToque(golpe)
		if jugador and jugador ~= base.dueno then
			local personaje, _, raiz = personajeVivo(jugador)
			if personaje and raiz then
				local fuera = base.lado * (Mapa.FRENTE_BASE - 7)
				personaje:PivotTo(CFrame.new(raiz.Position.X, raiz.Position.Y + 1, fuera) * raiz.CFrame.Rotation)
			end
		end
	end)
end

-- Cada segundo: ingresos pasivos, candados y boosts.
task.spawn(function()
	while true do
		task.wait(1)
		for jugador, sesion in sesiones do
			if sesion.cargado then
				sesion.datos.pendiente += ingresoPorSegundo(sesion)
				sesion.base.textoCobro.Text = "$" .. abreviar(sesion.datos.pendiente)
				if sesion.datos.boostHasta > 0 and sesion.datos.boostHasta <= os.time() and not sesion.boostAvisado then
					sesion.boostAvisado = true
					avisar(jugador, "⚡ Your 2x boost ended.", AMARILLO)
				end
				actualizarStats(jugador)
			end
		end
		local t = ahora()
		for _, base in mapa.bases do
			local restante = math.ceil(base.bloqueadaHasta - t)
			if restante > 0 then
				base.textoCandado.Text = "🔒 " .. restante .. "s"
			elseif base.barrera.CanTouch then
				base.barrera.Transparency = 1
				base.barrera.CanTouch = false
				base.textoCandado.Text = "🔒 LOCK"
				if base.dueno then
					avisar(base.dueno, "🔓 Your base is unlocked!", AMARILLO)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- CINTA TRANSPORTADORA
-- El servidor crea los aliens y la interfaz de cada jugador los mueve (suave y sin
-- gastar red). Como ambos usan la misma fórmula y la misma hora, coinciden.
---------------------------------------------------------------------
type ItemCinta = { modelo: Model, inicio: number, alien: Config.Alien, shiny: boolean, precio: number, alto: number, vendido: boolean }
local enCinta: { ItemCinta } = {}
local aleatorio = Random.new()

local function posicionEnCinta(item: ItemCinta, t: number): Vector3
	local progreso = math.clamp((t - item.inicio) / J.SEGUNDOS_EN_CINTA, 0, 1)
	return mapa.cintaInicio:Lerp(mapa.cintaFin, progreso) + Vector3.new(0, item.alto, 0)
end

local function comprarDeCinta(jugador: Player, item: ItemCinta)
	local sesion = sesiones[jugador]
	if not sesion or not sesion.cargado or item.vendido or not permitido(sesion, "comprar", 0.2) then
		return
	end
	local _, _, raiz = personajeVivo(jugador)
	if not raiz or (raiz.Position - posicionEnCinta(item, ahora())).Magnitude > 18 then
		return
	end
	if sesion.datos.dinero < item.precio then
		avisar(jugador, "Not enough cash! You need $" .. abreviar(item.precio), ROJO)
		return
	end
	local indice = slotLibre(sesion)
	if not indice then
		avisar(jugador, "Your base is full! Sell an alien or Rebirth for more space.", ROJO)
		return
	end
	item.vendido = true
	item.modelo:Destroy()
	sumarDinero(jugador, -item.precio)
	colocarAlien(sesion.base, indice, item.alien.id, item.shiny)
	registrarIndice(jugador, sesion, item.alien.id, item.shiny)
	avisar(jugador, "You bought " .. (if item.shiny then "✨ Shiny " else "") .. item.alien.nombre .. "!", VERDE)
	efecto(jugador, "COMPRAR")
	avanzarTutorial(jugador, sesion, 1)
	if item.alien.rareza >= 4 then
		local rareza = Config.RAREZAS[item.alien.rareza]
		avisarATodos(jugador.DisplayName .. " bought a " .. rareza.nombre .. " " .. item.alien.nombre .. "!", Modelos.rgb(rareza.color))
	end
end

local function lanzarAlienEnCinta()
	local suerte = ahora() < (remotos:GetAttribute("SuerteHasta") or 0)
	local id = Probabilidades.elegir(Config.RAREZAS, Config.ALIENS, suerte, E.MULTIPLICADOR_SUERTE, aleatorio:NextNumber())
	local alien = Config.alienPorId(id)
	if not alien then
		return
	end
	local shiny = aleatorio:NextNumber() < Config.SHINY.PROBABILIDAD
	local precio = Config.precioAlien(alien, shiny)
	local modelo = Modelos.crear(alien, shiny, precio)
	local item: ItemCinta = { modelo = modelo, inicio = ahora(), alien = alien, shiny = shiny, precio = precio, alto = alien.tamano * 0.65 + 0.6, vendido = false }
	modelo:PivotTo(CFrame.new(posicionEnCinta(item, item.inicio)) * CFrame.Angles(0, -math.pi / 2, 0))
	modelo:SetAttribute("CintaInicio", item.inicio)
	modelo:SetAttribute("CintaAlto", item.alto)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Comprar"
	prompt.ActionText = "Buy $" .. abreviar(precio)
	prompt.ObjectText = (if shiny then "✨ " else "") .. alien.nombre .. " (" .. Config.RAREZAS[alien.rareza].nombre .. ")"
	prompt.HoldDuration = 0.25
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = modelo.PrimaryPart
	prompt.Triggered:Connect(function(jugador)
		comprarDeCinta(jugador, item)
	end)

	CollectionService:AddTag(modelo, "AlienCinta")
	modelo.Parent = carpetaCinta
	table.insert(enCinta, item)

	if alien.rareza >= 5 or (shiny and alien.rareza >= 3) then
		local rareza = Config.RAREZAS[alien.rareza]
		avisarATodos("✨ A " .. (if shiny then "Shiny " else "") .. rareza.nombre .. " " .. alien.nombre .. " is on the belt!", Modelos.rgb(rareza.color))
	end
end

task.spawn(function()
	while true do
		lanzarAlienEnCinta()
		task.wait(J.SEGUNDOS_ENTRE_ALIENS)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		local t = ahora()
		for i = #enCinta, 1, -1 do
			local item = enCinta[i]
			if item.vendido or t - item.inicio >= J.SEGUNDOS_EN_CINTA then
				if item.modelo.Parent then
					item.modelo:Destroy()
				end
				table.remove(enCinta, i)
			end
		end
	end
end)

---------------------------------------------------------------------
-- EVENTOS: LUCKY BELT Y METEOR SHOWER
---------------------------------------------------------------------
local function activarSuerte(segundos: number, texto: string)
	local desde = math.max(ahora(), remotos:GetAttribute("SuerteHasta") or 0)
	remotos:SetAttribute("SuerteHasta", desde + segundos)
	avisarATodos(texto, Color3.fromRGB(120, 255, 120))
	for jugador in sesiones do
		efecto(jugador, "EVENTO")
	end
end

local function crearCristal(posicion: Vector3)
	local cristal = Instance.new("Part")
	cristal.Name = "CristalEspacial"
	cristal.Size = Vector3.new(1.6, 2.6, 1.6)
	cristal.CFrame = CFrame.new(posicion + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, aleatorio:NextNumber(0, 6), 0.3)
	cristal.Anchored = true
	cristal.CanCollide = false
	cristal.Material = Enum.Material.Neon
	cristal.Color = Color3.fromRGB(90, 230, 255)
	local luz = Instance.new("PointLight")
	luz.Color = cristal.Color
	luz.Range = 10
	luz.Parent = cristal
	local cogido = false
	cristal.Touched:Connect(function(golpe)
		if cogido then
			return
		end
		local jugador = jugadorDesdeToque(golpe)
		local sesion = jugador and sesiones[jugador]
		if not jugador or not sesion or not sesion.cargado then
			return
		end
		cogido = true
		local cantidad = math.floor(math.max(E.METEORITO_MINIMO, ingresoPorSegundo(sesion) * E.METEORITO_SEGUNDOS_INGRESO))
		sumarDinero(jugador, cantidad)
		avisar(jugador, "💎 +$" .. abreviar(cantidad), Color3.fromRGB(120, 230, 255))
		efecto(jugador, "COBRAR")
		onda(cristal.Position, cristal.Color)
		cristal:Destroy()
	end)
	cristal.Parent = workspace
	Debris:AddItem(cristal, 25)
end

local function lanzarMeteorito()
	local zona = mapa.zonaMeteoritos
	local lado = if aleatorio:NextNumber() < 0.5 then -1 else 1
	local destino = Vector3.new(aleatorio:NextNumber(zona.xMin, zona.xMax), 0.5, lado * aleatorio:NextNumber(zona.zMin, zona.zMax))
	local origen = destino + Vector3.new(60, 160, lado * 20)
	local meteoro = Instance.new("Part")
	meteoro.Shape = Enum.PartType.Ball
	meteoro.Size = Vector3.one * 3.5
	meteoro.Material = Enum.Material.Neon
	meteoro.Color = Color3.fromRGB(255, 140, 50)
	meteoro.Anchored = true
	meteoro.CanCollide = false
	meteoro.CanQuery = false
	meteoro.CanTouch = false
	meteoro.Position = origen
	local fuego = Instance.new("Fire")
	fuego.Size = 8
	fuego.Heat = 15
	fuego.Parent = meteoro
	meteoro.Parent = workspace
	local caida = TweenService:Create(meteoro, TweenInfo.new(1.6, Enum.EasingStyle.Linear), { Position = destino })
	caida.Completed:Connect(function()
		meteoro:Destroy()
		onda(destino, Color3.fromRGB(255, 160, 60))
		crearCristal(destino)
	end)
	caida:Play()
end

local function lluviaDeMeteoritos()
	remotos:SetAttribute("MeteoritosHasta", ahora() + E.METEORITOS_DURA)
	avisarATodos("☄️ METEOR SHOWER! Grab the space crystals in the plaza!", Color3.fromRGB(255, 170, 80))
	for jugador in sesiones do
		efecto(jugador, "EVENTO")
	end
	task.spawn(function()
		for _ = 1, E.METEORITOS_CANTIDAD do
			lanzarMeteorito()
			task.wait(E.METEORITOS_DURA / E.METEORITOS_CANTIDAD)
		end
	end)
end

task.spawn(function()
	while true do
		remotos:SetAttribute("ProximaSuerte", ahora() + E.SUERTE_CADA)
		task.wait(E.SUERTE_CADA)
		activarSuerte(E.SUERTE_DURA, "🍀 LUCKY BELT! Rare aliens x" .. E.MULTIPLICADOR_SUERTE .. " for " .. E.SUERTE_DURA .. "s!")
	end
end)

task.spawn(function()
	remotos:SetAttribute("ProximosMeteoritos", ahora() + E.METEORITOS_PRIMERO)
	task.wait(E.METEORITOS_PRIMERO)
	while true do
		lluviaDeMeteoritos()
		remotos:SetAttribute("ProximosMeteoritos", ahora() + E.METEORITOS_CADA)
		task.wait(E.METEORITOS_CADA)
	end
end)

---------------------------------------------------------------------
-- PUESTOS: VELOCIDAD Y REBIRTH
---------------------------------------------------------------------
local function promptPuesto(puesto: BasePart, accion: string, objeto: string, mantener: number, alPulsar: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = accion
	prompt.ObjectText = objeto
	prompt.HoldDuration = mantener
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = puesto
	prompt.Triggered:Connect(alPulsar)
end

promptPuesto(mapa.puestoVelocidad, "Upgrade", "Speed", 0.3, function(jugador)
	local sesion = sesiones[jugador]
	if not sesion or not sesion.cargado or not permitido(sesion, "velocidad", 0.3) then
		return
	end
	local nivel = sesion.datos.velocidad
	if nivel >= J.NIVEL_VELOCIDAD_MAX then
		avisar(jugador, "⚡ Max speed reached!")
		return
	end
	local coste = Config.costeVelocidad(nivel)
	if sesion.datos.dinero < coste then
		avisar(jugador, "⚡ Speed " .. (nivel + 1) .. " costs $" .. abreviar(coste), ROJO)
		return
	end
	sesion.datos.velocidad = nivel + 1
	sumarDinero(jugador, -coste)
	actualizarVelocidad(jugador)
	avisar(jugador, "⚡ Speed level " .. sesion.datos.velocidad .. "!", Color3.fromRGB(120, 200, 255))
	efecto(jugador, "COMPRAR")
end)

promptPuesto(mapa.puestoRebirth, "Rebirth (hold)", "Rebirth", 2, function(jugador)
	local sesion = sesiones[jugador]
	if not sesion or not sesion.cargado or sesion.llevando or not permitido(sesion, "rebirth", 2) then
		return
	end
	local coste = Config.costeRebirth(sesion.datos.rebirths)
	if sesion.datos.dinero < coste then
		avisar(jugador, "🌌 Rebirth needs $" .. abreviar(coste) .. ". Resets cash & aliens, gives +50% income and +1 pedestal forever.", Color3.fromRGB(255, 150, 220))
		return
	end
	for i in sesion.base.slots do
		quitarAlien(sesion.base, i)
	end
	sesion.datos.rebirths += 1
	sesion.datos.dinero = J.DINERO_INICIAL
	sesion.datos.pendiente = 0
	pintarPedestales(sesion.base, Config.slotsDesbloqueados(sesion.datos.rebirths))
	actualizarStats(jugador)
	task.spawn(guardar, jugador, false)
	avisarATodos("🌌 " .. jugador.DisplayName .. " reached Rebirth " .. sesion.datos.rebirths .. "!", Color3.fromRGB(255, 150, 220))
	efecto(jugador, "EVENTO")
end)

---------------------------------------------------------------------
-- MONETIZACIÓN
---------------------------------------------------------------------
local function idDe(clave: string): number
	local articulo = Config.articuloPorClave(clave)
	return if articulo then articulo.id else 0
end

local function poseePase(jugador: Player, id: number): boolean
	if id == 0 then
		return false
	end
	local ok, resultado = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(jugador.UserId, id)
	end)
	return ok and resultado == true
end

local function comprobarPases(jugador: Player, sesion: Sesion)
	sesion.pases.doble = poseePase(jugador, idDe("PASE_DOBLE_DINERO"))
	sesion.pases.vip = poseePase(jugador, idDe("PASE_VIP"))
	sesion.pases.candadoPlus = poseePase(jugador, idDe("PASE_CANDADO_PLUS"))
	jugador:SetAttribute("VIP", sesion.pases.vip)
	jugador:SetAttribute("PaseDoble", sesion.pases.doble)
	jugador:SetAttribute("PaseCandado", sesion.pases.candadoPlus)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(jugador, idPase, comprado)
	local sesion = sesiones[jugador]
	if not comprado or not sesion or idPase == 0 then
		return
	end
	if idPase == idDe("PASE_DOBLE_DINERO") then
		sesion.pases.doble = true
		jugador:SetAttribute("PaseDoble", true)
	elseif idPase == idDe("PASE_VIP") then
		sesion.pases.vip = true
		jugador:SetAttribute("VIP", true)
	elseif idPase == idDe("PASE_CANDADO_PLUS") then
		sesion.pases.candadoPlus = true
		jugador:SetAttribute("PaseCandado", true)
	end
	actualizarStats(jugador)
	actualizarVelocidad(jugador)
	avisar(jugador, "💜 Thank you for your support!", Color3.fromRGB(210, 160, 255))
	efecto(jugador, "EVENTO")
end)

-- Las compras se piden al servidor para poder aplicar las normas de cada país.
ePedirCompra.OnServerEvent:Connect(function(jugador, clave)
	local sesion = sesiones[jugador]
	if type(clave) ~= "string" or not sesion or not permitido(sesion, "pedirCompra", 1) then
		return
	end
	local articulo = Config.articuloPorClave(clave)
	if not articulo or articulo.id == 0 then
		return
	end
	if clave == "PRODUCTO_SUERTE_SERVIDOR" and sesion.suerteRestringida then
		avisar(jugador, "Sorry, this item is unavailable in your region.", ROJO)
		return
	end
	if articulo.tipo == "pase" then
		if poseePase(jugador, articulo.id) then
			avisar(jugador, "You already own this pass!")
			return
		end
		MarketplaceService:PromptGamePassPurchase(jugador, articulo.id)
	else
		MarketplaceService:PromptProductPurchase(jugador, articulo.id)
	end
end)

local function activarBoost(jugador: Player, sesion: Sesion, minutos: number)
	local desde = math.max(os.time(), sesion.datos.boostHasta)
	sesion.datos.boostHasta = desde + minutos * 60
	sesion.boostAvisado = false
	actualizarStats(jugador)
	avisar(jugador, "⚡ 2x income for " .. minutos .. " minutes!", AMARILLO)
end

local function paqueteDinero(jugador: Player, sesion: Sesion, segundos: number, minimo: number)
	local cantidad = math.floor(math.max(minimo, ingresoPorSegundo(sesion) * segundos))
	sumarDinero(jugador, cantidad)
	avisar(jugador, "💵 +$" .. abreviar(cantidad) .. "! Thank you!", VERDE)
end

local ENTREGAS: { [string]: (Player, Sesion) -> () } = {
	PRODUCTO_BOOST_X2 = function(jugador, sesion)
		activarBoost(jugador, sesion, J.BOOST_X2_MINUTOS)
	end,
	PRODUCTO_SUERTE_SERVIDOR = function(jugador)
		activarSuerte(E.SUERTE_PAGADA_DURA, "🍀 " .. jugador.DisplayName .. " activated LUCKY BELT for everyone! (" .. E.SUERTE_PAGADA_DURA .. "s)")
	end,
	PRODUCTO_DINERO_PEQUENO = function(jugador, sesion)
		paqueteDinero(jugador, sesion, 600, 2500)
	end,
	PRODUCTO_DINERO_GRANDE = function(jugador, sesion)
		paqueteDinero(jugador, sesion, 3600, 25000)
	end,
	ANUNCIO = function(jugador, sesion)
		activarBoost(jugador, sesion, 10)
	end,
}

local clavePorProducto: { [number]: string } = {}
for _, articulo in Config.TIENDA do
	if articulo.tipo == "producto" and articulo.id ~= 0 then
		clavePorProducto[articulo.id] = articulo.clave
	end
end
if Config.ANUNCIO_RECOMPENSA_PRODUCTO ~= 0 and not clavePorProducto[Config.ANUNCIO_RECOMPENSA_PRODUCTO] then
	clavePorProducto[Config.ANUNCIO_RECOMPENSA_PRODUCTO] = "ANUNCIO"
end

-- Roblox llama aquí con cada compra de Developer Product (y recompensa de anuncio).
-- Se guarda el PurchaseId para no entregar nunca una compra dos veces.
MarketplaceService.ProcessReceipt = function(recibo)
	local jugador = Players:GetPlayerByUserId(recibo.PlayerId)
	local sesion = jugador and sesiones[jugador]
	local clave = clavePorProducto[recibo.ProductId]
	local entregar = clave and ENTREGAS[clave]
	if not jugador or not sesion or not sesion.cargado or not entregar then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Perfil.yaComprado(sesion.datos, recibo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, err = pcall(entregar, jugador, sesion)
	if not ok then
		warn("[Compras] Error entregando", clave, err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Perfil.registrarCompra(sesion.datos, recibo.PurchaseId)
	if not sesion.sinGuardado and not guardar(jugador, false) then
		-- Ya está entregado y apuntado: si Roblox reintenta, contestaremos "Granted" sin repetir.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Anuncios de vídeo con recompensa (opcional, requiere activarlos en el Creator Hub).
eAnuncio.OnServerEvent:Connect(function(jugador)
	local sesion = sesiones[jugador]
	if Config.ANUNCIO_RECOMPENSA_PRODUCTO == 0 or not sesion or not permitido(sesion, "anuncio", 5) then
		return
	end
	local ok, resultado = pcall(function()
		local recompensa = AdService:CreateAdRewardFromDevProductId(Config.ANUNCIO_RECOMPENSA_PRODUCTO)
		return AdService:ShowRewardedVideoAdAsync(jugador, recompensa)
	end)
	eAnuncio:FireClient(jugador, ok, if ok then tostring(resultado) else nil)
end)

---------------------------------------------------------------------
-- CÓDIGOS PROMOCIONALES
---------------------------------------------------------------------
fCodigo.OnServerInvoke = function(jugador, texto)
	local sesion = sesiones[jugador]
	if not sesion or not sesion.cargado or type(texto) ~= "string" or #texto > 40 then
		return false, "Invalid code"
	end
	if not permitido(sesion, "codigo", 2) then
		return false, "Wait a moment..."
	end
	local codigo = string.upper((string.gsub(texto, "%s", "")))
	local premio = Codigos[codigo]
	if not premio then
		return false, "Invalid code"
	end
	if premio.caduca and os.time() > premio.caduca then
		return false, "This code has expired"
	end
	if sesion.datos.codigos[codigo] then
		return false, "Already redeemed"
	end
	sesion.datos.codigos[codigo] = true
	local partes = {}
	local dinero = (premio.dinero or 0) + ingresoPorSegundo(sesion) * (premio.segundos or 0)
	if dinero > 0 then
		sumarDinero(jugador, math.floor(dinero))
		table.insert(partes, "+$" .. abreviar(dinero))
	end
	if premio.boostMinutos then
		activarBoost(jugador, sesion, premio.boostMinutos)
		table.insert(partes, premio.boostMinutos .. " min 2x boost")
	end
	efecto(jugador, "EVENTO")
	return true, "Redeemed! " .. table.concat(partes, " + ")
end

---------------------------------------------------------------------
-- AMIGOS Y GRUPO (bonos sociales: Roblox premia que se juegue con amigos)
---------------------------------------------------------------------
local amistades: { [number]: { [number]: boolean } } = {}

local function recalcularAmigos()
	for jugador, sesion in sesiones do
		local cuenta = 0
		local suyas = amistades[jugador.UserId]
		if suyas then
			for otro in sesiones do
				if otro ~= jugador and suyas[otro.UserId] then
					cuenta += 1
				end
			end
		end
		if sesion.amigos ~= cuenta then
			if cuenta > sesion.amigos and sesion.cargado then
				avisar(jugador, "👥 Friend bonus: +" .. math.floor(math.min(cuenta * J.BONUS_POR_AMIGO, J.BONUS_AMIGOS_MAX) * 100) .. "% income!", Color3.fromRGB(150, 220, 255))
			end
			sesion.amigos = cuenta
			actualizarStats(jugador)
		end
	end
end

local function comprobarAmistades(jugador: Player)
	amistades[jugador.UserId] = amistades[jugador.UserId] or {}
	for _, otro in Players:GetPlayers() do
		if otro ~= jugador then
			local ok, sonAmigos = pcall(function()
				return jugador:IsFriendsWithAsync(otro.UserId)
			end)
			if ok and sonAmigos then
				amistades[jugador.UserId][otro.UserId] = true
				amistades[otro.UserId] = amistades[otro.UserId] or {}
				amistades[otro.UserId][jugador.UserId] = true
			end
		end
	end
	recalcularAmigos()
end

---------------------------------------------------------------------
-- RANKINGS GLOBALES
---------------------------------------------------------------------
local nombresCache: { [number]: string } = {}

local function nombreDe(userId: number): string
	if nombresCache[userId] then
		return nombresCache[userId]
	end
	local ok, nombre = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resultado = if ok and nombre then nombre else "???"
	nombresCache[userId] = resultado
	return resultado
end

local function actualizarRanking(nombre: string, obtenerValor: (Sesion) -> number)
	local almacen = Datos.ranking(nombre)
	local tablero = mapa.rankings[if nombre == "Rebirths" then "rebirths" else "robos"]
	if not almacen or not tablero then
		return
	end
	for jugador, sesion in sesiones do
		if sesion.cargado and not sesion.sinGuardado then
			local valor = obtenerValor(sesion)
			if valor > 0 then
				pcall(function()
					almacen:SetAsync(tostring(jugador.UserId), valor)
				end)
			end
		end
	end
	local ok, paginas = pcall(function()
		return almacen:GetSortedAsync(false, 10)
	end)
	if not ok or not paginas then
		return
	end
	local entradas = paginas:GetCurrentPage()
	for i, fila in tablero.filas do
		local entrada = entradas[i]
		if entrada then
			fila.Text = string.format("%d. %s — %s", i, nombreDe(tonumber(entrada.key) or 0), abreviar(entrada.value))
		else
			fila.Text = i .. ". ..."
		end
	end
end

task.spawn(function()
	task.wait(15)
	while true do
		if Datos.disponible() then
			actualizarRanking("Rebirths", function(sesion)
				return sesion.datos.rebirths
			end)
			actualizarRanking("Robos", function(sesion)
				return sesion.datos.stats.robos
			end)
		end
		task.wait(180)
	end
end)

---------------------------------------------------------------------
-- ENTRADA Y SALIDA DE JUGADORES
---------------------------------------------------------------------
local function asignarBase(jugador: Player): any
	for _, base in mapa.bases do
		if not base.dueno then
			base.dueno = jugador
			return base
		end
	end
	return nil
end

local function liberarBase(base: any)
	for i in base.slots do
		quitarAlien(base, i)
	end
	base.dueno = nil
	base.bloqueadaHasta = 0
	base.barrera.Transparency = 1
	base.barrera.CanTouch = false
	base.cartel.Text = "Empty base"
	base.textoCobro.Text = "$0"
	base.textoCandado.Text = "🔒 LOCK"
	pintarPedestales(base, J.SLOTS_MAXIMOS)
end

local function colocarEnBase(jugador: Player, personaje: Model, base: any)
	personaje:WaitForChild("HumanoidRootPart", 10)
	task.wait()
	if personaje.Parent then
		local mirarA = Vector3.new(base.x, base.centro.Y + 4, 0)
		personaje:PivotTo(CFrame.lookAt(base.centro + Vector3.new(0, 4, 0), mirarA))
	end
	darSlap(jugador)
	actualizarVelocidad(jugador)
end

local function crearLeaderstats(jugador: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, nombre in { "Cash", "Rebirths", "Steals" } do
		local valor = Instance.new("NumberValue")
		valor.Name = nombre
		valor.Parent = stats
	end
	stats.Parent = jugador
end

local function alEntrar(jugador: Player)
	local base = asignarBase(jugador)
	if not base then
		jugador:Kick("This server is full. Please join another server!")
		return
	end
	crearLeaderstats(jugador)
	local sesion: Sesion = {
		datos = Perfil.nuevo(J.DINERO_INICIAL),
		base = base,
		llevando = nil,
		pases = { doble = false, vip = false, candadoPlus = false },
		amigos = 0,
		grupo = false,
		cargado = false,
		sinGuardado = false,
		suerteRestringida = true, -- hasta confirmar la política del país
		ultimaAccion = {},
		ultimaPos = nil,
		ultimaPosT = 0,
		tutorial = 0,
		boostAvisado = false,
	}
	sesiones[jugador] = sesion
	base.cartel.Text = string.format('<font color="#%s">%s</font>\'s base', base.color:ToHex(), jugador.DisplayName)
	jugador:SetAttribute("BaseIndice", base.indice)

	jugador.CharacterAdded:Connect(function(personaje)
		colocarEnBase(jugador, personaje, base)
	end)
	if jugador.Character then
		task.spawn(colocarEnBase, jugador, jugador.Character, base)
	end

	-- Cargar datos
	local resultado = Datos.cargar(jugador.UserId)
	if sesiones[jugador] ~= sesion then
		-- Se fue mientras cargábamos: soltamos el bloqueo sin tocar sus datos.
		if resultado.ok and not resultado.sinGuardado then
			Datos.liberar(jugador.UserId)
		end
		return
	end
	if not resultado.ok then
		jugador:Kick("We couldn't load your data (Roblox servers may be busy). Please rejoin in a minute!")
		return
	end
	sesion.sinGuardado = resultado.sinGuardado
	sesion.datos = Perfil.reconciliar(resultado.guardado, J.DINERO_INICIAL, J.SLOTS_MAXIMOS, function(id)
		return Config.alienPorId(id) ~= nil
	end)
	local datos = sesion.datos

	pintarPedestales(base, Config.slotsDesbloqueados(datos.rebirths))
	for _, guardado in datos.aliens do
		colocarAlien(base, guardado.s, guardado.id, guardado.sh == true)
	end

	-- Comprobaciones externas (pueden tardar un poco)
	comprobarPases(jugador, sesion)
	local okPolitica, politica = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(jugador)
	end)
	sesion.suerteRestringida = not okPolitica or politica == nil or politica.ArePaidRandomItemsRestricted == true
	jugador:SetAttribute("SuerteRestringida", sesion.suerteRestringida)
	if Config.GRUPO_ID ~= 0 then
		local okGrupo, enGrupo = pcall(function()
			return jugador:IsInGroupAsync(Config.GRUPO_ID)
		end)
		sesion.grupo = okGrupo and enGrupo == true
	end
	if not jugador.Parent then
		return
	end
	sesion.cargado = true
	task.spawn(comprobarAmistades, jugador)

	-- Ganancias mientras no jugaba
	if datos.ultimaConexion > 0 then
		local offline = Config.gananciaOffline(os.time() - datos.ultimaConexion, ingresoPorSegundo(sesion))
		if offline >= 1 then
			datos.pendiente += offline
			task.delay(4, function()
				if jugador.Parent then
					avisar(jugador, "🌙 Your aliens made $" .. abreviar(offline) .. " while you were away! Collect it at your base.", Color3.fromRGB(180, 200, 255))
				end
			end)
		end
	end

	-- Recompensa diaria
	local hoy = os.time() // 86400
	local racha = Perfil.siguienteRacha(datos.diario, hoy)
	if racha then
		local premio = Config.recompensaDiaria(racha, ingresoPorSegundo(sesion))
		datos.diario = { dia = hoy, racha = racha }
		datos.dinero += premio
		task.delay(2, function()
			if jugador.Parent then
				eDiario:FireClient(jugador, racha, premio)
			end
		end)
	end

	actualizarIndiceAtributo(jugador, sesion)
	actualizarStats(jugador)
	actualizarVelocidad(jugador)

	if not datos.tutorialHecho then
		ponerPasoTutorial(jugador, sesion, 1)
		avisar(jugador, "👽 Welcome! Buy your first alien on the belt!", Color3.fromRGB(0, 255, 200))
	else
		avisar(jugador, "👽 Welcome back, " .. jugador.DisplayName .. "!", Color3.fromRGB(0, 255, 200))
	end
	if sesion.sinGuardado then
		avisar(jugador, "[Studio] Data saving is OFF (enable API Services to test saving).", AMARILLO)
	end
end

local function alSalir(jugador: Player)
	local sesion = sesiones[jugador]
	if not sesion then
		return
	end
	devolverCarga(jugador, nil)
	if sesion.cargado and not sesion.sinGuardado then
		serializar(sesion)
	end
	local base = sesion.base
	-- Guardamos antes de liberar la base (guardar usa los pedestales).
	guardar(jugador, true)
	sesiones[jugador] = nil
	liberarBase(base)
	amistades[jugador.UserId] = nil
	recalcularAmigos()
end

Players.PlayerAdded:Connect(alEntrar)
Players.PlayerRemoving:Connect(alSalir)
for _, jugador in Players:GetPlayers() do
	task.spawn(alEntrar, jugador)
end

-- Autoguardado
task.spawn(function()
	while true do
		task.wait(90)
		for jugador in sesiones do
			task.spawn(guardar, jugador, false)
			task.wait(0.5)
		end
	end
end)

game:BindToClose(function()
	local pendientes = 0
	for jugador in sesiones do
		pendientes += 1
		task.spawn(function()
			guardar(jugador, true)
			pendientes -= 1
		end)
	end
	local limite = os.clock() + 25
	while pendientes > 0 and os.clock() < limite do
		task.wait(0.2)
	end
end)

---------------------------------------------------------------------
-- COMANDOS DE PRUEBA (solo funcionan en Roblox Studio)
-- /cash 1000000   /luck   /meteors   /rebirths 3
---------------------------------------------------------------------
if RunService:IsStudio() then
	local function comando(alias: string, accion: (Player, string) -> ())
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = "Prueba_" .. alias
		cmd.PrimaryAlias = "/" .. alias
		cmd.Triggered:Connect(function(origen, texto)
			local jugador = Players:GetPlayerByUserId(origen.UserId)
			if jugador and sesiones[jugador] then
				accion(jugador, texto)
			end
		end)
		cmd.Parent = TextChatService
	end
	comando("cash", function(jugador, texto)
		local cantidad = tonumber(string.match(texto, "%d+")) or 1000000
		sumarDinero(jugador, cantidad)
	end)
	comando("luck", function()
		activarSuerte(60, "🍀 [Studio] Lucky Belt test")
	end)
	comando("meteors", function()
		lluviaDeMeteoritos()
	end)
	comando("rebirths", function(jugador, texto)
		local sesion = sesiones[jugador]
		sesion.datos.rebirths = tonumber(string.match(texto, "%d+")) or 1
		pintarPedestales(sesion.base, Config.slotsDesbloqueados(sesion.datos.rebirths))
		actualizarStats(jugador)
	end)
end

print("[Steal an Alien] Server ready, version " .. Config.VERSION)
