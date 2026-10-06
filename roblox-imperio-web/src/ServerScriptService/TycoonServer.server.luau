--[[
	TycoonServer (Script en ServerScriptService)

	El servidor manda: guarda el dinero, calcula ingresos cada segundo y
	comprueba cada acción que pide el jugador (así nadie puede hacer
	trampas desde su ordenador). También gestiona recompensas diarias,
	regalos, compras con Robux y la clasificación global.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterPlayer = game:GetService("StarterPlayer")
local PolicyService = game:GetService("PolicyService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local PlotManager = require(ServerScriptService:WaitForChild("PlotManager"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))

local random = Random.new()
local Monetization = Config.Monetization

StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED

---------------------------------------------------------------------
-- Remotes (canales de comunicación cliente <-> servidor)
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "TycoonRemotes"

local actionFunction = Instance.new("RemoteFunction")
actionFunction.Name = "Action"
actionFunction.Parent = remotes

local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "State"
stateEvent.Parent = remotes

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

local openComputerEvent = Instance.new("RemoteEvent")
openComputerEvent.Name = "OpenComputer"
openComputerEvent.Parent = remotes

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Guardado
---------------------------------------------------------------------
local store: DataStore? = nil
local leaderboardStore: OrderedDataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[ImperioWeb] DataStore no disponible, no se guardará la partida:", result)
	end
	local okBoard, board = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_NAME)
	end)
	if okBoard then
		leaderboardStore = board
	end
end

local function newData()
	return {
		money = Config.STARTING_MONEY,
		totalEarned = 0, -- ganado en esta partida (se reinicia al salir a bolsa)
		lifetimeEarned = 0, -- ganado desde siempre
		reputation = 0,
		shares = 0,
		ipoCount = 0,
		sites = {},
		project = nil,
		autoType = nil,
		companies = {},
		unlockedAds = { adsimple = true },
		maintenance = 0, -- $/s de contratos de mantenimiento
		goals = {},
		nextSiteId = 1,
		stats = { built = 0, sold = 0, clicks = 0, crits = 0, byType = {} },
		daily = { lastDay = -1, streak = 0 },
		boostUntil = 0,
		receipts = {},
		selectedNiche = Career.DEFAULT_NICHE,
		career = CareerService.newData(),
		tutorialDone = false,
		dailyMissions = { day = -1, list = {}, bonusGiven = false },
		settings = { muted = false },
		lastOnline = os.time(),
	}
end

-- Rellena campos que falten en partidas guardadas con versiones antiguas
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" and key ~= "sites" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function dataKey(player: Player): string
	return "player_" .. player.UserId
end

---------------------------------------------------------------------
-- Sesiones de jugador
---------------------------------------------------------------------
type Offer = { id: number, company: string, niche: string, type: string, mult: number, expiresAt: number }
type ActiveEvent = { id: string, name: string, endsAt: number, siteId: number? }
type Bonuses = {
	pass: boolean,
	turbo: boolean,
	slotsPass: boolean,
	agencyPro: boolean,
	xpPass: boolean,
	boost: boolean,
	friends: number,
	premium: boolean,
	group: boolean,
	randomRestricted: boolean, -- Roblox no permite artículos aleatorios de pago a este jugador
	agencyWork: number,
	agencyBonus: number,
}
type Session = {
	data: any,
	canSave: boolean,
	bonuses: Bonuses,
	offers: { Offer },
	nextOfferId: number,
	event: ActiveEvent?,
	nextEventAt: number,
	giftReadyAt: number,
	taskReadyAt: number,
	taskNotified: boolean,
	lastManualSave: number,
	lastSaveOk: boolean?,
	lastSaveAt: number,
	income: number,
	clickWindowStart: number,
	clickCount: number,
	actionWindowStart: number,
	actionCount: number,
	friendIds: { [number]: boolean },
	goalNotified: { [string]: boolean },
	leaderMoney: IntValue,
	leaderShares: IntValue,
	leaderLevel: IntValue,
}

local sessions: { [Player]: Session } = {}

local function notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

-- Ventana emergente en el cliente
local function popup(player: Player, title: string, body: string)
	notifyEvent:FireClient(player, title, "popup", body)
end

local function gain(data, amount: number)
	if amount <= 0 or amount ~= amount or amount == math.huge then
		return
	end
	data.money += amount
	data.totalEarned += amount
	data.lifetimeEarned += amount
end

local function findSite(data, siteId: any)
	for i, site in data.sites do
		if site.id == siteId then
			return site, i
		end
	end
	return nil, nil
end

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

-- Ingresos por segundo (webs + empresas + mantenimiento)
local function computeIncome(session: Session, withEvents: boolean): number
	local data = session.data
	local moneyMult = Config.moneyMult(data, session.bonuses)
	local total = 0
	for _, site in data.sites do
		local mult = if withEvents then eventVisitMult(session, site) else 1
		total += Config.siteIncome(data, site, Config.siteVisits(data, site, mult), moneyMult)
	end
	total += Config.companiesIncome(data, moneyMult)
	total += data.maintenance
	total += CareerService.salaryPerSec(session)
	return total
end

-- Dinero equivalente a "minutes" minutos de ingresos (mínimo "min")
local function incomeReward(session: Session, minutes: number, min: number): number
	return math.max(min, computeIncome(session, false) * minutes * 60)
end

local function randomSiteName(): string
	local parts = Config.SiteNameParts
	return parts.first[random:NextInteger(1, #parts.first)]
		.. parts.second[random:NextInteger(1, #parts.second)]
		.. parts.tld[random:NextInteger(1, #parts.tld)]
end

local function unlockedTypes(data)
	local list = {}
	for _, def in Config.WebTypes do
		if data.reputation >= def.rep then
			table.insert(list, def)
		end
	end
	return list
end

local function makeOffer(session: Session, mult: number?): Offer
	local data = session.data
	-- 70 % de las veces piden un tipo de web que ya tienes
	local typeId
	if #data.sites > 0 and random:NextNumber() < 0.7 then
		typeId = data.sites[random:NextInteger(1, #data.sites)].type
	else
		local types = unlockedTypes(data)
		typeId = types[random:NextInteger(1, #types)].id
	end
	local commercial = Config.level(data, "comercial")
	-- La empresa sale de las 500; a menudo es del nicho de alguna de tus webs
	local company
	if #data.sites > 0 and random:NextNumber() < 0.5 then
		local niche = data.sites[random:NextInteger(1, #data.sites)].niche or Career.DEFAULT_NICHE
		local list = Career.CompaniesByNiche[niche]
		company = list[random:NextInteger(1, #list)]
	else
		company = Career.Companies[random:NextInteger(1, #Career.Companies)]
	end
	session.nextOfferId += 1
	return {
		id = session.nextOfferId,
		company = company.name,
		niche = company.niche,
		type = typeId,
		mult = mult or (0.9 + random:NextNumber() * 0.9 + math.min(commercial * 0.03, 0.9)),
		expiresAt = os.clock() + Config.OFFER_LIFETIME + random:NextNumber() * 30,
	}
end

local function refreshOffers(session: Session)
	local now = os.clock()
	for i = #session.offers, 1, -1 do
		if session.offers[i].expiresAt <= now then
			table.remove(session.offers, i)
		end
	end
	while #session.offers < Config.OFFER_COUNT do
		table.insert(session.offers, makeOffer(session))
	end
end

-- Se define más abajo (misiones diarias), pero se usa al terminar webs
local progressDaily: (session: Session, stat: string, amount: number) -> ()

---------------------------------------------------------------------
-- Proyectos (webs en construcción)
---------------------------------------------------------------------
local function canStartProject(session: Session, def): (boolean, string?)
	local data = session.data
	if data.project then
		return false, "Ya estás programando una web."
	end
	if data.reputation < def.rep then
		return false, "Necesitas " .. Config.formatNumber(def.rep) .. " de reputación."
	end
	if #data.sites >= Config.slots(data, session.bonuses) then
		return false, "No te quedan huecos. Vende una web o mejora el Hosting."
	end
	if data.money < def.cost then
		return false, "No tienes suficiente dinero."
	end
	return true, nil
end

local function startProject(data, def)
	data.money -= def.cost
	data.project = { type = def.id, progress = 0, required = def.work, niche = data.selectedNiche or Career.DEFAULT_NICHE }
end

local function tryAutoStart(session: Session)
	local data = session.data
	if data.project or not data.autoType or Config.level(data, "ia_lab") < 1 then
		return
	end
	local def = Config.WebTypeById[data.autoType]
	if def and canStartProject(session, def) then
		startProject(data, def)
	end
end

local function finishProject(player: Player, session: Session)
	local data = session.data
	local project = data.project
	if not project then
		return
	end
	local def = Config.WebTypeById[project.type]
	data.project = nil

	local niche = project.niche or Career.DEFAULT_NICHE
	local quality = (0.85 + random:NextNumber() * 0.3) * (1 + 0.08 * Config.level(data, "design")) * Career.qualityBonus(data.career, niche)
	local site = {
		id = data.nextSiteId,
		type = def.id,
		name = randomSiteName(),
		niche = niche,
		quality = math.floor(quality * 100) / 100,
		seo = 0,
		design = 0,
		network = "adsimple",
		adLevel = 1,
		totalVisits = 0,
		earned = 0,
	}
	-- Usa automáticamente la mejor app de anuncios desbloqueada
	local bestValue = 0
	for id in data.unlockedAds do
		local network = Config.AdNetworkById[id]
		if network and network.rpv * (1 - network.penalty) > bestValue then
			bestValue = network.rpv * (1 - network.penalty)
			site.network = id
		end
	end
	data.nextSiteId += 1
	table.insert(data.sites, site)
	data.stats.built += 1
	data.stats.byType[def.id] = (data.stats.byType[def.id] or 0) + 1
	data.reputation += def.repReward
	CareerService.addXp(player, session, niche, def.work / 5)
	progressDaily(session, "built", 1)

	if not data.autoType then
		notify(player, string.format("%s ¡%s terminada! Calidad %d%%", def.emoji, site.name, math.floor(site.quality * 100)), "success")
	end
	tryAutoStart(session)
end

local function addWork(player: Player, session: Session, amount: number)
	local project = session.data.project
	if not project then
		return
	end
	project.progress += amount
	if project.progress >= project.required then
		finishProject(player, session)
	end
end

---------------------------------------------------------------------
-- Objetivos y recompensa diaria
---------------------------------------------------------------------
-- Los objetivos ya no se pagan solos: avisan y se reclaman en Misiones.
-- data.goals[id] = true significa "premio reclamado".
local function checkGoals(player: Player, session: Session)
	local data = session.data
	for _, goal in Config.Goals do
		if not data.goals[goal.id] and not session.goalNotified[goal.id] and goal.value(data) >= goal.target then
			session.goalNotified[goal.id] = true
			notify(player, "🎯 ¡Objetivo cumplido: " .. goal.text .. "! Reclama tu premio en 🎯 Misiones", "goal")
		end
	end
end

---------------------------------------------------------------------
-- Misiones diarias
---------------------------------------------------------------------
local function ensureDailyMissions(session: Session)
	local data = session.data
	local today = Config.dayIndex(os.time())
	local daily = data.dailyMissions
	if daily.day == today and #daily.list > 0 then
		return
	end
	local pool = {}
	for _, def in Config.DailyMissionPool do
		local available = (def.needs == nil)
			or (def.needs == "job" and data.career.job ~= nil)
			or (def.needs == "agency" and data.career.agency ~= nil)
		if available then
			table.insert(pool, def)
		end
	end
	local list = {}
	for tier = 1, math.min(Config.DAILY_MISSION_COUNT, #pool) do
		local def = table.remove(pool, random:NextInteger(1, #pool))
		table.insert(list, { id = def.id, tier = tier, target = def.amounts[tier], progress = 0, claimed = false })
	end
	daily.day = today
	daily.list = list
	daily.bonusGiven = false
end

function progressDaily(session: Session, stat: string, amount: number)
	for _, mission in session.data.dailyMissions.list do
		if mission.id == stat and not mission.claimed then
			mission.progress = math.min(mission.target, mission.progress + amount)
		end
	end
end

-- Acción del cliente que cuenta para una misión diaria
local ACTION_STATS = {
	upgradeSeo = "seo",
	buyCompany = "companies",
	claimGift = "gifts",
	solveTask = "tasks",
	recruit = "recruits",
	redeemTicket = "recruits",
	sellToOffer = "sold",
	quickSell = "sold",
	click = "clicks",
}

-- Devuelve (disponible, día de la racha que tocaría 1..7)
local function dailyStatus(data): (boolean, number)
	local today = Config.dayIndex(os.time())
	local daily = data.daily
	if daily.lastDay == today then
		return false, daily.streak
	end
	if daily.lastDay == today - 1 then
		return true, daily.streak % #Config.DailyRewards + 1
	end
	return true, 1
end

---------------------------------------------------------------------
-- Estado que se envía al cliente
---------------------------------------------------------------------
local function buildState(session: Session)
	local data = session.data
	local bonuses = session.bonuses
	local moneyMult = Config.moneyMult(data, bonuses)
	local now = os.clock()

	local sites = {}
	for _, site in data.sites do
		local visits = Config.siteVisits(data, site, eventVisitMult(session, site))
		table.insert(sites, {
			id = site.id,
			type = site.type,
			name = site.name,
			quality = site.quality,
			seo = site.seo,
			network = site.network,
			adLevel = site.adLevel,
			visits = visits,
			income = Config.siteIncome(data, site, visits, moneyMult),
			saleBase = Config.saleBase(data, site, moneyMult),
			seoCost = Config.seoCost(site),
			niche = site.niche,
			design = site.design or 0,
			designCost = Config.designCost(site),
			totalVisits = site.totalVisits or 0,
			earned = site.earned or 0,
			viral = session.event ~= nil and session.event.id == "viral" and session.event.siteId == site.id,
		})
	end

	local offers = {}
	for _, offer in session.offers do
		table.insert(offers, {
			id = offer.id,
			company = offer.company,
			niche = offer.niche,
			type = offer.type,
			mult = offer.mult,
			timeLeft = offer.expiresAt - now,
		})
	end

	local dailyAvailable, dailyDay = dailyStatus(data)
	local dailyDef = Config.DailyRewards[dailyDay] or Config.DailyRewards[1]

	return {
		money = data.money,
		income = session.income,
		totalEarned = data.totalEarned,
		lifetimeEarned = data.lifetimeEarned,
		reputation = data.reputation,
		shares = data.shares,
		ipoCount = data.ipoCount,
		ipoShares = Config.sharesForIpo(data.totalEarned),
		maintenance = data.maintenance,
		slots = Config.slots(data, bonuses),
		workPerSec = Config.workPerSec(data, bonuses),
		clickPower = Config.clickPower(data, bonuses),
		moneyMult = moneyMult,
		bonuses = bonuses,
		socialBonus = Config.socialBonus(bonuses),
		boostLeft = math.max(0, data.boostUntil - os.time()),
		project = data.project,
		autoType = data.autoType,
		sites = sites,
		companies = data.companies,
		unlockedAds = data.unlockedAds,
		offers = offers,
		event = if session.event then { name = session.event.name, timeLeft = session.event.endsAt - now } else nil,
		goals = data.goals,
		stats = data.stats,
		dailyAvailable = dailyAvailable,
		dailyDay = dailyDay,
		dailyAmount = incomeReward(session, dailyDef.minutes, dailyDef.min),
		giftLeft = math.max(0, session.giftReadyAt - now),
		giftAmount = incomeReward(session, Config.GIFT_MINUTES, Config.GIFT_MIN),
		canSave = session.canSave,
		lastSaveOk = session.lastSaveOk,
		lastSaveAgo = if session.lastSaveAt > 0 then os.time() - session.lastSaveAt else -1,
		selectedNiche = data.selectedNiche,
		career = CareerService.buildState(session),
		tutorialDone = data.tutorialDone,
		settings = data.settings,
		dailyMissions = {
			list = data.dailyMissions.list,
			bonusGiven = data.dailyMissions.bonusGiven,
			resetIn = 86400 - os.time() % 86400,
			rewards = (function()
				local amounts = {}
				for i, reward in Config.DailyMissionRewards do
					amounts[i] = incomeReward(session, reward.minutes, reward.min)
				end
				return amounts
			end)(),
		},
	}
end

local function sendState(player: Player)
	local session = sessions[player]
	if session then
		session.leaderMoney.Value = math.clamp(math.floor(session.data.money), 0, 9e18)
		session.leaderShares.Value = session.data.shares
		session.leaderLevel.Value = session.data.career.stats.devLevel
		stateEvent:FireClient(player, buildState(session))
	end
end

---------------------------------------------------------------------
-- Eventos aleatorios
---------------------------------------------------------------------
local function triggerEvent(player: Player, session: Session)
	local data = session.data
	local totalWeight = 0
	for _, event in Config.Events do
		totalWeight += event.weight
	end
	local roll = random:NextNumber() * totalWeight
	local chosen = Config.Events[1]
	for _, event in Config.Events do
		roll -= event.weight
		if roll <= 0 then
			chosen = event
			break
		end
	end

	if chosen.id == "viral" then
		if #data.sites == 0 then
			return
		end
		local site = data.sites[random:NextInteger(1, #data.sites)]
		local name = "🔥 ¡" .. site.name .. " es viral! x5 visitas"
		session.event = { id = "viral", name = name, endsAt = os.clock() + chosen.duration, siteId = site.id }
		notify(player, name, "event")
	elseif chosen.id == "caida" and Config.level(data, "datacenter") >= 1 then
		notify(player, "🏭 Tu Centro de Datos evitó una caída de servidores", "event")
	elseif chosen.duration > 0 then
		session.event = { id = chosen.id, name = chosen.name, endsAt = os.clock() + chosen.duration }
		notify(player, chosen.name, "event")
	elseif chosen.id == "inversor" then
		local amount = math.max(50, session.income * 90)
		gain(data, amount)
		notify(player, chosen.name .. ": +" .. Config.formatMoney(amount), "money")
	elseif chosen.id == "vip" then
		table.insert(session.offers, 1, makeOffer(session, 3.5))
		notify(player, chosen.name, "event")
	end
end

---------------------------------------------------------------------
-- Acciones que puede pedir el cliente
---------------------------------------------------------------------
local Actions = {}

function Actions.click(player: Player, session: Session)
	local now = os.clock()
	if now - session.clickWindowStart >= 1 then
		session.clickWindowStart = now
		session.clickCount = 0
	end
	session.clickCount += 1
	if session.clickCount > Config.CLICK_RATE_LIMIT then
		return false, nil
	end
	local data = session.data
	if not data.project then
		return false, "Primero elige una web para programar."
	end
	data.stats.clicks += 1
	local power = Config.clickPower(data, session.bonuses)
	local crit = random:NextNumber() < Config.CRIT_CHANCE
	if crit then
		power *= Config.CRIT_MULT
		data.stats.crits += 1
	end
	CareerService.addXp(player, session, data.project.niche or Career.DEFAULT_NICHE, 0.5)
	addWork(player, session, power)
	return true, nil, { crit = crit, power = power }
end

function Actions.startProject(_player: Player, session: Session, typeId: any)
	local def = Config.WebTypeById[typeId]
	if not def then
		return false, "Tipo de web desconocido."
	end
	local ok, reason = canStartProject(session, def)
	if not ok then
		return false, reason
	end
	startProject(session.data, def)
	return true, nil
end

function Actions.cancelProject(_player: Player, session: Session)
	local data = session.data
	if not data.project then
		return false, nil
	end
	local def = Config.WebTypeById[data.project.type]
	data.money += math.floor(def.cost * 0.5)
	data.project = nil
	data.autoType = nil
	return true, "Proyecto cancelado (te devuelven la mitad)."
end

function Actions.setAuto(_player: Player, session: Session, typeId: any)
	local data = session.data
	if Config.level(data, "ia_lab") < 1 then
		return false, "Necesitas el Laboratorio de IA."
	end
	if typeId == nil or data.autoType == typeId then
		data.autoType = nil
		return true, "Modo automático desactivado."
	end
	local def = Config.WebTypeById[typeId]
	if not def or data.reputation < def.rep then
		return false, "Esa web aún no está desbloqueada."
	end
	data.autoType = def.id
	tryAutoStart(session)
	return true, "🤖 La IA programará " .. def.name .. " sin parar."
end

function Actions.upgradeSeo(_player: Player, session: Session, siteId: any)
	local data = session.data
	local site = findSite(data, siteId)
	if not site then
		return false, nil
	end
	if site.seo >= Config.MAX_SEO then
		return false, "SEO al máximo."
	end
	local cost = Config.seoCost(site)
	if data.money < cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= cost
	site.seo += 1
	return true, nil
end

function Actions.setNetwork(_player: Player, session: Session, siteId: any, networkId: any)
	local data = session.data
	local site = findSite(data, siteId)
	if not site or not Config.AdNetworkById[networkId] or not data.unlockedAds[networkId] then
		return false, nil
	end
	site.network = networkId
	return true, nil
end

function Actions.setNetworkAll(_player: Player, session: Session, networkId: any)
	local data = session.data
	if not Config.AdNetworkById[networkId] or not data.unlockedAds[networkId] then
		return false, nil
	end
	for _, site in data.sites do
		site.network = networkId
	end
	return true, "Todas tus webs usan " .. Config.AdNetworkById[networkId].name
end

function Actions.setAdLevel(_player: Player, session: Session, siteId: any, level: any)
	local site = findSite(session.data, siteId)
	if not site or type(level) ~= "number" or not Config.AdLevels[level] then
		return false, nil
	end
	site.adLevel = level
	return true, nil
end

function Actions.unlockNetwork(_player: Player, session: Session, networkId: any)
	local data = session.data
	local network = Config.AdNetworkById[networkId]
	if not network or data.unlockedAds[networkId] then
		return false, nil
	end
	if data.reputation < network.rep then
		return false, "Necesitas " .. Config.formatNumber(network.rep) .. " de reputación."
	end
	if data.money < network.cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= network.cost
	data.unlockedAds[networkId] = true
	return true, network.emoji .. " " .. network.name .. " desbloqueada. ¡Pónsela a tus webs!"
end

function Actions.buyCompany(_player: Player, session: Session, companyId: any)
	local data = session.data
	local def = Config.CompanyById[companyId]
	if not def then
		return false, nil
	end
	local level = Config.level(data, def.id)
	if level >= def.maxLevel then
		return false, "Nivel máximo."
	end
	local cost = Config.companyCost(def.id, level)
	if data.money < cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= cost
	data.companies[def.id] = level + 1
	if level == 0 then
		return true, def.emoji .. " ¡Has fundado " .. def.name .. "!"
	end
	return true, nil
end

local function sellSite(session: Session, siteId: any, mult: number, buyer: string, buyerNiche: string?): (boolean, string?)
	local data = session.data
	local site, siteIndex = findSite(data, siteId)
	if not site or not siteIndex then
		return false, nil
	end
	local specialist = buyerNiche ~= nil and site.niche == buyerNiche
	if specialist then
		mult *= Career.NICHE_MATCH_SALE_BONUS
	end
	local def = Config.WebTypeById[site.type]
	local price = Config.saleBase(data, site, Config.moneyMult(data, session.bonuses)) * mult
	table.remove(data.sites, siteIndex)
	gain(data, price)
	data.maintenance += price * Config.MAINTENANCE_RATE
	data.reputation += def.repReward
	data.stats.sold += 1
	if session.event and session.event.siteId == siteId then
		session.event = nil
	end
	tryAutoStart(session)
	return true, string.format("🤝 Vendiste %s a %s por %s%s", site.name, buyer, Config.formatMoney(price), if specialist then " (⭐ especialista x1.5)" else "")
end

function Actions.sellToOffer(_player: Player, session: Session, offerId: any, siteId: any)
	for i, offer in session.offers do
		if offer.id == offerId then
			local site = findSite(session.data, siteId)
			if not site or site.type ~= offer.type then
				return false, "Esa empresa quiere otro tipo de web."
			end
			table.remove(session.offers, i)
			local ok, message = sellSite(session, siteId, offer.mult, offer.company, offer.niche)
			refreshOffers(session)
			return ok, message, { money = true }
		end
	end
	return false, "La oferta ya no está disponible."
end

function Actions.quickSell(_player: Player, session: Session, siteId: any)
	local ok, message = sellSite(session, siteId, Config.QUICK_SALE_MULT, "un comprador anónimo")
	return ok, message, { money = ok }
end

function Actions.ipo(_player: Player, session: Session)
	local data = session.data
	local newShares = Config.sharesForIpo(data.totalEarned)
	if newShares < 1 then
		return false, "Necesitas ganar " .. Config.formatMoney(Config.IPO_MIN_EARNED) .. " en esta partida."
	end
	local fresh = newData()
	data.money = fresh.money
	data.totalEarned = 0
	data.reputation = 0
	data.sites = {}
	data.project = nil
	data.autoType = nil
	data.companies = {}
	data.unlockedAds = fresh.unlockedAds
	data.maintenance = 0
	data.shares += newShares
	data.ipoCount += 1
	session.offers = {}
	session.event = nil
	refreshOffers(session)
	return true, string.format("📈 ¡Saliste a bolsa! +%d acciones (+%d%% de dinero para siempre)", newShares, math.floor(newShares * Config.SHARE_BONUS * 100)), { money = true }
end

function Actions.upgradeDesign(_player: Player, session: Session, siteId: any)
	local data = session.data
	local site = findSite(data, siteId)
	if not site then
		return false, nil
	end
	if (site.design or 0) >= Config.MAX_DESIGN then
		return false, "Diseño al máximo."
	end
	local cost = Config.designCost(site)
	if data.money < cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= cost
	site.design = (site.design or 0) + 1
	return true, "🎨 Rediseño de " .. site.name .. ": nivel " .. site.design
end

function Actions.setNiche(_player: Player, session: Session, nicheId: any)
	if type(nicheId) ~= "string" or not Career.NicheById[nicheId] then
		return false, nil
	end
	session.data.selectedNiche = nicheId
	return true, nil
end

function Actions.claimGoal(_player: Player, session: Session, goalId: any)
	local data = session.data
	for _, goal in Config.Goals do
		if goal.id == goalId then
			if data.goals[goal.id] then
				return false, "Ya lo has reclamado."
			end
			if goal.value(data) < goal.target then
				return false, "Aún no has cumplido este objetivo."
			end
			data.goals[goal.id] = true
			if goal.reward > 0 then
				data.money += goal.reward
			end
			return true, "🎯 " .. goal.text .. (if goal.reward > 0 then ": +" .. Config.formatMoney(goal.reward) else ""), { money = goal.reward > 0 }
		end
	end
	return false, nil
end

function Actions.claimDailyMission(player: Player, session: Session, index: any)
	ensureDailyMissions(session)
	local daily = session.data.dailyMissions
	local mission = type(index) == "number" and daily.list[index]
	if not mission then
		return false, nil
	end
	if mission.claimed then
		return false, "Ya la has reclamado."
	end
	if mission.progress < mission.target then
		return false, "Aún no has terminado esta misión."
	end
	local reward = Config.DailyMissionRewards[mission.tier]
	local amount = incomeReward(session, reward.minutes, reward.min)
	gain(session.data, amount)
	mission.claimed = true
	local allDone = true
	for _, m in daily.list do
		if not m.claimed then
			allDone = false
		end
	end
	if allDone and not daily.bonusGiven then
		daily.bonusGiven = true
		local data = session.data
		data.boostUntil = math.max(data.boostUntil, os.time()) + Config.DAILY_ALL_BONUS_BOOST_MINUTES * 60
		refreshBoost(session)
		notify(player, "🏆 ¡Todas las misiones de hoy completadas! 🚀 Boost x2 " .. Config.DAILY_ALL_BONUS_BOOST_MINUTES .. " min", "goal")
	end
	return true, "📅 Misión completada: +" .. Config.formatMoney(amount), { money = true }
end

function Actions.finishTutorial(_player: Player, session: Session)
	local data = session.data
	if data.tutorialDone then
		return true, nil
	end
	data.tutorialDone = true
	data.money += Config.TUTORIAL_REWARD
	return true, "🎓 ¡Tutorial completado! +" .. Config.formatMoney(Config.TUTORIAL_REWARD), { money = true }
end

function Actions.setMuted(_player: Player, session: Session, muted: any)
	session.data.settings.muted = muted == true
	return true, nil
end

function Actions.claimDaily(player: Player, session: Session)
	local data = session.data
	local available, day = dailyStatus(data)
	if not available then
		return false, "Ya has recogido la recompensa de hoy. ¡Vuelve mañana!"
	end
	local def = Config.DailyRewards[day]
	local amount = incomeReward(session, def.minutes, def.min)
	gain(data, amount)
	data.daily.lastDay = Config.dayIndex(os.time())
	data.daily.streak = day
	local extra = ""
	if def.boostMinutes then
		data.boostUntil = math.max(data.boostUntil, os.time()) + def.boostMinutes * 60
		refreshBoost(session)
		extra = " + 🚀 Boost x2 " .. def.boostMinutes .. " min"
	end
	notify(player, string.format("📅 Día %d: +%s%s", day, Config.formatMoney(amount), extra), "money")
	return true, nil, { money = true }
end

function Actions.claimGift(player: Player, session: Session)
	if os.clock() < session.giftReadyAt then
		return false, "Tu regalo aún no está listo."
	end
	local amount = incomeReward(session, Config.GIFT_MINUTES, Config.GIFT_MIN)
	gain(session.data, amount)
	session.giftReadyAt = os.clock() + Config.GIFT_INTERVAL
	notify(player, "🎁 Regalo: +" .. Config.formatMoney(amount), "money")
	return true, nil, { money = true }
end

actionFunction.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
	local session = sessions[player]
	if not session or type(action) ~= "string" then
		return false, nil
	end
	local handler = Actions[action]
	if not handler then
		return false, nil
	end

	-- Límite general de peticiones (los clics tienen su propio límite)
	if action ~= "click" then
		local now = os.clock()
		if now - session.actionWindowStart >= 1 then
			session.actionWindowStart = now
			session.actionCount = 0
		end
		session.actionCount += 1
		if session.actionCount > 10 then
			return false, "Vas muy rápido 😅"
		end
	end

	local ok, message, extra = handler(player, session, a, b)
	if ok then
		CareerService.refreshBonuses(session)
		local stat = ACTION_STATS[action]
		if stat then
			progressDaily(session, stat, 1)
		end
	end
	if ok then
		checkGoals(player, session)
		session.income = computeIncome(session, true)
		sendState(player)
	end
	return ok, message, extra
end

---------------------------------------------------------------------
-- Compras con Robux
---------------------------------------------------------------------
local passKeyById: { [number]: string } = {}
for _, pass in Monetization.GamePasses do
	if pass.id ~= 0 then
		passKeyById[pass.id] = pass.key
	end
end

local productById: { [number]: any } = {}
for _, product in Monetization.Products do
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

local function grantProduct(player: Player, session: Session, product)
	local data = session.data
	if product.kind == "cash" then
		local amount = incomeReward(session, product.minutes, product.min)
		gain(data, amount)
		notify(player, product.emoji .. " ¡" .. product.name .. "! +" .. Config.formatMoney(amount), "money")
	elseif product.kind == "boost" then
		data.boostUntil = math.max(data.boostUntil, os.time()) + product.minutes * 60
		refreshBoost(session)
		notify(player, "🚀 ¡Boost x2 activado durante " .. product.minutes .. " minutos!", "money")
	elseif product.kind == "ticket" then
		CareerService.grantTickets(player, session, product.ticket, product.amount)
	elseif product.kind == "finish" then
		if data.project then
			addWork(player, session, data.project.required)
			notify(player, "⏩ ¡Web terminada al instante!", "success")
		else
			local amount = incomeReward(session, 10, 1000)
			gain(data, amount)
			notify(player, "⏩ No programabas nada: te damos +" .. Config.formatMoney(amount), "money")
		end
	end
end

local saveData: (Player, Session) -> boolean

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and sessions[player]
	local product = productById[receipt.ProductId]
	if not player or not session or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = session.data
	local purchaseId = tostring(receipt.PurchaseId)
	if not data.receipts[purchaseId] then
		grantProduct(player, session, product)
		data.receipts[purchaseId] = os.time()
		-- Guardamos solo las 50 compras más recientes
		local entries = {}
		for id, time in data.receipts do
			table.insert(entries, { id = id, time = time })
		end
		if #entries > 50 then
			table.sort(entries, function(x, y)
				return x.time < y.time
			end)
			for i = 1, #entries - 50 do
				data.receipts[entries[i].id] = nil
			end
		end
		sendState(player)
	end
	-- Solo confirmamos la compra cuando está guardada
	if session.canSave and not saveData(player, session) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local key = passKeyById[passId]
	local session = sessions[player]
	if purchased and key and session then
		(session.bonuses :: any)[key] = true
		local def = Config.PassByKey[key]
		notify(player, def.emoji .. " ¡Gracias! Ya tienes " .. def.name .. ".", "money")
		session.income = computeIncome(session, true)
		sendState(player)
	end
end)

---------------------------------------------------------------------
-- Amigos en el servidor (bonus por jugar juntos)
---------------------------------------------------------------------
local function updateFriendBonus(session: Session)
	local count = 0
	for other in sessions do
		if session.friendIds[other.UserId] then
			count += 1
		end
	end
	session.bonuses.friends = count
end

local function registerFriends(player: Player, session: Session)
	-- Copia de la lista: IsFriendsWithAsync espera a la red y puede entrar o
	-- salir gente mientras tanto
	local others = {}
	for other in sessions do
		if other ~= player then
			table.insert(others, other)
		end
	end
	for _, other in others do
		local ok, isFriend = pcall(function()
			return player:IsFriendsWithAsync(other.UserId)
		end)
		local otherSession = sessions[other]
		if ok and isFriend and otherSession and sessions[player] then
			session.friendIds[other.UserId] = true
			otherSession.friendIds[player.UserId] = true
			notify(other, "👫 ¡" .. player.DisplayName .. " ha entrado! +10 % de dinero por jugar con amigos", "success")
		end
	end
	for _, s in sessions do
		updateFriendBonus(s)
	end
end

---------------------------------------------------------------------
-- Entrar y salir del juego
---------------------------------------------------------------------
local function loadData(player: Player): (any, boolean)
	if not store then
		return newData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(dataKey(player))
		end)
		if ok then
			if type(result) == "table" then
				return reconcile(result, newData()), true
			end
			return newData(), true
		end
		warn("[ImperioWeb] Error cargando datos (intento " .. attempt .. "):", result)
		task.wait(2)
	end
	return newData(), false
end

local pendingSaves = 0

-- Puntuación para la clasificación: logaritmo para que quepan cifras enormes
local function leaderboardScore(amount: number): number
	return math.floor(math.log10(1 + math.max(0, amount)) * 1e14)
end

local function leaderboardValue(score: number): number
	return 10 ^ (score / 1e14) - 1
end

function saveData(player: Player, session: Session): boolean
	if not session.canSave or not store then
		return false
	end
	session.data.lastOnline = os.time()
	pendingSaves += 1
	local ok, err = pcall(function()
		store:UpdateAsync(dataKey(player), function()
			return session.data
		end)
	end)
	if leaderboardStore then
		pcall(function()
			leaderboardStore:SetAsync("u_" .. player.UserId, leaderboardScore(session.data.lifetimeEarned))
		end)
	end
	pendingSaves -= 1
	session.lastSaveOk = ok
	if ok then
		session.lastSaveAt = os.time()
	else
		warn("[ImperioWeb] Error guardando datos de " .. player.Name .. ":", err)
	end
	return ok
end

Actions.saveNow = function(player: Player, session: Session)
	if not session.canSave then
		return false, "⚠️ El guardado está desactivado: publica el juego y activa «Enable Studio Access to API Services»."
	end
	local now = os.clock()
	if now - session.lastManualSave < Config.MANUAL_SAVE_COOLDOWN then
		return false, "Espera " .. math.ceil(Config.MANUAL_SAVE_COOLDOWN - (now - session.lastManualSave)) .. " s para volver a guardar."
	end
	session.lastManualSave = now
	if saveData(player, session) then
		return true, "💾 Partida guardada"
	end
	return false, "❌ No se pudo guardar. Se volverá a intentar solo."
end

local function spawnAtPlot(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart")
	task.wait()
	character:PivotTo(PlotManager.getSpawnCFrame(player))
end

local function checkPasses(player: Player, bonuses: Bonuses)
	for _, pass in Monetization.GamePasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				(bonuses :: any)[pass.key] = true
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	local data, canSave = loadData(player)
	if not player.Parent then
		return -- se fue mientras cargaba
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local leaderMoney = Instance.new("IntValue")
	leaderMoney.Name = "💰 Dinero"
	leaderMoney.Parent = leaderstats
	local leaderShares = Instance.new("IntValue")
	leaderShares.Name = "📈 Acciones"
	leaderShares.Parent = leaderstats
	local leaderLevel = Instance.new("IntValue")
	leaderLevel.Name = "🎓 Nivel"
	leaderLevel.Parent = leaderstats
	leaderstats.Parent = player

	local bonuses: Bonuses = {
		pass = false,
		turbo = false,
		slotsPass = false,
		agencyPro = false,
		xpPass = false,
		boost = false,
		friends = 0,
		premium = player.MembershipType == Enum.MembershipType.Premium,
		group = false,
		randomRestricted = true, -- por seguridad, hasta que PolicyService diga lo contrario
		agencyWork = 0,
		agencyBonus = 0,
	}
	local okPolicy, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if okPolicy and policy then
		bonuses.randomRestricted = policy.ArePaidRandomItemsRestricted == true
	end

	-- Webs de versiones anteriores: añadir campos nuevos
	for _, site in data.sites do
		site.niche = site.niche or Career.DEFAULT_NICHE
		site.design = site.design or 0
		site.totalVisits = site.totalVisits or 0
		site.earned = site.earned or 0
	end
	data.career.stats.devLevel = Career.devLevel(data.career)
	checkPasses(player, bonuses)
	if Monetization.GROUP_ID ~= 0 then
		local ok, inGroup = pcall(function()
			return player:IsInGroupAsync(Monetization.GROUP_ID)
		end)
		bonuses.group = ok and inGroup == true
	end

	local session: Session = {
		data = data,
		canSave = canSave,
		bonuses = bonuses,
		offers = {},
		nextOfferId = 0,
		event = nil,
		nextEventAt = os.clock() + 60,
		giftReadyAt = os.clock() + Config.GIFT_INTERVAL,
		taskReadyAt = os.clock() + Career.TASK_INTERVAL,
		taskNotified = false,
		lastManualSave = -math.huge,
		lastSaveOk = nil,
		lastSaveAt = 0,
		income = 0,
		clickWindowStart = 0,
		clickCount = 0,
		actionWindowStart = 0,
		actionCount = 0,
		friendIds = {},
		goalNotified = {},
		leaderMoney = leaderMoney,
		leaderShares = leaderShares,
		leaderLevel = leaderLevel,
	}
	sessions[player] = session
	refreshBoost(session)
	CareerService.initSession(session)
	CareerService.refreshBonuses(session)

	refreshOffers(session)
	session.income = computeIncome(session, false)

	-- Ganancias mientras estabas desconectado
	local isNew = data.stats.built == 0 and data.lifetimeEarned == 0
	local away = math.clamp(os.time() - (data.lastOnline or os.time()), 0, Config.OFFLINE_MAX_HOURS * 3600)
	if away >= 60 and session.income > 0 then
		local earned = session.income * away * Config.OFFLINE_RATE
		gain(data, earned)
		task.delay(2, function()
			popup(player, "😴 ¡Bienvenido de vuelta!", "Mientras no estabas (" .. Config.formatTime(away) .. ") tus webs y empresas ganaron\n" .. Config.formatMoney(earned))
		end)
	end
	local _ = isNew -- la bienvenida ahora la da el tutorial del cliente

	ensureDailyMissions(session)
	-- Objetivos ya cumplidos sin reclamar: un solo aviso
	local pending = 0
	for _, goal in Config.Goals do
		if not data.goals[goal.id] and goal.value(data) >= goal.target then
			session.goalNotified[goal.id] = true
			pending += 1
		end
	end
	if pending > 0 then
		task.delay(6, function()
			notify(player, "🎯 Tienes " .. pending .. " objetivo(s) por reclamar en 🎯 Misiones", "goal")
		end)
	end

	if not canSave then
		task.delay(5, function()
			notify(player, "⚠️ No se pudo conectar con el guardado: esta partida no se guardará.", "error")
		end)
	end

	PlotManager.claim(player)
	PlotManager.update(player, data.lifetimeEarned, session.income)

	player.CharacterAdded:Connect(function(character)
		spawnAtPlot(player, character)
	end)
	if player.Character then
		task.spawn(spawnAtPlot, player, player.Character)
	end

	task.spawn(registerFriends, player, session)
	sendState(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	-- Se quita primero para que el bucle de economía deje de tocarlo
	sessions[player] = nil
	PlotManager.release(player)
	for _, s in sessions do
		s.friendIds[player.UserId] = nil
		updateFriendBonus(s)
	end
	if session then
		saveData(player, session)
	end
end

---------------------------------------------------------------------
-- Clasificación global
---------------------------------------------------------------------
local nameCache: { [number]: string } = {}

local function refreshLeaderboard()
	if not leaderboardStore then
		PlotManager.setLeaderboard(nil, "Publica el juego para ver la clasificación")
		return
	end
	local ok, pages = pcall(function()
		return leaderboardStore:GetSortedAsync(false, 10)
	end)
	if not ok then
		PlotManager.setLeaderboard(nil, "Clasificación disponible al publicar el juego")
		return
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		local name = "???"
		if userId then
			if not nameCache[userId] then
				local okName, result = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				nameCache[userId] = if okName then result else "Jugador"
			end
			name = nameCache[userId]
		end
		table.insert(rows, { name = name, value = leaderboardValue(entry.value) })
	end
	PlotManager.setLeaderboard(rows, nil)
end

---------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------
CareerService.init({
	gain = gain,
	notify = notify,
	popup = popup,
	income = function(session)
		return computeIncome(session, false)
	end,
	random = random,
})
for name, handler in CareerService.Actions do
	Actions[name] = handler
end

PlotManager.init(function(player)
	openComputerEvent:FireClient(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, session in sessions do
		task.spawn(saveData, player, session)
	end
	-- Espera también a los guardados que ya estaban en marcha
	task.wait(0.5)
	local deadline = os.clock() + 25
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.5)
	end
end)

-- Guardado automático
task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for player, session in sessions do
			task.spawn(saveData, player, session)
		end
	end
end)

-- Clasificación
task.spawn(function()
	task.wait(5)
	while true do
		refreshLeaderboard()
		task.wait(Config.LEADERBOARD_REFRESH)
	end
end)

-- Bucle de la economía: una vez por segundo
local lastTick = os.clock()
while true do
	task.wait(1)
	local now = os.clock()
	local dt = math.min(now - lastTick, 5)
	lastTick = now

	for player, session in sessions do
		local data = session.data

		if session.event and session.event.endsAt <= now then
			session.event = nil
		end
		if now >= session.nextEventAt then
			session.nextEventAt = now + random:NextNumber(Config.EVENT_MIN_DELAY, Config.EVENT_MAX_DELAY)
			triggerEvent(player, session)
		end
		local hadBoost = session.bonuses.boost
		refreshBoost(session)
		if hadBoost and not session.bonuses.boost then
			notify(player, "🚀 Tu boost x2 ha terminado", "info")
		end

		CareerService.tick(player, session, dt)
		ensureDailyMissions(session)
		session.income = computeIncome(session, true)
		gain(data, session.income * dt)
		-- Visitas y dinero acumulados por cada web (para su ficha)
		local moneyMult = Config.moneyMult(data, session.bonuses)
		for _, site in data.sites do
			local visits = Config.siteVisits(data, site, eventVisitMult(session, site))
			site.totalVisits = (site.totalVisits or 0) + visits * dt
			site.earned = (site.earned or 0) + Config.siteIncome(data, site, visits, moneyMult) * dt
		end

		local workPerSec = Config.workPerSec(data, session.bonuses)
		if workPerSec > 0 then
			addWork(player, session, workPerSec * dt)
		end
		tryAutoStart(session)

		refreshOffers(session)
		checkGoals(player, session)
		PlotManager.update(player, data.lifetimeEarned, session.income)
		sendState(player)
	end
end
