--!nonstrict
--[[
	Ambiente: iluminación, cielo, niebla, efectos de cámara y partículas con buen aspecto.
	Ponlo en ReplicatedStorage (ModuleScript «Ambiente»).

	Desde el SERVIDOR (lo ven todos):
		local Ambiente = require(ReplicatedStorage.Ambiente)
		Ambiente.preset("soleado")                  -- o "atardecer", "noche", "magico", "caramelo", "cueva", "espacio", "submarino"
		Ambiente.cicloDiaNoche(16 * 60)             -- un día completo cada 16 minutos

	Desde el CLIENTE (solo ese jugador, p. ej. al entrar en una zona):
		Ambiente.transicion("magico", 2)            -- cambia poco a poco en 2 s

	Partículas (servidor o cliente):
		Ambiente.particulas(pieza, "destellos", { color = Color3.fromRGB(255, 220, 80) })
		Ambiente.aura(mascota.PrimaryPart, "Legendario")
		Ambiente.estela(espada, Color3.fromRGB(80, 200, 255))
		Ambiente.resaltar(modelo, Color3.fromRGB(255, 255, 0))
		Ambiente.estallido(posicion, "monedas")      -- explosión puntual que se borra sola

	Notas:
	- Lighting.Technology NO se puede cambiar por script: pon «Future» en Studio (Lighting → Technology)
	  o en el default.project.json de Rojo.
	- Las texturas de partículas usan las que trae Roblox (rbxasset://textures/particles/...), que
	  existen en todos los juegos. Cámbialas por las tuyas (rbxassetid://...) si quieres.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ambiente = {}

local TEX = {
	destello = "rbxasset://textures/particles/sparkles_main.dds",
	humo = "rbxasset://textures/particles/smoke_main.dds",
	fuego = "rbxasset://textures/particles/fire_main.dds",
	luz = "rbxasset://textures/particles/sparkles_main.dds",
}
Ambiente.texturas = TEX

--[[ Presets. Cada uno: propiedades de Lighting + Atmosphere + ColorCorrection + Bloom + SunRays.
	Ajusta a tu gusto; los valores están probados para estilo «cartoon» en Technology = Future. ]]
Ambiente.presets = {
	soleado = {
		luz = { ClockTime = 14, Brightness = 2.4, Ambient = Color3.fromRGB(120, 120, 135), OutdoorAmbient = Color3.fromRGB(150, 150, 160), EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.6, ExposureCompensation = 0.1, ShadowSoftness = 0.25 },
		atmosfera = { Density = 0.28, Offset = 0.15, Color = Color3.fromRGB(200, 225, 255), Decay = Color3.fromRGB(120, 160, 220), Glare = 0.2, Haze = 1 },
		color = { Brightness = 0.03, Contrast = 0.12, Saturation = 0.2, TintColor = Color3.fromRGB(255, 252, 245) },
		bloom = { Intensity = 0.6, Size = 24, Threshold = 1.6 },
		rayos = { Intensity = 0.06, Spread = 0.7 },
	},
	atardecer = {
		luz = { ClockTime = 17.8, Brightness = 2, Ambient = Color3.fromRGB(120, 90, 100), OutdoorAmbient = Color3.fromRGB(160, 120, 120), EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.6, ExposureCompensation = 0.15, ShadowSoftness = 0.35 },
		atmosfera = { Density = 0.38, Offset = 0.2, Color = Color3.fromRGB(255, 190, 150), Decay = Color3.fromRGB(190, 100, 120), Glare = 0.6, Haze = 1.6 },
		color = { Brightness = 0.02, Contrast = 0.15, Saturation = 0.25, TintColor = Color3.fromRGB(255, 230, 210) },
		bloom = { Intensity = 0.9, Size = 30, Threshold = 1.3 },
		rayos = { Intensity = 0.12, Spread = 0.8 },
	},
	noche = {
		luz = { ClockTime = 0, Brightness = 1, Ambient = Color3.fromRGB(60, 70, 110), OutdoorAmbient = Color3.fromRGB(70, 80, 130), EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0.3, ShadowSoftness = 0.4 },
		atmosfera = { Density = 0.35, Offset = 0.1, Color = Color3.fromRGB(80, 100, 160), Decay = Color3.fromRGB(40, 50, 100), Glare = 0, Haze = 1.2 },
		color = { Brightness = 0.02, Contrast = 0.15, Saturation = 0.1, TintColor = Color3.fromRGB(215, 225, 255) },
		bloom = { Intensity = 1, Size = 32, Threshold = 1 },
		rayos = { Intensity = 0, Spread = 0.5 },
	},
	magico = {
		luz = { ClockTime = 20.5, Brightness = 1.6, Ambient = Color3.fromRGB(120, 80, 160), OutdoorAmbient = Color3.fromRGB(150, 100, 200), EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.8, ExposureCompensation = 0.25, ShadowSoftness = 0.5 },
		atmosfera = { Density = 0.42, Offset = 0.25, Color = Color3.fromRGB(210, 150, 255), Decay = Color3.fromRGB(110, 60, 200), Glare = 0.4, Haze = 2 },
		color = { Brightness = 0.04, Contrast = 0.18, Saturation = 0.35, TintColor = Color3.fromRGB(240, 225, 255) },
		bloom = { Intensity = 1.2, Size = 36, Threshold = 0.9 },
		rayos = { Intensity = 0.05, Spread = 0.6 },
	},
	caramelo = {
		luz = { ClockTime = 13, Brightness = 2.6, Ambient = Color3.fromRGB(160, 130, 150), OutdoorAmbient = Color3.fromRGB(190, 160, 180), EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0.15, ShadowSoftness = 0.3 },
		atmosfera = { Density = 0.3, Offset = 0.2, Color = Color3.fromRGB(255, 200, 230), Decay = Color3.fromRGB(255, 150, 200), Glare = 0.3, Haze = 1.4 },
		color = { Brightness = 0.04, Contrast = 0.1, Saturation = 0.35, TintColor = Color3.fromRGB(255, 240, 250) },
		bloom = { Intensity = 0.7, Size = 28, Threshold = 1.4 },
		rayos = { Intensity = 0.05, Spread = 0.6 },
	},
	cueva = {
		luz = { ClockTime = 0, Brightness = 0.3, Ambient = Color3.fromRGB(40, 40, 55), OutdoorAmbient = Color3.fromRGB(35, 35, 50), EnvironmentDiffuseScale = 0.2, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.4, ShadowSoftness = 0.2 },
		atmosfera = { Density = 0.55, Offset = 0, Color = Color3.fromRGB(60, 60, 80), Decay = Color3.fromRGB(20, 20, 30), Glare = 0, Haze = 2.5 },
		color = { Brightness = 0, Contrast = 0.2, Saturation = -0.05, TintColor = Color3.fromRGB(220, 225, 255) },
		bloom = { Intensity = 1.1, Size = 30, Threshold = 0.9 },
		rayos = { Intensity = 0, Spread = 0.5 },
	},
	espacio = {
		luz = { ClockTime = 0, Brightness = 1.2, Ambient = Color3.fromRGB(70, 60, 110), OutdoorAmbient = Color3.fromRGB(80, 70, 130), EnvironmentDiffuseScale = 0.3, EnvironmentSpecularScale = 1, ExposureCompensation = 0.2, ShadowSoftness = 0.1 },
		atmosfera = { Density = 0, Offset = 0, Color = Color3.fromRGB(0, 0, 0), Decay = Color3.fromRGB(0, 0, 0), Glare = 0, Haze = 0 },
		color = { Brightness = 0.02, Contrast = 0.25, Saturation = 0.2, TintColor = Color3.fromRGB(235, 230, 255) },
		bloom = { Intensity = 1.3, Size = 40, Threshold = 0.8 },
		rayos = { Intensity = 0, Spread = 0.5 },
	},
	submarino = {
		luz = { ClockTime = 12, Brightness = 1.4, Ambient = Color3.fromRGB(40, 110, 140), OutdoorAmbient = Color3.fromRGB(50, 130, 160), EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.2, ShadowSoftness = 0.6 },
		atmosfera = { Density = 0.6, Offset = 0, Color = Color3.fromRGB(60, 170, 200), Decay = Color3.fromRGB(20, 80, 130), Glare = 0, Haze = 3 },
		color = { Brightness = 0, Contrast = 0.1, Saturation = 0.1, TintColor = Color3.fromRGB(190, 235, 255) },
		bloom = { Intensity = 0.8, Size = 30, Threshold = 1.2 },
		rayos = { Intensity = 0.15, Spread = 1 },
	},
}

-- Devuelve (o crea) un efecto dentro de Lighting por clase
local function efecto(clase: string): Instance
	local e = Lighting:FindFirstChildOfClass(clase)
	if not e then
		e = Instance.new(clase)
		e.Parent = Lighting
	end
	return e
end

local function poner(inst: Instance, props: { [string]: any })
	for k, v in props do
		(inst :: any)[k] = v
	end
end

-- Aplica un preset al instante
function Ambiente.preset(nombre: string)
	local p = Ambiente.presets[nombre]
	assert(p, "Ambiente: no existe el preset " .. tostring(nombre))
	poner(Lighting, p.luz)
	Lighting.GlobalShadows = true
	poner(efecto("Atmosphere"), p.atmosfera)
	poner(efecto("ColorCorrectionEffect"), p.color)
	poner(efecto("BloomEffect"), p.bloom)
	poner(efecto("SunRaysEffect"), p.rayos)
end

-- Cambia poco a poco a otro preset (ideal desde el cliente al entrar en una zona)
function Ambiente.transicion(nombre: string, segundos: number?)
	local p = Ambiente.presets[nombre]
	assert(p, "Ambiente: no existe el preset " .. tostring(nombre))
	local info = TweenInfo.new(segundos or 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local luz = table.clone(p.luz)
	luz.ClockTime = nil -- girar el reloj de golpe queda raro; se cambia aparte
	TweenService:Create(Lighting, info, luz):Play()
	if p.luz.ClockTime then
		TweenService:Create(Lighting, info, { ClockTime = p.luz.ClockTime }):Play()
	end
	TweenService:Create(efecto("Atmosphere"), info, p.atmosfera):Play()
	TweenService:Create(efecto("ColorCorrectionEffect"), info, p.color):Play()
	TweenService:Create(efecto("BloomEffect"), info, p.bloom):Play()
	TweenService:Create(efecto("SunRaysEffect"), info, p.rayos):Play()
end

-- Ciclo de día y noche (servidor). La noche puede pasar más rápido (multNoche > 1). Devuelve parar()
function Ambiente.cicloDiaNoche(segundosPorDia: number, multNoche: number?): () -> ()
	local vivo = true
	task.spawn(function()
		local horasPorSegundo = 24 / segundosPorDia
		while vivo do
			local dt = task.wait(0.1)
			local h = Lighting.ClockTime
			local noche = h < 6 or h > 19
			Lighting.ClockTime = (h + dt * horasPorSegundo * (if noche then multNoche or 2 else 1)) % 24
		end
	end)
	return function()
		vivo = false
	end
end

-- Profundidad de campo suave (fondo un poco borroso: queda «de juguete»). Solo cliente.
function Ambiente.desenfoqueFondo(intensidad: number?)
	local d = efecto("DepthOfFieldEffect") :: DepthOfFieldEffect
	d.FarIntensity = intensidad or 0.25
	d.FocusDistance = 40
	d.InFocusRadius = 60
	d.NearIntensity = 0
end

--------------------------------------------------------------------------------------------------
-- PARTÍCULAS
--------------------------------------------------------------------------------------------------

--[[ Recetas de ParticleEmitter. Cada una es una tabla de propiedades.
	Se pueden mezclar: Ambiente.particulas(p, "destellos", { color = ..., ritmo = 30 }) ]]
local function nseq(...: number): NumberSequence
	local v = { ... }
	local kp = {}
	for i = 1, #v, 2 do
		table.insert(kp, NumberSequenceKeypoint.new(v[i], v[i + 1]))
	end
	return NumberSequence.new(kp)
end

Ambiente.recetas = {
	destellos = function()
		return { Texture = TEX.destello, Rate = 12, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Size = nseq(0, 0, 0.3, 0.6, 1, 0), LightEmission = 1, Transparency = nseq(0, 0.2, 1, 1), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90) }
	end,
	humo = function()
		return { Texture = TEX.humo, Rate = 6, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(15, 15), Size = nseq(0, 1, 1, 5), Transparency = nseq(0, 0.6, 1, 1), Acceleration = Vector3.new(0, 1, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20), LightEmission = 0 }
	end,
	fuego = function()
		return { Texture = TEX.fuego, Rate = 25, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(10, 10), Size = nseq(0, 2, 1, 0.3), Transparency = nseq(0, 0.2, 1, 1), Acceleration = Vector3.new(0, 4, 0), LightEmission = 1, Rotation = NumberRange.new(0, 360) }
	end,
	magia = function()
		return { Texture = TEX.destello, Rate = 20, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), Size = nseq(0, 0.5, 0.5, 0.8, 1, 0), LightEmission = 1, Transparency = nseq(0, 0, 0.8, 0.3, 1, 1), Acceleration = Vector3.new(0, 2, 0), Drag = 2 }
	end,
	monedas = function()
		return { Texture = TEX.destello, Rate = 0, Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(60, 60), Size = nseq(0, 1, 1, 0.4), LightEmission = 0.6, Acceleration = Vector3.new(0, -30, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200) }
	end,
	confeti = function()
		return { Texture = TEX.destello, Rate = 0, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(14, 24), SpreadAngle = Vector2.new(50, 50), Size = nseq(0, 0.6, 1, 0.5), Acceleration = Vector3.new(0, -18, 0), Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), LightEmission = 0.3 }
	end,
	polvo = function()
		return { Texture = TEX.humo, Rate = 3, Lifetime = NumberRange.new(4, 8), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(180, 180), Size = nseq(0, 0.3, 0.5, 0.5, 1, 0.3), Transparency = nseq(0, 1, 0.5, 0.6, 1, 1), LightEmission = 0.5 }
	end,
}

--[[ Pone un emisor de partículas en una pieza (o Attachment).
	op: color (Color3 o ColorSequence), ritmo (Rate), tamano (multiplica el tamaño), nombre ]]
function Ambiente.particulas(padre: Instance, receta: string, op: { [string]: any }?): ParticleEmitter
	local hacer = Ambiente.recetas[receta]
	assert(hacer, "Ambiente: no existe la receta de partículas " .. tostring(receta))
	local props = hacer()
	local o = op or {}
	local pe = Instance.new("ParticleEmitter")
	pe.Name = o.nombre or ("Particulas_" .. receta)
	poner(pe, props)
	if o.color then
		pe.Color = if typeof(o.color) == "ColorSequence" then o.color else ColorSequence.new(o.color)
	end
	if o.ritmo then
		pe.Rate = o.ritmo
	end
	if o.tamano then
		local kp = {}
		for _, k in pe.Size.Keypoints do
			table.insert(kp, NumberSequenceKeypoint.new(k.Time, k.Value * o.tamano, k.Envelope * o.tamano))
		end
		pe.Size = NumberSequence.new(kp)
	end
	pe.Parent = padre
	return pe
end

-- Colores por rareza (iguales que en UIKit del plugin roblox-ui-componentes)
Ambiente.rarezas = {
	Comun = Color3.fromRGB(170, 175, 185),
	PocoComun = Color3.fromRGB(80, 200, 90),
	Raro = Color3.fromRGB(60, 140, 255),
	Epico = Color3.fromRGB(170, 80, 255),
	Legendario = Color3.fromRGB(255, 170, 30),
	Mitico = Color3.fromRGB(255, 60, 120),
	Secreto = Color3.fromRGB(255, 255, 255),
}

-- Aura alrededor de una mascota/objeto según su rareza (las comunes no llevan, para que luzcan las raras)
function Ambiente.aura(pieza: BasePart, rareza: string): ParticleEmitter?
	local color = Ambiente.rarezas[rareza]
	if not color or rareza == "Comun" or rareza == "PocoComun" then
		return nil
	end
	local intensidad = ({ Raro = 6, Epico = 12, Legendario = 20, Mitico = 30, Secreto = 40 })[rareza] or 10
	local pe = Ambiente.particulas(pieza, "magia", { color = color, ritmo = intensidad, nombre = "Aura" })
	if rareza == "Legendario" or rareza == "Mitico" or rareza == "Secreto" then
		local luz = Instance.new("PointLight")
		luz.Name = "LuzAura"
		luz.Color = color
		luz.Range = 10
		luz.Brightness = 1.2
		luz.Shadows = false
		luz.Parent = pieza
	end
	if rareza == "Secreto" then
		pe.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
		})
	end
	return pe
end

-- Explosión puntual de partículas en una posición del mundo (abrir huevo, recoger moneda). Se borra sola.
function Ambiente.estallido(posicion: Vector3, receta: string?, cantidad: number?, color: Color3?)
	local ancla = Instance.new("Part")
	ancla.Name = "Estallido"
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.CanTouch = false
	ancla.Transparency = 1
	ancla.Size = Vector3.new(0.2, 0.2, 0.2)
	ancla.CFrame = CFrame.new(posicion)
	ancla.Parent = Workspace
	local pe = Ambiente.particulas(ancla, receta or "confeti", { color = color })
	pe.Rate = 0
	pe:Emit(cantidad or 40)
	task.delay(3, function()
		ancla:Destroy()
	end)
end

-- Estela detrás de algo que se mueve (mascotas veloces, espadas, vehículos)
function Ambiente.estela(pieza: BasePart, color: Color3?, ancho: number?): Trail
	local a0 = Instance.new("Attachment")
	a0.Name = "EstelaA"
	a0.Position = Vector3.new(0, (ancho or 1) / 2, 0)
	a0.Parent = pieza
	local a1 = Instance.new("Attachment")
	a1.Name = "EstelaB"
	a1.Position = Vector3.new(0, -(ancho or 1) / 2, 0)
	a1.Parent = pieza
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.35
	t.LightEmission = 0.6
	t.Color = ColorSequence.new(color or Color3.fromRGB(120, 200, 255))
	t.Transparency = nseq(0, 0.2, 1, 1)
	t.WidthScale = nseq(0, 1, 1, 0)
	t.FaceCamera = true
	t.Parent = pieza
	return t
end

-- Rayo/haz entre dos piezas (portales, conexiones, «tractor» que recoge monedas)
function Ambiente.haz(desde: BasePart, hasta: BasePart, color: Color3?, ancho: number?): Beam
	local a0 = Instance.new("Attachment")
	a0.Parent = desde
	local a1 = Instance.new("Attachment")
	a1.Parent = hasta
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color or Color3.fromRGB(150, 220, 255))
	b.Width0 = ancho or 1
	b.Width1 = ancho or 1
	b.LightEmission = 1
	b.FaceCamera = true
	b.Transparency = nseq(0, 0.2, 1, 0.2)
	b.Texture = TEX.luz
	b.TextureSpeed = 1.5
	b.Parent = desde
	return b
end

-- Contorno brillante (objeto seleccionado, cosa que se puede recoger). Devuelve el Highlight
function Ambiente.resaltar(objeto: Instance, color: Color3?, relleno: number?): Highlight
	local h = objeto:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
	h.OutlineColor = color or Color3.fromRGB(255, 240, 120)
	h.FillColor = color or Color3.fromRGB(255, 240, 120)
	h.FillTransparency = relleno or 0.8
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = objeto
	return h
end

-- Hace que una pieza brille (Neon + luz). Úsalo con moderación: mucho neón cansa la vista.
function Ambiente.neon(pieza: BasePart, color: Color3?, alcance: number?)
	pieza.Material = Enum.Material.Neon
	if color then
		pieza.Color = color
	end
	local luz = pieza:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
	luz.Color = pieza.Color
	luz.Range = alcance or 12
	luz.Brightness = 1
	luz.Shadows = false
	luz.Parent = pieza
end

return Ambiente
