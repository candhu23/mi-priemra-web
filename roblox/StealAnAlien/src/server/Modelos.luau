--!strict
--[[
	Construye los modelos 3D de los aliens con piezas básicas, sin importar mallas.
	Todas las piezas van soldadas a "Cuerpo" (la única anclada), así que basta con
	mover el Cuerpo para mover todo el alien.

	Para usar modelos hechos por un artista: crea una carpeta ReplicatedStorage/ModelosAlien
	con un Model por alien llamado igual que su id (por ejemplo "blorp"). Si existe,
	se usa ese modelo en lugar del generado.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Compartido = ReplicatedStorage:WaitForChild("Compartido")
local Config = require(Compartido:WaitForChild("Config"))
local Formato = require(Compartido:WaitForChild("Formato"))

local Modelos = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
Modelos.rgb = rgb

local function nuevaPieza(modelo: Model, nombre: string, forma: Enum.PartType, tamano: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Shape = forma
	p.Size = tamano
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = modelo
	return p
end

-- Coloca una pieza relativa al cuerpo y la suelda.
local function fijar(cuerpo: BasePart, pieza: BasePart, offset: CFrame)
	pieza.CFrame = cuerpo.CFrame * offset
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cuerpo
	soldadura.Part1 = pieza
	soldadura.Parent = pieza
end

local function crearCartel(cuerpo: BasePart, alto: number): TextLabel
	local cartel = Instance.new("BillboardGui")
	cartel.Name = "Cartel"
	cartel.Size = UDim2.fromOffset(200, 64)
	cartel.StudsOffset = Vector3.new(0, alto, 0)
	cartel.MaxDistance = 55
	cartel.LightInfluence = 0
	cartel.Parent = cuerpo

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = "Texto"
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.TextScaled = true
	etiqueta.RichText = true
	etiqueta.Font = Enum.Font.FredokaOne
	etiqueta.TextColor3 = Color3.new(1, 1, 1)
	etiqueta.TextStrokeTransparency = 0
	etiqueta.Parent = cartel
	return etiqueta
end

local function colorHex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- Texto del cartel: nombre (color de rareza), rareza e ingresos. precio opcional (cinta).
function Modelos.textoCartel(alien: Config.Alien, shiny: boolean, precio: number?): string
	local rareza = Config.RAREZAS[alien.rareza]
	local hex = colorHex(rgb(rareza.color))
	local nombre = (if shiny then "✨ Shiny " else "") .. alien.nombre
	local lineas = {
		string.format('<font color="%s">%s</font>', hex, nombre),
		string.format('<font color="%s">%s</font> · $%s/s', hex, rareza.nombre, Formato.abreviar(Config.ingresoAlien(alien, shiny))),
	}
	if precio then
		table.insert(lineas, string.format('<font color="#7CFF96">$%s</font>', Formato.abreviar(precio)))
	end
	return table.concat(lineas, "\n")
end

local function construir(alien: Config.Alien, shiny: boolean): Model
	local rareza = Config.RAREZAS[alien.rareza]
	local colorRareza = rgb(rareza.color)
	local color = rgb(alien.color)
	if shiny then
		color = color:Lerp(Color3.new(1, 1, 1), 0.35)
	end
	local s = alien.tamano
	local estilo = alien.estilo
	local modelo = Instance.new("Model")

	-- Cuerpo
	local cuerpo: Part
	local altoCuerpo = s
	if estilo.cuerpo == "capsula" then
		altoCuerpo = s * 1.3
		cuerpo = nuevaPieza(modelo, "Cuerpo", Enum.PartType.Block, Vector3.new(s, altoCuerpo, s), color)
		local malla = Instance.new("SpecialMesh")
		malla.MeshType = Enum.MeshType.Sphere
		malla.Parent = cuerpo
	elseif estilo.cuerpo == "cubo" then
		cuerpo = nuevaPieza(modelo, "Cuerpo", Enum.PartType.Block, Vector3.new(s, s * 0.9, s), color)
		altoCuerpo = s * 0.9
	else
		cuerpo = nuevaPieza(modelo, "Cuerpo", Enum.PartType.Ball, Vector3.new(s, s, s), color)
	end
	cuerpo.Anchored = true
	cuerpo.Massless = false
	if alien.rareza >= 5 or shiny then
		cuerpo.Material = Enum.Material.Neon
	elseif alien.rareza >= 3 then
		cuerpo.Material = Enum.Material.Glass
		cuerpo.Reflectance = 0.15
	end
	modelo.PrimaryPart = cuerpo

	local frente = -s * 0.5 -- los modelos miran hacia -Z
	local arriba = altoCuerpo * 0.5

	-- Ojos
	local tamOjo = s * (if estilo.ojos == 1 then 0.42 else 0.3)
	for i = 1, estilo.ojos do
		local x = (i - (estilo.ojos + 1) / 2) * s * 0.3
		local y = altoCuerpo * 0.12
		local ojo = nuevaPieza(modelo, "Ojo", Enum.PartType.Ball, Vector3.one * tamOjo, Color3.new(1, 1, 1))
		fijar(cuerpo, ojo, CFrame.new(x, y, frente * 0.82))
		local pupila = nuevaPieza(modelo, "Pupila", Enum.PartType.Ball, Vector3.one * tamOjo * 0.5, Color3.fromRGB(15, 10, 25))
		fijar(cuerpo, pupila, CFrame.new(x, y, frente * 0.82 - tamOjo * 0.35))
		local brillo = nuevaPieza(modelo, "Brillo", Enum.PartType.Ball, Vector3.one * tamOjo * 0.18, Color3.new(1, 1, 1), Enum.Material.Neon)
		fijar(cuerpo, brillo, CFrame.new(x + tamOjo * 0.12, y + tamOjo * 0.12, frente * 0.82 - tamOjo * 0.55))
	end

	-- Boca sonriente (tres piezas en arco)
	for i = -1, 1 do
		local boca = nuevaPieza(modelo, "Boca", Enum.PartType.Block, Vector3.new(s * 0.12, s * 0.05, s * 0.05), Color3.fromRGB(40, 15, 40))
		fijar(cuerpo, boca, CFrame.new(i * s * 0.1, -altoCuerpo * 0.18 + math.abs(i) * s * 0.04, frente * 0.92) * CFrame.Angles(0, 0, -i * 0.5))
	end

	-- Accesorios
	for _, extra in estilo.extras do
		if extra == "antenas" then
			for _, lado in { -1, 1 } do
				local palo = nuevaPieza(modelo, "Antena", Enum.PartType.Cylinder, Vector3.new(s * 0.6, s * 0.07, s * 0.07), color)
				fijar(cuerpo, palo, CFrame.new(lado * s * 0.2, arriba + s * 0.22, 0) * CFrame.Angles(0, 0, math.pi / 2 + lado * 0.35))
				local bola = nuevaPieza(modelo, "Bolita", Enum.PartType.Ball, Vector3.one * s * 0.2, colorRareza, Enum.Material.Neon)
				fijar(cuerpo, bola, CFrame.new(lado * s * 0.32, arriba + s * 0.52, 0))
			end
		elseif extra == "orejas" then
			for _, lado in { -1, 1 } do
				local oreja = nuevaPieza(modelo, "Oreja", Enum.PartType.Block, Vector3.new(s * 0.3, s * 0.4, s * 0.12), color)
				local malla = Instance.new("SpecialMesh")
				malla.MeshType = Enum.MeshType.Sphere
				malla.Parent = oreja
				fijar(cuerpo, oreja, CFrame.new(lado * s * 0.3, arriba + s * 0.05, 0) * CFrame.Angles(0, 0, -lado * 0.4))
			end
		elseif extra == "cuernos" then
			for _, lado in { -1, 1 } do
				local cuerno = nuevaPieza(modelo, "Cuerno", Enum.PartType.Cylinder, Vector3.new(s * 0.45, s * 0.1, s * 0.1), Color3.fromRGB(255, 245, 220))
				fijar(cuerpo, cuerno, CFrame.new(lado * s * 0.32, arriba + s * 0.05, -s * 0.05) * CFrame.Angles(0, 0, math.pi / 2 - lado * 0.6))
			end
		elseif extra == "tentaculos" then
			for i = 0, 3 do
				local angulo = i * math.pi / 2 + math.pi / 4
				local tentaculo = nuevaPieza(modelo, "Tentaculo", Enum.PartType.Cylinder, Vector3.new(s * 0.55, s * 0.13, s * 0.13), color:Lerp(Color3.new(0, 0, 0), 0.15))
				fijar(cuerpo, tentaculo, CFrame.new(math.cos(angulo) * s * 0.28, -arriba - s * 0.05, math.sin(angulo) * s * 0.28) * CFrame.Angles(0, -angulo, math.pi / 2 + 0.4))
			end
		elseif extra == "alas" then
			for _, lado in { -1, 1 } do
				local ala = nuevaPieza(modelo, "Ala", Enum.PartType.Block, Vector3.new(s * 0.9, s * 0.6, s * 0.06), colorRareza, Enum.Material.ForceField)
				fijar(cuerpo, ala, CFrame.new(lado * s * 0.7, s * 0.15, s * 0.2) * CFrame.Angles(0, lado * 0.5, lado * 0.3))
			end
		elseif extra == "corona" then
			local aro = nuevaPieza(modelo, "Corona", Enum.PartType.Cylinder, Vector3.new(s * 0.12, s * 0.5, s * 0.5), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
			fijar(cuerpo, aro, CFrame.new(0, arriba + s * 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2))
			for i = 0, 4 do
				local angulo = i * math.pi * 2 / 5
				local punta = nuevaPieza(modelo, "Punta", Enum.PartType.Block, Vector3.new(s * 0.08, s * 0.2, s * 0.08), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
				fijar(cuerpo, punta, CFrame.new(math.cos(angulo) * s * 0.22, arriba + s * 0.15, math.sin(angulo) * s * 0.22))
			end
		elseif extra == "aleta" then
			local aleta = nuevaPieza(modelo, "Aleta", Enum.PartType.Block, Vector3.new(s * 0.08, s * 0.5, s * 0.6), color:Lerp(colorRareza, 0.5))
			fijar(cuerpo, aleta, CFrame.new(0, arriba * 0.6, s * 0.35) * CFrame.Angles(-0.5, 0, 0))
		elseif extra == "pinzas" then
			for _, lado in { -1, 1 } do
				local pinza = nuevaPieza(modelo, "Pinza", Enum.PartType.Ball, Vector3.one * s * 0.32, color:Lerp(Color3.new(1, 0.3, 0.3), 0.3))
				fijar(cuerpo, pinza, CFrame.new(lado * s * 0.62, -s * 0.05, frente * 0.5))
			end
		elseif extra == "halo" then
			for i = 0, 9 do
				local angulo = i * math.pi * 2 / 10
				local luz = nuevaPieza(modelo, "Halo", Enum.PartType.Ball, Vector3.one * s * 0.1, colorRareza, Enum.Material.Neon)
				fijar(cuerpo, luz, CFrame.new(math.cos(angulo) * s * 0.4, arriba + s * 0.45, math.sin(angulo) * s * 0.4))
			end
		end
	end

	-- Efectos según rareza
	if alien.rareza >= 4 or shiny then
		local luz = Instance.new("PointLight")
		luz.Color = colorRareza
		luz.Range = 10 + alien.rareza
		luz.Brightness = 1.5
		luz.Parent = cuerpo
	end
	if alien.rareza >= 5 then
		local particulas = Instance.new("ParticleEmitter")
		particulas.Color = ColorSequence.new(colorRareza)
		particulas.LightEmission = 1
		particulas.Size = NumberSequence.new(0.3, 0)
		particulas.Lifetime = NumberRange.new(0.8, 1.4)
		particulas.Rate = 12
		particulas.Speed = NumberRange.new(1.5, 3)
		particulas.SpreadAngle = Vector2.new(180, 180)
		particulas.Parent = cuerpo
	end
	if shiny then
		local destellos = Instance.new("Sparkles")
		destellos.SparkleColor = Color3.new(1, 1, 0.8)
		destellos.Parent = cuerpo
	end

	return modelo
end

-- Crea el alien. Si existe un modelo personalizado en ReplicatedStorage/ModelosAlien, lo usa.
function Modelos.crear(alien: Config.Alien, shiny: boolean, precio: number?): Model
	local modelo: Model
	local personalizados = ReplicatedStorage:FindFirstChild("ModelosAlien")
	local plantilla = personalizados and personalizados:FindFirstChild(alien.id)
	if plantilla and plantilla:IsA("Model") and plantilla.PrimaryPart then
		modelo = plantilla:Clone()
		local raiz = modelo.PrimaryPart :: BasePart
		raiz.Name = "Cuerpo"
		for _, p in modelo:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
				p.Anchored = p == raiz
				if p ~= raiz then
					p.Massless = true
					local soldadura = Instance.new("WeldConstraint")
					soldadura.Part0 = raiz
					soldadura.Part1 = p
					soldadura.Parent = p
				end
			end
		end
	else
		modelo = construir(alien, shiny)
	end
	modelo.Name = alien.nombre
	modelo:SetAttribute("AlienId", alien.id)
	modelo:SetAttribute("Shiny", shiny)
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local raiz = modelo.PrimaryPart :: BasePart
	local _, tamano = modelo:GetBoundingBox()
	local etiqueta = crearCartel(raiz, tamano.Y * 0.5 + 2.2)
	etiqueta.Text = Modelos.textoCartel(alien, shiny, precio)
	return modelo
end

-- Para llevarlo encima de la cabeza: nada anclado.
function Modelos.prepararParaLlevar(modelo: Model)
	local raiz = modelo.PrimaryPart :: BasePart
	raiz.Anchored = false
	raiz.Massless = true
	local cartel = raiz:FindFirstChild("Cartel")
	if cartel then
		cartel:Destroy()
	end
	for _, p in modelo:GetDescendants() do
		if p:IsA("ProximityPrompt") then
			p:Destroy()
		end
	end
end

return Modelos
