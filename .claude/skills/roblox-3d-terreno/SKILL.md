---
name: roblox-3d-terreno
description: Genera mundos con el Terrain de Roblox por código (Terreno.luau) — islas con colinas, playa, rocas, nieve y mar; colinas; agua; zonas planas para spawn y parcelas; caminos, ríos, montañas, túneles; zonas de simulador en fila unidas por pasos; reparto natural de árboles/rocas/monedas (Poisson) y paleta de colores cartoon para los materiales. Úsala cuando el usuario pida "un mapa", "una isla", "montañas", "un lago/río", "terreno", "el mundo del juego", "zonas como en Pet Simulator", o cuando el suelo plano de bloques se vea pobre.
---

# roblox-3d-terreno — Terreno

`Terreno.luau` (carpeta de esta skill) → ServerScriptService. Sin dependencias.

## API
| Función | Hace |
|---|---|
| `T.limpiar()` | borra todo el terreno |
| `T.isla{centro, radio, alto, semilla, nivelAgua, resolucion=8, escala?, materiales?}` | isla redonda con colinas (ruido), playa, roca, nieve y mar alrededor. Devuelve un **Mapa** |
| `T.colinas{centro, ancho, largo, alto, semilla, resolucion, material}` | terreno ondulado rectangular. Devuelve un Mapa |
| `T.alturaEn(mapa, pos)` / `T.sueloEn(x, z)` | altura del suelo (por el mapa o con un rayo real) para colocar cosas encima |
| `T.aplanar(centro, radio, material?)` | plaza/parcela plana (quita lo de encima y rellena debajo) |
| `T.camino({puntos}, ancho?, material?)` · `T.rio({puntos}, ancho?, hondo?)` · `T.montana(base, alto, radio)` · `T.tunel({puntos}, radio)` | detalles del mapa |
| `T.agua(centro, mitad, fondo, nivel)` | llena de agua el aire bajo un nivel |
| `T.esparcir(centro, radio, distancia, semilla)` | puntos repartidos de forma natural (nunca dos a menos de `distancia`) |
| `T.zonasEnLinea{inicio, numero, radio, separacion, materiales}` | zonas planas de simulador en fila (Zona 1 → 2 → 3…) unidas por un paso; devuelve los centros |
| `T.paletaCartoon()` / `T.colorMaterial(material, color)` | colores de los materiales y del agua más alegres |

## Ejemplo: isla de un simulador
```lua
local T = require(game.ServerScriptService.Terreno)
local C = require(game.ServerScriptService.Constructor) -- skill roblox-3d-construir
T.limpiar(); T.paletaCartoon()
local mapa = T.isla({ radio = 320, alto = 36, semilla = 11, nivelAgua = 2 })
T.aplanar(Vector3.new(0, 12, 0), 50)                         -- spawn
local arboles = C.modelo("Arboles", workspace)
for _, p in T.esparcir(Vector3.zero, 290, 22, 4) do
	local y = T.alturaEn(mapa, p)
	if y and y > 6 and p.Magnitude > 60 then C.arbol(arboles, Vector3.new(p.X, y, p.Z), { alto = 12 }) end
end
C.optimizar(arboles)
```

## Reglas
- **Rendimiento**: resolución 8 en mapas grandes (cada columna es un FillBlock); 4 solo en zonas pequeñas. Mapas para móvil ≲ 1.000×1.000 studs. Activa `Workspace.StreamingEnabled`.
- **Mejor generar una vez**: ejecuta el código en la barra de comandos de Studio (o un plugin) y guarda el lugar; así el servidor no tarda al arrancar y puedes retocar a mano. Si lo generas en cada partida, hazlo antes de que entren jugadores.
- Deja **zonas planas** donde va la jugabilidad (spawn, huevos, tiendas) y el relieve alrededor.
- El agua no debe tapar caminos; el nivel del mar por debajo de las zonas jugables (+2 o más).
- Colores: usa `T.paletaCartoon()` para que combine con UIs y piezas saturadas.

## Comprobar (límites)
El Terrain **no se puede ejecutar fuera de Roblox** (Lune no lo simula): aquí solo se comprueba que compila y que los tipos son correctos
(luau-lsp). Pide al usuario que lo ejecute en Studio y te mande una captura desde arriba y otra a ras de suelo. Confianza en el
aspecto final: media; en que funcione sin errores: alta.
