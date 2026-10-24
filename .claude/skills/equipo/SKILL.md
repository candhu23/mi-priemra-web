---
name: equipo
description: Reúne al equipo de tres agentes para diseñar y actualizar los juegos de Roblox del repo como si fueran tres compañeros más — Nico (disenador-juego, ideas y fichas), Leo (programador-luau, programa y verifica) y Vega (interfaz-probador, juega como jugadores reales, ve las pantallas y pule la interfaz) — con el revisor-juego antes del commit. Úsala cuando el usuario escriba /equipo, pida «ideas», «reunión», «que el equipo…», «mejora el juego», «añade algo nuevo», «pruébalo como un jugador», o quiera una actualización completa de un juego (idea → programa → interfaz → revisión → commit).
---

# equipo — tres compañeros para tus juegos

| Quién | Agente | Aporta | Escribe en |
|---|---|---|---|
| 💡 **Nico** | `disenador-juego` | Fase del juego, diagnóstico con datos, 3 ideas puntuadas, ficha lista para programar | `<juego>/propuestas/` |
| 🛠️ **Leo** | `programador-luau` | Programa de punta a punta, reproduce fallos, `check.sh` en verde | `src/`, `tools/`, docs del juego |
| 🎮 **Vega** | `interfaz-probador` | Juega como 3 jugadores (10 años móvil, 15 años PC, inglés), audita y pule lo visual | cliente (solo lo visual) |
| 🔎 Revisor | `revisor-juego` | APTO / NO APTO antes del commit | nada (solo lee) |

Tú (hilo principal) coordinas: lanzas a los agentes, juntas lo que dicen, hablas con el usuario y haces
commit/push. **Los agentes no se lanzan entre sí ni hablan con el usuario**: todo pasa por ti. Empiezan sin
la conversación: en cada prompt pon la carpeta del juego, el objetivo con las palabras del usuario, lo que ya
se sabe (capturas, errores de Studio, ideas rechazadas) y el encargo exacto.

## 0. Antes de empezar

1. **¿Qué juego?** Los juegos están en `.claude/skills/roblox-nube/juegos.json` (nombre, carpeta, **rama**) y en
   el índice de CLAUDE.md §0. Si no está claro, pregunta (AskUserQuestion).
2. **Rama**: cada juego vive en su rama. Si la carpeta no existe aquí:
   `git fetch origin <rama> && git checkout <rama>` (si el sistema te asignó otra rama, trabaja en la asignada,
   tráete la carpeta con `git checkout origin/<rama> -- <carpeta>` solo si el usuario está de acuerdo, y díselo).
3. **Herramientas**: `<juego>/tools/setup.sh` si falta `tools/bin`. Si el juego no tiene `tools/check.sh`, avisa al
   usuario de que la verificación será parcial.
4. Lee `<juego>/propuestas/INDICE.md` si existe (memoria del equipo: hecho, aprobado, rechazado y por qué).

## 1. Modo «reunión de ideas» (el usuario quiere ideas o «¿qué le falta?»)

1. Lanza **en paralelo**, en el mismo mensaje:
   - **Nico**: fase + diagnóstico + 3 ideas + ficha de la recomendada.
   - **Vega**, encargo **🎮 jugar, solo informe** (sin editar): primer minuto de A/B/C + «Ideas para Nico».
     (Solo Vega ejecuta `check.sh` en este modo; a Nico dile que use las capturas/simulación existentes).
   - **Leo** (opcional, si las ideas tienen dudas técnicas): «coste y riesgo de cada idea en el código actual, sin editar».
2. Junta las respuestas para el usuario (corto): lo que dijo cada uno en 2–3 líneas, dónde coinciden y dónde no,
   y **una pregunta con opciones** (la recomendada primero). Si Vega encontró algo que perdería jugadores ya,
   ofrécelo como opción.
3. Con la respuesta del usuario, actualiza `INDICE.md` (✅ aprobada / ❌ rechazada + motivo). No programes antes.

## 2. Modo «actualización» (sabe qué quiere o eligió una idea)

1. **Ficha**: si no existe en `propuestas/`, pídesela a Nico (para algo pequeño, escríbela tú en 10 líneas).
2. **Leo programa**. Si no llega a «TODO CORRECTO ✅», mándale el error con **SendMessage al mismo agente**
   (conserva el contexto) en vez de lanzar uno nuevo.
3. **Vega pule** si hay pantallas nuevas o cambiadas (encargo 🎮 + 🎨). Lo que apunte «Para Leo» vuelve a Leo.
   **Nunca** Leo y Vega a la vez sobre el mismo juego: comparten archivos, `tools/out/` y el `.rbxl`.
4. **Revisor**: `revisor-juego` sobre el diff. 🔴 → vuelve a Leo/Vega. Repite hasta APTO.
5. **Tú**: lee el diff entero, `tools/check.sh` una última vez, commit en español + push a la rama del juego (con el
   `.rbxl` regenerado; sin `tools/out/`). Sin PR salvo que lo pida.
6. **Al usuario**: qué cambia para el jugador, 1–3 capturas antes/después (SendUserFile, «aproximadas»), qué se
   verificó, qué no (no hay Studio aquí), qué probar en Studio de clic en clic, cómo publicar (skill `publicar` o
   CLAUDE.md §10) y **% de confianza**.

## 3. Modo «arreglar un fallo» (algo roto en Studio)

Pasa a Leo **todo** lo que mandó el usuario (texto exacto del error, qué pulsó, captura descrita) → Leo reproduce
y arregla → Vega si es visual → revisor → commit. Pide al usuario que lo pruebe y te diga si se arregló.

## 4. Modo «pruébalo como un jugador»

Solo Vega, encargo 🎮 (y 🎨 si el usuario quiere que lo arregle). Útil antes de publicar.

## Reglas del equipo

- Una tarea grande por juego a la vez. Dos juegos distintos sí pueden ir en paralelo (son carpetas distintas).
- Nada se publica en Roblox ni se cambia en la tienda sin el «sí» explícito del usuario (CLAUDE.md §15).
- Si dos agentes no están de acuerdo, enseña al usuario las dos posturas en 2 líneas y recomienda una.
- No reenvíes al usuario textos largos de los agentes: resúmelos tú, en su idioma, sin jerga.
- Coste: cada agente empieza de cero y lee mucho. Para cambios pequeños (un texto, un número, un color) hazlo tú.
