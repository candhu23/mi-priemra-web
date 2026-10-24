# equipo-roblox: tu equipo de 5 agentes para juegos de Roblox

Plugin de Claude Code para crear, diseñar, programar, probar y lanzar juegos de Roblox (Luau + Rojo), en español.

| | Quién | Agente | Qué hace |
|---|---|---|---|
| 🧑‍✈️ | Álex | `equipo-roblox:jefe-equipo` | Plan y órdenes con criterio de aceptación, evalúa las entregas, dice TERMINADO |
| 💡 | Nico | `equipo-roblox:disenador-juego` | Fase del juego, diagnóstico con datos, 3 ideas, ficha lista para programar |
| 🛠️ | Leo | `equipo-roblox:programador-luau` | Programa de punta a punta, reproduce los fallos, verificación en verde |
| 🎮 | Vega | `equipo-roblox:interfaz-probador` | Juega como 3 jugadores (móvil, PC, inglés) y pule la interfaz |
| 📣 | Iris | `equipo-roblox:crecimiento-lanzamiento` | Ficha ES/EN, arte, vídeos y plan gratis para conseguir jugadores |
| 🔎 | Revisor | `equipo-roblox:revisor-juego` | APTO / NO APTO antes de cada commit |

Skills: `/equipo-roblox:equipo` (coordina al equipo), `nuevo-juego` (juego nuevo con plantilla probada y todas las
pruebas), `disenar-juego`, `disenar-interfaz` (ver la interfaz como PNG en PC y móvil) y `arte-roblox` (iconos y miniaturas).

## Cómo usarlo

- En un repo vacío: «/equipo-roblox:equipo crea un juego nuevo de …» → crea el juego con `nuevo-juego` y el equipo sigue.
- En un repo con juego: «/equipo-roblox:equipo ideas para mi juego», «arreglad esto que falla en Studio», «quiero más jugadores».

## Instalar

**claude.ai (para tenerlo en todas las sesiones, también en la nube):** descarga `equipo-roblox.zip` →
claude.ai → Personalizar (Customize) → Plugins → Añadir → Subir plugin → elige el zip → actívalo.

**Claude Code en tu ordenador:** `/plugin marketplace add candhu23/mi-priemra-web` y después
`/plugin install equipo-roblox@candu-juegos`.

## Actualizar

La fuente es `.claude/` del repo `mi-priemra-web`. Tras cambiar un agente o una skill:
`python3 -I plugins/construir_equipo_roblox.py`, commit, y vuelve a subir el zip en claude.ai.
