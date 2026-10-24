-- Guion de ejemplo para probar_pantallas.luau: monta las pantallas de Pantallas.luau y las fotografía.
-- lune run probar_pantallas.luau salida ejemplo_guion.luau 1280 720 \
--   --modulo ReplicatedStorage/UIKit=<ruta a UIKit.luau (skill roblox-ui-componentes)> \
--   --modulo ReplicatedStorage/Animar=<ruta a Animar.luau (skill roblox-ui-animaciones)> \
--   --modulo ReplicatedStorage/Pantallas=Pantallas.luau
local RS = game:GetService("ReplicatedStorage")
local UIKit = require(RS:WaitForChild("UIKit"))
local P = require(RS:WaitForChild("Pantallas"))

local lienzo = UIKit.pantalla("Juego")
local hud = P.hud(lienzo, {})
hud.monedas:poner(15300)
hud.gemas:poner(42)
hud.insignias.misiones:poner(3)
UIKit.aviso(lienzo, "¡Has desbloqueado la Zona 2!", "exito")
captura("01_hud")

local tienda = P.tienda(lienzo, {
	{ id = "x2", nombre = "x2 Monedas", icono = "💰", precio = "R$ 199", descripcion = "Gana el doble para siempre", destacado = true },
	{ id = "huecos", nombre = "+3 Huecos", icono = "🐾", precio = "R$ 149", descripcion = "Equipa 3 mascotas más" },
	{ id = "auto", nombre = "Auto-abrir", icono = "🥚", precio = "R$ 249", descripcion = "Abre huevos solo", comprado = true },
	{ id = "suerte", nombre = "Suerte x2", icono = "🍀", precio = "R$ 99", descripcion = "Más probabilidad de raras" },
	{ id = "monedas1", nombre = "Saco", icono = "💵", precio = "R$ 25", descripcion = "15 min de ingresos" },
}, function() end)
tienda:abrir()
captura("02_tienda")
tienda:cerrar()

local inv = P.inventario(lienzo, function() end, function() end)
inv:poner({
	{ id = "1", nombre = "Gatito", emoji = "🐱", rareza = "Comun", poder = 12, equipada = true },
	{ id = "2", nombre = "Dragón", emoji = "🐉", rareza = "Legendario", poder = 2400, equipada = true },
	{ id = "3", nombre = "Perrito", emoji = "🐶", rareza = "PocoComun", poder = 30 },
	{ id = "4", nombre = "Unicornio", emoji = "🦄", rareza = "Mitico", poder = 9000, equipada = true },
	{ id = "5", nombre = "Pulpo", emoji = "🐙", rareza = "Raro", poder = 150 },
	{ id = "6", nombre = "Zorro", emoji = "🦊", rareza = "Epico", poder = 700 },
	{ id = "7", nombre = "Rana", emoji = "🐸", rareza = "Comun", poder = 10 },
}, 3, 5)
inv:abrir()
captura("03_inventario")
inv:cerrar()

P.abrirHuevo(lienzo, { nombre = "Dragón", emoji = "🐉", rareza = "Legendario" }, {
	{ emoji = "🐱", rareza = "Comun", pct = 60 },
	{ emoji = "🐶", rareza = "PocoComun", pct = 25 },
	{ emoji = "🐙", rareza = "Raro", pct = 10 },
	{ emoji = "🦊", rareza = "Epico", pct = 4 },
	{ emoji = "🐉", rareza = "Legendario", pct = 0.9 },
	{ emoji = "🦄", rareza = "Mitico", pct = 0.1 },
})
avanzar(4)
captura("04_huevo")
local velo = buscar("AbrirHuevo")
if velo then
	velo:Destroy()
end

P.recompensa(lienzo, "🎁 Premio diario", "💰", 500)
avanzar(2)
captura("05_recompensa")
