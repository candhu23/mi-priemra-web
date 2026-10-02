--!strict
--[[
	Construye el mapa al arrancar el servidor: plaza, cinta, 8 bases, puestos,
	rankings, decoración e iluminación. Devuelve referencias para la lógica del juego.

	Puedes decorar más el mapa en Studio: todo lo que pongas en Workspace se mantiene.
	Este módulo solo borra el Baseplate y el SpawnLocation de la plantilla.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Compartido"):WaitForChild("Config"))

local Mapa = {}

export type Slot = {
	pedestal: Part,
	etiqueta: TextLabel,
	id: string?,
	shiny: boolean,
	modelo: Model?,
}

export type Base = {
	indice: number,
	lado: number,
	x: number,
	color: Color3,
	centro: Vector3,
	piso: Part,
	barrera: Part,
	cartel: TextLabel,
	slots: { Slot },
	placaCobro: Part,
	textoCobro: TextLabel,
	placaCandado: Part,
	textoCandado: TextLabel,
	carpeta: Folder,
	dueno: Player?,
	bloqueadaHasta: number,
}

export type Ranking = { titulo: TextLabel, filas: { TextLabel } }

export type MapaConstruido = {
	carpeta: Folder,
	bases: { Base },
	cintaInicio: Vector3,
	cintaFin: Vector3,
	alturaCinta: number,
	puestoVelocidad: Part,
	puestoRebirth: Part,
	rankings: { [string]: Ranking },
	zonaMeteoritos: { xMin: number, xMax: number, zMin: number, zMax: number },
}

Mapa.ANCHO_BASE = 44
Mapa.FONDO_BASE = 40
Mapa.FRENTE_BASE = 30 -- distancia de la cinta al frente de cada base

local COLORES_BASE = {
	Color3.fromRGB(0, 255, 200),
	Color3.fromRGB(255, 80, 200),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(90, 140, 255),
	Color3.fromRGB(120, 255, 90),
	Color3.fromRGB(255, 120, 60),
	Color3.fromRGB(190, 90, 255),
	Color3.fromRGB(255, 70, 90),
}

local function parte(padre: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = padre
	return p
end

local function cartel(adornee: BasePart, texto: string, color: Color3, ancho: number, alto: number, offsetY: number, distancia: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Cartel"
	gui.Size = UDim2.fromOffset(ancho, alto)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = distancia or 150
	gui.LightInfluence = 0
	gui.Parent = adornee
	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = "Texto"
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.Text = texto
	etiqueta.TextColor3 = color
	etiqueta.TextStrokeTransparency = 0
	etiqueta.TextScaled = true
	etiqueta.RichText = true
	etiqueta.Font = Enum.Font.FredokaOne
	etiqueta.Parent = gui
	return etiqueta
end

local function iluminacion()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(95, 85, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 110, 180)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	for _, hijo in Lighting:GetChildren() do
		if hijo:IsA("Sky") or hijo:IsA("Atmosphere") or hijo:IsA("BloomEffect") or hijo:IsA("ColorCorrectionEffect") then
			hijo:Destroy()
		end
	end
	local cielo = Instance.new("Sky")
	cielo.StarCount = 5000
	cielo.CelestialBodiesShown = false
	cielo.Parent = Lighting
	local atmosfera = Instance.new("Atmosphere")
	atmosfera.Density = 0.28
	atmosfera.Color = Color3.fromRGB(120, 80, 190)
	atmosfera.Decay = Color3.fromRGB(60, 30, 110)
	atmosfera.Glare = 0.3
	atmosfera.Haze = 1.5
	atmosfera.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local correccion = Instance.new("ColorCorrectionEffect")
	correccion.Saturation = 0.15
	correccion.Contrast = 0.05
	correccion.Parent = Lighting
end

local function decoracion(carpeta: Folder)
	-- Planetas en el horizonte
	local planetas = {
		{ pos = Vector3.new(420, 160, -380), tam = 160, color = Color3.fromRGB(255, 120, 80), anillo = true },
		{ pos = Vector3.new(-450, 220, 300), tam = 110, color = Color3.fromRGB(90, 200, 255), anillo = false },
		{ pos = Vector3.new(-300, 120, -500), tam = 70, color = Color3.fromRGB(200, 120, 255), anillo = false },
	}
	for _, datos in planetas do
		local planeta = parte(carpeta, {
			Name = "Planeta",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * datos.tam,
			Position = datos.pos,
			Color = datos.color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		if datos.anillo then
			parte(carpeta, {
				Name = "Anillo",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2, datos.tam * 1.9, datos.tam * 1.9),
				CFrame = CFrame.new(planeta.Position) * CFrame.Angles(0, 0, math.rad(70)) * CFrame.Angles(math.rad(15), 0, 0),
				Color = Color3.fromRGB(255, 220, 160),
				Material = Enum.Material.Neon,
				Transparency = 0.5,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
		end
	end
	-- Rocas flotantes alrededor
	local rng = Random.new(7)
	for _ = 1, 24 do
		local angulo = rng:NextNumber(0, math.pi * 2)
		local distancia = rng:NextNumber(190, 320)
		parte(carpeta, {
			Name = "Asteroide",
			Size = Vector3.new(rng:NextNumber(4, 14), rng:NextNumber(4, 12), rng:NextNumber(4, 14)),
			CFrame = CFrame.new(math.cos(angulo) * distancia, rng:NextNumber(-20, 60), math.sin(angulo) * distancia)
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Color = Color3.fromRGB(80, 70, 100),
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

local function crearRanking(carpeta: Folder, nombre: string, titulo: string, posicion: Vector3, color: Color3): Ranking
	local tablero = parte(carpeta, {
		Name = "Ranking_" .. nombre,
		Size = Vector3.new(1, 16, 20),
		Position = posicion,
		Color = Color3.fromRGB(25, 20, 45),
	})
	parte(carpeta, {
		Name = "Marco",
		Size = Vector3.new(0.6, 16.8, 20.8),
		Position = posicion + Vector3.new(0.3, 0, 0),
		Color = color,
		Material = Enum.Material.Neon,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left -- mira hacia la plaza (-X)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = tablero
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 6)
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.Parent = gui
	local function fila(texto: string, alto: number, colorTexto: Color3): TextLabel
		local etiqueta = Instance.new("TextLabel")
		etiqueta.Size = UDim2.new(0.92, 0, 0, alto)
		etiqueta.BackgroundTransparency = 1
		etiqueta.Text = texto
		etiqueta.TextColor3 = colorTexto
		etiqueta.TextScaled = true
		etiqueta.Font = Enum.Font.FredokaOne
		etiqueta.TextXAlignment = Enum.TextXAlignment.Left
		etiqueta.Parent = gui
		return etiqueta
	end
	local cabecera = fila(titulo, 60, color)
	cabecera.TextXAlignment = Enum.TextXAlignment.Center
	local filas = {}
	for i = 1, 10 do
		table.insert(filas, fila(i .. ". ...", 36, Color3.new(1, 1, 1)))
	end
	return { titulo = cabecera, filas = filas }
end

local function crearBase(carpetaMapa: Folder, indice: number, x: number, lado: number): Base
	local color = COLORES_BASE[indice]
	local frenteZ = lado * Mapa.FRENTE_BASE
	local centroZ = lado * (Mapa.FRENTE_BASE + Mapa.FONDO_BASE / 2)
	local fondoZ = lado * (Mapa.FRENTE_BASE + Mapa.FONDO_BASE)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Base" .. indice
	carpeta.Parent = carpetaMapa

	local piso = parte(carpeta, {
		Name = "Piso",
		Size = Vector3.new(Mapa.ANCHO_BASE, 1, Mapa.FONDO_BASE),
		Position = Vector3.new(x, 1, centroZ),
		Color = Color3.fromRGB(55, 50, 85),
		Material = Enum.Material.DiamondPlate,
	})
	-- Borde de neón con el color de la base
	parte(carpeta, {
		Name = "Borde",
		Size = Vector3.new(Mapa.ANCHO_BASE, 0.3, 1),
		Position = Vector3.new(x, 1.55, frenteZ + lado * 0.5),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local colorPared = Color3.fromRGB(70, 60, 110)
	parte(carpeta, { Name = "Pared", Size = Vector3.new(Mapa.ANCHO_BASE, 12, 1), Position = Vector3.new(x, 7, fondoZ), Color = colorPared })
	parte(carpeta, { Name = "Franja", Size = Vector3.new(Mapa.ANCHO_BASE, 0.6, 1.2), Position = Vector3.new(x, 12.8, fondoZ), Color = color, Material = Enum.Material.Neon })
	for _, dx in { -Mapa.ANCHO_BASE / 2, Mapa.ANCHO_BASE / 2 } do
		parte(carpeta, { Name = "Pared", Size = Vector3.new(1, 12, Mapa.FONDO_BASE), Position = Vector3.new(x + dx, 7, centroZ), Color = colorPared })
		parte(carpeta, { Name = "Franja", Size = Vector3.new(1.2, 0.6, Mapa.FONDO_BASE), Position = Vector3.new(x + dx, 12.8, centroZ), Color = color, Material = Enum.Material.Neon })
	end

	local barrera = parte(carpeta, {
		Name = "Barrera",
		Size = Vector3.new(Mapa.ANCHO_BASE, 12, 1),
		Position = Vector3.new(x, 7, frenteZ),
		Color = Color3.fromRGB(255, 40, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	local poste = parte(carpeta, {
		Name = "Poste",
		Size = Vector3.one,
		Position = Vector3.new(x, 17, fondoZ),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local etiquetaDueno = cartel(poste, "Empty base", Color3.new(1, 1, 1), 320, 70, 0, 250)

	local slots: { Slot } = {}
	for fila = 0, 2 do
		for col = 0, 4 do
			local pedestal = parte(carpeta, {
				Name = "Pedestal",
				Size = Vector3.new(5, 1, 5),
				Position = Vector3.new(x - 16 + col * 8, 2, lado * (Mapa.FRENTE_BASE + 13 + fila * 10)),
				Color = Color3.fromRGB(100, 90, 150),
			})
			parte(carpeta, {
				Name = "Aro",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 5.6, 5.6),
				CFrame = CFrame.new(pedestal.Position + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.4,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
			local etiqueta = cartel(pedestal, "", Color3.fromRGB(200, 200, 220), 140, 40, 2, 60)
			table.insert(slots, { pedestal = pedestal, etiqueta = etiqueta, id = nil, shiny = false, modelo = nil })
		end
	end

	local placaCobro = parte(carpeta, {
		Name = "Cobrar",
		Size = Vector3.new(8, 0.4, 7),
		Position = Vector3.new(x - 15, 1.7, lado * (Mapa.FRENTE_BASE + 5)),
		Color = Color3.fromRGB(40, 230, 100),
		Material = Enum.Material.Neon,
	})
	local textoCobro = cartel(placaCobro, "$0", Color3.fromRGB(140, 255, 170), 220, 60, 3.5, 120)

	local placaCandado = parte(carpeta, {
		Name = "Candado",
		Size = Vector3.new(8, 0.4, 7),
		Position = Vector3.new(x + 15, 1.7, lado * (Mapa.FRENTE_BASE + 5)),
		Color = Color3.fromRGB(240, 50, 70),
		Material = Enum.Material.Neon,
	})
	local textoCandado = cartel(placaCandado, "🔒 LOCK", Color3.fromRGB(255, 160, 170), 220, 60, 3.5, 120)

	return {
		indice = indice,
		lado = lado,
		x = x,
		color = color,
		centro = Vector3.new(x, 1.5, centroZ),
		piso = piso,
		barrera = barrera,
		cartel = etiquetaDueno,
		slots = slots,
		placaCobro = placaCobro,
		textoCobro = textoCobro,
		placaCandado = placaCandado,
		textoCandado = textoCandado,
		carpeta = carpeta,
		dueno = nil,
		bloqueadaHasta = 0,
	}
end

function Mapa.construir(): MapaConstruido
	for _, nombre in { "Baseplate", "SpawnLocation" } do
		local viejo = workspace:FindFirstChild(nombre)
		if viejo then
			viejo:Destroy()
		end
	end
	iluminacion()

	local carpeta = Instance.new("Folder")
	carpeta.Name = "Mapa"
	carpeta.Parent = workspace

	parte(carpeta, {
		Name = "Suelo",
		Size = Vector3.new(320, 1, 220),
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(38, 32, 62),
		Material = Enum.Material.Slate,
	})
	-- Rejilla de neón decorativa en la plaza
	for i = -6, 6 do
		parte(carpeta, {
			Name = "Rejilla",
			Size = Vector3.new(0.3, 0.1, 50),
			Position = Vector3.new(i * 22, 0.55, 0),
			Color = Color3.fromRGB(110, 70, 200),
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
	-- Muros invisibles para no caerse del mapa
	for _, datos in {
		{ Vector3.new(161, 25, 0), Vector3.new(2, 60, 222) },
		{ Vector3.new(-161, 25, 0), Vector3.new(2, 60, 222) },
		{ Vector3.new(0, 25, 111), Vector3.new(322, 60, 2) },
		{ Vector3.new(0, 25, -111), Vector3.new(322, 60, 2) },
	} do
		parte(carpeta, { Name = "Limite", Position = datos[1], Size = datos[2], Transparency = 1, CanQuery = false })
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(-140, 0.6, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = carpeta

	-- Cinta transportadora
	local alturaCinta = Config.CINTA.ALTURA
	parte(carpeta, {
		Name = "Cinta",
		Size = Vector3.new(196, 1, 10),
		Position = Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(22, 22, 32),
		Material = Enum.Material.DiamondPlate,
	})
	for _, z in { -5.5, 5.5 } do
		parte(carpeta, {
			Name = "BordeCinta",
			Size = Vector3.new(196, 0.8, 1),
			Position = Vector3.new(0, 1.4, z),
			Color = Color3.fromRGB(0, 255, 200),
			Material = Enum.Material.Neon,
		})
	end
	for i = -9, 9 do
		parte(carpeta, {
			Name = "Flecha",
			Size = Vector3.new(1.5, 0.1, 4),
			CFrame = CFrame.new(i * 10, 1.52, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(0, 180, 150),
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
	-- Portales de entrada y salida de la cinta
	for _, x in { -100, 100 } do
		parte(carpeta, {
			Name = "Portal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 14, 14),
			Position = Vector3.new(x, 7, 0),
			Color = Color3.fromRGB(170, 80, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CanCollide = false,
		})
	end

	local bases: { Base } = {}
	local indice = 0
	for _, lado in { -1, 1 } do
		for _, x in { -78, -26, 26, 78 } do
			indice += 1
			table.insert(bases, crearBase(carpeta, indice, x, lado))
		end
	end

	local puestos = Instance.new("Folder")
	puestos.Name = "Puestos"
	puestos.Parent = carpeta
	local function puesto(nombre: string, posicion: Vector3, color: Color3, texto: string): Part
		local p = parte(puestos, {
			Name = nombre,
			Size = Vector3.new(9, 6, 9),
			Position = posicion,
			Color = color,
			Material = Enum.Material.Neon,
		})
		cartel(p, texto, Color3.new(1, 1, 1), 260, 90, 6, 150)
		return p
	end
	local puestoVelocidad = puesto("Velocidad", Vector3.new(-130, 3.5, 16), Color3.fromRGB(0, 170, 255), "⚡ SPEED")
	local puestoRebirth = puesto("Rebirth", Vector3.new(-130, 3.5, -16), Color3.fromRGB(255, 80, 200), "🌌 REBIRTH")

	local rankings = {
		rebirths = crearRanking(carpeta, "Rebirths", "🌌 TOP REBIRTHS", Vector3.new(135, 10, -15), Color3.fromRGB(255, 80, 200)),
		robos = crearRanking(carpeta, "Robos", "🦹 TOP THIEVES", Vector3.new(135, 10, 15), Color3.fromRGB(255, 200, 40)),
	}

	decoracion(carpeta)

	return {
		carpeta = carpeta,
		bases = bases,
		cintaInicio = Vector3.new(Config.CINTA.X_INICIO, alturaCinta, 0),
		cintaFin = Vector3.new(Config.CINTA.X_FIN, alturaCinta, 0),
		alturaCinta = alturaCinta,
		puestoVelocidad = puestoVelocidad,
		puestoRebirth = puestoRebirth,
		rankings = rankings,
		zonaMeteoritos = { xMin = -120, xMax = 120, zMin = 9, zMax = 26 },
	}
end

function Mapa.dentroDeBase(base: Base, posicion: Vector3): boolean
	local p = base.piso.Position
	return math.abs(posicion.X - p.X) < Mapa.ANCHO_BASE / 2 and math.abs(posicion.Z - p.Z) < Mapa.FONDO_BASE / 2 and posicion.Y < 25
end

return Mapa
