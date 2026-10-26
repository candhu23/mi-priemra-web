# PLAN vivo — Crías Míticas (Mythic Hatchlings)

Jefe: Álex · Rama: `claude/confident-johnson-v5zy5f` · Actualizado: 2026-10-26 (petición 2: «rarezas y árbol»)

## Objetivo del usuario (petición 2, sus palabras resumidas)
1. Cristales de distinto color y tamaño. 2. Los de la zona 2 (y siguientes) dan MÁS dinero, y se nota.
3. Un SITIO para fusionar. 4. Huevo de la zona 1 = solo Comunes; se sube de rareza fusionando:
5 Común→1 Poco común, 5→Rara, 5→Épica, 5→Legendaria, 5 Legendaria→1 Prodigiosa, 3 Prodigiosas→1 Ascendida,
3 Ascendidas→1 Mítica (8 rarezas, como Collect All Pets). 5. Cada Mítica → 1 Piedra de Renacimiento.
6. Las zonas se abren por crías DESCUBIERTAS en el Índice, no por monedas. 7. Quitar la pestaña Renacer.
8. Zona nueva con el ÁRBOL DE MEJORAS físico (pedestales unidos por caminos brillantes, se pagan con piedras,
unos piden otros antes) — como su captura de Collect All Pets (mecánica, no nombres ni arte).
**Éxito cuando:** los 8 puntos están programados, `tools/check.sh` = TODO CORRECTO ✅ (bot recorre fusión por rarezas,
desbloqueo por índice, piedra, compra de mejoras con requisito), ritmo medido (1.ª Mítica / 1.ª piedra en tiempo razonable),
revisor APTO, `.rbxl` subido y el usuario tiene los pasos de Studio.

## Respuestas del usuario (2026-10-26)
- Huevos 3D por rareza (solo hasta Legendario): blanco Común, verde Poco común, azul Raro, morado Épico, dorado Legendario.
- Huevo de cada zona: 1-2 Común · 3-4 Poco común · 5 Raro · 6 Épico · 7 **Épico (decisión de Álex, a confirmar)** · 8 Legendario.
  Un huevo da SOLO crías de su rareza; lo demás se sube fusionando (5/5/5/5/5/3/3).
- **Zona 9 nueva**, se entra con **200 de puntuación Brillante** → hace falta un sistema Brillante mínimo.
- Fusión → otra cría de la misma familia (zona). Dorada/Arcoíris se quitan. Sin renacer: solo piedras (1 por Mítica).
- Cálculo: con huevo Legendario, 1 Mítica = 45 Legendarias; con huevo Común (zona 1) = 28.125 Comunes → en zonas 1-2 la Mítica
  no es la meta; la primera piedra realista llega en la zona 8 (Nico lo mide).

## Mapa (decisión de Álex)
`World.GRID` es una lista: zona 9 en la celda (2,2) (vecina de la zona 8) y **Jardín de Mejoras** en (-1,0), pegado a la zona 1
(spawn), siempre abierto. Estación de fusión física en la zona 1 junto al spawn (y otra en el Jardín).

## Presupuesto
R2 Nico (1 ficha) ∥ Leo-1 · R3 Leo-2a núcleo (commit) · R4 Leo-2b mundo: árbol + zona 9 + estación + huevos 3D (commit) ·
R5 Vega 1 pasada · R6 revisor final + commit. Nada más sin preguntar.

## Rondas
| # | Quién | Qué | Estado |
|---|---|---|---|
| 1 | Leo | Cristales color/tamaño por zona + más dinero visible | ⏳ en curso |
| 1 | Usuario | Respuestas | ✅ (falta confirmar zona 7 y huevo de la zona 9) |
| 2 | Nico | Ficha `2026-10-26-rarezas-arbol.md` | ⏳ |
| 1b | Revisor + Hilo | APTO y commit de Leo-1 | — |
| 3 | Leo | 2a: 8 rarezas, 72 crías, huevos por rareza, fusión por familia + Fusionar todo, Brillantes, piedras, puertas por Índice/Brillante, sin Renacer ni Dorada/Arcoíris, DataStore v2, lógica del árbol | — |
| 3b | Revisor + Hilo | APTO y commit de 2a | — |
| 4 | Leo | 2b: Jardín de Mejoras físico, zona 9, estación de fusión, huevos 3D por rareza (pack + piezas) | — |
| 5 | Vega | 🎮+🎨 una pasada PC+móvil | — |
| 6 | Revisor + Hilo | APTO, commit + push con `.rbxl`, pasos de Studio | — |

## Decisiones y notas
- Juego SIN publicar → se puede cambiar a DataStore `MythicHatchlings_v2` (las partidas de prueba de Studio se pierden; nadie más).
- El mapa es una cuadrícula 3×3 con 8 zonas: la celda (2,2) está LIBRE → ahí va la zona del árbol (vecina de zonas 4 y 8);
  acceso por teletransporte desde el menú Islas y una plataforma en la zona 1 (siempre abierta, sin puerta).
- Hoy `Config.Rarities` tiene «common» repetido (35 y 25) → 7 entradas y 6 rarezas reales. Se rehace a 8 rarezas.
- Cristales: hoy monedas ×9 y vida ×7 por zona → por segundo solo ×1,29 más; por eso el usuario «no lo nota».
- Normas: piedras y mejoras solo jugando (nunca por Robux), probabilidades visibles en cada huevo, nada de vender huevos/suerte.
- Pendiente anterior que sigue: nadie lo ha probado en Studio.
