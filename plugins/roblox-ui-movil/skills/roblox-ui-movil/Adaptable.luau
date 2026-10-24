--!nonstrict
--[[
	Adaptable: que la interfaz funcione igual de bien en PC, móvil, tableta y consola.
	Ponlo en ReplicatedStorage (ModuleScript «Adaptable») y úsalo desde LocalScripts:

		local Adaptable = require(ReplicatedStorage.Adaptable)
		Adaptable.escalar(lienzo, Vector2.new(1280, 720))   -- escala todo el diseño base
		print(Adaptable.dispositivo())                         -- "Tactil" | "Raton" | "Mando"
		Adaptable.alCambiar(function(info) ... end)            -- giro de pantalla, cambio de control
		Adaptable.textoAjustado(label, 14, 32)                 -- TextScaled con mínimo y máximo
		Adaptable.zonaSegura(frame)                            -- no tapar la barra de Roblox ni la muesca

	Medidas de referencia (tamaño REAL en pantalla, después de escalar):
	- Botón para el dedo: mínimo 44×44 px (mejor 56). Texto: mínimo 14 px (mejor 16+).
	- Móvil horizontal típico: 844×390 (iPhone), 800×360 (Android). Tableta: 1024×768.
	- Abajo a la derecha está el botón de SALTAR de Roblox y abajo a la izquierda el joystick: no pongas
	  botones ahí en táctil. Arriba a la izquierda está el menú de Roblox y el chat.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Adaptable = {}

export type Info = {
	ancho: number,
	alto: number,
	dispositivo: string, -- "Tactil" | "Raton" | "Mando"
	movil: boolean, -- pantalla pequeña (alto < 500 px)
	vertical: boolean, -- más alto que ancho
	escala: number, -- última escala calculada por escalar()
}

local oyentes: { (Info) -> () } = {}
local ultimaEscala = 1

function Adaptable.dispositivo(): string
	local ultimo = UserInputService:GetLastInputType()
	if ultimo == Enum.UserInputType.Touch then
		return "Tactil"
	end
	if string.find(ultimo.Name, "Gamepad") then
		return "Mando"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
		return "Tactil"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Mando"
	end
	return "Raton"
end

function Adaptable.info(): Info
	local camara = Workspace.CurrentCamera
	local v = if camara then camara.ViewportSize else Vector2.new(1280, 720)
	return {
		ancho = v.X,
		alto = v.Y,
		dispositivo = Adaptable.dispositivo(),
		movil = v.Y < 500 or v.X < 700,
		vertical = v.Y > v.X,
		escala = ultimaEscala,
	}
end

local function avisar()
	local i = Adaptable.info()
	for _, f in oyentes do
		task.spawn(f, i)
	end
end

-- Llama a f(info) ahora y cada vez que cambie el tamaño de pantalla o el tipo de control
function Adaptable.alCambiar(f: (Info) -> ())
	table.insert(oyentes, f)
	task.spawn(f, Adaptable.info())
end

local conectado = false
local function conectar()
	if conectado then
		return
	end
	conectado = true
	local function engancharCamara()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(avisar)
		end
	end
	engancharCamara()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(engancharCamara)
	local anterior = Adaptable.dispositivo()
	UserInputService.LastInputTypeChanged:Connect(function()
		local ahora = Adaptable.dispositivo()
		if ahora ~= anterior then
			anterior = ahora
			avisar()
		end
	end)
end

--[[ Escala un Frame diseñado a tamaño fijo (base, p. ej. 1280×720) para que quepa en cualquier pantalla.
	- minimo: escala mínima para que el texto se siga leyendo en el móvil (0,7 por defecto). Si ni así
	  cabe a lo ancho, usa lo que quepa.
	- El Frame debe tener AnchorPoint (0.5, 0.5) y Position (0.5, 0.5) para quedar centrado. ]]
function Adaptable.escalar(frame: GuiObject, base: Vector2, minimo: number?): UIScale
	conectar()
	local esc = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	esc.Parent = frame
	Adaptable.alCambiar(function(i)
		local s = math.min(i.ancho / base.X, i.alto / base.Y)
		s = math.max(s, math.min(minimo or 0.7, i.ancho / base.X))
		esc.Scale = s
		ultimaEscala = s
	end)
	return esc
end

-- Texto que se ajusta al hueco pero sin bajar de un mínimo legible ni pasar de un máximo
function Adaptable.textoAjustado(label: any, minimo: number?, maximo: number?)
	label.TextScaled = true
	local c = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	c.MinTextSize = minimo or 14
	c.MaxTextSize = maximo or 48
	c.Parent = label
	return c
end

-- Proporción fija (para que una tarjeta o icono no se deforme al estirar)
function Adaptable.proporcion(obj: GuiObject, ancho: number, alto: number)
	local c = obj:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	c.AspectRatio = ancho / alto
	c.Parent = obj
	return c
end

-- Hueco que ocupa la barra superior de Roblox (para no poner nada debajo)
function Adaptable.margenSuperior(): number
	local arriba = GuiService:GetGuiInset()
	return arriba.Y
end

--[[ Mete un Frame dentro de la zona segura: lo separa de la barra de Roblox, la muesca del móvil
	y los bordes redondeados. Pon el ScreenGui con ScreenInsets = CoreUISafeInsets y esto es un extra
	para Frames sueltos que se pegan a los bordes. ]]
function Adaptable.zonaSegura(frame: GuiObject, extra: number?)
	local pad = frame:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	local e = extra or 8
	pad.PaddingTop = UDim.new(0, Adaptable.margenSuperior() + e)
	pad.PaddingLeft = UDim.new(0, e)
	pad.PaddingRight = UDim.new(0, e)
	pad.PaddingBottom = UDim.new(0, e)
	pad.Parent = frame
	return pad
end

--[[ Coloca un botón en la «zona del pulgar» según el dispositivo:
	en táctil, a media altura en el lateral (lejos del joystick y del botón de saltar);
	con ratón, donde lo pusiste. lado: "izquierda" | "derecha" ]]
function Adaptable.zonaPulgar(boton: GuiObject, lado: string, posicionRaton: UDim2)
	Adaptable.alCambiar(function(i)
		if i.dispositivo == "Tactil" then
			if lado == "derecha" then
				boton.AnchorPoint = Vector2.new(1, 0.5)
				boton.Position = UDim2.new(1, -16, 0.45, 0)
			else
				boton.AnchorPoint = Vector2.new(0, 0.5)
				boton.Position = UDim2.new(0, 16, 0.45, 0)
			end
		else
			boton.Position = posicionRaton
		end
	end)
end

-- Texto de la tecla/acción según el control: Adaptable.tecla("E", "ButtonX") → "E" / "X" / "Toca"
function Adaptable.tecla(teclado: string, mando: string?): string
	local d = Adaptable.dispositivo()
	if d == "Tactil" then
		return "Toca"
	elseif d == "Mando" then
		return string.gsub(mando or "ButtonX", "Button", "")
	end
	return teclado
end

--[[ Selección con mando: hace que los botones de una ventana se puedan recorrer con la cruceta.
	Llama al abrir la ventana con el primer botón seleccionado. ]]
function Adaptable.seleccionarConMando(primero: GuiObject)
	if Adaptable.dispositivo() == "Mando" then
		GuiService.SelectedObject = primero
	end
end

return Adaptable
