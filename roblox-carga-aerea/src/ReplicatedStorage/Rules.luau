--!strict
-- Reglas compartidas por el servidor y el cliente: cuánto paga una carga, si un avión puede llevarla,
-- eventos de España, ciudades en auge y pasaporte. El servidor decide; el cliente usa lo mismo para
-- mostrar estimaciones idénticas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Rules = {}

-- Lo que hace falta para calcular un pago (el servidor lo saca de la partida y el cliente del estado)
export type View = {
	upgrades: { [string]: number },
	moneyMult: number,
	fuelPrice: number,
	timeMult: number,
	event: string?, -- id del evento activo
	wanted: { [string]: number }, -- aeropuerto → multiplicador (ciudades en auge)
	sat: { [string]: number }, -- aeropuerto → multiplicador por saturación (< 1)
	album: { airports: { [string]: boolean }, goods: { [string]: number } },
}
export type Mod = { kind: string, icon: string, mult: number }

---------------------------------------------------------------------
-- Eventos y ciudades en auge (deterministas según la hora: iguales en todos los servidores)
---------------------------------------------------------------------
-- Devuelve (evento o nil, segundos que le quedan o que faltan para el siguiente)
function Rules.eventAt(now: number): (Config.EventDef?, number)
	local index = math.floor(now / Config.EVENT_PERIOD)
	local start = index * Config.EVENT_PERIOD
	local into = now - start
	if into >= Config.EVENT_LENGTH then
		return nil, start + Config.EVENT_PERIOD - now
	end
	-- Mes real (UTC): las fiestas de ese mes salen 4 veces más
	local month = 0
	local ok, t = pcall(function()
		return os.date("!*t", now)
	end)
	if ok and type(t) == "table" then
		month = (t :: any).month or 0
	end
	local weights, total = {}, 0
	for i, e in Config.Events do
		local w = 1
		if e.months and table.find(e.months, month) then
			w = 4
		end
		weights[i] = w
		total += w
	end
	local rand = Config.prng(index * 7919 + 13)
	-- Nunca el mismo evento dos veces seguidas
	local prevRand = Config.prng((index - 1) * 7919 + 13)
	local function pick(r: (number?, number?) -> number): number
		local roll = r() * total
		for i, w in weights do
			roll -= w
			if roll <= 0 then
				return i
			end
		end
		return #Config.Events
	end
	local i = pick(rand)
	if i == pick(prevRand) then
		i = i % #Config.Events + 1
	end
	return Config.Events[i], start + Config.EVENT_LENGTH - now
end

-- ¿Le afecta el evento a esta carga?
function Rules.eventMatches(e: Config.EventDef, load: any): boolean
	if e.goods and not table.find(e.goods, load.good) then
		return false
	end
	if e.to and not table.find(e.to, load.to) then
		return false
	end
	if e.region then
		local a, b = Config.AirportByCode[load.from], Config.AirportByCode[load.to]
		if not ((a and a.region == e.region) or (b and b.region == e.region)) then
			return false
		end
	end
	return true
end

-- Ciudades en auge del periodo actual: { { code, mult } } y segundos hasta que cambien
function Rules.wantedAt(now: number): ({ { code: string, mult: number } }, number)
	local index = math.floor(now / Config.WANTED_PERIOD)
	local rand = Config.prng(index * 104729 + 7)
	local starters, others = {}, {}
	for _, a in Config.Airports do
		if a.region == "CEN" or a.region == "LEV" then
			table.insert(starters, a.code)
		else
			table.insert(others, a.code)
		end
	end
	local list = {}
	-- 2 en las regiones iniciales (sirven desde el principio) y el resto en cualquier otra
	for n = 1, Config.WANTED_COUNT do
		local pool = n <= 2 and starters or others
		local code = table.remove(pool, rand(1, #pool)) :: string
		table.insert(list, { code = code, mult = Config.WANTED_MULTS[rand(1, #Config.WANTED_MULTS)] })
	end
	return list, (index + 1) * Config.WANTED_PERIOD - now
end

function Rules.satMult(level: number): number
	return math.floor(math.max(Config.SAT_MIN, 1 - Config.SAT_STEP * level) * 100 + 0.5) / 100
end

---------------------------------------------------------------------
-- Pasaporte
---------------------------------------------------------------------
function Rules.regionComplete(airports: { [string]: boolean }, regionId: string): boolean
	for _, a in Config.Airports do
		if a.region == regionId and not airports[a.code] then
			return false
		end
	end
	return true
end

function Rules.medals(count: number): number
	local n = 0
	for _, need in Config.MEDALS do
		if count >= need then
			n += 1
		end
	end
	return n
end

-- Sellos conseguidos (aeropuertos + medallas de productos) y total posible
function Rules.stamps(album: any): (number, number)
	local n = 0
	for _ in album.airports do
		n += 1
	end
	for _, count in album.goods do
		n += Rules.medals(count)
	end
	return n, #Config.Airports + #Config.Goods * #Config.MEDALS
end

---------------------------------------------------------------------
-- Pago de una carga
---------------------------------------------------------------------
function Rules.traitApplies(t: Config.Trait, load: any): boolean
	if t.goods then
		return t.goods[load.good] == true
	elseif t.regions then
		local a, b = Config.AirportByCode[load.from], Config.AirportByCode[load.to]
		return (a ~= nil and t.regions[a.region] == true) or (b ~= nil and t.regions[b.region] == true)
	elseif t.express then
		return load.express ~= nil
	end
	return true
end

function Rules.canFly(view: View, plane: any, load: any): string?
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
	elseif good.cold and (view.upgrades.cold or 0) < 1 then
		return "err_cold"
	end
	return nil
end

-- Devuelve (bruto, combustible, comisión del piloto, segundos, modificadores aplicados)
function Rules.quote(view: View, plane: any, load: any, pilot: any?): (number, number, number, number, { Mod })
	local model = Config.PlaneById[plane.model]
	local mods: { Mod } = {}
	local pay = (1 + 0.05 * (view.upgrades.sales or 0)) * view.moneyMult
	local timeK, fuelK = view.timeMult, 1
	if pilot then
		pay *= 1 + Config.pilotBonus(pilot.stars, pilot.level)
		local t = pilot.trait and Config.TraitById[pilot.trait]
		if t and Rules.traitApplies(t, load) then
			pay *= t.pay or 1
			timeK *= t.time or 1
			fuelK *= t.fuel or 1
			table.insert(mods, { kind = "trait", icon = t.emoji, mult = t.pay or t.time or t.fuel or 1 })
		end
	end
	local e = view.event and Config.EventById[view.event]
	if e and Rules.eventMatches(e, load) then
		pay *= e.pay
		timeK *= e.time or 1
		table.insert(mods, { kind = "event", icon = e.emoji, mult = e.pay })
	end
	local w = view.wanted[load.to]
	if w then
		pay *= w
		table.insert(mods, { kind = "wanted", icon = "🔥", mult = w })
	end
	local s = view.sat[load.to]
	if s and s < 1 then
		pay *= s
		table.insert(mods, { kind = "sat", icon = "📉", mult = s })
	end
	if not view.album.airports[load.to] then
		pay *= Config.NEW_ROUTE_MULT
		table.insert(mods, { kind = "new", icon = "✨", mult = Config.NEW_ROUTE_MULT })
	else
		local b = Config.AirportByCode[load.to]
		if b and Rules.regionComplete(view.album.airports, b.region) then
			pay *= 1 + Config.REGION_STAMP_BONUS
		end
	end
	local gross = math.floor(load.gross * pay)
	local fuel = math.floor(load.dist * model.burn * view.fuelPrice * fuelK)
	local fee = pilot and math.floor(gross * Config.PILOT_FEE) or 0
	local secs = load.tutorial and 15 or Config.flightSeconds(load.dist, model.speed, timeK)
	return gross, fuel, fee, secs, mods
end

return Rules
