--[[
	TycoonClient (LocalScript en StarterPlayer > StarterPlayerScripts)

	Toda la interfaz del juego:
	  · HUD superior con el dinero y los bonus activos
	  · menú lateral con avisos (!) cuando hay algo que hacer
	  · misión actual con barra de progreso
	  · botón PROGRAMAR siempre visible abajo (tecla F)
	  · ventana con pestañas (Crear, Webs, Clientes, Anuncios, Empresas,
	    Bolsa, Tienda)
	  · ventanas emergentes (bienvenida, recompensa diaria) y avisos
	  · marcador "TU IMPERIO" sobre tu parcela
	El cliente solo muestra cosas y pide acciones: el servidor decide.

	v4: el código está repartido en ClientUI/ (Core + una pestaña por módulo);
	aquí se juntan y queda lo que no es de ninguna pestaña.
]]

local ClientUI = script.Parent:WaitForChild("ClientUI")
local ui = require(ClientUI:WaitForChild("Core"))
-- Cada pestaña se construye en su módulo (en este orden)
for _, name in { "TabCreate", "TabSites", "TabClients", "TabAds", "TabCompanies", "TabCareer", "TabAgency", "TabMissions", "TabAchievements", "TabSeason", "TabCollection", "TabRanking", "TabMarket", "TabResearch", "TabShop", "Tutorial", "HudExtras" } do
	require(ClientUI:WaitForChild(name))(ui)
end

local RunService = ui.RunService
local UserInputService = ui.UserInputService
local Workspace = ui.Workspace
local Config = ui.Config
local Career = ui.Career
local Locale = ui.Locale
local StatePatch = ui.StatePatch
local actionFunction = ui.actionFunction
local stateEvent = ui.stateEvent
local openComputerEvent = ui.openComputerEvent
local visitEvent = ui.visitEvent
local player = ui.player
local playerGui = ui.playerGui
local T = ui.T
local TR = ui.TR
local boundTexts = ui.boundTexts
local THEME = ui.THEME
local fmt = ui.fmt
local num = ui.num
local audio = ui.audio
local playSound = ui.playSound
local create = ui.create
local setButton = ui.setButton
local updateScale = ui.updateScale
local stateTime = ui.stateTime
local sendAction = ui.sendAction
local moneyLabel = ui.moneyLabel
local incomeLabel = ui.incomeLabel
local chips = ui.chips
local eventLabel = ui.eventLabel
local saveBanner = ui.saveBanner
local window = ui.window
local languageButton = ui.languageButton
local renderers = ui.renderers
local refreshTabButtons = ui.refreshTabButtons
local selectTab = ui.selectTab
local openTab = ui.openTab
local setBadge = ui.setBadge
local missionCard = ui.missionCard
local renderMission = ui.renderMission
local quickBar = ui.quickBar
local quickTitle = ui.quickTitle
local quickFill = ui.quickFill
local quickProgress = ui.quickProgress
local quickButton = ui.quickButton
local floatText = ui.floatText
local pulseMoney = ui.pulseMoney
local showModal = ui.showModal
local showDailyModal = ui.showDailyModal
local visitHistory = ui.visitHistory
local HISTORY_SIZE = ui.HISTORY_SIZE

---------------------------------------------------------------------
-- Pestaña RANKING (eventos de fin de semana, top semanal y vecinos)
---------------------------------------------------------------------

-- Ficha del imperio de otro jugador (cartel "Ver imperio" o pestaña Ranking)
visitEvent.OnClientEvent:Connect(function(info)
	local lines = {
		T("🏢 %d plantas · 💰 %s ganados en total", info.floors, fmt(info.lifetimeEarned)),
		T("💵 %s/s · 🌐 %d webs", fmt(info.income), info.sites),
	}
	if info.bestSite then
		local def = Config.WebTypeById[info.bestSite.type]
		table.insert(lines, T("⭐ Web estrella: %s %s (%s visitas/s)", if def then def.emoji else "🌐", info.bestSite.name, num(info.bestSite.visits)))
	end
	if info.agency then
		local rarity = info.bestRarity and Career.RarityById[info.bestRarity]
		table.insert(lines, T("👥 %s · %d programadores", info.agency, info.programmers) .. (if rarity then T(" · el mejor: %s", T(rarity.name)) else ""))
	end
	table.insert(lines, T("🎓 Nivel de programador %d · 📈 %d acciones", info.devLevel, info.shares))
	table.insert(lines, T("👍 %d me gusta", info.likes))
	local title = (if info.gold then "👑 " else "🏢 ") .. T("Imperio de %s", info.name)
	local buttonText = if info.own then T("Cerrar")
		elseif info.liked then T("✓ Ya le diste me gusta hoy")
		else T("👍 Me gusta (+%s)", fmt(info.likeReward))
	showModal(title, table.concat(lines, "\n"), buttonText, function()
		if not info.own and not info.liked then
			sendAction("likePlot", info.userId, nil, function(ok)
				if ok then
					pulseMoney()
				end
			end)
		end
	end, nil)
end)

---------------------------------------------------------------------
-- Clic de programar (botón de abajo, pestaña Crear y tecla F)
---------------------------------------------------------------------
function ui.doClick()
	if not ui.state then
		return
	end
	if not ui.state.project then
		openTab("create")
		return
	end
	local power = ui.state.clickPower
	ui.pendingClickWork += power
	playSound("click")
	floatText(quickBar, "+" .. num(power), THEME.yellow, 28)
	sendAction("click", nil, nil, function(ok, _message, extra)
		if ok and type(extra) == "table" and extra.combo then
			ui.showCombo(extra.combo, extra.comboMult or 1)
		end
		if ok and type(extra) == "table" and extra.crit then
			ui.pendingClickWork += (extra.power or power) - power
			playSound("crit")
			floatText(quickBar, T("💥 ¡CRÍTICO! +%s", num(extra.power or power)), THEME.orange, 36)
		end
	end)
end

---------------------------------------------------------------------
-- Marcador "TU IMPERIO" sobre tu parcela
---------------------------------------------------------------------
local plotMarker = create("BillboardGui", {
	Name = "TuImperio",
	Size = UDim2.fromOffset(240, 60),
	StudsOffset = Vector3.new(0, 22, 0),
	AlwaysOnTop = true,
	MaxDistance = 1000,
	Enabled = false,
	Parent = playerGui,
})
create("TextLabel", {
	Parent = plotMarker,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "⬇️ TU IMPERIO ⬇️",
	TextScaled = true,
	Font = Enum.Font.FredokaOne,
	TextColor3 = THEME.yellow,
	TextStrokeTransparency = 0,
})
local myPlotPart: BasePart? = nil

local function findMyPlot()
	local folder = Workspace:FindFirstChild("Parcelas")
	if not folder then
		return
	end
	for _, plot in folder:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local part = plot:FindFirstChildWhichIsA("BasePart")
			if part then
				myPlotPart = part
				plotMarker.Adornee = part
			end
			return
		end
	end
end

---------------------------------------------------------------------
-- Recibir estado del servidor
---------------------------------------------------------------------
local function renderAlways(s)
	-- Avisos del menú
	local canFulfill = 0
	for _, offer in s.offers do
		if ui.bestSiteFor(s, offer) then
			canFulfill += 1
		end
	end
	setBadge("clients", canFulfill)

	local canCreate = false
	if not s.project and #s.sites < s.slots then
		for _, def in Config.WebTypes do
			if s.reputation >= def.rep and s.money >= def.cost then
				canCreate = true
			end
		end
	end
	setBadge("create", canCreate)

	local canBuy = false
	for _, def in Config.Companies do
		local level = s.companies[def.id] or 0
		if level < def.maxLevel and s.money >= Config.companyCost(def.id, level) then
			canBuy = true
		end
	end
	setBadge("companies", canBuy)

	local canUnlock = false
	for _, network in Config.AdNetworks do
		if not s.unlockedAds[network.id] and s.reputation >= network.rep and s.money >= network.cost then
			canUnlock = true
		end
	end
	setBadge("ads", canUnlock)
	local c = s.career
	setBadge("career", if #c.contracts < c.slots then #c.board else 0)
	local agencyReady = false
	if c.agency then
		local space = #c.programmers < c.agency.capacity
		agencyReady = space and (s.money >= c.recruitCost or (c.tickets.legendary or 0) > 0 or ((c.tickets.premium or 0) > 0 and not s.bonuses.randomRestricted))
	else
		agencyReady = c.devLevel >= Career.AGENCY_LEVEL_REQUIRED and s.money >= Career.AGENCY_COST
	end
	setBadge("agency", agencyReady)
	saveBanner.Visible = not s.canSave
	local playtimeReady = 0
	for i, reward in Config.PlaytimeRewards do
		if not s.playtime.claimed[tostring(i)] and s.playtime.seconds >= reward.atMinutes * 60 then
			playtimeReady += 1
		end
	end
	setBadge("shop", if s.giftLeft <= 0 or s.dailyAvailable then playtimeReady + 1 else playtimeReady)
	local seasonTier = math.min(Config.SEASON_TIERS, s.season.xp // Config.SEASON_XP_PER_TIER)
	local seasonReady = 0
	for tier = 1, seasonTier do
		if not s.season.free[tostring(tier)] then
			seasonReady += 1
		end
		if s.season.premium and not s.season.premiumClaimed[tostring(tier)] then
			seasonReady += 1
		end
	end
	setBadge("season", seasonReady)
	local researchReady = false
	for _, def in Config.Research do
		local level = Config.research(s, def.id)
		if level < def.maxLevel and s.patents >= Config.researchCost(def.id, level) then
			researchReady = true
		end
	end
	setBadge("ipo", s.ipoShares >= 1)
	setBadge("research", researchReady)
	local claimable = 0
	for _, goal in Config.Goals do
		if not s.goals[goal.id] and goal.value(s) >= goal.target then
			claimable += 1
		end
	end
	for _, list in { s.dailyMissions.list, s.weeklyMissions.list } do
		for _, mission in list do
			if not mission.claimed and mission.progress >= mission.target then
				claimable += 1
			end
		end
	end
	setBadge("missions", claimable)

	-- Bonus activos
	chips.pass.Visible = s.bonuses.pass
	chips.pass.Text = "💎 x2"
	chips.boost.Visible = s.bonuses.boost
	chips.boost.Text = "🚀 x2 " .. Config.formatTime(s.boostLeft)
	chips.social.Visible = s.socialBonus > 0
	chips.social.Text = "👫 +" .. math.floor(s.socialBonus * 100 + 0.5) .. "%"
	chips.turbo.Visible = s.bonuses.turbo
	chips.turbo.Text = "⚡ Turbo"
	local weekendEvent = s.weekend.id and Config.WeekendEventById[s.weekend.id]
	chips.weekend.Visible = weekendEvent ~= nil
	if weekendEvent then
		chips.weekend.Text = weekendEvent.emoji .. " " .. T(weekendEvent.short) .. " · " .. Config.formatTime(s.weekend.endsIn)
	end
	chips.gold.Visible = s.goldLeft > 0
	chips.gold.Text = "👑 " .. Config.formatTime(s.goldLeft)

	-- Evento
	if s.event then
		eventLabel.Visible = true
		eventLabel.Text = TR(s.event.name) .. "  (" .. Config.formatTime(s.event.timeLeft) .. ")"
	else
		eventLabel.Visible = false
	end

	-- Barra rápida
	if s.project then
		local def = Config.WebTypeById[s.project.type]
		quickTitle.Text = T("%s Programando %s", def.emoji, T(def.name)) .. (if s.autoType then "  · 🤖" else "") .. T("  ·  tecla F")
		setButton(quickButton, T("⌨️ PROGRAMAR"), true, THEME.green)
	else
		quickFill.Size = UDim2.fromScale(0, 1)
		quickProgress.Text = ""
		if #s.sites >= s.slots then
			quickTitle.Text = T("🌐 Sin huecos: vende una web o compra ☁️ Hosting")
		else
			quickTitle.Text = T("¿Qué web vas a crear ahora?")
		end
		setButton(quickButton, T("➕ Nueva web"), true, THEME.accent)
	end

	renderMission(s)
	ui.renderHudExtras(s)
	refreshTabButtons()
	if not myPlotPart then
		findMyPlot()
	end
end

-- El servidor manda el estado completo la primera vez y luego solo lo que
-- cambia (isPatch = true). Si llega un parche sin tener estado, se pide entero.
do
local resyncAt = 0
stateEvent.OnClientEvent:Connect(function(payload, isPatch)
	local first = ui.state == nil
	if isPatch then
		if not ui.state then
			if os.clock() >= resyncAt then
				resyncAt = os.clock() + 2
				task.spawn(function()
					pcall(function()
						actionFunction:InvokeServer("requestState")
					end)
				end)
			end
			return
		end
		StatePatch.apply(ui.state, payload)
	else
		ui.state = payload
	end
	local newState = ui.state
	for _, site in newState.sites do
		local history = visitHistory[site.id] or {}
		table.insert(history, site.visits)
		if #history > HISTORY_SIZE then
			table.remove(history, 1)
		end
		visitHistory[site.id] = history
	end
	if ui.detailSiteId and window.Visible then
		ui.renderDetail(newState)
	end
	stateTime = os.clock()
	ui.pendingClickWork = 0

	renderAlways(newState)
	if window.Visible and renderers[ui.currentTab] then
		renderers[ui.currentTab](newState)
	end
	ui.tutorialOnState(newState)

	if first then
		-- Idioma elegido a mano en otra partida (o el de la cuenta)
		local wanted = Locale.resolve(newState.settings and newState.settings.lang, player.LocaleId)
		if wanted ~= ui.lang then
			ui.applyLanguage(wanted)
		end
		local settings = newState.settings or {}
		audio.volume = if type(settings.volume) == "number" then settings.volume elseif settings.muted then 0 else 1
		audio.musicOn = settings.music ~= false
		ui.muteButton.Text = audio.volumeIcon(audio.volume)
		setButton(audio.button, "🎵", true, if audio.musicOn then THEME.green else THEME.card)
		audio.updateMusic()
		if not newState.tutorialDone then
			task.delay(1.5, ui.startTutorial)
		end
		task.delay(4, function()
			if not ui.dailyShown and ui.state and ui.state.dailyAvailable and ui.state.stats.built > 0 then
				ui.dailyShown = true
				showDailyModal()
			end
		end)
	end
end)
end

-- Animación suave del dinero y de las barras de progreso
RunService.RenderStepped:Connect(function()
	if os.clock() >= audio.checkAt then
		audio.checkAt = os.clock() + 2
		audio.updateMusic()
	end
	if not ui.state then
		return
	end
	local elapsed = math.min(os.clock() - stateTime, 1.5)
	moneyLabel.Text = "💰 " .. fmt(ui.state.money + ui.state.income * elapsed)
	incomeLabel.Text = T("+%s/s  ·  ⭐ %s  ·  📈 %d acciones", fmt(ui.state.income), num(ui.state.reputation), ui.state.shares)

	local project = ui.state.project
	if project then
		local progress = math.min(project.progress + ui.pendingClickWork + ui.state.workPerSec * elapsed, project.required)
		local ratio = progress / project.required
		quickFill.Size = UDim2.fromScale(ratio, 1)
		quickProgress.Text = num(progress) .. " / " .. num(project.required)
		if window.Visible and ui.currentTab == "create" then
			ui.progressFill.Size = UDim2.fromScale(ratio, 1)
			ui.progressText.Text = quickProgress.Text
		end
	end

	-- El marcador solo se ve cuando estás lejos de tu parcela
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if myPlotPart and root and root:IsA("BasePart") then
		plotMarker.Enabled = (root.Position - myPlotPart.Position).Magnitude > 60
	end
end)

---------------------------------------------------------------------
-- Abrir y cerrar
---------------------------------------------------------------------
ui.onTabChanged = function()
	if ui.detailSiteId then
		ui.detailSiteId = nil
		ui.detail.Visible = false
	end
end

window:GetPropertyChangedSignal("Visible"):Connect(function()
	quickBar.Visible = not window.Visible
	missionCard.Visible = not window.Visible
	if window.Visible and ui.state and renderers[ui.currentTab] then
		renderers[ui.currentTab](ui.state)
	end
end)

openComputerEvent.OnClientEvent:Connect(function()
	openTab(ui.currentTab)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		window.Visible = not window.Visible
	elseif input.KeyCode == Enum.KeyCode.F then
		ui.doClick()
	end
end)

---------------------------------------------------------------------
-- Carteles del mundo: los crea el servidor en español y aquí se
-- traducen (solo en tu pantalla). Si el servidor cambia el texto, se
-- vuelve a traducir.
---------------------------------------------------------------------
local worldProp: { [Instance]: string } = {} -- propiedad con el texto
local worldSource: { [Instance]: string } = {} -- texto original (español)
local worldShown: { [Instance]: string } = {} -- lo que estamos enseñando

local function applyWorldText(obj: Instance)
	local prop = worldProp[obj]
	local current = (obj :: any)[prop]
	if current ~= worldShown[obj] then
		worldSource[obj] = current -- lo ha cambiado el servidor
	end
	local out = TR(worldSource[obj])
	worldShown[obj] = out
	if out ~= current then
		(obj :: any)[prop] = out
	end
end

local function watchWorldText(obj: Instance)
	if worldProp[obj] then
		return
	end
	local prop = if obj:IsA("TextLabel") then "Text" elseif obj:IsA("ProximityPrompt") then "ActionText" else nil
	if not prop then
		return
	end
	worldProp[obj] = prop
	applyWorldText(obj)
	obj:GetPropertyChangedSignal(prop):Connect(function()
		applyWorldText(obj)
	end)
	obj.Destroying:Connect(function()
		worldProp[obj] = nil
		worldSource[obj] = nil
		worldShown[obj] = nil
	end)
end

for _, descendant in Workspace:GetDescendants() do
	watchWorldText(descendant)
end
Workspace.DescendantAdded:Connect(watchWorldText)

---------------------------------------------------------------------
-- Cambiar de idioma sin volver a entrar
---------------------------------------------------------------------
ui.applyLanguage = function(newLang: string)
	if newLang == ui.lang then
		return
	end
	local oldLang = ui.lang
	ui.lang = newLang
	languageButton.Text = "🌐 " .. string.upper(ui.lang)
	-- Textos fijos creados con create()
	for _, d in playerGui:GetDescendants() do
		local src = d:GetAttribute("SrcText")
		if type(src) == "string" and (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == Locale.t(oldLang, src) then
			d.Text = Locale.t(ui.lang, src)
		end
	end
	for _, item in boundTexts do
		item.obj.Text = item.fn()
	end
	for obj in worldProp do
		applyWorldText(obj)
	end
	-- Pestañas y todo lo que se pinta con el estado
	refreshTabButtons()
	ui.updateTitle()
	if ui.state then
		renderAlways(ui.state)
		if renderers[ui.currentTab] then
			renderers[ui.currentTab](ui.state)
		end
		if ui.detailSiteId then
			ui.renderDetail(ui.state)
		end
	end
end

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()
selectTab("create")
