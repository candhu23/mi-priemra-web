--!strict
-- La partida completa en el servidor: menú de título y ranuras, opciones, guardado agrupado, salida por la
-- puerta con evaluación (rango y final), logros/insignias y la fase especial (el Archivo con la definitiva).

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local BookData = require(ReplicatedStorage:WaitForChild("BookData"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))
local Codec = require(ReplicatedStorage:WaitForChild("Codec"))
local Game = require(script.Parent:WaitForChild("Game"))
local Library = require(script.Parent:WaitForChild("Library"))
local Data = require(script.Parent:WaitForChild("Data"))
local Magic = require(script.Parent:WaitForChild("Magic"))

local Flow = {}
local A = Game.Actions

local function now(): number
	return os.clock()
end

Flow.onProgress = nil :: ((any) -> ())? -- para enseñar llaves/cofres de la ranura cargada

---------------------------------------------------------------------
-- Logros → insignias
---------------------------------------------------------------------
function Flow.award(s: any, id: string)
	local ach = s.profile.achievements
	if ach[id] then
		return
	end
	ach[id] = true
	s.dirty = true
	Game.notify(s, "goal", "n_achievement", { name = "ach_" .. id })
	local badge = Config.Badges[id]
	if badge and badge ~= 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(s.player.UserId, badge)
			end)
		end)
	end
end

local function checkRows(s: any)
	if s.mode ~= "main" then
		return
	end
	local best = s.slot.best
	if best >= 1 then
		Flow.award(s, "first_row")
	end
	if best >= 50 then
		Flow.award(s, "rows_50")
	end
	if best >= 200 then
		Flow.award(s, "rows_200")
	end
	if s.lib.correct >= #s.lib.def.rows then
		Flow.award(s, "rows_400")
	end
end

local function checkSpells(s: any)
	local skills = s.slot.skills
	for _, sk in Config.Skills do
		if (skills[sk.id] or 0) >= 1 then
			Flow.award(s, "first_spell")
			break
		end
	end
	if Rules.allLearned(skills) then
		Flow.award(s, "all_spells")
	end
	if Rules.allMaxed(skills) then
		Flow.award(s, "spells_max")
	end
end

---------------------------------------------------------------------
-- Guardado agrupado: marca «pendiente» y escribe como mucho cada 30 s (+ al salir y en BindToClose).
-- Disparadores del original: fila completada, magia menor, salir, volver al menú y cada 50 libros.
---------------------------------------------------------------------
function Flow.capture(s: any)
	if s.mode == "main" and s.slotIndex > 0 then
		Game.capture(s)
		s.slot.updated = os.time()
		s.profile.slots[s.slotIndex] = s.slot
	end
end

function Flow.saveNow(s: any): boolean
	Flow.capture(s)
	s.dirty = false
	s.booksSinceSave = 0
	s.lastSave = now()
	if not s.canSave then
		return false
	end
	return Data.save(s.player.UserId, s.profile)
end

-- urgent = disparador del original (fila, llave, menú): se guarda ya si han pasado 30 s desde la última escritura
function Flow.request(s: any, urgent: boolean?)
	s.dirty = true
	if urgent and now() - s.lastSave >= Config.SAVE_MIN_INTERVAL then
		Flow.saveNow(s)
	end
end

function Flow.tick()
	for _, s in Game.sessions do
		local sx = s :: any
		if sx.mode == "special" and sx.special then
			sx.special.charge = math.min(Config.ULTIMATE_CHARGE, sx.special.charge + 1)
			if sx.special.charge >= Config.ULTIMATE_CHARGE and not sx.special.told then
				sx.special.told = true
				Game.notify(s, "goal", "n_ultimate_ready")
				Game.sendState(s)
			end
		end
		if sx.booksSinceSave >= Config.SAVE_EVERY_BOOKS then
			sx.dirty = true
		end
		local since = now() - sx.lastSave
		if sx.dirty and since >= Config.SAVE_MIN_INTERVAL then
			Flow.saveNow(sx)
		elseif sx.mode == "main" and since >= Config.SAVE_IDLE_INTERVAL then
			Flow.saveNow(sx)
		end
	end
end

---------------------------------------------------------------------
-- Menú de título y ranuras
---------------------------------------------------------------------
local function summary(slot: any): any
	if not slot then
		return false
	end
	return {
		rows = slot.rows or 0, shelved = slot.shelved or 0, time = slot.time or 0,
		finished = slot.finished == true, rank = slot.rank or 0, updated = slot.updated or 0,
	}
end

function Flow.enterMenu(s: any)
	s.mode = "menu"
	s.special = nil
	-- Fondo del menú: la última partida (o la biblioteca revuelta)
	local last = if s.profile.lastSlot > 0 then s.profile.slots[s.profile.lastSlot] else nil
	local def = Layout.get("main")
	s.slot = if last then last else Data.newSlot()
	s.lib = Library.new(def, if last then Codec.decodeAll(last.books, #def.books) else nil, if last then last.hand else nil, s.slot.best)
	if Flow.onProgress then
		Flow.onProgress(s)
	end
	Game.sendSnapshot(s)
	local char = s.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	end
	Game.moveTo(s, def.spawn)
	Game.sendState(s)
end

local function play(s: any, index: number, slot: any)
	s.slotIndex = index
	s.profile.lastSlot = index
	s.special = nil
	Game.startMain(s, slot)
	if Flow.onProgress then
		Flow.onProgress(s)
	end
	checkRows(s)
end

A.selectSlot = function(s, n)
	if s.mode ~= "menu" then
		return false, "err_generic"
	end
	local slot = if type(n) == "number" then s.profile.slots[n] else nil
	if not slot then
		return false, "err_generic"
	end
	play(s, n, slot)
	return true
end

A.newGame = function(s, n)
	if s.mode ~= "menu" or type(n) ~= "number" or n < 1 or n > Config.SLOTS or n ~= math.floor(n) then
		return false, "err_generic"
	end
	local slot = Data.newSlot()
	s.profile.slots[n] = slot
	play(s, n, slot)
	Flow.request(s, true)
	return true
end

A.deleteSlot = function(s, n)
	if s.mode ~= "menu" or type(n) ~= "number" or not s.profile.slots[n] then
		return false, "err_generic"
	end
	s.profile.slots[n] = false
	if s.profile.lastSlot == n then
		s.profile.lastSlot = 0
	end
	Flow.request(s, true)
	return true
end

A.toMenu = function(s)
	if s.mode == "menu" then
		return true
	end
	if s.mode == "main" then
		Flow.capture(s)
	end
	Flow.request(s, true)
	Flow.enterMenu(s)
	return true
end

---------------------------------------------------------------------
-- Opciones
---------------------------------------------------------------------
local OPTIONS: { [string]: (any) -> any } = {
	lang = function(v)
		return if v == "" or v == "es" or v == "en" then v else nil
	end,
	sens = function(v)
		return if type(v) == "number" then math.clamp(math.floor(v * 10 + 0.5) / 10, 0.2, 3) else nil
	end,
	fov = function(v)
		return if type(v) == "number" then math.clamp(math.floor(v), 50, 100) else nil
	end,
	music = function(v)
		return if type(v) == "number" then math.clamp(math.floor(v * 10 + 0.5) / 10, 0, 1) else nil
	end,
	sfx = function(v)
		return if type(v) == "number" then math.clamp(math.floor(v * 10 + 0.5) / 10, 0, 1) else nil
	end,
	bob = function(v)
		return if type(v) == "boolean" then v else nil
	end,
	cozy = function(v)
		return if type(v) == "boolean" then v else nil
	end,
	left = function(v)
		return if type(v) == "boolean" then v else nil
	end,
}

A.setOption = function(s, key, value)
	local check = if type(key) == "string" then OPTIONS[key] else nil
	if not check then
		return false, "err_generic"
	end
	local v = check(value)
	if v == nil then
		return false, "err_generic"
	end
	s.profile.settings[key] = v
	s.dirty = true
	return true
end

---------------------------------------------------------------------
-- Salida por la puerta: evaluación, rango y final
---------------------------------------------------------------------
local function evaluateMain(s: any)
	Game.commitTime(s)
	local slot = s.slot
	local total = #s.lib.def.rows
	local rows = s.lib.correct
	local t = slot.time
	local rank = Rules.rank(rows, total, t, slot.magic)
	local ending, list = Rules.ending(rows, total, t, slot.magic)
	local keys = 0
	for _, color in Config.KEYS do
		if slot.keys[color] then
			keys += 1
		end
	end
	local newBest = false
	if rows == total and (s.profile.bestTime == 0 or t < s.profile.bestTime) then
		s.profile.bestTime = t
		newBest = true
	end
	slot.finished = true
	slot.ending = ending
	slot.rank = math.max(slot.rank or 0, rank)
	s.profile.special = true
	checkRows(s)
	for _, e in list do
		if e == "fired" or e == "pizza" or e == "nomagic" then
			Flow.award(s, e)
		end
	end
	Flow.capture(s)
	Flow.request(s, true)
	return {
		kind = "main", time = t, rows = rows, total = total, magic = slot.magic, keys = keys,
		best = s.profile.bestTime, newBest = newBest, rank = rank, ending = ending, endings = list,
	}
end

local function evaluateSpecial(s: any)
	local used = s.special and s.special.used
	if used then
		Flow.award(s, "ultimate")
	end
	Flow.request(s, true)
	return { kind = "special", used = used == true, rows = s.lib.correct, total = #s.lib.def.rows }
end

Game.onExit = function(s: any)
	local results = if s.mode == "special" then evaluateSpecial(s) else evaluateMain(s)
	return true, nil, nil, { results = results, sound = "plate" }
end

---------------------------------------------------------------------
-- Fase especial: el Archivo (300 libros) y la habilidad definitiva (Z)
---------------------------------------------------------------------
A.startSpecial = function(s)
	if s.mode ~= "menu" then
		return false, "err_generic"
	end
	if not s.profile.special then
		return false, "special_locked"
	end
	local def = Layout.get("special")
	s.mode = "special"
	s.slotIndex = 0
	s.slot = Data.newSlot()
	-- En el Archivo se tiene toda la magia menor (salto, correr y 15 de capacidad); no hay magia mayor
	for _, color in Config.KEYS do
		s.slot.keys[color] = true
		s.slot.chests[color] = true
	end
	s.slot.tut = 99
	s.lib = Library.new(def)
	s.cap = Magic.capacity(s.slot)
	s.special = { charge = 0, used = false, told = false }
	Game.sendSnapshot(s)
	Game.applyCharacter(s)
	Game.moveTo(s, def.spawn)
	Game.notify(s, "info", "n_special")
	return true
end

A.ultimate = function(s)
	if s.mode ~= "special" or not s.special then
		return false, "err_generic"
	end
	if s.special.charge < Config.ULTIMATE_CHARGE then
		return false, "err_ultimate"
	end
	local def = s.lib.def
	-- Cada serie de cada sección a una fila de su sección (en orden), cada tomo a su hueco
	local targets: { [number]: number } = {}
	for _, sec in def.sections do
		local rowsByLen: { [number]: { number } } = {}
		for _, rowId in sec.rows do
			local len = def.rows[rowId].len
			rowsByLen[len] = rowsByLen[len] or {}
			table.insert(rowsByLen[len], rowId)
		end
		for _, sid in sec.series do
			local first = def.seriesFirst[sid]
			local n = BookData.Series[sid].volumes
			local rowId = table.remove(rowsByLen[n], 1) :: number
			for v = 1, n do
				targets[first + v - 1] = def.rows[rowId].first + v - 1
			end
		end
	end
	local root = Game.rootOf(s)
	s.lib:solveAll(targets, if root then root.CFrame.Position else nil)
	s.special.used = true
	s.special.charge = 0
	return true, "n_ultimate", nil, { sound = "plate" }
end

-- Colocar libros en el Archivo carga la definitiva más deprisa
local placeAction = A.place
A.place = function(s, slot)
	local ok, key, params, extra = placeAction(s, slot)
	if ok and s.mode == "special" and s.special then
		s.special.charge = math.min(Config.ULTIMATE_CHARGE, s.special.charge + Config.ULTIMATE_PER_BOOK)
	end
	return ok, key, params, extra
end

---------------------------------------------------------------------
-- Estado extra para el cliente
---------------------------------------------------------------------
table.insert(Game.stateHooks, function(s: any, st: { [string]: any })
	st.settings = table.clone(s.profile.settings)
	st.canSave = s.canSave
	st.loadFailed = s.loadFailed == true
	st.slotIndex = s.slotIndex
	st.bestTime = s.profile.bestTime
	st.specialUnlocked = s.profile.special == true
	st.achievements = table.clone(s.profile.achievements)
	if s.mode == "menu" then
		local slots = {}
		for i = 1, Config.SLOTS do
			slots[i] = summary(s.profile.slots[i])
		end
		st.slots = slots
		st.lastSlot = s.profile.lastSlot
	end
	if s.mode == "special" and s.special then
		st.ult = s.special.charge / Config.ULTIMATE_CHARGE
	end
end)

---------------------------------------------------------------------
-- Ganchos: logros y disparadores de guardado
---------------------------------------------------------------------
Game.onEvents = function(s: any, events: { any })
	for _, e in events do
		if e.kind == "row" or e.kind == "record" then
			checkRows(s)
			if s.mode == "main" then
				Flow.request(s, e.kind == "row")
			end
		end
	end
end

function Flow.onLearn(s: any)
	checkSpells(s)
	Flow.request(s, false)
end

function Flow.onKey(s: any)
	Flow.request(s, true)
end

function Flow.onChest(s: any)
	local all = true
	for _, color in Config.KEYS do
		if not s.slot.chests[color] then
			all = false
		end
	end
	if all then
		Flow.award(s, "chests")
	end
	Flow.request(s, true)
end

-- Entrada del jugador: carga su perfil y abre el menú
function Flow.join(s: any)
	local profile, ok = Data.load(s.player.UserId)
	s.profile = profile
	s.canSave = ok and Data.available()
	s.loadFailed = Data.available() and not ok
	s.slotIndex = 0
	s.lastSave = now()
	Flow.enterMenu(s)
	if not s.canSave then
		Game.notify(s, "popup", if s.loadFailed then "warn_load_failed" else "warn_no_save", { title = "menu_options" })
	end
end

function Flow.leave(s: any)
	-- respeta el límite de DataStore (1 escritura por clave cada 6 s)
	local wait = 6 - (now() - s.lastSave)
	if wait > 0 then
		task.wait(wait)
	end
	Flow.saveNow(s)
end

return Flow
