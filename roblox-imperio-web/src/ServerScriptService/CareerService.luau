--[[
	CareerService (ModuleScript en ServerScriptService)

	Lógica de servidor de la carrera (v3): XP por nicho, ENCARGOS de las
	500 empresas (te piden una web concreta con un plazo y pagan mucho más
	que vendiéndola), rangos de Junior a CTO, tu agencia, fichajes de
	programadores (con especialidad y rasgo) y tickets comprados con Robux.
	La carrera NO se reinicia al salir a bolsa.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local StatePatch = require(ReplicatedStorage:WaitForChild("StatePatch"))
local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))

local CareerService = {}

type Ctx = {
	gain: (data: any, amount: number, tag: string?) -> (),
	spend: (data: any, amount: number, tag: string) -> (),
	notify: (player: Player, text: string, kind: string?) -> (),
	popup: (player: Player, title: string, body: string) -> (),
	income: (session: any) -> number,
	random: Random,
	-- Lo que pagaría un cliente normal por una web nueva de ese tipo
	saleValue: (session: any, typeId: string) -> number,
	-- Trabajo por segundo aproximado del jugador (para calcular plazos)
	workRate: (session: any) -> number,
	isNight: () -> boolean,
	progress: (session: any, stat: string, amount: number) -> (),
	-- Empieza a programar la web de un encargo (devuelve ok, mensaje)
	startContract: (session: any, typeId: string, contractId: number) -> (boolean, string?),
}
local ctx: Ctx

function CareerService.init(context: Ctx)
	ctx = context
end

function CareerService.newData()
	return {
		xp = {},
		contracts = {}, -- encargos aceptados
		nextContractId = 1,
		agency = nil,
		programmers = {},
		nextProgrammerId = 1,
		pity = 0,
		tickets = { premium = 0, legendary = 0 },
		stats = { contracts = 0, rank = 1, bestRank = 0, devLevel = 1, agency = 0, bestRarity = 0, team = 0, recruits = 0, expired = 0 },
	}
end

local function nicheValid(nicheId: any): boolean
	return type(nicheId) == "string" and Career.NicheById[nicheId] ~= nil
end

local function randomRange(range: { number }): number
	return range[1] + ctx.random:NextNumber() * (range[2] - range[1])
end

-- Partidas de antes de la v3: sin trabajo, y los programadores reciben
-- especialidad y rasgo
function CareerService.migrate(career)
	career.job = nil
	career.contracts = career.contracts or {}
	for _, programmer in career.programmers do
		if not programmer.role then
			programmer.role = Career.Roles[ctx.random:NextInteger(1, #Career.Roles)].id
		end
		if not programmer.trait then
			programmer.trait = Career.Traits[ctx.random:NextInteger(1, #Career.Traits)].id
		end
		programmer.xp = programmer.xp or 0
	end
	career.stats.rank = Career.rankOf(career)
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
-- Bonus de la agencia
---------------------------------------------------------------------
function CareerService.refreshBonuses(session)
	local data = session.data
	local projectNiche = data.project and data.project.niche or nil
	local work, totals = Career.agencyTotals(data.career, projectNiche, session.bonuses.agencyPro, ctx.isNight())
	session.bonuses.agencyWork = work
	session.bonuses.agencyBonus = totals.money
	session.bonuses.agencyQuality = totals.quality
	session.bonuses.agencyVisits = totals.visits
	session.bonuses.agencySale = totals.sale
	session.bonuses.agencyRare = totals.rare
end

---------------------------------------------------------------------
-- Rangos
---------------------------------------------------------------------
local function checkRank(player: Player, session)
	local career = session.data.career
	local rank = Career.rankOf(career)
	if rank > (career.stats.rank or 1) then
		career.stats.rank = rank
		career.stats.bestRank = math.max(career.stats.bestRank, rank)
		local def = Career.Ranks[rank]
		ctx.popup(player, "🎉 ¡Ascenso a " .. def.name .. "!",
			string.format("Ahora puedes tener %d encargos a la vez y te pagan x%.2f por cada uno.", def.slots, def.payMult))
	else
		career.stats.rank = math.max(career.stats.rank or 1, rank)
	end
end

local function rankDef(career)
	return Career.Ranks[Career.rankOf(career)]
end

---------------------------------------------------------------------
-- Encargos: tablón (de la sesión) y aceptados (se guardan)
---------------------------------------------------------------------
local function fairMult(session): number
	return if session.bonuses.weekend == "contracts" then Config.WEEKEND_CONTRACT_MULT else 1
end

local function nextBoardDelay(session): number
	local delay = randomRange(Career.CONTRACT_INTERVAL)
	if session.bonuses.weekend == "contracts" then
		delay /= Config.WEEKEND_CONTRACT_SPEED
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

-- Tipos de web que ya puedes programar (los mejores al final)
local function unlockedTypes(data)
	local list = {}
	for _, def in Config.WebTypes do
		if data.reputation >= def.rep and Config.eraAllows(data, def) then
			table.insert(list, def)
		end
	end
	return list
end

-- Plazo: lo que tardarías a tu ritmo actual × 3 (mínimo 3 minutos)
local function contractDuration(session, def): number
	local rate = math.max(ctx.workRate(session), 0.5)
	local seconds = def.work / rate * Career.CONTRACT_DEADLINE_FACTOR
	return math.clamp(math.ceil(seconds / 10) * 10, Career.CONTRACT_MIN_DEADLINE, 1800)
end

local function makeContract(session)
	local data = session.data
	local career = data.career
	local types = unlockedTypes(data)
	if #types == 0 then
		return nil
	end
	-- Casi siempre de los 3 mejores tipos que ya sabes hacer
	local def = types[ctx.random:NextInteger(math.max(1, #types - 2), #types)]
	-- Nicho: el que tienes elegido, en el que destacas o uno al azar
	local roll = ctx.random:NextNumber()
	local nicheId = if roll < 0.4 then (data.selectedNiche or Career.DEFAULT_NICHE)
		elseif roll < 0.65 then bestNiche(career)
		else Career.Niches[ctx.random:NextInteger(1, #Career.Niches)].id
	-- Las mejores empresas solo te escriben si tienes nivel en su nicho
	local level = Career.nicheLevel(career, nicheId)
	local eligible = {}
	for _, company in Career.CompaniesByNiche[nicheId] do
		if company.reqLevel <= level then
			table.insert(eligible, company)
		end
	end
	local company = eligible[ctx.random:NextInteger(math.max(1, #eligible - 9), #eligible)]
	local pay = ctx.saleValue(session, def.id) * Career.CONTRACT_PAY * rankDef(career).payMult * company.payScale * fairMult(session)
	local id = career.nextContractId
	career.nextContractId += 1
	return {
		id = id,
		companyId = company.id,
		type = def.id,
		niche = nicheId,
		pay = math.floor(pay),
		rep = math.floor(def.repReward * Career.CONTRACT_REP),
		xp = def.work / 5 * Career.CONTRACT_XP,
		duration = contractDuration(session, def),
		expiresAt = os.clock() + randomRange(Career.CONTRACT_LIFETIME),
	}
end

local function addToBoard(player: Player?, session): any
	local board = session.contractBoard
	if #board >= Career.CONTRACT_BOARD then
		-- Se cae el que menos tiempo le queda
		table.sort(board, function(a, b)
			return a.expiresAt > b.expiresAt
		end)
		table.remove(board)
	end
	local contract = makeContract(session)
	if contract then
		table.insert(board, contract)
		if player and Config.isUnlocked(session.data, "career") then
			local company = Career.company(contract.companyId)
			local def = Config.WebTypeById[contract.type]
			ctx.notify(player, string.format("📨 Nuevo encargo de %s: %s %s por %s · pestaña Carrera", company.name, def.emoji, def.name, Config.formatMoney(contract.pay)), "info")
		end
	end
	return contract
end

-- Llamar al crear la sesión del jugador
function CareerService.initSession(session)
	session.contractBoard = {}
	session.nextContractAt = os.clock() + nextBoardDelay(session)
	session.askReadyAt = 0
	addToBoard(nil, session)
	addToBoard(nil, session)
end

-- Encargo aceptado que encaja con la web terminada (tipo y nicho)
local function matchingContract(career, project)
	local now = os.time()
	local fallback = nil
	for i, contract in career.contracts do
		if contract.deadline > now and contract.type == project.type and contract.niche == (project.niche or Career.DEFAULT_NICHE) then
			if contract.id == project.contractId then
				return contract, i
			end
			fallback = fallback or i
		end
	end
	if fallback then
		return career.contracts[fallback], fallback
	end
	return nil, nil
end

-- Al terminar una web: si es de un encargo, se entrega (y no ocupa hueco).
-- Devuelve true si se ha entregado.
function CareerService.tryDeliver(player: Player, session, project, variant): boolean
	local data = session.data
	local career = data.career
	local contract, index = matchingContract(career, project)
	if not contract or not index then
		return false
	end
	table.remove(career.contracts, index)
	local company = Career.company(contract.companyId)
	local def = Config.WebTypeById[contract.type]
	-- Una web rara encanta al cliente: paga el doble
	local pay = contract.pay * (if variant then 2 else 1)
	ctx.gain(data, pay, "encargos")
	data.reputation += contract.rep
	CareerService.addXp(player, session, contract.niche, contract.xp)
	career.stats.contracts += 1
	ctx.progress(session, "contracts", 1)
	ctx.notify(player, string.format("🧾 ¡Encargo entregado a %s! %s %s · +%s y +%s de reputación", company.name, def.emoji, def.name,
		Config.formatMoney(pay), Config.formatNumber(contract.rep)), "money")
	checkRank(player, session)
	return true
end

---------------------------------------------------------------------
-- Cada segundo
---------------------------------------------------------------------
function CareerService.tick(player: Player, session, dt: number)
	local data = session.data
	local career = data.career
	local now = os.clock()
	-- Tablón de encargos
	local board = session.contractBoard
	for i = #board, 1, -1 do
		if board[i].expiresAt <= now then
			table.remove(board, i)
		end
	end
	if now >= session.nextContractAt then
		session.nextContractAt = now + nextBoardDelay(session)
		addToBoard(player, session)
	end
	-- Encargos aceptados que se pasan de plazo
	local unix = os.time()
	for i = #career.contracts, 1, -1 do
		local contract = career.contracts[i]
		if contract.deadline <= unix then
			table.remove(career.contracts, i)
			career.stats.expired += 1
			local company = Career.company(contract.companyId)
			ctx.notify(player, "⌛ Se acabó el plazo del encargo de " .. (if company then company.name else "?") .. ". ¡Otra vez será!", "error")
		end
	end
	checkRank(player, session)

	-- Los programadores ganan experiencia trabajando y suben de nivel solos
	if career.agency then
		local mentors = 0
		for _, programmer in career.programmers do
			if programmer.trait == "mentor" then
				mentors += 1
			end
		end
		for _, programmer in career.programmers do
			if programmer.level < Career.PROGRAMMER_MAX_LEVEL then
				local others = mentors - (if programmer.trait == "mentor" then 1 else 0)
				local rate = (if programmer.trait == "incansable" then 2 else 1) * (1 + 0.25 * others)
					* (if Career.hasPerk(career, "cafe") then 1.3 else 1)
				programmer.xp = (programmer.xp or 0) + dt * rate
				local needed = Career.programmerXpNeeded(programmer.level)
				if programmer.xp >= needed then
					programmer.xp -= needed
					programmer.level += 1
					ctx.notify(player, string.format("⭐ %s ha subido a nivel %d trabajando", programmer.name, programmer.level), "success")
				end
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
		xp = 0,
		role = Career.Roles[ctx.random:NextInteger(1, #Career.Roles)].id,
		trait = Career.Traits[ctx.random:NextInteger(1, #Career.Traits)].id,
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

local function findContract(list, id: any)
	for i, contract in list do
		if contract.id == id then
			return contract, i
		end
	end
	return nil, nil
end

function Actions.acceptContract(_player: Player, session, contractId: any)
	local career = session.data.career
	local contract, index = findContract(session.contractBoard, contractId)
	if not contract or not index then
		return false, "Ese encargo ya no está disponible."
	end
	local slots = rankDef(career).slots
	if #career.contracts >= slots then
		return false, string.format("Como %s solo puedes tener %d encargo(s) a la vez. Sube de rango para tener más.", rankDef(career).name, slots)
	end
	table.remove(session.contractBoard, index)
	table.insert(career.contracts, {
		id = contract.id,
		companyId = contract.companyId,
		type = contract.type,
		niche = contract.niche,
		pay = contract.pay,
		rep = contract.rep,
		xp = contract.xp,
		duration = contract.duration,
		deadline = os.time() + contract.duration,
	})
	local company = Career.company(contract.companyId)
	return true, "🤝 Encargo aceptado: " .. company.name .. ". Pulsa «Programar ahora» para empezar."
end

function Actions.abandonContract(_player: Player, session, contractId: any)
	local career = session.data.career
	local contract, index = findContract(career.contracts, contractId)
	if not contract or not index then
		return false, nil
	end
	table.remove(career.contracts, index)
	if session.data.project and session.data.project.contractId == contract.id then
		session.data.project.contractId = nil
	end
	return true, "Has dejado el encargo."
end

-- Elige el nicho del encargo y empieza a programar la web que piden
function Actions.workOnContract(_player: Player, session, contractId: any)
	local data = session.data
	local contract = findContract(data.career.contracts, contractId)
	if not contract then
		return false, nil
	end
	data.selectedNiche = contract.niche
	return ctx.startContract(session, contract.type, contract.id)
end

-- Pedir un encargo nuevo (cada 60 s)
function Actions.askContract(_player: Player, session)
	local now = os.clock()
	if now < session.askReadyAt then
		return false, "Espera " .. math.ceil(session.askReadyAt - now) .. " s para pedir otro encargo."
	end
	session.askReadyAt = now + Career.ASK_COOLDOWN
	local contract = addToBoard(nil, session)
	if not contract then
		return false, "Ninguna empresa te ha contestado. Inténtalo otra vez."
	end
	return true, "📨 " .. Career.company(contract.companyId).name .. " te ha hecho un encargo"
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
	ctx.spend(data, Career.AGENCY_COST, "agencia")
	career.agency = { name = player.DisplayName .. " Dev Studio", officeLevel = 1, founded = os.time() }
	career.stats.agency = 1
	ctx.popup(player, "🏢 ¡Has fundado tu agencia!", "Ahora puedes fichar programadores.\n\nCada uno tiene una especialidad (programación, diseño, marketing, ventas o datos) y un rasgo. Cuanto más raro, más aporta, y suben de nivel solos trabajando.\n\n¡Ve a la pestaña 👥 Agencia!")
	return true, nil
end

function Actions.upgradeOffice(player: Player, session)
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
	ctx.spend(data, cost, "agencia")
	agency.officeLevel += 1
	for _, perk in Career.OfficePerks do
		if perk.level == agency.officeLevel then
			ctx.popup(player, "🏢 ¡Oficina ampliada!", string.format("%s %s\n\n%s\n\n(Mira tu edificio de la agencia: ¡ya se ve!)", perk.emoji, perk.name, perk.desc))
		end
	end
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
	ctx.spend(data, cost, "agencia")
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
	ctx.spend(data, cost, "agencia")
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
local function contractRow(contract, clockNow: number, unixNow: number)
	return {
		id = contract.id,
		companyId = contract.companyId,
		type = contract.type,
		niche = contract.niche,
		pay = contract.pay,
		rep = contract.rep,
		xp = contract.xp,
		duration = contract.duration,
		timeLeft = if contract.deadline then math.max(0, contract.deadline - unixNow) else math.max(0, math.ceil(contract.expiresAt - clockNow)),
	}
end

function CareerService.buildState(session)
	local data = session.data
	local career = data.career
	local income = ctx.income(session)
	local clockNow, unixNow = os.clock(), os.time()

	local nicheLevels = {}
	for _, niche in Career.Niches do
		nicheLevels[niche.id] = Career.nicheLevel(career, niche.id)
	end

	local board, contracts = {}, {}
	for _, contract in session.contractBoard do
		table.insert(board, contractRow(contract, clockNow, unixNow))
	end
	table.sort(board, function(a, b)
		return a.pay > b.pay
	end)
	for _, contract in career.contracts do
		local row = contractRow(contract, clockNow, unixNow)
		row.working = data.project ~= nil and data.project.type == contract.type and (data.project.niche or Career.DEFAULT_NICHE) == contract.niche
		table.insert(contracts, row)
	end

	local isNight = ctx.isNight()
	local programmers = {}
	for _, programmer in career.programmers do
		local work, stats = Career.programmerPower(programmer, session.bonuses.agencyPro, isNight)
		table.insert(programmers, {
			id = programmer.id,
			name = programmer.name,
			rarity = programmer.rarity,
			niche = programmer.niche,
			level = programmer.level,
			role = programmer.role or "dev",
			trait = programmer.trait,
			-- La XP sube cada segundo: se manda en pasos del 1 % de la barra
			xp = math.floor(math.floor((programmer.xp or 0) / Career.programmerXpNeeded(programmer.level) * 100) * Career.programmerXpNeeded(programmer.level) / 100),
			xpNeeded = Career.programmerXpNeeded(programmer.level),
			work = work,
			stats = stats,
			trainCost = StatePatch.sig3(Career.trainCost(programmer, income)),
		})
	end
	-- Orden fijo (por id) para que el estado cambie poco; el cliente los
	-- ordena para enseñarlos (los mejores primero)
	table.sort(programmers, function(a, b)
		return a.id < b.id
	end)

	local agency = nil
	if career.agency then
		agency = {
			name = career.agency.name,
			officeLevel = career.agency.officeLevel,
			capacity = capacity(session),
			upgradeCost = if career.agency.officeLevel < Career.MAX_OFFICE_LEVEL then Career.officeUpgradeCost(career.agency.officeLevel + 1) else nil,
			totals = {
				work = session.bonuses.agencyWork,
				money = session.bonuses.agencyBonus,
				quality = session.bonuses.agencyQuality,
				visits = session.bonuses.agencyVisits,
				sale = session.bonuses.agencySale,
				rare = session.bonuses.agencyRare,
			},
		}
	end

	local rank = Career.rankOf(career)
	return {
		rank = rank,
		slots = Career.Ranks[rank].slots,
		board = board,
		contracts = contracts,
		nextContractIn = math.max(0, math.ceil(session.nextContractAt - clockNow)),
		askLeft = math.max(0, math.ceil(session.askReadyAt - clockNow)),
		fair = session.bonuses.weekend == "contracts",
		xp = career.xp,
		nicheLevels = nicheLevels,
		devLevel = Career.devLevel(career),
		agency = agency,
		programmers = programmers,
		pity = career.pity,
		tickets = career.tickets,
		recruitCost = CareerService.recruitCost(session),
		stats = career.stats,
	}
end

return CareerService
