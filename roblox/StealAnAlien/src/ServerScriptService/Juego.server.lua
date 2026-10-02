--[[
	STEAL AN ALIEN — servidor
	-------------------------
	Bucle principal:
	  1. Por la cinta central pasan aliens. Compra los que puedas pagar.
	  2. Los aliens de tu base generan dinero cada segundo. Pisa la placa verde para cobrarlo.
	  3. Entra en las bases de otros jugadores y róbales aliens: llévalos a tu base sin que el dueño te toque.
	  4. Cierra tu base (placa roja) para protegerte un rato.
	  5. Mejora tu velocidad y haz "Rebirth" para multiplicar tus ganancias.

	Este Script va en ServerScriptService. Construye el mapa al arrancar.
	La interfaz está en StarterPlayerScripts/Interfaz.client.lua.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------------------------------------------------------------
-- CONFIGURACIÓN
---------------------------------------------------------------------
local CONFIG = {
	DINERO_INICIAL = 100,
	SEGUNDOS_ENTRE_ALIENS = 2.2, -- frecuencia de aparición en la cinta
	SEGUNDOS_EN_CINTA = 28, -- lo que tarda un alien en recorrer la cinta
	SEGUNDOS_CANDADO = 60,
	SEGUNDOS_CANDADO_VIP = 120,
	VELOCIDAD_BASE = 16,
	VELOCIDAD_POR_NIVEL = 2,
	NIVEL_VELOCIDAD_MAX = 8,
	FACTOR_VELOCIDAD_CARGANDO = 0.7, -- llevar un alien robado te frena
	DISTANCIA_ATRAPAR = 6, -- si el dueño se acerca tanto al ladrón, recupera su alien
	BONUS_POR_REBIRTH = 0.5, -- +50 % de ingresos por cada rebirth
	SUERTE_GRATIS_CADA = 600, -- evento gratuito de suerte cada 10 min...
	SUERTE_GRATIS_DURA = 60, -- ...que dura 60 s
	SUERTE_PAGADA_DURA = 180,
	MULTIPLICADOR_SUERTE = 4, -- los aliens raros salen x4 más durante la suerte
	CLAVE_DATASTORE = "StealAnAlien_v1",
}

-- IDs de monetización. Déjalos en 0 hasta crearlos en el Creator Hub
-- (ver README). Con 0, el botón aparece como "Coming soon".
local MONETIZACION = {
	PASE_DOBLE_DINERO = 0, -- Game Pass: x2 ingresos para siempre
	PASE_VIP = 0, -- Game Pass: +4 velocidad, candado de 120 s, etiqueta VIP
	PRODUCTO_DINERO_PEQUENO = 0, -- Developer Product: 10 min de ingresos
	PRODUCTO_DINERO_GRANDE = 0, -- Developer Product: 1 h de ingresos
	PRODUCTO_SUERTE_SERVIDOR = 0, -- Developer Product: suerte x4 para todo el servidor 3 min
}

-- Rarezas: peso = probabilidad relativa de salir en la cinta.
local RAREZAS = {
	{ nombre = "Common", color = Color3.fromRGB(200, 200, 200), peso = 60, rara = false },
	{ nombre = "Rare", color = Color3.fromRGB(70, 160, 255), peso = 25, rara = false },
	{ nombre = "Epic", color = Color3.fromRGB(180, 80, 255), peso = 10, rara = true },
	{ nombre = "Legendary", color = Color3.fromRGB(255, 190, 30), peso = 4, rara = true },
	{ nombre = "Mythic", color = Color3.fromRGB(255, 60, 90), peso = 0.9, rara = true },
	{ nombre = "Secret", color = Color3.fromRGB(20, 20, 20), peso = 0.1, rara = true },
}

-- Catálogo de aliens. rareza = índice en RAREZAS.
local ALIENS = {
	{ id = "blorp", nombre = "Blorp", rareza = 1, precio = 25, ingreso = 1, color = Color3.fromRGB(120, 230, 120), tamano = 2.5 },
	{ id = "zib", nombre = "Zib Zib", rareza = 1, precio = 90, ingreso = 3, color = Color3.fromRGB(120, 220, 255), tamano = 2.6 },
	{ id = "moonmoo", nombre = "Moonmoo", rareza = 2, precio = 450, ingreso = 10, color = Color3.fromRGB(240, 240, 200), tamano = 3 },
	{ id = "glarbo", nombre = "Glarbo", rareza = 2, precio = 1800, ingreso = 32, color = Color3.fromRGB(255, 150, 60), tamano = 3.2 },
	{ id = "nebulacat", nombre = "Nebula Cat", rareza = 3, precio = 8000, ingreso = 110, color = Color3.fromRGB(170, 100, 255), tamano = 3.5 },
	{ id = "tentacle", nombre = "Sir Tentacle", rareza = 3, precio = 30000, ingreso = 340, color = Color3.fromRGB(255, 100, 180), tamano = 3.8 },
	{ id = "cosmowhale", nombre = "Cosmo Whale", rareza = 4, precio = 150000, ingreso = 1300, color = Color3.fromRGB(60, 120, 255), tamano = 4.5 },
	{ id = "ufoking", nombre = "UFO Overlord", rareza = 4, precio = 500000, ingreso = 3800, color = Color3.fromRGB(180, 255, 80), tamano = 4.6 },
	{ id = "galaxydragon", nombre = "Galaxy Dragon", rareza = 5, precio = 2500000, ingreso = 16000, color = Color3.fromRGB(255, 50, 80), tamano = 5.2 },
	{ id = "voidking", nombre = "Void King", rareza = 6, precio = 20000000, ingreso = 110000, color = Color3.fromRGB(30, 0, 50), tamano = 6 },
}

local ALIEN_POR_ID = {}
for _, def in ipairs(ALIENS) do
	ALIEN_POR_ID[def.id] = def
end

---------------------------------------------------------------------
-- UTILIDADES
---------------------------------------------------------------------
local function abreviar(n)
	local sufijos = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	while n >= 1000 and i < #sufijos do
		n = n / 1000
		i = i + 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f%s", n, sufijos[i])
end

local function ahora()
	return workspace:GetServerTimeNow()
end

local function crearParte(propiedades, padre)
	local parte = Instance.new("Part")
	parte.Anchored = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Material = Enum.Material.SmoothPlastic
	for propiedad, valor in pairs(propiedades) do
		parte[propiedad] = valor
	end
	parte.Parent = padre
	return parte
end

local function crearCartel(adornee, texto, color, alto, offsetY)
	local cartel = Instance.new("BillboardGui")
	cartel.Size = UDim2.fromOffset(220, alto or 50)
	cartel.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	cartel.MaxDistance = 120
	cartel.Parent = adornee

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = "Texto"
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.Text = texto
	etiqueta.TextColor3 = color or Color3.new(1, 1, 1)
	etiqueta.TextStrokeTransparency = 0
	etiqueta.TextScaled = true
	etiqueta.Font = Enum.Font.FredokaOne
	etiqueta.Parent = cartel
	return etiqueta
end

local function personajeVivo(jugador)
	local personaje = jugador and jugador.Character
	local humanoid = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if humanoid and raiz and humanoid.Health > 0 then
		return personaje, humanoid, raiz
	end
	return nil
end

local function jugadorDesdeToque(golpe)
	local modelo = golpe:FindFirstAncestorOfClass("Model")
	return modelo and Players:GetPlayerFromCharacter(modelo)
end

---------------------------------------------------------------------
-- COMUNICACIÓN CON LA INTERFAZ
---------------------------------------------------------------------
local compartido = Instance.new("Folder")
compartido.Name = "StealAnAlien"
for clave, id in pairs(MONETIZACION) do
	compartido:SetAttribute(clave, id) -- el cliente lee aquí los IDs de la tienda
end
compartido:SetAttribute("SuerteHasta", 0)

local eventoAviso = Instance.new("RemoteEvent")
eventoAviso.Name = "Aviso"
eventoAviso.Parent = compartido
compartido.Parent = ReplicatedStorage

local function avisar(jugador, texto, color)
	eventoAviso:FireClient(jugador, texto, color)
end

local function avisarATodos(texto, color)
	eventoAviso:FireAllClients(texto, color)
end

---------------------------------------------------------------------
-- MODELOS DE ALIENS (hechos con piezas, sin necesidad de importar nada)
---------------------------------------------------------------------
local function crearModeloAlien(def)
	local rareza = RAREZAS[def.rareza]
	local s = def.tamano
	local modelo = Instance.new("Model")
	modelo.Name = def.nombre

	local cuerpo = Instance.new("Part")
	cuerpo.Name = "Cuerpo"
	cuerpo.Shape = Enum.PartType.Ball
	cuerpo.Size = Vector3.new(s, s, s)
	cuerpo.Color = def.color
	cuerpo.Material = def.rareza >= 4 and Enum.Material.Neon or Enum.Material.SmoothPlastic
	cuerpo.Anchored = true
	cuerpo.CanCollide = false
	cuerpo.Parent = modelo
	modelo.PrimaryPart = cuerpo

	local function pieza(nombre, tamano, offset, color, forma)
		local p = Instance.new("Part")
		p.Name = nombre
		p.Shape = forma or Enum.PartType.Ball
		p.Size = tamano
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = cuerpo.CFrame * CFrame.new(offset)
		p.Parent = modelo
	end

	-- Ojos (los aliens raros tienen tres)
	local numOjos = def.rareza >= 3 and 3 or 2
	for i = 1, numOjos do
		local x = (i - (numOjos + 1) / 2) * s * 0.28
		pieza("Ojo", Vector3.new(s * 0.3, s * 0.3, s * 0.3), Vector3.new(x, s * 0.15, -s * 0.38), Color3.new(1, 1, 1))
		pieza("Pupila", Vector3.new(s * 0.14, s * 0.14, s * 0.14), Vector3.new(x, s * 0.15, -s * 0.52), Color3.new(0, 0, 0))
	end
	-- Antenas
	for _, lado in ipairs({ -1, 1 }) do
		pieza("Antena", Vector3.new(s * 0.08, s * 0.5, s * 0.08), Vector3.new(lado * s * 0.2, s * 0.6, 0), def.color, Enum.PartType.Block)
		pieza("Bolita", Vector3.new(s * 0.2, s * 0.2, s * 0.2), Vector3.new(lado * s * 0.2, s * 0.9, 0), rareza.color)
	end

	if def.rareza >= 4 then
		local brillo = Instance.new("PointLight")
		brillo.Color = rareza.color
		brillo.Range = 12
		brillo.Brightness = 2
		brillo.Parent = cuerpo
	end

	local etiqueta = crearCartel(cuerpo, def.nombre, rareza.color, 70, s * 0.5 + 2.5)
	etiqueta.Text = string.format("%s\n%s · $%s/s", def.nombre, rareza.nombre, abreviar(def.ingreso))
	return modelo
end

-- Ancla o suelta todas las piezas de un modelo y las suelda al cuerpo.
local function prepararParaLlevar(modelo)
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			if p ~= modelo.PrimaryPart then
				local soldadura = Instance.new("WeldConstraint")
				soldadura.Part0 = modelo.PrimaryPart
				soldadura.Part1 = p
				soldadura.Parent = p
			end
		end
	end
end

---------------------------------------------------------------------
-- MAPA
---------------------------------------------------------------------
for _, nombre in ipairs({ "Baseplate", "SpawnLocation" }) do
	local viejo = workspace:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
end

local mapa = Instance.new("Folder")
mapa.Name = "Mapa"
mapa.Parent = workspace

game:GetService("Lighting").ClockTime = 20 -- ambiente nocturno espacial

crearParte({
	Name = "Suelo",
	Size = Vector3.new(300, 1, 200),
	Position = Vector3.new(0, 0, 0),
	Color = Color3.fromRGB(45, 40, 70),
	Material = Enum.Material.Slate,
}, mapa)

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(-120, 0.6, 0)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = mapa

-- Cinta transportadora
local CINTA_INICIO = Vector3.new(-90, 2.5, 0)
local CINTA_FIN = Vector3.new(90, 2.5, 0)
crearParte({
	Name = "Cinta",
	Size = Vector3.new(190, 1, 10),
	Position = Vector3.new(0, 0.9, 0),
	Color = Color3.fromRGB(25, 25, 35),
	Material = Enum.Material.DiamondPlate,
}, mapa)
for _, z in ipairs({ -5.5, 5.5 }) do
	crearParte({
		Name = "BordeCinta",
		Size = Vector3.new(190, 0.6, 1),
		Position = Vector3.new(0, 1.3, z),
		Color = Color3.fromRGB(0, 255, 200),
		Material = Enum.Material.Neon,
	}, mapa)
end

-- Bases: 4 a cada lado de la cinta (8 jugadores por servidor).
local bases = {}
local ANCHO_BASE, FONDO_BASE = 44, 40
local NUM_SLOTS = 10

local function crearBase(indice, x, lado)
	local frenteZ = lado * 30
	local centroZ = lado * (30 + FONDO_BASE / 2)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Base" .. indice
	carpeta.Parent = mapa

	local base = {
		indice = indice,
		lado = lado,
		centro = Vector3.new(x, 1.5, centroZ),
		dueno = nil,
		bloqueadaHasta = 0,
		slots = {},
	}

	base.piso = crearParte({
		Name = "Piso",
		Size = Vector3.new(ANCHO_BASE, 1, FONDO_BASE),
		Position = Vector3.new(x, 1, centroZ),
		Color = Color3.fromRGB(70, 65, 100),
	}, carpeta)

	-- Paredes laterales y trasera
	local colorPared = Color3.fromRGB(90, 80, 140)
	crearParte({ Size = Vector3.new(ANCHO_BASE, 10, 1), Position = Vector3.new(x, 6, lado * (30 + FONDO_BASE)), Color = colorPared }, carpeta)
	for _, dx in ipairs({ -ANCHO_BASE / 2, ANCHO_BASE / 2 }) do
		crearParte({ Size = Vector3.new(1, 10, FONDO_BASE), Position = Vector3.new(x + dx, 6, centroZ), Color = colorPared }, carpeta)
	end

	-- Barrera láser (solo activa con el candado)
	base.barrera = crearParte({
		Name = "Barrera",
		Size = Vector3.new(ANCHO_BASE, 10, 1),
		Position = Vector3.new(x, 6, frenteZ),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
	}, carpeta)
	base.barrera.Touched:Connect(function(golpe)
		local jugador = jugadorDesdeToque(golpe)
		if jugador and jugador ~= base.dueno then
			local personaje, _, raiz = personajeVivo(jugador)
			if personaje then
				personaje:PivotTo(CFrame.new(raiz.Position.X, 4, frenteZ - lado * 6))
			end
		end
	end)

	-- Cartel con el nombre del dueño
	local poste = crearParte({
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(x, 14, lado * (30 + FONDO_BASE)),
		Transparency = 1,
		CanCollide = false,
	}, carpeta)
	base.cartel = crearCartel(poste, "Empty base", Color3.new(1, 1, 1), 60, 0)

	-- Pedestales
	for fila = 0, 1 do
		for col = 0, 4 do
			local pedestal = crearParte({
				Name = "Pedestal",
				Size = Vector3.new(5, 1, 5),
				Position = Vector3.new(x - 16 + col * 8, 2, lado * (44 + fila * 14)),
				Color = Color3.fromRGB(120, 110, 170),
			}, carpeta)
			table.insert(base.slots, { pedestal = pedestal, id = nil, modelo = nil })
		end
	end

	-- Placa de cobro (verde) y placa de candado (roja)
	base.placaCobro = crearParte({
		Name = "Cobrar",
		Size = Vector3.new(7, 0.4, 7),
		Position = Vector3.new(x - 15, 1.7, lado * 35),
		Color = Color3.fromRGB(40, 220, 90),
		Material = Enum.Material.Neon,
	}, carpeta)
	base.textoCobro = crearCartel(base.placaCobro, "$0", Color3.fromRGB(120, 255, 150), 50, 3)

	base.placaCandado = crearParte({
		Name = "Candado",
		Size = Vector3.new(7, 0.4, 7),
		Position = Vector3.new(x + 15, 1.7, lado * 35),
		Color = Color3.fromRGB(230, 50, 50),
		Material = Enum.Material.Neon,
	}, carpeta)
	base.textoCandado = crearCartel(base.placaCandado, "🔒 LOCK", Color3.fromRGB(255, 150, 150), 50, 3)

	table.insert(bases, base)
	return base
end

do
	local indice = 0
	for _, lado in ipairs({ -1, 1 }) do
		for _, x in ipairs({ -78, -26, 26, 78 }) do
			indice = indice + 1
			crearBase(indice, x, lado)
		end
	end
end

local function dentroDeBase(base, posicion)
	local p = base.piso.Position
	return math.abs(posicion.X - p.X) < ANCHO_BASE / 2 and math.abs(posicion.Z - p.Z) < FONDO_BASE / 2 and posicion.Y < 20
end

local function baseBloqueada(base)
	return ahora() < base.bloqueadaHasta
end

---------------------------------------------------------------------
-- DATOS DE LOS JUGADORES
---------------------------------------------------------------------
local almacen = nil
do
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore(CONFIG.CLAVE_DATASTORE)
	end)
	if ok then
		almacen = resultado
	else
		warn("DataStore no disponible (activa 'Enable Studio Access to API Services' para probar el guardado):", resultado)
	end
end

local sesiones = {} -- sesiones[jugador] = { datos, base, pendiente, llevando, pases }

local function datosNuevos()
	return { dinero = CONFIG.DINERO_INICIAL, rebirths = 0, velocidad = 0, aliens = {}, compras = {} }
end

local function cargarDatos(jugador)
	if not almacen then
		return datosNuevos()
	end
	local ok, datos = pcall(function()
		return almacen:GetAsync("j_" .. jugador.UserId)
	end)
	if not ok then
		warn("Error cargando datos de", jugador.Name, datos)
		return nil -- no dejamos jugar para no sobrescribir datos buenos
	end
	local nuevos = datosNuevos()
	if type(datos) == "table" then
		for clave, valor in pairs(datos) do
			nuevos[clave] = valor
		end
	end
	return nuevos
end

local function guardarDatos(jugador)
	local sesion = sesiones[jugador]
	if not almacen or not sesion or not sesion.cargado then
		return false
	end
	-- Pasamos los aliens de los pedestales a una lista guardable.
	local lista = {}
	for i, slot in ipairs(sesion.base.slots) do
		if slot.id then
			table.insert(lista, { s = i, id = slot.id })
		end
	end
	sesion.datos.aliens = lista
	sesion.datos.dinero = math.floor(sesion.datos.dinero)
	local ok, err = pcall(function()
		almacen:SetAsync("j_" .. jugador.UserId, sesion.datos)
	end)
	if not ok then
		warn("Error guardando datos de", jugador.Name, err)
	end
	return ok
end

local function multiplicador(sesion)
	local m = 1 + sesion.datos.rebirths * CONFIG.BONUS_POR_REBIRTH
	if sesion.pases.dobleDinero then
		m = m * 2
	end
	return m
end

local function ingresoPorSegundo(sesion)
	local total = 0
	for _, slot in ipairs(sesion.base.slots) do
		if slot.id then
			total = total + ALIEN_POR_ID[slot.id].ingreso
		end
	end
	return total * multiplicador(sesion)
end

local function actualizarStats(jugador)
	local sesion = sesiones[jugador]
	local stats = jugador:FindFirstChild("leaderstats")
	if not sesion or not stats then
		return
	end
	stats.Cash.Value = math.floor(sesion.datos.dinero)
	stats.Rebirths.Value = sesion.datos.rebirths
	jugador:SetAttribute("Ingreso", ingresoPorSegundo(sesion))
	jugador:SetAttribute("NivelVelocidad", sesion.datos.velocidad)
end

local function sumarDinero(jugador, cantidad)
	local sesion = sesiones[jugador]
	if sesion then
		sesion.datos.dinero = sesion.datos.dinero + cantidad
		actualizarStats(jugador)
	end
end

local function actualizarVelocidad(jugador)
	local sesion = sesiones[jugador]
	local _, humanoid = personajeVivo(jugador)
	if not sesion or not humanoid then
		return
	end
	local v = CONFIG.VELOCIDAD_BASE + sesion.datos.velocidad * CONFIG.VELOCIDAD_POR_NIVEL
	if sesion.pases.vip then
		v = v + 4
	end
	if sesion.llevando then
		v = v * CONFIG.FACTOR_VELOCIDAD_CARGANDO
	end
	humanoid.WalkSpeed = v
end

---------------------------------------------------------------------
-- ALIENS EN LAS BASES
---------------------------------------------------------------------
local robarAlien -- se define más abajo
local venderAlien

local function slotLibre(base)
	for i, slot in ipairs(base.slots) do
		if not slot.id then
			return i
		end
	end
	return nil
end

local function colocarAlien(base, indiceSlot, id)
	local slot = base.slots[indiceSlot]
	local def = ALIEN_POR_ID[id]
	if not slot or slot.id or not def then
		return false
	end
	slot.id = id
	local modelo = crearModeloAlien(def)
	modelo:PivotTo(CFrame.new(slot.pedestal.Position + Vector3.new(0, 0.5 + def.tamano / 2, 0)) * CFrame.Angles(0, base.lado == 1 and 0 or math.pi, 0))
	modelo.Parent = slot.pedestal
	slot.modelo = modelo

	-- Dos prompts: el cliente enseña "Steal" a los demás y "Sell" al dueño.
	local duenoId = base.dueno and base.dueno.UserId or 0
	local promptRobar = Instance.new("ProximityPrompt")
	promptRobar.ActionText = "Steal"
	promptRobar.ObjectText = def.nombre
	promptRobar.HoldDuration = 1.2
	promptRobar.RequiresLineOfSight = false
	promptRobar.MaxActivationDistance = 9
	promptRobar:SetAttribute("Dueno", duenoId)
	CollectionService:AddTag(promptRobar, "PromptRobar")
	promptRobar.Parent = modelo.PrimaryPart
	promptRobar.Triggered:Connect(function(jugador)
		robarAlien(jugador, base, indiceSlot)
	end)

	local promptVender = Instance.new("ProximityPrompt")
	promptVender.ActionText = "Sell $" .. abreviar(def.precio / 2)
	promptVender.ObjectText = def.nombre
	promptVender.HoldDuration = 1
	promptVender.RequiresLineOfSight = false
	promptVender.MaxActivationDistance = 9
	promptVender.KeyboardKeyCode = Enum.KeyCode.F
	promptVender:SetAttribute("Dueno", duenoId)
	CollectionService:AddTag(promptVender, "PromptVender")
	promptVender.Parent = modelo.PrimaryPart
	promptVender.Triggered:Connect(function(jugador)
		venderAlien(jugador, base, indiceSlot)
	end)

	if base.dueno then
		actualizarStats(base.dueno)
	end
	return true
end

local function quitarAlien(base, indiceSlot)
	local slot = base.slots[indiceSlot]
	local id = slot.id
	if slot.modelo then
		slot.modelo:Destroy()
	end
	slot.id = nil
	slot.modelo = nil
	if base.dueno then
		actualizarStats(base.dueno)
	end
	return id
end

function venderAlien(jugador, base, indiceSlot)
	if base.dueno ~= jugador or not base.slots[indiceSlot].id then
		return
	end
	local def = ALIEN_POR_ID[quitarAlien(base, indiceSlot)]
	sumarDinero(jugador, def.precio / 2)
	avisar(jugador, "Sold " .. def.nombre .. " for $" .. abreviar(def.precio / 2))
end

---------------------------------------------------------------------
-- ROBAR
---------------------------------------------------------------------
local function soltarCarga(ladron)
	local sesion = sesiones[ladron]
	local carga = sesion and sesion.llevando
	if not carga then
		return nil
	end
	sesion.llevando = nil
	if carga.modelo then
		carga.modelo:Destroy()
	end
	ladron:SetAttribute("Llevando", nil)
	actualizarVelocidad(ladron)
	return carga
end

-- Devuelve el alien a su dueño original (si sigue en el servidor y tiene sitio).
local function devolverCarga(ladron, motivo)
	local carga = soltarCarga(ladron)
	if not carga then
		return
	end
	local victima = carga.victima
	local sesionVictima = victima and sesiones[victima]
	if sesionVictima and sesionVictima.base == carga.base then
		local i = carga.base.slots[carga.slot].id == nil and carga.slot or slotLibre(carga.base)
		if i then
			colocarAlien(carga.base, i, carga.id)
		end
		avisar(victima, "You got your " .. ALIEN_POR_ID[carga.id].nombre .. " back!", Color3.fromRGB(120, 255, 150))
	end
	if motivo and ladron.Parent then
		avisar(ladron, motivo, Color3.fromRGB(255, 120, 120))
	end
end

function robarAlien(ladron, base, indiceSlot)
	local sesion = sesiones[ladron]
	local slot = base.slots[indiceSlot]
	if not sesion or not slot.id or base.dueno == ladron or not base.dueno then
		return
	end
	if sesion.llevando then
		avisar(ladron, "You are already carrying an alien!")
		return
	end
	if baseBloqueada(base) then
		avisar(ladron, "This base is locked!")
		return
	end
	local personaje = personajeVivo(ladron)
	local cabeza = personaje and personaje:FindFirstChild("Head")
	if not cabeza then
		return
	end

	local id = quitarAlien(base, indiceSlot)
	local def = ALIEN_POR_ID[id]

	local modelo = crearModeloAlien(def)
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("ProximityPrompt") then
			p:Destroy()
		end
	end
	prepararParaLlevar(modelo)
	modelo:PivotTo(cabeza.CFrame * CFrame.new(0, def.tamano / 2 + 1, 0))
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cabeza
	soldadura.Part1 = modelo.PrimaryPart
	soldadura.Parent = modelo.PrimaryPart
	modelo.Parent = personaje

	sesion.llevando = { id = id, victima = base.dueno, base = base, slot = indiceSlot, modelo = modelo }
	ladron:SetAttribute("Llevando", def.nombre)
	actualizarVelocidad(ladron)
	avisar(ladron, "Run to your base!", Color3.fromRGB(255, 220, 80))
	avisar(base.dueno, "⚠️ " .. ladron.DisplayName .. " is stealing your " .. def.nombre .. "! Catch them!", Color3.fromRGB(255, 90, 90))
end

-- Comprobamos a los ladrones varias veces por segundo.
task.spawn(function()
	while true do
		task.wait(0.15)
		for ladron, sesion in pairs(sesiones) do
			local carga = sesion.llevando
			if carga then
				local _, _, raiz = personajeVivo(ladron)
				if not raiz then
					devolverCarga(ladron, "You dropped the alien!")
				elseif dentroDeBase(sesion.base, raiz.Position) then
					local i = slotLibre(sesion.base)
					if i then
						soltarCarga(ladron)
						colocarAlien(sesion.base, i, carga.id)
						avisar(ladron, "Stolen! " .. ALIEN_POR_ID[carga.id].nombre .. " is yours!", Color3.fromRGB(120, 255, 150))
					else
						devolverCarga(ladron, "Your base is full! Sell an alien first.")
					end
				else
					local _, _, raizVictima = personajeVivo(carga.victima)
					if raizVictima and (raizVictima.Position - raiz.Position).Magnitude < CONFIG.DISTANCIA_ATRAPAR then
						devolverCarga(ladron, "Caught! The owner took it back.")
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- COBRAR Y CANDADO
---------------------------------------------------------------------
for _, base in ipairs(bases) do
	base.placaCobro.Touched:Connect(function(golpe)
		local jugador = jugadorDesdeToque(golpe)
		local sesion = jugador and sesiones[jugador]
		if sesion and base.dueno == jugador and sesion.pendiente >= 1 then
			local cantidad = sesion.pendiente
			sesion.pendiente = 0
			sumarDinero(jugador, cantidad)
			base.textoCobro.Text = "$0"
		end
	end)

	base.placaCandado.Touched:Connect(function(golpe)
		local jugador = jugadorDesdeToque(golpe)
		local sesion = jugador and sesiones[jugador]
		if not sesion or base.dueno ~= jugador or baseBloqueada(base) then
			return
		end
		local duracion = sesion.pases.vip and CONFIG.SEGUNDOS_CANDADO_VIP or CONFIG.SEGUNDOS_CANDADO
		base.bloqueadaHasta = ahora() + duracion
		base.barrera.Transparency = 0.4
		base.barrera.CanTouch = true
		avisar(jugador, "Base locked for " .. duracion .. "s", Color3.fromRGB(255, 150, 150))
	end)
end

-- Cada segundo: ingresos pasivos y estado del candado.
task.spawn(function()
	while true do
		task.wait(1)
		for jugador, sesion in pairs(sesiones) do
			if sesion.cargado then
				sesion.pendiente = sesion.pendiente + ingresoPorSegundo(sesion)
				sesion.base.textoCobro.Text = "$" .. abreviar(sesion.pendiente)
			end
		end
		for _, base in ipairs(bases) do
			local restante = math.ceil(base.bloqueadaHasta - ahora())
			if restante > 0 then
				base.textoCandado.Text = "🔒 " .. restante .. "s"
			elseif base.barrera.CanTouch then
				base.barrera.Transparency = 1
				base.barrera.CanTouch = false
				base.textoCandado.Text = "🔒 LOCK"
				if base.dueno then
					avisar(base.dueno, "Your base is unlocked!", Color3.fromRGB(255, 200, 80))
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- CINTA TRANSPORTADORA
---------------------------------------------------------------------
local aleatorio = Random.new()

local function elegirAlien()
	local suerte = ahora() < compartido:GetAttribute("SuerteHasta")
	local pesos, total = {}, 0
	for i, rareza in ipairs(RAREZAS) do
		local peso = rareza.peso
		if suerte and rareza.rara then
			peso = peso * CONFIG.MULTIPLICADOR_SUERTE
		end
		pesos[i] = peso
		total = total + peso
	end
	local tirada = aleatorio:NextNumber(0, total)
	local rarezaElegida = #RAREZAS
	for i, peso in ipairs(pesos) do
		tirada = tirada - peso
		if tirada <= 0 then
			rarezaElegida = i
			break
		end
	end
	local candidatos = {}
	for _, def in ipairs(ALIENS) do
		if def.rareza == rarezaElegida then
			table.insert(candidatos, def)
		end
	end
	return candidatos[aleatorio:NextInteger(1, #candidatos)]
end

local function comprarDeCinta(jugador, modelo, def)
	local sesion = sesiones[jugador]
	if not sesion or modelo:GetAttribute("Vendido") then
		return
	end
	if sesion.datos.dinero < def.precio then
		avisar(jugador, "Not enough cash! You need $" .. abreviar(def.precio), Color3.fromRGB(255, 120, 120))
		return
	end
	local i = slotLibre(sesion.base)
	if not i then
		avisar(jugador, "Your base is full! Sell an alien first.", Color3.fromRGB(255, 120, 120))
		return
	end
	modelo:SetAttribute("Vendido", true)
	modelo:Destroy()
	sumarDinero(jugador, -def.precio)
	colocarAlien(sesion.base, i, def.id)
	avisar(jugador, "You bought " .. def.nombre .. "!", Color3.fromRGB(120, 255, 150))
	if def.rareza >= 4 then
		avisarATodos(jugador.DisplayName .. " bought a " .. RAREZAS[def.rareza].nombre .. " " .. def.nombre .. "!", RAREZAS[def.rareza].color)
	end
end

local enCinta = {}

local function lanzarAlienEnCinta()
	local def = elegirAlien()
	local modelo = crearModeloAlien(def)
	local alto = Vector3.new(0, def.tamano / 2, 0)
	modelo:PivotTo(CFrame.new(CINTA_INICIO + alto) * CFrame.Angles(0, -math.pi / 2, 0))
	modelo.Parent = mapa

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy $" .. abreviar(def.precio)
	prompt.ObjectText = def.nombre .. " (" .. RAREZAS[def.rareza].nombre .. ")"
	prompt.HoldDuration = 0.25
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = modelo.PrimaryPart
	prompt.Triggered:Connect(function(jugador)
		comprarDeCinta(jugador, modelo, def)
	end)

	if def.rareza >= 5 then
		avisarATodos("✨ A " .. RAREZAS[def.rareza].nombre .. " " .. def.nombre .. " appeared on the belt!", RAREZAS[def.rareza].color)
	end

	table.insert(enCinta, { modelo = modelo, alto = alto, inicio = ahora() })
end

-- Un único bucle mueve todos los aliens de la cinta.
RunService.Heartbeat:Connect(function()
	local t0 = ahora()
	for i = #enCinta, 1, -1 do
		local item = enCinta[i]
		local t = (t0 - item.inicio) / CONFIG.SEGUNDOS_EN_CINTA
		if not item.modelo.Parent or t >= 1 then
			item.modelo:Destroy()
			table.remove(enCinta, i)
		else
			item.modelo:PivotTo(CFrame.new(CINTA_INICIO:Lerp(CINTA_FIN, t) + item.alto) * CFrame.Angles(0, -math.pi / 2, 0))
		end
	end
end)

task.spawn(function()
	while true do
		lanzarAlienEnCinta()
		task.wait(CONFIG.SEGUNDOS_ENTRE_ALIENS)
	end
end)

-- Evento de suerte gratuito periódico (da motivos para quedarse y volver).
local function activarSuerte(segundos, texto)
	local desde = math.max(ahora(), compartido:GetAttribute("SuerteHasta"))
	compartido:SetAttribute("SuerteHasta", desde + segundos)
	avisarATodos(texto, Color3.fromRGB(120, 255, 120))
end

task.spawn(function()
	while true do
		task.wait(CONFIG.SUERTE_GRATIS_CADA)
		activarSuerte(CONFIG.SUERTE_GRATIS_DURA, "🍀 LUCKY BELT! Rare aliens x" .. CONFIG.MULTIPLICADOR_SUERTE .. " for " .. CONFIG.SUERTE_GRATIS_DURA .. "s!")
	end
end)

---------------------------------------------------------------------
-- TIENDAS DE LA PLAZA: VELOCIDAD Y REBIRTH
---------------------------------------------------------------------
local function costeVelocidad(nivel)
	return math.floor(300 * 3 ^ nivel)
end

local function costeRebirth(rebirths)
	return math.floor(1000000 * 4 ^ rebirths)
end

local function crearPuesto(nombre, posicion, color, texto, accion, alPulsar)
	local puesto = crearParte({
		Name = nombre,
		Size = Vector3.new(8, 6, 8),
		Position = posicion,
		Color = color,
		Material = Enum.Material.Neon,
	}, mapa)
	crearCartel(puesto, texto, Color3.new(1, 1, 1), 50, 5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = accion
	prompt.ObjectText = nombre
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.Parent = puesto
	prompt.Triggered:Connect(alPulsar)
end

crearPuesto("Speed Shop", Vector3.new(-115, 3.5, 18), Color3.fromRGB(0, 170, 255), "⚡ SPEED", "Upgrade", function(jugador)
	local sesion = sesiones[jugador]
	if not sesion then
		return
	end
	local nivel = sesion.datos.velocidad
	if nivel >= CONFIG.NIVEL_VELOCIDAD_MAX then
		avisar(jugador, "Max speed reached!")
		return
	end
	local coste = costeVelocidad(nivel)
	if sesion.datos.dinero < coste then
		avisar(jugador, "Speed " .. (nivel + 1) .. " costs $" .. abreviar(coste), Color3.fromRGB(255, 120, 120))
		return
	end
	sesion.datos.velocidad = nivel + 1
	sumarDinero(jugador, -coste)
	actualizarVelocidad(jugador)
	avisar(jugador, "Speed level " .. sesion.datos.velocidad .. "!", Color3.fromRGB(120, 200, 255))
end)

crearPuesto("Rebirth", Vector3.new(-115, 3.5, -18), Color3.fromRGB(255, 80, 200), "🌌 REBIRTH", "Rebirth", function(jugador)
	local sesion = sesiones[jugador]
	if not sesion or sesion.llevando then
		return
	end
	local coste = costeRebirth(sesion.datos.rebirths)
	if sesion.datos.dinero < coste then
		avisar(jugador, "Rebirth needs $" .. abreviar(coste) .. ". Resets cash and aliens, +50% income forever.", Color3.fromRGB(255, 150, 220))
		return
	end
	for i in ipairs(sesion.base.slots) do
		quitarAlien(sesion.base, i)
	end
	sesion.datos.rebirths = sesion.datos.rebirths + 1
	sesion.datos.dinero = CONFIG.DINERO_INICIAL
	sesion.pendiente = 0
	actualizarStats(jugador)
	guardarDatos(jugador)
	avisarATodos("🌌 " .. jugador.DisplayName .. " reached Rebirth " .. sesion.datos.rebirths .. "!", Color3.fromRGB(255, 150, 220))
end)

---------------------------------------------------------------------
-- MONETIZACIÓN
---------------------------------------------------------------------
local function comprobarPases(jugador)
	local sesion = sesiones[jugador]
	local function tiene(id)
		if id == 0 then
			return false
		end
		local ok, resultado = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(jugador.UserId, id)
		end)
		return ok and resultado
	end
	sesion.pases.dobleDinero = tiene(MONETIZACION.PASE_DOBLE_DINERO)
	sesion.pases.vip = tiene(MONETIZACION.PASE_VIP)
	jugador:SetAttribute("VIP", sesion.pases.vip)
	actualizarStats(jugador)
	actualizarVelocidad(jugador)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(jugador, idPase, comprado)
	local sesion = sesiones[jugador]
	if comprado and sesion and idPase ~= 0 then
		-- Lo activamos directamente: UserOwnsGamePassAsync puede tardar en enterarse.
		if idPase == MONETIZACION.PASE_DOBLE_DINERO then
			sesion.pases.dobleDinero = true
		elseif idPase == MONETIZACION.PASE_VIP then
			sesion.pases.vip = true
			jugador:SetAttribute("VIP", true)
		end
		actualizarStats(jugador)
		actualizarVelocidad(jugador)
		avisar(jugador, "Thanks for your support! 💜", Color3.fromRGB(200, 150, 255))
	end
end)

local function paqueteDinero(jugador, segundosDeIngreso, minimo)
	local sesion = sesiones[jugador]
	local cantidad = math.max(minimo, ingresoPorSegundo(sesion) * segundosDeIngreso)
	sumarDinero(jugador, cantidad)
	avisar(jugador, "+$" .. abreviar(cantidad) .. "! Thanks! 💜", Color3.fromRGB(120, 255, 150))
end

local ENTREGAS = {}
ENTREGAS[MONETIZACION.PRODUCTO_DINERO_PEQUENO] = function(jugador)
	paqueteDinero(jugador, 600, 2500)
end
ENTREGAS[MONETIZACION.PRODUCTO_DINERO_GRANDE] = function(jugador)
	paqueteDinero(jugador, 3600, 25000)
end
ENTREGAS[MONETIZACION.PRODUCTO_SUERTE_SERVIDOR] = function(jugador)
	activarSuerte(CONFIG.SUERTE_PAGADA_DURA, "🍀 " .. jugador.DisplayName .. " activated LUCKY BELT for everyone! (" .. CONFIG.SUERTE_PAGADA_DURA .. "s)")
end
ENTREGAS[0] = nil -- los productos aún sin ID no entregan nada

-- Roblox llama a esta función con cada compra de Developer Product.
-- Guardamos el ID de cada compra para no entregarla dos veces.
MarketplaceService.ProcessReceipt = function(recibo)
	local jugador = Players:GetPlayerByUserId(recibo.PlayerId)
	local sesion = jugador and sesiones[jugador]
	local entregar = ENTREGAS[recibo.ProductId]
	if not sesion or not sesion.cargado or not entregar then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local compras = sesion.datos.compras
	for _, idCompra in ipairs(compras) do
		if idCompra == recibo.PurchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	local ok, err = pcall(entregar, jugador)
	if not ok then
		warn("Error entregando compra:", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(compras, recibo.PurchaseId)
	while #compras > 50 do
		table.remove(compras, 1)
	end
	if almacen and not guardarDatos(jugador) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------
-- ENTRADA Y SALIDA DE JUGADORES
---------------------------------------------------------------------
local function asignarBase(jugador)
	for _, base in ipairs(bases) do
		if not base.dueno then
			base.dueno = jugador
			return base
		end
	end
	return nil
end

local function alEntrar(jugador)
	local base = asignarBase(jugador)
	if not base then
		jugador:Kick("Server full, please join another server.")
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = jugador

	local sesion = { datos = datosNuevos(), base = base, pendiente = 0, llevando = nil, pases = {}, cargado = false }
	sesiones[jugador] = sesion
	base.cartel.Text = jugador.DisplayName .. "'s base"

	jugador.CharacterAdded:Connect(function(personaje)
		personaje:WaitForChild("HumanoidRootPart")
		task.wait()
		personaje:PivotTo(CFrame.new(base.centro + Vector3.new(0, 4, 0)))
		actualizarVelocidad(jugador)
	end)

	local datos = cargarDatos(jugador)
	if not datos then
		jugador:Kick("Could not load your data. Please rejoin.")
		return
	end
	if not jugador.Parent then
		return -- se fue mientras cargábamos
	end
	sesion.datos = datos
	for _, guardado in ipairs(datos.aliens) do
		colocarAlien(base, guardado.s, guardado.id)
	end
	sesion.cargado = true
	comprobarPases(jugador)
	actualizarStats(jugador)
	jugador:SetAttribute("BaseIndice", base.indice)
	avisar(jugador, "Welcome! Buy aliens on the belt and steal from other bases!", Color3.fromRGB(0, 255, 200))
end

local function alSalir(jugador)
	local sesion = sesiones[jugador]
	if not sesion then
		return
	end
	devolverCarga(jugador, nil)
	-- Si alguien le estaba robando, el alien se queda con el ladrón al llegar a su base.
	guardarDatos(jugador)
	local base = sesion.base
	for i in ipairs(base.slots) do
		quitarAlien(base, i)
	end
	base.dueno = nil
	base.bloqueadaHasta = 0
	base.cartel.Text = "Empty base"
	base.textoCobro.Text = "$0"
	sesiones[jugador] = nil
end

Players.PlayerAdded:Connect(alEntrar)
Players.PlayerRemoving:Connect(alSalir)
for _, jugador in ipairs(Players:GetPlayers()) do
	task.spawn(alEntrar, jugador)
end

-- Autoguardado cada 2 minutos y al cerrar el servidor.
task.spawn(function()
	while true do
		task.wait(120)
		for jugador in pairs(sesiones) do
			guardarDatos(jugador)
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() and not almacen then
		return
	end
	for jugador in pairs(sesiones) do
		task.spawn(guardarDatos, jugador)
	end
	task.wait(3)
end)
