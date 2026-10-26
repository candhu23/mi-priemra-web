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
print("-- Studio sin publicar (sin DataStore) --")
local W2, SPS2 = boot({ datastoreInitFails = true, locale = "en-us" })
local _p4, real4 = join(W2, SPS2, 7)
frame(W2)
local s4 = lastState(W2)
assert(s4 and s4.canSave == false, "sin DataStore el servidor debería jugar sin guardar")
local gui4 = real4:FindFirstChild("PlayerGui")
assert(hasText(gui4, "Shop"), "en inglés no sale «Shop»")
dump(W2, gui4, "20_ingles")
print("  juega sin guardar y en inglés: OK")

print("JUEGO OK")
