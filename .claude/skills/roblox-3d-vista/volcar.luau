--[[
	volcar.luau — ejecuta en Lune (sin Studio) un módulo que CONSTRUYE cosas en el mundo y vuelca
	todas las piezas a JSON para dibujarlas con vista3d.py.

	Uso:
		lune run volcar.luau <modulo.luau> <salida.json> [opciones]
	Opciones:
		--codigo "<luau>"            código a ejecutar; tiene M (el módulo), workspace, game, CFrame, Vector3…
		                             Por defecto: si M es función → M(workspace); si M.construir → M.construir(workspace)
		--modulo Servicio/Nombre=ruta   registra otro ModuleScript (p. ej. ReplicatedStorage/Constructor=Constructor.luau)
		                             para que require(ReplicatedStorage.Constructor) funcione dentro del módulo.
	Ejemplos:
		lune run volcar.luau Constructor.luau out.json --codigo "M.casa(workspace, CFrame.new()); M.arbol(workspace, Vector3.new(20,0,0))"
		lune run volcar.luau MiMundo.luau out.json --modulo ReplicatedStorage/Constructor=Constructor.luau

	Lo que NO puede: Terrain (FillBlock…), física, eventos (Touched…), task.wait real. Los bucles con
	task.wait se quedan parados en la primera espera (lo construido antes sí se vuelca).
	Lune comprueba nombres y tipos de propiedades: si algo está mal escrito, falla aquí con el error.
]]
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local args = process.args
local RUTA, SALIDA = args[1], args[2]
assert(RUTA and SALIDA, "uso: lune run volcar.luau <modulo.luau> <salida.json> [--codigo ...] [--modulo Servicio/Nombre=ruta]")
local codigo: string? = nil
local extras = {}
do
	local i = 3
	while i <= #args do
		if args[i] == "--codigo" then
			codigo = args[i + 1]
			i += 2
		elseif args[i] == "--modulo" then
			local servicio, nombre, ruta = string.match(args[i + 1], "^([^/]+)/([^=]+)=(.+)$")
			assert(servicio, "--modulo debe ser Servicio/Nombre=ruta")
			table.insert(extras, { servicio = servicio, nombre = nombre, ruta = ruta })
			i += 2
		else
			error("opción desconocida: " .. tostring(args[i]))
		end
	end
end

-- Proxies: Lune no tiene eventos; los simulamos para que el código de Roblox no falle --------------
local realOf = setmetatable({}, { __mode = "k" })
local proxyOf = setmetatable({}, { __mode = "v" })
local EVENTOS = { Changed = true, Touched = true, TouchEnded = true, Activated = true, Triggered = true, Completed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true, MouseEnter = true, MouseLeave = true, AncestryChanged = true, Destroying = true }
local NOOP = { Emit = true, Play = true, Stop = true, Pause = true, Clear = true }

local function senal()
	return { Connect = function() return { Disconnect = function() end } end, Once = function() return { Disconnect = function() end } end, Wait = function() end }
end

local envolver, desenvolver
local meta = {}
function envolver(v)
	if typeof(v) == "Instance" then
		local p = proxyOf[v]
		if not p then
			p = setmetatable({}, meta)
			realOf[p] = v
			proxyOf[v] = p
		end
		return p
	elseif type(v) == "table" and not realOf[v] then
		local out = {}
		for k, x in v do
			out[k] = envolver(x)
		end
		return out
	end
	return v
end
function desenvolver(v)
	if type(v) == "table" and realOf[v] then
		return realOf[v]
	end
	return v
end
meta.__index = function(p, clave)
	local inst = realOf[p]
	if EVENTOS[clave] then
		return senal()
	end
	if clave == "GetPropertyChangedSignal" or clave == "GetAttributeChangedSignal" then
		return function() return senal() end
	end
	if clave == "WaitForChild" then
		return function(_, nombre)
			return envolver(assert(inst:FindFirstChild(nombre), "WaitForChild colgado: " .. tostring(nombre)))
		end
	end
	local ok, valor = pcall(function() return inst[clave] end)
	if not ok then
		if NOOP[clave] then
			return function() end
		end
		local hijo = inst:FindFirstChild(clave)
		if hijo then
			return envolver(hijo)
		end
		error(valor, 2)
	end
	if type(valor) == "function" then
		return function(_, ...)
			local a = table.pack(...)
			for i = 1, a.n do
				a[i] = desenvolver(a[i])
			end
			local r = table.pack(valor(inst, table.unpack(a, 1, a.n)))
			for i = 1, r.n do
				r[i] = envolver(r[i])
			end
			return table.unpack(r, 1, r.n)
		end
	end
	return envolver(valor)
end
meta.__newindex = function(p, clave, valor)
	realOf[p][clave] = desenvolver(valor)
end
meta.__tostring = function(p)
	return tostring(realOf[p])
end

-- Servicios ------------------------------------------------------------------------------------
local dm = roblox.Instance.new("DataModel")
local servicios = {}
for _, n in { "Workspace", "Lighting", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "SoundService" } do
	servicios[n] = dm:GetService(n)
end
local etiquetas = {}
local falsos = {
	CollectionService = {
		AddTag = function(_, inst, tag)
			etiquetas[tag] = etiquetas[tag] or {}
			table.insert(etiquetas[tag], inst)
		end,
		GetTagged = function(_, tag) return etiquetas[tag] or {} end,
		GetInstanceAddedSignal = function() return senal() end,
	},
	TweenService = {
		Create = function(_, inst, _info, props)
			return {
				Play = function()
					for k, v in props do
						inst[k] = v
					end
				end,
				Cancel = function() end,
				Completed = senal(),
			}
		end,
	},
	RunService = { Heartbeat = senal(), RenderStepped = senal(), Stepped = senal(), IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return true end },
	Players = { GetPlayers = function() return {} end, PlayerAdded = senal(), PlayerRemoving = senal() },
}
local game = {
	GetService = function(_, n)
		if falsos[n] then
			return falsos[n]
		end
		return envolver(assert(servicios[n], "servicio no simulado en volcar.luau: " .. n))
	end,
}
game.Workspace = envolver(servicios.Workspace)
game.Lighting = envolver(servicios.Lighting)

local Random = {
	new = function(semilla)
		local estado = (semilla or 1) % 2147483647
		if estado <= 0 then
			estado += 2147483646
		end
		local function siguiente()
			estado = (estado * 16807) % 2147483647
			return estado / 2147483647
		end
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + siguiente() * (b - a)
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(siguiente() * (b - a + 1))
			end,
		}
	end,
}

local nuestras = setmetatable({}, { __mode = "k" })
local task = {
	spawn = function(f, ...)
		local co = coroutine.create(f)
		nuestras[co] = true
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err)
		end
	end,
	delay = function() end, -- lo diferido no se ejecuta (no hay tiempo real)
	defer = function(f, ...) f(...) end,
	wait = function()
		if nuestras[coroutine.running()] then
			coroutine.yield() -- los bucles con espera se quedan parados aquí
		end
		return 0.03
	end,
}

-- Carga de módulos -----------------------------------------------------------------------------
local rutas = {}
local fuentes = {} -- código leído de antemano: fs.readFile es asíncrono en Lune y suspendería las corrutinas
local cache = {}
local cargar
local function entorno(inst)
	local env = {
		game = game,
		workspace = game.Workspace,
		script = envolver(inst),
		require = function(m) return cargar(m) end,
		Instance = { new = function(clase, padre)
			local i = roblox.Instance.new(clase)
			if padre then
				i.Parent = desenvolver(padre)
			end
			return envolver(i)
		end },
		Random = Random,
		TweenInfo = { new = function() return {} end },
		task = task,
		Enum = roblox.Enum,
		warn = function(...) print("[warn]", ...) end,
		typeof = function(v)
			if type(v) == "table" and realOf[v] then
				return "Instance"
			end
			return typeof(v)
		end,
	}
	for _, n in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "BrickColor", "Font", "Region3", "Rect", "PhysicalProperties", "Ray" } do
		env[n] = (roblox :: any)[n]
	end
	return setmetatable(env, { __index = _G })
end

function cargar(m)
	local inst = desenvolver(m)
	local clave = inst:GetFullName()
	if cache[clave] ~= nil then
		return cache[clave]
	end
	local ruta = assert(rutas[clave], "require de un módulo no registrado: " .. clave .. " (usa --modulo)")
	local f = luau.load(fuentes[ruta], { debugName = ruta, environment = entorno(inst) })
	local r = f()
	cache[clave] = r
	return r
end

local function registrar(servicio, nombre, ruta)
	local m = roblox.Instance.new("ModuleScript")
	m.Name = nombre
	m.Parent = assert(servicios[servicio], "servicio desconocido: " .. servicio)
	rutas[m:GetFullName()] = ruta
	fuentes[ruta] = fs.readFile(ruta)
	return m
end

for _, e in extras do
	registrar(e.servicio, e.nombre, e.ruta)
end
local principal = registrar("ServerScriptService", "Principal", RUTA)

-- Ejecución ------------------------------------------------------------------------------------
local M = cargar(envolver(principal))
local ws = game.Workspace
if codigo then
	local env = entorno(principal)
	env.M = M
	local f = luau.load(codigo, { debugName = "--codigo", environment = env })
	task.spawn(f)
elseif type(M) == "function" then
	task.spawn(M, ws)
elseif type(M) == "table" and type(M.construir) == "function" then
	task.spawn(M.construir, ws)
end

-- Volcado --------------------------------------------------------------------------------------
local piezas = {}
local clases = {}
for _, d in servicios.Workspace:GetDescendants() do
	clases[d.ClassName] = (clases[d.ClassName] or 0) + 1
	if d:IsA("BasePart") then
		local cf = d.CFrame
		local forma = "Block"
		if d:IsA("Part") then
			forma = d.Shape.Name
		elseif d:IsA("WedgePart") then
			forma = "Wedge"
		elseif d:IsA("CornerWedgePart") then
			forma = "CornerWedge"
		end
		local malla = d:FindFirstChildOfClass("SpecialMesh")
		local escala = { 1, 1, 1 }
		if malla then
			if malla.MeshType == roblox.Enum.MeshType.Sphere then
				forma = "Ball"
			end
			escala = { malla.Scale.X, malla.Scale.Y, malla.Scale.Z }
		end
		local luz = d:FindFirstChildWhichIsA("Light")
		table.insert(piezas, {
			n = d.Name,
			ruta = d:GetFullName(),
			p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
			x = { cf.XVector.X, cf.XVector.Y, cf.XVector.Z },
			y = { cf.YVector.X, cf.YVector.Y, cf.YVector.Z },
			z = { cf.ZVector.X, cf.ZVector.Y, cf.ZVector.Z },
			s = { d.Size.X * escala[1], d.Size.Y * escala[2], d.Size.Z * escala[3] },
			c = { d.Color.R, d.Color.G, d.Color.B },
			t = d.Transparency,
			forma = forma,
			m = d.Material.Name,
			anclada = d.Anchored,
			colision = d.CanCollide,
			clase = d.ClassName,
			luz = if luz then { luz.Color.R, luz.Color.G, luz.Color.B } else nil,
		})
	end
end
fs.writeFile(SALIDA, serde.encode("json", { piezas = piezas, clases = clases }))
print(string.format("VOLCADO OK · %d piezas → %s", #piezas, SALIDA))
