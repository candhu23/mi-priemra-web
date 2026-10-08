--[[
	GameClient (LocalScript en StarterPlayer > StarterPlayerScripts)
	Toda la interfaz de «Air Cargo Empire». El servidor manda: aquí solo se muestra
	el estado y se piden acciones. Cada pantalla se construye en su propia función
	(build*Page) para no pasar del límite de 200 variables locales por función.
	Al cambiar de idioma se reconstruye toda la interfaz.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalizationService = game:GetService("LocalizationService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))
local remotes = ReplicatedStorage:WaitForChild("CargoRemotes")
local actionRemote = remotes:WaitForChild("Action")
local stateRemote = remotes:WaitForChild("State")
local notifyRemote = remotes:WaitForChild("Notify")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local C = Config.Colors

local FONT_HEAD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local FONT_BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local DESIGN_WIDTH = 1280

---------------------------------------------------------------------
-- Estado del cliente
---------------------------------------------------------------------
local state: any = nil
local stateClock = os.clock()
local lang = "en"
local currentPage = "map"
local tabs = { fleet = "mine", pilots = "roster", company = "overview" }
local selectedPlaneId: number? = nil
local selectedPilot = 0 -- 0 = tú
local showLabels = true

local function T(key: string, params: { [string]: any }?): string
	return Lang.t(lang, key, params)
end

local function detectLang(): string
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if ok and type(locale) == "string" and string.sub(locale, 1, 2) == "es" then
		return "es"
	end
	return "en"
end
lang = detectLang()

-- Hora del servidor estimada (para las cuentas atrás)
local function serverNow(): number
	if not state then
		return os.time()
	end
	return state.now + (os.clock() - stateClock)
end

---------------------------------------------------------------------
-- Formatos
---------------------------------------------------------------------
local function fmtInt(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (n < 0 and "-" or "") .. out
end

local function fmtMoney(n: number): string
	local a = math.abs(n)
	local sign = n < 0 and "-" or ""
	if a >= 1e9 then
		return string.format("%s$%.2fB", sign, a / 1e9)
	elseif a >= 1e6 then
		return string.format("%s$%.2fM", sign, a / 1e6)
	elseif a >= 1e5 then
		return string.format("%s$%.1fK", sign, a / 1e3)
	end
	return sign .. "$" .. fmtInt(a)
end

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

local function fmtTons(t: number): string
	if t == math.floor(t) then
		return tostring(t) .. " t"
	end
	return string.format("%.1f t", t)
end

local function registration(id: number): string
	return string.format("AC-%03d", id)
end

---------------------------------------------------------------------
-- Ayudantes de interfaz
---------------------------------------------------------------------
local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, thickness: number?): UIStroke
	return create("UIStroke", { Color = color, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(l: number, r: number?, t: number?, b: number?): UIPadding
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l),
		PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l),
	})
end

local function listLayout(horizontal: boolean, gap: number, align: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return create("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

local function tween(obj: Instance, seconds: number, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- Texto. size en unidades de diseño (la interfaz entera se escala con un UIScale)
local function label(parent: Instance?, text: string, size: number, color: Color3?, font: Font?, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = {
		Parent = parent, BackgroundTransparency = 1, Text = text, TextSize = size,
		TextColor3 = color or C.text, FontFace = font or FONT_BODY,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, size + 6), TextTruncate = Enum.TextTruncate.AtEnd,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return create("TextLabel", p)
end

-- Sustitutos de los iconos mientras no se suba assets/iconos.png
local ICON_TEXT = {
	menu = "≡", map = "◎", plane = "✈", ["plane-takeoff"] = "✈", ["plane-landing"] = "✈", users = "☺",
	["user-round"] = "☺", ["building-2"] = "▦", settings = "⚙", wrench = "✎", fuel = "⛽", landmark = "$",
	star = "★", package = "▣", globe = "◍", warehouse = "⌂", ["trending-up"] = "↗", ["cloud-rain"] = "☂",
	snowflake = "❄", ["cloud-lightning"] = "ϟ", sun = "☀", clock = "◷", coins = "$", banknote = "$",
	trophy = "♛", languages = "A", x = "✕", check = "✓", lock = "■", award = "✪", ["refresh-cw"] = "↻",
	zap = "ϟ", ["arrow-right"] = "→", ["map-pin"] = "●", ["shopping-cart"] = "⊕", ["chart-column"] = "▥",
	["volume-2"] = "♪", ["volume-x"] = "♪", weight = "◆", route = "⇢", gauge = "◔",
}

local function icon(parent: Instance?, name: string, size: number, color: Color3?, props: { [string]: any }?): GuiObject
	local index = Config.Icons[name]
	local p: { [string]: any } = { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) }
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	if Config.Assets.icons ~= "" and index then
		p.Image = Config.Assets.icons
		p.ImageRectOffset = Vector2.new((index % 8) * 128, math.floor(index / 8) * 128)
		p.ImageRectSize = Vector2.new(128, 128)
		p.ImageColor3 = color or C.text
		return create("ImageLabel", p)
	end
	p.Text = ICON_TEXT[name] or "•"
	p.TextColor3 = color or C.text
	p.TextSize = math.floor(size * 0.8)
	p.FontFace = FONT_BOLD
	return create("TextLabel", p)
end

-- Ilustración del avión (assets/aviones.png) o sustituto
local function planeArt(parent: Instance, modelId: string, props: { [string]: any }?): GuiObject
	local model = Config.PlaneById[modelId]
	local p: { [string]: any } = { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	if Config.Assets.planes ~= "" then
		p.Image = Config.Assets.planes
		p.ImageRectOffset = Vector2.new((model.sheet % 2) * 512, math.floor(model.sheet / 2) * 256)
		p.ImageRectSize = Vector2.new(512, 256)
		p.ScaleType = Enum.ScaleType.Fit
		return create("ImageLabel", p)
	end
	local holder = create("Frame", p)
	icon(holder, "plane", 64 + model.sheet * 10, C.muted, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	})
	return holder
end

-- Sonidos integrados en Roblox (no hace falta subir nada)
local sounds: { [string]: Sound } = {}
local function playSound(kind: string)
	if state and state.settings and state.settings.muted then
		return
	end
	local s = sounds[kind]
	if s then
		s:Play()
	end
end

local BUTTON_STYLES = {
	primary = { bg = C.accent, text = C.bg },
	blue = { bg = C.blue, text = C.text },
	ghost = { bg = C.cardHi, text = C.text },
	danger = { bg = Color3.fromRGB(70, 28, 36), text = C.red },
}

local function button(parent: Instance?, text: string, style: string, size: UDim2, onClick: () -> ()): TextButton
	local st = BUTTON_STYLES[style] or BUTTON_STYLES.ghost
	local btn = create("TextButton", {
		Parent = parent, Size = size, BackgroundColor3 = st.bg, Text = text, TextColor3 = st.text,
		FontFace = FONT_BOLD, TextSize = 18, AutoButtonColor = false, TextTruncate = Enum.TextTruncate.AtEnd,
	}, { corner(10), padding(8, 8, 0, 0) })
	local scale = create("UIScale", { Parent = btn })
	btn:SetAttribute("Enabled", true)
	btn:SetAttribute("Style", style)
	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("Enabled") ~= false then
			tween(scale, 0.1, { Scale = 1.03 })
		end
	end)
	btn.MouseLeave:Connect(function()
		tween(scale, 0.1, { Scale = 1 })
	end)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Enabled") == false then
			playSound("error")
			return
		end
		playSound("click")
		scale.Scale = 0.94
		tween(scale, 0.15, { Scale = 1 })
		onClick()
	end)
	return btn
end

-- Activa o desactiva un botón (gris = no disponible) y cambia su texto
local function setButton(btn: TextButton, text: string?, enabled: boolean)
	if text and btn.Text ~= text then
		btn.Text = text
	end
	btn:SetAttribute("Enabled", enabled)
	local st = BUTTON_STYLES[btn:GetAttribute("Style") :: string] or BUTTON_STYLES.ghost
	btn.BackgroundColor3 = enabled and st.bg or C.cardHi
	btn.TextColor3 = enabled and st.text or C.muted
end

local function card(parent: Instance?, props: { [string]: any }?): Frame
	local p: { [string]: any } = { Parent = parent, BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 100) }
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return create("Frame", p, { corner(14), stroke(C.stroke, 1.5) })
end

-- Barra de progreso: devuelve el relleno
local function progressBar(parent: Instance, props: { [string]: any }, color: Color3): Frame
	local p: { [string]: any } = { Parent = parent, BackgroundColor3 = C.bg, Size = UDim2.new(1, 0, 0, 8) }
	for k, v in props do
		p[k] = v
	end
	local back = create("Frame", p, { corner(4) })
	return create("Frame", { Parent = back, BackgroundColor3 = color, Size = UDim2.fromScale(0, 1) }, { corner(4) })
end

-- Píldora de estado (texto en mayúsculas sobre fondo de color suave)
local function badge(parent: Instance?, text: string, color: Color3, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = {
		Parent = parent, BackgroundColor3 = color, BackgroundTransparency = 0.82, Text = text, TextColor3 = color,
		FontFace = FONT_BOLD, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26),
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return create("TextLabel", p, { corner(8), padding(10, 10, 0, 0) })
end

-- Sincroniza una lista de tarjetas con los datos: crea, actualiza y borra lo que sobra
type Entry = { root: GuiObject, update: (any) -> () }
local function syncList(cache: { [any]: Entry }, items: { any }, keyOf: (any) -> any, build: (any) -> Entry)
	local seen = {}
	for i, item in items do
		local key = keyOf(item)
		seen[key] = true
		local entry = cache[key]
		if not entry then
			entry = build(item)
			cache[key] = entry
		end
		entry.root.LayoutOrder = i
		entry.update(item)
	end
	for key, entry in cache do
		if not seen[key] then
			entry.root:Destroy()
			cache[key] = nil
		end
	end
end

---------------------------------------------------------------------
-- Reglas que el cliente necesita para mostrar estimaciones
-- (las mismas que el servidor; el servidor vuelve a comprobarlo todo)
---------------------------------------------------------------------
local function playerLevel(): number
	return state and state.level or 1
end

local function findPilot(id: number): any
	for _, p in state.pilots do
		if p.id == id then
			return p
		end
	end
	return nil
end

local function pilotBusy(id: number): boolean
	for _, p in state.planes do
		if p.flight and p.flight.pilot == id then
			return true
		end
	end
	return false
end

local function flyBlock(plane: any, load: any): string?
	local model = Config.PlaneById[plane.model]
	local cargo = Config.CargoById[load.cargo]
	if plane.flight then
		return "err_plane_busy"
	elseif plane.condition < Config.REPAIR_BLOCK then
		return "err_needs_repair"
	elseif model.license and not state.licenses[model.license] then
		return "err_plane_license"
	elseif load.weight > model.cap then
		return "err_too_heavy"
	elseif load.dist > model.range then
		return "err_out_of_range"
	elseif cargo.license and not state.licenses[cargo.license] then
		return "err_cargo_license"
	elseif cargo.planes and not table.find(cargo.planes, plane.model) then
		return "err_cargo_plane"
	end
	return nil
end

local function quote(plane: any, load: any, pilotId: number): (number, number, number, number)
	local model = Config.PlaneById[plane.model]
	local bonus = 0
	local pilot = pilotId > 0 and findPilot(pilotId)
	if pilot then
		bonus = Config.Rarities[Config.RarityIndex[pilot.rarity]].bonus
	end
	local gross = math.floor(load.gross * (1 + 0.04 * state.upgrades.broker) * (1 + bonus) * (state.passes.x2 and 2 or 1))
	local fuel = math.floor(load.dist * model.burn * state.fuelPrice)
	local fee = pilot and math.floor(gross * Config.PILOT_FEE) or 0
	local w = Config.WeatherById[state.weather[load.from] or "clear"]
	return gross, fuel, fee, Config.flightSeconds(load.dist, model.speed, w.time)
end

local function planeStatus(plane: any): (string, Color3)
	if plane.flight then
		if plane.flight.cargo == "ferry" then
			return T("st_ferry"), C.purple
		end
		return T("st_enroute"), C.sky
	elseif plane.condition < Config.REPAIR_BLOCK then
		return T("st_repair"), C.red
	end
	return T("st_idle"), C.green
end

local function planeWhere(plane: any): string
	if plane.flight then
		return string.format("%s → %s · %s", plane.flight.from, plane.flight.to, fmtTime(plane.flight.endT - serverNow()))
	end
	local a = Config.AirportByCode[plane.airport]
	return T("at_airport", { code = a.code, city = a.city })
end

---------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------
local toast: (string, string) -> ()
local openModal: (string, (Frame) -> (), { { text: string, style: string, onClick: (() -> ())? } }?) -> ()
local closeModal: () -> ()
local showPage: (string) -> ()
local refreshAll: () -> ()
local rebuild: () -> ()

local MONEY_PARAMS = { net = true, value = true, fuel = true, cost = true }
local function translateParams(params: { [string]: any }?): { [string]: any }
	local out = {}
	for k, v in (params or {}) :: { [string]: any } do
		if MONEY_PARAMS[k] and type(v) == "number" then
			out[k] = fmtMoney(v)
		elseif k == "region" then
			out[k] = T("r_" .. tostring(v))
		elseif k == "license" then
			out[k] = T("lic_" .. tostring(v))
		else
			out[k] = v
		end
	end
	return out
end

local function act(action: string, a: any?, b: any?, c: any?): (boolean, any)
	local ok, key, params, extra = actionRemote:InvokeServer(action, a, b, c)
	if key then
		toast(T(key, translateParams(params)), ok and "success" or "error")
	end
	if ok and extra and extra.money then
		playSound("money")
	end
	return ok, extra
end

---------------------------------------------------------------------
-- Pantallas (ScreenGui separados para que las capas no se mezclen)
---------------------------------------------------------------------
local mainGui = create("ScreenGui", { Name = "AirCargoUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1, Parent = playerGui })
local overlayGui = create("ScreenGui", { Name = "AirCargoOverlay", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10, Parent = playerGui })
for kind, info in { click = { 1.6, 0.25 }, money = { 1.25, 0.5 }, error = { 0.6, 0.4 }, level = { 0.9, 0.6 } } do
	sounds[kind] = create("Sound", { Parent = mainGui, SoundId = "rbxasset://sounds/electronicpingshort.wav", PlaybackSpeed = info[1], Volume = info[2] })
end

local scales: { UIScale } = {}
local function rootFrame(parent: Instance): Frame
	local f = create("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	table.insert(scales, create("UIScale", { Parent = f }))
	return f
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or DESIGN_WIDTH
	local s = math.clamp(width / DESIGN_WIDTH, 0.6, 1.6)
	for _, sc in scales do
		sc.Scale = s
		local holder = sc.Parent :: Frame
		holder.Size = UDim2.fromScale(1 / s, 1 / s)
	end
end

-- Funciones que se llaman 5 veces por segundo (cuentas atrás, aviones del mapa)
local tickers: { () -> () } = {}
local pageRefresh: { [string]: () -> () } = {}
local pageFrames: { [string]: Frame } = {}

---------------------------------------------------------------------
-- Avisos (toasts) y ventana modal
---------------------------------------------------------------------
local toastHolder: Frame
local KIND_STYLE = {
	success = { C.green, "check" }, money = { C.green, "banknote" }, error = { C.red, "info" },
	info = { C.sky, "info" }, level = { C.accent, "trophy" },
}

function toast(text: string, kind: string)
	if not toastHolder then
		return
	end
	local style = KIND_STYLE[kind] or KIND_STYLE.info
	local t = card(toastHolder, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.cardHi, LayoutOrder = -math.floor(os.clock() * 100),
	})
	padding(14, 14, 10, 10).Parent = t
	create("Frame", { Parent = t, BackgroundColor3 = style[1], Size = UDim2.new(0, 4, 1, 0), Position = UDim2.fromOffset(-14, 0) })
	icon(t, style[2], 22, style[1], { Position = UDim2.fromOffset(0, 2) })
	label(t, text, 17, C.text, FONT_BOLD, {
		Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
	})
	if kind == "error" then
		playSound("error")
	elseif kind == "money" then
		playSound("money")
	elseif kind == "level" then
		playSound("level")
	end
	local kids = toastHolder:GetChildren()
	if #kids > 6 then
		for _, k in kids do
			if k:IsA("Frame") and k ~= t then
				k:Destroy()
				break
			end
		end
	end
	task.delay(4.5, function()
		if t.Parent then
			t:Destroy()
		end
	end)
end

local modalDim: Frame
local modalCard: Frame
local modalBody: Frame
local modalTitle: TextLabel
local modalButtons: Frame

function closeModal()
	if modalDim then
		modalDim.Visible = false
	end
end

function openModal(title: string, fill: (Frame) -> (), buttons: { { text: string, style: string, onClick: (() -> ())? } }?)
	modalTitle.Text = title
	for _, k in modalBody:GetChildren() do
		k:Destroy()
	end
	for _, k in modalButtons:GetChildren() do
		if k:IsA("GuiButton") then
			k:Destroy()
		end
	end
	fill(modalBody)
	local list: { { text: string, style: string, onClick: (() -> ())? } } = buttons or { { text = T("btn_close"), style = "ghost" } }
	for i, b in list do
		local btn = button(modalButtons, b.text, b.style, UDim2.fromOffset(200, 48), function()
			closeModal()
			if b.onClick then
				b.onClick()
			end
		end)
		btn.LayoutOrder = i
	end
	modalDim.Visible = true
	modalCard.Position = UDim2.new(0.5, 0, 0.5, 20)
	tween(modalCard, 0.18, { Position = UDim2.fromScale(0.5, 0.5) })
end

---------------------------------------------------------------------
-- Pestañas dentro de una pantalla
---------------------------------------------------------------------
local function tabRow(parent: Instance, list: { { id: string, key: string, icon: string } }, group: string, onChange: () -> ()): Frame
	local row = create("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52) }, {
		listLayout(true, 12),
	})
	local buttons = {}
	local function paint()
		for id, b in buttons do
			local active = tabs[group] == id
			b.BackgroundColor3 = active and C.cardHi or C.card
			b:FindFirstChildOfClass("UIStroke").Color = active and C.accent or C.stroke
			b:FindFirstChild("Line").Visible = active
		end
	end
	for i, t in list do
		local b = create("TextButton", {
			Parent = row, LayoutOrder = i, Size = UDim2.new(1 / #list, -12 * (#list - 1) / #list, 1, 0),
			BackgroundColor3 = C.card, Text = "", AutoButtonColor = false,
		}, { corner(12), stroke(C.stroke, 1.5) })
		local inner = create("Frame", { Parent = b, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
			listLayout(true, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center), padding(18, 12, 0, 0),
		})
		icon(inner, t.icon, 24, C.text, { LayoutOrder = 1 })
		label(inner, T(t.key), 20, C.text, FONT_HEAD, { LayoutOrder = 2, Size = UDim2.new(1, -40, 1, 0) })
		create("Frame", {
			Name = "Line", Parent = b, BackgroundColor3 = C.accent, Size = UDim2.new(1, -36, 0, 3),
			Position = UDim2.new(0, 18, 1, -6), Visible = false,
		}, { corner(2) })
		b.Activated:Connect(function()
			playSound("click")
			tabs[group] = t.id
			paint()
			onChange()
		end)
		buttons[t.id] = b
	end
	paint()
	return row
end

-- Zona desplazable bajo las pestañas
local function scrollArea(parent: Instance, top: number): ScrollingFrame
	return create("ScrollingFrame", {
		Parent = parent, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6, ScrollBarImageColor3 = C.stroke, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, { padding(2, 10, 2, 16) })
end

local function grid(parent: Instance, cellHeight: number, columns: number): UIGridLayout
	return create("UIGridLayout", {
		Parent = parent, CellSize = UDim2.new(1 / columns, -12 * (columns - 1) / columns, 0, cellHeight),
		CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

---------------------------------------------------------------------
-- MAPA
---------------------------------------------------------------------
local function mapXY(lat: number, lon: number): (number, number)
	return (lon + 180) / 360, (Config.Map.latTop - lat) / (Config.Map.latTop - Config.Map.latBottom)
end

-- Punto intermedio de una ruta (longitud con vuelta por el antimeridiano)
local function routePoint(a: any, b: any, t: number): (number, number)
	local dLon = b.lon - a.lon
	if dLon > 180 then
		dLon -= 360
	elseif dLon < -180 then
		dLon += 360
	end
	local lon = a.lon + dLon * t
	if lon < -180 then
		lon += 360
	elseif lon >= 180 then
		lon -= 360
	end
	return mapXY(a.lat + (b.lat - a.lat) * t, lon)
end

local function buildMapPage(page: Frame)
	local holder = create("Frame", { Parent = page, BackgroundColor3 = C.panel, Size = UDim2.fromScale(1, 1), ClipsDescendants = true }, {
		corner(14), stroke(C.stroke, 1.5),
	})
	local map = create("Frame", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(9, 16, 31), BorderSizePixel = 0,
	}, { create("UIAspectRatioConstraint", { AspectRatio = Config.Map.aspect }) })
	if Config.Assets.mapWest ~= "" then
		create("ImageLabel", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Image = Config.Assets.mapWest })
		create("ImageLabel", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), Image = Config.Assets.mapEast })
	else
		-- Sustituto: retícula cada 30 grados
		for lon = -150, 150, 30 do
			create("Frame", { Parent = map, BackgroundColor3 = C.stroke, BackgroundTransparency = 0.6, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale((lon + 180) / 360, 0) })
		end
		for lat = -60, 75, 30 do
			local _, y = mapXY(lat, 0)
			create("Frame", { Parent = map, BackgroundColor3 = C.stroke, BackgroundTransparency = 0.6, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, y) })
		end
	end
	local routeLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local airportLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	local planeLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 })

	local function airportInfo(a: any)
		openModal(a.city .. " (" .. a.code .. ")", function(body)
			listLayout(false, 8).Parent = body
			local w = Config.WeatherById[state.weather[a.code] or "clear"]
			local row = create("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, { listLayout(true, 8, nil, Enum.VerticalAlignment.Center) })
			icon(row, w.icon, 24, C.sky)
			label(row, T("map_weather", { w = T("w_" .. w.id) }), 20, C.text, FONT_BOLD, { Size = UDim2.new(1, -40, 1, 0) })
			label(body, T("r_" .. a.region) .. (state.regions[a.region] and "" or " · " .. T("map_locked")), 18, C.muted)
			local here = 0
			for _, p in state.planes do
				if not p.flight and p.airport == a.code then
					here += 1
				end
			end
			label(body, T("map_planes_here", { n = here }), 18, C.muted)
		end)
	end

	local markers = {}
	for _, a in Config.Airports do
		local x, y = mapXY(a.lat, a.lon)
		local m = create("TextButton", {
			Parent = airportLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "", ZIndex = 3,
		})
		local dot = create("Frame", {
			Parent = m, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.sky, ZIndex = 3,
		}, { corner(6), stroke(C.bg, 2) })
		-- Etiqueta debajo del punto o al lado indicado en Config (aeropuertos muy juntos)
		local side = a.label or "bottom"
		local anchor, offset, align = Vector2.new(0.5, 0), Vector2.new(0, 9), Enum.TextXAlignment.Center
		if side == "top" then
			anchor, offset = Vector2.new(0.5, 1), Vector2.new(0, -9)
		elseif side == "left" then
			anchor, offset, align = Vector2.new(1, 0.5), Vector2.new(-9, 0), Enum.TextXAlignment.Right
		elseif side == "right" then
			anchor, offset, align = Vector2.new(0, 0.5), Vector2.new(9, 0), Enum.TextXAlignment.Left
		end
		local tag = label(airportLayer, a.code, 13, C.text, FONT_BOLD, {
			AnchorPoint = anchor, Position = UDim2.new(x, offset.X, y, offset.Y), Size = UDim2.fromOffset(34, 16),
			TextXAlignment = align, TextStrokeTransparency = 0.4, TextStrokeColor3 = C.bg, ZIndex = 3,
		})
		local weatherIcon = icon(airportLayer, "sun", 16, C.yellow, {
			AnchorPoint = Vector2.new(0.5, side == "top" and 0 or 1), Position = UDim2.new(x, 0, y, side == "top" and 8 or -8), ZIndex = 3,
		})
		local count = create("TextLabel", {
			Parent = m, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 4, 0.5, -2), Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = C.accent, TextColor3 = C.bg, FontFace = FONT_BOLD, TextSize = 13, Text = "", Visible = false, ZIndex = 4,
		}, { corner(9) })
		m.Activated:Connect(function()
			playSound("click")
			airportInfo(a)
		end)
		markers[a.code] = { dot = dot, tag = tag, weather = weatherIcon, count = count, airport = a }
	end

	-- Tarjeta superior: aviones listos
	local readyCard = create("TextButton", {
		Parent = holder, Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(330, 76), AutoButtonColor = false,
		BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, Text = "", ZIndex = 6,
	}, { corner(14), stroke(C.green, 2) })
	local readyDot = create("Frame", { Parent = readyCard, Position = UDim2.fromOffset(18, 30), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.green, ZIndex = 6 }, { corner(8) })
	local readyTitle = label(readyCard, "", 22, C.text, FONT_BOLD, { Position = UDim2.fromOffset(46, 10), Size = UDim2.new(1, -56, 0, 28), ZIndex = 6 })
	local readySub = label(readyCard, T("map_tap") .. "  →", 15, C.accent, FONT_BOLD, { Position = UDim2.fromOffset(46, 40), Size = UDim2.new(1, -56, 0, 22), ZIndex = 6 })
	readyCard.Activated:Connect(function()
		playSound("click")
		showPage("dispatch")
	end)

	-- Interruptor de nombres
	local labelsBtn = create("TextButton", {
		Parent = holder, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = C.panel, Text = "", AutoButtonColor = false, ZIndex = 6,
	}, { corner(12), stroke(C.accent, 1.5) })
	label(labelsBtn, T("map_labels"), 17, C.text, FONT_BOLD, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -80, 1, 0), ZIndex = 6 })
	local labelsState = badge(labelsBtn, "", C.accent, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 6 })
	labelsBtn.Activated:Connect(function()
		playSound("click")
		showLabels = not showLabels
		pageRefresh.map()
	end)

	-- Aviones en vuelo: ruta punteada + icono que avanza
	local flights: { [number]: { dots: { Frame }, marker: GuiObject } } = {}
	local DOTS = 18
	local function flightVisual(planeId: number)
		local f = flights[planeId]
		if f then
			return f
		end
		local dots = {}
		for i = 1, DOTS do
			dots[i] = create("Frame", { Parent = routeLayer, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = C.sky, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 2 }, { corner(2) })
		end
		local marker = icon(planeLayer, "plane", 26, C.text, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
		f = { dots = dots, marker = marker }
		flights[planeId] = f
		return f
	end

	local function animate()
		if not state or currentPage ~= "map" then
			return
		end
		local now = serverNow()
		local alive = {}
		for _, p in state.planes do
			local fl = p.flight
			if fl then
				alive[p.id] = true
				local a, b = Config.AirportByCode[fl.from], Config.AirportByCode[fl.to]
				local v = flightVisual(p.id)
				local t = math.clamp((now - fl.startT) / math.max(1, fl.endT - fl.startT), 0, 1)
				for i, d in v.dots do
					local x, y = routePoint(a, b, i / (DOTS + 1))
					d.Position = UDim2.fromScale(x, y)
					d.BackgroundTransparency = (i / (DOTS + 1)) < t and 0.75 or 0.25
				end
				local x, y = routePoint(a, b, t)
				local x2, y2 = routePoint(a, b, math.min(1, t + 0.02))
				v.marker.Position = UDim2.fromScale(x, y)
				local dx, dy = (x2 - x) * Config.Map.aspect, y2 - y
				if math.abs(dx) < 0.5 and (dx ~= 0 or dy ~= 0) then
					-- El icono de Lucide apunta al noreste (−45°)
					v.marker.Rotation = math.deg(math.atan2(dy, dx)) + 45
				end
				local col = fl.cargo == "ferry" and C.purple or C.accent
				if v.marker:IsA("ImageLabel") then
					v.marker.ImageColor3 = col
				elseif v.marker:IsA("TextLabel") then
					v.marker.TextColor3 = col
				end
			end
		end
		for id, v in flights do
			if not alive[id] then
				for _, d in v.dots do
					d:Destroy()
				end
				v.marker:Destroy()
				flights[id] = nil
			end
		end
	end
	table.insert(tickers, animate)

	pageRefresh.map = function()
		if not state then
			return
		end
		local idleAt, idle = {}, 0
		for _, p in state.planes do
			if not p.flight then
				idleAt[p.airport] = (idleAt[p.airport] or 0) + 1
				idle += 1
			end
		end
		for code, m in markers do
			local unlocked = state.regions[m.airport.region] == true
			m.dot.BackgroundColor3 = unlocked and C.sky or C.muted
			m.dot.BackgroundTransparency = unlocked and 0 or 0.5
			m.tag.Visible = showLabels
			m.tag.TextTransparency = unlocked and 0 or 0.5
			local w = Config.WeatherById[state.weather[code] or "clear"]
			m.weather.Visible = showLabels and unlocked and w.id ~= "clear"
			if m.weather:IsA("ImageLabel") then
				m.weather.ImageRectOffset = Vector2.new((Config.Icons[w.icon] % 8) * 128, math.floor(Config.Icons[w.icon] / 8) * 128)
			elseif m.weather:IsA("TextLabel") then
				m.weather.Text = ICON_TEXT[w.icon] or "•"
			end
			local n = idleAt[code] or 0
			m.count.Visible = n > 0
			m.count.Text = tostring(n)
		end
		readyTitle.Text = idle > 0 and T("map_ready", { n = idle }) or T("map_all_busy")
		readyDot.BackgroundColor3 = idle > 0 and C.green or C.muted
		readySub.Visible = idle > 0
		labelsState.Text = showLabels and T("on") or T("off")
		animate()
	end
end

---------------------------------------------------------------------
-- FLOTA
---------------------------------------------------------------------
local function buildFleetPage(page: Frame)
	local area: ScrollingFrame
	local hangarBadge: TextLabel
	local cache: { [any]: Entry } = {}
	local currentTab = ""

	local function sellConfirm(plane: any)
		local model = Config.PlaneById[plane.model]
		openModal(T("btn_sell") .. " " .. model.name, function(body)
			label(body, fmtMoney(Config.sellPrice(model.price, plane.condition)), 34, C.green, FONT_HEAD, { Size = UDim2.new(1, 0, 0, 44) })
		end, {
			{ text = T("btn_cancel"), style = "ghost" },
			{ text = T("btn_confirm"), style = "danger", onClick = function()
				act("sellPlane", plane.id)
			end },
		})
	end

	local function buildMine(plane: any): Entry
		local root = card(area)
		padding(14).Parent = root
		local art = create("Frame", { Parent = root, BackgroundColor3 = C.bg, Size = UDim2.new(1, 0, 0, 140) }, { corner(10) })
		planeArt(art, plane.model, { Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5) })
		badge(art, registration(plane.id), C.text, {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 0, BackgroundColor3 = C.text, TextColor3 = C.bg,
		})
		local name = label(root, "", 22, C.text, FONT_HEAD, { Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, -150, 0, 28) })
		local status = badge(root, "", C.green, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 152) })
		local where = label(root, "", 16, C.muted, FONT_BODY, { Position = UDim2.fromOffset(0, 182), Size = UDim2.new(1, 0, 0, 20) })
		local stats = label(root, "", 16, C.text, FONT_BOLD, { Position = UDim2.fromOffset(0, 206), Size = UDim2.new(1, 0, 0, 20) })
		local condText = label(root, "", 14, C.muted, FONT_BOLD, { Position = UDim2.fromOffset(0, 230), Size = UDim2.new(1, 0, 0, 18) })
		local condFill = progressBar(root, { Position = UDim2.fromOffset(0, 252) }, C.green)
		local row = create("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 44) }, { listLayout(true, 8) })
		local dispatchBtn = button(row, T("btn_dispatch"), "blue", UDim2.new(0.37, -6, 1, 0), function()
			selectedPlaneId = plane.id
			showPage("dispatch")
		end)
		local repairBtn = button(row, "", "ghost", UDim2.new(0.39, -6, 1, 0), function()
			act("repair", plane.id)
		end)
		repairBtn.LayoutOrder = 2
		local sellBtn = button(row, T("btn_sell"), "danger", UDim2.new(0.24, -4, 1, 0), function()
			for _, p in state.planes do
				if p.id == plane.id then
					sellConfirm(p)
				end
			end
		end)
		sellBtn.LayoutOrder = 3
		for _, b in { dispatchBtn, repairBtn, sellBtn } do
			b.TextSize = 16
		end
		return {
			root = root,
			update = function(p: any)
				local model = Config.PlaneById[p.model]
				name.Text = model.name
				local st, col = planeStatus(p)
				status.Text = st
				status.TextColor3 = col
				status.BackgroundColor3 = col
				where.Text = planeWhere(p)
				stats.Text = string.format("%s  ·  %s km  ·  %s km/h", fmtTons(model.cap), fmtInt(model.range), model.speed)
				condText.Text = T("condition", { p = math.floor(p.condition) })
				condFill.Size = UDim2.fromScale(p.condition / 100, 1)
				condFill.BackgroundColor3 = p.condition >= 60 and C.green or (p.condition >= Config.REPAIR_BLOCK and C.yellow or C.red)
				setButton(dispatchBtn, nil, not p.flight)
				local cost = Config.repairCost(model.price, p.condition)
				setButton(repairBtn, T("btn_repair", { cost = fmtMoney(cost) }), not p.flight and cost > 0 and state.money >= cost)
				setButton(sellBtn, nil, not p.flight and #state.planes > 1)
			end,
		}
	end

	local function buildDealer(model: any): Entry
		local root = card(area)
		padding(14).Parent = root
		local art = create("Frame", { Parent = root, BackgroundColor3 = C.bg, Size = UDim2.new(1, 0, 0, 140) }, { corner(10) })
		planeArt(art, model.id, { Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5) })
		label(root, model.name, 24, C.text, FONT_HEAD, { Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, -130, 0, 30) })
		badge(root, T("class_" .. model.class), C.sky, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 152) })
		label(root, T("plane_" .. model.id .. "_d"), 15, C.muted, FONT_BODY, {
			Position = UDim2.fromOffset(0, 184), Size = UDim2.new(1, 0, 0, 38), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})
		local price = label(root, fmtMoney(model.price), 30, C.green, FONT_HEAD, { Position = UDim2.fromOffset(0, 224), Size = UDim2.new(1, 0, 0, 36) })
		local statRow = create("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 264), Size = UDim2.new(1, 0, 0, 24) }, {
			listLayout(true, 6, nil, Enum.VerticalAlignment.Center),
		})
		for i, s in {
			{ "weight", fmtTons(model.cap) }, { "gauge", model.speed .. " km/h" }, { "route", fmtInt(model.range) .. " km" }, { "fuel", model.burn .. " L/km" },
		} do
			icon(statRow, s[1], 18, C.sky, { LayoutOrder = i * 2 - 1 })
			label(statRow, s[2], 15, C.text, FONT_BOLD, { LayoutOrder = i * 2, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X })
		end
		local req = label(root, "", 15, C.yellow, FONT_BOLD, { Position = UDim2.fromOffset(0, 292), Size = UDim2.new(1, 0, 0, 20) })
		local buy = button(root, T("btn_buy"), "primary", UDim2.new(1, 0, 0, 44), function()
			act("buyPlane", model.id)
		end)
		buy.Position = UDim2.new(0, 0, 1, -44)
		return {
			root = root,
			update = function()
				local reasons = {}
				if playerLevel() < model.level then
					table.insert(reasons, T("req_level", { level = model.level }))
				end
				if model.license and not state.licenses[model.license] then
					table.insert(reasons, T("req_license", { license = T("lic_" .. model.license) }))
				end
				req.Text = table.concat(reasons, " · ")
				price.TextColor3 = state.money >= model.price and C.green or C.red
				setButton(buy, nil, #reasons == 0 and state.money >= model.price and #state.planes < state.maxPlanes)
			end,
		}
	end

	local function buildUpgrade(up: any): Entry
		local root = card(area, { Size = UDim2.new(1, 0, 0, 140) })
		padding(18).Parent = root
		local box = create("Frame", { Parent = root, BackgroundColor3 = C.cardHi, Size = UDim2.fromOffset(100, 100) }, { corner(14) })
		icon(box, up.icon, 52, C.accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		label(root, T("up_" .. up.id), 24, C.text, FONT_BOLD, { Position = UDim2.fromOffset(120, 0), Size = UDim2.new(1, -360, 0, 30) })
		label(root, T("up_" .. up.id .. "_d"), 17, C.muted, FONT_BODY, { Position = UDim2.fromOffset(120, 32), Size = UDim2.new(1, -360, 0, 22) })
		local lvl = label(root, "", 15, C.green, FONT_BOLD, { Position = UDim2.fromOffset(120, 60), Size = UDim2.new(1, -360, 0, 20) })
		local segs = create("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(120, 86), Size = UDim2.new(1, -360, 0, 12) }, { listLayout(true, 4) })
		local pieces = {}
		for i = 1, up.max do
			pieces[i] = create("Frame", { Parent = segs, LayoutOrder = i, BackgroundColor3 = C.bg, Size = UDim2.new(1 / up.max, -4, 1, 0) }, { corner(4) })
		end
		local buy = button(root, "", "primary", UDim2.fromOffset(220, 50), function()
			act("buyUpgrade", up.id)
		end)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.fromScale(1, 0.5)
		return {
			root = root,
			update = function()
				local level = state.upgrades[up.id] or 0
				lvl.Text = T("up_level", { n = level, max = up.max })
				for i, piece in pieces do
					piece.BackgroundColor3 = i <= level and C.accent or C.bg
				end
				if level >= up.max then
					setButton(buy, T("maxed"), false)
				else
					local cost = Config.upgradeCost(up.id, level)
					setButton(buy, T("btn_upgrade", { cost = fmtMoney(cost) }), state.money >= cost)
				end
			end,
		}
	end

	local function render()
		if not state then
			return
		end
		local tab = tabs.fleet
		if tab ~= currentTab then
			currentTab = tab
			for _, e in cache do
				e.root:Destroy()
			end
			table.clear(cache)
			for _, k in area:GetChildren() do
				if k:IsA("UIGridLayout") or k:IsA("UIListLayout") then
					k:Destroy()
				end
			end
			if tab == "upgrades" then
				listLayout(false, 12).Parent = area
			else
				grid(area, tab == "mine" and 340 or 392, 3)
			end
		end
		hangarBadge.Text = T("hangar", { n = #state.planes, max = state.maxPlanes })
		if tab == "mine" then
			syncList(cache, state.planes, function(p) return p.id end, buildMine)
		elseif tab == "dealer" then
			syncList(cache, Config.Planes, function(m) return m.id end, buildDealer)
		else
			syncList(cache, Config.Upgrades, function(u) return u.id end, buildUpgrade)
		end
	end

	local header = tabRow(page, {
		{ id = "mine", key = "tab_my_planes", icon = "plane" },
		{ id = "dealer", key = "tab_dealership", icon = "shopping-cart" },
		{ id = "upgrades", key = "tab_upgrades", icon = "settings" },
	}, "fleet", render)
	header.Size = UDim2.new(1, -170, 0, 52)
	hangarBadge = badge(page, "", C.accent, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 13) })
	area = scrollArea(page, 64)
	pageRefresh.fleet = render
	table.insert(tickers, function()
		if currentPage == "fleet" and tabs.fleet == "mine" then
			render()
		end
	end)
end

---------------------------------------------------------------------
-- DESPACHO
---------------------------------------------------------------------
local function buildDispatchPage(page: Frame)
	-- Columna izquierda: aviones (con el interruptor de despacho automático arriba)
	local left = card(page, { Size = UDim2.new(0, 340, 1, 0) })
	label(left, T("disp_planes"), 18, C.muted, FONT_HEAD, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -180, 0, 24) })
	local autoBtn = button(left, "", "ghost", UDim2.fromOffset(160, 36), function()
		if state.autoUnlocked then
			act("setAuto", not state.settings.auto)
		end
	end)
	autoBtn.TextSize = 15
	autoBtn.AnchorPoint = Vector2.new(1, 0)
	autoBtn.Position = UDim2.new(1, -10, 0, 8)
	local planeList = scrollArea(left, 52)
	planeList:FindFirstChildOfClass("UIPadding"):Destroy()
	padding(10, 10, 4, 10).Parent = planeList
	listLayout(false, 8).Parent = planeList
	local planeCache: { [any]: Entry } = {}

	-- Columna derecha: tablón
	local right = card(page, { Position = UDim2.fromOffset(352, 0), Size = UDim2.new(1, -352, 1, 0) })
	padding(16).Parent = right
	local boardTitle = label(right, "", 22, C.text, FONT_HEAD, { Size = UDim2.new(1, -330, 0, 30) })
	local weatherRow = create("Frame", { Parent = right, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, -330, 0, 24) }, {
		listLayout(true, 6, nil, Enum.VerticalAlignment.Center),
	})
	local weatherIconHolder = create("Frame", { Parent = weatherRow, BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20), LayoutOrder = 1 })
	local weatherText = label(weatherRow, "", 16, C.muted, FONT_BOLD, { LayoutOrder = 2, Size = UDim2.new(1, -30, 1, 0) })
	local function selectedPlane(): any
		if not state then
			return nil
		end
		for _, p in state.planes do
			if p.id == selectedPlaneId then
				return p
			end
		end
		return nil
	end
	local refreshBtn = button(right, T("btn_refresh"), "ghost", UDim2.fromOffset(150, 42), function()
		local plane = selectedPlane()
		if plane then
			act("refreshBoard", plane.airport)
		end
	end)
	refreshBtn.AnchorPoint = Vector2.new(1, 0)
	refreshBtn.Position = UDim2.new(1, -170, 0, 0)
	local ferryBtn: TextButton
	local pilotTitle = label(right, T("disp_pilot"), 15, C.muted, FONT_HEAD, { Position = UDim2.fromOffset(0, 64), Size = UDim2.fromOffset(200, 20) })
	local pilotRow = create("ScrollingFrame", {
		Parent = right, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 46),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0,
	}, { listLayout(true, 8) })
	local loadList = scrollArea(right, 146)
	listLayout(false, 8).Parent = loadList
	local loadCache: { [any]: Entry } = {}
	local emptyText = label(right, "", 18, C.muted, FONT_BODY, {
		Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
	})

	local function ferryMenu()
		local plane = selectedPlane()
		if not plane or plane.flight then
			return
		end
		local model = Config.PlaneById[plane.model]
		openModal(T("ferry_title", { name = model.name }), function(body)
			label(body, T("ferry_body"), 16, C.muted, FONT_BODY, { Size = UDim2.new(1, 0, 0, 22), TextWrapped = true })
			local list = create("ScrollingFrame", {
				Parent = body, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 300),
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
			}, { listLayout(false, 6) })
			local options = {}
			for _, a in Config.Airports do
				if a.code ~= plane.airport and state.regions[a.region] then
					local d = Config.distance(plane.airport, a.code)
					if d <= model.range then
						table.insert(options, { a = a, d = d })
					end
				end
			end
			table.sort(options, function(x, y) return x.d < y.d end)
			for i, o in options do
				local row = create("Frame", { Parent = list, LayoutOrder = i, BackgroundColor3 = C.cardHi, Size = UDim2.new(1, -8, 0, 48) }, { corner(10), padding(12, 6, 0, 0) })
				label(row, o.a.code .. " · " .. o.a.city, 18, C.text, FONT_BOLD, { Size = UDim2.new(0.5, 0, 1, 0) })
				label(row, string.format("%s km · %s · %s", fmtInt(o.d), fmtTime(Config.flightSeconds(o.d, model.speed, 1)), fmtMoney(math.floor(o.d * model.burn * state.fuelPrice))), 15, C.muted, FONT_BODY, {
					Position = UDim2.fromScale(0.42, 0), Size = UDim2.new(0.58, -110, 1, 0),
				})
				local go = button(row, "→", "blue", UDim2.fromOffset(96, 36), function()
					closeModal()
					act("ferry", plane.id, o.a.code)
				end)
				go.AnchorPoint = Vector2.new(1, 0.5)
				go.Position = UDim2.fromScale(1, 0.5)
			end
		end)
	end
	ferryBtn = button(right, T("btn_ferry"), "ghost", UDim2.fromOffset(160, 42), ferryMenu)
	ferryBtn.AnchorPoint = Vector2.new(1, 0)
	ferryBtn.Position = UDim2.fromScale(1, 0)

	local function buildPlaneRow(plane: any): Entry
		local root = create("TextButton", { Parent = planeList, BackgroundColor3 = C.cardHi, Size = UDim2.new(1, 0, 0, 74), Text = "", AutoButtonColor = false }, {
			corner(12), stroke(C.stroke, 1.5),
		})
		local art = create("Frame", { Parent = root, BackgroundColor3 = C.bg, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(92, 58) }, { corner(8) })
		planeArt(art, plane.model, { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3) })
		local name = label(root, "", 17, C.text, FONT_BOLD, { Position = UDim2.fromOffset(110, 8), Size = UDim2.new(1, -118, 0, 22) })
		local where = label(root, "", 14, C.muted, FONT_BODY, { Position = UDim2.fromOffset(110, 30), Size = UDim2.new(1, -118, 0, 18) })
		local status = label(root, "", 13, C.green, FONT_BOLD, { Position = UDim2.fromOffset(110, 50), Size = UDim2.new(1, -118, 0, 16) })
		root.Activated:Connect(function()
			playSound("click")
			selectedPlaneId = plane.id
			pageRefresh.dispatch()
		end)
		return {
			root = root,
			update = function(p: any)
				name.Text = Config.PlaneById[p.model].name .. "  ·  " .. registration(p.id)
				where.Text = planeWhere(p)
				local st, col = planeStatus(p)
				status.Text = st
				status.TextColor3 = col
				local sel = p.id == selectedPlaneId
				root:FindFirstChildOfClass("UIStroke").Color = sel and C.accent or C.stroke
				root.BackgroundColor3 = sel and C.accentDark or C.cardHi
			end,
		}
	end

	local function buildLoadRow(load: any): Entry
		local root = create("Frame", { Parent = loadList, BackgroundColor3 = C.cardHi, Size = UDim2.new(1, 0, 0, 76) }, { corner(12) })
		local cargo = Config.CargoById[load.cargo]
		local box = create("Frame", { Parent = root, BackgroundColor3 = C.bg, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(56, 56) }, { corner(10) })
		icon(box, cargo.icon, 32, C.accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		label(root, T("cargo_" .. cargo.id), 18, C.text, FONT_BOLD, { Position = UDim2.fromOffset(78, 10), Size = UDim2.new(0.34, -78, 0, 24) })
		local to = Config.AirportByCode[load.to]
		label(root, string.format("%s → %s %s", load.from, to.code, to.city), 15, C.muted, FONT_BODY, { Position = UDim2.fromOffset(78, 36), Size = UDim2.new(0.34, -60, 0, 20) })
		label(root, string.format("%s km · %s", fmtInt(load.dist), fmtTons(load.weight)), 15, C.text, FONT_BOLD, { Position = UDim2.new(0.36, 0, 0, 10), Size = UDim2.new(0.2, 0, 0, 24) })
		local time = label(root, "", 15, C.muted, FONT_BODY, { Position = UDim2.new(0.36, 0, 0, 36), Size = UDim2.new(0.2, 0, 0, 20) })
		local net = label(root, "", 24, C.green, FONT_HEAD, { Position = UDim2.new(0.57, 0, 0, 6), Size = UDim2.new(0.22, 0, 0, 30) })
		local detail = label(root, "", 13, C.muted, FONT_BODY, { Position = UDim2.new(0.57, 0, 0, 38), Size = UDim2.new(0.22, 0, 0, 30), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		local fly = button(root, T("btn_fly"), "primary", UDim2.new(0.19, -10, 0, 48), function()
			act("dispatch", selectedPlaneId, load.id, selectedPilot)
		end)
		fly.AnchorPoint = Vector2.new(1, 0.5)
		fly.Position = UDim2.new(1, -10, 0.5, 0)
		local reason = label(root, "", 13, C.red, FONT_BOLD, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.19, -10, 0, 48),
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
		})
		return {
			root = root,
			update = function(l: any)
				local plane = selectedPlane()
				if not plane then
					return
				end
				local gross, fuel, fee, secs = quote(plane, l, selectedPilot)
				local n = gross - fuel - fee
				net.Text = fmtMoney(n)
				net.TextColor3 = n >= 0 and C.green or C.red
				detail.Text = T("disp_fuel", { fuel = fmtMoney(fuel) }) .. (fee > 0 and (" · −" .. fmtMoney(fee)) or "")
				time.Text = "◷ " .. fmtTime(secs)
				local block = flyBlock(plane, l)
				if not block and selectedPilot > 0 and pilotBusy(selectedPilot) then
					block = "err_pilot_busy"
				elseif not block and selectedPilot == 0 and pilotBusy(0) then
					block = "err_you_busy"
				end
				fly.Visible = block == nil
				reason.Visible = block ~= nil
				reason.Text = block and T(block) or ""
			end,
		}
	end

	local pilotChips: { [number]: TextButton } = {}
	local function renderPilots()
		local list = { { id = 0, name = T("pilot_you"), rarity = "common" } }
		for _, p in state.pilots do
			table.insert(list, p)
		end
		-- Si el piloto elegido ya no existe o está volando, se elige uno libre:
		-- primero tú; si no, el contratado libre de mayor rareza
		if (selectedPilot ~= 0 and not findPilot(selectedPilot)) or pilotBusy(selectedPilot) then
			local best, bestRank = nil, -1
			for _, p in list do
				local rank = p.id == 0 and 99 or Config.RarityIndex[p.rarity]
				if not pilotBusy(p.id) and rank > bestRank then
					best, bestRank = p.id, rank
				end
			end
			selectedPilot = best or 0
		end
		local seen = {}
		for i, p in list do
			seen[p.id] = true
			local chip = pilotChips[p.id]
			if not chip then
				chip = create("TextButton", {
					Parent = pilotRow, Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, AutoButtonColor = false,
					BackgroundColor3 = C.cardHi, Text = "", FontFace = FONT_BOLD, TextSize = 16, TextColor3 = C.text,
				}, { corner(21), stroke(C.stroke, 2), padding(16, 16, 0, 0) })
				chip.Activated:Connect(function()
					playSound("click")
					selectedPilot = p.id
					pageRefresh.dispatch()
				end)
				pilotChips[p.id] = chip
			end
			chip.LayoutOrder = i
			local rarity = Config.Rarities[Config.RarityIndex[p.rarity] or 1]
			local busy = pilotBusy(p.id)
			local bonus = rarity.bonus > 0 and p.id > 0 and string.format(" +%d%%", rarity.bonus * 100) or ""
			chip.Text = (p.id == 0 and "★ " or "") .. p.name .. bonus .. (busy and " ✈" or "")
			chip.TextColor3 = busy and C.muted or (p.id == 0 and C.text or rarity.color)
			chip.BackgroundColor3 = p.id == selectedPilot and C.accentDark or C.cardHi
			chip:FindFirstChildOfClass("UIStroke").Color = p.id == selectedPilot and C.accent or C.stroke
		end
		for id, chip in pilotChips do
			if not seen[id] then
				chip:Destroy()
				pilotChips[id] = nil
			end
		end
	end

	local lastBoardKey = ""
	local function render()
		if not state then
			return
		end
		-- Despacho automático
		if state.autoUnlocked then
			setButton(autoBtn, T("disp_auto_short", { v = state.settings.auto and T("disp_auto_on") or T("disp_auto_off") }), true)
			autoBtn.BackgroundColor3 = state.settings.auto and C.green or C.cardHi
			autoBtn.TextColor3 = state.settings.auto and C.bg or C.text
		else
			setButton(autoBtn, T("disp_auto_locked_short", { level = Config.AUTO_DISPATCH_LEVEL }), false)
		end
		-- Lista de aviones: primero los que están en tierra
		local planes = table.clone(state.planes)
		table.sort(planes, function(a, b)
			local ia, ib = a.flight and 1 or 0, b.flight and 1 or 0
			if ia ~= ib then
				return ia < ib
			end
			return a.id < b.id
		end)
		local sel = selectedPlane()
		if not sel or sel.flight then
			selectedPlaneId = nil
			for _, p in planes do
				if not p.flight then
					selectedPlaneId = p.id
					break
				end
			end
			sel = selectedPlane()
		end
		syncList(planeCache, planes, function(p) return p.id end, buildPlaneRow)
		renderPilots()
		pilotTitle.Visible = sel ~= nil
		pilotRow.Visible = sel ~= nil
		if not sel then
			boardTitle.Text = T("disp_no_idle")
			weatherText.Text = ""
			emptyText.Text = ""
			syncList(loadCache, {}, function(l) return l.id end, buildLoadRow)
			setButton(refreshBtn, nil, false)
			setButton(ferryBtn, nil, false)
			return
		end
		local a = Config.AirportByCode[sel.airport]
		boardTitle.Text = T("disp_board", { code = a.code, city = a.city })
		local w = Config.WeatherById[state.weather[a.code] or "clear"]
		weatherText.Text = T("w_" .. w.id) .. (w.pay > 1 and string.format("  ·  +%d%% $", math.floor((w.pay - 1) * 100 + 0.5)) or "")
		local key = sel.airport .. w.id
		if key ~= lastBoardKey then
			lastBoardKey = key
			for _, k in weatherIconHolder:GetChildren() do
				k:Destroy()
			end
			icon(weatherIconHolder, w.icon, 20, w.id == "clear" and C.yellow or C.sky)
		end
		local cooldown = state.refresh[sel.airport] or 0
		setButton(refreshBtn, cooldown > 0 and T("disp_cooldown", { s = cooldown }) or T("btn_refresh"), cooldown <= 0)
		setButton(ferryBtn, nil, sel.condition >= Config.REPAIR_BLOCK)
		local loads = table.clone(state.boards[sel.airport] or {})
		-- Primero las que este avión puede llevar, de más a menos beneficio
		table.sort(loads, function(x, y)
			local bx, by = flyBlock(sel, x) == nil, flyBlock(sel, y) == nil
			if bx ~= by then
				return bx
			end
			local gx, fx, ex = quote(sel, x, selectedPilot)
			local gy, fy, ey = quote(sel, y, selectedPilot)
			return gx - fx - ex > gy - fy - ey
		end)
		syncList(loadCache, loads, function(l) return l.id end, buildLoadRow)
		emptyText.Text = #loads == 0 and T("board_empty") or ""
	end
	pageRefresh.dispatch = render
	table.insert(tickers, function()
		if currentPage == "dispatch" and state then
			for _, p in state.planes do
				local e = planeCache[p.id]
				if e and p.flight then
					e.update(p)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- PILOTOS
---------------------------------------------------------------------
local function rarityName(id: string): string
	return T("rarity_" .. id)
end

local function pilotCardContents(root: Instance, pilot: any)
	local rarity = Config.Rarities[Config.RarityIndex[pilot.rarity]]
	local avatar = create("Frame", { Parent = root, BackgroundColor3 = C.bg, Size = UDim2.fromOffset(64, 64) }, { corner(32), stroke(rarity.color, 3) })
	local initials = string.sub(pilot.name, 1, 1) .. (string.match(pilot.name, " (%a)") or "")
	label(avatar, initials, 26, rarity.color, FONT_HEAD, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	label(root, pilot.name, 20, C.text, FONT_BOLD, { Position = UDim2.fromOffset(78, 2), Size = UDim2.new(1, -78, 0, 26) })
	label(root, rarityName(pilot.rarity), 16, rarity.color, FONT_BOLD, { Position = UDim2.fromOffset(78, 28), Size = UDim2.new(1, -78, 0, 20) })
	label(root, T("pilot_bonus", { p = math.floor(rarity.bonus * 100) }), 15, C.green, FONT_BODY, { Position = UDim2.fromOffset(78, 48), Size = UDim2.new(1, -78, 0, 20) })
end

local function buildPilotsPage(page: Frame)
	local area: ScrollingFrame
	local rosterBadge: TextLabel
	local cache: { [any]: Entry } = {}
	local currentTab = ""
	local emptyLabel: TextLabel?

	local function buildPilot(pilot: any): Entry
		local root = card(area)
		padding(14).Parent = root
		pilotCardContents(root, pilot)
		local status = badge(root, "", C.green, { Position = UDim2.new(0, 0, 1, -30) })
		local fire = button(root, T("btn_fire"), "danger", UDim2.fromOffset(120, 34), function()
			openModal(T("btn_fire") .. " " .. pilot.name, function() end, {
				{ text = T("btn_cancel"), style = "ghost" },
				{ text = T("btn_confirm"), style = "danger", onClick = function()
					act("firePilot", pilot.id)
				end },
			})
		end)
		fire.AnchorPoint = Vector2.new(1, 1)
		fire.Position = UDim2.fromScale(1, 1)
		return {
			root = root,
			update = function(p: any)
				local busy = pilotBusy(p.id)
				status.Text = busy and T("pilot_flying") or T("pilot_free")
				status.TextColor3 = busy and C.sky or C.green
				status.BackgroundColor3 = status.TextColor3
				setButton(fire, nil, not busy)
			end,
		}
	end

	local function buildAgency(agency: any): Entry
		local root = card(area)
		padding(18).Parent = root
		local box = create("Frame", { Parent = root, BackgroundColor3 = C.accentDark, Size = UDim2.fromOffset(84, 84) }, { corner(14), stroke(C.accent, 1.5) })
		icon(box, agency.icon, 46, C.accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		label(root, string.upper(T("ag_" .. agency.id)), 24, C.text, FONT_HEAD, { Position = UDim2.fromOffset(100, 6), Size = UDim2.new(1, -100, 0, 32) })
		local lock = label(root, "", 17, C.green, FONT_BOLD, { Position = UDim2.fromOffset(100, 42), Size = UDim2.new(1, -100, 0, 22) })
		label(root, T("ag_" .. agency.id .. "_d"), 16, C.muted, FONT_BODY, { Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		-- Barra apilada con las probabilidades
		local bar = create("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 146), Size = UDim2.new(1, 0, 0, 12) }, { listLayout(true, 3) })
		for i, r in Config.Rarities do
			if agency.odds[i] > 0 then
				create("Frame", { Parent = bar, LayoutOrder = i, BackgroundColor3 = r.color, Size = UDim2.new(agency.odds[i] / 100, -3, 1, 0) }, { corner(3) })
			end
		end
		label(root, T("odds"), 14, C.muted, FONT_HEAD, { Position = UDim2.fromOffset(0, 166), Size = UDim2.new(1, 0, 0, 20) })
		for i, r in Config.Rarities do
			local y = 188 + (i - 1) * 28
			local zero = agency.odds[i] == 0
			create("Frame", { Parent = root, BackgroundColor3 = r.color, BackgroundTransparency = zero and 0.6 or 0, Position = UDim2.fromOffset(0, y + 6), Size = UDim2.fromOffset(14, 14) }, { corner(3) })
			label(root, rarityName(r.id), 17, zero and C.muted or r.color, FONT_BOLD, { Position = UDim2.fromOffset(24, y), Size = UDim2.new(1, -110, 0, 26) })
			label(root, (agency.odds[i] % 1 == 0 and tostring(agency.odds[i]) or string.format("%.1f", agency.odds[i])) .. "%", 17, zero and C.muted or C.text, FONT_BOLD, {
				Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
		label(root, T("pilot_fee_note"), 13, C.muted, FONT_BODY, {
			Position = UDim2.fromOffset(0, 334), Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})
		local hire = button(root, T("btn_hire", { cost = fmtMoney(agency.cost) }), "primary", UDim2.new(1, 0, 0, 50), function()
			local ok, extra = act("hirePilot", agency.id)
			if ok and extra and extra.pilot then
				local p = extra.pilot
				openModal(T("hired_title"), function(body)
					local holder = create("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 72) })
					pilotCardContents(holder, p)
				end)
			end
		end)
		hire.Position = UDim2.new(0, 0, 1, -50)
		return {
			root = root,
			update = function()
				local locked = playerLevel() < agency.level
				lock.Text = locked and ("■ " .. T("req_level", { level = agency.level })) or ("✓ " .. T("unlocked_level", { level = agency.level }))
				lock.TextColor3 = locked and C.yellow or C.green
				setButton(hire, nil, not locked and state.money >= agency.cost and #state.pilots < Config.MAX_PILOTS)
			end,
		}
	end

	local function render()
		if not state then
			return
		end
		local tab = tabs.pilots
		if tab ~= currentTab then
			currentTab = tab
			for _, e in cache do
				e.root:Destroy()
			end
			table.clear(cache)
			for _, k in area:GetChildren() do
				if not k:IsA("UIPadding") then
					k:Destroy()
				end
			end
			emptyLabel = nil
			if tab == "roster" then
				grid(area, 150, 3)
			else
				grid(area, 460, 3)
			end
		end
		rosterBadge.Text = T("roster", { n = #state.pilots, max = Config.MAX_PILOTS })
		if tab == "roster" then
			syncList(cache, state.pilots, function(p) return p.id end, buildPilot)
			if #state.pilots == 0 and not emptyLabel then
				emptyLabel = label(area, T("no_pilots"), 18, C.muted, FONT_BODY, { TextWrapped = true, LayoutOrder = 0 })
			elseif #state.pilots > 0 and emptyLabel then
				(emptyLabel :: TextLabel):Destroy()
				emptyLabel = nil
			end
		else
			syncList(cache, Config.Agencies, function(a) return a.id end, buildAgency)
		end
	end

	local header = tabRow(page, {
		{ id = "roster", key = "tab_roster", icon = "users" },
		{ id = "hire", key = "tab_hire", icon = "id-card" },
	}, "pilots", render)
	header.Size = UDim2.new(1, -190, 0, 52)
	rosterBadge = badge(page, "", C.accent, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 13) })
	area = scrollArea(page, 64)
	pageRefresh.pilots = render
end

---------------------------------------------------------------------
-- EMPRESA
---------------------------------------------------------------------
local function buildCompanyPage(page: Frame)
	local area: ScrollingFrame
	local cache: { [any]: Entry } = {}
	local currentTab = ""
	local overview: { [string]: TextLabel } = {}
	local xpFill: Frame

	local function buildOverview()
		local top = card(area, { Size = UDim2.new(1, 0, 0, 120), LayoutOrder = 1 })
		padding(20).Parent = top
		overview.level = label(top, "", 34, C.text, FONT_HEAD, { Size = UDim2.new(1, 0, 0, 42) })
		overview.xp = label(top, "", 16, C.muted, FONT_BOLD, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 20) })
		xpFill = progressBar(top, { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 12) }, C.accent)
		local tiles = create("Frame", { Parent = area, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 230), LayoutOrder = 2 })
		grid(tiles, 108, 3)
		for i, k in { "ov_earned", "ov_flights", "ov_km", "ov_tons", "ov_fleet", "ov_pilots" } do
			local t = card(tiles, { LayoutOrder = i })
			padding(16).Parent = t
			label(t, T(k), 16, C.muted, FONT_BOLD, { Size = UDim2.new(1, 0, 0, 22) })
			overview[k] = label(t, "", 32, C.text, FONT_HEAD, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 40) })
		end
	end

	local function buildRegion(r: any): Entry
		local root = card(area, { Size = UDim2.new(1, 0, 0, 96) })
		padding(18).Parent = root
		icon(root, "globe", 44, C.sky, { Position = UDim2.new(0, 0, 0.5, -22) })
		label(root, T("r_" .. r.id), 24, C.text, FONT_BOLD, { Position = UDim2.fromOffset(62, 4), Size = UDim2.new(1, -330, 0, 30) })
		local n = 0
		for _, a in Config.Airports do
			if a.region == r.id then
				n += 1
			end
		end
		local info = label(root, "", 16, C.muted, FONT_BODY, { Position = UDim2.fromOffset(62, 34), Size = UDim2.new(1, -330, 0, 22) })
		local btn = button(root, "", "primary", UDim2.fromOffset(250, 48), function()
			act("buyRegion", r.id)
		end)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.fromScale(1, 0.5)
		return {
			root = root,
			update = function()
				local owned = state.regions[r.id] == true
				info.Text = T("airports_n", { n = n }) .. (owned and "" or "  ·  " .. T("req_level", { level = r.level }))
				if owned then
					setButton(btn, "✓ " .. T("owned"), false)
				else
					setButton(btn, T("btn_unlock", { cost = fmtMoney(r.cost) }), playerLevel() >= r.level and state.money >= r.cost)
				end
			end,
		}
	end

	local function buildLicense(lic: any): Entry
		local root = card(area)
		padding(18).Parent = root
		local box = create("Frame", { Parent = root, BackgroundColor3 = C.cardHi, Size = UDim2.fromOffset(64, 64) }, { corner(32), stroke(C.accent, 2) })
		icon(box, lic.icon, 34, C.accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		label(root, T("lic_" .. lic.id), 20, C.text, FONT_BOLD, { Position = UDim2.fromOffset(78, 2), Size = UDim2.new(1, -78, 0, 26), TextWrapped = true })
		label(root, T("lic_" .. lic.id .. "_d"), 15, C.muted, FONT_BODY, { Position = UDim2.fromOffset(78, 30), Size = UDim2.new(1, -78, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		local req = label(root, T("req_level", { level = lic.level }), 15, C.yellow, FONT_BOLD, { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 20) })
		local btn = button(root, "", "primary", UDim2.new(1, 0, 0, 46), function()
			act("buyLicense", lic.id)
		end)
		btn.Position = UDim2.new(0, 0, 1, -46)
		return {
			root = root,
			update = function()
				local owned = state.licenses[lic.id] == true
				req.Visible = not owned
				req.TextColor3 = playerLevel() >= lic.level and C.green or C.yellow
				if owned then
					setButton(btn, "✓ " .. T("owned"), false)
				else
					setButton(btn, T("btn_buy") .. " " .. fmtMoney(lic.cost), playerLevel() >= lic.level and state.money >= lic.cost)
				end
			end,
		}
	end

	local function render()
		if not state then
			return
		end
		local tab = tabs.company
		if tab ~= currentTab then
			currentTab = tab
			for _, e in cache do
				e.root:Destroy()
			end
			table.clear(cache)
			for _, k in area:GetChildren() do
				if not k:IsA("UIPadding") then
					k:Destroy()
				end
			end
			if tab == "overview" then
				listLayout(false, 12).Parent = area
				buildOverview()
			elseif tab == "regions" then
				listLayout(false, 12).Parent = area
			else
				grid(area, 220, 3)
			end
		end
		if tab == "overview" then
			local lvl = state.level
			local base, nextXp = Config.xpForLevel(lvl), Config.xpForLevel(lvl + 1)
			overview.level.Text = T("ov_level") .. "  " .. lvl
			overview.xp.Text = T("xp_next", { xp = fmtInt(state.xp - base), need = fmtInt(nextXp - base) })
			xpFill.Size = UDim2.fromScale(math.clamp((state.xp - base) / math.max(1, nextXp - base), 0, 1), 1)
			overview.ov_earned.Text = fmtMoney(state.stats.earned)
			overview.ov_flights.Text = fmtInt(state.stats.flights)
			overview.ov_km.Text = fmtInt(state.stats.km)
			overview.ov_tons.Text = fmtInt(state.stats.tons)
			overview.ov_fleet.Text = #state.planes .. " / " .. state.maxPlanes
			overview.ov_pilots.Text = #state.pilots .. " / " .. Config.MAX_PILOTS
		elseif tab == "regions" then
			syncList(cache, Config.Regions, function(r) return r.id end, buildRegion)
		else
			syncList(cache, Config.Licenses, function(l) return l.id end, buildLicense)
		end
	end

	tabRow(page, {
		{ id = "overview", key = "tab_overview", icon = "chart-column" },
		{ id = "regions", key = "tab_regions", icon = "globe" },
		{ id = "licenses", key = "tab_licenses", icon = "award" },
	}, "company", render)
	area = scrollArea(page, 64)
	pageRefresh.company = render
end

---------------------------------------------------------------------
-- AJUSTES
---------------------------------------------------------------------
local function buildSettingsPage(page: Frame)
	local area = scrollArea(page, 0)
	listLayout(false, 12).Parent = area
	local warn = card(area, { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(70, 28, 36), LayoutOrder = 0, Visible = false })
	label(warn, "⚠ " .. T("warn_nosave"), 18, C.red, FONT_BOLD, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0) })

	local langCard = card(area, { Size = UDim2.new(1, 0, 0, 100), LayoutOrder = 1 })
	padding(18).Parent = langCard
	icon(langCard, "languages", 28, C.sky)
	label(langCard, T("set_language"), 22, C.text, FONT_HEAD, { Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(300, 28) })
	local langRow = create("Frame", { Parent = langCard, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 44) }, { listLayout(true, 10) })
	local langButtons = {}
	for i, opt in { { "", T("lang_auto") }, { "en", "English" }, { "es", "Español" } } do
		local b = button(langRow, opt[2], "ghost", UDim2.fromOffset(200, 44), function()
			act("setLang", opt[1])
			lang = opt[1] ~= "" and opt[1] or detectLang()
			rebuild()
		end)
		b.LayoutOrder = i
		langButtons[opt[1]] = b
	end

	local soundCard = card(area, { Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 2 })
	padding(18).Parent = soundCard
	icon(soundCard, "volume-2", 28, C.sky, { Position = UDim2.new(0, 0, 0.5, -14) })
	label(soundCard, T("set_sound"), 22, C.text, FONT_HEAD, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(0, 300, 1, 0) })
	local soundBtn = button(soundCard, "", "ghost", UDim2.fromOffset(120, 44), function()
		act("setMuted", not state.settings.muted)
	end)
	soundBtn.AnchorPoint = Vector2.new(1, 0.5)
	soundBtn.Position = UDim2.fromScale(1, 0.5)

	local about = card(area, { Size = UDim2.new(1, 0, 0, 90), LayoutOrder = 3 })
	padding(18).Parent = about
	local version = label(about, "", 18, C.text, FONT_BOLD, { Size = UDim2.new(1, 0, 0, 24) })
	label(about, T("credits"), 15, C.muted, FONT_BODY, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 22), TextWrapped = true })

	pageRefresh.settings = function()
		if not state then
			return
		end
		warn.Visible = state.canSave == false
		for code, b in langButtons do
			local active = (state.settings.lang or "") == code
			b.BackgroundColor3 = active and C.accent or C.cardHi
			b.TextColor3 = active and C.bg or C.text
		end
		soundBtn.Text = state.settings.muted and T("off") or T("on")
		soundBtn.BackgroundColor3 = state.settings.muted and C.cardHi or C.green
		soundBtn.TextColor3 = state.settings.muted and C.text or C.bg
		version.Text = T("set_version", { v = state.version or Config.VERSION })
	end
end

---------------------------------------------------------------------
-- Estructura general: barra superior, menú lateral y páginas
---------------------------------------------------------------------
local NAV = {
	{ id = "map", key = "nav_map", icon = "map" },
	{ id = "fleet", key = "nav_fleet", icon = "plane" },
	{ id = "dispatch", key = "nav_dispatch", icon = "plane-takeoff" },
	{ id = "pilots", key = "nav_pilots", icon = "users" },
	{ id = "company", key = "nav_company", icon = "building-2" },
	{ id = "settings", key = "nav_settings", icon = "settings" },
}
local BUILDERS = {
	map = buildMapPage, fleet = buildFleetPage, dispatch = buildDispatchPage,
	pilots = buildPilotsPage, company = buildCompanyPage, settings = buildSettingsPage,
}

local topRefresh: () -> () = function() end
local drawer: Frame
local drawerDim: TextButton
local navButtons: { [string]: TextButton } = {}
local pageTitle: TextLabel
local pageIconHolder: Frame

local function setDrawer(open: boolean)
	drawerDim.Visible = open
	drawer.Position = UDim2.fromOffset(open and -320 or 0, 0)
	tween(drawer, 0.18, { Position = UDim2.fromOffset(open and 0 or -320, 0) })
	if not open then
		task.delay(0.18, function()
			drawer.Visible = drawerDim.Visible
		end)
	else
		drawer.Visible = true
	end
end

function showPage(id: string)
	currentPage = id
	for pid, frame in pageFrames do
		frame.Visible = pid == id
	end
	for pid, b in navButtons do
		local active = pid == id
		b.BackgroundColor3 = active and C.accent or C.card
		for _, k in b:GetDescendants() do
			if k:IsA("TextLabel") then
				k.TextColor3 = active and C.bg or C.text
			elseif k:IsA("ImageLabel") then
				k.ImageColor3 = active and C.bg or C.text
			end
		end
	end
	for _, nav in NAV do
		if nav.id == id then
			pageTitle.Text = T(nav.key)
			for _, k in pageIconHolder:GetChildren() do
				k:Destroy()
			end
			icon(pageIconHolder, nav.icon, 26, C.accent)
		end
	end
	if drawerDim and drawerDim.Visible then
		setDrawer(false)
	end
	if pageRefresh[id] then
		pageRefresh[id]()
	end
end

function refreshAll()
	topRefresh()
	if pageRefresh[currentPage] then
		pageRefresh[currentPage]()
	end
end

local function statChip(parent: Instance, order: number, iconName: string, color: Color3, width: number): (TextLabel, Frame)
	local chip = create("Frame", { Parent = parent, LayoutOrder = order, BackgroundColor3 = C.card, Size = UDim2.fromOffset(width, 48) }, {
		corner(12), stroke(C.stroke, 1.5),
	})
	local box = create("Frame", { Parent = chip, BackgroundColor3 = color, BackgroundTransparency = 0.8, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(36, 36) }, { corner(9) })
	icon(box, iconName, 24, color, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local text = label(chip, "", 22, C.text, FONT_HEAD, { Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -56, 1, 0) })
	return text, chip
end

local function buildUI()
	for _, k in mainGui:GetChildren() do
		if not k:IsA("Sound") then
			k:Destroy()
		end
	end
	for _, k in overlayGui:GetChildren() do
		k:Destroy()
	end
	table.clear(scales)
	table.clear(tickers)
	table.clear(pageRefresh)
	table.clear(pageFrames)
	table.clear(navButtons)

	local app = rootFrame(mainGui)
	create("Frame", { Parent = app, BackgroundColor3 = C.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 0 })

	-- Barra superior
	local top = create("Frame", { Parent = app, BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 64) })
	create("Frame", { Parent = top, BackgroundColor3 = C.stroke, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) })
	local menuBtn = create("TextButton", { Parent = top, BackgroundColor3 = C.card, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(48, 48), Text = "", AutoButtonColor = false }, {
		corner(12), stroke(C.stroke, 1.5),
	})
	icon(menuBtn, "menu", 28, C.accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local titleChip = create("Frame", { Parent = top, BackgroundColor3 = C.card, Position = UDim2.fromOffset(68, 8), Size = UDim2.fromOffset(230, 48) }, {
		corner(12), stroke(C.stroke, 1.5),
	})
	pageIconHolder = create("Frame", { Parent = titleChip, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(26, 26) })
	pageTitle = label(titleChip, "", 22, C.text, FONT_HEAD, { Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -56, 1, 0) })

	local chips = create("Frame", { Parent = top, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.new(1, -330, 0, 48) }, {
		listLayout(true, 10, Enum.HorizontalAlignment.Right),
	})
	local moneyText = statChip(chips, 1, "banknote", C.green, 190)
	local levelText, levelChip = statChip(chips, 2, "star", C.accent, 150)
	local levelFill = progressBar(levelChip, { Position = UDim2.new(0, 50, 1, -10), Size = UDim2.new(1, -62, 0, 4) }, C.accent)
	local fuelText = statChip(chips, 3, "fuel", C.yellow, 150)
	local airText = statChip(chips, 4, "plane", C.sky, 120)

	-- Contenido
	local content = create("Frame", { Parent = app, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 1, -88) })
	for _, nav in NAV do
		local frame = create("Frame", { Parent = content, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Name = nav.id })
		pageFrames[nav.id] = frame
		BUILDERS[nav.id](frame)
	end

	-- Avisos
	local overlay = rootFrame(overlayGui)
	toastHolder = create("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 76), Size = UDim2.fromOffset(380, 400), ZIndex = 20 }, {
		listLayout(false, 8, Enum.HorizontalAlignment.Right),
	})

	-- Menú lateral
	drawerDim = create("TextButton", { Parent = app, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, Visible = false, ZIndex = 10 })
	drawer = create("Frame", { Parent = app, BackgroundColor3 = C.panel, Size = UDim2.new(0, 320, 1, 0), Visible = false, ZIndex = 11 }, { stroke(C.stroke, 1.5) })
	label(drawer, T("game_title"), 26, C.accent, FONT_HEAD, { Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 32), ZIndex = 11 })
	local drawerSub = label(drawer, "", 17, C.muted, FONT_BOLD, { Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 22), ZIndex = 11 })
	local navList = create("Frame", { Parent = drawer, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 88), Size = UDim2.new(1, -28, 1, -100), ZIndex = 11 }, {
		listLayout(false, 8),
	})
	for i, nav in NAV do
		local b = create("TextButton", { Parent = navList, LayoutOrder = i, BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 58), Text = "", AutoButtonColor = false, ZIndex = 11 }, {
			corner(12), stroke(C.stroke, 1.5),
		})
		local inner = create("Frame", { Parent = b, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11 }, {
			listLayout(true, 14, nil, Enum.VerticalAlignment.Center), padding(18, 12, 0, 0),
		})
		icon(inner, nav.icon, 28, C.text, { LayoutOrder = 1, ZIndex = 11 })
		label(inner, T(nav.key), 22, C.text, FONT_HEAD, { LayoutOrder = 2, Size = UDim2.new(1, -50, 1, 0), ZIndex = 11 })
		b.Activated:Connect(function()
			playSound("click")
			showPage(nav.id)
		end)
		navButtons[nav.id] = b
	end
	menuBtn.Activated:Connect(function()
		playSound("click")
		setDrawer(not drawerDim.Visible)
	end)
	drawerDim.Activated:Connect(function()
		setDrawer(false)
	end)

	-- Ventana modal
	modalDim = create("Frame", { Parent = overlay, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30, Active = true })
	modalCard = card(modalDim, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel, ZIndex = 31,
	})
	padding(24).Parent = modalCard
	listLayout(false, 14).Parent = modalCard
	modalTitle = label(modalCard, "", 30, C.text, FONT_HEAD, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 38) })
	modalBody = create("Frame", { Parent = modalCard, BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	modalButtons = create("Frame", { Parent = modalCard, BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 48) }, {
		listLayout(true, 12, Enum.HorizontalAlignment.Right),
	})

	topRefresh = function()
		if not state then
			return
		end
		moneyText.Text = fmtMoney(state.money)
		levelText.Text = T("top_level", { level = state.level })
		local base, nextXp = Config.xpForLevel(state.level), Config.xpForLevel(state.level + 1)
		levelFill.Size = UDim2.fromScale(math.clamp((state.xp - base) / math.max(1, nextXp - base), 0, 1), 1)
		fuelText.Text = string.format("$%.2f/L", state.fuelPrice)
		local inAir = 0
		for _, p in state.planes do
			if p.flight then
				inAir += 1
			end
		end
		airText.Text = inAir .. "/" .. #state.planes
		drawerSub.Text = T("top_level", { level = state.level }) .. "  ·  " .. fmtMoney(state.money)
	end

	updateScale()
	showPage(currentPage)
	refreshAll()
end

function rebuild()
	buildUI()
end

---------------------------------------------------------------------
-- Conexiones
---------------------------------------------------------------------
stateRemote.OnClientEvent:Connect(function(newState: any)
	local first = state == nil
	state = newState
	stateClock = os.clock()
	if first and state.settings and state.settings.lang ~= "" and state.settings.lang ~= lang then
		lang = state.settings.lang
		rebuild()
		return
	end
	refreshAll()
end)

notifyRemote.OnClientEvent:Connect(function(kind: string, key: string, params: { [string]: any }?)
	toast(T(key, translateParams(params)), kind)
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
	for _, fn in tickers do
		fn()
	end
end)

buildUI()
