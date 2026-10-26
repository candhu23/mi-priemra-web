--[[
	Ritmo de la economía: un bot «bueno» rompe montones en la mejor isla abierta, abre huevos,
	fusiona, equipa lo mejor, abre islas y renace. Imprime cuándo llega a cada hito (compáralo con
	DISENO.md §5). Un jugador real va ~2 veces más lento (anda, mira menús…).
	Uso: lune run ritmo.luau <src> [minutos]
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

local EFICIENCIA = 0.75 -- parte del tiempo que las crías están picando
local HUEVOS_POR_ISLA = 20 -- el bot abre estos huevos en cada isla y luego ahorra para la puerta

local data = { coins = 0, zones = 1, rebirths = 0, pets = {}, equipped = {}, album = {}, albumClaimed = {} }
local bonuses = {}
local nextUid = 1
local hatchedHere = 0
local function addPet(kind, tier)
	table.insert(data.pets, { uid = nextUid, kind = kind, tier = tier })
	data.album[Config.albumKey(kind, tier)] = true
	nextUid += 1
end

local function equipBest()
	table.sort(data.pets, function(a, b)
		return Config.petPower(a.kind, a.tier) > Config.petPower(b.kind, b.tier)
	end)
	data.equipped = {}
	for i = 1, math.min(Config.slots(data, bonuses), #data.pets) do
		table.insert(data.equipped, data.pets[i].uid)
	end
end
local function fuseAll(stats)
	local changed = true
	while changed do
		changed = false
		local groups = {}
		for _, p in data.pets do
			if p.tier < Config.MAX_TIER then
				local k = p.kind .. ":" .. p.tier
				groups[k] = groups[k] or {}
				table.insert(groups[k], p)
			end
		end
		for _, g in groups do
			if #g >= Config.FUSE_COUNT then
				local kind, tier = g[1].kind, g[1].tier
				local quitar = {}
				for i = 1, Config.FUSE_COUNT do
					quitar[g[i].uid] = true
				end
				for i = #data.pets, 1, -1 do
					if quitar[data.pets[i].uid] then
						table.remove(data.pets, i)
					end
				end
				addPet(kind, tier + 1)
				stats.fused += 1
				changed = true
				break
			end
		end
	end
end

addPet(Config.STARTER_PET, 0)
equipBest()

local hitos = {}
local function hito(nombre: string, t: number)
	if not hitos[nombre] then
		hitos[nombre] = true
		print(string.format("  %6s  %-28s poder %s  monedas/s %s", string.format("%d:%02d", t // 60, t % 60), nombre,
			string.format("%.3g", Config.teamPower(data)), string.format("%.3g", Config.coinRate(data, bonuses) / Config.EFFICIENCY * EFICIENCIA)))
	end
end

local stats = { fused = 0, hatched = 0 }
for t = 1, MINUTOS * 60 do
	data.coins += Config.teamPower(data) * Config.coinsPerHp(data.zones) * Config.coinMult(data, bonuses) * EFICIENCIA
	-- Renacer
	if data.zones >= Config.rebirthZone(data.rebirths) and data.coins >= Config.rebirthCost(data.rebirths) then
		data.rebirths += 1
		data.coins = 0
		data.zones = 1
		hatchedHere = HUEVOS_POR_ISLA -- tras renacer va directo a por las puertas
		equipBest()
		hito("renacer " .. data.rebirths, t)
	end
	local nextZone = Config.Zones[data.zones + 1]
	local ahorrando = data.zones >= Config.rebirthZone(data.rebirths)
	if nextZone and data.coins >= nextZone.doorCost and not (ahorrando and data.zones + 1 > Config.rebirthZone(data.rebirths)) then
		data.coins -= nextZone.doorCost
		data.zones += 1
		hatchedHere = 0
		hito("isla " .. data.zones .. " (R" .. data.rebirths .. ")", t)
	end
	local zone = Config.Zones[data.zones]
	while data.coins >= zone.eggCost and hatchedHere < HUEVOS_POR_ISLA do
		data.coins -= zone.eggCost
		hatchedHere += 1
		stats.hatched += 1
		addPet(Config.rollPet(data.zones, false, math.random()), 0)
		if stats.hatched == 1 then
			hito("1.er huevo", t)
		end
		fuseAll(stats)
		if stats.fused == 1 then
			hito("1.ª fusión (Dorada)", t)
		end
		-- mochila: suelta las más flojas
		while #data.pets > Config.backpack(data, bonuses) do
			equipBest()
			table.remove(data.pets)
		end
		equipBest()
	end
	-- Álbum
	local pct = Config.albumCount(data) / Config.albumTotal() * 100
	for i, m in Config.AlbumMilestones do
		if pct >= m.pct and not data.albumClaimed[tostring(i)] then
			data.albumClaimed[tostring(i)] = true
			hito("álbum " .. m.pct .. " %", t)
		end
	end
end
print(string.format("  Tras %d min: isla %d, renacer %d, álbum %d/%d, %d huevos, %d fusiones", MINUTOS, data.zones, data.rebirths,
	Config.albumCount(data), Config.albumTotal(), stats.hatched, stats.fused))
