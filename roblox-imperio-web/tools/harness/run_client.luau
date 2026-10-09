-- Ejecuta TycoonClient real: crea toda la interfaz con instancias de Lune
-- (valida propiedades), le pasa un estado real del servidor, abre todas
-- las pestañas y pulsa TODOS los botones.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SRC = process.args[1]
local configSource = fs.readFile(SRC .. "/ReplicatedStorage/TycoonConfig.luau")
local careerSource = fs.readFile(SRC .. "/ReplicatedStorage/CareerConfig.luau")
local marketSource = fs.readFile(SRC .. "/ReplicatedStorage/MarketConfig.luau")
local clientSource = fs.readFile(SRC .. "/StarterPlayerScripts/TycoonClient.client.luau")
local localeSource = fs.readFile(SRC .. "/ReplicatedStorage/Locale.luau")
local localeEnSource = fs.readFile(SRC .. "/ReplicatedStorage/LocaleEN.luau")
local localePtSource = fs.readFile(SRC .. "/ReplicatedStorage/LocalePT.luau")
local patchSource = fs.readFile(SRC .. "/ReplicatedStorage/StatePatch.luau")
local storySource = fs.readFile(SRC .. "/ReplicatedStorage/StoryConfig.luau")
local stateJson = serde.decode("json", fs.readFile("state.json"))
-- Fusión lista y Legado para gastar, para que se pulsen también esos botones
if stateJson.eras then
	stateJson.eras.legacy = 30
	stateJson.eras.ipos = stateJson.eras.needIpos
	stateJson.eras.earned = stateJson.eras.needEarned
end
local visitJson = serde.decode("json", fs.readFile("visit.json"))

local realOf = setmetatable({}, { __mode = "k" })
local proxyById = {}
local overrides = setmetatable({}, { __mode = "k" })
local signals = {}
local invoked = {}
local SIGNAL_NAMES = {
	Activated = true, MouseEnter = true, MouseLeave = true, OnClientEvent = true, Triggered = true,
	Changed = true, Completed = true, CharacterAdded = true, DescendantAdded = true, Destroying = true,
}

local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	function s:Wait() end
	return s
end

local function signalFor(id, key)
	local k = tostring(id) .. ":" .. key
	signals[k] = signals[k] or newSignal()
	return signals[k]
end

local wrap, unwrap
local proxyMeta = {}
local nextId = 0

local function idOf(inst)
	local id = inst:GetAttribute("__hid")
	if not id then
		nextId += 1
		id = nextId
		inst:SetAttribute("__hid", id)
	end
	return id
end

function wrap(v)
	if typeof(v) == "Instance" then
		local id = idOf(v)
		local p = proxyById[id]
		if not p then
			p = setmetatable({}, proxyMeta)
			realOf[p] = v
			proxyById[id] = p
		end
		return p
	elseif type(v) == "table" and not realOf[v] and getmetatable(v) == nil then
		-- Listas de instancias (GetChildren, GetDescendants...)
		local out = {}
		for k, x in v do
			out[k] = wrap(x)
		end
		return out
	end
	return v
end

function unwrap(v)
	if type(v) == "table" and realOf[v] then
		return realOf[v]
	end
	return v
end

proxyMeta.__index = function(p, key)
	local o = overrides[p]
	if o and o[key] ~= nil then
		return o[key]
	end
	local inst = realOf[p]
	if SIGNAL_NAMES[key] then
		return signalFor(idOf(inst), key)
	end
	if key == "GetPropertyChangedSignal" or key == "GetAttributeChangedSignal" then
		return function(_, name)
			return signalFor(idOf(inst), "changed:" .. name)
		end
	end
	if key == "SetAttribute" then
		return function(_, name, value)
			inst:SetAttribute(name, unwrap(value))
			signalFor(idOf(inst), "changed:" .. name):Fire()
		end
	end
	if key == "AbsolutePosition" then
		return roblox.Vector2.new(100, 100)
	elseif key == "AbsoluteSize" then
		return roblox.Vector2.new(60, 40)
	end
	if key == "InvokeServer" then
		return function(_, action, a, b)
			table.insert(invoked, action)
			if action == "click" then
				return true, nil, { crit = true, power = 5 }
			end
			if action == "recruit" or action == "redeemTicket" then
				return true, nil, { recruit = { id = 9, name = "Noa T.", rarity = "legendario", niche = "tech", level = 1 } }
			end
			return true, "ok " .. action, { money = true }
		end
	end
	if key == "WaitForChild" then
		return function(_, name)
			local child = inst:FindFirstChild(name)
			assert(child, "WaitForChild colgado: " .. tostring(name))
			return wrap(child)
		end
	end
	local ok, value = pcall(function() return inst[key] end)
	if not ok then
		if key == "Play" or key == "Stop" then
			return function() end
		end
		error(value, 2)
	end
	if type(value) == "function" then
		return function(_, ...)
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			local results = table.pack(value(inst, table.unpack(args, 1, args.n)))
			for i = 1, results.n do
				results[i] = wrap(results[i])
			end
			return table.unpack(results, 1, results.n)
		end
	end
	return wrap(value)
end
proxyMeta.__newindex = function(p, key, value)
	realOf[p][key] = unwrap(value)
	signalFor(idOf(realOf[p]), "changed:" .. key):Fire()
end

-- Servicios
local dataModel = roblox.Instance.new("DataModel")
local services = {}
for _, name in { "Workspace", "ReplicatedStorage", "SoundService", "Lighting" } do
	services[name] = dataModel:GetService(name)
end
services.Lighting.ClockTime = 14 -- (Lune no le da valor por defecto)
local configModule = roblox.Instance.new("ModuleScript")
configModule.Name = "TycoonConfig"
configModule.Parent = services.ReplicatedStorage
local remotes = roblox.Instance.new("Folder")
remotes.Name = "TycoonRemotes"
remotes.Parent = services.ReplicatedStorage
local function remote(className, name)
	local r = roblox.Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
remote("RemoteFunction", "Action")
local stateRemote = remote("RemoteEvent", "State")
local notifyRemote = remote("RemoteEvent", "Notify")
local openRemote = remote("RemoteEvent", "OpenComputer")
local visitRemote = remote("RemoteEvent", "Visit")

-- Carteles del mundo (como los que crea el servidor) para probar su traducción
local worldBoard = roblox.Instance.new("Part")
worldBoard.Parent = services.Workspace
local worldGui = roblox.Instance.new("SurfaceGui")
worldGui.Parent = worldBoard
local worldLabel = roblox.Instance.new("TextLabel")
worldLabel.Text = "🏗️ PARCELA LIBRE"
worldLabel.Parent = worldGui
local worldInfo = roblox.Instance.new("TextLabel")
worldInfo.Text = "12 plantas · $1.50K/s · 👍 3"
worldInfo.Parent = worldGui
local worldPrompt = roblox.Instance.new("ProximityPrompt")
worldPrompt.ActionText = "Ver imperio"
worldPrompt.Parent = worldBoard

local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
local playerFolder = roblox.Instance.new("Folder")
playerFolder.Name = "Jorge"
playerGui.Parent = playerFolder
local player = wrap(playerFolder)
overrides[player] = { UserId = 42, Character = false, LocaleId = "es-es" }

overrides[wrap(services.Workspace)] = {
	CurrentCamera = {
		ViewportSize = roblox.Vector2.new(1280, 720),
		GetPropertyChangedSignal = function() return newSignal() end,
	},
}
local renderStepped = newSignal()
local inputBegan = newSignal()
local mocks = {
	Players = { LocalPlayer = player },
	RunService = { RenderStepped = renderStepped, IsStudio = function() return true end },
	TweenService = { Create = function(_, inst, _i, props) return { Play = function() for k, v in props do inst[k] = v end end, Completed = newSignal() } end },
	UserInputService = { InputBegan = inputBegan },
	MarketplaceService = {
		PromptGamePassPurchase = function() end,
		PromptProductPurchase = function() end,
		GetProductInfo = function() return { PriceInRobux = 99 } end,
	},
	SocialService = { CanSendGameInviteAsync = function() return true end, PromptGameInvite = function() end },
	GuiService = { GetGuiInset = function() return roblox.Vector2.new(0, 58), roblox.Vector2.new(0, 0) end },
}
local game = {
	GetService = function(_, name)
		if mocks[name] then
			return mocks[name]
		end
		return wrap(assert(services[name], "servicio no simulado: " .. name))
	end,
}

local delayed = {}
local task = {
	spawn = function(fn, ...) fn(...) end,
	delay = function(_, fn, ...) table.insert(delayed, { fn, table.pack(...) }) end,
	wait = function() end,
}

local function env(script)
	local e = {
		game = game,
		script = script,
		Instance = { new = function(className) return wrap(roblox.Instance.new(className)) end },
		task = task,
		Enum = roblox.Enum,
		TweenInfo = { new = function() return {} end },
		typeof = function(v)
			if type(v) == "table" and realOf[v] then return "Instance" end
			return typeof(v)
		end,
	}
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "ColorSequence" } do
		e[name] = roblox[name]
	end
	return setmetatable(e, { __index = _G })
end

local Config = luau.load(configSource, { debugName = "TycoonConfig", environment = env(nil) })()
local CareerCfg = luau.load(careerSource, { debugName = "CareerConfig", environment = env(nil) })()
local MarketCfg = luau.load(marketSource, { debugName = "MarketConfig", environment = env(nil) })()
local marketModule = roblox.Instance.new("ModuleScript")
marketModule.Name = "MarketConfig"
marketModule.Parent = services.ReplicatedStorage
local careerModule = roblox.Instance.new("ModuleScript")
careerModule.Name = "CareerConfig"
careerModule.Parent = services.ReplicatedStorage
local localeEnModule = roblox.Instance.new("ModuleScript")
localeEnModule.Name = "LocaleEN"
localeEnModule.Parent = services.ReplicatedStorage
local localeModule = roblox.Instance.new("ModuleScript")
localeModule.Name = "Locale"
localeModule.Parent = services.ReplicatedStorage
local patchModule = roblox.Instance.new("ModuleScript")
patchModule.Name = "StatePatch"
patchModule.Parent = services.ReplicatedStorage
local StatePatchMod = luau.load(patchSource, { debugName = "StatePatch", environment = env(nil) })()
local storyModule = roblox.Instance.new("ModuleScript")
storyModule.Name = "StoryConfig"
storyModule.Parent = services.ReplicatedStorage
local EN = luau.load(localeEnSource, { debugName = "LocaleEN", environment = env(nil) })()
local PT = luau.load(localePtSource, { debugName = "LocalePT", environment = env(nil) })()
local localePtModule = roblox.Instance.new("ModuleScript")
localePtModule.Name = "LocalePT"
localePtModule.Parent = services.ReplicatedStorage
local localeEnv = env(wrap(localeModule))
localeEnv.require = function(m)
	return if realOf[m] and realOf[m].Name == "LocalePT" then PT else EN
end
local Locale = luau.load(localeSource, { debugName = "Locale", environment = localeEnv })()
-- Textos que el cliente pide traducir y no están en el diccionario
local missing = {}
Locale.onMissing = function(text, lang)
	missing[text] = lang or true
end
local modulesByName = { CareerConfig = CareerCfg, MarketConfig = MarketCfg, Locale = Locale, LocaleEN = EN, LocalePT = PT, TycoonConfig = Config, StatePatch = StatePatchMod }
modulesByName.StoryConfig = luau.load(storySource, { debugName = "StoryConfig", environment = env(nil) })()
-- PlayerScripts: el LocalScript y la carpeta ClientUI con sus módulos (v4)
local playerScripts = roblox.Instance.new("Folder")
playerScripts.Name = "PlayerScripts"
local clientScript = roblox.Instance.new("LocalScript")
clientScript.Name = "TycoonClient"
clientScript.Parent = playerScripts
local clientUIFolder = roblox.Instance.new("Folder")
clientUIFolder.Name = "ClientUI"
clientUIFolder.Parent = playerScripts
local uiSources = {}
for _, file in fs.readDir(SRC .. "/StarterPlayerScripts/ClientUI") do
	if string.sub(file, -5) == ".luau" then
		local name = string.sub(file, 1, -6)
		uiSources[name] = fs.readFile(SRC .. "/StarterPlayerScripts/ClientUI/" .. file)
		local module = roblox.Instance.new("ModuleScript")
		module.Name = name
		module.Parent = clientUIFolder
	end
end
local loadedUI = {}
local function clientRequire(m)
	local inst = realOf[m]
	local name = inst and inst.Name
	if inst and inst.Parent and inst.Parent.Name == "ClientUI" and uiSources[name] then
		if loadedUI[name] == nil then
			local moduleEnv = env(m)
			moduleEnv.require = clientRequire
			loadedUI[name] = luau.load(uiSources[name], { debugName = name, environment = moduleEnv })()
		end
		return loadedUI[name]
	end
	return assert(modulesByName[name], "módulo desconocido: " .. tostring(name))
end
local clientEnv = env(wrap(clientScript))
clientEnv.require = clientRequire
luau.load(clientSource, { debugName = "TycoonClient", environment = clientEnv })()

local function countGui()
	local n = 0
	for _ in playerGui:GetDescendants() do n += 1 end
	return n
end
print("Interfaz creada · objetos:", countGui())

-- Estado real del servidor y algunas variantes
local function fireState(s)
	signalFor(idOf(stateRemote), "OnClientEvent"):Fire(s)
	renderStepped:Fire(0.016)
end
stateJson.tutorialDone = false
-- Una misión diaria y una semanal completadas (para pulsar "Reclamar")
for _, list in { stateJson.dailyMissions.list, stateJson.weeklyMissions.list } do
	if list[1] then
		list[1].progress = list[1].target
		list[1].claimed = false
	end
end
fireState(stateJson)
-- Un parche (lo normal cada segundo): solo cambian unas pocas cosas
do
	local changed = serde.decode("json", serde.encode("json", stateJson))
	changed.money += 1234
	changed.offers[1] = nil
	if changed.sites[1] then changed.sites[1].totalVisits += 10 end
	changed.project = nil
	local patch = StatePatchMod.diff(stateJson, changed)
	signalFor(idOf(stateRemote), "OnClientEvent"):Fire(serde.decode("json", serde.encode("json", patch)), true)
	renderStepped:Fire(0.016)
	-- Y al revés, para dejarlo como estaba
	signalFor(idOf(stateRemote), "OnClientEvent"):Fire(serde.decode("json", serde.encode("json", StatePatchMod.diff(changed, stateJson))), true)
	renderStepped:Fire(0.016)
	-- Comprobación del formato: aplicar el parche a una copia da el estado nuevo
	local rebuilt = StatePatchMod.apply(serde.decode("json", serde.encode("json", stateJson)), serde.decode("json", serde.encode("json", patch)))
	assert(serde.encode("json", rebuilt) == serde.encode("json", changed) or rebuilt.money == changed.money, "el parche no reconstruye el estado")
	print("Parches de estado OK")
end

-- Variante: proyecto en marcha, evento activo, regalo y diaria disponibles
local s2 = serde.decode("json", serde.encode("json", stateJson))
s2.project = { type = "blog", progress = 10, required = 60 }
s2.event = { name = "🔥 viral", timeLeft = 20 }
s2.giftLeft = 0
s2.dailyAvailable = true
s2.dailyDay = 7
s2.bonuses.boost = true
s2.boostLeft = 100
s2.socialBonus = 0.2
s2.ipoShares = 3
s2.career.agency = { name = "Jorge Dev Studio", officeLevel = 2, capacity = 7, upgradeCost = 45000,
	totals = { work = 48, money = 0.05, quality = 0.06, visits = 0.1, sale = 0.02, rare = 0.03 } }
local function stats(money, quality, visits, sale, rare)
	return { money = money, quality = quality, visits = visits, sale = sale, rare = rare }
end
s2.career.programmers = {
	{ id = 1, name = "Lucía M.", rarity = "epico", niche = "gaming", level = 2, role = "marketing", trait = "noctambulo", xp = 300, xpNeeded = 960,
		work = 46, stats = stats(0.04, 0, 0.1, 0, 0), trainCost = 5000 },
	{ id = 2, name = "Hugo P.", rarity = "comun", niche = "salud", level = 1, role = "design", trait = "mentor", xp = 10, xpNeeded = 240,
		work = 2, stats = stats(0.0025, 0.004, 0, 0, 0), trainCost = 900 },
	{ id = 3, name = "Mei K.", rarity = "legendario", niche = "tech", level = 10, role = "data", trait = "suertudo", xp = 0, xpNeeded = 24000,
		work = 120, stats = stats(0.1, 0, 0, 0, 0.5), trainCost = 900 },
}
s2.career.tickets = { premium = 2, legendary = 1 }
s2.career.rank = 3
s2.career.slots = 2
s2.career.fair = true
s2.career.askLeft = 0
s2.career.board = {
	{ id = 7, companyId = 12, type = "blog", niche = "ecommerce", pay = 9000, rep = 6, xp = 30, duration = 300, timeLeft = 200 },
	{ id = 8, companyId = 60, type = "landing", niche = "gaming", pay = 3000, rep = 2, xp = 10, duration = 180, timeLeft = 40 },
}
s2.career.contracts = {
	{ id = 5, companyId = 3, type = "blog", niche = "ecommerce", pay = 9500, rep = 6, xp = 30, duration = 300, timeLeft = 50, working = true },
}
-- Ranking: vecinos, top semanal y de siempre, evento de fin de semana y dorado
s2.neighbors = {
	{ userId = 43, name = "Ana", floors = 7, likes = 2, liked = false },
	{ userId = 44, name = "Leo", floors = 3, likes = 0, liked = true },
}
s2.weekly = { earned = 5000, resetIn = 90000, top = {} }
for i = 1, 10 do
	table.insert(s2.weekly.top, { name = "Jugador" .. i, value = 1e6 / i, userId = if i == 4 then 42 else 100 + i })
end
s2.globalTop = { { name = "Ana", value = 5e9, userId = 43 } }
s2.weekend = { id = "contracts", endsIn = 7200, nextId = "money", startsIn = 500000 }
s2.goldLeft = 3600
s2.likes = 5
-- v2.0: patentes, tiempo jugado, pase, evento del servidor, meta común, colección
s2.patents = 30
s2.playtime = { seconds = 6000, claimed = { ["1"] = true } }
s2.season.xp = 2500
s2.season.premium = true
s2.serverEvent = { id = "datastorm", endsIn = 90 }
s2.community = { target = 50000, progress = 20000, endsIn = 600 }
s2.starterLeft = 3600
s2.collection = { landing = { normal = true, brillante = true, arcoiris = true, diamante = true, cosmica = true }, blog = { normal = true } }
s2.sites[1].variant = "diamante"
fireState(s2)
-- v2.1: una semanal lista para reclamar
for _, mission in s2.weeklyMissions.list do
	mission.claimed = false
	mission.progress = mission.target
end
-- Jugador nuevo: casi todas las pestañas con candado
local sNew = serde.decode("json", serde.encode("json", s2))
sNew.lifetimeEarned = 0
fireState(sNew)
local locked = 0
for _, d in playerGui:GetDescendants() do
	if d:IsA("TextButton") and string.sub(d.Text, 1, #"🔒") == "🔒" then
		locked += 1
		signalFor(idOf(d), "Activated"):Fire()
	end
end
print("Pestañas con candado para un jugador nuevo:", locked)
assert(locked >= 9, "un jugador nuevo debería ver las pestañas bloqueadas")
fireState(s2)
-- Sin evento de fin de semana (muestra el próximo); encargo sin empezar
local s3 = serde.decode("json", serde.encode("json", s2))
s3.project = nil
s3.career.contracts[1].working = false
s3.career.contracts[2] = { id = 6, companyId = 9, type = "landing", niche = "salud", pay = 2000, rep = 2, xp = 10, duration = 180, timeLeft = 170, working = false }
s3.career.rank = 5
s3.weekend = { endsIn = 0, nextId = "viral", startsIn = 100000 }
s3.goldLeft = 0
fireState(s3)

-- Avisos y ventanas emergentes
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Hola", "money")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Título", "popup", "Cuerpo")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Otro", "popup", "En cola")
signalFor(idOf(openRemote), "OnClientEvent"):Fire()

-- Pulsar todos los botones (varias pasadas, porque abrir pestañas crea filas)
local pressed = 0
for pass = 1, 3 do
	for _, d in playerGui:GetDescendants() do
		-- (el botón de idioma se prueba aparte, más abajo; los botones que
		-- otro botón ya ha borrado se saltan)
		local alive, id = pcall(idOf, d)
		if alive and d:IsA("TextButton") and string.sub(d.Text, 1, #"🌐") ~= "🌐" then
			signalFor(id, "Activated"):Fire()
			signalFor(id, "MouseEnter"):Fire()
			signalFor(id, "MouseLeave"):Fire()
			pressed += 1
		end
	end
	fireState(s2)
end
-- Teclas
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.F }, false)
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.M }, false)
-- Ejecutar los task.delay pendientes (avisos que desaparecen, el tutorial...)
for _, item in delayed do
	item[1](table.unpack(item[2], 1, item[2].n))
end
-- Recorrer el tutorial entero pulsando sus botones
local tutorialGui = playerGui:FindFirstChild("ImperioWebTutorial")
assert(tutorialGui and tutorialGui.Enabled, "el tutorial no arrancó")
for step = 1, 10 do
	fireState(s2)
	for _, d in tutorialGui:GetDescendants() do
		if d:IsA("TextButton") and d.Text:find("Siguiente") or (d:IsA("TextButton") and d.Text:find("Empezar")) then
			signalFor(idOf(d), "Activated"):Fire()
		end
	end
end
print("Tutorial recorrido · sigue activo:", tutorialGui.Enabled)
fireState(stateJson)

-- Ficha de otro imperio
signalFor(idOf(visitRemote), "OnClientEvent"):Fire(visitJson)
assert(worldLabel.Text == "🏗️ PARCELA LIBRE", "en español el cartel no cambia: " .. worldLabel.Text)

---------------------------------------------------------------------
-- v4 bloque 3: centros con sub-pestañas, pensados para móvil
---------------------------------------------------------------------
do
	local ui = loadedUI.Core
	assert(ui and ui.HUBS, "Core no expone los centros")
	-- Móvil apaisado típico (844 × 390) y vertical (390 × 844)
	for _, viewport in { roblox.Vector2.new(844, 390), roblox.Vector2.new(390, 844), roblox.Vector2.new(1920, 1080) } do
		ui.resizeWindow(viewport)
		local scale = ui.window:FindFirstChildOfClass("UIScale").Scale
		local hubHeight = ui.hubBar.Size.Y.Offset * scale
		local subHeight = ui.subBar.Size.Y.Offset * scale
		local windowHeight = ui.window.Size.Y.Offset * scale
		local windowWidth = ui.window.Size.X.Offset * scale
		print(string.format("  pantalla %dx%d: escala %.2f · centros %d px · pestañas %d px · ventana %dx%d px",
			viewport.X, viewport.Y, scale, hubHeight, subHeight, windowWidth, windowHeight))
		assert(hubHeight >= 44 and subHeight >= 44, "botones de menos de 44 px")
		-- (la barra de Roblox ocupa 58 px arriba: GuiService simulado)
		assert(windowHeight <= viewport.Y - 58 and windowWidth <= viewport.X, "la ventana no cabe en la pantalla")
	end
	assert(#ui.HUBS == 5, "deberían ser 5 centros")
	local seen = {}
	for _, hub in ui.HUBS do
		assert(#hub.tabs <= 5, "más de 5 pestañas en un centro: " .. hub.id)
		for _, id in hub.tabs do
			assert(not seen[id], "pestaña en dos centros: " .. id)
			seen[id] = true
			assert(ui.pages[id], "pestaña sin página: " .. id)
		end
	end
	for _, tab in ui.TABS do
		assert(seen[tab.id], "pestaña sin centro: " .. tab.id)
	end
	-- Pulsar cada centro abre una de sus pestañas (están todas desbloqueadas aquí)
	for _, hub in ui.HUBS do
		signalFor(idOf(ui.hubButtons[hub.id]), "Activated"):Fire()
		assert(ui.currentHub == hub.id and ui.hubOfTab[ui.currentTab] == hub, "el centro " .. hub.id .. " no abrió su pestaña")
		local visible = 0
		for _, child in ui.subBar:GetChildren() do
			if child:IsA("TextButton") and child.Visible then visible += 1 end
		end
		assert(visible == #hub.tabs, "se ven " .. visible .. " pestañas en " .. hub.id)
	end
	ui.selectTab("create")
	print("Centros OK: 5 centros, " .. #ui.TABS .. " pestañas, máximo 5 por fila")
end

---------------------------------------------------------------------
-- Ahora en inglés y luego en portugués: botón 🌐 y otra vez todas las
-- pestañas y botones (ES → EN → PT → ES)
---------------------------------------------------------------------
local languageButton = nil
for _, d in playerGui:GetDescendants() do
	if d:IsA("TextButton") and d.Text == "🌐 ES" then
		languageButton = d
	end
end
assert(languageButton, "no está el botón de idioma")

-- Palabras que delatan un texto que se ha quedado en español
local SPANISH = {
	en = { " de ", " la ", " el ", " tu ", " tus ", " para ", " con ", " por ", " en ", " una ", " del ", " los ", " las ", " y ", "¿", "¡", "á", "é", "í", "ó", "ú", "ñ" },
	-- (el portugués comparte muchas: solo las que son solo del español)
	pt = { " el ", " los ", " las ", " y ", " del ", " tu ", " tus ", " una ", " con ", " muy ", " pero ", " hay ", " ya ", " ha ", " has ",
		" un ", " al ", " la ", " es ", "ción", "ión ", " más ", " aún ", "¿", "¡", "ñ" },
}
local properNames = { "Jorge", "Ana", "Dev Studio" }
for _, c in CareerCfg.Companies do table.insert(properNames, c.name) end
for _, n in CareerCfg.FirstNames do table.insert(properNames, n) end
table.sort(properNames, function(a, b) return #a > #b end)
local function stripName(text, name)
	local i = string.find(text, name, 1, true)
	while i do
		text = string.sub(text, 1, i - 1) .. string.sub(text, i + #name)
		i = string.find(text, name, 1, true)
	end
	return text
end

local function languagePass(code, label, expected)
	table.clear(missing)
	signalFor(idOf(languageButton), "Activated"):Fire()
	assert(languageButton.Text == "🌐 " .. string.upper(code), "el botón de idioma no cambió: " .. languageButton.Text)
	assert(worldLabel.Text == expected.board, "el cartel del mundo no se tradujo: " .. worldLabel.Text)
	assert(worldInfo.Text == expected.info, "el cartel con datos no se tradujo: " .. worldInfo.Text)
	assert(worldPrompt.ActionText == expected.prompt, "el ProximityPrompt no se tradujo: " .. worldPrompt.ActionText)
	local sLang = serde.decode("json", serde.encode("json", s2))
	sLang.settings.lang = code
	for _ = 1, 2 do
		for _, d in playerGui:GetDescendants() do
			-- Pulsar un botón puede borrar otros (filas, ventanas): esos se saltan
			local alive, id = pcall(idOf, d)
			if alive and d:IsA("TextButton") and d ~= languageButton then
				signalFor(id, "Activated"):Fire()
			end
		end
		fireState(sLang)
	end
	-- Avisos y ventanas que manda el servidor (en español) → deben salir traducidos
	signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("💾 Partida guardada", "success")
	signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("😴 ¡Bienvenido de vuelta!", "popup", "Mientras no estabas (1h 00m) tus webs y empresas ganaron\n$19.0K")
	signalFor(idOf(visitRemote), "OnClientEvent"):Fire(visitJson)
	fireState(sLang)
	-- Abrir las ventanas que estaban en cola y pulsar su botón (la ficha da "me gusta")
	for _ = 1, 40 do
		local pending = delayed
		delayed = {}
		for _, item in pending do
			item[1](table.unpack(item[2], 1, item[2].n))
		end
		local modal = playerGui:FindFirstChild("ImperioWebModal")
		if modal and modal.Enabled then
			for _, d in modal:GetDescendants() do
				if d:IsA("TextButton") then
					signalFor(idOf(d), "Activated"):Fire()
				end
			end
		end
	end
	-- Buscar textos que se hayan quedado en español
	local leftovers = {}
	for _, d in playerGui:GetDescendants() do
		-- Los números flotantes del clic duran 0,8 s (aquí no se borran porque
		-- Lune no ejecuta animaciones): los de antes del cambio de idioma no cuentan
		local isText = d:IsA("TextLabel") or d:IsA("TextButton")
		local transient = isText and string.find(d.Text, "¡CRÍTICO!", 1, true) ~= nil
		if isText and d.Text ~= "" and not transient then
			local clean = " " .. d.Text .. " "
			for _, name in properNames do
				clean = stripName(clean, name)
			end
			for _, word in SPANISH[code] do
				if string.find(clean, word, 1, true) then
					leftovers[d.Text] = word
					break
				end
			end
		end
	end
	local nLeft = 0
	for text, word in leftovers do
		nLeft += 1
		print("  EN ESPAÑOL [" .. word .. "]: " .. string.gsub(text, "\n", " / "))
	end
	local nMissing = 0
	for text in missing do
		nMissing += 1
		print("  FALTA EN EL DICCIONARIO (" .. code .. "): " .. string.gsub(text, "\n", " / "))
	end
	print(label .. ": textos en español que quedan", nLeft, "· claves que faltan", nMissing)
	assert(nLeft == 0 and nMissing == 0, "faltan traducciones (" .. code .. ")")
end

languagePass("en", "Inglés", { board = "🏗️ FREE PLOT", info = "12 floors · $1.50K/s · 👍 3", prompt = "View empire" })
languagePass("pt", "Portugués", { board = "🏗️ TERRENO LIVRE", info = "12 andares · $1.50K/s · 👍 3", prompt = "Ver império" })
-- Toda clave de LocaleEN tiene que estar en LocalePT (y al revés)
local onlyEn, onlyPt = 0, 0
for key in EN do
	if PT[key] == nil then onlyEn += 1 print("  FALTA EN LocalePT: " .. key) end
end
for key in PT do
	if EN[key] == nil then onlyPt += 1 print("  SOBRA EN LocalePT: " .. key) end
end
assert(onlyEn == 0 and onlyPt == 0, "LocaleEN y LocalePT no tienen las mismas claves")
-- Y volver al español
signalFor(idOf(languageButton), "Activated"):Fire()
assert(languageButton.Text == "🌐 ES", "el botón no volvió al español")
assert(worldLabel.Text == "🏗️ PARCELA LIBRE", "el cartel no volvió al español")
fireState(stateJson)

local counts = {}
for _, a in invoked do counts[a] = (counts[a] or 0) + 1 end
local list = {}
for a, n in counts do table.insert(list, a .. "×" .. n) end
table.sort(list)
print("Botones pulsados:", pressed)
print("Acciones enviadas:", table.concat(list, ", "))
print("Objetos de interfaz al final:", countGui())
print("CLIENTE OK")
process.exit(0)
