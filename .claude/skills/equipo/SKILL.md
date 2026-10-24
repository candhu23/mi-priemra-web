---
name: equipo
description: Reúne al equipo de cinco agentes para diseñar, actualizar y lanzar los juegos de Roblox del repo como si fueran compañeros — Álex (jefe-equipo, planifica y da las órdenes), Nico (disenador-juego, ideas y fichas), Leo (programador-luau, programa y verifica), Vega (interfaz-probador, juega como jugadores reales y pule la interfaz) e Iris (crecimiento-lanzamiento, ficha, arte, vídeos y plan para conseguir jugadores) — con el revisor-juego antes del commit. Úsala cuando el usuario escriba /equipo, pida «ideas», «reunión», «que el equipo / el jefe…», «mejora el juego», «añade algo nuevo», «pruébalo como un jugador», «quiero más jugadores», o una actualización completa de un juego.
---

# equipo — cinco compañeros para tus juegos

| Quién | Agente | Aporta | Escribe en |
|---|---|---|---|
| 🧑‍✈️ **Álex** | `jefe-equipo` | Plan, órdenes con criterio de aceptación, evalúa entregas, dice TERMINADO | `<juego>/propuestas/PLAN.md` |
| 💡 **Nico** | `disenador-juego` | Fase, diagnóstico con datos, 3 ideas puntuadas, ficha lista para programar | `<juego>/propuestas/` |
| 🛠️ **Leo** | `programador-luau` | Programa de punta a punta, reproduce fallos, `check.sh` en verde | `src/`, `tools/`, docs del juego |
| 🎮 **Vega** | `interfaz-probador` | Juega como 3 jugadores (10 años móvil, 15 años PC, inglés), pule lo visual | cliente (solo lo visual) |
| 📣 **Iris** | `crecimiento-lanzamiento` | Ficha ES/EN, arte, notas, vídeos, plan para conseguir jugadores, analíticas | `<juego>/marketing/`, `docs/arte/` |
| 🔎 Revisor | `revisor-juego` | APTO / NO APTO antes del commit | nada (solo lee) |

**Límite técnico**: un agente no puede lanzar a otros. Por eso Álex **manda** y tú (hilo principal) **ejecutas**:
lanzas a cada miembro con la orden de Álex, le devuelves los informes y haces lo que solo tú puedes hacer
(hablar con el usuario, commit/push, publicar con su «sí»).

**Desde el plugin** (otro proyecto): los agentes se llaman con prefijo, `equipo-roblox:jefe-equipo`,
`equipo-roblox:disenador-juego`, etc. Si en el repo no hay juego, empieza con la skill `nuevo-juego` (la trae el
plugin) para crear uno con todas las pruebas; sin `juegos.json`, la lista de juegos son las carpetas con
`default.project.json`. Las rutas `.claude/skills/...` de los agentes se buscan como indica su sección «Si estás en otro proyecto».

## 0. Antes de empezar

1. **¿Qué juego?** `.claude/skills/roblox-nube/juegos.json` (nombre, carpeta, **rama**) y CLAUDE.md §0. Si no está claro, pregunta.
2. **Rama**: si la carpeta no existe aquí, `git fetch origin <rama> && git checkout <rama>` (si el sistema te
   asignó otra rama, díselo al usuario antes de traer la carpeta).
3. **Herramientas**: `<juego>/tools/setup.sh` si falta `tools/bin`. Sin `tools/check.sh` la verificación es parcial: avísalo.

## 1. El ciclo con el jefe (para todo lo que necesite a más de un miembro)

1. Lanza a **Álex** con: la petición del usuario **literal**, el juego y la rama, y lo que ya se sabe (capturas,
   errores de Studio, decisiones previas). Guarda su ID para hablar con él con **SendMessage** (conserva el contexto).
2. Lee su respuesta:
   - `PREGUNTAS PARA EL USUARIO` → pregúntalas con AskUserQuestion (opciones, la recomendada primero) y pásale la respuesta.
   - `ÓRDENES` → ejecútalas en su orden. Las marcadas «paralelo» lánzalas en el **mismo mensaje**. Pega la orden
     completa como prompt del agente (encargo, entradas, «no hagas», aceptación).
3. Cuando terminen, manda a Álex (SendMessage) un resumen fiel de cada informe: lo importante, rutas de archivos,
   la última línea de `check.sh`, el veredicto del revisor. **No maquilles** fallos.
4. Repite 2–3 hasta `ESTADO: TERMINADO`. Si un agente tiene que corregir algo, usa SendMessage **a ese mismo agente**.
5. Final: lee tú el diff entero, `tools/check.sh` una última vez, commit en español y push a la rama del juego (con el
   `.rbxl` regenerado; sin `tools/out/`). Al usuario: la «NOTA PARA EL USUARIO» de Álex, en tus palabras y corta, con
   1–3 capturas (SendUserFile, «aproximadas») y tu % de confianza.

Mantén a Álex informado de lo que el usuario diga a mitad del trabajo. Si una orden de Álex choca con una norma
(CLAUDE.md, publicar sin «sí», dos `check.sh` a la vez en el mismo juego), no la ejecutes: díselo y que la cambie.

## 2. Atajos sin jefe (cuando es evidente quién lo hace)

- **Ideas**: Nico + Vega («🎮 jugar, solo informe») en paralelo → resumen al usuario con una pregunta de opciones.
- **Pruébalo como un jugador**: solo Vega.
- **Arreglar un fallo de Studio**: Leo (con el texto exacto del error) → Vega si es visual → revisor → commit.
- **Más jugadores / ficha / miniaturas / vídeos / notas de versión**: solo Iris (y `roblox-nube` para subir, con «sí»).
- **Cambio pequeño** (un texto, un número, un color): hazlo tú.

## Reglas del equipo

- Una tarea grande por juego a la vez; dos juegos distintos sí pueden ir en paralelo.
- Nunca Leo y Vega 🎨 a la vez en el mismo juego (comparten archivos, `tools/out/` y el `.rbxl`); en cada ronda,
  solo un agente ejecuta `check.sh` por juego.
- Nada se publica en Roblox ni se cambia en la tienda o en la ficha sin el «sí» explícito del usuario (CLAUDE.md §15).
- `propuestas/INDICE.md` es la memoria del equipo: cuando el usuario apruebe o rechace una idea, apúntalo (con el motivo).
- No reenvíes al usuario textos largos de los agentes: resúmelos tú, sin jerga.
- Coste: cada agente empieza de cero y lee mucho; el jefe añade una vuelta más. Úsalo para trabajos de varios pasos, no para retoques.
