---
name: equipo
description: Reúne al equipo de tres agentes para diseñar y actualizar los juegos de Roblox del repo como si fueran tres compañeros más — Nico (disenador-juego, ideas y fichas), Leo (programador-luau, programa y verifica) y Vega (interfaz-probador, juega, ve las pantallas y pule la interfaz) — con el revisor-juego antes del commit. Úsala cuando el usuario escriba /equipo, pida «ideas», «reunión», «que el equipo…», «mejora el juego», «añade algo nuevo», o quiera una actualización completa de un juego (idea → programa → interfaz → revisión → commit).
---

# equipo — tres compañeros para tus juegos

| Quién | Agente | Aporta | Escribe en |
|---|---|---|---|
| 💡 **Nico** | `disenador-juego` | Diagnóstico, 3 ideas puntuadas, ficha lista para programar | `<juego>/propuestas/` |
| 🛠️ **Leo** | `programador-luau` | Programa de punta a punta, harness, `check.sh` en verde | `src/`, `tools/`, docs del juego |
| 🎮 **Vega** | `interfaz-probador` | Juega como un jugador nuevo, audita PC/móvil, pule lo visual | cliente (solo lo visual) |
| 🔎 Revisor | `revisor-juego` | APTO / NO APTO antes del commit | nada (solo lee) |

Tú (hilo principal) eres quien coordina: lanzas a los agentes, juntas lo que dicen, hablas con el usuario,
haces commit/push. **Los agentes no pueden lanzarse entre sí ni hablar con el usuario**: todo pasa por ti.

## 0. Antes de empezar

- ¿Qué juego? (Imperio → `roblox-imperio-web/`, AeroCarga → `roblox-carga-aerea/`, u otro de `juegos.json`).
  Si no está claro, pregúntalo. Comprueba que la carpeta existe en la rama actual (CLAUDE.md raíz §0).
- Pasa a cada agente en el prompt: carpeta del juego, objetivo del usuario con sus palabras, y lo que ya se sabe
  (capturas que mandó, fallos vistos en Studio). Los agentes empiezan sin la conversación: no des nada por sabido.

## 1. Modo «reunión de ideas» (el usuario quiere ideas)

1. Lanza **en paralelo** (en el mismo mensaje):
   - Nico: diagnóstico + 3 ideas + ficha de la recomendada.
   - Vega: sombrero de jugador sobre el estado actual (primeros 5 min, PC y móvil) + «Ideas para Nico».
   - Leo (opcional, solo si hay dudas técnicas): «¿qué cuesta y qué riesgo tiene cada una de estas ideas en el código actual?» — sin editar nada.
2. Junta las respuestas en un resumen corto para el usuario: lo que dijo cada uno (2–3 líneas), dónde
   coinciden, y **una pregunta con opciones** (AskUserQuestion; la recomendada primero) sobre qué hacer.
3. No programes nada hasta que el usuario elija.

## 2. Modo «actualización» (el usuario ya sabe qué quiere o eligió una idea)

1. **Ficha**: si no existe en `<juego>/propuestas/`, pídesela a Nico (o escríbela tú si es un cambio pequeño).
2. **Leo programa** con la ficha. Espera a que diga «TODO CORRECTO ✅». Si no lo consigue, vuelve a mandarle el error
   (SendMessage al mismo agente para que conserve el contexto) en vez de empezar de cero.
3. **Vega revisa** si hay pantallas nuevas o cambiadas: juega, audita, arregla lo visual. Lo que apunte «Para Leo»
   vuelve a Leo.
4. **Revisor**: lanza `revisor-juego` sobre el diff. 🔴 → vuelve a Leo/Vega. Repite hasta APTO.
5. **Tú**: `tools/check.sh` una última vez, revisa el diff tú mismo, commit en español + push a la rama de trabajo
   (con el `.rbxl` regenerado). Sin PR salvo que lo pida.
6. **Al usuario**: qué cambia para el jugador, 1–3 capturas (SendUserFile, «aproximadas»), qué se verificó, qué no
   (no hay Studio aquí), pasos de clic en clic para probar/publicar (CLAUDE.md §10 o skill `publicar`) y **% de confianza**.

## 3. Modo «arreglar un fallo» (el usuario ve algo roto en Studio)

Leo diagnostica y arregla (con las capturas/mensajes de error del usuario en el prompt) → Vega si es visual →
revisor → commit. No hace falta Nico.

## Reglas del equipo

- Una sola cosa grande por vez: no lances a Leo con dos fichas a la vez sobre el mismo juego (se pisan los archivos).
  Leo y Vega no deben editar el mismo archivo a la vez: primero uno, luego el otro.
- Nada se publica en Roblox ni se cambia en la tienda sin el «sí» explícito del usuario (CLAUDE.md §15).
- Si dos agentes no están de acuerdo, enseña al usuario las dos posturas en 2 líneas y recomienda una.
- Coste: cada agente empieza de cero y lee mucho. Para cambios pequeños (un texto, un número) hazlo tú directamente.
