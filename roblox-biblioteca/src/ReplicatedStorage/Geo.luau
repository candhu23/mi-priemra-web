--!strict
-- Rayos contra cajas alineadas con los ejes (las piezas sólidas de Layout). Se usa en el servidor para
-- soltar y lanzar libros SIN física de Roblox: así es igual en Studio, en el juego y en las pruebas.

local Geo = {}

export type Box = { min: Vector3, max: Vector3, kind: string }

-- Primer choque del segmento a → b con alguna caja. Devuelve (t 0–1, normal, caja) o nil.
function Geo.segment(boxes: { Box }, a: Vector3, b: Vector3): (number?, Vector3?, Box?)
	local d = b - a
	local bestT, bestN, bestBox = math.huge, nil :: Vector3?, nil :: Box?
	for _, box in boxes do
		local tmin, tmax = 0, 1
		local nrm: Vector3? = nil
		local ok = true
		for axis = 1, 3 do
			local o = if axis == 1 then a.X elseif axis == 2 then a.Y else a.Z
			local dir = if axis == 1 then d.X elseif axis == 2 then d.Y else d.Z
			local lo = if axis == 1 then box.min.X elseif axis == 2 then box.min.Y else box.min.Z
			local hi = if axis == 1 then box.max.X elseif axis == 2 then box.max.Y else box.max.Z
			if math.abs(dir) < 1e-9 then
				if o < lo or o > hi then
					ok = false
					break
				end
			else
				local t1, t2 = (lo - o) / dir, (hi - o) / dir
				local sign = -1
				if t1 > t2 then
					t1, t2 = t2, t1
					sign = 1
				end
				if t1 > tmin then
					tmin = t1
					nrm = if axis == 1 then Vector3.new(sign, 0, 0) elseif axis == 2 then Vector3.new(0, sign, 0) else Vector3.new(0, 0, sign)
				end
				tmax = math.min(tmax, t2)
				if tmin > tmax then
					ok = false
					break
				end
			end
		end
		-- nrm == nil: el punto de salida ya está dentro de la caja (se ignora)
		if ok and nrm and tmin < bestT then
			bestT, bestN, bestBox = tmin, nrm, box
		end
	end
	if bestBox then
		return bestT, bestN, bestBox
	end
	return nil, nil, nil
end

-- Superficie más alta bajo (x, z) que no esté por encima de fromY. Devuelve (y, caja) o nil.
function Geo.surfaceBelow(boxes: { Box }, x: number, z: number, fromY: number): (number?, Box?)
	local bestY, bestBox = -math.huge, nil :: Box?
	for _, box in boxes do
		if x >= box.min.X and x <= box.max.X and z >= box.min.Z and z <= box.max.Z then
			local top = box.max.Y
			if top <= fromY + 0.05 and top > bestY then
				bestY, bestBox = top, box
			end
		end
	end
	if bestBox then
		return bestY, bestBox
	end
	return nil, nil
end

-- ¿El punto está dentro de alguna caja (con margen)? Devuelve la caja.
function Geo.inside(boxes: { Box }, p: Vector3, margin: number?): Box?
	local m = margin or 0
	for _, box in boxes do
		if p.X > box.min.X + m and p.X < box.max.X - m and p.Y > box.min.Y + m and p.Y < box.max.Y - m
			and p.Z > box.min.Z + m and p.Z < box.max.Z - m then
			return box
		end
	end
	return nil
end

function Geo.box(minV: Vector3, maxV: Vector3, kind: string): Box
	return {
		min = Vector3.new(math.min(minV.X, maxV.X), math.min(minV.Y, maxV.Y), math.min(minV.Z, maxV.Z)),
		max = Vector3.new(math.max(minV.X, maxV.X), math.max(minV.Y, maxV.Y), math.max(minV.Z, maxV.Z)),
		kind = kind,
	}
end

return Geo
