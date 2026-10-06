--[[
	TycoonClient (LocalScript en StarterPlayer > StarterPlayerScripts)

	Toda la interfaz: el dinero arriba, el botón del ordenador y la
	ventana con pestañas (Crear, Mis webs, Clientes, Anuncios, Empresas,
	Bolsa). El cliente solo muestra cosas y pide acciones: el servidor
	decide si se pueden hacer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local actionFunction = remotes:WaitForChild("Action") :: RemoteFunction
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local openComputerEvent = remotes:WaitForChild("OpenComputer") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local THEME = {
	bg = Color3.fromRGB(17, 24, 39),
	panel = Color3.fromRGB(31, 41, 55),
	card = Color3.fromRGB(45, 55, 72),
	accent = Color3.fromRGB(59, 130, 246),
	green = Color3.fromRGB(34, 197, 94),
	yellow = Color3.fromRGB(234, 179, 8),
	red = Color3.fromRGB(239, 68, 68),
	purple = Color3.fromRGB(168, 85, 247),
	orange = Color3.fromRGB(249, 115, 22),
	text = Color3.fromRGB(243, 244, 246),
	muted = Color3.fromRGB(156, 163, 175),
	disabled = Color3.fromRGB(75, 85, 99),
}

local fmt = Config.formatMoney
local num = Config.formatNumber

---------------------------------------------------------------------
-- Ayudas para crear interfaz
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

local function padding(px: number): UIPadding
	return create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function maxText(size: number): UITextSizeConstraint
	return create("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 8 })
end

local function makeLabel(parent: Instance, text: string, y: number, height: number, textSize: number, color: Color3?, bold: boolean?): TextLabel
	return create("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		Text = text,
		TextSize = textSize,
		TextColor3 = color or THEME.text,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function makeButton(parent: Instance?, text: string, color: Color3, size: UDim2, onClick: () -> ()): TextButton
	local button = create("TextButton", {
		Parent = parent,
		Size = size,
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
	}, { corner(8), maxText(16), padding(4) })
	button:SetAttribute("BaseColor", color)
	button:SetAttribute("Enabled", true)
	button.Activated:Connect(function()
		if button:GetAttribute("Enabled") ~= false then
			onClick()
		end
	end)
	return button
end

-- Cambia texto y si se puede pulsar (gris = no disponible)
local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3?)
	button.Text = text
	button:SetAttribute("Enabled", enabled)
	button.AutoButtonColor = enabled
	local base = color or button:GetAttribute("BaseColor") or THEME.accent
	button.BackgroundColor3 = if enabled then base else THEME.disabled
end

local function makeCard(parent: Instance, height: number, order: number): Frame
	return create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = THEME.card,
		LayoutOrder = order,
	}, { corner(10), padding(10) })
end

local function makeButtonRow(parent: Instance, y: number, height: number): Frame
	return create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- Mantiene una lista de filas sincronizada con los datos sin recrearla
-- entera cada segundo (así no parpadea ni pierde el scroll).
local function syncRows(container: Instance, rows: { [any]: any }, items: { any }, keyOf: (any) -> any, build: (any) -> any, update: (any, any) -> ())
	local seen = {}
	for i, item in items do
		local key = keyOf(item)
		seen[key] = true
		local row = rows[key]
		if not row then
			row = build(item)
			rows[key] = row
			row.frame.Parent = container
		end
		row.frame.LayoutOrder = 100 + i
		update(row, item)
	end
	for key, row in rows do
		if not seen[key] then
			row.frame:Destroy()
			rows[key] = nil
		end
	end
end

local showToast: (text: string, kind: string?) -> ()

local function sendAction(action: string, a: any?, b: any?)
	task.spawn(function()
		local ok, success, message = pcall(function()
			return actionFunction:InvokeServer(action, a, b)
		end)
		-- El servidor responde con un texto cuando hay algo que contar
		if ok and type(message) == "string" then
			showToast(message, if success then "success" else "error")
		end
	end)
end

---------------------------------------------------------------------
-- Pantalla principal
---------------------------------------------------------------------
local screenGui = create("ScreenGui", {
	Name = "ImperioWebUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- HUD superior (siempre visible)
local hud = create("Frame", {
	Parent = screenGui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.new(0.6, 0, 0, 74),
	BackgroundColor3 = THEME.bg,
	BackgroundTransparency = 0.15,
}, { corner(12), padding(6), create("UISizeConstraint", { MaxSize = Vector2.new(520, 74) }) })

local moneyLabel = create("TextLabel", {
	Parent = hud,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 34),
	Text = "💰 $0",
	TextColor3 = THEME.green,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
}, { maxText(32) })

local incomeLabel = create("TextLabel", {
	Parent = hud,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 36),
	Size = UDim2.new(1, 0, 0, 24),
	Text = "",
	TextColor3 = THEME.muted,
	Font = Enum.Font.GothamMedium,
	TextScaled = true,
}, { maxText(16) })

local eventLabel = create("TextLabel", {
	Parent = screenGui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 86),
	Size = UDim2.new(0.6, 0, 0, 30),
	BackgroundColor3 = THEME.purple,
	Text = "",
	TextColor3 = THEME.text,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	Visible = false,
}, { corner(10), padding(4), maxText(16), create("UISizeConstraint", { MaxSize = Vector2.new(520, 30) }) })

-- Botón para abrir el ordenador
local window: Frame
local openButton = makeButton(screenGui, "💻 Ordenador (M)", THEME.accent, UDim2.fromOffset(170, 46), function()
	window.Visible = not window.Visible
end)
openButton.AnchorPoint = Vector2.new(0, 0.5)
openButton.Position = UDim2.new(0, 10, 0.5, 0)

-- Ventana
window = create("Frame", {
	Parent = screenGui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromScale(0.94, 0.78),
	BackgroundColor3 = THEME.panel,
	Visible = false,
}, { corner(14), create("UISizeConstraint", { MaxSize = Vector2.new(900, 600) }) })

local header = create("Frame", {
	Parent = window,
	BackgroundColor3 = THEME.bg,
	Size = UDim2.new(1, 0, 0, 44),
}, { corner(14) })

create("TextLabel", {
	Parent = header,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 0),
	Size = UDim2.new(1, -70, 1, 0),
	Text = "🌐 Imperio Web — tu ordenador",
	TextColor3 = THEME.text,
	Font = Enum.Font.FredokaOne,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local closeButton = makeButton(header, "✕", THEME.red, UDim2.fromOffset(36, 32), function()
	window.Visible = false
end)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -8, 0.5, 0)

local tabBar = create("Frame", {
	Parent = window,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 50),
	Size = UDim2.new(1, -16, 0, 38),
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local content = create("Frame", {
	Parent = window,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 94),
	Size = UDim2.new(1, -16, 1, -102),
})

local TABS = {
	{ id = "create", name = "🖥️ Crear" },
	{ id = "sites", name = "🌐 Mis webs" },
	{ id = "clients", name = "🤝 Clientes" },
	{ id = "ads", name = "📢 Anuncios" },
	{ id = "companies", name = "🏢 Empresas" },
	{ id = "market", name = "📈 Bolsa" },
}

local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local renderers: { [string]: (any) -> () } = {}
local currentTab = "create"
local state: any = nil
local stateTime = os.clock()

local function makePage(id: string): ScrollingFrame
	local page = create("ScrollingFrame", {
		Parent = content,
		Name = id,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Visible = false,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	pages[id] = page
	return page
end

local function selectTab(id: string)
	currentTab = id
	for tabId, page in pages do
		page.Visible = tabId == id
		tabButtons[tabId].BackgroundColor3 = if tabId == id then THEME.accent else THEME.card
	end
	if state and renderers[id] then
		renderers[id](state)
	end
end

for i, tab in TABS do
	local button = makeButton(tabBar, tab.name, THEME.card, UDim2.new(1 / #TABS, -6, 1, 0), function()
		selectTab(tab.id)
	end)
	button.LayoutOrder = i
	tabButtons[tab.id] = button
	makePage(tab.id)
end

---------------------------------------------------------------------
-- Notificaciones
---------------------------------------------------------------------
local toastContainer = create("Frame", {
	Parent = screenGui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.6, 0, 0, 220),
	BackgroundTransparency = 1,
	ZIndex = 10,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}),
	create("UISizeConstraint", { MaxSize = Vector2.new(460, 220) }),
})

local TOAST_COLORS = {
	success = THEME.green,
	error = THEME.red,
	event = THEME.purple,
	goal = THEME.yellow,
	info = THEME.accent,
}
local toastOrder = 0

function showToast(text: string, kind: string?)
	toastOrder += 1
	local toast = create("TextLabel", {
		Parent = toastContainer,
		LayoutOrder = toastOrder,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = TOAST_COLORS[kind or "info"] or THEME.accent,
		BackgroundTransparency = 0.05,
		Text = text,
		TextColor3 = THEME.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
	}, { corner(10), padding(6), maxText(16) })

	-- Máximo 4 a la vez
	local toasts = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 4 do
		toasts[i]:Destroy()
	end

	task.delay(4, function()
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			toast:Destroy()
		end
	end)
end

notifyEvent.OnClientEvent:Connect(function(text: string, kind: string)
	showToast(text, kind)
end)

---------------------------------------------------------------------
-- Pestaña CREAR
---------------------------------------------------------------------
local pendingClickWork = 0
local createPage = pages.create

local projectCard = makeCard(createPage, 178, 1)
local projectTitle = makeLabel(projectCard, "Elige qué web programar 👇", 0, 24, 18, THEME.text, true)
projectTitle.Size = UDim2.new(1, -100, 0, 24)

local cancelButton = makeButton(projectCard, "Cancelar", THEME.red, UDim2.fromOffset(90, 24), function()
	sendAction("cancelProject")
end)
cancelButton.AnchorPoint = Vector2.new(1, 0)
cancelButton.Position = UDim2.new(1, 0, 0, 0)

local progressBack = create("Frame", {
	Parent = projectCard,
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundColor3 = THEME.bg,
}, { corner(8) })
local progressFill = create("Frame", {
	Parent = progressBack,
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = THEME.green,
}, { corner(8) })
local progressText = create("TextLabel", {
	Parent = progressBack,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	TextColor3 = THEME.text,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	ZIndex = 2,
})

local programButton: TextButton
programButton = makeButton(projectCard, "⌨️ PROGRAMAR", THEME.green, UDim2.new(1, 0, 0, 60), function()
	if not state or not state.project then
		return
	end
	pendingClickWork += state.clickPower
	sendAction("click")

	-- Efecto "+X" flotando
	local float = create("TextLabel", {
		Parent = projectCard,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.3 + math.random() * 0.4, 0, 0, 84),
		Size = UDim2.fromOffset(120, 30),
		Text = "+" .. num(state.clickPower),
		TextColor3 = THEME.yellow,
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		ZIndex = 5,
	})
	local tween = TweenService:Create(float, TweenInfo.new(0.7), {
		Position = float.Position - UDim2.fromOffset(0, 50),
		TextTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		float:Destroy()
	end)
end)
programButton.Position = UDim2.fromOffset(0, 62)
local programScale = create("UIScale", { Parent = programButton })
programButton.Activated:Connect(function()
	programScale.Scale = 0.94
	TweenService:Create(programScale, TweenInfo.new(0.15), { Scale = 1 }):Play()
end)

local projectInfo = makeLabel(projectCard, "", 130, 20, 14, THEME.muted)

local typeRows: { [string]: any } = {}
for i, def in Config.WebTypes do
	local card = makeCard(createPage, 92, 10 + i)
	local title = makeLabel(card, def.emoji .. " " .. def.name, 0, 24, 18, THEME.text, true)
	local info = makeLabel(card, "", 26, 18, 14, THEME.muted)
	local buttons = makeButtonRow(card, 48, 24)
	local createButton = makeButton(buttons, "Crear", THEME.accent, UDim2.new(0.5, -3, 1, 0), function()
		sendAction("startProject", def.id)
	end)
	local autoButton = makeButton(buttons, "🤖 Auto", THEME.purple, UDim2.new(0.5, -3, 1, 0), function()
		sendAction("setAuto", def.id)
	end)
	typeRows[def.id] = { title = title, info = info, create = createButton, auto = autoButton }
end

renderers.create = function(s)
	local project = s.project
	if project then
		local def = Config.WebTypeById[project.type]
		projectTitle.Text = "Programando: " .. def.emoji .. " " .. def.name
		setButton(programButton, "⌨️ PROGRAMAR  (+" .. num(s.clickPower) .. " por clic)", true)
		cancelButton.Visible = true
	else
		projectTitle.Text = "Elige qué web programar 👇"
		progressFill.Size = UDim2.fromScale(0, 1)
		progressText.Text = ""
		setButton(programButton, "Elige una web de la lista", false)
		cancelButton.Visible = false
	end

	local autoText = ""
	if s.autoType then
		autoText = " · 🤖 Auto: " .. Config.WebTypeById[s.autoType].name
	end
	projectInfo.Text = string.format("👩‍💻 %s trabajo/s · 🌐 Webs %d/%d · ⭐ %s rep%s", num(s.workPerSec), #s.sites, s.slots, num(s.reputation), autoText)

	local hasLab = (s.companies.ia_lab or 0) >= 1
	local full = #s.sites >= s.slots
	for _, def in Config.WebTypes do
		local row = typeRows[def.id]
		local locked = s.reputation < def.rep
		row.title.Text = def.emoji .. " " .. def.name .. (if locked then "  🔒 necesitas ⭐ " .. num(def.rep) else "")
		row.title.TextColor3 = if locked then THEME.muted else THEME.text
		row.info.Text = string.format("Coste %s · Trabajo %s · 👀 ~%s visitas/s · ⭐ +%d rep", fmt(def.cost), num(def.work), num(def.visits), def.repReward)

		local canCreate = not locked and not project and not full and s.money >= def.cost
		local createText = if locked then "🔒 Bloqueada"
			elseif project then "Ya programas otra"
			elseif full then "Sin huecos (vende o compra Hosting)"
			elseif s.money < def.cost then "Te faltan " .. fmt(def.cost - s.money)
			else "Crear (" .. fmt(def.cost) .. ")"
		setButton(row.create, createText, canCreate)

		row.auto.Visible = hasLab
		local isAuto = s.autoType == def.id
		setButton(row.auto, if isAuto then "🤖 Auto: ACTIVO" else "🤖 Auto", hasLab and not locked, if isAuto then THEME.orange else THEME.purple)
	end
end

---------------------------------------------------------------------
-- Pestaña MIS WEBS
---------------------------------------------------------------------
local sitesPage = pages.sites
local sitesHeader = makeCard(sitesPage, 72, 1)
local sitesSummary = makeLabel(sitesHeader, "", 0, 20, 15, THEME.text, true)
local bestNetworkButton = makeButton(sitesHeader, "📢 Poner la mejor app de anuncios en todas", THEME.purple, UDim2.new(1, 0, 0, 26), function()
	if not state then
		return
	end
	local bestId, bestValue = nil, -1
	for _, network in Config.AdNetworks do
		local value = network.rpv * (1 - network.penalty)
		if state.unlockedAds[network.id] and value > bestValue then
			bestId, bestValue = network.id, value
		end
	end
	if bestId then
		sendAction("setNetworkAll", bestId)
	end
end)
bestNetworkButton.Position = UDim2.fromOffset(0, 26)

local emptySites = makeCard(sitesPage, 50, 2)
makeLabel(emptySites, "Aún no tienes webs. Ve a 🖥️ Crear y programa la primera.", 0, 30, 15, THEME.muted)

local siteRows = {}

local function unlockedNetworkList(s): { any }
	local list = {}
	for _, network in Config.AdNetworks do
		if s.unlockedAds[network.id] then
			table.insert(list, network)
		end
	end
	return list
end

renderers.sites = function(s)
	local totalVisits, totalIncome = 0, 0
	for _, site in s.sites do
		totalVisits += site.visits
		totalIncome += site.income
	end
	sitesSummary.Text = string.format("🌐 %d/%d webs · 👀 %s visitas/s · 💵 %s/s por anuncios", #s.sites, s.slots, num(totalVisits), fmt(totalIncome))
	emptySites.Visible = #s.sites == 0

	syncRows(sitesPage, siteRows, s.sites, function(site)
		return site.id
	end, function(site)
		local card = makeCard(sitesPage, 100, 0)
		local row: any = { frame = card, id = site.id }
		row.title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
		row.info = makeLabel(card, "", 24, 18, 14, THEME.muted)
		local buttons = makeButtonRow(card, 50, 30)
		row.seo = makeButton(buttons, "SEO", THEME.accent, UDim2.new(0.25, -5, 1, 0), function()
			sendAction("upgradeSeo", row.id)
		end)
		row.network = makeButton(buttons, "Anuncios", THEME.purple, UDim2.new(0.25, -5, 1, 0), function()
			if not state then
				return
			end
			-- Pasa a la siguiente app de anuncios desbloqueada
			local list = unlockedNetworkList(state)
			local nextIndex = 1
			for i, network in list do
				if network.id == row.currentNetwork then
					nextIndex = i % #list + 1
				end
			end
			sendAction("setNetwork", row.id, list[nextIndex].id)
		end)
		row.level = makeButton(buttons, "Cantidad", THEME.orange, UDim2.new(0.25, -5, 1, 0), function()
			sendAction("setAdLevel", row.id, (row.currentLevel or 1) % #Config.AdLevels + 1)
		end)
		row.sell = makeButton(buttons, "Vender", THEME.red, UDim2.new(0.25, -5, 1, 0), function()
			sendAction("quickSell", row.id)
		end)
		return row
	end, function(row, site)
		local def = Config.WebTypeById[site.type]
		local network = Config.AdNetworkById[site.network]
		row.currentNetwork = site.network
		row.currentLevel = site.adLevel
		row.title.Text = (if site.viral then "🔥 " else "") .. def.emoji .. " " .. site.name .. "  ·  " .. def.name
		row.title.TextColor3 = if site.viral then THEME.orange else THEME.text
		row.info.Text = string.format("⭐ Calidad %d%% · 🔎 SEO %d/%d · 👀 %s visitas/s · 💵 %s/s",
			math.floor(site.quality * 100), site.seo, Config.MAX_SEO, num(site.visits), fmt(site.income))

		if site.seo >= Config.MAX_SEO then
			setButton(row.seo, "SEO MÁX", false)
		else
			setButton(row.seo, "🔎 SEO+ " .. fmt(site.seoCost), s.money >= site.seoCost)
		end
		local multiple = #unlockedNetworkList(s) > 1
		setButton(row.network, network.emoji .. " " .. network.name .. (if multiple then " ▸" else ""), multiple)
		setButton(row.level, "Anuncios: " .. Config.AdLevels[site.adLevel].name .. " ▸", true)
		setButton(row.sell, "Vender ya " .. fmt(site.saleBase * Config.QUICK_SALE_MULT), true)
	end)
end

---------------------------------------------------------------------
-- Pestaña CLIENTES
---------------------------------------------------------------------
local clientsPage = pages.clients
local clientsHeader = makeCard(clientsPage, 84, 1)
makeLabel(clientsHeader, "🤝 Empresas que quieren comprar webs", 0, 22, 17, THEME.text, true)
makeLabel(clientsHeader, "Pagan según las visitas de tu web. Cada venta te da reputación y un contrato de mantenimiento.", 22, 18, 13, THEME.muted)
local maintenanceLabel = makeLabel(clientsHeader, "", 42, 18, 14, THEME.green, true)

local offerRows = {}

local function bestSiteFor(s, typeId: string)
	local best = nil
	for _, site in s.sites do
		if site.type == typeId and (not best or site.saleBase > best.saleBase) then
			best = site
		end
	end
	return best
end

renderers.clients = function(s)
	maintenanceLabel.Text = "🔧 Contratos de mantenimiento: +" .. fmt(s.maintenance) .. "/s para siempre"

	syncRows(clientsPage, offerRows, s.offers, function(offer)
		return offer.id
	end, function(offer)
		local card = makeCard(clientsPage, 92, 0)
		local row: any = { frame = card, id = offer.id }
		row.title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
		row.info = makeLabel(card, "", 24, 18, 14, THEME.muted)
		row.sell = makeButton(card, "Vender", THEME.green, UDim2.new(1, 0, 0, 28), function()
			if row.siteId then
				sendAction("sellToOffer", row.id, row.siteId)
			end
		end)
		row.sell.Position = UDim2.fromOffset(0, 46)
		return row
	end, function(row, offer)
		local def = Config.WebTypeById[offer.type]
		local vip = offer.mult >= 3
		row.title.Text = (if vip then "👑 " else "🏢 ") .. offer.company .. " quiere: " .. def.emoji .. " " .. def.name
		row.title.TextColor3 = if vip then THEME.yellow else THEME.text
		row.info.Text = string.format("Paga x%.2f del valor · ⏱ %s", offer.mult, Config.formatTime(offer.timeLeft))
		local site = bestSiteFor(s, offer.type)
		row.siteId = site and site.id
		if site then
			setButton(row.sell, "Vender " .. site.name .. " por " .. fmt(site.saleBase * offer.mult), true)
		else
			setButton(row.sell, "No tienes ninguna " .. def.name, false)
		end
	end)
end

---------------------------------------------------------------------
-- Pestaña ANUNCIOS
---------------------------------------------------------------------
local adsPage = pages.ads
local adsHeader = makeCard(adsPage, 104, 1)
makeLabel(adsHeader, "📢 Apps de anuncios para tus webs", 0, 22, 17, THEME.text, true)
makeLabel(adsHeader, "Cada app paga distinto por visita, pero algunas molestan y espantan visitas.", 22, 18, 13, THEME.muted)
makeLabel(adsHeader, "Cantidad de anuncios: Pocos (x1 dinero) · Normal (x1.7, -12% visitas) · Muchos (x2.5, -32% visitas)", 42, 18, 13, THEME.muted)
makeLabel(adsHeader, "Truco: menos visitas = la web vale menos al venderla.", 62, 18, 13, THEME.yellow)

local networkRows = {}
for i, network in Config.AdNetworks do
	local card = makeCard(adsPage, 92, 10 + i)
	local title = makeLabel(card, network.emoji .. " " .. network.name, 0, 22, 17, THEME.text, true)
	makeLabel(card, string.format("Paga %s por visita · Pierdes %d%% de visitas · Requiere ⭐ %s",
		fmt(network.rpv), math.floor(network.penalty * 100), num(network.rep)), 24, 18, 14, THEME.muted)
	local button = makeButton(card, "", THEME.accent, UDim2.new(1, 0, 0, 26), function()
		sendAction("unlockNetwork", network.id)
	end)
	button.Position = UDim2.fromOffset(0, 46)
	networkRows[network.id] = { title = title, button = button }
end

renderers.ads = function(s)
	for _, network in Config.AdNetworks do
		local row = networkRows[network.id]
		if s.unlockedAds[network.id] then
			setButton(row.button, "✓ Desbloqueada", false, THEME.green)
			row.button.BackgroundColor3 = THEME.green
		elseif s.reputation < network.rep then
			setButton(row.button, "🔒 Necesitas ⭐ " .. num(network.rep) .. " de reputación", false)
		else
			setButton(row.button, "Desbloquear por " .. fmt(network.cost), s.money >= network.cost)
		end
	end
end

---------------------------------------------------------------------
-- Pestaña EMPRESAS
---------------------------------------------------------------------
local companiesPage = pages.companies
local companiesHeader = makeCard(companiesPage, 56, 1)
makeLabel(companiesHeader, "🏢 Tus empresas", 0, 22, 17, THEME.text, true)
local companiesSummary = makeLabel(companiesHeader, "", 22, 18, 14, THEME.green)

local companyRows = {}
for i, def in Config.Companies do
	local card = makeCard(companiesPage, 92, 10 + i)
	local title = makeLabel(card, "", 0, 22, 17, THEME.text, true)
	makeLabel(card, def.desc, 24, 18, 14, THEME.muted)
	local button = makeButton(card, "", THEME.accent, UDim2.new(1, 0, 0, 28), function()
		sendAction("buyCompany", def.id)
	end)
	button.Position = UDim2.fromOffset(0, 46)
	companyRows[def.id] = { title = title, button = button }
end

renderers.companies = function(s)
	companiesSummary.Text = "💵 Tus empresas generan " .. fmt(Config.companiesIncome(s, s.moneyMult)) .. "/s"
	for _, def in Config.Companies do
		local row = companyRows[def.id]
		local level = s.companies[def.id] or 0
		local incomeText = if def.income > 0 then " · +" .. fmt(def.income * s.moneyMult) .. "/s por nivel" else ""
		row.title.Text = def.emoji .. " " .. def.name .. "  —  Nivel " .. level .. incomeText
		if level >= def.maxLevel then
			setButton(row.button, "NIVEL MÁXIMO", false)
		else
			local cost = Config.companyCost(def.id, level)
			setButton(row.button, (if level == 0 then "Fundar por " else "Mejorar por ") .. fmt(cost), s.money >= cost)
		end
	end
end

---------------------------------------------------------------------
-- Pestaña BOLSA (prestigio, objetivos, estadísticas, tienda)
---------------------------------------------------------------------
local marketPage = pages.market
local ipoCard = makeCard(marketPage, 168, 1)
makeLabel(ipoCard, "📈 Salir a bolsa", 0, 22, 17, THEME.text, true)
local ipoInfo1 = makeLabel(ipoCard, "", 24, 18, 14, THEME.muted)
local ipoInfo2 = makeLabel(ipoCard, "", 44, 18, 14, THEME.green, true)
makeLabel(ipoCard, "Se reinicia: dinero, webs, empresas, apps y reputación.", 64, 18, 13, THEME.muted)
makeLabel(ipoCard, "Te quedas: acciones (+" .. math.floor(Config.SHARE_BONUS * 100) .. "% dinero cada una), objetivos y rascacielos extra.", 84, 18, 13, THEME.muted)
local confirmUntil = 0
local ipoButton: TextButton
ipoButton = makeButton(ipoCard, "", THEME.yellow, UDim2.new(1, 0, 0, 34), function()
	if os.clock() < confirmUntil then
		confirmUntil = 0
		sendAction("ipo")
	else
		confirmUntil = os.clock() + 3
		ipoButton.Text = "¿Seguro? Pulsa otra vez para confirmar"
	end
end)
ipoButton.Position = UDim2.fromOffset(0, 112)

local passCard = makeCard(marketPage, 70, 2)
makeLabel(passCard, "💎 Pase x2 Dinero: ganas el doble para siempre", 0, 22, 16, THEME.text, true)
local passButton = makeButton(passCard, "Comprar", THEME.purple, UDim2.new(1, 0, 0, 24), function()
	local passId = Config.Monetization.DOUBLE_MONEY_GAMEPASS_ID
	if passId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end
end)
passButton.Position = UDim2.fromOffset(0, 26)
passCard.Visible = Config.Monetization.DOUBLE_MONEY_GAMEPASS_ID ~= 0

local statsCard = makeCard(marketPage, 80, 3)
makeLabel(statsCard, "📊 Estadísticas", 0, 22, 17, THEME.text, true)
local statsLabel = makeLabel(statsCard, "", 24, 18, 14, THEME.muted)
local saveLabel = makeLabel(statsCard, "", 42, 18, 13, THEME.muted)

local goalsTitle = makeCard(marketPage, 40, 4)
makeLabel(goalsTitle, "🎯 Objetivos", 0, 20, 17, THEME.text, true)

local goalRows = {}
for i, goal in Config.Goals do
	local card = makeCard(marketPage, 40, 10 + i)
	goalRows[goal.id] = makeLabel(card, "", 0, 20, 14, THEME.muted)
end

renderers.market = function(s)
	ipoInfo1.Text = string.format("Ganado en esta partida: %s · Acciones: %d (x%.2f dinero)", fmt(s.totalEarned), s.shares, s.moneyMult)
	if s.ipoShares >= 1 then
		ipoInfo2.Text = "Si sales a bolsa ahora consigues +" .. s.ipoShares .. " acciones"
		if os.clock() >= confirmUntil then
			setButton(ipoButton, "📈 Salir a bolsa (+" .. s.ipoShares .. " acciones)", true)
		end
	else
		ipoInfo2.Text = "Necesitas ganar " .. fmt(Config.IPO_MIN_EARNED) .. " en esta partida"
		setButton(ipoButton, "Te faltan " .. fmt(Config.IPO_MIN_EARNED - s.totalEarned), false)
	end

	if s.hasPass then
		setButton(passButton, "✓ Ya lo tienes", false, THEME.green)
	end

	statsLabel.Text = string.format("Webs creadas %d · Vendidas %d · Clics %s · Ganado en total %s · Salidas a bolsa %d",
		s.stats.built, s.stats.sold, num(s.stats.clicks), fmt(s.lifetimeEarned), s.ipoCount)
	saveLabel.Text = if s.canSave then "💾 Tu partida se guarda automáticamente." else "⚠️ Guardado desactivado en esta sesión."

	for _, goal in Config.Goals do
		local done = s.goals[goal.id] == true
		local label = goalRows[goal.id]
		label.Text = (if done then "✅ " else "⬜ ") .. goal.text .. (if goal.reward > 0 then "  ·  premio " .. fmt(goal.reward) else "")
		label.TextColor3 = if done then THEME.green else THEME.text
	end
end

---------------------------------------------------------------------
-- Recibir estado del servidor
---------------------------------------------------------------------
stateEvent.OnClientEvent:Connect(function(newState)
	state = newState
	stateTime = os.clock()
	pendingClickWork = 0

	if newState.event then
		eventLabel.Visible = true
		eventLabel.Text = newState.event.name .. "  (" .. Config.formatTime(newState.event.timeLeft) .. ")"
	else
		eventLabel.Visible = false
	end

	if window.Visible and renderers[currentTab] then
		renderers[currentTab](newState)
	end
end)

-- Animación suave del dinero y de la barra de progreso entre actualizaciones
RunService.RenderStepped:Connect(function()
	if not state then
		return
	end
	local elapsed = math.min(os.clock() - stateTime, 1.5)
	moneyLabel.Text = "💰 " .. fmt(state.money + state.income * elapsed)
	incomeLabel.Text = string.format("+%s/s  ·  ⭐ %s rep  ·  📈 %d acciones", fmt(state.income), num(state.reputation), state.shares)

	local project = state.project
	if project and window.Visible and currentTab == "create" then
		local progress = math.min(project.progress + pendingClickWork + state.workPerSec * elapsed, project.required)
		progressFill.Size = UDim2.fromScale(progress / project.required, 1)
		progressText.Text = num(progress) .. " / " .. num(project.required)
	end
end)

---------------------------------------------------------------------
-- Abrir y cerrar
---------------------------------------------------------------------
window:GetPropertyChangedSignal("Visible"):Connect(function()
	if window.Visible and state and renderers[currentTab] then
		renderers[currentTab](state)
	end
end)

openComputerEvent.OnClientEvent:Connect(function()
	window.Visible = true
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		window.Visible = not window.Visible
	end
end)

selectTab("create")
task.delay(2, function()
	showToast("👋 ¡Bienvenido a Imperio Web! Abre el 💻 Ordenador y programa tu primera web.", "info")
end)
