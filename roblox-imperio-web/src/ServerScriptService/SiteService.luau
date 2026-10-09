--[[
	SiteService (ModuleScript en ServerScriptService)

	Producción y ventas: webs (programar, terminar, SEO, diseño, anuncios),
	ofertas de clientes, negociaciones, empresas, Bolsa y salir a bolsa.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local Validate = require(ReplicatedStorage:WaitForChild("Validate"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))
local Analytics = require(ServerScriptService:WaitForChild("Analytics"))
local MarketService = require(ServerScriptService:WaitForChild("MarketService"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local SaveService = require(ServerScriptService:WaitForChild("SaveService"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))

local findSite = ServerState.findSite
local gain = ServerState.gain
local spend = ServerState.spend
local notify = ServerState.notify
local random = ServerState.random
local serverEventIs = ServerState.serverEventIs
local sessions = ServerState.sessions
type Offer = ServerState.Offer
type Session = ServerState.Session
local newData = SaveService.newData
local addSeasonXp = RewardService.addSeasonXp
local progressDaily = RewardService.progressDaily
local progressDailyMax = RewardService.progressDailyMax

local SiteService = {}
local Actions = {}

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
	spend(data, def.cost, "webs")
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
	session.dirty = true -- web nueva: que el cliente la vea pronto

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
	Analytics.onboarding(player, data, "firstSite")

	if variant then
		progressDaily(session, "rares", 1)
		Analytics.event(player, "WebRara", variant.mult, { variante = variant.id, tipo = def.id })
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

function Actions.startProject(player: Player, session: Session, typeId: any)
	local def = Config.WebTypeById[typeId]
	if not def then
		return false, "Tipo de web desconocido."
	end
	local ok, reason = canStartProject(session, def)
	if not ok then
		return false, reason
	end
	startProject(session.data, def)
	Analytics.onboarding(player, session.data, "firstProject")
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
	spend(data, cost, "webs")
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
	if not site or not Validate.integer(level, 1, #Config.AdLevels) then
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
	spend(data, network.cost, "anuncios")
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
	spend(data, cost, "empresas")
	data.companies[def.id] = level + count
	progressDaily(session, "companies", count - 1) -- (la acción ya cuenta 1)
	local milestonesBefore = Config.milestonesReached(level)
	if Config.milestonesReached(level + count) > milestonesBefore then
		notify(player, string.format("🏅 ¡Hito! %s %s nivel %d: produce x%.1f", def.emoji, def.name, level + count, Config.companyMult(data, def.id)), "goal")
	end
	if level == 0 then
		Analytics.onboarding(player, data, "firstCompany")
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
	gain(data, price, "ventas")
	data.maintenance += price * Config.MAINTENANCE_RATE
	data.reputation += def.repReward
	data.stats.sold += 1
	progressDaily(session, "sold", 1)
	addSeasonXp(player, session, Config.SeasonXp.sale)
	Analytics.onboarding(player, data, "firstSale")
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

-- Lo que cobrarías ya por las negociaciones en curso (para la confirmación)
local function pendingDeals(data): (number, number)
	local count, total = 0, 0
	for _, site in data.sites do
		if site.deal then
			count += 1
			total += site.deal.price
		end
	end
	return count, total
end

function Actions.ipo(player: Player, session: Session)
	local data = session.data
	-- Las ventas que se estaban negociando se cobran ya (y cuentan para las acciones)
	local dealCount, dealTotal = pendingDeals(data)
	if Config.sharesForIpo(data.totalEarned + dealTotal) < 1 then
		return false, "Necesitas ganar " .. Config.formatMoney(Config.IPO_MIN_EARNED) .. " en esta partida."
	end
	for i = #data.sites, 1, -1 do
		local site = data.sites[i]
		if site.deal then
			completeSale(player, session, site, site.deal.price)
		end
	end
	local newShares = Config.sharesForIpo(data.totalEarned)
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
	if dealCount > 0 then
		notify(player, string.format("🤝 Se cerraron %d ventas que estabas negociando: +%s", dealCount, Config.formatMoney(dealTotal)), "money")
	end
	Analytics.progress(player, "SalidasABolsa", data.ipoCount, "Salida " .. data.ipoCount)
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
	spend(data, cost, "webs")
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

SiteService.activeDeals = activeDeals
SiteService.addWork = addWork
SiteService.canStartProject = canStartProject
SiteService.completeSale = completeSale
SiteService.finishDeals = finishDeals
SiteService.finishProject = finishProject
SiteService.makeOffer = makeOffer
SiteService.pendingDeals = pendingDeals
SiteService.randomSiteName = randomSiteName
SiteService.refreshOffers = refreshOffers
SiteService.salePrice = salePrice
SiteService.startProject = startProject
SiteService.tryAutoStart = tryAutoStart
SiteService.unlockedTypes = unlockedTypes
SiteService.Actions = Actions

return SiteService
