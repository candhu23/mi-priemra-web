---
name: libro-lector
description: Pasa un libro (o unos capítulos) por un lector beta independiente que lee SOLO los capítulos, como un lector real del público objetivo, y da una opinión honesta con citas — enganche por capítulo, dónde dejaría de leer, qué no se entiende, si los personajes importan, qué cree que pasará — y convierte esa opinión en una lista priorizada de mejoras que se aplican con libro-escribir/libro-revisar. Úsala cada 3–5 capítulos, al terminar un libro, o cuando el usuario pregunte "¿está bien?", "¿engancha?", "¿qué le falta?", "¿le gustará a un niño/adolescente?".
---

# libro-lector — la opinión de un lector de verdad

> **Rutas**: en Claude Code los scripts están en `.claude/skills/<skill>/`; en claude.ai están en la carpeta de esta
> skill (súbela como .zip) y el libro se guarda en archivos de la conversación con la misma estructura.

Quien escribe sabe demasiado: rellena huecos que el lector no puede rellenar. Por eso el lector beta
**no ve** la BIBLIA ni el PLAN, solo los capítulos.

## Pasos

1. Decide qué leer: los capítulos nuevos desde la última lectura (o el libro entero al final) y el
   **lector objetivo** (de la BIBLIA §1: edad y gustos).
2. Lanza la lectura en un contexto limpio:
   - **Claude Code**: agente `lector-beta` con el libro, los capítulos y el lector objetivo. Si quieres
     contraste, lanza dos con perfiles distintos (p. ej. «lector de 12 años que juega a videojuegos» y
     «adulto que lee mucha fantasía») y compara.
   - **Sin agentes** (claude.ai): haz una pasada aparte, olvidando el plan, leyendo solo los capítulos y
     respondiendo con el formato de abajo **antes** de mirar tus notas.
3. Guarda la respuesta en `libros/<libro>/revision/lector-caps-X-Y.md`.
4. **Triaje** (tú, como autor): compara la opinión con la BIBLIA y el PLAN.
   - Lo que el lector no entiende pero el plan sí explica → falta información en el texto (añádela en
     el momento justo, no como explicación).
   - Lo que el lector adivina demasiado pronto → pista demasiado obvia (suavízala o añade una pista falsa).
   - Lo que le aburre → recorta, empieza la escena más tarde o sube lo que está en juego.
   - Personaje que «le da igual» → dale un deseo concreto y algo que perder en la página.
5. Convierte el triaje en **máx. 5 cambios priorizados**, aplícalos (`libro-escribir` + `libro-revisar`),
   actualiza la BIBLIA si cambia algún hecho y anota en `ESTADO.md` la lectura y la nota.
6. Al usuario: nota del lector, las 2–3 cosas más importantes que dijo (con cita corta) y qué has cambiado.
   Si una mejora implica cambiar la historia (no solo la escritura), **pregúntale antes**.

## Formato de la opinión (el agente ya lo usa)

Enganche por capítulo (1–5) con ⚠️ donde dejaría de leer · lo mejor (3, con cita) · lo que me sacó de la
historia (5, por gravedad) · qué siento por cada personaje · preguntas que me hago y qué creo que pasará ·
nota global (1–10) y la única cosa que más mejoraría el texto.
