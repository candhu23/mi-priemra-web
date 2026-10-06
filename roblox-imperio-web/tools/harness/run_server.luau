-- Ejecuta TycoonServer real con servicios simulados y un jugador falso que
-- recorre todas las acciones. Falla con error si algo revienta.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local SRC = process.args[1]
local sources = {}
local function readSource(path)
	if not sources[path] then
		sources[path] = fs.readFile(path)
	end
	return sources[path]
end
for _, rel in { "/ReplicatedStorage/CareerConfig.luau", "/ServerScriptService/CareerService.luau", "/ServerScriptService/MarketService.luau", "/ReplicatedStorage/MarketConfig.luau", "/ReplicatedStorage/CityLayout.luau", "/ServerScriptService/AgencyOffice.luau", "/ReplicatedStorage/TycoonConfig.luau", "/ReplicatedStorage/Locale.luau", "/ReplicatedStorage/LocaleEN.luau", "/ServerScriptService/Building.luau", "/ServerScriptService/Showcase.luau", "/ServerScriptService/World.luau", "/ServerScriptService/PlotManager.luau", "/ServerScriptService/TycoonServer.server.luau" } do
	readSource(SRC .. rel)
end

local realOf = setmetatable({}, { __mode = "k" })
local proxyByKey = {}
local overrides = setmetatable({}, { __mode = "k" })
local callbacks = {}
local fired = {} -- llamadas a FireClient
local EVENTS = { Triggered = true, Changed = true, Touched = true, Activated = true, Completed = true, CharacterAdded = true, Destroying = true }
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
			local entry = { inst.Name, ... }
			entry.to = plr -- a quién va (hay dos jugadores)
			table.insert(fired, entry)
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
local orderedStores = {}
local DataStoreService = {
	GetDataStore = function()
		return {
			GetAsync = function(_, key) return saved[key] end,
			UpdateAsync = function(_, key, fn) saved[key] = fn(saved[key]) end,
		}
	end,
	-- Una clasificación por nombre (la global y una por semana), ordenada de mayor a menor
	GetOrderedDataStore = function(_, name)
		orderedStores[name] = orderedStores[name] or {}
		local scores = orderedStores[name]
		return {
			SetAsync = function(_, key, value)
				assert(value == math.floor(value), "puntuación no entera")
				scores[key] = value
			end,
			GetSortedAsync = function(_, _ascending, pageSize)
				return { GetCurrentPage = function()
					local list = {}
					for k, v in scores do table.insert(list, { key = k, value = v }) end
					table.sort(list, function(a, b) return a.value > b.value end)
					while #list > (pageSize or 100) do table.remove(list) end
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
addModule(services.ReplicatedStorage, "ModuleScript", "MarketConfig", SRC .. "/ReplicatedStorage/MarketConfig.luau")
addModule(services.ReplicatedStorage, "ModuleScript", "CityLayout", SRC .. "/ReplicatedStorage/CityLayout.luau")
addModule(services.ServerScriptService, "ModuleScript", "AgencyOffice", SRC .. "/ServerScriptService/AgencyOffice.luau")
addModule(services.ReplicatedStorage, "ModuleScript", "Locale", SRC .. "/ReplicatedStorage/Locale.luau")
addModule(services.ReplicatedStorage, "ModuleScript", "LocaleEN", SRC .. "/ReplicatedStorage/LocaleEN.luau")
addModule(services.ServerScriptService, "ModuleScript", "Showcase", SRC .. "/ServerScriptService/Showcase.luau")
addModule(services.ServerScriptService, "ModuleScript", "CareerService", SRC .. "/ServerScriptService/CareerService.luau")
addModule(services.ServerScriptService, "ModuleScript", "MarketService", SRC .. "/ServerScriptService/MarketService.luau")
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
	cfg.Monetization.Products[8].id = 989 -- pack de inicio
	cfg.Monetization.Products[9].id = 888 -- pase de temporada premium
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
local playersById = { [42] = player }
Players.GetPlayerByUserId = function(_, id) return playersById[id] end
Players.PlayerAdded:Fire(player)

local function lastState(who)
	for i = #fired, 1, -1 do
		if fired[i][1] == "State" and (fired[i].to == (who or player) or fired[i].to == nil) then return fired[i][2] end
	end
end

local actionMessages = {}
local function act(name, a, b, who)
	local ok, message, extra = invoke(who or player, name, a, b)
	print(string.format("  %-14s -> %s %s", name, tostring(ok), tostring(message or "")))
	if type(message) == "string" then
		table.insert(actionMessages, message)
	end
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

-- Comprar dinero hasta desbloquear la Carrera (planta 5)
for i = 1, 60 do
	if lastState().lifetimeEarned >= Config.earnedForFloor(Config.unlockFloor("career")) then
		break
	end
	MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 111, PurchaseId = "cash" .. i })
end
tick(1)
print("  ganado para desbloquear la Carrera:", Config.formatMoney(lastState().lifetimeEarned))

-- Carrera
local Career = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("CareerConfig")))
local minPay, maxPay = math.huge, 0
for _, c in Career.Companies do minPay = math.min(minPay, c.payScale); maxPay = math.max(maxPay, c.payScale) end
print(string.format("Factor de paga por empresa: de x%.2f a x%.2f", minPay, maxPay))
print("Empresas generadas:", #Career.Companies, "· primera:", Career.Companies[1].name, "· última:", Career.Companies[500].name)
local names = {}
for _, c in Career.Companies do
	assert(not names[c.name], "nombre repetido: " .. c.name)
	names[c.name] = true
end
act("setNiche", "gaming")
act("setNiche", "noexiste")
-- Encargos (v3)
fakeTime += 1.1
s = lastState()
print("  tablón de encargos:", #s.career.board, "· rango", s.career.rank, "· huecos", s.career.slots)
assert(#s.career.board >= 1, "debería haber encargos en el tablón")
for _, c in s.career.board do
	local company = Career.company(c.companyId)
	print(string.format("    %s quiere %s (%s) · paga %s · plazo %s", company.name, c.type, c.niche, Config.formatMoney(c.pay), Config.formatTime(c.duration)))
end
local contract = s.career.board[1]
assert(act("acceptContract", contract.id), "aceptar encargo")
act("acceptContract", 99999) -- no existe
act("acceptContract", s.career.board[2] and s.career.board[2].id) -- Junior: solo 1 a la vez
act("askContract")
act("askContract") -- enfriamiento
fakeTime += 1.1
act("workOnContract", contract.id)
s = lastState()
assert(s.project and s.project.contractId == contract.id, "debería programar la web del encargo")
assert(s.selectedNiche == contract.niche, "el nicho debería ser el del encargo")
local sitesBefore, earnedBefore, contractsBefore = #s.sites, s.lifetimeEarned, s.career.stats.contracts
print("  receipt terminar (encargo) ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 444, PurchaseId = "p4" }))
tick(1)
s = lastState()
print(string.format("  encargo entregado: webs %d → %d · entregados %d · ganado +%s", sitesBefore, #s.sites, s.career.stats.contracts, Config.formatMoney(s.lifetimeEarned - earnedBefore)))
assert(s.career.stats.contracts == contractsBefore + 1, "el encargo debería contar como entregado")
assert(#s.sites == sitesBefore, "la web del encargo no se queda en tus webs")
assert(#s.career.contracts == 0, "el encargo entregado sale de la lista")
-- Un encargo que caduca
s = lastState()
if s.career.board[1] then
	fakeTime += 1.1
	local id = s.career.board[1].id
	act("acceptContract", id)
	act("abandonContract", 424242)
	fakeTime += 2000
	tick(1)
	assert(#lastState().career.contracts == 0, "el encargo debería caducar")
end
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
	print(string.format("    %s · %s · %s · %s · %s · +%.1f%% dinero", p.name, p.rarity, p.niche, p.role, tostring(p.trait), p.stats.money * 100))
	assert(Career.RoleById[p.role] and Career.TraitById[p.trait], "programador sin especialidad o rasgo")
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

-- Idioma (las acciones nuevas se espacian: hay un límite de 10 por segundo)
fakeTime += 1.1
act("setLanguage", "en")
assert(lastState().settings.lang == "en", "no se guardó el idioma")
act("setLanguage", "klingon") -- no válido
act("setLanguage", "auto")

-- Segundo jugador: visitas y "me gusta"
local realAna = roblox.Instance.new("Folder")
realAna.Name = "Ana"
realAna.Parent = playersFolder
local ana = wrap(realAna)
overrides[ana] = {
	UserId = 43, DisplayName = "Ana", Name = "Ana",
	MembershipType = roblox.Enum.MembershipType.None,
	CharacterAdded = signal(),
	Character = false,
	IsFriendsWithAsync = function() return true end,
	IsInGroupAsync = function() return false end,
}
playersById[43] = ana
Players.PlayerAdded:Fire(ana)
tick(1)
s = lastState()
print("  vecinos:", #s.neighbors, s.neighbors[1] and s.neighbors[1].name)
local visitsBefore = 0
for _, f in fired do if f[1] == "Visit" then visitsBefore += 1 end end
fakeTime += 1.1
act("visitPlot", 43)
act("visitPlot", 999) -- no está
local visitInfo
for _, f in fired do if f[1] == "Visit" then visitInfo = f[2] end end
assert(visitInfo and visitInfo.name == "Ana" and not visitInfo.own, "no llegó la ficha de Ana")
print(string.format("  ficha de %s: %d plantas, %d webs, liked=%s, premio %s", visitInfo.name, visitInfo.floors, visitInfo.sites, tostring(visitInfo.liked), Config.formatMoney(visitInfo.likeReward)))
assert(act("likePlot", 43), "el me gusta debería funcionar")
assert(not act("likePlot", 43), "dos me gusta el mismo día")
assert(not act("likePlot", 42), "me gusta a uno mismo")
act("likePlot", "nope")
act("likePlot", 42, nil, ana) -- Ana devuelve el me gusta
assert(lastState().likes == 1, "Jorge debería tener 1 me gusta")
act("visitPlot", 42) -- su propia ficha
fs.writeFile("visit.json", serde.encode("json", visitInfo))

-- Ranking semanal: termina la semana y se reparten premios
s = lastState()
print("  ganado esta semana:", Config.formatMoney(s.weekly.earned), "· se reinicia en", Config.formatTime(s.weekly.resetIn))
assert(s.weekly.earned > 0, "debería contar lo ganado esta semana")
fakeTime += 31
act("saveNow")
local ticketsBefore = s.career.tickets.legendary or 0
fakeTime += 604800 -- una semana después
tick(1)
tick(1)
s = lastState()
print(string.format("  premio semanal: dorado %s · contratos legendarios %d → %d · ganado esta semana %s",
	Config.formatTime(s.goldLeft), ticketsBefore, s.career.tickets.legendary or 0, Config.formatMoney(s.weekly.earned)))
assert(s.goldLeft > 0, "el ganador debería tener el rascacielos dorado")
assert((s.career.tickets.legendary or 0) == ticketsBefore + 1, "el ganador debería recibir un Contrato Legendario")
local prizePopup = false
for _, f in fired do
	if f[1] == "Notify" and f[3] == "popup" and string.find(f[2], "semanal") then prizePopup = true end
end
assert(prizePopup, "falta la ventana del premio semanal")
tick(1)
assert((lastState().career.tickets.legendary or 0) == ticketsBefore + 1, "el premio no se debe dar dos veces")

-- Evento de fin de semana (sábado a mediodía UTC)
local week = Config.weekIndex(1_700_000_000 + math.floor(fakeTime))
fakeTime = Config.weekStart(week) + 5 * 86400 + 12 * 3600 - 1_700_000_000
tick(1)
s = lastState()
print("  fin de semana:", s.weekend.id, "· termina en", Config.formatTime(s.weekend.endsIn), "· bonus:", s.bonuses.weekend)
assert(s.weekend.id ~= nil and s.bonuses.weekend == s.weekend.id, "debería haber evento de fin de semana")
for w = 0, 2 do
	local event = Config.weekendStatus(Config.weekStart(week + w) + 5 * 86400)
	print("    semana +" .. w .. ":", event and event.id)
end
assert(Config.weekendStatus(Config.weekStart(week) + 86400) == nil, "el martes no hay evento")
assert(Config.weekendStatus(Config.weekStart(week) + 3600) ~= nil, "el lunes a la 1:00 sigue el evento")

-- 30 ticks de economía
for _ = 1, 30 do tick(1) end
s = lastState()
print(string.format("Tras 30 s: dinero %s · ingresos %s/s · rep %d · objetivos %d", Config.formatMoney(s.money), Config.formatMoney(s.income), s.reputation, (function() local n = 0 for _ in s.goals do n += 1 end return n end)()))

-- Salir y guardar
Players.PlayerRemoving:Fire(ana)
Players.PlayerRemoving:Fire(player)
assert(saved["player_42"], "no se guardó")
print("Guardado OK · claves:", (function() local n = 0 for _ in saved["player_42"] do n += 1 end return n end)())
for _, fn in closeHandlers do task.spawn(fn) end
print("Cierre del servidor OK")

-- Volver a entrar (carga de datos guardados + ganancias offline)
fakeTime += 3600
saved["player_42"].career.xp.tech = 20000
saved["player_42"].money = 5e6
saved["player_42"].totalEarned = 4e6 -- para poder salir a bolsa y probar las patentes
saved["player_42"].lifetimeEarned = 5e6 -- todo desbloqueado
-- Partida de la v2.1: trabajo, misión de "tareas" y programador sin especialidad
saved["player_42"].career.job = { companyId = 3, rank = 2, rankSince = 0, salaryMult = 1, xpMult = 1 }
saved["player_42"].career.contracts = nil
saved["player_42"].career.stats.contracts = nil
table.insert(saved["player_42"].career.programmers, { id = 900, name = "Viejo V.", rarity = "raro", niche = "tech", level = 3 })
if saved["player_42"].dailyMissions.list[1] then
	saved["player_42"].dailyMissions.list[1].id = "tasks"
end
realPlayer.Parent = playersFolder
Players.PlayerAdded:Fire(player)
s = lastState()
print("Reentrada: webs", #s.sites, "dinero", Config.formatMoney(s.money))
for _, m in s.dailyMissions.list do
	assert(Config.DailyMissionById[m.id], "misión antigua sin migrar: " .. m.id)
end
for _, p in s.career.programmers do
	assert(p.role and p.trait, "programador antiguo sin especialidad o rasgo")
end
assert(s.career.contracts and s.career.stats.contracts == 0, "carrera antigua sin migrar")
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
	print(string.format("    %s · %s · %s · %s/%s · +%.1f%% · %s trabajo/s", p.name, p.rarity, p.niche, p.role, tostring(p.trait), p.stats.money * 100, Config.formatNumber(p.work)))
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
-- v2.0 ------------------------------------------------------------
print("-- v2.0 --")
fakeTime += 2
act("buyCompany", "devs", 10)
act("buyCompany", "marketing", "max")
s = lastState()
print("  niveles: devs", s.companies.devs, "· marketing", s.companies.marketing, "· x", Config.companyMult(s, "marketing"))
assert((s.companies.marketing or 0) >= 10, "comprar al máximo debería subir varios niveles")
fakeTime += 2
act("redeemCode", " lanzamiento ")
assert(not act("redeemCode", "LANZAMIENTO"), "un código solo se usa una vez")
act("redeemCode", "NOEXISTE")
act("redeemCode", 123)
fakeTime += 2
for i = 1, #Config.PlaytimeRewards do
	act("claimPlaytime", i)
end
s = lastState()
print(string.format("  jugado hoy %s · premios recogidos %d", Config.formatTime(s.playtime.seconds), (function() local n = 0 for _ in s.playtime.claimed do n += 1 end return n end)()))
-- Bolsa (v3)
print("-- Bolsa --")
fakeTime += 2
s = lastState()
print("  acciones:", #s.market.stocks, "· máximo por empresa", Config.formatMoney(s.market.cap), "· próximo precio en", s.market.nextTick)
assert(#s.market.stocks == 6, "deberían cotizar 6 empresas")
local moneyBefore = s.money
act("buyStock", "byte", 0.1)
act("buyStock", "nope", 0.1)
act("buyStock", "byte", 5) -- fracción no válida
act("buyStock", "pixl", 1)
s = lastState()
local byte = s.market.stocks[1]
print(string.format("  BYTE: %.2f participaciones · invertido %s · dinero %s → %s", byte.units, Config.formatMoney(byte.invested), Config.formatMoney(moneyBefore), Config.formatMoney(s.money)))
assert(byte.units > 0 and s.money < moneyBefore, "la compra de acciones no funcionó")
for _ = 1, 40 do
	fakeTime += 30
	tick(1)
end
s = lastState()
for _, stock in s.market.stocks do
	print(string.format("    %s %s · %s · %d puntos", stock.id, Config.formatMoney(stock.price), stock.mode, #stock.history))
end
fakeTime += 2
act("sellStock", "byte", 0.5)
act("sellStock", "byte", 1)
act("sellStock", "byte", 1) -- ya no tiene
act("sellStock", "pixl", 2) -- fracción no válida
assert(lastState().market.stocks[1].units == 0, "debería haber vendido todo")
fakeTime += 2
local patentsBefore = s.patents
act("ipo")
s = lastState()
print("  patentes tras salir a bolsa:", patentsBefore, "→", s.patents, "· dinero inicial", Config.formatMoney(s.money))
assert(s.patents > patentsBefore, "salir a bolsa debería dar patentes")
for _, stock in s.market.stocks do
	assert(stock.units == 0, "al salir a bolsa se pierden las acciones")
end
fakeTime += 2
act("buyResearch", "capital")
act("buyResearch", "viral")
act("buyResearch", "nope")
act("buyResearch", "autolab") -- puede faltar
s = lastState()
print("  I+D:", serde.encode("json", s.research), "· patentes", s.patents)
assert(Config.research(s, "capital") == 1, "debería tener Capital semilla 1")
fakeTime += 2
act("claimSeason", 1, false)
act("claimSeason", 1, true) -- sin premium
act("claimSeason", 99, false)
print("  pase:", s.season.xp, "⭐ · premium", s.season.premium)
print("  receipt pase premium ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 888, PurchaseId = "s1" }))
print("  receipt pack inicio ->", MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 989, PurchaseId = "st1" }))
s = lastState()
assert(s.season.premium, "el pase premium debería estar activo")
assert(s.starterLeft == 0, "el pack de inicio ya no debería ofrecerse")
-- Muchas webs para ver variantes raras y la colección
fakeTime += 2
local rares = 0
for _ = 1, 40 do
	act("startProject", "landing")
	for _ = 1, 40 do invoke(player, "click") fakeTime += 0.05 end
	tick(1)
	s = lastState()
	if #s.sites >= s.slots then act("quickSell", s.sites[1].id) end
	fakeTime += 0.3
end
s = lastState()
local entries = Config.collectionStats(s)
for _, site in s.sites do if site.variant then rares += 1 end end
print("  colección:", entries, "casillas · bonus", Config.collectionBonus(s), "· mejor combo", s.bestCombo, "· webs raras ahora", rares)
print("  evento del servidor:", s.serverEvent and s.serverEvent.id, "· meta común:", s.community and Config.formatMoney(s.community.target))
assert(s.bestCombo >= 3, "el combo debería subir con clics seguidos")
-- v2.1: misiones semanales y logros
fakeTime += 2
print("  semanales:", #s.weeklyMissions.list, "· recompensa", Config.formatMoney(s.weeklyMissions.reward))
assert(#s.weeklyMissions.list == Config.WEEKLY_MISSION_COUNT, "deberían salir 4 misiones semanales")
act("claimWeeklyMission", 1)
act("claimWeeklyMission", 99)
for _, achievement in Config.Achievements do
	print(string.format("    logro %s: nivel %d (%s)", achievement.id, Config.achievementTier(s, achievement), tostring(achievement.value(s))))
end
print("  bonus de logros: dinero", Config.achievementBonus(s, "money"), "· clic", Config.achievementBonus(s, "click"))

fs.writeFile("state.json", serde.encode("json", lastState()))

-- Traducciones: todo lo que ha dicho el servidor debe salir en inglés
local Locale = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("Locale")))
local properNames = {}
for _, c in Career.Companies do table.insert(properNames, c.name) end
for _, n in Career.FirstNames do table.insert(properNames, n) end
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
local function looksSpanish(text)
	local clean = " " .. text .. " "
	for _, name in properNames do
		clean = stripName(clean, name)
	end
	for _, word in SPANISH do
		if string.find(clean, word, 1, true) then
			return word
		end
	end
	return nil
end
local texts = {}
for _, f in fired do
	if f[1] == "Notify" then
		table.insert(texts, f[2])
		if f[4] then table.insert(texts, f[4]) end
	end
end
for _, m in actionMessages do table.insert(texts, m) end
local seenText, bad = {}, 0
for _, text in texts do
	if not seenText[text] then
		seenText[text] = true
		local english = Locale.translate("en", text)
		print("  [en] " .. string.gsub(english, "\n", " / "))
		local word = looksSpanish(english)
		if word then
			bad += 1
			print("  SIN TRADUCIR [" .. word .. "]: " .. text .. "  →  " .. english)
		end
	end
end
local count = 0
for _ in seenText do count += 1 end
print("Textos del servidor traducidos:", count - bad, "de", count)
assert(bad == 0, "hay textos del servidor sin traducir")
print("TODO OK")
process.exit(0)
