--[[
	Simulación de Roblox para Lune (compartida por run_world, run_server y run_client).
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
			return { Disconnect = function() end }
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
		Changed = true, Completed = true, CharacterAdded = true, Triggered = true, CharacterRemoving = true,
		MouseButton1Down = true, MouseButton1Up = true, InputBegan = true, InputEnded = true, Died = true,
	}
	local NOOP = { Play = true, Stop = true, Pause = true, Resume = true }

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
			-- Como Roblox: los nil en medio de los argumentos o de lo devuelto conservan su posición
			return function(_, ...)
				local packed = table.pack(...)
				local args = {}
				for i = 1, packed.n do
					args[i] = serialize(packed[i])
				end
				table.insert(W.invoked, args[1])
				local cb = assert(W.callbacks[inst.Name], "nadie escucha " .. inst.Name)
				local res = table.pack(cb(W.player, table.unpack(args, 1, packed.n)))
				local outs = {}
				for i = 1, res.n do
					outs[i] = serialize(res[i])
				end
				return table.unpack(outs, 1, res.n)
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
		defer = function(fn, ...)
			table.insert(delayed, { at = W.fakeTime, fn = fn, args = table.pack(...) })
		end,
		cancel = function() end,
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
	W.heartbeat = newSignal()
	-- Entrada simulada (teclado/ratón/táctil/mando)
	W.UIS = {
		InputBegan = newSignal(), InputEnded = newSignal(), InputChanged = newSignal(), TouchStarted = newSignal(),
		LastInputTypeChanged = newSignal(), JumpRequest = newSignal(),
		TouchEnabled = options.touch == true, KeyboardEnabled = options.touch ~= true, GamepadEnabled = false, MouseEnabled = options.touch ~= true,
		MouseBehavior = roblox.Enum.MouseBehavior.Default, MouseIconEnabled = true, MouseDeltaSensitivity = 1,
		GetLastInputType = function() return options.touch and roblox.Enum.UserInputType.Touch or roblox.Enum.UserInputType.Keyboard end,
		IsKeyDown = function() return false end,
		GetGamepadConnected = function() return false end,
	}
	W.actions = {}
	W.CAS = {
		BindAction = function(_, name, fn) W.actions[name] = fn end,
		BindActionAtPriority = function(_, name, fn) W.actions[name] = fn end,
		UnbindAction = function(_, name) W.actions[name] = nil end,
		SetTitle = function() end, SetPosition = function() end, SetImage = function() end,
		GetButton = function() return nil end,
	}
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
		RunService = {
			RenderStepped = W.renderStepped, Heartbeat = W.heartbeat, Stepped = newSignal(),
			IsStudio = function() return true end, IsServer = function() return true end, IsClient = function() return true end,
			BindToRenderStep = function(_, name, _p, fn) W.renderBound = W.renderBound or {} W.renderBound[name] = fn end,
			UnbindFromRenderStep = function(_, name) if W.renderBound then W.renderBound[name] = nil end end,
		},
		LocalizationService = { RobloxLocaleId = options.locale or "es-es" },
		CollectionService = { AddTag = function() end, GetTagged = function() return {} end, HasTag = function() return false end },
		BadgeService = { AwardBadge = function(_, userId, id) W.badges = W.badges or {} table.insert(W.badges, id) return true end, UserHasBadgeAsync = function() return false end },
		TeleportService = {
			ReserveServer = function() error("TeleportService no funciona en Studio (simulado)") end,
			TeleportToPrivateServer = function() error("TeleportService no funciona en Studio (simulado)") end,
		},
		StarterGui = { SetCoreGuiEnabled = function() end, SetCore = function() end },
		UserInputService = W.UIS,
		ContextActionService = W.CAS,
		GuiService = { SelectedObject = nil, GetGuiInset = function() return roblox.Vector2.new(0, 36), roblox.Vector2.new(0, 0) end },
		SocialService = { PromptGameInvite = function() table.insert(W.prompts, "invite") end, CanSendGameInviteAsync = function() return true end },
	}
	W.mocks = mocks
	local camera = {
		ViewportSize = roblox.Vector2.new(options.width or 1280, options.height or 720),
		CFrame = roblox.CFrame.new(0, 5, 0),
		FieldOfView = 70,
		CameraType = roblox.Enum.CameraType.Custom,
		GetPropertyChangedSignal = function() return newSignal() end,
	}
	W.camera = camera
	-- Rayo contra todas las piezas consultables del Workspace (cajas orientadas)
	local function raycast(_, origin, dir, params)
		local ws = W.game:GetService("Workspace")
		local excluded = {}
		if params and params.FilterDescendantsInstances then
			for _, inst in params.FilterDescendantsInstances do
				excluded[unwrap(inst)] = true
			end
		end
		local best, bestT, bestN = nil, math.huge, nil
		local function visit(inst)
			if excluded[inst] then return end
			if inst:IsA("BasePart") and inst.CanQuery and inst.Transparency < 1.01 then
				local cf, half = inst.CFrame, inst.Size / 2
				local o = cf:PointToObjectSpace(origin)
				local d = cf:VectorToObjectSpace(dir)
				local tmin, tmax, nrm = 0, 1, nil
				local ok = true
				for _, ax in { "X", "Y", "Z" } do
					local oo, dd, h = o[ax], d[ax], half[ax]
					if math.abs(dd) < 1e-9 then
						if oo < -h or oo > h then ok = false break end
					else
						local t1, t2 = (-h - oo) / dd, (h - oo) / dd
						local sgn = -1
						if t1 > t2 then t1, t2 = t2, t1 sgn = 1 end
						if t1 > tmin then tmin = t1 nrm = { ax, sgn } end
						if t2 < tmax then tmax = t2 end
						if tmin > tmax then ok = false break end
					end
				end
				if ok and nrm and tmin < bestT then
					local lv = roblox.Vector3.new(nrm[1] == "X" and nrm[2] or 0, nrm[1] == "Y" and nrm[2] or 0, nrm[1] == "Z" and nrm[2] or 0)
					best, bestT, bestN = inst, tmin, cf:VectorToWorldSpace(lv)
				end
			end
			for _, c in inst:GetChildren() do visit(c) end
		end
		visit(ws)
		if not best then return nil end
		return { Instance = wrap(best), Position = origin + dir * bestT, Normal = bestN, Distance = dir.Magnitude * bestT }
	end
	overrides[wrap(W.game:GetService("Workspace"))] = { CurrentCamera = camera, Raycast = raycast }
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
			RaycastParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = roblox.Enum.RaycastFilterType.Exclude } end },
			warn = function(...) print("[warn]", ...) end,
			typeof = function(v) if type(v) == "table" and realOf[v] then return "Instance" end return typeof(v) end,
			require = requireModule,
		}
		for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "ColorSequence", "Font", "ColorSequenceKeypoint", "Rect", "NumberSequenceKeypoint", "BrickColor" } do
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
			UserId = userId, DisplayName = name, Name = name, LocaleId = options.locale or "es-es",
			MembershipType = roblox.Enum.MembershipType.None,
			IsFriendsWithAsync = function() return true end,
			IsInGroupAsync = function() return false end,
		}
		W.playersById[userId] = p
		table.insert(W.playerList, p)
		return p, real
	end

	-- Personaje mínimo: Model con HumanoidRootPart y Humanoid, colocado en Workspace
	function W.addCharacter(p, pos)
		local model = roblox.Instance.new("Model")
		model.Name = tostring(p)
		local rootPart = roblox.Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = roblox.Vector3.new(2, 2, 1)
		rootPart.CFrame = roblox.CFrame.new(pos)
		rootPart.Anchored = true
		rootPart.CanQuery = false
		rootPart.Parent = model
		local head = roblox.Instance.new("Part")
		head.Name = "Head"
		head.Size = roblox.Vector3.new(1, 1, 1)
		head.CanQuery = false
		head.Parent = model
		local hum = roblox.Instance.new("Humanoid")
		hum.Parent = model
		model.PrimaryPart = rootPart
		model.Parent = W.game:GetService("Workspace")
		local mp = wrap(model)
		overrides[mp] = {
			PivotTo = function(_, cf)
				rootPart.CFrame = cf
			end,
		}
		overrides[p].Character = mp
		W.root = rootPart
		return mp, rootPart
	end
	function W.teleport(pos)
		W.root.CFrame = roblox.CFrame.new(pos)
	end

	return W
end

return M
