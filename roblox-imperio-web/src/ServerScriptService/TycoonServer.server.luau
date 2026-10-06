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
local MarketService = require(ServerScriptService:WaitForChild("MarketService"))

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

-- Ficha del imperio de otro jugador (al pulsar "Ver imperio" en su cartel)
local visitEvent = Instance.new("RemoteEvent")
visitEvent.Name = "Visit"
visitEvent.Parent = remotes

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Guardado
---------------------------------------------------------------------
local store: DataStore? = nil
local leaderboardStore: OrderedDataStore? = nil
local weeklyStores: { [number]: OrderedDataStore } = {}
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

-- Clasificación de una semana concreta (una por semana)
local function weeklyStore(week: number): OrderedDataStore?
	if weeklyStores[week] then
		return weeklyStores[week]
	end
	if not leaderboardStore then
		return nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.WEEKLY_STORE_PREFIX .. week)
	end)
	if ok then
		weeklyStores[week] = result
		return result
	end
	return nil
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
		stats = { built = 0, sold = 0, clicks = 0, crits = 0, byType = {}, missions = 0, marketProfit = 0 },
		daily = { lastDay = -1, streak = 0 },
		boostUntil = 0,
		receipts = {},
		selectedNiche = Career.DEFAULT_NICHE,
		career = CareerService.newData(),
		tutorialDone = false,
		dailyMissions = { day = -1, list = {}, bonusGiven = false },
		settings = { muted = false, lang = "auto" },
		lastOnline = os.time(),
		-- Ranking semanal: lo ganado esta semana y la anterior (para el premio)
		weekly = { week = -1, earned = 0, prevWeek = -1, prevEarned = 0, rewardedWeek = -1 },
		goldUntil = 0, -- rascacielos dorado (premio del ranking semanal)
		likes = 0, -- "me gusta" que ha recibido tu imperio
		likesGiven = { day = -1, ids = {} }, -- a quién has dado "me gusta" hoy
		-- v2.0
		collection = {}, -- [tipo] = { normal = true, brillante = true, ... }
		research = {}, -- [mejora] = nivel (I+D, no se pierde nunca)
		patents = 0, -- 💡 patentes sin gastar
		season = { id = -1, xp = 0, free = {}, premiumClaimed = {}, premium = false },
		playtime = { day = -1, seconds = 0, claimed = {} },
		codes = {}, -- [CÓDIGO] = true
		firstJoin = os.time(),
		starterBought = false,
		bestCombo = 0,
		-- v2.1
		weeklyMissions = { week = -1, list = {}, bonusGiven = false },
		-- v3.0
		portfolio = {}, -- Bolsa: [empresa] = { units, invested }
		peakIncome = 0, -- mejores ingresos/s de la partida (máximo invertible)
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
	agencyBonus: number, -- % extra de dinero de tus programadores
	agencyQuality: number, -- % extra de calidad (Diseño)
	agencyVisits: number, -- % extra de visitas (Marketing)
	agencySale: number, -- % extra al vender (Ventas)
	agencyRare: number, -- % extra de webs raras (Datos)
	weekend: string?, -- evento de fin de semana activo
}
type Session = {
	data: any,
	combo: number, -- clics seguidos
	lastClickAt: number,
	floors: number, -- plantas (para avisar de lo que se desbloquea)
	achievementTiers: { [string]: number }, -- niveles de logros ya avisados
	canSave: boolean,
	bonuses: Bonuses,
	offers: { Offer },
	nextOfferId: number,
	nextOfferAt: number, -- cuándo llega la próxima oferta de cliente
	quickSaleReadyAt: number, -- venta rápida disponible otra vez
	event: ActiveEvent?,
	nextEventAt: number,
	giftReadyAt: number,
	contractBoard: { any }, -- encargos del tablón (CareerService)
	nextContractAt: number,
	askReadyAt: number,
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
	weeklyCheckAt: number, -- cuándo mirar si hay premio del ranking semanal
	weeklyChecking: boolean,
}

local sessions: { [Player]: Session } = {}

-- Evento del servidor (para todos a la vez) y meta cooperativa
type ServerEvent = { id: string, endsAt: number }
local serverEvent: ServerEvent? = nil
type Community = { target: number, endsAt: number, start: { [Player]: number } }
local community: Community? = nil

-- Lo ganado entre todos desde que empezó la meta
local function communityProgress(): number
	local goal = community
	if not goal then
		return 0
	end
	local total = 0
	for player, startEarned in goal.start do
		local session = sessions[player]
		if session then
			total += math.max(0, session.data.lifetimeEarned - startEarned)
		end
	end
	return total
end

local function serverEventIs(id: string): boolean
	return serverEvent ~= nil and serverEvent.id == id
end

-- Clasificaciones (las rellena refreshLeaderboard y van en el estado)
type BoardRow = { name: string, value: number, userId: number? }
local globalTop: { BoardRow } = {}
local weeklyTop: { BoardRow } = {}
local weeklyTopWeek = -1

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
	data.weekly.earned += amount
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
		mult = (mult or (0.9 + random:NextNumber() * 0.9 + math.min(commercial * 0.03, 0.9)))
			* (1 + 0.05 * Config.research(data, "offers")),
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
	-- Las ofertas nuevas llegan de una en una (cada OFFER_INTERVAL s)
	local maxOffers = Config.OFFER_COUNT + Config.researchValue(session.data, "offers")
	if #session.offers >= maxOffers then
		session.nextOfferAt = math.max(session.nextOfferAt, now + Config.OFFER_INTERVAL)
	elseif now >= session.nextOfferAt then
		table.insert(session.offers, makeOffer(session))
		session.nextOfferAt = now + Config.OFFER_INTERVAL * (0.75 + random:NextNumber() * 0.5)
	end
end

-- Se define más abajo (misiones diarias), pero se usa al terminar webs
local progressDaily: (session: Session, stat: string, amount: number) -> ()

---------------------------------------------------------------------
-- Proyectos (webs en construcción)
---------------------------------------------------------------------
-- forContract: la web de un encargo no ocupa hueco (se entrega al acabar)
local function canStartProject(session: Session, def, forContract: boolean?): (boolean, string?)
	local data = session.data
	if data.project then
		return false, "Ya estás programando una web."
	end
	if data.reputation < def.rep then
		return false, "Necesitas " .. Config.formatNumber(def.rep) .. " de reputación."
	end
	if not forContract and #data.sites >= Config.slots(data, session.bonuses) then
		return false, "No te quedan huecos. Vende una web o mejora el Hosting."
	end
	if data.money < def.cost then
		return false, "No tienes suficiente dinero."
	end
	return true, nil
end

local function startProject(data, def, contractId: number?)
	data.money -= def.cost
	data.project = { type = def.id, progress = 0, required = def.work, niche = data.selectedNiche or Career.DEFAULT_NICHE, contractId = contractId }
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

	-- ¿Sale una web rara? Se prueba de la más rara a la menos rara
	local chanceMult = Config.variantChanceMult(data, (if serverEventIs("datastorm") then 5 else 1) * (1 + (session.bonuses.agencyRare or 0)))
	local variant = nil
	local roll = random:NextNumber()
	local acc = 0
	for i = #Config.Variants, 1, -1 do
		acc += Config.Variants[i].chance * chanceMult
		if roll < acc then
			variant = Config.Variants[i]
			break
		end
	end

	local niche = project.niche or Career.DEFAULT_NICHE
	-- ¿Era la web de un encargo? Se entrega y no se queda en tus webs
	if CareerService.tryDeliver(player, session, project, variant) then
		local row = data.collection[def.id] or {}
		local isNewEntry = not row[if variant then variant.id else "normal"]
		row[if variant then variant.id else "normal"] = true
		data.collection[def.id] = row
		data.stats.built += 1
		data.stats.byType[def.id] = (data.stats.byType[def.id] or 0) + 1
		progressDaily(session, "built", 1)
		if variant then
			progressDaily(session, "rares", 1)
			notify(player, string.format("%s ¡Web %s! Al cliente le ha encantado: paga el doble", variant.emoji, variant.name), "rare")
		end
		if isNewEntry then
			notify(player, "📖 ¡Nueva casilla en tu colección! +1 % de dinero para siempre", "goal")
		end
		tryAutoStart(session)
		return
	end
	local quality = (0.85 + random:NextNumber() * 0.3) * (1 + 0.08 * Config.level(data, "design")) * Career.qualityBonus(data.career, niche)
		* (1 + (session.bonuses.agencyQuality or 0))
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
		variant = if variant then variant.id else nil,
	}
	-- Colección: apunta la combinación tipo × variante
	local row = data.collection[def.id] or {}
	local isNewEntry = not row[site.variant or "normal"]
	row[site.variant or "normal"] = true
	data.collection[def.id] = row
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

	if variant then
		progressDaily(session, "rares", 1)
		notify(player, string.format("%s ¡Web %s! %s %s · visitas x%d", variant.emoji, variant.name, def.emoji, site.name, variant.mult), "rare")
		-- Las muy raras se anuncian a todo el servidor
		if variant.mult >= 10 then
			for other in sessions do
				if other ~= player then
					notify(other, string.format("%s ¡%s ha conseguido una web %s!", variant.emoji, player.DisplayName, variant.name), "event")
				end
			end
		end
	elseif not data.autoType then
		notify(player, string.format("%s ¡%s terminada! Calidad %d%%", def.emoji, site.name, math.floor(site.quality * 100)), "success")
	end
	if isNewEntry then
		notify(player, "📖 ¡Nueva casilla en tu colección! +1 % de dinero para siempre", "goal")
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
			or (def.needs == "career" and Config.isUnlocked(data, "career"))
			or (def.needs == "agency" and data.career.agency ~= nil)
		if available then
			table.insert(pool, def)
		end
	end
	local list = {}
	-- 2 fáciles, 2 medias y 2 difíciles
	for i = 1, math.min(Config.DAILY_MISSION_COUNT, #pool) do
		local tier = math.clamp((i + 1) // 2, 1, #Config.DailyMissionRewards)
		local def = table.remove(pool, random:NextInteger(1, #pool))
		table.insert(list, { id = def.id, tier = tier, target = def.amounts[tier], progress = 0, claimed = false })
	end
	daily.day = today
	daily.list = list
	daily.bonusGiven = false
end

function progressDaily(session: Session, stat: string, amount: number)
	-- Cuenta para las misiones diarias y para las semanales
	for _, list in { session.data.dailyMissions.list, session.data.weeklyMissions.list } do
		for _, mission in list do
			if mission.id == stat and not mission.claimed then
				mission.progress = math.min(mission.target, mission.progress + amount)
			end
		end
	end
end

-- Misiones semanales: 4 nuevas cada lunes
local function ensureWeeklyMissions(session: Session)
	local data = session.data
	local week = Config.weekIndex(os.time())
	local weekly = data.weeklyMissions
	if weekly.week == week and #weekly.list > 0 then
		return
	end
	local pool = {}
	for _, def in Config.WeeklyMissionPool do
		local available = (def.needs == nil)
			or (def.needs == "career" and Config.isUnlocked(data, "career"))
			or (def.needs == "agency" and data.career.agency ~= nil)
		if available then
			table.insert(pool, def)
		end
	end
	local list = {}
	for _ = 1, math.min(Config.WEEKLY_MISSION_COUNT, #pool) do
		local def = table.remove(pool, random:NextInteger(1, #pool))
		table.insert(list, { id = def.id, target = def.amount, progress = 0, claimed = false })
	end
	data.weeklyMissions = { week = week, list = list, bonusGiven = false }
end

-- Para misiones de "llega a X" (el combo): se queda con el mejor valor
local function progressDailyMax(session: Session, stat: string, value: number)
	for _, mission in session.data.dailyMissions.list do
		if mission.id == stat and not mission.claimed then
			mission.progress = math.min(mission.target, math.max(mission.progress, value))
		end
	end
end

---------------------------------------------------------------------
-- Pase de temporada
---------------------------------------------------------------------
-- Si ha empezado otra temporada, se empieza de cero
local function ensureSeason(session: Session)
	local current = Config.seasonIndex(os.time())
	local season = session.data.season
	if season.id ~= current then
		session.data.season = { id = current, xp = 0, free = {}, premiumClaimed = {}, premium = false }
	end
end

local function seasonTier(xp: number): number
	return math.min(Config.SEASON_TIERS, xp // Config.SEASON_XP_PER_TIER)
end

local function addSeasonXp(player: Player, session: Session, amount: number)
	ensureSeason(session)
	local season = session.data.season
	local before = seasonTier(season.xp)
	season.xp += amount
	local after = seasonTier(season.xp)
	if after > before then
		notify(player, string.format("🎫 ¡Nivel %d del pase de temporada! Recoge tu premio en 🎫 Pase", after), "goal")
	end
end

-- Acción del cliente que cuenta para una misión diaria
local ACTION_STATS = {
	upgradeSeo = "seo",
	buyCompany = "companies",
	claimGift = "gifts",
	recruit = "recruits",
	redeemTicket = "recruits",
	click = "clicks",
}

-- Acción → parte del juego que tiene que estar desbloqueada (Config.Unlocks)
local ACTION_FEATURES = {
	sellToOffer = "clients",
	unlockNetwork = "ads",
	buyCompany = "companies",
	acceptContract = "career",
	abandonContract = "career",
	workOnContract = "career",
	askContract = "career",
	foundAgency = "agency",
	recruit = "agency",
	redeemTicket = "agency",
	upgradeOffice = "agency",
	trainProgrammer = "agency",
	claimSeason = "season",
	ipo = "market",
	buyResearch = "market",
	buyStock = "market",
	sellStock = "market",
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
		local visits = Config.siteVisits(data, site, visitMult(session, site))
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
			saleBase = Config.saleBase(data, site, moneyMult, bonuses),
			seoCost = Config.seoCost(site),
			niche = site.niche,
			design = site.design or 0,
			designCost = Config.designCost(site),
			totalVisits = site.totalVisits or 0,
			earned = site.earned or 0,
			viral = session.event ~= nil and session.event.id == "viral" and session.event.siteId == site.id,
			variant = site.variant,
			deal = if site.deal then { endsIn = math.max(0, site.deal.endsAt - os.time()), buyer = site.deal.buyer, price = site.deal.price } else nil,
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

	local nowUnix = os.time()
	local activeWeekend, weekendEnds, nextWeekend, nextWeekendStarts = Config.weekendStatus(nowUnix)
	local today = Config.dayIndex(nowUnix)
	local likedToday = if data.likesGiven.day == today then data.likesGiven.ids else {}

	-- Otros jugadores del servidor (para visitar su imperio)
	local neighbors = {}
	for other, otherSession in sessions do
		if otherSession ~= session then
			table.insert(neighbors, {
				userId = other.UserId,
				name = other.DisplayName,
				floors = Config.buildingFloors(otherSession.data.lifetimeEarned),
				likes = otherSession.data.likes,
				liked = likedToday["u" .. other.UserId] == true,
			})
		end
	end
	table.sort(neighbors, function(a, b)
		return a.floors > b.floors
	end)

	return {
		money = data.money,
		income = session.income,
		totalEarned = data.totalEarned,
		lifetimeEarned = data.lifetimeEarned,
		reputation = data.reputation,
		shares = data.shares,
		ipoCount = data.ipoCount,
		ipoShares = Config.sharesForIpo(data.totalEarned),
		ipoPatents = Config.patentsForShares(Config.sharesForIpo(data.totalEarned)),
		maxDeals = Config.maxDeals(data),
		quickSaleLeft = math.max(0, session.quickSaleReadyAt - now),
		weeklyMissions = {
			list = data.weeklyMissions.list,
			bonusGiven = data.weeklyMissions.bonusGiven,
			resetIn = Config.weekStart(Config.weekIndex(os.time()) + 1) - os.time(),
			reward = incomeReward(session, Config.WeeklyMissionReward.minutes, Config.WeeklyMissionReward.min),
		},
		maintenance = Config.maintenanceIncome(data),
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
		market = MarketService.buildState(session, now),
		tutorialDone = data.tutorialDone,
		settings = data.settings,
		likes = data.likes,
		goldLeft = math.max(0, data.goldUntil - nowUnix),
		-- v2.0
		collection = data.collection,
		research = data.research,
		patents = data.patents,
		combo = session.combo,
		bestCombo = data.bestCombo,
		season = {
			id = data.season.id,
			xp = data.season.xp,
			free = data.season.free,
			premiumClaimed = data.season.premiumClaimed,
			premium = data.season.premium,
			endsIn = Config.seasonEnds(data.season.id) - nowUnix,
		},
		playtime = { seconds = data.playtime.seconds, claimed = data.playtime.claimed },
		starterLeft = if data.starterBought then 0 else math.max(0, data.firstJoin + Config.STARTER_HOURS * 3600 - nowUnix),
		serverEvent = if serverEvent then { id = serverEvent.id, endsIn = serverEvent.endsAt - now } else nil,
		community = if community then {
			target = community.target,
			progress = communityProgress(),
			endsIn = community.endsAt - now,
		} else nil,
		neighbors = neighbors,
		globalTop = globalTop,
		weekly = {
			earned = data.weekly.earned,
			resetIn = Config.weekStart(Config.weekIndex(nowUnix) + 1) - nowUnix,
			top = if weeklyTopWeek == Config.weekIndex(nowUnix) then weeklyTop else {},
		},
		weekend = {
			id = if activeWeekend then activeWeekend.id else nil,
			endsIn = if activeWeekend then weekendEnds - nowUnix else 0,
			nextId = nextWeekend.id,
			startsIn = nextWeekendStarts - nowUnix,
		},
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
		local amount = math.max(50, session.income * 90) * Config.REWARD_SCALE
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
	-- Combo: clics seguidos (sin parar más de COMBO_WINDOW) valen más
	if now - session.lastClickAt <= Config.COMBO_WINDOW then
		session.combo = math.min(session.combo + 1, Config.COMBO_MAX)
	else
		session.combo = 1
	end
	session.lastClickAt = now
	if session.combo > data.bestCombo then
		data.bestCombo = session.combo
	end
	progressDailyMax(session, "combo", session.combo)
	local power = Config.clickPower(data, session.bonuses) * Config.comboMult(session.combo)
	if serverEventIs("hackathon") then
		power *= 3
	end
	local crit = random:NextNumber() < Config.CRIT_CHANCE
	if crit then
		power *= Config.CRIT_MULT
		data.stats.crits += 1
	end
	CareerService.addXp(player, session, data.project.niche or Career.DEFAULT_NICHE, 0.5)
	addWork(player, session, power)
	return true, nil, { crit = crit, power = power, combo = session.combo, comboMult = Config.comboMult(session.combo) }
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

-- amount = 1, 10 o "max" (todos los que puedas pagar)
function Actions.buyCompany(player: Player, session: Session, companyId: any, amount: any)
	local data = session.data
	local def = Config.CompanyById[companyId]
	if not def then
		return false, nil
	end
	local level = Config.level(data, def.id)
	if level >= def.maxLevel then
		return false, "Nivel máximo."
	end
	local wanted = if amount == "max" then def.maxLevel elseif amount == 10 then 10 else 1
	local count, cost = Config.companyAffordable(def.id, level, data.money, math.min(wanted, def.maxLevel - level))
	-- x10: si no llega para los 10, no compra ninguno (para no gastar a medias sin querer)
	if count < 1 or (amount == 10 and count < math.min(10, def.maxLevel - level)) then
		return false, "No tienes suficiente dinero."
	end
	data.money -= cost
	data.companies[def.id] = level + count
	progressDaily(session, "companies", count - 1) -- (la acción ya cuenta 1)
	local milestonesBefore = Config.milestonesReached(level)
	if Config.milestonesReached(level + count) > milestonesBefore then
		notify(player, string.format("🏅 ¡Hito! %s %s nivel %d: produce x%.1f", def.emoji, def.name, level + count, Config.companyMult(data, def.id)), "goal")
	end
	if level == 0 then
		return true, def.emoji .. " ¡Has fundado " .. def.name .. "!"
	end
	return true, nil
end

-- Precio que pagaría un comprador (y si es especialista de su nicho)
local function salePrice(session: Session, site, mult: number, buyerNiche: string?): (number, boolean)
	local data = session.data
	local specialist = buyerNiche ~= nil and site.niche == buyerNiche
	if specialist then
		mult *= Career.NICHE_MATCH_SALE_BONUS
	end
	return Config.saleBase(data, site, Config.moneyMult(data, session.bonuses), session.bonuses) * mult, specialist
end

-- Cobra la venta y quita la web
local function completeSale(player: Player, session: Session, site, price: number)
	local data = session.data
	local _, siteIndex = findSite(data, site.id)
	if not siteIndex then
		return
	end
	local def = Config.WebTypeById[site.type]
	table.remove(data.sites, siteIndex)
	gain(data, price)
	data.maintenance += price * Config.MAINTENANCE_RATE
	data.reputation += def.repReward
	data.stats.sold += 1
	progressDaily(session, "sold", 1)
	addSeasonXp(player, session, Config.SeasonXp.sale)
	if session.event and session.event.siteId == site.id then
		session.event = nil
	end
	tryAutoStart(session)
end

local function activeDeals(data): number
	local n = 0
	for _, site in data.sites do
		if site.deal then
			n += 1
		end
	end
	return n
end

-- Termina las negociaciones cuyo tiempo ya ha pasado (también las que
-- acabaron mientras estabas desconectado)
local function finishDeals(player: Player, session: Session)
	local now = os.time()
	for i = #session.data.sites, 1, -1 do
		local site = session.data.sites[i]
		local deal = site and site.deal
		if deal and now >= deal.endsAt then
			completeSale(player, session, site, deal.price)
			notify(player, string.format("🤝 ¡Vendida! %s a %s por %s%s", site.name, deal.buyer, Config.formatMoney(deal.price),
				if deal.specialist then " (⭐ especialista x1.5)" else ""), "money")
		end
	end
end

-- Vender a un cliente no es instantáneo: empieza una negociación que dura
-- según el tipo de web. El precio queda fijado al empezar.
function Actions.sellToOffer(_player: Player, session: Session, offerId: any, siteId: any)
	local data = session.data
	for i, offer in session.offers do
		if offer.id == offerId then
			local site = findSite(data, siteId)
			if not site or site.type ~= offer.type then
				return false, "Esa empresa quiere otro tipo de web."
			end
			if site.deal then
				return false, "Esa web ya está en negociación."
			end
			if activeDeals(data) >= Config.maxDeals(data) then
				return false, "Ya tienes el máximo de negociaciones a la vez. Espera a que acabe alguna."
			end
			table.remove(session.offers, i)
			local mult = offer.mult * (if serverEventIs("blackfriday") then 2 else 1)
			local price, specialist = salePrice(session, site, mult, offer.niche)
			local seconds = Config.dealSeconds(data, site.type)
			site.deal = { endsAt = os.time() + seconds, price = price, buyer = offer.company, specialist = specialist }
			refreshOffers(session)
			return true, string.format("🤝 Negociando con %s: %s en %s", offer.company, Config.formatMoney(price), Config.formatTime(seconds))
		end
	end
	return false, "La oferta ya no está disponible."
end

-- La venta rápida sí es al momento, pero paga mucho menos
function Actions.quickSell(player: Player, session: Session, siteId: any)
	local site = findSite(session.data, siteId)
	if not site then
		return false, nil
	end
	if site.deal then
		return false, "Esa web ya está en negociación."
	end
	local now = os.clock()
	if now < session.quickSaleReadyAt then
		return false, string.format("Espera %d s para otra venta rápida.", math.ceil(session.quickSaleReadyAt - now))
	end
	session.quickSaleReadyAt = now + Config.QUICK_SALE_COOLDOWN
	local price = salePrice(session, site, Config.QUICK_SALE_MULT, nil)
	completeSale(player, session, site, price)
	return true, string.format("🤝 Vendiste %s a %s por %s", site.name, "un comprador anónimo", Config.formatMoney(price)), { money = true }
end

function Actions.ipo(_player: Player, session: Session)
	local data = session.data
	local newShares = Config.sharesForIpo(data.totalEarned)
	if newShares < 1 then
		return false, "Necesitas ganar " .. Config.formatMoney(Config.IPO_MIN_EARNED) .. " en esta partida."
	end
	local fresh = newData()
	local newPatents = Config.patentsForShares(newShares)
	data.patents += newPatents
	-- I+D: dinero inicial y Laboratorio de IA que se conservan
	local capital = Config.research(data, "capital")
	data.money = if capital > 0 then 100 * 10 ^ capital else fresh.money
	data.totalEarned = 0
	data.reputation = 0
	data.sites = {}
	data.project = nil
	data.autoType = nil
	data.companies = if Config.research(data, "autolab") > 0 then { ia_lab = 1 } else {}
	data.unlockedAds = fresh.unlockedAds
	data.maintenance = 0
	data.shares += newShares
	data.ipoCount += 1
	data.peakIncome = 0
	MarketService.clear(session)
	session.offers = {}
	session.event = nil
	refreshOffers(session)
	return true, string.format("📈 ¡Saliste a bolsa! +%d acciones (+%d%% de dinero para siempre) y +%d 💡 patentes", newShares, math.floor(newShares * Config.SHARE_BONUS * 100), newPatents), { money = true }
end

-- Bolsa de Ciudad Web (MarketService): fraction = parte del dinero / de tus acciones
function Actions.buyStock(_player: Player, session: Session, stockId: any, fraction: any)
	return MarketService.buy(session, stockId, fraction)
end

function Actions.sellStock(_player: Player, session: Session, stockId: any, fraction: any)
	local ok, message, profit = MarketService.sell(session, stockId, fraction)
	if ok and profit and profit > 0 then
		session.data.stats.marketProfit = (session.data.stats.marketProfit or 0) + profit
	end
	return ok, message, if ok then { money = true } else nil
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

function Actions.claimGoal(player: Player, session: Session, goalId: any)
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
			addSeasonXp(player, session, Config.SeasonXp.goal)
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
	session.data.stats.missions = (session.data.stats.missions or 0) + 1
	progressDaily(session, "missions", 1)
	addSeasonXp(player, session, Config.SeasonXp.dailyMission[mission.tier] or 60)
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

function Actions.claimWeeklyMission(player: Player, session: Session, index: any)
	ensureWeeklyMissions(session)
	local data = session.data
	local weekly = data.weeklyMissions
	local mission = type(index) == "number" and weekly.list[index]
	if not mission then
		return false, nil
	end
	if mission.claimed then
		return false, "Ya la has reclamado."
	end
	if mission.progress < mission.target then
		return false, "Aún no has terminado esta misión."
	end
	local reward = Config.WeeklyMissionReward
	local amount = incomeReward(session, reward.minutes, reward.min)
	gain(data, amount)
	mission.claimed = true
	data.stats.missions = (data.stats.missions or 0) + 1
	addSeasonXp(player, session, reward.seasonXp)
	local allDone = true
	for _, m in weekly.list do
		if not m.claimed then
			allDone = false
		end
	end
	if allDone and not weekly.bonusGiven then
		weekly.bonusGiven = true
		data.patents += Config.WEEKLY_ALL_PATENTS
		data.boostUntil = math.max(data.boostUntil, os.time()) + Config.WEEKLY_ALL_BOOST_MINUTES * 60
		refreshBoost(session)
		notify(player, string.format("🗓️ ¡Todas las misiones de la semana completadas! +%d 💡 patentes y 🚀 Boost x2 %d min",
			Config.WEEKLY_ALL_PATENTS, Config.WEEKLY_ALL_BOOST_MINUTES), "goal")
	end
	return true, "🗓️ Misión semanal completada: +" .. Config.formatMoney(amount), { money = true }
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

function Actions.setLanguage(_player: Player, session: Session, lang: any)
	if lang ~= "auto" and lang ~= "es" and lang ~= "en" then
		return false, nil
	end
	session.data.settings.lang = lang
	return true, nil
end

---------------------------------------------------------------------
-- Visitar imperios y dar "me gusta"
---------------------------------------------------------------------
local function playerByUserId(userId: any): Player?
	if type(userId) ~= "number" then
		return nil
	end
	for other in sessions do
		if other.UserId == userId then
			return other
		end
	end
	return nil
end

local function likedToday(data, ownerId: number): boolean
	local given = data.likesGiven
	return given.day == Config.dayIndex(os.time()) and given.ids["u" .. ownerId] == true
end

-- Manda al visitante la ficha del imperio de "owner"
local function sendVisit(visitor: Player, owner: Player)
	local ownerSession = sessions[owner]
	local visitorSession = sessions[visitor]
	if not ownerSession or not visitorSession then
		return
	end
	local data = ownerSession.data
	local best, bestVisits = nil, -1
	for _, site in data.sites do
		local visits = Config.siteVisits(data, site, visitMult(ownerSession, site))
		if visits > bestVisits then
			best, bestVisits = site, visits
		end
	end
	local career = data.career
	local bestRarity = nil
	for _, programmer in career.programmers do
		local rarity = Career.RarityById[programmer.rarity]
		if rarity and (not bestRarity or rarity.order > bestRarity.order) then
			bestRarity = rarity
		end
	end
	visitEvent:FireClient(visitor, {
		userId = owner.UserId,
		name = owner.DisplayName,
		own = visitor == owner,
		floors = Config.buildingFloors(data.lifetimeEarned),
		lifetimeEarned = data.lifetimeEarned,
		income = ownerSession.income,
		sites = #data.sites,
		bestSite = if best then { name = best.name, type = best.type, visits = bestVisits } else nil,
		agency = if career.agency then career.agency.name else nil,
		programmers = #career.programmers,
		bestRarity = if bestRarity then bestRarity.id else nil,
		devLevel = Career.devLevel(career),
		shares = data.shares,
		likes = data.likes,
		gold = data.goldUntil > os.time(),
		liked = likedToday(visitorSession.data, owner.UserId),
		likeReward = incomeReward(visitorSession, Config.LIKE_VISITOR_MINUTES, Config.LIKE_VISITOR_MIN),
	})
end

function Actions.visitPlot(player: Player, _session: Session, userId: any)
	local owner = playerByUserId(userId)
	if not owner then
		return false, "Ese jugador ya no está en el servidor."
	end
	sendVisit(player, owner)
	return true, nil
end

function Actions.likePlot(player: Player, session: Session, userId: any)
	local owner = playerByUserId(userId)
	local ownerSession = owner and sessions[owner]
	if not owner or not ownerSession then
		return false, "Ese jugador ya no está en el servidor."
	end
	if owner == player then
		return false, "No puedes darte me gusta a ti mismo 😄"
	end
	local data = session.data
	local today = Config.dayIndex(os.time())
	if data.likesGiven.day ~= today then
		data.likesGiven = { day = today, ids = {} }
	end
	local key = "u" .. owner.UserId
	if data.likesGiven.ids[key] then
		return false, "Ya le has dado me gusta hoy a este imperio."
	end
	local given = 0
	for _ in data.likesGiven.ids do
		given += 1
	end
	if given >= Config.MAX_LIKES_PER_DAY then
		return false, "Ya has dado todos los me gusta de hoy. ¡Vuelve mañana!"
	end
	data.likesGiven.ids[key] = true
	ownerSession.data.likes += 1
	local ownerReward = incomeReward(ownerSession, Config.LIKE_OWNER_MINUTES, Config.LIKE_OWNER_MIN)
	gain(ownerSession.data, ownerReward)
	notify(owner, string.format("👍 ¡A %s le gusta tu imperio! +%s", player.DisplayName, Config.formatMoney(ownerReward)), "money")
	local reward = incomeReward(session, Config.LIKE_VISITOR_MINUTES, Config.LIKE_VISITOR_MIN)
	gain(data, reward)
	sendState(owner)
	return true, string.format("👍 Te gusta el imperio de %s: +%s", owner.DisplayName, Config.formatMoney(reward)), { money = true }
end

---------------------------------------------------------------------
-- v2.0: premios (temporada, tiempo jugado, códigos), I+D
---------------------------------------------------------------------
-- Da un premio { kind = cash|boost|ticket|patents } y devuelve cómo se llama
local function giveReward(player: Player, session: Session, reward): string
	local data = session.data
	if reward.kind == "cash" then
		local amount = incomeReward(session, reward.minutes or reward.rewardMinutes or 5, reward.min or 500)
		gain(data, amount)
		return "+" .. Config.formatMoney(amount)
	elseif reward.kind == "boost" then
		local minutes = reward.minutes or reward.boostMinutes or 10
		data.boostUntil = math.max(data.boostUntil, os.time()) + minutes * 60
		refreshBoost(session)
		return "🚀 Boost x2 " .. minutes .. " min"
	elseif reward.kind == "ticket" then
		local tickets = data.career.tickets
		tickets[reward.ticket] = (tickets[reward.ticket] or 0) + reward.amount
		return if reward.ticket == "legendary" then "👑 +" .. reward.amount .. " Contrato Legendario" else "🎯 +" .. reward.amount .. " Headhunter Premium"
	elseif reward.kind == "patents" then
		data.patents += reward.amount
		return "💡 +" .. reward.amount .. " patentes"
	end
	return ""
end

function Actions.buyResearch(player: Player, session: Session, researchId: any)
	local def = type(researchId) == "string" and Config.ResearchById[researchId]
	if not def then
		return false, nil
	end
	local data = session.data
	local level = Config.research(data, def.id)
	if level >= def.maxLevel then
		return false, "Nivel máximo."
	end
	local cost = Config.researchCost(def.id, level)
	if data.patents < cost then
		return false, "Te faltan patentes. Se consiguen al salir a bolsa."
	end
	data.patents -= cost
	data.research[def.id] = level + 1
	CareerService.refreshBonuses(session)
	return true, string.format("💡 %s %s: nivel %d", def.emoji, def.name, level + 1)
end

function Actions.claimSeason(player: Player, session: Session, tier: any, premium: any)
	ensureSeason(session)
	local season = session.data.season
	if type(tier) ~= "number" or tier < 1 or tier > Config.SEASON_TIERS or tier % 1 ~= 0 then
		return false, nil
	end
	if seasonTier(season.xp) < tier then
		return false, "Aún no has llegado a ese nivel del pase."
	end
	local key = tostring(tier)
	if premium == true then
		if not season.premium then
			return false, "Necesitas el Pase de temporada Premium."
		end
		if season.premiumClaimed[key] then
			return false, "Ya lo has recogido."
		end
		season.premiumClaimed[key] = true
	else
		if season.free[key] then
			return false, "Ya lo has recogido."
		end
		season.free[key] = true
	end
	local text = giveReward(player, session, Config.seasonReward(tier, premium == true))
	return true, string.format("🎫 Nivel %d: %s", tier, text), { money = true }
end

-- Tiempo jugado hoy (se reinicia cada día UTC)
local function ensurePlaytime(data)
	local today = Config.dayIndex(os.time())
	if data.playtime.day ~= today then
		data.playtime = { day = today, seconds = 0, claimed = {} }
	end
end

function Actions.claimPlaytime(player: Player, session: Session, index: any)
	local data = session.data
	ensurePlaytime(data)
	local def = type(index) == "number" and Config.PlaytimeRewards[index]
	if not def then
		return false, nil
	end
	local key = tostring(index)
	if data.playtime.claimed[key] then
		return false, "Ya lo has recogido."
	end
	if data.playtime.seconds < def.minutes * 60 then
		return false, "Aún no has jugado suficiente hoy."
	end
	data.playtime.claimed[key] = true
	local text = giveReward(player, session, def)
	addSeasonXp(player, session, Config.SeasonXp.playtime)
	return true, string.format("⏱️ %d min jugados: %s", def.minutes, text), { money = true }
end

function Actions.redeemCode(player: Player, session: Session, text: any)
	if type(text) ~= "string" or #text > 40 then
		return false, nil
	end
	local code = string.upper((string.gsub(text, "%s", "")))
	local def = Config.CodeByCode[code]
	if not def or (def.expires and os.time() > def.expires) then
		return false, "Ese código no existe o ha caducado."
	end
	local data = session.data
	if data.codes[code] then
		return false, "Ya has usado ese código."
	end
	data.codes[code] = true
	local parts = { giveReward(player, session, { kind = "cash", minutes = def.minutes, min = def.min }) }
	if def.boostMinutes then
		table.insert(parts, giveReward(player, session, { kind = "boost", minutes = def.boostMinutes }))
	end
	return true, "🎟️ Código canjeado: " .. table.concat(parts, " · "), { money = true }
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

	-- Partes del juego que aún no se han desbloqueado (planta del rascacielos)
	local feature = ACTION_FEATURES[action]
	if feature and not Config.isUnlocked(session.data, feature) then
		return false, string.format("🔒 Se desbloquea en la planta %d de tu rascacielos.", Config.unlockFloor(feature))
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
		local amount = paidReward(session, product.minutes, product.min)
		gain(data, amount)
		notify(player, product.emoji .. " ¡" .. product.name .. "! +" .. Config.formatMoney(amount), "money")
	elseif product.kind == "boost" then
		data.boostUntil = math.max(data.boostUntil, os.time()) + product.minutes * 60
		refreshBoost(session)
		notify(player, "🚀 ¡Boost x2 activado durante " .. product.minutes .. " minutos!", "money")
	elseif product.kind == "ticket" then
		CareerService.grantTickets(player, session, product.ticket, product.amount)
	elseif product.kind == "starter" then
		data.starterBought = true
		local amount = paidReward(session, product.minutes, product.min)
		gain(data, amount)
		data.boostUntil = math.max(data.boostUntil, os.time()) + product.boostMinutes * 60
		refreshBoost(session)
		data.career.tickets.legendary = (data.career.tickets.legendary or 0) + 1
		popup(player, "🎁 ¡Pack de inicio!", "💰 +" .. Config.formatMoney(amount) .. "\n🚀 Boost x2 durante " .. product.boostMinutes .. " minutos\n👑 +1 Contrato Legendario\n\n¡Gracias por apoyar el juego!")
	elseif product.kind == "season" then
		ensureSeason(session)
		data.season.premium = true
		notify(player, "🎫 ¡Pase de temporada Premium activado! Recoge tus premios en 🎫 Pase", "money")
	elseif product.kind == "finish" then
		if data.project then
			addWork(player, session, data.project.required)
			notify(player, "⏩ ¡Web terminada al instante!", "success")
		else
			local amount = paidReward(session, 10, 1000)
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
	local weekly = session.data.weekly
	local weekStore = if weekly.earned > 0 then weeklyStore(weekly.week) else nil
	if weekStore then
		pcall(function()
			weekStore:SetAsync("u_" .. player.UserId, leaderboardScore(weekly.earned))
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

---------------------------------------------------------------------
-- Ranking semanal: cambio de semana y premios
---------------------------------------------------------------------
-- Si ha empezado una semana nueva, lo ganado pasa a "la semana pasada"
local function rolloverWeek(player: Player, session: Session)
	local weekly = session.data.weekly
	local week = Config.weekIndex(os.time())
	if weekly.week == week then
		return
	end
	if weekly.week >= 0 then
		local oldWeek, oldEarned = weekly.week, weekly.earned
		-- Puntuación final de la semana que acaba
		local weekStore = if oldEarned > 0 then weeklyStore(oldWeek) else nil
		if weekStore and session.canSave then
			task.spawn(function()
				pcall(function()
					weekStore:SetAsync("u_" .. player.UserId, leaderboardScore(oldEarned))
				end)
			end)
		end
		weekly.prevWeek, weekly.prevEarned = oldWeek, oldEarned
	end
	weekly.week = week
	weekly.earned = 0
	-- Los premios se reparten un rato después, cuando todos han guardado
	session.weeklyCheckAt = math.max(os.clock(), os.clock() + (Config.weekStart(week) + Config.WEEKLY_GRACE - os.time()))
end

-- Puestos de una semana ya terminada: { [userId] = puesto } (top 100)
local weeklyRanks: { [number]: { [number]: number } } = {}

local function ranksOfWeek(week: number): { [number]: number }?
	if weeklyRanks[week] then
		return weeklyRanks[week]
	end
	local weekStore = weeklyStore(week)
	if not weekStore then
		return nil
	end
	local ok, pages = pcall(function()
		return weekStore:GetSortedAsync(false, 100)
	end)
	if not ok then
		return nil
	end
	local ranks = {}
	for i, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		if userId then
			ranks[userId] = i
		end
	end
	weeklyRanks[week] = ranks
	return ranks
end

local function grantWeeklyPrize(player: Player, session: Session)
	local data = session.data
	local weekly = data.weekly
	if weekly.prevWeek < 0 or weekly.rewardedWeek >= weekly.prevWeek then
		return
	end
	if weekly.prevEarned <= 0 or not session.canSave then
		weekly.rewardedWeek = weekly.prevWeek
		return
	end
	local ranks = ranksOfWeek(weekly.prevWeek)
	if not ranks then
		session.weeklyCheckAt = os.clock() + 120 -- se reintenta más tarde
		return
	end
	weekly.rewardedWeek = weekly.prevWeek
	local rank = ranks[player.UserId]
	local prize = rank and Config.weeklyPrize(rank)
	if not rank or not prize then
		notify(player, "📊 La semana pasada ganaste " .. Config.formatMoney(weekly.prevEarned) .. ". ¡Esta semana puedes entrar en el top 100!", "info")
		return
	end
	local lines = {}
	local amount = incomeReward(session, prize.minutes, 1000)
	gain(data, amount)
	table.insert(lines, "💰 +" .. Config.formatMoney(amount))
	if prize.legendary > 0 then
		data.career.tickets.legendary = (data.career.tickets.legendary or 0) + prize.legendary
		table.insert(lines, "👑 +" .. prize.legendary .. " Contrato Legendario")
	end
	if prize.goldDays > 0 then
		data.goldUntil = math.max(data.goldUntil, os.time()) + prize.goldDays * 86400
		table.insert(lines, "🏆 Rascacielos dorado durante " .. prize.goldDays .. " días")
	end
	popup(player, prize.emoji .. " ¡" .. prize.name .. "!", "Quedaste en el puesto #" .. rank .. " del ranking semanal.\n\n" .. table.concat(lines, "\n"))
	-- Se guarda ya para que el premio no se pueda repetir si el servidor se cae
	task.spawn(saveData, player, session)
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

-- Lo que se ve de tu imperio en la parcela (programadores, webs, pantalla...)
local function plotExtras(session: Session)
	local data = session.data
	local best, bestVisits = nil, -1
	for _, site in data.sites do
		local visits = Config.siteVisits(data, site, visitMult(session, site))
		if visits > bestVisits then
			best, bestVisits = site, visits
		end
	end
	local career = data.career
	return {
		gold = data.goldUntil > os.time(),
		likes = data.likes,
		agency = career.agency ~= nil,
		agencyName = if career.agency then career.agency.name else nil,
		officeLevel = if career.agency then career.agency.officeLevel else 0,
		capacity = CareerService.capacity(session),
		programmers = career.programmers,
		builtTypes = data.stats.byType,
		bestSite = if best then { name = best.name, type = best.type, visits = bestVisits, variant = best.variant } else nil,
	}
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
		agencyQuality = 0,
		agencyVisits = 0,
		agencySale = 0,
		agencyRare = 0,
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
	CareerService.migrate(data.career)
	-- Misiones que ya no existen (v3: "tareas del trabajo"): se sortean otras
	for _, mission in data.dailyMissions.list do
		if not Config.DailyMissionById[mission.id] then
			data.dailyMissions.day = -1
		end
	end
	for _, mission in data.weeklyMissions.list do
		if not Config.WeeklyMissionById[mission.id] then
			data.weeklyMissions.week = -1
		end
	end
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
		nextOfferAt = 0,
		quickSaleReadyAt = 0,
		event = nil,
		nextEventAt = os.clock() + 60,
		giftReadyAt = os.clock() + Config.GIFT_INTERVAL,
		contractBoard = {},
		nextContractAt = 0,
		askReadyAt = 0,
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
		weeklyCheckAt = os.clock() + 10,
		weeklyChecking = false,
		combo = 0,
		lastClickAt = 0,
		floors = Config.buildingFloors(data.lifetimeEarned),
		achievementTiers = {},
	}
	sessions[player] = session
	rolloverWeek(player, session)
	ensureSeason(session)
	ensurePlaytime(data)
	ensureWeeklyMissions(session)
	for _, achievement in Config.Achievements do
		session.achievementTiers[achievement.id] = Config.achievementTier(data, achievement)
	end
	if session.weeklyCheckAt < os.clock() + 10 then
		session.weeklyCheckAt = os.clock() + 10
	end
	local weekend = Config.weekendStatus(os.time())
	bonuses.weekend = if weekend then weekend.id else nil
	refreshBoost(session)
	CareerService.initSession(session)
	CareerService.refreshBonuses(session)

	-- Al entrar ya hay ofertas; luego llegan de una en una
	for _ = 1, Config.OFFER_COUNT do
		table.insert(session.offers, makeOffer(session))
	end
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

	-- Evento de fin de semana en marcha
	-- (a los nuevos solo un aviso pequeño, para no taparles el tutorial)
	local weekendEvent, weekendEnds = Config.weekendStatus(os.time())
	if weekendEvent then
		task.delay(8, function()
			if isNew then
				notify(player, "🎉 ¡Empieza el evento: " .. weekendEvent.emoji .. " " .. weekendEvent.name .. "!", "event")
			else
				popup(player, "🎉 ¡Evento de fin de semana!", weekendEvent.emoji .. " " .. weekendEvent.name .. "\n\n" .. weekendEvent.desc .. "\n\nTermina en " .. Config.formatTime(weekendEnds - os.time()) .. ".")
			end
		end)
	end

	PlotManager.claim(player)
	PlotManager.update(player, data.lifetimeEarned, session.income, plotExtras(session))

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

local function nameOf(userId: number): string
	if not nameCache[userId] then
		local okName, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if not okName then
			return "Jugador"
		end
		nameCache[userId] = result
	end
	return nameCache[userId]
end

-- Las 10 mejores puntuaciones de una clasificación (nil si falla)
local function topRows(board: OrderedDataStore): { BoardRow }?
	local ok, pages = pcall(function()
		return board:GetSortedAsync(false, Config.WEEKLY_TOP_SIZE)
	end)
	if not ok then
		return nil
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		table.insert(rows, {
			name = if userId then nameOf(userId) else "???",
			value = leaderboardValue(entry.value),
			userId = userId,
		})
	end
	return rows
end

local function refreshLeaderboard()
	if not leaderboardStore then
		PlotManager.setLeaderboard(nil, "Publica el juego para ver la clasificación")
		PlotManager.setWeeklyBoard(nil, "Publica el juego para ver la clasificación")
		return
	end
	local rows = topRows(leaderboardStore)
	if rows then
		globalTop = rows
		PlotManager.setLeaderboard(rows, nil)
	else
		PlotManager.setLeaderboard(nil, "Clasificación disponible al publicar el juego")
	end
	local week = Config.weekIndex(os.time())
	local weekStore = weeklyStore(week)
	local weekRows = weekStore and topRows(weekStore)
	if weekRows then
		weeklyTop = weekRows
		weeklyTopWeek = week
		PlotManager.setWeeklyBoard(weekRows, nil)
	else
		PlotManager.setWeeklyBoard(nil, "Clasificación disponible al publicar el juego")
	end
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
	saleValue = function(session, typeId)
		-- Una web nueva de calidad normal
		local data = session.data
		local site = { type = typeId, quality = 1, seo = 0, design = 0, network = "adsimple", adLevel = 1 }
		return Config.saleBase(data, site, Config.moneyMult(data, session.bonuses), session.bonuses)
	end,
	workRate = function(session)
		-- Trabajo automático + unos 3 clics por segundo
		return Config.workPerSec(session.data, session.bonuses) + Config.clickPower(session.data, session.bonuses) * 3
	end,
	isNight = PlotManager.isNight,
	progress = function(session, stat, amount)
		progressDaily(session, stat, amount)
	end,
	startContract = function(session, typeId, contractId)
		local def = Config.WebTypeById[typeId]
		if not def then
			return false, nil
		end
		local ok, reason = canStartProject(session, def, true)
		if not ok then
			return false, reason
		end
		startProject(session.data, def, contractId)
		return true, "💻 ¡A programar! Cuando termines la web se entrega sola."
	end,
})
for name, handler in CareerService.Actions do
	Actions[name] = handler
end

MarketService.init({
	random = random,
	gain = gain,
	notifyAll = function(text, kind)
		for other in sessions do
			notify(other, text, kind)
		end
	end,
	sessions = function()
		return sessions
	end,
	onTick = PlotManager.setMarketBoard,
})

PlotManager.init(function(player)
	openComputerEvent:FireClient(player)
end, function(visitor, owner)
	sendVisit(visitor, owner)
end)
PlotManager.setMarketBoard(MarketService.rows())

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

---------------------------------------------------------------------
-- Eventos del servidor y meta cooperativa (para todos a la vez)
---------------------------------------------------------------------
local nextServerEventAt = os.clock() + random:NextNumber(Config.SERVER_EVENT_MIN_DELAY, Config.SERVER_EVENT_MAX_DELAY) / 2
local nextCommunityAt = os.clock() + 60

local function notifyAll(text: string, kind: string)
	for other in sessions do
		notify(other, text, kind)
	end
end

local function updateServerEvent(now: number)
	if serverEvent and now >= serverEvent.endsAt then
		local def = Config.ServerEventById[serverEvent.id]
		serverEvent = nil
		PlotManager.setEventTint(nil)
		notifyAll(string.format("%s %s ha terminado", def.emoji, def.name), "info")
	end
	if not serverEvent and now >= nextServerEventAt and next(sessions) ~= nil then
		nextServerEventAt = now + random:NextNumber(Config.SERVER_EVENT_MIN_DELAY, Config.SERVER_EVENT_MAX_DELAY)
		local total = 0
		for _, def in Config.ServerEvents do
			total += def.weight
		end
		local roll = random:NextNumber() * total
		local chosen = Config.ServerEvents[1]
		for _, def in Config.ServerEvents do
			roll -= def.weight
			if roll <= 0 then
				chosen = def
				break
			end
		end
		serverEvent = { id = chosen.id, endsAt = now + chosen.duration }
		PlotManager.setEventTint(chosen.tint)
		notifyAll(string.format("%s ¡EVENTO DEL SERVIDOR: %s! %s", chosen.emoji, chosen.name, chosen.desc), "event")
	end
end

local function updateCommunity(now: number)
	if community then
		-- Los que entran a mitad también cuentan desde que llegan
		for player, session in sessions do
			if community.start[player] == nil then
				community.start[player] = session.data.lifetimeEarned
			end
		end
		if communityProgress() >= community.target then
			for player in community.start do
				local session = sessions[player]
				if session then
					local amount = incomeReward(session, Config.COMMUNITY_REWARD_MINUTES, 500)
					gain(session.data, amount)
					addSeasonXp(player, session, Config.SeasonXp.community)
					notify(player, "🤝 ¡Meta del servidor conseguida! Premio para todos: +" .. Config.formatMoney(amount), "money")
				end
			end
			community = nil
			nextCommunityAt = now + Config.COMMUNITY_COOLDOWN
		elseif now >= community.endsAt then
			community = nil
			nextCommunityAt = now + Config.COMMUNITY_COOLDOWN
			notifyAll("🤝 Esta vez no se llegó a la meta del servidor. ¡Viene otra!", "info")
		end
	elseif now >= nextCommunityAt and next(sessions) ~= nil then
		local incomes = 0
		local start = {}
		for player, session in sessions do
			incomes += computeIncome(session, false)
			start[player] = session.data.lifetimeEarned
		end
		local target = math.max(Config.COMMUNITY_MIN_TARGET, incomes * Config.COMMUNITY_TARGET_SECONDS)
		community = {
			target = target,
			endsAt = now + Config.COMMUNITY_DURATION,
			start = start,
		}
		notifyAll("🤝 ¡Nueva meta del servidor! Ganad " .. Config.formatMoney(target) .. " entre todos en " .. Config.formatTime(Config.COMMUNITY_DURATION), "event")
	end
end

-- Qué es cada parte del juego (ventana al desbloquearla)
local UNLOCK_INFO = {
	clients = "Ahora las empresas quieren comprarte webs.\n\nEn 🤝 Clientes verás sus ofertas. Al aceptar una, la negociación tarda un rato y luego cobras. Cada venta te deja un contrato de mantenimiento que paga para siempre.",
	ads = "En 📢 Anuncios puedes desbloquear apps de anuncios mejores.\n\nCada app paga más por visita, pero algunas espantan a parte de tus visitas. También eliges cuántos anuncios pones en cada web.",
	ranking = "En 🏆 Ranking ves a los mejores del servidor y de la semana.\n\nVisita sus imperios y dales me gusta: los dos ganáis dinero.",
	companies = "En 🏢 Empresas compras negocios que te ayudan para siempre: programadores que trabajan solos, más visitas, mejores ventas...\n\nCada empresa te dice qué hace ahora y qué hará al subirla.",
	season = "El 🎫 Pase de temporada sube con todo lo que haces. Cada nivel tiene un premio gratis.",
	career = "Las empresas te harán ENCARGOS: te piden una web concreta (tipo y nicho) con un plazo.\n\nAcepta uno en 💼 Carrera, pulsa «Programar ahora» y cuando termines la web se entrega sola. Pagan mucho más que vender una web y con ellos subes de rango.",
	collection = "📖 Colección: cada combinación de tipo de web y rareza que consigas da +1 % de dinero para siempre.",
	agency = "Con nivel de programador 8 puedes fundar tu 👥 Agencia y fichar programadores.\n\nCada uno tiene una especialidad (programación, diseño, marketing, ventas o datos) y un rasgo, y sube de nivel solo trabajando.",
	market = "📈 La Bolsa de Ciudad Web: compra acciones de 6 empresas cuando estén baratas y véndelas cuando suban. Los precios cambian cada 30 s y son iguales para todo el servidor. Mientras las tengas, cobras dividendos.\n\nAhí también puedes SALIR A BOLSA con tu imperio: empiezas de cero, pero ganas más dinero para siempre y patentes para 💡 I+D.",
}

-- Nombre de cada parte del juego que se desbloquea (para el aviso)
local UNLOCK_NAMES = {
	clients = "🤝 Clientes",
	ads = "📢 Anuncios",
	ranking = "🏆 Ranking",
	companies = "🏢 Empresas",
	season = "🎫 Pase de temporada",
	career = "💼 Carrera",
	collection = "📖 Colección",
	agency = "👥 Agencia",
	market = "📈 Bolsa e 💡 I+D",
}

-- Bucle de la economía: una vez por segundo
local lastTick = os.clock()
while true do
	task.wait(1)
	local now = os.clock()
	local dt = math.min(now - lastTick, 5)
	lastTick = now

	local weekendEvent = Config.weekendStatus(os.time())
	local weekendId = if weekendEvent then weekendEvent.id else nil
	updateServerEvent(now)
	updateCommunity(now)
	MarketService.tick(now)
	for player, session in sessions do
		local data = session.data

		-- Tiempo jugado hoy (premios y misión diaria "juega X minutos")
		ensurePlaytime(data)
		local minutesBefore = data.playtime.seconds // 60
		data.playtime.seconds += dt
		local minutesNow = data.playtime.seconds // 60
		if minutesNow > minutesBefore then
			progressDaily(session, "playtime", minutesNow - minutesBefore)
			for _, reward in Config.PlaytimeRewards do
				if reward.minutes == minutesNow then
					notify(player, string.format("⏱️ ¡Premio por jugar %d minutos listo! Recógelo en 🛒 Tienda", reward.minutes), "goal")
				end
			end
		end
		ensureSeason(session)
		ensureWeeklyMissions(session)
		finishDeals(player, session)
		-- Partes del juego que se abren al crecer el rascacielos
		local floors = Config.buildingFloors(data.lifetimeEarned)
		if floors > session.floors then
			for feature, floor in Config.Unlocks do
				if floor > session.floors and floor <= floors then
					notify(player, "🔓 ¡Desbloqueado: " .. UNLOCK_NAMES[feature] .. "! Mira tu ordenador", "goal")
					popup(player, "🔓 " .. UNLOCK_NAMES[feature], UNLOCK_INFO[feature])
				end
			end
			session.floors = floors
		end
		-- Logros: avisar al subir de nivel (el bonus se aplica solo)
		for _, achievement in Config.Achievements do
			local tier = Config.achievementTier(data, achievement)
			if tier > (session.achievementTiers[achievement.id] or 0) then
				session.achievementTiers[achievement.id] = tier
				notify(player, string.format("%s ¡Logro %s %s! Bonus permanente", Config.ACHIEVEMENT_TIER_EMOJIS[tier], achievement.emoji, achievement.name), "goal")
			end
		end
		-- El combo se pierde si dejas de teclear
		if session.combo > 0 and now - session.lastClickAt > Config.COMBO_WINDOW then
			session.combo = 0
		end

		-- Evento de fin de semana: avisar cuando empieza y cuando acaba
		if session.bonuses.weekend ~= weekendId then
			if weekendEvent then
				notify(player, "🎉 ¡Empieza el evento: " .. weekendEvent.emoji .. " " .. weekendEvent.name .. "!", "event")
			else
				notify(player, "El evento de fin de semana ha terminado. ¡Hasta el próximo!", "info")
			end
			session.bonuses.weekend = weekendId
		end
		-- Ranking semanal
		rolloverWeek(player, session)
		if now >= session.weeklyCheckAt and not session.weeklyChecking and data.weekly.rewardedWeek < data.weekly.prevWeek then
			session.weeklyChecking = true
			task.spawn(function()
				grantWeeklyPrize(player, session)
				session.weeklyChecking = false
				if sessions[player] then
					sendState(player)
				end
			end)
		end

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
		-- Lo máximo que puedes invertir en Bolsa depende de tus mejores ingresos
		data.peakIncome = math.max(data.peakIncome, computeIncome(session, false))
		-- Visitas y dinero acumulados por cada web (para su ficha)
		local moneyMult = Config.moneyMult(data, session.bonuses)
		for _, site in data.sites do
			local visits = Config.siteVisits(data, site, visitMult(session, site))
			site.totalVisits = (site.totalVisits or 0) + visits * dt
			site.earned = (site.earned or 0) + Config.siteIncome(data, site, visits, moneyMult) * dt
		end

		local workPerSec = Config.workPerSec(data, session.bonuses) * (if serverEventIs("hackathon") then 2 else 1)
		if workPerSec > 0 then
			addWork(player, session, workPerSec * dt)
		end
		tryAutoStart(session)

		refreshOffers(session)
		checkGoals(player, session)
		PlotManager.update(player, data.lifetimeEarned, session.income, plotExtras(session))
		sendState(player)
	end
end
