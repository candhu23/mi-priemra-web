---
name: libro-escribir
description: Escribe los capítulos de un libro en español con oficio de novelista — sigue la biblia y la escaleta, construye cada escena con objetivo, conflicto y cambio, muestra en vez de explicar, da a cada personaje su voz, cuida el ritmo y los ganchos, puntúa los diálogos con raya según la RAE y evita clichés y frases de texto genérico — y al terminar cada capítulo lo revisa y actualiza la memoria del libro. Úsala cuando el usuario pida escribir un libro, una novela, un cuento, un capítulo o "sigue con el siguiente capítulo".
---

# libro-escribir — redactar con oficio

## Antes de cada capítulo (obligatorio)

1. Lee `BIBLIA.md` (voz + muestra, personajes que salen, registro de continuidad, pistas pendientes) y la
   fila del capítulo en `PLAN.md`. Lee también el final del capítulo anterior (último párrafo y gancho).
2. Escribe para ti (no en el libro) 3 líneas: qué quiere el POV en este capítulo, qué se lo impide y qué
   habrá cambiado al final. Si no lo tienes claro, el capítulo no está listo para escribirse.

## Al escribir: reglas de oficio

**Escenas**
- Entra tarde y sal pronto: empieza con algo ya en marcha (acción, diálogo, detalle extraño), no con el
  despertar, el tiempo o un resumen. Termina en el giro o en una pregunta, no en la calma posterior.
- Cada escena: objetivo → obstáculo → resultado (normalmente peor: «sí, pero…» o «no, y además…»).
- Alterna escena (acción en tiempo real) y secuela (reacción, decisión) para controlar el ritmo.

**Mostrar, no contar (con medida)**
- Emociones a través del cuerpo, la acción y lo que se dice/calla. Nómbralas solo para ir rápido.
- Detalle concreto y específico de los sentidos (uno o dos bien elegidos, no inventarios). Sustantivos y
  verbos precisos antes que adjetivos y adverbios.
- Nada de explicar lo que el lector ya entiende, ni moralejas, ni resúmenes al final del capítulo.

**Personajes y diálogo**
- El diálogo es acción: cada réplica quiere algo, esconde algo o cambia la relación. Fuera saludos y
  relleno («Hola, ¿qué tal?» solo si dice algo).
- Cada personaje suena distinto (usa los rasgos de habla de la BIBLIA). Los niños no hablan como adultos.
- Información de fondo (exposición): en pequeñas dosis, cuando el lector la necesite, nunca como
  conversación del tipo «como ya sabes…».
- Un solo punto de vista por escena; el narrador no sabe lo que su POV no sabe.

**Ritmo y prosa**
- Varía la longitud de las frases; frase corta para el golpe. Párrafos cortos en la acción.
- Evita: muletillas («de repente», «se dio cuenta de que», «no pudo evitar»), clichés («el corazón le
  latía con fuerza»), verbos filtro («vio que», «notó que»), y los giros de texto genérico de IA («tapiz»,
  «danza de», «testamento de», «no era solo X, era Y», «nada volvería a ser igual»). Si una frase suena a
  frase hecha, cámbiala por algo que solo pueda decir este libro.
- Respeta la voz de la muestra de la BIBLIA (persona, tiempo verbal, tono, vocabulario para la edad).

**Español correcto (RAE)**
- Diálogo con raya: `—¿Vienes? —preguntó Ana—. Te espero abajo.` Sin espacio tras la raya de apertura;
  verbo de habla en minúscula; punto tras la raya de cierre si sigue la frase del personaje.
- Comillas angulares «» para citas o palabras dentro de la narración; cursiva (`*…*`) para pensamientos
  literales y extranjerismos. Números en letra en narrativa. Sin dequeísmo ni gerundio de posterioridad.

## Después de cada capítulo (obligatorio, en este orden)

1. Guarda en `libros/<libro>/capitulos/NN-titulo.md` (encabezado `# Capítulo N: Título`).
2. Revisa con la skill **`libro-revisar`** (analizador + pasadas) y aplica las mejoras.
3. Actualiza la **BIBLIA** (registro de continuidad, línea temporal, pistas, glosario) y ejecuta
   `comprobar_continuidad.py`.
4. Actualiza `ESTADO.md` (borrador ✅, revisado ✅, palabras).
5. Cada 3–5 capítulos (y al final), pasa el **lector beta** (`libro-lector`).
6. Al usuario: un resumen de 2–3 líneas de lo que pasa (sin destripar si no quiere), las palabras, y si
   hay alguna decisión que debe tomar él. Si pide leerlo, envíale el archivo.

## Si el usuario pide un libro entero de una vez

Hazlo por fases y enséñale cada una: biblia → plan → capítulos 1–3 (para validar voz y tono) → resto.
Nunca escribas todo el libro sin que haya validado la voz con los primeros capítulos.
