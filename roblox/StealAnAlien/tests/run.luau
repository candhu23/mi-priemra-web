--[[
	Tests de los módulos que no dependen de Roblox.
	Ejecutar desde roblox/StealAnAlien con el intérprete de Luau:
	    luau tests/run.luau
]]

local Config = require("../src/shared/Config")
local Formato = require("../src/shared/Formato")
local Probabilidades = require("../src/shared/Probabilidades")
local Perfil = require("../src/server/Perfil")

local pasados, fallados = 0, 0

local function test(nombre: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		pasados += 1
	else
		fallados += 1
		print("FALLO: " .. nombre .. "\n    " .. tostring(err))
	end
end

local function igual(a: any, b: any, mensaje: string?)
	if a ~= b then
		error(string.format("%s: esperado %s, obtenido %s", mensaje or "", tostring(b), tostring(a)), 2)
	end
end

local function cerca(a: number, b: number, tolerancia: number, mensaje: string?)
	if math.abs(a - b) > tolerancia then
		error(string.format("%s: esperado %s ± %s, obtenido %s", mensaje or "", tostring(b), tostring(tolerancia), tostring(a)), 2)
	end
end

local function verdad(cond: boolean, mensaje: string)
	if not cond then
		error(mensaje, 2)
	end
end

---------------------------------------------------------------------
-- CONFIG: coherencia de los datos
---------------------------------------------------------------------
test("ids de aliens únicos y válidos", function()
	local vistos = {}
	for _, alien in Config.ALIENS do
		verdad(not vistos[alien.id], "id repetido: " .. alien.id)
		vistos[alien.id] = true
		verdad(Config.RAREZAS[alien.rareza] ~= nil, "rareza inválida en " .. alien.id)
		verdad(alien.precio > 0 and alien.ingreso > 0, "precio/ingreso inválido en " .. alien.id)
		verdad(alien.estilo.ojos >= 1 and alien.estilo.ojos <= 3, "ojos inválidos en " .. alien.id)
		for _, extra in alien.estilo.extras do
			verdad(table.find({ "antenas", "tentaculos", "alas", "corona", "cuernos", "aleta", "pinzas", "halo", "orejas" }, extra) ~= nil, "extra desconocido: " .. extra)
		end
	end
end)

test("cada rareza tiene al menos un alien", function()
	for i, rareza in Config.RAREZAS do
		local hay = false
		for _, alien in Config.ALIENS do
			if alien.rareza == i then
				hay = true
			end
		end
		verdad(hay, "rareza sin aliens: " .. rareza.nombre)
	end
end)

test("los aliens más caros generan más y tardan más en amortizarse", function()
	local anterior = nil
	for _, alien in Config.ALIENS do
		if anterior then
			verdad(alien.precio > anterior.precio, "precio no creciente en " .. alien.id)
			verdad(alien.ingreso > anterior.ingreso, "ingreso no creciente en " .. alien.id)
		end
		local amortizacion = alien.precio / alien.ingreso
		verdad(amortizacion >= 20 and amortizacion <= 300, alien.id .. " se amortiza en " .. amortizacion .. " s")
		anterior = alien
	end
end)

test("se puede comprar el primer alien con el dinero inicial", function()
	verdad(Config.ALIENS[1].precio <= Config.JUEGO.DINERO_INICIAL, "el primer alien es demasiado caro")
end)

test("tienda: claves únicas, tipos válidos", function()
	local vistos = {}
	for _, articulo in Config.TIENDA do
		verdad(not vistos[articulo.clave], "clave repetida " .. articulo.clave)
		vistos[articulo.clave] = true
		verdad(articulo.tipo == "pase" or articulo.tipo == "producto", "tipo inválido " .. articulo.clave)
		verdad(articulo.id >= 0, "id negativo")
	end
	for _, clave in { "PASE_DOBLE_DINERO", "PASE_VIP", "PASE_CANDADO_PLUS", "PRODUCTO_BOOST_X2", "PRODUCTO_SUERTE_SERVIDOR", "PRODUCTO_DINERO_PEQUENO", "PRODUCTO_DINERO_GRANDE" } do
		verdad(Config.articuloPorClave(clave) ~= nil, "falta el artículo " .. clave)
	end
end)

---------------------------------------------------------------------
-- ECONOMÍA
---------------------------------------------------------------------
test("multiplicador de ingresos", function()
	local base = { rebirths = 0, dobleDinero = false, vip = false, amigos = 0, grupo = false, boost = false }
	igual(Config.multiplicadorIngresos(base), 1, "sin bonos")
	base.rebirths = 2
	igual(Config.multiplicadorIngresos(base), 2, "2 rebirths")
	base.dobleDinero = true
	igual(Config.multiplicadorIngresos(base), 4, "2 rebirths + 2x")
	base.boost = true
	igual(Config.multiplicadorIngresos(base), 8, "+ boost")
	local amigos = { rebirths = 0, dobleDinero = false, vip = false, amigos = 20, grupo = true, boost = false }
	cerca(Config.multiplicadorIngresos(amigos), 1 + Config.JUEGO.BONUS_AMIGOS_MAX + Config.JUEGO.BONUS_GRUPO, 1e-9, "tope de amigos + grupo")
end)

test("costes crecientes", function()
	verdad(Config.costeVelocidad(1) > Config.costeVelocidad(0), "velocidad")
	verdad(Config.costeRebirth(1) > Config.costeRebirth(0), "rebirth")
	igual(Config.costeRebirth(0), 1000000, "primer rebirth")
end)

test("pedestales desbloqueados con tope", function()
	igual(Config.slotsDesbloqueados(0), Config.JUEGO.SLOTS_INICIALES)
	igual(Config.slotsDesbloqueados(3), Config.JUEGO.SLOTS_INICIALES + 3)
	igual(Config.slotsDesbloqueados(999), Config.JUEGO.SLOTS_MAXIMOS)
end)

test("shiny: más caro y más ingresos; venta a mitad", function()
	local alien = Config.ALIENS[1]
	igual(Config.ingresoAlien(alien, true), alien.ingreso * Config.SHINY.MULTIPLICADOR_INGRESO)
	verdad(Config.precioAlien(alien, true) > Config.precioAlien(alien, false), "shiny más caro")
	igual(Config.precioVenta(alien, false), math.floor(alien.precio * 0.5))
end)

test("recompensa diaria y ganancias offline", function()
	igual(Config.recompensaDiaria(1, 0), 500)
	igual(Config.recompensaDiaria(7, 0), 3500)
	igual(Config.recompensaDiaria(30, 0), 3500, "tope en el día 7")
	igual(Config.recompensaDiaria(1, 100), 12000, "escala con ingresos")
	igual(Config.gananciaOffline(-50, 10), 0, "tiempo negativo")
	igual(Config.gananciaOffline(100, 10), 250)
	igual(Config.gananciaOffline(10 ^ 9, 1), math.floor(Config.JUEGO.OFFLINE_HORAS_MAX * 3600 * Config.JUEGO.OFFLINE_FRACCION), "tope de horas")
end)

---------------------------------------------------------------------
-- PROBABILIDADES
---------------------------------------------------------------------
local function suma(tabla): number
	local total = 0
	for _, e in tabla do
		total += e.probabilidad
	end
	return total
end

test("las probabilidades suman 100 %", function()
	local mult = Config.EVENTOS.MULTIPLICADOR_SUERTE
	cerca(suma(Probabilidades.porAlien(Config.RAREZAS, Config.ALIENS, false, mult)), 1, 1e-9, "sin suerte")
	cerca(suma(Probabilidades.porAlien(Config.RAREZAS, Config.ALIENS, true, mult)), 1, 1e-9, "con suerte")
end)

test("la suerte sube las rarezas afectadas y baja las demás", function()
	local mult = Config.EVENTOS.MULTIPLICADOR_SUERTE
	local normal = Probabilidades.porRareza(Config.RAREZAS, false, mult)
	local conSuerte = Probabilidades.porRareza(Config.RAREZAS, true, mult)
	for i, rareza in Config.RAREZAS do
		if rareza.afectadaPorSuerte then
			verdad(conSuerte[i] > normal[i], rareza.nombre .. " debería subir")
		else
			verdad(conSuerte[i] < normal[i], rareza.nombre .. " debería bajar")
		end
	end
	cerca(normal[1], 0.6, 1e-9, "Common = 60 %")
end)

test("elegir respeta los extremos", function()
	local mult = Config.EVENTOS.MULTIPLICADOR_SUERTE
	igual(Probabilidades.elegir(Config.RAREZAS, Config.ALIENS, false, mult, 0), Config.ALIENS[1].id, "tirada 0")
	igual(Probabilidades.elegir(Config.RAREZAS, Config.ALIENS, false, mult, 0.9999999999), Config.ALIENS[#Config.ALIENS].id, "tirada ~1")
end)

test("elegir: frecuencias simuladas cercanas a las teóricas", function()
	local mult = Config.EVENTOS.MULTIPLICADOR_SUERTE
	local teoria = Probabilidades.porAlien(Config.RAREZAS, Config.ALIENS, false, mult)
	local conteo = {}
	math.randomseed(42)
	local n = 200000
	for _ = 1, n do
		local id = Probabilidades.elegir(Config.RAREZAS, Config.ALIENS, false, mult, math.random())
		conteo[id] = (conteo[id] or 0) + 1
	end
	for _, e in teoria do
		local observado = (conteo[e.id] or 0) / n
		cerca(observado, e.probabilidad, 0.005, "frecuencia de " .. e.id)
	end
end)

---------------------------------------------------------------------
-- FORMATO
---------------------------------------------------------------------
test("abreviar", function()
	igual(Formato.abreviar(0), "0")
	igual(Formato.abreviar(999), "999")
	igual(Formato.abreviar(1000), "1.0K")
	igual(Formato.abreviar(1999), "1.9K", "trunca, no redondea")
	igual(Formato.abreviar(25000000), "25.0M")
	igual(Formato.abreviar(150000), "150K")
	igual(Formato.abreviar(-1500), "-1.5K")
	igual(Formato.abreviar(0 / 0), "0", "NaN")
end)

test("tiempo y porcentaje", function()
	igual(Formato.tiempo(75), "1:15")
	igual(Formato.tiempo(0), "0:00")
	igual(Formato.tiempo(3725), "1:02:05")
	igual(Formato.porcentaje(0.6), "60.0%")
	igual(Formato.porcentaje(0.05), "5.00%")
	igual(Formato.porcentaje(0.0005), "0.0500%")
end)

---------------------------------------------------------------------
-- PERFIL (datos guardados)
---------------------------------------------------------------------
local function esValido(id: string): boolean
	return Config.alienPorId(id) ~= nil
end

test("datos nuevos y nil", function()
	local d = Perfil.reconciliar(nil, 100, 15, esValido)
	igual(d.dinero, 100)
	igual(#d.aliens, 0)
	igual(d.version, Perfil.VERSION)
end)

test("limpia datos corruptos", function()
	local d = Perfil.reconciliar({
		dinero = "mucho",
		rebirths = -3,
		velocidad = 1e9,
		pendiente = 0 / 0,
		aliens = {
			{ s = 1, id = "blorp" },
			{ s = 1, id = "zib" }, -- slot repetido
			{ s = 99, id = "blorp" }, -- slot fuera de rango
			{ s = 2, id = "no_existe" },
			{ s = 3, id = "voidking", sh = true },
			"basura",
		},
		indice = { blorp = 1, voidking = 2, fantasma = 1, [5] = 1 },
		compras = { "a", 5, "b" },
		codigos = { RELEASE = true, OTRO = "si" },
		diario = { dia = 20000, racha = 3 },
		stats = { robos = 7 },
	}, 100, 15, esValido)
	igual(d.dinero, 100, "dinero inválido -> inicial")
	igual(d.rebirths, 0, "rebirths negativos -> 0")
	igual(d.velocidad, 100, "velocidad con tope")
	igual(d.pendiente, 0, "NaN -> 0")
	igual(#d.aliens, 2, "solo aliens válidos")
	igual(d.aliens[2].sh, true, "conserva shiny")
	igual(d.indice.blorp, 1)
	igual(d.indice.voidking, 2)
	igual(d.indice.fantasma, nil)
	igual(#d.compras, 2)
	igual(d.codigos.RELEASE, true)
	igual(d.codigos.OTRO, nil)
	igual(d.diario.racha, 3)
	igual(d.stats.robos, 7)
	igual(d.stats.ganadoTotal, 0)
end)

test("racha diaria", function()
	igual(Perfil.siguienteRacha({ dia = 0, racha = 0 }, 100), 1, "primera vez")
	igual(Perfil.siguienteRacha({ dia = 99, racha = 4 }, 100), 5, "día seguido")
	igual(Perfil.siguienteRacha({ dia = 97, racha = 4 }, 100), 1, "se rompe la racha")
	igual(Perfil.siguienteRacha({ dia = 100, racha = 4 }, 100), nil, "ya cobrado hoy")
end)

test("compras: sin duplicados y con límite", function()
	local d = Perfil.nuevo(0)
	igual(Perfil.registrarCompra(d, "x"), true)
	igual(Perfil.registrarCompra(d, "x"), false, "duplicado")
	igual(Perfil.yaComprado(d, "x"), true)
	for i = 1, 80 do
		Perfil.registrarCompra(d, "c" .. i)
	end
	igual(#d.compras, Perfil.MAX_COMPRAS, "límite")
	igual(Perfil.yaComprado(d, "c80"), true, "conserva las recientes")
end)

print(string.format("\n%d tests pasados, %d fallados", pasados, fallados))
if fallados > 0 then
	error("Hay tests fallados")
end
