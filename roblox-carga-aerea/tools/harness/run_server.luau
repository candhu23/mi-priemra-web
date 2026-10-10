--[[
	Prueba del SERVIDOR real con un jugador falso que juega solo (sin interfaz).
	Uso: lune run run_server.luau <test.rbxl> [sin-datastore]
	- normal: tutorial, errores, partida rápida con ritmo medido, salida/entrada con ganancias
	  offline, compras con Robux simuladas, todo desbloqueado y despacho automático.
	- sin-datastore: GetDataStore da error (como en Studio sin publicar). El juego debe funcionar igual.
	Termina con «TODO OK» o «SIN DATASTORE OK»; cualquier fallo lanza un error.
]]

local M = require("./mock")
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local MODE = process.args[2] or "normal"
local W = M.new(process.args[1], { datastoreInitFails = MODE == "sin-datastore" })
local RS = W.game:GetService("ReplicatedStorage")
local SSS = W.game:GetService("ServerScriptService")
local Config = W.require(W.wrap(RS:FindFirstChild("Config")))
local Lang = W.require(W.wrap(RS:FindFirstChild("Lang")))

-- IDs de prueba para la tienda (antes de que el servidor cargue Shop)
if MODE == "normal" then
	for i, p in Config.Products do
		p.id = 1000 + i
	end
end

W.runScript(SSS:FindFirstChild("GameServer"))
local player = W.addPlayer(42, "Jorge")
W.player = player
W.Players.PlayerAdded:Fire(player)
local invoke = assert(W.callbacks.Action, "el servidor no creó la acción")

local function lastState()
	for i = #W.fired, 1, -1 do
		local f = W.fired[i]
		if f[1] == "State" and f[2] == player then
			return f[3]
		end
	end
	error("no ha llegado ningún estado")
end
local seenNotes = 0
local function newNotes()
	local out = {}
	for i = seenNotes + 1, #W.fired do
		local f = W.fired[i]
		if f[1] == "Notify" then
			table.insert(out, f[3] .. ": " .. Lang.t("es", f[4], f[5]))
		end
	end
	seenNotes = #W.fired
	return out
end
local function act(name, a, b, c, quiet)
	local ok, key, params, extra = invoke(player, name, a, b, c)
	if not quiet then
		print(string.format("  %-16s -> %-5s %s", name, tostring(ok), key and Lang.t("es", key, params) or ""))
	end
	W.fakeTime += 0.15
	return ok, key, extra
end
local function money(n)
	return "$" .. tostring(math.floor(n))
end

local s = lastState()
assert(s.money == Config.START_MONEY and #s.planes == 1 and s.tutorial == 0, "estado inicial incorrecto")
assert(s.boards.MAD and not s.boards.MAD[1].tutorial, "la carga del tutorial solo sale tras empezarlo")
print("Estado inicial:", money(s.money), "· tutorial", s.tutorial, "· cargas en MAD", #s.boards.MAD, "· guardar:", s.canSave)

if MODE == "sin-datastore" then
	assert(s.canSave == false, "sin DataStore, canSave debería ser false")
	act("tutorial", "start")
	s = lastState()
	assert(s.boards.MAD[1].tutorial, "falta la carga del tutorial en Madrid")
	act("dispatch", s.planes[1].id, s.boards.MAD[1].id, 0)
	W.tick(20)
	s = lastState()
	assert(s.money > Config.START_MONEY, "debería haber cobrado el vuelo")
	for _, n in newNotes() do print("  aviso:", n) end
	W.Players.PlayerRemoving:Fire(player)
	print("SIN DATASTORE OK")
	process.exit(0)
end

---------------------------------------------------------------------
print("-- Tutorial --")
act("tutorial", "start")
s = lastState()
assert(s.boards.MAD[1].tutorial, "falta la carga del tutorial en Madrid")
act("dispatch", s.planes[1].id, s.boards.MAD[2].id, -1) -- piloto inventado
act("dispatch", s.planes[1].id, s.boards.MAD[2].id, 0 / 0) -- NaN
assert(not lastState().planes[1].flight, "no se puede volar con un piloto que no existe")
act("dispatch", s.planes[1].id, s.boards.MAD[1].id, 0)
assert(lastState().tutorial == 2, "tras despachar el tutorial debería ir al paso 2")
act("land", s.planes[1].id, "perfect") -- demasiado pronto
assert(not lastState().planes[1].flight.landing, "aterrizar tan pronto no debería valer")
W.tick(11)
local okLand = act("land", s.planes[1].id, "perfect")
assert(okLand, "el aterrizaje perfecto debería aceptarse en los últimos segundos")
act("land", s.planes[1].id, "perfect") -- solo un intento
W.tick(5)
s = lastState()
assert(s.tutorial == 3 and not s.planes[1].flight, "tras aterrizar debería ir al paso 3")
assert(s.stats.perfect == 1 and s.album.airports.VLC, "debería contar el aterrizaje perfecto y el sello de Valencia")
act("buyPlane", "sparrow")
s = lastState()
assert(s.tutorial == 4, "tras comprar debería ir al paso 4")
local cheap = s.candidates[1]
assert(cheap.stars == 1 and s.money >= cheap.price, "el primer candidato del tutorial debería ser barato")
act("hire", cheap.id)
assert(lastState().tutorial == 5, "tras fichar debería ir al paso 5")
act("claimGoal", "flights_1")
s = lastState()
assert(s.tutorial == 99, "el tutorial debería terminar al reclamar el objetivo")
print("  tutorial completo · dinero", money(s.money), "· aviones", #s.planes, "· pilotos", #s.pilots)
for _, n in newNotes() do print("  aviso:", n) end

---------------------------------------------------------------------
print("-- Errores esperados --")
act("buyPlane", "hawk") -- nivel
act("repair", s.planes[1].id)
act("refreshBoard", s.planes[1].airport)
act("refreshBoard", s.planes[1].airport) -- espera
act("buyRegion", "CAT") -- nivel
act("buyUpgrade", "cold") -- nivel
act("setAuto", true) -- nivel
act("claimGoal", "flights_8") -- sin terminar
act("claimMission", 1) -- sin terminar
act("bogus")
act("dispatch", "x", {}, nil)
for _ = 1, 12 do invoke(player, "setMuted", false) end
act("setMuted", false) -- demasiado rápido
W.fakeTime += 2
act("claimDaily")
act("claimDaily") -- ya reclamado
act("acceptContract", 1) -- nivel
act("charter", s.planes[1].id, "c1") -- nivel
act("goPublic") -- nivel
act("setAirline", { 9, 1, 1 }, 1) -- pieza que no existe
act("setAirline", { 1, 2, 3 }, Config.GOLD_COLOR) -- oro bloqueado
act("setAirline", { 2, 3, 4 }, 5)
assert(lastState().airline.color == 5, "debería cambiar el color de la aerolínea")
act("claimGoals") -- nada que reclamar
act("land", s.planes[1].id, "perfect") -- no está volando

---------------------------------------------------------------------
-- Bot: despacha todo lo que puede con los pilotos libres
local function bestLoad(st, plane)
	local model = Config.PlaneById[plane.model]
	local best, bestValue = nil, -math.huge
	for _, l in st.boards[plane.airport] or {} do
		local good = Config.GoodById[l.good]
		if l.weight <= model.cap and l.dist <= model.range and (not good.cold or st.upgrades.cold > 0) then
			local value = (l.gross - l.dist * model.burn * st.fuelPrice) / Config.flightSeconds(l.dist, model.speed, st.timeMult)
			if l.express then value *= 3 end
			if value > bestValue then
				best, bestValue = l, value
			end
		end
	end
	return best
end
local function dispatchAll()
	local st = lastState()
	local busy = {}
	for _, p in st.planes do
		if p.flight then busy[p.flight.pilot] = true end
	end
	local pilots = { 0 }
	for _, p in st.pilots do table.insert(pilots, p.id) end
	for _, plane in st.planes do
		if not plane.flight then
			if plane.condition < 40 then
				act("repair", plane.id, nil, nil, true)
				st = lastState()
			end
			local load = bestLoad(st, plane)
			local pilot
			for _, id in pilots do
				if not busy[id] then pilot = id break end
			end
			if load and pilot then
				local ok = act("dispatch", plane.id, load.id, pilot, true)
				if ok then busy[pilot] = true end
				st = lastState()
			elseif not load then
				act("refreshBoard", plane.airport, nil, nil, true)
				st = lastState()
			end
		end
	end
end
local function untilLanding()
	local st = lastState()
	local nextT = math.huge
	for _, p in st.planes do
		if p.flight then nextT = math.min(nextT, p.flight.endT) end
	end
	local now = 1_700_000_000 + math.floor(W.fakeTime)
	W.tick(nextT == math.huge and 1 or math.max(1, nextT - now))
end

print("-- Partida rápida (bot) --")
local start = W.fakeTime
local ipoAt = nil
local firstTen = 0
local marks = {}
local function mark(name)
	if not marks[name] then
		marks[name] = true
		local st = lastState()
		print(string.format("  [%5.1f min] %-26s %12s · nv %2d · aviones %2d · pilotos %2d · regiones %d", (W.fakeTime - start) / 60, name, money(st.money), st.level, #st.planes, #st.pilots, (function()
			local n = 0 for _ in st.regions do n += 1 end return n
		end)()))
	end
end
for _ = 1, 3000 do
	dispatchAll()
	untilLanding()
	local st = lastState()
	-- Reclamar todo lo reclamable
	for i, m in st.missions.list do
		if not m.claimed and m.progress >= m.target then act("claimMission", i, nil, nil, true) mark("misión reclamada") end
	end
	-- Objetivos: todos de golpe (el botón «Reclamar todo»)
	local claimable = false
	for _, g in Config.Goals do
		if not st.goals[g.id] then
			local v = g.stat == "planes" and #st.planes or g.stat == "pilots" and #st.pilots or g.stat == "level" and st.level
				or g.stat == "regions" and (function() local n = 0 for _ in st.regions do n += 1 end return n end)()
				or g.stat == "stamps" and st.stamps or g.stat == "ipo" and st.ipoCount or st.stats[g.stat]
			if v >= g.target then claimable = true end
		end
	end
	if claimable then act("claimGoals", nil, nil, nil, true) end
	st = lastState()
	if st.stats.express > 0 then mark("primer exprés") end
	-- Contratos: acepta la primera oferta si hay hueco
	if st.contracts and #st.contracts.offers > 0 and #st.contracts.active < st.contracts.slots and st.level >= Config.CONTRACT_LEVEL then
		act("acceptContract", st.contracts.offers[1].id, nil, nil, true)
		st = lastState()
	end
	if st.stats.contracts > 0 then mark("primer contrato cumplido") end
	if st.event then mark("primer evento: " .. st.event) end
	-- Salir a bolsa en cuanto se pueda (una vez) y medir la segunda partida
	if not ipoAt and st.level >= Config.IPO_LEVEL and st.newShares >= Config.IPO_MIN_SHARES then
		mark("ganado al salir a bolsa: " .. money(st.stats.earned))
		local ok = act("goPublic", nil, nil, nil, true)
		assert(ok, "debería poder salir a bolsa")
		ipoAt = W.fakeTime
		st = lastState()
		assert(st.ipoCount == 1 and st.shares >= Config.IPO_MIN_SHARES and #st.planes == 1 and st.level == 1, "salir a bolsa debería reiniciar la partida")
		assert(st.money == Config.START_MONEY + Config.IPO_START_MONEY, "la ventaja 1 da dinero inicial extra")
		mark("salida a bolsa (+" .. st.shares .. " acciones)")
	end
	-- Compras sencillas por prioridad
	local nextModel
	for _, m in Config.Planes do
		if st.level >= m.level then nextModel = m end
	end
	local cheapest
	for _, c in st.candidates do
		if not cheapest or c.price < cheapest.price then cheapest = c end
	end
	local nextRegion
	for _, r in Config.Regions do
		if not st.regions[r.id] and st.level >= r.level then nextRegion = nextRegion or r end
	end
	if #st.pilots < #st.planes - 1 and cheapest and st.money >= cheapest.price then
		act("hire", cheapest.id, nil, nil, true) mark("piloto fichado")
	elseif nextRegion and st.money >= nextRegion.cost then
		act("buyRegion", nextRegion.id, nil, nil, true) mark("región " .. nextRegion.id)
	elseif #st.planes >= st.maxPlanes and st.money >= Config.upgradeCost("hangar", st.upgrades.hangar) then
		act("buyUpgrade", "hangar", nil, nil, true) mark("hangar ampliado")
	elseif nextModel and #st.planes < st.maxPlanes and st.money >= nextModel.price * 1.1 then
		act("buyPlane", nextModel.id, nil, nil, true) mark("compra " .. nextModel.id)
	end
	for _, lvl in { 2, 3, 5, 7, 10, 12 } do
		if st.level >= lvl then mark((ipoAt and "2ª partida: " or "") .. "nivel " .. lvl) end
	end
	if ipoAt and st.level >= 10 then
		print(string.format("  2ª partida: nivel 10 en %.1f min (la 1ª tardó %.1f min)", (W.fakeTime - ipoAt) / 60, firstTen / 60))
		break
	end
	if st.level >= 10 and firstTen == 0 then firstTen = W.fakeTime - start end
	if W.fakeTime - start > 4 * 3600 then break end
end
assert(ipoAt, "el bot debería haber salido a bolsa en menos de 4 h")
s = lastState()
print(string.format("  tras %.1f min: %s · nivel %d · vuelos %d · exprés %d · contratos %d · sellos %d/%d · perfectos %d",
	(W.fakeTime - start) / 60, money(s.money), s.level, s.stats.flights, s.stats.express, s.stats.contracts, s.stamps, s.stampsMax, s.stats.perfect))
assert(s.stats.contracts > 0, "el bot debería haber cumplido algún contrato")
newNotes()

---------------------------------------------------------------------
print("-- Salir con el piloto automático y un chárter, y volver 2 horas después --")
act("setAuto", true)
W.tick(130) -- para que se mida el ritmo de ganancias
s = lastState()
local charterPlane
for _, p in s.planes do
	if not p.flight and p.condition >= Config.REPAIR_BLOCK then charterPlane = p break end
end
if not charterPlane then
	W.tick(60)
	for _, p in lastState().planes do
		if not p.flight and p.condition >= Config.REPAIR_BLOCK then charterPlane = p break end
	end
end
act("setAuto", false)
W.tick(120)
for _, p in lastState().planes do
	if not p.flight and p.condition >= Config.REPAIR_BLOCK then charterPlane = p break end
end
assert(charterPlane, "debería haber un avión libre para el chárter")
local okCharter = act("charter", charterPlane.id, "c1")
assert(okCharter, "el chárter debería despegar")
act("charter", charterPlane.id, "c4") -- ya está volando
act("setAuto", true)
dispatchAll()
W.Players.PlayerRemoving:Fire(player)
assert(W.saved["AeroCarga_v1/player_42"], "debería haberse guardado")
W.fakeTime += 7200
W.Players.PlayerAdded:Fire(player)
local welcome
for _, n in newNotes() do
	print("  aviso:", n)
	if string.find(n, "^welcome") then welcome = n end
end
assert(welcome, "debería haber aviso de bienvenida con ganancias offline")
for _, p in lastState().planes do assert(not p.flight, "los vuelos deberían haber aterrizado") end
assert(lastState().stats.charters == 1, "el chárter debería haber vuelto")

---------------------------------------------------------------------
print("-- Compras con Robux (simuladas) --")
local MS = W.MarketplaceService
local before = lastState().money
for i, p in Config.Products do
	local r = MS.ProcessReceipt({ PlayerId = 42, ProductId = p.id, PurchaseId = "r" .. i })
	print(string.format("  %-12s -> %s", p.key, tostring(r)))
end
local again = MS.ProcessReceipt({ PlayerId = 42, ProductId = Config.Products[2].id, PurchaseId = "r2" })
local after = lastState()
assert(tostring(again) == tostring(W.roblox.Enum.ProductPurchaseDecision.PurchaseGranted), "el recibo repetido debe darse por concedido")
assert(after.money > before and after.starterBought and after.boostLeft > 0, "las compras deberían notarse")
W.tick(1)
after = lastState()
local cashTwice = MS.ProcessReceipt({ PlayerId = 42, ProductId = Config.Products[2].id, PurchaseId = "r2" })
assert(lastState().money == after.money or tostring(cashTwice) ~= "", "no debe cobrar dos veces")
print("  dinero", money(before), "→", money(after.money), "· pilotos 5★:", (function()
	local n = 0 for _, p in after.pilots do if p.stars == 5 then n += 1 end end return n
end)())

---------------------------------------------------------------------
print("-- Partida avanzada (dinero y XP inyectados) --")
W.Players.PlayerRemoving:Fire(player)
local key = "AeroCarga_v1/player_42"
W.saved[key].money = 5e9
W.saved[key].xp = Config.xpForLevel(20)
W.Players.PlayerAdded:Fire(player)
newNotes()
for _, r in Config.Regions do act("buyRegion", r.id, nil, nil, true) end
for _, u in Config.Upgrades do
	for _ = 1, u.max + 1 do act("buyUpgrade", u.id, nil, nil, true) end
end
W.fakeTime += 2
act("buyUpgrade", "fuel") -- ya al máximo
for _, m in Config.Planes do act("buyPlane", m.id) end
act("searchCandidates")
for _ = 1, 3 do
	local c = lastState().candidates[1]
	if c then act("hire", c.id, nil, nil, true) end
end
s = lastState()
local regions = 0
for _ in s.regions do regions += 1 end
print("  nivel", s.level, "· regiones", regions, "/", #Config.Regions, "· aviones", #s.planes, "/", s.maxPlanes, "· pilotos", #s.pilots)
assert(regions == #Config.Regions, "deberían estar todas las regiones")
for _, p in s.planes do
	if p.model == "albatross" and not p.flight then
		act("ferry", p.id, "TFN")
		break
	end
end
act("ferry", s.planes[1].id, "TFN") -- el Gorrión no llega a Canarias
act("setAuto", true)
W.tick(2)
s = lastState()
local inAir = 0
for _, p in s.planes do if p.flight then inAir += 1 end end
print("  despacho automático: aviones en el aire", inAir, "de", #s.planes)
assert(inAir >= 4, "el despacho automático debería mandar varios aviones")
act("setLang", "en")
act("setLang", "fr")
local ok, _, extra = act("getTop")
assert(ok and extra and extra.top and extra.week, "getTop debería devolver la clasificación de siempre y la semanal")
-- Estado para el harness del juego: mitad en el aire y mitad en tierra
act("setAuto", false)
W.tick(400)
dispatchAll()
W.tick(5)
s = lastState()
fs.writeFile("state.json", serde.encode("json", s))
for _, n in newNotes() do if string.find(n, "feed") then print("  " .. n) end end
print("TODO OK")
process.exit(0)
