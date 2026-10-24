--[[
	probar_pantallas.luau — ejecuta en Lune (sin Studio) el código de INTERFAZ de un LocalScript/módulo,
	pulsa lo que le pidas y guarda «fotos» de la PlayerGui para verlas con ver_interfaz.py.

	Uso:
		lune run probar_pantallas.luau <carpetaSalida> <guion.luau> [ancho alto] [--modulo Servicio/Nombre=ruta ...]

	El guion es Luau normal de cliente (tiene game, workspace, Instance, Enum, require…) y además:
		captura("01_hud")          guarda la PlayerGui en <carpeta>/01_hud.json
		avanzar(n)                 deja pasar n «esperas» (task.wait) de lo que haya en marcha: animaciones, huevos…
		pulsar(boton)              dispara Activated de un botón creado por el código (TextButton/ImageButton)
		buscar("Nombre")           primer descendiente de la PlayerGui con ese nombre
		jugador                    el LocalPlayer simulado
	Ejemplo de guion:
		local UIKit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"))
		local lienzo = UIKit.pantalla("Juego")
		UIKit.boton({ Parent = lienzo, texto = "Hola", Position = UDim2.fromScale(0.5, 0.5) })
		captura("01_boton")

	Después: python3 -I ver_interfaz.py <carpetaSalida> [--movil]   → PNG + informe_diseno.md
	Para móvil, ejecuta con 844 390: la escala de la interfaz se calcula con ese tamaño.
	Llama a captura() desde el cuerpo del guion (no dentro de task.spawn).
	Límites: sin AbsolutePosition reales (se devuelven 0), sin física ni red; las animaciones se aplican al
	instante (TweenService pone el valor final).
]]
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local args = process.args
local CARPETA, GUION = args[1], args[2]
assert(CARPETA and GUION, "uso: lune run probar_pantallas.luau <carpeta> <guion.luau> [ancho alto] [--modulo Servicio/Nombre=ruta]")
local ANCHO, ALTO = 1280, 720
local extras = {}
do
	local i = 3
	if args[3] and tonumber(args[3]) then
		ANCHO, ALTO = tonumber(args[3]) :: number, tonumber(args[4]) :: number
		i = 5
	end
	while i <= #args do
		if args[i] == "--modulo" then
			local servicio, nombre, ruta = string.match(args[i + 1], "^([^/]+)/([^=]+)=(.+)$")
			assert(servicio, "--modulo debe ser Servicio/Nombre=ruta")
			table.insert(extras, { servicio = servicio, nombre = nombre, ruta = ruta })
			i += 2
		else
			error("opción desconocida: " .. tostring(args[i]))
		end
	end
end
if not fs.isDir(CARPETA) then
	fs.writeDir(CARPETA)
end
local BARRA = 58 -- alto de la barra superior de Roblox (lo usa ver_interfaz.py igual)

-- Planificador: task.wait cede; avanzar(n) reanuda lo pendiente ----------------------------------
local pendientes = {}
local nuestras = setmetatable({}, { __mode = "k" }) -- corrutinas creadas por task.spawn/delay de aquí
local function reanudar(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(err)))
	end
	if coroutine.status(co) == "suspended" then
		table.insert(pendientes, co)
	end
end
local task = {
	spawn = function(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		nuestras[co] = true
		reanudar(co, ...)
		return co
	end,
	delay = function(_, f, ...)
		local a = table.pack(...)
		local co = coroutine.create(function()
			coroutine.yield()
			f(table.unpack(a, 1, a.n))
		end)
		nuestras[co] = true
		reanudar(co)
		return co
	end,
	defer = function(f, ...)
		return task.spawn(f, ...)
	end,
	wait = function(s)
		-- Solo cede dentro de nuestras corrutinas; en el guion principal no espera (el tiempo pasa con avanzar)
		if nuestras[coroutine.running()] then
			coroutine.yield()
		end
		return s or 0.03
	end,
	cancel = function() end,
}
local function avanzar(n)
	for _ = 1, n or 1 do
		local lista = pendientes
		pendientes = {}
		for _, co in lista do
			if coroutine.status(co) == "suspended" then
				reanudar(co)
			end
		end
	end
end

-- Señales simuladas (con Fire para poder «pulsar») -----------------------------------------------
local function nuevaSenal()
	local conexiones = {}
	local s = {}
	function s.Connect(_, f)
		local c = { f = f, vivo = true }
		table.insert(conexiones, c)
		return { Disconnect = function() c.vivo = false end, Connected = true }
	end
	s.Once = s.Connect
	function s.Wait() end
	function s.Fire(_, ...)
		for _, c in conexiones do
			if c.vivo then
				task.spawn(c.f, ...)
			end
		end
	end
	return s
end

-- Proxies sobre instancias reales de Lune -----------------------------------------------------
local realOf = setmetatable({}, { __mode = "k" })
local proxyOf = setmetatable({}, { __mode = "v" })
local senales = setmetatable({}, { __mode = "k" }) -- inst → { evento → señal }
local EVENTOS = { Changed = true, Touched = true, Activated = true, Triggered = true, Completed = true, ChildAdded = true, ChildRemoved = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true, MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true, FocusLost = true, Destroying = true, AncestryChanged = true }
local NOOP = { Emit = true, Play = true, Stop = true, Pause = true }

local function senalDe(inst, evento)
	senales[inst] = senales[inst] or {}
	local s = senales[inst][evento]
	if not s then
		s = nuevaSenal()
		senales[inst][evento] = s
	end
	return s
end

local envolver, desenvolver
local meta = {}
local camara = {
	ViewportSize = roblox.Vector2.new(ANCHO, ALTO),
	CFrame = roblox.CFrame.new(),
	GetPropertyChangedSignal = function() return nuevaSenal() end,
}
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
		return senalDe(inst, clave)
	end
	if clave == "GetPropertyChangedSignal" or clave == "GetAttributeChangedSignal" then
		return function(_, prop) return senalDe(inst, "cambio_" .. tostring(prop)) end
	end
	if clave == "CurrentCamera" and inst.ClassName == "Workspace" then
		return camara
	end
	if clave == "AbsoluteSize" then
		if inst:IsA("ScreenGui") then
			return roblox.Vector2.new(ANCHO, ALTO - BARRA)
		end
		return roblox.Vector2.new(0, 0)
	end
	if clave == "AbsolutePosition" then
		return roblox.Vector2.new(0, 0)
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
	local inst = realOf[p]
	inst[clave] = desenvolver(valor)
	local s = senales[inst] and senales[inst]["cambio_" .. clave]
	if s then
		s:Fire()
	end
	if clave == "Value" then
		local c = senales[inst] and senales[inst].Changed
		if c then
			c:Fire(valor)
		end
	end
end
meta.__tostring = function(p)
	return tostring(realOf[p])
end

-- Servicios y jugador ----------------------------------------------------------------------------
local dm = roblox.Instance.new("DataModel")
local servicios = {}
for _, n in { "Workspace", "Lighting", "ReplicatedStorage", "StarterGui", "SoundService" } do
	servicios[n] = dm:GetService(n)
end
local carpetaJugador = roblox.Instance.new("Folder")
carpetaJugador.Name = "JugadorPrueba"
local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
playerGui.Parent = carpetaJugador
local jugador = setmetatable({ Name = "JugadorPrueba", DisplayName = "Jugador", UserId = 1, LocaleId = "es-es" }, {
	__index = function(_, k)
		if k == "PlayerGui" then
			return envolver(playerGui)
		end
		return envolver(carpetaJugador)[k]
	end,
})
local falsos = {
	Players = { LocalPlayer = jugador, GetPlayers = function() return { jugador } end, PlayerAdded = nuevaSenal(), PlayerRemoving = nuevaSenal() },
	TweenService = {
		Create = function(_, inst, _info, props)
			local completado = nuevaSenal()
			return {
				Play = function()
					for k, v in props do
						inst[k] = v
					end
					completado:Fire(roblox.Enum.PlaybackState.Completed)
				end,
				Cancel = function() end,
				Pause = function() end,
				Completed = completado,
			}
		end,
	},
	RunService = { Heartbeat = nuevaSenal(), RenderStepped = nuevaSenal(), Stepped = nuevaSenal(), IsClient = function() return true end, IsServer = function() return false end, IsStudio = function() return true end },
	UserInputService = {
		TouchEnabled = ANCHO < 1000, KeyboardEnabled = ANCHO >= 1000, MouseEnabled = ANCHO >= 1000, GamepadEnabled = false,
		GetLastInputType = function() return if ANCHO < 1000 then roblox.Enum.UserInputType.Touch else roblox.Enum.UserInputType.MouseButton1 end,
		LastInputTypeChanged = nuevaSenal(), InputBegan = nuevaSenal(), InputEnded = nuevaSenal(),
	},
	GuiService = { GetGuiInset = function() return roblox.Vector2.new(0, BARRA), roblox.Vector2.new(0, 0) end, SelectedObject = nil },
	SoundService = { PlayLocalSound = function() end },
	ContentProvider = { PreloadAsync = function() end },
	CollectionService = { GetTagged = function() return {} end, AddTag = function() end, GetInstanceAddedSignal = function() return nuevaSenal() end },
}
local game = {
	GetService = function(_, n)
		if falsos[n] then
			return falsos[n]
		end
		return envolver(assert(servicios[n], "servicio no simulado en probar_pantallas.luau: " .. n))
	end,
}
game.Workspace = envolver(servicios.Workspace)

local Random = {
	new = function(semilla)
		local e = (semilla or 1) % 2147483647
		if e <= 0 then
			e += 2147483646
		end
		local function sig()
			e = (e * 16807) % 2147483647
			return e / 2147483647
		end
		return {
			NextNumber = function(_, a, b) a, b = a or 0, b or 1 return a + sig() * (b - a) end,
			NextInteger = function(_, a, b) return a + math.floor(sig() * (b - a + 1)) end,
		}
	end,
}

-- Módulos ----------------------------------------------------------------------------------------
local rutas = {}
local fuentes = {} -- código leído de antemano: fs.readFile es asíncrono en Lune y suspendería las corrutinas
local cache = {}
local cargar
local function entorno(inst)
	local env = {
		game = game,
		workspace = game.Workspace,
		script = if inst then envolver(inst) else nil,
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
	for _, n in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "BrickColor", "Font", "Rect", "Region3" } do
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
	local r = luau.load(fuentes[ruta], { debugName = ruta, environment = entorno(inst) })()
	cache[clave] = r
	return r
end
for _, e in extras do
	local m = roblox.Instance.new("ModuleScript")
	m.Name = e.nombre
	m.Parent = assert(servicios[e.servicio], "servicio desconocido: " .. e.servicio)
	rutas[m:GetFullName()] = e.ruta
	fuentes[e.ruta] = fs.readFile(e.ruta)
end

-- Guion -----------------------------------------------------------------------------------------
local volcar = require("./volcado")
local env = entorno(nil)
env.jugador = jugador
env.avanzar = avanzar
env.captura = function(nombre)
	volcar(playerGui, CARPETA .. "/" .. nombre .. ".json")
	print("captura", nombre)
end
env.pulsar = function(boton)
	local inst = desenvolver(boton)
	senalDe(inst, "Activated"):Fire()
	senalDe(inst, "MouseButton1Click"):Fire()
end
env.buscar = function(nombre)
	local d = playerGui:FindFirstChild(nombre, true)
	return if d then envolver(d) else nil
end
local f = luau.load(fs.readFile(GUION), { debugName = GUION, environment = env })
f() -- el guion va en el hilo principal: así captura() puede escribir archivos
avanzar(3)
print(string.format("PANTALLAS OK · %dx%d · capturas en %s", ANCHO, ALTO, CARPETA))
