-- Ejecuta World/Building/PlotManager reales sobre instancias de Lune
-- (que validan nombres y tipos de propiedades) y vuelca las piezas a JSON.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SRC = process.args[1]
local OUT = process.args[2]

-- Proxies sobre instancias reales -----------------------------------
local realOf = setmetatable({}, { __mode = "k" })
local proxyOf = setmetatable({}, { __mode = "v" })
local EVENTS = { Triggered = true, Changed = true, Touched = true, Activated = true, Completed = true }
local NOOP_METHODS = { Emit = true, Play = true, Stop = true }

local function fakeSignal()
	return { Connect = function() return { Disconnect = function() end } end, Wait = function() end }
end

local wrap, unwrap
local proxyMeta = {}

function wrap(v)
	if typeof(v) == "Instance" then
		local p = proxyOf[v]
		if not p then
			p = setmetatable({}, proxyMeta)
			realOf[p] = v
			proxyOf[v] = p
		end
		return p
	elseif type(v) == "table" and not realOf[v] then
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
	local inst = realOf[p]
	if EVENTS[key] then
		return fakeSignal()
	end
	if key == "GetPropertyChangedSignal" or key == "GetAttributeChangedSignal" then
		return function() return fakeSignal() end
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
	realOf[p][key] = unwrap(value)
end
proxyMeta.__tostring = function(p)
	return tostring(realOf[p])
end

-- Servicios simulados -------------------------------------------------
local tagged = {}
local CollectionService = {
	AddTag = function(_, inst, tag)
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], inst)
	end,
	GetTagged = function(_, tag)
		return tagged[tag] or {}
	end,
}
local TweenService = {
	Create = function(_, inst, _info, props)
		return {
			Play = function()
				for k, v in props do
					inst[k] = v
				end
			end,
			Completed = fakeSignal(),
		}
	end,
}

local dataModel = roblox.Instance.new("DataModel")
local services = {}
for _, name in { "Workspace", "Lighting", "ReplicatedStorage", "ServerScriptService" } do
	services[name] = dataModel:GetService(name)
end
local game = {
	GetService = function(_, name)
		if name == "CollectionService" then
			return CollectionService
		elseif name == "TweenService" then
			return TweenService
		end
		return wrap(assert(services[name], "servicio no simulado: " .. name))
	end,
}

-- Módulos en su sitio
local modulePaths = {}
local function addModule(parent, name, path)
	local m = roblox.Instance.new("ModuleScript")
	m.Name = name
	m.Parent = parent
	modulePaths[m:GetFullName()] = path
	return m
end
addModule(services.ReplicatedStorage, "TycoonConfig", SRC .. "/ReplicatedStorage/TycoonConfig.luau")
addModule(services.ReplicatedStorage, "CareerConfig", SRC .. "/ReplicatedStorage/CareerConfig.luau")
addModule(services.ReplicatedStorage, "CityLayout", SRC .. "/ReplicatedStorage/CityLayout.luau")
local trafficModule = addModule(services.ReplicatedStorage, "Traffic", SRC .. "/ReplicatedStorage/Traffic.luau")
addModule(services.ServerScriptService, "AgencyOffice", SRC .. "/ServerScriptService/AgencyOffice.luau")
addModule(services.ServerScriptService, "Building", SRC .. "/ServerScriptService/Building.luau")
addModule(services.ServerScriptService, "Showcase", SRC .. "/ServerScriptService/Showcase.luau")
addModule(services.ServerScriptService, "World", SRC .. "/ServerScriptService/World.luau")
local plotModule = addModule(services.ServerScriptService, "PlotManager", SRC .. "/ServerScriptService/PlotManager.luau")

local Random = {
	new = function(seed)
		math.randomseed(seed or 1)
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + math.random() * (b - a)
			end,
			NextInteger = function(_, a, b)
				return math.random(a, b)
			end,
		}
	end,
}

local task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err)
		end
	end,
	delay = function(_, fn, ...)
		fn(...)
	end,
	wait = function()
		coroutine.yield() -- los bucles infinitos se quedan aquí parados
	end,
}

local cache = {}
local requireModule
function requireModule(moduleProxy)
	local inst = unwrap(moduleProxy)
	local key = inst:GetFullName()
	if cache[key] then
		return cache[key]
	end
	local path = assert(modulePaths[key], "módulo desconocido: " .. key)
	local env = {
		game = game,
		script = wrap(inst),
		require = requireModule,
		Instance = { new = function(className) return wrap(roblox.Instance.new(className)) end },
		Random = Random,
		TweenInfo = roblox.TweenInfo or { new = function() return {} end },
		task = task,
		Enum = roblox.Enum,
		typeof = function(v) if type(v) == "table" and realOf[v] then return "Instance" end return typeof(v) end,
	}
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "ColorSequence", "BrickColor" } do
		env[name] = roblox[name]
	end
	-- CFrame.lookAt de Lune mira hacia el lado contrario que el de Roblox:
	-- se corrige para que el volcado (y los dibujos) salgan como en el juego
	env.CFrame = setmetatable({
		lookAt = function(at, target, up)
			return roblox.CFrame.lookAt(at, at * 2 - target, up)
		end,
	}, { __index = roblox.CFrame })
	setmetatable(env, { __index = _G })
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = chunk()
	cache[key] = result
	return result
end

-- Ejecución -----------------------------------------------------------
local PlotManager = requireModule(wrap(plotModule))
PlotManager.init(function() end)

local rarities = { "comun", "pococomun", "raro", "epico", "legendario", "mitico" }
local players = {
	{ name = "Ana", earned = 2e3, team = 0, types = 1, office = 0 },
	{ name = "Jorge", earned = 1e6, team = 3, types = 3, office = 1 },
	{ name = "Leo", earned = 3e9, team = 6, types = 5, gold = true, office = 3 },
	{ name = "Marta", earned = 1e13, team = 14, types = 7, office = 6 },
	{ name = "Nico", earned = 1e17, team = 26, types = 8, gold = true, office = 10 },
}
local roles = { "dev", "design", "marketing", "sales", "data" }
local Config = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("TycoonConfig")))
for i, p in players do
	local fakePlayer = { DisplayName = p.name, UserId = i }
	assert(PlotManager.claim(fakePlayer), "no hay parcela")
	-- Lo que se ve de su imperio: programadores, webs creadas y web estrella
	local programmers = {}
	for k = 1, p.team do
		table.insert(programmers, { id = k, name = "Prog " .. k, rarity = rarities[(k - 1) % #rarities + 1], niche = "tech", level = k % 10 + 1, role = roles[k % #roles + 1] })
	end
	local built = {}
	for k = 1, p.types do
		built[Config.WebTypes[k].id] = k * 3
	end
	local extra = {
		gold = false,
		likes = i * 2,
		agency = p.team > 0,
		agencyName = p.name .. " Dev Studio",
		officeLevel = p.office,
		capacity = 3 + 2 * p.office,
		programmers = programmers,
		builtTypes = built,
		bestSite = { name = "NovaHub.io", type = Config.WebTypes[p.types].id, visits = 1234 },
	}
	PlotManager.update(fakePlayer, p.earned, 123, extra)
	-- Segunda llamada para probar el crecimiento animado (y el dorado)
	extra.gold = p.gold == true
	PlotManager.update(fakePlayer, p.earned * 50, 456, extra)
end
-- Paneles de clasificación
PlotManager.setLeaderboard({ { name = "Ana", value = 5e6 } }, nil)
PlotManager.setWeeklyBoard({ { name = "Leo", value = 2e5 }, { name = "Ana", value = 1e4 } }, nil)
-- Liberar y volver a ocupar una parcela
local leaving = { DisplayName = "Temp", UserId = 99 }
PlotManager.claim(leaving)
PlotManager.update(leaving, 5e4, 1)
PlotManager.release(leaving)

-- Tráfico (en el juego lo mueve cada cliente)
local Traffic = requireModule(wrap(trafficModule))
local City = requireModule(wrap(services.ReplicatedStorage:FindFirstChild("CityLayout")))
Traffic.start(wrap(services.Workspace))
local path = Traffic.path()
local function distanceToPath(position)
	local best = math.huge
	for i, a in path do
		local b = path[i % #path + 1]
		local ab = b - a
		local t = math.clamp((position - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (a + ab * t - position).Magnitude)
	end
	return best
end
for frame = 1, 600 do
	Traffic.step(1 / 30)
	if frame % 100 == 0 then
		for _, car in Traffic.cars() do
			local position = car.cframe.Position
			assert(position == position, "coche con posición NaN")
			assert(distanceToPath(position) < 0.5, "un coche se ha salido de la carretera")
		end
	end
end
-- Las parcelas no pisan la calzada de la glorieta ni la avenida
for _, x in City.PLOT_X do
	local edge = math.abs(x) - City.PLOT_SIZE / 2
	assert(math.sqrt(edge * edge + (City.plotZ() - City.PLOT_SIZE / 2) ^ 2) > City.RING_OUTER + City.RING_SIDEWALK, "una parcela pisa la glorieta")
end
print(string.format("Tráfico: %d coches · recorrido de %.0f studs (una vuelta cada %.0f s)", #Traffic.cars(), Traffic.length(), Traffic.length() / Traffic.SPEED))

-- Volcado
local parts = {}
local count = 0
for _, d in services.Workspace:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
		local cf = d.CFrame
		local rx, ry, rz = cf.XVector, cf.YVector, cf.ZVector
		local plot = nil
		local ancestor = d.Parent
		while ancestor and ancestor ~= services.Workspace do
			if ancestor:GetAttribute("PlotIndex") then
				plot = ancestor:GetAttribute("PlotIndex")
			end
			ancestor = ancestor.Parent
		end
		table.insert(parts, {
			n = d.Name,
			p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
			x = { rx.X, rx.Y, rx.Z },
			y = { ry.X, ry.Y, ry.Z },
			z = { rz.X, rz.Y, rz.Z },
			s = { d.Size.X, d.Size.Y, d.Size.Z },
			c = { d.Color.R, d.Color.G, d.Color.B },
			t = d.Transparency,
			shape = if d:IsA("Part") then d.Shape.Name else "Block",
			m = d.Material.Name,
			plot = plot,
		})
	end
end
fs.writeFile(OUT, serde.encode("json", { parts = parts }))
print("OK · piezas en el mundo:", count)
print("Lighting.ClockTime", services.Lighting.ClockTime, "· efectos:", #services.Lighting:GetChildren())
process.exit(0)
