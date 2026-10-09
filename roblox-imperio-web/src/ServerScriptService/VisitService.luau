--[[
	VisitService (ModuleScript en ServerScriptService)

	Visitar imperios, "me gusta" y bonus por jugar con amigos.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Career = require(ReplicatedStorage:WaitForChild("CareerConfig"))
local Validate = require(ReplicatedStorage:WaitForChild("Validate"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local StateService = require(ServerScriptService:WaitForChild("StateService"))

local gain = ServerState.gain
local likedToday = ServerState.likedToday
local notify = ServerState.notify
local sessions = ServerState.sessions
local visitEvent = ServerState.visitEvent
type Session = ServerState.Session
local incomeReward = Economy.incomeReward
local visitMult = Economy.visitMult
local sendState = StateService.sendState

local VisitService = {}
local Actions = {}

local function playerByUserId(userId: any): Player?
	if not Validate.integer(userId, 1) then
		return nil
	end
	for other in sessions do
		if other.UserId == userId then
			return other
		end
	end
	return nil
end

-- Manda al visitante la ficha del imperio de "owner"
local function sendVisit(visitor: Player, owner: Player)
	local ownerSession = sessions[owner]
	local visitorSession = sessions[visitor]
	if not ownerSession or not visitorSession then
		return
	end
	local data = ownerSession.data
	local best, bestVisits = nil, -1
	for _, site in data.sites do
		local visits = Config.siteVisits(data, site, visitMult(ownerSession, site))
		if visits > bestVisits then
			best, bestVisits = site, visits
		end
	end
	local career = data.career
	local bestRarity = nil
	for _, programmer in career.programmers do
		local rarity = Career.RarityById[programmer.rarity]
		if rarity and (not bestRarity or rarity.order > bestRarity.order) then
			bestRarity = rarity
		end
	end
	visitEvent:FireClient(visitor, {
		userId = owner.UserId,
		name = owner.DisplayName,
		own = visitor == owner,
		floors = Config.buildingFloors(data.lifetimeEarned),
		lifetimeEarned = data.lifetimeEarned,
		income = ownerSession.income,
		sites = #data.sites,
		bestSite = if best then { name = best.name, type = best.type, visits = bestVisits } else nil,
		agency = if career.agency then career.agency.name else nil,
		programmers = #career.programmers,
		bestRarity = if bestRarity then bestRarity.id else nil,
		devLevel = Career.devLevel(career),
		shares = data.shares,
		likes = data.likes,
		gold = data.goldUntil > os.time(),
		liked = likedToday(visitorSession.data, owner.UserId),
		likeReward = incomeReward(visitorSession, Config.LIKE_VISITOR_MINUTES, Config.LIKE_VISITOR_MIN),
	})
end

function Actions.visitPlot(player: Player, _session: Session, userId: any)
	local owner = playerByUserId(userId)
	if not owner then
		return false, "Ese jugador ya no está en el servidor."
	end
	sendVisit(player, owner)
	return true, nil
end

function Actions.likePlot(player: Player, session: Session, userId: any)
	local owner = playerByUserId(userId)
	local ownerSession = owner and sessions[owner]
	if not owner or not ownerSession then
		return false, "Ese jugador ya no está en el servidor."
	end
	if owner == player then
		return false, "No puedes darte me gusta a ti mismo 😄"
	end
	local data = session.data
	local today = Config.dayIndex(os.time())
	if data.likesGiven.day ~= today then
		data.likesGiven = { day = today, ids = {} }
	end
	local key = "u" .. owner.UserId
	if data.likesGiven.ids[key] then
		return false, "Ya le has dado me gusta hoy a este imperio."
	end
	local given = 0
	for _ in data.likesGiven.ids do
		given += 1
	end
	if given >= Config.MAX_LIKES_PER_DAY then
		return false, "Ya has dado todos los me gusta de hoy. ¡Vuelve mañana!"
	end
	data.likesGiven.ids[key] = true
	ownerSession.data.likes += 1
	local ownerReward = incomeReward(ownerSession, Config.LIKE_OWNER_MINUTES, Config.LIKE_OWNER_MIN)
	gain(ownerSession.data, ownerReward, "megusta")
	notify(owner, string.format("👍 ¡A %s le gusta tu imperio! +%s", player.DisplayName, Config.formatMoney(ownerReward)), "money")
	local reward = incomeReward(session, Config.LIKE_VISITOR_MINUTES, Config.LIKE_VISITOR_MIN)
	gain(data, reward, "megusta")
	sendState(owner)
	return true, string.format("👍 Te gusta el imperio de %s: +%s", owner.DisplayName, Config.formatMoney(reward)), { money = true }
end

---------------------------------------------------------------------
-- v2.0: premios (temporada, tiempo jugado, códigos), I+D
---------------------------------------------------------------------

local function updateFriendBonus(session: Session)
	local count = 0
	for other in sessions do
		if session.friendIds[other.UserId] then
			count += 1
		end
	end
	session.bonuses.friends = count
end

local function registerFriends(player: Player, session: Session)
	-- Copia de la lista: IsFriendsWithAsync espera a la red y puede entrar o
	-- salir gente mientras tanto
	local others = {}
	for other in sessions do
		if other ~= player then
			table.insert(others, other)
		end
	end
	for _, other in others do
		local ok, isFriend = pcall(function()
			return player:IsFriendsWithAsync(other.UserId)
		end)
		local otherSession = sessions[other]
		if ok and isFriend and otherSession and sessions[player] then
			session.friendIds[other.UserId] = true
			otherSession.friendIds[player.UserId] = true
			notify(other, "👫 ¡" .. player.DisplayName .. " ha entrado! +10 % de dinero por jugar con amigos", "success")
		end
	end
	for _, s in sessions do
		updateFriendBonus(s)
	end
end

---------------------------------------------------------------------
-- Entrar y salir del juego
---------------------------------------------------------------------

VisitService.playerByUserId = playerByUserId
VisitService.registerFriends = registerFriends
VisitService.sendVisit = sendVisit
VisitService.updateFriendBonus = updateFriendBonus
VisitService.Actions = Actions

return VisitService
