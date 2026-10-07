-- Ejecuta el servidor REAL (GameServer + World + RunManager + GameConfig)
-- con servicios simulados y jugadores falsos con personaje que recorren todo:
-- partida solo (oleadas, armas, cristales, subir de nivel, elegir mejoras,
-- élites, jefe, portal y victoria), partida en grupo (unirse, caer, revivir,
-- abandonar), mejoras permanentes, clases, mochila, forja, cofres, compras
-- con Robux, guardar, salir a mitad de partida y volver.
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
	Ambience = "/ReplicatedStorage/Ambience.luau",
	EnemyModels = "/ReplicatedStorage/EnemyModels.luau",
	World = "/ServerScriptService/World.luau",
	RunManager = "/ServerScriptService/RunManager.luau",
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
local fired = {} -- llamadas a FireClient / FireAllClients: { remote, userId, ... }
local swarmCount = 0
local lastSwarm = {}
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
		return function(_, plr, ...)
			if inst.Name == "Swarm" then
				swarmCount += 1
				lastSwarm[plr.UserId] = table.pack(...)
				return
			end
			table.insert(fired, { inst.Name, plr.UserId, ... })
		end
	end
	if key == "FireAllClients" then
		return function(_, ...)
			table.insert(fired, { inst.Name, 0, ... })
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
	local o = overrides[p]
	if o and o[key] ~= nil then
		o[key] = value
		return
	end
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
addModule(services.ReplicatedStorage, "ModuleScript", "EnemyModels")
addModule(services.ReplicatedStorage, "ModuleScript", "Ambience")
addModule(services.ServerScriptService, "ModuleScript", "World")
addModule(services.ServerScriptService, "ModuleScript", "RunManager")
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
Config.PassByKey.choicePass.id = 555 -- UserOwnsGamePassAsync devuelve true solo para este

-- Terreno simulado (Lune no tiene Terrain): se apuntan los rellenos para dibujarlos
local terrainFills = {}
local terrainGroup = "ciudad"
do
	local terrainFolder = roblox.Instance.new("Folder")
	terrainFolder.Name = "Terrain"
	terrainFolder.Parent = services.Workspace
	local terrainProxy = wrap(terrainFolder)
	local function record(kind, material, data)
		assert(typeof(material) == "EnumItem", "material no válido")
		if terrainGroup and material ~= roblox.Enum.Material.Air then
			data.kind = kind
			data.m = material.Name
			data.g = terrainGroup
			table.insert(terrainFills, data)
		end
	end
	local function v(x) return { x.X, x.Y, x.Z } end
	overrides[terrainProxy] = {
		WaterColor = roblox.Color3.new(), WaterReflectance = 0, WaterTransparency = 0, WaterWaveSize = 0, WaterWaveSpeed = 0, Decoration = false,
		FillBlock = function(_, cf, size, material)
			record("block", material, { p = v(cf.Position), x = v(cf.XVector), y = v(cf.YVector), z = v(cf.ZVector), s = v(size) })
		end,
		FillBall = function(_, center, radius, material)
			assert(radius > 0, "radio no válido")
			record("ball", material, { p = v(center), r = radius })
		end,
		FillCylinder = function(_, cf, height, radius, material)
			record("cylinder", material, { p = v(cf.Position), h = height, r = radius })
		end,
		FillWedge = function(_, cf, size, material)
			record("block", material, { p = v(cf.Position), x = v(cf.XVector), y = v(cf.YVector), z = v(cf.ZVector), s = v(size) })
		end,
	}
	overrides[wrap(services.Workspace)] = {
		Terrain = terrainProxy,
		FindFirstChildOfClass = function(_, className)
			if className == "Terrain" then return terrainProxy end
			return wrap(services.Workspace:FindFirstChildOfClass(className))
		end,
	}
end

-- Arrancar el script del servidor (se queda dormido en su bucle principal)
do
	local env = makeEnv(serverScript)
	env.require = requireModule
	local chunk = luau.load(readSource(SRC .. FILES.GameServer), { debugName = "GameServer", environment = env })
	task.spawn(chunk)
end
local RunManager = requireModule(wrap(services.ServerScriptService:FindFirstChild("RunManager")))
local World = requireModule(wrap(services.ServerScriptService:FindFirstChild("World")))
local invoke = assert(callbacks.Action, "no hay OnServerInvoke")
local processReceipt = assert(callbacks.ProcessReceipt, "no hay ProcessReceipt")
local remotes = services.ReplicatedStorage:FindFirstChild("DungeonRemotes")
local swarmRemote = remotes:FindFirstChild("Swarm")

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
-- Lobby construido
---------------------------------------------------------------------
local workspace = services.Workspace
local mundo = workspace:FindFirstChild("Mundo")
assert(mundo, "no se creó el mundo")
local prompts = {}
local partCount = 0
for _, d in mundo:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	elseif d:IsA("ProximityPrompt") then
		table.insert(prompts, d)
	end
end
print(string.format("Lobby: %d piezas · %d carteles con botón", partCount, #prompts))
assert(#prompts == #Config.Maps + 2, "faltan ProximityPrompts")

-- Volcar piezas para dibujar mapas y enemigos (tools/harness/render.py)
do
	local World = requireModule(wrap(services.ServerScriptService:FindFirstChild("World")))
	local EnemyModels = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("EnemyModels")))
	local parts = {}
	local function v(x)
		return { x.X, x.Y, x.Z }
	end
	local function dump(root, group, offset)
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local cf = d.CFrame
				local c = d.Color
				local shape = if d:IsA("Part") then d.Shape.Name else "Block"
				table.insert(parts, { n = d.Name, g = group, p = v(cf.Position - offset), x = v(cf.XVector), y = v(cf.YVector), z = v(cf.ZVector), s = v(d.Size), c = { c.R, c.G, c.B }, t = d.Transparency, m = d.Material.Name, shape = shape })
			end
		end
	end
	dump(mundo:FindFirstChild("Ciudad"), "ciudad", roblox.Vector3.new())
	for i, map in Config.Maps do
		local slot = Config.ARENA_SLOTS - i + 1
		terrainGroup = map.id
		local origin = World.buildArena(slot, i)
		terrainGroup = nil
		for _, fill in terrainFills do
			if fill.g == map.id and not fill.relative then
				fill.p = { fill.p[1] - origin.X, fill.p[2] - origin.Y, fill.p[3] - origin.Z }
				fill.relative = true
			end
		end
		dump(mundo:FindFirstChild("Arena_" .. slot), map.id, origin)
		World.destroyArena(slot)
	end
	-- Galería: un ejemplar de cada enemigo (y un élite) en fila, mirando a la cámara (-Z)
	local gallery = roblox.Instance.new("Folder")
	local ids = table.clone(Config.EnemyList)
	table.sort(ids, function(a, b)
		local da, db = Config.Enemies[a], Config.Enemies[b]
		if (da.boss == true) ~= (db.boss == true) then return not da.boss end
		return a < b
	end)
	table.insert(ids, 1, "goblin*")
	local x = 0
	for _, id in ids do
		local elite = string.sub(id, -1) == "*"
		local def = Config.Enemies[if elite then string.sub(id, 1, -2) else id]
		local model = unwrap(EnemyModels.build(def, elite))
		local width = 8 * def.size * (if elite then 1.7 else 1) + 2
		x += width / 2
		pivotTo(model, roblox.CFrame.new(x, 0, 5000) * roblox.CFrame.Angles(0, math.pi, 0))
		model.Parent = gallery
		x += width / 2
	end
	dump(gallery, "galeria", roblox.Vector3.new())
	for _, fill in terrainFills do
		fill.terrain = true
		table.insert(parts, fill)
	end
	fs.writeFile("world.json", serde.encode("json", parts))
	local lobbyFills = 0
	for _, fill in terrainFills do if fill.g == "ciudad" then lobbyFills += 1 end end
	print(string.format("Terreno: %d rellenos en el lobby · %d en total con las arenas", lobbyFills, #terrainFills))
end

---------------------------------------------------------------------
-- Jugadores falsos con personaje
---------------------------------------------------------------------
local playersFolder = roblox.Instance.new("Folder")
playersFolder.Name = "Players"
playersFolder.Parent = dataModel
local byUserId = {}
Players.GetPlayerByUserId = function(_, id) return byUserId[id] end

type Fake = { player: any, real: any, character: any, humanoid: any, root: any, loads: number }
local function makeCharacter(fake)
	local model = roblox.Instance.new("Model")
	model.Name = fake.real.Name
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
	hum.WalkSpeed = 16
	hum.Parent = model
	model.Parent = workspace
	fake.character, fake.humanoid, fake.root = wrap(model), wrap(hum), wrap(hrp)
	overrides[fake.humanoid] = {
		TakeDamage = function(_, amount)
			fake.humanoid.Health = math.max(0, fake.humanoid.Health - amount)
		end,
	}
	overrides[fake.player].Character = fake.character
end

local function makePlayer(name: string, userId: number): Fake
	local real = roblox.Instance.new("Folder")
	real.Name = name
	real.Parent = playersFolder
	local fake = { real = real, player = wrap(real), loads = 0 }
	overrides[fake.player] = {
		UserId = userId, DisplayName = name, Name = name,
		IsFriendsWithAsync = function() return true end,
		LoadCharacterAsync = function()
			fake.loads += 1
			makeCharacter(fake)
			signalFor(idOf(real), "CharacterAdded"):Fire(fake.character)
		end,
	}
	makeCharacter(fake)
	byUserId[userId] = fake.player
	table.insert(playerList, fake.player)
	Players.PlayerAdded:Fire(fake.player)
	tick(0)
	return fake
end

local jorge = makePlayer("Jorge", 42)


local function lastState(userId)
	for i = #fired, 1, -1 do
		if fired[i][1] == "State" and fired[i][2] == (userId or 42) then return fired[i][3] end
	end
end
local function countFired(remote, kind, userId)
	local n = 0
	for _, f in fired do
		if f[1] == remote and (userId == nil or f[2] == userId) and (kind == nil or f[3] == kind or f[4] == kind) then n += 1 end
	end
	return n
end
local function act(fake, name, a, b)
	fakeTime += 0.15 -- el servidor limita a 10 acciones por segundo
	local ok, message = invoke(fake.player, name, a, b)
	tick(0) -- el bucle del servidor manda el estado a los demás
	print(string.format("  %-6s %-13s -> %s %s", fake.real.Name, name, tostring(ok), tostring(message or "")))
	return ok, message
end
local function moveTo(fake, x, z)
	pivotTo(unwrap(fake.character), roblox.CFrame.new(x, 3, z))
end
local function die(fake)
	fake.humanoid.Health = 0
	signalFor(idOf(unwrap(fake.humanoid)), "Died"):Fire()
end

---------------------------------------------------------------------
-- Modo bot (tools/harness/run_server.luau <src> bot): partidas completas
-- con un jugador que esquiva en círculos SIN trampas de vida, para medir
-- el equilibrio con el código real.
---------------------------------------------------------------------
if process.args[2] == "bot" then
	local function botRun(name, userId, mapIndex, classId, upgrades, minutes)
		local data = nil
		saved["player_" .. userId] = {
			gold = 0, unlockedMap = 3, classes = { guerrero = true, mago = true, picaro = true },
			selectedClass = classId, upgrades = upgrades, tutorialDone = true,
			inventory = { { id = 1, def = "espada_madera", rarity = "comun", up = 0 } }, equipped = { weapon = 1 },
		}
		local bot = makePlayer(name, userId)
		invoke(bot.player, "playSolo", mapIndex)
		local run
		for _, r in RunManager.debugRuns() do
			if r.byPlayer[bot.player] then run = r end
		end
		local member = run.byPlayer[bot.player]
		local angle = 0
		local radius = 50
		local deathAt = nil
		local maxEnemies = 0
		local steps = math.floor(minutes * 60 * 15)
		for i = 1, steps do
			if run.ended or not member.alive then
				deathAt = deathAt or run.time
				break
			end
			-- Corre en círculo a su velocidad real
			local speed = Config.WALK_SPEED * member.speedMult
			-- Cambia de sentido cada 15 s (como una persona que esquiva)
			local direction = if math.floor(run.time / 15) % 2 == 0 then 1 else -1
			angle += direction * speed / radius / 15
			-- Tras el jefe va al portal (andando, no teletransportado)
			local tx, tz = run.origin.X + math.cos(angle) * radius, run.origin.Z + math.sin(angle) * radius
			local px, pz = bot.root.Position.X, bot.root.Position.Z
			if run.portalEndsAt then
				local dx, dz = run.portalX - px, run.portalZ - pz
				local d = math.max(0.01, math.sqrt(dx * dx + dz * dz))
				local stepLength = math.min(d, speed / 15)
				tx, tz = px + dx / d * stepLength, pz + dz / d * stepLength
			end
			-- Se aparta de los enemigos cercanos (como haría una persona)
			local ax, az = tx - px, tz - pz
			local alen = math.max(0.01, math.sqrt(ax * ax + az * az))
			ax, az = ax / alen, az / alen
			if not run.portalEndsAt then
				local rx, rz = 0, 0
				for _, e in run.enemies do
					local dx, dz = px - e.x, pz - e.z
					local d2 = dx * dx + dz * dz
					if d2 < 144 and d2 > 0.01 then
						local d = math.sqrt(d2)
						rx += dx / d * (12 - d) / 12
						rz += dz / d * (12 - d) / 12
					end
				end
				ax, az = ax + rx * 1.5, az + rz * 1.5
				alen = math.max(0.01, math.sqrt(ax * ax + az * az))
				local stepLength = speed / 15
				tx, tz = px + ax / alen * stepLength, pz + az / alen * stepLength
				local half = Config.ARENA_HALF - 5
				tx = math.clamp(tx, run.origin.X - half, run.origin.X + half)
				tz = math.clamp(tz, run.origin.Z - half, run.origin.Z + half)
			end
			-- Como en Roblox: el personaje mira hacia donde anda
			local mx, mz = tx - px, tz - pz
			local yaw = if mx * mx + mz * mz > 0.0001 then math.atan2(-mx, -mz) else 0
			pivotTo(unwrap(bot.character), roblox.CFrame.new(tx, 3, tz) * roblox.CFrame.Angles(0, yaw, 0))
			fakeTime += 1 / 15
			heartbeat:Fire(1 / 15)
			if bot.humanoid.Health <= 0 and member.alive then
				deathAt = run.time
				die(bot) -- en Roblox el Humanoid avisa con Died
			end
			maxEnemies = math.max(maxEnemies, #run.enemies)
			if process.args[3] == "debug" and i % 75 == 0 then
				local best = math.huge
				for _, e in run.enemies do
					best = math.min(best, math.sqrt((e.x - member.x) ^ 2 + (e.z - member.z) ^ 2))
				end
				print(string.format("    t=%5.1f enemigos %3d · más cercano %.1f · jugador (%.0f,%.0f) · vida %.0f", run.time, #run.enemies, best, member.x - run.origin.X, member.z - run.origin.Z, bot.humanoid.Health))
			end
			if member.offer then
				-- Elige: evolución > subir arma > arma nueva > pasiva
				local best, score = 1, -1
				for k, o in member.offer do
					local value = if o.kind == "evolve" then 4 elseif o.kind == "weapon" and o.level > 1 then 3 elseif o.kind == "weapon" then 2.5 elseif o.kind == "passive" then 2 else 0
					if value > score then best, score = k, value end
				end
				RunManager.choose(bot.player, best)
			end
			if i % 30 == 0 then tick(0) end
			if member.finished then break end
		end
		tick(0)
		local result = if deathAt then "CAE" elseif member.finished then "ESCAPA" else "vivo"
		local weapons = {}
		for _, id in member.weaponOrder do table.insert(weapons, id .. member.weapons[id]) end
		print(string.format("  %-9s mapa %d %-8s %-7s t=%s nivel %2d · muertes %4d · oro %5d · máx enemigos %3d · vida %d/%d · %s",
			name, mapIndex, classId, result, Config.formatClock(deathAt or run.time), run.level, member.kills, math.floor(member.gold), maxEnemies,
			math.floor(bot.humanoid.Health), math.floor(member.maxHealth), table.concat(weapons, " ")))
		if not member.finished then
			RunManager.leave(bot.player)
		end
		Players.PlayerRemoving:Fire(bot.player)
		tick(0)
	end
	print("-- Bot de equilibrio (esquiva en círculos, sin trampas) --")
	botRun("Novato", 101, 1, "guerrero", {}, if process.args[3] == "debug" then 0.6 else 9.5)
	if process.args[3] == "debug" then process.exit(0) end
	botRun("Novato2", 102, 1, "mago", {}, 9.5)
	botRun("Medio", 103, 1, "guerrero", { fuerza = 4, vida = 4, regen = 3 }, 9.5)
	botRun("Medio2", 104, 2, "guerrero", { fuerza = 5, vida = 5, regen = 4, velocidad = 3 }, 10.5)
	botRun("Fuerte", 105, 3, "mago", { fuerza = 9, vida = 9, regen = 7, velocidad = 6, recarga = 6 }, 11.5)
	process.exit(0)
end

local s = lastState()
assert(s and s.gold == 0 and s.selectedClass == "guerrero" and s.unlockedMap == 1 and s.run == nil, "estado inicial")
print(string.format("Estado inicial: oro %d · clase %s · vida %d · mochila %d/%d", s.gold, s.selectedClass, jorge.humanoid.MaxHealth, #s.inventory, s.capacity))
assert(jorge.humanoid.MaxHealth == Config.BASE_HEALTH + 30, "el guerrero debería tener +30 de vida")
assert(unwrap(jorge.character):FindFirstChild("ArmaEquipada"), "no lleva el arma en la mano")
assert(s.bonuses.choicePass == true, "el pase de 4 opciones debería estar activo")

-- Portal del lobby: abre la pestaña Jugar
for _, p in prompts do
	if p.ObjectText == "Bosque Encantado" then
		signalFor(idOf(p), "Triggered"):Fire(jorge.player)
	end
end
assert(countFired("OpenMenu", "jugar") > 0, "el portal no abre la pestaña Jugar")

---------------------------------------------------------------------
-- Partida solo en el Bosque
---------------------------------------------------------------------
print("-- Partida solo --")
act(jorge, "playSolo", 3) -- bloqueado
act(jorge, "playSolo", 99)
act(jorge, "playSolo", 1)
s = lastState()
assert(s.run and s.run.map == "bosque", "no empezó la partida")
local runs = RunManager.debugRuns()
local run
for _, r in runs do run = r end
assert(workspace:FindFirstChild("Mundo"):FindFirstChild("Arena_1"), "no se construyó la arena")
local arenaParts = 0
for _, d in workspace:FindFirstChild("Mundo"):FindFirstChild("Arena_1"):GetDescendants() do
	if d:IsA("BasePart") then arenaParts += 1 end
end
print(string.format("  arena: %d piezas · centro x=%d · jugador en x=%.0f", arenaParts, run.origin.X, jorge.root.Position.X))
assert(math.abs(jorge.root.Position.X - run.origin.X) < 10, "el jugador no está en la arena")
act(jorge, "playSolo", 1) -- ya está en partida
act(jorge, "buyUpgrade", "fuerza") -- sin oro: falla

-- Correr en círculos (como un jugador que esquiva) con la vida rellenada
local angle = 0
local choices = 0
local function play(seconds, keepAlive)
	local steps = math.floor(seconds * 15)
	for i = 1, steps do
		angle += 0.02
		if run.ended then break end
		local m = run.byPlayer[jorge.player]
		if m and m.alive then
			moveTo(jorge, run.origin.X + math.cos(angle) * 30, run.origin.Z + math.sin(angle) * 30)
			if keepAlive then jorge.humanoid.Health = jorge.humanoid.MaxHealth end
		end
		fakeTime += 1 / 15
		heartbeat:Fire(1 / 15)
		if i % 4 == 0 then
			tick(0)
			local st = lastState()
			if st.run and st.run.offer then
				fakeTime += 0.15
				invoke(jorge.player, "choose", 1)
				choices += 1
			end
		end
	end
	tick(0)
end
play(5, true)
assert(#run.enemies > 0, "no aparecen enemigos")
print(string.format("  a los 5 s: %d enemigos · %d fotos de la horda enviadas", #run.enemies, swarmCount))
assert(swarmCount > 0, "no se envían las posiciones")
local snap = lastSwarm[42]
local count = buffer.readu16(snap[1], 0)
assert(count > 0 and math.abs(count - #run.enemies) <= 2, "la foto no lleva a los enemigos")
-- Esquivar y cambiar mejora
signalFor(idOf(swarmRemote), "OnServerEvent"):Fire(jorge.player, "dash")
assert(run.byPlayer[jorge.player].invulnerableUntil > fakeTime, "esquivar no da invulnerabilidad")
play(55, true)
s = lastState()
print(string.format("  al minuto: nivel %d · %d enemigos vivos · %d muertos · oro %d · mejoras elegidas %d", s.run.level, #run.enemies, s.run.kills, s.run.gold, choices))
assert(s.run.kills > 20, "las armas no matan")
assert(s.run.level >= 3 and choices >= 2, "no sube de nivel o no se eligen mejoras")
local m = run.byPlayer[jorge.player]
print("  armas:", table.concat(m.weaponOrder, ", "), "· pasivas:", table.concat(m.passiveOrder, ", "))
-- Reroll: forzar una oferta
m.pendingChoices += 1
play(0.3, true)
if lastState().run.offer then
	act(jorge, "reroll")
	act(jorge, "reroll") -- 1 cambio gratis: el segundo falla
	act(jorge, "choose", 9) -- no existe
	act(jorge, "choose", 1)
end

-- Todas las armas al máximo para probar cada tipo y llegar rápido al jefe
m.weapons = { espada = 6, varita = 6, dagas = 6, rayo = 6 }
m.weaponOrder = { "espada", "varita", "dagas", "rayo" }
m.passives = { fuerza = 5, rapidez = 5, area = 3, vida = 2 }
m.passiveOrder = { "fuerza", "rapidez", "area", "vida" }
local killsBefore = run.kills
play(20, true)
print(string.format("  con armas evolucionadas: +%d muertes en 20 s · %d cristales en el suelo", run.kills - killsBefore, run.gemCount))
-- Aura y orbes también
m.weapons = { aura = 6, orbes = 6, espada = 3, varita = 2 }
m.weaponOrder = { "aura", "orbes", "espada", "varita" }
killsBefore = run.kills
play(15, true)
print(string.format("  aura + orbes: +%d muertes en 15 s", run.kills - killsBefore))
assert(run.kills > killsBefore, "aura u orbes no hacen daño")

-- Élites (cofre) y jefe
run.time = run.map.bossAt - 1
m.weapons = { espada = 6, varita = 6, dagas = 6, rayo = 6 }
m.weaponOrder = { "espada", "varita", "dagas", "rayo" }
play(1.5, true)
assert(run.bossSpawned and run.boss, "no aparece el jefe")
print(string.format("  jefe: %s con %d de vida", run.boss.type, run.boss.hp))
local elites = 0
for _, e in run.enemies do if e.elite then elites += 1 end end
print("  élites vivos:", elites, "· cofres en el suelo:", (function() local n = 0 for _, g in run.gems do if g.kind == 3 then n += 1 end end return n end)())
-- Esperar al golpe de área (acercarse al jefe; aguanta mientras tanto)
local bossHp = run.boss.hp
run.boss.hp, run.boss.maxHp = 1e7, 1e7
local sawWarning = false
for _ = 1, 120 do
	moveTo(jorge, run.boss.x + 6, run.boss.z)
	jorge.humanoid.Health = jorge.humanoid.MaxHealth
	fakeTime += 1 / 15
	heartbeat:Fire(1 / 15)
	if run.boss and run.boss.slamAt then sawWarning = true end
	if run.boss == nil then break end
end
tick(0)
assert(sawWarning, "el jefe no avisa de su golpe de área")
run.boss.hp, run.boss.maxHp = bossHp, bossHp
-- Rematarlo
local guard = 0
while run.boss and guard < 3000 do
	guard += 1
	moveTo(jorge, run.boss.x + 6, run.boss.z)
	jorge.humanoid.Health = jorge.humanoid.MaxHealth
	fakeTime += 1 / 15
	heartbeat:Fire(1 / 15)
	if guard % 4 == 0 then
		tick(0)
		local st = lastState()
		if st.run and st.run.offer then fakeTime += 0.15 invoke(jorge.player, "choose", 1) end
	end
end
tick(0)
assert(run.bossDead and run.portalEndsAt, "el jefe no muere o no aparece el portal")
s = lastState()
assert(s.run.portal, "el portal no está en el estado")
print(string.format("  jefe derrotado en %.0f s de juego · portal en (%.0f, %.0f)", guard / 15, s.run.portal.x, s.run.portal.z))
local runGold = math.floor(m.gold)
moveTo(jorge, run.portalX, run.portalZ)
fakeTime += 1 / 15
heartbeat:Fire(1 / 15)
tick(0)
s = lastState()
assert(s.run == nil, "no salió de la partida al entrar en el portal")
assert(run.ended and workspace:FindFirstChild("Mundo"):FindFirstChild("Arena_1"), "la partida no terminó o la arena no se guardó para reutilizarla")
assert(math.abs(jorge.root.Position.X) < 50, "no volvió al lobby")
local summary
for _, f in fired do if f[1] == "Notify" and f[4] == "summary" then summary = f[5] end end
assert(summary and summary.result == "win" and summary.item and summary.unlocked == "cueva", "resumen de victoria incorrecto")
print(string.format("  ¡VICTORIA! oro de la partida %d → cobrado %d · objeto %s (%s) · desbloqueado %s", runGold, summary.gold, summary.item.def, summary.item.rarity, summary.unlocked))
assert(summary.gold == math.floor(runGold * (1 + Config.WIN_BONUS)), "el bonus de victoria no cuadra")
assert(s.unlockedMap == 2 and s.gold >= summary.gold and s.mapWins.bosque == 1, "no se guardó la victoria")
assert(jorge.humanoid.MaxHealth == lastState().stats.health, "al volver al lobby no recupera su vida normal")

---------------------------------------------------------------------
-- Lobby: mejoras permanentes, clases, mochila y forja
---------------------------------------------------------------------
print("-- Lobby --")
local dmgBefore = lastState().stats.damage
act(jorge, "buyUpgrade", "fuerza")
act(jorge, "buyUpgrade", "noexiste")
assert(lastState().stats.damage > dmgBefore, "la mejora de fuerza no sube el daño")
act(jorge, "buyClass", "picaro") -- caro
act(jorge, "buyClass", "mago")
s = lastState()
if s.classes.mago then
	assert(s.selectedClass == "mago", "no se eligió el mago")
end
act(jorge, "buyClass", "guerrero") -- ya la tiene: la elige
act(jorge, "buyChest", 1)
act(jorge, "buyChest", 3) -- bloqueado
s = lastState()
local candidate
for _, item in s.inventory do
	if item.id ~= s.equipped[Config.Items[item.def].slot] then candidate = item end
end
if candidate then
	act(jorge, "equip", candidate.id)
	act(jorge, "sell", candidate.id) -- equipado: falla
end
act(jorge, "upgrade", lastState().equipped.weapon)
act(jorge, "sellJunk", 1)
act(jorge, "sellJunk", 9)
act(jorge, "setAutoSell", true)
act(jorge, "claimDaily")
act(jorge, "claimDaily")
act(jorge, "finishTutorial")
act(jorge, "finishTutorial")
act(jorge, "setMuted", true)
act(jorge, "saveNow")
act(jorge, "saveNow")
act(jorge, "bogus")
s = lastState()
assert(s.settings.muted and s.settings.autoSell and s.tutorialDone, "ajustes no guardados en el estado")

---------------------------------------------------------------------
-- Partida en grupo (2 jugadores)
---------------------------------------------------------------------
print("-- Grupo --")
local ana = makePlayer("Ana", 77)
act(ana, "createGroup", 2) -- Ana no tiene la Cueva
act(jorge, "createGroup", 2)
s = lastState(77)
assert(#s.groups == 1 and s.groups[1].leader == "Jorge", "Ana no ve el grupo de Jorge")
act(ana, "joinGroup", s.groups[1].id)
act(ana, "startGroup") -- no es líder
act(jorge, "startGroup") -- Ana no tiene el mapa
act(jorge, "leaveGroup")
act(ana, "leaveGroup")
act(jorge, "createGroup", 1)
act(ana, "joinGroup", lastState(77).groups[1].id)
act(jorge, "startGroup")
s = lastState()
local s2 = lastState(77)
assert(s.run and s2.run and #s.run.team == 2, "la partida en grupo no empezó para los dos")
for _, r in RunManager.debugRuns() do run = r end
print(string.format("  grupo en la arena %d · vida enemigos x%.1f", run.slot, 1 + 0.5))
local anaMember = run.byPlayer[ana.player]
play(10, true)
-- Ana cae y revive con el producto
die(ana)
tick(0)
assert(lastState(77).run.alive == false, "Ana debería estar caída")
print("  receipt revivir  ->", processReceipt({ PlayerId = 77, ProductId = 333, PurchaseId = "r1" }))
tick(0)
tick(0)
assert(anaMember.alive and ana.loads == 1, "Ana no revivió")
assert(math.abs(ana.root.Position.X - run.origin.X) < 150, "Ana no volvió a la arena")
-- Jorge abandona: cobra la mitad
local gold0 = lastState().gold
local jorgeRunGold = math.floor(run.byPlayer[jorge.player].gold)
act(jorge, "leaveRun")
assert(lastState().run == nil, "Jorge sigue en la partida")
print(string.format("  Jorge abandona: oro de partida %d → cobra %d", jorgeRunGold, lastState().gold - gold0))
-- Ana cae y no revive: tras la ventana sale de la partida
die(ana)
fakeTime += RunManager.REVIVE_WINDOW + 1
heartbeat:Fire(1 / 15)
tick(0)
assert(lastState(77).run == nil and run.ended, "la partida no terminó al caer el último jugador")
print("  Ana cae sin revivir: partida terminada (la arena se reutiliza)")

---------------------------------------------------------------------
-- Compras con Robux
---------------------------------------------------------------------
print("-- Compras --")
local g0 = lastState().gold
print("  receipt oro       ->", processReceipt({ PlayerId = 42, ProductId = 111, PurchaseId = "p1" }))
local g1 = lastState().gold
print("  receipt repetido  ->", processReceipt({ PlayerId = 42, ProductId = 111, PurchaseId = "p1" }))
assert(g1 > g0 and lastState().gold == g1, "la compra repetida no debe pagar dos veces")
print("  receipt boost     ->", processReceipt({ PlayerId = 42, ProductId = 222, PurchaseId = "p2" }))
assert(lastState().bonuses.boost, "boost no activo")
print("  receipt revivir (sin partida) ->", processReceipt({ PlayerId = 42, ProductId = 333, PurchaseId = "p3" }))
print("  receipt desconocido ->", processReceipt({ PlayerId = 42, ProductId = 999, PurchaseId = "p4" }))
act(jorge, "buyClass", "picaro")

---------------------------------------------------------------------
-- Salir a mitad de partida, cerrar y volver
---------------------------------------------------------------------
print("-- Salir y volver --")
act(jorge, "playSolo", 2)
for _, r in RunManager.debugRuns() do run = r end
play(10, true)
local inRunGold = math.floor(run.byPlayer[jorge.player].gold)
local goldBefore = lastState().gold
do
	-- (JSON no admite Vector3: el cliente de prueba lo reconstruye)
	local copy = table.clone(lastState())
	copy.run = table.clone(copy.run)
	local o = copy.run.origin
	copy.run.origin = { o.X, o.Y, o.Z }
	fs.writeFile("state_run.json", serde.encode("json", copy))
end
Players.PlayerRemoving:Fire(jorge.player)
assert(saved["player_42"], "no se guardó")
assert(saved["player_42"].gold == goldBefore + math.floor(inRunGold * Config.LOSS_GOLD_RATE), "al salir del juego no cobra la mitad del oro de la partida")
print(string.format("Guardado OK · oro %d (incluye la mitad de %d) · objetos %d · victorias %d", saved["player_42"].gold, inRunGold, #saved["player_42"].inventory, saved["player_42"].stats.wins))
Players.PlayerRemoving:Fire(ana.player)
for _, fn in closeHandlers do task.spawn(fn) end
tick(0)
print("Cierre del servidor OK")

saved["player_42"].equipped.amulet = 424242 -- objeto que ya no existe: debe limpiarse
saved["player_42"].selectedClass = "noexiste"
fakeTime += 60
table.clear(playerList)
table.insert(playerList, jorge.player)
Players.PlayerAdded:Fire(jorge.player)
tick(0)
s = lastState()
assert(s.equipped.amulet == nil and s.selectedClass == "guerrero" and s.unlockedMap == 2, "la partida no se cargó bien")
print(string.format("Reentrada: oro %d · mapas %d · clases %s", s.gold, s.unlockedMap, serde.encode("json", s.classes)))
for _ = 1, 3 do tick(0) end

fs.writeFile("state.json", serde.encode("json", lastState()))
print("TODO OK")
process.exit(0)
