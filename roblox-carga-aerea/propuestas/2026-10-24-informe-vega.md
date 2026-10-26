# Informe de Vega (interfaz y pruebas): AeroCarga v0.2, 2026-10-24

Solo informe: no se tocó nada. `tools/check.sh` → TODO CORRECTO ✅. Revisadas 23 pantallas en PC (1280×720)
y 23 en móvil (844×390). Las capturas son aproximadas (sin 3D, animaciones ni sonido). Confianza ~70 %.

Notas como jugador nuevo: claridad 3/5 · recompensa 3/5 · ganas de volver mañana 3,5/5.

## Para arreglar (por orden: lo que más jugadores perdería primero)

| # | Gravedad | Dónde | Qué pasa | Origen probable |
|---|---|---|---|---|
| 1 | 🔴 Alta | móvil, tutorial paso 4 (fichajes) | El bocadillo del tutorial tapa el botón FICHAR del piloto barato que pide fichar; solo se ve uno de $40.000 en gris → atasco o «Saltar» | `Screens.luau:402-404` (bocadillo fijo abajo a la izquierda, 440×110). Regla: colocarlo donde NO esté el botón señalado |
| 2 | 🔴 Alta | móvil, todo | La escala baja a 0,66 sin mínimo: textos de 7,9–9,2 px reales («🔒 Nv 4», «LISTO», «Saltar», «⭐ Primer vuelo») | `GameClient.client.luau:104`: escala mínima ~0,75 o agrandar con `ctx.compact` |
| 3 | 🔴 Alta | móvil | 48 botones pequeños para el dedo: pines del mapa 17×17, cerrar 30×30, pestañas 25 de alto, Saltar 66×20, Despedir 73×21 | Kit / MapView |
| 4 | 🟠 Media | tutorial paso 1 | «Pulsa VOLAR en el ⭐ primer vuelo», pero los 5 VOLAR son iguales | Resaltar el botón (borde/brillo) |
| 5 | 🟠 Media | tutorial paso 5 | Dice «¡Reclama aquí abajo!» y la tarjeta está a la izquierda | `Lang.luau` |
| 6 | 🟠 Media | móvil, Misiones | «¡Reclama las 3 y gana x2…!» cortado; el aviso exprés tapa la pestaña «Premio diario» | MissionsPanel |
| 7 | 🟠 Media | varios | Contraste bajo: blanco sobre amarillo (RECLAMAR DÍA 1, IR: 1,59:1), VOLAR/JUGAR/FICHAR ≈ 2,8:1 | colores del Kit |
| 8 | 🟡 Baja | varios | Plurales («Haz 1 entregas», «Completa 1 contratos»), coma/punto decimal mezclados, «$751,0K» | `Lang.luau:163,167`, formateo |
| 9 | 🟡 Baja | portada | «AeroCarga» pisa la franja «ESPAÑA»; el avión parece desmontado | Screens / PlaneArt |
| 10 | 🟡 Baja | Flota/Pilotos | 2 columnas dejan ⅓ vacío; botón «💲» de vender no se entiende; piloto 1★ «+0 %» no motiva | paneles |

Falsas alarmas: la barra inferior «tapando» textos (queda debajo de la ventana) y «👇 fuera de pantalla»
(el mock da la misma `AbsolutePosition` a todo; la flecha del tutorial no se puede comprobar con capturas).

## Herramientas (para Leo)

- `check.sh` de AeroCarga no genera la vista móvil: añadir una pasada `run_game.luau` con `{width=844,height=390}`.
- ✅ `ver_interfaz.py` ya acepta los degradados de AeroCarga (`[[r,g,b],…]`), arreglado en el commit del equipo.

## Ideas para Nico

Aviones y rutas visibles en el mapa desde el primer minuto; piloto 1★ con al menos +2 %; comprobar si los premios
de misiones diarias escalan con el progreso; «Motores turbo» (249) más caro que «VIP x2» (199); etiqueta «mejor
oferta» en el Pack de inicio.
