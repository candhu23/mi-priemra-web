---
name: roblox-ui-pantallas
description: Pantallas típicas de un juego de Roblox ya hechas y bonitas (Pantallas.luau) — HUD con monedas y menú, tienda en rejilla, inventario de mascotas por rareza con «equipar mejores», apertura de huevo animada con probabilidades visibles, ventana de recompensa y flecha de tutorial — y un probador para VERLAS sin Studio (probar_pantallas.luau en Lune + ver_interfaz.py con Chromium → PNG en PC y móvil + informe de problemas). Úsala al crear o rehacer el HUD, la tienda, el inventario, la apertura de huevos/cajas, premios o tutorial, o cuando el usuario diga "enséñame cómo queda", "no se ve bien en el móvil", "haz la tienda como la de Pet Simulator".
---

# roblox-ui-pantallas — pantallas hechas + verlas sin Studio

Archivos en la carpeta de esta skill:
| Archivo | Qué es |
|---|---|
| `Pantallas.luau` | `P.hud`, `P.tienda`, `P.inventario`, `P.abrirHuevo`, `P.recompensa`, `P.senalar`. Necesita **UIKit** (roblox-ui-componentes) y **Animar** (roblox-ui-animaciones) en ReplicatedStorage |
| `probar_pantallas.luau` | ejecuta en **Lune** el código de UI con un jugador falso y guarda «fotos» de la PlayerGui (`captura("nombre")`) |
| `ejemplo_guion.luau` | guion de ejemplo que monta y fotografía las 5 pantallas |
| `volcado.luau`, `ver_interfaz.py`, `capturar.js` | convierten las fotos en PNG (Chromium/Playwright) y auditan: texto cortado, solapes, fuera de pantalla, texto pequeño, contraste, botones pequeños, UIGradient sobre texto |

## Usar las pantallas
```lua
local P = require(RS.Pantallas)
local lienzo = UIKit.pantalla("Juego")
local hud = P.hud(lienzo, { alAbrir = function(cual) if cual == "tienda" then tienda:abrir() end end })
local tienda = P.tienda(lienzo, articulos, function(id) Remotes.Comprar:InvokeServer(id) end)
local inv = P.inventario(lienzo, function(id) Remotes.Equipar:InvokeServer(id) end, function() Remotes.EquiparMejores:InvokeServer() end)
-- Cuando el SERVIDOR diga qué ha salido del huevo:
P.abrirHuevo(lienzo, resultado, probabilidadesDelHuevo)
```
Todo texto entra por parámetro (tradúcelo antes si hay ES/EN). El servidor decide resultados y compras.

## Ver la interfaz sin Studio (hazlo siempre que cambies algo visible)
Requisitos: `lune` (0.10.x) y Chromium + Playwright (en las sesiones en la nube de Claude ya están; Lune: descarga
`https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip`).
1. Escribe un guion (copia `ejemplo_guion.luau`): crea la UI como lo haría tu LocalScript, rellénala con datos de prueba, `captura("01_hud")`, `pulsar(boton)`, `avanzar(n)` para que pasen esperas/animaciones.
2. Ejecuta en PC y en móvil (cada `--modulo` registra un ModuleScript para que `require` funcione):
   ```bash
   lune run probar_pantallas.luau salida_pc guion.luau 1280 720 --modulo ReplicatedStorage/UIKit=ruta/UIKit.luau --modulo ReplicatedStorage/Animar=ruta/Animar.luau --modulo ReplicatedStorage/Pantallas=ruta/Pantallas.luau
   lune run probar_pantallas.luau salida_movil guion.luau 844 390 --modulo …
   python3 -I ver_interfaz.py salida_pc        # → *.png, *_problemas.png, informe_diseno.md
   python3 -I ver_interfaz.py salida_movil --movil
   ```
3. **Mira los PNG con Read** (no te fíes solo del informe), arregla, repite. Enseña 1–3 capturas al usuario.
Prioridad de problemas: cortado > solape > fuera > gradiente > pequeño > contraste > botón.
Falsas alarmas normales: un aviso (toast) que pisa una ventana (es temporal); emojis algo más anchos que en Roblox.

## Recetas de diseño de cada pantalla (por qué está hecha así)
- **HUD**: dinero arriba-izquierda (lo más mirado), menú 2×2 a media altura a la izquierda (zona del pulgar y lejos del joystick), nada abajo-derecha (botón de saltar en móvil) ni arriba-izquierda pegado (menú de Roblox). Insignias rojas para lo que hay que reclamar.
- **Tienda**: rejilla de tarjetas iguales; lo destacado primero, con brillo y borde dorado; precio dentro de un botón verde grande; lo comprado en gris con «✓». Pocas cosas (4–8) mejor que muchas.
- **Inventario**: ordenado equipadas → rareza → poder; borde del color de la rareza; marca ✓ en las equipadas; barra «Equipadas x/y»; botón «Equipar mejores» (evita frustración).
- **Huevo**: suspense corto (≈2 s: balanceo que acelera), destello, revelado con nombre y rareza en su color, confeti si es Épico o más. **Probabilidades siempre visibles** (obligatorio si se paga con Robux; recomendable siempre).
- **Recompensa**: un icono enorme, la cantidad contando hacia arriba, un solo botón «Recoger».
- **Tutorial**: flecha que flota señalando el botón + globo con UNA instrucción corta. Un paso cada vez.

## Límites (dilos con honestidad)
Lune no tiene renderizado real: no hay AbsolutePosition (P.senalar coloca mal la flecha en las capturas), las animaciones se
aplican al instante y las fuentes son parecidas, no idénticas. Sirve para distribución, tamaños, colores y solapes.
