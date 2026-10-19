---
name: libro-revisar
description: Revisa y corrige capítulos de un libro en español como lo haría un editor profesional, en pasadas separadas — estructura de la escena, edición de estilo línea a línea y corrección ortotipográfica (RAE: diálogos con raya, tildes, dequeísmo, gerundios…) — apoyándose en analizar_texto.py, que mide legibilidad INFLESZ, ritmo de frases, repeticiones, muletillas, clichés, giros de texto de IA y emociones «dichas». Úsala después de escribir cada capítulo, cuando el usuario diga "revisa", "corrige", "mejora este capítulo", "pásalo a limpio", "¿está bien escrito?", o pegue un texto suyo de ficción para mejorarlo.
---

# libro-revisar — el editor

> **Rutas**: en Claude Code los scripts están en `.claude/skills/<skill>/`; en claude.ai están en la carpeta de esta
> skill (súbela como .zip) y el libro se guarda en archivos de la conversación con la misma estructura.

Escribir y revisar son tareas distintas: **nunca entregues un capítulo sin al menos una pasada de revisión**.

## Herramienta

`python3 -I .claude/skills/libro-revisar/analizar_texto.py <capítulo.md | carpeta del libro> [--salida informe.md]`
→ legibilidad INFLESZ (55–65 normal, 65–80 bastante fácil: lo habitual en novela juvenil/comercial),
longitud y variación de frases, -mente/gerundios/pasivas por 1.000 palabras y avisos con número de línea:
diálogos mal puntuados, dequeísmo, giros de IA, muletillas, emociones nombradas, repeticiones, verbos
filtro, frases > 45 palabras y verbos de habla llamativos. Con una carpeta, tabla por capítulo (ritmo del libro).
Es una ayuda: decide tú cada aviso en contexto (una anáfora o una repetición buscada están bien).

## Las 4 pasadas (en este orden; no mezcles)

1. **Estructura (la escena funciona)** — Para cada escena: ¿quién quiere qué, qué se lo impide, qué cambia
   al final? ¿Empieza tarde y acaba pronto? ¿El capítulo termina con un gancho o una pregunta? ¿Hay
   información que el lector aún no necesita (fuera) o le falta algo para entender (dentro)? ¿Cuadra con
   `BIBLIA.md` (personajes, voz, reglas del mundo, línea temporal)? Si una escena no cambia nada, se corta o
   se fusiona.
2. **Estilo (línea a línea)** — Ejecuta el analizador y trabaja sus avisos más:
   - Concreto mejor que abstracto («olía a gasolina y a pan quemado» > «olía raro»).
   - Mostrar emociones con cuerpo, acción y diálogo; nombrarlas solo cuando aporte (rapidez, tono).
   - Verbos fuertes en vez de verbo + adverbio («susurró» > «dijo en voz baja»; «corrió» > «fue rápidamente»).
   - Cortar verbos filtro, muletillas, clichés y giros de IA (lista en el analizador). Nada de moralejas
     explicadas ni resúmenes de lo que el lector acaba de leer.
   - Ritmo: mezcla frases cortas y largas; frase corta para el golpe, larga para la calma o la descripción.
   - Diálogo: cada personaje suena distinto (vocabulario, longitud, muletillas propias de la BIBLIA);
     «dijo» es invisible y está bien; mejor una acción que una acotación.
   - Punto de vista: no saltes de cabeza dentro de una escena; el narrador solo sabe lo que su POV sabe.
3. **Corrección (RAE)** — Diálogos con raya (—): `—Hola —dijo Ana—. ¿Vienes?` (sin espacio tras la raya
   de apertura; acotación en minúscula si es verbo de habla; punto después de la raya de cierre). Tildes
   («solo» y los demostrativos van sin tilde por norma general; la RAE solo la admite si hay ambigüedad), «por qué/porque/porqué», dequeísmo y
   queísmo, gerundio de posterioridad, leísmo, concordancias, mayúsculas en días/meses (minúscula), números
   en letra en narrativa, comillas «angulares» para citas dentro del texto, cursiva para pensamientos o
   palabras extranjeras (en Markdown `*así*`).
4. **Lectura final en voz alta (mental)** — Lee el capítulo entero de seguido buscando tropiezos de ritmo,
   repeticiones de sonido y frases que no se entienden a la primera. Luego vuelve a pasar el analizador.

## Cómo entregar la revisión

- Si el texto es **mío** (lo escribí con `libro-escribir`): aplico los cambios directamente y doy un
  resumen corto de qué mejoró (antes/después del analizador: INFLESZ, avisos por 1.000 palabras).
- Si el texto es **del usuario**: no reescribo su voz. Devuelvo (a) el texto corregido con los cambios
  mínimos de corrección (pasada 3) y (b) una lista priorizada de sugerencias de estilo (máx. 10, con
  ejemplo antes → después y el porqué), y le pregunto si aplico las de estilo.
- Guarda el informe en `libros/<libro>/revision/<capítulo>.md` y anota en `ESTADO.md` el capítulo como
  «revisado».
- Si encuentras incoherencias con la BIBLIA, corrige el capítulo o actualiza la BIBLIA (y dilo).
