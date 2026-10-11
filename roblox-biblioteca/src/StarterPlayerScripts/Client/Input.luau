--!strict
-- Controles: PC (como el original + F para lanzar), mando y botones táctiles (los crea Hud).
-- Aquí se definen las acciones de ctx.input y qué tecla las dispara.
--   PC: E/clic = usar · R = soltar (mantener: toda la pila) · F = lanzar · clic dcho. = el de arriba pasa abajo
--       Tab = lista · M = mapa · B = manual · P = menú · 1–5 = magia · Z = definitiva · Mayús = correr
--   Mando: RT = usar · X = soltar (mantener: todo) · Y = lanzar · RB = rotar · B = lista · cruceta + LB = magia 1–5
--          Select = mapa · L3 = correr · A = saltar (Roblox)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Aim = require(script.Parent:WaitForChild("Aim"))
local Panels = require(script.Parent:WaitForChild("Panels"))

local Input = {}

Input.running = false

local function humanoid(): Humanoid?
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- Velocidad según correr (solo si se ha desbloqueado con la llave verde)
function Input.applySpeed()
	local hum = humanoid()
	local st = Kit.ctx.state
	if hum then
		hum.WalkSpeed = if Input.running and st.run then Config.RUN_SPEED else Config.WALK_SPEED
	end
end

function Input.build(ctx: Kit.Ctx)
	local T = Kit.T

	-- Usar lo que marca la cruceta
	ctx.input.use = function()
		if ctx.panel then
			return
		end
		local t = Aim.target
		if not t then
			return
		end
		if not t.ok then
			ctx.toast(t.label, "error")
			return
		end
		if t.kind == "book" then
			ctx.act("pick", t.book)
		elseif t.kind == "slot" then
			ctx.act("place", t.slot)
		elseif t.kind == "interact" then
			local what = t.interact :: string
			if what == "letter" then
				ctx.act("readLetter")
				Panels.message(T("letter_title"), T("letter_body"))
			elseif what == "door" then
				ctx.act("exitDoor")
			elseif what == "map1" or what == "map2" then
				Panels.openMap(if what == "map2" then 2 else 1)
			elseif what == "crystal" then
				ctx.act("useCrystal")
			elseif string.sub(what, 1, 4) == "key_" then
				ctx.act("takeKey", string.sub(what, 5))
			elseif string.sub(what, 1, 6) == "chest_" then
				ctx.act("openChest", string.sub(what, 7))
			elseif string.sub(what, 1, 9) == "painting_" then
				ctx.toast(T("painting_" .. string.sub(what, 10)), "info")
			end
		end
	end
	ctx.input.drop = function()
		if not ctx.panel then
			ctx.act("drop")
		end
	end
	ctx.input.dropAll = function()
		if not ctx.panel then
			ctx.act("dropAll")
		end
	end
	ctx.input.throw = function()
		if ctx.panel then
			return
		end
		local cam = Workspace.CurrentCamera
		ctx.act("throw", if cam then cam.CFrame.LookVector else nil)
	end
	ctx.input.cycle = function()
		if not ctx.panel then
			ctx.act("cycle")
		end
	end
	local function toggle(name: string)
		if ctx.panel == name then
			ctx.closePanel()
		elseif not ctx.panel or ctx.panel == "list" or ctx.panel == "map" or ctx.panel == "manual" then
			if ctx.panels[name] then
				ctx.openPanel(name)
			end
		end
	end
	ctx.input.list = function()
		toggle("list")
	end
	ctx.input.map = function()
		if ctx.panel == "map" then
			ctx.closePanel()
		elseif not ctx.panel then
			Panels.openMap()
		end
	end
	ctx.input.manual = function()
		toggle("manual")
	end
	ctx.input.menu = function()
		toggle("menu")
	end
	ctx.input.cast = function(i: number)
		if ctx.panel then
			return
		end
		if ctx.input.castSkill then
			ctx.input.castSkill(i)
		end
	end
	ctx.input.ultimate = function()
		if not ctx.panel then
			ctx.act("ultimate")
		end
	end
	ctx.input.toggleRun = function()
		Input.running = not Input.running
		Input.applySpeed()
	end

	-------------------------------------------------------------------
	-- Teclado, ratón y mando
	-------------------------------------------------------------------
	local K = Enum.KeyCode
	local dropDown: number? = nil
	local dropAllDone = false
	local NUMBERS = { [K.One] = 1, [K.Two] = 2, [K.Three] = 3, [K.Four] = 4, [K.Five] = 5 }
	local PAD_SPELL = { [K.DPadUp] = 1, [K.DPadRight] = 2, [K.DPadDown] = 3, [K.DPadLeft] = 4, [K.ButtonL1] = 5 }

	UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		local key = io.KeyCode
		if io.UserInputType == Enum.UserInputType.Gamepad1 then
			ctx.gamepad = true
		end
		-- Tab y P funcionan aunque haya una ventana abierta (para cerrarla)
		if key == K.Tab or key == K.ButtonB then
			ctx.input.list()
			return
		elseif key == K.P then
			ctx.input.menu()
			return
		elseif key == K.M or key == K.ButtonSelect then
			ctx.input.map()
			return
		elseif key == K.B and not processed then
			ctx.input.manual()
			return
		end
		if processed then
			return
		end
		if io.UserInputType == Enum.UserInputType.MouseButton1 or key == K.E or key == K.ButtonR2 then
			ctx.input.use()
		elseif io.UserInputType == Enum.UserInputType.MouseButton2 or key == K.ButtonR1 then
			ctx.input.cycle()
		elseif key == K.R or key == K.ButtonX then
			dropDown = os.clock()
			dropAllDone = false
		elseif key == K.F or key == K.ButtonY then
			ctx.input.throw()
		elseif NUMBERS[key] or PAD_SPELL[key] then
			ctx.input.cast(NUMBERS[key] or PAD_SPELL[key])
		elseif key == K.Z then
			ctx.input.ultimate()
		elseif key == K.LeftShift or key == K.RightShift then
			Input.running = true
			Input.applySpeed()
		elseif key == K.ButtonL3 then
			ctx.input.toggleRun()
		end
	end)

	UserInputService.InputEnded:Connect(function(io: InputObject)
		local key = io.KeyCode
		if key == K.R or key == K.ButtonX then
			if dropDown and not dropAllDone then
				if os.clock() - dropDown >= Config.HOLD_DROP_ALL then
					ctx.input.dropAll()
				else
					ctx.input.drop()
				end
			end
			dropDown = nil
		elseif key == K.LeftShift or key == K.RightShift then
			Input.running = false
			Input.applySpeed()
		end
	end)

	-- Mantener R: suelta toda la pila sin esperar a soltar la tecla
	table.insert(ctx.tickers, function()
		if dropDown and not dropAllDone and os.clock() - dropDown >= Config.HOLD_DROP_ALL then
			dropAllDone = true
			ctx.input.dropAll()
		end
	end)

	-- Nombre de la tecla de cada acción según el dispositivo (para las pistas)
	ctx.keyName = function(action: string): string
		if ctx.touch then
			local names = { use = T("btn_use"), map = T("btn_map"), list = T("btn_list"), manual = T("btn_manual"), menu = T("btn_menu"), ultimate = "Z" }
			return names[action] or action
		elseif ctx.gamepad then
			local names = { use = "RT", map = "Select", list = "B", manual = "Start", menu = "Start", ultimate = "Z" }
			return names[action] or action
		end
		local names = { use = "E", map = "M", list = "Tab", manual = "B", menu = "P", ultimate = "Z" }
		return names[action] or action
	end
end

return Input
