--[[
	CareerConfig (ModuleScript en ReplicatedStorage)

	Carrera profesional del jugador:
	  · 10 nichos con nivel propio (subes programando y entregando encargos)
	  · 500 empresas ficticias (50 por nicho) que te hacen ENCARGOS
	  · rangos de Junior a CTO según los encargos que entregas
	  · tu propia agencia con programadores de 6 rarezas, 5 especialidades y 7 rasgos
	Lo usan el servidor y el cliente. La lista de empresas se genera igual
	en los dos, así no hace falta enviarla por la red.
]]

local Career = {}

---------------------------------------------------------------------
-- Nichos
---------------------------------------------------------------------
Career.Niches = {
	{ id = "ecommerce", name = "Comercio online", emoji = "🛍️",
		roots = { "Compra", "Tienda", "Mercado", "Carrito", "Oferta", "Bazar", "Outlet", "Vende", "Cesta", "Pedido" },
		suffixes = { "Ya", "Plus", "Express", "Online", "Total" } },
	{ id = "gaming", name = "Videojuegos", emoji = "🎮",
		roots = { "Pixel", "Arcade", "Nexus", "Quest", "Boss", "Retro", "Loot", "Combo", "Spawn", "Joystick" },
		suffixes = { "Studios", "Games", "Interactive", "Labs", "Arena" } },
	{ id = "salud", name = "Salud", emoji = "🩺",
		roots = { "Clínica", "Salud", "Vital", "Farma", "Dental", "Bienestar", "Médica", "Cuida", "Fisio", "Óptica" },
		suffixes = { "Norte", "Sur", "Central", "Integral", "Familiar" } },
	{ id = "finanzas", name = "Finanzas", emoji = "💳",
		roots = { "Banco", "Crédito", "Inversa", "Capital", "Fondo", "Ahorro", "Cambio", "Seguros", "Cripto", "Patrimonio" },
		suffixes = { "Global", "Seguro", "Directo", "Futuro", "Libre" } },
	{ id = "educacion", name = "Educación", emoji = "🎓",
		roots = { "Academia", "Colegio", "Instituto", "Escuela", "Campus", "Aula", "Saber", "Tutor", "Idiomas", "Ciencia" },
		suffixes = { "Sigma", "Delta", "Alfa", "Omega", "Nova" } },
	{ id = "comida", name = "Restauración", emoji = "🍕",
		roots = { "Pizzería", "Burger", "Sushi", "Taquería", "Cafetería", "Panadería", "Heladería", "Asador", "Tapas", "Bocatas" },
		suffixes = { "Napoli", "Express", "del Barrio", "Gourmet", "Feliz" } },
	{ id = "moda", name = "Moda", emoji = "👗",
		roots = { "Moda", "Estilo", "Boutique", "Zapatos", "Tejidos", "Look", "Trend", "Urban", "Glam", "Vintage" },
		suffixes = { "Studio", "Shop", "Chic", "Store", "Atelier" } },
	{ id = "viajes", name = "Viajes", emoji = "✈️",
		roots = { "Viajes", "Vuelos", "Hotel", "Rutas", "Destino", "Aventura", "Playa", "Turismo", "Mochila", "Crucero" },
		suffixes = { "Horizonte", "Sol", "Mundo", "Azul", "Express" } },
	{ id = "tech", name = "Tecnología e IA", emoji = "🤖",
		roots = { "Nube", "Código", "Datos", "Robot", "Chip", "Quantum", "Neuro", "Byte", "Cyber", "Logic" },
		suffixes = { "Systems", "AI", "Tech", "Soft", "Labs" } },
	{ id = "inmo", name = "Inmobiliaria", emoji = "🏠",
		roots = { "Inmobiliaria", "Casas", "Pisos", "Hogar", "Villa", "Torre", "Alquiler", "Ladrillo", "Barrio", "Residencial" },
		suffixes = { "Faro", "Centro", "Real", "Premium", "Verde" } },
}
Career.NicheById = {}
for i, niche in Career.Niches do
	niche.order = i
	Career.NicheById[niche.id] = niche
end
Career.DEFAULT_NICHE = "ecommerce"

---------------------------------------------------------------------
-- Niveles de nicho (XP acumulada para llegar al nivel L: 40·(L-1)^1.8)
---------------------------------------------------------------------
Career.MAX_NICHE_LEVEL = 50

function Career.xpForLevel(level: number): number
	return 40 * (level - 1) ^ 1.8
end

function Career.levelFromXp(xp: number): number
	local level = math.floor((math.max(xp, 0) / 40) ^ (1 / 1.8)) + 1
	-- Corrige redondeos en los bordes
	while level < Career.MAX_NICHE_LEVEL and Career.xpForLevel(level + 1) <= xp do
		level += 1
	end
	while level > 1 and Career.xpForLevel(level) > xp do
		level -= 1
	end
	return math.min(level, Career.MAX_NICHE_LEVEL)
end

function Career.nicheLevel(career, nicheId: string): number
	return Career.levelFromXp(career.xp[nicheId] or 0)
end

-- Nivel de programador: 1 + todo lo subido en todos los nichos
function Career.devLevel(career): number
	local total = 1
	for _, niche in Career.Niches do
		total += Career.nicheLevel(career, niche.id) - 1
	end
	return total
end

-- Bonus de calidad para webs del nicho (+2 % por nivel)
function Career.qualityBonus(career, nicheId: string): number
	return 1 + 0.02 * (Career.nicheLevel(career, nicheId) - 1)
end

Career.NICHE_MATCH_SALE_BONUS = 1.5 -- vender a una empresa de tu mismo nicho

---------------------------------------------------------------------
-- 500 empresas ficticias (50 por nicho)
---------------------------------------------------------------------
Career.Tiers = {
	{ name = "Startup", emoji = "🌱", upTo = 20 },
	{ name = "PyME", emoji = "🏪", upTo = 35 },
	{ name = "Gran empresa", emoji = "🏢", upTo = 45 },
	{ name = "Multinacional", emoji = "🌍", upTo = 50 },
}

Career.Companies = {}
Career.CompaniesByNiche = {}
for nicheIndex, niche in Career.Niches do
	local list = {}
	for k, suffix in niche.suffixes do
		for i, root in niche.roots do
			local rank = (k - 1) * #niche.roots + i -- 1..50 dentro del nicho
			local tier = Career.Tiers[1]
			for _, t in Career.Tiers do
				if rank <= t.upTo then
					tier = t
					break
				end
			end
			local id = (nicheIndex - 1) * 50 + rank
			-- Cada empresa paga distinto sus encargos: factor fijo entre 0.75 y 1.35
			-- (sale siempre igual para la misma empresa)
			local payScale = 0.75 + ((id * 7919 + 104729) % 61) / 100
			local company = {
				id = id,
				name = root .. " " .. suffix,
				niche = niche.id,
				rank = rank,
				tier = tier,
				reqLevel = math.floor(1 + (rank - 1) * 0.9),
				payScale = payScale,
			}
			table.insert(Career.Companies, company)
			table.insert(list, company)
		end
	end
	Career.CompaniesByNiche[niche.id] = list
end

function Career.company(id: number)
	return Career.Companies[id]
end

---------------------------------------------------------------------
-- Carrera v3: ENCARGOS. Las empresas te encargan webs concretas (tipo +
-- nicho) con un plazo. Si terminas de programar una web así a tiempo, se
-- entrega sola y cobras mucho más que vendiéndola. Con los encargos
-- entregados (y tu nivel de programador) subes de rango.
---------------------------------------------------------------------
Career.Ranks = {
	{ name = "Junior", contracts = 0, devLevel = 1, slots = 1, payMult = 1.0 },
	{ name = "Semi-senior", contracts = 5, devLevel = 4, slots = 1, payMult = 1.2 },
	{ name = "Senior", contracts = 15, devLevel = 10, slots = 2, payMult = 1.45 },
	{ name = "Lead", contracts = 40, devLevel = 20, slots = 2, payMult = 1.75 },
	{ name = "CTO", contracts = 100, devLevel = 35, slots = 3, payMult = 2.2 },
}
Career.CONTRACT_BOARD = 3 -- encargos disponibles a la vez en el tablón
Career.CONTRACT_INTERVAL = { 60, 120 } -- segundos entre encargos nuevos
Career.CONTRACT_LIFETIME = { 240, 420 } -- segundos que está en el tablón sin aceptar
Career.CONTRACT_PAY = 2 -- paga = el doble de lo que te darían por vender esa web
Career.CONTRACT_REP = 1 -- reputación = la misma que al programarla
Career.CONTRACT_XP = 2 -- XP del nicho = 2 veces la de programarla
Career.CONTRACT_MIN_DEADLINE = 180
Career.CONTRACT_DEADLINE_FACTOR = 3 -- plazo = 3 veces lo que tardarías a tu ritmo actual
Career.ASK_COOLDOWN = 60 -- segundos entre "pedir encargo"

-- Rango según encargos entregados y nivel de programador (1..5)
function Career.rankOf(career): number
	local done = career.stats.contracts or 0
	local level = Career.devLevel(career)
	local rank = 1
	for i, r in Career.Ranks do
		if done >= r.contracts and level >= r.devLevel then
			rank = i
		end
	end
	return rank
end

---------------------------------------------------------------------
-- Tu agencia y sus programadores
---------------------------------------------------------------------
Career.AGENCY_LEVEL_REQUIRED = 8 -- nivel de programador para fundarla
Career.AGENCY_COST = 2500
Career.MAX_OFFICE_LEVEL = 10
Career.PROGRAMMER_MAX_LEVEL = 10
Career.PITY_INTERVIEWS = 60 -- legendario garantizado cada 60 entrevistas sin suerte

function Career.officeCapacity(officeLevel: number, agencyPro: boolean?): number
	return 3 + 2 * officeLevel + (if agencyPro then 5 else 0)
end

function Career.officeUpgradeCost(officeLevel: number): number
	return math.floor(5000 * 3 ^ (officeLevel - 1))
end

-- weight = probabilidad en entrevistas normales; premium = con Headhunter
Career.Rarities = {
	{ id = "comun", name = "Común", color = Color3.fromRGB(156, 163, 175), weight = 60, premium = 0, work = 2, bonus = 0.01 },
	{ id = "pococomun", name = "Poco común", color = Color3.fromRGB(34, 197, 94), weight = 25, premium = 0, work = 5, bonus = 0.025 },
	{ id = "raro", name = "Raro", color = Color3.fromRGB(59, 130, 246), weight = 10, premium = 55, work = 14, bonus = 0.06 },
	{ id = "epico", name = "Épico", color = Color3.fromRGB(168, 85, 247), weight = 4, premium = 33, work = 40, bonus = 0.15 },
	{ id = "legendario", name = "Legendario", color = Color3.fromRGB(234, 179, 8), weight = 0.9, premium = 10, work = 120, bonus = 0.40 },
	{ id = "mitico", name = "Mítico", color = Color3.fromRGB(239, 68, 68), weight = 0.1, premium = 2, work = 400, bonus = 1.00 },
}
Career.RarityById = {}
for i, rarity in Career.Rarities do
	rarity.order = i
	Career.RarityById[rarity.id] = rarity
end

function Career.odds(field: string): { { rarity: any, percent: number } }
	local total = 0
	for _, rarity in Career.Rarities do
		total += rarity[field]
	end
	local list = {}
	for _, rarity in Career.Rarities do
		if rarity[field] > 0 then
			table.insert(list, { rarity = rarity, percent = rarity[field] / total * 100 })
		end
	end
	return list
end

Career.FirstNames = {
	"Lucía", "Hugo", "Martina", "Mateo", "Sofía", "Leo", "Julia", "Daniel", "Valeria", "Pablo",
	"Paula", "Álvaro", "Emma", "Adrián", "Carla", "Mario", "Noa", "Diego", "Alba", "Marcos",
	"Sara", "Iker", "Lola", "Bruno", "Vega", "Thiago", "Nora", "Enzo", "Aitana", "Izan",
	"Aisha", "Omar", "Mei", "Yuki", "Amara", "Kenji", "Ingrid", "Rafael", "Zoe", "Samuel",
}

---------------------------------------------------------------------
-- Trabajadores v3: cada programador tiene una ESPECIALIDAD (qué mejora) y
-- un RASGO (su forma de ser). Además ganan experiencia trabajando y
-- suben de nivel solos (o más rápido si los entrenas).
--   work = cuánto programan (x su trabajo base de rareza)
--   stat = qué mejoran (money, quality, visits, sale, rare); per = cuánto
---------------------------------------------------------------------
Career.Roles = {
	{ id = "dev", emoji = "💻", name = "Programación", work = 1.0, stat = "money", per = 0.5,
		desc = "Programa rápido y da un % extra de dinero." },
	{ id = "design", emoji = "🎨", name = "Diseño", work = 0.4, stat = "quality", per = 0.4,
		desc = "Más calidad en las webs nuevas." },
	{ id = "marketing", emoji = "📣", name = "Marketing", work = 0.4, stat = "visits", per = 0.6,
		desc = "Más visitas en todas tus webs." },
	{ id = "sales", emoji = "🤝", name = "Ventas", work = 0.4, stat = "sale", per = 0.6,
		desc = "Más dinero al vender webs y en los encargos." },
	{ id = "data", emoji = "📊", name = "Datos", work = 0.4, stat = "rare", per = 1.0,
		desc = "Más probabilidad de webs raras." },
}
Career.Traits = {
	{ id = "rapido", emoji = "⚡", name = "Rápido", desc = "+30 % de trabajo." },
	{ id = "perfeccionista", emoji = "💎", name = "Perfeccionista", desc = "Su especialidad rinde un 25 % más." },
	{ id = "noctambulo", emoji = "🌙", name = "Noctámbulo", desc = "Rinde x1.5 de noche y x0.8 de día." },
	{ id = "carismatico", emoji = "😎", name = "Carismático", desc = "+10 % al vender webs." },
	{ id = "suertudo", emoji = "🍀", name = "Suertudo", desc = "+5 % de probabilidad de webs raras." },
	{ id = "mentor", emoji = "🎓", name = "Mentor", desc = "El resto del equipo gana experiencia un 25 % más rápido." },
	{ id = "incansable", emoji = "💪", name = "Incansable", desc = "Gana experiencia el doble de rápido." },
}
Career.RoleById = {}
for i, role in Career.Roles do
	role.order = i
	Career.RoleById[role.id] = role
end
Career.TraitById = {}
for i, trait in Career.Traits do
	trait.order = i
	Career.TraitById[trait.id] = trait
end

-- Experiencia (segundos trabajando) para pasar del nivel L al L+1
function Career.programmerXpNeeded(level: number): number
	return 240 * level * level
end

-- Lo que aporta un programador: trabajo/s y una tabla de bonus
-- { money, quality, visits, sale, rare } (0.1 = +10 %)
function Career.programmerPower(programmer, agencyPro: boolean?, isNight: boolean?): (number, { [string]: number })
	local rarity = Career.RarityById[programmer.rarity] or Career.Rarities[1]
	local role = Career.RoleById[programmer.role or "dev"] or Career.Roles[1]
	local trait = programmer.trait
	local levelMult = 1 + 0.15 * (programmer.level - 1)
	local pro = if agencyPro then 1.25 else 1
	local shift = if trait == "noctambulo" then (if isNight then 1.5 else 0.8) else 1
	local power = rarity.bonus * levelMult * pro * shift
	local work = rarity.work * levelMult * pro * role.work * shift * (if trait == "rapido" then 1.3 else 1)
	local stats = { money = power * 0.25, quality = 0, visits = 0, sale = 0, rare = 0 }
	stats[role.stat] += power * role.per * (if trait == "perfeccionista" then 1.25 else 1)
	if trait == "carismatico" then
		stats.sale += 0.10
	elseif trait == "suertudo" then
		stats.rare += 0.05
	end
	return work, stats
end

-- Totales de toda la agencia: trabajo/s y bonus sumados
function Career.agencyTotals(career, projectNiche: string?, agencyPro: boolean?, isNight: boolean?): (number, { [string]: number })
	local totals = { money = 0, quality = 0, visits = 0, sale = 0, rare = 0 }
	local work = 0
	if not career.agency then
		return 0, totals
	end
	for _, programmer in career.programmers do
		local w, stats = Career.programmerPower(programmer, agencyPro, isNight)
		if projectNiche and programmer.niche == projectNiche then
			w *= 1.5
		end
		work += w
		for key, value in stats do
			totals[key] += value
		end
	end
	return work, totals
end

function Career.recruitCost(income: number): number
	return math.floor(math.max(1500, income * 180))
end

function Career.trainCost(programmer, income: number): number
	local rarity = Career.RarityById[programmer.rarity]
	return math.floor(math.max(800, income * 90) * (1 + rarity.order * 0.3) * 1.4 ^ (programmer.level - 1))
end

return Career
