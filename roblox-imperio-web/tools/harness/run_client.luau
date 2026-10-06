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
local clientSource = fs.readFile(SRC .. "/StarterPlayerScripts/TycoonClient.client.luau")
local localeSource = fs.readFile(SRC .. "/ReplicatedStorage/Locale.luau")
local localeEnSource = fs.readFile(SRC .. "/ReplicatedStorage/LocaleEN.luau")
local stateJson = serde.decode("json", fs.readFile("state.json"))
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
for _, name in { "Workspace", "ReplicatedStorage", "SoundService" } do
	services[name] = dataModel:GetService(name)
end
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
local careerModule = roblox.Instance.new("ModuleScript")
careerModule.Name = "CareerConfig"
careerModule.Parent = services.ReplicatedStorage
local localeEnModule = roblox.Instance.new("ModuleScript")
localeEnModule.Name = "LocaleEN"
localeEnModule.Parent = services.ReplicatedStorage
local localeModule = roblox.Instance.new("ModuleScript")
localeModule.Name = "Locale"
localeModule.Parent = services.ReplicatedStorage
local EN = luau.load(localeEnSource, { debugName = "LocaleEN", environment = env(nil) })()
local localeEnv = env(wrap(localeModule))
localeEnv.require = function() return EN end
local Locale = luau.load(localeSource, { debugName = "Locale", environment = localeEnv })()
-- Textos que el cliente pide traducir y no están en el diccionario
local missing = {}
Locale.onMissing = function(text)
	missing[text] = true
end
local modulesByName = { CareerConfig = CareerCfg, Locale = Locale, LocaleEN = EN, TycoonConfig = Config }
local clientEnv = env(nil)
clientEnv.require = function(m)
	return assert(modulesByName[realOf[m] and realOf[m].Name], "módulo desconocido")
end
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
fireState(stateJson)

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
s2.career.agency = { name = "Jorge Dev Studio", officeLevel = 2, capacity = 7, upgradeCost = 45000 }
s2.career.job = { companyId = 3, rank = 2, salary = 12, xpRate = 2, promotion = "Faltan 3 min", taskLeft = 0 }
s2.career.programmers = {
	{ id = 1, name = "Lucía M.", rarity = "epico", niche = "gaming", level = 2, work = 46, bonus = 0.17, trainCost = 5000 },
	{ id = 2, name = "Hugo P.", rarity = "comun", niche = "salud", level = 1, work = 2, bonus = 0.01, trainCost = 900 },
}
s2.career.tickets = { premium = 2, legendary = 1 }
s2.career.jobOffers = {
	{ id = 1, companyId = 12, rank = 1, salaryMult = 1.42, xpMult = 0.9, salary = 20, xpRate = 3, timeLeft = 120 },
	{ id = 2, companyId = 60, rank = 2, salaryMult = 0.8, xpMult = 1.3, salary = 9, xpRate = 5, timeLeft = 40 },
}
s2.career.cvLeft = 0
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
s2.weekend = { id = "jobs", endsIn = 7200, nextId = "money", startsIn = 500000 }
s2.goldLeft = 3600
s2.likes = 5
fireState(s2)
-- Sin evento de fin de semana (muestra el próximo)
local s3 = serde.decode("json", serde.encode("json", s2))
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
		-- (el botón de idioma se prueba aparte, más abajo)
		if d:IsA("TextButton") and string.sub(d.Text, 1, #"🌐") ~= "🌐" then
			signalFor(idOf(d), "Activated"):Fire()
			signalFor(idOf(d), "MouseEnter"):Fire()
			signalFor(idOf(d), "MouseLeave"):Fire()
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
-- Ahora en inglés: botón 🌐 y otra vez todas las pestañas y botones
---------------------------------------------------------------------
local languageButton = nil
for _, d in playerGui:GetDescendants() do
	if d:IsA("TextButton") and d.Text == "🌐 ES" then
		languageButton = d
	end
end
assert(languageButton, "no está el botón de idioma")
signalFor(idOf(languageButton), "Activated"):Fire()
assert(languageButton.Text == "🌐 EN", "el botón de idioma no cambió")
assert(worldLabel.Text == "🏗️ FREE PLOT", "el cartel del mundo no se tradujo: " .. worldLabel.Text)
assert(worldInfo.Text == "12 floors · $1.50K/s · 👍 3", "el cartel con datos no se tradujo: " .. worldInfo.Text)
assert(worldPrompt.ActionText == "View empire", "el ProximityPrompt no se tradujo")
local sEn = serde.decode("json", serde.encode("json", s2))
sEn.settings.lang = "en"
for _ = 1, 2 do
	for _, d in playerGui:GetDescendants() do
		-- Pulsar un botón puede borrar otros (filas, ventanas): esos se saltan
		local alive, id = pcall(idOf, d)
		if alive and d:IsA("TextButton") and d ~= languageButton then
			signalFor(id, "Activated"):Fire()
		end
	end
	fireState(sEn)
end
-- Avisos y ventanas que manda el servidor (en español) → deben salir en inglés
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("💾 Partida guardada", "success")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("😴 ¡Bienvenido de vuelta!", "popup", "Mientras no estabas (1h 00m) tus webs y empresas ganaron\n$19.0K")
signalFor(idOf(visitRemote), "OnClientEvent"):Fire(visitJson)
fireState(sEn)
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
local properNames = { "Jorge", "Ana", "Dev Studio" }
for _, c in CareerCfg.Companies do table.insert(properNames, c.name) end
for _, n in CareerCfg.FirstNames do table.insert(properNames, n) end
table.sort(properNames, function(a, b) return #a > #b end)
local SPANISH = { " de ", " la ", " el ", " tu ", " tus ", " para ", " con ", " por ", " en ", " una ", " del ", " los ", " las ", " y ", "¿", "¡", "á", "é", "í", "ó", "ú", "ñ" }
local function stripName(text, name)
	local i = string.find(text, name, 1, true)
	while i do
		text = string.sub(text, 1, i - 1) .. string.sub(text, i + #name)
		i = string.find(text, name, 1, true)
	end
	return text
end
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
		for _, word in SPANISH do
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
	print("  FALTA EN EL DICCIONARIO: " .. string.gsub(text, "\n", " / "))
end
print("Inglés: textos en español que quedan", nLeft, "· claves que faltan", nMissing)
assert(nLeft == 0 and nMissing == 0, "faltan traducciones")
-- Y volver al español
signalFor(idOf(languageButton), "Activated"):Fire()
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
