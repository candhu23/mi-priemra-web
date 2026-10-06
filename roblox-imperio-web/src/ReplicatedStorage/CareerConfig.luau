--[[
	CareerConfig (ModuleScript en ReplicatedStorage)

	Carrera profesional del jugador:
	  · 10 nichos con nivel propio (subes programando y trabajando)
	  · 500 empresas ficticias (50 por nicho) donde puedes trabajar
	  · puestos de Junior a CTO con ascensos
	  · tu propia agencia con programadores de 6 rarezas
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
			local company = {
				id = (nicheIndex - 1) * 50 + rank,
				name = root .. " " .. suffix,
				niche = niche.id,
				rank = rank,
				tier = tier,
				reqLevel = math.floor(1 + (rank - 1) * 0.9),
				salary = 2 * 1.09 ^ (rank - 1), -- $/s base de un Junior
				xpRate = 1 + rank * 0.08, -- XP/s en el nicho
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
-- Puestos y ascensos
---------------------------------------------------------------------
Career.Ranks = {
	{ name = "Junior", mult = 1.0, minutes = 3, extraLevel = 0 },
	{ name = "Semi-senior", mult = 1.5, minutes = 8, extraLevel = 3 },
	{ name = "Senior", mult = 2.2, minutes = 15, extraLevel = 6 },
	{ name = "Lead", mult = 3.2, minutes = 30, extraLevel = 9 },
	{ name = "CTO", mult = 5.0, minutes = 0, extraLevel = 12 },
}
Career.TASK_INTERVAL = 40 -- segundos entre tareas del trabajo
Career.TASK_SALARY_SECONDS = 60 -- una tarea paga 60 s de sueldo...
Career.TASK_XP_SECONDS = 30 -- ...y 30 s de XP

function Career.salary(company, rank: number, nicheLevel: number, moneyMult: number): number
	return company.salary * Career.Ranks[rank].mult * (1 + 0.1 * (nicheLevel - 1)) * moneyMult
end

function Career.jobXpRate(company, rank: number, xpMult: number): number
	return company.xpRate * (1 + 0.25 * (rank - 1)) * xpMult
end

-- ¿Puede ascender? Devuelve (sí/no, motivo)
function Career.canPromote(job, nicheLevel: number, now: number): (boolean, string?)
	local rank = Career.Ranks[job.rank]
	local nextRank = Career.Ranks[job.rank + 1]
	if not nextRank then
		return false, "Ya eres CTO"
	end
	local company = Career.company(job.companyId)
	if nicheLevel < company.reqLevel + nextRank.extraLevel then
		return false, "Necesitas nivel " .. (company.reqLevel + nextRank.extraLevel) .. " en el nicho"
	end
	local waited = now - job.rankSince
	if waited < rank.minutes * 60 then
		return false, "Faltan " .. math.ceil((rank.minutes * 60 - waited) / 60) .. " min"
	end
	return true, nil
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

function Career.programmerPower(programmer, agencyPro: boolean?): (number, number)
	local rarity = Career.RarityById[programmer.rarity]
	local levelMult = 1 + 0.15 * (programmer.level - 1)
	local pro = if agencyPro then 1.25 else 1
	return rarity.work * levelMult * pro, rarity.bonus * levelMult * pro
end

-- Trabajo/s y % extra de dinero de toda la agencia
function Career.agencyTotals(career, projectNiche: string?, agencyPro: boolean?): (number, number)
	local work, bonus = 0, 0
	if not career.agency then
		return 0, 0
	end
	for _, programmer in career.programmers do
		local w, b = Career.programmerPower(programmer, agencyPro)
		if projectNiche and programmer.niche == projectNiche then
			w *= 1.5
		end
		work += w
		bonus += b
	end
	return work, bonus
end

function Career.recruitCost(income: number): number
	return math.floor(math.max(1500, income * 180))
end

function Career.trainCost(programmer, income: number): number
	local rarity = Career.RarityById[programmer.rarity]
	return math.floor(math.max(800, income * 90) * (1 + rarity.order * 0.3) * 1.4 ^ (programmer.level - 1))
end

return Career
