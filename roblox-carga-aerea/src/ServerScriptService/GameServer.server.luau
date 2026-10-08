--!strict
-- Servidor de «Air Cargo Empire». El servidor manda: el cliente solo muestra y pide acciones.
-- Los avisos y errores se mandan como claves de traducción (Lang.luau) + parámetros.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local remotes = Instance.new("Folder")
remotes.Name = "CargoRemotes"
local actionRemote = Instance.new("RemoteFunction")
actionRemote.Name = "Action"
actionRemote.Parent = remotes
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = remotes
local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local store = DataStoreService:GetDataStore("AirCargo_v1")
local rng = Random.new()

---------------------------------------------------------------------
-- Datos del jugador
---------------------------------------------------------------------
local function newData(): any
	return {
		money = Config.START_MONEY,
		xp = 0,
		planes = { { id = 1, model = "courier", airport = "JFK", condition = 100 } },
		nextId = 2,
		pilots = {},
		regions = { NA = true },
		licenses = {},
		upgrades = { hangar = 0, fuel = 0, broker = 0 },
		settings = { lang = "", muted = false, auto = false },
		stats = { flights = 0, km = 0, tons = 0, earned = 0 },
		lastOnline = 0,
	}
end

-- Rellena campos nuevos en partidas antiguas
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and #v == 0 then
			reconcile(data[k], v)
		end
	end
end

type Load = {
	id: number, cargo: string, from: string, to: string, weight: number, dist: number, gross: number,
}
type Session = {
	data: any,
	canSave: boolean,
	boards: { [string]: { loads: { Load }, expires: number } },
	refreshAt: { [string]: number },
	nextLoadId: number,
	actionWindow: number,
	actionCount: number,
	passes: { [string]: boolean },
	dirty: boolean,
}
local sessions: { [Player]: Session } = {}

local function level(data: any): number
	return Config.levelFromXp(data.xp)
end

local function notify(player: Player, kind: string, key: string, params: { [string]: any }?)
	notifyRemote:FireClient(player, kind, key, params or {})
end

---------------------------------------------------------------------
-- Mundo compartido: clima por aeropuerto y precio del combustible
---------------------------------------------------------------------
local weather: { [string]: string } = {}
local function rollWeather(): string
	local roll = rng:NextNumber(0, 100)
	for _, w in Config.Weather do
		roll -= w.chance
		if roll <= 0 then
			return w.id
		end
	end
	return "clear"
end
for _, a in Config.Airports do
	weather[a.code] = rollWeather()
end
local fuelMult = 1
local nextWeather = os.time() + Config.WEATHER_PERIOD
local nextFuel = os.time() + 300

local function fuelPrice(data: any): number
	return Config.FUEL_PRICE * fuelMult * (1 - 0.05 * data.upgrades.fuel)
end

---------------------------------------------------------------------
-- Pases
---------------------------------------------------------------------
local function autoUnlocked(session: Session): boolean
	return session.passes.autopilot == true or level(session.data) >= Config.AUTO_DISPATCH_LEVEL
end

local function maxPlanes(session: Session): number
	return Config.maxPlanes(session.data.upgrades.hangar) + (session.passes.hangar and 4 or 0)
end

---------------------------------------------------------------------
-- Tablón de cargas
---------------------------------------------------------------------
-- Modelos para los que se generan cargas: los aviones en tierra en ese aeropuerto
-- (para que el tablón sirva a quien está allí); si no hay ninguno, toda la flota
local function ownedModels(data: any, at: string?): { any }
	local seen, list = {}, {}
	if at then
		for _, p in data.planes do
			if not p.flight and p.airport == at and not seen[p.model] then
				seen[p.model] = true
				table.insert(list, Config.PlaneById[p.model])
			end
		end
		if #list > 0 then
			return list
		end
	end
	for _, p in data.planes do
		if not seen[p.model] then
			seen[p.model] = true
			table.insert(list, Config.PlaneById[p.model])
		end
	end
	if #list == 0 then
		table.insert(list, Config.PlaneById.courier)
	end
	return list
end

local function generateLoad(session: Session, from: string): Load?
	local data = session.data
	local lvl = level(data)
	local cargos = {}
	local total = 0
	for _, c in Config.Cargo do
		if c.level <= lvl then
			table.insert(cargos, c)
			total += c.weight
		end
	end
	local roll = rng:NextNumber(0, total)
	local cargo = cargos[1]
	for _, c in cargos do
		roll -= c.weight
		if roll <= 0 then
			cargo = c
			break
		end
	end
	local models = ownedModels(data, from)
	local model = models[rng:NextInteger(1, #models)]
	if cargo.planes then
		model = Config.PlaneById[cargo.planes[1]]
	end
	-- 75 % de las cargas caben en el alcance de un avión del jugador
	local inRange, any = {}, {}
	for _, a in Config.Airports do
		if a.code ~= from and data.regions[a.region] then
			local d = Config.distance(from, a.code)
			table.insert(any, a.code)
			if d <= model.range and d >= 250 then
				table.insert(inRange, a.code)
			end
		end
	end
	local pool = (#inRange > 0 and rng:NextNumber() < 0.75) and inRange or any
	if #pool == 0 then
		return nil
	end
	local to = pool[rng:NextInteger(1, #pool)]
	local weight = math.max(0.3, math.floor(model.cap * rng:NextNumber(0.35, 1) * 10 + 0.5) / 10)
	local dist = Config.distance(from, to)
	local w = Config.WeatherById[weather[from]]
	session.nextLoadId += 1
	return {
		id = session.nextLoadId,
		cargo = cargo.id,
		from = from,
		to = to,
		weight = weight,
		dist = dist,
		gross = Config.payout(weight, dist, cargo.mult, w.pay),
	}
end

local function board(session: Session, code: string, force: boolean?): { Load }
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
		b = { loads = loads, expires = now + Config.BOARD_TTL }
		session.boards[code] = b
	end
	return (b :: any).loads
end

---------------------------------------------------------------------
-- Cálculo de un vuelo (el cliente usa las mismas fórmulas para estimar)
---------------------------------------------------------------------
local function findPlane(data: any, id: number): any
	for _, p in data.planes do
		if p.id == id then
			return p
		end
	end
	return nil
end
local function findPilot(data: any, id: number): any
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

local function quote(session: Session, plane: any, load: Load, pilotId: number): (number, number, number, number)
	local data = session.data
	local model = Config.PlaneById[plane.model]
	local bonus = 0
	if pilotId > 0 then
		local pilot = findPilot(data, pilotId)
		bonus = Config.Rarities[Config.RarityIndex[pilot.rarity]].bonus
	end
	local gross = math.floor(load.gross * (1 + 0.04 * data.upgrades.broker) * (1 + bonus) * (session.passes.x2 and 2 or 1))
	local fuel = math.floor(load.dist * model.burn * fuelPrice(data))
	local fee = pilotId > 0 and math.floor(gross * Config.PILOT_FEE) or 0
	local w = Config.WeatherById[weather[load.from]]
	local secs = Config.flightSeconds(load.dist, model.speed, w.time)
	return gross, fuel, fee, secs
end

-- Comprueba si un avión puede llevar una carga; devuelve clave de error o nil
local function canFly(session: Session, plane: any, load: Load): string?
	local data = session.data
	local model = Config.PlaneById[plane.model]
	local cargo = Config.CargoById[load.cargo]
	if plane.flight then
		return "err_plane_busy"
	elseif plane.condition < Config.REPAIR_BLOCK then
		return "err_needs_repair"
	elseif model.license and not data.licenses[model.license] then
		return "err_plane_license"
	elseif load.weight > model.cap then
		return "err_too_heavy"
	elseif load.dist > model.range then
		return "err_out_of_range"
	elseif cargo.license and not data.licenses[cargo.license] then
		return "err_cargo_license"
	elseif cargo.planes and not table.find(cargo.planes, plane.model) then
		return "err_cargo_plane"
	end
	return nil
end

local function startFlight(session: Session, plane: any, load: Load, pilotId: number)
	local gross, fuel, fee, secs = quote(session, plane, load, pilotId)
	local now = os.time()
	plane.flight = {
		from = load.from, to = load.to, cargo = load.cargo, weight = load.weight, dist = load.dist,
		gross = gross, fuel = fuel, fee = fee, pilot = pilotId, startT = now, endT = now + secs,
		wear = Config.wear(load.dist, Config.WeatherById[weather[load.from]].wear),
	}
	local b = session.boards[load.from]
	if b then
		for i, l in b.loads do
			if l.id == load.id then
				table.remove(b.loads, i)
				break
			end
		end
	end
	session.dirty = true
end

local function finishFlight(player: Player?, session: Session, plane: any, offline: boolean)
	local data = session.data
	local f = plane.flight
	plane.flight = nil
	plane.airport = f.to
	plane.condition = math.max(0, math.floor((plane.condition - f.wear) * 10 + 0.5) / 10)
	local net = f.gross - f.fuel - f.fee
	data.money += net
	local before = level(data)
	if f.cargo ~= "ferry" then
		data.xp += Config.flightXp(f.gross)
		data.stats.flights += 1
		data.stats.tons += f.weight
	end
	data.stats.km += f.dist
	data.stats.earned += math.max(0, net)
	session.dirty = true
	if player and not offline then
		if f.cargo == "ferry" then
			notify(player, "info", "n_ferry_landed", { to = f.to, fuel = f.fuel })
		else
			notify(player, net >= 0 and "money" or "error", "n_landed", { to = f.to, net = net })
		end
		local after = level(data)
		if after > before then
			notify(player, "level", "n_level_up", { level = after })
		end
	end
end

---------------------------------------------------------------------
-- Pilotos
---------------------------------------------------------------------
local function rollPilot(session: Session, agency: any): any
	local data = session.data
	-- Sorteo con las probabilidades publicadas (las rarezas al 0 % nunca salen)
	local roll = rng:NextNumber(0, 100)
	local rarity = Config.Rarities[1].id
	for i, r in Config.Rarities do
		if agency.odds[i] > 0 then
			rarity = r.id
			roll -= agency.odds[i]
			if roll <= 0 then
				break
			end
		end
	end
	local name = Config.FirstNames[rng:NextInteger(1, #Config.FirstNames)] .. " " .. Config.LastNames[rng:NextInteger(1, #Config.LastNames)]
	local pilot = { id = data.nextId, name = name, rarity = rarity, flights = 0 }
	data.nextId += 1
	return pilot
end

---------------------------------------------------------------------
-- Estado que se manda al cliente
---------------------------------------------------------------------
local function sendState(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	local boards = {}
	local refresh = {}
	local now = os.time()
	for _, p in data.planes do
		if not p.flight and not boards[p.airport] then
			boards[p.airport] = board(session, p.airport)
			refresh[p.airport] = math.max(0, (session.refreshAt[p.airport] or 0) - now)
		end
	end
	stateRemote:FireClient(player, {
		money = data.money,
		xp = data.xp,
		level = level(data),
		planes = data.planes,
		pilots = data.pilots,
		regions = data.regions,
		licenses = data.licenses,
		upgrades = data.upgrades,
		settings = data.settings,
		stats = data.stats,
		now = now,
		fuelPrice = fuelPrice(data),
		weather = weather,
		boards = boards,
		refresh = refresh,
		maxPlanes = maxPlanes(session),
		autoUnlocked = autoUnlocked(session),
		passes = session.passes,
		canSave = session.canSave,
		version = Config.VERSION,
	})
end

---------------------------------------------------------------------
-- Acciones (devuelven ok, claveDeMensaje?, parámetros?)
---------------------------------------------------------------------
local Actions: { [string]: (Player, Session, any, any, any) -> (boolean, string?, any?, any?) } = {}

function Actions.dispatch(_player, session, planeId, loadId, pilotId)
	local data = session.data
	if type(planeId) ~= "number" or type(loadId) ~= "number" then
		return false, "err_generic"
	end
	pilotId = type(pilotId) == "number" and pilotId or 0
	local plane = findPlane(data, planeId)
	if not plane then
		return false, "err_generic"
	end
	local load
	for _, l in board(session, plane.airport) do
		if l.id == loadId then
			load = l
			break
		end
	end
	if not load then
		return false, "err_load_gone"
	end
	local err = canFly(session, plane, load)
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
	startFlight(session, plane, load, pilotId)
	return true, "n_takeoff", { from = load.from, to = load.to }
end

function Actions.ferry(_player, session, planeId, to)
	local data = session.data
	local plane = if type(planeId) == "number" then findPlane(data, planeId) else nil
	local dest = if type(to) == "string" then Config.AirportByCode[to] else nil
	if not plane or not dest or dest.code == plane.airport or not data.regions[dest.region] then
		return false, "err_generic"
	end
	if plane.flight then
		return false, "err_plane_busy"
	elseif plane.condition < Config.REPAIR_BLOCK then
		return false, "err_needs_repair"
	end
	local model = Config.PlaneById[plane.model]
	local dist = Config.distance(plane.airport, dest.code)
	if dist > model.range then
		return false, "err_out_of_range"
	end
	local fuel = math.floor(dist * model.burn * fuelPrice(data))
	local now = os.time()
	plane.flight = {
		from = plane.airport, to = dest.code, cargo = "ferry", weight = 0, dist = dist, gross = 0,
		fuel = fuel, fee = 0, pilot = -1, startT = now,
		endT = now + Config.flightSeconds(dist, model.speed, 1), wear = Config.wear(dist, 1),
	}
	session.dirty = true
	return true, "n_ferry", { to = dest.code }
end

function Actions.refreshBoard(_player, session, code)
	if type(code) ~= "string" or not Config.AirportByCode[code] then
		return false, "err_generic"
	end
	local now = os.time()
	if (session.refreshAt[code] or 0) > now then
		return false, "err_cooldown", { s = session.refreshAt[code] - now }
	end
	session.refreshAt[code] = now + Config.REFRESH_COOLDOWN
	board(session, code, true)
	return true
end

function Actions.buyPlane(_player, session, modelId)
	local data = session.data
	local model = if type(modelId) == "string" then Config.PlaneById[modelId] else nil
	if not model then
		return false, "err_generic"
	elseif level(data) < model.level then
		return false, "err_level", { level = model.level }
	elseif model.license and not data.licenses[model.license] then
		return false, "err_plane_license"
	elseif #data.planes >= maxPlanes(session) then
		return false, "err_hangar_full"
	elseif data.money < model.price then
		return false, "err_money"
	end
	data.money -= model.price
	-- El avión nuevo aparece en el aeropuerto con más aviones del jugador (su base)
	local count, hq = {}, "JFK"
	for _, p in data.planes do
		local at = p.flight and p.flight.to or p.airport
		count[at] = (count[at] or 0) + 1
		if count[at] > (count[hq] or 0) then
			hq = at
		end
	end
	table.insert(data.planes, { id = data.nextId, model = model.id, airport = hq, condition = 100 })
	data.nextId += 1
	session.dirty = true
	return true, "n_bought", { name = model.name }, { money = true }
end

function Actions.sellPlane(_player, session, planeId)
	local data = session.data
	if #data.planes <= 1 then
		return false, "err_last_plane"
	end
	for i, p in data.planes do
		if p.id == planeId then
			if p.flight then
				return false, "err_plane_busy"
			end
			local model = Config.PlaneById[p.model]
			local value = Config.sellPrice(model.price, p.condition)
			data.money += value
			table.remove(data.planes, i)
			session.dirty = true
			return true, "n_sold", { value = value }
		end
	end
	return false, "err_generic"
end

function Actions.repair(_player, session, planeId)
	local data = session.data
	local plane = if type(planeId) == "number" then findPlane(data, planeId) else nil
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

function Actions.hirePilot(_player, session, agencyId)
	local data = session.data
	local agency = if type(agencyId) == "string" then Config.AgencyById[agencyId] else nil
	if not agency then
		return false, "err_generic"
	elseif level(data) < agency.level then
		return false, "err_level", { level = agency.level }
	elseif #data.pilots >= Config.MAX_PILOTS then
		return false, "err_roster_full"
	elseif data.money < agency.cost then
		return false, "err_money"
	end
	data.money -= agency.cost
	local pilot = rollPilot(session, agency)
	table.insert(data.pilots, pilot)
	session.dirty = true
	return true, "n_hired", { name = pilot.name }, { pilot = pilot }
end

function Actions.firePilot(_player, session, pilotId)
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

function Actions.buyRegion(_player, session, regionId)
	local data = session.data
	for _, r in Config.Regions do
		if r.id == regionId then
			if data.regions[r.id] then
				return false, "err_owned"
			elseif level(data) < r.level then
				return false, "err_level", { level = r.level }
			elseif data.money < r.cost then
				return false, "err_money"
			end
			data.money -= r.cost
			data.regions[r.id] = true
			session.boards = {} -- los destinos nuevos aparecen ya
			session.dirty = true
			return true, "n_region", { region = r.id }
		end
	end
	return false, "err_generic"
end

function Actions.buyLicense(_player, session, licenseId)
	local data = session.data
	local lic = if type(licenseId) == "string" then Config.LicenseById[licenseId] else nil
	if not lic then
		return false, "err_generic"
	elseif data.licenses[lic.id] then
		return false, "err_owned"
	elseif level(data) < lic.level then
		return false, "err_level", { level = lic.level }
	elseif data.money < lic.cost then
		return false, "err_money"
	end
	data.money -= lic.cost
	data.licenses[lic.id] = true
	session.dirty = true
	return true, "n_license", { license = lic.id }
end

function Actions.buyUpgrade(_player, session, upgradeId)
	local data = session.data
	local up = if type(upgradeId) == "string" then Config.UpgradeById[upgradeId] else nil
	if not up then
		return false, "err_generic"
	end
	local lvl = data.upgrades[up.id]
	if lvl >= up.max then
		return false, "err_maxed"
	end
	local cost = Config.upgradeCost(up.id, lvl)
	if data.money < cost then
		return false, "err_money"
	end
	data.money -= cost
	data.upgrades[up.id] = lvl + 1
	session.dirty = true
	return true, "n_upgrade", { upgrade = up.id, level = lvl + 1 }
end

function Actions.setAuto(_player, session, on)
	if on and not autoUnlocked(session) then
		return false, "err_level", { level = Config.AUTO_DISPATCH_LEVEL }
	end
	session.data.settings.auto = on == true
	return true
end

function Actions.setLang(_player, session, lang)
	if lang ~= "" and lang ~= "en" and lang ~= "es" then
		return false, "err_generic"
	end
	session.data.settings.lang = lang
	return true
end

function Actions.setMuted(_player, session, muted)
	session.data.settings.muted = muted == true
	return true
end

---------------------------------------------------------------------
-- Despacho automático: cada avión libre coge la carga con más beneficio
---------------------------------------------------------------------
local function autoDispatch(session: Session)
	local data = session.data
	if not data.settings.auto or not autoUnlocked(session) then
		return
	end
	-- Pilotos libres, los mejores primero; «tú» (0) al final
	local free = {}
	for _, p in data.pilots do
		if not pilotBusy(data, p.id) then
			table.insert(free, p)
		end
	end
	table.sort(free, function(a, b)
		return Config.RarityIndex[a.rarity] > Config.RarityIndex[b.rarity]
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
		for _, load in board(session, plane.airport) do
			if not canFly(session, plane, load) then
				local gross, fuel, fee = quote(session, plane, load, pilotId)
				local net = gross - fuel - fee
				if net > bestNet then
					best, bestNet = load, net
				end
			end
		end
		if best then
			startFlight(session, plane, best, pilotId)
		elseif pilotId == 0 then
			youFree = true
		else
			table.insert(free, 1, findPilot(data, pilotId) :: any)
		end
	end
end

---------------------------------------------------------------------
-- Guardado
---------------------------------------------------------------------
local function save(player: Player)
	local session = sessions[player]
	if not session or not session.canSave then
		return
	end
	session.data.lastOnline = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync("player_" .. player.UserId, function()
			return session.data
		end)
	end)
	if ok then
		session.dirty = false
	else
		warn("No se pudo guardar", player.Name, err)
	end
end

local function onPlayerAdded(player: Player)
	local data, ok = nil, false
	for attempt = 1, 3 do
		ok = pcall(function()
			data = store:GetAsync("player_" .. player.UserId)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not player.Parent then
		return
	end
	local fresh = data == nil
	data = data or newData()
	reconcile(data, newData())
	local session: Session = {
		data = data, canSave = ok, boards = {}, refreshAt = {}, nextLoadId = 0,
		actionWindow = 0, actionCount = 0, passes = {}, dirty = false,
	}
	sessions[player] = session
	for _, p in Config.Monetization.GamePasses do
		if p.id ~= 0 then
			pcall(function()
				session.passes[p.key] = MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
			end)
		end
	end
	-- Vuelos que aterrizaron mientras no estaba
	local landed, earned = 0, 0
	local now = os.time()
	for _, plane in data.planes do
		if plane.flight and plane.flight.endT <= now then
			earned += plane.flight.gross - plane.flight.fuel - plane.flight.fee
			finishFlight(nil, session, plane, true)
			landed += 1
		end
	end
	if not ok then
		notify(player, "error", "n_load_failed")
	elseif fresh then
		notify(player, "info", "n_welcome")
	elseif landed > 0 then
		notify(player, "money", "n_offline", { count = landed, net = earned })
	end
	sendState(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
end)

game:BindToClose(function()
	for player in sessions do
		save(player)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, bought)
	local session = sessions[player]
	if not session or not bought then
		return
	end
	for _, p in Config.Monetization.GamePasses do
		if p.id == id then
			session.passes[p.key] = true
			notify(player, "success", "n_pass", { pass = p.key })
		end
	end
	sendState(player)
end)

actionRemote.OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
	local session = sessions[player]
	if not session or type(action) ~= "string" then
		return false, "err_generic"
	end
	local now = os.clock()
	if now - session.actionWindow > 1 then
		session.actionWindow = now
		session.actionCount = 0
	end
	session.actionCount += 1
	if session.actionCount > 10 then
		return false, "err_slow_down"
	end
	local fn = Actions[action]
	if not fn then
		return false, "err_generic"
	end
	local ok, key, params, extra = fn(player, session, a, b, c)
	sendState(player)
	return ok, key, params, extra
end

---------------------------------------------------------------------
-- Bucle principal (1 s)
---------------------------------------------------------------------
local lastSave = os.time()
while true do
	task.wait(1)
	local now = os.time()
	if now >= nextWeather then
		nextWeather = now + Config.WEATHER_PERIOD
		for _, a in Config.Airports do
			weather[a.code] = rollWeather()
		end
	end
	if now >= nextFuel then
		nextFuel = now + 300
		fuelMult = math.clamp(fuelMult + rng:NextNumber(-0.12, 0.12), 0.7, 1.3)
	end
	for player, session in sessions do
		for _, plane in session.data.planes do
			if plane.flight and plane.flight.endT <= now then
				finishFlight(player, session, plane, false)
			end
		end
		autoDispatch(session)
		sendState(player)
	end
	if now - lastSave >= 60 then
		lastSave = now
		for player, session in sessions do
			if session.dirty then
				task.spawn(save, player)
			end
		end
	end
end
