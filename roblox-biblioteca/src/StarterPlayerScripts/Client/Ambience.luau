--!strict
-- Ambiente: luz que cae con el tiempo de juego (media tarde → noche cerrada a las ~3 h; se congela en modo
-- acogedor), música por tramos según el % de filas correctas, opciones (campo de visión, sensibilidad,
-- volumen, balanceo de cabeza) y la cámara del menú de título.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local Ambience = {}

Ambience.COZY_CLOCK = 16.5 -- (supuesto) hora fija del modo acogedor
Ambience.MENU_CLOCK = 17.2

-- Hora del día según el tiempo de juego
function Ambience.clockFor(seconds: number): number
	local k = math.clamp(seconds / (Config.LIGHT_HOURS * 3600), 0, 1)
	return Config.LIGHT_START + (Config.LIGHT_END - Config.LIGHT_START) * k
end

local music: Sound? = nil
local musicTier = 0

local function setMusic(tier: number, volume: number)
	if not music then
		local m = Instance.new("Sound")
		m.Name = "Music"
		m.Looped = true
		m.Parent = SoundService
		music = m
	end
	local m = music :: Sound
	m.Volume = volume * 0.5
	if tier ~= musicTier then
		musicTier = tier
		local id = if Config.Music[tier] then Config.Music[tier].id else ""
		m:Stop()
		if id ~= "" then
			m.SoundId = id
			m:Play()
		end
	end
end

function Ambience.build(ctx: Kit.Ctx)
	local camera = Workspace.CurrentCamera
	local wasMenu = false
	local menuT = 0
	local lightT = 0

	table.insert(ctx.tickers, function(dt: number)
		local st = ctx.state
		local set = st.settings or {}
		local cam = Workspace.CurrentCamera or camera
		-- Opciones
		Kit.sfxVolume = set.sfx or 0.6
		pcall(function()
			UserInputService.MouseDeltaSensitivity = set.sens or 1
		end)
		-- Cámara del menú: vista lenta sobre la biblioteca
		local inMenu = st.mode == "menu"
		if cam then
			if inMenu then
				menuT += dt or 0
				cam.CameraType = Enum.CameraType.Scriptable
				local x = math.sin(menuT * 0.05) * 6
				cam.CFrame = CFrame.new(Vector3.new(x, 25, -6)) * CFrame.Angles(0, math.sin(menuT * 0.03) * 0.15, 0) * CFrame.Angles(math.rad(-22), 0, 0)
				cam.FieldOfView = 70
			elseif wasMenu then
				cam.CameraType = Enum.CameraType.Custom
			end
			if not inMenu then
				cam.FieldOfView = set.fov or 70
			end
		end
		wasMenu = inMenu
		-- Luz (cada medio segundo basta)
		lightT += dt or 0
		if lightT >= 0.5 then
			lightT = 0
			local clock
			if inMenu then
				clock = Ambience.MENU_CLOCK
			elseif st.mode == "special" or set.cozy then
				clock = Ambience.COZY_CLOCK
			else
				clock = Ambience.clockFor((st.time or 0) + (os.clock() - Hud.stateAt))
			end
			Lighting.ClockTime = clock
			-- De noche, el interior se apoya en sus lámparas
			Lighting.Brightness = if clock > 19 then 1 else 2
			-- Música por tramos de % de filas correctas
			local p = if (st.rowsTotal or 0) > 0 then (st.rows or 0) / st.rowsTotal else 0
			local tier = 1
			for i, m in Config.Music do
				if p >= m.from then
					tier = i
				end
			end
			setMusic(tier, set.music or 0.5)
		end
	end)

	-- Balanceo de cabeza al andar (después de la cámara de Roblox; no se acumula)
	local bobT = 0
	pcall(function()
		RunService:BindToRenderStep("HeadBob", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
			local st = ctx.state
			local set = st.settings or {}
			local cam = Workspace.CurrentCamera
			if not cam or not set.bob or st.mode == "menu" or ctx.panel then
				return
			end
			local char = Players.LocalPlayer and Players.LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.MoveDirection.Magnitude < 0.1 then
				return
			end
			bobT += dt * hum.WalkSpeed / 12
			cam.CFrame = cam.CFrame * CFrame.new(0, math.sin(bobT * 9) * 0.07, 0) * CFrame.Angles(0, 0, math.sin(bobT * 4.5) * 0.004)
		end)
	end)
end

return Ambience
