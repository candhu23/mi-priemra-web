-- Simulador de balance: un "jugador bot" razonable, 1 tick = 1 s
Color3 = { fromRGB = function() return {} end }
local Config = require("./TycoonConfig")
local Career = require("./CareerConfig")
local CAREER = (...) ~= "nocareer"
local career = { xp = {}, programmers = {}, agency = nil, pity = 0, stats = { contracts = 0 } }
local bonuses = { agencyWork = 0, agencyBonus = 0, agencyVisits = 0, agencySale = 0, agencyQuality = 0 }
-- Encargos: el bot acepta uno cuando tiene hueco y llega al tablón (~cada 90 s)
local contracts = {}
local boardTimer = 0
local contractIncome = 0
local CLICKS_PER_SEC = 4
math.randomseed(42)

local d = { money = Config.STARTING_MONEY, totalEarned = 0, reputation = 0, shares = 0, ipoCount = 0,
	sites = {}, project = nil, companies = {}, unlockedAds = { adsimple = true }, maintenance = 0,
	stats = { built = 0, sold = 0 }, nextId = 1 }

local function gain(x) d.money += x; d.totalEarned += x end
local function income()
	local mm = Config.moneyMult(d, bonuses)
	local t = 0
	for _, s in d.sites do t += Config.siteIncome(d, s, Config.siteVisits(d, s, 1 + bonuses.agencyVisits), mm) end
	return t + Config.companiesIncome(d, mm) + d.maintenance
end
local function bestNet()
	local best, bv = "adsimple", 0
	for id in d.unlockedAds do local n = Config.AdNetworkById[id]; local v = n.rpv*(1-n.penalty); if v > bv then best, bv = id, v end end
	return best
end
local function bestType()
	local best
	for _, t in Config.WebTypes do if d.reputation >= t.rep and d.money >= t.cost then best = t end end
	return best
end
-- Las ventas a clientes tardan (negociación) y hay un máximo a la vez
local now = 0
local function dealsActive()
	local n = 0
	for _, s in d.sites do if s.dealAt then n += 1 end end
	return n
end
local function finishSale(i, price)
	local s = d.sites[i]
	table.remove(d.sites, i)
	gain(price); d.maintenance += price * Config.MAINTENANCE_RATE
	d.reputation += Config.WebTypeById[s.type].repReward; d.stats.sold += 1
end
local function sell(i, mult)
	local s = d.sites[i]
	if s.dealAt or dealsActive() >= Config.maxDeals(d) then return end
	s.dealPrice = Config.saleBase(d, s, Config.moneyMult(d, bonuses), bonuses) * mult
	s.dealAt = now + Config.dealSeconds(d, s.type)
end
local function finishDeals()
	for i = #d.sites, 1, -1 do
		local s = d.sites[i]
		if s.dealAt and now >= s.dealAt then finishSale(i, s.dealPrice) end
	end
end

local milestones = { 1e3, 1e4, 1e5, 1e6, 1e7, 1e8 }
local mi = 1
local typeSeen = {}
local offerTimer = 0
for t = 1, 6 * 3600 do
	now = t
	finishDeals()
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
			for _, ty in Config.WebTypes do if d.reputation >= ty.rep then def2 = ty end end
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
			d.nextId += 1; d.stats.built += 1; d.reputation += def.repReward
			career.xp.ecommerce = (career.xp.ecommerce or 0) + def.work / 5
			if not typeSeen[def.id] then typeSeen[def.id] = true; print(string.format("%6s  primera %s (rep %d, %d webs)", Config.formatTime(t), def.name, d.reputation, #d.sites)) end
		end
	end
	-- ofertas de clientes: cada ~25 s, para un tipo que tienes
	offerTimer += 1
	if offerTimer >= 25 and #d.sites > 0 then
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
			for _, ty in Config.WebTypes do if d.reputation >= ty.rep then table.insert(types, ty) end end
			local ty = types[math.random(math.max(1, #types - 2), #types)]
			if #contracts < rank.slots and math.random() < 0.65 then
				local site = { type = ty.id, quality = 1, seo = 0, design = 0, network = "adsimple", adLevel = 1 }
				local pay = Config.saleBase(d, site, Config.moneyMult(d, bonuses), bonuses) * Career.CONTRACT_PAY * rank.payMult * 1.05
				table.insert(contracts, { type = ty.id, pay = pay })
			end
		end
		if not career.agency and Career.devLevel(career) >= 8 and d.money > 2500 then
			d.money -= 2500; career.agency = { officeLevel = 1 }
			print(string.format("%6s  funda agencia", Config.formatTime(t)))
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
		for _, c in Config.Companies do local lv = Config.level(d, c.id); if lv < c.maxLevel then table.insert(options, { kind = "c", id = c.id, cost = Config.companyCost(c.id, lv) }) end end
		for _, n in Config.AdNetworks do if not d.unlockedAds[n.id] and d.reputation >= n.rep then table.insert(options, { kind = "n", id = n.id, cost = n.cost }) end end
		for _, s in d.sites do if s.seo < Config.MAX_SEO then table.insert(options, { kind = "s", site = s, cost = Config.seoCost(s) }) end end
		table.sort(options, function(a, b) return a.cost < b.cost end)
		local o = options[1]
		if not o or o.cost > d.money * 0.8 then break end
		d.money -= o.cost
		if o.kind == "c" then d.companies[o.id] = Config.level(d, o.id) + 1
		elseif o.kind == "n" then d.unlockedAds[o.id] = true; for _, s in d.sites do s.network = bestNet() end
		else o.site.seo += 1 end
	end
	while mi <= #milestones and d.totalEarned >= milestones[mi] do
		print(string.format("%6s  ganado %s · %s/s · rep %d · webs %d/%d · niveles empresas %d", Config.formatTime(t), Config.formatMoney(milestones[mi]), Config.formatMoney(income()), d.reputation, #d.sites, Config.slots(d), (function() local n=0 for _,v in d.companies do n+=v end return n end)()))
		local seo=0 for _,x in d.sites do seo+=x.seo end
		local mm = Config.moneyMult(d,false); local si=0 for _,x in d.sites do si += Config.siteIncome(d,x,Config.siteVisits(d,x,1),mm) end
		print(string.format("        webs %s/s · empresas %s/s · mantenimiento %s/s · vendidas %d", Config.formatMoney(si), Config.formatMoney(Config.companiesIncome(d,mm)), Config.formatMoney(d.maintenance), d.stats.sold))
		print(string.format("        mkt %d · diseño %d · comercial %d · adnet %d · hosting %d · devs %d · SEO medio %.1f · app %s", Config.level(d,"marketing"), Config.level(d,"design"), Config.level(d,"comercial"), Config.level(d,"adnet"), Config.level(d,"hosting"), Config.level(d,"devs"), #d.sites>0 and seo/#d.sites or 0, bestNet()))
		mi += 1
	end
end
print("Acciones al salir a bolsa tras 6h:", Config.sharesForIpo(d.totalEarned))
print(string.format("Encargos entregados: %d · rango %s · cobrado por encargos %s", career.stats.contracts, Career.Ranks[Career.rankOf(career)].name, Config.formatMoney(contractIncome)))
