--[[
	StateService (ModuleScript en ServerScriptService)

	Estado que se envía al cliente (completo la primera vez y luego por
	diferencias, F7) y su límite de envíos.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local StatePatch = require(ReplicatedStorage:WaitForChild("StatePatch"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))
local MarketService = require(ServerScriptService:WaitForChild("MarketService"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local StoryService = require(ServerScriptService:WaitForChild("StoryService"))

local communityProgress = ServerState.communityProgress
local sessions = ServerState.sessions
local stateEvent = ServerState.stateEvent
local world = ServerState.world
type Session = ServerState.Session
local incomeReward = Economy.incomeReward
local visitMult = Economy.visitMult
local dailyStatus = RewardService.dailyStatus

local StateService = {}
local Actions = {}

local sig3 = StatePatch.sig3
local timer = StatePatch.timer

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
			totalVisits = sig3(site.totalVisits or 0),
			earned = sig3(site.earned or 0),
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
			timeLeft = math.ceil(offer.expiresAt - now),
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
		quickSaleLeft = math.max(0, math.ceil(session.quickSaleReadyAt - now)),
		weeklyMissions = {
			list = data.weeklyMissions.list,
			bonusGiven = data.weeklyMissions.bonusGiven,
			resetIn = timer(Config.weekStart(Config.weekIndex(os.time()) + 1) - os.time()),
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
		event = if session.event then { name = session.event.name, timeLeft = math.ceil(session.event.endsAt - now) } else nil,
		goals = data.goals,
		stats = data.stats,
		dailyAvailable = dailyAvailable,
		dailyDay = dailyDay,
		dailyAmount = incomeReward(session, dailyDef.minutes, dailyDef.min),
		giftLeft = math.max(0, math.ceil(session.giftReadyAt - now)),
		giftAmount = incomeReward(session, Config.GIFT_MINUTES, Config.GIFT_MIN),
		canSave = session.canSave,
		lastSaveOk = session.lastSaveOk,
		lastSaveAgo = if session.lastSaveAt > 0 then os.time() - session.lastSaveAt else -1,
		selectedNiche = data.selectedNiche,
		career = CareerService.buildState(session),
		story = StoryService.buildState(session),
		market = MarketService.buildState(session, now),
		tutorialDone = data.tutorialDone,
		settings = data.settings,
		likes = data.likes,
		goldLeft = timer(data.goldUntil - nowUnix),
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
			endsIn = timer(Config.seasonEnds(data.season.id) - nowUnix),
		},
		playtime = { seconds = math.floor(data.playtime.seconds), claimed = data.playtime.claimed },
		starterLeft = if data.starterBought then 0 else math.max(0, data.firstJoin + Config.STARTER_HOURS * 3600 - nowUnix),
		serverEvent = if world.serverEvent then { id = world.serverEvent.id, endsIn = math.ceil(world.serverEvent.endsAt - now) } else nil,
		community = if world.community then {
			target = world.community.target,
			progress = sig3(communityProgress()),
			endsIn = math.ceil(world.community.endsAt - now),
		} else nil,
		neighbors = neighbors,
		globalTop = world.globalTop,
		weekly = {
			earned = sig3(data.weekly.earned),
			resetIn = timer(Config.weekStart(Config.weekIndex(nowUnix) + 1) - nowUnix),
			top = if world.weeklyTopWeek == Config.weekIndex(nowUnix) then world.weeklyTop else {},
		},
		weekend = {
			id = if activeWeekend then activeWeekend.id else nil,
			endsIn = if activeWeekend then timer(weekendEnds - nowUnix) else 0,
			nextId = nextWeekend.id,
			startsIn = timer(nextWeekendStarts - nowUnix),
		},
		dailyMissions = {
			list = data.dailyMissions.list,
			bonusGiven = data.dailyMissions.bonusGiven,
			resetIn = timer(86400 - os.time() % 86400),
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

-- Manda al cliente lo que ha cambiado desde el último envío (la primera vez,
-- o si lo pide el cliente, el estado completo). FireClient(estado, esParche)
local function sendState(player: Player)
	local session = sessions[player]
	if session then
		session.leaderMoney.Value = math.clamp(math.floor(session.data.money), 0, 9e18)
		session.leaderShares.Value = session.data.shares
		session.leaderLevel.Value = session.data.career.stats.devLevel
		local state = buildState(session)
		session.dirty = false
		session.lastSendAt = os.clock()
		if session.sent == nil then
			stateEvent:FireClient(player, state, false)
		else
			local patch = StatePatch.diff(session.sent, state)
			if patch == nil then
				return
			end
			stateEvent:FireClient(player, patch, true)
		end
		session.sent = StatePatch.copy(state)
	end
end

-- Tras una acción: se manda ya si hace al menos STATE_MIN_INTERVAL del último
-- envío; si no, se marca y lo manda el bucle rápido (máx. 4 envíos/s)
local function requestState(player: Player, session: Session)
	if os.clock() - session.lastSendAt >= Config.STATE_MIN_INTERVAL then
		sendState(player)
	else
		session.dirty = true
	end
end

---------------------------------------------------------------------
-- Eventos aleatorios
---------------------------------------------------------------------

-- El cliente pide el estado completo (p. ej. si le llegó un parche sin tener
-- el estado de partida)
function Actions.requestState(_player: Player, session: Session)
	session.sent = nil
	return true, nil
end

StateService.buildState = buildState
StateService.requestState = requestState
StateService.sendState = sendState
StateService.sig3 = sig3
StateService.Actions = Actions

return StateService
