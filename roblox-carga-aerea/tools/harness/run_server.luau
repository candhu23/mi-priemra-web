-- Ejecuta GameServer real con servicios simulados y un jugador falso que juega
-- (despacha, compra, contrata...) y recorre todas las acciones. Falla si algo revienta.
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
for _, rel in { "/ReplicatedStorage/Config.luau", "/ReplicatedStorage/Lang.luau", "/ServerScriptService/GameServer.server.luau" } do
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
addModule(services.ReplicatedStorage, "ModuleScript", "Config", SRC .. "/ReplicatedStorage/Config.luau")
addModule(services.ReplicatedStorage, "ModuleScript", "Lang", SRC .. "/ReplicatedStorage/Lang.luau")
local serverScript = addModule(services.ServerScriptService, "Script", "GameServer", SRC .. "/ServerScriptService/GameServer.server.luau")

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
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "ColorSequence", "Font" } do
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

-- Arrancar el script del servidor (se queda dormido en su bucle principal)
do
	local env = makeEnv(serverScript)
	env.require = requireModule
	local chunk = luau.load(readSource(SRC .. "/ServerScriptService/GameServer.server.luau"), { debugName = "GameServer", environment = env })
	task.spawn(chunk)
end
local Config = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("Config")))
local Lang = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("Lang")))
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
overrides[player] = { UserId = 42, DisplayName = "Jorge", Name = "Jorge" }
Players.PlayerAdded:Fire(player)

local function lastState()
	for i = #fired, 1, -1 do
		if fired[i][1] == "State" then return fired[i][2] end
	end
end
local notes = {}
local function newNotes()
	local out = {}
	for i = #notes + 1, #fired do
		notes[i] = true
	end
	for i, f in fired do
		if f[1] == "Notify" and not f.seen then
			f.seen = true
			table.insert(out, Lang.t("es", f[3], f[4]))
		end
	end
	return out
end
local function act(name, a, b, c, quiet)
	local ok, key, params, extra = invoke(player, name, a, b, c)
	if not quiet then
		print(string.format("  %-13s -> %-5s %s", name, tostring(ok), key and Lang.t("es", key, params) or ""))
	end
	return ok, key, extra
end
local function money(n)
	return string.format("$%s", tostring(math.floor(n)))
end

local s = lastState()
assert(s and s.money == Config.START_MONEY and #s.planes == 1, "estado inicial")
assert(s.boards.JFK and #s.boards.JFK > 0, "debería haber cargas en JFK")
print("Estado inicial:", money(s.money), "· aviones", #s.planes, "· cargas en JFK", #s.boards.JFK, "· nivel", s.level)

-- Mejor carga que puede llevar un avión (sin licencias)
local function bestLoad(state, plane)
	local model = Config.PlaneById[plane.model]
	local best, bestValue = nil, -math.huge
	for _, l in state.boards[plane.airport] or {} do
		local cargo = Config.CargoById[l.cargo]
		local licOk = (not cargo.license or state.licenses[cargo.license]) and (not cargo.planes or table.find(cargo.planes, plane.model))
		if l.weight <= model.cap and l.dist <= model.range and licOk then
			local value = (l.gross - l.dist * model.burn * state.fuelPrice) / Config.flightSeconds(l.dist, model.speed, 1)
			if value > bestValue then
				best, bestValue = l, value
			end
		end
	end
	return best
end

-- Despacha todos los aviones libres con los pilotos libres
local function dispatchAll(quiet)
	local st = lastState()
	local busy = {}
	for _, p in st.planes do
		if p.flight then busy[p.flight.pilot] = true end
	end
	local pilots = { 0 }
	for _, p in st.pilots do table.insert(pilots, p.id) end
	local sent = 0
	for _, plane in st.planes do
		if not plane.flight then
			if plane.condition < Config.REPAIR_BLOCK then
				act("repair", plane.id, nil, nil, quiet)
				st = lastState()
			end
			local load = bestLoad(st, plane)
			local pilot
			for _, id in pilots do
				if not busy[id] then pilot = id break end
			end
			if load and pilot then
				local ok = act("dispatch", plane.id, load.id, pilot, quiet)
				if ok then
					busy[pilot] = true
					sent += 1
				end
				st = lastState()
			elseif not load then
				act("refreshBoard", plane.airport, nil, nil, true)
				st = lastState()
			end
		end
	end
	return sent
end

-- Avanza hasta el siguiente aterrizaje
local function untilLanding()
	local st = lastState()
	local nextT = math.huge
	for _, p in st.planes do
		if p.flight then nextT = math.min(nextT, p.flight.endT) end
	end
	if nextT == math.huge then
		tick(1)
		return
	end
	local now = 1_700_000_000 + math.floor(fakeTime)
	local wait = math.max(1, nextT - now)
	for _ = 1, wait do tick(1) end
end

print("-- Primer vuelo --")
local plane1 = s.planes[1]
local load = bestLoad(s, plane1)
assert(load, "no hay carga para el avión inicial")
act("dispatch", plane1.id, load.id, 0)
act("dispatch", plane1.id, load.id, 0) -- ocupado
s = lastState()
assert(s.planes[1].flight, "el avión debería estar volando")
local secs = s.planes[1].flight.endT - s.planes[1].flight.startT
print(string.format("  vuelo %s→%s · %d km · %.1f t · %d s · bruto %s · combustible %s", load.from, load.to, load.dist, load.weight, secs, money(s.planes[1].flight.gross), money(s.planes[1].flight.fuel)))
untilLanding()
s = lastState()
assert(not s.planes[1].flight and s.planes[1].airport == load.to, "debería haber aterrizado")
assert(s.money > Config.START_MONEY and s.xp > 0, "debería haber ganado dinero y XP")
print("  aterrizado:", money(s.money), "· XP", s.xp, "· estado", s.planes[1].condition)
for _, n in newNotes() do print("  aviso:", n) end

print("-- Errores esperados --")
act("buyPlane", "turboprop") -- nivel
act("sellPlane", s.planes[1].id) -- último avión
act("repair", s.planes[1].id)
act("refreshBoard", s.planes[1].airport)
act("refreshBoard", s.planes[1].airport) -- enfriamiento
act("hirePilot", "academy") -- nivel
act("buyLicense", "jet") -- nivel
act("buyRegion", "EU") -- nivel
act("setAuto", true) -- nivel
act("bogus")
act("dispatch", "x", {}, nil)
for _ = 1, 12 do invoke(player, "setMuted", false) end
act("setMuted", false) -- demasiado rápido
fakeTime += 2

print("-- Partida rápida (el bot despacha todo lo que puede) --")
local start = fakeTime
local milestones = {}
local function mark(name)
	if not milestones[name] then
		milestones[name] = true
		print(string.format("  [%5.1f min] %s · %s · nivel %d · aviones %d · pilotos %d", (fakeTime - start) / 60, name, money(lastState().money), lastState().level, #lastState().planes, #lastState().pilots))
	end
end
for _ = 1, 2000 do
	dispatchAll(true)
	untilLanding()
	s = lastState()
	-- Compras sencillas: pilotos para que vuelen todos, aviones, licencia y turbohélice
	if #s.pilots < #s.planes - 1 and s.money >= 5000 then
		invoke(player, "hirePilot", "school") mark("piloto contratado")
	elseif s.level >= 3 and not s.licenses.turboprop and s.money >= Config.LicenseById.turboprop.cost then
		invoke(player, "buyLicense", "turboprop") mark("licencia turbohélice")
	elseif s.licenses.turboprop and s.money >= Config.PlaneById.turboprop.price + 5000 and #s.planes < s.maxPlanes then
		invoke(player, "buyPlane", "turboprop") mark("primer turbohélice")
	elseif s.money >= 25000 + 5000 and #s.planes < s.maxPlanes and not s.licenses.turboprop then
		invoke(player, "buyPlane", "courier") mark("segundo avión")
	elseif #s.planes >= s.maxPlanes and s.money >= Config.upgradeCost("hangar", s.upgrades.hangar) then
		invoke(player, "buyUpgrade", "hangar") mark("hangar ampliado")
	end
	if s.level >= 2 then mark("nivel 2") end
	if s.level >= 3 then mark("nivel 3") end
	if s.level >= 5 then mark("nivel 5 (despacho automático)") end
	if s.level >= 6 then mark("nivel 6") break end
end
s = lastState()
print(string.format("  tras %.1f min de juego: %s · nivel %d · XP %d · vuelos %d", (fakeTime - start) / 60, money(s.money), s.level, s.xp, s.stats.flights))
newNotes()

print("-- Salir con vuelos en el aire y volver más tarde --")
dispatchAll(true)
local flying = 0
for _, p in lastState().planes do if p.flight then flying += 1 end end
print("  aviones volando al salir:", flying)
Players.PlayerRemoving:Fire(player)
assert(saved.player_42, "debería haberse guardado")
fakeTime += 3600
Players.PlayerAdded:Fire(player)
s = lastState()
for _, p in s.planes do assert(not p.flight, "los vuelos deberían haber aterrizado offline") end
for _, n in newNotes() do print("  aviso:", n) end

print("-- Partida avanzada (dinero y XP inyectados en el guardado) --")
Players.PlayerRemoving:Fire(player)
saved.player_42.money = 2e9
saved.player_42.xp = Config.xpForLevel(22)
Players.PlayerAdded:Fire(player)
s = lastState()
print("  nivel", s.level, money(s.money))
for _, r in Config.Regions do act("buyRegion", r.id, nil, nil, true) fakeTime += 0.2 end
for _, l in Config.Licenses do act("buyLicense", l.id, nil, nil, true) fakeTime += 0.2 end
fakeTime += 2
for _, u in Config.Upgrades do
	for _ = 1, u.max + 1 do act("buyUpgrade", u.id, nil, nil, true) fakeTime += 0.2 end
end
fakeTime += 2
act("buyUpgrade", "fuel") -- ya al máximo
for _, m in Config.Planes do act("buyPlane", m.id) fakeTime += 0.2 end
for _ = 1, 3 do act("hirePilot", "academy", nil, nil, true) fakeTime += 0.4 end
for _ = 1, 3 do act("hirePilot", "aces", nil, nil, true) fakeTime += 0.4 end
s = lastState()
print("  regiones", #Config.Regions, "· licencias", #Config.Licenses, "· aviones", #s.planes, "/", s.maxPlanes, "· pilotos", #s.pilots)
local rarities = {}
for _, p in s.pilots do rarities[p.rarity] = (rarities[p.rarity] or 0) + 1 end
for r, n in rarities do print("    pilotos", r, n) end
-- El sorteo respeta las probabilidades (nada común en Academy/Aces)
act("ferry", s.planes[1].id, "SYD") -- fuera de alcance
for _, p in s.planes do
	if p.model == "widebody" and not p.flight then
		act("ferry", p.id, p.airport == "LHR" and "FRA" or "LHR")
		break
	end
end
act("setAuto", true)
fakeTime += 2
tick(1)
s = lastState()
local inAir = 0
for _, p in s.planes do if p.flight then inAir += 1 end end
print("  despacho automático: aviones en el aire", inAir, "de", #s.planes)
assert(inAir >= 3, "el despacho automático debería mandar varios aviones")
act("firePilot", s.pilots[1].id) -- puede estar volando
act("setLang", "es")
act("setLang", "fr")
act("setMuted", true)
-- Venta y reparación
for _ = 1, 30 do tick(1) end
s = lastState()
for _, p in s.planes do
	if not p.flight then
		act("repair", p.id)
		act("sellPlane", p.id)
		break
	end
end
-- Estado para el harness del cliente: algunos aviones volando y otros en tierra
act("setAuto", false)
for _ = 1, 400 do tick(1) end
-- La mitad de los aviones en el aire y el resto en tierra con su tablón
local st = lastState()
local sentOne = 0
for _, p in st.planes do
	if not p.flight and sentOne < #st.planes / 2 then
		local l = bestLoad(lastState(), p)
		if l then
			act("dispatch", p.id, l.id, 0, true)
			sentOne += 1
			fakeTime += 0.2
			break
		end
	end
end
st = lastState()
local idle = 0
for _, p in st.planes do if not p.flight then idle += 1 end end
print("  estado final: aviones en tierra", idle, "de", #st.planes)
assert(idle > 0, "el estado para el cliente necesita aviones en tierra")
fs.writeFile("state.json", require("@lune/serde").encode("json", st))
print("TODO OK")
process.exit(0)
