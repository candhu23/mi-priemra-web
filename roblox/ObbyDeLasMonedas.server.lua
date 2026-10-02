--[[
	OBBY DE LAS MONEDAS
	-------------------
	Un juego de obstáculos (obby) completo en un solo Script.

	Cómo usarlo:
	  1. Abre Roblox Studio y crea un juego nuevo con la plantilla "Baseplate".
	  2. En el Explorador, haz clic derecho en ServerScriptService > Insert Object > Script.
	  3. Borra el contenido del Script y pega TODO este archivo.
	  4. Pulsa Play.

	El script construye el mapa al arrancar (plataformas, lava, checkpoints,
	monedas y meta) y gestiona las estadísticas de cada jugador.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

---------------------------------------------------------------------
-- CONFIGURACIÓN (cambia estos números para modificar el juego)
---------------------------------------------------------------------
local CONFIG = {
	NUM_ETAPAS = 5, -- cuántas etapas (cada una termina en un checkpoint)
	PLATAFORMAS_POR_ETAPA = 4, -- saltos por etapa
	SEPARACION = 13, -- distancia (en studs) entre plataformas
	SUBIDA = 1.2, -- cuánto sube cada plataforma respecto a la anterior
	SEMILLA = 2026, -- cambia la semilla para obtener otro recorrido
	RESPAWN_MONEDA = 10, -- segundos hasta que reaparece una moneda
	PREMIO_META = 10, -- monedas extra por llegar a la meta
}

local COLORES = {
	normal = Color3.fromRGB(80, 160, 255),
	desaparece = Color3.fromRGB(255, 120, 200),
	pequena = Color3.fromRGB(150, 110, 255),
	checkpoint = Color3.fromRGB(70, 200, 90),
	checkpointActivo = Color3.fromRGB(150, 255, 150),
	lava = Color3.fromRGB(255, 80, 20),
	moneda = Color3.fromRGB(255, 205, 40),
	meta = Color3.fromRGB(255, 215, 0),
}

local aleatorio = Random.new(CONFIG.SEMILLA)

---------------------------------------------------------------------
-- PREPARAR EL MUNDO
---------------------------------------------------------------------
-- Quitamos el suelo y el spawn de la plantilla para que caer sea peligroso.
for _, nombre in ipairs({ "Baseplate", "SpawnLocation" }) do
	local viejo = workspace:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
end

local mapa = Instance.new("Folder")
mapa.Name = "MapaObby"
mapa.Parent = workspace

local function crearParte(clase, propiedades)
	local parte = Instance.new(clase)
	parte.Anchored = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	for propiedad, valor in pairs(propiedades) do
		parte[propiedad] = valor
	end
	parte.Parent = mapa
	return parte
end

local function crearCartel(parte, texto, color)
	local cartel = Instance.new("BillboardGui")
	cartel.Size = UDim2.fromOffset(200, 50)
	cartel.StudsOffset = Vector3.new(0, 5, 0)
	cartel.AlwaysOnTop = false
	cartel.Parent = parte

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.Text = texto
	etiqueta.TextColor3 = color
	etiqueta.TextStrokeTransparency = 0
	etiqueta.TextScaled = true
	etiqueta.Font = Enum.Font.FredokaOne
	etiqueta.Parent = cartel
end

-- Devuelve el jugador y su Humanoid si lo que ha tocado la parte es un personaje vivo.
local function jugadorDesdeToque(golpe)
	local personaje = golpe:FindFirstAncestorOfClass("Model")
	if not personaje then
		return nil
	end
	local humanoid = personaje:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local jugador = Players:GetPlayerFromCharacter(personaje)
	if not jugador then
		return nil
	end
	return jugador, humanoid
end

---------------------------------------------------------------------
-- AVISOS EN PANTALLA
---------------------------------------------------------------------
local turnoAviso = {} -- evita que un aviso viejo borre uno nuevo

local function avisar(jugador, texto, color)
	local gui = jugador:FindFirstChild("PlayerGui")
	local avisos = gui and gui:FindFirstChild("Avisos")
	if not avisos then
		return
	end
	local etiqueta = avisos.Texto
	etiqueta.Text = texto
	etiqueta.TextColor3 = color or Color3.new(1, 1, 1)
	etiqueta.Visible = true

	local turno = (turnoAviso[jugador] or 0) + 1
	turnoAviso[jugador] = turno
	task.delay(2.5, function()
		if turnoAviso[jugador] == turno and etiqueta.Parent then
			etiqueta.Visible = false
		end
	end)
end

local function crearGuiAvisos(jugador)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Avisos"
	gui.ResetOnSpawn = false

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = "Texto"
	etiqueta.AnchorPoint = Vector2.new(0.5, 0)
	etiqueta.Position = UDim2.fromScale(0.5, 0.15)
	etiqueta.Size = UDim2.fromScale(0.6, 0.08)
	etiqueta.BackgroundTransparency = 1
	etiqueta.TextScaled = true
	etiqueta.TextStrokeTransparency = 0
	etiqueta.Font = Enum.Font.FredokaOne
	etiqueta.Visible = false
	etiqueta.Parent = gui

	gui.Parent = jugador:WaitForChild("PlayerGui")
end

---------------------------------------------------------------------
-- ELEMENTOS DEL OBBY
---------------------------------------------------------------------
local checkpoints = {} -- checkpoints[numeroEtapa] = parte
local monedas = {} -- lista de monedas para hacerlas girar

local function hacerMortal(parte)
	parte.Touched:Connect(function(golpe)
		local _, humanoid = jugadorDesdeToque(golpe)
		if humanoid then
			humanoid.Health = 0
		end
	end)
end

local function crearMoneda(posicion)
	local moneda = crearParte("Part", {
		Name = "Moneda",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2.5, 2.5),
		Color = COLORES.moneda,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CFrame = CFrame.new(posicion),
	})
	table.insert(monedas, moneda)

	local recogida = false
	moneda.Touched:Connect(function(golpe)
		if recogida then
			return
		end
		local jugador = jugadorDesdeToque(golpe)
		if not jugador then
			return
		end
		recogida = true
		local stats = jugador:FindFirstChild("leaderstats")
		if stats then
			stats.Monedas.Value = stats.Monedas.Value + 1
		end
		moneda.Transparency = 1
		task.delay(CONFIG.RESPAWN_MONEDA, function()
			moneda.Transparency = 0
			recogida = false
		end)
	end)
end

local function crearPlataformaQueDesaparece(parte)
	local activa = false
	parte.Touched:Connect(function(golpe)
		if activa or not jugadorDesdeToque(golpe) then
			return
		end
		activa = true
		local info = TweenInfo.new(0.8)
		TweenService:Create(parte, info, { Transparency = 0.8 }):Play()
		task.wait(0.8)
		parte.CanCollide = false
		task.wait(2.5)
		parte.CanCollide = true
		parte.Transparency = 0
		activa = false
	end)
end

local function crearCheckpoint(numero, posicion)
	local parte = crearParte("Part", {
		Name = "Checkpoint" .. numero,
		Size = Vector3.new(12, 1, 12),
		Position = posicion,
		Color = COLORES.checkpoint,
		Material = Enum.Material.SmoothPlastic,
	})
	crearCartel(parte, "Checkpoint " .. numero, COLORES.checkpointActivo)
	checkpoints[numero] = parte

	parte.Touched:Connect(function(golpe)
		local jugador = jugadorDesdeToque(golpe)
		local stats = jugador and jugador:FindFirstChild("leaderstats")
		if stats and stats.Etapa.Value < numero then
			stats.Etapa.Value = numero
			parte.Color = COLORES.checkpointActivo
			avisar(jugador, "¡Checkpoint " .. numero .. "!", COLORES.checkpointActivo)
		end
	end)
end

---------------------------------------------------------------------
-- CONSTRUIR EL RECORRIDO
---------------------------------------------------------------------
local inicio = crearParte("SpawnLocation", {
	Name = "Inicio",
	Size = Vector3.new(14, 1, 14),
	Position = Vector3.new(0, 10, 0),
	Color = COLORES.checkpoint,
	Material = Enum.Material.SmoothPlastic,
	Neutral = true,
	Duration = 0, -- sin campo de fuerza al aparecer
})
crearCartel(inicio, "¡Llega a la meta!", Color3.new(1, 1, 1))
checkpoints[0] = inicio

local posicion = inicio.Position
local function siguientePosicion()
	posicion = Vector3.new(aleatorio:NextNumber(-4, 4), posicion.Y + CONFIG.SUBIDA, posicion.Z + CONFIG.SEPARACION)
	return posicion
end

for etapa = 1, CONFIG.NUM_ETAPAS do
	for i = 1, CONFIG.PLATAFORMAS_POR_ETAPA do
		local pos = siguientePosicion()
		local tipo = "normal"
		-- La dificultad aumenta con cada etapa.
		if etapa >= 2 and i == 2 then
			tipo = "desaparece"
		elseif etapa >= 3 and i == 3 then
			tipo = "pequena"
		elseif etapa >= 4 and i == 1 then
			tipo = "lava"
		end

		local tamano = tipo == "pequena" and Vector3.new(4, 1, 4) or Vector3.new(8, 1, 8)
		local plataforma = crearParte("Part", {
			Name = "Plataforma",
			Size = tamano,
			Position = pos,
			Color = COLORES[tipo] or COLORES.normal,
			Material = Enum.Material.SmoothPlastic,
		})

		if tipo == "desaparece" then
			crearPlataformaQueDesaparece(plataforma)
		elseif tipo == "lava" then
			-- Una franja de lava en medio de la plataforma: hay que saltarla.
			plataforma.Color = COLORES.normal
			local franja = crearParte("Part", {
				Name = "Lava",
				Size = Vector3.new(8, 0.4, 1.5),
				Position = pos + Vector3.new(0, 0.7, 0),
				Color = COLORES.lava,
				Material = Enum.Material.Neon,
			})
			hacerMortal(franja)
		end

		if tipo == "normal" and aleatorio:NextNumber() < 0.7 then
			crearMoneda(pos + Vector3.new(0, 3, 0))
		end
	end

	if etapa < CONFIG.NUM_ETAPAS then
		crearCheckpoint(etapa, siguientePosicion())
	end
end

-- Meta
local meta = crearParte("Part", {
	Name = "Meta",
	Size = Vector3.new(16, 1, 16),
	Position = siguientePosicion(),
	Color = COLORES.meta,
	Material = Enum.Material.Neon,
})
crearCartel(meta, "🏆 META 🏆", COLORES.meta)

-- Suelo de lava bajo todo el recorrido
local largo = meta.Position.Z + 40
local sueloLava = crearParte("Part", {
	Name = "SueloDeLava",
	Size = Vector3.new(120, 2, largo + 40),
	Position = Vector3.new(0, -5, largo / 2 - 20),
	Color = COLORES.lava,
	Material = Enum.Material.Neon,
})
hacerMortal(sueloLava)

-- Hacer girar las monedas
RunService.Heartbeat:Connect(function(dt)
	local giro = CFrame.Angles(0, dt * 3, 0)
	for _, moneda in ipairs(monedas) do
		moneda.CFrame = moneda.CFrame * giro
	end
end)

---------------------------------------------------------------------
-- META
---------------------------------------------------------------------
local celebrando = {}

meta.Touched:Connect(function(golpe)
	local jugador = jugadorDesdeToque(golpe)
	if not jugador or celebrando[jugador] then
		return
	end
	local stats = jugador:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	celebrando[jugador] = true
	stats.Victorias.Value = stats.Victorias.Value + 1
	stats.Monedas.Value = stats.Monedas.Value + CONFIG.PREMIO_META
	avisar(jugador, "🏆 ¡Has ganado! +" .. CONFIG.PREMIO_META .. " monedas", COLORES.meta)

	task.wait(4)
	if jugador.Parent then
		stats.Etapa.Value = 0
		jugador:LoadCharacter() -- vuelve al inicio para jugar otra vez
	end
	celebrando[jugador] = nil
end)

---------------------------------------------------------------------
-- JUGADORES
---------------------------------------------------------------------
local function alEntrarJugador(jugador)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats" -- este nombre exacto hace que salga en la tabla de puntuación

	for _, nombre in ipairs({ "Etapa", "Monedas", "Victorias" }) do
		local valor = Instance.new("IntValue")
		valor.Name = nombre
		valor.Parent = stats
	end
	stats.Parent = jugador

	-- Al reaparecer, el jugador vuelve a su último checkpoint.
	jugador.CharacterAdded:Connect(function(personaje)
		personaje:WaitForChild("HumanoidRootPart")
		task.wait() -- deja que Roblox termine de colocar al personaje
		local checkpoint = checkpoints[stats.Etapa.Value] or inicio
		personaje:PivotTo(checkpoint.CFrame + Vector3.new(0, 4, 0))
	end)

	crearGuiAvisos(jugador)
	if jugador.Character then
		jugador:LoadCharacter()
	end
end

Players.PlayerAdded:Connect(alEntrarJugador)
for _, jugador in ipairs(Players:GetPlayers()) do
	task.spawn(alEntrarJugador, jugador)
end

Players.PlayerRemoving:Connect(function(jugador)
	turnoAviso[jugador] = nil
	celebrando[jugador] = nil
end)
