# Prompt para Claude Code: clon de mecánicas de «Librarian: Tidy Up the Arcane Library!» para Roblox

> Copia TODO lo que hay debajo de la línea y pégalo como primer mensaje en una sesión nueva de Claude Code
> sobre el repo `candhu23/mi-priemra-web`.

---

Vas a crear un **juego nuevo de Roblox** (el tercero de este repo) que replique **con la máxima fidelidad
las mecánicas, los números y la estructura** del juego de Steam **«Librarian: Tidy Up the Arcane Library!»**
(ArtRising, 30-04-2026, ~6 $, 93 % de reseñas positivas). Lo que tiene derechos de autor tiene que ser
**original**: nombre, textos, títulos de libros, personajes, arte, música y logotipo. Cambia **solo lo justo**:
lo que obliga la ley, lo que obliga Roblox (normas, móvil, sesiones cortas, rendimiento) y nada más.

## 0. Antes de escribir código

1. Lee entero el `CLAUDE.md` de la raíz, sobre todo **§2 (cómo es el usuario), §8 (verificación), §9 (trampas
   de Luau/Roblox), §10 (publicar) y §11 (normas de Roblox)**. Lee también `roblox-carga-aerea/CLAUDE.md`
   como ejemplo de estructura con `Lang.luau` (textos ES/EN).
2. Crea la carpeta **`roblox-biblioteca/`** con la misma organización que los otros juegos: proyecto Rojo
   (`default.project.json`), `src/`, `tools/` (copia y adapta `setup.sh` y `check.sh` de
   `roblox-imperio-web/tools/`: luau-lsp, luau-compile, rojo 7.4.4, lune 0.10.4), `README.md` para el usuario
   y **`roblox-biblioteca/CLAUDE.md`** con todo el contexto del juego. Añade el juego a la tabla §0 del
   `CLAUDE.md` raíz.
3. Trabaja en la rama que te asigne el sistema (si no te asigna ninguna, crea `claude/biblioteca-arcana`) y
   apunta la rama en los dos `CLAUDE.md`.
4. Escribe primero **`roblox-biblioteca/DISENO.md`**: todas las reglas y números de este prompt, cada valor que
   tengas que inventar marcado como **(supuesto)**, y la tabla «original → nuestra versión» de la §2.
   Enséñale al usuario un resumen y empieza la Fase 1 sin esperar (no bloquees por detalles menores).

## 1. Qué es el juego original (resumen de la investigación)

- **Simulador de ordenar en primera persona**, tranquilo, de 1 jugador. Un **hada traviesa** ha desordenado la
  biblioteca de una universidad de magia; el **director** te deja una carta: no puedes salir hasta devolver los
  **3.072 libros** a su sitio (te promete **pizza** como premio). La historia es solo el pretexto.
- Duración: 3–4 h con magia; un primer intento normal, 4–10 h; sin magia, 9–12 h.
- **Estructura exacta:** 2 plantas, **31 secciones** (planta 1: 1A–1N; planta 2: 2A–2Q), **400 series = 400 filas**,
  **3.072 libros**. Cada serie tiene **10, 5 o 3 tomos**. Las series de 10 van en estanterías largas
  (filas de 10 huecos); las de 5 y 3, en estanterías cortas.
- Ordenar tiene 3 capas: **sección correcta → toda la serie junta en una fila → tomos en orden 1…N de izquierda
  a derecha**. Dentro de una sección da igual qué serie va en qué fila (no hay orden alfabético).
- Pistas para saber la sección: **palabras clave del título** (lo fiable) y **diseño de portada** (orientativo):
  blancos = sanación / sagrada / filosofía; negros con letras rojas = nigromancia / maldiciones; rojo oscuro =
  psicología; marrones = monstruos; cristales y estrellas = astrología; gemas = libros de hechizos; morados y
  azules = ilusión / invocación. Algunos colores se solapan **a propósito** para que haya que leer el título.
- Hay **prefijos de serie** que también dan pistas de longitud: «Libro de hechizos: Fuego – Novato» (los rangos
  Novato/Adepto/Experto son de 10 tomos; Maestro/Legendario, de 5); «Libros de alquimia: …» (10) frente a
  «Tomos de alquimia: …» (5); «Novela romántica: …», «Ficción de misterio: …», etc.
- Los títulos son **parodias con humor** («¿Por qué las acciones caen justo cuando las compro?», «Psicología de
  preferir jugar a ordenar tu cuarto»). Ese tono es parte del encanto: mantenlo, pero con textos tuyos.
- **Feedback al colocar:** brillo **dorado** = el libro está bien; brillo **rojo tenue** = sección correcta pero
  posición, longitud de estantería o serie mal. Cuando **todas** las filas de una sección están bien, su
  **placa se pone azul** y suena un aviso. Que un libro «encaje» en un hueco no significa que la fila esté bien.
- **Progreso:** contador de **filas correctas (x/400)** arriba y de **libros colocados en estanterías (x/3.072)**
  abajo; se indica cuántas filas faltan para el siguiente punto.
- **Magia mayor (5 hechizos)**: se compran y suben de nivel con **puntos** que dan las filas completadas, en un
  **«manual personal»**. Se activan a mano (teclas 1–5), duran un rato y tienen enfriamiento; subir de nivel
  alarga la duración y acorta el enfriamiento.
- **Magia menor (4 llaves → 4 cofres)**: salto alto, correr, +3 y +2 de capacidad. Al principio **no puedes
  saltar ni correr** y llevas **10 libros**; con todo, 15.
- **Mapas** de las secciones en la pared al pie de la escalera de cada planta. **Una sola escalera**. Desde la
  planta 2 se pueden **tirar libros por la barandilla** a la planta 1.
- **Cristal/podio de recuperación** en el rellano de la escalera: devuelve hasta **20 libros perdidos** (no cuenta
  como magia). Los libros que caen fuera del mapa vuelven a su sitio inicial.
- **Puerta de salida:** solo se abre cuando los 3.072 libros están **en estanterías** (bien o mal). Al salir, el
  director evalúa la partida (velocidad, magia usada, llaves, filas correctas, mejor tiempo) con **6 rangos**,
  desde «¡Despedido!» hasta el mejor. Finales: **Normal, Sin magia, Pizza** y el chiste de **colocarlo todo mal**.
- **Fase especial** (se desbloquea en el menú de título tras terminar): hay que esperar a que cargue la habilidad
  **definitiva** (tecla Z, unos 10 min), que coloca sola todos los libros. Su tiempo no cuenta como récord.
- **12 logros** (ver §3.13). **Modo acogedor**: oculta el cronómetro y para el cambio de luz con el tiempo.
- **Ambiente:** madera, mesas, bancos, jarrones, lámparas, «destellos» mágicos; pasos y golpe sordo de los libros;
  música calmada y etérea que **cambia según se llenan las estanterías**.
- Autoguardado al: completar una fila, aprender una magia menor, salir, volver al menú y cada 50 libros colocados.
  Tiene ranuras de guardado.
- Críticas de los jugadores (no las «arregles» salvo que el usuario lo pida; apúntalas en `DISENO.md` como
  opciones): las letras de las secciones van en zigzag, solo hay una escalera y el principio es lento.

## 2. Qué se copia y qué se cambia

| Se copia tal cual (mecánica y números) | Se cambia (obligatorio) |
|---|---|
| 2 plantas, 31 secciones con sus códigos 1A–2Q y sus temas, 400 filas, 3.072 libros, tomos 10/5/3 | **Nombre del juego**: nada de «Librarian» ni «Arcane Library». Propuesta: *Estanterías Hechizadas* / *Spellbound Shelves* (en `Config.GAME_NAME`, fácil de cambiar) |
| Reglas de validación, brillos dorado/rojo, placa azul, contadores | **Los 400 títulos**: todos inventados por ti, en español e inglés, con el mismo tipo de pistas y humor |
| Las 5 magias mayores, teclas 1–5, niveles, enfriamientos | **Personajes y lugar**: el hada → otro personaje travieso; el director (en el original, «Merlin») y la universidad (*Celesthall*) → nombres nuevos |
| 4 llaves/cofres con las mismas recompensas, capacidad 10→15 | **Arte y portadas**: diseños propios (no copies capturas ni iconos); llaves con formas/colores propios |
| Cristal de recuperación, puerta, evaluación con 6 rangos, finales, fase especial, Z | **Textos** de cartas, rangos y logros: escritos por ti |
| Modo acogedor, cambio de luz con el tiempo, música que evoluciona | **Música y sonidos**: solo audio con licencia de la Creator Store de Roblox (IDs en `Config`, 0 = sin sonido) |
| Primera persona, sin saltar ni correr al inicio | **Humor apto para todos**: nada de chistes de caca, insinuaciones (súcubos, «seducción») ni palabrotas, para que el cuestionario de Roblox salga «Mínimo» |
| Duración y ritmo (sin atajos de pago que rompan el reto) | **Plataforma**: controles táctiles y de mando, guardado en la nube, 1 jugador por servidor, logros → insignias de Roblox, rendimiento (ver §4) |

En la ficha de Roblox **no menciones** el juego original ni a ArtRising.

## 3. Especificación detallada

### 3.1 Inicio e historia
- Apareces en la entrada de la planta 1. Cerca, una **carta del director** (historia + reglas + «habrá pizza») y
  un **montón de inicio** con **2 series muy reconocibles** (p. ej. una con un búho blanco en la portada) de la
  sección 1A, para aprender: cógelas, colócalas en orden y mira cómo la fila brilla y la placa se pone azul.
- La puerta, si intentas salir antes de tiempo, avisa de que no puedes irte hasta que todo esté en estanterías.
- Encima de cada cofre cerrado hay un **cuadro/foto** que insinúa dónde está su llave (pista ambiental).

### 3.2 Las 31 secciones (datos exactos del original; los nombres de tema puedes redactarlos a tu manera)

**Planta 1 — magia y criaturas** (176 series, 1.456 libros)

| Código | Tema | Series de 10 | de 5 | de 3 | Libros |
|---|---|---|---|---|---|
| 1A | Monstruología | 12 | – | – | 120 |
| 1B | Astrología y adivinación | 12 | – | – | 120 |
| 1C | Maldiciones y cómo romperlas | 4 | – | 8 | 64 |
| 1D | Bardos y música mágica | 4 | – | 8 | 64 |
| 1E | Nigromancia | 12 | – | – | 120 |
| 1F | Transfiguración | 12 | – | – | 120 |
| 1G | Artefactos mágicos y encantamientos | 4 | – | 8 | 64 |
| 1H | Sigilo e invisibilidad | 4 | – | 8 | 64 |
| 1I | Ilusiones | 12 | – | – | 120 |
| 1J | Invocación | 12 | – | – | 120 |
| 1K | Sanación | 8 | – | – | 80 |
| 1L | Magia sagrada | 8 | – | – | 80 |
| 1M | Magia destructiva («Libros de hechizos» por elemento y rango) | 12 | 8 | – | 160 |
| 1N | Alquimia y pociones | 12 | 8 | – | 160 |

**Planta 2 — oficios, sociedad, ficción y estudio** (224 series, 1.616 libros)

| Código | Tema | Series de 10 | de 5 | de 3 | Libros |
|---|---|---|---|---|---|
| 2A | Guerreros | 12 | – | – | 120 |
| 2B | Tiro con arco | 12 | – | – | 120 |
| 2C | Magia cotidiana | 6 | – | 12 | 96 |
| 2D | Matemáticas mágicas | 6 | – | 12 | 96 |
| 2E | Arte | 12 | – | – | 120 |
| 2F | Gestión de gremios | 12 | – | – | 120 |
| 2G | Economía | 6 | – | 12 | 96 |
| 2H | Sociología | 6 | – | 12 | 96 |
| 2I | Psicología | 12 | – | – | 120 |
| 2J | Filosofía | 12 | – | – | 120 |
| 2K | Derecho | 6 | – | 12 | 96 |
| 2L | Novela romántica | 6 | – | 12 | 96 |
| 2M | Novela de misterio | 4 | 4 | – | 60 |
| 2N | Historia | 4 | 4 | – | 60 |
| 2O | Viajes a otros mundos (parodia: un mundo sin magia con «wifi» e «internet») | 4 | 8 | – | 80 |
| 2P | Mazmorras | 4 | 4 | – | 60 |
| 2Q | Idiomas (élfico, enano, dracónico…) | 4 | 4 | – | 60 |

**Totales que el código debe comprobar con `assert`:** 256 series de 10 + 40 de 5 + 104 de 3 = **400 series**;
2.560 + 200 + 312 = **3.072 libros**; 128 series de 10 en cada planta.

- **Colocación física:** las secciones de letra impar a un lado de la planta, las pares al otro, y otras en la
  pared del fondo (así es el original: el orden de letras hace zigzag). Cada sección es un mueble con su
  **placa** (código + tema), y tiene **exactamente** una fila por serie: filas largas de 10 huecos para las series
  de 10 y estantes cortos de 5 o 3 huecos para las demás.
- La planta 2 es una galería con **barandilla** desde la que se ve y se puede tirar a la planta 1. Una sola
  escalera, con un **rellano trasero** donde está el **podio con el cristal de recuperación**.
- **Mapa** de cada planta en la pared, al pie de la escalera (y accesible también desde la interfaz con el
  mismo dibujo, porque en el móvil cuesta leer carteles).
- Los libros empiezan **desordenados** en montones por el suelo, en mesas, bancos y escaleras, en las dos plantas
  (también libros de la planta 1 arriba y al revés). Cada tomo tiene un **sitio inicial fijo** (generado con una
  semilla: todas las partidas empiezan igual), y nunca empiezan dos tomos seguidos de la misma serie juntos.

### 3.3 Libros y títulos (`BookData.luau`)
- 400 series con: `id`, `section`, `volumes` (10/5/3), `title = { es = "...", en = "..." }`, `cover`
  (color base, color de letra, franja/símbolo). Escríbelos **tú**, con humor parecido al original y apto para
  todos. Cada título lleva **palabras clave** de su sección (p. ej. Nigromancia: «no-muertos», «esqueletos»,
  «almas»; Economía: «mercado», «impuestos», «monedas de maná»).
- Usa prefijos de serie como en el original: «Libro de hechizos: Fuego – Novato/Adepto/Experto» (10 tomos) y
  «… – Maestro/Legendario» (5) en 1M; «Libros de alquimia: …» (10) y «Tomos de alquimia: …» (5) en 1N;
  «Novela romántica: …» en 2L; «Ficción de misterio: …» en 2M.
- Portadas con la lógica de colores de §1 (incluidos los solapamientos a propósito). Cada serie distinguible de
  sus vecinas. El **número de tomo** visible en el lomo de cerca y siempre en la lista de libros en mano.
- Script de comprobación (en `tools/`): títulos únicos, ES y EN presentes, longitud máxima, recuentos de la
  tabla y una lista de palabras prohibidas.

### 3.4 Coger, llevar y colocar
- **Mira con la cruceta** (raycast desde el centro de la cámara, alcance ~10 studs): resalta en **verde** el
  hueco o libro donde puedes actuar y en **rojo** si está bloqueado.
- **Coger** (clic izq. / E / botón táctil): coge 1 libro (del suelo, de una mesa o de una estantería) y lo pone
  **encima** de tu pila. Se pueden sacar libros de las estanterías para rehacer filas.
- **Colocar**: con la cruceta en un hueco libre, coloca el libro **de arriba** de tu pila.
- **Soltar** (R): deja el libro de arriba en el suelo delante de ti; **manteniendo R** sueltas toda la pila en
  un montón ordenado. **Lanzar** (F / botón táctil; tecla supuesta, el original no la documenta): tira el libro
  de arriba en arco (sirve para bajarlos por la barandilla).
- **Reordenar a mano** (clic dcho.) y **lista de libros en mano** (Tab): título, tomo y sección de cada libro.
- **Capacidad**: 10 libros; +3 y +2 con los cofres (máx. 15).
- Movimiento: andar lento al principio y **sin poder saltar** (anula el salto por defecto de Roblox hasta tener
  la llave). Salto alto: suficiente para subir de un salto a la planta 2 desde algún punto concreto. Correr con
  Mayús. Velocidades en `Config` (supuesto: andar 12, correr 22).

### 3.5 Validación
- **Fila correcta** = todos sus huecos llenos con tomos 1…N de **la misma serie**, en orden, la serie es de esa
  sección y la longitud de la estantería coincide con la de la serie.
- Por libro, al colocarlo: **dorado** si su sección es la de la estantería, la longitud coincide, su hueco es el de
  su tomo y no hay en la fila libros de otra serie; **rojo tenue** si la sección es correcta pero falla lo demás;
  sin brillo si la sección es otra. (Esta regla exacta es una **deducción** de las guías: apúntalo como supuesto.)
- La **placa** de una sección se pone **azul** (con sonido) cuando todas sus filas son correctas, y vuelve a
  apagarse si deshaces una fila.
- Contadores en pantalla: filas correctas x/400, libros en estanterías x/3.072 y «faltan N filas para el
  siguiente punto».

### 3.6 Puntos y magia mayor (el «manual personal»)
- Los puntos se ganan con filas correctas. Original: al principio **1 punto cada 2 filas** y luego cada vez cuesta
  más; con unas 200–250 filas se puede tener todo al máximo. Supuesto (en `Config`): filas 1–20 → 1 punto cada 2;
  21–80 → cada 4; 81–200 → cada 6 (45 puntos en total, justo lo que cuesta subirlo todo al máximo).
- **Contra trampas:** los puntos se dan por el **récord de filas correctas alcanzado**, no cada vez que una fila se
  rompe y se rehace.
- Cada nivel cuesta 1 punto. El primer nivel compra el hechizo. Se pueden comprar en cualquier orden.
- Valores (el **máximo** sale de las guías del original; los niveles intermedios son **supuestos** que debes
  interpolar):

| Tecla | Hechizo | Qué hace | Niv. máx. | Duración o efecto (niv. 1 → máx.) | Enfriamiento (niv. 1 → máx.) |
|---|---|---|---|---|---|
| 1 | **Ordenar** | Ordena tu pila por serie y número de tomo | 5 | instantáneo | 30 s → **5 s** |
| 2 | **Guía de estantería** | Resalta la estantería del libro de arriba de tu pila | 10 | 15 s → **60 s** | 60 s → **5 s** |
| 3 | **Revelar** | Hace brillar los demás tomos de la serie del libro de arriba (alcance que crece con el nivel; mientras está activo puedes cambiar de serie) | 10 | 10 s → **40 s** | 60 s → **20 s** |
| 4 | **Autocolocar** | Mientras está activo, cada pulsación apuntando a una sección coloca en sus filas correctas todos los libros que lleves de esa sección (falla si no llevas ninguno) | 10 | 10 s → **55 s** | 120 s → **10 s** |
| 5 | **Reunir** | Atrae a tu mano otros tomos de la serie del libro de arriba **desde suelo y mesas, nunca desde estanterías**, hasta llenar tu capacidad | 10 | 1 libro → **9 libros** | 90 s → **10 s** |

- Animación: los libros **vuelan** hacia ti o hacia su hueco (tween en el cliente; el servidor decide).
- Se registra en la partida si se ha **comprado o usado** alguna magia mayor (para «Sin magia» y su insignia).

### 3.7 Magia menor (4 llaves → 4 cofres)
| Llave (formas/colores tuyos) | Escondite (como en el original, adaptado a tu mapa) | Cofre da |
|---|---|---|
| Roja | En la pared, cerca del escudo de la entrada (visible al darse la vuelta al empezar) | **Salto alto** |
| Verde | Bajo un montón de libros en el primer banco a la derecha del punto de inicio (hay que despejarlo) | **Correr** |
| Amarilla | Dentro de un jarrón de la barandilla de la escalera (hay que subirse de un salto) | **Capacidad +3** |
| Azul | Encima de las estanterías del fondo de la planta 2 (junto a Mazmorras/Otros mundos; hay que saltar) | **Capacidad +2** |

- Cada cofre tiene una nota graciosa del director. La magia menor **no** cuenta como «magia» para «Sin magia».

### 3.8 Cristal de recuperación
- En el podio del rellano. Al usarlo, trae al podio hasta **20 libros** que no estén en ninguna estantería y estén
  «perdidos» (atascados, inalcanzables o lejos). No cuenta como magia. Los libros que salgan del mapa vuelven solos
  a su sitio inicial.

### 3.9 Salida, evaluación y finales
- La puerta solo se abre con los **3.072 libros en estanterías**. Al cruzarla: **pantalla de resultados** del
  director con tiempo jugado, filas correctas, magia mayor usada (sí/no), llaves encontradas, mejor tiempo y
  **rango** (6 rangos con nombres tuyos; el peor es «¡Despedido!»). Diseña los umbrales (supuesto) combinando
  % de filas correctas, tiempo y magia.
- Finales: **Normal** (400/400); **Sin magia** (400/400 sin haber comprado ni usado magia mayor); **Pizza** (no
  sabemos la condición exacta del original: supuesto = 400/400 en menos de 3 h de juego, llega la pizza
  prometida); **Despedido** (todo colocado y 0 filas correctas: nota furiosa del director).
- Solo cuentan como récord las partidas con la biblioteca entera bien ordenada (ni la fase especial ni las
  incompletas).

### 3.10 Fase especial y habilidad definitiva
- Se desbloquea en el menú de título al terminar una partida. Es una sala aparte (supuesto: un ala pequeña con
  unos 300 libros revueltos). Una barra de **habilidad definitiva** se carga con el tiempo (~10 min; supuesto: se
  carga algo más rápido mientras colocas libros). Con **Z** todos los libros vuelan a su sitio; al salir, insignia
  «sin horas extra». Si la terminas a mano no se da esa insignia.

### 3.11 Opciones, modo acogedor, luz y música
- Opciones: idioma ES/EN (por defecto según `LocaleId`), sensibilidad, campo de visión, balanceo de cabeza on/off,
  volumen de música y efectos, **modo acogedor**, controles táctiles para zurdos (espejo).
- **Modo acogedor:** oculta el cronómetro y congela la iluminación. Avisa de que la evaluación sigue contando el tiempo.
- **Luz con el tiempo:** la tarde va cayendo según tu tiempo de juego (empieza a media tarde y a las ~3 h es de noche
  cerrada, la broma de «horas extra»). `Lighting.Technology = Future` en `default.project.json`.
- **Música por capas/pistas** que cambia según el % de filas correctas (p. ej. 4 tramos). Sonidos: pasos, golpe
  sordo al soltar, «clic» al colocar, campanita al completar fila y al poner la placa azul.

### 3.12 Guardado y menú de título
- **Menú de título**: Continuar, Nueva partida, **3 ranuras**, Fase especial (si está desbloqueada), Opciones.
- Estado por ranura: dónde está cada uno de los 3.072 libros (en hueco de estantería, en el suelo con posición,
  o en tu mano), puntos, niveles, llaves y cofres, tiempo jugado, si se ha usado magia, finales e indicadores.
  Codifícalo compacto (cadena binaria/base64 o array de enteros), muy por debajo del límite de 4 MB.
- Autoguardado con los **mismos disparadores que el original** (fila completada, magia menor, salir, volver al
  menú, cada 50 libros), pero **agrupados** para respetar los límites de DataStore (1 escritura por clave cada
  6 s y el presupuesto por minuto): marca «pendiente» y guarda como mucho cada ~30 s, más al salir y en
  `BindToClose`. **Todo el DataStore en `pcall`.** Si la carga falla, no guardes (no machaques datos), igual que
  en los otros juegos del repo. En Studio sin publicar, aviso en pantalla.

### 3.13 Logros → 12 insignias de Roblox (nombres tuyos; IDs en `Config`, 0 = desactivada)
1. Primera fila correcta · 2. 50 filas · 3. 200 filas · 4. 400 filas (todas las placas azules) ·
5. Comprar la 1ª magia mayor · 6. Comprar las 5 · 7. Abrir los 4 cofres · 8. Todas las magias al máximo ·
9. Usar la definitiva en la fase especial y salir · 10. Salir con todo colocado y 0 filas correctas ·
11. Terminarlo todo bien en menos de 3 h de juego · 12. Terminarlo sin magia mayor (la menor sí vale).
Además, guarda estos logros en los datos del jugador y muéstralos en un panel del menú.

## 4. Adaptación a Roblox (lo que cambia por la plataforma)

- **1 jugador por servidor** (el original es de un jugador y la biblioteca es «tuya»). El usuario pondrá
  **Max Players = 1** en Creator Hub (compruébalo en la documentación oficial; si no se permitiera, usa
  `TeleportService:ReserveServer` para mandar a cada jugador a un servidor privado). Si entra un 2.º jugador por
  error, que no rompa nada.
- **El servidor manda:** el estado de los libros vive en el servidor; el cliente pide acciones por un
  `RemoteFunction` (`pickUp`, `place`, `drop`, `dropAll`, `throw`, `reorder`, `cast`, `buySkill`, `openChest`,
  `useCrystal`, `exitDoor`, `ultimate`, `setOption`, `selectSlot`…) y el servidor valida distancia, capacidad,
  enfriamientos y límite de acciones por segundo.
- **No mandes el estado completo cada segundo** (son 3.072 libros): una foto al entrar y luego **deltas**
  («el libro 1234 ha ido al hueco X»).
- **Rendimiento (también en móvil):** libros como `Part` sencillas y **ancladas**; nada de física real
  continuada (el lanzamiento es una parábola calculada con raycasts y animada con tween; al caer queda anclado).
  Colisión de los libros con el personaje desactivada (grupos de colisión) pero visibles para el raycast.
  Presupuesto orientativo: < 15.000 piezas en total; mídelo en el harness. Lomos con texto: **no** pongas un
  `SurfaceGui` en cada libro; usa un **grupo reutilizable** de etiquetas solo para los libros cercanos a la cámara.
  **Ojo: Roblox solo dibuja unos 31 `Highlight` a la vez**: para Revelar y Guía usa otra técnica (color neón,
  `SelectionBox` o partículas). Decide `StreamingEnabled` en `default.project.json` sabiendo que Revelar necesita
  que el cliente tenga todos los libros (lo más simple: desactivarlo, el edificio es uno).
- **Primera persona** forzada (`CameraMode = LockFirstPerson`), cruceta en el centro.
- **Controles:** PC (como el original: WASD, ratón, E/clic, R, clic dcho., Tab, 1–5, Z, Espacio, Mayús, Esc; más F para lanzar),
  **móvil** (joystick de Roblox + botones grandes: Coger/Colocar, Soltar, Lanzar, Lista, 5 hechizos con su
  enfriamiento visible, Saltar, Correr) y **mando**. Usa `ContextActionService`/`UserInputService`.
- Interfaz: discreta como el original (contadores arriba/abajo, barra de hechizos con enfriamientos, cruceta,
  aviso de «faltan N filas para el siguiente punto», lista de libros, manual, mapa, opciones), escalada para
  pantallas pequeñas.
- **Idiomas ES/EN** desde el principio (`Lang.luau` como en `roblox-carga-aerea`), también los 400 títulos.
- Insignias con `BadgeService:AwardBadge` (en `pcall`).

## 5. Verificación (obligatoria antes de cada commit; mismo sistema que los otros juegos)

`roblox-biblioteca/tools/check.sh` debe:
1. `luau-compile` de cada archivo (sintaxis y **límite de 200 variables locales por función**).
2. `luau-lsp analyze` con las definiciones de Roblox → **0 avisos**.
3. Comprobar `BookData` (recuentos de §3.2, títulos únicos, ES/EN, palabras prohibidas).
4. Harness de Lune del mundo: construye la biblioteca real y comprueba 31 secciones, 400 filas con su número de
   huecos, 3.072 libros, piezas totales y que no hay libros dentro de paredes.
5. Harness del servidor con un **bot** que juega: coge y coloca **todo** bien (teletransportándose cerca),
   compra magias, abre cofres, usa el cristal, guarda a mitad, sale, vuelve a entrar y comprueba que **el estado
   cargado es idéntico**; acaba con 400/400, 45 puntos, puerta abierta, rango y final correctos. Segundo bot que lo
   coloca **todo mal** → final «Despedido». Tercer bot: fase especial con la definitiva. Debe terminar en `TODO OK`.
6. Harness del cliente: crea toda la interfaz con un estado real y pulsa todos los botones (PC y móvil). `CLIENTE OK`.
7. `rojo build` → `roblox-biblioteca/Biblioteca.rbxl` (solo si todo pasa). **Súbelo en cada commit.**

## 6. Fases (haz commit + push al final de cada una y avisa al usuario)

1. **Datos y documentos:** `DISENO.md`, `CLAUDE.md`, herramientas, `Config`, `Lang`, `BookData` con los 400 títulos.
2. **La biblioteca:** generador del edificio (2 plantas, escalera, galería, barandilla, 31 secciones con placas,
   mapas, mesas, bancos, jarrones, puerta, podio con cristal, cofres) y los 3.072 libros en sus montones iniciales.
3. **Bucle principal:** primera persona, coger/llevar/colocar/soltar/lanzar/reordenar, validación, brillos,
   placas, contadores, carta y montón de inicio. **Aquí el juego ya debe ser jugable** (avisa al usuario para que
   lo pruebe en Studio).
4. **Progresión:** puntos, manual, las 5 magias con niveles, llaves y cofres, cristal.
5. **Partida completa:** guardado y ranuras, menú de título, opciones, modo acogedor, luz, música, puerta,
   evaluación, finales, insignias, fase especial.
6. **Plataforma y pulido:** controles táctiles y de mando, rendimiento, revisión ES/EN, `README.md` para el usuario.
7. **Monetización (solo si el usuario lo aprueba):** el original es de pago y no vende ventajas. Propón opciones que
   **no rompan el reto** (p. ej. objetos cosméticos o un pase de apoyo) con IDs en `Config` (0 = oculto). Nada
   aleatorio de pago. Pregunta antes de añadir nada.

## 7. Lo que no sabemos del original (decide tú, ponlo en `Config` y márcalo como supuesto en `DISENO.md`)
Tabla exacta de puntos por fila; niveles intermedios de cada hechizo; los niveles máximos de Revelar y Guía (¿10?);
la condición exacta del final Pizza; los umbrales de los 6 rangos; el contenido de la fase especial; la planta
exacta del edificio; las velocidades de andar y correr; la capacidad inicial (las reseñas dicen 10, alguna guía
da otra cifra). Si un dato del original y este prompt chocan, gana la jugabilidad descrita aquí.

## 8. Cómo trabajar con el usuario
- Habla en **español**, sin jerga. El usuario **no programa**, usa **Windows** y **Roblox Studio**, te enviará
  capturas. Tú no puedes abrir Studio: dile qué has verificado con las herramientas y qué no.
- En **cada** respuesta: tu **% de confianza** y **qué información te falta**. Sé conservador.
- Al terminar cada fase, dale pasos de **clic en clic** para probar: descargar el `.rbxl`
  (`https://github.com/candhu23/mi-priemra-web/raw/<rama>/roblox-biblioteca/Biblioteca.rbxl`), abrirlo en Studio,
  Play, qué mirar.
- Para publicar, en el `README.md`: **File → Publish to Roblox As… → experiencia NUEVA** (¡que **no** reemplace
  *Web Empire Tycoon*!), activar *Enable Studio Access to API Services*, **Max Players = 1**, crear las 12
  insignias (5 gratis cada 24 h por experiencia; después cuestan 100 Robux cada una, así que en 3 días salen
  gratis), cuestionario de contenido y descripción (sin mencionar el juego original).
- Commits en español, sin identificadores de modelos de IA, con las líneas de atribución que indique el sistema.
  No abras PR salvo que el usuario lo pida.
