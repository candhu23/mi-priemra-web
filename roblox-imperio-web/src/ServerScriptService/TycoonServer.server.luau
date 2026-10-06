--[[
	TycoonServer (Script en ServerScriptService)

	El servidor manda: guarda el dinero, calcula ingresos cada segundo y
	comprueba cada acción que pide el jugador (así nadie puede hacer
	trampas desde su ordenador).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local PlotManager = require(ServerScriptService:WaitForChild("PlotManager"))

local random = Random.new()

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
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[ImperioWeb] DataStore no disponible, no se guardará la partida:", result)
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
		stats = { built = 0, sold = 0, clicks = 0 },
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
type Offer = { id: number, company: string, type: string, mult: number, expiresAt: number }
type ActiveEvent = { id: string, name: string, endsAt: number, siteId: number? }
type Session = {
	data: any,
	canSave: boolean,
	hasPass: boolean,
	offers: { Offer },
	nextOfferId: number,
	event: ActiveEvent?,
	nextEventAt: number,
	income: number,
	clickWindowStart: number,
	clickCount: number,
	actionWindowStart: number,
	actionCount: number,
	leaderMoney: IntValue,
	leaderShares: IntValue,
}

local sessions: { [Player]: Session } = {}

local function notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

local function gain(data, amount: number)
	if amount <= 0 or amount ~= amount then
		return
	end
	data.money += amount
	data.totalEarned += amount
	data.lifetimeEarned += amount
end

local function findSite(data, siteId: number)
	for i, site in data.sites do
		if site.id == siteId then
			return site, i
		end
	end
	return nil, nil
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
	local moneyMult = Config.moneyMult(data, session.hasPass)
	local total = 0
	for _, site in data.sites do
		local mult = if withEvents then eventVisitMult(session, site) else 1
		total += Config.siteIncome(data, site, Config.siteVisits(data, site, mult), moneyMult)
	end
	total += Config.companiesIncome(data, moneyMult)
	total += data.maintenance
	return total
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
	session.nextOfferId += 1
	return {
		id = session.nextOfferId,
		company = Config.ClientNames[random:NextInteger(1, #Config.ClientNames)],
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

---------------------------------------------------------------------
-- Proyectos (webs en construcción)
---------------------------------------------------------------------
local function canStartProject(data, def): (boolean, string?)
	if data.project then
		return false, "Ya estás programando una web."
	end
	if data.reputation < def.rep then
		return false, "Necesitas " .. def.rep .. " de reputación."
	end
	if #data.sites >= Config.slots(data) then
		return false, "No te quedan huecos. Vende una web o mejora el Hosting."
	end
	if data.money < def.cost then
		return false, "No tienes suficiente dinero."
	end
	return true, nil
end

local function startProject(data, def)
	data.money -= def.cost
	data.project = { type = def.id, progress = 0, required = def.work }
end

local function finishProject(player: Player, session: Session)
	local data = session.data
	local project = data.project
	if not project then
		return
	end
	local def = Config.WebTypeById[project.type]
	data.project = nil

	local quality = (0.85 + random:NextNumber() * 0.3) * (1 + 0.08 * Config.level(data, "design"))
	local site = {
		id = data.nextSiteId,
		type = def.id,
		name = randomSiteName(),
		quality = math.floor(quality * 100) / 100,
		seo = 0,
		network = "adsimple",
		adLevel = 1,
	}
	-- Usa automáticamente la mejor app de anuncios desbloqueada
	local bestRpv = 0
	for id in data.unlockedAds do
		local network = Config.AdNetworkById[id]
		if network and network.rpv * (1 - network.penalty) > bestRpv then
			bestRpv = network.rpv * (1 - network.penalty)
			site.network = id
		end
	end
	data.nextSiteId += 1
	table.insert(data.sites, site)
	data.stats.built += 1
	data.reputation += def.repReward

	if not data.autoType then
		notify(player, string.format("%s ¡%s terminada! Calidad %d%%", def.emoji, site.name, math.floor(site.quality * 100)), "success")
	end

	-- Modo automático del Laboratorio de IA
	if data.autoType and Config.level(data, "ia_lab") >= 1 then
		local autoDef = Config.WebTypeById[data.autoType]
		if autoDef and canStartProject(data, autoDef) then
			startProject(data, autoDef)
		end
	end
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
-- Objetivos y rascacielos
---------------------------------------------------------------------
local function checkGoals(player: Player, session: Session)
	local data = session.data
	for _, goal in Config.Goals do
		if not data.goals[goal.id] and goal.check(data) then
			data.goals[goal.id] = true
			if goal.reward > 0 then
				data.money += goal.reward
			end
			notify(player, "🎯 Objetivo cumplido: " .. goal.text .. (if goal.reward > 0 then " (+" .. Config.formatMoney(goal.reward) .. ")" else ""), "goal")
		end
	end
end

local function updateBuilding(player: Player, session: Session)
	local data = session.data
	local companyLevels = 0
	for _, level in data.companies do
		companyLevels += level
	end
	local floors = 1 + #data.sites + companyLevels // 3 + data.ipoCount * 2
	PlotManager.setFloors(player, floors)
end

---------------------------------------------------------------------
-- Estado que se envía al cliente
---------------------------------------------------------------------
local function buildState(session: Session)
	local data = session.data
	local moneyMult = Config.moneyMult(data, session.hasPass)
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
			viral = session.event ~= nil and session.event.id == "viral" and session.event.siteId == site.id,
		})
	end

	local offers = {}
	for _, offer in session.offers do
		table.insert(offers, {
			id = offer.id,
			company = offer.company,
			type = offer.type,
			mult = offer.mult,
			timeLeft = offer.expiresAt - now,
		})
	end

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
		slots = Config.slots(data),
		workPerSec = Config.workPerSec(data),
		clickPower = Config.clickPower(data),
		moneyMult = moneyMult,
		hasPass = session.hasPass,
		project = data.project,
		autoType = data.autoType,
		sites = sites,
		companies = data.companies,
		unlockedAds = data.unlockedAds,
		offers = offers,
		event = if session.event then { name = session.event.name, timeLeft = session.event.endsAt - now } else nil,
		goals = data.goals,
		stats = data.stats,
		canSave = session.canSave,
	}
end

local function sendState(player: Player)
	local session = sessions[player]
	if session then
		session.leaderMoney.Value = math.clamp(math.floor(session.data.money), 0, 9e18)
		session.leaderShares.Value = session.data.shares
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
		notify(player, chosen.name .. ": +" .. Config.formatMoney(amount), "event")
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
	if not session.data.project then
		return false, "Primero elige una web para programar."
	end
	session.data.stats.clicks += 1
	addWork(player, session, Config.clickPower(session.data))
	return true, nil
end

function Actions.startProject(_player: Player, session: Session, typeId: any)
	local def = Config.WebTypeById[typeId]
	if not def then
		return false, "Tipo de web desconocido."
	end
	local ok, reason = canStartProject(session.data, def)
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
	if canStartProject(data, def) then
		startProject(data, def)
	end
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
		return false, "Necesitas " .. network.rep .. " de reputación."
	end
	if data.money < network.cost then
		return false, "No tienes suficiente dinero."
	end
	data.money -= network.cost
	data.unlockedAds[networkId] = true
	return true, network.emoji .. " " .. network.name .. " desbloqueada. ¡Pónsela a tus webs!"
end

function Actions.buyCompany(player: Player, session: Session, companyId: any)
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
	updateBuilding(player, session)
	if level == 0 then
		return true, def.emoji .. " ¡Has fundado " .. def.name .. "!"
	end
	return true, nil
end

local function sellSite(player: Player, session: Session, siteId: number, mult: number, buyer: string): (boolean, string?)
	local data = session.data
	local site, siteIndex = findSite(data, siteId)
	if not site or not siteIndex then
		return false, nil
	end
	local def = Config.WebTypeById[site.type]
	local price = Config.saleBase(data, site, Config.moneyMult(data, session.hasPass)) * mult
	table.remove(data.sites, siteIndex)
	gain(data, price)
	data.maintenance += price * Config.MAINTENANCE_RATE
	data.reputation += def.repReward
	data.stats.sold += 1
	if session.event and session.event.siteId == siteId then
		session.event = nil
	end
	updateBuilding(player, session)
	return true, string.format("🤝 Vendiste %s a %s por %s", site.name, buyer, Config.formatMoney(price))
end

function Actions.sellToOffer(player: Player, session: Session, offerId: any, siteId: any)
	for i, offer in session.offers do
		if offer.id == offerId then
			local site = findSite(session.data, siteId)
			if not site or site.type ~= offer.type then
				return false, "Esa empresa quiere otro tipo de web."
			end
			table.remove(session.offers, i)
			local ok, message = sellSite(player, session, siteId, offer.mult, offer.company)
			refreshOffers(session)
			return ok, message
		end
	end
	return false, "La oferta ya no está disponible."
end

function Actions.quickSell(player: Player, session: Session, siteId: any)
	return sellSite(player, session, siteId, Config.QUICK_SALE_MULT, "un comprador anónimo")
end

function Actions.ipo(player: Player, session: Session)
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
	updateBuilding(player, session)
	return true, string.format("📈 ¡Saliste a bolsa! +%d acciones (+%d%% de dinero para siempre)", newShares, math.floor(newShares * Config.SHARE_BONUS * 100))
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

	local ok, message = handler(player, session, a, b)
	if ok then
		checkGoals(player, session)
		session.income = computeIncome(session, true)
		sendState(player)
	end
	return ok, message
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

local function saveData(player: Player, session: Session)
	if not session.canSave or not store then
		return
	end
	session.data.lastOnline = os.time()
	pendingSaves += 1
	local ok, err = pcall(function()
		store:UpdateAsync(dataKey(player), function()
			return session.data
		end)
	end)
	pendingSaves -= 1
	if not ok then
		warn("[ImperioWeb] Error guardando datos de " .. player.Name .. ":", err)
	end
end

local function spawnAtPlot(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart")
	task.wait()
	character:PivotTo(PlotManager.getSpawnCFrame(player))
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
	leaderstats.Parent = player

	local hasPass = false
	local passId = Config.Monetization.DOUBLE_MONEY_GAMEPASS_ID
	if passId ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		hasPass = ok and owns == true
	end

	local session: Session = {
		data = data,
		canSave = canSave,
		hasPass = hasPass,
		offers = {},
		nextOfferId = 0,
		event = nil,
		nextEventAt = os.clock() + 60,
		income = 0,
		clickWindowStart = 0,
		clickCount = 0,
		actionWindowStart = 0,
		actionCount = 0,
		leaderMoney = leaderMoney,
		leaderShares = leaderShares,
	}
	sessions[player] = session

	refreshOffers(session)
	session.income = computeIncome(session, false)

	-- Ganancias mientras estabas desconectado
	local away = math.clamp(os.time() - (data.lastOnline or os.time()), 0, Config.OFFLINE_MAX_HOURS * 3600)
	if away >= 60 and session.income > 0 then
		local earned = session.income * away * Config.OFFLINE_RATE
		gain(data, earned)
		task.delay(3, function()
			notify(player, "😴 Mientras no estabas (" .. Config.formatTime(away) .. ") ganaste " .. Config.formatMoney(earned), "success")
		end)
	end

	if not canSave then
		task.delay(4, function()
			notify(player, "⚠️ No se pudo conectar con el guardado: esta partida no se guardará.", "error")
		end)
	end

	PlotManager.claim(player)
	updateBuilding(player, session)

	player.CharacterAdded:Connect(function(character)
		spawnAtPlot(player, character)
	end)
	if player.Character then
		task.spawn(spawnAtPlot, player, player.Character)
	end

	sendState(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	-- Se quita primero para que el bucle de economía deje de tocarlo
	sessions[player] = nil
	PlotManager.release(player)
	if session then
		saveData(player, session)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Config.Monetization.DOUBLE_MONEY_GAMEPASS_ID then
		local session = sessions[player]
		if session then
			session.hasPass = true
			notify(player, "💎 ¡Gracias! Ahora ganas el doble de dinero.", "success")
		end
	end
end)

---------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------
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

		session.income = computeIncome(session, true)
		gain(data, session.income * dt)

		local workPerSec = Config.workPerSec(data)
		if workPerSec > 0 then
			addWork(player, session, workPerSec * dt)
		end
		-- Si el modo automático se quedó parado (sin dinero o huecos), reintenta
		if not data.project and data.autoType and Config.level(data, "ia_lab") >= 1 then
			local autoDef = Config.WebTypeById[data.autoType]
			if autoDef and canStartProject(data, autoDef) then
				startProject(data, autoDef)
			end
		end

		refreshOffers(session)
		checkGoals(player, session)
		updateBuilding(player, session)
		sendState(player)
	end
end
