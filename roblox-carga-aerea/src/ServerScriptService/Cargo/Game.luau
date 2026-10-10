--!strict
-- Lógica del juego en el servidor. Las acciones devuelven (ok, claveDeTexto?, parámetros?, extra?)
-- y los avisos se mandan como claves de Lang.luau: el cliente las traduce.
-- Las fórmulas de pago están en ReplicatedStorage/Rules.luau (las mismas que usa el cliente).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))

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
	sat: { [string]: number }, -- saturación por destino (vuelos recientes)
}
Game.sessions = {} :: { [Player]: Session }

local rng = Random.new()
local fuelMult = 1
local nextFuel = os.time() + Config.FUEL_PERIOD
Game.fuelHistory = { 1, 1, 1, 1, 1, 1, 1, 1 } :: { number } -- últimos precios (multiplicador) para la gráfica

-- Mundo compartido: evento de España y ciudades en auge (iguales en todos los servidores)
Game.world = {
	event = nil :: Config.EventDef?,
	eventLeft = 0,
	wanted = {} :: { [string]: number },
	wantedList = {} :: { { code: string, mult: number } },
	wantedLeft = 0,
}

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

-- Nivel efectivo del despachador (el pase Piloto automático equivale al nivel 1)
function Game.dispatcher(session: Session): number
	local lvl = session.data.staff.dispatcher or 0
	if session.passes.autopilot then
		lvl = math.max(lvl, 1)
	end
	return lvl
end

function Game.autoUnlocked(session: Session): boolean
	return Game.dispatcher(session) >= 1
end

function Game.tankCapacity(data: any): number
	return Config.tankCapacity(data.upgrades.tank or 0)
end

function Game.addRep(data: any, amount: number)
	data.rep = math.clamp(math.floor((data.rep + amount) * 100 + 0.5) / 100, 0, 100)
end

function Game.fuelNextIn(now: number): number
	return math.max(0, nextFuel - now)
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

-- Ventaja n.º i de salir a bolsa (se activa en la salida i)
function Game.hasPerk(data: any, perk: string): boolean
	local i = table.find(Config.IpoPerks, perk)
	return i ~= nil and data.ipoCount >= i
end

-- Multiplicador de dinero: bonus sociales × pase VIP × boost × acciones
function Game.moneyMult(session: Session): number
	local s = session.social
	local social = 1 + 0.1 * math.min(s.friends, 4) + (s.premium and 0.1 or 0) + (s.group and 0.1 or 0)
	local shares = 1 + Config.SHARE_BONUS * session.data.shares
	return social * (session.passes.vip and 2 or 1) * (Game.boostActive(session.data) and 2 or 1) * shares
end

-- Las acciones de bolsa también dan XP extra (así cada partida nueva va más rápida)
function Game.xpMult(data: any): number
	return 1 + Config.SHARE_XP_BONUS * data.shares
end

function Game.timeMult(session: Session): number
	return (1 - 0.08 * session.data.upgrades.fast) * (session.passes.turbo and 0.75 or 1)
end

function Game.contractSlots(data: any): number
	return Config.CONTRACT_SLOTS + (Game.hasPerk(data, "contract") and 1 or 0)
end

-- Ingresos de referencia por minuto (para premios que no se queden pequeños)
function Game.incomeBase(session: Session): number
	return math.max(session.incomePerMin, session.data.rate * 60, Config.rewardScale(Game.level(session.data)) / 4)
end

-- Base de premios: crece con el nivel y con lo que ganas de verdad
function Game.rewardBase(session: Session): number
	return math.floor(math.max(Config.rewardScale(Game.level(session.data)), Game.incomeBase(session) * 2) / 100) * 100
end

---------------------------------------------------------------------
-- Mundo: eventos y ciudades en auge
---------------------------------------------------------------------
function Game.updateWorld(now: number)
	local w = Game.world
	local before = w.event
	w.event, w.eventLeft = Rules.eventAt(now)
	if w.event and w.event ~= before then
		Game.notifyAll("event", "n_event", { event = w.event.id })
	end
	local list, left = Rules.wantedAt(now)
	w.wantedList, w.wantedLeft = list, left
	local map = {}
	for _, x in list do
		map[x.code] = x.mult
	end
	w.wanted = map
end
Game.updateWorld(os.time())

function Game.satMap(session: Session): { [string]: number }
	local out = {}
	for code, level in session.sat do
		local m = Rules.satMult(level)
		if m < 1 then
			out[code] = m
		end
	end
	return out
end

-- Lo que necesita Rules.quote
function Game.view(session: Session): Rules.View
	local data = session.data
	return {
		upgrades = data.upgrades,
		moneyMult = Game.moneyMult(session),
		fuelPrice = Game.fuelPrice(data),
		timeMult = Game.timeMult(session),
		event = Game.world.event and Game.world.event.id or nil,
		wanted = Game.world.wanted,
		sat = Game.satMap(session),
		album = data.album,
		pending = Rules.pendingStamps(data.planes, data.album),
		rep = data.rep,
		fuel = data.fuel,
	}
end

---------------------------------------------------------------------
-- Estadísticas, misiones y objetivos
---------------------------------------------------------------------
local function newMissions(session: Session)
	local data = session.data
	local level = Game.level(data)
	local pool = {}
	for _, def in Config.MissionPool do
		if level >= (def.level or 1) then
			table.insert(pool, def)
		end
	end
	local list = {}
	local scale = Config.rewardScale(level)
	local base = Game.rewardBase(session)
	for difficulty = 1, 3 do
		local def = table.remove(pool, rng:NextInteger(1, #pool)) :: any
		local target = def.goal[difficulty]
		if def.stat == "earned" then
			target *= math.max(scale, math.floor(Game.incomeBase(session) / 100) * 100)
		end
		table.insert(list, {
			id = def.id, stat = def.stat, target = target, progress = 0, claimed = false,
			reward = math.floor(base * def.reward * ({ 0.6, 1, 1.6 })[difficulty] / 100) * 100,
		})
	end
	data.missions = { day = today(), list = list, bonusGiven = false }
end

function Game.ensureMissions(session: Session)
	local data = session.data
	if data.missions.day ~= today() or #data.missions.list == 0 then
		newMissions(session)
	end
end

-- Suma a una estadística y al progreso de las misiones que la usan
function Game.addStat(session: Session, stat: string, amount: number)
	local data = session.data
	if data.stats[stat] ~= nil then
		data.stats[stat] += amount
	end
	Game.ensureMissions(session)
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
	elseif stat == "stamps" then
		return (Rules.stamps(data.album))
	elseif stat == "ipo" then
		return data.ipoCount
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

-- Producto de una carga: típico del aeropuerto (con preferencia por los de eventos y contratos)
local function pickGood(data: any, airport: any): string
	local favored = {}
	local e = Game.world.event
	for _, g in airport.goods do
		if e and e.goods and table.find(e.goods, g) then
			table.insert(favored, g)
		end
		for _, c in data.contracts.active do
			if c.good == g then
				table.insert(favored, g)
			end
		end
	end
	if #favored > 0 and rng:NextNumber() < 0.45 then
		return favored[rng:NextInteger(1, #favored)]
	end
	if rng:NextNumber() < 0.65 then
		return airport.goods[rng:NextInteger(1, #airport.goods)]
	end
	return rng:NextNumber() < 0.6 and "parcel" or "mail"
end

local function generateLoad(session: Session, from: string, model: any?): Load?
	local data = session.data
	local airport = Config.AirportByCode[from]
	local models = modelsAt(data, from)
	model = model or models[rng:NextInteger(1, #models)]
	local range = (model :: any).range
	local good = pickGood(data, airport)
	local inRange, any, hot = {}, {}, {}
	local e = Game.world.event
	for _, a in Config.Airports do
		if a.code ~= from and data.regions[a.region] then
			local d = Config.distance(from, a.code)
			table.insert(any, a.code)
			if d <= range and d >= 80 then
				table.insert(inRange, a.code)
				-- Destinos «calientes»: en auge, del evento o de un contrato de este producto
				local isHot = Game.world.wanted[a.code] ~= nil or (e ~= nil and e.to ~= nil and table.find(e.to, a.code) ~= nil)
				for _, c in data.contracts.active do
					if c.good == good and c.region == a.region then
						isHot = true
					end
				end
				if isHot then
					table.insert(hot, a.code)
				end
			end
		end
	end
	local pool = (#inRange > 0 and rng:NextNumber() < 0.85) and inRange or any
	if #hot > 0 and rng:NextNumber() < 0.35 then
		pool = hot
	end
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
	if session.data.tutorial == 1 and code == Config.START_HUB and not (loads[1] and loads[1].tutorial) then
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
	if plane.flight and plane.flight.good == "charter" then
		return
	end
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
-- Contratos con empresas
---------------------------------------------------------------------
local function newOffer(session: Session): any?
	local data = session.data
	local level = Game.level(data)
	-- Productos que puedes recoger (de aeropuertos en tus regiones) y que tienen empresa
	local goods, seen = {}, {}
	for _, a in Config.Airports do
		if data.regions[a.region] then
			for _, g in a.goods do
				local good = Config.GoodById[g]
				if not seen[g] and Config.CompanyByGood[g] and (not good.cold or data.upgrades.cold > 0) then
					seen[g] = true
					table.insert(goods, g)
				end
			end
		end
	end
	-- Destinos: tus regiones (Canarias solo si algún avión llega)
	local reach = 0
	for _, p in data.planes do
		reach = math.max(reach, Config.PlaneById[p.model].range)
	end
	local regions = {}
	for _, r in Config.Regions do
		if data.regions[r.id] and (r.id ~= "CAN" or reach >= 2200) then
			table.insert(regions, r.id)
		end
	end
	if #goods == 0 or #regions == 0 then
		return nil
	end
	local good = goods[rng:NextInteger(1, #goods)]
	local count = Config.contractSize(level)
	-- Los productos más caros dan contratos mejor pagados
	local minutes = (count * 2.5 + 4) * (0.6 + 0.4 * Config.GoodById[good].mult)
	local id = data.nextId
	data.nextId += 1
	return {
		id = id, company = Config.CompanyByGood[good].id, good = good,
		region = regions[rng:NextInteger(1, #regions)], count = count,
		secs = count * Config.CONTRACT_SECS_PER_LOAD,
		-- La reputación mejora (o empeora) lo que pagan las empresas
		reward = math.floor(minutes * Game.incomeBase(session) * (0.8 + 0.4 * data.rep / 100) / 100) * 100,
	}
end

function Game.refreshOffers(session: Session)
	local c = session.data.contracts
	c.offers = {}
	for _ = 1, Config.CONTRACT_OFFERS do
		local o = newOffer(session)
		if o then
			table.insert(c.offers, o)
		end
	end
	c.nextAt = os.time() + Config.CONTRACT_REFRESH
	session.dirty = true
end

local function tickContracts(session: Session, now: number)
	local data = session.data
	if Game.level(data) < Config.CONTRACT_LEVEL or data.tutorial ~= 99 then
		return
	end
	local c = data.contracts
	if now >= c.nextAt then
		Game.refreshOffers(session)
	end
	for i = #c.active, 1, -1 do
		local x = c.active[i]
		if now >= x.expires then
			table.remove(c.active, i)
			Game.addRep(data, Config.Rep.contractFailed)
			Game.notify(session.player, "error", "n_contract_failed", { company = x.company })
			session.dirty = true
		end
	end
end

-- Una entrega cuenta para los contratos activos de ese producto y región
local function contractDelivery(session: Session, good: string, to: string, landedAt: number)
	local data = session.data
	local airport = Config.AirportByCode[to]
	for i = #data.contracts.active, 1, -1 do
		local x = data.contracts.active[i]
		if x.good == good and airport and airport.region == x.region and landedAt <= x.expires then
			x.progress += 1
			if x.progress >= x.count then
				table.remove(data.contracts.active, i)
				data.money += x.reward
				data.xp += math.floor(Config.flightXp(x.reward) * Game.xpMult(data))
				Game.addStat(session, "contracts", 1)
				Game.addRep(data, Config.Rep.contract)
				Game.notify(session.player, "goal", "n_contract_done", { company = x.company, amount = x.reward })
			end
		end
	end
end

---------------------------------------------------------------------
-- Vuelos
---------------------------------------------------------------------
function Game.canFly(session: Session, plane: any, load: Load): string?
	return Rules.canFly(Game.view(session), plane, load)
end

function Game.quote(session: Session, plane: any, load: Load, pilotId: number): (number, number, number, number, number)
	local pilot = pilotId > 0 and findPilot(session.data, pilotId) or nil
	local gross, fuel, fee, secs, _, litres = Rules.quote(Game.view(session), plane, load, pilot)
	return gross, fuel, fee, secs, litres
end

-- Gasta combustible del depósito y avisa si queda poco
local function useFuel(session: Session, litres: number)
	local data = session.data
	local cap = Game.tankCapacity(data)
	local before = data.fuel
	data.fuel = math.max(0, data.fuel - litres)
	if before >= cap * Config.FUEL_LOW and data.fuel < cap * Config.FUEL_LOW then
		Game.notify(session.player, "error", "n_fuel_low")
	end
end

function Game.startFlight(session: Session, plane: any, load: Load, pilotId: number)
	local gross, fuel, fee, secs, litres = Game.quote(session, plane, load, pilotId)
	local now = os.time()
	plane.flight = {
		from = load.from, to = load.to, good = load.good, weight = load.weight, dist = load.dist,
		gross = gross, fuel = fuel, fee = fee, pilot = pilotId, startT = now, endT = now + secs,
		express = load.express ~= nil, litres = litres,
	}
	useFuel(session, litres)
	-- Cuantos más vuelos recientes al mismo sitio, menos paga el siguiente
	session.sat[load.to] = (session.sat[load.to] or 0) + 1
	removeLoad(session, load.from, load.id)
	tutorialStep(session, 1, 2)
	session.dirty = true
end

-- Dinero ganado (cuenta para el ranking, la semana y salir a bolsa).
-- countRate = false para chárter y aterrizajes offline: no deben inflar «ingresos por minuto»
-- (de ahí salen el pago del siguiente chárter, contratos, premios y lo offline)
local function earned(session: Session, net: number, countRate: boolean)
	local data = session.data
	Game.addStat(session, "earned", net)
	if countRate then
		session.earnedWindow += net
	end
	data.run.earned += net
	local week = math.floor((os.time() - 345600) / 604800)
	if data.week.id ~= week then
		data.week = { id = week, earned = 0 }
	end
	data.week.earned += net
end

function Game.finishFlight(session: Session, plane: any, offline: boolean): number
	local data = session.data
	local f = plane.flight
	plane.flight = nil
	plane.airport = f.to
	local player = session.player
	local before = Game.level(data)
	if f.good == "charter" then
		plane.condition = math.max(0, plane.condition - 8)
		data.money += f.gross
		data.xp += math.floor(Config.flightXp(f.gross) * Game.xpMult(data))
		Game.addStat(session, "charters", 1)
		earned(session, f.gross, false)
		if not offline then
			Game.notify(player, "landed", "n_landed", { code = f.to, net = f.gross, charter = true })
		end
		session.dirty = true
		return f.gross
	end
	plane.condition = math.max(0, math.floor((plane.condition - Config.wear(f.dist)) * 10 + 0.5) / 10)
	-- Aterrizaje perfecto (solo si volabas tú y pulsaste a tiempo)
	local bonus = 0
	if f.landing then
		bonus = math.floor(f.gross * ((f.landing == "perfect" and Config.LANDING.perfect or Config.LANDING.good) - 1))
		if f.landing == "perfect" then
			Game.addStat(session, "perfect", 1)
		end
	end
	-- El combustible ya se pagó al comprarlo (depósito): se cobra el pago menos la comisión del piloto.
	-- Para estadísticas y ritmo se descuenta el valor del combustible gastado.
	-- (Vuelos de antes de la v0.4 sin «litres»: pagaban el combustible al aterrizar.)
	local cash = f.gross + bonus - f.fee - (if f.litres then 0 else f.fuel)
	local net = cash - (if f.litres then f.fuel else 0)
	data.money += cash
	if f.good ~= "ferry" then
		Game.addRep(data, Config.Rep.flight + (f.express and Config.Rep.express or 0) + (f.landing == "perfect" and Config.Rep.perfect or 0))
		data.xp += math.floor(Config.flightXp(f.gross) * Game.xpMult(data))
		Game.addStat(session, "flights", 1)
		Game.addStat(session, "tons", f.weight)
		if f.good ~= "parcel" and f.good ~= "mail" then
			Game.addStat(session, "localGoods", 1)
		end
		if f.express then
			Game.addStat(session, "express", 1)
		end
		-- Pasaporte: sello del aeropuerto y medalla del producto
		local album = data.album
		if not album.airports[f.to] then
			album.airports[f.to] = true
			Game.addStat(session, "newRoutes", 1)
			if not offline then
				Game.notify(player, "goal", "n_stamp", { city = Config.AirportByCode[f.to].city })
			end
			local region = Config.AirportByCode[f.to].region
			if Rules.regionComplete(album.airports, region) and not offline then
				Game.notify(player, "goal", "n_region_stamps", { region = region })
			end
		end
		local medalsBefore = Rules.medals(album.goods[f.good] or 0)
		album.goods[f.good] = (album.goods[f.good] or 0) + 1
		-- Solo se avisa de plata y oro (el bronce llega con la primera entrega y sería demasiado ruido)
		if Rules.medals(album.goods[f.good]) > medalsBefore and medalsBefore >= 1 and not offline then
			Game.notify(player, "goal", "n_medal", { good = f.good, n = Rules.medals(album.goods[f.good]) })
		end
		contractDelivery(session, f.good, f.to, f.endT)
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
		earned(session, net, not offline)
	end
	tutorialStep(session, 2, 3)
	if not offline then
		Game.notify(player, "landed", "n_landed", { code = f.to, net = cash, landing = f.landing })
		local after = Game.level(data)
		if after > before then
			Game.notify(player, "level", "n_level_up", { level = after })
		end
	end
	session.dirty = true
	return cash
end

---------------------------------------------------------------------
-- Pilotos: candidatos a la vista (con su rasgo)
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

local function randomTrait(): string
	local list = {}
	for _, t in Config.Traits do
		if not t.special then
			table.insert(list, t.id)
		end
	end
	return list[rng:NextInteger(1, #list)]
end

function Game.newPilot(data: any, stars: number, trait: string?): any
	local first = Config.FirstNames[rng:NextInteger(1, #Config.FirstNames)]
	local last = Config.LastNames[rng:NextInteger(1, #Config.LastNames)]
	local p = {
		id = data.nextId, name = first .. " " .. last, stars = stars, level = 1, flights = 0,
		avatar = Config.Avatars[rng:NextInteger(1, #Config.Avatars)], trait = trait or randomTrait(),
	}
	data.nextId += 1
	return p
end

function Game.refreshCandidates(session: Session)
	local data = session.data
	local lvl = Game.level(data)
	data.candidates = {}
	for i = 1, Config.CANDIDATES + (Game.hasPerk(data, "candidate") and 1 or 0) do
		-- Durante el tutorial siempre hay uno barato de 1 estrella
		local stars = (data.tutorial < 99 and i == 1) and 1 or rollStars()
		local c = Game.newPilot(data, stars)
		c.price = Config.candidatePrice(stars, lvl)
		table.insert(data.candidates, c)
	end
	-- Mecánicos candidatos (estrellas visibles antes de contratar)
	data.mechCandidates = {}
	for _ = 1, Config.MECH_CANDIDATES do
		local roll, stars = rng:NextNumber(0, 100), 1
		for st, chance in Config.MechStarChance do
			roll -= chance
			if roll <= 0 then
				stars = st
				break
			end
		end
		local first = Config.FirstNames[rng:NextInteger(1, #Config.FirstNames)]
		local last = Config.LastNames[rng:NextInteger(1, #Config.LastNames)]
		table.insert(data.mechCandidates, {
			id = data.nextId, name = first .. " " .. last, stars = stars,
			avatar = Config.MechAvatars[rng:NextInteger(1, #Config.MechAvatars)], price = Config.mechPrice(stars, lvl),
		})
		data.nextId += 1
	end
	data.candidatesAt = os.time()
	session.dirty = true
end

-- Los mecánicos reparan gratis los aviones en tierra (cada uno, el más estropeado que quede)
function Game.tickMechanics(session: Session)
	local data = session.data
	if #data.mechanics == 0 then
		return
	end
	local grounded = {}
	for _, p in data.planes do
		if not p.flight and p.condition < 100 then
			table.insert(grounded, p)
		end
	end
	table.sort(grounded, function(a, b)
		return a.condition < b.condition
	end)
	local mechs = table.clone(data.mechanics)
	table.sort(mechs, function(a: any, b: any)
		return a.stars > b.stars
	end)
	for i, m in mechs do
		local p = grounded[i]
		if not p then
			break
		end
		p.condition = math.min(100, math.floor((p.condition + Config.mechRate(m.stars)) * 100 + 0.5) / 100)
		session.dirty = true
	end
end

-- Compra combustible al precio de ahora: devuelve los litros comprados
function Game.buyFuel(session: Session, litres: number): (number, number)
	local data = session.data
	local price = Game.fuelPrice(data)
	local room = Game.tankCapacity(data) - data.fuel
	local amount = math.floor(math.min(litres, room, data.money / price))
	if amount < 1 then
		return 0, 0
	end
	local cost = math.ceil(amount * price)
	data.money -= cost
	data.fuel += amount
	session.dirty = true
	return amount, cost
end

---------------------------------------------------------------------
-- Despacho automático: los mejores pilotos a los aviones más grandes; cada uno coge la carga
-- con más beneficio (no tiene en cuenta contratos ni aterrizajes perfectos: jugar a mano rinde más)
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
	local planes = {}
	for _, plane in data.planes do
		if not plane.flight and plane.condition >= Config.REPAIR_BLOCK then
			table.insert(planes, plane)
		end
	end
	table.sort(planes, function(a, b)
		return Config.PlaneById[a.model].cap > Config.PlaneById[b.model].cap
	end)
	local youFree = not pilotBusy(data, 0)
	local dispatcher = Game.dispatcher(session)
	-- Despachador nivel 2+: si queda poco combustible, llena el depósito
	if dispatcher >= 2 and data.fuel < Game.tankCapacity(data) * 0.3 then
		Game.buyFuel(session, math.huge)
	end
	local view = Game.view(session)
	for _, plane in planes do
		local pilotId
		if #free > 0 then
			pilotId = (table.remove(free, 1) :: any).id
		elseif youFree then
			pilotId = 0
			youFree = false
		else
			return
		end
		local pilot = pilotId > 0 and findPilot(data, pilotId) or nil
		local best, bestNet = nil, 0
		for _, load in Game.board(session, plane.airport) do
			if not Rules.canFly(view, plane, load) then
				local gross, fuel, fee = Rules.quote(view, plane, load, pilot)
				local value = gross - fuel - fee
				-- Despachador nivel 3: primero contratos y exprés
				if dispatcher >= 3 and value > 0 then
					local dest = Config.AirportByCode[load.to]
					for _, c in data.contracts.active do
						if c.good == load.good and dest.region == c.region then
							value *= 1.6
						end
					end
					if load.express then
						value *= 1.4
					end
				end
				if value > bestNet then
					best, bestNet = load, value
				end
			end
		end
		if best then
			Game.startFlight(session, plane, best, pilotId)
			view.sat = Game.satMap(session)
			view.fuel = data.fuel
			view.pending = Rules.pendingStamps(data.planes, data.album)
		elseif pilotId == 0 then
			youFree = true
		else
			table.insert(free, 1, pilot :: any)
		end
	end
end

---------------------------------------------------------------------
-- Ganancias offline y migraciones (al entrar)
---------------------------------------------------------------------
-- Parte de lo que gana tu flota mientras no juegas: 100 % con el pase, 75 % con el despachador nivel 3, si no 50 %
function Game.offlineRate(session: Session): number
	if session.passes.autopilot then
		return 1
	elseif Game.dispatcher(session) >= 3 then
		return 0.75
	end
	return Config.OFFLINE_RATE
end

function Game.onJoin(session: Session)
	local data = session.data
	local now = os.time()
	-- Partidas de la v0.2: los pilotos no tenían rasgo
	for _, list in { data.pilots, data.candidates } do
		for _, p in list do
			if not p.trait then
				local normal = {}
				for _, t in Config.Traits do
					if not t.special then
						table.insert(normal, t.id)
					end
				end
				p.trait = normal[p.id % #normal + 1]
			end
		end
	end
	-- Partidas anteriores a la v0.4: depósito lleno y, si ya tenían el despacho automático (nivel 5), despachador
	if data.migrateV4 then
		data.migrateV4 = nil
		data.fuel = Game.tankCapacity(data)
		if Game.level(data) >= Config.AUTO_DISPATCH_LEVEL then
			data.staff.dispatcher = math.max(data.staff.dispatcher, 1)
		end
		session.dirty = true
	end
	data.fuel = math.min(data.fuel, Game.tankCapacity(data))
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
		offline = math.floor(data.rate * seconds * Game.offlineRate(session))
		data.money += offline
	end
	session.offlineLast = offline
	Game.ensureMissions(session)
	if now - data.candidatesAt >= Config.CANDIDATE_REFRESH or #data.candidates == 0 then
		Game.refreshCandidates(session)
	end
	tickContracts(session, now)
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
		nextFuel = now + Config.FUEL_PERIOD
		fuelMult = math.clamp(math.floor((fuelMult + rng:NextNumber(-0.12, 0.12)) * 100 + 0.5) / 100, 0.75, 1.25)
		table.remove(Game.fuelHistory, 1)
		table.insert(Game.fuelHistory, fuelMult)
	end
	Game.updateWorld(now)
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
		-- La saturación se recupera poco a poco
		for code, level in session.sat do
			local left = level - 1 / Config.SAT_DECAY
			if left > 0 then
				session.sat[code] = left
			else
				session.sat[code] = nil
			end
		end
		tickExpress(session, now)
		tickContracts(session, now)
		Game.tickMechanics(session)
		Game.autoDispatch(session)
		if now - data.candidatesAt >= Config.CANDIDATE_REFRESH then
			Game.refreshCandidates(session)
		end
		Game.ensureMissions(session)
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
	return math.floor(Game.incomeBase(session) * minutes / 100) * 100
end

-- Pago de un chárter (minutos de tus ingresos)
function Game.charterPay(session: Session, kind: string): number
	local c = Config.CharterById[kind]
	return c and math.floor(Game.incomeBase(session) * c.minutes / 100) * 100 or 0
end

---------------------------------------------------------------------
-- Salir a bolsa
---------------------------------------------------------------------
function Game.newShares(data: any): number
	return math.max(0, Config.sharesTotal(data.stats.earned) - data.shares)
end

function Game.goPublic(session: Session): number
	local data = session.data
	local gained = Game.newShares(data)
	data.shares += gained
	data.ipoCount += 1
	-- Se reinicia: dinero, nivel, flota, pilotos, regiones, mejoras y contratos
	data.money = Config.START_MONEY + (Game.hasPerk(data, "gold") and Config.IPO_START_MONEY or 0)
	data.xp = 0
	-- Lo comprado con Robux se conserva (aviones del pack de inicio y pilotos estrella)
	local paidPlanes = {}
	for _, p in data.planes do
		if p.paid then
			table.insert(paidPlanes, { id = p.id, model = p.model, airport = Config.START_HUB, condition = 100, paid = true })
		end
	end
	local paidPilots = {}
	for _, p in data.pilots do
		if p.trait == "ace" then
			table.insert(paidPilots, p)
		end
	end
	data.planes = { { id = data.nextId, model = "sparrow", airport = Config.START_HUB, condition = 100 } }
	data.nextId += 1
	for _, p in paidPlanes do
		table.insert(data.planes, p)
	end
	if Game.hasPerk(data, "hawk") then
		table.insert(data.planes, { id = data.nextId, model = "hawk", airport = Config.START_HUB, condition = 100 })
		data.nextId += 1
	end
	data.pilots = paidPilots
	data.regions = { CEN = true, LEV = true }
	if Game.hasPerk(data, "region") then
		data.regions.CAT = true
	end
	for id in data.upgrades do
		data.upgrades[id] = 0
	end
	data.contracts = { offers = {}, active = {}, nextAt = 0 }
	data.staff.dispatcher = 0
	data.mechanics = {}
	data.fuel = math.max(Config.FUEL_START, math.min(data.fuel, Game.tankCapacity(data)))
	data.run = { earned = 0 }
	data.rate = 0
	data.settings.auto = false
	session.boards = {}
	session.express = nil
	session.sat = {}
	session.incomePerMin = 0
	session.earnedWindow = 0
	Game.refreshCandidates(session)
	session.dirty = true
	return gained
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
	if pilotId == nil then
		pilotId = 0
	elseif type(pilotId) ~= "number" then
		return false, "err_generic"
	end
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
	if pilotId ~= 0 then
		-- Cualquier otro número (−1, NaN, decimales…) tiene que ser un piloto tuyo
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
	local litres = Config.fuelLitres(dist, model.burn)
	if litres > data.fuel then
		return false, "err_no_fuel"
	end
	local now = os.time()
	plane.flight = {
		from = plane.airport, to = dest.code, good = "ferry", weight = 0, dist = dist, gross = 0,
		fuel = math.floor(litres * Game.fuelPrice(data)), fee = 0, pilot = -1, startT = now,
		endT = now + Config.flightSeconds(dist, model.speed, Game.timeMult(session)), express = false, litres = litres,
	}
	useFuel(session, litres)
	session.dirty = true
	return true, "n_ferry", { city = dest.city }
end

-- Chárter: horas reales fuera de España; paga minutos de tus ingresos (uno a la vez)
function Actions.charter(session, planeId, kind)
	local data = session.data
	local plane = findPlane(data, planeId)
	local c = if type(kind) == "string" then Config.CharterById[kind] else nil
	if not plane or not c then
		return false, "err_generic"
	elseif Game.level(data) < Config.CHARTER_LEVEL then
		return false, "err_level", { level = Config.CHARTER_LEVEL }
	elseif plane.flight then
		return false, "err_plane_busy"
	elseif plane.condition < Config.REPAIR_BLOCK then
		return false, "err_needs_repair"
	end
	for _, p in data.planes do
		if p.flight and p.flight.good == "charter" then
			return false, "err_charter_busy"
		end
	end
	local now = os.time()
	local gross = Game.charterPay(session, c.id)
	plane.flight = {
		from = plane.airport, to = plane.airport, good = "charter", weight = 0, dist = 0, gross = gross,
		fuel = 0, fee = 0, pilot = -2, startT = now, endT = now + c.hours * 3600, express = false,
		city = Config.CharterCities[rng:NextInteger(1, #Config.CharterCities)],
	}
	session.dirty = true
	return true, "n_charter", { amount = gross, h = c.hours }, { takeoff = plane.id }
end

-- Aterrizaje perfecto: solo tus vuelos, en los últimos segundos y una vez por vuelo
function Actions.land(session, planeId, quality)
	local plane = findPlane(session.data, planeId)
	local f = plane and plane.flight
	if not f or f.pilot ~= 0 or f.good == "ferry" or f.good == "charter" or f.landing then
		return false
	elseif quality ~= "perfect" and quality ~= "good" then
		return false
	end
	local now = os.time()
	if now < f.endT - Config.LANDING.window - 1 or f.endT - f.startT < Config.LANDING.minSecs then
		return false
	end
	f.landing = quality
	return true
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

-- Compra combustible: litres = cantidad (se limita a lo que cabe y a lo que puedes pagar)
function Actions.buyFuel(session, litres)
	if type(litres) ~= "number" or litres ~= litres or litres <= 0 then
		return false, "err_generic"
	end
	local data = session.data
	if data.fuel >= Game.tankCapacity(data) then
		return false, "err_tank_full"
	end
	local amount, cost = Game.buyFuel(session, litres)
	if amount < 1 then
		return false, "err_money"
	end
	return true, "n_fuel_bought", { n = amount, cost = cost }, { money = true }
end

-- Contrata o sube de nivel al despachador
function Actions.hireDispatcher(session)
	local data = session.data
	local nextLevel = (data.staff.dispatcher or 0) + 1
	local def = Config.Dispatcher[nextLevel]
	if not def then
		return false, "err_maxed"
	elseif Game.level(data) < def.level then
		return false, "err_level", { level = def.level }
	elseif data.money < def.cost then
		return false, "err_money"
	end
	data.money -= def.cost
	data.staff.dispatcher = nextLevel
	Game.addStat(session, "purchases", 1)
	session.dirty = true
	return true, "n_dispatcher", { n = nextLevel }, { money = true }
end

function Actions.hireMechanic(session, candidateId)
	local data = session.data
	if Game.level(data) < Config.MECH_LEVEL then
		return false, "err_level", { level = Config.MECH_LEVEL }
	end
	for i, c in data.mechCandidates do
		if c.id == candidateId then
			if #data.mechanics >= Config.MAX_MECHANICS then
				return false, "err_roster_full"
			elseif data.money < c.price then
				return false, "err_money"
			end
			data.money -= c.price
			table.remove(data.mechCandidates, i)
			c.price = nil
			table.insert(data.mechanics, c)
			Game.addStat(session, "purchases", 1)
			session.dirty = true
			return true, "n_hired", { name = c.name }
		end
	end
	return false, "err_generic"
end

function Actions.fireMechanic(session, id)
	local data = session.data
	for i, m in data.mechanics do
		if m.id == id then
			table.remove(data.mechanics, i)
			session.dirty = true
			return true, "n_fired", { name = m.name }
		end
	end
	return false, "err_generic"
end

function Actions.acceptContract(session, offerId)
	local data = session.data
	local c = data.contracts
	if Game.level(data) < Config.CONTRACT_LEVEL then
		return false, "err_level", { level = Config.CONTRACT_LEVEL }
	elseif #c.active >= Game.contractSlots(data) then
		return false, "err_contracts_full"
	end
	for i, o in c.offers do
		if o.id == offerId then
			table.remove(c.offers, i)
			o.progress = 0
			o.expires = os.time() + o.secs
			table.insert(c.active, o)
			session.dirty = true
			return true, "n_contract_accepted", { company = o.company }
		end
	end
	return false, "err_load_gone"
end

function Actions.abandonContract(session, contractId)
	local c = session.data.contracts
	for i, x in c.active do
		if x.id == contractId then
			table.remove(c.active, i)
			Game.addRep(session.data, Config.Rep.contractQuit)
			session.dirty = true
			return true
		end
	end
	return false, "err_generic"
end

function Actions.goPublic(session)
	local data = session.data
	local gained = Game.newShares(data)
	if Game.level(data) < Config.IPO_LEVEL then
		return false, "err_level", { level = Config.IPO_LEVEL }
	elseif gained < Config.IPO_MIN_SHARES then
		return false, "err_ipo_shares", { n = Config.IPO_MIN_SHARES }
	end
	for _, p in data.planes do
		if p.flight and p.flight.good == "charter" then
			return false, "err_ipo_charter"
		end
	end
	Game.goPublic(session)
	Game.notifyAll("feed", "n_feed_ipo", { player = session.player.DisplayName, n = data.ipoCount })
	return true, "n_ipo_done", { n = gained }, { ipo = gained, total = data.shares, count = data.ipoCount }
end

function Actions.setAirline(session, parts, color)
	local data = session.data
	if type(parts) ~= "table" or type(color) ~= "number" then
		return false, "err_generic"
	end
	local P = Config.AirlineParts
	local a, b, c = parts[1], parts[2], parts[3]
	for i, v in { a, b, c } do
		if type(v) ~= "number" or not P[i][v] then
			return false, "err_generic"
		end
	end
	if not Config.AirlineColors[color] then
		return false, "err_generic"
	elseif color == Config.GOLD_COLOR and not Game.hasPerk(data, "gold") then
		return false, "err_gold_locked"
	end
	data.airline = { a = a, b = b, c = c, color = color }
	session.dirty = true
	return true
end

function Actions.setAuto(session, on)
	if on and not Game.autoUnlocked(session) then
		return false, "err_need_dispatcher"
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
	local amount = math.floor(Game.rewardBase(session) * Config.DailyRewards[data.daily.streak])
	data.money += amount
	if data.daily.streak == #Config.DailyRewards then
		data.boostUntil = math.max(os.time(), data.boostUntil) + 1800
	end
	session.dirty = true
	return true, "n_daily", { amount = amount, day = data.daily.streak }, { money = true }
end

function Actions.claimMission(session, index)
	local data = session.data
	Game.ensureMissions(session)
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

local function claimGoal(session: Session, g: any): number
	local data = session.data
	data.goals[g.id] = true
	local amount = math.floor(Game.rewardBase(session) * g.reward / 100) * 100
	data.money += amount
	tutorialStep(session, 5, 99)
	session.dirty = true
	return amount
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
			return true, "n_claimed", { amount = claimGoal(session, g) }, { money = true }
		end
	end
	return false, "err_generic"
end

-- Reclama de una vez todos los objetivos terminados
function Actions.claimGoals(session)
	local data = session.data
	local total = 0
	for _, g in Config.Goals do
		if not data.goals[g.id] and Game.goalValue(data, g.stat) >= g.target then
			total += claimGoal(session, g)
		end
	end
	if total == 0 then
		return false, "err_not_done"
	end
	return true, "n_claimed", { amount = total }, { money = true }
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
