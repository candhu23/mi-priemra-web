-- Ejecuta GameClient + SwarmView REALES: crea toda la interfaz con instancias
-- de Lune (valida propiedades), le pasa los estados reales del servidor (lobby
-- y partida), le manda fotos de la horda con todos los tipos de enemigo,
-- cristales y efectos, pulsa TODOS los botones, las teclas y el tutorial.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SRC = process.args[1]
local configSource = fs.readFile(SRC .. "/ReplicatedStorage/GameConfig.luau")
local modelsSource = fs.readFile(SRC .. "/ReplicatedStorage/EnemyModels.luau")
local swarmSource = fs.readFile(SRC .. "/StarterPlayerScripts/SwarmView.luau")
local clientSource = fs.readFile(SRC .. "/StarterPlayerScripts/GameClient.client.luau")
local stateJson = serde.decode("json", fs.readFile("state.json"))
local runJson = serde.decode("json", fs.readFile("state_run.json"))

local realOf = setmetatable({}, { __mode = "k" })
local proxyById = {}
local overrides = setmetatable({}, { __mode = "k" })
local signals = {}
local invoked = {}
local firedToServer = {}
local bulkMoves = 0
local SIGNAL_NAMES = {
	Activated = true, MouseEnter = true, MouseLeave = true, OnClientEvent = true, Triggered = true,
	Changed = true, Completed = true, CharacterAdded = true, Died = true,
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
	if key == "Position" and inst:IsA("BasePart") then
		return inst.CFrame.Position
	end
	if key == "BulkMoveTo" then
		-- No existe en Lune: movemos pieza a pieza
		return function(_, parts, cframes)
			assert(#parts == #cframes, "BulkMoveTo: listas de distinto tamaño")
			for i, part in parts do
				unwrap(part).CFrame = cframes[i]
			end
			bulkMoves += #parts
		end
	end
	if key == "InvokeServer" then
		return function(_, action, a, b)
			table.insert(invoked, action)
			if action == "equip" then
				return true, "ok equip", { equip = true }
			elseif action == "upgrade" then
				return true, "ok upgrade", { forge = true }
			elseif action == "teleport" then
				return true, "ok teleport", nil
			end
			return true, "ok " .. action, { gold = true }
		end
	end
	if key == "FireServer" then
		return function(_, kind, a)
			table.insert(firedToServer, tostring(kind) .. ":" .. tostring(a))
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
	local o = overrides[p]
	if o and o[key] ~= nil then
		o[key] = value
		return
	end
	realOf[p][key] = unwrap(value)
	signalFor(idOf(realOf[p]), "changed:" .. key):Fire()
end

-- Servicios
local dataModel = roblox.Instance.new("DataModel")
local services = {}
for _, name in { "Workspace", "ReplicatedStorage", "SoundService" } do
	services[name] = dataModel:GetService(name)
end
local remotes = roblox.Instance.new("Folder")
remotes.Name = "DungeonRemotes"
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
local swarmRemote = remote("RemoteEvent", "Swarm")
local openRemote = remote("RemoteEvent", "OpenMenu")
for _, name in { "GameConfig", "EnemyModels" } do
	local m = roblox.Instance.new("ModuleScript")
	m.Name = name
	m.Parent = services.ReplicatedStorage
end
local playerScripts = roblox.Instance.new("Folder")
playerScripts.Name = "PlayerScripts"
local swarmModule = roblox.Instance.new("ModuleScript")
swarmModule.Name = "SwarmView"
swarmModule.Parent = playerScripts
local clientScript = roblox.Instance.new("LocalScript")
clientScript.Name = "GameClient"
clientScript.Parent = playerScripts

-- Personaje del jugador
local character = roblox.Instance.new("Model")
character.Name = "Jorge"
local hrp = roblox.Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.CFrame = roblox.CFrame.new(2000, 3, 0)
hrp.Parent = character
local humanoid = roblox.Instance.new("Humanoid")
humanoid.MaxHealth = 250
humanoid.Health = 180
humanoid.Parent = character
character.Parent = services.Workspace
overrides[wrap(humanoid)] = { MoveDirection = roblox.Vector3.new(1, 0, 0) }

local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
local playerFolder = roblox.Instance.new("Folder")
playerFolder.Name = "Jorge"
playerGui.Parent = playerFolder
local player = wrap(playerFolder)
overrides[player] = { UserId = 42, Character = wrap(character), CameraMinZoomDistance = 0.5, CameraMaxZoomDistance = 128 }

overrides[wrap(services.Workspace)] = {
	CurrentCamera = {
		ViewportSize = roblox.Vector2.new(1280, 720),
		GetPropertyChangedSignal = function() return newSignal() end,
	},
}
local renderStepped = newSignal()
local inputBegan = newSignal()
local prompts = {}
local mocks = {
	Players = { LocalPlayer = player, GetPlayerByUserId = function(_, id) return if id == 42 then player else nil end },
	RunService = { RenderStepped = renderStepped },
	TweenService = { Create = function(_, inst, _i, props) return { Play = function() for k, v in props do inst[k] = v end end, Completed = newSignal() } end },
	UserInputService = { InputBegan = inputBegan },
	StarterGui = { SetCoreGuiEnabled = function() end },
	MarketplaceService = {
		PromptGamePassPurchase = function(_, _p, id) table.insert(prompts, "pass:" .. id) end,
		PromptProductPurchase = function(_, _p, id) table.insert(prompts, "product:" .. id) end,
	},
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
local fakeClock = 0
local task = {
	spawn = function(fn, ...) fn(...) end,
	delay = function(_, fn, ...) table.insert(delayed, { fn, table.pack(...) }) end,
	wait = function() end,
}

local function env(scriptInstance)
	local e = {
		game = game,
		script = scriptInstance and wrap(scriptInstance),
		Instance = { new = function(className) return wrap(roblox.Instance.new(className)) end },
		task = task,
		Enum = roblox.Enum,
		TweenInfo = { new = function() return {} end },
		os = { clock = function() return fakeClock end, time = os.time },
		Random = { new = function() return { NextNumber = function(_, a, b) a, b = a or 0, b or 1 return a + math.random() * (b - a) end, NextInteger = function(_, a, b) return math.random(a, b) end } end },
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

local Config = luau.load(configSource, { debugName = "GameConfig", environment = env(nil) })()
-- IDs de prueba para que aparezcan los artículos de la tienda y el botón de revivir
for _, pass in Config.Monetization.GamePasses do pass.id = 1000 + #pass.key end
for _, product in Config.Monetization.Products do product.id = 2000 + #product.key end
local modulesByName = { GameConfig = Config }
local function requireByName(m)
	local name = realOf[m] and realOf[m].Name
	return assert(modulesByName[name], "módulo no cargado: " .. tostring(name))
end
local modelsEnv = env(nil)
modelsEnv.require = requireByName
modulesByName.EnemyModels = luau.load(modelsSource, { debugName = "EnemyModels", environment = modelsEnv })()
local swarmEnv = env(swarmModule)
swarmEnv.require = requireByName
modulesByName.SwarmView = luau.load(swarmSource, { debugName = "SwarmView", environment = swarmEnv })()
local clientEnv = env(clientScript)
clientEnv.require = requireByName
luau.load(clientSource, { debugName = "GameClient", environment = clientEnv })()
local SwarmView = modulesByName.SwarmView

local function countGui()
	local n = 0
	for _ in playerGui:GetDescendants() do n += 1 end
	return n
end
print("Interfaz creada · objetos:", countGui())

local function fireState(s)
	signalFor(idOf(stateRemote), "OnClientEvent"):Fire(s)
	fakeClock += 0.05
	renderStepped:Fire(0.016)
end
local function findButton(predicate)
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and predicate(d) then
			return d
		end
	end
	return nil
end
local function press(button)
	signalFor(idOf(button), "Activated"):Fire()
end
local function pressAll(s, passes)
	local pressed = 0
	for _ = 1, passes do
		for _, d in playerGui:GetDescendants() do
			-- (algunas filas se recrean al pulsar: saltamos las destruidas)
			local alive, id = pcall(idOf, d)
			if alive and d:IsA("TextButton") then
				signalFor(id, "Activated"):Fire()
				signalFor(id, "MouseEnter"):Fire()
				signalFor(id, "MouseLeave"):Fire()
				pressed += 1
			end
		end
		fireState(s)
	end
	return pressed
end

---------------------------------------------------------------------
-- Lobby
---------------------------------------------------------------------
stateJson.tutorialDone = false
fireState(stateJson)
local tutorialGui = playerGui:FindFirstChild("DungeonTutorial")
assert(tutorialGui and tutorialGui.Enabled, "el tutorial no arrancó")

local lobby = serde.decode("json", serde.encode("json", stateJson))
lobby.dailyAvailable = true
lobby.dailyDay = 7
lobby.boostLeft = 300
lobby.canSave = false
lobby.unlockedMap = 3
lobby.gold = 1e6
lobby.bonuses.goldPass = true
lobby.groups = { { id = 5, leader = "Ana", map = 2, members = { "Ana", "Luis" } }, { id = 6, leader = "Jorge", map = 1, members = { "Jorge" } } }
lobby.myGroup = { id = 6, leader = true, map = 1 }
lobby.classes = { guerrero = true, mago = true }
table.insert(lobby.inventory, { id = 900, def = "guadana_sombria", rarity = "legendario", up = 3 })
table.insert(lobby.inventory, { id = 901, def = "amuleto_almas", rarity = "epico", up = 10 })
lobby.equipped.amulet = 901
fireState(lobby)

-- Avisos, ventanas emergentes y menú abierto desde un portal
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Hola", "loot")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Título", "popup", "Cuerpo")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("", "loot_item", { item = { id = 902, def = "espada_hierro", rarity = "raro", up = 0 }, better = true })
signalFor(idOf(openRemote), "OnClientEvent"):Fire("jugar", "cueva")
signalFor(idOf(openRemote), "OnClientEvent"):Fire("forja", nil)

local pressed = pressAll(lobby, 2)
for _, tab in { "jugar", "clases", "mejoras", "mochila", "forja", "tienda", "diario", "ajustes" } do
	signalFor(idOf(openRemote), "OnClientEvent"):Fire(tab, nil)
	fireState(lobby)
	pressed += pressAll(lobby, 1)
end
-- Sin grupo: botones de jugar solo y crear grupo
lobby.myGroup = nil
signalFor(idOf(openRemote), "OnClientEvent"):Fire("jugar", nil)
fireState(lobby)
press(findButton(function(b) return b.Text == "▶ Jugar solo" end))
press(findButton(function(b) return b.Text == "👥 Crear grupo" end))
press(findButton(function(b) return b.Text == "Unirse" end))
-- Mochila: elegir un objeto no equipado y equiparlo
signalFor(idOf(openRemote), "OnClientEvent"):Fire("mochila", nil)
fireState(lobby)
local tile = findButton(function(b)
	for _, c in b:GetChildren() do
		if c:IsA("TextLabel") and c.Text == "Guadaña sombría" then
			return true
		end
	end
	return false
end)
assert(tile, "no aparece la guadaña en la mochila")
press(tile)
local equipButton = findButton(function(b) return b.Text == "Equipar" end)
assert(equipButton and equipButton:GetAttribute("Enabled"), "el botón Equipar no se activa al elegir un objeto")
press(equipButton)

---------------------------------------------------------------------
-- Partida
---------------------------------------------------------------------
local o = runJson.run.origin
runJson.run.origin = roblox.Vector3.new(o[1], o[2], o[3])
local inRun = runJson
inRun.run.offer = { { kind = "weapon", id = "varita", level = 1 }, { kind = "evolve", id = "espada", level = 6 }, { kind = "passive", id = "fuerza", level = 2 }, { kind = "gold" } }
inRun.run.pending = 2
inRun.run.rerolls = 1
inRun.run.boss = { name = "Rey Goblin", hp = 0.6 }
inRun.run.portal = { x = 10, z = -20, left = 42 }
inRun.run.lives = 1
inRun.run.weapons = { espada = 6, aura = 3, orbes = 4 }
inRun.run.weaponOrder = { "espada", "aura", "orbes" }
inRun.run.passives = { fuerza = 2 }
inRun.run.passiveOrder = { "fuerza" }
inRun.run.team = { { userId = 42, name = "Jorge", alive = true, weapons = inRun.run.weapons, weaponOrder = inRun.run.weaponOrder } }
fireState(inRun)
local offerGui = playerGui:FindFirstChild("DungeonOffer")
assert(offerGui.Enabled, "no se muestran las cartas de mejora")
assert(overrides[player].CameraMinZoomDistance >= 30, "la cámara no se aleja en partida")

-- Foto de la horda: un enemigo de cada tipo, un élite y un jefe
local function snapshot(entries)
	local b = buffer.create(2 + #entries * 9)
	buffer.writeu16(b, 0, #entries)
	for i, e in entries do
		local off = 2 + (i - 1) * 9
		buffer.writeu16(b, off, e.id)
		buffer.writeu8(b, off + 2, e.type)
		buffer.writeu8(b, off + 3, e.hp)
		buffer.writeu8(b, off + 4, e.flags)
		buffer.writei16(b, off + 5, e.x * 4)
		buffer.writei16(b, off + 7, e.z * 4)
	end
	return b
end
local entries = {}
for i = 1, #Config.EnemyList do
	local def = Config.Enemies[Config.EnemyList[i]]
	table.insert(entries, { id = i, type = i, hp = 255, flags = if def.boss then 2 else 0, x = i * 3, z = 10 })
end
table.insert(entries, { id = 500, type = 1, hp = 255, flags = 1, x = -10, z = -10 })
local fxList = {
	{ "slash", 42, 0, 0, 0.5, 9, false, true },
	{ "slash", 7, 0, 0, 0.5, 9, true, true },
	{ "bolt", 0, 0, 10, 10, false },
	{ "dagger", 0, 0, 1, 0, 34 },
	{ "lightning", 5, 5, 4 },
	{ "slamwarn", 0, 0, 13, 1.3 },
	{ "slam", 0, 0, 13 },
	{ "death", 3, 3, 2 },
	{ "levelup", 0, 0 },
	{ "revive", 0, 0 },
	{ "evolve", 0, 0 },
	{ "portal", 10, -20 },
	{ "desconocido", 1 },
}
signalFor(idOf(swarmRemote), "OnClientEvent"):Fire(snapshot(entries), { 1, 1, 40, 40, 2, 2, -40, 0, 3, 3, 0, 80 }, {}, fxList)
for _ = 1, 5 do
	fakeClock += 0.02
	renderStepped:Fire(0.02)
end
local enemyCount, gemCount = SwarmView.debugCounts()
print(string.format("Horda dibujada: %d enemigos · %d cristales · %d piezas movidas con BulkMoveTo", enemyCount, gemCount, bulkMoves))
assert(enemyCount == #entries and gemCount == 3 and bulkMoves > 0, "la horda no se dibuja")
-- Segunda foto: se mueven, reciben daño, uno muere y se recogen cristales
for _, e in entries do
	e.x += 1
	e.hp = 128
end
table.remove(entries, 1)
signalFor(idOf(swarmRemote), "OnClientEvent"):Fire(snapshot(entries), {}, { 1, 42, 2, 99 }, {})
for _ = 1, 5 do
	fakeClock += 0.02
	renderStepped:Fire(0.02)
end
enemyCount, gemCount = SwarmView.debugCounts()
assert(enemyCount == #entries and gemCount == 1, "no se quitan enemigos o cristales")
local numbers = 0
for _, d in services.Workspace:FindFirstChild("HordaLocal"):GetDescendants() do
	if d:IsA("BillboardGui") and d.Parent and d.Parent.Name ~= "Root" then numbers += 1 end
end
print("Números de daño en pantalla:", numbers)
assert(numbers > 0, "no salen números de daño")

-- Cartas, cambio, esquivar y teclas
press(findButton(function(b) return b.Text:find("Cambiar") ~= nil end))
local cardButton = nil
for _, d in offerGui:GetDescendants() do
	if d:IsA("TextButton") and d.Text == "" then cardButton = d end
end
assert(cardButton, "no hay cartas")
press(cardButton)
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.Two, UserInputType = roblox.Enum.UserInputType.Keyboard }, false)
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.Q, UserInputType = roblox.Enum.UserInputType.Keyboard }, false)
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.LeftShift, UserInputType = roblox.Enum.UserInputType.Keyboard }, false) -- en recarga: no se envía
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.Q, UserInputType = roblox.Enum.UserInputType.Keyboard }, true) -- sobre la interfaz
humanoid.Health = 100 -- daño: destello rojo
renderStepped:Fire(0.016)
pressed += pressAll(inRun, 1)

-- Caído en partida: pantalla con revivir
inRun.run.offer = nil
inRun.run.alive = false
fireState(inRun)
assert(playerGui:FindFirstChild("DungeonDeath").Enabled, "no sale la pantalla al caer")
press(findButton(function(b) return b.Text:find("Revivir") ~= nil end))
press(findButton(function(b) return b.Text == "Volver al lobby" end))

-- Resumen final y vuelta al lobby
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("", "summary", { result = "win", map = "bosque", time = 512, kills = 1234, level = 22, gold = 2400, item = { id = 903, def = "cota_cuero", rarity = "epico", up = 0 }, unlocked = "cueva" })
assert(playerGui:FindFirstChild("DungeonSummary").Enabled, "no sale el resumen")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("", "summary", { result = "dead", map = "cueva", time = 100, kills = 12, level = 3, gold = 40 })
press(findButton(function(b) return b.Text == "Continuar" end))
fireState(lobby)
enemyCount, gemCount = SwarmView.debugCounts()
assert(enemyCount == 0 and gemCount == 0, "al volver al lobby queda la horda dibujada")
assert(overrides[player].CameraMinZoomDistance == 0.5, "la cámara no vuelve a la normalidad")

-- Ejecutar los task.delay pendientes (avisos que desaparecen, efectos…)
for _, item in delayed do
	item[1](table.unpack(item[2], 1, item[2].n))
end

-- Recorrer el tutorial entero
for _ = 1, 10 do
	for _, d in tutorialGui:GetDescendants() do
		if d:IsA("TextButton") and (d.Text:find("Siguiente") or d.Text:find("A jugar")) then
			press(d)
		end
	end
end
assert(not tutorialGui.Enabled, "el tutorial no se cerró")
fireState(stateJson)

local counts = {}
for _, a in invoked do counts[a] = (counts[a] or 0) + 1 end
local list = {}
for a, n in counts do table.insert(list, a .. "×" .. n) end
table.sort(list)
print("Botones pulsados:", pressed)
print("Acciones enviadas:", table.concat(list, ", "))
print("Al servidor por la partida:", table.concat(firedToServer, ", "))
print("Compras abiertas:", table.concat(prompts, ", "))
for _, needed in { "playSolo", "createGroup", "joinGroup", "leaveGroup", "startGroup", "buyClass", "buyUpgrade", "equip", "sell", "sellJunk", "upgrade", "buyChest", "claimDaily", "setMuted", "setAutoSell", "saveNow", "finishTutorial", "choose", "reroll", "leaveRun" } do
	assert(counts[needed], "ningún botón envía la acción " .. needed)
end
assert(table.find(firedToServer, "dash:nil"), "no se envía el esquive")
assert(#prompts > 0, "la tienda no abre compras")
print("Objetos de interfaz al final:", countGui())
print("CLIENTE OK")
process.exit(0)
