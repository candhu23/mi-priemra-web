--[[
	STEAL AN ALIEN — interfaz (LocalScript)
	Va en StarterPlayer > StarterPlayerScripts.
	Muestra el dinero, los ingresos, los avisos, el evento de suerte y la tienda.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local jugador = Players.LocalPlayer
local compartido = ReplicatedStorage:WaitForChild("StealAnAlien")
local eventoAviso = compartido:WaitForChild("Aviso")

local function abreviar(n)
	local sufijos = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	while n >= 1000 and i < #sufijos do
		n = n / 1000
		i = i + 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f%s", n, sufijos[i])
end

---------------------------------------------------------------------
-- PROMPTS: "Steal" solo en bases ajenas, "Sell" solo en la tuya
---------------------------------------------------------------------
local function ajustarPrompt(prompt, esRobar)
	local function actualizar()
		local esMio = prompt:GetAttribute("Dueno") == jugador.UserId
		if esRobar then
			prompt.Enabled = not esMio
		else
			prompt.Enabled = esMio
		end
	end
	actualizar()
	prompt:GetAttributeChangedSignal("Dueno"):Connect(actualizar)
end

for _, etiqueta in ipairs({ "PromptRobar", "PromptVender" }) do
	local esRobar = etiqueta == "PromptRobar"
	for _, prompt in ipairs(CollectionService:GetTagged(etiqueta)) do
		ajustarPrompt(prompt, esRobar)
	end
	CollectionService:GetInstanceAddedSignal(etiqueta):Connect(function(prompt)
		ajustarPrompt(prompt, esRobar)
	end)
end

---------------------------------------------------------------------
-- ESTILO
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = jugador:WaitForChild("PlayerGui")

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio or 12)
	esquina.Parent = objeto
end

local function borde(objeto, color)
	local trazo = Instance.new("UIStroke")
	trazo.Thickness = 3
	trazo.Color = color or Color3.new(0, 0, 0)
	trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	trazo.Parent = objeto
end

local function texto(padre, propiedades)
	local etiqueta = Instance.new("TextLabel")
	etiqueta.BackgroundTransparency = 1
	etiqueta.Font = Enum.Font.FredokaOne
	etiqueta.TextScaled = true
	etiqueta.TextColor3 = Color3.new(1, 1, 1)
	etiqueta.TextStrokeTransparency = 0
	for k, v in pairs(propiedades) do
		etiqueta[k] = v
	end
	etiqueta.Parent = padre
	return etiqueta
end

---------------------------------------------------------------------
-- DINERO E INGRESOS
---------------------------------------------------------------------
local panelDinero = Instance.new("Frame")
panelDinero.AnchorPoint = Vector2.new(0.5, 1)
panelDinero.Position = UDim2.new(0.5, 0, 1, -12)
panelDinero.Size = UDim2.fromOffset(240, 70)
panelDinero.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
panelDinero.BackgroundTransparency = 0.2
panelDinero.Parent = gui
redondear(panelDinero)
borde(panelDinero, Color3.fromRGB(0, 255, 200))

local etiquetaDinero = texto(panelDinero, {
	Size = UDim2.new(1, -16, 0.6, 0),
	Position = UDim2.fromOffset(8, 4),
	Text = "$0",
	TextColor3 = Color3.fromRGB(120, 255, 150),
})
local etiquetaIngreso = texto(panelDinero, {
	Size = UDim2.new(1, -16, 0.32, 0),
	Position = UDim2.new(0, 8, 0.62, 0),
	Text = "+$0/s",
	TextColor3 = Color3.fromRGB(200, 255, 220),
})

local function actualizarIngreso()
	etiquetaIngreso.Text = "+$" .. abreviar(jugador:GetAttribute("Ingreso") or 0) .. "/s"
end
jugador:GetAttributeChangedSignal("Ingreso"):Connect(actualizarIngreso)
actualizarIngreso()

task.spawn(function()
	local cash = jugador:WaitForChild("leaderstats"):WaitForChild("Cash")
	local function actualizar()
		etiquetaDinero.Text = "$" .. abreviar(cash.Value)
	end
	cash.Changed:Connect(actualizar)
	actualizar()
end)

---------------------------------------------------------------------
-- AVISOS
---------------------------------------------------------------------
local listaAvisos = Instance.new("Frame")
listaAvisos.AnchorPoint = Vector2.new(0.5, 0)
listaAvisos.Position = UDim2.new(0.5, 0, 0, 70)
listaAvisos.Size = UDim2.new(0.6, 0, 0, 200)
listaAvisos.BackgroundTransparency = 1
listaAvisos.Parent = gui
local orden = Instance.new("UIListLayout")
orden.HorizontalAlignment = Enum.HorizontalAlignment.Center
orden.Padding = UDim.new(0, 4)
orden.Parent = listaAvisos

eventoAviso.OnClientEvent:Connect(function(mensaje, color)
	local etiqueta = texto(listaAvisos, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = mensaje,
		TextColor3 = color or Color3.new(1, 1, 1),
	})
	if #listaAvisos:GetChildren() > 6 then
		for _, hijo in ipairs(listaAvisos:GetChildren()) do
			if hijo:IsA("TextLabel") and hijo ~= etiqueta then
				hijo:Destroy()
				break
			end
		end
	end
	task.delay(3.5, function()
		local desvanecer = TweenService:Create(etiqueta, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
		desvanecer:Play()
		desvanecer.Completed:Wait()
		etiqueta:Destroy()
	end)
end)

---------------------------------------------------------------------
-- EVENTO DE SUERTE Y AVISO DE "LLEVANDO"
---------------------------------------------------------------------
local bannerSuerte = texto(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(420, 50),
	Text = "",
	TextColor3 = Color3.fromRGB(120, 255, 120),
	Visible = false,
})

local bannerLlevando = texto(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -95),
	Size = UDim2.fromOffset(420, 40),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 220, 80),
	Visible = false,
})

task.spawn(function()
	while true do
		local restante = math.ceil((compartido:GetAttribute("SuerteHasta") or 0) - workspace:GetServerTimeNow())
		bannerSuerte.Visible = restante > 0
		if restante > 0 then
			bannerSuerte.Text = string.format("🍀 LUCKY BELT %d:%02d", math.floor(restante / 60), restante % 60)
		end
		local llevando = jugador:GetAttribute("Llevando")
		bannerLlevando.Visible = llevando ~= nil
		if llevando then
			bannerLlevando.Text = "🏃 Carrying " .. llevando .. " — run to your base!"
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------
-- TIENDA
---------------------------------------------------------------------
local ARTICULOS = {
	{ clave = "PASE_DOBLE_DINERO", tipo = "pase", titulo = "💰 2x Cash", descripcion = "Double income forever" },
	{ clave = "PASE_VIP", tipo = "pase", titulo = "👑 VIP", descripcion = "+4 speed, 120s lock" },
	{ clave = "PRODUCTO_SUERTE_SERVIDOR", tipo = "producto", titulo = "🍀 Server Luck", descripcion = "x4 rare aliens for EVERYONE (3 min)" },
	{ clave = "PRODUCTO_DINERO_PEQUENO", tipo = "producto", titulo = "💵 Cash Pack", descripcion = "10 minutes of income" },
	{ clave = "PRODUCTO_DINERO_GRANDE", tipo = "producto", titulo = "💎 Mega Cash", descripcion = "1 hour of income" },
}

local botonTienda = Instance.new("TextButton")
botonTienda.AnchorPoint = Vector2.new(0, 0.5)
botonTienda.Position = UDim2.new(0, 12, 0.5, 0)
botonTienda.Size = UDim2.fromOffset(110, 50)
botonTienda.BackgroundColor3 = Color3.fromRGB(255, 190, 30)
botonTienda.Font = Enum.Font.FredokaOne
botonTienda.TextScaled = true
botonTienda.Text = "🛒 SHOP"
botonTienda.TextColor3 = Color3.new(1, 1, 1)
botonTienda.TextStrokeTransparency = 0
botonTienda.Parent = gui
redondear(botonTienda)
borde(botonTienda)

local tienda = Instance.new("Frame")
tienda.AnchorPoint = Vector2.new(0.5, 0.5)
tienda.Position = UDim2.fromScale(0.5, 0.5)
tienda.Size = UDim2.fromOffset(380, 400)
tienda.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
tienda.Visible = false
tienda.Parent = gui
redondear(tienda, 16)
borde(tienda, Color3.fromRGB(255, 190, 30))
local limiteTienda = Instance.new("UISizeConstraint")
limiteTienda.MaxSize = Vector2.new(380, 400)
limiteTienda.Parent = tienda
tienda.Size = UDim2.new(0.9, 0, 0.8, 0)

texto(tienda, { Size = UDim2.new(1, -60, 0, 40), Position = UDim2.fromOffset(12, 8), Text = "SHOP", TextXAlignment = Enum.TextXAlignment.Left })

local cerrar = Instance.new("TextButton")
cerrar.Size = UDim2.fromOffset(36, 36)
cerrar.Position = UDim2.new(1, -46, 0, 10)
cerrar.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
cerrar.Text = "X"
cerrar.Font = Enum.Font.FredokaOne
cerrar.TextScaled = true
cerrar.TextColor3 = Color3.new(1, 1, 1)
cerrar.Parent = tienda
redondear(cerrar, 8)

local listaTienda = Instance.new("ScrollingFrame")
listaTienda.Position = UDim2.fromOffset(10, 56)
listaTienda.Size = UDim2.new(1, -20, 1, -66)
listaTienda.BackgroundTransparency = 1
listaTienda.ScrollBarThickness = 6
listaTienda.AutomaticCanvasSize = Enum.AutomaticSize.Y
listaTienda.CanvasSize = UDim2.new()
listaTienda.Parent = tienda
local ordenTienda = Instance.new("UIListLayout")
ordenTienda.Padding = UDim.new(0, 8)
ordenTienda.Parent = listaTienda

for _, articulo in ipairs(ARTICULOS) do
	local id = compartido:GetAttribute(articulo.clave) or 0
	local fila = Instance.new("TextButton")
	fila.Size = UDim2.new(1, -8, 0, 60)
	fila.BackgroundColor3 = id ~= 0 and Color3.fromRGB(60, 50, 100) or Color3.fromRGB(50, 50, 55)
	fila.Text = ""
	fila.AutoButtonColor = id ~= 0
	fila.Parent = listaTienda
	redondear(fila, 10)
	texto(fila, { Size = UDim2.new(1, -16, 0.55, 0), Position = UDim2.fromOffset(8, 2), Text = articulo.titulo, TextXAlignment = Enum.TextXAlignment.Left })
	texto(fila, {
		Size = UDim2.new(1, -16, 0.38, 0),
		Position = UDim2.new(0, 8, 0.58, 0),
		Text = id ~= 0 and articulo.descripcion or "Coming soon",
		TextColor3 = Color3.fromRGB(200, 200, 230),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	fila.Activated:Connect(function()
		if id == 0 then
			return
		end
		if articulo.tipo == "pase" then
			MarketplaceService:PromptGamePassPurchase(jugador, id)
		else
			MarketplaceService:PromptProductPurchase(jugador, id)
		end
	end)
end

botonTienda.Activated:Connect(function()
	tienda.Visible = not tienda.Visible
end)
cerrar.Activated:Connect(function()
	tienda.Visible = false
end)
