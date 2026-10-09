--[[
	StoryService (ModuleScript en ServerScriptService)

	Modo Historia (v4): mira cada segundo si se ha cumplido la misión actual
	de StoryConfig; si sí, da su premio, avanza y avisa al jugador (Notify
	tipo "story" = aviso de Ada; tipo "chapter" = fin de capítulo: el
	cliente hace la vuelta de cámara y enseña la ventana del capítulo).
	Como mucho una misión por segundo, para que los avisos no se amontonen.

	data.story = { chapter, mission, done }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Story = require(ReplicatedStorage:WaitForChild("StoryConfig"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local Analytics = require(ServerScriptService:WaitForChild("Analytics"))
local StatePatch = require(ReplicatedStorage:WaitForChild("StatePatch"))

local notify = ServerState.notify
local notifyEvent = ServerState.notifyEvent
local sessions = ServerState.sessions
local gain = ServerState.gain
local sig3 = StatePatch.sig3
type Session = ServerState.Session

local StoryService = {}

-- Datos de una partida nueva
function StoryService.newData()
	return { chapter = 1, mission = 1, done = false }
end

-- Lo que ve el cliente
function StoryService.buildState(session: Session)
	local story = session.data.story
	local mission = Story.current(story)
	if not mission then
		return { chapter = story.chapter, mission = story.mission, done = true, progress = 0, target = 1 }
	end
	local ok, value = pcall(mission.value, session.data)
	return {
		chapter = story.chapter,
		mission = story.mission,
		done = false,
		-- Redondeados a 3 cifras: cambian cada segundo (estado por diferencias)
		progress = sig3(math.min(if ok and type(value) == "number" then value else 0, mission.target)),
		target = mission.target,
		reward = sig3(Economy.incomeReward(session, mission.reward.minutes, mission.reward.min)),
	}
end

local function sendChapter(player: Player, chapterIndex: number, rewardText: string)
	local chapter = Story.Chapters[chapterIndex]
	local nextChapter = Story.Chapters[chapterIndex + 1]
	-- Cada línea se traduce por separado en el cliente
	local body = chapter.outro .. "\n\n" .. string.format("🎁 Premio del capítulo: %s", rewardText)
	if nextChapter then
		body ..= "\n\n" .. string.format("➡️ Siguiente: %s %s", nextChapter.emoji, nextChapter.name) .. "\n" .. nextChapter.intro
	end
	if sessions[player] then
		notifyEvent:FireClient(player, string.format("%s ¡Capítulo %d completado: %s!", chapter.emoji, chapterIndex, chapter.name), "chapter", body)
	end
end

-- Mira la misión actual; devuelve true si ha avanzado
function StoryService.check(player: Player, session: Session): boolean
	local data = session.data
	local story = data.story
	local mission, chapter = Story.current(story)
	if not mission or not chapter then
		return false
	end
	local ok, value = pcall(mission.value, data)
	if not ok or type(value) ~= "number" or value < mission.target then
		return false
	end
	-- Premio de la misión
	local amount = Economy.incomeReward(session, mission.reward.minutes, mission.reward.min)
	gain(data, amount, "historia")
	Analytics.funnel(player, "Historia", tostring(player.UserId), Story.stepIndex(story.chapter, story.mission), mission.id)
	local chapterIndex = story.chapter
	if story.mission < #chapter.missions then
		story.mission += 1
		local nextMission = chapter.missions[story.mission]
		notify(player, string.format("💬 Ada: ¡Hecho! «%s» +%s · Ahora: %s", mission.text, Config.formatMoney(amount), nextMission.text), "story")
	else
		-- Fin del capítulo: premio especial
		local rewardText = RewardService.giveReward(player, session, chapter.reward)
		Analytics.progress(player, "Historia", chapterIndex, chapter.id)
		if story.chapter < #Story.Chapters then
			story.chapter += 1
			story.mission = 1
		else
			story.done = true
		end
		notify(player, string.format("💬 Ada: ¡Hecho! «%s» +%s", mission.text, Config.formatMoney(amount)), "story")
		sendChapter(player, chapterIndex, rewardText)
	end
	return true
end

-- Presentación (al entrar por primera vez o al hablar con Ada)
function StoryService.greet(player: Player, session: Session)
	local story = session.data.story
	local mission, chapter = Story.current(story)
	if not mission or not chapter then
		notify(player, "💬 Ada: ¡Ya eres un magnate! Sigue haciendo crecer tu imperio.", "story")
		return
	end
	notify(player, "💬 Ada: " .. mission.say, "story")
end

local Actions = {}

-- Hablar con Ada (también desde la pestaña Historia)
function Actions.talkToAda(player: Player, session: Session)
	StoryService.greet(player, session)
	return true, nil
end

StoryService.Actions = Actions

return StoryService
