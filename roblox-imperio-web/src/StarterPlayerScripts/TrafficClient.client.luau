--[[
	TrafficClient (LocalScript en StarterPlayerScripts)

	Pone en marcha los coches de Ciudad Web en la pantalla de este jugador
	(ver ReplicatedStorage.Traffic). Solo es decoración: no chocan.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Traffic = require(ReplicatedStorage:WaitForChild("Traffic"))

Traffic.start(Workspace)
RunService.Heartbeat:Connect(function(dt)
	Traffic.step(dt)
end)
