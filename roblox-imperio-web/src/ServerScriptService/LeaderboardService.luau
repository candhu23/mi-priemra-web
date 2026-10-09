--[[
	LeaderboardService (ModuleScript en ServerScriptService)

	Clasificación global y semanal: cambio de semana, premios y nombres.

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local PlotManager = require(ServerScriptService:WaitForChild("PlotManager"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local SaveService = require(ServerScriptService:WaitForChild("SaveService"))
local BadgeAwards = require(ServerScriptService:WaitForChild("BadgeAwards"))

local gain = ServerState.gain
local notify = ServerState.notify
local popup = ServerState.popup
local world = ServerState.world
type BoardRow = ServerState.BoardRow
type Session = ServerState.Session
local incomeReward = Economy.incomeReward
local leaderboardScore = SaveService.leaderboardScore
local leaderboardStore = SaveService.leaderboardStore
local leaderboardValue = SaveService.leaderboardValue
local saveData = SaveService.saveData
local weeklyStore = SaveService.weeklyStore

local LeaderboardService = {}

-- Si ha empezado una semana nueva, lo ganado pasa a "la semana pasada"
local function rolloverWeek(player: Player, session: Session)
	local weekly = session.data.weekly
	local week = Config.weekIndex(os.time())
	if weekly.week == week then
		return
	end
	if weekly.week >= 0 then
		local oldWeek, oldEarned = weekly.week, weekly.earned
		-- Puntuación final de la semana que acaba
		local weekStore = if oldEarned > 0 then weeklyStore(oldWeek) else nil
		if weekStore and session.canSave then
			task.spawn(function()
				pcall(function()
					weekStore:SetAsync("u_" .. player.UserId, leaderboardScore(oldEarned))
				end)
			end)
		end
		weekly.prevWeek, weekly.prevEarned = oldWeek, oldEarned
	end
	weekly.week = week
	weekly.earned = 0
	-- Los premios se reparten un rato después, cuando todos han guardado
	session.weeklyCheckAt = math.max(os.clock(), os.clock() + (Config.weekStart(week) + Config.WEEKLY_GRACE - os.time()))
end

-- Puestos de una semana ya terminada: { [userId] = puesto } (top 100)
local weeklyRanks: { [number]: { [number]: number } } = {}

local function ranksOfWeek(week: number): { [number]: number }?
	if weeklyRanks[week] then
		return weeklyRanks[week]
	end
	local weekStore = weeklyStore(week)
	if not weekStore then
		return nil
	end
	local ok, pages = pcall(function()
		return weekStore:GetSortedAsync(false, 100)
	end)
	if not ok then
		return nil
	end
	local ranks = {}
	for i, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		if userId then
			ranks[userId] = i
		end
	end
	weeklyRanks[week] = ranks
	return ranks
end

local function grantWeeklyPrize(player: Player, session: Session)
	local data = session.data
	local weekly = data.weekly
	if weekly.prevWeek < 0 or weekly.rewardedWeek >= weekly.prevWeek then
		return
	end
	if weekly.prevEarned <= 0 or not session.canSave then
		weekly.rewardedWeek = weekly.prevWeek
		return
	end
	local ranks = ranksOfWeek(weekly.prevWeek)
	if session.closed then
		return -- se fue mientras se consultaba el ranking: se le dará al volver
	end
	if not ranks then
		session.weeklyCheckAt = os.clock() + 120 -- se reintenta más tarde
		return
	end
	weekly.rewardedWeek = weekly.prevWeek
	local rank = ranks[player.UserId]
	local prize = rank and Config.weeklyPrize(rank)
	if not rank or not prize then
		notify(player, "📊 La semana pasada ganaste " .. Config.formatMoney(weekly.prevEarned) .. ". ¡Esta semana puedes entrar en el top 100!", "info")
		return
	end
	local lines = {}
	local amount = incomeReward(session, prize.minutes, 1000)
	gain(data, amount, "ranking")
	table.insert(lines, "💰 +" .. Config.formatMoney(amount))
	if prize.legendary > 0 then
		data.career.tickets.legendary = (data.career.tickets.legendary or 0) + prize.legendary
		table.insert(lines, "👑 +" .. prize.legendary .. " Contrato Legendario")
	end
	BadgeAwards.give(player, data, "weekly_top")
	if prize.goldDays > 0 then
		data.goldUntil = math.max(data.goldUntil, os.time()) + prize.goldDays * 86400
		table.insert(lines, "🏆 Rascacielos dorado durante " .. prize.goldDays .. " días")
	end
	popup(player, prize.emoji .. " ¡" .. prize.name .. "!", "Quedaste en el puesto #" .. rank .. " del ranking semanal.\n\n" .. table.concat(lines, "\n"))
	-- Se guarda ya para que el premio no se pueda repetir si el servidor se cae
	task.spawn(saveData, player, session)
end

local nameCache: { [number]: string } = {}

local nameLookupsLeft = 0 -- consultas a Roblox que quedan en esta actualización

local function nameOf(userId: number): string
	if not nameCache[userId] then
		-- Si está en el servidor no hace falta preguntar
		local here = Players:GetPlayerByUserId(userId)
		if here then
			nameCache[userId] = here.Name
			return here.Name
		end
		-- Como mucho 10 consultas por actualización (GetNameFromUserIdAsync
		-- tiene límite de peticiones); las que falten salen en la siguiente
		if nameLookupsLeft <= 0 then
			return "Jugador"
		end
		nameLookupsLeft -= 1
		local okName, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if not okName then
			return "Jugador"
		end
		nameCache[userId] = result
	end
	return nameCache[userId]
end

-- Las 10 mejores puntuaciones de una clasificación (nil si falla)
local function topRows(board: OrderedDataStore): { BoardRow }?
	local ok, pages = pcall(function()
		return board:GetSortedAsync(false, Config.WEEKLY_TOP_SIZE)
	end)
	if not ok then
		return nil
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		table.insert(rows, {
			name = if userId then nameOf(userId) else "???",
			value = leaderboardValue(entry.value),
			userId = userId,
		})
	end
	return rows
end

local function refreshLeaderboard()
	nameLookupsLeft = 10
	if not leaderboardStore then
		PlotManager.setLeaderboard(nil, "Publica el juego para ver la clasificación")
		PlotManager.setWeeklyBoard(nil, "Publica el juego para ver la clasificación")
		return
	end
	local rows = topRows(leaderboardStore)
	if rows then
		world.globalTop = rows
		PlotManager.setLeaderboard(rows, nil)
	else
		PlotManager.setLeaderboard(nil, "Clasificación disponible al publicar el juego")
	end
	local week = Config.weekIndex(os.time())
	local weekStore = weeklyStore(week)
	local weekRows = weekStore and topRows(weekStore)
	if weekRows then
		world.weeklyTop = weekRows
		world.weeklyTopWeek = week
		PlotManager.setWeeklyBoard(weekRows, nil)
	else
		PlotManager.setWeeklyBoard(nil, "Clasificación disponible al publicar el juego")
	end
end

---------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------

LeaderboardService.grantWeeklyPrize = grantWeeklyPrize
LeaderboardService.nameOf = nameOf
LeaderboardService.ranksOfWeek = ranksOfWeek
LeaderboardService.refreshLeaderboard = refreshLeaderboard
LeaderboardService.rolloverWeek = rolloverWeek
LeaderboardService.topRows = topRows

return LeaderboardService
