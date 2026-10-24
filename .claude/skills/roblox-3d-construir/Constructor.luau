--!nonstrict
--[[
	Constructor: construir cosas 3D en Roblox con código, rápido y con buen aspecto.
	Ponlo en ServerScriptService o ReplicatedStorage (ModuleScript «Constructor»).

		local C = require(ServerScriptService.Constructor)
		local pueblo = C.modelo("Pueblo", workspace)
		C.casa(pueblo, CFrame.new(0, 0, 0), { ancho = 16, fondo = 14, color = C.paleta.crema })
		C.arbol(pueblo, Vector3.new(20, 0, 5), { alto = 14, estilo = "redondo" })
		C.valla(pueblo, Vector3.new(-20, 0, -20), Vector3.new(20, 0, -20))
		C.optimizar(pueblo)

	Reglas que cumple (y que debes cumplir si lo amplías):
	- Todo Anchored (nada se cae ni consume física) y sin huecos ni piezas que se solapen en la misma cara
	  (parpadeo / z-fighting): las piezas pegadas se separan 0,01 o se meten una dentro de otra.
	- Cilindros de Roblox van a lo largo del eje X: C.cilindro() ya los gira para ponerlos de pie.
	- Decoración pequeña: CanCollide/CanTouch/CanQuery = false y sin sombra (rendimiento).
	- Funciona también en Lune (para dibujarlo con el plugin roblox-3d-vista): solo usa Instance.new,
	  CFrame, Vector3, Color3 y Enum.
	- Origen de cada receta: el CENTRO DEL SUELO del objeto (y = altura del suelo).
]]

local C = {}

-- Paleta «cartoon» que queda bien junta. Usa estas en vez de colores sueltos.
C.paleta = {
	cesped = Color3.fromRGB(106, 190, 84),
	cespedOscuro = Color3.fromRGB(78, 150, 64),
	tierra = Color3.fromRGB(150, 105, 70),
	arena = Color3.fromRGB(236, 214, 160),
	piedra = Color3.fromRGB(140, 145, 155),
	piedraOscura = Color3.fromRGB(95, 100, 110),
	madera = Color3.fromRGB(160, 110, 70),
	maderaOscura = Color3.fromRGB(110, 72, 45),
	crema = Color3.fromRGB(245, 232, 205),
	tejado = Color3.fromRGB(200, 80, 70),
	tejadoAzul = Color3.fromRGB(70, 110, 190),
	hoja = Color3.fromRGB(90, 175, 80),
	hojaClara = Color3.fromRGB(140, 210, 90),
	rosa = Color3.fromRGB(255, 150, 190),
	cielo = Color3.fromRGB(120, 200, 255),
	oro = Color3.fromRGB(255, 200, 60),
	blanco = Color3.fromRGB(245, 245, 245),
	negro = Color3.fromRGB(30, 30, 35),
	agua = Color3.fromRGB(70, 160, 230),
	cristal = Color3.fromRGB(170, 230, 255),
}

local function aplicar(inst: Instance, props: { [string]: any }?)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
end

-- Modelo vacío (carpeta 3D). Pon un Name claro: luego lo buscas por nombre.
function C.modelo(nombre: string, padre: Instance?): Model
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = padre
	return m
end

--[[ Pieza base. Todas las demás funciones la usan.
	props: cualquier propiedad de Part (Size, CFrame, Color, Material, Transparency, Shape, Name…) ]]
function C.pieza(padre: Instance, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Color = C.paleta.blanco
	aplicar(p, props)
	p.Parent = padre
	return p
end

-- Bloque apoyado en el suelo: base = centro de la cara de ABAJO
function C.bloque(padre: Instance, base: Vector3, tam: Vector3, color: Color3?, material: Enum.Material?, giroY: number?): Part
	return C.pieza(padre, {
		Name = "Bloque",
		Size = tam,
		CFrame = CFrame.new(base + Vector3.new(0, tam.Y / 2, 0)) * CFrame.Angles(0, math.rad(giroY or 0), 0),
		Color = color or C.paleta.blanco,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- Cilindro DE PIE apoyado en el suelo (base = centro de abajo)
function C.cilindro(padre: Instance, base: Vector3, alto: number, diametro: number, color: Color3?, material: Enum.Material?): Part
	return C.pieza(padre, {
		Name = "Cilindro",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(alto, diametro, diametro),
		CFrame = CFrame.new(base + Vector3.new(0, alto / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color or C.paleta.blanco,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- Esfera (o elipsoide estirando con escala: usa un MeshPart/SpecialMesh si la necesitas ovalada)
function C.esfera(padre: Instance, centro: Vector3, diametro: number, color: Color3?, material: Enum.Material?): Part
	return C.pieza(padre, {
		Name = "Esfera",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diametro, diametro, diametro),
		CFrame = CFrame.new(centro),
		Color = color or C.paleta.blanco,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- Cuña (rampa / tejado). cf = centro; lo alto queda en +Z local y la pendiente baja hacia -Z local
function C.cuna(padre: Instance, cf: CFrame, tam: Vector3, color: Color3?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = tam
	w.CFrame = cf
	w.Color = color or C.paleta.blanco
	w.Material = Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = padre
	return w
end

-- Viga entre dos puntos (cuerdas, barandillas, rayos, troncos inclinados)
function C.viga(padre: Instance, a: Vector3, b: Vector3, grosor: number, color: Color3?, material: Enum.Material?): Part
	local largo = (b - a).Magnitude
	return C.pieza(padre, {
		Name = "Viga",
		Size = Vector3.new(grosor, grosor, largo),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = color or C.paleta.madera,
		Material = material or Enum.Material.Wood,
	})
end

-- Etiqueta encima de algo (precio de una zona, nombre de un huevo). Se ve siempre de frente.
function C.cartel(adornar: BasePart, texto: string, alto: number?, color: Color3?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Cartel"
	bb.Size = UDim2.fromScale(8, 2)
	bb.StudsOffset = Vector3.new(0, (alto or 3) + adornar.Size.Y / 2, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.Adornee = adornar
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = texto
	l.TextScaled = true
	l.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Parent = bb
	bb.Parent = adornar
	return bb
end

--------------------------------------------------------------------------------------------------
-- RECETAS (origen = centro del suelo). Cada una devuelve un Model.
--------------------------------------------------------------------------------------------------

--[[ Casa con paredes, puerta, ventanas y tejado a dos aguas.
	op: ancho (X), fondo (Z), alto, color, colorTejado, colorPuerta ]]
function C.casa(padre: Instance, origen: CFrame, op: { [string]: any }?): Model
	local o = op or {}
	local ancho, fondo, alto = o.ancho or 16, o.fondo or 14, o.alto or 10
	local m = C.modelo(o.nombre or "Casa", padre)
	local function en(x: number, y: number, z: number): CFrame
		return origen * CFrame.new(x, y, z)
	end
	-- Suelo y paredes (huecas no: un bloque macizo es más barato y no se ve por dentro)
	C.pieza(m, { Name = "Cimientos", Size = Vector3.new(ancho + 2, 1, fondo + 2), CFrame = en(0, 0.5, 0), Color = C.paleta.piedra, Material = Enum.Material.Slate })
	C.pieza(m, { Name = "Paredes", Size = Vector3.new(ancho, alto, fondo), CFrame = en(0, 1 + alto / 2, 0), Color = o.color or C.paleta.crema, Material = Enum.Material.SmoothPlastic })
	-- Esquinas de madera (0,1 más altas que la pared: si coinciden las caras de arriba, parpadean)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			C.pieza(m, { Name = "Esquina", Size = Vector3.new(1.2, alto + 0.1, 1.2), CFrame = en(sx * ancho / 2, 1 + (alto + 0.1) / 2, sz * fondo / 2), Color = C.paleta.maderaOscura, Material = Enum.Material.Wood })
		end
	end
	-- Puerta (sobresale 0,1 de la pared: evita parpadeo)
	local frente = -fondo / 2 - 0.1
	C.pieza(m, { Name = "Puerta", Size = Vector3.new(4, 7, 0.4), CFrame = en(0, 1 + 3.5, frente), Color = o.colorPuerta or C.paleta.madera, Material = Enum.Material.Wood })
	C.esfera(m, (en(1.3, 4.5, frente - 0.3)).Position, 0.5, C.paleta.oro, Enum.Material.Metal)
	-- Ventanas
	for _, x in { -ancho / 4 - 1, ancho / 4 + 1 } do
		C.pieza(m, { Name = "Ventana", Size = Vector3.new(3.4, 3.4, 0.3), CFrame = en(x, 1 + alto * 0.55, frente), Color = C.paleta.cristal, Material = Enum.Material.Glass, Transparency = 0.2 })
		C.pieza(m, { Name = "Marco", Size = Vector3.new(4, 0.5, 0.5), CFrame = en(x, 1 + alto * 0.55 - 1.9, frente - 0.1), Color = C.paleta.blanco })
	end
	-- Tejado a dos aguas: dos cuñas espalda con espalda + vuelo de 1
	local hT = math.max(4, ancho * 0.35)
	local mitad = ancho / 2 + 1
	local yT = 1 + alto + hT / 2
	C.cuna(m, en(-mitad / 2, yT, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(fondo + 2, hT, mitad), o.colorTejado or C.paleta.tejado)
	C.cuna(m, en(mitad / 2, yT, 0) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(fondo + 2, hT, mitad), o.colorTejado or C.paleta.tejado)
	-- Chimenea
	C.pieza(m, { Name = "Chimenea", Size = Vector3.new(2, hT + 2, 2), CFrame = en(ancho / 4, 1 + alto + (hT + 2) / 2, fondo / 5), Color = C.paleta.piedraOscura, Material = Enum.Material.Brick })
	m.PrimaryPart = m:FindFirstChild("Cimientos") :: BasePart
	return m
end

--[[ Árbol low-poly. op: alto, estilo ("redondo" | "pino" | "palmera"), color ]]
function C.arbol(padre: Instance, base: Vector3, op: { [string]: any }?): Model
	local o = op or {}
	local alto = o.alto or 12
	local estilo = o.estilo or "redondo"
	local m = C.modelo("Arbol", padre)
	local tronco = alto * 0.45
	C.cilindro(m, base, tronco, alto * 0.12, C.paleta.maderaOscura, Enum.Material.Wood)
	if estilo == "pino" then
		local capas = 3
		for i = 0, capas - 1 do
			local d = alto * (0.7 - i * 0.18)
			local h = alto * 0.3
			local y = tronco * 0.7 + i * h * 0.6
			-- Pirámide: cuatro cuñas de pie alrededor del eje
			for g = 0, 3 do
				local cf = CFrame.new(base + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, math.rad(90 * g), 0) * CFrame.new(0, 0, d / 4)
				C.cuna(m, cf * CFrame.Angles(0, math.rad(180), 0), Vector3.new(d, h, d / 2), o.color or C.paleta.cespedOscuro)
			end
		end
	elseif estilo == "palmera" then
		local tope = base + Vector3.new(alto * 0.15, alto * 0.85, 0)
		C.viga(m, base + Vector3.new(0, tronco, 0), tope, alto * 0.1, C.paleta.madera, Enum.Material.Wood)
		for g = 0, 5 do
			local ang = math.rad(60 * g)
			local punta = tope + Vector3.new(math.cos(ang) * alto * 0.4, -alto * 0.12, math.sin(ang) * alto * 0.4)
			local hoja = C.viga(m, tope, punta, 0.4, o.color or C.paleta.hoja, Enum.Material.Grass)
			hoja.Size = Vector3.new(alto * 0.14, 0.4, hoja.Size.Z)
		end
		C.esfera(m, tope - Vector3.new(0, 0.6, 0), alto * 0.1, C.paleta.maderaOscura)
	else
		local copa = alto * 0.55
		local centro = base + Vector3.new(0, tronco + copa * 0.35, 0)
		C.esfera(m, centro, copa, o.color or C.paleta.hoja, Enum.Material.Grass)
		C.esfera(m, centro + Vector3.new(copa * 0.3, copa * 0.15, copa * 0.1), copa * 0.65, C.paleta.hojaClara, Enum.Material.Grass)
		C.esfera(m, centro + Vector3.new(-copa * 0.28, -copa * 0.05, -copa * 0.15), copa * 0.6, o.color or C.paleta.hoja, Enum.Material.Grass)
	end
	return m
end

-- Valla de madera entre dos puntos del suelo (postes cada «separacion» studs)
function C.valla(padre: Instance, a: Vector3, b: Vector3, separacion: number?, alto: number?): Model
	local m = C.modelo("Valla", padre)
	local h = alto or 4
	local sep = separacion or 6
	local n = math.max(1, math.floor((b - a).Magnitude / sep + 0.5))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		C.bloque(m, p, Vector3.new(0.8, h, 0.8), C.paleta.madera, Enum.Material.Wood)
	end
	for _, y in { h * 0.35, h * 0.75 } do
		C.viga(m, a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.45, C.paleta.madera, Enum.Material.Wood)
	end
	return m
end

-- Escalera recta: sube «alto» en «peldanos» escalones hacia la dirección «dir» (Vector3 plano)
function C.escalera(padre: Instance, base: Vector3, dir: Vector3, alto: number, ancho: number?, peldanos: number?, color: Color3?): Model
	local m = C.modelo("Escalera", padre)
	local n = peldanos or math.max(2, math.floor(alto))
	local h = alto / n
	local fondoPeldano = 1.6
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	for i = 1, n do
		local centro = base + d * (fondoPeldano * (i - 0.5))
		local cf = CFrame.lookAt(centro, centro + d)
		C.pieza(m, {
			Name = "Peldano",
			Size = Vector3.new(ancho or 6, h * i, fondoPeldano),
			CFrame = cf + Vector3.new(0, h * i / 2, 0),
			Color = color or C.paleta.piedra,
			Material = Enum.Material.Slate,
		})
	end
	return m
end

-- Camino de losas entre puntos (lista de Vector3 del suelo)
function C.camino(padre: Instance, puntos: { Vector3 }, ancho: number?, color: Color3?): Model
	local m = C.modelo("Camino", padre)
	for i = 1, #puntos - 1 do
		local a, b = puntos[i], puntos[i + 1]
		local largo = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		C.pieza(m, {
			Name = "Tramo",
			Size = Vector3.new(ancho or 8, 0.4, largo + (ancho or 8) * 0.5),
			CFrame = cf + Vector3.new(0, 0.2 + i * 0.002, 0), -- desfase mínimo: sin parpadeo en los cruces
			Color = color or C.paleta.arena,
			Material = Enum.Material.Sand,
		})
	end
	return m
end

-- Farola con luz cálida
function C.farola(padre: Instance, base: Vector3, alto: number?): Model
	local h = alto or 12
	local m = C.modelo("Farola", padre)
	C.cilindro(m, base, h, 0.6, C.paleta.negro, Enum.Material.Metal)
	local lampara = C.pieza(m, {
		Name = "Lampara",
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = CFrame.new(base + Vector3.new(0, h + 0.8, 0)),
		Color = Color3.fromRGB(255, 225, 150),
		Material = Enum.Material.Neon,
	})
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 210, 140)
	luz.Range = 22
	luz.Brightness = 1.5
	luz.Shadows = false
	luz.Parent = lampara
	return m
end

--[[ Puerta de zona (para mundos de simuladores): dos columnas, arco y una pared transparente
	con el precio. La pared se quita cuando el jugador desbloquea la zona (eso lo hace tu servidor:
	busca el modelo por nombre y pon Pared.CanCollide = false / Transparency = 1).
	op: ancho, alto, color, texto ("Zona 2 · 500 💰") ]]
function C.puertaZona(padre: Instance, origen: CFrame, op: { [string]: any }?): Model
	local o = op or {}
	local ancho, alto = o.ancho or 24, o.alto or 18
	local m = C.modelo(o.nombre or "PuertaZona", padre)
	local color = o.color or C.paleta.tejadoAzul
	for _, sx in { -1, 1 } do
		C.pieza(m, { Name = "Columna", Size = Vector3.new(3, alto, 3), CFrame = origen * CFrame.new(sx * (ancho / 2 + 1.5), alto / 2, 0), Color = color, Material = Enum.Material.SmoothPlastic })
		C.esfera(m, (origen * CFrame.new(sx * (ancho / 2 + 1.5), alto + 1.6, 0)).Position, 3.4, C.paleta.oro, Enum.Material.Neon)
	end
	C.pieza(m, { Name = "Arco", Size = Vector3.new(ancho + 6, 2.4, 3.4), CFrame = origen * CFrame.new(0, alto + 0.4, 0), Color = color })
	local pared = C.pieza(m, {
		Name = "Pared",
		Size = Vector3.new(ancho, alto - 0.8, 0.6),
		CFrame = origen * CFrame.new(0, (alto - 0.8) / 2, 0),
		Color = C.paleta.cielo,
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
	})
	C.cartel(pared, o.texto or "🔒", 2, C.paleta.oro)
	return m
end

--[[ Pedestal de huevo / tienda 3D: base escalonada + huevo flotando + cartel.
	El huevo es una esfera estirada (Size distinto en Y) → en Roblox una Part Ball es siempre redonda,
	así que usamos un SpecialMesh Sphere con escala. ]]
function C.pedestalHuevo(padre: Instance, base: Vector3, op: { [string]: any }?): Model
	local o = op or {}
	local m = C.modelo(o.nombre or "Huevo", padre)
	C.cilindro(m, base, 1, 12, C.paleta.piedraOscura, Enum.Material.Slate)
	C.cilindro(m, base + Vector3.new(0, 1, 0), 1, 9, C.paleta.piedra, Enum.Material.Slate)
	local huevo = C.pieza(m, {
		Name = "Huevo",
		Size = Vector3.new(5, 6.5, 5),
		CFrame = CFrame.new(base + Vector3.new(0, 6.5, 0)),
		Color = o.color or C.paleta.rosa,
		Material = Enum.Material.SmoothPlastic,
	})
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = huevo
	C.cartel(huevo, o.texto or "Huevo · 100 💰", 2.5)
	m.PrimaryPart = huevo
	return m
end

-- Plataforma flotante redonda (islas en el cielo, zonas)
function C.isla(padre: Instance, centro: Vector3, radio: number, op: { [string]: any }?): Model
	local o = op or {}
	local m = C.modelo(o.nombre or "Isla", padre)
	C.cilindro(m, centro - Vector3.new(0, 2, 0), 2, radio * 2, o.color or C.paleta.cesped, Enum.Material.Grass)
	C.cilindro(m, centro - Vector3.new(0, 6, 0), 4, radio * 1.8, C.paleta.tierra, Enum.Material.Ground)
	C.cilindro(m, centro - Vector3.new(0, 10, 0), 4, radio * 1.2, C.paleta.piedra, Enum.Material.Rock)
	C.cilindro(m, centro - Vector3.new(0, 13, 0), 3, radio * 0.6, C.paleta.piedraOscura, Enum.Material.Rock)
	return m
end

-- Roca low-poly hecha con 3 bloques girados
function C.roca(padre: Instance, base: Vector3, tam: number?, semilla: number?): Model
	local r = Random.new(semilla or 1)
	local t = tam or 4
	local m = C.modelo("Roca", padre)
	for i = 1, 3 do
		local s = t * (1 - i * 0.18)
		C.pieza(m, {
			Name = "Trozo",
			Size = Vector3.new(s, s * 0.7, s * 0.9),
			CFrame = CFrame.new(base + Vector3.new(r:NextNumber(-0.3, 0.3) * t, s * 0.3, r:NextNumber(-0.3, 0.3) * t))
				* CFrame.Angles(r:NextNumber(-0.4, 0.4), r:NextNumber(0, 6.28), r:NextNumber(-0.4, 0.4)),
			Color = if i == 2 then C.paleta.piedraOscura else C.paleta.piedra,
			Material = Enum.Material.Rock,
		})
	end
	return m
end

--------------------------------------------------------------------------------------------------
-- UTILIDADES
--------------------------------------------------------------------------------------------------

-- Repite una receta en círculo: C.enCirculo(12, 40, function(pos, ang) C.arbol(m, pos) end)
function C.enCirculo(n: number, radio: number, centro: Vector3, f: (Vector3, number) -> ())
	for i = 0, n - 1 do
		local ang = (i / n) * math.pi * 2
		f(centro + Vector3.new(math.cos(ang) * radio, 0, math.sin(ang) * radio), ang)
	end
end

-- Repite en rejilla: C.enRejilla(4, 3, 20, origen, function(pos, i, j) ... end)
function C.enRejilla(columnas: number, filas: number, separacion: number, origen: Vector3, f: (Vector3, number, number) -> ())
	for i = 0, columnas - 1 do
		for j = 0, filas - 1 do
			f(origen + Vector3.new(i * separacion, 0, j * separacion), i, j)
		end
	end
end

--[[ Optimiza un modelo terminado:
	- piezas pequeñas (< umbral studs de diagonal): sin colisión, sin toque, sin consultas, sin sombra
	- todo anclado
	Devuelve cuántas piezas tiene (para vigilar el presupuesto: < 5.000 por mapa en móvil va bien). ]]
function C.optimizar(modelo: Instance, umbral: number?): number
	local n = 0
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			d.Anchored = true
			if d.Size.Magnitude < (umbral or 3) then
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.CastShadow = false
			end
		end
	end
	return n
end

-- Cambia el color de todas las piezas que tengan un color concreto (temas, estaciones)
function C.recolorear(modelo: Instance, de: Color3, a: Color3)
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and (d.Color.R - de.R) ^ 2 + (d.Color.G - de.G) ^ 2 + (d.Color.B - de.B) ^ 2 < 0.001 then
			d.Color = a
		end
	end
end

return C
