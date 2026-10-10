--[[
	GameClient (LocalScript en StarterPlayerScripts) de «AeroCarga España».
	Todo es 2D: el mapa de España ocupa la pantalla, el HUD va encima y las ventanas se abren
	sobre el mapa. Los módulos están en la carpeta UI. Al cambiar de idioma se reconstruye todo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalizationService = game:GetService("LocalizationService")
local Workspace = game:GetService("Workspace")

local UI = script.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local MapView = require(UI:WaitForChild("MapView"))
local Hud = require(UI:WaitForChild("Hud"))
local Screens = require(UI:WaitForChild("Screens"))
local FleetPanel = require(UI:WaitForChild("FleetPanel"))
local CargoPanel = require(UI:WaitForChild("CargoPanel"))
local PilotsPanel = require(UI:WaitForChild("PilotsPanel"))
local SpainPanel = require(UI:WaitForChild("SpainPanel"))
local MissionsPanel = require(UI:WaitForChild("MissionsPanel"))
local ShopPanel = require(UI:WaitForChild("ShopPanel"))
local SystemPanels = require(UI:WaitForChild("SystemPanels"))
local ContractsPanel = require(UI:WaitForChild("ContractsPanel"))
local IpoPanel = require(UI:WaitForChild("IpoPanel"))

local remotes = ReplicatedStorage:WaitForChild("CargoRemotes")
local actionRemote = remotes:WaitForChild("Action")
local stateRemote = remotes:WaitForChild("State")
local notifyRemote = remotes:WaitForChild("Notify")

local ctx = Kit.ctx
local C = Kit.C
local T = Kit.T
local create = Kit.create
local DESIGN_WIDTH = 1280

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

function ctx.detectLang(): string
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if ok and type(locale) == "string" and string.sub(locale, 1, 2) == "es" then
		return "es"
	end
	return "en"
end
ctx.lang = ctx.detectLang()
ctx.started = false

---------------------------------------------------------------------
-- Acciones al servidor (los textos llegan como claves y se traducen aquí)
---------------------------------------------------------------------
local MONEY = { net = true, value = true, amount = true, fuel = true, cost = true, offline = true }
local function translate(params: { [string]: any }?): { [string]: any }
	local out = {}
	for k, v in (params or {}) :: { [string]: any } do
		if MONEY[k] and type(v) == "number" then
			out[k] = Kit.fmtMoney(v)
		elseif k == "region" then
			out[k] = T("r_" .. tostring(v))
		elseif k == "plane" then
			out[k] = Kit.planeName(tostring(v))
		elseif k == "upgrade" then
			out[k] = T("up_" .. tostring(v))
		elseif k == "item" then
			out[k] = T("item_" .. tostring(v))
		elseif k == "company" then
			out[k] = T("company_" .. tostring(v))
		elseif k == "good" then
			out[k] = Kit.goodName(tostring(v))
		elseif k == "event" then
			out[k] = Kit.eventName(tostring(v))
		else
			out[k] = v
		end
	end
	return out
end
ctx.translate = translate

function ctx.act(action: string, a: any?, b: any?, c: any?): (boolean, any)
	local ok, key, params, extra = actionRemote:InvokeServer(action, a, b, c)
	if key then
		ctx.toast(T(key, translate(params)), ok and "success" or "error")
	end
	if ok and extra and extra.money then
		Kit.playSound("money")
	end
	return ok, extra
end

---------------------------------------------------------------------
-- Construcción de la interfaz
---------------------------------------------------------------------
local gui = create("ScreenGui", { Name = "AeroCargaUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1, Parent = playerGui })
Kit.setupSounds(gui)
local rootScale: UIScale
local root: Frame
local pendingWelcome: any = nil

local function updateScale()
	if not rootScale then
		return
	end
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or DESIGN_WIDTH
	local height = camera and camera.ViewportSize.Y or 720
	local s = math.clamp(width / DESIGN_WIDTH, 0.55, 1.6)
	ctx.compact = height / s < 640
	rootScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	ctx.scale = s
end

local function build()
	for _, k in gui:GetChildren() do
		if not k:IsA("Sound") then
			k:Destroy()
		end
	end
	table.clear(ctx.tickers)
	table.clear(ctx.refreshers)
	table.clear(ctx.targets)
	ctx.panel = nil

	root = create("Frame", { Parent = gui, BackgroundColor3 = C.sea, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Name = "Root" }, {
		create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(146, 212, 246), Color3.fromRGB(96, 182, 232)), Rotation = 90 }),
	})
	rootScale = create("UIScale", { Parent = root })

	local mapArea = create("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 1, -180) })
	MapView.build(mapArea)
	Hud.build(root)
	Screens.buildPanels(root, {
		fleet = FleetPanel.build, cargo = CargoPanel.build, pilots = PilotsPanel.build, spain = SpainPanel.build,
		missions = MissionsPanel.build, shop = ShopPanel.build, ranking = SystemPanels.ranking, settings = SystemPanels.settings,
		contracts = ContractsPanel.build, ipo = IpoPanel.build,
	})
	Screens.landing(root)
	Screens.tutorial(root, root)
	Screens.buildOverlay(root)

	-- Aviso si el servidor no contesta (antes la pantalla se quedaba vacía sin explicación)
	local waiting = Kit.title(root, "⏳ " .. T("connecting"), 24, C.white, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 60),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 90, Visible = ctx.state == nil, TextWrapped = true,
	})
	table.insert(ctx.refreshers, function()
		waiting.Visible = false
	end)
	task.delay(10, function()
		if ctx.state == nil and waiting.Parent then
			waiting.Text = "⚠️ " .. T("no_server")
		end
	end)

	if not ctx.started then
		Screens.title(root, function()
			ctx.started = true
			if ctx.state and ctx.state.tutorial == 0 then
				Screens.tutorialWelcome()
			elseif pendingWelcome then
				Screens.welcomeBack(pendingWelcome)
			end
			pendingWelcome = nil
		end)
	end
	updateScale()
	ctx.refreshAll()
end

function ctx.refreshAll()
	if not ctx.state then
		return
	end
	for _, fn in ctx.refreshers do
		fn()
	end
	if ctx.refreshPanel then
		ctx.refreshPanel()
	end
end

function ctx.rebuild()
	build()
end

---------------------------------------------------------------------
-- Conexiones
---------------------------------------------------------------------
stateRemote.OnClientEvent:Connect(function(newState: any)
	local first = ctx.state == nil
	ctx.state = newState
	ctx.stateClock = os.clock()
	if first and newState.settings and newState.settings.lang ~= "" and newState.settings.lang ~= ctx.lang then
		ctx.lang = newState.settings.lang
		build()
		return
	end
	ctx.refreshAll()
end)

notifyRemote.OnClientEvent:Connect(function(kind: string, key: string, params: { [string]: any }?)
	local p = params or {}
	if kind == "landed" then
		if ctx.floatMoney then
			ctx.floatMoney(p.code, p.net, p)
		end
		Kit.playSound("money")
	elseif kind == "level" then
		Screens.levelUp(p.level)
	elseif kind == "welcome" then
		if ctx.started then
			Screens.welcomeBack(p)
		else
			pendingWelcome = p
		end
	else
		ctx.toast(T(key, translate(p)), kind)
	end
end)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local accum = 0
RunService.RenderStepped:Connect(function(dt: number)
	accum += dt
	if accum < 0.2 then
		return
	end
	accum = 0
	for _, fn in ctx.tickers do
		fn()
	end
end)

build()
