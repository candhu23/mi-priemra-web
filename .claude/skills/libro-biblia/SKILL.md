---
name: libro-biblia
description: Crea y mantiene la «biblia» de un libro — su memoria permanente con idea, voz y estilo (con un párrafo de muestra), fichas de personajes (qué quieren, qué temen, cómo hablan), mundo y reglas, línea temporal, glosario de nombres, registro de continuidad y pistas pendientes — y comprueba la continuidad de nombres en los capítulos. Úsala SIEMPRE al empezar un libro nuevo ("escríbeme un libro/novela/cuento sobre…"), antes de escribir cada capítulo (leerla) y después (actualizarla), y cuando el usuario cambie algo de un personaje o del mundo.
---

# libro-biblia — la memoria del libro

> **Rutas**: en Claude Code los scripts están en `.claude/skills/<skill>/`; en claude.ai están en la carpeta de esta
> skill (súbela como .zip) y el libro se guarda en archivos de la conversación con la misma estructura.

Un libro largo no cabe en una conversación: sin memoria escrita aparecen ojos que cambian de color,
personajes que olvidan lo que sabían y voces que se desdibujan. La biblia lo evita.

## Empezar un libro

1. `python3 -I .claude/skills/libro-biblia/crear_libro.py "<Título>"` → `libros/<titulo>/` con
   `BIBLIA.md`, `PLAN.md`, `ESTADO.md`, `capitulos/` y `revision/`.
2. Si el usuario no lo ha dicho, pregunta **solo lo imprescindible** en UNA pregunta con opciones (máx. 4):
   género, lector (edad), extensión y tono. Lo demás lo propones tú.
3. Rellena la BIBLIA con propuestas concretas (no plantillas vacías): logline, tema, narrador y tiempo
   verbal, 3–6 personajes principales con objetivo/necesidad/miedo/forma de hablar/arco, lugares con un
   detalle sensorial cada uno, reglas del mundo con límites y coste, y **un párrafo de muestra de voz**.
4. Enséñale al usuario un resumen corto (logline, protagonista, tono, muestra de voz) y pide su visto
   bueno antes de planificar (`libro-plan`). Apunta sus decisiones en `ESTADO.md`.

## Mantenerla (en cada capítulo)

- **Antes de escribir**: lee la BIBLIA entera (sobre todo voz, personajes del capítulo, registro de
  continuidad y pistas pendientes) y la fila del capítulo en `PLAN.md`.
- **Después de escribir**: añade al **registro de continuidad** los hechos que ya no pueden cambiar
  (heridas, objetos, quién sabe qué, promesas, fechas), actualiza la línea temporal, anota pistas plantadas
  y pagadas, y documenta personajes/lugares nuevos en el glosario.
- **Comprueba**: `python3 -I .claude/skills/libro-biblia/comprobar_continuidad.py libros/<libro>` →
  nombres no documentados, nombres casi iguales (¿errata?) y personajes olvidados.
- Si el usuario cambia algo (nombre, edad, regla), cámbialo en la BIBLIA **y** busca y corrige todas las
  apariciones en los capítulos ya escritos (`grep`), y dilo.

## Calidad de una buena biblia (revísalo)

- Cada personaje principal quiere algo concreto **y** necesita algo distinto que aún no sabe.
- Cada personaje tiene una forma de hablar reconocible (2–3 rasgos: frases cortas, muletilla, registro).
- Cada regla del mundo tiene un límite o un precio (si no, no genera conflicto).
- El tema es una pregunta, no una moraleja.
