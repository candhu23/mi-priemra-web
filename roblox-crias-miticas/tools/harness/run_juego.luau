--[[
	Prueba de JUEGO COMPLETO con Lune: servidor real + interfaz real en el mismo proceso.
	Un bot juega a Crías Míticas: sus crías rompen montones (modo Auto y tocando un montón), abre un
	huevo junto al pedestal, fusiona, equipa las mejores, suelta una cría, abre islas (menú y puerta),
	viaja, renace, reclama álbum, misiones y diario, cambia idioma y sonido, salta el tutorial, pulsa
	TODOS los botones, sale (se guarda) y vuelve (se carga). Luego, «Studio sin publicar» (sin DataStore).
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
local KEY = "MythicHatchlings_v1/player_42"

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

local function dump(W: any, gui: any, name: string)
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
dump(W, gui, "00_inicio")

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
for _ = 1, 60 do
	frame(W)
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
assert(gold:GetAttribute("MaxHp") == Config.GOLD_HP * Config.Zones[1].pileHp, "vida del Montón Dorado mal")
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
assert(not W.callbacks.Action(W.player, "hatch", 1, 1, false), "se puede abrir el huevo desde lejos")
hrp.CFrame = W.roblox.CFrame.new(egg.CFrame.Position + W.roblox.Vector3.new(0, 0, 8))
frame(W)
assert(named(gui, "AbrirHuevo") and named(gui, "AbrirHuevo").Parent.Parent.Parent.Visible, "no sale el panel del huevo al lado")
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

-- Salir y volver con una partida avanzada (monedas, 5 crías iguales, álbum y misiones listas)
leave(W)
local saved = W.saved[KEY]
assert(saved and #saved.pets == 2, "no se guardó la partida al salir")
saved.coins = 1e13
for _ = 1, 5 do
	table.insert(saved.pets, { uid = saved.nextUid, kind = "bunbun", tier = 0 })
	saved.nextUid += 1
end
local n = 0
for _, pet in Config.Pets do
	if n < 20 then
		saved.album[Config.albumKey(pet.id, 0)] = true
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

-- Crías: elegir una de las 5 iguales → fusionar; equipar mejores; soltar
pressNamed(W, gui, "Menu_pets")
dump(W, gui, "03_crias")
local bun = nil
for _, p in s.pets do
	if p.kind == "bunbun" then
		bun = p
	end
end
local hit = nil
for _, d in gui:GetDescendants() do
	if d:IsA("TextButton") and d.Text == "" and d.Parent and d.Parent.Parent and d.Parent.Parent:IsA("Frame") then
		-- las tarjetas de cría llevan un botón invisible encima; buscamos la de bunbun por su emoji
		for _, l in d.Parent:GetChildren() do
			if l:IsA("TextLabel") and l.Text == Config.PetById.bunbun.emoji then
				hit = d
			end
		end
	end
end
assert(bun and hit, "no encuentro la tarjeta de la cría para fusionar")
press(W, hit)
frame(W)
dump(W, gui, "04_cria_elegida")
pressNamed(W, gui, "Fusionar")
s = lastState(W)
assert(s.album[Config.albumKey("bunbun", 1)], "la fusión no dio la Dorada")
pressNamed(W, gui, "EquiparMejores")
s = lastState(W)
assert(#s.equipped == math.min(s.slots, #s.pets), "Equipar mejores no llena los huecos")
local before = #s.pets
local loose = s.equipped[#s.equipped]
W.callbacks.Action(W.player, "unequip", loose)
frame(W)
pressNamed(W, gui, "Cria_" .. loose)
pressNamed(W, gui, "Soltar")
assert(#lastState(W).pets == before, "Soltar debe pedir confirmación")
pressNamed(W, gui, "Soltar")
assert(#lastState(W).pets == before - 1, "Soltar no quita la cría")
assert(not W.callbacks.Action(W.player, "fuse", "bunbun", 0), "se puede fusionar sin 5 iguales")
assert(not W.callbacks.Action(W.player, "equip", 99999), "equipar una cría que no existe")
W.callbacks.Action(W.player, "equipBest")
local eqUid = lastState(W).equipped[1]
assert(not W.callbacks.Action(W.player, "release", eqUid), "se puede soltar una cría equipada")
assert(W.callbacks.Action(W.player, "unequip", eqUid), "quitar una cría no funciona")
assert(not table.find(lastState(W).equipped, eqUid), "la cría sigue equipada")
assert(W.callbacks.Action(W.player, "equip", eqUid), "volver a equipar no funciona")
pressNamed(W, gui, "Cerrar")
print("  fusionar, equipar mejores y soltar: OK")

-- Islas: abrir 2, 3 y 4 desde el menú, viajar a la 4
pressNamed(W, gui, "Menu_islands")
for z = 2, 4 do
	pressNamed(W, gui, "AbrirIsla" .. z)
	frame(W)
end
s = lastState(W)
assert(s.zones == 4, "no se abrieron las islas (zones = " .. s.zones .. ")")
dump(W, gui, "05_islas")
pressNamed(W, gui, "Ir4")
local c4 = mundo:FindFirstChild("Isla4"):FindFirstChild("Suelo").CFrame.Position
assert((hrp.CFrame.Position - c4).Magnitude < 60, "Ir a la isla 4 no mueve al jugador")
assert(not W.callbacks.Action(W.player, "teleport", 6), "viajar a una isla cerrada")

-- Puerta de la isla 5: panel al acercarse y abrir
local door = mundo:FindFirstChild("Isla5"):FindFirstChild("Puerta")
hrp.CFrame = W.roblox.CFrame.new(door.CFrame.Position + W.roblox.Vector3.new(-10, -18, 0))
frame(W)
assert(named(gui, "AbrirPuerta").Parent.Parent.Visible, "no sale el panel de la puerta")
dump(W, gui, "06_puerta")
pressNamed(W, gui, "AbrirPuerta")
assert(lastState(W).zones == 5, "la puerta no abre la isla 5")
print("  islas, viaje y puerta: OK")

-- Renacer
local petsBefore = #lastState(W).pets
pressNamed(W, gui, "Menu_rebirth")
dump(W, gui, "07_renacer")
pressNamed(W, gui, "Renacer")
s = lastState(W)
assert(s.rebirths == 1 and s.zones == 1 and s.coins < 1e6, "renacer no reinicia bien")
assert(#s.pets == petsBefore, "renacer no debe quitar crías")
print("  renacer: OK")

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
assert(lastState(W).albumClaimed["1"], "no se reclamó el álbum")
pressNamed(W, gui, "Cerrar")
pressNamed(W, gui, "Menu_missions")
dump(W, gui, "09_misiones")
for i = 1, 3 do
	pressNamed(W, gui, "Mision" .. i)
end
s = lastState(W)
assert(s.missions[3].claimed and s.luckLeft > 0, "las misiones no dan la suerte x2")
pressNamed(W, gui, "Menu_daily")
dump(W, gui, "10_diario")
pressNamed(W, gui, "RecogerDiario")
assert(not lastState(W).daily.available, "el diario no se recogió")
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
assert(saved and saved.rebirths == 1, "no se guardó la partida al salir")
local _p3, real3 = join(W, SPS, 42)
frame(W)
local after = lastState(W)
assert(after.rebirths == before.rebirths and #after.pets == #before.pets and after.albumCount == before.albumCount, "la partida no se cargó bien")
assert(real3:FindFirstChild("PlayerGui"):FindFirstChild("MythicHatchlingsUI"), "no se creó la interfaz al volver")
print("  guardar y cargar: OK")

---------------------------------------------------------------------
print("-- Gran momento (cría rara) --")
-- Para forzar la rareza se envuelve Config.rollPet (tabla compartida con el servidor): las probabilidades
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
local roll0 = Config3.rollPet
local function forceRoll(roll: number)
	Config3.rollPet = function(z, luck, _r)
		return roll0(z, luck, roll)
	end
end
local function rareNotices(): number
	local n = 0
	for _, f in W3.fired do
		if f[1] == "Notify" and f[2] == "all" and f[3] == "rare" and f[4] == "n_rare_hatch" then
			assert(f[5].uid == 42 and f[5].rarity ~= nil and f[5].pet ~= nil and f[5].name ~= nil, "aviso de cría rara sin datos")
			n += 1
		end
	end
	return n
end
local odds1 = Config3.eggOdds(1, false)
-- 1) Legendaria con el botón: ventana grande, título, probabilidad real, un aviso al servidor y no para uno mismo
forceRoll(0.99) -- acumulado hasta Épica = 0,98 → Legendaria
pressNamed(W3, gui3, "AbrirHuevo")
frame(W3) -- el huevo tiembla 1,2 s
local pets3 = lastState(W3).pets
assert(pets3[#pets3].kind == Config3.Zones[1].pets[6].id, "no salió la Legendaria forzada")
assert(named(gui3, "Apertura").Visible, "no sale la ventana de apertura")
local titulo = named(gui3, "MomentoRaro")
assert(titulo and titulo.Visible and titulo.Text == Lang3.t("es", "rare_big_legendary"), "no sale el título «¡¡LEGENDARIA!!»")
local pctLeg = string.gsub(string.format("%.1f", odds1[6]), "%.", ",")
local prob = named(gui3, "ProbabilidadRara")
assert(prob and prob.Visible and prob.Text == Lang3.t("es", "rare_odds", { pct = pctLeg }), "probabilidad mal: " .. tostring(prob and prob.Text))
assert(named(gui3, "Destello") and named(gui3, "Destello").Visible, "no sale el destello")
assert(rareNotices() == 1, "tiene que haber UN aviso al servidor")
assert(not hasText(gui3, Lang3.t("es", "rar_legendary") .. ": "), "quien la saca no debe ver su propio aviso")
if DUMP then
	volcar(gui3, DUMP .. "/02b_apertura_legendaria.json")
end
-- 2) Mítica 1 s después: su ventana sí, pero NO otro aviso (enfriamiento de 10 s)
frame(W3)
forceRoll(0.9999)
local okH, _k, ph = W3.callbacks.Action(p3, "hatch", 1, 1, false)
assert(okH and ph.hatched[1].rarity == 7 and ph.hatched[1].kind == "dawngriffin", "la Mítica no lleva rarity = 7")
assert(ph.hatched[1].chance == odds1[7], "la probabilidad del servidor no es la del huevo")
assert(rareNotices() == 1, "aviso antes de que pasen 10 s")
-- 3) x3 pasados 10 s: UN solo aviso por apertura (la más rara del lote)
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
forceRoll(0.1) -- una Común: nunca avisa
assert(W3.callbacks.Action(p3, "hatch", 1, 1, false) and rareNotices() == 2, "una Común no debe avisar")
frame(W3)
forceRoll(0.9999)
assert(W3.callbacks.Action(p3, "hatch", 1, 1, false) and rareNotices() == 3, "pasados 10 s debe volver a avisar")
-- 4) Épica: momento mediano (título «¡ÉPICA!», sin probabilidad ni destello)
frame(W3)
forceRoll(0.95)
press(W3, named(gui3, "AbrirHuevo"))
frame(W3)
assert(named(gui3, "MomentoRaro").Visible and named(gui3, "MomentoRaro").Text == Lang3.t("es", "rare_mid"), "la Épica no da el momento mediano")
assert(named(gui3, "ProbabilidadRara") == nil, "la Épica no lleva línea de probabilidad")
assert(rareNotices() == 3, "una Épica no avisa al servidor")
Config3.rollPet = roll0
-- 5) Aviso de OTRO jugador: toast con su nombre y la cría traducida
for _ = 1, 6 do
	frame(W3)
end
local notifyInst = W3.game:GetService("ReplicatedStorage"):FindFirstChild("MythicHatchlingsRemotes"):FindFirstChild("Notify")
W3.signalFor(W3.idOf(notifyInst), "OnClientEvent"):Fire("rare", "n_rare_hatch", { uid = 999, name = "Ana", pet = "dawngriffin", rarity = "mythic" })
assert(hasText(gui3, Lang3.t("es", "n_rare_hatch", { name = "Ana", rarity = Lang3.t("es", "rar_mythic"), pet = Lang3.t("es", "pet_dawngriffin") })), "no sale el aviso de otro jugador")
if DUMP then
	volcar(gui3, DUMP .. "/02c_aviso_raro.json")
end
print("  gran momento (Legendaria, Mítica, x3, enfriamiento 10 s, Épica, aviso de otro): OK")

-- Montón Dorado con 2 jugadores (A en la isla 1, B con la isla 2): uno en la isla más alta de cada uno,
-- solo lo pica quien tiene la isla y el premio se reparte según el daño
W3.saved["MythicHatchlings_v1/player_43"] = { zones = 2, tutorialDone = true }
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
assert(#noticesTo(W3, pB, fired3, "gold", "n_gold_pile") == 2, "B puede llegar a los dos dorados")
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
W2.signalFor(W2.idOf(notify2), "OnClientEvent"):Fire("rare", "n_rare_hatch", { uid = 999, name = "Ana", pet = "dawngriffin", rarity = "mythic" })
assert(hasText(gui4, "Ana hatched a Mythic pet: Dawn Griffin!"), "el aviso de cría rara no sale en inglés")
local Config2 = W2.require(W2.wrap(W2.game:GetService("ReplicatedStorage"):FindFirstChild("Config")))
Config2.GOLD_INTERVAL = 1
frame(W2)
Config2.GOLD_INTERVAL = 1e9
assert(hasText(gui4, "Golden Pile on Sprout Meadow! Break it within 60 s"), "el aviso del Montón Dorado no sale en inglés")
print("  juega sin guardar y en inglés: OK")

print("JUEGO OK")
