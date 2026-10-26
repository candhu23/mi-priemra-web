-- Construye el mundo con el servidor real (en el mock) y lo guarda como .rbxlx para verlo con roblox-3d-vista.
-- Uso: lune run vista_mundo.luau <test.rbxl> <salida.rbxlx>
local M = require("./mock")
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local W = M.new(process.args[1], {})
W.runScript(W.game:GetService("ServerScriptService"):FindFirstChild("Main"))
local place = roblox.Instance.new("DataModel")
W.game:GetService("Workspace"):FindFirstChild("Mundo").Parent = place:GetService("Workspace")
fs.writeFile(process.args[2], roblox.serializePlace(place, true))
print("ok")
