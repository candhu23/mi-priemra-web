--!nonstrict
--[[
	Terreno: generar mundos con el Terrain de Roblox por código (islas, colinas, agua, caminos,
	zonas planas para construir) y repartir decoración de forma natural.
	Ponlo en ServerScriptService (ModuleScript «Terreno») y llámalo UNA vez al arrancar el servidor
	(o úsalo desde la barra de comandos de Studio y guarda el lugar: así no se genera en cada partida).

		local T = require(ServerScriptService.Terreno)
		T.limpiar()
		local mapa = T.isla({ centro = Vector3.zero, radio = 300, alto = 40, semilla = 7, nivelAgua = 2 })
		T.aplanar(Vector3.new(0, 10, 0), 60, Enum.Material.Grass)        -- plaza para el spawn
		T.camino({ Vector3.new(0, 10, 0), Vector3.new(120, 12, 40) }, 10)
		for _, p in T.esparcir(Vector3.zero, 280, 18, 7) do                 -- puntos para árboles
			local suelo = T.alturaEn(mapa, p)
			if suelo and suelo > 4 then  ... pon un árbol en Vector3.new(p.X, suelo, p.Z) ... end
		end

	Rendimiento: cada «columna» es una llamada a FillBlock. radio 300 con resolucion 8 ≈ 4.400 columnas
	(1–3 s). No bajes de resolucion 4 en mapas grandes. Para móvil, mapas de hasta ~1.000×1.000 studs.
]]

local Workspace = game:GetService("Workspace")

local T = {}

local function terreno(): Terrain
	return Workspace.Terrain
end

-- Borra todo el terreno
function T.limpiar()
	terreno():Clear()
end

-- Ruido 2D en capas (fBm): valores aprox. entre -1 y 1. octavas: detalle; escala: tamaño de las colinas
function T.ruido(x: number, z: number, semilla: number, escala: number, octavas: number?): number
	local total, amplitud, frecuencia, suma = 0, 1, 1 / escala, 0
	for _ = 1, octavas or 4 do
		total += math.noise(x * frecuencia, z * frecuencia, semilla) * amplitud
		suma += amplitud
		amplitud *= 0.5
		frecuencia *= 2
	end
	return total / suma * 1.6
end

export type Mapa = { alturas: { [number]: { [number]: number } }, resolucion: number, origen: Vector3 }

--[[ Isla redonda con colinas, playa y agua alrededor.
	op: centro (Vector3), radio, alto (altura máx. de colinas), semilla, nivelAgua (y), resolucion (studs por columna),
	    escala (tamaño de las colinas, por defecto radio/3), materiales = { playa, cesped, roca, nieve }
	Devuelve un Mapa para consultar alturas (T.alturaEn). ]]
function T.isla(op: { [string]: any }): Mapa
	local centro: Vector3 = op.centro or Vector3.zero
	local radio = op.radio or 250
	local alto = op.alto or 30
	local semilla = op.semilla or 1
	local agua = op.nivelAgua or 0
	local res = op.resolucion or 8
	local escala = op.escala or radio / 3
	local mat = op.materiales or {}
	local playa = mat.playa or Enum.Material.Sand
	local cesped = mat.cesped or Enum.Material.Grass
	local roca = mat.roca or Enum.Material.Rock
	local nieve = mat.nieve or Enum.Material.Snow
	local fondo = centro.Y - 20
	local t = terreno()
	local alturas = {}
	local borde = radio + 40
	local minimo = fondo
	for x = -borde, borde, res do
		alturas[x] = {}
		for z = -borde, borde, res do
			local d = math.sqrt(x * x + z * z) / radio -- 0 en el centro, 1 en la costa
			local forma = 1 - d * d -- cúpula
			local h = agua + (forma * 0.6 + T.ruido(x, z, semilla, escala) * 0.4 * math.max(forma, 0)) * alto
			if d > 1 then
				h = agua - 4 - (d - 1) * 30 -- fondo marino que baja
			end
			alturas[x][z] = h
			minimo = math.min(minimo, h)
			local material
			if h < agua + 1.5 then
				material = playa
			elseif h > agua + alto * 0.8 then
				material = nieve
			elseif h > agua + alto * 0.55 then
				material = roca
			else
				material = cesped
			end
			local base = math.min(fondo, h - 10)
			local altura = h - base
			t:FillBlock(CFrame.new(centro.X + x, base + altura / 2, centro.Z + z), Vector3.new(res, altura, res), material)
		end
	end
	-- Agua: rellena de agua solo el aire que queda por debajo del nivel (no machaca la tierra)
	T.agua(centro, borde, minimo - 2, agua)
	return { alturas = alturas, resolucion = res, origen = centro }
end

--[[ Colinas sin mar (un mapa rectangular). op: centro, ancho, largo, alto, semilla, resolucion, escala, material ]]
function T.colinas(op: { [string]: any }): Mapa
	local centro: Vector3 = op.centro or Vector3.zero
	local ancho, largo = op.ancho or 400, op.largo or 400
	local alto = op.alto or 20
	local res = op.resolucion or 8
	local semilla = op.semilla or 1
	local escala = op.escala or 120
	local t = terreno()
	local alturas = {}
	for x = -ancho / 2, ancho / 2, res do
		alturas[x] = {}
		for z = -largo / 2, largo / 2, res do
			local h = centro.Y + (T.ruido(x, z, semilla, escala) * 0.5 + 0.5) * alto
			alturas[x][z] = h
			local base = centro.Y - 16
			t:FillBlock(CFrame.new(centro.X + x, (base + h) / 2, centro.Z + z), Vector3.new(res, h - base, res), op.material or Enum.Material.Grass)
		end
	end
	return { alturas = alturas, resolucion = res, origen = centro }
end

-- Rellena de agua un cuadrado (centro, mitad del lado) desde «fondo» hasta «nivel», solo donde hay aire
function T.agua(centro: Vector3, mitad: number, fondo: number, nivel: number)
	local t = terreno()
	local region = Region3.new(
		Vector3.new(centro.X - mitad, fondo, centro.Z - mitad),
		Vector3.new(centro.X + mitad, nivel, centro.Z + mitad)
	):ExpandToGrid(4)
	t:ReplaceMaterial(region, 4, Enum.Material.Air, Enum.Material.Water)
end

-- Altura del suelo en un punto del mundo según el Mapa (nil si cae fuera)
function T.alturaEn(mapa: Mapa, p: Vector3): number?
	local res = mapa.resolucion
	local x = math.floor((p.X - mapa.origen.X) / res + 0.5) * res
	local z = math.floor((p.Z - mapa.origen.Z) / res + 0.5) * res
	local fila = mapa.alturas[x]
	return fila and fila[z]
end

-- Altura REAL del suelo con un rayo (sirve también para terreno hecho a mano)
function T.sueloEn(x: number, z: number, desde: number?): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terreno() }
	local r = Workspace:Raycast(Vector3.new(x, desde or 500, z), Vector3.new(0, -1000, 0), params)
	if r and r.Material ~= Enum.Material.Water then
		return r.Position
	end
	return nil
end

-- Zona plana circular (spawn, plaza, parcela). Quita lo que sobra encima y rellena por debajo.
function T.aplanar(centro: Vector3, radio: number, material: Enum.Material?, profundidad: number?)
	local t = terreno()
	local prof = profundidad or 30
	-- Quita lo de encima (cilindro de aire)
	t:FillCylinder(CFrame.new(centro + Vector3.new(0, 30, 0)), 60, radio + 4, Enum.Material.Air)
	-- Rellena por debajo
	t:FillCylinder(CFrame.new(centro - Vector3.new(0, prof / 2, 0)), prof, radio, material or Enum.Material.Grass)
end

-- Camino por una lista de puntos (en el suelo). Mete el material un poco en el terreno.
function T.camino(puntos: { Vector3 }, ancho: number?, material: Enum.Material?)
	local t = terreno()
	local a = ancho or 8
	for i = 1, #puntos - 1 do
		local p1, p2 = puntos[i], puntos[i + 1]
		local largo = (p2 - p1).Magnitude
		local pasos = math.max(1, math.floor(largo / (a / 2)))
		for s = 0, pasos do
			local p = p1:Lerp(p2, s / pasos)
			t:FillBlock(CFrame.lookAt(p, p + (p2 - p1)) * CFrame.new(0, -1, 0), Vector3.new(a, 2.5, a), material or Enum.Material.Ground)
		end
	end
end

-- Río o lago: excava y llena de agua a lo largo de los puntos
function T.rio(puntos: { Vector3 }, ancho: number?, hondo: number?)
	local t = terreno()
	local a = ancho or 16
	local h = hondo or 6
	for i = 1, #puntos - 1 do
		local p1, p2 = puntos[i], puntos[i + 1]
		local pasos = math.max(1, math.floor((p2 - p1).Magnitude / (a / 3)))
		for s = 0, pasos do
			local p = p1:Lerp(p2, s / pasos)
			t:FillBall(p, a / 2 + 2, Enum.Material.Sand)
			t:FillBall(p + Vector3.new(0, 2, 0), a / 2, Enum.Material.Air)
			t:FillBlock(CFrame.new(p - Vector3.new(0, h / 2 - 1, 0)), Vector3.new(a * 0.8, h, a * 0.8), Enum.Material.Water)
		end
	end
end

-- Montaña en un punto (cono de roca con nieve arriba)
function T.montana(base: Vector3, alto: number, radio: number)
	local t = terreno()
	local capas = math.max(4, math.floor(alto / 6))
	for i = 0, capas - 1 do
		local f = i / capas
		local r = radio * (1 - f)
		local y = base.Y + f * alto
		local material = if f > 0.75 then Enum.Material.Snow elseif f > 0.35 then Enum.Material.Rock else Enum.Material.Grass
		t:FillCylinder(CFrame.new(base.X, y + alto / capas / 2, base.Z), alto / capas + 1, r, material)
	end
end

-- Cueva/túnel: una serie de bolas de aire
function T.tunel(puntos: { Vector3 }, radio: number?)
	local t = terreno()
	local r = radio or 8
	for i = 1, #puntos - 1 do
		local p1, p2 = puntos[i], puntos[i + 1]
		local pasos = math.max(1, math.floor((p2 - p1).Magnitude / (r / 2)))
		for s = 0, pasos do
			t:FillBall(p1:Lerp(p2, s / pasos), r, Enum.Material.Air)
		end
	end
end

--[[ Reparto natural de puntos (Poisson disc): ninguno a menos de «distancia» de otro.
	Mucho mejor que math.random para árboles, rocas y monedas (sin grumos ni huecos).
	centro + radio (círculo en el plano XZ). Devuelve una lista de Vector3 con Y = centro.Y. ]]
function T.esparcir(centro: Vector3, radio: number, distancia: number, semilla: number?, intentos: number?): { Vector3 }
	local rng = Random.new(semilla or 1)
	local celda = distancia / math.sqrt(2)
	local rejilla: { [string]: Vector3 } = {}
	local puntos: { Vector3 } = {}
	local activos: { Vector3 } = {}
	local function clave(p: Vector3): string
		return math.floor(p.X / celda) .. "," .. math.floor(p.Z / celda)
	end
	local function valido(p: Vector3): boolean
		if (Vector3.new(p.X, 0, p.Z) - Vector3.new(centro.X, 0, centro.Z)).Magnitude > radio then
			return false
		end
		local cx, cz = math.floor(p.X / celda), math.floor(p.Z / celda)
		for dx = -2, 2 do
			for dz = -2, 2 do
				local q = rejilla[(cx + dx) .. "," .. (cz + dz)]
				if q and (q - p).Magnitude < distancia then
					return false
				end
			end
		end
		return true
	end
	local primero = Vector3.new(centro.X, centro.Y, centro.Z)
	table.insert(puntos, primero)
	table.insert(activos, primero)
	rejilla[clave(primero)] = primero
	while #activos > 0 and #puntos < 5000 do
		local i = rng:NextInteger(1, #activos)
		local base = activos[i]
		local ok = false
		for _ = 1, intentos or 20 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(distancia, distancia * 2)
			local p = base + Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
			if valido(p) then
				table.insert(puntos, p)
				table.insert(activos, p)
				rejilla[clave(p)] = p
				ok = true
				break
			end
		end
		if not ok then
			table.remove(activos, i)
		end
	end
	return puntos
end

--[[ Zonas de un simulador en línea (Zona 1 → Zona 2 → …), cada una una plataforma plana
	de terreno con su material, unidas por un paso. Devuelve los centros para poner puertas/huevos.
	op: inicio (Vector3), numero, radio, separacion, materiales (lista de Enum.Material por zona) ]]
function T.zonasEnLinea(op: { [string]: any }): { Vector3 }
	local inicio: Vector3 = op.inicio or Vector3.zero
	local n = op.numero or 4
	local r = op.radio or 70
	local sep = op.separacion or (r * 2 + 40)
	local mats = op.materiales or { Enum.Material.Grass, Enum.Material.Sand, Enum.Material.Snow, Enum.Material.Basalt, Enum.Material.CrackedLava, Enum.Material.Glacier }
	local centros = {}
	for i = 0, n - 1 do
		local c = inicio + Vector3.new(i * sep, 0, 0)
		T.aplanar(c, r, mats[(i % #mats) + 1], 20)
		if i > 0 then
			-- Paso entre zonas
			T.camino({ c - Vector3.new(sep, 0, 0) + Vector3.new(r - 4, 0, 0), c - Vector3.new(r - 4, 0, 0) }, 22, Enum.Material.Cobblestone)
		end
		table.insert(centros, c)
	end
	return centros
end

-- Colores de los materiales del terreno (para darle tu paleta al mundo entero)
function T.colorMaterial(material: Enum.Material, color: Color3)
	terreno():SetMaterialColor(material, color)
end

-- Paleta «cartoon» de materiales (más saturada que la de serie)
function T.paletaCartoon()
	T.colorMaterial(Enum.Material.Grass, Color3.fromRGB(106, 190, 84))
	T.colorMaterial(Enum.Material.Sand, Color3.fromRGB(240, 220, 160))
	T.colorMaterial(Enum.Material.Rock, Color3.fromRGB(140, 140, 150))
	T.colorMaterial(Enum.Material.Ground, Color3.fromRGB(170, 125, 85))
	T.colorMaterial(Enum.Material.Snow, Color3.fromRGB(245, 250, 255))
	T.colorMaterial(Enum.Material.Cobblestone, Color3.fromRGB(165, 160, 150))
	local t = terreno()
	t.WaterColor = Color3.fromRGB(60, 170, 230)
	t.WaterTransparency = 0.6
	t.WaterReflectance = 0.3
	t.WaterWaveSize = 0.15
	t.WaterWaveSpeed = 8
end

return T
