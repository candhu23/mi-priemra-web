---
name: disenar-juego
description: Diseña y añade mecánicas a los juegos de Roblox del repo con método — bucle principal, primeros 5 minutos, metas de sesión y de días, economía con objetivos de ritmo medidos con simulación, y monetización legítima — y las implementa de punta a punta en la arquitectura de estos juegos (Config → acción del servidor → estado → cliente → textos ES/EN → harness → docs). Úsala cuando el usuario pida una mecánica o sistema nuevo ("añade mascotas", "pon eventos", "que haya misiones"), diga "el juego es aburrido / muy simple / le falta algo", quiera más jugadores o más Robux, o al darle identidad a un juego recién creado.
---

# disenar-juego — mecánicas que enganchan, bien hechas

Objetivo del usuario: **enganche y Robux, con prácticas legítimas** (CLAUDE.md §2 y §11).

## 0. Entender el juego antes de tocar nada (1 minuto)

`python3 -I ${CLAUDE_SKILL_DIR}/mapa_juego.py <carpeta>` → archivos, tablas de Config, acciones del
servidor (y cuáles **no prueba ningún harness** ❌), textos ES/EN y tienda. Lee también el CLAUDE.md del
juego y su `DISENO.md` si existe.

## 1. Diagnóstico con las 5 preguntas (antes de proponer)

1. **Bucle principal (30 s)**: ¿qué hace el jugador una y otra vez? ¿se siente bien (sonido, número que
   sube, animación)? Si no es divertido 30 s, ninguna mecánica lo salva.
2. **Primeros 5 minutos**: ¿en < 10 s sabe qué tocar? ¿primera compra < 30 s? ¿algo nuevo cada ~1 min?
   (aquí se pierde a la mayoría; mira las capturas `00_*` con `disenar-interfaz`).
3. **Metas a la vista**: siempre 1 meta corta (< 1 min), 1 media (5–10 min) y 1 larga (días) visibles.
4. **Motivos para volver**: diario con racha, misiones diarias, ganancias offline, eventos con hora,
   clasificación semanal, «tu edificio/flota crece y se ve».
5. **Social**: bonus por amigos en el servidor, invitar, ver a otros progresar (tráfico, edificios).

Escribe el diagnóstico en 5 líneas y propón **máx. 3 mejoras** ordenadas por impacto/esfuerzo. Pregunta al
usuario cuál (una pregunta con opciones; la recomendada primero) si no lo dejó claro.

## 2. Patrones que funcionan en Roblox (elige, no los metas todos)

| Patrón | Para qué | Cuidado |
|---|---|---|
| Prestigio / «salir a bolsa» (reinicia con multiplicador) | Juego largo sin techo | Que el 1.º sea a ~1–2 h, no antes |
| Colección (mascotas, programadores, aviones) con rarezas | Metas largas y presumir | Si es de pago y aleatorio → **probabilidades visibles**, «pity» y alternativa no aleatoria |
| Misiones diarias (fácil/media/difícil) + premio por completar todas | Volver cada día | Que se puedan hacer en 15–20 min |
| Eventos con hora (x2 fin de semana, «San Fermín») | Sesiones a la misma hora, sorpresa | Avisar con cuenta atrás |
| Mejoras visibles en el mundo (edificio que crece) | Orgullo, captura para TikTok | Coste de piezas (rendimiento) |
| Clasificación semanal con premio | Competir, volver | Premio cosmético o pequeño |
| Tutorial con flecha (máx. 5–7 pasos) | Primeros 5 min | Se puede saltar; premio al final |

## 3. Economía: números con objetivo, no a ojo

- Fórmulas y números SOLO en `Config` (ver §6 de CLAUDE.md). Costes `base × crecimiento^n` (1,07–1,20).
- Escribe los **objetivos de ritmo** en `DISENO.md` (p. ej. 1.er negocio < 30 s, 2.º ~2 min, 4.º ~15–25 min,
  prestigio ~1–2 h) y **mídelos**: plantilla → `tools/harness/ritmo.luau` (lo ejecuta `check.sh`);
  Imperio → `tools/sim/sim.luau`; AeroCarga → bot de `run_server.luau`. El bot va ~2–3× más rápido que
  una persona. Ajusta hasta que cuadre y apunta el resultado en el DISENO/CLAUDE.md del juego.
- Recompensas en «minutos de ingresos» (escalan solas con el progreso) con un mínimo fijo.

## 4. Monetización legítima (lo que más Robux da sin trampas)

- **Pases permanentes** (x2 dinero, automático, +huecos, velocidad): el grueso de los ingresos. Rango
  habitual 99–499 R$; el «x2» suele ser el más vendido (199–299).
- **Productos** (dinero = minutos de ingresos, boost temporal, «terminar ya»): baratos (19–99) y útiles
  justo cuando faltan (ofrécelos en el momento: «te faltan $200 → Maletín»).
- Paquete de inicio de una vez (99) con valor claro. Premium/grupo/amigos: +10 % cada uno (gratis).
- Nunca: pagar para ganar contra otros, textos engañosos, «free Robux», aleatorio sin probabilidades,
  la tienda abriéndose sola al entrar. Probabilidades visibles = obligatorio (CLAUDE.md §11).

## 5. Implementar una mecánica (orden fijo; verificación al final de cada paso grande)

1. **Datos**: campos nuevos en `newData()` (las partidas viejas los reciben con `reconcile`).
2. **Config**: números y fórmulas (compartidas servidor/cliente).
3. **Servidor**: acción en `Actions` con **validación de cada argumento** (tipo, rango, existe, tiene dinero)
   y límite de frecuencia; efectos en el bucle de 1 s si son por tiempo; campos nuevos en el estado.
4. **Cliente**: interfaz con las piezas del Kit y la guía de `disenar-interfaz` (botón principal claro,
   texto ≥ 16, móvil). Textos en `Lang` ES **y** EN (o en el idioma del juego si aún no tiene Lang).
5. **Harness**: la acción nueva en el bot (`run_juego.luau` / `run_server.luau` / `run_game.luau`) y, si
   tiene pantalla, un volcado para verla. `mapa_juego.py` no debe marcarla ❌.
6. `tools/check.sh` → `TODO CORRECTO ✅`; mirar capturas; medir el ritmo.
7. Docs: CLAUDE.md del juego (acciones, datos, estado) y `DISENO.md`; subir `Config.VERSION`.
8. Explicar al usuario: qué cambia para el jugador, qué verificaste, qué no (sin Studio) y tu % de confianza.

Para sistemas cliente/servidor grandes, la skill `roblox-dev:new-system` y el agente `revisor-juego`
(revisión antes del commit) ayudan.
