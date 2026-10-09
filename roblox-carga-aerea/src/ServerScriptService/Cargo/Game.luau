--!strict
-- Lógica del juego en el servidor. Las acciones devuelven (ok, claveDeTexto?, parámetros?, extra?)
-- y los avisos se mandan como claves de Lang.luau: el cliente las traduce.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Game = {}

export type Load = {
	id: number, good: string, from: string, to: string, weight: number, dist: number, gross: number,
	express: number?, tutorial: boolean?,
}
export type Session = {
	player: Player,
	data: any,
	canSave: boolean,
	boards: { [string]: { loads: { Load }, expires: number } },
	refreshAt: { [string]: number },
	nextLoadId: number,
	passes: { [string]: boolean },
	social: { friends: number, premium: boolean, group: boolean },
	express: Load?,
	nextExpress: number,
	dirty: boolean,
	actionWindow: number,
	actionCount: number,
	earnedWindow: number,
	incomePerMin: number,
	offlineLast: number,
}
Game.sessions = {} :: { [Player]: Session }

local rng = Random.new()
local fuelMult = 1
local nextFuel = os.time() + 300

-- Envío de avisos (lo conecta GameServer)
Game.notify = function(_player: Player, _kind: string, _key: string, _params: { [string]: any }?) end
Game.notifyAll = function(_kind: string, _key: string, _params: { [string]: any }?) end
Game.pushState = function(_player: Player) end -- manda el estado ya (lo conecta GameServer)

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
function Game.level(data: any): number
	return Config.levelFromXp(data.xp)
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function findPlane(data: any, id: any): any
	for _, p in data.planes do
		if p.id == id then
			return p
		end
	end
	return nil
end

local function findPilot(data: any, id: any): any
	for _, p in data.pilots do
		if p.id == id then
			return p
		end
	end
	return nil
end

local function pilotBusy(data: any, pilotId: number): boolean
	for _, p in data.planes do
		if p.flight and p.flight.pilot == pilotId then
			return true
		end
	end
	return false
end

local function regionCount(data: any): number
	local n = 0
	for _ in data.regions do
		n += 1
	end
	return n
end

function Game.autoUnlocked(session: Session): boolean
	return session.passes.autopilot == true or Game.level(session.data) >= Config.AUTO_DISPATCH_LEVEL
end

function Game.maxPlanes(session: Session): number
	return Config.maxPlanes(session.data.upgrades.hangar, session.passes.hangarxl)
end

function Game.fuelPrice(data: any): number
	return Config.FUEL_PRICE * fuelMult * (1 - 0.05 * data.upgrades.fuel)
end

function Game.boostActive(data: any): boolean
	return data.boostUntil > os.time()
end

-- Multiplicador de dinero: bonus sociales × pase VIP × boost
function Game.moneyMult(session: Session): number
	local s = session.social
	local social = 1 + 0.1 * math.min(s.friends, 4) + (s.premium and 0.1 or 0) + (s.group and 0.1 or 0)
	return social * (session.passes.vip and 2 or 1) * (Game.boostActive(session.data) and 2 or 1)
end

function Game.timeMult(session: Session): number
	return (1 - 0.08 * session.data.upgrades.fast) * (session.passes.turbo and 0.75 or 1)
end

---------------------------------------------------------------------
-- Estadísticas, misiones y objetivos
---------------------------------------------------------------------
local function newMissions(data: any)
	local pool = table.clone(Config.MissionPool)
	local list = {}
	local scale = Config.rewardScale(Game.level(data))
	for difficulty = 1, 3 do
		local def = table.remove(pool, rng:NextInteger(1, #pool)) :: any
		local target = def.goal[difficulty]
		if def.stat == "earned" then
			target *= scale
		end
		table.insert(list, {
			id = def.id, stat = def.stat, target = target, progress = 0, claimed = false,
			reward = math.floor(scale * def.reward * ({ 0.6, 1, 1.6 })[difficulty] / 100) * 100,
		})
	end
	data.missions = { day = today(), list = list, bonusGiven = false }
end

function Game.ensureMissions(data: any)
	if data.missions.day ~= today() or #data.missions.list == 0 then
		newMissions(data)
	end
end

-- Suma a una estadística y al progreso de las misiones que la usan
function Game.addStat(session: Session, stat: string, amount: number)
	local data = session.data
	if data.stats[stat] ~= nil then
		data.stats[stat] += amount
	end
	Game.ensureMissions(data)
	for _, m in data.missions.list do
		if m.stat == stat and not m.claimed and m.progress < m.target then
			m.progress = math.min(m.target, m.progress + amount)
			if m.progress >= m.target then
				Game.notify(session.player, "goal", "n_mission_done")
			end
		end
	end
	session.dirty = true
end

function Game.goalValue(data: any, stat: string): number
	if stat == "planes" then
		return #data.planes
	elseif stat == "pilots" then
		return #data.pilots
	elseif stat == "regions" then
		return regionCount(data)
	elseif stat == "level" then
		return Game.level(data)
	end
	return data.stats[stat] or 0
end

---------------------------------------------------------------------
-- Tutorial (pasos en el servidor; el cliente dibuja las flechas)
-- 0 bienvenida · 1 despacha · 2 espera el aterrizaje · 3 compra avión · 4 ficha piloto
-- 5 reclama un objetivo · 99 terminado
---------------------------------------------------------------------
local function tutorialStep(session: Session, from: number, to: number)
	local data = session.data
	if data.tutorial ~= from then
		return
	end
	data.tutorial = to
	if to == 3 then
		data.money += 5000
		Game.notify(session.player, "money", "n_tutorial_gift", { amount = 5000 })
	elseif to == 99 then
		data.money += 10000
		Game.notify(session.player, "money", "n_tutorial_done", { amount = 10000 })
	end
	session.dirty = true
end

---------------------------------------------------------------------
-- Tablón de cargas
---------------------------------------------------------------------
-- Modelos para los que se generan cargas: los aviones en tierra en ese aeropuerto
local function modelsAt(data: any, at: string): { any }
	local seen, list = {}, {}
	for _, p in data.planes do
		if not p.flight and p.airport == at and not seen[p.model] then
			seen[p.model] = true
			table.insert(list, Config.PlaneById[p.model])
		end
	end
	if #list == 0 then
		for _, p in data.planes do
			if not seen[p.model] then
				seen[p.model] = true
				table.insert(list, Config.PlaneById[p.model])
			end
		end
	end
	return list
end

local function generateLoad(session: Session, from: string, model: any?): Load?
	local data = session.data
	local airport = Config.AirportByCode[from]
	local models = modelsAt(data, from)
	model = model or models[rng:NextInteger(1, #models)]
	local good
	if rng:NextNumber() < 0.65 then
		good = airport.goods[rng:NextInteger(1, #airport.goods)]
	else
		good = rng:NextNumber() < 0.6 and "parcel" or "mail"
	end
	local inRange, any = {}, {}
	for _, a in Config.Airports do
		if a.code ~= from and data.regions[a.region] then
			local d = Config.distance(from, a.code)
			table.insert(any, a.code)
			if d <= (model :: any).range and d >= 80 then
				table.insert(inRange, a.code)
			end
		end
	end
	local pool = (#inRange > 0 and rng:NextNumber() < 0.85) and inRange or any
	if #pool == 0 then
		return nil
	end
	local to = pool[rng:NextInteger(1, #pool)]
	local weight = math.max(0.2, math.floor((model :: any).cap * rng:NextNumber(0.35, 1) * 10 + 0.5) / 10)
	local dist = Config.distance(from, to)
	session.nextLoadId += 1
	return {
		id = session.nextLoadId, good = good, from = from, to = to, weight = weight, dist = dist,
		gross = Config.payout(weight, dist, Config.GoodById[good].mult),
	}
end

function Game.board(session: Session, code: string, force: boolean?): { Load }
	local b = session.boards[code]
	local now = os.time()
	if force or not b or b.expires <= now then
		local loads = {}
		for _ = 1, Config.BOARD_SIZE do
			local l = generateLoad(session, code)
			if l then
				table.insert(loads, l)
			end
		end
		-- El contrato exprés se mantiene aunque se renueve el tablón
		if session.express and session.express.from == code then
			table.insert(loads, 1, session.express)
		end
		b = { loads = loads, expires = now + Config.BOARD_TTL }
		session.boards[code] = b
	end
	local loads = (b :: any).loads
	-- Carga del tutorial: corta, rápida y bien pagada
	if session.data.tutorial <= 1 and code == Config.START_HUB and not (loads[1] and loads[1].tutorial) then
		session.nextLoadId += 1
		table.insert(loads, 1, {
			id = session.nextLoadId, good = "parcel", from = code, to = "VLC", weight = 0.8,
			dist = Config.distance(code, "VLC"), gross = 3000, tutorial = true,
		})
	end
	return loads
end

local function removeLoad(session: Session, code: string, id: number)
	local b = session.boards[code]
	if b then
		for i, l in b.loads do
			if l.id == id then
				table.remove(b.loads, i)
				break
			end
		end
	end
	if session.express and session.express.id == id then
		session.express = nil
	end
end

---------------------------------------------------------------------
-- Contratos exprés
---------------------------------------------------------------------
local function spawnExpress(session: Session)
	local data = session.data
	local idleAt = {}
	for _, p in data.planes do
		if not p.flight and p.condition >= Config.REPAIR_BLOCK then
			table.insert(idleAt, p)
		end
	end
	local plane = #idleAt > 0 and idleAt[rng:NextInteger(1, #idleAt)] or data.planes[rng:NextInteger(1, #data.planes)]
	local code = plane.flight and plane.flight.to or plane.airport
	local l = generateLoad(session, code, Config.PlaneById[plane.model])
	if not l then
		return
	end
	local load = l :: Load
	load.gross = math.floor(load.gross * Config.Express.mult)
	load.express = os.time() + Config.Express.lasts
	Game.board(session, code) -- primero el tablón (si se regenera, aún no incluye el exprés)
	session.express = load
	table.insert(session.boards[code].loads, 1, load)
	local a = Config.AirportByCode[code]
	Game.notify(session.player, "express", "n_express", { city = a.city, code = code, mult = Config.Express.mult })
end

local function tickExpress(session: Session, now: number)
	local ex = session.express
	if ex and (ex.express :: number) <= now then
		removeLoad(session, ex.from, ex.id)
		session.express = nil
	end
	if not session.express and now >= session.nextExpress and session.data.tutorial == 99 then
		session.nextExpress = now + rng:NextInteger(Config.Express.every[1], Config.Express.every[2])
		spawnExpress(session)
	end
end

---------------------------------------------------------------------
-- Vuelos
---------------------------------------------------------------------
function Game.canFly(session: Session, plane: any, load: Load): string?
	local data = session.data
	local model = Config.PlaneById[plane.model]
	local good = Config.GoodById[load.good]
	if plane.flight then
		return "err_plane_busy"
	elseif plane.condition < Config.REPAIR_BLOCK then
		return "err_needs_repair"
	elseif load.weight > model.cap then
		return "err_too_heavy"
	elseif load.dist > model.range then
		return "err_out_of_range"
	elseif good.cold and data.upgrades.cold < 1 then
		return "err_cold"
	end
	return nil
end

function Game.quote(session: Session, plane: any, load: Load, pilotId: number): (number, number, number, number)
	local data = session.data
	local model = Config.PlaneById[plane.model]
	local bonus = 0
	local pilot = pilotId > 0 and findPilot(data, pilotId)
	if pilot then
		bonus = Config.pilotBonus(pilot.stars, pilot.level)
	end
	local gross = math.floor(load.gross * (1 + 0.05 * data.upgrades.sales) * (1 + bonus) * Game.moneyMult(session))
	local fuel = math.floor(load.dist * model.burn * Game.fuelPrice(data))
	local fee = pilot and math.floor(gross * Config.PILOT_FEE) or 0
	local secs = load.tutorial and 15 or Config.flightSeconds(load.dist, model.speed, Game.timeMult(session))
	return gross, fuel, fee, secs
end

function Game.startFlight(session: Session, plane: any, load: Load, pilotId: number)
	local gross, fuel, fee, secs = Game.quote(session, plane, load, pilotId)
	local now = os.time()
	plane.flight = {
		from = load.from, to = load.to, good = load.good, weight = load.weight, dist = load.dist,
		gross = gross, fuel = fuel, fee = fee, pilot = pilotId, startT = now, endT = now + secs,
		express = load.express ~= nil,
	}
	removeLoad(session, load.from, load.id)
	tutorialStep(session, 1, 2)
	session.dirty = true
end

function Game.finishFlight(session: Session, plane: any, offline: boolean): number
	local data = session.data
	local f = plane.flight
	plane.flight = nil
	plane.airport = f.to
	plane.condition = math.max(0, math.floor((plane.condition - Config.wear(f.dist)) * 10 + 0.5) / 10)
	local net = f.gross - f.fuel - f.fee
	data.money += net
	local before = Game.level(data)
	local player = session.player
	if f.good ~= "ferry" then
		data.xp += Config.flightXp(f.gross)
		Game.addStat(session, "flights", 1)
		Game.addStat(session, "tons", f.weight)
		if f.good ~= "parcel" and f.good ~= "mail" then
			Game.addStat(session, "localGoods", 1)
		end
		if f.express then
			Game.addStat(session, "express", 1)
		end
		local pilot = f.pilot > 0 and findPilot(data, f.pilot)
		if pilot then
			pilot.flights += 1
			while pilot.level < Config.PILOT_MAX_LEVEL and pilot.flights >= Config.pilotXpForLevel(pilot.level + 1) do
				pilot.level += 1
				if not offline then
					Game.notify(player, "success", "n_pilot_level", { name = pilot.name, level = pilot.level })
				end
			end
		end
	end
	Game.addStat(session, "km", f.dist)
	if net > 0 then
		Game.addStat(session, "earned", net)
		session.earnedWindow += net
	end
	tutorialStep(session, 2, 3)
	if not offline then
		Game.notify(player, "landed", "n_landed", { code = f.to, net = net })
		local after = Game.level(data)
		if after > before then
			Game.notify(player, "level", "n_level_up", { level = after })
		end
	end
	session.dirty = true
	return net
end

---------------------------------------------------------------------
-- Pilotos: candidatos a la vista
---------------------------------------------------------------------
local function rollStars(): number
	local roll = rng:NextNumber(0, 100)
	for stars, chance in Config.StarChance do
		roll -= chance
		if roll <= 0 then
			return stars
		end
	end
	return 1
end

local function newPilot(data: any, stars: number): any
	local first = Config.FirstNames[rng:NextInteger(1, #Config.FirstNames)]
	local last = Config.LastNames[rng:NextInteger(1, #Config.LastNames)]
	local p = {
		id = data.nextId, name = first .. " " .. last, stars = stars, level = 1, flights = 0,
		avatar = Config.Avatars[rng:NextInteger(1, #Config.Avatars)],
	}
	data.nextId += 1
	return p
end

function Game.refreshCandidates(session: Session)
	local data = session.data
	local lvl = Game.level(data)
	data.candidates = {}
	for i = 1, Config.CANDIDATES do
		-- Durante el tutorial siempre hay uno barato de 1 estrella
		local stars = (data.tutorial < 99 and i == 1) and 1 or rollStars()
		local c = newPilot(data, stars)
		c.price = Config.candidatePrice(stars, lvl)
		table.insert(data.candidates, c)
	end
	data.candidatesAt = os.time()
	session.dirty = true
end

---------------------------------------------------------------------
-- Despacho automático: cada avión libre coge la carga con más beneficio
---------------------------------------------------------------------
function Game.autoDispatch(session: Session)
	local data = session.data
	if not data.settings.auto or not Game.autoUnlocked(session) then
		return
	end
	local free = {}
	for _, p in data.pilots do
		if not pilotBusy(data, p.id) then
			table.insert(free, p)
		end
	end
	table.sort(free, function(a, b)
		return Config.pilotBonus(a.stars, a.level) > Config.pilotBonus(b.stars, b.level)
	end)
	local youFree = not pilotBusy(data, 0)
	for _, plane in data.planes do
		if plane.flight or plane.condition < Config.REPAIR_BLOCK then
			continue
		end
		local pilotId
		if #free > 0 then
			pilotId = (table.remove(free, 1) :: any).id
		elseif youFree then
			pilotId = 0
			youFree = false
		else
			return
		end
		local best, bestNet = nil, 0
		for _, load in Game.board(session, plane.airport) do
			if not Game.canFly(session, plane, load) then
				local gross, fuel, fee = Game.quote(session, plane, load, pilotId)
				if gross - fuel - fee > bestNet then
					best, bestNet = load, gross - fuel - fee
				end
			end
		end
		if best then
			Game.startFlight(session, plane, best, pilotId)
		elseif pilotId == 0 then
			youFree = true
		else
			table.insert(free, 1, findPilot(data, pilotId) :: any)
		end
	end
end

---------------------------------------------------------------------
-- Ganancias offline (al entrar)
---------------------------------------------------------------------
function Game.onJoin(session: Session)
	local data = session.data
	local now = os.time()
	local landed, net = 0, 0
	for _, plane in data.planes do
		if plane.flight and plane.flight.endT <= now then
			net += Game.finishFlight(session, plane, true)
			landed += 1
		end
	end
	local offline = 0
	if data.lastOnline > 0 and data.settings.auto and Game.autoUnlocked(session) then
		local seconds = math.min(now - data.lastOnline, Config.OFFLINE_MAX_HOURS * 3600)
		offline = math.floor(data.rate * seconds * (session.passes.autopilot and 1 or Config.OFFLINE_RATE))
		data.money += offline
	end
	session.offlineLast = offline
	Game.ensureMissions(data)
	if now - data.candidatesAt >= Config.CANDIDATE_REFRESH or #data.candidates == 0 then
		Game.refreshCandidates(session)
	end
	if landed > 0 or offline > 0 then
		Game.notify(session.player, "welcome", "n_welcome_back", { landed = landed, net = net, offline = offline })
	end
end

---------------------------------------------------------------------
-- Bonus sociales: amigos en el servidor, Premium y grupo
---------------------------------------------------------------------
function Game.updateSocial()
	local list = Players:GetPlayers()
	for _, p in list do
		local session = Game.sessions[p]
		if session then
			local friends = 0
			for _, other in list do
				if other ~= p then
					local ok, isFriend = pcall(function()
						return p:IsFriendsWithAsync(other.UserId)
					end)
					if ok and isFriend then
						friends += 1
					end
				end
			end
			session.social.friends = friends
			session.social.premium = p.MembershipType == Enum.MembershipType.Premium
			if Config.GROUP_ID ~= 0 then
				local ok, inGroup = pcall(function()
					return p:IsInGroupAsync(Config.GROUP_ID)
				end)
				session.social.group = ok and inGroup == true
			end
		end
	end
end

---------------------------------------------------------------------
-- Tick de cada jugador (1 s)
---------------------------------------------------------------------
local lastRate = os.time()
function Game.tick(now: number)
	if now >= nextFuel then
		nextFuel = now + 300
		fuelMult = math.clamp(fuelMult + rng:NextNumber(-0.1, 0.1), 0.75, 1.25)
	end
	local rateTick = now - lastRate >= 60
	if rateTick then
		lastRate = now
	end
	for _, session in Game.sessions do
		local data = session.data
		for _, plane in data.planes do
			if plane.flight and plane.flight.endT <= now then
				Game.finishFlight(session, plane, false)
			end
		end
		tickExpress(session, now)
		Game.autoDispatch(session)
		if now - data.candidatesAt >= Config.CANDIDATE_REFRESH then
			Game.refreshCandidates(session)
		end
		Game.ensureMissions(data)
		if rateTick then
			local perSec = session.earnedWindow / 60
			session.incomePerMin = session.incomePerMin * 0.6 + perSec * 60 * 0.4
			if data.settings.auto then
				data.rate = data.rate * 0.7 + perSec * 0.3
			end
			session.earnedWindow = 0
		end
	end
end

---------------------------------------------------------------------
-- Dinero de los maletines de la tienda
---------------------------------------------------------------------
function Game.cashPack(session: Session, key: string): number
	local minutes = Config.CashPacks[key] or 10
	local perMin = math.max(session.incomePerMin, session.data.rate * 60, Config.rewardScale(Game.level(session.data)) / 4)
	return math.floor(perMin * minutes / 100) * 100
end

---------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------
type ActionFn = (Session, any, any, any) -> (boolean, string?, any?, any?)
local Actions: { [string]: ActionFn } = {}
Game.Actions = Actions

function Actions.dispatch(session, planeId, loadId, pilotId)
	local data = session.data
	if type(loadId) ~= "number" then
		return false, "err_generic"
	end
	pilotId = type(pilotId) == "number" and pilotId or 0
	local plane = findPlane(data, planeId)
	if not plane then
		return false, "err_generic"
	end
	local load
	for _, l in Game.board(session, plane.airport) do
		if l.id == loadId then
			load = l
			break
		end
	end
	if not load then
		return false, "err_load_gone"
	end
	local err = Game.canFly(session, plane, load)
	if err then
		return false, err
	end
	if pilotId > 0 then
		if not findPilot(data, pilotId) then
			return false, "err_generic"
		elseif pilotBusy(data, pilotId) then
			return false, "err_pilot_busy"
		end
	elseif pilotBusy(data, 0) then
		return false, "err_you_busy"
	end
	Game.startFlight(session, plane, load, pilotId)
	return true, nil, nil, { takeoff = plane.id }
end

function Actions.ferry(session, planeId, to)
	local data = session.data
	local plane = findPlane(data, planeId)
	local dest = if type(to) == "string" then Config.AirportByCode[to] else nil
	if not plane or not dest or dest.code == plane.airport or not data.regions[dest.region] then
		return false, "err_generic"
	elseif plane.flight then
		return false, "err_plane_busy"
	elseif plane.condition < Config.REPAIR_BLOCK then
		return false, "err_needs_repair"
	end
	local model = Config.PlaneById[plane.model]
	local dist = Config.distance(plane.airport, dest.code)
	if dist > model.range then
		return false, "err_out_of_range"
	end
	local now = os.time()
	plane.flight = {
		from = plane.airport, to = dest.code, good = "ferry", weight = 0, dist = dist, gross = 0,
		fuel = math.floor(dist * model.burn * Game.fuelPrice(data)), fee = 0, pilot = -1, startT = now,
		endT = now + Config.flightSeconds(dist, model.speed, Game.timeMult(session)), express = false,
	}
	session.dirty = true
	return true, "n_ferry", { city = dest.city }
end

function Actions.refreshBoard(session, code)
	if type(code) ~= "string" or not Config.AirportByCode[code] then
		return false, "err_generic"
	end
	local now = os.time()
	if (session.refreshAt[code] or 0) > now then
		return false, "err_cooldown", { s = session.refreshAt[code] - now }
	end
	session.refreshAt[code] = now + Config.REFRESH_COOLDOWN
	Game.board(session, code, true)
	return true
end

function Actions.buyPlane(session, modelId)
	local data = session.data
	local model = if type(modelId) == "string" then Config.PlaneById[modelId] else nil
	if not model then
		return false, "err_generic"
	elseif Game.level(data) < model.level then
		return false, "err_level", { level = model.level }
	elseif #data.planes >= Game.maxPlanes(session) then
		return false, "err_hangar_full"
	elseif data.money < model.price then
		return false, "err_money"
	end
	data.money -= model.price
	-- El avión nuevo aparece donde tienes más aviones (tu base)
	local count, hq = {}, Config.START_HUB
	for _, p in data.planes do
		local at = p.flight and p.flight.to or p.airport
		count[at] = (count[at] or 0) + 1
		if count[at] > (count[hq] or 0) then
			hq = at
		end
	end
	table.insert(data.planes, { id = data.nextId, model = model.id, airport = hq, condition = 100 })
	data.nextId += 1
	Game.addStat(session, "purchases", 1)
	tutorialStep(session, 3, 4)
	if model.level >= 9 then
		Game.notifyAll("feed", "n_feed_plane", { player = session.player.DisplayName, plane = model.id })
	end
	return true, "n_bought", { plane = model.id }, { money = true }
end

function Actions.sellPlane(session, planeId)
	local data = session.data
	if #data.planes <= 1 then
		return false, "err_last_plane"
	end
	for i, p in data.planes do
		if p.id == planeId then
			if p.flight then
				return false, "err_plane_busy"
			end
			local value = Config.sellPrice(Config.PlaneById[p.model].price, p.condition)
			data.money += value
			table.remove(data.planes, i)
			session.dirty = true
			return true, "n_sold", { value = value }
		end
	end
	return false, "err_generic"
end

function Actions.repair(session, planeId)
	local data = session.data
	local plane = findPlane(data, planeId)
	if not plane then
		return false, "err_generic"
	elseif plane.flight then
		return false, "err_plane_busy"
	end
	local cost = Config.repairCost(Config.PlaneById[plane.model].price, plane.condition)
	if cost <= 0 then
		return false, "err_no_repair"
	elseif data.money < cost then
		return false, "err_money"
	end
	data.money -= cost
	plane.condition = 100
	session.dirty = true
	return true, "n_repaired"
end

function Actions.hire(session, candidateId)
	local data = session.data
	for i, c in data.candidates do
		if c.id == candidateId then
			if #data.pilots >= Config.MAX_PILOTS then
				return false, "err_roster_full"
			elseif data.money < c.price then
				return false, "err_money"
			end
			data.money -= c.price
			table.remove(data.candidates, i)
			c.price = nil
			table.insert(data.pilots, c)
			Game.addStat(session, "purchases", 1)
			tutorialStep(session, 4, 5)
			if c.stars >= 5 then
				Game.notifyAll("feed", "n_feed_pilot", { player = session.player.DisplayName, name = c.name })
			end
			return true, "n_hired", { name = c.name }, { pilot = c }
		end
	end
	return false, "err_generic"
end

function Actions.searchCandidates(session)
	local data = session.data
	local cost = Config.searchCost(Game.level(data))
	if data.money < cost then
		return false, "err_money"
	end
	data.money -= cost
	Game.refreshCandidates(session)
	return true
end

function Actions.firePilot(session, pilotId)
	local data = session.data
	for i, p in data.pilots do
		if p.id == pilotId then
			if pilotBusy(data, p.id) then
				return false, "err_pilot_busy"
			end
			table.remove(data.pilots, i)
			session.dirty = true
			return true, "n_fired", { name = p.name }
		end
	end
	return false, "err_generic"
end

function Actions.buyRegion(session, regionId)
	local data = session.data
	local r = if type(regionId) == "string" then Config.RegionById[regionId] else nil
	if not r then
		return false, "err_generic"
	elseif data.regions[r.id] then
		return false, "err_owned"
	elseif Game.level(data) < r.level then
		return false, "err_level", { level = r.level }
	elseif data.money < r.cost then
		return false, "err_money"
	end
	data.money -= r.cost
	data.regions[r.id] = true
	session.boards = {} -- los destinos nuevos aparecen ya
	Game.addStat(session, "purchases", 1)
	Game.notifyAll("feed", "n_feed_region", { player = session.player.DisplayName, region = r.id })
	return true, "n_region", { region = r.id }, { region = r.id }
end

function Actions.buyUpgrade(session, upgradeId)
	local data = session.data
	local up = if type(upgradeId) == "string" then Config.UpgradeById[upgradeId] else nil
	if not up then
		return false, "err_generic"
	end
	local lvl = data.upgrades[up.id]
	if lvl >= up.max then
		return false, "err_maxed"
	elseif Game.level(data) < up.level then
		return false, "err_level", { level = up.level }
	end
	local cost = Config.upgradeCost(up.id, lvl)
	if data.money < cost then
		return false, "err_money"
	end
	data.money -= cost
	data.upgrades[up.id] = lvl + 1
	Game.addStat(session, "purchases", 1)
	return true, "n_upgrade", { upgrade = up.id }, { money = true }
end

function Actions.setAuto(session, on)
	if on and not Game.autoUnlocked(session) then
		return false, "err_level", { level = Config.AUTO_DISPATCH_LEVEL }
	end
	session.data.settings.auto = on == true
	return true
end

function Actions.setLang(session, lang)
	if lang ~= "" and lang ~= "en" and lang ~= "es" then
		return false, "err_generic"
	end
	session.data.settings.lang = lang
	return true
end

function Actions.setMuted(session, muted)
	session.data.settings.muted = muted == true
	return true
end

function Actions.claimDaily(session)
	local data = session.data
	local day = today()
	if data.daily.last == day then
		return false, "err_daily_done"
	end
	if data.daily.last < day - 1 then
		data.daily.streak = 0
	end
	data.daily.streak = data.daily.streak % #Config.DailyRewards + 1
	data.daily.last = day
	local amount = math.floor(Config.rewardScale(Game.level(data)) * Config.DailyRewards[data.daily.streak])
	data.money += amount
	if data.daily.streak == #Config.DailyRewards then
		data.boostUntil = math.max(os.time(), data.boostUntil) + 1800
	end
	session.dirty = true
	return true, "n_daily", { amount = amount, day = data.daily.streak }, { money = true }
end

function Actions.claimMission(session, index)
	local data = session.data
	Game.ensureMissions(data)
	local m = type(index) == "number" and data.missions.list[index]
	if not m then
		return false, "err_generic"
	elseif m.claimed then
		return false, "err_owned"
	elseif m.progress < m.target then
		return false, "err_not_done"
	end
	m.claimed = true
	data.money += m.reward
	local all = true
	for _, x in data.missions.list do
		all = all and x.claimed
	end
	if all and not data.missions.bonusGiven then
		data.missions.bonusGiven = true
		data.boostUntil = math.max(os.time(), data.boostUntil) + Config.MISSIONS_BOOST_MIN * 60
		Game.notify(session.player, "goal", "n_missions_bonus", { min = Config.MISSIONS_BOOST_MIN })
	end
	session.dirty = true
	return true, "n_claimed", { amount = m.reward }, { money = true }
end

function Actions.claimGoal(session, goalId)
	local data = session.data
	for _, g in Config.Goals do
		if g.id == goalId then
			if data.goals[g.id] then
				return false, "err_owned"
			elseif Game.goalValue(data, g.stat) < g.target then
				return false, "err_not_done"
			end
			data.goals[g.id] = true
			local amount = math.floor(Config.rewardScale(Game.level(data)) * g.reward / 100) * 100
			data.money += amount
			tutorialStep(session, 5, 99)
			session.dirty = true
			return true, "n_claimed", { amount = amount }, { money = true }
		end
	end
	return false, "err_generic"
end

function Actions.tutorial(session, op)
	local data = session.data
	if op == "start" and data.tutorial == 0 then
		data.tutorial = 1
	elseif op == "skip" then
		data.tutorial = 99
	end
	session.dirty = true
	return true
end

return Game
