--[[
	Kit: estado compartido del cliente (ctx) y piezas de interfaz reutilizables.
	Estilo: claro y soleado, letra redondeada (FredokaOne) y botones «gruesos» con sombra.
	Todos los tamaños están en unidades de diseño (1280 de ancho); un UIScale ajusta a la pantalla.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))

local Kit = {}
local C = Config.Colors
Kit.C = C
Kit.Config = Config
Kit.Lang = Lang
Kit.Rules = Rules
Kit.FONT_TITLE = Font.fromEnum(Enum.Font.FredokaOne)
Kit.FONT_BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
Kit.FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

-- Estado compartido entre módulos (lo rellena GameClient)
local ctx: any = {
	state = nil,
	stateClock = os.clock(),
	lang = "en",
	targets = {}, -- botones con nombre para las flechas del tutorial
	tickers = {}, -- funciones que se llaman 5 veces por segundo
	refreshers = {}, -- funciones que se llaman con cada estado nuevo
}
Kit.ctx = ctx

function Kit.T(key: string, params: { [string]: any }?): string
	return Lang.t(ctx.lang, key, params)
end
local T = Kit.T

function Kit.serverNow(): number
	if not ctx.state then
		return os.time()
	end
	return ctx.state.now + (os.clock() - ctx.stateClock)
end

---------------------------------------------------------------------
-- Formatos
---------------------------------------------------------------------
function Kit.fmtInt(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local sep = ctx.lang == "es" and "." or ","
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1" .. sep)))
	if string.sub(out, 1, 1) == sep then
		out = string.sub(out, 2)
	end
	return (n < 0 and "-" or "") .. out
end

function Kit.fmtMoney(n: number): string
	local a = math.abs(n)
	local sign = n < 0 and "-" or ""
	local dec = ctx.lang == "es" and "," or "."
	local function short(v: number, suffix: string): string
		return sign .. "$" .. string.gsub(string.format("%.2f", v), "%.", dec) .. suffix
	end
	if a >= 1e9 then
		return short(a / 1e9, "B")
	elseif a >= 1e6 then
		return short(a / 1e6, "M")
	elseif a >= 1e5 then
		return sign .. "$" .. string.gsub(string.format("%.1f", a / 1e3), "%.", dec) .. "K"
	end
	return sign .. "$" .. Kit.fmtInt(a)
end

function Kit.fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Kit.fmtTons(t: number): string
	local s = t == math.floor(t) and tostring(t) or string.format("%.1f", t)
	if ctx.lang == "es" then
		s = string.gsub(s, "%.", ",")
	end
	return s .. " t"
end

-- Estrellas con las vacías en gris (usar en etiquetas con RichText = true)
function Kit.stars(n: number): string
	return '<font color="#F5B000">' .. string.rep("★", n) .. '</font><font color="#C4CBD7">' .. string.rep("★", 5 - n) .. "</font>"
end

---------------------------------------------------------------------
-- Creación de instancias
---------------------------------------------------------------------
function Kit.create(className: string, props: { [string]: any }, children: { Instance }?): any
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
local create = Kit.create

function Kit.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = radius and UDim.new(0, radius) or UDim.new(0.5, 0) })
end
local corner = Kit.corner

function Kit.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return create("UIStroke", {
		Color = color, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(l: number, r: number?, t: number?, b: number?): UIPadding
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l),
		PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l),
	})
end

function Kit.list(horizontal: boolean, gap: number, align: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return create("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

function Kit.grid(parent: Instance, cellHeight: number, columns: number, gap: number?): UIGridLayout
	local g = gap or 14
	return create("UIGridLayout", {
		Parent = parent, CellSize = UDim2.new(1 / columns, -g * (columns - 1) / columns, 0, cellHeight),
		CellPadding = UDim2.fromOffset(g, g), SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Kit.tween(obj: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function merge(base: { [string]: any }, extra: { [string]: any }?): { [string]: any }
	if extra then
		for k, v in extra do
			base[k] = v
		end
	end
	return base
end
Kit.merge = merge

-- Texto normal
function Kit.label(parent: Instance?, text: string, size: number, color: Color3?, font: Font?, props: { [string]: any }?): TextLabel
	return create("TextLabel", merge({
		Parent = parent, BackgroundTransparency = 1, Text = text, TextSize = size,
		TextColor3 = color or C.ink, FontFace = font or Kit.FONT_BODY,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, size + 6), TextTruncate = Enum.TextTruncate.AtEnd,
	}, props))
end

-- Título con la letra redondeada
function Kit.title(parent: Instance?, text: string, size: number, color: Color3?, props: { [string]: any }?): TextLabel
	return Kit.label(parent, text, size, color, Kit.FONT_TITLE, props)
end

-- Emoji grande centrado (los emojis se ven en Roblox sin subir imágenes)
function Kit.emoji(parent: Instance?, e: string, size: number, props: { [string]: any }?): TextLabel
	return create("TextLabel", merge({
		Parent = parent, BackgroundTransparency = 1, Text = e, TextSize = size, FontFace = Kit.FONT_BODY,
		Size = UDim2.fromOffset(size + 6, size + 6), TextColor3 = C.ink,
	}, props))
end

-- Tarjeta suave (dentro de los paneles)
function Kit.card(parent: Instance?, props: { [string]: any }?): Frame
	return create("Frame", merge({ Parent = parent, BackgroundColor3 = C.soft, Size = UDim2.new(1, 0, 0, 100), BorderSizePixel = 0 }, props), {
		corner(16),
	})
end

-- Panel blanco flotante con sombra (sobre el mapa)
function Kit.float(parent: Instance?, props: { [string]: any }?): Frame
	local holder = create("Frame", merge({ Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 50) }, props))
	create("Frame", {
		Name = "Shadow", Parent = holder, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.82,
		Position = UDim2.fromOffset(0, 4), Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = holder.ZIndex,
	}, { corner(18) })
	local body = create("Frame", {
		Name = "Body", Parent = holder, BackgroundColor3 = C.panel, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = holder.ZIndex,
	}, { corner(18) })
	return body
end

function Kit.progress(parent: Instance, props: { [string]: any }, color: Color3, back: Color3?): Frame
	local bar = create("Frame", merge({ Parent = parent, BackgroundColor3 = back or C.line, Size = UDim2.new(1, 0, 0, 10), BorderSizePixel = 0 }, props), {
		corner(),
	})
	return create("Frame", { Parent = bar, BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, { corner() })
end

function Kit.pill(parent: Instance?, text: string, color: Color3, props: { [string]: any }?): TextLabel
	return create("TextLabel", merge({
		Parent = parent, BackgroundColor3 = color, Text = text, TextColor3 = C.white, FontFace = Kit.FONT_TITLE,
		TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), BorderSizePixel = 0,
	}, props), { corner(), Kit.padding(10, 10, 0, 0) })
end

---------------------------------------------------------------------
-- Sonidos integrados en Roblox (no hay que subir nada)
---------------------------------------------------------------------
local sounds: { [string]: Sound } = {}
function Kit.setupSounds(parent: Instance)
	local kinds = {
		click = { 1.5, 0.25 }, money = { 1.2, 0.5 }, error = { 0.6, 0.4 }, level = { 0.9, 0.6 }, express = { 1.8, 0.5 },
		takeoff = { 0.75, 0.35 }, coin = { 2.2, 0.2 }, perfect = { 1.35, 0.6 },
	}
	for kind, info in kinds do
		sounds[kind] = create("Sound", { Parent = parent, SoundId = "rbxasset://sounds/electronicpingshort.wav", PlaybackSpeed = info[1], Volume = info[2] })
	end
end
function Kit.playSound(kind: string)
	local st = ctx.state
	if st and st.settings and st.settings.muted then
		return
	end
	local s = sounds[kind]
	if s then
		s:Play()
	end
end

---------------------------------------------------------------------
-- Botón «grueso»: base oscura debajo y cara de color encima (se hunde al pulsar)
---------------------------------------------------------------------
local STYLES = {
	orange = { C.orange, C.orangeDark },
	blue = { C.blue, C.blueDark },
	green = { C.green, C.greenDark },
	gold = { C.gold, C.goldDark },
	red = { C.red, Color3.fromRGB(185, 40, 40) },
	white = { C.white, C.grey },
	grey = { C.grey, C.greyDark },
}

function Kit.button(parent: Instance?, text: string, style: string, size: UDim2, onClick: () -> (), props: { [string]: any }?): TextButton
	local colors = STYLES[style] or STYLES.orange
	local holder = create("Frame", merge({ Parent = parent, BackgroundColor3 = colors[2], Size = size, BorderSizePixel = 0 }, props), {
		corner(14),
	})
	local face = create("TextButton", {
		Name = "Face", Parent = holder, BackgroundColor3 = colors[1], Size = UDim2.new(1, 0, 1, -4), Text = text,
		TextColor3 = style == "white" and C.ink or C.white, FontFace = Kit.FONT_TITLE, TextSize = 20, AutoButtonColor = false,
		TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0, ZIndex = holder.ZIndex,
	}, { corner(14), Kit.padding(8, 8, 0, 0) })
	face:SetAttribute("Enabled", true)
	face:SetAttribute("Style", style)
	face.Activated:Connect(function()
		if face:GetAttribute("Enabled") == false then
			Kit.playSound("error")
			return
		end
		Kit.playSound("click")
		face.Position = UDim2.fromOffset(0, 3)
		Kit.tween(face, 0.12, { Position = UDim2.fromOffset(0, 0) })
		onClick()
	end)
	return face
end

-- Activa o desactiva un botón grueso (gris = no disponible)
function Kit.setButton(face: TextButton, text: string?, enabled: boolean)
	if text and face.Text ~= text then
		face.Text = text
	end
	face:SetAttribute("Enabled", enabled)
	local style = face:GetAttribute("Style") :: string
	local colors = enabled and (STYLES[style] or STYLES.orange) or STYLES.grey
	face.BackgroundColor3 = colors[1]
	local holder = face.Parent :: Frame
	if holder then
		holder.BackgroundColor3 = colors[2]
	end
	face.TextColor3 = (enabled and style == "white") and C.ink or C.white
end

---------------------------------------------------------------------
-- Listas que se sincronizan con los datos (crea, actualiza y borra lo que sobra)
---------------------------------------------------------------------
export type Entry = { root: GuiObject, update: (any) -> () }
function Kit.syncList(cache: { [any]: Entry }, items: { any }, keyOf: (any) -> any, build: (any) -> Entry)
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

-- Zona con desplazamiento vertical
function Kit.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	return create("ScrollingFrame", merge({
		Parent = parent, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.grey, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, props), { Kit.padding(4, 12, 4, 16) })
end

-- Pestañas tipo «pastilla»: devuelve el contenedor y una función para repintarlas
function Kit.tabs(parent: Instance, list: { { id: string, text: string } }, current: () -> string, onPick: (string) -> ()): (Frame, () -> ())
	local row = create("Frame", { Parent = parent, BackgroundColor3 = C.soft, Size = UDim2.new(0, 0, 0, 46), AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0 }, {
		corner(), Kit.padding(4), Kit.list(true, 4),
	})
	local buttons = {}
	local function paint()
		for id, b in buttons do
			local active = current() == id
			b.BackgroundColor3 = active and C.white or C.soft
			b.BackgroundTransparency = active and 0 or 1
			b.TextColor3 = active and C.ink or C.muted
		end
	end
	for i, t in list do
		local b = create("TextButton", {
			Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X,
			Text = t.text, FontFace = Kit.FONT_TITLE, TextSize = 18, AutoButtonColor = false, BorderSizePixel = 0,
		}, { corner(), Kit.padding(18, 18, 0, 0) })
		b.Activated:Connect(function()
			Kit.playSound("click")
			onPick(t.id)
			paint()
		end)
		buttons[t.id] = b
		ctx.targets["tab_" .. t.id] = b
	end
	paint()
	return row, paint
end

---------------------------------------------------------------------
-- Reglas que el cliente necesita para mostrar estimaciones
-- (las mismas que el servidor, que vuelve a comprobarlo todo)
---------------------------------------------------------------------
function Kit.findPilot(id: number): any
	for _, p in ctx.state.pilots do
		if p.id == id then
			return p
		end
	end
	return nil
end

function Kit.pilotBusy(id: number): boolean
	for _, p in ctx.state.planes do
		if p.flight and p.flight.pilot == id then
			return true
		end
	end
	return false
end

-- Datos para Rules.quote sacados del estado (el servidor usa la misma función)
function Kit.view(): any
	local st = ctx.state
	return {
		upgrades = st.upgrades, moneyMult = st.moneyMult, fuelPrice = st.fuelPrice, timeMult = st.timeMult,
		event = st.event, wanted = st.wanted or {}, sat = st.sat or {}, album = st.album or { airports = {}, goods = {} },
	}
end

function Kit.flyBlock(plane: any, load: any): string?
	return Rules.canFly(Kit.view(), plane, load)
end

function Kit.quote(plane: any, load: any, pilotId: number): (number, number, number, number, { any })
	local pilot = pilotId > 0 and Kit.findPilot(pilotId) or nil
	return Rules.quote(Kit.view(), plane, load, pilot)
end

-- Texto corto de un modificador de pago: «🔥 ×1,5», «📉 −16%», «⚡»
function Kit.modText(m: any): string
	if m.kind == "sat" then
		return m.icon .. " −" .. math.floor((1 - m.mult) * 100 + 0.5) .. "%"
	elseif m.kind == "trait" then
		return m.icon
	end
	local v = string.format("%.1f", m.mult)
	if ctx.lang == "es" then
		v = string.gsub(v, "%.", ",")
	end
	return m.icon .. " ×" .. v
end

function Kit.traitName(id: string?): string
	local t = id and Config.TraitById[id]
	if not t then
		return ""
	end
	return t.emoji .. " " .. T("trait_" .. t.id)
end

function Kit.eventName(id: string): string
	local e = Config.EventById[id]
	return e and (e.emoji .. " " .. T("ev_" .. id)) or ""
end

function Kit.airlineColor(st: any): Color3
	local a = st and st.airline
	return Config.AirlineColors[a and a.color or 1] or C.orange
end

function Kit.planeName(model: string): string
	return T("plane_" .. model)
end

function Kit.goodName(good: string): string
	return Config.GoodById[good].emoji .. " " .. T("good_" .. good)
end

return Kit
