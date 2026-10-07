--[[
	Ambience (ModuleScript en ReplicatedStorage)

	Ambientes de luz de cada lugar: hora del día, luz ambiente, niebla
	(Atmosphere), color de imagen, resplandor (Bloom), rayos de sol, nubes y
	agua. El servidor pone el del lobby al arrancar; el CLIENTE cambia al del
	mapa al entrar en una partida (los cambios del cliente en Lighting solo
	los ve ese jugador) y vuelve al del lobby al salir.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Ambience = {}

type Preset = {
	clock: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	exposure: number,
	shadowSoftness: number,
	atmosphere: { density: number, offset: number, color: Color3, decay: Color3, glare: number, haze: number },
	grade: { saturation: number, contrast: number, brightness: number, tint: Color3 },
	bloom: { intensity: number, size: number, threshold: number },
	sunRays: { intensity: number, spread: number },
	clouds: { cover: number, density: number, color: Color3 }?,
	stars: number,
}

Ambience.Presets = {
	-- Tarde dorada sobre la isla
	lobby = {
		clock = 16.2,
		brightness = 2.6,
		ambient = Color3.fromRGB(95, 88, 105),
		outdoor = Color3.fromRGB(150, 138, 140),
		exposure = 0.15,
		shadowSoftness = 0.25,
		atmosphere = { density = 0.3, offset = 0.2, color = Color3.fromRGB(255, 220, 182), decay = Color3.fromRGB(128, 112, 140), glare = 0.6, haze = 1.6 },
		grade = { saturation = 0.18, contrast = 0.08, brightness = 0.02, tint = Color3.fromRGB(255, 246, 236) },
		bloom = { intensity = 0.55, size = 30, threshold = 1.7 },
		sunRays = { intensity = 0.09, spread = 0.65 },
		clouds = { cover = 0.55, density = 0.55, color = Color3.fromRGB(255, 236, 222) },
		stars = 0,
	},
	-- Mediodía luminoso y verde
	bosque = {
		clock = 13.2,
		brightness = 3,
		ambient = Color3.fromRGB(88, 100, 86),
		outdoor = Color3.fromRGB(140, 150, 128),
		exposure = 0.05,
		shadowSoftness = 0.2,
		atmosphere = { density = 0.32, offset = 0.1, color = Color3.fromRGB(205, 232, 196), decay = Color3.fromRGB(96, 130, 100), glare = 0.3, haze = 1.4 },
		grade = { saturation = 0.24, contrast = 0.1, brightness = 0.01, tint = Color3.fromRGB(246, 255, 240) },
		bloom = { intensity = 0.45, size = 28, threshold = 1.8 },
		sunRays = { intensity = 0.12, spread = 0.7 },
		clouds = { cover = 0.45, density = 0.5, color = Color3.fromRGB(255, 255, 255) },
		stars = 0,
	},
	-- Noche azul: solo brillan los cristales
	cueva = {
		clock = 0.5,
		brightness = 1.2,
		ambient = Color3.fromRGB(58, 70, 118),
		outdoor = Color3.fromRGB(70, 86, 150),
		exposure = 0.45,
		shadowSoftness = 0.4,
		atmosphere = { density = 0.45, offset = 0, color = Color3.fromRGB(90, 120, 200), decay = Color3.fromRGB(40, 30, 90), glare = 0, haze = 2.2 },
		grade = { saturation = 0.3, contrast = 0.14, brightness = 0.02, tint = Color3.fromRGB(220, 232, 255) },
		bloom = { intensity = 1, size = 34, threshold = 1.1 },
		sunRays = { intensity = 0, spread = 0.5 },
		clouds = nil,
		stars = 4000,
	},
	-- Atardecer morado y brumoso
	castillo = {
		clock = 18.4,
		brightness = 1.8,
		ambient = Color3.fromRGB(96, 70, 112),
		outdoor = Color3.fromRGB(128, 92, 140),
		exposure = 0.25,
		shadowSoftness = 0.3,
		atmosphere = { density = 0.42, offset = 0.05, color = Color3.fromRGB(170, 110, 196), decay = Color3.fromRGB(70, 40, 96), glare = 0.4, haze = 2.6 },
		grade = { saturation = 0.2, contrast = 0.15, brightness = 0, tint = Color3.fromRGB(238, 222, 255) },
		bloom = { intensity = 0.8, size = 32, threshold = 1.3 },
		sunRays = { intensity = 0.06, spread = 0.6 },
		clouds = { cover = 0.7, density = 0.7, color = Color3.fromRGB(150, 110, 170) },
		stars = 1500,
	},
} :: { [string]: Preset }

local function ensure(className: string, parent: Instance, name: string?): any
	local existing = if name then parent:FindFirstChild(name) else parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	if name then
		instance.Name = name
	end
	instance.Parent = parent
	return instance
end

function Ambience.apply(name: string)
	local preset = Ambience.Presets[name] or Ambience.Presets.lobby
	Lighting.ClockTime = preset.clock
	Lighting.Brightness = preset.brightness
	Lighting.Ambient = preset.ambient
	Lighting.OutdoorAmbient = preset.outdoor
	Lighting.ExposureCompensation = preset.exposure
	Lighting.ShadowSoftness = preset.shadowSoftness
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local atmosphere = ensure("Atmosphere", Lighting)
	atmosphere.Density = preset.atmosphere.density
	atmosphere.Offset = preset.atmosphere.offset
	atmosphere.Color = preset.atmosphere.color
	atmosphere.Decay = preset.atmosphere.decay
	atmosphere.Glare = preset.atmosphere.glare
	atmosphere.Haze = preset.atmosphere.haze

	local grade = ensure("ColorCorrectionEffect", Lighting)
	grade.Saturation = preset.grade.saturation
	grade.Contrast = preset.grade.contrast
	grade.Brightness = preset.grade.brightness
	grade.TintColor = preset.grade.tint

	local bloom = ensure("BloomEffect", Lighting)
	bloom.Intensity = preset.bloom.intensity
	bloom.Size = preset.bloom.size
	bloom.Threshold = preset.bloom.threshold

	local rays = ensure("SunRaysEffect", Lighting)
	rays.Intensity = preset.sunRays.intensity
	rays.Spread = preset.sunRays.spread

	local sky = ensure("Sky", Lighting)
	sky.StarCount = preset.stars
	sky.CelestialBodiesShown = true

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds")
		if not clouds and preset.clouds then
			clouds = Instance.new("Clouds")
			clouds.Parent = terrain
		end
		if clouds then
			clouds.Enabled = preset.clouds ~= nil
			if preset.clouds then
				clouds.Cover = preset.clouds.cover
				clouds.Density = preset.clouds.density
				clouds.Color = preset.clouds.color
			end
		end
	end
end

return Ambience
