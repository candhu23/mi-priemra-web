--[[
	Simulación de Roblox para Lune (compartida por run_server.luau y run_game.luau).
	- Carga el lugar real construido con Rojo (tools/out/test.rbxl).
	- Envuelve las instancias de Lune en «proxies» para simular eventos (Activated, OnClientEvent…),
	  RemoteEvents/RemoteFunctions entre servidor y cliente, y propiedades que Lune no tiene.
	- Reloj falso: os.time/os.clock/task.wait/task.delay avanzan con tick().
	Nada de esto se publica: solo sirve para probar el código real sin abrir Studio.
]]

local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")

local M = {}

function M.new(placePath: string, opts: { [string]: any }?)
	local options = opts or {}
	local W: any = {}
	W.roblox = roblox
	W.game = roblox.deserializePlace(fs.readFile(placePath))
	W.fakeTime = 0
	W.fired = {} -- FireClient / FireAllClients del servidor
	W.callbacks = {} -- OnServerInvoke
	W.invoked = {} -- acciones enviadas por el cliente
	W.clientHandlers = {} -- se rellenan al conectar OnClientEvent
	W.saved = {}
	W.datastoreFails = options.datastoreFails == true

	local realOf = setmetatable({}, { __mode = "k" })
	local proxyById = {}
	local overrides = setmetatable({}, { __mode = "k" })
	local signals = {}
	local nextId = 0
	W.overrides = overrides
	W.realOf = realOf

	local function newSignal()
		local s = { handlers = {} }
		function s:Connect(fn)
			table.insert(self.handlers, fn)
			return { Disconnect = function()
				local i = table.find(self.handlers, fn)
				if i then table.remove(self.handlers, i) end
			end }
		end
		function s:Fire(...)
			for _, fn in table.clone(self.handlers) do
				fn(...)
			end
		end
		function s:Wait() end
		return s
	end
	W.newSignal = newSignal

	local function idOf(inst)
		local id = inst:GetAttribute("__hid")
		if not id then
			nextId += 1
			id = nextId
			inst:SetAttribute("__hid", id)
		end
		return id
	end
	W.idOf = idOf

	local function signalFor(id, key)
		local k = tostring(id) .. ":" .. key
		signals[k] = signals[k] or newSignal()
		return signals[k]
	end
	W.signalFor = signalFor

	local SIGNALS = {
		Activated = true, MouseEnter = true, MouseLeave = true, OnClientEvent = true, OnServerEvent = true,
		Changed = true, Completed = true, CharacterAdded = true, Triggered = true,
		InputBegan = true, InputChanged = true, InputEnded = true,
	}
	local NOOP = { Play = true, Stop = true }

	local wrap, unwrap
	local meta = {}
	function wrap(v)
		if typeof(v) == "Instance" then
			local id = idOf(v)
			local p = proxyById[id]
			if not p then
				p = setmetatable({}, meta)
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
	W.wrap, W.unwrap = wrap, unwrap

	-- Copia profunda como la que hace Roblox al mandar datos por un remote
	local function serialize(v, depth)
		depth = depth or 0
		assert(depth < 30, "tabla demasiado profunda o con ciclos en un remote")
		if type(v) == "table" and not realOf[v] then
			local out = {}
			for k, x in v do
				assert(type(k) == "string" or type(k) == "number", "clave no válida en un remote: " .. tostring(k))
				assert(type(x) ~= "function", "función dentro de un remote")
				out[k] = serialize(x, depth + 1)
			end
			return out
		end
		return v
	end
	W.serialize = serialize

	W.playersById = {}
	meta.__index = function(p, key)
		local o = overrides[p]
		if o and o[key] ~= nil then
			return o[key]
		end
		local inst = realOf[p]
		if SIGNALS[key] then
			return signalFor(idOf(inst), key)
		end
		if key == "GetPropertyChangedSignal" or key == "GetAttributeChangedSignal" then
			return function(_, name)
				return signalFor(idOf(inst), "changed:" .. name)
			end
		end
		if key == "AbsolutePosition" then
			return roblox.Vector2.new(100, 100)
		elseif key == "AbsoluteSize" then
			return roblox.Vector2.new(60, 40)
		end
		-- Remotes: servidor ↔ cliente en el mismo proceso
		if key == "FireClient" then
			return function(_, plr, ...)
				local args = serialize({ ... })
				table.insert(W.fired, { inst.Name, plr, table.unpack(args) })
				signalFor(idOf(inst), "OnClientEvent"):Fire(table.unpack(args))
			end
		elseif key == "FireAllClients" then
			return function(_, ...)
				local args = serialize({ ... })
				table.insert(W.fired, { inst.Name, "all", table.unpack(args) })
				signalFor(idOf(inst), "OnClientEvent"):Fire(table.unpack(args))
			end
		elseif key == "InvokeServer" then
			-- table.pack/n: Roblox conserva los nil en medio de los argumentos y de las respuestas
			return function(_, ...)
				local args = serialize(table.pack(...))
				table.insert(W.invoked, args[1])
				local cb = assert(W.callbacks[inst.Name], "nadie escucha " .. inst.Name)
				local results = serialize(table.pack(cb(W.player, table.unpack(args, 1, args.n))))
				return table.unpack(results, 1, results.n)
			end
		elseif key == "WaitForChild" then
			return function(_, name)
				local child = inst:FindFirstChild(name)
				assert(child, "WaitForChild colgado: " .. tostring(name) .. " en " .. inst:GetFullName())
				return wrap(child)
			end
		end
		local ok, value = pcall(function() return inst[key] end)
		if not ok then
			if NOOP[key] then
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
	meta.__newindex = function(p, key, value)
		if key == "OnServerInvoke" then
			W.callbacks[realOf[p].Name] = value
			return
		end
		realOf[p][key] = unwrap(value)
	end
	meta.__tostring = function(p)
		return tostring(realOf[p])
	end

	---------------------------------------------------------------------
	-- Reloj y tareas
	---------------------------------------------------------------------
	local sleeping = {}
	local delayed = {}
	local task = {
		spawn = function(fn, ...)
			local co = coroutine.create(fn)
			local ok, err = coroutine.resume(co, ...)
			if not ok then error(debug.traceback(co, tostring(err))) end
			if coroutine.status(co) == "suspended" then table.insert(sleeping, co) end
		end,
		delay = function(t, fn, ...)
			table.insert(delayed, { at = W.fakeTime + (t or 0), fn = fn, args = table.pack(...) })
		end,
		wait = function()
			if coroutine.isyieldable() then coroutine.yield() end
		end,
	}
	W.task = task

	-- Avanza el reloj: despierta el bucle del servidor y ejecuta los task.delay vencidos
	function W.tick(seconds: number)
		for _ = 1, math.max(1, math.floor(seconds)) do
			W.fakeTime += 1
			local list = sleeping
			sleeping = {}
			for _, co in list do
				local ok, err = coroutine.resume(co)
				if not ok then error(debug.traceback(co, tostring(err))) end
				if coroutine.status(co) == "suspended" then table.insert(sleeping, co) end
			end
			W.runDelayed()
		end
	end
	function W.runDelayed()
		local due = {}
		for i = #delayed, 1, -1 do
			if delayed[i].at <= W.fakeTime then
				table.insert(due, table.remove(delayed, i))
			end
		end
		for _, d in due do
			d.fn(table.unpack(d.args, 1, d.args.n))
		end
	end

	---------------------------------------------------------------------
	-- Servicios simulados
	---------------------------------------------------------------------
	local playersFolder = roblox.Instance.new("Folder")
	playersFolder.Name = "Players"
	playersFolder.Parent = W.game
	W.playerList = {}
	W.Players = {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function() return table.clone(W.playerList) end,
		GetPlayerByUserId = function(_, id) return W.playersById[id] end,
		GetNameFromUserIdAsync = function(_, id) return "Jugador" .. id end,
	}
	local function store(name)
		return {
			GetAsync = function(_, key)
				if W.datastoreFails then error("DataStore no disponible (simulado)") end
				return W.saved[name .. "/" .. key]
			end,
			UpdateAsync = function(_, key, fn)
				if W.datastoreFails then error("DataStore no disponible (simulado)") end
				W.saved[name .. "/" .. key] = serialize(fn(W.saved[name .. "/" .. key]))
			end,
			SetAsync = function(_, key, value)
				assert(value == math.floor(value), "puntuación no entera")
				W.saved[name .. "/" .. key] = value
			end,
			GetSortedAsync = function()
				return { GetCurrentPage = function()
					local list = {}
					for k, v in W.saved do
						local userId = string.match(k, "^" .. name .. "/(%d+)$")
						if userId then table.insert(list, { key = userId, value = v }) end
					end
					return list
				end }
			end,
		}
	end
	W.DataStoreService = {
		GetDataStore = function(_, name)
			if options.datastoreInitFails then error("You must publish this place to the web to access DataStore (simulado)") end
			return store(name)
		end,
		GetOrderedDataStore = function(_, name)
			if options.datastoreInitFails then error("You must publish this place to the web to access DataStore (simulado)") end
			return store(name)
		end,
	}
	W.prompts = {}
	W.MarketplaceService = {
		PromptGamePassPurchaseFinished = newSignal(),
		UserOwnsGamePassAsync = function() return true end,
		PromptGamePassPurchase = function(_, _p, id) table.insert(W.prompts, "pass:" .. id) end,
		PromptProductPurchase = function(_, _p, id) table.insert(W.prompts, "product:" .. id) end,
		GetProductInfo = function() return { PriceInRobux = 99 } end,
	}
	W.renderStepped = newSignal()
	local function tweenService()
		return { Create = function(_, inst, _i, props)
			return { Play = function() for k, v in props do inst[k] = v end end, Completed = newSignal() }
		end }
	end
	local mocks = {
		Players = W.Players,
		DataStoreService = W.DataStoreService,
		MarketplaceService = W.MarketplaceService,
		TweenService = tweenService(),
		RunService = { RenderStepped = W.renderStepped, Heartbeat = newSignal(), IsStudio = function() return true end },
		LocalizationService = { RobloxLocaleId = options.locale or "es-es" },
		SocialService = { PromptGameInvite = function() table.insert(W.prompts, "invite") end, CanSendGameInviteAsync = function() return true end },
		UserInputService = { TouchPinch = newSignal(), InputBegan = newSignal(), InputChanged = newSignal(), InputEnded = newSignal() },
	}
	W.mocks = mocks
	local camera = { ViewportSize = roblox.Vector2.new(options.width or 1280, options.height or 720), GetPropertyChangedSignal = function() return newSignal() end }
	overrides[wrap(W.game:GetService("Workspace"))] = { CurrentCamera = camera }
	W.gameGlobal = {
		GetService = function(_, name)
			if mocks[name] then return mocks[name] end
			return wrap(W.game:GetService(name))
		end,
		BindToClose = function(_, fn) W.closeHandler = fn end,
	}

	---------------------------------------------------------------------
	-- Entorno de ejecución de un script y require de ModuleScripts reales
	---------------------------------------------------------------------
	local cache = {}
	local env
	local function requireModule(moduleProxy)
		local inst = unwrap(moduleProxy)
		assert(typeof(inst) == "Instance" and inst.ClassName == "ModuleScript", "require de algo que no es un ModuleScript")
		local key = idOf(inst)
		if cache[key] == nil then
			local chunk = luau.load(inst.Source, { debugName = inst:GetFullName(), environment = env(inst) })
			cache[key] = chunk()
		end
		return cache[key]
	end
	function env(scriptInst)
		local e = {
			game = W.gameGlobal,
			script = wrap(scriptInst),
			Instance = { new = function(className) return wrap(roblox.Instance.new(className)) end },
			Random = { new = function()
				return {
					NextNumber = function(_, a, b) a, b = a or 0, b or 1 return a + math.random() * (b - a) end,
					NextInteger = function(_, a, b) return math.random(a, b) end,
				}
			end },
			task = task,
			Enum = roblox.Enum,
			TweenInfo = { new = function() return {} end },
			os = { time = function() return 1_700_000_000 + math.floor(W.fakeTime) end, clock = function() return W.fakeTime end, date = os.date },
			warn = function(...) print("[warn]", ...) end,
			typeof = function(v) if type(v) == "table" and realOf[v] then return "Instance" end return typeof(v) end,
			require = requireModule,
		}
		for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "ColorSequence", "Font", "ColorSequenceKeypoint", "Rect" } do
			e[name] = roblox[name]
		end
		return setmetatable(e, { __index = _G })
	end
	W.env = env
	W.require = requireModule

	-- Ejecuta un Script/LocalScript (puede quedarse dormido en su bucle principal)
	function W.runScript(inst)
		local chunk = luau.load(inst.Source, { debugName = inst:GetFullName(), environment = env(inst) })
		task.spawn(chunk)
	end

	-- Crea un jugador falso (un Folder real dentro de Players)
	function W.addPlayer(userId: number, name: string)
		local real = roblox.Instance.new("Folder")
		real.Name = name
		real.Parent = playersFolder
		local pg = roblox.Instance.new("Folder")
		pg.Name = "PlayerGui"
		pg.Parent = real
		local ps = roblox.Instance.new("Folder")
		ps.Name = "PlayerScripts"
		ps.Parent = real
		local p = wrap(real)
		overrides[p] = {
			UserId = userId, DisplayName = name, Name = name,
			MembershipType = roblox.Enum.MembershipType.None,
			IsFriendsWithAsync = function() return true end,
			IsInGroupAsync = function() return false end,
		}
		W.playersById[userId] = p
		table.insert(W.playerList, p)
		return p, real
	end

	return W
end

return M
