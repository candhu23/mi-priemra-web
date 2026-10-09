--[[
	Economy (ModuleScript en ServerScriptService)

	Ingresos por segundo, multiplicadores de visitas por eventos, boost y
	lo que valen las recompensas (minutos de ingresos).

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))

local serverEventIs = ServerState.serverEventIs
type Session = ServerState.Session

local Economy = {}

local function refreshBoost(session: Session)
	session.bonuses.boost = session.data.boostUntil > os.time()
end

local function eventVisitMult(session: Session, site): number
	local event = session.event
	if not event then
		return 1
	end
	if event.id == "viral" and event.siteId == site.id then
		return 5
	elseif event.id == "algoritmo" then
		return 1.5
	elseif event.id == "caida" and Config.level(session.data, "datacenter") < 1 then
		return 0.5
	end
	return 1
end

-- Eventos aleatorios × evento de fin de semana
local function visitMult(session: Session, site): number
	local mult = eventVisitMult(session, site)
	if session.bonuses.weekend == "viral" then
		mult *= Config.WEEKEND_VISITS_MULT
	end
	if serverEventIs("rushhour") then
		mult *= 2
	end
	-- Programadores de Marketing
	return mult * (1 + (session.bonuses.agencyVisits or 0))
end

-- Ingresos por segundo (webs + empresas + mantenimiento)
local function computeIncome(session: Session, withEvents: boolean): number
	local data = session.data
	local moneyMult = Config.moneyMult(data, session.bonuses)
	local total = 0
	for _, site in data.sites do
		local mult = if withEvents then visitMult(session, site) else 1
		total += Config.siteIncome(data, site, Config.siteVisits(data, site, mult), moneyMult)
	end
	total += Config.companiesIncome(data, moneyMult)
	total += Config.maintenanceIncome(data)
	return total
end

-- Dinero equivalente a "minutes" minutos de ingresos (mínimo "min")
-- Dinero equivalente a "minutes" minutos de ingresos (mínimo "min"), para
-- lo que se COMPRA con Robux (no se rebaja)
local function paidReward(session: Session, minutes: number, min: number): number
	return math.max(min, computeIncome(session, false) * minutes * 60)
end

-- Lo mismo para las recompensas gratis: rebajadas con Config.REWARD_SCALE
local function incomeReward(session: Session, minutes: number, min: number): number
	return paidReward(session, minutes, min) * Config.REWARD_SCALE
end

Economy.computeIncome = computeIncome
Economy.eventVisitMult = eventVisitMult
Economy.incomeReward = incomeReward
Economy.paidReward = paidReward
Economy.refreshBoost = refreshBoost
Economy.visitMult = visitMult

return Economy
