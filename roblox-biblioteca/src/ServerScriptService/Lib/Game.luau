--!strict
-- Lógica de la partida en el servidor: sesión del jugador, acciones (validadas), deltas y estado.
-- El cliente solo pide; aquí se comprueba distancia, capacidad, enfriamientos y ritmo de acciones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))
local Codec = require(ReplicatedStorage:WaitForChild("Codec"))
local Library = require(script.Parent:WaitForChild("Library"))
local Data = require(script.Parent:WaitForChild("Data"))

local Game = {}

export type Session = {
	player: Player,
	slot: any,
	mode: string,
	lib: Library.Lib,
	cap: number,
	rateT: number,
	rateN: number,
	timeT: number,
	lastState: number,
	dirty: boolean,
	booksSinceSave: number,
	-- Partida completa (Flow): perfil guardado, ranura activa, guardado y fase especial
	profile: any,
	canSave: boolean,
	loadFailed: boolean,
	slotIndex: number,
	lastSave: number,
	special: any,
	spells: any,
	passes: any,
	studio: boolean,
}

Game.sessions = {} :: { [Player]: Session }
Game.remotes = nil :: any
-- Ganchos que rellenan otros módulos (magia, guardado, evaluación)
Game.stateHooks = {} :: { (any, { [string]: any }) -> () }
Game.onEvents = nil :: ((Session, { any }) -> ())?
Game.onExit = nil :: ((Session) -> (boolean, string?, { [string]: any }?, { [string]: any }?))?

local function now(): number
	return os.clock()
end

---------------------------------------------------------------------
-- Partida nueva (ranura)
---------------------------------------------------------------------
function Game.newSlot(): any
	return Data.newSlot()
end

local function rootOf(s: Session): BasePart?
	local char = s.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end
Game.rootOf = rootOf

-- ¿El jugador está lo bastante cerca de `pos`?
local function near(s: Session, pos: Vector3, reach: number?): boolean
	local root = rootOf(s)
	if not root then
		return false
	end
	return (root.CFrame.Position - pos).Magnitude <= (reach or (Config.REACH + Config.REACH_SLACK))
end
Game.near = near

-- Tiempo de juego acumulado (solo cuenta dentro de la biblioteca principal)
function Game.playTime(s: Session): number
	local t = s.slot.time
	if s.mode == "main" then
		t += now() - s.timeT
	end
	return t
end

local function commitTime(s: Session)
	if s.mode == "main" then
		s.slot.time += now() - s.timeT
	end
	s.timeT = now()
end
Game.commitTime = commitTime

---------------------------------------------------------------------
-- Avisos, estado y deltas
---------------------------------------------------------------------
function Game.notify(s: Session, kind: string, key: string, params: { [string]: any }?)
	Game.remotes.Notify:FireClient(s.player, kind, key, params or {})
end

function Game.state(s: Session): { [string]: any }
	local lib = s.lib
	local slot = s.slot
	local earned = Rules.points(slot.best)
	local st = {
		mode = s.mode,
		lib = lib.def.name,
		hand = table.clone(lib.hand),
		cap = s.cap,
		rows = lib.correct,
		best = slot.best,
		rowsTotal = #lib.def.rows,
		shelved = lib.shelved,
		total = #lib.def.books,
		points = earned - slot.spent,
		earned = earned,
		nextAt = Rules.nextPointAt(slot.best) or 0,
		tut = slot.tut,
		time = Game.playTime(s),
		door = lib.shelved >= #lib.def.books,
	}
	for _, hook in Game.stateHooks do
		hook(s, st)
	end
	return st
end

function Game.sendState(s: Session)
	s.lastState = now()
	Game.remotes.State:FireClient(s.player, Game.state(s))
end

function Game.sendSnapshot(s: Session)
	Game.remotes.Snapshot:FireClient(s.player, s.lib.def.name, s.lib:encode())
end

-- Avisos que salen de los cambios de filas (récord → puntos; tutorial)
local function handleEvents(s: Session, events: { Library.Event })
	local slot = s.slot
	for _, e in events do
		if e.kind == "record" then
			local before = Rules.points(slot.best)
			slot.best = math.max(slot.best, s.lib.best)
			if Rules.points(slot.best) > before then
				Game.notify(s, "point", "n_point", { key = "B" })
			end
			s.dirty = true
		elseif e.kind == "row" and s.mode == "main" then
			s.dirty = true
			-- Tutorial: filas de las dos series del montón de inicio
			local def = s.lib.def
			local row = def.rows[e.row :: number]
			local first = s.lib.slotBook[row.first]
			if first and table.find(def.tutorialSeries, def.books[first].series) then
				local both = true
				for _, sid in def.tutorialSeries do
					local book = def.seriesFirst[sid]
					local loc = s.lib.locs[book]
					if loc.k ~= 1 or not s.lib.rowOk[def.slotRow[loc.s :: number]] then
						both = false
					end
				end
				if both and slot.tut < 4 then
					slot.tut = 4
				elseif slot.tut < 3 then
					slot.tut = 3
				end
			end
		end
	end
	if Game.onEvents then
		Game.onEvents(s, events)
	end
end

-- Manda al cliente lo que ha cambiado (deltas) y procesa los avisos
function Game.flush(s: Session)
	local moves, events = s.lib:flush()
	if #moves > 0 then
		local out: { any } = {}
		for i, m in moves do
			local item: { any } = { m.id, m.code, m.anim or "", m.from }
			out[i] = item
		end
		Game.remotes.Delta:FireClient(s.player, out)
	end
	handleEvents(s, events)
end


---------------------------------------------------------------------
-- Acciones de los libros
---------------------------------------------------------------------
Game.Actions = {} :: { [string]: (Session, any, any, any) -> (boolean, string?, { [string]: any }?, { [string]: any }?) }
local A = Game.Actions

local function inWorld(s: Session): boolean
	return s.mode == "main" or s.mode == "special"
end

A.pick = function(s, id)
	if not inWorld(s) then
		return false, "err_menu"
	end
	if type(id) ~= "number" or not s.lib.locs[id] then
		return false, "err_gone"
	end
	if #s.lib.hand >= s.cap then
		return false, "err_full"
	end
	local pos = s.lib:posOf(id)
	if not pos then
		return false, "err_gone"
	end
	if not near(s, pos) then
		return false, "err_reach"
	end
	s.lib:take(id)
	if s.slot.tut == 1 then
		s.slot.tut = 2
	end
	return true, nil, nil, { sound = "pick" }
end

A.place = function(s, slot)
	if not inWorld(s) then
		return false, "err_menu"
	end
	if type(slot) ~= "number" or not s.lib.def.slotCF[slot] then
		return false, "err_generic"
	end
	if #s.lib.hand == 0 then
		return false, "err_empty"
	end
	if s.lib.slotBook[slot] then
		return false, "err_taken"
	end
	local pos = s.lib.def.slotCF[slot].Position
	if not near(s, pos) then
		return false, "err_reach"
	end
	local root = rootOf(s)
	s.lib:put(slot, if root then root.CFrame.Position + Vector3.new(0, 1.5, 0) else nil)
	s.booksSinceSave += 1
	return true, nil, nil, { sound = "place" }
end

A.drop = function(s)
	if not inWorld(s) then
		return false, "err_menu"
	end
	local root = rootOf(s)
	if #s.lib.hand == 0 or not root then
		return false, "err_empty"
	end
	local look = root.CFrame.LookVector
	local x, z, y = s.lib:dropPoint(root.CFrame.Position, look)
	local id = s.lib.hand[#s.lib.hand]
	if not s.lib:dropBook(id, x, z, y, math.atan2(-look.X, -look.Z), "fly", root.CFrame.Position + Vector3.new(0, 1.5, 0)) then
		return false, "err_generic"
	end
	return true, nil, nil, { sound = "thud" }
end

A.dropAll = function(s)
	if not inWorld(s) then
		return false, "err_menu"
	end
	local root = rootOf(s)
	if #s.lib.hand == 0 or not root then
		return false, "err_empty"
	end
	local look = root.CFrame.LookVector
	local x, z, y = s.lib:dropPoint(root.CFrame.Position, look)
	-- En el mismo orden que en la mano: el de abajo de la pila queda abajo del montón
	local list = table.clone(s.lib.hand)
	for _, id in list do
		s.lib:dropBook(id, x, z, y, math.atan2(-look.X, -look.Z), "fly", root.CFrame.Position + Vector3.new(0, 1.5, 0))
	end
	return true, nil, nil, { sound = "thud" }
end

A.throw = function(s, dir)
	if not inWorld(s) then
		return false, "err_menu"
	end
	local root = rootOf(s)
	if #s.lib.hand == 0 or not root then
		return false, "err_empty"
	end
	local d = if typeof(dir) == "Vector3" then dir else root.CFrame.LookVector
	if d.Magnitude < 0.5 or d.Magnitude > 1.5 then
		d = root.CFrame.LookVector
	end
	local _, inside = s.lib:throw(root.CFrame.Position + Vector3.new(0, 1.5, 0), d)
	if not inside then
		Game.notify(s, "info", "n_returned")
	end
	return true, nil, nil, { sound = "throw" }
end

A.cycle = function(s)
	if not s.lib:cycle() then
		return false, nil
	end
	return true
end

A.reorder = function(s, from, to)
	if type(from) ~= "number" or type(to) ~= "number" or not s.lib:reorder(from, to) then
		return false, "err_generic"
	end
	return true
end

-- El cliente está listo: le manda la foto de la biblioteca (y, tras la acción, el estado)
A.ready = function(s)
	Game.sendSnapshot(s) -- también en el menú: la biblioteca se ve de fondo
	return true
end

A.readLetter = function(s)
	if s.slot.tut == 0 then
		s.slot.tut = 1
	end
	return true
end

A.exitDoor = function(s)
	if not inWorld(s) then
		return false, "err_menu"
	end
	local missing = #s.lib.def.books - s.lib.shelved
	if missing > 0 then
		return false, "err_door_locked", { n = missing }
	end
	if Game.onExit then
		return Game.onExit(s)
	end
	return true
end

---------------------------------------------------------------------
-- Entrada de acciones: ritmo, dueño, errores
---------------------------------------------------------------------
function Game.handle(player: Player, name: any, a: any, b: any, c: any): (boolean, string?, { [string]: any }?, { [string]: any }?)
	local s = Game.sessions[player]
	if not s then
		return false, "err_not_owner"
	end
	if type(name) ~= "string" or not A[name] then
		return false, "err_generic"
	end
	-- Límite de acciones por segundo
	local t = now()
	if t - s.rateT >= 1 then
		s.rateT, s.rateN = t, 0
	end
	s.rateN += 1
	if s.rateN > Config.ACTIONS_PER_SECOND then
		return false, "err_slow"
	end
	local ok, okRes, key, params, extra = pcall(A[name], s, a, b, c)
	if not ok then
		warn("Error en la acción", name, okRes)
		return false, "err_generic"
	end
	Game.flush(s)
	Game.sendState(s)
	return okRes, key, params, extra
end

---------------------------------------------------------------------
-- Personaje
---------------------------------------------------------------------
function Game.applyCharacter(s: Session)
	local char = s.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local menu = s.mode == "menu"
		hum.WalkSpeed = if menu then 0 else Config.WALK_SPEED
		hum.UseJumpPower = false
		hum.JumpHeight = if s.slot.chests.red and not menu then Config.JUMP_HEIGHT else 0
	end
end

function Game.moveTo(s: Session, cf: CFrame)
	local char = s.player.Character
	if char then
		char:PivotTo(cf + Vector3.new(0, 3, 0))
	end
end

---------------------------------------------------------------------
-- Entrar / salir
---------------------------------------------------------------------
-- Empieza (o continúa) la partida de una ranura en la biblioteca principal
function Game.startMain(s: Session, slot: any)
	s.slot = slot
	local def = Layout.get("main")
	local locs = Codec.decodeAll(slot.books, #def.books)
	s.lib = Library.new(def, locs, slot.hand, slot.best)
	slot.best = math.max(slot.best, s.lib.best)
	s.mode = "main"
	s.timeT = now()
	s.cap = Config.CAPACITY + (if slot.chests.yellow then Config.CAPACITY_BONUS.yellow else 0) + (if slot.chests.blue then Config.CAPACITY_BONUS.blue else 0)
	Game.sendSnapshot(s)
	Game.applyCharacter(s)
	if slot.pos then
		Game.moveTo(s, CFrame.new(slot.pos[1], slot.pos[2], slot.pos[3]))
	else
		Game.moveTo(s, def.spawn)
	end
	Game.sendState(s)
end

-- Guarda en la ranura lo que hay en la biblioteca (para DataStore)
function Game.capture(s: Session)
	if s.mode ~= "main" then
		return
	end
	commitTime(s)
	local slot = s.slot
	slot.books = s.lib:encode()
	slot.hand = table.clone(s.lib.hand)
	slot.best = math.max(slot.best, s.lib.best)
	slot.rows = s.lib.correct
	slot.shelved = s.lib.shelved
	local root = rootOf(s)
	if root then
		local p = root.CFrame.Position
		slot.pos = { math.floor(p.X * 10) / 10, math.floor(p.Y * 10) / 10 - 3, math.floor(p.Z * 10) / 10 }
	end
end

function Game.newSession(player: Player): Session
	local s: Session = {
		player = player,
		slot = Game.newSlot(),
		mode = "menu",
		lib = Library.new(Layout.get("main")),
		cap = Config.CAPACITY,
		rateT = now(),
		rateN = 0,
		timeT = now(),
		lastState = 0,
		dirty = false,
		booksSinceSave = 0,
		profile = Data.newProfile(),
		canSave = false,
		loadFailed = false,
		slotIndex = 0,
		lastSave = now(),
		special = nil,
		spells = nil,
		passes = {},
		studio = false,
	}
	Game.sessions[player] = s
	return s
end

function Game.tick()
	for _, s in Game.sessions do
		if now() - s.lastState > 10 then
			Game.sendState(s)
		end
	end
end

function Game.removeSession(player: Player)
	Game.sessions[player] = nil
end

function Game.ownerCount(): number
	local n = 0
	for _ in Game.sessions do
		n += 1
	end
	return n
end

local _ = Players
return Game
