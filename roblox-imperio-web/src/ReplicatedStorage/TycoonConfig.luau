--[[
	TycoonConfig (ModuleScript en ReplicatedStorage)

	Todos los datos del juego (tipos de web, apps de anuncios, empresas,
	objetivos...) y las fórmulas de economía. Lo usan el servidor (que es
	quien manda) y el cliente (para mostrar precios).

	Para equilibrar el juego basta con tocar los números de este archivo.
]]

local Config = {}

---------------------------------------------------------------------
-- Ajustes generales
---------------------------------------------------------------------
Config.DATASTORE_NAME = "ImperioWeb_v1"
Config.AUTOSAVE_INTERVAL = 120 -- segundos
Config.STARTING_MONEY = 25
Config.BASE_SLOTS = 3 -- webs que puedes tener a la vez sin Hosting
Config.OFFLINE_MAX_HOURS = 8
Config.OFFLINE_RATE = 0.5 -- % de los ingresos que ganas estando desconectado
Config.OFFER_COUNT = 4 -- ofertas de clientes visibles a la vez
Config.OFFER_LIFETIME = 90 -- segundos que dura una oferta
Config.QUICK_SALE_MULT = 0.6 -- vender sin cliente paga menos
Config.SALE_SECONDS = 150 -- una empresa paga ~150 s de lo que puede ganar la web
Config.MAINTENANCE_RATE = 0.0002 -- contrato de mantenimiento: % del precio de venta por segundo
Config.MAX_SEO = 10
Config.SEO_VISIT_BONUS = 1.25 -- cada nivel de SEO multiplica las visitas
Config.IPO_MIN_EARNED = 1_000_000 -- dinero ganado en la partida para salir a bolsa
Config.SHARE_BONUS = 0.05 -- +5 % de dinero por cada acción
Config.EVENT_MIN_DELAY = 90
Config.EVENT_MAX_DELAY = 180
Config.CLICK_RATE_LIMIT = 15 -- clics por segundo como máximo

-- Monetización opcional. Crea un Game Pass en el Creator Hub y pon su ID
-- aquí. Con 0 la tienda no aparece.
Config.Monetization = {
	DOUBLE_MONEY_GAMEPASS_ID = 0,
}

---------------------------------------------------------------------
-- Tipos de web que puedes programar
--   work      = trabajo necesario (clics + programadores)
--   cost      = lo que cuesta empezarla (dominio, servidores...)
--   visits    = visitas por segundo base
--   rep       = reputación necesaria para desbloquearla
--   repReward = reputación que ganas al terminarla
---------------------------------------------------------------------
Config.WebTypes = {
	{ id = "landing", name = "Landing Page", emoji = "📄", work = 15, cost = 0, visits = 4, rep = 0, repReward = 1 },
	{ id = "blog", name = "Blog", emoji = "✍️", work = 60, cost = 40, visits = 12, rep = 3, repReward = 3 },
	{ id = "tienda", name = "Tienda Online", emoji = "🛒", work = 250, cost = 300, visits = 36, rep = 30, repReward = 8 },
	{ id = "noticias", name = "Periódico Digital", emoji = "📰", work = 1000, cost = 1500, visits = 110, rep = 200, repReward = 20 },
	{ id = "red_social", name = "Red Social", emoji = "💬", work = 4000, cost = 20000, visits = 330, rep = 1000, repReward = 50 },
	{ id = "streaming", name = "Plataforma de Streaming", emoji = "🎬", work = 16000, cost = 250000, visits = 1000, rep = 4000, repReward = 120 },
	{ id = "app_ia", name = "App de IA", emoji = "🤖", work = 65000, cost = 3000000, visits = 3000, rep = 15000, repReward = 300 },
	{ id = "metaverso", name = "Metaverso", emoji = "🥽", work = 260000, cost = 50000000, visits = 9000, rep = 50000, repReward = 800 },
}

---------------------------------------------------------------------
-- Apps de anuncios
--   rpv     = dinero por visita
--   penalty = % de visitas que se pierden porque molestan
---------------------------------------------------------------------
Config.AdNetworks = {
	{ id = "adsimple", name = "AdSimple", emoji = "🟢", rpv = 0.25, penalty = 0.00, cost = 0, rep = 0 },
	{ id = "clickboom", name = "ClickBoom", emoji = "💥", rpv = 0.45, penalty = 0.08, cost = 2500, rep = 10 },
	{ id = "bannerpro", name = "BannerPro", emoji = "🖼️", rpv = 0.8, penalty = 0.12, cost = 50000, rep = 80 },
	{ id = "videomax", name = "VideoMax", emoji = "📺", rpv = 1.5, penalty = 0.20, cost = 1200000, rep = 600 },
	{ id = "influads", name = "InfluAds", emoji = "🤳", rpv = 2.4, penalty = 0.10, cost = 25000000, rep = 2500 },
	{ id = "premium", name = "PremiumAds Global", emoji = "💎", rpv = 4.0, penalty = 0.06, cost = 600000000, rep = 10000 },
	{ id = "neuroads", name = "NeuroAds IA", emoji = "🧠", rpv = 7.0, penalty = 0.03, cost = 20000000000, rep = 35000 },
}

-- Cuántos anuncios pones en cada web: más anuncios = más dinero por visita,
-- pero menos visitas (y la web vale menos al venderla).
Config.AdLevels = {
	{ name = "Pocos", rev = 1.0, visits = 1.0 },
	{ name = "Normal", rev = 1.7, visits = 0.88 },
	{ name = "Muchos", rev = 2.5, visits = 0.68 },
}

---------------------------------------------------------------------
-- Empresas que puedes fundar y mejorar
--   income = dinero por segundo por cada nivel
--   growth = cuánto sube el precio en cada nivel
---------------------------------------------------------------------
Config.Companies = {
	{ id = "devs", name = "Equipo de Programadores", emoji = "👩‍💻", baseCost = 50, growth = 1.15, income = 0, maxLevel = 200,
		desc = "+1.5 de trabajo por segundo por nivel: programan por ti." },
	{ id = "hosting", name = "Hosting Nube", emoji = "☁️", baseCost = 300, growth = 1.75, income = 2, maxLevel = 40,
		desc = "+1 hueco para tener más webs a la vez." },
	{ id = "marketing", name = "Agencia de Marketing", emoji = "📣", baseCost = 1000, growth = 1.32, income = 5, maxLevel = 200,
		desc = "+10 % de visitas en todas tus webs." },
	{ id = "design", name = "Estudio de Diseño", emoji = "🎨", baseCost = 4000, growth = 1.33, income = 15, maxLevel = 200,
		desc = "+8 % de calidad en las webs nuevas." },
	{ id = "comercial", name = "Agencia Comercial", emoji = "🤝", baseCost = 10000, growth = 1.38, income = 40, maxLevel = 200,
		desc = "+12 % al vender webs y clientes que pagan más." },
	{ id = "ia_lab", name = "Laboratorio de IA", emoji = "🧪", baseCost = 75000, growth = 1.45, income = 150, maxLevel = 200,
		desc = "+25 % de velocidad programando. Nivel 1 activa el modo automático." },
	{ id = "adnet", name = "Red de Anuncios Propia", emoji = "📡", baseCost = 1000000, growth = 1.45, income = 1000, maxLevel = 200,
		desc = "+15 % de dinero por anuncios." },
	{ id = "datacenter", name = "Centro de Datos", emoji = "🏭", baseCost = 25000000, growth = 1.5, income = 20000, maxLevel = 200,
		desc = "+5 % a todo el dinero y tus webs no se caen." },
}

---------------------------------------------------------------------
-- Objetivos (dan dinero la primera vez que los cumples)
---------------------------------------------------------------------
local function totalCompanyLevels(data): number
	local total = 0
	for _, level in data.companies do
		total += level
	end
	return total
end

local function countKeys(t): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function hasType(data, typeId: string): boolean
	for _, site in data.sites do
		if site.type == typeId then
			return true
		end
	end
	return false
end

Config.Goals = {
	{ id = "first_site", text = "Programa tu primera web", reward = 50, check = function(d) return d.stats.built >= 1 end },
	{ id = "earn_1k", text = "Gana $1K en total", reward = 200, check = function(d) return d.totalEarned >= 1000 end },
	{ id = "sell_1", text = "Vende una web a una empresa", reward = 300, check = function(d) return d.stats.sold >= 1 end },
	{ id = "company_1", text = "Funda tu primera empresa", reward = 500, check = function(d) return totalCompanyLevels(d) >= 1 end },
	{ id = "network_2", text = "Desbloquea una segunda app de anuncios", reward = 1500, check = function(d) return countKeys(d.unlockedAds) >= 2 end },
	{ id = "sites_5", text = "Ten 5 webs a la vez", reward = 3000, check = function(d) return #d.sites >= 5 end },
	{ id = "sell_10", text = "Vende 10 webs", reward = 10000, check = function(d) return d.stats.sold >= 10 end },
	{ id = "earn_100k", text = "Gana $100K en total", reward = 20000, check = function(d) return d.totalEarned >= 100000 end },
	{ id = "red_social", text = "Crea una Red Social", reward = 50000, check = function(d) return hasType(d, "red_social") end },
	{ id = "companies_25", text = "Suma 25 niveles de empresas", reward = 100000, check = function(d) return totalCompanyLevels(d) >= 25 end },
	{ id = "earn_1m", text = "Gana $1M en total", reward = 250000, check = function(d) return d.totalEarned >= 1000000 end },
	{ id = "ipo_1", text = "Sal a bolsa por primera vez", reward = 0, check = function(d) return d.ipoCount >= 1 end },
	{ id = "metaverso", text = "Crea un Metaverso", reward = 5000000, check = function(d) return hasType(d, "metaverso") end },
}

---------------------------------------------------------------------
-- Clientes y eventos
---------------------------------------------------------------------
Config.ClientNames = {
	"Panadería La Espiga", "Zapatos Veloz", "Clínica Sonrisa", "TecnoMarket", "Club Deportivo Olimpo",
	"Pizzería Napoli", "Viajes Horizonte", "Banco Cobre", "Moda Urbana", "Gimnasio Titán",
	"Editorial Pluma", "Estudio Pixel", "Inmobiliaria Faro", "Cafetería Aroma", "Juguetes Kiko",
	"Fintech Nube", "Hotel Brisa", "Academia Sigma", "Floristería Lila", "Motores Rayo",
}

Config.SiteNameParts = {
	first = { "Super", "Mega", "Ultra", "Pixel", "Nova", "Turbo", "Happy", "Cyber", "Eco", "Smart", "Hiper", "Top" },
	second = { "Web", "Zone", "Hub", "Lab", "Spot", "World", "Net", "Place", "Point", "Store", "Click", "Wave" },
	tld = { ".com", ".es", ".net", ".io", ".app" },
}

-- Eventos aleatorios. weight = probabilidad relativa.
Config.Events = {
	{ id = "viral", name = "🔥 ¡Una de tus webs se ha hecho viral! x5 visitas", duration = 45, weight = 3 },
	{ id = "algoritmo", name = "🔎 El buscador te favorece: x1.5 visitas", duration = 60, weight = 2 },
	{ id = "caida", name = "⚠️ Caída de servidores: visitas a la mitad", duration = 30, weight = 1 },
	{ id = "inversor", name = "💼 Un inversor cree en ti y te da dinero", duration = 0, weight = 2 },
	{ id = "vip", name = "👑 ¡Ha llegado un cliente VIP que paga x3.5!", duration = 0, weight = 2 },
}

---------------------------------------------------------------------
-- Búsquedas rápidas por id
---------------------------------------------------------------------
local function index(list)
	local map = {}
	for i, item in list do
		item.order = i
		map[item.id] = item
	end
	return map
end

Config.WebTypeById = index(Config.WebTypes)
Config.AdNetworkById = index(Config.AdNetworks)
Config.CompanyById = index(Config.Companies)

---------------------------------------------------------------------
-- Fórmulas (iguales en servidor y cliente)
---------------------------------------------------------------------
function Config.level(data, companyId: string): number
	return data.companies[companyId] or 0
end

function Config.companyCost(companyId: string, level: number): number
	local def = Config.CompanyById[companyId]
	return math.floor(def.baseCost * def.growth ^ level)
end

function Config.slots(data): number
	return Config.BASE_SLOTS + Config.level(data, "hosting")
end

function Config.workPerSec(data): number
	return Config.level(data, "devs") * 1.5 * (1 + 0.25 * Config.level(data, "ia_lab"))
end

function Config.clickPower(data): number
	return (1 + Config.workPerSec(data) * 0.15) * (1 + 0.25 * Config.level(data, "ia_lab"))
end

-- Multiplicador global de dinero (acciones, game pass, centro de datos)
function Config.moneyMult(data, hasPass: boolean?): number
	local mult = 1 + data.shares * Config.SHARE_BONUS
	mult *= 1 + 0.05 * Config.level(data, "datacenter")
	if hasPass then
		mult *= 2
	end
	return mult
end

function Config.siteVisits(data, site, eventMult: number?): number
	local def = Config.WebTypeById[site.type]
	local network = Config.AdNetworkById[site.network] or Config.AdNetworks[1]
	local adLevel = Config.AdLevels[site.adLevel] or Config.AdLevels[1]
	local visits = def.visits * site.quality
	visits *= Config.SEO_VISIT_BONUS ^ site.seo
	visits *= 1 + 0.10 * Config.level(data, "marketing")
	visits *= adLevel.visits * (1 - network.penalty)
	return visits * (eventMult or 1)
end

function Config.siteIncome(data, site, visits: number, moneyMult: number): number
	local network = Config.AdNetworkById[site.network] or Config.AdNetworks[1]
	local adLevel = Config.AdLevels[site.adLevel] or Config.AdLevels[1]
	local adBonus = 1 + 0.15 * Config.level(data, "adnet")
	return visits * network.rpv * adLevel.rev * adBonus * moneyMult
end

-- La mejor app de anuncios desbloqueada: las empresas valoran tu web
-- según lo que podrían ganar con ella.
function Config.bestRpv(data): number
	local best = Config.AdNetworks[1].rpv
	for id in data.unlockedAds do
		local network = Config.AdNetworkById[id]
		if network and network.rpv > best then
			best = network.rpv
		end
	end
	return best
end

-- Precio de venta de una web (sin multiplicador de cliente)
function Config.saleBase(data, site, moneyMult: number): number
	local visits = Config.siteVisits(data, site, 1)
	local commercial = 1 + 0.12 * Config.level(data, "comercial")
	return visits * Config.SALE_SECONDS * Config.bestRpv(data) * commercial * moneyMult
end

function Config.seoCost(site): number
	local def = Config.WebTypeById[site.type]
	return math.floor((def.cost + 50) * 3 * 2.1 ^ site.seo)
end

function Config.companiesIncome(data, moneyMult: number): number
	local total = 0
	for _, def in Config.Companies do
		total += def.income * Config.level(data, def.id)
	end
	return total * moneyMult
end

function Config.sharesForIpo(totalEarned: number): number
	if totalEarned < Config.IPO_MIN_EARNED then
		return 0
	end
	return math.floor(10 * math.sqrt(totalEarned / Config.IPO_MIN_EARNED))
end

---------------------------------------------------------------------
-- Formato de números: 1.25K, 3.4M, 7B...
---------------------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.formatNumber(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "∞"
	end
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n < 1000 then
		if n < 10 and n % 1 ~= 0 then
			return sign .. string.format("%.2f", n)
		elseif n < 100 and n % 1 ~= 0 then
			return sign .. string.format("%.1f", n)
		end
		return sign .. tostring(math.floor(n))
	end
	local i = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local value = n / 10 ^ (i * 3)
	local pattern = if value < 10 then "%.2f%s" elseif value < 100 then "%.1f%s" else "%.0f%s"
	return sign .. string.format(pattern, value, SUFFIXES[i + 1])
end

function Config.formatMoney(n: number): string
	return "$" .. Config.formatNumber(n)
end

function Config.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
end

return Config
