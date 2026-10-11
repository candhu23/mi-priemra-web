--!strict
-- Cliente de Estanterías Hechizadas.
-- Fase 2: dibuja los 3.072 libros en sus montones iniciales para poder recorrer la biblioteca.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Codec = require(ReplicatedStorage:WaitForChild("Codec"))
local Books = require(script.Parent:WaitForChild("Client"):WaitForChild("Books"))

Workspace:WaitForChild("Library")
local def = Layout.get("main")
local locs: { Codec.Loc } = table.create(#def.books)
for id = 1, #def.books do
	locs[id] = { k = 0 }
end
local lang = string.sub(string.lower(Players.LocalPlayer and Players.LocalPlayer.LocaleId or "es"), 1, 2)
Books.lang = if lang == "es" then "es" else "en"
Books.init()
Books.load(def, locs)

while true do
	task.wait(0.25)
	local cam = Workspace.CurrentCamera
	if cam then
		Books.updateLabels(cam.CFrame)
	end
end
