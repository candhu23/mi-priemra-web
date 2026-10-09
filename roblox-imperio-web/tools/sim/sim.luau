-- Simulador de balance: un "jugador bot" razonable, 1 tick = 1 s
-- Uso: luau sim.luau -a [nocareer] [horas]   (por defecto 6 h)
-- v4: también sale a bolsa, compra I+D con patentes, hace la Fusión,
-- compra Legado y usa los productos de las eras 2 y 3.
Color3 = { fromRGB = function() return {} end }
local Config = require("./TycoonConfig")
local Career = require("./CareerConfig")
local args = { ... }
DEBUG_IPO = false
local CAREER = true
local HOURS = 6
for _, a in args do
	if a == "nocareer" then
		CAREER = false
	elseif a == "debug" then
		DEBUG_IPO = true
	elseif tonumber(a) then
		HOURS = tonumber(a) :: number
	end
end
local career = { xp = {}, programmers = {}, agency = nil, pity = 0, stats = { contracts = 0 } }
local bonuses = { agencyWork = 0, agencyBonus = 0, agencyVisits = 0, agencySale = 0, agencyQuality = 0 }
-- Encargos: el bot acepta uno cuando tiene hueco y llega al tablón (~cada 90 s)
local contracts = {}
local boardTimer = 0
local contractIncome = 0
local CLICKS_PER_SEC = 4
math.randomseed(42)

local d = { money = Config.STARTING_MONEY, totalEarned = 0, lifetimeEarned = 0, reputation = 0, shares = 0, ipoCount = 0,
	sites = {}, project = nil, companies = {}, unlockedAds = { adsimple = true }, maintenance = 0,
	stats = { built = 0, sold = 0 }, nextId = 1, research = {}, patents = 0,
	era = 1, eraIpos = 0, eraEarned = 0, fusions = 0, legacy = 0, legacyTree = {} }

local now = 0
Config.clock = function()
	return now
end

local function gain(x)
	d.money += x
	d.totalEarned += x
	d.lifetimeEarned += x
	d.eraEarned += x
end
local function income()
	local mm = Config.moneyMult(d, bonuses)
	local t = 0
	for _, s in d.sites do t += Config.siteIncome(d, s, Config.siteVisits(d, s, 1 + bonuses.agencyVisits), mm) end
	return t + Config.companiesIncome(d, mm) + Config.maintenanceIncome(d)
end
local function bestNet()
	local best, bv = "adsimple", 0
	for id in d.unlockedAds do local n = Config.AdNetworkById[id]; local v = n.rpv*(1-n.penalty); if v > bv then best, bv = id, v end end
	return best
end
local function bestType()
	local best
	for _, t in Config.WebTypes do if Config.eraAllows(d, t) and d.reputation >= t.rep and d.money >= t.cost then best = t end end
	return best
end
-- Las ventas a clientes tardan (negociación) y hay un máximo a la vez
local function dealsActive()
	local n = 0
	for _, s in d.sites do if s.dealAt then n += 1 end end
	return n
end
local function finishSale(i, price)
	local s = d.sites[i]
	table.remove(d.sites, i)
	gain(price); d.maintenance += price * Config.MAINTENANCE_RATE
	d.reputation += Config.repReward(d, Config.WebTypeById[s.type]); d.stats.sold += 1
end
local function sell(i, mult)
	local s = d.sites[i]
	if s.dealAt or dealsActive() >= Config.maxDeals(d) then return end
	s.dealPrice = Config.saleBase(d, s, Config.moneyMult(d, bonuses), bonuses) * mult
	s.dealAt = now + Config.dealSeconds(d, s.type)
end
local function finishDeals(force)
	for i = #d.sites, 1, -1 do
		local s = d.sites[i]
		if s.dealAt and (force or now >= s.dealAt) then finishSale(i, s.dealPrice) end
	end
end

---------------------------------------------------------------------
-- Prestigio: salir a bolsa, I+D, Fusión y Legado
---------------------------------------------------------------------
local RESEARCH_PRIORITY = { "autolab", "viral", "negotiator", "fingers", "slots", "capital", "luck", "offers", "maintenance" }
local function buyResearch()
	while true do
		local best, bestCost = nil, math.huge
		for _, id in RESEARCH_PRIORITY do
			local level = Config.research(d, id)
			if level < Config.ResearchById[id].maxLevel then
				local cost = Config.researchCost(id, level)
				if cost < bestCost then best, bestCost = id, cost end
			end
		end
		if not best or bestCost > d.patents then return end
		d.patents -= bestCost
		d.research[best] = Config.research(d, best) + 1
	end
end
local function buyLegacy()
	while true do
		local best, bestCost = nil, math.huge
		for _, def in Config.LegacyTree do
			local level = Config.legacy(d, def.id)
			if level < def.maxLevel and (not def.requires or Config.legacy(d, def.requires) >= 1) then
				local cost = Config.legacyCost(def.id, level)
				if cost < bestCost then best, bestCost = def.id, cost end
			end
		end
		if not best or bestCost > d.legacy then return end
		d.legacy -= bestCost
		d.legacyTree[best] = Config.legacy(d, best) + 1
	end
end
local function resetRun()
	d.money = Config.startMoney(d)
	d.totalEarned = 0
	d.reputation = Config.startReputation(d)
	d.sites = {}
	d.project = nil
	d.companies = if Config.research(d, "autolab") > 0 then { ia_lab = 1 } else {}
	d.unlockedAds = { adsimple = true }
	d.maintenance = 0
	contracts = {}
end
local runStart = 0
local log = {}
local function mark(key, text)
	if not log[key] then
		log[key] = now
		print(string.format("%6s  %s", Config.formatTime(now), text))
	end
end
local function ipo()
	finishDeals(true)
	local n = Config.sharesForIpo(d.totalEarned, d)
	if DEBUG_IPO then
		print(string.format("   [ipo] partida %s · acciones %d · ganado %s · dinero x%.3g · ingresos %s/s · webs %d (mejor %s) · empresas %d · maint %s/s · encargos %s",
			Config.formatTime(now - runStart), d.shares, Config.formatMoney(d.totalEarned), Config.moneyMult(d, bonuses), Config.formatMoney(income()), #d.sites,
			(function() local b = "-" for _, x in d.sites do b = x.type end return b end)(), (function() local c=0 for _,v in d.companies do c+=v end return c end)(),
			Config.formatMoney(Config.maintenanceIncome(d)), Config.formatMoney(contractIncome)))
	end
	d.patents += Config.patentsForShares(n, d)
	resetRun()
	d.shares += n
	d.ipoCount += 1
	d.eraIpos += 1
	runStart = now
	buyResearch()
	mark("ipo" .. d.ipoCount, string.format("salida a bolsa nº %d (era %d): +%d acciones → %d · patentes libres %d", d.ipoCount, d.era, n, d.shares, d.patents))
end
local function fusion()
	local legacy = Config.legacyForShares(d.shares)
	finishDeals(true)
	resetRun()
	d.shares = 0
	d.legacy += legacy
	d.era += 1
	d.eraIpos = 0
	d.eraEarned = 0
	d.fusions += 1
	runStart = now
	buyLegacy()
	mark("fusion" .. d.fusions, string.format("FUSIÓN nº %d → Era %d (+%d 🧬 Legado)", d.fusions, d.era, legacy))
end
-- ¿Merece la pena salir a bolsa ya? (cuando el bonus de acciones crece bastante)
local function shouldIpo(): boolean
	local n = Config.sharesForIpo(d.totalEarned, d)
	if n < 10 then return false end
	local ratio = Config.shareMult(d, d.shares + n) / Config.shareMult(d, d.shares)
	local runTime = now - runStart
	return ratio >= 2 or (runTime > 2.5 * 3600 and ratio >= 1.25)
end
local function shouldFuse(): boolean
	local req = Config.fusionRequirement(d)
	return req ~= nil and d.eraIpos >= req.ipos and d.eraEarned >= req.earned
end

local milestones = { 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e12, 1e15, 1e18 }
local mi = 1
local typeSeen = {}
local offerTimer = 0
for t = 1, HOURS * 3600 do
	now = t
	finishDeals(false)
	-- trabajo
	if not d.project and CAREER and contracts[1] and d.money >= Config.WebTypeById[contracts[1].type].cost then
		local def = Config.WebTypeById[contracts[1].type]
		d.money -= def.cost; d.project = { type = def.id, progress = 0, required = def.work, contract = true }
	end
	if not d.project then
		local def = bestType()
		if def and #d.sites < Config.slots(d) then
			d.money -= def.cost; d.project = { type = def.id, progress = 0, required = def.work }
		elseif #d.sites >= Config.slots(d) then
			-- sin huecos: vende la peor web si hay una mejor disponible
			local def2 = nil
			for _, ty in Config.WebTypes do if Config.eraAllows(d, ty) and d.reputation >= ty.rep then def2 = ty end end
			local worst, wi = math.huge, nil
			for i, s in d.sites do local v = Config.WebTypeById[s.type].order; if not s.dealAt and v < worst then worst, wi = v, i end end
			if wi and def2 and def2.order > worst then sell(wi, 1.3) end -- vende a un cliente medio
		end
	end
	if d.project then
		d.project.progress += Config.workPerSec(d, bonuses) + CLICKS_PER_SEC * Config.clickPower(d)
		if d.project.progress >= d.project.required then
			local def = Config.WebTypeById[d.project.type]
			local wasContract = d.project.contract
			d.project = nil
			if wasContract then
				local c = table.remove(contracts, 1)
				gain(c.pay); contractIncome += c.pay
				d.reputation += def.repReward * Career.CONTRACT_REP
				career.xp.ecommerce = (career.xp.ecommerce or 0) + def.work / 5 * (1 + Career.CONTRACT_XP)
				career.stats.contracts += 1
				d.stats.built += 1
				continue
			end
			table.insert(d.sites, { id = d.nextId, type = def.id, quality = (0.85 + math.random()*0.3) * (1 + 0.08*Config.level(d,"design")), seo = 0, network = bestNet(), adLevel = 2 })
			d.nextId += 1; d.stats.built += 1; d.reputation += Config.repReward(d, def)
			career.xp.ecommerce = (career.xp.ecommerce or 0) + def.work / 5
			if not typeSeen[def.id] then typeSeen[def.id] = true; mark("type_" .. def.id, string.format("primera %s (rep %s, %d webs, era %d)", def.name, Config.formatNumber(d.reputation), #d.sites, d.era)) end
		end
	end
	-- ofertas de clientes: cada ~45 s, para un tipo que tienes
	offerTimer += 1
	if offerTimer >= Config.OFFER_INTERVAL and #d.sites > 0 then
		offerTimer = 0
		local ty = d.sites[math.random(1, #d.sites)].type
		local mult = 0.9 + math.random() * 0.9 + math.min(Config.level(d, "comercial") * 0.03, 0.9)
		if mult >= 1.3 then
			local worst, wi = math.huge, nil
			for i, s in d.sites do if not s.dealAt and s.type == ty and s.quality < worst then worst, wi = s.quality, i end end
			if wi then sell(wi, mult) end
		end
	end
	gain(income())
	if CAREER then
		-- Tablón: un encargo cada ~90 s; el bot coge los de su nicho (~65 %)
		boardTimer += 1
		local rank = Career.Ranks[Career.rankOf(career)]
		if boardTimer >= 90 then
			boardTimer = 0
			local types = {}
			for _, ty in Config.WebTypes do if Config.eraAllows(d, ty) and d.reputation >= ty.rep then table.insert(types, ty) end end
			local ty = types[math.random(math.max(1, #types - 2), #types)]
			if #contracts < rank.slots and math.random() < 0.65 then
				local site = { type = ty.id, quality = 1, seo = 0, design = 0, network = "adsimple", adLevel = 1 }
				local pay = Config.saleBase(d, site, Config.moneyMult(d, bonuses), bonuses) * Career.CONTRACT_PAY * rank.payMult * 1.05
				table.insert(contracts, { type = ty.id, pay = pay })
			end
		end
		if not career.agency and Career.devLevel(career) >= 8 and d.money > 2500 then
			d.money -= 2500; career.agency = { officeLevel = 1 }
			mark("agency", "funda agencia")
		end
		if career.agency then
			local cost = Career.recruitCost(income())
			if #career.programmers < Career.officeCapacity(career.agency.officeLevel) and d.money > cost * 2 then
				d.money -= cost
				local total, roll = 0, 0
				for _, r in Career.Rarities do total += r.weight end
				roll = math.random() * total
				local pick = Career.Rarities[1]
				for _, r in Career.Rarities do roll -= r.weight; if roll <= 0 then pick = r; break end end
				table.insert(career.programmers, { rarity = pick.id, niche = "ecommerce", level = 1, role = Career.Roles[math.random(1, #Career.Roles)].id })
			end
			local up = Career.officeUpgradeCost(career.agency.officeLevel + 1)
			if career.agency.officeLevel < Career.MAX_OFFICE_LEVEL and d.money > up * 3 then d.money -= up; career.agency.officeLevel += 1 end
			local work, totals = Career.agencyTotals(career, "ecommerce", false, false)
			bonuses.agencyWork, bonuses.agencyBonus = work, totals.money
			bonuses.agencyVisits, bonuses.agencySale, bonuses.agencyQuality = totals.visits, totals.sale, totals.quality
		end
	end
	-- compras: lo más barato que tenga sentido (deja dinero para el siguiente proyecto)
	for _ = 1, 5 do
		local options = {}
		for _, c in Config.Companies do local lv = Config.level(d, c.id); if lv < c.maxLevel and Config.eraAllows(d, c) then table.insert(options, { kind = "c", id = c.id, cost = Config.companyCost(c.id, lv) }) end end
		for _, n in Config.AdNetworks do if not d.unlockedAds[n.id] and d.reputation >= n.rep and Config.eraAllows(d, n) then table.insert(options, { kind = "n", id = n.id, cost = n.cost }) end end
		for _, s in d.sites do if s.seo < Config.MAX_SEO then table.insert(options, { kind = "s", site = s, cost = Config.seoCost(s) }) end end
		table.sort(options, function(a, b) return a.cost < b.cost end)
		local o = options[1]
		if not o or o.cost > d.money * 0.8 then break end
		d.money -= o.cost
		if o.kind == "c" then d.companies[o.id] = Config.level(d, o.id) + 1
		elseif o.kind == "n" then d.unlockedAds[o.id] = true; for _, s in d.sites do s.network = bestNet() end
		else o.site.seo += 1 end
	end
	while mi <= #milestones and d.lifetimeEarned >= milestones[mi] do
		mark("earned" .. mi, string.format("ganado %s · %s/s · rep %s · webs %d/%d · niveles empresas %d", Config.formatMoney(milestones[mi]), Config.formatMoney(income()), Config.formatNumber(d.reputation), #d.sites, Config.slots(d), (function() local n=0 for _,v in d.companies do n+=v end return n end)()))
		mi += 1
	end
	-- Prestigio: la Fusión primero (saliendo a bolsa justo antes si compensa)
	if t % 10 == 0 then
		if shouldFuse() then
			if Config.sharesForIpo(d.totalEarned, d) >= 10 then ipo() end
			if shouldFuse() then fusion() end
		elseif shouldIpo() then
			ipo()
		end
	end
end
print(string.format("Al final (%d h): era %d · %d salidas a bolsa · %d acciones · %d Fusiones · Legado libre %d · ganado en total %s",
	HOURS, d.era, d.ipoCount, d.shares, d.fusions, d.legacy, Config.formatMoney(d.lifetimeEarned)))
print(string.format("Encargos entregados: %d · rango %s · cobrado por encargos %s", career.stats.contracts, Career.Ranks[Career.rankOf(career)].name, Config.formatMoney(contractIncome)))
-- Tabla resumen (tiempo de juego de un bot perfecto)
local function at(key)
	return if log[key] then Config.formatTime(log[key]) else "—"
end
print("RESUMEN | $1M " .. at("earned4") .. " | $1B " .. at("earned7") .. " | 1ª salida a bolsa " .. at("ipo1")
	.. " | 1ª Fusión " .. at("fusion1") .. " | Era 3 " .. at("fusion2"))
