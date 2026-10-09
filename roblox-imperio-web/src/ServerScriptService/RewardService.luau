--[[
	RewardService (ModuleScript en ServerScriptService)

	Misiones diarias y semanales, objetivos, pase de temporada, premios
	por tiempo, recompensa diaria, regalo, códigos e I+D.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Validate = require(ReplicatedStorage:WaitForChild("Validate"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))
local Analytics = require(ServerScriptService:WaitForChild("Analytics"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))

local gain = ServerState.gain
local notify = ServerState.notify
local random = ServerState.random
type Session = ServerState.Session
local incomeReward = Economy.incomeReward
local refreshBoost = Economy.refreshBoost

local RewardService = {}
local Actions = {}

-- Se define más abajo (misiones diarias), pero se usa al terminar webs
local progressDaily: (session: Session, stat: string, amount: number) -> ()

---------------------------------------------------------------------
-- Proyectos (webs en construcción)
---------------------------------------------------------------------

-- Los objetivos ya no se pagan solos: avisan y se reclaman en Misiones.
-- data.goals[id] = true significa "premio reclamado".
local function checkGoals(player: Player, session: Session)
	local data = session.data
	for _, goal in Config.Goals do
		if not data.goals[goal.id] and not session.goalNotified[goal.id] and goal.value(data) >= goal.target then
			session.goalNotified[goal.id] = true
			notify(player, "🎯 ¡Objetivo cumplido: " .. goal.text .. "! Reclama tu premio en 🎯 Misiones", "goal")
		end
	end
end

---------------------------------------------------------------------
-- Misiones diarias
---------------------------------------------------------------------

local function ensureDailyMissions(session: Session)
	local data = session.data
	local today = Config.dayIndex(os.time())
	local daily = data.dailyMissions
	if daily.day == today and #daily.list > 0 then
		return
	end
	local pool = {}
	for _, def in Config.DailyMissionPool do
		local available = (def.needs == nil)
			or (def.needs == "career" and Config.isUnlocked(data, "career"))
			or (def.needs == "agency" and data.career.agency ~= nil)
		if available then
			table.insert(pool, def)
		end
	end
	local list = {}
	-- 2 fáciles, 2 medias y 2 difíciles
	for i = 1, math.min(Config.DAILY_MISSION_COUNT, #pool) do
		local tier = math.clamp((i + 1) // 2, 1, #Config.DailyMissionRewards)
		local def = table.remove(pool, random:NextInteger(1, #pool))
		table.insert(list, { id = def.id, tier = tier, target = def.amounts[tier], progress = 0, claimed = false })
	end
	daily.day = today
	daily.list = list
	daily.bonusGiven = false
end

function progressDaily(session: Session, stat: string, amount: number)
	-- Cuenta para las misiones diarias y para las semanales
	for _, list in { session.data.dailyMissions.list, session.data.weeklyMissions.list } do
		for _, mission in list do
			if mission.id == stat and not mission.claimed then
				mission.progress = math.min(mission.target, mission.progress + amount)
			end
		end
	end
end

-- Misiones semanales: 4 nuevas cada lunes
local function ensureWeeklyMissions(session: Session)
	local data = session.data
	local week = Config.weekIndex(os.time())
	local weekly = data.weeklyMissions
	if weekly.week == week and #weekly.list > 0 then
		return
	end
	local pool = {}
	for _, def in Config.WeeklyMissionPool do
		local available = (def.needs == nil)
			or (def.needs == "career" and Config.isUnlocked(data, "career"))
			or (def.needs == "agency" and data.career.agency ~= nil)
		if available then
			table.insert(pool, def)
		end
	end
	local list = {}
	for _ = 1, math.min(Config.WEEKLY_MISSION_COUNT, #pool) do
		local def = table.remove(pool, random:NextInteger(1, #pool))
		table.insert(list, { id = def.id, target = def.amount, progress = 0, claimed = false })
	end
	data.weeklyMissions = { week = week, list = list, bonusGiven = false }
end

-- Para misiones de "llega a X" (el combo): se queda con el mejor valor
local function progressDailyMax(session: Session, stat: string, value: number)
	for _, mission in session.data.dailyMissions.list do
		if mission.id == stat and not mission.claimed then
			mission.progress = math.min(mission.target, math.max(mission.progress, value))
		end
	end
end

---------------------------------------------------------------------
-- Pase de temporada
---------------------------------------------------------------------

-- Si ha empezado otra temporada, se empieza de cero
local function ensureSeason(session: Session)
	local current = Config.seasonIndex(os.time())
	local season = session.data.season
	if season.id ~= current then
		session.data.season = { id = current, xp = 0, free = {}, premiumClaimed = {}, premium = false }
	end
end

local function seasonTier(xp: number): number
	return math.min(Config.SEASON_TIERS, xp // Config.SEASON_XP_PER_TIER)
end

local function addSeasonXp(player: Player, session: Session, amount: number)
	ensureSeason(session)
	local season = session.data.season
	local before = seasonTier(season.xp)
	season.xp += amount
	local after = seasonTier(season.xp)
	if after > before then
		notify(player, string.format("🎫 ¡Nivel %d del pase de temporada! Recoge tu premio en 🎫 Pase", after), "goal")
	end
end

-- Devuelve (disponible, día de la racha que tocaría 1..7)
local function dailyStatus(data): (boolean, number)
	local today = Config.dayIndex(os.time())
	local daily = data.daily
	if daily.lastDay == today then
		return false, daily.streak
	end
	if daily.lastDay == today - 1 then
		return true, daily.streak % #Config.DailyRewards + 1
	end
	return true, 1
end

---------------------------------------------------------------------
-- Estado que se envía al cliente
---------------------------------------------------------------------

function Actions.claimGoal(player: Player, session: Session, goalId: any)
	local data = session.data
	for _, goal in Config.Goals do
		if goal.id == goalId then
			if data.goals[goal.id] then
				return false, "Ya lo has reclamado."
			end
			if goal.value(data) < goal.target then
				return false, "Aún no has cumplido este objetivo."
			end
			data.goals[goal.id] = true
			if goal.reward > 0 then
				data.money += goal.reward
				Analytics.track(data, "Source", "objetivos", goal.reward)
			end
			addSeasonXp(player, session, Config.SeasonXp.goal)
			return true, "🎯 " .. goal.text .. (if goal.reward > 0 then ": +" .. Config.formatMoney(goal.reward) else ""), { money = goal.reward > 0 }
		end
	end
	return false, nil
end

function Actions.claimDailyMission(player: Player, session: Session, index: any)
	ensureDailyMissions(session)
	local daily = session.data.dailyMissions
	local mission = Validate.integer(index, 1, #daily.list) and daily.list[index]
	if not mission then
		return false, nil
	end
	if mission.claimed then
		return false, "Ya la has reclamado."
	end
	if mission.progress < mission.target then
		return false, "Aún no has terminado esta misión."
	end
	local reward = Config.DailyMissionRewards[mission.tier]
	local amount = incomeReward(session, reward.minutes, reward.min)
	gain(session.data, amount, "misiones")
	mission.claimed = true
	session.data.stats.missions = (session.data.stats.missions or 0) + 1
	progressDaily(session, "missions", 1)
	addSeasonXp(player, session, Config.SeasonXp.dailyMission[mission.tier] or 60)
	local allDone = true
	for _, m in daily.list do
		if not m.claimed then
			allDone = false
		end
	end
	if allDone and not daily.bonusGiven then
		daily.bonusGiven = true
		local data = session.data
		data.boostUntil = math.max(data.boostUntil, os.time()) + Config.DAILY_ALL_BONUS_BOOST_MINUTES * 60
		refreshBoost(session)
		notify(player, "🏆 ¡Todas las misiones de hoy completadas! 🚀 Boost x2 " .. Config.DAILY_ALL_BONUS_BOOST_MINUTES .. " min", "goal")
	end
	return true, "📅 Misión completada: +" .. Config.formatMoney(amount), { money = true }
end

function Actions.claimWeeklyMission(player: Player, session: Session, index: any)
	ensureWeeklyMissions(session)
	local data = session.data
	local weekly = data.weeklyMissions
	local mission = Validate.integer(index, 1, #weekly.list) and weekly.list[index]
	if not mission then
		return false, nil
	end
	if mission.claimed then
		return false, "Ya la has reclamado."
	end
	if mission.progress < mission.target then
		return false, "Aún no has terminado esta misión."
	end
	local reward = Config.WeeklyMissionReward
	local amount = incomeReward(session, reward.minutes, reward.min)
	gain(data, amount, "misiones")
	mission.claimed = true
	data.stats.missions = (data.stats.missions or 0) + 1
	addSeasonXp(player, session, reward.seasonXp)
	local allDone = true
	for _, m in weekly.list do
		if not m.claimed then
			allDone = false
		end
	end
	if allDone and not weekly.bonusGiven then
		weekly.bonusGiven = true
		data.patents += Config.WEEKLY_ALL_PATENTS
		data.boostUntil = math.max(data.boostUntil, os.time()) + Config.WEEKLY_ALL_BOOST_MINUTES * 60
		refreshBoost(session)
		notify(player, string.format("🗓️ ¡Todas las misiones de la semana completadas! +%d 💡 patentes y 🚀 Boost x2 %d min",
			Config.WEEKLY_ALL_PATENTS, Config.WEEKLY_ALL_BOOST_MINUTES), "goal")
	end
	return true, "🗓️ Misión semanal completada: +" .. Config.formatMoney(amount), { money = true }
end

-- El cliente avisa de cada paso del tutorial que enseña (para el embudo)
function Actions.tutorialStep(player: Player, session: Session, step: any)
	if not Validate.integer(step, 1, 30) then
		return false, nil
	end
	local seen = session.tutorialSteps
	if seen[step] then
		return true, nil
	end
	seen[step] = true
	local data = session.data
	Analytics.funnel(player, "Tutorial", player.UserId .. "-" .. (data.firstJoin or 0), step, "Paso " .. step)
	return true, nil
end

function Actions.finishTutorial(player: Player, session: Session)
	local data = session.data
	if data.tutorialDone then
		return true, nil
	end
	data.tutorialDone = true
	data.money += Config.TUTORIAL_REWARD
	Analytics.track(data, "Source", "tutorial", Config.TUTORIAL_REWARD)
	Analytics.onboarding(player, data, "tutorial")
	return true, "🎓 ¡Tutorial completado! +" .. Config.formatMoney(Config.TUTORIAL_REWARD), { money = true }
end

function Actions.claimDaily(player: Player, session: Session)
	local data = session.data
	local available, day = dailyStatus(data)
	if not available then
		return false, "Ya has recogido la recompensa de hoy. ¡Vuelve mañana!"
	end
	local def = Config.DailyRewards[day]
	local amount = incomeReward(session, def.minutes, def.min)
	gain(data, amount, "diaria")
	data.daily.lastDay = Config.dayIndex(os.time())
	data.daily.streak = day
	local extra = ""
	if def.boostMinutes then
		data.boostUntil = math.max(data.boostUntil, os.time()) + def.boostMinutes * 60
		refreshBoost(session)
		extra = " + 🚀 Boost x2 " .. def.boostMinutes .. " min"
	end
	notify(player, string.format("📅 Día %d: +%s%s", day, Config.formatMoney(amount), extra), "money")
	return true, nil, { money = true }
end

function Actions.claimGift(player: Player, session: Session)
	if os.clock() < session.giftReadyAt then
		return false, "Tu regalo aún no está listo."
	end
	local amount = incomeReward(session, Config.GIFT_MINUTES, Config.GIFT_MIN)
	gain(session.data, amount, "regalo")
	session.giftReadyAt = os.clock() + Config.GIFT_INTERVAL
	notify(player, "🎁 Regalo: +" .. Config.formatMoney(amount), "money")
	return true, nil, { money = true }
end

-- Da un premio { kind = cash|boost|ticket|patents } y devuelve cómo se llama
local function giveReward(player: Player, session: Session, reward): string
	local data = session.data
	if reward.kind == "cash" then
		local amount = incomeReward(session, reward.minutes or 5, reward.min or 500)
		gain(data, amount, "premios")
		return "+" .. Config.formatMoney(amount)
	elseif reward.kind == "boost" then
		local minutes = reward.minutes or 10
		data.boostUntil = math.max(data.boostUntil, os.time()) + minutes * 60
		refreshBoost(session)
		return "🚀 Boost x2 " .. minutes .. " min"
	elseif reward.kind == "ticket" then
		local tickets = data.career.tickets
		tickets[reward.ticket] = (tickets[reward.ticket] or 0) + reward.amount
		return if reward.ticket == "legendary" then "👑 +" .. reward.amount .. " Contrato Legendario" else "🎯 +" .. reward.amount .. " Headhunter Premium"
	elseif reward.kind == "patents" then
		data.patents += reward.amount
		return "💡 +" .. reward.amount .. " patentes"
	end
	return ""
end

function Actions.buyResearch(player: Player, session: Session, researchId: any)
	local def = type(researchId) == "string" and Config.ResearchById[researchId]
	if not def then
		return false, nil
	end
	local data = session.data
	local level = Config.research(data, def.id)
	if level >= def.maxLevel then
		return false, "Nivel máximo."
	end
	local cost = Config.researchCost(def.id, level)
	if data.patents < cost then
		return false, "Te faltan patentes. Se consiguen al salir a bolsa."
	end
	data.patents -= cost
	data.research[def.id] = level + 1
	CareerService.refreshBonuses(session)
	return true, string.format("💡 %s %s: nivel %d", def.emoji, def.name, level + 1)
end

function Actions.claimSeason(player: Player, session: Session, tier: any, premium: any)
	ensureSeason(session)
	local season = session.data.season
	if not Validate.integer(tier, 1, Config.SEASON_TIERS) then
		return false, nil
	end
	if seasonTier(season.xp) < tier then
		return false, "Aún no has llegado a ese nivel del pase."
	end
	local key = tostring(tier)
	if premium == true then
		if not season.premium then
			return false, "Necesitas el Pase de temporada Premium."
		end
		if season.premiumClaimed[key] then
			return false, "Ya lo has recogido."
		end
		season.premiumClaimed[key] = true
	else
		if season.free[key] then
			return false, "Ya lo has recogido."
		end
		season.free[key] = true
	end
	local text = giveReward(player, session, Config.seasonReward(tier, premium == true))
	return true, string.format("🎫 Nivel %d: %s", tier, text), { money = true }
end

-- Tiempo jugado hoy (se reinicia cada día UTC)
local function ensurePlaytime(data)
	local today = Config.dayIndex(os.time())
	if data.playtime.day ~= today then
		data.playtime = { day = today, seconds = 0, claimed = {} }
	end
end

function Actions.claimPlaytime(player: Player, session: Session, index: any)
	local data = session.data
	ensurePlaytime(data)
	local def = Validate.integer(index, 1, #Config.PlaytimeRewards) and Config.PlaytimeRewards[index]
	if not def then
		return false, nil
	end
	local key = tostring(index)
	if data.playtime.claimed[key] then
		return false, "Ya lo has recogido."
	end
	if data.playtime.seconds < def.atMinutes * 60 then
		return false, "Aún no has jugado suficiente hoy."
	end
	data.playtime.claimed[key] = true
	local text = giveReward(player, session, def)
	addSeasonXp(player, session, Config.SeasonXp.playtime)
	return true, string.format("⏱️ %d min jugados: %s", def.atMinutes, text), { money = true }
end

function Actions.redeemCode(player: Player, session: Session, text: any)
	if not Validate.text(text, 40) then
		return false, nil
	end
	local code = string.upper((string.gsub(text, "%s", "")))
	local def = Config.CodeByCode[code]
	if not def or (def.expires and os.time() > def.expires) then
		return false, "Ese código no existe o ha caducado."
	end
	local data = session.data
	if data.codes[code] then
		return false, "Ya has usado ese código."
	end
	data.codes[code] = true
	Analytics.event(player, "Codigo", 1, { codigo = code })
	local parts = { giveReward(player, session, { kind = "cash", minutes = def.minutes, min = def.min }) }
	if def.boostMinutes then
		table.insert(parts, giveReward(player, session, { kind = "boost", minutes = def.boostMinutes }))
	end
	return true, "🎟️ Código canjeado: " .. table.concat(parts, " · "), { money = true }
end

RewardService.addSeasonXp = addSeasonXp
RewardService.checkGoals = checkGoals
RewardService.dailyStatus = dailyStatus
RewardService.ensureDailyMissions = ensureDailyMissions
RewardService.ensurePlaytime = ensurePlaytime
RewardService.ensureSeason = ensureSeason
RewardService.ensureWeeklyMissions = ensureWeeklyMissions
RewardService.giveReward = giveReward
RewardService.progressDaily = progressDaily
RewardService.progressDailyMax = progressDailyMax
RewardService.seasonTier = seasonTier
RewardService.Actions = Actions

return RewardService
