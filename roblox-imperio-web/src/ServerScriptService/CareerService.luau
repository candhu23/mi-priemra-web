--[[
	CareerService (ModuleScript en ServerScriptService)

	Lógica de servidor de la carrera: XP por nicho, trabajos en las 500
	empresas, ascensos, tareas, tu agencia, fichajes de programadores y
	tickets comprados con Robux. La carrera NO se reinicia al salir a bolsa.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))

local CareerService = {}

type Ctx = {
	gain: (data: any, amount: number) -> (),
	notify: (player: Player, text: string, kind: string?) -> (),
	popup: (player: Player, title: string, body: string) -> (),
	income: (session: any) -> number,
	random: Random,
}
local ctx: Ctx

function CareerService.init(context: Ctx)
	ctx = context
end

function CareerService.newData()
	return {
		xp = {},
		job = nil,
		agency = nil,
		programmers = {},
		nextProgrammerId = 1,
		pity = 0,
		tickets = { premium = 0, legendary = 0 },
		stats = { jobs = 0, bestRank = 0, devLevel = 1, agency = 0, bestRarity = 0, team = 0, recruits = 0, tasks = 0 },
	}
end

local function nicheValid(nicheId: any): boolean
	return type(nicheId) == "string" and Career.NicheById[nicheId] ~= nil
end

---------------------------------------------------------------------
-- XP y niveles
---------------------------------------------------------------------
function CareerService.addXp(player: Player, session, nicheId: string, amount: number)
	if not nicheValid(nicheId) or amount <= 0 then
		return
	end
	local career = session.data.career
	if session.bonuses.xpPass then
		amount *= 2
	end
	amount *= 1 + Config.researchValue(session.data, "mentor")
	local before = Career.nicheLevel(career, nicheId)
	career.xp[nicheId] = (career.xp[nicheId] or 0) + amount
	local after = Career.nicheLevel(career, nicheId)
	if after > before then
		local niche = Career.NicheById[nicheId]
		career.stats.devLevel = Career.devLevel(career)
		ctx.notify(player, string.format("⬆️ ¡Nivel %d en %s %s! (nivel de programador %d)", after, niche.emoji, niche.name, career.stats.devLevel), "goal")
	end
end

---------------------------------------------------------------------
-- Bonus de la agencia y sueldo
---------------------------------------------------------------------
function CareerService.refreshBonuses(session)
	local data = session.data
	local projectNiche = data.project and data.project.niche or nil
	local work, bonus = Career.agencyTotals(data.career, projectNiche, session.bonuses.agencyPro)
	session.bonuses.agencyWork = work
	session.bonuses.agencyBonus = bonus
end

-- Feria de Empleo (evento de fin de semana): sueldo y XP x1.5
local function jobFairMult(session): number
	return if session.bonuses.weekend == "jobs" then Config.WEEKEND_JOB_MULT else 1
end

function CareerService.salaryPerSec(session): number
	local career = session.data.career
	local job = career.job
	if not job then
		return 0
	end
	local company = Career.company(job.companyId)
	if not company then
		return 0
	end
	return Career.salary(company, job.rank, Career.nicheLevel(career, company.niche), Config.moneyMult(session.data, session.bonuses), job.salaryMult) * jobFairMult(session)
end

local function jobXpRate(session): number
	local job = session.data.career.job
	local company = job and Career.company(job.companyId)
	if not company then
		return 0
	end
	return Career.jobXpRate(company, job.rank, job.xpMult or 1) * jobFairMult(session)
end

---------------------------------------------------------------------
-- Ofertas de empleo (llegan solas, cada una con condiciones aleatorias)
---------------------------------------------------------------------
local function randomRange(range: { number }): number
	return range[1] + ctx.random:NextNumber() * (range[2] - range[1])
end

-- Segundos hasta la próxima oferta de empleo (la mitad en la Feria de Empleo)
local function nextOfferDelay(session): number
	local delay = randomRange(Career.JOB_OFFER_INTERVAL)
	if session.bonuses.weekend == "jobs" then
		delay /= Config.WEEKEND_JOB_OFFER_SPEED
	end
	return delay
end

local function bestNiche(career): string
	local best, bestLevel = Career.DEFAULT_NICHE, -1
	for _, niche in Career.Niches do
		local level = Career.nicheLevel(career, niche.id)
		if level > bestLevel then
			best, bestLevel = niche.id, level
		end
	end
	return best
end

local function makeJobOffer(session)
	local data = session.data
	local career = data.career
	local taken = {}
	for _, offer in session.jobOffers do
		taken[offer.companyId] = true
	end
	if career.job then
		taken[career.job.companyId] = true
	end

	-- Nicho: casi siempre uno en el que destacas o el que tienes elegido.
	-- Si ahí no hay empresas a tu alcance, se prueba con otros.
	local eligible, level = {}, 1
	for attempt = 1, 4 do
		local roll = ctx.random:NextNumber()
		local nicheId = if attempt == 1 and roll < 0.5 then bestNiche(career)
			elseif attempt == 1 and roll < 0.75 then (data.selectedNiche or Career.DEFAULT_NICHE)
			else Career.Niches[ctx.random:NextInteger(1, #Career.Niches)].id
		level = Career.nicheLevel(career, nicheId)
		eligible = {}
		for _, company in Career.CompaniesByNiche[nicheId] do
			if company.reqLevel <= level and not taken[company.id] then
				table.insert(eligible, company)
			end
		end
		if #eligible > 0 then
			break
		end
	end
	if #eligible == 0 then
		return nil
	end
	-- Más probable que te escriban las mejores empresas a tu alcance
	local first = math.max(1, #eligible - 9)
	local company = eligible[ctx.random:NextInteger(first, #eligible)]

	-- Si te sobra nivel, a veces te ofrecen directamente un puesto mejor
	local rank = 1
	if level >= company.reqLevel + Career.Ranks[2].extraLevel + 2 and ctx.random:NextNumber() < 0.35 then
		rank = 2
	end

	session.nextJobOfferId += 1
	return {
		id = session.nextJobOfferId,
		companyId = company.id,
		rank = rank,
		salaryMult = math.floor(randomRange(Career.OFFER_SALARY_RANGE) * 100) / 100,
		xpMult = math.floor(randomRange(Career.OFFER_XP_RANGE) * 100) / 100,
		expiresAt = os.clock() + randomRange(Career.JOB_OFFER_LIFETIME),
	}
end

local function addJobOffer(player: Player?, session): any
	if #session.jobOffers >= Career.JOB_OFFER_MAX then
		-- Se cae la que menos tiempo le queda
		table.sort(session.jobOffers, function(a, b)
			return a.expiresAt > b.expiresAt
		end)
		table.remove(session.jobOffers)
	end
	local offer = makeJobOffer(session)
	if offer then
		table.insert(session.jobOffers, offer)
		if player then
			local company = Career.company(offer.companyId)
			ctx.notify(player, "📨 Oferta de trabajo de " .. company.name .. " (x" .. string.format("%.2f", offer.salaryMult) .. " sueldo) · pestaña Carrera", "info")
		end
	end
	return offer
end

-- Llamar al crear la sesión del jugador
function CareerService.initSession(session)
	session.jobOffers = {}
	session.nextJobOfferId = 0
	session.nextJobOfferAt = os.clock() + nextOfferDelay(session)
	session.cvReadyAt = 0
	-- Dos ofertas para empezar
	addJobOffer(nil, session)
	addJobOffer(nil, session)
end

---------------------------------------------------------------------
-- Cada segundo
---------------------------------------------------------------------
function CareerService.tick(player: Player, session, dt: number)
	local career = session.data.career
	local job = career.job
	if job then
		local company = Career.company(job.companyId)
		if company then
			CareerService.addXp(player, session, company.niche, jobXpRate(session) * dt)
			-- Ascenso automático
			local can = Career.canPromote(job, Career.nicheLevel(career, company.niche), os.time())
			if can then
				job.rank += 1
				job.rankSince = os.time()
				career.stats.bestRank = math.max(career.stats.bestRank, job.rank)
				ctx.popup(player, "🎉 ¡Ascenso!", string.format("En %s ahora eres %s.\n\nTu sueldo sube a %s/s.",
					company.name, Career.Ranks[job.rank].name, Config.formatMoney(CareerService.salaryPerSec(session))))
			end
			-- Aviso de tarea disponible (una vez)
			if os.clock() >= session.taskReadyAt and not session.taskNotified then
				session.taskNotified = true
				ctx.notify(player, "💼 Tienes una tarea nueva en " .. company.name .. " (pestaña Carrera)", "event")
			end
		end
	end
	-- Ofertas de empleo
	local now = os.clock()
	for i = #session.jobOffers, 1, -1 do
		if session.jobOffers[i].expiresAt <= now then
			table.remove(session.jobOffers, i)
		end
	end
	if now >= session.nextJobOfferAt then
		session.nextJobOfferAt = now + nextOfferDelay(session)
		addJobOffer(player, session)
	end

	career.stats.team = #career.programmers
	CareerService.refreshBonuses(session)
end

---------------------------------------------------------------------
-- Fichajes
---------------------------------------------------------------------
local function rollRarity(field: string): any
	local total = 0
	for _, rarity in Career.Rarities do
		total += rarity[field]
	end
	local roll = ctx.random:NextNumber() * total
	for _, rarity in Career.Rarities do
		roll -= rarity[field]
		if roll <= 0 and rarity[field] > 0 then
			return rarity
		end
	end
	return Career.Rarities[#Career.Rarities]
end

function CareerService.capacity(session): number
	local agency = session.data.career.agency
	if not agency then
		return 0
	end
	return Career.officeCapacity(agency.officeLevel, session.bonuses.agencyPro) + Config.researchValue(session.data, "office")
end
local capacity = CareerService.capacity

-- Coste de una entrevista (con el descuento de I+D "Ojeador")
function CareerService.recruitCost(session): number
	return math.floor(Career.recruitCost(ctx.income(session)) * (1 - Config.researchValue(session.data, "recruiter")))
end

local function hire(player: Player, session, rarity, nicheId: string?)
	local career = session.data.career
	local niche = if nicheId and nicheValid(nicheId) then nicheId else Career.Niches[ctx.random:NextInteger(1, #Career.Niches)].id
	local programmer = {
		id = career.nextProgrammerId,
		name = Career.FirstNames[ctx.random:NextInteger(1, #Career.FirstNames)] .. " " .. string.char(ctx.random:NextInteger(65, 90)) .. ".",
		rarity = rarity.id,
		niche = niche,
		level = 1,
	}
	career.nextProgrammerId += 1
	table.insert(career.programmers, programmer)
	career.stats.recruits += 1
	career.stats.team = #career.programmers
	career.stats.bestRarity = math.max(career.stats.bestRarity, rarity.order)
	if rarity.order >= 5 then
		career.pity = 0
	end
	CareerService.refreshBonuses(session)
	return programmer
end

---------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------
local Actions = {}

function Actions.acceptJobOffer(_player: Player, session, offerId: any)
	local career = session.data.career
	for i, offer in session.jobOffers do
		if offer.id == offerId then
			local company = Career.company(offer.companyId)
			table.remove(session.jobOffers, i)
			career.job = {
				companyId = company.id,
				rank = offer.rank,
				rankSince = os.time(),
				salaryMult = offer.salaryMult,
				xpMult = offer.xpMult,
			}
			career.stats.jobs += 1
			career.stats.bestRank = math.max(career.stats.bestRank, offer.rank)
			session.taskReadyAt = os.clock() + Career.TASK_INTERVAL
			session.taskNotified = false
			return true, "💼 ¡Contratado en " .. company.name .. " como " .. Career.Ranks[offer.rank].name .. "!"
		end
	end
	return false, "Esa oferta ya no está disponible."
end

function Actions.sendCV(_player: Player, session)
	local now = os.clock()
	if now < session.cvReadyAt then
		return false, "Espera " .. math.ceil(session.cvReadyAt - now) .. " s para enviar otro currículum."
	end
	session.cvReadyAt = now + Career.CV_COOLDOWN
	local offer = addJobOffer(nil, session)
	if not offer then
		return false, "Ninguna empresa nueva te ha contestado. Sube de nivel e inténtalo otra vez."
	end
	return true, "📨 " .. Career.company(offer.companyId).name .. " te ha hecho una oferta"
end

function Actions.quitJob(_player: Player, session)
	local career = session.data.career
	if not career.job then
		return false, nil
	end
	career.job = nil
	return true, "Has dejado tu trabajo."
end

function Actions.solveTask(player: Player, session)
	local career = session.data.career
	local job = career.job
	if not job then
		return false, "No tienes trabajo."
	end
	if os.clock() < session.taskReadyAt then
		return false, "Aún no hay tareas nuevas."
	end
	local company = Career.company(job.companyId)
	local pay = CareerService.salaryPerSec(session) * Career.TASK_SALARY_SECONDS
	ctx.gain(session.data, pay)
	CareerService.addXp(player, session, company.niche, jobXpRate(session) * Career.TASK_XP_SECONDS)
	career.stats.tasks += 1
	session.taskReadyAt = os.clock() + Career.TASK_INTERVAL
	session.taskNotified = false
	return true, "✅ Tarea resuelta: +" .. Config.formatMoney(pay), { money = true }
end

function Actions.foundAgency(player: Player, session)
	local data = session.data
	local career = data.career
	if career.agency then
		return false, nil
	end
	if Career.devLevel(career) < Career.AGENCY_LEVEL_REQUIRED then
		return false, "Necesitas nivel de programador " .. Career.AGENCY_LEVEL_REQUIRED .. "."
	end
	if data.money < Career.AGENCY_COST then
		return false, "No tienes suficiente dinero."
	end
	data.money -= Career.AGENCY_COST
	career.agency = { name = player.DisplayName .. " Dev Studio", officeLevel = 1, founded = os.time() }
	career.stats.agency = 1
	ctx.popup(player, "🏢 ¡Has fundado tu agencia!", "Ahora puedes fichar programadores.\n\nCada uno programa por ti y te da un % extra de TODO tu dinero. Cuanto más raro, mejor.\n\n¡Ve a la pestaña 👥 Agencia!")
	return true, nil
end

function Actions.upgradeOffice(_player: Player, session)
	local data = session.data
	local agency = data.career.agency
	if not agency then
		return false, nil
	end
	if agency.officeLevel >= Career.MAX_OFFICE_LEVEL then
		return false, "Oficina al máximo."
	end
	local cost = Career.officeUpgradeCost(agency.officeLevel + 1)
	if data.money < cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= cost
	agency.officeLevel += 1
	return true, "🏢 Oficina ampliada: " .. capacity(session) .. " puestos"
end

function Actions.recruit(player: Player, session)
	local data = session.data
	local career = data.career
	if not career.agency then
		return false, "Primero funda tu agencia."
	end
	if #career.programmers >= capacity(session) then
		return false, "Oficina llena: amplíala o despide a alguien."
	end
	local cost = CareerService.recruitCost(session)
	if data.money < cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= cost
	career.pity += 1
	local rarity
	if career.pity >= Career.PITY_INTERVIEWS then
		-- Garantía: Legendario o Mítico
		rarity = if ctx.random:NextNumber() < 0.1 then Career.RarityById.mitico else Career.RarityById.legendario
	else
		rarity = rollRarity("weight")
	end
	local programmer = hire(player, session, rarity, nil)
	return true, nil, { recruit = programmer }
end

function Actions.redeemTicket(player: Player, session, kind: any, nicheId: any)
	local career = session.data.career
	if not career.agency then
		return false, "Primero funda tu agencia."
	end
	if #career.programmers >= capacity(session) then
		return false, "Oficina llena: amplíala o despide a alguien."
	end
	if kind == "premium" and career.tickets.premium > 0 then
		career.tickets.premium -= 1
		return true, nil, { recruit = hire(player, session, rollRarity("premium"), nil) }
	elseif kind == "legendary" and career.tickets.legendary > 0 then
		if not nicheValid(nicheId) then
			return false, "Elige un nicho."
		end
		career.tickets.legendary -= 1
		return true, nil, { recruit = hire(player, session, Career.RarityById.legendario, nicheId) }
	end
	return false, "No tienes ese ticket."
end

local function findProgrammer(career, id: any)
	for i, programmer in career.programmers do
		if programmer.id == id then
			return programmer, i
		end
	end
	return nil, nil
end

function Actions.trainProgrammer(_player: Player, session, id: any)
	local data = session.data
	local programmer = findProgrammer(data.career, id)
	if not programmer then
		return false, nil
	end
	if programmer.level >= Career.PROGRAMMER_MAX_LEVEL then
		return false, "Nivel máximo."
	end
	local cost = Career.trainCost(programmer, ctx.income(session))
	if data.money < cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= cost
	programmer.level += 1
	CareerService.refreshBonuses(session)
	return true, "📚 " .. programmer.name .. " sube a nivel " .. programmer.level
end

function Actions.fireProgrammer(_player: Player, session, id: any)
	local career = session.data.career
	local programmer, index = findProgrammer(career, id)
	if not programmer or not index then
		return false, nil
	end
	table.remove(career.programmers, index)
	career.stats.team = #career.programmers
	CareerService.refreshBonuses(session)
	return true, "👋 " .. programmer.name .. " ha dejado la agencia."
end

CareerService.Actions = Actions

-- Tickets comprados con Robux
function CareerService.grantTickets(player: Player, session, ticket: string, amount: number)
	local tickets = session.data.career.tickets
	tickets[ticket] = (tickets[ticket] or 0) + amount
	ctx.notify(player, "🎟️ +" .. amount .. " ticket(s). Úsalos en la pestaña 👥 Agencia", "money")
end

---------------------------------------------------------------------
-- Estado para el cliente
---------------------------------------------------------------------
function CareerService.buildState(session)
	local data = session.data
	local career = data.career
	local income = ctx.income(session)

	local nicheLevels = {}
	for _, niche in Career.Niches do
		nicheLevels[niche.id] = Career.nicheLevel(career, niche.id)
	end

	local job = nil
	if career.job then
		local company = Career.company(career.job.companyId)
		if company then
			local _, reason = Career.canPromote(career.job, nicheLevels[company.niche], os.time())
			job = {
				companyId = company.id,
				salaryMult = career.job.salaryMult or 1,
				rank = career.job.rank,
				salary = CareerService.salaryPerSec(session),
				xpRate = jobXpRate(session) * (if session.bonuses.xpPass then 2 else 1),
				promotion = reason,
				taskLeft = math.max(0, session.taskReadyAt - os.clock()),
			}
		end
	end

	local programmers = {}
	for _, programmer in career.programmers do
		local work, bonus = Career.programmerPower(programmer, session.bonuses.agencyPro)
		table.insert(programmers, {
			id = programmer.id,
			name = programmer.name,
			rarity = programmer.rarity,
			niche = programmer.niche,
			level = programmer.level,
			work = work,
			bonus = bonus,
			trainCost = Career.trainCost(programmer, income),
		})
	end
	-- Los mejores primero
	table.sort(programmers, function(a, b)
		local ra, rb = Career.RarityById[a.rarity].order, Career.RarityById[b.rarity].order
		if ra ~= rb then
			return ra > rb
		end
		return a.level > b.level
	end)

	local agency = nil
	if career.agency then
		agency = {
			name = career.agency.name,
			officeLevel = career.agency.officeLevel,
			capacity = capacity(session),
			upgradeCost = if career.agency.officeLevel < Career.MAX_OFFICE_LEVEL then Career.officeUpgradeCost(career.agency.officeLevel + 1) else nil,
		}
	end

	local moneyMult = Config.moneyMult(data, session.bonuses)
	local jobOffers = {}
	for _, offer in session.jobOffers do
		local company = Career.company(offer.companyId)
		table.insert(jobOffers, {
			id = offer.id,
			companyId = offer.companyId,
			rank = offer.rank,
			salaryMult = offer.salaryMult,
			xpMult = offer.xpMult,
			salary = Career.salary(company, offer.rank, nicheLevels[company.niche], moneyMult, offer.salaryMult) * jobFairMult(session),
			xpRate = Career.jobXpRate(company, offer.rank, offer.xpMult) * (if session.bonuses.xpPass then 2 else 1) * jobFairMult(session),
			timeLeft = math.max(0, offer.expiresAt - os.clock()),
		})
	end
	table.sort(jobOffers, function(a, b)
		return a.salary > b.salary
	end)

	return {
		jobOffers = jobOffers,
		cvLeft = math.max(0, session.cvReadyAt - os.clock()),
		xp = career.xp,
		nicheLevels = nicheLevels,
		devLevel = Career.devLevel(career),
		job = job,
		agency = agency,
		programmers = programmers,
		pity = career.pity,
		tickets = career.tickets,
		recruitCost = CareerService.recruitCost(session),
		stats = career.stats,
	}
end

return CareerService
