--[[
	WorldEvents (ModuleScript en ServerScriptService)

	Eventos aleatorios de cada jugador, eventos del servidor y meta común.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local PlotManager = require(ServerScriptService:WaitForChild("PlotManager"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local SiteService = require(ServerScriptService:WaitForChild("SiteService"))

local communityProgress = ServerState.communityProgress
local gain = ServerState.gain
local notify = ServerState.notify
local notifyAll = ServerState.notifyAll
local random = ServerState.random
local sessions = ServerState.sessions
local world = ServerState.world
type Session = ServerState.Session
local computeIncome = Economy.computeIncome
local incomeReward = Economy.incomeReward
local addSeasonXp = RewardService.addSeasonXp
local makeOffer = SiteService.makeOffer

local WorldEvents = {}

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
		local amount = math.max(50, session.income * 90) * Config.REWARD_SCALE
		gain(data, amount, "eventos")
		notify(player, chosen.name .. ": +" .. Config.formatMoney(amount), "money")
	elseif chosen.id == "vip" then
		table.insert(session.offers, 1, makeOffer(session, 3.5))
		notify(player, chosen.name, "event")
	end
end

---------------------------------------------------------------------
-- Acciones que puede pedir el cliente
---------------------------------------------------------------------

local nextServerEventAt = os.clock() + random:NextNumber(Config.SERVER_EVENT_MIN_DELAY, Config.SERVER_EVENT_MAX_DELAY) / 2

local nextCommunityAt = os.clock() + 60

local function updateServerEvent(now: number)
	if world.serverEvent and now >= world.serverEvent.endsAt then
		local def = Config.ServerEventById[world.serverEvent.id]
		world.serverEvent = nil
		PlotManager.setEventTint(nil)
		notifyAll(string.format("%s %s ha terminado", def.emoji, def.name), "info")
	end
	if not world.serverEvent and now >= nextServerEventAt and next(sessions) ~= nil then
		nextServerEventAt = now + random:NextNumber(Config.SERVER_EVENT_MIN_DELAY, Config.SERVER_EVENT_MAX_DELAY)
		local total = 0
		for _, def in Config.ServerEvents do
			total += def.weight
		end
		local roll = random:NextNumber() * total
		local chosen = Config.ServerEvents[1]
		for _, def in Config.ServerEvents do
			roll -= def.weight
			if roll <= 0 then
				chosen = def
				break
			end
		end
		world.serverEvent = { id = chosen.id, endsAt = now + chosen.duration }
		PlotManager.setEventTint(chosen.tint)
		notifyAll(string.format("%s ¡EVENTO DEL SERVIDOR: %s! %s", chosen.emoji, chosen.name, chosen.desc), "event")
	end
end

local function updateCommunity(now: number)
	if world.community then
		-- Los que entran a mitad también cuentan desde que llegan
		for player, session in sessions do
			if world.community.start[player] == nil then
				world.community.start[player] = session.data.lifetimeEarned
			end
		end
		if communityProgress() >= world.community.target then
			for player in world.community.start do
				local session = sessions[player]
				if session then
					local amount = incomeReward(session, Config.COMMUNITY_REWARD_MINUTES, 500)
					gain(session.data, amount, "meta")
					addSeasonXp(player, session, Config.SeasonXp.community)
					notify(player, "🤝 ¡Meta del servidor conseguida! Premio para todos: +" .. Config.formatMoney(amount), "money")
				end
			end
			world.community = nil
			nextCommunityAt = now + Config.COMMUNITY_COOLDOWN
		elseif now >= world.community.endsAt then
			world.community = nil
			nextCommunityAt = now + Config.COMMUNITY_COOLDOWN
			notifyAll("🤝 Esta vez no se llegó a la meta del servidor. ¡Viene otra!", "info")
		end
	elseif now >= nextCommunityAt and next(sessions) ~= nil then
		local incomes = 0
		local start = {}
		for player, session in sessions do
			incomes += computeIncome(session, false)
			start[player] = session.data.lifetimeEarned
		end
		local target = math.max(Config.COMMUNITY_MIN_TARGET, incomes * Config.COMMUNITY_TARGET_SECONDS)
		world.community = {
			target = target,
			endsAt = now + Config.COMMUNITY_DURATION,
			start = start,
		}
		notifyAll("🤝 ¡Nueva meta del servidor! Ganad " .. Config.formatMoney(target) .. " entre todos en " .. Config.formatTime(Config.COMMUNITY_DURATION), "event")
	end
end

WorldEvents.triggerEvent = triggerEvent
WorldEvents.updateCommunity = updateCommunity
WorldEvents.updateServerEvent = updateServerEvent

return WorldEvents
