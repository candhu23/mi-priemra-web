--[[
	CityLayout (ModuleScript en ReplicatedStorage)

	Medidas de Ciudad Web que necesitan a la vez el servidor (World, que
	construye la ciudad) y el cliente (Traffic, que mueve los coches).

	Plano (visto desde arriba, X = avenida, Z = a los lados):
	  · glorieta con la plaza en el centro (0, 0, 0)
	  · avenida de -AVENUE_HALF a +AVENUE_HALF, con una rotonda pequeña en
	    cada punta para que los coches den la vuelta
	  · 8 parcelas de PLOT_SIZE: 2 a cada lado de la plaza, a los dos lados
	    de la avenida
	  · la Bolsa al sur de la plaza (z < 0) y los paneles de clasificación
	    al norte (z > 0)
]]

local City = {}

City.PLOT_SIZE = 96
City.PLOT_X = { -246, -130, 130, 246 } -- centro de cada columna de parcelas
City.STREET_WIDTH = 28
City.SIDEWALK = 8
City.AVENUE_HALF = 330 -- la avenida llega de -330 a 330
City.TURN_RADIUS = 18 -- rotondas de las puntas
City.RING_INNER = 40 -- radio de la plaza (isla de la glorieta)
City.RING_OUTER = 56 -- radio exterior de la calzada de la glorieta
City.RING_SIDEWALK = 8
City.LANE = 7 -- distancia del centro de la avenida al centro de cada carril
City.BOLSA_Z = -100
City.BOARDS_Z = 96
City.CROSSWALK_X = { -188, -72, 72, 188 } -- pasos de cebra de la avenida

-- Centro de cada parcela: z = calle + acera + media parcela
function City.plotZ(): number
	return City.STREET_WIDTH / 2 + City.SIDEWALK + City.PLOT_SIZE / 2
end

-- Recorrido cerrado de los coches (conducción por la derecha):
-- hacia +X por el carril z = +LANE, media vuelta a la glorieta por el
-- norte, vuelta en la rotonda del este, hacia -X por z = -LANE, media
-- vuelta a la glorieta por el sur y vuelta en la rotonda del oeste.
function City.trafficPath(): { Vector3 }
	local points: { Vector3 } = {}
	local y = 0.3
	local lane = City.LANE
	local ringR = (City.RING_INNER + City.RING_OUTER) / 2
	local entryX = math.sqrt(ringR * ringR - lane * lane)
	local endX = City.AVENUE_HALF - City.TURN_RADIUS
	local function arc(cx: number, cz: number, r: number, fromDeg: number, toDeg: number)
		local steps = math.max(4, math.ceil(math.abs(toDeg - fromDeg) / 6))
		for i = 1, steps do
			local a = math.rad(fromDeg + (toDeg - fromDeg) * i / steps)
			table.insert(points, Vector3.new(cx + math.cos(a) * r, y, cz + math.sin(a) * r))
		end
	end
	local entryDeg = math.deg(math.atan2(lane, entryX))
	-- Oeste → glorieta (carril z = +lane)
	table.insert(points, Vector3.new(-endX, y, lane))
	table.insert(points, Vector3.new(-entryX, y, lane))
	arc(0, 0, ringR, 180 - entryDeg, entryDeg) -- por el norte (z > 0)
	table.insert(points, Vector3.new(endX, y, lane))
	arc(endX, 0, lane, 90, -90) -- media vuelta en la punta este
	table.insert(points, Vector3.new(entryX, y, -lane))
	arc(0, 0, ringR, -entryDeg, -180 + entryDeg) -- por el sur (z < 0)
	table.insert(points, Vector3.new(-endX, y, -lane))
	arc(-endX, 0, lane, 270, 90) -- media vuelta en la punta oeste
	return points
end

return City
