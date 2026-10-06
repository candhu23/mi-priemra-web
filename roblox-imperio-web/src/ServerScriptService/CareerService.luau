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
	return Career.salary(company, job.rank, Career.nicheLevel(career, company.niche), Config.moneyMult(session.data, session.bonuses))
end

local function jobXpRate(session): number
	local job = session.data.career.job
	local company = job and Career.company(job.companyId)
	if not company then
		return 0
	end
	return Career.jobXpRate(company, job.rank, 1)
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

local function capacity(session): number
	local agency = session.data.career.agency
	return if agency then Career.officeCapacity(agency.officeLevel, session.bonuses.agencyPro) else 0
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

function Actions.applyJob(_player: Player, session, companyId: any)
	local career = session.data.career
	local company = type(companyId) == "number" and Career.company(companyId)
	if not company then
		return false, nil
	end
	if career.job and career.job.companyId == company.id then
		return false, "Ya trabajas aquí."
	end
	local level = Career.nicheLevel(career, company.niche)
	if level < company.reqLevel then
		return false, "Necesitas nivel " .. company.reqLevel .. " en " .. Career.NicheById[company.niche].name .. "."
	end
	career.job = { companyId = company.id, rank = 1, rankSince = os.time() }
	career.stats.jobs += 1
	career.stats.bestRank = math.max(career.stats.bestRank, 1)
	session.taskReadyAt = os.clock() + Career.TASK_INTERVAL
	session.taskNotified = false
	return true, "💼 ¡Contratado en " .. company.name .. " como Junior!"
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
	local cost = Career.recruitCost(ctx.income(session))
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

	return {
		xp = career.xp,
		nicheLevels = nicheLevels,
		devLevel = Career.devLevel(career),
		job = job,
		agency = agency,
		programmers = programmers,
		pity = career.pity,
		tickets = career.tickets,
		recruitCost = Career.recruitCost(income),
		stats = career.stats,
	}
end

return CareerService
