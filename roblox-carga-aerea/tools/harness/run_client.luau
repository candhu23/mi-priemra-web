-- Ejecuta GameClient real: crea toda la interfaz con instancias de Lune
-- (valida propiedades), le pasa el estado real del servidor (state.json),
-- abre todas las pantallas y pestañas y pulsa TODOS los botones.
-- Con un 2º argumento vuelca el árbol de la interfaz en JSON (para la vista previa).
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SRC = process.args[1]
local DUMP = process.args[2]
local configSource = fs.readFile(SRC .. "/ReplicatedStorage/Config.luau")
local langSource = fs.readFile(SRC .. "/ReplicatedStorage/Lang.luau")
local clientSource = fs.readFile(SRC .. "/StarterPlayerScripts/GameClient.client.luau")
local stateJson = serde.decode("json", fs.readFile("state.json"))

local realOf = setmetatable({}, { __mode = "k" })
local proxyById = {}
local overrides = setmetatable({}, { __mode = "k" })
local signals = {}
local invoked = {}
local SIGNAL_NAMES = {
	Activated = true, MouseEnter = true, MouseLeave = true, OnClientEvent = true, Triggered = true,
	Changed = true, Completed = true, CharacterAdded = true,
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
			if action == "hirePilot" then
				return true, "n_hired", { name = "Noa Tanaka" }, { pilot = { id = 99, name = "Noa Tanaka", rarity = "legendary", flights = 0 } }
			end
			if action == "sellPlane" then
				return false, "err_last_plane"
			end
			return true, "n_bought", { name = action }, { money = true }
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
for _, name in { "Workspace", "ReplicatedStorage" } do
	services[name] = dataModel:GetService(name)
end
for _, name in { "Config", "Lang" } do
	local m = roblox.Instance.new("ModuleScript")
	m.Name = name
	m.Parent = services.ReplicatedStorage
end
local remotes = roblox.Instance.new("Folder")
remotes.Name = "CargoRemotes"
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

local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
local playerFolder = roblox.Instance.new("Folder")
playerFolder.Name = "Jorge"
playerGui.Parent = playerFolder
local player = wrap(playerFolder)
overrides[player] = { UserId = 42 }

overrides[wrap(services.Workspace)] = {
	CurrentCamera = {
		ViewportSize = roblox.Vector2.new(1280, 720),
		GetPropertyChangedSignal = function() return newSignal() end,
	},
}
local renderStepped = newSignal()
local mocks = {
	Players = { LocalPlayer = player },
	RunService = { RenderStepped = renderStepped },
	TweenService = { Create = function(_, inst, _i, props) return { Play = function() for k, v in props do inst[k] = v end end, Completed = newSignal() } end },
	LocalizationService = { RobloxLocaleId = "es-es" },
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
local clock = 0
local function env()
	local e = {
		game = game,
		Instance = { new = function(className) return wrap(roblox.Instance.new(className)) end },
		task = task,
		Enum = roblox.Enum,
		TweenInfo = { new = function() return {} end },
		os = { time = os.time, clock = function() return clock end },
		typeof = function(v)
			if type(v) == "table" and realOf[v] then return "Instance" end
			return typeof(v)
		end,
	}
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "ColorSequence", "Font" } do
		e[name] = roblox[name]
	end
	return setmetatable(e, { __index = _G })
end

local Config = luau.load(configSource, { debugName = "Config", environment = env() })()
local Lang = luau.load(langSource, { debugName = "Lang", environment = env() })()
-- Vista previa: usa los PNG locales como si ya estuvieran subidos
if DUMP then
	local ASSETS = process.args[3]
	Config.Assets.icons = ASSETS .. "/iconos.png"
	Config.Assets.planes = ASSETS .. "/aviones.png"
	Config.Assets.mapWest = ASSETS .. "/mapa_oeste.png"
	Config.Assets.mapEast = ASSETS .. "/mapa_este.png"
end
local clientEnv = env()
clientEnv.require = function(m)
	if realOf[m] and realOf[m].Name == "Lang" then
		return Lang
	end
	return Config
end
luau.load(clientSource, { debugName = "GameClient", environment = clientEnv })()

local function countGui()
	local n = 0
	for _ in playerGui:GetDescendants() do n += 1 end
	return n
end
print("Interfaz creada · objetos:", countGui())

local stateJson = serde.decode("json", fs.readFile("state.json"))
stateJson.now = os.time()
local function fireState(s)
	signalFor(idOf(stateRemote), "OnClientEvent"):Fire(s)
	clock += 0.25
	renderStepped:Fire(0.25)
end
fireState(stateJson)

local function findButton(text)
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") then
			for _, k in d:GetDescendants() do
				if k:IsA("TextLabel") and k.Text == text then
					return d
				end
			end
			if d.Text == text then
				return d
			end
		end
	end
	return nil
end
local function press(btn)
	signalFor(idOf(btn), "Activated"):Fire()
end
local T = function(key, params) return Lang.t("es", key, params) end

-- Abrir cada pantalla y cada pestaña
local pages = { "nav_map", "nav_fleet", "nav_dispatch", "nav_pilots", "nav_company", "nav_settings" }
local tabsList = { "tab_my_planes", "tab_dealership", "tab_upgrades", "tab_roster", "tab_hire", "tab_overview", "tab_regions", "tab_licenses" }
for _, nav in pages do
	local b = assert(findButton(T(nav)), "falta el botón " .. nav)
	press(b)
	fireState(stateJson)
	for _, tab in tabsList do
		local tb = findButton(T(tab))
		if tb then
			local frame = tb
			local visible = true
			while frame and frame ~= playerGui do
				if frame:IsA("GuiObject") and not frame.Visible then visible = false end
				frame = frame.Parent
			end
			if visible then
				press(tb)
				fireState(stateJson)
			end
		end
	end
end
print("Pantallas y pestañas abiertas · objetos:", countGui())

-- Flujos con ventana de confirmación (el barrido general no los garantiza)
local function expect(action)
	assert(invoked[#invoked] == action, "se esperaba la acción " .. action .. " y llegó " .. tostring(invoked[#invoked]))
end
press(assert(findButton(T("nav_dispatch"))))
fireState(stateJson)
press(assert(findButton(T("btn_ferry")), "falta REPOSICIONAR"))
local arrow
for _, d in playerGui:GetDescendants() do
	if d:IsA("TextButton") and d.Text == "→" then arrow = d break end
end
press(assert(arrow, "el menú de reposicionar no tiene destinos"))
expect("ferry")
press(assert(findButton(T("nav_pilots"))))
press(assert(findButton(T("tab_roster"))))
fireState(stateJson)
press(assert(findButton(T("btn_fire")), "falta DESPEDIR"))
press(assert(findButton(T("btn_confirm")), "falta CONFIRMAR"))
expect("firePilot")
press(assert(findButton(T("nav_fleet"))))
press(assert(findButton(T("tab_my_planes"))))
fireState(stateJson)
press(assert(findButton(T("btn_sell")), "falta VENDER"))
press(assert(findButton(T("btn_confirm"))))
expect("sellPlane")
-- Estado sin nada comprado: mejoras, regiones y licencias disponibles
local fresh = serde.decode("json", serde.encode("json", stateJson))
fresh.money = 1e10
fresh.regions = { NA = true }
fresh.licenses = {}
fresh.upgrades = { hangar = 0, fuel = 0, broker = 0 }
for _, pair in { { "nav_fleet", "tab_upgrades", "buyUpgrade" }, { "nav_company", "tab_regions", "buyRegion" }, { "nav_company", "tab_licenses", "buyLicense" } } do
	press(assert(findButton(T(pair[1]))))
	press(assert(findButton(T(pair[2]))))
	fireState(fresh)
	local before = #invoked
	for _, d in playerGui:GetDescendants() do
		local ok, candidate = pcall(function()
			return d.Parent ~= nil and d:IsA("TextButton") and d:GetAttribute("Enabled") == true
				and string.find(d.Text, "$", 1, true) ~= nil
		end)
		if ok and candidate then
			press(d)
			if invoked[#invoked] == pair[3] then break end
		end
	end
	assert(#invoked > before and invoked[#invoked] == pair[3], "no se pudo " .. pair[3])
end
print("Flujos con confirmación y compras: OK")

-- Variantes de estado: sin aviones en tierra, sin pilotos, sin guardado, mucho dinero
local s2 = serde.decode("json", serde.encode("json", stateJson))
for _, p in s2.planes do
	p.flight = p.flight or { from = p.airport, to = "LHR", cargo = "general", weight = 1, dist = 5000, gross = 100, fuel = 10, fee = 0, pilot = 0, startT = s2.now - 10, endT = s2.now + 50, wear = 1 }
end
s2.pilots = {}
s2.canSave = false
s2.money = 1e10
s2.settings.auto = true
fireState(s2)

-- Avisos y ventanas
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("money", "n_landed", { to = "LHR", net = 12345 })
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("level", "n_level_up", { level = 7 })
signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("info", "n_region", { region = "EU" })
for _ = 1, 8 do
	signalFor(idOf(notifyRemote), "OnClientEvent"):Fire("error", "err_money", {})
end

local rich = serde.decode("json", serde.encode("json", stateJson))
rich.money = 1e10
-- Pulsar todos los botones: cada página y cada pestaña, en dos pasadas
local pressed = 0
local function sweep()
	-- Recorrido al derecho y al revés: pulsar un avión cambia el tablón y
	-- destruye los botones VOLAR que venían después en la lista
	local all = playerGui:GetDescendants()
	local ordered = {}
	for k = #all, 1, -1 do table.insert(ordered, all[k]) end
	for _, d in all do table.insert(ordered, d) end
	for _, d in ordered do
		-- Pulsar una pestaña destruye tarjetas de la lista: se saltan
		local ok, isButton = pcall(function()
			return d.Parent ~= nil and d:IsA("TextButton") and d.Text ~= "Español" and d.Text ~= "English" and d.Text ~= T("lang_auto")
		end)
		if ok and isButton then
			local id = idOf(d)
			signalFor(id, "MouseEnter"):Fire()
			signalFor(id, "MouseLeave"):Fire()
			signalFor(id, "Activated"):Fire()
			pressed += 1
		end
	end
end
local PAGE_TABS = {
	nav_map = { false }, nav_dispatch = { false }, nav_settings = { false },
	nav_fleet = { "tab_my_planes", "tab_dealership", "tab_upgrades" },
	nav_pilots = { "tab_roster", "tab_hire" },
	nav_company = { "tab_overview", "tab_regions", "tab_licenses" },
}
for pass = 1, 2 do
	local st = pass == 1 and rich or s2
	for _, nav in pages do
		for _, tab in PAGE_TABS[nav] do
			press(assert(findButton(T(nav))))
			if tab then
				press(assert(findButton(T(tab)), "falta la pestaña " .. tab))
			end
			fireState(st)
			sweep()
			fireState(st)
		end
	end
end
for _, item in delayed do
	item[1](table.unpack(item[2], 1, item[2].n))
end
-- Cambiar de idioma reconstruye toda la interfaz
press(assert(findButton(T("nav_settings"))))
press(assert(findButton("English"), "falta el botón English"))
fireState(stateJson)
assert(findButton(Lang.t("en", "nav_map")), "la interfaz no cambió a inglés")
press(assert(findButton("Español")))
fireState(stateJson)
assert(findButton(T("nav_map")), "la interfaz no volvió a español")

local counts = {}
for _, a in invoked do counts[a] = (counts[a] or 0) + 1 end
local list = {}
for a, n in counts do table.insert(list, a .. "×" .. n) end
table.sort(list)
print("Botones pulsados:", pressed)
print("Acciones enviadas:", table.concat(list, ", "))
print("Objetos de interfaz al final:", countGui())

-- Volcado de la interfaz para la vista previa (una página por llamada)
if DUMP then
	local PROPS = {
		"Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "ZIndex", "LayoutOrder",
		"Text", "TextSize", "TextColor3", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextTransparency", "TextStrokeTransparency",
		"Image", "ImageRectOffset", "ImageRectSize", "ImageColor3", "ImageTransparency", "ScaleType", "Rotation", "ClipsDescendants", "AutomaticSize",
		"CornerRadius", "Color", "Thickness", "Transparency", "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom",
		"FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment", "CellSize", "CellPadding", "AspectRatio", "Scale", "FontFace",
	}
	local function encode(v)
		local t = typeof(v)
		if t == "UDim2" then return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
		elseif t == "UDim" then return { v.Scale, v.Offset }
		elseif t == "Vector2" then return { v.X, v.Y }
		elseif t == "Color3" then return { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
		elseif t == "EnumItem" then return v.Name
		elseif t == "Font" then return { v.Family, v.Weight.Name }
		elseif t == "number" or t == "string" or t == "boolean" then return v
		end
		return nil
	end
	local function node(inst)
		local n = { class = inst.ClassName, name = inst.Name, children = {} }
		for _, p in PROPS do
			local ok, v = pcall(function() return inst[p] end)
			if ok and v ~= nil then n[p] = encode(v) end
		end
		for _, c in inst:GetChildren() do
			if not c:IsA("Sound") then table.insert(n.children, node(c)) end
		end
		return n
	end
	local outDir = DUMP
	for _, nav in pages do
		press(assert(findButton(T(nav))))
		fireState(stateJson)
		local guis = {}
		for _, g in playerGui:GetChildren() do table.insert(guis, node(g)) end
		fs.writeFile(outDir .. "/" .. nav .. ".json", serde.encode("json", guis))
	end
	-- Extra: pestañas de contratar y concesionario, menú lateral abierto
	for _, extra in { { "nav_fleet", "tab_dealership" }, { "nav_pilots", "tab_hire" } } do
		press(assert(findButton(T(extra[1]))))
		press(assert(findButton(T(extra[2]))))
		fireState(stateJson)
		local guis = {}
		for _, g in playerGui:GetChildren() do table.insert(guis, node(g)) end
		fs.writeFile(outDir .. "/" .. extra[2] .. ".json", serde.encode("json", guis))
	end
	print("Volcado de interfaz en", outDir)
end
print("CLIENTE OK")
process.exit(0)
