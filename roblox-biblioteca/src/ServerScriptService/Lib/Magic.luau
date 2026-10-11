--!strict
-- Progresión en el servidor: magia mayor (manual personal: comprar/subir niveles, lanzar hechizos con
-- duración y enfriamiento), magia menor (llaves → cofres) y el cristal de recuperación.
-- Los puntos salen del RÉCORD de filas correctas (Rules.points), así romper y rehacer una fila no da puntos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local BookData = require(ReplicatedStorage:WaitForChild("BookData"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))
local Geo = require(ReplicatedStorage:WaitForChild("Geo"))
local Game = require(script.Parent:WaitForChild("Game"))

local Magic = {}
local A = Game.Actions
-- Ganchos (logros, mundo): los rellena LibraryServer
Magic.onLearn = nil :: ((any, string, number) -> ())?
Magic.onKey = nil :: ((any, string) -> ())?
Magic.onChest = nil :: ((any, string) -> ())?

local function now(): number
	return os.clock()
end

-- Tiempos de los hechizos de la sesión (no se guardan: al volver a entrar están listos)
local function timers(s: any): { cd: { [string]: number }, active: { [string]: number } }
	if not s.spells then
		s.spells = { cd = {}, active = {} }
	end
	return s.spells
end

function Magic.points(s: any): number
	return Rules.points(s.slot.best) - s.slot.spent
end

-- Estado de los hechizos para el cliente: segundos que faltan de enfriamiento y de efecto
function Magic.state(s: any, st: { [string]: any })
	local t = timers(s)
	local cds, active = {}, {}
	for _, sk in Config.Skills do
		local cdLeft = math.max(0, (t.cd[sk.id] or 0) - now())
		local actLeft = math.max(0, (t.active[sk.id] or 0) - now())
		cds[sk.id] = math.ceil(cdLeft * 10) / 10
		active[sk.id] = math.ceil(actLeft * 10) / 10
	end
	st.skills = table.clone(s.slot.skills)
	st.cd = cds
	st.active = active
	st.keys = table.clone(s.slot.keys)
	st.chests = table.clone(s.slot.chests)
	st.jump = s.slot.chests.red == true
	st.run = s.slot.chests.green == true
	st.magic = s.slot.magic == true
end

---------------------------------------------------------------------
-- Manual personal: comprar y subir de nivel
---------------------------------------------------------------------
A.buySkill = function(s, id)
	if s.mode ~= "main" then
		return false, "err_menu"
	end
	local sk = Config.SkillById[id]
	if type(id) ~= "string" or not sk then
		return false, "err_generic"
	end
	local level = s.slot.skills[id] or 0
	if level >= sk.max then
		return false, "err_maxed"
	end
	if Magic.points(s) < 1 then
		return false, "err_no_points"
	end
	s.slot.spent += 1
	s.slot.skills[id] = level + 1
	s.slot.magic = true -- comprar magia mayor ya cuenta para «Sin magia»
	s.dirty = true
	if Magic.onLearn then
		Magic.onLearn(s, id, level + 1)
	end
	if level == 0 then
		return true, "n_learned", { name = "sk_" .. id }, { sound = "plate" }
	end
	return true, "n_upgraded", { name = "sk_" .. id, l = level + 1 }, { sound = "plate" }
end

-- Top de la pila (libro de arriba)
local function topBook(s: any): number?
	local hand = s.lib.hand
	return hand[#hand]
end

-- Fila de destino para un libro con Autocolocar: la que ya tiene tomos de su serie (y solo de ella);
-- si no, una vacía de la longitud correcta. Devuelve el hueco del tomo, o nil.
local function autoSlot(s: any, id: number, reserved: { [number]: number }): number?
	local def = s.lib.def
	local info = def.books[id]
	local code = def.seriesSection[info.series]
	local len = BookData.Series[info.series].volumes
	local sec = def.sectionByCode[code]
	local empty: number? = nil
	for _, rowId in sec.rows do
		local row = def.rows[rowId]
		if row.len == len then
			local only, any = true, false
			for i = 1, row.len do
				local b = s.lib.slotBook[row.first + i - 1]
				local series = if b then def.books[b].series else reserved[row.first + i - 1]
				if series then
					any = true
					if series ~= info.series then
						only = false
					end
				end
			end
			if any and only then
				return row.first + info.vol - 1
			elseif not any and not empty then
				empty = rowId
			end
		end
	end
	if empty then
		return def.rows[empty].first + info.vol - 1
	end
	return nil
end

-- Lanzar un hechizo (teclas 1–5). Ordenar y Reunir son instantáneos; Guía, Revelar y Autocolocar duran.
-- El enfriamiento empieza al acabar el efecto (supuesto).
A.cast = function(s, id)
	if s.mode ~= "main" then
		return false, "err_menu"
	end
	local sk = Config.SkillById[id]
	if type(id) ~= "string" or not sk then
		return false, "err_generic"
	end
	local level = s.slot.skills[id] or 0
	if level < 1 then
		return false, "err_not_learned", { key = "B" }
	end
	local t = timers(s)
	if (t.active[id] or 0) > now() then
		return false, "err_active"
	end
	local left = (t.cd[id] or 0) - now()
	if left > 0 then
		return false, "err_cooldown", { s = math.ceil(left) }
	end
	local cooldown = Rules.skill(id, level, "cooldown")
	local duration = Rules.skill(id, level, "duration")
	if id == "sort" then
		if #s.lib.hand < 2 then
			return false, "err_empty"
		end
		s.lib:sortHand()
		t.cd[id] = now() + cooldown
		s.slot.magic = true
		return true, "n_sorted", nil, { sound = "plate", spell = id }
	elseif id == "gather" then
		local top = topBook(s)
		if not top then
			return false, "err_empty"
		end
		local root = Game.rootOf(s)
		local origin = if root then root.CFrame.Position else s.lib.def.spawn.Position
		local series = s.lib.def.books[top].series
		local want = math.min(Rules.skill(id, level, "count"), s.cap - #s.lib.hand)
		-- Tomos sueltos de la misma serie (suelo y mesas, nunca estanterías), los más cercanos primero
		local found: { { id: number, d: number } } = {}
		local first = s.lib.def.seriesFirst[series]
		for v = 1, BookData.Series[series].volumes do
			local b = first + v - 1
			if b ~= top and s.lib:isLoose(b) then
				table.insert(found, { id = b, d = ((s.lib:posOf(b) :: Vector3) - origin).Magnitude })
			end
		end
		if #found == 0 or want <= 0 then
			return false, if want <= 0 then "err_full" else "err_nothing_to_gather"
		end
		table.sort(found, function(a, b)
			return a.d < b.d
		end)
		local n = 0
		for i = 1, math.min(want, #found) do
			s.lib:take(found[i].id)
			n += 1
		end
		t.cd[id] = now() + cooldown
		s.slot.magic = true
		return true, "n_gathered", { n = n }, { sound = "pick", spell = id }
	end
	-- Con duración: Guía, Revelar, Autocolocar
	t.active[id] = now() + duration
	t.cd[id] = now() + duration + cooldown
	s.slot.magic = true
	local key = if id == "guide" then "n_guide" elseif id == "reveal" then "n_reveal" else "n_auto"
	return true, key, { key = Config.SkillById[id].key }, { sound = "plate", spell = id }
end

-- Autocolocar: con el hechizo activo, coloca todos los libros de la mano de la sección apuntada
A.autoPlace = function(s, code)
	if s.mode ~= "main" then
		return false, "err_menu"
	end
	local t = timers(s)
	if (t.active.auto or 0) <= now() then
		return false, "err_auto_off", { key = Config.SkillById.auto.key }
	end
	local def = s.lib.def
	local sec = if type(code) == "string" then def.sectionByCode[code] else nil
	if not sec then
		return false, "err_aim_section"
	end
	local b = sec.box
	local root = Game.rootOf(s)
	if not root then
		return false, "err_reach"
	end
	-- Distancia al punto más cercano del mueble
	local p = root.CFrame.Position
	local closest = Vector3.new(math.clamp(p.X, b.min.X, b.max.X), math.clamp(p.Y, b.min.Y, b.max.Y), math.clamp(p.Z, b.min.Z, b.max.Z))
	if (closest - p).Magnitude > Config.AIM_SECTION_RANGE then
		return false, "err_reach"
	end
	local list = {}
	for _, id in s.lib.hand do
		if def.seriesSection[def.books[id].series] == code then
			table.insert(list, id)
		end
	end
	if #list == 0 then
		return false, "err_no_section_books"
	end
	local reserved: { [number]: number } = {}
	local placed = 0
	-- Primero los de series que ya tienen fila (así no se reparten en dos filas)
	for _, id in list do
		local slot = autoSlot(s, id, reserved)
		if slot and not s.lib.slotBook[slot] and not reserved[slot] then
			reserved[slot] = def.books[id].series
			if s.lib:putBook(id, slot, p + Vector3.new(0, 1.5, 0)) then
				placed += 1
			end
		end
	end
	s.booksSinceSave += placed
	return true, "n_auto_placed", { n = placed }, { sound = "place" }
end

---------------------------------------------------------------------
-- Magia menor: llaves y cofres
---------------------------------------------------------------------
local VALID = { red = true, green = true, yellow = true, blue = true }

A.takeKey = function(s, color)
	if s.mode ~= "main" then
		return false, "err_menu"
	end
	if type(color) ~= "string" or not VALID[color] then
		return false, "err_generic"
	end
	if s.slot.keys[color] then
		return false, "err_gone"
	end
	local def = s.lib.def
	local pos = def.interact["key_" .. color]
	-- La llave verde está bajo un montón: hay que quitar antes los libros de encima
	for id = 1, #def.books do
		if s.lib:isLoose(id) then
			local bp = s.lib:posOf(id) :: Vector3
			if math.abs(bp.X - pos.X) < 1 and math.abs(bp.Z - pos.Z) < 1 and bp.Y > pos.Y - 0.3 and bp.Y < pos.Y + 5 then
				return false, "err_key_covered"
			end
		end
	end
	-- Las llaves se cogen de cerca (las altas exigen saltar)
	local root = Game.rootOf(s)
	if not root or (root.CFrame.Position - pos).Magnitude > Config.KEY_REACH + 0.5 then
		return false, if root and root.CFrame.Position.Y < pos.Y - 3 then "err_key_high" else "err_reach"
	end
	s.slot.keys[color] = true
	s.dirty = true
	if Magic.onKey then
		Magic.onKey(s, color)
	end
	return true, "n_key", { color = "key_" .. color }, { sound = "row" }
end

A.openChest = function(s, color)
	if s.mode ~= "main" then
		return false, "err_menu"
	end
	if type(color) ~= "string" or not VALID[color] then
		return false, "err_generic"
	end
	if s.slot.chests[color] then
		return false, "err_gone"
	end
	if not s.slot.keys[color] then
		return false, "err_need_key", { color = "key_" .. color }
	end
	if not Game.near(s, s.lib.def.interact["chest_" .. color]) then
		return false, "err_reach"
	end
	s.slot.chests[color] = true
	s.dirty = true
	local reward = Config.ChestReward[color]
	if reward == "cap3" or reward == "cap2" then
		s.cap = Magic.capacity(s.slot)
	end
	Game.applyCharacter(s)
	if Magic.onChest then
		Magic.onChest(s, color)
	end
	return true, nil, nil, { sound = "plate", chest = color, reward = reward, cap = s.cap }
end

function Magic.capacity(slot: any): number
	return Config.CAPACITY + (if slot.chests.yellow then Config.CAPACITY_BONUS.yellow else 0) + (if slot.chests.blue then Config.CAPACITY_BONUS.blue else 0)
end

---------------------------------------------------------------------
-- Cristal de recuperación: trae al podio hasta 20 libros perdidos
---------------------------------------------------------------------
-- ¿Libro suelto «perdido»? Fuera del edificio, encima de algo que no es suelo/escalera/mueble, o flotando.
function Magic.isLost(def: Layout.Def, pos: Vector3): boolean
	local b = def.bounds
	if pos.X < b.min.X or pos.X > b.max.X or pos.Z < b.min.Z or pos.Z > b.max.Z or pos.Y < b.min.Y then
		return true
	end
	local top, box = Geo.surfaceBelow(def.solids, pos.X, pos.Z, pos.Y)
	if not top or not box then
		return true
	end
	if box.kind ~= "floor" and box.kind ~= "stair" and box.kind ~= "furniture" then
		return true
	end
	-- encima de otros libros: se mira la altura sobre su superficie (montones muy altos también cuentan)
	return pos.Y - top > 4
end

A.useCrystal = function(s)
	if s.mode ~= "main" then
		return false, "err_menu"
	end
	local def = s.lib.def
	if not Game.near(s, def.interact.crystal) then
		return false, "err_reach"
	end
	local lost = {}
	for id = 1, #def.books do
		if s.lib:isLoose(id) and Magic.isLost(def, s.lib:posOf(id) :: Vector3) then
			table.insert(lost, id)
			if #lost >= Config.CRYSTAL_MAX then
				break
			end
		end
	end
	if #lost == 0 then
		return false, "err_crystal_none"
	end
	-- En dos montones junto al podio
	local crystal = def.interact.crystal
	for i, id in lost do
		local base = def.podium[(i - 1) % #def.podium + 1]
		s.lib:take(id)
		s.lib:dropBook(id, base.X, base.Z, base.Y + 0.5, 0, "fly", crystal)
	end
	return true, "n_crystal", { n = #lost }, { sound = "row" }
end

table.insert(Game.stateHooks, Magic.state)

return Magic
