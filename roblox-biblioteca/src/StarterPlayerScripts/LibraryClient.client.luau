--!strict
-- Cliente de Estanterías Hechizadas: arranca la interfaz, recibe del servidor la foto de los libros, los
-- cambios (deltas), el estado y los avisos, y pide acciones. El servidor decide; aquí solo se muestra.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Codec = require(ReplicatedStorage:WaitForChild("Codec"))
local Client = script.Parent:WaitForChild("Client")
local Kit = require(Client:WaitForChild("Kit"))
local Books = require(Client:WaitForChild("Books"))
local Aim = require(Client:WaitForChild("Aim"))
local Hud = require(Client:WaitForChild("Hud"))
local Panels = require(Client:WaitForChild("Panels"))
local Input = require(Client:WaitForChild("Input"))
local MapArt = require(Client:WaitForChild("MapArt"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LibRemotes")
local Action = remotes:WaitForChild("Action") :: RemoteFunction
local ctx = Kit.ctx
local T = Kit.T

-- Libera las teclas Tab (lista de jugadores) y 1–5 (mochila) para el juego
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- Idioma inicial: el de Roblox del jugador
local locale = string.lower(player.LocaleId or "es")
ctx.lang = if string.sub(locale, 1, 2) == "es" then "es" else "en"
ctx.touch = Kit.isTouch()
ctx.gamepad = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled

---------------------------------------------------------------------
-- Pantalla
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "LibraryGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromOffset(1280, 720)
root.Parent = gui
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
ctx.gui = gui
ctx.root = root

local function rescale()
	local vp = Kit.viewport()
	local s = math.min(vp.X / 1280, vp.Y / 720)
	if ctx.touch then
		s = math.max(s, 0.55)
	end
	ctx.scale = s
	uiScale.Scale = s
	root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
end
rescale()
local cam = Workspace.CurrentCamera
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

---------------------------------------------------------------------
-- Acciones y ventanas
---------------------------------------------------------------------
ctx.act = function(name: string, a: any?, b: any?, c: any?): (boolean, { [string]: any }?)
	local ok, okRes, key, params, extra = pcall(function()
		return Action:InvokeServer(name, a, b, c)
	end)
	if not ok then
		return false, nil
	end
	if key then
		ctx.toast(T(key, params), if okRes then "success" else "error")
	end
	if extra and extra.sound then
		Kit.sound(extra.sound)
	end
	return okRes == true, extra
end

ctx.openPanel = function(name: string)
	if ctx.panel and ctx.panel ~= name then
		ctx.closePanel()
	end
	local p = ctx.panels[name]
	if not p then
		return
	end
	ctx.panel = name
	Aim.hide()
	p.open()
	UserInputService.MouseIconEnabled = true
end

ctx.closePanel = function()
	local name = ctx.panel
	if not name then
		return
	end
	ctx.panel = nil
	local p = ctx.panels[name]
	if p and p.close then
		p.close()
	end
	UserInputService.MouseIconEnabled = false
end

Books.lang = ctx.lang
Books.init()
Input.build(ctx)
Hud.build(ctx)
Panels.build(ctx)
UserInputService.MouseIconEnabled = false

local function refreshAll()
	for _, f in ctx.refreshers do
		f()
	end
end

---------------------------------------------------------------------
-- Tablones con el mapa en la pared
---------------------------------------------------------------------
local boardGuis: { SurfaceGui } = {}
local function drawBoards()
	for _, g in boardGuis do
		g:Destroy()
	end
	table.clear(boardGuis)
	local lib = Workspace:FindFirstChild("Library")
	local maps = lib and lib:FindFirstChild("maps")
	if not maps or not Books.def or Books.def.name ~= "main" then
		return
	end
	for floor = 1, 2 do
		local board = maps:FindFirstChild("MapBoard" .. floor)
		if board and board:IsA("BasePart") then
			local sg = Instance.new("SurfaceGui")
			sg.Name = "MapBoardGui" .. floor
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 50
			sg.LightInfluence = 0.5
			sg.ResetOnSpawn = false
			sg.Adornee = board
			local title = Instance.new("TextLabel")
			title.BackgroundTransparency = 1
			title.Size = UDim2.fromScale(1, 0.07)
			title.Text = T("map_floor", { f = floor })
			title.TextScaled = true
			title.Font = Enum.Font.Garamond
			title.TextColor3 = Kit.C.ink
			title.Parent = sg
			local canvas = Instance.new("Frame")
			canvas.Name = "Canvas"
			canvas.Size = UDim2.fromScale(0.94, 0.9)
			canvas.Position = UDim2.fromScale(0.03, 0.08)
			canvas.BorderSizePixel = 0
			canvas.Parent = sg
			MapArt.draw(canvas, floor, Books.sectionDone, { stairs = T("map_stairs"), door = T("map_door"), crystal = T("map_crystal") })
			sg.Parent = player:FindFirstChild("PlayerGui")
			table.insert(boardGuis, sg)
		end
	end
end

---------------------------------------------------------------------
-- Avisos de filas y placas (los calcula el cliente con las mismas reglas que el servidor)
---------------------------------------------------------------------
Books.onRow = function(_rowId: number, correct: boolean)
	if correct then
		Kit.sound("row")
		ctx.toast(T("n_row"), "row")
	end
end
Books.onSection = function(code: string, done: boolean)
	if done then
		Kit.sound("plate", 1.3)
		ctx.toast(T("n_section", { code = code }), "success")
	end
	drawBoards()
end

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local onSnapshot = remotes:WaitForChild("Snapshot") :: RemoteEvent
onSnapshot.OnClientEvent:Connect(function(libName: string, encoded: string)
	local def = Layout.get(libName)
	local decoded = Codec.decodeAll(encoded, #def.books)
	local locs: { Codec.Loc } = {}
	for id = 1, #def.books do
		locs[id] = if decoded then decoded[id] else { k = 0 }
	end
	Books.load(def, locs)
	drawBoards()
end)

local onDelta = remotes:WaitForChild("Delta") :: RemoteEvent
onDelta.OnClientEvent:Connect(function(moves: { any })
	for _, m in moves do
		local anim = m[3]
		Books.move(m[1], Codec.decode(m[2]), if anim ~= "" then anim else nil, m[4])
	end
end)

local onState = remotes:WaitForChild("State") :: RemoteEvent
onState.OnClientEvent:Connect(function(state: { [string]: any })
	ctx.state = state
	refreshAll()
	Input.applySpeed()
end)

local onNotify = remotes:WaitForChild("Notify") :: RemoteEvent
onNotify.OnClientEvent:Connect(function(kind: string, key: string, params: { [string]: any }?)
	local p: { [string]: any } = params or {}
	if p.key == "B" then
		p.key = ctx.keyName("manual")
	end
	if kind == "popup" then
		Panels.message(T(p.title or key), T(key, p))
	else
		ctx.toast(T(key, p), kind)
		if kind == "point" then
			Kit.sound("row", 1.5)
		end
	end
end)

---------------------------------------------------------------------
-- Bucle: cruceta cada fotograma, etiquetas de lomos 4 veces por segundo
---------------------------------------------------------------------
local labelT = 0
RunService.RenderStepped:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local st = ctx.state
	if (st.mode == "main" or st.mode == "special") and not ctx.panel then
		local exclude: { Instance } = {}
		if player.Character then
			table.insert(exclude, player.Character)
		end
		Aim.update(camera.CFrame, exclude)
	else
		Aim.hide()
	end
	for _, f in ctx.tickers do
		f(dt)
	end
	labelT += dt
	if labelT > 0.25 then
		labelT = 0
		Books.updateLabels(camera.CFrame)
	end
end)

-- Todo conectado: pide al servidor la foto de la biblioteca y el estado
ctx.act("ready")
