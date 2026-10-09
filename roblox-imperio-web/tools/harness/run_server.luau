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
-- Todos los módulos de ReplicatedStorage y ServerScriptService (se leen
-- antes porque fs.readFile no se puede usar dentro de require)
local MODULE_DIRS = { "ReplicatedStorage", "ServerScriptService" }
for _, dir in MODULE_DIRS do
	for _, file in fs.readDir(SRC .. "/" .. dir) do
		if string.sub(file, -5) == ".luau" then
			readSource(SRC .. "/" .. dir .. "/" .. file)
		end
	end
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
			-- Como en Roblox, lo que viaja por un remote es una copia
			local args = table.pack(...)
			for i = 1, args.n do
				if type(args[i]) == "table" then
					args[i] = serde.decode("json", serde.encode("json", args[i]))
				end
			end
			local entry = { inst.Name, table.unpack(args, 1, args.n) }
			entry.to = plr -- a quién va (hay varios jugadores)
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
local storeFail = {} -- [clave] = true → el DataStore falla para esa clave (simula una caída)
local storeWrites = 0
-- Como en Roblox, lo guardado es una copia en JSON (no la misma tabla)
local function jsonCopy(v)
	if v == nil then
		return nil
	end
	return serde.decode("json", serde.encode("json", v))
end
local DataStoreService = {
	GetDataStore = function()
		return {
			GetAsync = function(_, key)
				if storeFail[key] then error("DataStore caído (simulado)") end
				return jsonCopy(saved[key])
			end,
			-- Si la función devuelve nil, no se escribe nada (igual que en Roblox)
			UpdateAsync = function(_, key, fn)
				if storeFail[key] then error("DataStore caído (simulado)") end
				local result = fn(jsonCopy(saved[key]))
				if result ~= nil then
					storeWrites += 1
					saved[key] = jsonCopy(result)
				end
				return result
			end,
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
local studioMode = false -- RunService:IsStudio()
-- Analítica e insignias: se apuntan las llamadas
local analyticsLog = {}
local function logger(kind)
	return function(_, ...)
		table.insert(analyticsLog, { kind = kind, args = table.pack(...) })
	end
end
local analyticsMock = {
	LogOnboardingFunnelStepEvent = logger("onboarding"),
	LogFunnelStepEvent = logger("funnel"),
	LogEconomyEvent = logger("economy"),
	LogProgressionCompleteEvent = logger("progress"),
	LogCustomEvent = logger("custom"),
}
local badgesAwarded = {}
local badgeMock = {
	AwardBadgeAsync = function(_, userId, badgeId)
		table.insert(badgesAwarded, { userId = userId, badgeId = badgeId })
		return true
	end,
}
local game = {
	JobId = "servidor-A",
	GetService = function(_, name)
		local mocks = {
			CollectionService = CollectionService, TweenService = TweenService, DataStoreService = DataStoreService,
			MarketplaceService = MarketplaceService, Players = Players,
			PolicyService = { GetPolicyInfoForPlayerAsync = function() return { ArePaidRandomItemsRestricted = false } end },
			RunService = { IsStudio = function() return studioMode end },
			AnalyticsService = analyticsMock,
			BadgeService = badgeMock,
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
for _, dir in MODULE_DIRS do
	for _, file in fs.readDir(SRC .. "/" .. dir) do
		if string.sub(file, -5) == ".luau" and not string.find(file, "%.server%.luau$") and not string.find(file, "%.client%.luau$") then
			addModule(services[dir], "ModuleScript", string.sub(file, 1, -6), SRC .. "/" .. dir .. "/" .. file)
		end
	end
end
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
local spawned = setmetatable({}, { __mode = "k" }) -- corrutinas creadas con task.spawn
local task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		spawned[co] = true
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(debug.traceback(co, tostring(err))) end
		if coroutine.status(co) == "suspended" then table.insert(sleeping, co) end
	end,
	delay = function(_, fn, ...) fn(...) end,
	-- Solo cede dentro de task.spawn; en el hilo principal del harness no espera
	wait = function()
		if spawned[coroutine.running()] then coroutine.yield() end
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
	-- En el harness el tiempo casi no avanza entre acciones: sin límite de
	-- envíos para que cada acción mande su estado (la prueba F7 lo activa)
	cfg.STATE_MIN_INTERVAL = 0
	-- Dos insignias activadas para probar
	for _, badge in cfg.Badges do
		if badge.key == "first_site" then badge.id = 9001 end
		if badge.key == "weekly_top" then badge.id = 9002 end
	end
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
	Kick = function(_, msg) print("  [kick] Jorge:", msg) end,
}
local playersById = { [42] = player }
Players.GetPlayerByUserId = function(_, id) return playersById[id] end
Players.PlayerAdded:Fire(player)

-- Estado de cada jugador tal como lo tiene su cliente: el primero llega
-- entero y luego llegan parches (StatePatch). Devuelve una copia.
local StatePatchMod = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("StatePatch")))
local recon = {}
local reconIndex = 0
local function lastState(who)
	for i = reconIndex + 1, #fired do
		local f = fired[i]
		if f[1] == "State" and f.to ~= nil then
			if f[3] == true then
				assert(recon[f.to] ~= nil, "llegó un parche sin estado previo")
				recon[f.to] = StatePatchMod.apply(recon[f.to], f[2])
			else
				recon[f.to] = f[2]
			end
		end
	end
	reconIndex = #fired
	local current = recon[who or player]
	return current and StatePatchMod.copy(current)
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

-- Pruebas de los fallos de la v3.1 (F1…F12): se apuntan todos y se falla al final
local failures = {}
local function check(id, cond, msg)
	if cond then
		print("  ✔ " .. id .. ": " .. msg)
	else
		print("  ✘ " .. id .. ": " .. msg)
		table.insert(failures, id .. ": " .. msg)
	end
end
local kicked = {}
local function makePlayer(name, userId, friends)
	local real = roblox.Instance.new("Folder")
	real.Name = name
	real.Parent = playersFolder
	local p = wrap(real)
	overrides[p] = {
		UserId = userId, DisplayName = name, Name = name,
		MembershipType = roblox.Enum.MembershipType.None,
		CharacterAdded = signal(),
		Character = false,
		LocaleId = "es-es",
		IsFriendsWithAsync = function() return friends == true end,
		IsInGroupAsync = function() return false end,
		Kick = function(_, msg)
			kicked[userId] = msg
			table.insert(actionMessages, msg)
			print("  [kick] " .. name .. ":", msg)
		end,
	}
	playersById[userId] = p
	return p, real
end
local function statesTo(who)
	local n = 0
	for _, f in fired do
		if f[1] == "State" and f.to == who then n += 1 end
	end
	return n
end
local function nowUnix()
	return 1_700_000_000 + math.floor(fakeTime)
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
	Kick = function(_, msg) print("  [kick] Ana:", msg) end,
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
-- (un martes a mediodía, sin evento de fin de semana, para medir el offline)
do
	local wk = Config.weekIndex(nowUnix())
	fakeTime = Config.weekStart(wk + 1) + 86400 + 12 * 3600 - 1_700_000_000
end
-- F10: estuvo fuera 1 h y su boost acabó a los 10 min de irse
saved["player_42"].lastOnline = nowUnix() - 3600
saved["player_42"].boostUntil = nowUnix() - 3000
-- F3: hoy ya ha jugado 90 min (puede reclamar los 7 premios por tiempo)
saved["player_42"].playtime = { day = Config.dayIndex(nowUnix()), seconds = 5400, claimed = {} }
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
do
	-- F10: 1 h fuera con boost x2 los primeros 10 min → 70 min de ingresos base × OFFLINE_RATE
	local base = s.giftAmount / Config.REWARD_SCALE / (Config.GIFT_MINUTES * 60)
	local offline = s.money - 5e6
	local expected = base * Config.OFFLINE_RATE * (3600 + 600)
	print(string.format("  offline: %s (esperado %s, base %s/s)", Config.formatMoney(offline), Config.formatMoney(expected), Config.formatMoney(base)))
	check("F10", base * 120 > Config.GIFT_MIN and math.abs(offline - expected) <= expected * 1e-3,
		"ganancias offline con el boost solo mientras duró")
end
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
do
	local okAll = true
	for i, def in Config.PlaytimeRewards do
		local before = lastState()
		local base = before.giftAmount / Config.REWARD_SCALE / (Config.GIFT_MINUTES * 60)
		local announced = def.rewardMinutes or def.boostMinutes or def.minutes
		local ok = act("claimPlaytime", i)
		local after = lastState()
		local good = ok == true
		if def.kind == "cash" then
			local expected = math.max(def.min, base * announced * 60) * Config.REWARD_SCALE
			good = good and math.abs((after.money - before.money) - expected) <= expected * 1e-6
			print(string.format("    premio %d: +%s (anunciado %d min → %s)", i, Config.formatMoney(after.money - before.money), announced, Config.formatMoney(expected)))
		elseif def.kind == "boost" then
			good = good and (after.boostLeft - before.boostLeft) == announced * 60
			print(string.format("    premio %d: boost +%d s (anunciado %d min)", i, after.boostLeft - before.boostLeft, announced))
		elseif def.kind == "ticket" then
			good = good and (after.career.tickets[def.ticket] or 0) == (before.career.tickets[def.ticket] or 0) + def.amount
		end
		okAll = okAll and good
	end
	check("F3", okAll, "los 7 premios por tiempo pagan exactamente lo anunciado")
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
do
	tick(1)
	local capBefore = lastState().market.cap
	MarketplaceService.ProcessReceipt({ PlayerId = 42, ProductId = 333, PurchaseId = "boostCap" })
	tick(1)
	local capAfter = lastState().market.cap
	print(string.format("  máximo invertible: %s → %s con boost", Config.formatMoney(capBefore), Config.formatMoney(capAfter)))
	check("F5c", capAfter <= capBefore * 1.01, "un boost x2 no sube el máximo invertible en Bolsa")
end
moneyBefore = lastState().money
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
	print(string.format("    %s %s · rumor %s · %d puntos", stock.id, Config.formatMoney(stock.price), tostring(stock.rumor), #stock.history))
end
do
	-- F4: el precio es el mismo que calcularía cualquier otro servidor
	local Market = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("MarketConfig")))
	local tickNow = nowUnix() // Market.TICK
	local same, independent = true, true
	for i, stock in s.market.stocks do
		local fresh = Market.priceOf(i, Market.xAt(i, tickNow))
		same = same and math.abs(stock.price / fresh - 1) < 1e-6
		-- Un servidor que arrancó 300 ticks antes llega al mismo precio
		local x = Market.xAt(i, tickNow - 300)
		for t = tickNow - 299, tickNow do x = Market.step(x, i, t) end
		independent = independent and math.abs(Market.priceOf(i, x) / fresh - 1) < 1e-9
		-- La gráfica: el último punto (antes de head) es el precio actual
		local newest = stock.history[((stock.head or 1) - 2) % #stock.history + 1]
		same = same and math.abs(newest / stock.price - 1) < 1e-9 and #stock.history == Market.HISTORY
	end
	check("F4a", same, "los precios coinciden con el cálculo global (iguales en todos los servidores)")
	check("F4b", independent, "da igual cuándo arrancó el servidor")
	-- F5: no se envía la tendencia real; el rumor acierta ~60 %
	local leaks = false
	for _, stock in s.market.stocks do
		if stock.mode ~= nil then leaks = true end
	end
	local hits, total = 0, 0
	for block = 1, 3000 do
		local t = (tickNow // Market.MODE_BLOCK - block) * Market.MODE_BLOCK
		local truth = Market.ModeById[Market.modeAt(1 + block % 6, t)].dir
		if Market.rumor(1 + block % 6, t, 42, 0.6) == truth then hits += 1 end
		total += 1
	end
	print(string.format("  rumor del analista: acierta %.1f %% (%d bloques)", hits / total * 100, total))
	check("F5a", not leaks and math.abs(hits / total - 0.6) < 0.04, "la tendencia real no se envía y el rumor acierta ~60 %")
	check("F5b", Market.DIVIDEND <= 0.0005 + 1e-12, "dividendo ~0,05 % por tick")
end
fakeTime += 2
act("sellStock", "byte", 0.5)
act("sellStock", "byte", 1)
act("sellStock", "byte", 1) -- ya no tiene
act("sellStock", "pixl", 2) -- fracción no válida
act("sellStock", "pixl", 0 / 0) -- NaN (exploit)
act("buyStock", "pixl", math.huge)
check("F6", lastState().money == lastState().money and lastState().money ~= math.huge, "vender acciones con NaN no rompe el dinero")
assert(lastState().market.stocks[1].units == 0, "debería haber vendido todo")
fakeTime += 2
-- F9: deja una venta negociándose justo antes de salir a bolsa
local dealPrice = 0
for _ = 1, 30 do
	s = lastState()
	for _, offer in s.offers do
		for _, site in s.sites do
			if dealPrice == 0 and site.type == offer.type and not site.deal and act("sellToOffer", offer.id, site.id) then
				for _, site2 in lastState().sites do
					if site2.id == site.id and site2.deal then dealPrice = site2.deal.price end
				end
			end
		end
	end
	if dealPrice > 0 then break end
	fakeTime += 50
	tick(1)
end
fakeTime += 2
s = lastState()
local lifetimeBeforeIpo = s.lifetimeEarned
local patentsBefore = s.patents
act("ipo")
s = lastState()
print("  patentes tras salir a bolsa:", patentsBefore, "→", s.patents, "· dinero inicial", Config.formatMoney(s.money))
assert(s.patents > patentsBefore, "salir a bolsa debería dar patentes")
check("F9", dealPrice > 0 and s.lifetimeEarned >= lifetimeBeforeIpo + dealPrice * 0.999,
	"las negociaciones en curso se cobran al salir a bolsa (" .. Config.formatMoney(dealPrice) .. ")")
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

-- Bloque 2: analítica e insignias --------------------------------------
print("-- Analítica e insignias --")
do
	local count = {}
	local onboardingSteps, sinks, sources, tutorialSteps = {}, {}, {}, 0
	for _, entry in analyticsLog do
		count[entry.kind] = (count[entry.kind] or 0) + 1
		if entry.kind == "onboarding" then onboardingSteps[entry.args[3]] = true end
		if entry.kind == "economy" then
			local list = if tostring(entry.args[2]) == tostring(roblox.Enum.AnalyticsEconomyFlowType.Source) then sources else sinks
			list[entry.args[7]] = true
		end
	end
	local parts = {}
	for kind, n in count do table.insert(parts, kind .. "=" .. n) end
	table.sort(parts)
	print("  llamadas: " .. table.concat(parts, ", "))
	local function keys(t) local out = {} for k in t do table.insert(out, k) end table.sort(out) return table.concat(out, ", ") end
	print("  embudo: " .. keys(onboardingSteps))
	print("  economía · entra: " .. keys(sources) .. " · sale: " .. keys(sinks))
	check("A1", onboardingSteps["Entra por primera vez"] and onboardingSteps["Empieza su primera web"] and onboardingSteps["Termina su primera web"],
		"embudo de los primeros minutos")
	check("A2", sources.ingresos and sources.robux and sinks.webs and sinks.empresas, "economía: entradas y salidas por categoría")
	check("A3", (count.progress or 0) > 0, "progresión (plantas del rascacielos)")
	local first, weekly = false, false
	for _, b in badgesAwarded do
		if b.userId == 42 and b.badgeId == 9001 then first = true end
		if b.userId == 42 and b.badgeId == 9002 then weekly = true end
	end
	check("B1", first and weekly and #badgesAwarded <= 4, "insignias: primera web y top semanal, sin repetirse")
	act("tutorialStep", 1)
	act("tutorialStep", 1) -- repetido: no se apunta dos veces
	act("tutorialStep", 0 / 0)
	local funnel = 0
	for _, entry in analyticsLog do if entry.kind == "funnel" and entry.args[2] == "Tutorial" then funnel += 1 end end
	check("A4", funnel == 1, "embudo del tutorial (un evento por paso)")
end

-- F7: cuánto ocupa lo que se manda cada segundo ------------------------
print("-- F7: tamaño del estado --")
do
	local fullSize = #serde.encode("json", lastState())
	local startIdx = #fired
	for _ = 1, 40 do
		fakeTime += 1
		tick(1)
	end
	local maxSize, total, count, full = 0, 0, 0, 0
	local byKey = {}
	local sizes = {}
	for i = startIdx + 1, #fired do
		local f = fired[i]
		if f[1] == "State" and f.to == player then
			if f[3] == true then
				local size = #serde.encode("json", f[2])
				for key, value in f[2] do
					byKey[key] = (byKey[key] or 0) + #serde.encode("json", { [key] = value })
				end
				if process.env.DEBUG_PATCH and size > 2000 then
					for key, value in f[2] do print("DEBUG", key, #serde.encode("json", { [key] = value }), string.sub(serde.encode("json", value), 1, 300)) end
				end
				table.insert(sizes, size)
				maxSize = math.max(maxSize, size)
				total += size
				count += 1
			else
				full += 1
			end
		end
	end
	table.sort(sizes)
	local p90 = sizes[math.max(1, math.ceil(#sizes * 0.9))] or 0
	print(string.format("  estado completo %d bytes · parches por segundo: media %d, p90 %d, máx. %d bytes (%d envíos, %d completos)",
		fullSize, total // math.max(count, 1), p90, maxSize, count, full))
	local keys = {}
	for key, bytes in byKey do table.insert(keys, { key = key, bytes = bytes // math.max(count, 1) }) end
	table.sort(keys, function(x, y) return x.bytes > y.bytes end)
	local parts = {}
	for i = 1, math.min(8, #keys) do table.insert(parts, keys[i].key .. "=" .. keys[i].bytes) end
	print("  bytes por segundo de cada parte: " .. table.concat(parts, ", "))
	-- (medido en JSON; por la red de Roblox los números ocupan menos)
	check("F7a", count > 0 and full == 0 and total / count < 2048 and p90 < 2048 and maxSize < 4096,
		"cada segundo solo viaja lo que cambia (media y p90 < 2 KB)")
	-- Los clics no mandan estado
	s = lastState()
	fakeTime += 100
	if #s.sites >= s.slots then act("quickSell", s.sites[1].id) end
	fakeTime += 1.1
	act("startProject", "landing")
	local before = statesTo(player)
	for _ = 1, 3 do invoke(player, "click") fakeTime += 0.1 end
	check("F7b", statesTo(player) == before, "los clics no mandan estado")
	-- Como mucho 4 envíos por segundo
	Config.STATE_MIN_INTERVAL = 0.25
	fakeTime += 1.1
	before = statesTo(player)
	for i = 1, 8 do act("setNiche", if i % 2 == 0 then "gaming" else "tech") end
	local burst = statesTo(player) - before
	fakeTime += 0.3
	tick(0)
	local afterFlush = statesTo(player) - before
	Config.STATE_MIN_INTERVAL = 0
	print(string.format("  8 acciones seguidas: %d envíos al momento, %d tras 0,3 s", burst, afterFlush))
	check("F7c", burst <= 1 and afterFlush >= 1 and afterFlush <= 3 and lastState().selectedNiche == "gaming",
		"como mucho 4 envíos por segundo y el último cambio llega igual")
end

-- F1: bloqueo de sesión del guardado ----------------------------------
print("-- F1: bloqueo de sesión --")
local luis = makePlayer("Luis", 44)
Players.PlayerAdded:Fire(luis)
fakeTime += 1.1
Players.PlayerRemoving:Fire(luis)
check("F1a", saved["player_44"] ~= nil and saved["player_44"]._lock == nil, "al salir se guarda y se libera el bloqueo")
-- Otro servidor tiene la partida abierta ahora mismo
saved["player_44"]._lock = { jobId = "servidor-B", t = nowUnix() }
saved["player_44"].money = 777
local statesBefore = statesTo(luis)
Players.PlayerAdded:Fire(luis)
check("F1b", kicked[44] ~= nil and statesTo(luis) == statesBefore and saved["player_44"]._lock.jobId == "servidor-B",
	"si otro servidor tiene la partida abierta, no se carga (se le echa con aviso)")
Players.PlayerRemoving:Fire(luis)
check("F1c", saved["player_44"].money == 777 and saved["player_44"]._lock.jobId == "servidor-B", "el que no cargó no guarda al salir")
-- Bloqueo caducado (servidor caído hace una hora): se roba
kicked[44] = nil
saved["player_44"]._lock = { jobId = "servidor-B", t = nowUnix() - 3600 }
Players.PlayerAdded:Fire(luis)
check("F1d", kicked[44] == nil and lastState(luis) and lastState(luis).money == 777 and saved["player_44"]._lock and saved["player_44"]._lock.jobId == "servidor-A",
	"un bloqueo caducado se roba y se carga la partida")
-- Mientras juega, otro servidor le quita la partida: este ya no debe guardar
saved["player_44"]._lock = { jobId = "servidor-B", t = nowUnix() }
saved["player_44"].money = 999
fakeTime += 40
act("saveNow", nil, nil, luis)
check("F1e", saved["player_44"].money == 999 and kicked[44] ~= nil, "si perdemos el bloqueo no se machaca la partida")
Players.PlayerRemoving:Fire(luis)
check("F1f", saved["player_44"].money == 999 and saved["player_44"]._lock.jobId == "servidor-B", "ni al salir")
check("F1g", saved["player_42"].dataVersion ~= nil and saved["player_42"].dataVersion >= 4, "las partidas llevan dataVersion")

-- F2: compra con Robux cuando la partida no se pudo cargar ------------
print("-- F2: compras sin guardado --")
local marta = makePlayer("Marta", 45)
storeFail["player_45"] = true
Players.PlayerAdded:Fire(marta)
local mBefore = lastState(marta).money
local decision = MarketplaceService.ProcessReceipt({ PlayerId = 45, ProductId = 111, PurchaseId = "m1" })
check("F2a", tostring(decision) == tostring(roblox.Enum.ProductPurchaseDecision.NotProcessedYet) and lastState(marta).money == mBefore,
	"sin guardado (fuera de Studio) la compra queda pendiente y no se entrega")
studioMode = true
decision = MarketplaceService.ProcessReceipt({ PlayerId = 45, ProductId = 111, PurchaseId = "m2" })
studioMode = false
check("F2b", tostring(decision) == tostring(roblox.Enum.ProductPurchaseDecision.PurchaseGranted) and lastState(marta).money > mBefore,
	"en Studio sin publicar se sigue entregando para probar")
Players.PlayerRemoving:Fire(marta)
storeFail["player_45"] = nil

-- F8: un jugador con datos raros no debe parar la economía de los demás
print("-- F8: errores aislados por jugador --")
local pablo = makePlayer("Pablo", 46)
Players.PlayerAdded:Fire(pablo)
fakeTime += 1.1
Players.PlayerRemoving:Fire(pablo)
saved["player_46"].playtime = { day = Config.dayIndex(nowUnix()), seconds = "roto", claimed = {} }
pcall(function() Players.PlayerAdded:Fire(pablo) end)
local jBefore = lastState(player).money
local okTicks = pcall(function()
	for _ = 1, 3 do tick(1) end
end)
check("F8", okTicks and lastState(player).money > jBefore, "el bucle sigue pagando a los demás aunque falle uno")
pcall(function() Players.PlayerRemoving:Fire(pablo) end)

-- Bloque 5: productos nuevos, Eras, Fusión y Legado -------------------
print("-- Eras y Fusión --")
do
	local ServerStateMod = requireModule(wrap(services.ServerScriptService:FindFirstChild("ServerState")))
	local eva = makePlayer("Eva", 50)
	Players.PlayerAdded:Fire(eva)
	fakeTime += 1.1
	local session = ServerStateMod.sessions[eva]
	local data = session.data
	data.lifetimeEarned = 1e15 -- rascacielos alto: todo desbloqueado por plantas
	local st = lastState(eva)
	check("E1", st.eras and st.eras.era == 1 and st.eras.needIpos == Config.Fusions[1].ipos and data.legacy == 0,
		"una partida nueva está en la Era 1 y el estado trae lo que pide la Fusión")
	-- Lo de la Era 2 está cerrado en la Era 1
	data.reputation = 1e9
	data.money = 1e16
	local okWeb, msgWeb = act("startProject", "buscador", nil, eva)
	local okAd = act("unlockNetwork", "searchads", nil, eva)
	local okCo = act("buyCompany", "fintech", 1, eva)
	check("E2", not okWeb and not okAd and not okCo and type(msgWeb) == "string" and string.find(msgWeb, "Era 2") ~= nil,
		"webs, apps y empresas de la Era 2 no se pueden usar en la Era 1")
	-- Fusión sin cumplir lo que pide
	data.eraIpos = Config.Fusions[1].ipos - 1
	data.eraEarned = Config.Fusions[1].earned
	local okEarly = act("fusion", nil, nil, eva)
	check("E3", not okEarly and data.era == 1, "sin las salidas a bolsa necesarias no hay Fusión")
	-- Fusión de verdad
	data.eraIpos = Config.Fusions[1].ipos
	data.shares = 100
	data.patents = 7
	data.research.viral = 2
	data.collection.landing = { normal = true }
	local ipoBefore = data.ipoCount
	local okFusion = act("fusion", nil, nil, eva)
	check("E4", okFusion and data.era == 2 and data.shares == 0 and data.legacy == Config.legacyForShares(100) and data.eraIpos == 0
		and data.eraEarned == 0 and data.fusions == 1 and #data.sites == 0 and data.money == Config.startMoney(data)
		and data.patents == 7 and data.research.viral == 2 and data.collection.landing ~= nil and data.ipoCount == ipoBefore,
		"la Fusión reinicia la partida y las acciones, da Legado y conserva I+D, patentes y colección")
	tick(1)
	check("E5", lastState(eva).eras.era == 2 and lastState(eva).era == 2, "el cliente recibe la era nueva")
	-- Árbol de Legado
	local okLocked = act("buyLegacy", "preferentes", nil, eva)
	local legacyBefore = data.legacy
	local mmBefore = Config.moneyMult(data, nil)
	local okBuy = act("buyLegacy", "herencia", nil, eva)
	local okBad = act("buyLegacy", "noexiste", nil, eva)
	check("E6", not okLocked and okBuy and not okBad and data.legacyTree.herencia == 1 and data.legacy == legacyBefore - Config.legacyCost("herencia", 0)
		and math.abs(Config.moneyMult(data, nil) / mmBefore - 1.5) < 1e-6,
		"Legado: hace falta la mejora anterior, cuesta 🧬 y da su efecto")
	-- En la Era 2 sí se puede programar un Buscador
	data.reputation = 1e9
	data.money = 1e16
	local okWeb2 = act("startProject", "buscador", nil, eva)
	check("E7", okWeb2 and data.project ~= nil and data.project.type == "buscador", "en la Era 2 se abren los productos nuevos")
	act("cancelProject", nil, nil, eva)
	-- Mecánicas propias
	local function fakeSite(typeId, id)
		return { id = id, type = typeId, name = "X", niche = "ecommerce", quality = 1, seo = 0, design = 0, network = "adsimple", adLevel = 1, totalVisits = 0, earned = 0 }
	end
	data.sites = { fakeSite("landing", 9001) }
	local visitsAlone = Config.siteVisits(data, data.sites[1], 1)
	local slotsAlone = Config.slots(data, nil)
	table.insert(data.sites, fakeSite("buscador", 9002))
	table.insert(data.sites, fakeSite("cloud", 9003))
	local bank = fakeSite("banco", 9004)
	table.insert(data.sites, bank)
	local searchOk = math.abs(Config.siteVisits(data, data.sites[1], 1) / visitsAlone - (1 + Config.Mechanics.search.value)) < 1e-6
	local cloudOk = Config.slots(data, nil) == slotsAlone + Config.Mechanics.cloud.value
	data.money = 0
	local bankPoor = Config.siteIncome(data, bank, 100, 1)
	data.money = 1e30
	local bankRich = Config.siteIncome(data, bank, 100, 1)
	local bankOk = math.abs(bankRich / bankPoor - (1 + Config.Mechanics.bank.cap)) < 1e-6
	local inSeason = Config.gameSeason(600 * 1000 + 10)
	local offSeason = Config.gameSeason(600 * 1000 + 400)
	check("E8", searchOk and cloudOk and bankOk and inSeason and not offSeason,
		"Buscador (+visitas a las demás), Cloud (+huecos), Banco (intereses con tope) y temporadas del Videojuego")
	data.sites = {}
	data.money = 1e16
	-- La parcela cambia de aspecto con la era
	local eraBuilding = false
	for _, d in services.Workspace:GetDescendants() do
		if d.Name == "AnilloEra" then eraBuilding = true end
	end
	check("E9", eraBuilding, "el rascacielos de la Era 2 tiene su azotea de neón")
	Players.PlayerRemoving:Fire(eva)
	check("E10", saved["player_50"] and saved["player_50"].era == 2 and saved["player_50"].legacyTree.herencia == 1,
		"la era y el Legado se guardan")
	-- Salir a bolsa cuenta para la Fusión
	local ipoData = lastState().eras
	check("E11", ipoData ~= nil and ipoData.ipos >= 1, "las salidas a bolsa de esta era se cuentan (Jorge salió a bolsa)")
end

-- Bloque 4: Modo Historia --------------------------------------------
print("-- Modo Historia --")
do
	local ServerStateMod = requireModule(wrap(services.ServerScriptService:FindFirstChild("ServerState")))
	local sofia = makePlayer("Sofía", 47)
	Players.PlayerAdded:Fire(sofia)
	fakeTime += 1.1
	local session = ServerStateMod.sessions[sofia]
	local story0 = lastState(sofia).story
	check("H1", story0 and story0.chapter == 1 and story0.mission == 1 and not story0.done and story0.target == 1,
		"una partida nueva empieza en el capítulo 1, misión 1")
	local function notifiesTo(who, kind)
		local n = 0
		for _, f in fired do
			if f[1] == "Notify" and f.to == who and f[3] == kind then n += 1 end
		end
		return n
	end
	-- Misión 1: programar la primera web (la hace de verdad)
	local storyBefore = notifiesTo(sofia, "story")
	act("startProject", "landing", nil, sofia)
	for _ = 1, 200 do
		fakeTime += 0.08
		invoke(sofia, "click")
		if session.data.stats.built >= 1 then break end
	end
	local moneyBefore = session.data.money
	tick(1)
	local st = lastState(sofia).story
	check("H2", st.mission == 2 and session.data.money > moneyBefore and notifiesTo(sofia, "story") > storyBefore,
		"al cumplir una misión se cobra el premio, avisa Ada y pasa a la siguiente")
	-- Como mucho una misión por segundo
	session.data.stats.sold = 5
	session.data.lifetimeEarned = math.max(session.data.lifetimeEarned, 2000)
	session.data.story.mission = 4
	tick(1)
	check("H3", session.data.story.mission == 5, "como mucho una misión por segundo")
	-- Fin de capítulo: premio especial (boost) y aviso de capítulo
	session.data.story.mission = 6
	local boostBefore = session.data.boostUntil or 0
	local chapterBefore = notifiesTo(sofia, "chapter")
	tick(1)
	st = lastState(sofia).story
	check("H4", st.chapter == 2 and st.mission == 1 and (session.data.boostUntil or 0) > boostBefore and notifiesTo(sofia, "chapter") == chapterBefore + 1,
		"al acabar un capítulo da su premio especial y la ventana del capítulo")
	-- Hablar con Ada
	storyBefore = notifiesTo(sofia, "story")
	local okTalk = act("talkToAda", nil, nil, sofia)
	check("H5", okTalk == true and notifiesTo(sofia, "story") == storyBefore + 1, "hablar con Ada repite la misión actual")
	-- Último capítulo: la historia termina
	session.data.story.chapter = 5
	session.data.story.mission = 6
	session.data.ipoCount = 2
	local legacyPatents = session.data.patents or 0
	tick(1)
	st = lastState(sofia).story
	check("H6", st.done == true and session.data.story.done == true and (session.data.patents or 0) > legacyPatents,
		"la última misión termina la historia (premio: patentes)")
	tick(1)
	check("H7", session.data.story.done == true and session.data.story.chapter == 5, "una historia terminada no vuelve a avanzar")
	act("talkToAda", nil, nil, sofia)
	Players.PlayerRemoving:Fire(sofia)
	-- Veteranos: partida de la v4-alpha con mucho ganado → historia completada
	saved["player_48"] = { money = 10, lifetimeEarned = 2e7, totalEarned = 5e6, dataVersion = 4, ipoCount = 0 }
	local rosa = makePlayer("Rosa", 48)
	Players.PlayerAdded:Fire(rosa)
	local rs = lastState(rosa)
	check("H8", rs and rs.story and rs.story.done == true, "los veteranos no empiezan la historia desde el garaje")
	Players.PlayerRemoving:Fire(rosa)
	saved["player_49"] = { money = 10, lifetimeEarned = 500, totalEarned = 500, dataVersion = 4, ipoCount = 0 }
	local nuevo = makePlayer("Hugo", 49)
	Players.PlayerAdded:Fire(nuevo)
	rs = lastState(nuevo)
	check("H9", rs and rs.story and rs.story.done == false and rs.story.chapter == 1, "los que llevan poco sí hacen la historia")
	Players.PlayerRemoving:Fire(nuevo)
	local funnelHistoria = 0
	for _, entry in analyticsLog do
		if entry.kind == "funnel" and entry.args[2] == "Historia" then funnelHistoria += 1 end
	end
	check("A5", funnelHistoria >= 4, "embudo de la historia en la analítica")
end

-- Traducciones: todo lo que ha dicho el servidor debe salir en inglés
local Locale = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("Locale")))
local properNames = {}
for _, c in Career.Companies do table.insert(properNames, c.name) end
for _, n in Career.FirstNames do table.insert(properNames, n) end
table.sort(properNames, function(a, b) return #a > #b end)
local SPANISH = { " de ", " la ", " el ", " tu ", " tus ", " para ", " con ", " por ", " en ", " una ", " del ", " los ", " las ", " y ", " que ", " se ", " Se ", " es ", "¿", "¡", "á", "é", "í", "ó", "ú", "ñ" }
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
-- En portugués solo sirven las palabras que son solo del español
local SPANISH_PT = { " el ", " los ", " las ", " y ", " del ", " tu ", " tus ", " una ", " con ", " muy ", " pero ", " hay ", " ya ", " ha ", " has ",
	" un ", " al ", " la ", " es ", "ción", "ión ", " más ", " aún ", "¿", "¡", "ñ" }
local function looksSpanishPT(text)
	local clean = " " .. text .. " "
	for _, name in properNames do
		clean = stripName(clean, name)
	end
	for _, word in SPANISH_PT do
		if string.find(clean, word, 1, true) then
			return word
		end
	end
	return nil
end
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
		local portuguese = Locale.translate("pt", text)
		print("  [pt] " .. string.gsub(portuguese, "\n", " / "))
		local wordPt = looksSpanishPT(portuguese)
		if wordPt then
			bad += 1
			print("  SIN TRADUCIR AL PORTUGUÉS [" .. tostring(wordPt) .. "]: " .. text .. "  →  " .. portuguese)
		end
	end
end
local count = 0
for _ in seenText do count += 1 end
print("Textos del servidor traducidos:", count - bad, "de", count)
assert(bad == 0, "hay textos del servidor sin traducir")
if #failures > 0 then
	print("FALLOS (" .. #failures .. "):")
	for _, f in failures do print("  - " .. f) end
	error("hay pruebas F1–F12 que fallan")
end
print("TODO OK")
process.exit(0)
