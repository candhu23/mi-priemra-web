-- Ejecuta GameClient REAL: crea toda la interfaz con instancias de Lune
-- (valida propiedades), le pasa el estado real del servidor, simula los
-- eventos de combate, abre todas las pestañas, pulsa TODOS los botones,
-- las teclas de habilidades y recorre el tutorial.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SRC = process.args[1]
local configSource = fs.readFile(SRC .. "/ReplicatedStorage/GameConfig.luau")
local clientSource = fs.readFile(SRC .. "/StarterPlayerScripts/GameClient.client.luau")
local stateJson = serde.decode("json", fs.readFile("state.json"))

local realOf = setmetatable({}, { __mode = "k" })
local proxyById = {}
local overrides = setmetatable({}, { __mode = "k" })
local signals = {}
local invoked = {}
local firedToServer = {}
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
configModule.Name = "GameConfig"
configModule.Parent = services.ReplicatedStorage
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
local combatRemote = remote("RemoteEvent", "Combat")
local openRemote = remote("RemoteEvent", "OpenMenu")

-- Personaje del jugador
local character = roblox.Instance.new("Model")
character.Name = "Jorge"
local hrp = roblox.Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.CFrame = roblox.CFrame.new(0, 3, -1000)
hrp.Parent = character
local humanoid = roblox.Instance.new("Humanoid")
humanoid.MaxHealth = 250
humanoid.Health = 180
humanoid.Parent = character
character.Parent = services.Workspace

-- Un enemigo cerca (para el auto-ataque)
local enemies = roblox.Instance.new("Folder")
enemies.Name = "Enemigos"
enemies.Parent = services.Workspace
local enemy = roblox.Instance.new("Model")
local enemyRoot = roblox.Instance.new("Part")
enemyRoot.CFrame = roblox.CFrame.new(3, 0, -1002)
enemyRoot.Parent = enemy
enemy.PrimaryPart = enemyRoot
enemy.Parent = enemies

local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
local playerFolder = roblox.Instance.new("Folder")
playerFolder.Name = "Jorge"
playerGui.Parent = playerFolder
local player = wrap(playerFolder)
overrides[player] = { UserId = 42, Character = wrap(character) }

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
	Players = { LocalPlayer = player },
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

local function env()
	local e = {
		game = game,
		script = nil,
		Instance = { new = function(className) return wrap(roblox.Instance.new(className)) end },
		task = task,
		Enum = roblox.Enum,
		TweenInfo = { new = function() return {} end },
		os = { clock = function() return fakeClock end, time = os.time },
		Random = { new = function() return { NextNumber = function(_, a, b) a, b = a or 0, b or 1 return a + math.random() * (b - a) end } end },
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

local Config = luau.load(configSource, { debugName = "GameConfig", environment = env() })()
-- IDs de prueba para que aparezcan los artículos de la tienda y el botón de revivir
for _, pass in Config.Monetization.GamePasses do pass.id = 1000 + #pass.key end
for _, product in Config.Monetization.Products do product.id = 2000 + #product.key end
local clientEnv = env()
clientEnv.require = function()
	return Config
end
luau.load(clientSource, { debugName = "GameClient", environment = clientEnv })()

local function countGui()
	local n = 0
	for _ in playerGui:GetDescendants() do n += 1 end
	return n
end
print("Interfaz creada · objetos:", countGui())

local function fireState(s)
	signalFor(idOf(stateRemote), "OnClientEvent"):Fire(s)
	fakeClock += 0.2
	renderStepped:Fire(0.016)
end
local function combat(...)
	signalFor(idOf(combatRemote), "OnClientEvent"):Fire(...)
end

-- Estado real del servidor (primera vez: arranca el tutorial)
stateJson.tutorialDone = false
fireState(stateJson)
local tutorialGui = playerGui:FindFirstChild("DungeonTutorial")
assert(tutorialGui and tutorialGui.Enabled, "el tutorial no arrancó")

-- Variante: diaria disponible, boost, auto-ataque y sin guardado
local s2 = serde.decode("json", serde.encode("json", stateJson))
s2.dailyAvailable = true
s2.dailyDay = 7
s2.boostLeft = 300
s2.bonuses.autoPass = true
s2.bonuses.goldPass = true
s2.canSave = false
s2.unlockedZone = 2
s2.gold = 1e6
table.insert(s2.inventory, { id = 900, def = "guadana_sombria", rarity = "legendario", up = 3 })
table.insert(s2.inventory, { id = 901, def = "amuleto_almas", rarity = "epico", up = 10 })
s2.equipped.amulet = 901
fireState(s2)

-- Avisos, ventanas emergentes y menú abierto desde un cartel del mundo
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Hola", "loot")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Título", "popup", "Cuerpo")
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("Otro", "popup", "En cola")
signalFor(idOf(openRemote), "OnClientEvent"):Fire("forja")

-- Eventos de combate
local pos = roblox.Vector3.new(0, 4, -1005)
combat("hits", { { p = pos, d = 25, c = false }, { p = pos, d = 80, c = true } })
combat("hurt", 12)
combat("reward", pos, 30, 12)
combat("loot", { id = 902, def = "espada_hierro", rarity = "raro", up = 0 }, true)
combat("loot", { id = 903, def = "cota_cuero", rarity = "legendario", up = 0 }, false)
combat("levelup", 8)
for _, kind in { "attack", "spin", "dash", "heal", "levelup", "slam", "death" } do
	local extra = if kind == "slam" then 14 elseif kind == "death" then roblox.Color3.fromRGB(74, 222, 128) else roblox.Vector3.new(0, 0, -1)
	combat("fx", kind, pos, extra, 7)
end
combat("fx", "attack", pos, roblox.Vector3.new(0, 0, -1), 42) -- propio: se ignora
combat("died", "bosque", 4)
assert(playerGui:FindFirstChild("DungeonDeath").Enabled == false, "la cuenta atrás debería terminar")
combat("died", "bosque", 4)

-- Pulsar todos los botones (varias pasadas, porque abrir pestañas crea filas)
local pressed = 0
for _ = 1, 3 do
	for _, d in playerGui:GetDescendants() do
		-- (las fichas de la mochila se recrean al pulsarlas: saltamos las destruidas)
		local alive, id = pcall(idOf, d)
		if alive and d:IsA("TextButton") then
			signalFor(id, "Activated"):Fire()
			signalFor(id, "MouseEnter"):Fire()
			signalFor(id, "MouseLeave"):Fire()
			pressed += 1
		end
	end
	fireState(s2)
end
-- Abrir cada pestaña desde el menú lateral con el estado de prueba
for _, tab in { "mochila", "forja", "zonas", "tienda", "diario", "ajustes" } do
	signalFor(idOf(openRemote), "OnClientEvent"):Fire(tab)
	fireState(s2)
end

-- Mochila: elegir un objeto no equipado (la guadaña legendaria) y equiparlo
signalFor(idOf(openRemote), "OnClientEvent"):Fire("mochila")
fireState(s2)
local function findButton(predicate)
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and predicate(d) then
			return d
		end
	end
	return nil
end
local tile = findButton(function(b)
	for _, c in b:GetChildren() do
		if c:IsA("TextLabel") and c.Text == "Guadaña sombría" then
			return true
		end
	end
	return false
end)
assert(tile, "no aparece la guadaña en la mochila")
signalFor(idOf(tile), "Activated"):Fire()
local equipButton = findButton(function(b) return b.Text == "Equipar" end)
assert(equipButton and equipButton:GetAttribute("Enabled"), "el botón Equipar no se activa al elegir un objeto")
signalFor(idOf(equipButton), "Activated"):Fire()

-- Teclas y clic de ataque (con tiempo para que se recarguen)
for _, key in { roblox.Enum.KeyCode.Q, roblox.Enum.KeyCode.E, roblox.Enum.KeyCode.R, roblox.Enum.KeyCode.One, roblox.Enum.KeyCode.Z } do
	inputBegan:Fire({ KeyCode = key, UserInputType = roblox.Enum.UserInputType.Keyboard }, false)
end
fakeClock += 1
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.Unknown, UserInputType = roblox.Enum.UserInputType.MouseButton1 }, false)
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.Unknown, UserInputType = roblox.Enum.UserInputType.MouseButton1 }, true) -- sobre la interfaz: no ataca
-- Auto-ataque con el pase (hay un enemigo a 3,6 studs)
renderStepped:Fire(0.016)
local autoButton = findButton(function(b) return b.Text:find("AUTO") ~= nil end)
if autoButton.Text:find("NO") then
	signalFor(idOf(autoButton), "Activated"):Fire()
end
local attacksBefore = 0
for _, f in firedToServer do if f == "skill:attack" then attacksBefore += 1 end end
for _ = 1, 10 do
	fakeClock += 0.3
	renderStepped:Fire(0.016)
end

local attacksAfter = 0
for _, f in firedToServer do if f == "skill:attack" then attacksAfter += 1 end end
assert(attacksAfter >= attacksBefore + 3, "el auto-ataque no ataca")
print("Auto-ataque: " .. (attacksAfter - attacksBefore) .. " ataques en 3 s")

-- Ejecutar los task.delay pendientes (avisos que desaparecen, la embestida…)
for _, item in delayed do
	item[1](table.unpack(item[2], 1, item[2].n))
end

-- Recorrer el tutorial entero
for _ = 1, 10 do
	for _, d in tutorialGui:GetDescendants() do
		if d:IsA("TextButton") and (d.Text:find("Siguiente") or d.Text:find("A jugar")) then
			signalFor(idOf(d), "Activated"):Fire()
		end
	end
end
assert(not tutorialGui.Enabled, "el tutorial no se cerró")
-- El personaje nuevo cierra la pantalla de muerte
signalFor(idOf(playerFolder), "CharacterAdded"):Fire(wrap(character))
fireState(stateJson)

local counts = {}
for _, a in invoked do counts[a] = (counts[a] or 0) + 1 end
local list = {}
for a, n in counts do table.insert(list, a .. "×" .. n) end
table.sort(list)
local skillCounts = {}
for _, f in firedToServer do skillCounts[f] = (skillCounts[f] or 0) + 1 end
local skillList = {}
for f, n in skillCounts do table.insert(skillList, f .. "×" .. n) end
table.sort(skillList)
print("Botones pulsados:", pressed)
print("Acciones enviadas:", table.concat(list, ", "))
print("Habilidades enviadas:", table.concat(skillList, ", "))
print("Compras abiertas:", table.concat(prompts, ", "))
for _, needed in { "equip", "sell", "sellJunk", "upgrade", "buyChest", "teleport", "claimDaily", "setMuted", "setAutoSell", "saveNow", "finishTutorial" } do
	assert(counts[needed], "ningún botón envía la acción " .. needed)
end
for _, needed in { "skill:attack", "skill:spin", "skill:dash", "skill:heal" } do
	assert(skillCounts[needed], "no se envió " .. needed)
end
assert(#prompts > 0, "la tienda no abre compras")
print("Objetos de interfaz al final:", countGui())
print("CLIENTE OK")
process.exit(0)
