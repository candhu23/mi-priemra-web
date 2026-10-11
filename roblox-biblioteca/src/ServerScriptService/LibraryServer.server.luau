--!strict
-- Servidor de Estanterías Hechizadas.
-- Fase 2: construye la biblioteca y el Archivo. (Las acciones y el guardado llegan en las fases 3–5.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Building = require(script.Parent:WaitForChild("Lib"):WaitForChild("Building"))

Building.build(Layout.get("main"), Workspace)
Building.build(Layout.get("special"), Workspace)
