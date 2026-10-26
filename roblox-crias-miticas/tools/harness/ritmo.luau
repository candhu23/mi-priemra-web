--[[
	Ritmo de la economía: un bot «bueno» pica cristales en su isla más alta, abre el huevo de esa isla en cuanto
	puede pagarlo (respetando el tiempo entre aperturas), «Fusionar todo» tras cada huevo, equipa lo mejor, abre
	la puerta en cuanto cumple el Índice (o la puntuación Brillante en la 9) y compra mejoras en cuanto puede.
	Juega N partidas con semillas distintas e imprime la mediana (mín–máx) de cada hito: compáralo con DISENO.md §5
	y la ficha propuestas/2026-10-26-rarezas-arbol.md §10. Un jugador real va ~2 veces más lento (anda, mira menús…).
	Sin Montón Dorado ni pases (como la ficha). Con «oro» como 4.º argumento suma el Montón Dorado.
	Uso: lune run ritmo.luau <src> [minutos=300] [partidas=10] [oro]
]]
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local SRC = process.args[1]
local MINUTOS = tonumber(process.args[2]) or 300
local PARTIDAS = tonumber(process.args[3]) or 10
local ORO = process.args[4] == "oro"
local Config = luau.load(fs.readFile(SRC .. "/ReplicatedStorage/Config.luau"), {
	debugName = "Config",
	environment = setmetatable({ Color3 = roblox.Color3, Vector2 = roblox.Vector2 }, { __index = _G }),
})()

local EFICIENCIA = 0.75 -- parte del tiempo que las crías están picando

-- Generador propio (misma secuencia en cada máquina para una semilla)
local function newRng(seed: number)
	local x = seed * 7919 + 13
	return function(): number
		x = (x * 1103515245 + 12345) % 2147483648
		return x / 2147483648
	end
end

-- Orden de los hitos en la tabla
local ORDEN = { "1.er huevo", "1.ª fusión", "1.ª Brillante" }
for z = 2, #Config.Zones - 1 do
	table.insert(ORDEN, "zona " .. z)
end
for _, h in { "1.ª Mítica = 1.ª piedra", "5 Míticas", "20 Míticas", "50 Míticas" } do
	table.insert(ORDEN, h)
end
for _, u in Config.Upgrades do
	table.insert(ORDEN, "árbol: " .. u.id)
end
table.insert(ORDEN, "✨ 200 Brillante")
table.insert(ORDEN, "zona " .. #Config.Zones)
table.insert(ORDEN, "árbol completo")

local function partida(seed: number): ({ [string]: number }, any)
	local rnd = newRng(seed)
	local data = { coins = 0, zones = 1, pets = {}, equipped = {}, album = {}, albumClaimed = {}, shinyIndex = {}, upgrades = {}, stones = 0 }
	local bonuses = {}
	local nextUid = 1
	local t = 0
	local hitos: { [string]: number } = {}
	local stats = { fused = 0, hatched = 0, mythics = 0, shinies = 0 }
	local function hito(nombre: string)
		if not hitos[nombre] then
			hitos[nombre] = t
		end
	end
	local function addPet(kind: string, shiny: boolean)
		table.insert(data.pets, { uid = nextUid, kind = kind, shiny = shiny })
		data.album[kind] = true
		if shiny then
			data.shinyIndex[kind] = true
		end
		nextUid += 1
	end
	local power = 0
	local function equipBest()
		table.sort(data.pets, function(a, b)
			return Config.petPower(a.kind, a.shiny) > Config.petPower(b.kind, b.shiny)
		end)
		data.equipped = {}
		for i = 1, math.min(Config.slots(data, bonuses), #data.pets) do
			table.insert(data.equipped, data.pets[i].uid)
		end
		power = Config.teamPower(data)
	end
	-- Igual que el servidor: cada vez el grupo de rareza más baja que llega a fuseNeed (lo nuevo se vuelve a fusionar)
	local function fuseAll()
		while true do
			local groups = {}
			local best, bestKey = nil, ""
			for i, p in data.pets do
				local def = Config.PetById[p.kind]
				local key = def.zone .. ":" .. def.rarity .. ":" .. tostring(p.shiny)
				local g = groups[key]
				if not g then
					g = { zone = def.zone, rarity = def.rarity, shiny = p.shiny, idx = {} }
					groups[key] = g
				end
				table.insert(g.idx, i)
				local need = Config.Rarities[def.rarity].fuseNeed
				if need > 0 and #g.idx == need and (best == nil or def.rarity < best.rarity) then
					best, bestKey = g, key
				end
			end
			if not best then
				return
			end
			local _ = bestKey
			local need = Config.Rarities[best.rarity].fuseNeed
			for i = need, 1, -1 do
				table.remove(data.pets, best.idx[i])
			end
			local made = Config.fuseResult(best.zone, best.rarity) :: string
			addPet(made, best.shiny)
			stats.fused += 1
			hito("1.ª fusión")
			if best.rarity + 1 == Config.MYTHIC then
				data.stones += 1
				stats.mythics += 1
				hito("1.ª Mítica = 1.ª piedra")
				for _, n in { 5, 20, 50 } do
					if stats.mythics >= n then
						hito(n .. " Míticas")
					end
				end
			end
		end
	end

	addPet(Config.STARTER_PET, false)
	equipBest()
	local hatchBudget = 0
	while t < MINUTOS * 60 do
		t += 1
		data.coins += power * Config.coinsPerHp(data.zones) * Config.coinMult(data, bonuses) * EFICIENCIA
		if ORO and t % Config.GOLD_INTERVAL == 0 then
			local z = Config.Zones[data.zones]
			data.coins += (Config.GOLD_COINS * z.pileCoins - Config.GOLD_HP * z.pileHp * Config.coinsPerHp(data.zones)) * Config.coinMult(data, bonuses)
		end
		-- Puerta en cuanto cumple (no cuesta monedas)
		if data.zones < #Config.Zones and Config.zoneNeed(data, data.zones + 1) then
			data.zones += 1
			hito("zona " .. data.zones)
		end
		-- Mejoras en cuanto puede (en el orden de la lista)
		local bought = false
		for _, u in Config.Upgrades do
			if Config.canBuyUpgrade(data, u.id) then
				data.stones -= u.cost
				data.upgrades[u.id] = true
				hito("árbol: " .. u.id)
				bought = true
			end
		end
		if bought then
			equipBest()
			local all = true
			for _, u in Config.Upgrades do
				all = all and data.upgrades[u.id] == true
			end
			if all then
				hito("árbol completo")
			end
		end
		-- Huevos: el de la isla más alta, con el tiempo entre aperturas
		hatchBudget = math.min(hatchBudget + 1 / Config.hatchCooldown(data), 2)
		local cost = Config.eggCost(data.zones, data)
		local changed = false
		while hatchBudget >= 1 and data.coins >= cost do
			hatchBudget -= 1
			data.coins -= cost
			stats.hatched += 1
			hito("1.er huevo")
			local shiny = Config.rollShiny(data.zones, data, bonuses, rnd())
			if shiny then
				stats.shinies += 1
				hito("1.ª Brillante")
			end
			addPet(Config.rollPet(data.zones, rnd()), shiny)
			fuseAll()
			-- Mochila llena: suelta primero las Míticas sin equipar más flojas (ya no se fusionan; si no, la mochila se
			-- llena de Míticas en la zona 9 y cada cría nueva se soltaría al momento), luego las más flojas
			if #data.pets > Config.backpack(data, bonuses) then
				equipBest()
				local eq = {}
				for _, uid in data.equipped do
					eq[uid] = true
				end
				for i = #data.pets, 1, -1 do
					local p = data.pets[i]
					if #data.pets > Config.backpack(data, bonuses) and not eq[p.uid] and Config.PetById[p.kind].rarity == Config.MYTHIC then
						table.remove(data.pets, i)
					end
				end
				while #data.pets > Config.backpack(data, bonuses) do
					table.remove(data.pets)
				end
			end
			changed = true
		end
		if changed then
			equipBest()
		end
		if Config.shinyScore(data) >= 200 then
			hito("✨ 200 Brillante")
		end
		-- Álbum
		local pct = Config.albumCount(data) / Config.albumTotal() * 100
		for i, m in Config.AlbumMilestones do
			if pct >= m.pct and not data.albumClaimed[tostring(i)] then
				data.albumClaimed[tostring(i)] = true
			end
		end
	end
	return hitos, { zones = data.zones, album = Config.albumCount(data), stones = data.stones, mythics = stats.mythics, shinies = stats.shinies, score = Config.shinyScore(data) }
end

local function hms(s: number): string
	if s >= 3600 then
		return string.format("%d h %02d", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

local todos = {}
local finales = {}
for i = 1, PARTIDAS do
	local h, fin = partida(i)
	table.insert(todos, h)
	table.insert(finales, fin)
end
print(string.format("  Bot: %d partidas de %d min (eficiencia %.2f%s). Mediana (mín–máx):", PARTIDAS, MINUTOS, EFICIENCIA, if ORO then ", con Montón Dorado" else ""))
for _, nombre in ORDEN do
	local ts = {}
	for _, h in todos do
		if h[nombre] then
			table.insert(ts, h[nombre])
		end
	end
	if #ts > 0 then
		table.sort(ts)
		local med = if #ts % 2 == 1 then ts[(#ts + 1) // 2] else (ts[#ts // 2] + ts[#ts // 2 + 1]) // 2
		local faltan = if #ts < PARTIDAS then string.format("  (solo %d/%d)", #ts, PARTIDAS) else ""
		print(string.format("  %-26s %9s  (%s – %s)%s", nombre, hms(med), hms(ts[1]), hms(ts[#ts]), faltan))
	else
		print(string.format("  %-26s %9s", nombre, "—"))
	end
end
local f = finales[1]
print(string.format("  Partida 1 al acabar: zona %d, Índice %d/%d, ✨ %d, %d Míticas, %d 🪨 sin gastar, %d Brillantes",
	f.zones, f.album, Config.albumTotal(), f.score, f.mythics, f.stones, f.shinies))
