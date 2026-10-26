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
- Por isla: vida de montones ×7, monedas ×9, huevo ×8, poder de crías ×6, puerta ×23 (base 1.800).
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
Islas flotantes con colores cartoon (skills `roblox-3d-terreno`, `roblox-3d-construir`, `roblox-3d-ambiente`),
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
