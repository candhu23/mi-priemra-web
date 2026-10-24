--[[
	Ritmo de la economía: un jugador «bueno» toca 4 veces por segundo y compra siempre lo más
	rentable que pueda pagar. Imprime cuándo llega a cada hito. Compáralo con DISENO.md §5.
	Un jugador real va ~2-3 veces más lento. Uso: lune run ritmo.luau <src> [minutos]
]]
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local SRC = process.args[1]
local MINUTOS = tonumber(process.args[2]) or 120
local Config = luau.load(fs.readFile(SRC .. "/ReplicatedStorage/Config.luau"), {
	debugName = "Config",
	environment = setmetatable({ Color3 = roblox.Color3 }, { __index = _G }),
})()

local data = { money = 0, generators = {}, clickLevel = 0 }
for _, g in Config.Generators do
	data.generators[g.id] = 0
end
local bonuses = { x2 = false, auto = false, boost = false, friends = 0, premium = false }
local hitos = {}
local function hito(nombre: string, t: number)
	if not hitos[nombre] then
		hitos[nombre] = true
		print(string.format("  %6s  %s", string.format("%d:%02d", t // 60, t % 60), nombre))
	end
end

local TOQUES = 4
for t = 1, MINUTOS * 60 do
	data.money += Config.incomePerSec(data, bonuses) + TOQUES * Config.clickValue(data, bonuses)
	-- Comprar lo que más ingreso da por cada dólar (o la mejora de clic si sale mejor)
	local comprado = true
	while comprado do
		comprado = false
		local mejor, ratio = nil, 0
		for _, g in Config.Generators do
			local coste = Config.genCost(g.id, data.generators[g.id])
			local r = g.income / coste
			if coste <= data.money and r > ratio then
				mejor, ratio = g, r
			end
		end
		local costeClic = Config.clickUpgradeCost(data.clickLevel)
		if data.clickLevel < Config.ClickUpgrade.max and costeClic <= data.money then
			local ganancia = TOQUES * (Config.clickValue({ clickLevel = data.clickLevel + 1 }, bonuses) - Config.clickValue(data, bonuses))
			if ganancia / costeClic > ratio then
				data.money -= costeClic
				data.clickLevel += 1
				comprado = true
				continue
			end
		end
		if mejor then
			data.money -= Config.genCost(mejor.id, data.generators[mejor.id])
			if data.generators[mejor.id] == 0 then
				hito("primer " .. mejor.id, t)
			end
			data.generators[mejor.id] += 1
			comprado = true
		end
	end
	local ingreso = Config.incomePerSec(data, bonuses)
	for _, meta in { 10, 100, 1_000, 10_000, 100_000 } do
		if ingreso >= meta then
			hito(string.format("ingresos %s/s", if meta >= 1000 then (meta // 1000) .. "K" else tostring(meta)), t)
		end
	end
end
print(string.format("  Tras %d min: %.0f/s de ingresos, clic nivel %d", MINUTOS, Config.incomePerSec(data, bonuses), data.clickLevel))
