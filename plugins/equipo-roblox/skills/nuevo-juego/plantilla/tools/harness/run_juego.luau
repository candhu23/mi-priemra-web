--[[
	Prueba de JUEGO COMPLETO con Lune: servidor real + interfaz real en el mismo proceso.
	Un bot juega (toca, compra, mejora, recoge el diario), abre las ventanas, pulsa TODOS los botones,
	sale (se guarda) y vuelve a entrar (se carga). Luego, el caso «Studio sin publicar» (sin DataStore).
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

local function boot(opts: { [string]: any }?)
	local o = opts or {}
	o.width, o.height = WIDTH, HEIGHT
	local W = M.new(PLACE, o)
	local SSS = W.game:GetService("ServerScriptService")
	local SPS = W.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	W.runScript(SSS:FindFirstChild("Main"))
	return W, SPS
end

local function join(W: any, SPS: any, userId: number)
	local player, real = W.addPlayer(userId, "Bot" .. userId)
	W.player = player
	W.Players.LocalPlayer = player
	W.Players.PlayerAdded:Fire(player)
	local ps = real:FindFirstChild("PlayerScripts")
	for _, child in SPS:GetChildren() do
		child:Clone().Parent = ps
	end
	W.runScript(ps:FindFirstChild("Client"))
	return player, real
end

local function frame(W: any)
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

local function findButton(gui: any, text: string): any
	for _, b in buttons(gui) do
		if string.find(b.Text, text, 1, true) then
			return b
		end
	end
	return nil
end

local function dump(W: any, gui: any, name: string)
	if DUMP then
		for _ = 1, 4 do -- que se vayan los avisos (duran 3 s)
			frame(W)
		end
		volcar(gui, DUMP .. "/" .. name .. ".json")
	end
end

---------------------------------------------------------------------
print("-- Partida normal --")
local W, SPS = boot({ locale = "es-es" })
local _player, real = join(W, SPS, 42)
frame(W)
local gui = real:FindFirstChild("PlayerGui")
assert(lastState(W), "el servidor no mandó el estado")
dump(W, gui, "00_inicio")

-- Tocar (respetando el límite de 15/s) hasta poder comprar
local tap = findButton(gui, "💵")
assert(tap, "no encuentro el botón TOCA")
for i = 1, 60 do
	press(W, tap)
	if i % 10 == 0 then
		frame(W)
	end
end
frame(W)
local s = lastState(W)
assert(s.money > 0, "tocar no da dinero")
print(string.format("  tras 60 toques: %s", tostring(s.money)))

-- Comprar el primer negocio y mejorar el clic
local Config = W.require(W.wrap(W.game:GetService("ReplicatedStorage"):FindFirstChild("Config")))
local firstCost = Config.genCost(Config.Generators[1].id, 0)
for _ = 1, 30 do
	if lastState(W).money >= firstCost then
		break
	end
	for _ = 1, 10 do
		press(W, tap)
	end
	frame(W)
end
local buy = findButton(gui, "$" .. firstCost)
assert(buy, "no encuentro el botón de comprar a $" .. firstCost)
press(W, buy)
frame(W)
s = lastState(W)
assert(s.generators[Config.Generators[1].id] == 1, "la compra no se hizo")
assert(s.incomePerSec > 0, "el negocio no da ingresos")
for _ = 1, 30 do
	frame(W)
end
dump(W, gui, "01_jugando")

-- Diario y ventanas
local daily = findButton(gui, "🎁")
assert(daily, "no encuentro el botón Diario")
press(W, daily)
frame(W)
dump(W, gui, "02_diario")
local claim = findButton(gui, "Recoger")
assert(claim, "no encuentro Recoger")
press(W, claim)
frame(W)
assert(not lastState(W).daily.available, "el diario no se recogió")
press(W, assert(findButton(gui, "🛒"), "no encuentro Tienda"))
frame(W)
dump(W, gui, "03_tienda")

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
local before = lastState(W)
W.Players.PlayerRemoving:Fire(W.player)
local saved = W.saved["{{PREFIJO}}_v1/player_42"]
assert(saved and saved.generators[Config.Generators[1].id] >= 1, "no se guardó la partida al salir")
W.player = nil
local _p2, real2 = join(W, SPS, 42)
frame(W)
local after = lastState(W)
assert(after.generators[Config.Generators[1].id] == before.generators[Config.Generators[1].id], "la partida no se cargó bien")
print("  guardar y cargar: OK")
assert(real2:FindFirstChild("PlayerGui"):FindFirstChild("{{PREFIJO}}UI"), "no se creó la interfaz al volver")

---------------------------------------------------------------------
print("-- Studio sin publicar (sin DataStore) --")
local W2, SPS2 = boot({ datastoreInitFails = true, locale = "en-us" })
local _p3, real3 = join(W2, SPS2, 7)
frame(W2)
local s3 = lastState(W2)
assert(s3 and s3.canSave == false, "sin DataStore el servidor debería jugar sin guardar")
local gui3 = real3:FindFirstChild("PlayerGui")
assert(findButton(gui3, "Shop"), "en inglés no sale «Shop»")
dump(W2, gui3, "10_ingles")
print("  juega sin guardar y en inglés: OK")

print("JUEGO OK")
