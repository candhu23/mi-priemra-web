--!strict
-- Estado de los libros de UNA biblioteca en el servidor (la principal o el Archivo).
-- Guarda dónde está cada libro, la mano del jugador, las filas correctas y el récord, y apunta los
-- cambios («deltas») que se mandan al cliente. Soltar y lanzar usan cajas (Geo), no la física de Roblox.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))
local Codec = require(ReplicatedStorage:WaitForChild("Codec"))
local Geo = require(ReplicatedStorage:WaitForChild("Geo"))

local Library = {}
Library.__index = Library

export type Move = { id: number, code: string, anim: string?, from: Vector3? }
export type Event = { kind: string, row: number?, section: string? }
export type Lib = typeof(setmetatable(
	{} :: {
		def: Layout.Def,
		locs: { Codec.Loc },
		slotBook: { [number]: number },
		hand: { number },
		rowOk: { [number]: boolean },
		sectionOk: { [string]: boolean },
		correct: number,
		shelved: number,
		best: number,
		moves: { Move },
		events: { Event },
	},
	Library
))

local FLAT = Layout.FLAT_H

function Library.new(def: Layout.Def, locs: { Codec.Loc }?, hand: { number }?, best: number?): Lib
	local self = setmetatable({
		def = def,
		locs = {},
		slotBook = {},
		hand = {},
		rowOk = {},
		sectionOk = {},
		correct = 0,
		shelved = 0,
		best = best or 0,
		moves = {},
		events = {},
	} :: any, Library) :: Lib
	for id = 1, #def.books do
		local given: Codec.Loc? = if locs then locs[id] else nil
		local loc: Codec.Loc = given or { k = 0 }
		-- un hueco ocupado dos veces (partida corrupta) devuelve el libro a su sitio inicial
		if loc.k == 1 and (self.slotBook[loc.s :: number] or (loc.s :: number) < 1 or (loc.s :: number) > #def.slotCF) then
			loc = { k = 0 }
		end
		self.locs[id] = loc
		if loc.k == 1 then
			self.slotBook[loc.s :: number] = id
			self.shelved += 1
		end
	end
	-- La mano: solo libros marcados «en la mano», sin repetir; el resto vuelve a su sitio inicial
	local seen: { [number]: boolean } = {}
	local handList: { number } = hand or {}
	for _, id in handList do
		if type(id) == "number" and self.locs[id] and self.locs[id].k == 3 and not seen[id] then
			table.insert(self.hand, id)
			seen[id] = true
		end
	end
	for id, loc in self.locs do
		if loc.k == 3 and not seen[id] then
			self.locs[id] = { k = 0 }
		end
	end
	for rowId in def.rows do
		local ok = Rules.row(def, rowId, self.slotBook)
		self.rowOk[rowId] = ok
		if ok then
			self.correct += 1
		end
	end
	for _, sec in def.sections do
		self.sectionOk[sec.code] = self:sectionDone(sec.code)
	end
	self.best = math.max(self.best, self.correct)
	return self
end

function Library.sectionDone(self: Lib, code: string): boolean
	for _, r in self.def.sectionByCode[code].rows do
		if not self.rowOk[r] then
			return false
		end
	end
	return true
end

-- Centro de un libro en el mundo (nil si está en la mano)
function Library.posOf(self: Lib, id: number): Vector3?
	local loc = self.locs[id]
	if not loc or loc.k == 3 then
		return nil
	elseif loc.k == 1 then
		return self.def.slotCF[loc.s :: number].Position
	elseif loc.k == 2 then
		return loc.p
	end
	return self.def.initial[id].pos
end

-- Posición «suelta» de un libro (k = 0 o 2), con su giro
local function loosePos(self: Lib, id: number): (Vector3?, number)
	local loc = self.locs[id]
	if loc.k == 2 then
		return loc.p, loc.yaw or 0
	elseif loc.k == 0 then
		local init = self.def.initial[id]
		return init.pos, init.yaw
	end
	return nil, 0
end

local function record(self: Lib, id: number, anim: string?, from: Vector3?)
	table.insert(self.moves, { id = id, code = Codec.encode(self.locs[id]), anim = anim, from = from })
end

-- Recalcula una fila tras un cambio y apunta avisos (fila hecha / rota, sección completa / rota)
local function touchRow(self: Lib, rowId: number)
	local ok = Rules.row(self.def, rowId, self.slotBook)
	local was = self.rowOk[rowId]
	if ok == was then
		return
	end
	self.rowOk[rowId] = ok
	self.correct += if ok then 1 else -1
	table.insert(self.events, { kind = if ok then "row" else "rowBroken", row = rowId })
	if self.correct > self.best then
		self.best = self.correct
		table.insert(self.events, { kind = "record" })
	end
	local code = self.def.rows[rowId].section
	local done = self:sectionDone(code)
	if done ~= self.sectionOk[code] then
		self.sectionOk[code] = done
		table.insert(self.events, { kind = if done then "section" else "sectionBroken", section = code })
	end
end

local function setLoc(self: Lib, id: number, loc: Codec.Loc, anim: string?, from: Vector3?)
	local old = self.locs[id]
	if old.k == 1 then
		local s = old.s :: number
		self.slotBook[s] = nil
		self.shelved -= 1
		touchRow(self, self.def.slotRow[s])
	end
	if loc.k == 2 then
		local p, yaw = Codec.quantize(loc.p :: Vector3, loc.yaw or 0)
		loc = { k = 2, p = p, yaw = yaw }
	end
	self.locs[id] = loc
	if loc.k == 1 then
		local s = loc.s :: number
		self.slotBook[s] = id
		self.shelved += 1
		touchRow(self, self.def.slotRow[s])
	end
	record(self, id, anim, from)
end

-- Los libros sueltos que estaban encima de `pos` bajan un libro (no hay física: se calcula)
local function settleAbove(self: Lib, pos: Vector3)
	for id, loc in self.locs do
		if loc.k == 0 or loc.k == 2 then
			local p, yaw = loosePos(self, id)
			if p and p.Y > pos.Y + 0.1 and p.Y < pos.Y + 8 and (Vector3.new(p.X - pos.X, 0, p.Z - pos.Z)).Magnitude < 0.65 then
				setLoc(self, id, { k = 2, p = p - Vector3.new(0, FLAT, 0), yaw = yaw })
			end
		end
	end
end

-- Altura a la que queda un libro soltado en (x, z) sobre la superficie `top` (encima de otros libros)
local function stackY(self: Lib, x: number, z: number, top: number): number
	local y = top + FLAT / 2
	for id, loc in self.locs do
		if loc.k == 0 or loc.k == 2 then
			local p = loosePos(self, id)
			if p and p.Y >= top and p.Y < top + 8 and math.abs(p.X - x) < 0.6 and math.abs(p.Z - z) < 0.6 then
				y = math.max(y, p.Y + FLAT)
			end
		end
	end
	return y
end

function Library.capacityLeft(self: Lib, cap: number): number
	return cap - #self.hand
end

-- Coger un libro (de un hueco o suelto) y ponerlo ENCIMA de la pila
function Library.take(self: Lib, id: number): boolean
	local loc = self.locs[id]
	if not loc or loc.k == 3 then
		return false
	end
	local wasLoose = loc.k ~= 1
	local p = loosePos(self, id)
	setLoc(self, id, { k = 3 })
	table.insert(self.hand, id)
	if wasLoose and p then
		settleAbove(self, p)
	end
	return true
end

-- Colocar el libro de arriba de la pila en un hueco libre
function Library.put(self: Lib, slot: number, from: Vector3?): number?
	if self.slotBook[slot] or #self.hand == 0 then
		return nil
	end
	local id = table.remove(self.hand) :: number
	setLoc(self, id, { k = 1, s = slot }, "fly", from)
	return id
end

-- Colocar un libro concreto de la mano en un hueco (Autocolocar)
function Library.putBook(self: Lib, id: number, slot: number, from: Vector3?): boolean
	local idx = table.find(self.hand, id)
	if not idx or self.slotBook[slot] then
		return false
	end
	table.remove(self.hand, idx)
	setLoc(self, id, { k = 1, s = slot }, "fly", from)
	return true
end

-- Suelta un libro de la mano en el punto (x, z) más alto bajo `fromY`, encima de otros libros si los hay
function Library.dropBook(self: Lib, id: number, x: number, z: number, fromY: number, yaw: number, anim: string?, from: Vector3?): boolean
	local top = Geo.surfaceBelow(self.def.solids, x, z, fromY)
	if not top then
		return false
	end
	local idx = table.find(self.hand, id)
	if idx then
		table.remove(self.hand, idx)
	end
	setLoc(self, id, { k = 2, p = Vector3.new(x, stackY(self, x, z, top), z), yaw = yaw }, anim, from)
	return true
end

-- Punto delante del jugador donde soltar (retrocede si delante hay un mueble o una pared)
function Library.dropPoint(self: Lib, rootPos: Vector3, look: Vector3): (number, number, number)
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	for _, dist in { 2.2, 1.6, 1.1, 0.6, 0 } do
		local p = rootPos + flat * dist
		local top = Geo.surfaceBelow(self.def.solids, p.X, p.Z, rootPos.Y)
		if top and not Geo.inside(self.def.solids, Vector3.new(p.X, top + 0.3, p.Z), 0) and rootPos.Y - top < 6 then
			return p.X, p.Z, rootPos.Y
		end
	end
	return rootPos.X, rootPos.Z, rootPos.Y
end

-- Vuelve a dejar un libro en su sitio inicial (si sale del mapa)
function Library.reset(self: Lib, id: number, from: Vector3?)
	local idx = table.find(self.hand, id)
	if idx then
		table.remove(self.hand, idx)
	end
	setLoc(self, id, { k = 0 }, if from then "fly" else nil, from)
end

-- Lanza el libro de arriba en parábola (pasa por encima de la barandilla). Devuelve el punto de caída.
function Library.throw(self: Lib, head: Vector3, dir: Vector3): (Vector3?, boolean)
	if #self.hand == 0 then
		return nil, false
	end
	local id = self.hand[#self.hand]
	local d = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	local p = head + d * 0.8
	local v = d * Config.THROW_SPEED + Vector3.new(0, Config.THROW_UP, 0)
	local dt = 1 / 30
	local b = self.def.bounds
	local t = 0
	while t < Config.THROW_MAX_TIME do
		local nv = v - Vector3.new(0, Config.THROW_GRAVITY * dt, 0)
		local q = p + (v + nv) * (dt / 2)
		local hitT, normal = Geo.segment(self.def.solids, p, q)
		if hitT then
			local hit = p + (q - p) * hitT
			local n = normal :: Vector3
			-- rebota un poco hacia fuera si choca de lado y cae
			local land = if n.Y > 0.5 then hit else hit + n * 0.45
			local yaw = math.atan2(-d.X, -d.Z)
			self:dropBook(id, land.X, land.Z, land.Y + 0.1, yaw, "throw", head)
			local lp = self:posOf(id)
			return lp, true
		end
		p, v = q, nv
		t += dt
		if p.X < b.min.X - 3 or p.X > b.max.X + 3 or p.Z < b.min.Z - 3 or p.Z > b.max.Z + 3 or p.Y < b.min.Y - 5 then
			break
		end
	end
	-- Fuera del mapa: vuelve a su sitio inicial
	self:reset(id, head)
	return self:posOf(id), false
end

-- El de arriba pasa abajo (clic derecho)
function Library.cycle(self: Lib): boolean
	if #self.hand < 2 then
		return false
	end
	local top = table.remove(self.hand) :: number
	table.insert(self.hand, 1, top)
	return true
end

-- Cambia de sitio un libro dentro de la pila (lista de libros en mano)
function Library.reorder(self: Lib, from: number, to: number): boolean
	local n = #self.hand
	if from < 1 or from > n or to < 1 or to > n or from == to then
		return false
	end
	local id = table.remove(self.hand, from) :: number
	table.insert(self.hand, to, id)
	return true
end

-- Ordena la pila por serie y tomo (hechizo Ordenar): el primero en colocarse (arriba) es el tomo 1
function Library.sortHand(self: Lib)
	local def = self.def
	table.sort(self.hand, function(a, b)
		local A, B = def.books[a], def.books[b]
		if A.series ~= B.series then
			return A.series > B.series
		end
		return A.vol > B.vol
	end)
end

-- Libros sueltos (no en estantería ni en la mano)
function Library.isLoose(self: Lib, id: number): boolean
	local k = self.locs[id].k
	return k == 0 or k == 2
end

function Library.flush(self: Lib): ({ Move }, { Event })
	local m, e = self.moves, self.events
	self.moves, self.events = {}, {}
	return m, e
end

function Library.encode(self: Lib): string
	return Codec.encodeAll(self.locs)
end

return Library
