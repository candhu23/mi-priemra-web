--[[
	TabStory (ModuleScript en StarterPlayerScripts > ClientUI)

	Pestaña 📖 Historia (v4, centro 🎯 Progreso): Modo Historia «Del garaje
	al imperio». Arriba, Ada y la misión actual; debajo, los 5 capítulos con
	sus 6 misiones (✅ hecha, ▶ la actual con su progreso, 🔒 las que faltan).
	Los datos están en StoryConfig; el progreso lo manda el servidor (state.story).
]]

return function(ui: any)
	local Config = ui.Config
	local Story = ui.Story
	local THEME = ui.THEME
	local T = ui.T
	local fmt = ui.fmt
	local num = ui.num
	local makeLabel = ui.makeLabel
	local makeButton = ui.makeButton
	local makeCard = ui.makeCard
	local makeProgressBar = ui.makeProgressBar
	local sendAction = ui.sendAction
	local pages = ui.pages
	local renderers = ui.renderers

	local page = pages.story

	-- Cabecera: capítulo actual
	local header = makeCard(page, 70, 1, Color3.fromRGB(67, 56, 202))
	makeLabel(header, "📖 Del garaje al imperio", 0, 22, 18, THEME.text, true)
	local chapterLabel = makeLabel(header, "", 24, 18, 14, THEME.yellow, true)
	local totalLabel = makeLabel(header, "", 44, 18, 13, THEME.muted)

	-- Ada y la misión actual
	local adaCard = makeCard(page, 150, 2, Color3.fromRGB(46, 16, 101))
	makeLabel(adaCard, "👩‍💻 Ada, tu mentora", 0, 20, 16, THEME.yellow, true)
	local sayLabel = makeLabel(adaCard, "", 22, 40, 14, THEME.text)
	sayLabel.TextWrapped = true
	sayLabel.TextTruncate = Enum.TextTruncate.None
	local missionLabel = makeLabel(adaCard, "", 64, 18, 14, THEME.green, true)
	local _back, fill, progressText = makeProgressBar(adaCard, UDim2.fromOffset(0, 86), UDim2.new(1, 0, 0, 16), THEME.green)
	local hintLabel = makeLabel(adaCard, "", 104, 16, 12, THEME.muted)
	local talkButton = makeButton(adaCard, "💬 Hablar con Ada", THEME.purple, UDim2.new(1, 0, 0, 26), function()
		sendAction("talkToAda")
	end)
	talkButton.Position = UDim2.fromOffset(0, 122)

	-- Un tarjetón por capítulo con sus misiones
	local chapterCards = {}
	for i, chapter in Story.Chapters do
		local card = makeCard(page, 30 + #chapter.missions * 19, 2 + i, THEME.panel)
		local title = makeLabel(card, "", 0, 22, 16, THEME.text, true)
		local rows = {}
		for m = 1, #chapter.missions do
			rows[m] = makeLabel(card, "", 24 + (m - 1) * 19, 18, 13, THEME.muted)
		end
		chapterCards[i] = { title = title, rows = rows }
	end

	renderers.story = function(s)
		local story = s.story
		if not story then
			return
		end
		local mission, chapter = Story.current(story)
		local doneCount = if story.done then Story.TOTAL else Story.stepIndex(story.chapter, story.mission) - 1
		totalLabel.Text = T("Misiones completadas: %d de %d", doneCount, Story.TOTAL)
		if mission and chapter then
			chapterLabel.Text = T("Capítulo %d de %d: %s %s", story.chapter, #Story.Chapters, chapter.emoji, T(chapter.name))
			sayLabel.Text = T(mission.say)
			missionLabel.Text = T("▶ %s", T(mission.text))
			local target = math.max(story.target or 1, 1)
			local progress = math.min(story.progress or 0, target)
			fill.Size = UDim2.fromScale(progress / target, 1)
			progressText.Text = if target >= 1000 then fmt(progress) .. " / " .. fmt(target) else num(progress) .. " / " .. num(target)
			local locked = mission.feature and not Config.isUnlocked(s, mission.feature)
			hintLabel.Text = if locked then T("🔒 Se desbloquea en la planta %d de tu rascacielos.", Config.unlockFloor(mission.feature))
				else T("📍 %s", T(mission.hint)) .. "  ·  " .. T("🎁 Premio: %s", fmt(story.reward or 0))
		else
			chapterLabel.Text = T("👑 ¡Historia completada!")
			sayLabel.Text = T("¡Ya eres un magnate! Sigue haciendo crecer tu imperio.")
			missionLabel.Text = ""
			fill.Size = UDim2.fromScale(1, 1)
			progressText.Text = ""
			hintLabel.Text = ""
		end
		for i, chapterDef in Story.Chapters do
			local card = chapterCards[i]
			local reached = story.done or i <= story.chapter
			card.title.Text = (if reached then chapterDef.emoji else "🔒") .. " " .. T("Capítulo %d: %s", i, T(chapterDef.name))
			card.title.TextColor3 = if reached then THEME.text else THEME.muted
			for m, def in chapterDef.missions do
				local row = card.rows[m]
				local done = story.done or i < story.chapter or (i == story.chapter and m < story.mission)
				local current = not story.done and i == story.chapter and m == story.mission
				if done then
					row.Text = "✅ " .. T(def.text)
					row.TextColor3 = THEME.green
				elseif current then
					row.Text = "▶ " .. T(def.text)
					row.TextColor3 = THEME.yellow
				else
					row.Text = "🔒 " .. (if reached then T(def.text) else "???")
					row.TextColor3 = THEME.muted
				end
			end
		end
	end
end
