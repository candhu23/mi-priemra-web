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
local StarterPlayer = game:GetService("StarterPlayer")
local PolicyService = game:GetService("PolicyService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local Validate = require(ReplicatedStorage:WaitForChild("Validate"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))
local PlotManager = require(ServerScriptService:WaitForChild("PlotManager"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))
local MarketService = require(ServerScriptService:WaitForChild("MarketService"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local SaveService = require(ServerScriptService:WaitForChild("SaveService"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local SiteService = require(ServerScriptService:WaitForChild("SiteService"))
local WorldEvents = require(ServerScriptService:WaitForChild("WorldEvents"))
local StateService = require(ServerScriptService:WaitForChild("StateService"))
local VisitService = require(ServerScriptService:WaitForChild("VisitService"))
local PurchaseService = require(ServerScriptService:WaitForChild("PurchaseService"))
local LeaderboardService = require(ServerScriptService:WaitForChild("LeaderboardService"))
local Analytics = require(ServerScriptService:WaitForChild("Analytics"))
local BadgeAwards = require(ServerScriptService:WaitForChild("BadgeAwards"))

local actionFunction = ServerState.actionFunction
local gain = ServerState.gain
local notify = ServerState.notify
local openComputerEvent = ServerState.openComputerEvent
local popup = ServerState.popup
local random = ServerState.random
local serverEventIs = ServerState.serverEventIs
local sessions = ServerState.sessions
type Bonuses = ServerState.Bonuses
type Session = ServerState.Session
local computeIncome = Economy.computeIncome
local refreshBoost = Economy.refreshBoost
local visitMult = Economy.visitMult
local kickText = SaveService.kickText
local loadData = SaveService.loadData
local releaseLock = SaveService.releaseLock
local releasing = SaveService.releasing
local saveData = SaveService.saveData
local checkGoals = RewardService.checkGoals
local ensureDailyMissions = RewardService.ensureDailyMissions
local ensurePlaytime = RewardService.ensurePlaytime
local ensureSeason = RewardService.ensureSeason
local ensureWeeklyMissions = RewardService.ensureWeeklyMissions
local progressDaily = RewardService.progressDaily
local addWork = SiteService.addWork
local canStartProject = SiteService.canStartProject
local finishDeals = SiteService.finishDeals
local makeOffer = SiteService.makeOffer
local refreshOffers = SiteService.refreshOffers
local startProject = SiteService.startProject
local tryAutoStart = SiteService.tryAutoStart
local triggerEvent = WorldEvents.triggerEvent
local updateCommunity = WorldEvents.updateCommunity
local updateServerEvent = WorldEvents.updateServerEvent
local requestState = StateService.requestState
local sendState = StateService.sendState
local registerFriends = VisitService.registerFriends
local sendVisit = VisitService.sendVisit
local updateFriendBonus = VisitService.updateFriendBonus
local checkPasses = PurchaseService.checkPasses
local grantWeeklyPrize = LeaderboardService.grantWeeklyPrize
local refreshLeaderboard = LeaderboardService.refreshLeaderboard
local rolloverWeek = LeaderboardService.rolloverWeek

local Monetization = Config.Monetization

StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED

---------------------------------------------------------------------
-- Remotes (canales de comunicación cliente <-> servidor)
---------------------------------------------------------------------

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

local Actions = {}

function Actions.setMuted(_player: Player, session: Session, muted: any)
	session.data.settings.muted = muted == true
	session.data.settings.volume = if muted == true then 0 else 1
	return true, nil
end

-- Volumen de los efectos (0..1) y música sí/no
function Actions.setVolume(_player: Player, session: Session, volume: any)
	if not Validate.number(volume, 0, 1) then
		return false, nil
	end
	session.data.settings.volume = volume
	session.data.settings.muted = volume == 0
	return true, nil
end

function Actions.setMusic(_player: Player, session: Session, on: any)
	session.data.settings.music = on == true
	return true, nil
end

function Actions.setLanguage(_player: Player, session: Session, lang: any)
	if not Locale.isValid(lang) then
		return false, nil
	end
	session.data.settings.lang = lang
	return true, nil
end

---------------------------------------------------------------------
-- Visitar imperios y dar "me gusta"
---------------------------------------------------------------------

actionFunction.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
	local session = sessions[player]
	if not session or type(action) ~= "string" then
		return false, nil
	end
	-- Nada de NaN, infinitos ni textos enormes (F6)
	if not Validate.args(a, b) then
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
		-- El clic no manda estado: el cliente ya suma el progreso él solo
		if action ~= "click" then
			requestState(player, session)
		end
	end
	return ok, message, extra
end

---------------------------------------------------------------------
-- Compras con Robux
---------------------------------------------------------------------

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

local function onPlayerAdded(player: Player)
	local data, canSave, status = loadData(player)
	if status == "locked" then
		if player.Parent then
			player:Kick(kickText(player, "Tu partida sigue abierta en otro servidor. Espera un minuto y vuelve a entrar."))
		end
		return
	end
	if not player.Parent then
		-- se fue mientras cargaba
		if canSave then
			releaseLock(player)
		end
		return
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
		userId = player.UserId,
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
		closed = false,
		joinedAt = os.clock(),
		tutorialSteps = {},
		badgeCheckAt = os.clock() + 5,
		errors = 0,
		sent = nil,
		lastSendAt = 0,
		dirty = false,
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

	-- Ganancias mientras estabas desconectado. El boost x2 y el fin de semana
	-- x2 solo cuentan el rato que estuvieron activos mientras no estabas.
	local isNew = data.stats.built == 0 and data.lifetimeEarned == 0
	if isNew then
		Analytics.onboarding(player, data, "join")
	end
	local lastOnline = tonumber(data.lastOnline) or os.time()
	local away = math.clamp(os.time() - lastOnline, 0, Config.OFFLINE_MAX_HOURS * 3600)
	if away >= 60 and session.income > 0 then
		local boost, weekendBonus = bonuses.boost, bonuses.weekend
		bonuses.boost, bonuses.weekend = false, nil
		local base = computeIncome(session, false)
		bonuses.boost, bonuses.weekend = boost, weekendBonus
		-- Se cuenta en trozos de 10 min (máx. 8 h = 48 trozos)
		local earned = 0
		local t = lastOnline
		while t < lastOnline + away do
			local step = math.min(600, lastOnline + away - t)
			local boosted = math.clamp(data.boostUntil - t, 0, step) -- segundos con boost x2
			local event = Config.weekendStatus(t + step / 2)
			local weekendMult = if event and event.id == "money" then Config.WEEKEND_MONEY_MULT else 1
			earned += base * Config.OFFLINE_RATE * weekendMult * (step + boosted)
			t += step
		end
		gain(data, earned, "offline")
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
		session.closed = true
		Analytics.flush(player, session.data)
		releasing[player.UserId] = true
		saveData(player, session, true)
		releasing[player.UserId] = nil
	end
end

---------------------------------------------------------------------
-- Clasificación global
---------------------------------------------------------------------

CareerService.init({
	gain = gain,
	spend = ServerState.spend,
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

-- Las acciones viven en cada módulo; aquí se juntan todas
for _, module in { CareerService, SiteService, RewardService, StateService, VisitService, SaveService } do
	for name, handler in (module :: any).Actions do
		assert(Actions[name] == nil, "acción repetida: " .. name)
		Actions[name] = handler
	end
end

MarketService.init({
	gain = gain,
	spend = ServerState.spend,
	userId = function(session)
		return session.userId
	end,
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
		session.closed = true
		task.spawn(saveData, player, session, true)
	end
	-- Espera también a los guardados que ya estaban en marcha
	task.wait(0.5)
	local deadline = os.clock() + 25
	while SaveService.pending() > 0 and os.clock() < deadline do
		task.wait(0.5)
	end
end)

-- Errores en los bucles: se avisan sin parar el juego (F8)
local loopErrors = 0

local function reportLoopError(where: string, err: any)
	loopErrors += 1
	if loopErrors <= 20 or loopErrors % 100 == 0 then
		warn(string.format("[ImperioWeb] Error en %s (%d en total): %s", where, loopErrors, tostring(err)))
	end
end

-- Envíos de estado pendientes (como mucho cada STATE_MIN_INTERVAL)
task.spawn(function()
	while true do
		task.wait(Config.STATE_MIN_INTERVAL)
		for player, session in sessions do
			if session.dirty and os.clock() - session.lastSendAt >= Config.STATE_MIN_INTERVAL then
				local ok, err = pcall(sendState, player)
				if not ok then
					reportLoopError("el envío de estado de " .. player.Name, err)
				end
			end
		end
	end
end)

-- Analítica de la economía: se envía sumada cada cierto tiempo
task.spawn(function()
	while true do
		task.wait(Analytics.FLUSH_INTERVAL)
		for player, session in sessions do
			local ok, err = pcall(Analytics.flush, player, session.data)
			if not ok then
				reportLoopError("la analítica de " .. player.Name, err)
			end
		end
	end
end)

-- Guardado automático
task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for player, session in sessions do
			task.spawn(function()
				local ok, err = pcall(saveData, player, session)
				if not ok then
					reportLoopError("el guardado de " .. player.Name, err)
				end
			end)
		end
	end
end)

-- Clasificación
task.spawn(function()
	task.wait(5)
	while true do
		local ok, err = pcall(refreshLeaderboard)
		if not ok then
			reportLoopError("la clasificación", err)
		end
		task.wait(Config.LEADERBOARD_REFRESH)
	end
end)

---------------------------------------------------------------------
-- Eventos del servidor y meta cooperativa (para todos a la vez)
---------------------------------------------------------------------

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

-- Un segundo de economía para un jugador (si falla, no afecta a los demás)
local function tickPlayer(player: Player, session: Session, now: number, dt: number, weekendEvent: any, weekendId: string?)
	local data = session.data

	-- Tiempo jugado hoy (premios y misión diaria "juega X minutos")
	ensurePlaytime(data)
	local minutesBefore = data.playtime.seconds // 60
	data.playtime.seconds += dt
	local minutesNow = data.playtime.seconds // 60
	if minutesNow > minutesBefore then
		progressDaily(session, "playtime", minutesNow - minutesBefore)
		for _, reward in Config.PlaytimeRewards do
			if reward.atMinutes == minutesNow then
				notify(player, string.format("⏱️ ¡Premio por jugar %d minutos listo! Recógelo en 🛒 Tienda", reward.atMinutes), "goal")
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
		Analytics.progress(player, "Rascacielos", floors, "Planta " .. floors)
		if floors >= 3 then
			Analytics.onboarding(player, data, "floor3")
		end
	end
	-- Primeros minutos (embudo) e insignias
	local played = now - session.joinedAt
	if played >= 300 then
		Analytics.onboarding(player, data, "min5")
	end
	if played >= 900 then
		Analytics.onboarding(player, data, "min15")
	end
	if played >= 1800 then
		Analytics.onboarding(player, data, "min30")
	end
	if now >= session.badgeCheckAt then
		session.badgeCheckAt = now + Config.BADGE_CHECK_INTERVAL
		BadgeAwards.check(player, data)
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
	gain(data, session.income * dt, "ingresos")
	-- Lo máximo que puedes invertir en Bolsa depende de tus mejores ingresos
	-- (sin boosts temporales ni el x2 del fin de semana: si no, un boost lo
	-- subiría para siempre)
	local bonuses = session.bonuses
	local boost, weekendBonus = bonuses.boost, bonuses.weekend
	bonuses.boost, bonuses.weekend = false, nil
	data.peakIncome = math.max(data.peakIncome, computeIncome(session, false))
	bonuses.boost, bonuses.weekend = boost, weekendBonus
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

-- Bucle de la economía: una vez por segundo
local lastTick = os.clock()

while true do
	task.wait(1)
	local now = os.clock()
	local dt = math.min(now - lastTick, 5)
	lastTick = now

	local weekendEvent = Config.weekendStatus(os.time())
	local weekendId = if weekendEvent then weekendEvent.id else nil
	for name, step in { eventoServidor = updateServerEvent, metaComun = updateCommunity, bolsa = MarketService.tick } do
		local ok, err = pcall(step, now)
		if not ok then
			reportLoopError(name, err)
		end
	end
	for player, session in sessions do
		local ok, err = pcall(tickPlayer, player, session, now, dt, weekendEvent, weekendId)
		if not ok then
			session.errors += 1
			reportLoopError("el jugador " .. player.Name, err)
		end
	end
end
