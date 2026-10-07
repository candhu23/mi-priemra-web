-- Ejecuta el servidor REAL (GameServer + World + CombatService + EnemyModels)
-- con servicios simulados y un jugador falso con personaje que recorre todo:
-- viajar, luchar, subir de nivel, botín, equipar, vender, forja, cofres, jefe,
-- desbloqueo de zona, compras con Robux, morir y revivir, guardar, salir y volver.
-- Si algo revienta o no cuadra, falla con error.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SRC = process.args[1]
local sources = {}
local function readSource(path)
	if not sources[path] then
		sources[path] = fs.readFile(path)
	end
	return sources[path]
end
local FILES = {
	GameConfig = "/ReplicatedStorage/GameConfig.luau",
	World = "/ServerScriptService/World.luau",
	EnemyModels = "/ServerScriptService/EnemyModels.luau",
	CombatService = "/ServerScriptService/CombatService.luau",
	GameServer = "/ServerScriptService/GameServer.server.luau",
}
for _, rel in FILES do
	readSource(SRC .. rel)
end

---------------------------------------------------------------------
-- Proxies sobre instancias reales de Lune
---------------------------------------------------------------------
local realOf = setmetatable({}, { __mode = "k" })
local proxyByKey = {}
local overrides = setmetatable({}, { __mode = "k" })
local callbacks = {}
local fired = {} -- llamadas a FireClient / FireAllClients
local EVENTS = { Triggered = true, Changed = true, Touched = true, Activated = true, Completed = true, CharacterAdded = true, Died = true, OnServerEvent = true, Heartbeat = true }
local NOOP_METHODS = { Emit = true, Play = true, Stop = true }

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
local signals = {}
local function signalFor(id, key)
	local k = tostring(id) .. ":" .. key
	signals[k] = signals[k] or newSignal()
	return signals[k]
end

local wrap, unwrap
local proxyMeta = {}
local idCounter = 0

local function idOf(inst)
	-- Lune crea objetos distintos para la misma instancia: usamos un atributo como id
	local id = inst:GetAttribute("__hid")
	if not id then
		idCounter += 1
		id = idCounter
		inst:SetAttribute("__hid", id)
	end
	return id
end

function wrap(v)
	if typeof(v) == "Instance" then
		local id = idOf(v)
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

-- Model:PivotTo no existe en Lune: movemos todas las piezas como haría Roblox
local function pivotTo(model, target)
	local pivotPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	assert(pivotPart, "PivotTo sin piezas")
	local delta = target * pivotPart.CFrame:Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end

proxyMeta.__index = function(p, key)
	local o = overrides[p]
	if o and o[key] ~= nil then
		return o[key]
	end
	local inst = realOf[p]
	if EVENTS[key] then
		return signalFor(idOf(inst), key)
	end
	if key == "GetPropertyChangedSignal" or key == "GetAttributeChangedSignal" then
		return function() return newSignal() end
	end
	if key == "FireClient" then
		return function(_, _plr, ...)
			table.insert(fired, { inst.Name, ... })
		end
	end
	if key == "FireAllClients" then
		return function(_, ...)
			table.insert(fired, { inst.Name, ... })
		end
	end
	if key == "PivotTo" then
		return function(_, cframe)
			pivotTo(inst, cframe)
		end
	end
	-- Lune no calcula Position a partir del CFrame
	if key == "Position" and inst:IsA("BasePart") then
		return inst.CFrame.Position
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
	if key == "ProcessReceipt" then
		callbacks.ProcessReceipt = value
		return
	end
	if key == "Position" and realOf[p]:IsA("BasePart") then
		local cf = realOf[p].CFrame
		realOf[p].CFrame = cf - cf.Position + value
		return
	end
	realOf[p][key] = unwrap(value)
end
proxyMeta.__tostring = function(p)
	return tostring(realOf[p])
end

---------------------------------------------------------------------
-- Servicios simulados
---------------------------------------------------------------------
local saved = {}
local DataStoreService = {
	GetDataStore = function()
		return {
			GetAsync = function(_, key) return saved[key] end,
			UpdateAsync = function(_, key, fn)
				-- Como en Roblox: se guarda una copia serializada
				saved[key] = serde.decode("json", serde.encode("json", fn(saved[key])))
			end,
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
local MarketplaceService = setmetatable({
	PromptGamePassPurchaseFinished = newSignal(),
	UserOwnsGamePassAsync = function(_, _userId, passId) return passId == 555 end,
}, {
	__newindex = function(_, key, value)
		callbacks[key] = value
	end,
})
local playerList = {}
local Players = {
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function() return playerList end,
	GetNameFromUserIdAsync = function(_, id) return "Jugador" .. id end,
	RespawnTime = 5,
}
local heartbeat = newSignal()
local RunService = { Heartbeat = heartbeat }

local dataModel = roblox.Instance.new("DataModel")
local services = {}
for _, name in { "Workspace", "Lighting", "ReplicatedStorage", "ServerScriptService" } do
	services[name] = dataModel:GetService(name)
end

local closeHandlers = {}
local game = {
	GetService = function(_, name)
		local mocks = {
			DataStoreService = DataStoreService,
			MarketplaceService = MarketplaceService,
			Players = Players,
			RunService = RunService,
		}
		if mocks[name] then
			return mocks[name]
		end
		return wrap(assert(services[name], "servicio no simulado: " .. name))
	end,
	BindToClose = function(_, fn) table.insert(closeHandlers, fn) end,
}

local modulePaths = {}
local function addModule(parent, className, name)
	local m = roblox.Instance.new(className)
	m.Name = name
	m.Parent = parent
	modulePaths[m:GetFullName()] = SRC .. FILES[name]
	return m
end
addModule(services.ReplicatedStorage, "ModuleScript", "GameConfig")
addModule(services.ServerScriptService, "ModuleScript", "World")
addModule(services.ServerScriptService, "ModuleScript", "EnemyModels")
addModule(services.ServerScriptService, "ModuleScript", "CombatService")
local serverScript = addModule(services.ServerScriptService, "Script", "GameServer")

local randomSeed = 1
local Random = {
	new = function(seed)
		local rng = { state = seed or randomSeed }
		randomSeed += 1
		local function nextValue()
			rng.state = (rng.state * 1103515245 + 12345) % 2147483648
			return rng.state / 2147483648
		end
		return {
			NextNumber = function(_, a, b) a, b = a or 0, b or 1 return a + nextValue() * (b - a) end,
			NextInteger = function(_, a, b) return a + math.floor(nextValue() * (b - a + 1)) end,
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
local Config = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("GameConfig")))
Config.ProductByKey.gold_small.id = 111
Config.ProductByKey.boost.id = 222
Config.ProductByKey.revive.id = 333
Config.PassByKey.goldPass.id = 555 -- UserOwnsGamePassAsync devuelve true solo para este

-- Arrancar el script del servidor (se queda dormido en su bucle principal)
do
	local env = makeEnv(serverScript)
	env.require = requireModule
	local chunk = luau.load(readSource(SRC .. FILES.GameServer), { debugName = "GameServer", environment = env })
	task.spawn(chunk)
end
local Combat = requireModule(wrap(services.ServerScriptService:FindFirstChild("CombatService")))
local World = requireModule(wrap(services.ServerScriptService:FindFirstChild("World")))
local invoke = assert(callbacks.Action, "no hay OnServerInvoke")
local processReceipt = assert(callbacks.ProcessReceipt, "no hay ProcessReceipt")
local remotes = services.ReplicatedStorage:FindFirstChild("DungeonRemotes")
local combatRemote = wrap(remotes:FindFirstChild("Combat"))

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
-- Avanza el combate (como el Heartbeat de Roblox)
local function step(seconds)
	local n = math.max(1, math.floor(seconds / (1 / 15)))
	for _ = 1, n do
		fakeTime += 1 / 15
		heartbeat:Fire(1 / 15)
	end
	tick(0)
end

---------------------------------------------------------------------
-- Mundo construido
---------------------------------------------------------------------
local workspace = services.Workspace
local mundo = workspace:FindFirstChild("Mundo")
assert(mundo, "no se creó el mundo")
local partCount, prompts = 0, {}
for _, d in mundo:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	elseif d:IsA("ProximityPrompt") then
		table.insert(prompts, d)
	end
end
local enemies = Combat.debugEnemies()
print(string.format("Mundo: %d piezas · %d carteles con botón · %d enemigos (%d jefes)", partCount, #prompts, #enemies, #Config.Zones))
assert(#enemies == #Config.Zones * 13, "faltan enemigos")
assert(#prompts == #Config.Zones * 2 + 2, "faltan ProximityPrompts")
for _, zone in Config.Zones do
	local entry = World.zoneEntry(zone.id)
	assert(World.zoneAt(entry.Position) == zone.id, "la entrada de " .. zone.id .. " no está dentro de su zona")
end
assert(World.zoneAt(roblox.Vector3.new(0, 3, 18)) == nil, "la ciudad no debería ser una zona")
-- Todos los enemigos dentro de su zona
for _, enemy in enemies do
	assert(World.zoneAt(enemy.home) == enemy.zoneId, "enemigo fuera de su zona: " .. enemy.def.name)
end

-- Volcar las piezas para dibujar mapas y enemigos (tools/harness/render.py)
do
	local parts = {}
	local function v(x)
		return { x.X, x.Y, x.Z }
	end
	local function dump(root, group)
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local cf = d.CFrame
				local c = d.Color
				local shape = if d:IsA("Part") then d.Shape.Name else "Block"
				table.insert(parts, { n = d.Name, g = group, p = v(cf.Position), x = v(cf.XVector), y = v(cf.YVector), z = v(cf.ZVector), s = v(d.Size), c = { c.R, c.G, c.B }, t = d.Transparency, m = d.Material.Name, shape = shape })
			end
		end
	end
	dump(mundo:FindFirstChild("Ciudad"), "ciudad")
	for _, zone in Config.Zones do
		dump(mundo:FindFirstChild("Zona_" .. zone.id), zone.id)
	end
	dump(workspace:FindFirstChild("Enemigos"), "enemigos")
	-- Galería: un ejemplar de cada enemigo en fila, mirando a la cámara (-Z)
	local EnemyModels = requireModule(wrap(services.ServerScriptService:FindFirstChild("EnemyModels")))
	local gallery = roblox.Instance.new("Folder")
	local ids = {}
	for id in Config.Enemies do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local da, db = Config.Enemies[a], Config.Enemies[b]
		if (da.boss == true) ~= (db.boss == true) then return not da.boss end
		return a < b
	end)
	local x = 0
	for _, id in ids do
		local model = unwrap(EnemyModels.build(Config.Enemies[id]))
		local width = 8 * Config.Enemies[id].size + 2
		x += width / 2
		pivotTo(model, roblox.CFrame.new(x, 0, 5000) * roblox.CFrame.Angles(0, math.pi, 0))
		model.Parent = gallery
		x += width / 2
	end
	dump(gallery, "galeria")
	fs.writeFile("world.json", serde.encode("json", parts))
end

---------------------------------------------------------------------
-- Jugador falso con personaje
---------------------------------------------------------------------
local playersFolder = roblox.Instance.new("Folder")
playersFolder.Name = "Players"
playersFolder.Parent = dataModel
local realPlayer = roblox.Instance.new("Folder")
realPlayer.Name = "Jorge"
realPlayer.Parent = playersFolder
local player = wrap(realPlayer)

local character, humanoid, root
local function makeCharacter()
	local model = roblox.Instance.new("Model")
	model.Name = "Jorge"
	local hrp = roblox.Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = roblox.Vector3.new(2, 2, 1)
	hrp.CFrame = roblox.CFrame.new(0, 3, 18)
	hrp.Parent = model
	local hand = roblox.Instance.new("Part")
	hand.Name = "RightHand"
	hand.CFrame = roblox.CFrame.new(1.5, 2, 18)
	hand.Parent = model
	model.PrimaryPart = hrp
	local hum = roblox.Instance.new("Humanoid")
	hum.MaxHealth = 100
	hum.Health = 100
	hum.Parent = model
	model.Parent = workspace
	character, humanoid, root = wrap(model), wrap(hum), wrap(hrp)
	overrides[humanoid] = {
		TakeDamage = function(_, amount)
			humanoid.Health = math.max(0, humanoid.Health - amount)
		end,
	}
	return character
end
makeCharacter()

local loadedCharacters = 0
overrides[player] = {
	UserId = 42, DisplayName = "Jorge", Name = "Jorge",
	Character = character,
	IsFriendsWithAsync = function() return false end,
	LoadCharacterAsync = function()
		loadedCharacters += 1
		overrides[player].Character = makeCharacter()
		signalFor(idOf(realPlayer), "CharacterAdded"):Fire(character)
	end,
}
Players.GetPlayerByUserId = function() return player end
table.insert(playerList, player)
Players.PlayerAdded:Fire(player)
tick(0)

local function lastState()
	for i = #fired, 1, -1 do
		if fired[i][1] == "State" then return fired[i][2] end
	end
end
local function countFired(remote, kind)
	local n = 0
	for _, f in fired do
		if f[1] == remote and (kind == nil or f[2] == kind or f[3] == kind) then n += 1 end
	end
	return n
end
local function act(name, a, b)
	fakeTime += 0.15 -- el servidor limita a 10 acciones por segundo
	local ok, message = invoke(player, name, a, b)
	print(string.format("  %-14s -> %s %s", name, tostring(ok), tostring(message or "")))
	return ok, message
end
local function skill(id)
	signalFor(idOf(unwrap(combatRemote)), "OnServerEvent"):Fire(player, "skill", id)
end
local function moveTo(position)
	pivotTo(unwrap(character), roblox.CFrame.new(position + roblox.Vector3.new(0, 3, 0)))
end

local s = lastState()
assert(s and s.level == 1 and s.gold == 0 and #s.inventory == 1, "estado inicial")
assert(humanoid.MaxHealth == Config.BASE_HEALTH, "vida máxima inicial")
assert(unwrap(character):FindFirstChild("ArmaEquipada"), "no lleva el arma en la mano")
print(string.format("Estado inicial: nivel %d · vida %d · daño %d · mochila %d/%d", s.level, humanoid.MaxHealth, s.stats.damage, #s.inventory, s.capacity))
assert(s.bonuses.goldPass == true, "el pase x2 Oro debería estar activo")

---------------------------------------------------------------------
-- Viajar
---------------------------------------------------------------------
print("-- Viajes --")
act("teleport", "castillo") -- bloqueado
act("teleport", "noexiste")
act("teleport", "bosque")
assert(World.zoneAt(root.Position) == "bosque", "no llegó al bosque")
act("teleport", "lobby")
assert(World.zoneAt(root.Position) == nil, "no volvió a la ciudad")
-- Portal de la ciudad (ProximityPrompt)
for _, p in prompts do
	if p.ObjectText == "Bosque Encantado" then
		signalFor(idOf(p), "Triggered"):Fire(player)
	end
end
assert(World.zoneAt(root.Position) == "bosque", "el portal no funciona")

---------------------------------------------------------------------
-- Combate en el Bosque
---------------------------------------------------------------------
print("-- Combate --")
local function nearestAlive(zoneId, filter)
	local best, bestDist = nil, math.huge
	for _, e in enemies do
		if e.alive and e.zoneId == zoneId and (not filter or filter(e)) then
			local d = (e.pos - root.Position).Magnitude
			if d < bestDist then best, bestDist = e, d end
		end
	end
	return best
end
local slime = nearestAlive("bosque", function(e) return e.def.id == "slime" end)
moveTo(slime.home + roblox.Vector3.new(0, 0, 12))
step(1.5)
assert(slime.target == player, "el slime no persigue al jugador")
local distance = (slime.pos - root.Position).Magnitude
print(string.format("  el slime persigue: distancia %.1f", distance))
step(3)
assert(humanoid.Health < 100, "el slime no hace daño")
print(string.format("  vida tras el ataque del slime: %d", humanoid.Health))
skill("spin") -- nivel 1: bloqueada
assert(countFired("Notify") > 0, "debería avisar de habilidad bloqueada")
local killsBefore = lastState().kills
for _ = 1, 10 do
	skill("attack")
	step(0.55)
	if not slime.alive then break end
end
tick(0)
s = lastState()
assert(not slime.alive and s.kills > killsBefore, "no se mató al slime")
assert(s.xp > 0 and s.gold > 0, "no dio XP ni oro")
assert(countFired("Combat", "hits") > 0 and countFired("Combat", "reward") > 0, "no se enviaron golpes o recompensa")
print(string.format("  slime derrotado: XP %d · oro %d", s.xp, s.gold))
-- Reaparece
step(Config.ENEMY_RESPAWN + 1)
assert(slime.alive, "el slime no reapareció")

-- Farmear para subir de nivel y conseguir botín (con la vida rellenada)
local function farm(zoneId, attacks)
	for _ = 1, attacks do
		local e = nearestAlive(zoneId, function(x) return not x.isBoss end)
		if e then
			moveTo(e.pos + roblox.Vector3.new(0, 0, 4))
			skill(if lastState().level >= 3 then "spin" else "attack")
			skill("attack")
		end
		humanoid.Health = humanoid.MaxHealth
		step(0.6)
	end
	tick(0)
end
farm("bosque", 260)
s = lastState()
print(string.format("  tras farmear: nivel %d · XP %d/%d · oro %d · objetos %d · enemigos %d", s.level, s.xp, s.xpNeeded, s.gold, #s.inventory, s.kills))
assert(s.level >= 3, "debería haber subido de nivel")
assert(humanoid.MaxHealth > Config.BASE_HEALTH, "la vida no sube con el nivel")
assert(countFired("Combat", "levelup") > 0, "no avisó de subida de nivel")

---------------------------------------------------------------------
-- Mochila y forja
---------------------------------------------------------------------
print("-- Mochila y forja --")
-- Asegurar botín para probar (cofre con oro)
act("buyChest", 1)
act("buyChest", 3) -- bloqueado
s = lastState()
print("  objetos en la mochila:", #s.inventory)
local equipCandidate, sellCandidate
for _, item in s.inventory do
	local slot = Config.Items[item.def].slot
	if item.id ~= s.equipped[slot] then
		if not equipCandidate then equipCandidate = item elseif not sellCandidate then sellCandidate = item end
	end
end
if equipCandidate then
	act("equip", equipCandidate.id)
	s = lastState()
	assert(s.equipped[Config.Items[equipCandidate.def].slot] == equipCandidate.id, "no se equipó")
	act("sell", equipCandidate.id) -- equipado: falla
end
if sellCandidate then
	act("sell", sellCandidate.id)
end
act("sell", 99999)
act("equip", "malo")
local weaponId = lastState().equipped.weapon
local before = lastState().stats.damage
act("upgrade", weaponId)
local after = lastState().stats.damage
print(string.format("  daño antes/después de forjar: %d → %d", before, after))
act("sellJunk", 1)
act("sellJunk", 9) -- no válido
act("setAutoSell", true)

---------------------------------------------------------------------
-- Jefe del Bosque
---------------------------------------------------------------------
print("-- Jefe --")
local boss = nil
for _, e in enemies do
	if e.isBoss and e.zoneId == "bosque" then boss = e end
end
moveTo(boss.home + roblox.Vector3.new(0, 0, 6))
step(0.5)
assert(boss.target == player, "el jefe no persigue")
step(2.2)
local warning = workspace:FindFirstChild("Enemigos"):FindFirstChild("AvisoGolpe")
assert(warning, "el jefe no avisa de su golpe de área")
local hpBefore = humanoid.Health
step(1.6)
assert(not workspace:FindFirstChild("Enemigos"):FindFirstChild("AvisoGolpe"), "el aviso no desaparece")
print(string.format("  golpe de área del jefe: vida %d → %d", hpBefore, humanoid.Health))
assert(humanoid.Health < hpBefore, "el golpe de área no hace daño")
-- Derrotarlo (dando vida al jugador para que aguante)
local hits = 0
while boss.alive and hits < 600 do
	moveTo(boss.pos + roblox.Vector3.new(0, 0, 5))
	skill("attack")
	if lastState().level >= 3 then skill("spin") end
	humanoid.Health = humanoid.MaxHealth
	step(0.55)
	hits += 1
end
tick(0)
assert(not boss.alive, "no se pudo derrotar al jefe")
s = lastState()
print(string.format("  jefe derrotado en %d golpes · zona desbloqueada %d · jefes %s", hits, s.unlockedZone, serde.encode("json", s.bossKills)))
assert(s.unlockedZone == 2, "no se desbloqueó la Cueva")
act("teleport", "cueva")
assert(World.zoneAt(root.Position) == "cueva", "no llegó a la cueva")
act("teleport", "castillo") -- aún bloqueado

---------------------------------------------------------------------
-- Diario, tutorial, ajustes y guardado
---------------------------------------------------------------------
print("-- Diario y ajustes --")
act("claimDaily")
act("claimDaily") -- ya recogida
act("finishTutorial")
act("finishTutorial") -- no paga dos veces
act("setMuted", true)
act("saveNow")
act("saveNow") -- enfriamiento
act("bogus")
s = lastState()
assert(s.settings.muted and s.settings.autoSell and s.tutorialDone, "ajustes no guardados en el estado")

---------------------------------------------------------------------
-- Compras con Robux
---------------------------------------------------------------------
print("-- Compras --")
local gold0 = lastState().gold
print("  receipt oro       ->", processReceipt({ PlayerId = 42, ProductId = 111, PurchaseId = "p1" }))
local gold1 = lastState().gold
print("  receipt repetido  ->", processReceipt({ PlayerId = 42, ProductId = 111, PurchaseId = "p1" }))
assert(gold1 > gold0 and lastState().gold == gold1, "la compra repetida no debe pagar dos veces")
print("  receipt boost     ->", processReceipt({ PlayerId = 42, ProductId = 222, PurchaseId = "p2" }))
assert(lastState().bonuses.boost, "boost no activo")
print("  receipt desconocido ->", processReceipt({ PlayerId = 42, ProductId = 999, PurchaseId = "p3" }))

-- Morir en la cueva y revivir allí
moveTo(World.zoneEntry("cueva").Position)
humanoid.Health = 0
signalFor(idOf(unwrap(humanoid)), "Died"):Fire()
assert(countFired("Combat", "died") > 0, "no avisó de la muerte")
print("  receipt revivir   ->", processReceipt({ PlayerId = 42, ProductId = 333, PurchaseId = "p4" }))
tick(0)
assert(loadedCharacters == 1, "no se recargó el personaje")
assert(World.zoneAt(root.Position) == "cueva", "no revivió en la cueva")
assert(humanoid.MaxHealth == lastState().stats.maxHealth, "el personaje nuevo no recibió su vida")
print(string.format("  revivido en la cueva con %d de vida", humanoid.Health))
-- Morir otra vez, reaparecer en la Ciudad y comprar después: también vuelve a la cueva
humanoid.Health = 0
signalFor(idOf(unwrap(humanoid)), "Died"):Fire()
overrides[player].LoadCharacterAsync(player) -- la reaparición automática de Roblox
act("teleport", "lobby")
assert(World.zoneAt(root.Position) == nil, "debería estar en la Ciudad")
print("  receipt revivir tarde ->", processReceipt({ PlayerId = 42, ProductId = 333, PurchaseId = "p5" }))
tick(0)
assert(World.zoneAt(root.Position) == "cueva", "la compra tardía no lleva a la cueva")
print("  receipt revivir (sin morir) ->", processReceipt({ PlayerId = 42, ProductId = 333, PurchaseId = "p6" }))

---------------------------------------------------------------------
-- Salir, cerrar y volver a entrar
---------------------------------------------------------------------
print("-- Salir y volver --")
Players.PlayerRemoving:Fire(player)
assert(saved["player_42"], "no se guardó")
print("Guardado OK · nivel", saved["player_42"].level, "· objetos", #saved["player_42"].inventory)
for _, fn in closeHandlers do task.spawn(fn) end
tick(0)
print("Cierre del servidor OK")

-- Volver con nivel alto para probar Embestida y Curación
saved["player_42"].level = 12
saved["player_42"].equipped.amulet = 424242 -- objeto que ya no existe: debe limpiarse
fakeTime += 60
Players.PlayerAdded:Fire(player)
tick(0)
s = lastState()
assert(s.level == 12 and s.equipped.amulet == nil, "la partida no se cargó bien")
print(string.format("Reentrada: nivel %d · oro %d · objetos %d", s.level, s.gold, #s.inventory))
act("teleport", "bosque")
humanoid.Health = 50
skill("heal")
assert(humanoid.Health > 50, "la curación no cura")
local wolf = nearestAlive("bosque", function(e) return e.def.id == "lobo" end)
local look = (wolf.pos - root.Position)
look = roblox.Vector3.new(look.X, 0, look.Z).Unit
-- (CFrame.lookAt de Lune gira al revés: usamos el ángulo como hace CombatService)
pivotTo(unwrap(character), roblox.CFrame.new(wolf.pos - look * 12 + roblox.Vector3.new(0, 3, 0)) * roblox.CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0))
local wolfHp = wolf.hp
skill("dash")
assert(wolf.hp < wolfHp or not wolf.alive, "la embestida no golpea en línea")
print(string.format("  embestida: lobo %d → %d · curación OK", wolfHp, wolf.hp))

-- La clasificación lee las puntuaciones
for _ = 1, 3 do tick(0) end

fs.writeFile("state.json", serde.encode("json", lastState()))
print("TODO OK")
process.exit(0)
