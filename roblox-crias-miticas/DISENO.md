# Diseño de «Crías Míticas» (Mythic Hatchlings)

> Documento vivo. Estado: **APROBADO** (el usuario eligió «todo de golpe» = fases 1 y 2, y NO vender huevos ni suerte).
> Programado en la v0.3. Los números reales están en `src/ReplicatedStorage/Config.luau`.
> Inspiración: la *idea* de «Collect All Pets» (coleccionar mascotas que recogen por ti). Nombres, arte,
> textos y sonidos **originales**: no se copia nada del juego original.

## 1. Idea en una frase
Eres cuidador/a de un archipiélago de islas flotantes: abres huevos mágicos, tus crías te siguen y rompen
montones de monedas y cristales por ti, y con lo que ganas abres nuevas islas y completas el **Álbum Mítico**.

## 2. Bucle principal (30 segundos)
1. Caminas por la isla; hay **montones** (monedas, cofres, cristales) repartidos que reaparecen.
2. Tocas un montón (o se elige solo el más cercano) → tus crías equipadas vuelan hacia él y lo rompen.
3. Salen monedas que vuelan hacia ti (sonido + número «+25» flotando).
4. Con monedas compras **huevos** → animación de apertura → cría nueva con su **rareza**.
5. Equipas las mejores (botón «Equipar mejores») → rompes más rápido → huevos más caros.

Rarezas: Común · Poco común · Rara · Épica · Legendaria · Mítica (colores fijos en `Config.Colors`).
Cada cría tiene **Poder** (daño por segundo a los montones). Montones con más vida dan más monedas.

## 3. Bucle de sesión (10–20 min) y de días
- **Islas** (8, se desbloquean con una puerta que cuesta monedas). Cada isla: montones que dan más, su propio
  huevo (6–8 crías nuevas) y decoración distinta:
  Pradera Brote · Bosque Seta · Playa Coral · Dunas Doradas · Volcán Brasa · Glaciar Cristal · Mar de Nubes · Cosmos.
- **Fusión**: 5 crías iguales → versión **Dorada** (Poder ×3). 5 Doradas → **Arcoíris** (×3 otra vez).
- **Huecos**: 3 crías equipadas al empezar; +1 al renacer 1, 3 y 5; +3 con el pase. Mochila de 50 (+25 por renacer).
- **Renacer** (cuando llegas a la isla 4): reinicia monedas e islas; **conservas crías y álbum**;
  monedas ×(1 + 0,5 × renacimientos) para siempre.
- **Álbum Mítico** («Colecciónalas todas»): ~60 crías (+ sus Doradas/Arcoíris). Barra de progreso siempre
  visible y premios al 10/25/50/75/100 % (bonus permanente de monedas y un título).
- **Motivos para volver**: recompensa diaria (racha de 7, ya existe), 3 misiones diarias (fácil/media/difícil,
  completar las 3 da suerte ×2 durante 10 min), ganancias sin conexión (25 %, máx. 8 h).
- **Social**: +10 % de monedas por amigo en el servidor (máx. 4), ves las crías de los demás jugadores.
  **Sin intercambios** en la primera versión (evita estafas y es mucho trabajo; se puede añadir luego).

## 4. Primeros 5 minutos
- 0:00 Flecha y texto «¡Toca un montón!» con 1 cría de regalo ya equipada.
- 0:40 Ya tienes para el **primer huevo** (flecha hacia él). Animación de apertura con probabilidades a la vista.
- 1:30 Segundo y tercer huevo → aparece el botón «Equipar mejores» (paso del tutorial).
- 3:00 Primer duplicado → pista «Junta 5 iguales para una Dorada».
- 5:00 La puerta de la isla 2 a la vista con su precio y barra de progreso.
Tutorial de 5 pasos, se puede saltar, premio al final.

## 5. Economía (objetivos de ritmo; se MEDIRÁN con el bot, no a ojo)
| Hito | Objetivo (jugador normal) | Medido con el bot (v0.3) | Estimado persona (×2) |
|---|---|---|---|
| 1.er huevo | < 60 s | 0:32 | ~1 min |
| 1.ª Dorada | ~ 10 min | 1:10–2:00 | ~3–4 min |
| Isla 2 | ~ 8 min | 3:00–4:40 | ~6–9 min |
| Isla 3 | ~ 25 min | 9–13 min | ~20–26 min |
| Isla 4 / 1.er renacer | ~ 60–90 min | 27–37 / 31–41 min | ~60–80 min |
| Isla 8 | varios días (con renacimientos) | > 7 h | días |
| Álbum 100 % | semanas | 40 % a los 90 min | semanas (Arcoíris de Míticas) |
El bot sale distinto cada vez (las rarezas son al azar): por eso hay rangos. Se mide con `tools/harness/ritmo.luau`.
- **Montón Dorado** (cada 3 min en la isla más alta de cada jugador; vida ×10, monedas ×33 de un montón de la isla, dura 60 s):
  mediana de 60 partidas del bot, sin → con: isla 2 3:55 → 4:00, isla 3 11:38 → 11:04 (−5 %), isla 4 30:09 → 27:53 (−7,5 %),
  1.er renacer 35:58 → 33:21 (−7 %). Supone que el bot rompe todos (cota alta).
- **Gran momento** al abrir: Épica = momento mediano; Legendaria/Mítica = destello, su probabilidad real y aviso al servidor (máx. 1 cada 10 s por jugador).
- Por isla: vida de cristales ×7, monedas ×17,5, huevo ×8, poder de crías ×6, puerta ×45 (base 1.800).
  → con el mismo equipo, cada isla rinde **×2,5 monedas por segundo** (antes ×9/×7 = ×1,29: no se notaba). La puerta de
  cada isla lo dice: «💎 Cristales ×N monedas» (N = monedas por punto de vida frente a la isla 1: ×2,5, ×6,2, ×15…).
- **Cristales distintos por isla** (2026-10-26): cada isla tiene su paleta (`Config.Zones[i].crystalColors`, 4 colores) y cada
  tipo su tamaño (`Config.PileKinds[k].size`: pequeño 1 / mediano 1,3 / grande 1,65, ±12 %). El «+🪙» sale más grande cuanto
  más vale frente al premio típico de la isla (`Config.FLOAT_TEXT`).
- Ritmo antes → después de ese cambio (mediana del bot, 24 partidas antes / 30 después, `ritmo.luau`; entre paréntesis mín–máx).
  La puerta pasó de ×23 a ×45 para que el ritmo de las primeras islas no cambie (se probó ×23: isla 4 en 12 min; ×40: 24 min; ×50: 33 min):

| Hito | Antes (monedas ×9, puerta ×23) | Después (monedas ×17,5, puerta ×45) |
|---|---|---|
| Isla 2 | 3:56 (3:00–4:59) | 3:33 (2:02–5:14) |
| Isla 3 | 10:48 (6:31–12:56) | 10:28 (7:18–14:12) |
| Isla 4 | 27:08 (15:41–34:19) | 26:48 (18:27–32:55) |
| 1.er renacer | 32:44 (21:28–41:57) | 28:36 (19:39–35:20) |
| Isla 5 (tras renacer) | 51:38 | 49:32 |
| Isla 7 (1 partida de 7 h) | 6:22 h | 5:32 h |
  Ojo: los huevos siguen ×8 por isla y el dinero ahora sube ×15 por isla con las crías nuevas → en islas altas los huevos
  salen relativamente más baratos (por eso el final va algo más rápido). Si se nota, subir `ZONE_GROWTH.eggCost`.
- Renacer: isla 4 (+1 por renacer, máx. 8) **y** monedas = 2 × puerta de esa isla × 4^renacimientos (si no, se renacía en cadena).
- Premios (diaria, misiones, productos) en «minutos de monedas» con un mínimo fijo (escalan solos).

## 6. Tienda (Robux) — todo con `id = 0` hasta que se cree en Roblox
| Artículo | Tipo | Precio | Qué da |
|---|---|---|---|
| Monedas x2 | Pase | 199 | x2 monedas para siempre |
| +3 huecos | Pase | 249 | 3 crías más equipadas |
| Abrir x3 | Pase | 199 | Abre 3 huevos a la vez |
| Auto-abrir | Pase | 149 | Abre huevos solo mientras estás al lado |
| Mochila +100 | Pase | 99 | Más espacio |
| Saco / Cofre de monedas | Producto | 25 / 99 | 15 / 90 min de monedas |
| Monedas x2 30 min | Producto | 39 | Boost temporal |

**Decisión importante (recomendada):** NO vender huevos ni «suerte» por Robux. Así no hay «artículos aleatorios
de pago» (más simple en el cuestionario de contenido, CLAUDE.md §11). La suerte se gana jugando (misiones).
Probabilidades de cada huevo siempre visibles. Nada de «free Robux», ni tienda que se abre sola.

## 7. Estilo visual
Mapa CONTINUO como Collect All Pets (capturas del usuario 2026-10-26): 8 zonas pegadas en zigzag, cada una con su suelo y
decoración (pradera, setas, playa, desierto, volcán, glaciar, nubes, cosmos), acantilados alrededor, puertas en las paredes
y cristales de colores sobre losas; colores cartoon (skills `roblox-3d-terreno`, `roblox-3d-construir`, `roblox-3d-ambiente`),
crías low-poly propias (`roblox-3d-mallas`) con aura según rareza, interfaz clara con botones gruesos
(`roblox-ui-pantallas`: HUD, inventario por rareza, apertura de huevo, álbum). Letra FredokaOne. ES/EN.

## 8. Plan por fases (para no quedarnos a medias otra vez)
- **Fase 1 (v0.2, jugable):** islas 1–3, 3 huevos, ~20 crías, montones, seguir al jugador, equipar, fusionar,
  álbum, diaria, tutorial. Bot de pruebas + capturas. *Commit y push al terminar cada parte.*
- **Fase 2 (v0.3):** islas 4–8, renacer, misiones diarias, pases y productos (id = 0), offline.
- **Fase 3 (v0.4):** arte 3D bonito, iconos (`arte-roblox`), ficha ES/EN, primera publicación.

## 9. Riesgos / lo que no puedo comprobar aquí
- Que las crías **sigan bien** al jugador y no atraviesen cosas: Lune no simula físicas ni movimiento;
  solo se ve de verdad en Studio (te pediré una prueba con capturas).
- Rendimiento con 8 jugadores × 6–9 crías + montones: se diseña ligero (crías ancladas movidas por código),
  pero hay que probarlo en un servidor real.
