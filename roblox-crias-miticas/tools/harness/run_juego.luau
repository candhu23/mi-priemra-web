--[[
	Prueba de JUEGO COMPLETO con Lune: servidor real + interfaz real en el mismo proceso.
	Un bot juega a Crías Míticas: sus crías rompen montones (modo Auto y tocando un montón), abre un
	huevo junto al pedestal (especies y Brillante con sus probabilidades), fusiona en el altar (5→1, 3→1,
	«Fusionar todo», Mítica → Piedra), equipa las mejores, suelta una cría, abre islas por el Índice (y la 9
	por puntuación Brillante), viaja, compra mejoras del Jardín, reclama álbum, misiones y diario, cambia
	idioma y sonido, salta el tutorial, pulsa TODOS los botones, sale (se guarda) y vuelve (se carga).
	Luego, «Studio sin publicar» (sin DataStore). Ya no existe «rebirth».
	Uso: lune run run_juego.luau <test.rbxl> [carpeta-volcado] [ancho] [alto]
	Con carpeta, vuelca la interfaz en JSON para verla con la skill disenar-interfaz.
	Si añades una acción al servidor, añade aquí cómo probarla.
]]

local M = require("./mock")
local process = require("@lune/process")
local volcar = require("./volcado")

local PLACE = process.args[1]
local DUMP = process.args[2]
local WIDTH = tonumber(process.args[3]) or 1280
local HEIGHT = tonumber(process.args[4]) or 720
local KEY = "MythicHatchlings_v2/player_42"

local function boot(opts: { [string]: any }?)
	local o = opts or {}
	o.width, o.height = WIDTH, HEIGHT
	local W = M.new(PLACE, o)
	local SSS = W.game:GetService("ServerScriptService")
	local SPS = W.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	W.runScript(SSS:FindFirstChild("Main"))
	return W, SPS
end

-- Personaje falso: un Model con HumanoidRootPart en el Workspace
local function makeCharacter(W: any, player: any, pos: any)
	local R = W.roblox
	local model = R.Instance.new("Model")
	model.Name = "Personaje"
	local hrp = R.Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Anchored = true
	hrp.CFrame = R.CFrame.new(pos)
	hrp.Parent = model
	local hum = R.Instance.new("Humanoid")
	hum.Parent = model
	model.Parent = W.game:GetService("Workspace")
	W.overrides[player].Character = W.wrap(model)
	return hrp
end

local function join(W: any, SPS: any, userId: number)
	local player, real = W.addPlayer(userId, "Bot" .. userId)
	W.player = player
	W.Players.LocalPlayer = player
	local spawn = W.game:GetService("Workspace"):FindFirstChild("Mundo"):FindFirstChild("Aparicion")
	local hrp = makeCharacter(W, player, spawn.CFrame.Position + W.roblox.Vector3.new(0, 3, 0))
	W.Players.PlayerAdded:Fire(player)
	local ps = real:FindFirstChild("PlayerScripts")
	for _, child in SPS:GetChildren() do
		child:Clone().Parent = ps
	end
	W.runScript(ps:FindFirstChild("Client"))
	return player, real, hrp
end

local function frame(W: any)
	W.renderStepped:Fire(0.25)
	W.tick(1)
	W.renderStepped:Fire(0.25)
end

local function lastState(W: any): any
	for i = #W.fired, 1, -1 do
		local f = W.fired[i]
		if f[1] == "State" then
			return f[3]
		end
	end
	return nil
end

-- Último estado que recibió un jugador concreto (con 2 jugadores en el servidor)
local function lastStateOf(W: any, plr: any): any
	for i = #W.fired, 1, -1 do
		local f = W.fired[i]
		if f[1] == "State" and f[2] == plr then
			return f[3]
		end
	end
	return nil
end

-- Montones Dorados que hay ahora en el mundo
local function golds(W: any): { any }
	local list = {}
	for _, p in W.game:GetService("Workspace"):FindFirstChild("Mundo"):FindFirstChild("Montones"):GetChildren() do
		if p:GetAttribute("Gold") == true then
			table.insert(list, p)
		end
	end
	return list
end

-- Avisos que ha recibido un jugador desde la posición «from» de W.fired
local function noticesTo(W: any, plr: any, from: number, kind: string, key: string): { any }
	local list = {}
	for i = from + 1, #W.fired do
		local f = W.fired[i]
		if f[1] == "Notify" and f[2] == plr and f[3] == kind and f[4] == key then
			table.insert(list, f[5])
		end
	end
	return list
end

-- Pieza «Pedestal» de una mejora en el Jardín
local function pedestalOf(mundoX: any, id: string): any
	for _, d in mundoX:FindFirstChild("Jardin"):GetChildren() do
		if d.Name == "Pedestal" and d:GetAttribute("UpgradeId") == id then
			return d
		end
	end
	return nil
end

local function buttons(gui: any): { any }
	local list = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("TextButton") then
			table.insert(list, d)
		end
	end
	return list
end

local function press(W: any, btn: any)
	W.signalFor(W.idOf(btn), "Activated"):Fire()
end

local function named(gui: any, name: string): any
	for _, d in gui:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function pressNamed(W: any, gui: any, name: string)
	local b = named(gui, name)
	assert(b, "no encuentro el botón " .. name)
	press(W, b)
	frame(W)
end

local function hasText(gui: any, text: string): boolean
	for _, d in gui:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and string.find(d.Text, text, 1, true) then
			return true
		end
	end
	return false
end

-- Puntos rojos del menú: los visibles son justo los de Config.menuAlerts (Tienda y Ajustes nunca)
local MENU_IDS = { "pets", "album", "missions", "daily", "shop", "upgrades", "islands", "settings" }
local function visibleDots(gui: any): { [string]: boolean }
	local v = {}
	for _, id in MENU_IDS do
		local d = named(gui, "Aviso_" .. id)
		assert(d, "falta el punto rojo de " .. id)
		v[id] = d.Visible == true
	end
	return v
end
local function checkDots(W: any, gui: any, where: string)
	local s = lastState(W)
	if not s then
		return
	end
	local ConfigX = W.require(W.wrap(W.game:GetService("ReplicatedStorage"):FindFirstChild("Config")))
	local alerts = ConfigX.menuAlerts(s)
	for id, on in visibleDots(gui) do
		assert(on == (alerts[id] == true), "punto rojo de " .. id .. " mal en " .. where)
	end
end

local function dump(W: any, gui: any, name: string)
	checkDots(W, gui, name)
	if DUMP then
		for _ = 1, 4 do -- que se vayan los avisos (duran 3 s)
			frame(W)
		end
		volcar(gui, DUMP .. "/" .. name .. ".json")
	end
end

local function leave(W: any)
	W.Players.PlayerRemoving:Fire(W.player)
	local real = W.realOf[W.player]
	local i = table.find(W.playerList, W.player)
	if i then
		table.remove(W.playerList, i)
	end
	real.Parent = nil
	W.player = nil
end

---------------------------------------------------------------------
print("-- Partida normal --")
local W, SPS = boot({ locale = "es-es" })
local _player, real, hrp = join(W, SPS, 42)
frame(W)
local gui = real:FindFirstChild("PlayerGui")
local Config = W.require(W.wrap(W.game:GetService("ReplicatedStorage"):FindFirstChild("Config")))
local mundo = W.game:GetService("Workspace"):FindFirstChild("Mundo")
local s = lastState(W)
assert(s, "el servidor no mandó el estado")
assert(#s.pets == 1 and #s.equipped == 1, "hay que empezar con 1 cría equipada")
assert(named(gui, "Tutorial").Visible, "el tutorial no sale al empezar")
assert(#mundo:FindFirstChild("Montones"):GetChildren() == Config.PILES_PER_ZONE * #Config.Zones, "faltan montones")
assert(s.stones == 0 and s.albumCount == 1 and s.albumTotal == 72 and s.shinyScore == 0, "estado inicial de Índice/piedras mal")
assert(#Config.Rarities == 8 and #Config.Pets == 72 and #Config.Zones == 9, "tienen que ser 8 rarezas, 72 crías y 9 islas")
-- 9 islas en el mundo, cada huevo del color de su rareza, y la puerta de la 9 (desde la 8)
for zi = 1, #Config.Zones do
	local isla = mundo:FindFirstChild("Isla" .. zi)
	assert(isla and isla:FindFirstChild("Huevo"), "falta la isla " .. zi .. " o su huevo")
	local c, e = isla:FindFirstChild("Huevo").Color, Config.EggColors[Config.Zones[zi].eggRarity].shell
	assert(math.abs(c.R - e.R) + math.abs(c.G - e.G) + math.abs(c.B - e.B) < 0.02, "el huevo de la isla " .. zi .. " no es del color de su rareza")
end
local door9 = nil
for _, d in mundo:GetDescendants() do
	if d.Name == "Puerta" and d:GetAttribute("Zone") == 9 then
		door9 = d
	end
end
assert(door9, "no hay puerta de la isla 9")
-- Jardín de Mejoras: 12 pedestales con orbe, anillo y ProximityPrompt; 14 caminos de neón; cartel; altar
local jardin = mundo:FindFirstChild("Jardin")
local L = W.require(W.wrap(W.game:GetService("ReplicatedStorage"):FindFirstChild("Lang")))
assert(jardin, "no hay Jardín de Mejoras")
do
local nPed, nOrb, nRing, nLink, nAltar = 0, 0, 0, 0, 0
for _, d in jardin:GetChildren() do
	if d.Name == "Pedestal" then
		nPed += 1
		local pp = d:FindFirstChildOfClass("ProximityPrompt")
		assert(pp and pp.MaxActivationDistance == Config.PROMPT_REACH and not pp.RequiresLineOfSight and pp.HoldDuration > 0, "pedestal sin ProximityPrompt bien puesto")
	elseif d.Name == "Orbe" then
		nOrb += 1
	elseif d.Name == "Anillo" then
		nRing += 1
	elseif d.Name == "Camino" then
		nLink += 1
		assert(d.Material == W.roblox.Enum.Material.Neon and d.CanCollide == false, "los caminos deben ser de neón y sin colisión")
	end
end
local altares = {}
for _, d in mundo:GetDescendants() do
	if d.Name == "Altar" and d:HasTag("FuseStation") then
		table.insert(altares, d)
		assert(d:FindFirstChildOfClass("ProximityPrompt"), "altar sin ProximityPrompt")
	end
end
nAltar = #altares
assert(nPed == 12 and nOrb == 12 and nRing == 12 and nLink == 14, string.format("Jardín: %d pedestales, %d orbes, %d anillos, %d caminos", nPed, nOrb, nRing, nLink))
assert(nAltar == 2, "tiene que haber 2 altares de fusión (zona 1 y Jardín), hay " .. nAltar)
assert(jardin:FindFirstChild("CartelJardin") and jardin:FindFirstChild("AltarFusion") and mundo:FindFirstChild("Isla1"):FindFirstChild("AltarFusion"), "falta el cartel o algún altar")
-- Paso de la zona 1 al Jardín: sin rocas en el hueco del muro oeste (x = −100) y con arco
local isla1 = mundo:FindFirstChild("Isla1")
for _, d in isla1:GetChildren() do
	if d.Name == "Acantilado" then
		local q = d.CFrame.Position
		assert(not (math.abs(q.X + 100) < 15 and math.abs(q.Z) < 8), "una roca tapa el paso al Jardín")
	end
end
assert(isla1:FindFirstChild("ArcoJardin"), "no hay arco en el paso al Jardín")
assert(mundo:FindFirstChild("Isla9"):FindFirstChild("Aurora") and mundo:FindFirstChild("Isla9"):FindFirstChild("Portal"), "la zona 9 no tiene su cielo de aurora")
-- Huevos sin modelos: elipsoide con manchas (más manchas cuanto más raro)
local manchas = 0
for _, d in mundo:FindFirstChild("Isla8"):FindFirstChild("Huevo"):GetChildren() do
	manchas += if d.Name == "Mancha" then 1 else 0
end
assert(manchas == Config.EggColors[5].spotCount, "el huevo Legendario no tiene sus manchas")
-- En el cliente: carteles de pedestal y altar traducidos
frame(W)
assert(hasText(mundo, L.t("es", "up_goldenroot_desc")) and hasText(mundo, L.t("es", "altar_title")), "faltan los carteles del Jardín o del altar")
assert(pedestalOf(mundo, "goldenroot"):FindFirstChildOfClass("ProximityPrompt").ActionText == L.t("es", "up_prompt_buy", { n = 1 }), "el prompt del pedestal no está traducido")
print("  Jardín (12 pedestales, 14 caminos, cartel, paso con arco), 2 altares, zona 9 con aurora, huevo con manchas: OK")
end
-- Puerta por Índice: con 1 cría descubierta la isla 2 (pide 3) no se abre, y sin gastar monedas
local okU, keyU = W.callbacks.Action(W.player, "unlockZone", 2)
assert(not okU and keyU == "n_need_index" and lastState(W).zones == 1, "la isla 2 se abre sin descubrir 3 crías")
assert(not W.callbacks.Action(W.player, "unlockZone", 3), "se puede saltar una isla")
assert(not W.callbacks.Action(W.player, "rebirth"), "renacer ya no debe existir")
assert(named(gui, "Menu_rebirth") == nil and named(gui, "Menu_upgrades"), "el menú aún tiene Renacer o no tiene Mejoras")
-- Huevos por rareza: especies y probabilidades visibles
for zi, nSp in { 1, 1, 2, 2, 3, 4, 4, 5, 6 } do
	local odds = Config.eggOdds(zi, {}, {})
	assert(#odds.species == nSp, "el huevo de la isla " .. zi .. " debe dar " .. nSp .. " especies")
	for _, sp in odds.species do
		assert(Config.PetById[sp.kind].rarity == Config.Zones[zi].eggRarity and math.abs(sp.pct - 100 / nSp) < 1e-9, "especie del huevo " .. zi .. " mal")
	end
end
assert(Config.rollPet(3, 0.1) ~= Config.rollPet(3, 0.9), "el huevo de la isla 3 solo da una especie")
-- Brillante: 1 %, ×2 en la isla 9, ×2 con suerte, ×1,5 con Flor Destello; poder ×2
assert(math.abs(Config.shinyChance(1, {}, {}) - 0.01) < 1e-12 and math.abs(Config.shinyChance(9, {}, {}) - 0.02) < 1e-12, "probabilidad de Brillante mal")
assert(math.abs(Config.shinyChance(1, {}, { luck = true }) - 0.02) < 1e-12, "la suerte no duplica la Brillante")
assert(math.abs(Config.shinyChance(9, { upgrades = { sparklebloom = true } }, { luck = true }) - 0.06) < 1e-12, "el máximo de Brillante no es 6 %")
assert(Config.petPower("sproutchick", true) == 2 * Config.petPower("sproutchick", false), "una Brillante no da ×2 de poder")
print("  9 islas, huevos por rareza (especies y % visibles), Brillante 1 %/×2, puerta por Índice cerrada, sin renacer: OK")
dump(W, gui, "00_inicio")
do -- jugador nuevo: solo el diario tiene algo que recoger
	local v = visibleDots(gui)
	for id, on in v do
		assert(on == (id == "daily"), "jugador nuevo: sobra o falta el punto rojo de " .. id)
	end
end

-- Cristales distintos por isla: colores de su paleta (varios en la misma isla) y tamaño según el tipo
local function nearPalette(c: any, palette: { any }): boolean
	for _, q in palette do
		-- el color es uno de la paleta aclarado hacia blanco como mucho un 15 %
		local okC = true
		for _, ch in { "R", "G", "B" } do
			local d = c[ch] - q[ch]
			if d < -0.01 or d > 0.15 * (1 - q[ch]) + 0.01 then
				okC = false
			end
		end
		if okC then
			return true
		end
	end
	return false
end
local zonesWithVariety = 0
for zi = 1, #Config.Zones do
	local colors, sizes = {}, { coins = {}, chest = {}, crystal = {} }
	for _, p in mundo:FindFirstChild("Montones"):GetChildren() do
		if p:GetAttribute("Zone") == zi and p:GetAttribute("Gold") ~= true then
			assert(nearPalette(p.Color, Config.Zones[zi].crystalColors), "un cristal de la isla " .. zi .. " no es de su paleta")
			colors[string.format("%.2f,%.2f,%.2f", p.Color.R, p.Color.G, p.Color.B)] = true
			table.insert(sizes[p:GetAttribute("Kind")], p.Size.Y)
		end
	end
	local nColors = 0
	for _ in colors do
		nColors += 1
	end
	assert(nColors >= 3, "en la isla " .. zi .. " casi todos los cristales son del mismo color")
	local function avg(t: { number }): number?
		if #t == 0 then
			return nil
		end
		local sum = 0
		for _, v in t do
			sum += v
		end
		return sum / #t
	end
	local a1, a2, a3 = avg(sizes.coins), avg(sizes.chest), avg(sizes.crystal)
	assert(not (a1 and a2) or a1 < a2, "en la isla " .. zi .. " el cristal mediano no es mayor que el pequeño")
	assert(not (a2 and a3) or a2 < a3, "en la isla " .. zi .. " el cristal grande no es mayor que el mediano")
	if a1 and a2 and a3 then
		zonesWithVariety += 1
	end
end
assert(zonesWithVariety >= 2, "no hay 2 islas con los 3 tamaños de cristal")
-- Cada isla rinde claramente más por segundo (monedas por punto de vida ×2–3 frente a la anterior)
for zi = 2, #Config.Zones do
	local r = Config.coinsPerHp(zi) / Config.coinsPerHp(zi - 1)
	assert(r >= 2 and r <= 3, string.format("la isla %d rinde ×%.2f por segundo frente a la anterior (debe ser ×2–3)", zi, r))
end
-- Cartel de la puerta: «Cristales ×N monedas» (traducido)
local Lang0 = W.require(W.wrap(W.game:GetService("ReplicatedStorage"):FindFirstChild("Lang")))
local cartel = string.gsub(Lang0.es.door_crystals, "{value}", "2.5")
assert(hasText(mundo, cartel), "la puerta de la isla 2 no dice cuánto rinden sus cristales (" .. cartel .. ")")
print(string.format("  cristales: colores de su paleta y 3 tamaños (%d islas con los 3), isla 2 rinde ×%.1f/s, cartel: OK", zonesWithVariety, Config.zoneCrystalMult(2)))

-- Tocar un montón (ClickDetector) y dejar que las crías trabajen solas (Auto)
local pile = nil
for _, p in mundo:FindFirstChild("Montones"):GetChildren() do
	if p:GetAttribute("Zone") == 1 and (p.CFrame.Position - hrp.CFrame.Position).Magnitude < Config.REACH then
		pile = p
		break
	end
end
assert(pile, "no hay montones cerca de la aparición")
W.signalFor(W.idOf(pile:FindFirstChildOfClass("ClickDetector")), "MouseClick"):Fire(W.player)
assert(W.realOf[W.player]:GetAttribute("Target") == pile:GetAttribute("PileId"), "tocar el montón no manda a las crías")
local ok = W.callbacks.Action(W.player, "target", pile:GetAttribute("PileId"))
assert(ok, "la acción target falla")
assert(not W.callbacks.Action(W.player, "target", 99999), "target acepta un montón que no existe")
local firedCoins = #W.fired
for _ = 1, 60 do
	frame(W)
end
-- Cada «+🪙» dice cuánto vale frente al premio típico de la isla (para dibujarlo más grande)
local avisos = noticesTo(W, W.player, firedCoins, "coins", "n_coins")
assert(#avisos > 0, "romper cristales no avisa de las monedas")
for _, n in avisos do
	assert(type(n.rel) == "number" and n.rel > 0, "el aviso de monedas no trae «rel»")
end
-- El cliente lo dibuja más grande cuanto más vale
do
	local notifyR = W.game:GetService("ReplicatedStorage"):FindFirstChild("MythicHatchlingsRemotes"):FindFirstChild("Notify")
	local locales = W.game:GetService("Workspace"):FindFirstChild("CriasLocales")
	W.signalFor(W.idOf(notifyR), "OnClientEvent"):Fire("coins", "n_coins", { value = 5, rel = 0.4, x = 1001, y = 0, z = 0 })
	W.signalFor(W.idOf(notifyR), "OnClientEvent"):Fire("coins", "n_coins", { value = 500, rel = 15, x = 2002, y = 0, z = 0 })
	local small, big = nil, nil
	for _, a0 in locales:GetChildren() do
		local bb = a0:FindFirstChildOfClass("BillboardGui")
		if bb and a0:IsA("BasePart") then
			local x = math.floor(a0.CFrame.Position.X + 0.5)
			if x == 1001 then
				small = bb.Size.Y.Offset
			elseif x == 2002 then
				big = bb.Size.Y.Offset
			end
		end
	end
	assert(small and big and big > small * 1.5, string.format("el «+🪙» de un premio grande no sale más grande (%s / %s)", tostring(small), tostring(big)))
	print(string.format("  «+🪙» flotante: %d avisos con rel; tamaño %d → %d px según lo que vale: OK", #avisos, small, big))
end
s = lastState(W)
assert(s.coins > 0, "las crías no dan monedas")
print(string.format("  tras 60 s: %s monedas", tostring(math.floor(s.coins))))
assert(#W.game:GetService("Workspace"):FindFirstChild("CriasLocales"):GetChildren() >= 1, "no se dibujan las crías")

-- Montón Dorado (1 jugador): aparece en su isla con estrella y aviso, se rompe y paga x33, no reaparece y caduca.
-- Para no esperar 3 min se baja Config.GOLD_INTERVAL (el servidor lo lee en cada vuelta) y luego se deja como estaba
local Lang = W.require(W.wrap(W.game:GetService("ReplicatedStorage"):FindFirstChild("Lang")))
local goldInterval = Config.GOLD_INTERVAL
W.callbacks.Action(W.player, "setAuto", false) -- que las crías no vayan solas a por él (se mide su premio)
for _ = 1, 3 do
	frame(W)
end
local fired0 = #W.fired
Config.GOLD_INTERVAL = 2
for _ = 1, 4 do
	if #golds(W) > 0 then
		break
	end
	frame(W)
end
Config.GOLD_INTERVAL = 1e9 -- que no salga otro mientras se prueba este
local g = golds(W)
assert(#g == 1, "con 1 jugador tiene que salir UN Montón Dorado (salen " .. #g .. ")")
local gold = g[1]
assert(gold:GetAttribute("Zone") == 1, "el Montón Dorado no está en la isla del jugador")
local esperada = math.max(1, math.min(Config.GOLD_HP * Config.Zones[1].pileHp, math.floor(lastState(W).power * Config.GOLD_MAX_SECONDS)))
assert(gold:GetAttribute("MaxHp") == esperada, "vida del Montón Dorado mal: " .. tostring(gold:GetAttribute("MaxHp")) .. " (esperada " .. esperada .. ")")
assert(esperada <= lastState(W).power * Config.GOLD_MAX_SECONDS, "el Montón Dorado no se puede romper antes de caducar")
local avisos = noticesTo(W, W.player, fired0, "gold", "n_gold_pile")
assert(#avisos == 1 and avisos[1].zone == 1 and avisos[1].secs == Config.GOLD_LIFETIME, "no llega el aviso del Montón Dorado")
frame(W)
assert(gold:FindFirstChild("MarcaDorada"), "no sale la estrella 🌟 sobre el Montón Dorado")
local textoOro = Lang.t("es", "n_gold_pile", { zone = Lang.t("es", "zone_meadow"), secs = Config.GOLD_LIFETIME })
assert(hasText(gui, textoOro), "no sale el aviso dorado en pantalla")
if DUMP then
	volcar(gui, DUMP .. "/00b_monton_dorado.json")
end
local c0 = lastState(W).coins
hrp.CFrame = W.roblox.CFrame.new(gold.CFrame.Position + W.roblox.Vector3.new(0, 0, 12))
W.signalFor(W.idOf(gold:FindFirstChildOfClass("ClickDetector")), "MouseClick"):Fire(W.player)
assert(W.realOf[W.player]:GetAttribute("Target") == gold:GetAttribute("PileId"), "tocar el Montón Dorado no manda a las crías")
for _ = 1, Config.GOLD_LIFETIME do
	if not gold.Parent then
		break
	end
	frame(W)
end
assert(gold.Parent == nil, "las crías no rompen el Montón Dorado")
local sOro = lastState(W)
assert(sOro.coins - c0 >= Config.GOLD_COINS * Config.Zones[1].pileCoins * sOro.coinMult * 0.99,
	string.format("el Montón Dorado paga poco: %.1f", sOro.coins - c0))
for _ = 1, Config.PILE_RESPAWN + 2 do
	frame(W)
end
assert(#golds(W) == 0, "el Montón Dorado no debe reaparecer")
assert(#mundo:FindFirstChild("Montones"):GetChildren() == Config.PILES_PER_ZONE * #Config.Zones, "el Montón Dorado ha reaparecido como un montón normal")
-- Caduca: sale otro, nadie lo toca (sin Auto y lejos) → a los GOLD_LIFETIME s ya no está y no ha dado monedas
Config.GOLD_INTERVAL = 1
frame(W)
Config.GOLD_INTERVAL = 1e9
assert(#golds(W) == 1, "no sale el 2.º Montón Dorado")
local hrpPos = hrp.CFrame.Position
hrp.CFrame = W.roblox.CFrame.new(hrpPos + W.roblox.Vector3.new(0, 500, 0))
frame(W)
local c2 = lastState(W).coins
for _ = 1, Config.GOLD_LIFETIME do
	frame(W)
end
assert(#golds(W) == 0, "el Montón Dorado no caduca")
assert(lastState(W).coins == c2, "un Montón Dorado caducado no debe dar monedas")
hrp.CFrame = W.roblox.CFrame.new(hrpPos)
Config.GOLD_INTERVAL = goldInterval
W.callbacks.Action(W.player, "setAuto", true)
frame(W)
print("  montón dorado (aparece, estrella, aviso, paga x33, no reaparece, caduca): OK")

-- Ir al huevo y abrirlo
for _ = 1, 200 do
	if lastState(W).coins >= Config.Zones[1].eggCost then
		break
	end
	frame(W)
end
local egg = mundo:FindFirstChild("Isla1"):FindFirstChild("Huevo")
-- Desde la aparición (≈28 studs del huevo; tras el dorado el bot puede haber quedado en cualquier sitio)
hrp.CFrame = W.roblox.CFrame.new(mundo:FindFirstChild("Aparicion").CFrame.Position + W.roblox.Vector3.new(0, 3, 0))
local okLejos, keyLejos = W.callbacks.Action(W.player, "hatch", 1, 1, false)
assert(not okLejos and keyLejos == "n_go_egg", "se puede abrir el huevo desde lejos")
hrp.CFrame = W.roblox.CFrame.new(egg.CFrame.Position + W.roblox.Vector3.new(0, 0, 8))
frame(W)
assert(named(gui, "AbrirHuevo") and named(gui, "AbrirHuevo").Parent.Parent.Parent.Visible, "no sale el panel del huevo al lado")
assert(hasText(gui, "100 %") and hasText(gui, "1 %"), "el panel del huevo no muestra la probabilidad de la especie y de Brillante")
dump(W, gui, "01_huevo")
pressNamed(W, gui, "AbrirHuevo")
s = lastState(W)
assert(#s.pets == 2, "abrir el huevo no da una cría")
assert(named(gui, "Apertura").Visible, "no sale la animación de apertura")
if DUMP then
	volcar(gui, DUMP .. "/02_apertura.json")
end
assert(not W.callbacks.Action(W.player, "hatch", 1, 3, false), "x3 sin pase")
assert(not W.callbacks.Action(W.player, "hatch", 5, 1, false), "huevo de isla cerrada")
for _ = 1, 4 do
	frame(W)
end
print("  abrir huevo: OK")

-- Salir y volver con una partida avanzada: monedas, crías para probar cada fusión, Índice de 20 y misiones listas
leave(W)
local saved = W.saved[KEY]
assert(saved and #saved.pets == 2, "no se guardó la partida al salir")
saved.coins = 1e13
local function give(kind: string, n: number, shiny: boolean?): { number }
	local uids = {}
	for _ = 1, n do
		table.insert(saved.pets, { uid = saved.nextUid, kind = kind, shiny = shiny == true })
		table.insert(uids, saved.nextUid)
		saved.nextUid += 1
	end
	return uids
end
give("sproutchick", 5) -- 5 Comunes (+ la inicial, equipada, y la del huevo) → 5→1 sin gastar la equipada
give("bloomeagle", 3) -- 3 Prodigiosas → 3→1 (Ascendida)
local dawn = give("dawneagle", 3) -- 3 Ascendidas, 2 EQUIPADAS → Mítica + Piedra, y vuelve a equipar lo mejor
saved.equipped = { 1, dawn[1], dawn[2] }
give("mosskit", 4) -- 4 normales + 1 Brillante de la isla 2: no se mezclan
give("mosskit", 1, true)
local n = 0
for _, pet in Config.Pets do
	if n < 20 then
		saved.album[pet.id] = true
		n += 1
	end
end
local day = math.floor((1_700_000_000 + W.fakeTime) // 86400)
saved.stats.piles = 1000
saved.missions = { day = day, bonusGiven = false, list = {
	{ tier = "easy", stat = "piles", n = 40, start = 0, claimed = false },
	{ tier = "medium", stat = "piles", n = 200, start = 0, claimed = false },
	{ tier = "hard", stat = "piles", n = 500, start = 0, claimed = false },
} }
local _p2, real2, hrp2 = join(W, SPS, 42)
frame(W)
gui = real2:FindFirstChild("PlayerGui")
hrp = hrp2
s = lastState(W)
assert(s.coins >= 1e12, "no se cargó la partida")
assert(s.nearAltar == true, "la aparición debe estar junto al Altar de Fusión")

-- Lejos del altar no se fusiona (Config.FUSE_NEEDS_ALTAR); la ventana ofrece «Ir al altar»
local spawnPos = hrp.CFrame.Position
hrp.CFrame = W.roblox.CFrame.new(spawnPos + W.roblox.Vector3.new(0, 0, -80))
frame(W)
local okF, keyF = W.callbacks.Action(W.player, "fuse", 1, 1, false)
assert(not okF and keyF == "n_go_altar", "se puede fusionar lejos del altar")
assert(not W.callbacks.Action(W.player, "fuseAll"), "se puede «Fusionar todo» lejos del altar")
pressNamed(W, gui, "Menu_pets")
dump(W, gui, "03_crias")
pressNamed(W, gui, "IrAltar")
frame(W)
assert(lastState(W).nearAltar == true, "«Ir al altar» no lleva al altar")

-- Tarjeta de una Común (las tarjetas de cría llevan un botón invisible encima; se busca por su emoji)
local function commonCard(): any
	local hit = nil
	for _, d in gui:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "" and d.Parent and d.Parent.Parent and d.Parent.Parent:IsA("Frame") then
			for _, l in d.Parent:GetChildren() do
				if l:IsA("TextLabel") and l.Text == Config.PetById.sproutchick.emoji then
					hit = d
				end
			end
		end
	end
	assert(hit, "no encuentro la tarjeta de la cría para fusionar")
	return hit
end

-- Lejos del altar, con bastantes iguales, el botón de la cría elegida es «Ir al altar»: lleva al altar y no fusiona
hrp.CFrame = W.roblox.CFrame.new(spawnPos + W.roblox.Vector3.new(0, 0, -80))
frame(W)
assert(lastState(W).nearAltar ~= true, "la prueba debería empezar lejos del altar")
pressNamed(W, gui, "Menu_pets")
press(W, commonCard())
frame(W)
assert(named(gui, "FusionarIrAltar") and not named(gui, "Fusionar"), "lejos del altar el botón de la cría no lleva al altar")
local farBefore = lastState(W)
pressNamed(W, gui, "FusionarIrAltar")
frame(W)
local farAfter = lastState(W)
assert(farAfter.nearAltar == true, "«Ir al altar» de la cría elegida no lleva al altar")
assert(#farAfter.pets == #farBefore.pets, "«Ir al altar» ha fusionado")
assert(not named(gui, "Fondo").Visible, "«Ir al altar» de la cría no cierra la ventana")
print("  fusionar lejos del altar → «Ir al altar» (FusionarIrAltar) teletransporta sin fusionar: OK")

-- Crías: elegir una Común → «Fusionar 7/5 → Poco común»
pressNamed(W, gui, "Menu_pets")
local hit = commonCard()
press(W, hit)
frame(W)
dump(W, gui, "04_cria_elegida")
local before = #lastState(W).pets
pressNamed(W, gui, "Fusionar")
s = lastState(W)
assert(s.album.cloverchick and #s.pets == before - 4, "la fusión 5→1 no dio la Poco común de la isla")
local starterKept = false
for _, p in s.pets do
	starterKept = starterKept or p.uid == 1
end
assert(starterKept, "la fusión gastó una equipada habiendo sin equipar")

-- 3 Ascendidas equipadas → Mítica: +1 Piedra en la misma fusión, aviso y vuelve a equipar lo mejor
local firedM = #W.fired
local okM, _kM, pM = W.callbacks.Action(W.player, "fuse", 1, 7, false)
s = lastState(W)
assert(okM and pM.stones == 1 and s.stones == 1, "crear una Mítica no da una Piedra")
local mythicUid = nil
for _, p in s.pets do
	if p.kind == "meadowskylord" then
		mythicUid = p.uid
	end
end
assert(mythicUid and table.find(s.equipped, mythicUid), "tras gastar equipadas no se equipa lo mejor (la Mítica)")
assert(#noticesTo(W, W.player, firedM, "success", "n_stone") == 1, "no llega el aviso de la Piedra")
local mythicNotice = false
for i = firedM + 1, #W.fired do
	local f = W.fired[i]
	mythicNotice = mythicNotice or (f[1] == "Notify" and f[2] == "all" and f[4] == "n_mythic_made")
end
assert(mythicNotice, "crear una Mítica no avisa al servidor")
-- «Fusionar todo»: las 3 Prodigiosas → 1 Ascendida; los mosskit (4 normales + 1 Brillante) no se mezclan
local okA, _kA, pA = W.callbacks.Action(W.player, "fuseAll")
s = lastState(W)
assert(okA and pA.count == 1 and s.album.dawneagle and s.stones == 1, "«Fusionar todo» no hace la 3→1")
local moss, mossShiny = 0, 0
for _, p in s.pets do
	if p.kind == "mosskit" then
		if p.shiny then
			mossShiny += 1
		else
			moss += 1
		end
	end
end
assert(moss == 4 and mossShiny == 1, "se mezclaron Brillantes con normales")
W.tick(1) -- límite de 10 acciones/s
local okN, keyN = W.callbacks.Action(W.player, "fuseAll")
assert(not okN and keyN == "n_fuse_none", "«Fusionar todo» sin nada que fusionar debe decirlo")
assert(not W.callbacks.Action(W.player, "fuse", 2, 1, true) and not W.callbacks.Action(W.player, "fuse", 2, 1, false), "se fusiona sin 5 iguales")
assert(not W.callbacks.Action(W.player, "fuse", "mosskit", 1, false), "fuse acepta una isla que no es número")
assert(not W.callbacks.Action(W.player, "fuse", 1, 8, false), "fuse acepta Míticas")
assert(not W.callbacks.Action(W.player, "fuse", 1, 1, "sí"), "fuse acepta un Brillante que no es booleano")
assert(not W.callbacks.Action(W.player, "fuse", 1, 1.5, false), "fuse acepta una rareza con decimales")
assert(lastState(W).album.meadowskylord, "la Mítica creada no está en el Índice")
pressNamed(W, gui, "Menu_pets")
assert(named(gui, "FusionarTodo"), "en el altar la ventana no tiene «Fusionar todo»")
pressNamed(W, gui, "FusionarTodo") -- sin nada que fusionar: botón apagado, no rompe
print("  fusión en el altar (lejos no), 5→1, 3→1, «Fusionar todo», Mítica → Piedra, no mezcla Brillantes: OK")

-- Equipar mejores; soltar
pressNamed(W, gui, "EquiparMejores")
s = lastState(W)
assert(#s.equipped == math.min(s.slots, #s.pets), "Equipar mejores no llena los huecos")
before = #s.pets
local loose = s.equipped[#s.equipped]
W.callbacks.Action(W.player, "unequip", loose)
frame(W)
pressNamed(W, gui, "Cria_" .. loose)
pressNamed(W, gui, "Soltar")
assert(#lastState(W).pets == before, "Soltar debe pedir confirmación")
pressNamed(W, gui, "Soltar")
assert(#lastState(W).pets == before - 1, "Soltar no quita la cría")
assert(not W.callbacks.Action(W.player, "equip", 99999), "equipar una cría que no existe")
W.callbacks.Action(W.player, "equipBest")
local eqUid = lastState(W).equipped[1]
assert(not W.callbacks.Action(W.player, "release", eqUid), "se puede soltar una cría equipada")
assert(W.callbacks.Action(W.player, "unequip", eqUid), "quitar una cría no funciona")
assert(not table.find(lastState(W).equipped, eqUid), "la cría sigue equipada")
assert(W.callbacks.Action(W.player, "equip", eqUid), "volver a equipar no funciona")
pressNamed(W, gui, "Cerrar")
print("  equipar mejores y soltar: OK")

-- Islas por Índice (20 descubiertas): 2, 3 y 4 desde el menú, la 5 por la puerta; la 6 (pide 21) no
local coinsBefore = lastState(W).coins
pressNamed(W, gui, "Menu_islands")
dump(W, gui, "05_islas")
for z = 2, 4 do
	pressNamed(W, gui, "AbrirIsla" .. z)
	frame(W)
end
s = lastState(W)
assert(s.zones == 4, "no se abrieron las islas (zones = " .. s.zones .. ")")
assert(s.coins >= coinsBefore, "abrir islas no debe costar monedas")
pressNamed(W, gui, "Ir4")
local c4 = mundo:FindFirstChild("Isla4"):FindFirstChild("Suelo").CFrame.Position
assert((hrp.CFrame.Position - c4).Magnitude < 60, "Ir a la isla 4 no mueve al jugador")
assert(not W.callbacks.Action(W.player, "teleport", 6), "viajar a una isla cerrada")

-- Puerta de la isla 5: panel al acercarse y abrir
local door = nil
for _, d in mundo:GetDescendants() do
	if d.Name == "Puerta" and d:GetAttribute("Zone") == 5 then
		door = d
	end
end
assert(door, "no encuentro la puerta de la isla 5")
hrp.CFrame = W.roblox.CFrame.new(door.CFrame.Position + W.roblox.Vector3.new(-10, -18, 0))
frame(W)
assert(named(gui, "AbrirPuerta").Parent.Parent.Visible, "no sale el panel de la puerta")
dump(W, gui, "06_puerta")
pressNamed(W, gui, "AbrirPuerta")
assert(lastState(W).zones == 5, "la puerta no abre la isla 5")
local ok6, key6, p6 = W.callbacks.Action(W.player, "unlockZone", 6)
assert(not ok6 and key6 == "n_need_index" and p6.n == 21 and p6.have == lastState(W).albumCount, "la isla 6 se abre sin 21 crías descubiertas")
assert(lastState(W).nextZone.need == 21 and lastState(W).nextZone.kind == "index", "el estado no dice lo que pide la isla 6")
print("  islas por Índice (sin monedas; rechaza la 6), viaje y puerta: OK")

-- Mejoras: con 1 Piedra se compra la Raíz Dorada, pero EN su pedestal; el resto pide requisitos o más piedras
do
local cm0 = lastState(W).coinMult
local okR, keyR = W.callbacks.Action(W.player, "buyUpgrade", "swiftsprout")
assert(not okR and keyR == "n_need_upgrade", "se compra una mejora sin su requisito")
assert(not W.callbacks.Action(W.player, "buyUpgrade", "noexiste") and not W.callbacks.Action(W.player, "buyUpgrade", 5), "buyUpgrade acepta un id falso")
local okL, keyL = W.callbacks.Action(W.player, "buyUpgrade", "goldenroot")
assert(not okL and keyL == "n_go_pedestal" and not lastState(W).upgrades.goldenroot, "se compra una mejora lejos de su pedestal")
pressNamed(W, gui, "Menu_upgrades")
dump(W, gui, "07_mejoras")
pressNamed(W, gui, "Mejora_goldenroot") -- lejos: botón apagado, no compra
assert(not lastState(W).upgrades.goldenroot, "la ventana compra lejos del pedestal")
pressNamed(W, gui, "IrJardin")
frame(W)
local gc = jardin:FindFirstChild("Suelo").CFrame.Position
assert(math.abs(hrp.CFrame.Position.X - gc.X) < 100 and math.abs(hrp.CFrame.Position.Z - gc.Z) < 100, "«Ir al jardín» no lleva al Jardín")
local ped = pedestalOf(mundo, "goldenroot")
hrp.CFrame = W.roblox.CFrame.new(ped.CFrame.Position + W.roblox.Vector3.new(0, 1.5, 6))
frame(W)
pressNamed(W, gui, "Menu_upgrades")
pressNamed(W, gui, "Mejora_goldenroot")
s = lastState(W)
assert(s.upgrades.goldenroot and s.stones == 0, "comprar la Raíz Dorada no gasta la piedra")
assert(math.abs(s.coinMult / cm0 - 1.25) < 1e-9, "la Raíz Dorada no da +25 % de monedas")
local okD, keyD = W.callbacks.Action(W.player, "buyUpgrade", "goldenroot")
assert(not okD and keyD == "n_upgrade_owned", "se puede comprar dos veces la misma mejora")
local okS, keyS, pS = W.callbacks.Action(W.player, "buyUpgrade", "thriftynest")
assert(not okS and keyS == "n_need_stones" and pS.n == 5, "se compra una mejora sin piedras")
pressNamed(W, gui, "Cerrar")
frame(W)
-- El cliente pinta el pedestal comprado de verde (neón) y el prompt dice «Comprada»; los demás siguen grises
local function orbOf(id: string): any
	for _, d in jardin:GetChildren() do
		if d.Name == "Orbe" and d:GetAttribute("UpgradeId") == id then
			return d
		end
	end
	return nil
end
local green, grey = orbOf("goldenroot").Color, orbOf("mightysap").Color
assert(green.G > 0.7 and green.R < 0.3 and orbOf("goldenroot").Material == W.roblox.Enum.Material.Neon, "el pedestal comprado no está verde")
assert(math.abs(grey.R - grey.B) < 0.25 and grey.G < 0.6, "un pedestal bloqueado no está gris")
assert(ped:FindFirstChildOfClass("ProximityPrompt").ActionText == L.t("es", "up_prompt_owned"), "el prompt no dice «Comprada»")
print("  mejoras: requisito, id falso, lejos del pedestal no, «Ir al jardín», en el pedestal sí (+25 %), no repetir, sin piedras, colores: OK")

-- Altar físico: su ProximityPrompt abre la ventana de Crías con «Fusionar todo»
hrp.CFrame = W.roblox.CFrame.new(mundo:FindFirstChild("Aparicion").CFrame.Position + W.roblox.Vector3.new(0, 3, 0))
frame(W)
local altarPrompt = mundo:FindFirstChild("Isla1"):FindFirstChild("AltarFusion"):FindFirstChild("Altar"):FindFirstChildOfClass("ProximityPrompt")
assert(altarPrompt.ActionText == L.t("es", "altar_prompt"), "el prompt del altar no está traducido")
W.signalFor(W.idOf(altarPrompt), "Triggered"):Fire(W.player)
frame(W)
assert(named(gui, "Fondo").Visible and named(gui, "FusionarTodo"), "el altar no abre la ventana de fusión")
dump(W, gui, "07b_altar_fusion")
-- «Soltar repetidas»: Míticas e islas anteriores, nunca equipadas, Brillantes ni la última de cada especie
local before = lastState(W)
local expected = #W.require(W.wrap(W.game:GetService("ReplicatedStorage"):FindFirstChild("Config"))).dupesToRelease(before)
assert(expected > 0, "la partida de prueba debería tener repetidas que soltar")
pressNamed(W, gui, "SoltarRepetidas")
assert(#lastState(W).pets == #before.pets, "«Soltar repetidas» debe pedir confirmación")
pressNamed(W, gui, "SoltarRepetidas")
local after = lastState(W)
assert(#after.pets == #before.pets - expected, "«Soltar repetidas» no suelta las que dice la regla")
local kinds, eqOk = {}, true
for _, p in after.pets do
	kinds[p.kind] = (kinds[p.kind] or 0) + (if p.shiny then 0 else 1)
end
for _, p in before.pets do
	assert(p.shiny ~= true or kinds[p.kind] ~= nil, "se soltó una Brillante")
	if not p.shiny then
		assert((kinds[p.kind] or 0) >= 1, "se soltó la última normal de " .. p.kind)
	end
end
for _, uid in before.equipped do
	local found = false
	for _, p in after.pets do
		found = found or p.uid == uid
	end
	eqOk = eqOk and found
end
assert(eqOk, "se soltó una cría equipada")
local okDu, keyDu = W.callbacks.Action(W.player, "releaseDupes")
assert(not okDu and keyDu == "n_no_dupes", "sin repetidas debe decirlo")
pressNamed(W, gui, "Cerrar")
print(string.format("  altar físico abre la fusión; «Soltar repetidas» (%d, nunca equipadas/Brillantes/última): OK", expected))
end

-- Álbum, misiones, diario, tienda, ajustes
pressNamed(W, gui, "Menu_album")
dump(W, gui, "08_album")
local claim = nil
for _, b in buttons(gui) do
	if b.Text == "Recoger" and b:GetAttribute("Enabled") then
		claim = b
		break
	end
end
assert(claim, "no hay hito del álbum para reclamar")
press(W, claim)
frame(W)
local claimedA = lastState(W).albumClaimed
assert(claimedA["1"] or claimedA["2"], "no se reclamó el álbum") -- 20/72 = 28 %: valen el de 10 % y el de 25 %
-- Índice Brillante: pestaña aparte con la puntuación
pressNamed(W, gui, "VerBrillantes")
assert(hasText(gui, Lang0.t("es", "shiny_score", { n = lastState(W).shinyScore, need = 200 })), "la pestaña Brillantes no muestra la puntuación")
dump(W, gui, "08b_album_brillantes")
pressNamed(W, gui, "VerNormales")
pressNamed(W, gui, "Cerrar")
pressNamed(W, gui, "Menu_missions")
dump(W, gui, "09_misiones")
for i = 1, 3 do
	pressNamed(W, gui, "Mision" .. i)
end
s = lastState(W)
assert(s.missions[3].claimed and s.luckLeft > 0, "las misiones no dan la suerte x2")
assert(not named(gui, "Aviso_missions").Visible, "el punto rojo de Misiones sigue tras recogerlas")
pressNamed(W, gui, "Menu_daily")
dump(W, gui, "10_diario")
pressNamed(W, gui, "RecogerDiario")
assert(not lastState(W).daily.available, "el diario no se recogió")
assert(not named(gui, "Aviso_daily").Visible, "el punto rojo del Diario sigue tras recogerlo")
pressNamed(W, gui, "Menu_shop")
dump(W, gui, "11_tienda")
pressNamed(W, gui, "Menu_settings")
pressNamed(W, gui, "Idioma")
frame(W)
assert(lastState(W).settings.lang == "es", "no cambia el idioma")
pressNamed(W, gui, "Sonido")
frame(W)
assert(lastState(W).settings.muted == true, "no cambia el sonido")
dump(W, gui, "12_ajustes")
pressNamed(W, gui, "Cerrar")
for _ = 1, 3 do
	if not lastState(W).tutorialDone then
		pressNamed(W, gui, "TutorialSiguiente")
		frame(W)
	end
end
assert(lastState(W).tutorialDone, "saltar el tutorial no lo da por hecho")
W.callbacks.Action(W.player, "setAuto", false)
assert(lastState(W).settings.auto == false, "setAuto no funciona")
print("  álbum, misiones, diario, tienda, ajustes, tutorial: OK")

-- Compras simuladas: entrega, no repite y deshace si no se puede guardar
local product = Config.Products[1]
product.id = 1234
local PS = W.roblox.Enum.ProductPurchaseDecision
local c0 = lastState(W).coins
local r1 = W.MarketplaceService.ProcessReceipt({ PlayerId = 42, PurchaseId = "compra1", ProductId = 1234 })
assert(r1 == PS.PurchaseGranted, "la compra no se confirma")
local c1 = lastState(W).coins
assert(c1 > c0, "la compra no da monedas")
assert(W.MarketplaceService.ProcessReceipt({ PlayerId = 42, PurchaseId = "compra1", ProductId = 1234 }) == PS.PurchaseGranted, "repetir la compra falla")
assert(lastState(W).coins == c1, "una compra repetida se entrega dos veces")
W.datastoreFails = true
local r2 = nil
W.task.spawn(function() -- el guardado reintenta con esperas: va en su propia tarea
	r2 = W.MarketplaceService.ProcessReceipt({ PlayerId = 42, PurchaseId = "compra2", ProductId = 1234 })
end)
for _ = 1, 8 do
	if r2 == nil then
		W.tick(1)
	end
end
W.datastoreFails = false
assert(r2 == PS.NotProcessedYet, "sin guardar no se debe confirmar la compra")
frame(W)
assert(math.abs(lastState(W).coins - c1) < c1 * 0.01 + 1e6, "no se deshizo la compra sin guardar")
product.id = 0
print("  compras (entregar, no repetir, deshacer): OK")

-- Pulsar TODOS los botones dos veces (nada debe romper)
local pulsados = 0
for _ = 1, 2 do
	for _, b in buttons(gui) do
		if b.Parent then
			press(W, b)
			pulsados += 1
		end
	end
	frame(W)
end
print("  botones pulsados:", pulsados)

-- Salir (guarda) y volver a entrar (carga)
before = lastState(W)
leave(W)
saved = W.saved[KEY]
assert(saved and saved.upgrades.goldenroot and saved.stones == 0 and saved.shinyIndex.mosskit == nil, "no se guardó la partida al salir")
assert(saved.rebirths == nil and saved.stats.mythics == 1, "la partida guardada no tiene las estadísticas nuevas")
local _p3, real3 = join(W, SPS, 42)
frame(W)
local after = lastState(W)
assert(after.stones == before.stones and after.upgrades.goldenroot and #after.pets == #before.pets and after.albumCount == before.albumCount
	and after.shinyScore == before.shinyScore and after.zones == before.zones, "la partida no se cargó bien")
assert(real3:FindFirstChild("PlayerGui"):FindFirstChild("MythicHatchlingsUI"), "no se creó la interfaz al volver")
print("  guardar y cargar: OK")

---------------------------------------------------------------------
print("-- Gran momento (Brillante, cría nueva) --")
-- Para forzar Brillante se envuelve Config.rollShiny (tabla compartida con el servidor): las probabilidades
-- reales NO cambian, así que la que se enseña es la de verdad. (math es de solo lectura en Lune.)
local W3, SPS3 = boot({ locale = "es-es" })
W3.saved[KEY] = { coins = 1e6, tutorialDone = true }
local p3, real3b, hrp3 = join(W3, SPS3, 42)
frame(W3)
local gui3 = real3b:FindFirstChild("PlayerGui")
local Config3 = W3.require(W3.wrap(W3.game:GetService("ReplicatedStorage"):FindFirstChild("Config")))
local Lang3 = W3.require(W3.wrap(W3.game:GetService("ReplicatedStorage"):FindFirstChild("Lang")))
local mundo3 = W3.game:GetService("Workspace"):FindFirstChild("Mundo")
local egg3 = mundo3:FindFirstChild("Isla1"):FindFirstChild("Huevo")
hrp3.CFrame = W3.roblox.CFrame.new(egg3.CFrame.Position + W3.roblox.Vector3.new(0, 0, 8))
frame(W3)
local shiny0 = Config3.rollShiny
local function forceShiny(on: boolean)
	Config3.rollShiny = function(_z, _d, _b, _r)
		return on
	end
end
local function rareNotices(): number
	local n = 0
	for _, f in W3.fired do
		if f[1] == "Notify" and f[2] == "all" and f[3] == "rare" and f[4] == "n_shiny_hatch" then
			assert(f[5].uid == 42 and f[5].rarity ~= nil and f[5].pet ~= nil and f[5].name ~= nil, "aviso de Brillante sin datos")
			n += 1
		end
	end
	return n
end
-- 0) Cría NUEVA al fusionar en el altar (5 Comunes normales → Poco común): momento mediano «¡NUEVA CRÍA!»
forceShiny(false)
for _ = 1, 4 do
	assert(W3.callbacks.Action(p3, "hatch", 1, 1, false), "no abre el huevo")
	frame(W3)
end
local eggSpot = hrp3.CFrame
hrp3.CFrame = W3.roblox.CFrame.new(mundo3:FindFirstChild("Aparicion").CFrame.Position + W3.roblox.Vector3.new(0, 3, 0))
frame(W3)
pressNamed(W3, gui3, "Menu_pets")
pressNamed(W3, gui3, "FusionarTodo")
frame(W3)
assert(lastState(W3).album.cloverchick, "«Fusionar todo» no dio la Poco común")
assert(named(gui3, "MomentoRaro").Visible and named(gui3, "MomentoRaro").Text == Lang3.t("es", "rare_new"), "una cría nueva no da el momento mediano")
assert(named(gui3, "ProbabilidadRara") == nil, "el momento mediano no lleva línea de probabilidad")
if DUMP then
	volcar(gui3, DUMP .. "/02d_fusion_nueva.json")
end
for _ = 1, 5 do
	frame(W3)
end
hrp3.CFrame = eggSpot
frame(W3)
-- 1) Brillante con el botón: ventana grande, título, probabilidad real, un aviso al servidor y no para uno mismo
forceShiny(true)
pressNamed(W3, gui3, "AbrirHuevo")
frame(W3) -- el huevo tiembla 1,2 s
local pets3 = lastState(W3).pets
assert(pets3[#pets3].shiny == true and lastState(W3).shinyIndex.sproutchick, "no salió la Brillante forzada")
assert(lastState(W3).shinyScore == 1, "la Brillante Común no suma 1 a la puntuación")
assert(named(gui3, "Apertura").Visible, "no sale la ventana de apertura")
local titulo = named(gui3, "MomentoRaro")
assert(titulo and titulo.Visible and titulo.Text == Lang3.t("es", "rare_big_shiny"), "no sale el título «¡¡BRILLANTE!!»")
local prob = named(gui3, "ProbabilidadRara")
assert(prob and prob.Visible and prob.Text == Lang3.t("es", "rare_odds", { pct = "1" }), "probabilidad mal: " .. tostring(prob and prob.Text))
assert(named(gui3, "Destello") and named(gui3, "Destello").Visible, "no sale el destello")
assert(rareNotices() == 1, "tiene que haber UN aviso al servidor")
assert(not hasText(gui3, Lang3.t("es", "n_shiny_hatch", { name = "Bot42", pet = Lang3.t("es", "pet_sproutchick") })), "quien la saca no debe ver su propio aviso")
if DUMP then
	volcar(gui3, DUMP .. "/02b_apertura_brillante.json")
end
-- 2) Otra Brillante 1 s después: su ventana sí, pero NO otro aviso (enfriamiento de 10 s); probabilidad del servidor = la del huevo
frame(W3)
local okH, _k, ph = W3.callbacks.Action(p3, "hatch", 1, 1, false)
assert(okH and ph.hatched[1].shiny and ph.hatched[1].chance == Config3.eggOdds(1, {}, {}).shinyPct, "la probabilidad del servidor no es la del huevo")
assert(rareNotices() == 1, "aviso antes de que pasen 10 s")
-- 3) x3 pasados 10 s: UN solo aviso por apertura
Config3.GamePasses[3].id = 777 -- hatch3: se «compra» durante la partida
W3.MarketplaceService.PromptGamePassPurchaseFinished:Fire(p3, 777, true)
Config3.GamePasses[3].id = 0
for _ = 1, 11 do
	frame(W3)
end
okH, _k, ph = W3.callbacks.Action(p3, "hatch", 1, 3, false)
assert(okH and #ph.hatched == 3, "x3 no abre 3")
assert(rareNotices() == 2, "x3 debe dar exactamente un aviso (hay " .. rareNotices() .. ")")
frame(W3)
okH = W3.callbacks.Action(p3, "hatch", 1, 3, false)
assert(okH and rareNotices() == 2, "otro x3 al segundo no debe avisar")
for _ = 1, 11 do
	frame(W3)
end
-- 4) Repetida normal: ni aviso ni título
forceShiny(false)
press(W3, named(gui3, "AbrirHuevo"))
frame(W3)
assert(rareNotices() == 2 and not named(gui3, "MomentoRaro").Visible, "una repetida normal no debe dar momento ni aviso")
Config3.rollShiny = shiny0
-- 5) Fusión de las Brillantes (8 Comunes ✨ → 1 Poco común ✨): momento grande, sin línea de probabilidad (no es al azar)
for _ = 1, 6 do
	frame(W3)
end
hrp3.CFrame = W3.roblox.CFrame.new(mundo3:FindFirstChild("Aparicion").CFrame.Position + W3.roblox.Vector3.new(0, 3, 0))
frame(W3)
pressNamed(W3, gui3, "Menu_pets")
pressNamed(W3, gui3, "FusionarTodo")
frame(W3)
assert(lastState(W3).shinyIndex.cloverchick, "«Fusionar todo» no fusionó las Brillantes en una Brillante")
assert(named(gui3, "MomentoRaro").Visible and named(gui3, "MomentoRaro").Text == Lang3.t("es", "rare_big_shiny"), "fusionar Brillantes no da el momento grande")
assert(named(gui3, "ProbabilidadRara") == nil, "una fusión no lleva línea de probabilidad")
pressNamed(W3, gui3, "Cerrar")
-- 6) Aviso de OTRO jugador: toast con su nombre y la cría traducida
for _ = 1, 6 do
	frame(W3)
end
local notifyInst = W3.game:GetService("ReplicatedStorage"):FindFirstChild("MythicHatchlingsRemotes"):FindFirstChild("Notify")
W3.signalFor(W3.idOf(notifyInst), "OnClientEvent"):Fire("rare", "n_shiny_hatch", { uid = 999, name = "Ana", pet = "dawneagle", rarity = "ascended" })
assert(hasText(gui3, Lang3.t("es", "n_shiny_hatch", { name = "Ana", pet = Lang3.t("es", "pet_dawneagle") })), "no sale el aviso de otro jugador")
if DUMP then
	volcar(gui3, DUMP .. "/02c_aviso_raro.json")
end
print("  gran momento (cría nueva al fusionar, Brillante, enfriamiento 10 s, x3, repetida, fusión Brillante, aviso de otro): OK")

-- Montón Dorado con 2 jugadores (A en la isla 1, B con la isla 2): uno en la isla más alta de cada uno,
-- solo lo pica quien tiene la isla y el premio se reparte según el daño
W3.saved["MythicHatchlings_v2/player_43"] = { zones = 2, tutorialDone = true }
local pB = W3.addPlayer(43, "Bot43")
local spawn3 = mundo3:FindFirstChild("Aparicion").CFrame.Position
local hrpB = makeCharacter(W3, pB, spawn3 + W3.roblox.Vector3.new(0, 3, 0))
W3.Players.PlayerAdded:Fire(pB)
frame(W3)
assert(lastStateOf(W3, pB) and lastStateOf(W3, pB).zones == 2, "el 2.º jugador no cargó su partida")
W3.callbacks.Action(p3, "setAuto", false)
W3.callbacks.Action(pB, "setAuto", false)
frame(W3)
local fired3 = #W3.fired
Config3.GOLD_INTERVAL = 1
frame(W3)
Config3.GOLD_INTERVAL = 1e9
local gByZone = {}
for _, p in golds(W3) do
	gByZone[p:GetAttribute("Zone")] = p
end
assert(#golds(W3) == 2 and gByZone[1] and gByZone[2], "con jugadores en las islas 1 y 2 tiene que haber un dorado en cada una")
assert(#noticesTo(W3, p3, fired3, "gold", "n_gold_pile") == 1 and #noticesTo(W3, p3, fired3, "gold", "n_gold_pile_locked") == 1,
	"A debe saber que hay un dorado en una isla que no tiene")
assert(#noticesTo(W3, pB, fired3, "gold", "n_gold_pile") == 1, "B recibe un solo aviso (el dorado más alto al que llega)")
assert(hasText(gui3, Lang3.t("es", "n_gold_pile_locked", { zone = Lang3.t("es", "zone_mushroom") })), "no sale el aviso de isla cerrada")
-- A no tiene la isla 2: ni con la acción ni tocándolo
local g2 = gByZone[2]
hrp3.CFrame = W3.roblox.CFrame.new(g2.CFrame.Position + W3.roblox.Vector3.new(0, 0, 10))
assert(not W3.callbacks.Action(p3, "target", g2:GetAttribute("PileId")), "A puede picar el dorado de una isla que no ha abierto")
W3.signalFor(W3.idOf(g2:FindFirstChildOfClass("ClickDetector")), "MouseClick"):Fire(p3)
assert(W3.realOf[p3]:GetAttribute("Target") ~= g2:GetAttribute("PileId"), "tocar un dorado de isla cerrada manda a las crías")
frame(W3)
assert(g2:GetAttribute("Hp") == g2:GetAttribute("MaxHp"), "el dorado de la isla 2 ha recibido daño de A")
-- Reparto: B pega primero (poder 3) y luego A termina
local g1 = gByZone[1]
hrp3.CFrame = W3.roblox.CFrame.new(g1.CFrame.Position + W3.roblox.Vector3.new(0, 500, 0))
hrpB.CFrame = W3.roblox.CFrame.new(g1.CFrame.Position + W3.roblox.Vector3.new(0, 0, -10))
assert(W3.callbacks.Action(pB, "target", g1:GetAttribute("PileId")), "B no puede picar el dorado de la isla 1")
frame(W3)
assert(g1:GetAttribute("Hp") < g1:GetAttribute("MaxHp"), "B no le hace daño")
hrp3.CFrame = W3.roblox.CFrame.new(g1.CFrame.Position + W3.roblox.Vector3.new(0, 0, 10))
assert(W3.callbacks.Action(p3, "target", g1:GetAttribute("PileId")), "A no puede picar el dorado de su isla")
local fired4 = #W3.fired
for _ = 1, 10 do
	if not g1.Parent then
		break
	end
	frame(W3)
end
assert(g1.Parent == nil, "el dorado de la isla 1 no se rompe")
local pagoA, pagoB = noticesTo(W3, p3, fired4, "coins", "n_coins"), noticesTo(W3, pB, fired4, "coins", "n_coins")
assert(#pagoA == 1 and #pagoB == 1, "el premio tiene que llegar a los dos")
local base = pagoA[1].value / lastStateOf(W3, p3).coinMult + pagoB[1].value / lastStateOf(W3, pB).coinMult
assert(math.abs(base - Config3.GOLD_COINS * Config3.Zones[1].pileCoins) < 0.01, string.format("el reparto no suma el premio: %.2f", base))
assert(pagoB[1].value < pagoA[1].value, "quien hace menos daño debe llevarse menos")
print(string.format("  montón dorado con 2 jugadores (isla cerrada, reparto %.0f / %.0f): OK", pagoA[1].value, pagoB[1].value))

-- Isla 9 por puntuación Brillante: con 199 no, con 200 sí (Brillantes distintas descubiertas; no cuesta monedas)
do
	local function shinyTo(score: number): { [string]: boolean }
		local idx, total = {}, 0
		local list = table.clone(Config3.Pets)
		table.sort(list, function(a, b)
			return a.rarity > b.rarity
		end)
		for _, p in list do
			local pts = Config3.Rarities[p.rarity].shinyPoints
			if total + pts <= score then
				idx[p.id] = true
				total += pts
			end
		end
		assert(total == score, "no puedo montar " .. score .. " de puntuación")
		return idx
	end
	W3.saved["MythicHatchlings_v2/player_44"] = { zones = 8, tutorialDone = true, shinyIndex = shinyTo(199) }
	W3.saved["MythicHatchlings_v2/player_45"] = { zones = 8, tutorialDone = true, shinyIndex = shinyTo(200) }
	local p44 = W3.addPlayer(44, "Bot44")
	makeCharacter(W3, p44, mundo3:FindFirstChild("Aparicion").CFrame.Position)
	W3.Players.PlayerAdded:Fire(p44)
	local p45 = W3.addPlayer(45, "Bot45")
	makeCharacter(W3, p45, mundo3:FindFirstChild("Aparicion").CFrame.Position)
	W3.Players.PlayerAdded:Fire(p45)
	frame(W3)
	assert(lastStateOf(W3, p44).shinyScore == 199 and lastStateOf(W3, p44).nextZone.kind == "shiny", "el estado no trae la puntuación Brillante")
	local ok9, key9 = W3.callbacks.Action(p44, "unlockZone", 9)
	assert(not ok9 and key9 == "n_need_shiny" and lastStateOf(W3, p44).zones == 8, "la isla 9 se abre con 199 de puntuación Brillante")
	assert(W3.callbacks.Action(p45, "unlockZone", 9) and lastStateOf(W3, p45).zones == 9, "la isla 9 no se abre con 200")
	assert(W3.callbacks.Action(p45, "teleport", 9), "no se puede viajar a la isla 9")
	-- Mejoras con piedras de sobra: huecos, mochila, velocidad al andar y huevo más barato
	W3.saved["MythicHatchlings_v2/player_46"] = { stones = 500, tutorialDone = true }
	local p46 = W3.addPlayer(46, "Bot46")
	local hrp46 = makeCharacter(W3, p46, mundo3:FindFirstChild("Aparicion").CFrame.Position)
	W3.Players.PlayerAdded:Fire(p46)
	frame(W3)
	local hum46 = hrp46.Parent:FindFirstChildOfClass("Humanoid")
	local s46 = lastStateOf(W3, p46)
	assert(hum46.WalkSpeed == 16 and s46.walkSpeed == 16, "velocidad al andar inicial mal")
	local okP, keyP = W3.callbacks.Action(p46, "buyUpgrade", "goldenroot")
	assert(not okP and keyP == "n_go_pedestal", "con pedestales se compra desde lejos")
	-- Lejos, el ProximityPrompt tampoco compra (el servidor mira la distancia)
	local pp1 = pedestalOf(mundo3, "goldenroot"):FindFirstChildOfClass("ProximityPrompt")
	W3.signalFor(W3.idOf(pp1), "Triggered"):Fire(p46)
	assert(not lastStateOf(W3, p46).upgrades.goldenroot, "el prompt compra desde lejos")
	-- Junto a cada pedestal, mantener pulsado su prompt la compra
	for _, id in { "goldenroot", "swiftsprout", "buddybranch1", "thriftynest", "leafpouch", "dewyhands", "mightysap" } do
		W3.tick(1) -- límite de 10 acciones/s
		local pd = pedestalOf(mundo3, id)
		hrp46.CFrame = W3.roblox.CFrame.new(pd.CFrame.Position + W3.roblox.Vector3.new(0, 1.5, 6))
		W3.signalFor(W3.idOf(pd:FindFirstChildOfClass("ProximityPrompt")), "Triggered"):Fire(p46)
		assert(lastStateOf(W3, p46).upgrades[id], "el prompt del pedestal no compra " .. id)
	end
	frame(W3)
	s46 = lastStateOf(W3, p46)
	assert(s46.slots == 4 and s46.backpack == 100 and s46.walkSpeed == 20 and hum46.WalkSpeed == 20, "las mejoras no suben huecos/mochila/velocidad")
	assert(math.abs(s46.hatchCooldown - 0.7) < 1e-9 and Config3.eggCost(1, s46) == 40, "las mejoras no abaratan ni aceleran los huevos")
	assert(s46.stones == 500 - (1 + 3 + 8 + 5 + 10 + 15 + 20), "las piedras gastadas no cuadran")
	print("  isla 9 (199 no, 200 sí), mejoras por ProximityPrompt (lejos no, cerca sí): huecos 4, mochila 100, andar 20, huevo −20 %, abrir 0,7 s: OK")
end

---------------------------------------------------------------------
print("-- Studio sin publicar (sin DataStore) --")
local W2, SPS2 = boot({ datastoreInitFails = true, locale = "en-us" })
local _p4, real4 = join(W2, SPS2, 7)
frame(W2)
local s4 = lastState(W2)
assert(s4 and s4.canSave == false, "sin DataStore el servidor debería jugar sin guardar")
local gui4 = real4:FindFirstChild("PlayerGui")
assert(hasText(gui4, "Shop"), "en inglés no sale «Shop»")
dump(W2, gui4, "20_ingles")
local notify2 = W2.game:GetService("ReplicatedStorage"):FindFirstChild("MythicHatchlingsRemotes"):FindFirstChild("Notify")
W2.signalFor(W2.idOf(notify2), "OnClientEvent"):Fire("rare", "n_mythic_made", { uid = 999, name = "Ana", pet = "meadowskylord", rarity = "mythic" })
assert(hasText(gui4, "Ana made a Mythic pet: Meadow Skylord!"), "el aviso de Mítica no sale en inglés")
local Config2 = W2.require(W2.wrap(W2.game:GetService("ReplicatedStorage"):FindFirstChild("Config")))
Config2.GOLD_INTERVAL = 1
frame(W2)
Config2.GOLD_INTERVAL = 1e9
assert(hasText(gui4, "Golden Crystal on Sprout Meadow! Break it within 60 s"), "el aviso del Cristal Dorado no sale en inglés")
print("  juega sin guardar y en inglés: OK")

---------------------------------------------------------------------
print("-- Con modelos 3D en ReplicatedStorage.Modelos (falsos: piezas con los mismos nombres) --")
do
	local W5 = M.new(PLACE, { width = WIDTH, height = HEIGHT, locale = "es-es" })
	local R = W5.roblox
	local folder = R.Instance.new("Model")
	folder.Name = "Modelos"
	local aliases = { "Cristal1", "Cristal2", "CristalGrande", "PiedraA", "PiedraB", "PiedraC", "PiedraAlta", "PiedraAltaB", "RocaMusgo", "Roble", "Arbol", "ArbolDetallado", "ArbolGordo",
		"ArbolCono", "Pino", "PinoRedondo", "Palmera", "PalmeraCurva", "SetaRoja", "SetaAlta", "SetaTan", "CactusAlto", "CactusBajo",
		"Arbusto", "Arbusto2", "Hierba", "FlorRoja", "FlorAmarilla", "FlorMorada", "Tronco", "Tocon", "RocaDeco", "RocaAlta" }
	local animals = { "Chick", "Bird", "Eagle", "RedFox", "Cat", "Wolf", "Fish", "Piranha", "Whale", "Llama", "Horse", "Zebra", "Pig", "Cow", "Pug", "Dog", "Sheep" }
	local function mats(alias: string): { string }
		if string.sub(alias, 1, 7) == "Cristal" then
			return { "crystal", "crystal" }
		elseif alias == "Huevo" then
			return { "eggShell", "eggSpots" }
		elseif table.find(animals, alias) then
			return { "Eyes", "Body" } -- el cuerpo es la pieza más grande (i = 2)
		end
		return { "stone", "leafsGreen" }
	end
	local all = table.clone(aliases)
	for _, a in animals do
		table.insert(all, a)
	end
	table.insert(all, "Huevo")
	for _, alias in all do
		local mm = R.Instance.new("Model")
		mm.Name = alias
		for i, mat in mats(alias) do
			local p = R.Instance.new("Part")
			p.Name = alias .. "__" .. mat
			p.Size = R.Vector3.new(2, 1 + i, 2)
			p.CFrame = R.CFrame.new(100 + i, (1 + i) / 2, 50)
			p.Parent = mm
		end
		mm.Parent = folder
	end
	folder.Parent = W5.game:GetService("ReplicatedStorage") -- donde dice modelos/LEEME.md (los clientes dibujan las crías)
	W5.runScript(W5.game:GetService("ServerScriptService"):FindFirstChild("Main"))
	local mundo5 = W5.game:GetService("Workspace"):FindFirstChild("Mundo")
	local piles5 = mundo5:FindFirstChild("Montones"):GetChildren()
	assert(#piles5 == Config.PILES_PER_ZONE * #Config.Zones, "con modelos faltan cristales")
	for _, p in piles5 do
		assert(p.Transparency == 1 and p:FindFirstChildOfClass("Model"), "el cristal con modelo debe ser una caja invisible con el modelo dentro")
		assert(p:FindFirstChildOfClass("ClickDetector"), "el cristal con modelo no se puede tocar")
		assert(type(p:GetAttribute("Radius")) == "number", "el cristal no dice a qué distancia lo rodean las crías")
	end
	-- Con modelos también: color de la paleta de su isla y el grande más alto que el pequeño
	local col5, hi5 = {}, { coins = 0, crystal = 0 }
	local lo5 = { coins = math.huge, crystal = math.huge }
	for _, p in piles5 do
		local zi = p:GetAttribute("Zone")
		local kind = p:GetAttribute("Kind")
		local cp = p:FindFirstChildOfClass("Model"):FindFirstChildWhichIsA("BasePart", true)
		if zi == 2 and p:GetAttribute("Gold") ~= true then
			assert(cp and nearPalette(cp.Color, Config.Zones[2].crystalColors), "con modelos, un cristal de la isla 2 no es de su paleta")
			col5[string.format("%.2f,%.2f,%.2f", cp.Color.R, cp.Color.G, cp.Color.B)] = true
		end
		if kind == "coins" or kind == "crystal" then
			hi5[kind] = math.max(hi5[kind], p.Size.Y)
			lo5[kind] = math.min(lo5[kind], p.Size.Y)
		end
	end
	local n5 = 0
	for _ in col5 do
		n5 += 1
	end
	assert(n5 >= 3, "con modelos, los cristales de la isla 2 son casi todos del mismo color")
	assert(lo5.crystal > hi5.coins, "con modelos, el cristal grande no es más alto que el pequeño")
	local placed = 0
	for _, d in mundo5:FindFirstChild("Isla1"):GetChildren() do
		if d:IsA("Model") and table.find(aliases, d.Name) then
			placed += 1
		end
	end
	assert(placed >= 10, "con modelos casi no se coloca decoración (" .. placed .. ")")
	-- Escala y color: un árbol mide lo que se pidió y está pintado por material
	local tree = nil
	for _, d in mundo5:FindFirstChild("Isla1"):GetChildren() do
		if d:IsA("Model") and (d.Name == "Roble" or d.Name == "Arbol") then
			tree = d
		end
	end
	assert(tree, "no hay árboles con modelo en la pradera")
	local leaf = tree:FindFirstChild(tree.Name .. "__leafsGreen")
	assert(leaf and leaf.Size.Y > 5, "el árbol no se ha escalado")
	local _p5, real5, hrp5 = join(W5, SPS, 99)
	for _ = 1, 60 do
		frame(W5)
	end
	assert(lastState(W5).coins > 0, "con modelos las crías no rompen cristales")
	-- Huevo con el modelo del pack pintado por rareza (caja invisible con el modelo dentro)
	local egg5 = mundo5:FindFirstChild("Isla3"):FindFirstChild("Huevo")
	local shell5 = egg5:FindFirstChild("Huevo", true) and egg5:FindFirstChild("Huevo"):FindFirstChild("Huevo__eggShell")
	assert(egg5.Transparency == 1 and shell5, "con modelos el huevo no usa el modelo «Huevo»")
	local e3 = Config.EggColors[2].shell
	assert(math.abs(shell5.Color.R - e3.R) + math.abs(shell5.Color.G - e3.G) + math.abs(shell5.Color.B - e3.B) < 0.02, "el huevo con modelo no tiene el color de su rareza")
	-- Crías con el animal del pack: ancla + piezas «Chick__…», la grande del color de la cría, que se mueven con ella
	local cria = nil
	for _, d in W5.game:GetService("Workspace"):FindFirstChild("CriasLocales"):GetChildren() do
		if d.Name == "Cria" and d:FindFirstChild("Chick__Body") then
			cria = d
		end
	end
	assert(cria, "con modelos la cría no es el animal del pack")
	local body5 = cria:FindFirstChild("Chick__Body")
	local want = Config.PetById.sproutchick.color
	assert(math.abs(body5.Color.R - want.R) + math.abs(body5.Color.G - want.G) + math.abs(body5.Color.B - want.B) < 0.02, "la cría no está pintada con su color")
	assert(body5.Anchored and not body5.CanCollide, "las piezas de la cría deben ir ancladas y sin colisión")
	local p0 = body5.CFrame.Position
	hrp5.CFrame = W5.roblox.CFrame.new(hrp5.CFrame.Position + W5.roblox.Vector3.new(30, 0, 0))
	W5.callbacks.Action(W5.player, "setAuto", false)
	for _ = 1, 4 do
		frame(W5)
	end
	assert((body5.CFrame.Position - p0).Magnitude > 5 and cria:FindFirstChild("Chick__Body") == body5, "la cría con modelo no sigue al jugador (o se recrea cada frame)")
	assert(real5:FindFirstChild("PlayerGui"):FindFirstChild("MythicHatchlingsUI"), "con modelos no se crea la interfaz")
	print(string.format("  cristales con modelo (%d), decoración (%d en la pradera), monedas en 60 s: %d: OK", #piles5, placed, math.floor(lastState(W5).coins)))
	local _ = hrp5
end

print("JUEGO OK")
