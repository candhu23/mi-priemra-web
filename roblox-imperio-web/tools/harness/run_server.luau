-- Ejecuta TycoonServer real con servicios simulados y un jugador falso que
-- recorre todas las acciones. Falla con error si algo revienta.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local SRC = process.args[1]
local sources = {}
local function readSource(path)
	if not sources[path] then
		sources[path] = fs.readFile(path)
	end
	return sources[path]
end
for _, rel in { "/ReplicatedStorage/CareerConfig.luau", "/ServerScriptService/CareerService.luau", "/ReplicatedStorage/TycoonConfig.luau", "/ServerScriptService/Building.luau", "/ServerScriptService/World.luau", "/ServerScriptService/PlotManager.luau", "/ServerScriptService/TycoonServer.server.luau" } do
	readSource(SRC .. rel)
end

local realOf = setmetatable({}, { __mode = "k" })
local proxyByKey = {}
local overrides = setmetatable({}, { __mode = "k" })
local callbacks = {}
local fired = {} -- llamadas a FireClient
local EVENTS = { Triggered = true, Changed = true, Touched = true, Activated = true, Completed = true, CharacterAdded = true }
local NOOP_METHODS = { Emit = true, Play = true, Stop = true }

local function signal()
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

local wrap, unwrap
local proxyMeta = {}
local idCounter = 0
local idOf = setmetatable({}, { __mode = "k" })

function wrap(v)
	if typeof(v) == "Instance" then
		-- Lune crea objetos distintos para la misma instancia: usamos un atributo como id
		local id = v:GetAttribute("__hid")
		if not id then
			idCounter += 1
			id = idCounter
			v:SetAttribute("__hid", id)
		end
		local p = proxyByKey[id]
		if not p then
			p = setmetatable({}, proxyMeta)
			realOf[p] = v
			proxyByKey[id] = p
		end
		return p
	elseif type(v) == "table" and not realOf[v] and getmetatable(v) == nil then
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
	if EVENTS[key] then
		return signal()
	end
	if key == "GetPropertyChangedSignal" or key == "GetAttributeChangedSignal" then
		return function() return signal() end
	end
	if key == "FireClient" or key == "FireAllClients" then
		return function(_, plr, ...)
			table.insert(fired, { inst.Name, ... })
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
		if NOOP_METHODS[key] then
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
	if key == "OnServerInvoke" or key == "OnClientInvoke" then
		callbacks[realOf[p].Name] = value
		return
	end
	realOf[p][key] = unwrap(value)
end
proxyMeta.__tostring = function(p)
	return tostring(realOf[p])
end

-- Servicios simulados
local tagged = {}
local CollectionService = {
	AddTag = function(_, inst, tag)
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], inst)
	end,
	-- Como en Roblox: solo devuelve instancias que siguen en el juego
	GetTagged = function(_, tag)
		local alive = {}
		for _, inst in tagged[tag] or {} do
			local ok, parent = pcall(function() return realOf[inst].Parent end)
			if ok and parent ~= nil then
				table.insert(alive, inst)
			end
		end
		tagged[tag] = alive
		return alive
	end,
}
local TweenService = {
	Create = function(_, inst, _info, props)
		return { Play = function() for k, v in props do inst[k] = v end end, Completed = signal() }
	end,
}
local saved = {}
local DataStoreService = {
	GetDataStore = function()
		return {
			GetAsync = function(_, key) return saved[key] end,
			UpdateAsync = function(_, key, fn) saved[key] = fn(saved[key]) end,
		}
	end,
	GetOrderedDataStore = function()
		local scores = {}
		return {
			SetAsync = function(_, key, value)
				assert(value == math.floor(value), "puntuación no entera")
				scores[key] = value
			end,
			GetSortedAsync = function()
				return { GetCurrentPage = function()
					local list = {}
					for k, v in scores do table.insert(list, { key = k, value = v }) end
					return list
				end }
			end,
		}
	end,
}
local MarketplaceService = {
	PromptGamePassPurchaseFinished = signal(),
	UserOwnsGamePassAsync = function() return true end,
}
local playersFolder
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function() return {} end,
	GetNameFromUserIdAsync = function(_, id) return "Jugador" .. id end,
}

local dataModel = roblox.Instance.new("DataModel")
local services = {}
for _, name in { "Workspace", "Lighting", "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
	services[name] = dataModel:GetService(name)
end
playersFolder = roblox.Instance.new("Folder")
playersFolder.Name = "Players"
playersFolder.Parent = dataModel

local closeHandlers = {}
local game = {
	GetService = function(_, name)
		local mocks = {
			CollectionService = CollectionService, TweenService = TweenService, DataStoreService = DataStoreService,
			MarketplaceService = MarketplaceService, Players = Players,
			PolicyService = { GetPolicyInfoForPlayerAsync = function() return { ArePaidRandomItemsRestricted = false } end },
		}
		if mocks[name] then
			return mocks[name]
		end
		return wrap(assert(services[name], "servicio no simulado: " .. name))
	end,
	BindToClose = function(_, fn) table.insert(closeHandlers, fn) end,
}

local modulePaths = {}
local function addModule(parent, className, name, path)
	local m = roblox.Instance.new(className)
	m.Name = name
	m.Parent = parent
	modulePaths[m:GetFullName()] = path
	return m
end
addModule(services.ReplicatedStorage, "ModuleScript", "TycoonConfig", SRC .. "/ReplicatedStorage/TycoonConfig.luau")
addModule(services.ReplicatedStorage, "ModuleScript", "CareerConfig", SRC .. "/ReplicatedStorage/CareerConfig.luau")
addModule(services.ServerScriptService, "ModuleScript", "CareerService", SRC .. "/ServerScriptService/CareerService.luau")
addModule(services.ServerScriptService, "ModuleScript", "Building", SRC .. "/ServerScriptService/Building.luau")
addModule(services.ServerScriptService, "ModuleScript", "World", SRC .. "/ServerScriptService/World.luau")
addModule(services.ServerScriptService, "ModuleScript", "PlotManager", SRC .. "/ServerScriptService/PlotManager.luau")
local serverScript = addModule(services.ServerScriptService, "Script", "TycoonServer", SRC .. "/ServerScriptService/TycoonServer.server.luau")

local Random = {
	new = function(seed)
		return {
			NextNumber = function(_, a, b) a, b = a or 0, b or 1 return a + math.random() * (b - a) end,
			NextInteger = function(_, a, b) return math.random(a, b) end,
		}
	end,
}

local sleeping = {}
local fakeTime = 0
local task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(debug.traceback(co, tostring(err))) end
		if coroutine.status(co) == "suspended" then table.insert(sleeping, co) end
	end,
	delay = function(_, fn, ...) fn(...) end,
	wait = function()
		if coroutine.isyieldable() then coroutine.yield() end
	end,
}

local function makeEnv(inst)
	local env = {
		game = game,
		script = wrap(inst),
		Instance = { new = function(className) return wrap(roblox.Instance.new(className)) end },
		Random = Random,
		task = task,
		Enum = roblox.Enum,
		TweenInfo = { new = function() return {} end },
		os = { time = function() return 1_700_000_000 + math.floor(fakeTime) end, clock = function() return fakeTime end },
		warn = function(...) print("[warn]", ...) end,
		typeof = function(v) if type(v) == "table" and realOf[v] then return "Instance" end return typeof(v) end,
	}
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "ColorSequence" } do
		env[name] = roblox[name]
	end
	return setmetatable(env, { __index = _G })
end

local cache = {}
local function requireModule(moduleProxy)
	local inst = unwrap(moduleProxy)
	local key = inst:GetFullName()
	if cache[key] then return cache[key] end
	local path = assert(modulePaths[key], "módulo desconocido: " .. key)
	local env = makeEnv(inst)
	env.require = requireModule
	local result = luau.load(readSource(path), { debugName = path, environment = env })()
	cache[key] = result
	return result
end

-- IDs de prueba para la tienda (antes de que cargue el servidor)
do
	local cfg = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("TycoonConfig")))
	cfg.Monetization.Products[1].id = 111 -- dinero
	cfg.Monetization.Products[3].id = 333 -- boost
	cfg.Monetization.Products[4].id = 444 -- terminar web
	cfg.Monetization.GamePasses[1].id = 555 -- x2 (UserOwnsGamePassAsync devuelve true)
	cfg.Monetization.Products[5].id = 666 -- headhunter
	cfg.Monetization.Products[7].id = 777 -- contrato legendario
end
-- Arrancar el script del servidor (se queda dormido en su bucle principal)
do
	local env = makeEnv(serverScript)
	env.require = requireModule
	local chunk = luau.load(readSource(SRC .. "/ServerScriptService/TycoonServer.server.luau"), { debugName = "TycoonServer", environment = env })
	task.spawn(chunk)
end
local Config = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("TycoonConfig")))
for k in callbacks do print("callback", k) end print("dormidos", #sleeping) for _, co in sleeping do print(debug.traceback(co)) end
local invoke = assert(callbacks.Action, "no hay OnServerInvoke")

local function tick(seconds)
	fakeTime += seconds
	local list = sleeping
	sleeping = {}
	for _, co in list do
		local ok, err = coroutine.resume(co)
		if not ok then error(debug.traceback(co, tostring(err))) end
		if coroutine.status(co) == "suspended" then table.insert(sleeping, co) end
	end
end

-- Jugador falso
local realPlayer = roblox.Instance.new("Folder")
realPlayer.Name = "Jorge"
realPlayer.Parent = playersFolder
local player = wrap(realPlayer)
overrides[player] = {
	UserId = 42, DisplayName = "Jorge", Name = "Jorge",
	MembershipType = roblox.Enum.MembershipType.None,
	CharacterAdded = signal(),
	Character = false,
	IsFriendsWithAsync = function() return false end,
	IsInGroupAsync = function() return false end,
}
Players.GetPlayerByUserId = function() return player end
Players.PlayerAdded:Fire(player)

local function lastState()
	for i = #fired, 1, -1 do
		if fired[i][1] == "State" then return fired[i][2] end
	end
end

local function act(name, a, b)
	local ok, message, extra = invoke(player, name, a, b)
	print(string.format("  %-14s -> %s %s", name, tostring(ok), tostring(message or "")))
	return ok, message, extra
end

local s = lastState()
assert(s and s.money == Config.STARTING_MONEY, "estado inicial")
print("Estado inicial: dinero", s.money, "huecos", s.slots, "diaria", s.dailyAvailable, s.dailyDay)

act("startProject", "landing")
for _ = 1, 20 do
	invoke(player, "click")
	fakeTime += 0.1
end
tick(1)
s = lastState()
print("Webs tras programar:", #s.sites, "construidas", s.stats.built, "dinero", math.floor(s.money))
assert(#s.sites == 1, "debería haber una web")
local siteId = s.sites[1].id
act("setAdLevel", siteId, 2)
act("upgradeSeo", siteId)
act("claimDaily")
act("claimDaily") -- segunda vez: debe fallar
act("buyCompany", "devs")
act("buyCompany", "hosting")
act("unlockNetwork", "clickboom")
act("setNetworkAll", "adsimple")
-- Mucho dinero para probarlo todo
local session = nil
fakeTime += 700
tick(1)
act("claimGift")
s = lastState()
for _, offer in s.offers do
	if offer.type == "landing" then
		act("sellToOffer", offer.id, siteId)
		break
	end
end
act("startProject", "landing")
for _ = 1, 30 do invoke(player, "click") fakeTime += 0.1 end
tick(1)
s = lastState()
act("quickSell", s.sites[1].id)
act("ipo") -- debe fallar (falta dinero)
act("bogusAction")
act("setAuto", "landing") -- falla sin laboratorio

-- Compra con Robux (producto configurado al vuelo)
local productDef = Config.Monetization.Products[1]
productDef.id = 123
-- productById se construye al cargar: simulamos con un id ya existente
local receiptResult = (MarketplaceService.ProcessReceipt)({ PlayerId = 42, ProductId = 999, PurchaseId = "abc" })
print("  ProcessReceipt (producto desconocido) ->", receiptResult)

local before = lastState().money
print("  receipt dinero   ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 111, PurchaseId = "p1" }))
local after1 = lastState().money
print("  receipt repetido ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 111, PurchaseId = "p1" }))
local after2 = lastState().money
assert(after1 > before and math.abs(after2 - after1) < 1e-6, "la compra repetida no debe pagar dos veces")
print("  receipt boost    ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 333, PurchaseId = "p2" }))
assert(lastState().bonuses.boost, "boost no activo")
act("startProject", "landing")
print("  receipt terminar ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 444, PurchaseId = "p3" }))
assert(lastState().project == nil, "la web debería estar terminada")
print("  pase x2 activo:", lastState().bonuses.pass, "· multiplicador:", lastState().moneyMult)

-- Carrera
local Career = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("CareerConfig")))
local minPay, maxPay = math.huge, 0
for _, c in Career.Companies do minPay = math.min(minPay, c.payScale); maxPay = math.max(maxPay, c.payScale) end
print(string.format("Factor de sueldo por empresa: de x%.2f a x%.2f", minPay, maxPay))
print("Empresas generadas:", #Career.Companies, "· primera:", Career.Companies[1].name, "· última:", Career.Companies[500].name)
local names = {}
for _, c in Career.Companies do
	assert(not names[c.name], "nombre repetido: " .. c.name)
	names[c.name] = true
end
act("setNiche", "gaming")
act("setNiche", "noexiste")
s = lastState()
print("  ofertas iniciales:", #s.career.jobOffers)
for _, o in s.career.jobOffers do
	local company = Career.company(o.companyId)
	print(string.format("    %s (%s, x%.2f paga empresa) · rango %d · x%.2f sueldo · x%.2f XP · %s/s", company.name, company.niche, company.payScale, o.rank, o.salaryMult, o.xpMult, Config.formatMoney(o.salary)))
end
act("acceptJobOffer", s.career.jobOffers[1].id)
act("acceptJobOffer", 99999) -- no existe
act("sendCV")
act("sendCV") -- enfriamiento
act("solveTask") -- aún no
fakeTime += 45
tick(1)
act("solveTask")
s = lastState()
print("  trabajo:", s.career.job and s.career.job.salary, "nivel gaming:", s.career.nicheLevels.gaming, "devLevel:", s.career.devLevel)
act("foundAgency") -- falla: nivel bajo
-- Subir de nivel a lo bruto para probar la agencia
for _ = 1, 400 do
	fakeTime += 1
	tick(1)
end
s = lastState()
print("  tras 400 s: devLevel", s.career.devLevel, "rango", s.career.job and s.career.job.rank, "dinero", Config.formatMoney(s.money))
-- Dar XP directamente si hace falta
local srvSession = nil
act("foundAgency")
s = lastState()
print("  agencia:", s.career.agency and s.career.agency.name)
act("recruit")
act("upgradeOffice")
print("  receipt headhunter ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 666, PurchaseId = "h1" }))
print("  receipt legendario ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 777, PurchaseId = "l1" }))
act("redeemTicket", "premium")
act("redeemTicket", "legendary", "nope")
act("redeemTicket", "legendary", "tech")
s = lastState()
for _, p in s.career.programmers do
	print(string.format("    %s · %s · %s · +%.1f%%", p.name, p.rarity, p.niche, p.bonus * 100))
	act("trainProgrammer", p.id)
end
s = lastState()
print("  bonus agencia:", s.bonuses.agencyBonus, "trabajo:", s.bonuses.agencyWork, "mult:", s.moneyMult)
if #s.career.programmers > 0 then act("fireProgrammer", s.career.programmers[#s.career.programmers].id) end
act("startProject", "landing")
for _ = 1, 30 do invoke(player, "click") fakeTime += 0.1 end
tick(1)
s = lastState()
print("  web nueva nicho:", s.sites[#s.sites] and s.sites[#s.sites].niche)
if s.sites[1] then act("upgradeDesign", s.sites[1].id) end
act("saveNow")
act("saveNow") -- enfriamiento
act("quitJob")

-- Misiones y tutorial
s = lastState()
print("  tutorialDone:", s.tutorialDone, "· misiones diarias:", #s.dailyMissions.list)
for i, m in s.dailyMissions.list do
	print(string.format("    %d. %s %d/%d (dificultad %d)", i, m.id, m.progress, m.target, m.tier))
end
act("claimGoal", "first_site")
act("claimGoal", "first_site") -- ya reclamado
act("claimGoal", "earn_1t") -- no cumplido
act("claimDailyMission", 1)
act("finishTutorial")
act("finishTutorial") -- segunda vez no paga
act("setMuted", true)
s = lastState()
print("  muted:", s.settings.muted, "· objetivos reclamados:", (function() local n = 0 for _ in s.goals do n += 1 end return n end)())

-- 30 ticks de economía
for _ = 1, 30 do tick(1) end
s = lastState()
print(string.format("Tras 30 s: dinero %s · ingresos %s/s · rep %d · objetivos %d", Config.formatMoney(s.money), Config.formatMoney(s.income), s.reputation, (function() local n = 0 for _ in s.goals do n += 1 end return n end)()))

-- Salir y guardar
Players.PlayerRemoving:Fire(player)
assert(saved["player_42"], "no se guardó")
print("Guardado OK · claves:", (function() local n = 0 for _ in saved["player_42"] do n += 1 end return n end)())
for _, fn in closeHandlers do task.spawn(fn) end
print("Cierre del servidor OK")

-- Volver a entrar (carga de datos guardados + ganancias offline)
fakeTime += 3600
saved["player_42"].career.xp.tech = 20000
saved["player_42"].money = 5e6
realPlayer.Parent = playersFolder
Players.PlayerAdded:Fire(player)
s = lastState()
print("Reentrada: webs", #s.sites, "dinero", Config.formatMoney(s.money))
for _, f in fired do
	if f[1] == "Notify" and f[3] == "popup" then
		print("  Popup:", f[2])
	end
end
print("-- Agencia --")
act("foundAgency")
act("recruit")
act("upgradeOffice")
act("redeemTicket", "premium")
act("redeemTicket", "legendary", "nope")
act("redeemTicket", "legendary", "tech")
for _ = 1, 3 do act("recruit") end
s = lastState()
for _, p in s.career.programmers do
	print(string.format("    %s · %s · %s · +%.1f%% · %s trabajo/s", p.name, p.rarity, p.niche, p.bonus * 100, Config.formatNumber(p.work)))
end
act("trainProgrammer", s.career.programmers[1].id)
tick(1)
s = lastState()
print("  bonus agencia:", s.bonuses.agencyBonus, "trabajo:", s.bonuses.agencyWork, "mult:", s.moneyMult, "pity:", s.career.pity)
act("fireProgrammer", s.career.programmers[#s.career.programmers].id)
-- Llenar la oficina
for _ = 1, 12 do invoke(player, "recruit") fakeTime += 1 end
local ok, msg = act("recruit")
s = lastState()
print("  equipo:", #s.career.programmers, "/", s.career.agency.capacity)
local serde = require("@lune/serde")
fs.writeFile("state.json", serde.encode("json", lastState()))
print("TODO OK")
process.exit(0)
