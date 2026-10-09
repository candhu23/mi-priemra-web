--[[
	TycoonConfig (ModuleScript en ReplicatedStorage)

	Todos los datos del juego (tipos de web, apps de anuncios, empresas,
	objetivos, tienda...) y las fórmulas de economía. Lo usan el servidor
	(que es quien manda) y el cliente (para mostrar precios y progreso).

	Para equilibrar el juego basta con tocar los números de este archivo.
]]

local Config = {}

Config.VERSION = "4.0-alpha.1"

---------------------------------------------------------------------
-- Ajustes generales
---------------------------------------------------------------------
Config.DATASTORE_NAME = "ImperioWeb_v1"
Config.DATA_VERSION = 4 -- versión de la partida guardada (migrate() en el servidor)
-- Bloqueo de sesión: la partida guarda qué servidor la tiene abierta. Se
-- renueva en cada guardado (cada minuto). Si otro servidor la tiene y su
-- bloqueo es reciente, se reintenta LOCK_RETRIES veces cada LOCK_RETRY_WAIT s;
-- si sigue, no se carga (se avisa al jugador). Un bloqueo sin renovar desde
-- hace SESSION_LOCK_STALE s es de un servidor caído y se puede quitar.
Config.SESSION_LOCK_STALE = 300
Config.LOCK_RETRIES = 6
Config.LOCK_RETRY_WAIT = 5
Config.LEADERBOARD_NAME = "ImperioWebTop_v1"
Config.AUTOSAVE_INTERVAL = 60 -- segundos
Config.STATE_MIN_INTERVAL = 0.25 -- como mucho 4 envíos de estado por segundo y jugador
Config.MANUAL_SAVE_COOLDOWN = 30 -- segundos entre guardados manuales
Config.LEADERBOARD_REFRESH = 120 -- segundos
Config.STARTING_MONEY = 25
Config.BASE_SLOTS = 3 -- webs que puedes tener a la vez sin Hosting
Config.OFFLINE_MAX_HOURS = 8
Config.OFFLINE_RATE = 0.35 -- % de los ingresos que ganas estando desconectado
Config.OFFER_COUNT = 3 -- ofertas de clientes visibles a la vez (como máximo)
Config.OFFER_LIFETIME = 90 -- segundos que dura una oferta
Config.OFFER_INTERVAL = 45 -- segundos entre ofertas nuevas (antes salían al momento)
Config.QUICK_SALE_MULT = 0.5 -- vender sin cliente paga menos...
Config.QUICK_SALE_COOLDOWN = 90 -- ...y solo se puede cada 90 s
Config.SALE_SECONDS = 130 -- una empresa paga ~130 s de lo que puede ganar la web
-- Las ventas a clientes no son instantáneas: hay que negociar. Segundos por
-- tipo de web (la Agencia Comercial lo acorta un 3 % por nivel, hasta la mitad)
Config.DealSeconds = { landing = 60, blog = 90, tienda = 150, noticias = 240, red_social = 360, streaming = 480, app_ia = 600, metaverso = 900 }
Config.MAX_DEALS = 2 -- negociaciones a la vez (+1 cada 15 niveles de Agencia Comercial, máx. 4)
Config.MAINTENANCE_RATE = 0.0002 -- contrato de mantenimiento: % del precio de venta por segundo
Config.MAX_SEO = 10
Config.MAX_DESIGN = 5
Config.DESIGN_QUALITY_BONUS = 0.10 -- cada nivel de rediseño: +10 % de calidad
Config.SEO_VISIT_BONUS = 1.25 -- cada nivel de SEO multiplica las visitas
Config.IPO_MIN_EARNED = 1_000_000 -- dinero ganado en la partida para salir a bolsa
Config.SHARE_BONUS = 0.05 -- +5 % de dinero por cada acción
Config.EVENT_MIN_DELAY = 90
Config.EVENT_MAX_DELAY = 180
Config.CLICK_RATE_LIMIT = 15 -- clics por segundo como máximo
Config.CRIT_CHANCE = 0.06 -- probabilidad de clic crítico
Config.CRIT_MULT = 5
Config.GOAL_REWARD_SCALE = 0.2 -- premios de los objetivos (1 = como en la v1)
Config.REWARD_SCALE = 0.6 -- TODAS las recompensas gratis en minutos de ingresos (diaria, regalo,
-- misiones, tiempo jugado, me gusta, meta común, pase, códigos, ranking...). Las compras con Robux no.
Config.TUTORIAL_REWARD = 100 -- premio por terminar el tutorial
Config.GIFT_INTERVAL = 600 -- un regalo cada 10 minutos jugando
Config.GIFT_MINUTES = 2 -- el regalo vale 2 minutos de ingresos...
Config.GIFT_MIN = 200 -- ...o como mínimo esto
Config.DAY_LENGTH_MINUTES = 16 -- duración de un día completo en el juego
Config.WALK_SPEED = 22
Config.LIKE_OWNER_MINUTES = 2 -- un "me gusta" da al dueño 2 minutos de ingresos...
Config.LIKE_OWNER_MIN = 100
Config.LIKE_VISITOR_MINUTES = 1 -- ...y al que lo da, 1 minuto
Config.LIKE_VISITOR_MIN = 50
Config.MAX_LIKES_PER_DAY = 20 -- "me gusta" que puedes dar al día
Config.STARTER_HOURS = 72 -- el pack de inicio se ofrece las primeras 72 h

---------------------------------------------------------------------
-- Monetización (Robux). Con id = 0 el artículo no aparece en la tienda.
-- Crea los Game Passes y Developer Products en el Creator Hub y pega
-- aquí sus IDs. El precio en Robux se pone allí, no aquí.
---------------------------------------------------------------------
Config.Monetization = {
	GamePasses = {
		{ key = "pass", id = 2008580363, emoji = "💎", name = "x2 Dinero", desc = "Ganas el doble de dinero para siempre." },
		{ key = "turbo", id = 2009090346, emoji = "⚡", name = "Programador Turbo", desc = "Programas el doble de rápido para siempre." },
		{ key = "slotsPass", id = 2006769799, emoji = "🗄️", name = "+3 Huecos", desc = "Puedes tener 3 webs más a la vez." },
		{ key = "agencyPro", id = 2008664354, emoji = "🏙️", name = "Agencia Pro", desc = "+5 puestos en tu oficina y programadores +25 % mejores." },
		{ key = "xpPass", id = 2006871734, emoji = "🎓", name = "Mentor x2 XP", desc = "Subes de nivel en los nichos el doble de rápido." },
	},
	Products = {
		{ key = "cash_small", id = 0, emoji = "💼", name = "Maletín de dinero", kind = "cash", minutes = 15, min = 1000,
			desc = "15 minutos de tus ingresos al instante." },
		{ key = "cash_big", id = 0, emoji = "🚚", name = "Camión de dinero", kind = "cash", minutes = 120, min = 15000,
			desc = "2 horas de tus ingresos al instante." },
		{ key = "boost", id = 0, emoji = "🚀", name = "Boost x2 (30 min)", kind = "boost", minutes = 30,
			desc = "Todo tu dinero x2 durante 30 minutos." },
		{ key = "finish", id = 0, emoji = "⏩", name = "Terminar web ya", kind = "finish",
			desc = "Termina al instante la web que estás programando." },
		-- random = true: contiene un resultado aleatorio. Se muestran las
		-- probabilidades y se oculta donde Roblox restringe estos artículos.
		{ key = "headhunter", id = 0, emoji = "🎯", name = "Headhunter Premium", kind = "ticket", ticket = "premium", amount = 1, random = true,
			desc = "1 fichaje con probabilidades mejoradas (Raro o mejor)." },
		{ key = "headhunter5", id = 0, emoji = "🎯", name = "Headhunter Premium x5", kind = "ticket", ticket = "premium", amount = 5, random = true,
			desc = "5 fichajes con probabilidades mejoradas (Raro o mejor)." },
		{ key = "legendary", id = 0, emoji = "👑", name = "Contrato Legendario", kind = "ticket", ticket = "legendary", amount = 1,
			desc = "Un programador Legendario del nicho que tú elijas." },
		-- Pack de inicio: solo se ofrece las primeras STARTER_HOURS horas y una vez
		{ key = "starter", id = 0, emoji = "🎁", name = "Pack de inicio", kind = "starter", minutes = 60, min = 10000, boostMinutes = 60,
			desc = "1 h de ingresos + Boost x2 1 h + 1 Contrato Legendario. Solo para nuevos." },
		-- Pase de temporada premium (vale para la temporada en curso)
		{ key = "seasonPremium", id = 0, emoji = "🎫", name = "Pase de temporada Premium", kind = "season",
			desc = "Desbloquea los premios premium de esta temporada (y los ya alcanzados)." },
	},
	GROUP_ID = 0, -- ID de tu grupo de Roblox (0 = desactivado)
	GROUP_BONUS = 0.10,
	PREMIUM_BONUS = 0.10,
	FRIEND_BONUS = 0.10, -- por cada amigo en el mismo servidor
	MAX_FRIENDS = 4,
}

-- Sonidos (v4). PARA PONER LOS TUYOS: en el Creator Hub → Creator Store →
-- Audio busca lo que dice "search", copia el número del sonido (la URL es
-- .../store/asset/NÚMERO/...) y ponlo así: id = "rbxassetid://NÚMERO".
-- Mientras id = "", suena el "ping" de Roblox con otro tono (fallbackSpeed)
-- para que cada sonido se distinga. volume = volumen (0..1).
Config.SOUND_FALLBACK = "rbxasset://sounds/electronicpingshort.wav"
Config.Sounds = {
	click = { id = "", volume = 0.25, fallbackSpeed = 1.6, search = "keyboard click / button click (corto)" },
	crit = { id = "", volume = 0.6, fallbackSpeed = 0.8, search = "punch impact / power hit" },
	success = { id = "", volume = 0.5, fallbackSpeed = 1.0, search = "success notification / pop" },
	money = { id = "", volume = 0.5, fallbackSpeed = 1.25, search = "coins / cash register" },
	error = { id = "", volume = 0.3, fallbackSpeed = 0.5, search = "error buzz / wrong" },
	levelUp = { id = "", volume = 0.55, fallbackSpeed = 1.45, search = "level up / achievement" },
	unlock = { id = "", volume = 0.55, fallbackSpeed = 0.95, search = "unlock chime / door unlock" },
	recruit = { id = "", volume = 0.6, fallbackSpeed = 1.1, search = "fanfare / reveal" },
	rare = { id = "", volume = 0.6, fallbackSpeed = 0.7, search = "magic sparkle / shimmer" },
}
-- Música de fondo (en bucle). Sin id no suena nada. Se cambia sola con el
-- día y la noche del juego. Busca pistas largas y sin derechos de terceros
-- (las de la Creator Store subidas por Roblox o por "Roblox Music").
Config.Music = {
	day = { id = "", volume = 0.25, search = "lofi chill / upbeat electronic loop" },
	night = { id = "", volume = 0.2, search = "synthwave / night city ambient loop" },
}
Config.VOLUME_STEPS = { 1, 0.5, 0 } -- el botón 🔊 va pasando por estos volúmenes

---------------------------------------------------------------------
-- Tipos de web que puedes programar
--   work      = trabajo necesario (clics + programadores)
--   cost      = lo que cuesta empezarla (dominio, servidores...)
--   visits    = visitas por segundo base
--   rep       = reputación necesaria para desbloquearla
--   repReward = reputación que ganas al terminarla
---------------------------------------------------------------------
Config.WebTypes = {
	{ id = "landing", name = "Landing Page", emoji = "📄", work = 23, cost = 0, visits = 4, rep = 0, repReward = 1 },
	{ id = "blog", name = "Blog", emoji = "✍️", work = 94, cost = 40, visits = 12, rep = 6, repReward = 3 },
	{ id = "tienda", name = "Tienda Online", emoji = "🛒", work = 390, cost = 300, visits = 36, rep = 59, repReward = 8 },
	{ id = "noticias", name = "Periódico Digital", emoji = "📰", work = 1560, cost = 1500, visits = 110, rep = 392, repReward = 20 },
	{ id = "red_social", name = "Red Social", emoji = "💬", work = 6240, cost = 20000, visits = 330, rep = 1700, repReward = 50 },
	{ id = "streaming", name = "Plataforma de Streaming", emoji = "🎬", work = 24960, cost = 250000, visits = 1000, rep = 6000, repReward = 120 },
	{ id = "app_ia", name = "App de IA", emoji = "🤖", work = 101400, cost = 3000000, visits = 3000, rep = 20000, repReward = 300 },
	{ id = "metaverso", name = "Metaverso", emoji = "🥽", work = 405600, cost = 50000000, visits = 9000, rep = 65000, repReward = 800 },
}

---------------------------------------------------------------------
-- Apps de anuncios
--   rpv     = dinero por visita
--   penalty = % de visitas que se pierden porque molestan
---------------------------------------------------------------------
Config.AdNetworks = {
	{ id = "adsimple", name = "AdSimple", emoji = "🟢", rpv = 0.15, penalty = 0.00, cost = 0, rep = 0 },
	{ id = "clickboom", name = "ClickBoom", emoji = "💥", rpv = 0.27, penalty = 0.08, cost = 2500, rep = 10 },
	{ id = "bannerpro", name = "BannerPro", emoji = "🖼️", rpv = 0.48, penalty = 0.12, cost = 50000, rep = 80 },
	{ id = "videomax", name = "VideoMax", emoji = "📺", rpv = 0.9, penalty = 0.20, cost = 1200000, rep = 600 },
	{ id = "influads", name = "InfluAds", emoji = "🤳", rpv = 1.44, penalty = 0.10, cost = 25000000, rep = 2500 },
	{ id = "premium", name = "PremiumAds Global", emoji = "💎", rpv = 2.4, penalty = 0.06, cost = 600000000, rep = 10000 },
	{ id = "neuroads", name = "NeuroAds IA", emoji = "🧠", rpv = 4.2, penalty = 0.03, cost = 20000000000, rep = 35000 },
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
	{ id = "devs", name = "Equipo de Programadores", emoji = "👩‍💻", baseCost = 75, growth = 1.15, income = 0.0, maxLevel = 200,
		desc = "+1.5 de trabajo por segundo por nivel: programan por ti." },
	{ id = "hosting", name = "Hosting Nube", emoji = "☁️", baseCost = 450, growth = 1.75, income = 1.2, maxLevel = 40,
		desc = "+1 hueco para tener más webs a la vez." },
	{ id = "marketing", name = "Agencia de Marketing", emoji = "📣", baseCost = 1500, growth = 1.32, income = 3.0, maxLevel = 200,
		desc = "+10 % de visitas en todas tus webs." },
	{ id = "design", name = "Estudio de Diseño", emoji = "🎨", baseCost = 6000, growth = 1.33, income = 9.0, maxLevel = 200,
		desc = "+8 % de calidad en las webs nuevas." },
	{ id = "comercial", name = "Agencia Comercial", emoji = "🤝", baseCost = 15000, growth = 1.38, income = 24.0, maxLevel = 200,
		desc = "+12 % al vender webs y clientes que pagan más." },
	{ id = "ia_lab", name = "Laboratorio de IA", emoji = "🧪", baseCost = 112500, growth = 1.45, income = 90.0, maxLevel = 200,
		desc = "+25 % de velocidad programando. Nivel 1 activa el modo automático." },
	{ id = "adnet", name = "Red de Anuncios Propia", emoji = "📡", baseCost = 1500000, growth = 1.45, income = 600.0, maxLevel = 200,
		desc = "+15 % de dinero por anuncios." },
	{ id = "datacenter", name = "Centro de Datos", emoji = "🏭", baseCost = 37500000, growth = 1.5, income = 12000.0, maxLevel = 200,
		desc = "+5 % a todo el dinero y tus webs no se caen." },
}

---------------------------------------------------------------------
-- Recompensa diaria (racha de 7 días). Vale "minutes" minutos de tus
-- ingresos o, como mínimo, "min".
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Misiones diarias: cada día tocan 6 (2 fáciles, 2 medias y 2
-- difíciles). Completarlas todas da un boost extra.
--   stat    = qué cuenta para la misión
--   amounts = objetivo según la dificultad (fácil, media, difícil)
--   needs   = solo sale si tienes la Carrera ("career") o agencia ("agency")
---------------------------------------------------------------------
Config.DAILY_MISSION_COUNT = 6
Config.DAILY_ALL_BONUS_BOOST_MINUTES = 10
Config.DailyMissionPool = {
	{ id = "built", text = "Programa %d webs", amounts = { 5, 10, 18 } },
	{ id = "sold", text = "Vende %d webs a empresas", amounts = { 2, 4, 7 } },
	{ id = "clicks", text = "Haz %d clics programando", amounts = { 250, 600, 1200 } },
	{ id = "seo", text = "Mejora el SEO %d veces", amounts = { 3, 6, 12 } },
	{ id = "companies", text = "Mejora tus empresas %d veces", amounts = { 5, 12, 25 } },
	{ id = "gifts", text = "Recoge %d regalos gratis", amounts = { 2, 3, 5 } },
	{ id = "contracts", text = "Entrega %d encargos de empresas", amounts = { 1, 2, 4 }, needs = "career" },
	{ id = "recruits", text = "Entrevista a %d programadores", amounts = { 2, 4, 8 }, needs = "agency" },
	{ id = "rares", text = "Consigue %d webs raras", amounts = { 1, 3, 5 } },
	{ id = "playtime", text = "Juega %d minutos", amounts = { 15, 30, 60 } },
	{ id = "combo", text = "Haz un combo de %d clics", amounts = { 20, 35, 50 } },
}
Config.DailyMissionRewards = {
	{ name = "Fácil", minutes = 1.5, min = 100 },
	{ name = "Media", minutes = 3, min = 250 },
	{ name = "Difícil", minutes = 5, min = 600 },
}
Config.DailyMissionById = {}
for _, mission in Config.DailyMissionPool do
	Config.DailyMissionById[mission.id] = mission
end

---------------------------------------------------------------------
-- Misiones semanales: 6 por semana (se renuevan el lunes 00:00 UTC),
-- bastante difíciles. Cuentan lo mismo que las diarias. Completar las 6
-- da patentes y un boost.
---------------------------------------------------------------------
Config.WEEKLY_MISSION_COUNT = 6
Config.WeeklyMissionPool = {
	{ id = "built", text = "Programa %d webs esta semana", amount = 150 },
	{ id = "sold", text = "Vende %d webs a empresas esta semana", amount = 60 },
	{ id = "clicks", text = "Haz %d clics programando esta semana", amount = 15000 },
	{ id = "seo", text = "Mejora el SEO %d veces esta semana", amount = 90 },
	{ id = "companies", text = "Mejora tus empresas %d veces esta semana", amount = 300 },
	{ id = "rares", text = "Consigue %d webs raras esta semana", amount = 30 },
	{ id = "playtime", text = "Juega %d minutos esta semana", amount = 420 },
	{ id = "missions", text = "Completa %d misiones diarias esta semana", amount = 30 },
	{ id = "contracts", text = "Entrega %d encargos de empresas esta semana", amount = 35, needs = "career" },
	{ id = "recruits", text = "Entrevista a %d programadores esta semana", amount = 40, needs = "agency" },
}
Config.WeeklyMissionReward = { minutes = 20, min = 5000, seasonXp = 150 }
Config.WEEKLY_ALL_PATENTS = 2
Config.WEEKLY_ALL_BOOST_MINUTES = 30
Config.WeeklyMissionById = {}
for _, mission in Config.WeeklyMissionPool do
	Config.WeeklyMissionById[mission.id] = mission
end

---------------------------------------------------------------------
-- Logros: tienen varios niveles (🥉 → 💎) y cada nivel da un bonus
-- PERMANENTE. No se pierden nunca. value(d) = progreso actual.
--   bonus = qué mejora: money (todo el dinero), click (trabajo por clic),
--           visits, sale (precio de venta), work (trabajo/s), rare
--           (probabilidad de webs raras). per = cuánto por nivel.
---------------------------------------------------------------------
Config.ACHIEVEMENT_TIER_EMOJIS = { "🥉", "🥈", "🥇", "🏆", "💎" }
Config.Achievements = {
	{ id = "builder", emoji = "⌨️", name = "Programador incansable", text = "Webs programadas", tiers = { 25, 150, 600, 2500, 10000 },
		bonus = "click", per = 0.05, value = function(d) return d.stats.built or 0 end },
	{ id = "seller", emoji = "🤝", name = "Gran vendedor", text = "Webs vendidas", tiers = { 10, 75, 300, 1200, 5000 },
		bonus = "sale", per = 0.05, value = function(d) return d.stats.sold or 0 end },
	{ id = "clicker", emoji = "🖱️", name = "Dedos de acero", text = "Clics programando", tiers = { 2000, 20000, 100000, 500000, 2000000 },
		bonus = "click", per = 0.04, value = function(d) return d.stats.clicks or 0 end },
	{ id = "tycoon", emoji = "💰", name = "Magnate", text = "Dinero ganado en total", tiers = { 1e6, 1e9, 1e12, 1e15, 1e18 },
		bonus = "money", per = 0.04, value = function(d) return d.lifetimeEarned or 0 end },
	{ id = "investor", emoji = "📈", name = "Inversor", text = "Salidas a bolsa", tiers = { 1, 3, 8, 20, 50 },
		bonus = "money", per = 0.03, value = function(d) return d.ipoCount or 0 end },
	{ id = "collector", emoji = "📖", name = "Coleccionista", text = "Casillas de la colección", tiers = { 5, 12, 20, 30, 40 },
		bonus = "rare", per = 0.08, value = function(d)
			local n = 0
			for _, row in d.collection or {} do
				for _ in row do
					n += 1
				end
			end
			return n
		end },
	{ id = "boss", emoji = "👥", name = "Jefe de equipo", text = "Entrevistas en tu agencia", tiers = { 10, 50, 200, 800, 3000 },
		bonus = "work", per = 0.05, value = function(d) return (d.career and d.career.stats and d.career.stats.recruits) or 0 end },
	{ id = "dedicated", emoji = "📅", name = "Constante", text = "Misiones completadas", tiers = { 10, 50, 150, 400, 1000 },
		bonus = "money", per = 0.03, value = function(d) return d.stats.missions or 0 end },
	{ id = "popular", emoji = "👍", name = "Famoso", text = "Me gusta recibidos", tiers = { 5, 25, 100, 400, 1500 },
		bonus = "visits", per = 0.04, value = function(d) return d.likes or 0 end },
	{ id = "combo", emoji = "🔥", name = "Imparable", text = "Mejor combo", tiers = { 10, 20, 30, 40, 50 },
		bonus = "click", per = 0.03, value = function(d) return d.bestCombo or 0 end },
	{ id = "freelance", emoji = "🧾", name = "Profesional", text = "Encargos entregados", tiers = { 5, 25, 100, 400, 1500 },
		bonus = "sale", per = 0.04, value = function(d) return (d.career and d.career.stats and d.career.stats.contracts) or 0 end },
	{ id = "trader", emoji = "📈", name = "Lobo de la bolsa", text = "Beneficio en la Bolsa", tiers = { 1e4, 1e6, 1e8, 1e10, 1e12 },
		bonus = "money", per = 0.03, value = function(d) return (d.stats and d.stats.marketProfit) or 0 end },
}

-- Niveles conseguidos de un logro (0..5)
function Config.achievementTier(data, achievement): number
	local value = achievement.value(data)
	local tier = 0
	for i, target in achievement.tiers do
		if value >= target then
			tier = i
		end
	end
	return tier
end

-- Bonus total de los logros de un tipo (0.15 = +15 %)
function Config.achievementBonus(data, kind: string): number
	local total = 0
	for _, achievement in Config.Achievements do
		if achievement.bonus == kind then
			total += Config.achievementTier(data, achievement) * achievement.per
		end
	end
	return total
end

---------------------------------------------------------------------
-- Desbloqueo progresivo: cada parte del juego se abre al llegar a una
-- planta de tu rascacielos (que crece con todo lo que has ganado, así que
-- nunca se vuelve a cerrar). Lo comprueba también el servidor.
---------------------------------------------------------------------
Config.Unlocks = {
	clients = 2, -- vender a empresas
	ads = 3, -- más apps de anuncios
	ranking = 3,
	companies = 4,
	season = 4, -- pase de temporada
	career = 5,
	collection = 6,
	agency = 7,
	market = 9, -- bolsa e I+D
}

function Config.unlockFloor(feature: string): number
	return Config.Unlocks[feature] or 1
end

function Config.isUnlocked(data, feature: string): boolean
	return Config.buildingFloors(data.lifetimeEarned) >= Config.unlockFloor(feature)
end

Config.DailyRewards = {
	{ minutes = 2, min = 100 },
	{ minutes = 4, min = 300 },
	{ minutes = 6, min = 600 },
	{ minutes = 10, min = 1200 },
	{ minutes = 15, min = 2500 },
	{ minutes = 20, min = 5000 },
	{ minutes = 30, min = 10000, boostMinutes = 30 },
}

---------------------------------------------------------------------
-- Objetivos: dan dinero la primera vez que los cumples.
-- value(d) devuelve el progreso actual y target la meta.
---------------------------------------------------------------------
local function companyLevels(d): number
	local total = 0
	for _, level in d.companies do
		total += level
	end
	return total
end

local function networksUnlocked(d): number
	local n = 0
	for _ in d.unlockedAds do
		n += 1
	end
	return n
end

local function maxSeo(d): number
	local best = 0
	for _, site in d.sites do
		best = math.max(best, site.seo)
	end
	return best
end

local function built(typeId: string)
	return function(d): number
		return (d.stats.byType and d.stats.byType[typeId]) or 0
	end
end

local function careerStat(field: string)
	return function(d): number
		return (d.career and d.career.stats and d.career.stats[field]) or 0
	end
end

-- Casillas de la colección (se calcula aquí porque las fórmulas van más abajo)
local function collectionEntries(d): number
	local n = 0
	for _, row in d.collection or {} do
		for _ in row do
			n += 1
		end
	end
	return n
end

local function rareEntries(d): number
	local n = 0
	for _, row in d.collection or {} do
		for variant in row do
			if variant ~= "normal" then
				n += 1
			end
		end
	end
	return n
end

local function researchLevels(d): number
	local n = 0
	for _, level in d.research or {} do
		n += level
	end
	return n
end

local function goal(id: string, text: string, reward: number, target: number, value: (any) -> number)
	return { id = id, text = text, reward = math.floor(reward * Config.GOAL_REWARD_SCALE), target = target, value = value }
end

Config.Goals = {
	goal("first_site", "Programa tu primera web", 50, 1, function(d) return d.stats.built end),
	goal("earn_1k", "Gana $1K", 200, 1e3, function(d) return d.totalEarned end),
	goal("blog", "Programa un Blog", 300, 1, built("blog")),
	goal("sell_1", "Vende una web a una empresa", 400, 1, function(d) return d.stats.sold end),
	goal("network_2", "Desbloquea una segunda app de anuncios", 1500, 2, networksUnlocked),
	goal("company_1", "Funda tu primera empresa", 500, 1, companyLevels),
	goal("contract_1", "Entrega tu primer encargo a una empresa", 600, 1, careerStat("contracts")),
	goal("tienda", "Programa una Tienda Online", 2000, 1, built("tienda")),
	goal("sites_5", "Ten 5 webs a la vez", 3000, 5, function(d) return #d.sites end),
	goal("dev_8", "Llega a nivel de programador 8", 4000, 8, careerStat("devLevel")),
	goal("agency", "Funda tu propia agencia", 6000, 1, careerStat("agency")),
	goal("seo_5", "Sube una web a SEO 5", 5000, 5, maxSeo),
	goal("rare_1", "Consigue una web rara (✨ o mejor)", 8000, 1, rareEntries),
	goal("sell_10", "Vende 10 webs", 10000, 10, function(d) return d.stats.sold end),
	goal("earn_100k", "Gana $100K", 20000, 1e5, function(d) return d.totalEarned end),
	goal("senior", "Llega al rango Senior (pestaña Carrera)", 30000, 3, careerStat("rank")),
	goal("epic", "Ficha a un programador Épico o mejor", 40000, 4, careerStat("bestRarity")),
	goal("noticias", "Programa un Periódico Digital", 30000, 1, built("noticias")),
	goal("companies_25", "Suma 25 niveles de empresas", 100000, 25, companyLevels),
	goal("earn_1m", "Gana $1M", 250000, 1e6, function(d) return d.totalEarned end),
	goal("ipo_1", "Sal a bolsa por primera vez", 0, 1, function(d) return d.ipoCount end),
	goal("research_1", "Compra una mejora de I+D con patentes", 60000, 1, researchLevels),
	goal("red_social", "Programa una Red Social", 500000, 1, built("red_social")),
	goal("team_10", "Ten 10 programadores en tu agencia", 1000000, 10, careerStat("team")),
	goal("cto", "Llega al rango CTO", 5000000, 5, careerStat("rank")),
	goal("sell_100", "Vende 100 webs", 1000000, 100, function(d) return d.stats.sold end),
	goal("collection_20", "Llena 20 casillas de la colección", 5000000, 20, collectionEntries),
	goal("earn_1b", "Gana $1B", 50000000, 1e9, function(d) return d.totalEarned end),
	goal("streaming", "Programa una Plataforma de Streaming", 100000000, 1, built("streaming")),
	goal("ipo_5", "Sal a bolsa 5 veces", 0, 5, function(d) return d.ipoCount end),
	goal("app_ia", "Programa una App de IA", 2000000000, 1, built("app_ia")),
	goal("metaverso", "Programa un Metaverso", 50000000000, 1, built("metaverso")),
	goal("earn_1t", "Gana $1T", 500000000000, 1e12, function(d) return d.totalEarned end),
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
-- Ranking semanal (se reinicia cada lunes a las 00:00 UTC). Puntúa el
-- dinero ganado en la semana. Al acabar, los mejores reciben premio.
--   upTo      = puestos que cubre el premio
--   legendary = Contratos Legendarios
--   minutes   = minutos de ingresos
--   goldDays  = días con el rascacielos dorado
---------------------------------------------------------------------
Config.WEEKLY_STORE_PREFIX = "ImperioWebSemana_v1_" -- + número de semana
Config.WEEKLY_GRACE = 600 -- segundos tras el cambio de semana antes de repartir premios
Config.WEEKLY_TOP_SIZE = 10
Config.WeeklyPrizes = {
	{ upTo = 1, emoji = "🥇", name = "Campeón semanal", legendary = 1, minutes = 240, goldDays = 7 },
	{ upTo = 3, emoji = "🥈", name = "Podio semanal", legendary = 1, minutes = 120, goldDays = 7 },
	{ upTo = 10, emoji = "🏅", name = "Top 10 semanal", legendary = 0, minutes = 120, goldDays = 7 },
	{ upTo = 100, emoji = "🎖️", name = "Top 100 semanal", legendary = 0, minutes = 45, goldDays = 0 },
}

function Config.weeklyPrize(rank: number)
	for _, prize in Config.WeeklyPrizes do
		if rank <= prize.upTo then
			return prize
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Eventos de fin de semana: del viernes 20:00 al lunes 04:00 (UTC).
-- Cada semana toca uno distinto, en este orden.
---------------------------------------------------------------------
Config.WeekendEvents = {
	{ id = "money", emoji = "💰", name = "Fin de semana x2 Dinero", short = "x2 Dinero",
		desc = "Todo el dinero que ganas vale el doble." },
	{ id = "viral", emoji = "🔥", name = "Fin de semana Viral", short = "+50% visitas",
		desc = "Todas tus webs reciben un 50 % más de visitas." },
	{ id = "contracts", emoji = "💼", name = "Feria de Encargos", short = "Encargos x1.5",
		desc = "Llegan encargos el doble de a menudo y pagan x1.5." },
}
Config.WEEKEND_START = 4 * 86400 + 20 * 3600 -- desde el lunes 00:00 UTC: viernes 20:00
Config.WEEKEND_DURATION = 56 * 3600 -- hasta el lunes a las 04:00
Config.WEEKEND_MONEY_MULT = 2
Config.WEEKEND_VISITS_MULT = 1.5
Config.WEEKEND_CONTRACT_MULT = 1.5 -- paga de los encargos en la Feria de Encargos
Config.WEEKEND_CONTRACT_SPEED = 2 -- llegan encargos el doble de rápido

-- Semana actual (empieza el lunes a las 00:00 UTC; el 1-1-1970 fue jueves)
function Config.weekIndex(unixTime: number): number
	return (unixTime + 3 * 86400) // 604800
end

function Config.weekStart(week: number): number
	return week * 604800 - 3 * 86400
end

local function weekendEventFor(week: number)
	return Config.WeekendEvents[week % #Config.WeekendEvents + 1]
end

-- Evento de fin de semana activo (o nil), cuándo acaba, y el siguiente
-- con su hora de inicio.
function Config.weekendStatus(unixTime: number): (any?, number, any, number)
	local week = Config.weekIndex(unixTime)
	local start = Config.weekStart(week) + Config.WEEKEND_START
	-- El de la semana pasada dura hasta el lunes por la mañana
	local previousStart = start - 604800
	if unixTime < previousStart + Config.WEEKEND_DURATION then
		return weekendEventFor(week - 1), previousStart + Config.WEEKEND_DURATION, weekendEventFor(week), start
	elseif unixTime < start then
		return nil, 0, weekendEventFor(week), start
	elseif unixTime < start + Config.WEEKEND_DURATION then
		return weekendEventFor(week), start + Config.WEEKEND_DURATION, weekendEventFor(week + 1), start + 604800
	end
	return nil, 0, weekendEventFor(week + 1), start + 604800
end

---------------------------------------------------------------------
-- v2.0 · Variantes raras de webs (como las mutaciones): al terminar una
-- web hay una probabilidad de que salga especial. Multiplican sus visitas
-- (y por tanto lo que gana y lo que vale). chance = probabilidad base.
---------------------------------------------------------------------
Config.Variants = {
	{ id = "brillante", emoji = "✨", name = "Brillante", mult = 2, chance = 0.08, color = Color3.fromRGB(253, 224, 71) },
	{ id = "arcoiris", emoji = "🌈", name = "Arcoíris", mult = 4, chance = 0.02, color = Color3.fromRGB(236, 72, 153) },
	{ id = "diamante", emoji = "💎", name = "Diamante", mult = 10, chance = 0.005, color = Color3.fromRGB(56, 189, 248) },
	{ id = "cosmica", emoji = "🌌", name = "Cósmica", mult = 30, chance = 0.001, color = Color3.fromRGB(168, 85, 247) },
}
Config.MAX_VARIANT_CHANCE_MULT = 10 -- tope a lo que se pueden multiplicar las probabilidades

---------------------------------------------------------------------
-- Colección (índice): cada combinación tipo de web × variante que has
-- conseguido alguna vez da dinero extra para siempre. Completar todas las
-- variantes de un tipo da un bonus mayor. No se pierde al salir a bolsa.
---------------------------------------------------------------------
Config.COLLECTION_ENTRY_BONUS = 0.01 -- +1 % de dinero por casilla
Config.COLLECTION_ROW_BONUS = 0.10 -- +10 % por tipo de web completo

---------------------------------------------------------------------
-- Hitos de empresa: al llegar a estos niveles, la empresa produce x1.5
-- (dinero, o trabajo en el Equipo de Programadores). Se acumulan.
---------------------------------------------------------------------
Config.COMPANY_MILESTONES = { 10, 25, 50, 100, 150, 200 }
Config.MILESTONE_MULT = 1.5

---------------------------------------------------------------------
-- Combo de clics: si tecleas seguido, cada clic vale más (hasta x3)
---------------------------------------------------------------------
Config.COMBO_WINDOW = 0.8 -- segundos máximos entre clics para seguir el combo
Config.COMBO_MAX = 50 -- clics seguidos para llegar al máximo
Config.COMBO_MAX_MULT = 3

---------------------------------------------------------------------
-- I+D con patentes: al salir a bolsa ganas 💡 patentes (además de
-- acciones) y las gastas en mejoras PERMANENTES. cost = patentes del
-- primer nivel; cada nivel cuesta costGrowth veces más. value = efecto
-- por nivel (ver "Config.research").
---------------------------------------------------------------------
Config.PATENTS_PER_SHARES = 4 -- 1 patente por cada 4 acciones conseguidas (mínimo 1)
Config.ResearchBranches = {
	{ id = "negocio", emoji = "💰", name = "Negocio" },
	{ id = "codigo", emoji = "⌨️", name = "Código" },
	{ id = "trafico", emoji = "📈", name = "Tráfico" },
	{ id = "talento", emoji = "👥", name = "Talento" },
}
Config.Research = {
	{ id = "capital", branch = "negocio", emoji = "🏦", name = "Capital semilla", maxLevel = 5, cost = 1, costGrowth = 2, value = 10,
		desc = "Empiezas cada partida con más dinero (x10 por nivel, desde $1K)." },
	{ id = "negotiator", branch = "negocio", emoji = "🤝", name = "Negociador", maxLevel = 10, cost = 1, costGrowth = 1.5, value = 0.10,
		desc = "+10 % al vender webs por nivel." },
	{ id = "maintenance", branch = "negocio", emoji = "🔧", name = "Contratos blindados", maxLevel = 5, cost = 2, costGrowth = 1.6, value = 0.25,
		desc = "+25 % de dinero de los contratos de mantenimiento por nivel." },
	{ id = "analyst", branch = "negocio", emoji = "🔍", name = "Analista de bolsa", maxLevel = 4, cost = 2, costGrowth = 1.6, value = 0.05,
		desc = "El rumor del analista de la Bolsa acierta un 5 % más por nivel (del 60 % al 80 %)." },
	{ id = "fingers", branch = "codigo", emoji = "⚡", name = "Dedos rápidos", maxLevel = 10, cost = 1, costGrowth = 1.5, value = 0.25,
		desc = "+25 % de trabajo por clic por nivel." },
	{ id = "slots", branch = "codigo", emoji = "🗄️", name = "Servidores propios", maxLevel = 3, cost = 2, costGrowth = 2, value = 1,
		desc = "+1 hueco para webs por nivel." },
	{ id = "autolab", branch = "codigo", emoji = "🤖", name = "IA heredada", maxLevel = 1, cost = 3, costGrowth = 1, value = 1,
		desc = "Tras salir a bolsa conservas el Laboratorio de IA a nivel 1 (modo automático)." },
	{ id = "viral", branch = "trafico", emoji = "🔥", name = "Marketing viral", maxLevel = 10, cost = 1, costGrowth = 1.5, value = 0.10,
		desc = "+10 % de visitas en todas tus webs por nivel." },
	{ id = "luck", branch = "trafico", emoji = "🍀", name = "Golpe de suerte", maxLevel = 5, cost = 2, costGrowth = 1.6, value = 0.20,
		desc = "+20 % de probabilidad de webs raras por nivel." },
	{ id = "offers", branch = "trafico", emoji = "📇", name = "Cartera de clientes", maxLevel = 2, cost = 2, costGrowth = 2, value = 1,
		desc = "+1 oferta de cliente a la vez y pagan un 5 % más, por nivel." },
	{ id = "office", branch = "talento", emoji = "🏢", name = "Oficina ampliada", maxLevel = 5, cost = 2, costGrowth = 1.5, value = 1,
		desc = "+1 puesto en la oficina de tu agencia por nivel." },
	{ id = "recruiter", branch = "talento", emoji = "🎯", name = "Ojeador", maxLevel = 5, cost = 1, costGrowth = 1.5, value = 0.10,
		desc = "-10 % de coste al entrevistar programadores por nivel." },
	{ id = "mentor", branch = "talento", emoji = "🎓", name = "Mentoría", maxLevel = 5, cost = 1, costGrowth = 1.5, value = 0.15,
		desc = "+15 % de XP en los nichos por nivel." },
}

---------------------------------------------------------------------
-- Pase de temporada: cada temporada dura 4 semanas (empieza un lunes).
-- Ganas ⭐ puntos de temporada con misiones, objetivos, tiempo jugado y
-- ventas. 30 niveles con premio gratis y premio premium.
---------------------------------------------------------------------
Config.SEASON_WEEKS = 4
Config.SEASON_TIERS = 30
Config.SEASON_XP_PER_TIER = 200
Config.SeasonXp = {
	dailyMission = { 60, 100, 160 }, -- por dificultad
	goal = 50,
	playtime = 40,
	sale = 5,
	community = 50,
}
Config.SeasonNames = { "Temporada del Píxel", "Temporada Neón", "Temporada Nube", "Temporada Cohete", "Temporada Cripto", "Temporada Galaxia" }

-- Premio de un nivel: { kind = "cash"|"boost"|"ticket"|"patents", ... }
function Config.seasonReward(tier: number, premium: boolean)
	if premium then
		if tier % 10 == 0 then
			return { kind = "ticket", ticket = "legendary", amount = 1 }
		elseif tier % 5 == 0 then
			return { kind = "patents", amount = 2 + tier // 10 }
		elseif tier % 3 == 0 then
			return { kind = "boost", minutes = 15 }
		end
		return { kind = "cash", minutes = 10 + tier, min = 2000 * tier }
	end
	if tier == Config.SEASON_TIERS then
		return { kind = "ticket", ticket = "legendary", amount = 1 }
	elseif tier % 10 == 0 then
		return { kind = "patents", amount = 1 + tier // 10 }
	elseif tier % 5 == 0 then
		return { kind = "ticket", ticket = "premium", amount = 1 }
	elseif tier % 4 == 0 then
		return { kind = "boost", minutes = 10 }
	end
	return { kind = "cash", minutes = 4 + tier // 2, min = 500 * tier }
end

function Config.seasonIndex(unixTime: number): number
	return Config.weekIndex(unixTime) // Config.SEASON_WEEKS
end

function Config.seasonEnds(season: number): number
	return Config.weekStart((season + 1) * Config.SEASON_WEEKS)
end

function Config.seasonName(season: number): string
	return Config.SeasonNames[season % #Config.SeasonNames + 1]
end

---------------------------------------------------------------------
-- Premios por tiempo jugado hoy (minutos acumulados en el día, UTC)
--   atMinutes = cuándo se puede reclamar
--   el resto es el premio, con el mismo formato que los del pase
--   (cash: minutes de ingresos o min; boost: minutes de boost x2)
---------------------------------------------------------------------
Config.PlaytimeRewards = {
	{ atMinutes = 5, kind = "cash", minutes = 3, min = 300 },
	{ atMinutes = 10, kind = "cash", minutes = 5, min = 600 },
	{ atMinutes = 15, kind = "cash", minutes = 8, min = 1000 },
	{ atMinutes = 25, kind = "boost", minutes = 10 },
	{ atMinutes = 40, kind = "cash", minutes = 15, min = 3000 },
	{ atMinutes = 60, kind = "boost", minutes = 20 },
	{ atMinutes = 90, kind = "ticket", ticket = "premium", amount = 1 },
}

---------------------------------------------------------------------
-- Códigos (para redes sociales). code en MAYÚSCULAS. expires = hora unix
-- en que deja de valer (nil = siempre).
---------------------------------------------------------------------
Config.Codes = {
	{ code = "LANZAMIENTO", minutes = 15, min = 2000 },
	{ code = "WEBEMPIRE", minutes = 10, min = 1000, boostMinutes = 10 },
	{ code = "V2", minutes = 20, min = 5000 },
}

---------------------------------------------------------------------
-- Eventos de servidor: les pasan a TODOS los del servidor a la vez
-- (cambia hasta el color del cielo). Uno cada 8-14 minutos.
---------------------------------------------------------------------
Config.SERVER_EVENT_MIN_DELAY = 480
Config.SERVER_EVENT_MAX_DELAY = 840
Config.ServerEvents = {
	{ id = "rushhour", emoji = "🚀", name = "Hora punta de Internet", desc = "Visitas x2 en todas las webs.", duration = 180, weight = 3,
		tint = Color3.fromRGB(255, 236, 214) },
	{ id = "datastorm", emoji = "⚡", name = "Tormenta de datos", desc = "Webs raras x5 más probables.", duration = 180, weight = 2,
		tint = Color3.fromRGB(214, 200, 255) },
	{ id = "blackfriday", emoji = "🛍️", name = "Black Friday", desc = "Los clientes pagan x2 por tus webs.", duration = 150, weight = 2,
		tint = Color3.fromRGB(255, 214, 230) },
	{ id = "hackathon", emoji = "💻", name = "Hackatón", desc = "Clics x3 y programadores x2.", duration = 120, weight = 2,
		tint = Color3.fromRGB(205, 255, 220) },
}

---------------------------------------------------------------------
-- Meta del servidor (cooperativa): entre todos los del servidor hay que
-- ganar una cantidad antes de que acabe el tiempo. Premio para todos.
---------------------------------------------------------------------
Config.COMMUNITY_DURATION = 900 -- 15 minutos para conseguirla
Config.COMMUNITY_COOLDOWN = 120 -- pausa hasta la siguiente
Config.COMMUNITY_TARGET_SECONDS = 420 -- la meta = 7 min de los ingresos de todos juntos
Config.COMMUNITY_MIN_TARGET = 2000
Config.COMMUNITY_REWARD_MINUTES = 8

---------------------------------------------------------------------
-- Búsquedas rápidas por id
---------------------------------------------------------------------
local function index(list, field: string)
	local map = {}
	for i, item in list do
		item.order = i
		map[item[field]] = item
	end
	return map
end

Config.WebTypeById = index(Config.WebTypes, "id")
Config.AdNetworkById = index(Config.AdNetworks, "id")
Config.CompanyById = index(Config.Companies, "id")
-- Pases y productos se buscan por "key" (su id vale 0 hasta que lo configures)
Config.WeekendEventById = index(Config.WeekendEvents, "id")
Config.VariantById = index(Config.Variants, "id")
Config.ResearchById = index(Config.Research, "id")
Config.ServerEventById = index(Config.ServerEvents, "id")
Config.CodeByCode = index(Config.Codes, "code")
Config.PassByKey = index(Config.Monetization.GamePasses, "key")
Config.ProductByKey = index(Config.Monetization.Products, "key")

---------------------------------------------------------------------
-- Fórmulas (iguales en servidor y cliente)
--
-- "bonuses" es una tabla que calcula el servidor para cada jugador:
--   { pass, turbo, slotsPass, boost: boolean, friends: number,
--     premium, group: boolean, weekend: id del evento de fin de semana }
---------------------------------------------------------------------
function Config.level(data, companyId: string): number
	return data.companies[companyId] or 0
end

-- Nivel de una mejora de I+D (0 si no la tienes) y su efecto total
function Config.research(data, researchId: string): number
	return (data.research and data.research[researchId]) or 0
end

function Config.researchValue(data, researchId: string): number
	return Config.research(data, researchId) * Config.ResearchById[researchId].value
end

-- Patentes que cuesta subir del nivel "level" al siguiente
function Config.researchCost(researchId: string, level: number): number
	local def = Config.ResearchById[researchId]
	return math.max(1, math.floor(def.cost * def.costGrowth ^ level + 0.5))
end

function Config.patentsForShares(shares: number): number
	if shares < 1 then
		return 0
	end
	return math.max(1, shares // Config.PATENTS_PER_SHARES)
end

-- Hitos que ha alcanzado una empresa con ese nivel
function Config.milestonesReached(level: number): number
	local n = 0
	for _, milestone in Config.COMPANY_MILESTONES do
		if level >= milestone then
			n += 1
		end
	end
	return n
end

-- Siguiente hito (nil si ya están todos)
function Config.nextMilestone(level: number): number?
	for _, milestone in Config.COMPANY_MILESTONES do
		if level < milestone then
			return milestone
		end
	end
	return nil
end

function Config.companyMult(data, companyId: string): number
	return Config.MILESTONE_MULT ^ Config.milestonesReached(Config.level(data, companyId))
end

-- Coste de comprar "count" niveles seguidos desde "level"
function Config.companyBulkCost(companyId: string, level: number, count: number): number
	local total = 0
	for i = 0, count - 1 do
		total += Config.companyCost(companyId, level + i)
	end
	return total
end

-- Cuántos niveles puedes comprar con "money" (máximo "limit")
function Config.companyAffordable(companyId: string, level: number, money: number, limit: number): (number, number)
	local count, total = 0, 0
	while count < limit do
		local cost = Config.companyCost(companyId, level + count)
		if total + cost > money then
			break
		end
		total += cost
		count += 1
	end
	return count, total
end

-- Colección: casillas conseguidas, tipos completos y bonus de dinero
function Config.collectionStats(data): (number, number)
	local entries, rows = 0, 0
	local collection = data.collection
	if not collection then
		return 0, 0
	end
	for _, def in Config.WebTypes do
		local row = collection[def.id]
		if row then
			local complete = row.normal == true
			if row.normal then
				entries += 1
			end
			for _, variant in Config.Variants do
				if row[variant.id] then
					entries += 1
				else
					complete = false
				end
			end
			if complete then
				rows += 1
			end
		end
	end
	return entries, rows
end

function Config.collectionBonus(data): number
	local entries, rows = Config.collectionStats(data)
	return entries * Config.COLLECTION_ENTRY_BONUS + rows * Config.COLLECTION_ROW_BONUS
end

-- Multiplicador de probabilidad de webs raras (I+D, logros, evento del
-- servidor y programadores de Datos: eventMult ya los incluye)
function Config.variantChanceMult(data, eventMult: number?): number
	return math.min(Config.MAX_VARIANT_CHANCE_MULT, (1 + Config.researchValue(data, "luck") + Config.achievementBonus(data, "rare")) * (eventMult or 1))
end

-- Multiplicador del combo de clics
function Config.comboMult(combo: number): number
	return 1 + (Config.COMBO_MAX_MULT - 1) * math.clamp(combo, 0, Config.COMBO_MAX) / Config.COMBO_MAX
end

-- Segundos que tarda un cliente en comprar una web de ese tipo
function Config.dealSeconds(data, typeId: string): number
	local base = Config.DealSeconds[typeId] or 60
	return math.floor(base * math.max(0.6, 1 - 0.02 * Config.level(data, "comercial")))
end

-- Negociaciones de venta que puedes tener a la vez
function Config.maxDeals(data): number
	return math.min(4, Config.MAX_DEALS + Config.level(data, "comercial") // 15)
end

-- Contratos de mantenimiento (con la mejora de I+D)
function Config.maintenanceIncome(data): number
	return data.maintenance * (1 + Config.researchValue(data, "maintenance"))
end

function Config.companyCost(companyId: string, level: number): number
	local def = Config.CompanyById[companyId]
	return math.floor(def.baseCost * def.growth ^ level)
end

function Config.slots(data, bonuses): number
	local extra = if bonuses and bonuses.slotsPass then 3 else 0
	return Config.BASE_SLOTS + Config.level(data, "hosting") + extra + Config.researchValue(data, "slots")
end

-- bonuses.agencyWork = trabajo/s de los programadores de tu agencia
function Config.workPerSec(data, bonuses): number
	local turbo = if bonuses and bonuses.turbo then 2 else 1
	local agency = if bonuses and bonuses.agencyWork then bonuses.agencyWork else 0
	local devs = Config.level(data, "devs") * 1.5 * Config.companyMult(data, "devs")
	return (devs + agency) * (1 + 0.25 * Config.level(data, "ia_lab")) * turbo * (1 + Config.achievementBonus(data, "work"))
end

function Config.clickPower(data, bonuses): number
	local turbo = if bonuses and bonuses.turbo then 2 else 1
	local fingers = 1 + Config.researchValue(data, "fingers") + Config.achievementBonus(data, "click")
	return (1 + Config.workPerSec(data, nil) * 0.15) * (1 + 0.25 * Config.level(data, "ia_lab")) * turbo * fingers
end

-- % extra por amigos, Premium y grupo
function Config.socialBonus(bonuses): number
	if not bonuses then
		return 0
	end
	local m = Config.Monetization
	local pct = math.min(bonuses.friends or 0, m.MAX_FRIENDS) * m.FRIEND_BONUS
	if bonuses.premium then
		pct += m.PREMIUM_BONUS
	end
	if bonuses.group then
		pct += m.GROUP_BONUS
	end
	return pct
end

-- Multiplicador global de dinero
function Config.moneyMult(data, bonuses): number
	local mult = 1 + data.shares * Config.SHARE_BONUS
	mult *= 1 + 0.05 * Config.level(data, "datacenter")
	mult *= 1 + Config.collectionBonus(data)
	mult *= 1 + Config.achievementBonus(data, "money")
	if bonuses then
		if bonuses.pass then
			mult *= 2
		end
		if bonuses.boost then
			mult *= 2
		end
		if bonuses.weekend == "money" then
			mult *= Config.WEEKEND_MONEY_MULT
		end
		mult *= 1 + Config.socialBonus(bonuses)
		-- bonuses.agencyBonus = % extra de los programadores de tu agencia
		mult *= 1 + (bonuses.agencyBonus or 0)
	end
	return mult
end

function Config.siteVisits(data, site, eventMult: number?): number
	local def = Config.WebTypeById[site.type]
	local network = Config.AdNetworkById[site.network] or Config.AdNetworks[1]
	local adLevel = Config.AdLevels[site.adLevel] or Config.AdLevels[1]
	local visits = def.visits * site.quality * (1 + Config.DESIGN_QUALITY_BONUS * (site.design or 0))
	visits *= Config.SEO_VISIT_BONUS ^ site.seo
	visits *= 1 + 0.10 * Config.level(data, "marketing")
	visits *= adLevel.visits * (1 - network.penalty)
	visits *= 1 + Config.researchValue(data, "viral") + Config.achievementBonus(data, "visits")
	local variant = site.variant and Config.VariantById[site.variant]
	if variant then
		visits *= variant.mult
	end
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
-- bonuses.agencySale = % extra de tus programadores de Ventas
function Config.saleBase(data, site, moneyMult: number, bonuses: any?): number
	local visits = Config.siteVisits(data, site, 1)
	local agency = 1 + (if bonuses then bonuses.agencySale or 0 else 0)
	local commercial = 1 + 0.12 * Config.level(data, "comercial")
	local negotiator = 1 + Config.researchValue(data, "negotiator") + Config.achievementBonus(data, "sale")
	return visits * Config.SALE_SECONDS * Config.bestRpv(data) * commercial * negotiator * agency * moneyMult
end

function Config.seoCost(site): number
	local def = Config.WebTypeById[site.type]
	return math.floor((def.cost + 50) * 3 * 2.1 ^ site.seo)
end

function Config.designCost(site): number
	local def = Config.WebTypeById[site.type]
	return math.floor((def.cost + 80) * 6 * 2.6 ^ (site.design or 0))
end

function Config.companiesIncome(data, moneyMult: number): number
	local total = 0
	for _, def in Config.Companies do
		total += def.income * Config.level(data, def.id) * Config.companyMult(data, def.id)
	end
	return total * moneyMult
end

function Config.sharesForIpo(totalEarned: number): number
	if totalEarned < Config.IPO_MIN_EARNED then
		return 0
	end
	return math.floor(10 * math.sqrt(totalEarned / Config.IPO_MIN_EARNED))
end

-- Plantas del rascacielos: crecen con todo lo que has ganado en tu vida
-- (nunca bajan, ni al vender webs ni al salir a bolsa).
Config.MAX_FLOORS = 40
function Config.buildingFloors(lifetimeEarned: number): number
	local floors = 1 + math.floor(2.6 * math.log10(1 + math.max(lifetimeEarned, 0) / 100))
	return math.clamp(floors, 1, Config.MAX_FLOORS)
end

-- Dinero ganado necesario para la planta "floors"
function Config.earnedForFloor(floors: number): number
	return 100 * (10 ^ ((floors - 1) / 2.6) - 1)
end

function Config.dayIndex(unixTime: number): number
	return unixTime // 86400
end

---------------------------------------------------------------------
-- Formato de números: 1.25K, 3.4M, 7B...
---------------------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.formatNumber(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "∞"
	end
	local sign = if n < 0 then "-" else ""
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
