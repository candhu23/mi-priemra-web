# DISEÑO — «Estanterías Hechizadas» (*Spellbound Shelves*)

Juego de Roblox de **ordenar libros en primera persona**, tranquilo y de **1 jugador por servidor**.
Reproduce con la máxima fidelidad posible las **mecánicas, números y estructura** de un simulador de
biblioteca mágica publicado en Steam en 2026. Todo lo que tiene derechos de autor es **nuestro**:
nombre, textos, los 400 títulos, personajes, arte y logotipo. En la ficha de Roblox **no se menciona**
el juego original ni a su estudio.

> **Cómo leer este documento.** Los valores marcados **(supuesto)** no se conocen del original: son
> decisiones nuestras, están en `src/ReplicatedStorage/Config.luau` y se pueden cambiar en un solo sitio.
> Si un dato del original choca con la jugabilidad descrita aquí, gana lo descrito aquí.

---

## 1. Resumen

- Un **gato alado travieso, Garabato**, ha tirado al suelo todos los libros de la **Biblioteca de la
  Academia Brumaluna**. La **rectora Ofelia Tintero** te deja una carta: no puedes salir hasta devolver los
  **3.072 libros** a una estantería. Promete **pizza**.
- **2 plantas, 31 secciones (1A–1N y 2A–2Q), 400 series = 400 filas, 3.072 libros.** Cada serie tiene
  10, 5 o 3 tomos. Ordenar = **sección correcta → serie entera en una fila → tomos 1…N de izquierda a derecha**.
- Puntos por filas correctas → **5 magias mayores** (teclas 1–5). **4 llaves → 4 cofres** (salto alto,
  correr, +3 y +2 de capacidad). **Cristal** que recupera libros perdidos. **Puerta** que solo se abre con
  todo en estanterías → **evaluación con 6 rangos** y **finales** (Normal, Sin magia, Pizza, Despedido).
- Duración del original: 3–4 h con magia; 4–10 h un primer intento; 9–12 h sin magia. **Mantenemos el ritmo**:
  no hay atajos de pago que rompan el reto.

## 2. Original → nuestra versión

| Del original (se copia la mecánica) | Nuestra versión (cambia por ley o por Roblox) |
|---|---|
| Nombre del juego | **Estanterías Hechizadas / Spellbound Shelves** (`Config.GAME_NAME`) |
| Hada traviesa que desordena | **Garabato**, un gato alado (*Scribble*) |
| Director «Merlin» | **Rectora Ofelia Tintero** (*Headmistress Ophelia Inkwell*) |
| Universidad «Celesthall» | **Academia Brumaluna** (*Mistmoon Academy*) |
| 400 títulos (parodias con humor) | **400 títulos nuevos** escritos por nosotros, ES y EN, con el mismo tipo de pistas y humor apto para todos |
| Arte, portadas, iconos, llaves | Portadas por **paletas propias** (color base + franja + símbolo); llaves de formas/colores propios |
| Música y sonidos | Solo audio con licencia: **Creator Store de Roblox** o sonidos incluidos en Roblox (`rbxasset://`). IDs en `Config` |
| Humor de algunos títulos (caca, súcubos…) | **Nada** de eso: lista de palabras prohibidas que comprueba `check_books.py` |
| Un jugador, PC | 1 jugador **por servidor**, **táctil + mando + PC**, guardado en la nube, logros → **insignias de Roblox** |
| Esc = pausa | Esc está reservado por Roblox → **P** abre el menú |
| Tab = lista, 1–5 = magia | Igual (se desactivan la lista de jugadores y la mochila de Roblox para liberar esas teclas) |
| Lanzar (tecla no documentada) | **F** **(supuesto)** |

## 3. Secciones (datos exactos del original; los nombres del tema son nuestros)

Muebles: cada sección es una estantería con **exactamente una fila por serie**: filas largas de 10 huecos
para las series de 10 y estantes cortos de 5 o 3 huecos para las demás. Las baldas van en **4 alturas**
(3 en las secciones 2C, 2D, 2G, 2H, 2K, 2L, que tienen 18 filas).

**Planta 1 — magia y criaturas** (176 series, 1.456 libros)

| Código | Tema (nuestro nombre) | 10 | 5 | 3 | Libros | Colores de portada |
|---|---|---|---|---|---|---|
| 1A | Criaturas y monstruos | 12 | – | – | 120 | marrones |
| 1B | Astros y adivinación | 12 | – | – | 120 | azul noche, estrellas y cristales |
| 1C | Maldiciones y cómo romperlas | 4 | – | 8 | 64 | **negro, letras rojas** |
| 1D | Bardos y música mágica | 4 | – | 8 | 64 | naranjas, notas musicales |
| 1E | Nigromancia | 12 | – | – | 120 | **negro, letras rojas** (se solapa con 1C) |
| 1F | Transformaciones | 12 | – | – | 120 | verdes azulados |
| 1G | Artefactos y encantamientos | 4 | – | 8 | 64 | bronces |
| 1H | Sigilo e invisibilidad | 4 | – | 8 | 64 | grises, letras grises |
| 1I | Ilusiones | 12 | – | – | 120 | **morados** |
| 1J | Invocación | 12 | – | – | 120 | **azules y morados** (se solapa con 1I) |
| 1K | Sanación | 8 | – | – | 80 | **blancos**, letras verdes |
| 1L | Luz sagrada | 8 | – | – | 80 | **blancos**, letras doradas |
| 1M | Hechizos elementales («Libro de hechizos: elemento – rango») | 12 | 8 | – | 160 | color del elemento + **gemas** |
| 1N | Alquimia y pociones | 12 | 8 | – | 160 | verdes y ámbar |

**Planta 2 — oficios, sociedad, ficción y estudio** (224 series, 1.616 libros)

| Código | Tema | 10 | 5 | 3 | Libros | Colores |
|---|---|---|---|---|---|---|
| 2A | Guerreros | 12 | – | – | 120 | acero y rojo |
| 2B | Tiro con arco | 12 | – | – | 120 | verdes bosque |
| 2C | Magia del día a día | 6 | – | 12 | 96 | pasteles |
| 2D | Aritmancia (matemáticas mágicas) | 6 | – | 12 | 96 | azul marino con números |
| 2E | Bellas artes | 12 | – | – | 120 | multicolor |
| 2F | Gestión de gremios | 12 | – | – | 120 | granate y oro |
| 2G | Economía mágica | 6 | – | 12 | 96 | verde y oro |
| 2H | Sociología | 6 | – | 12 | 96 | turquesa y naranja |
| 2I | Psicología | 12 | – | – | 120 | **rojo oscuro** |
| 2J | Filosofía | 12 | – | – | 120 | **blancos** (se solapa con 1K y 1L) |
| 2K | Leyes y tribunales | 6 | – | 12 | 96 | cuero |
| 2L | Novela romántica («Novela romántica: …») | 6 | – | 12 | 96 | rosas |
| 2M | Novela de misterio («Ficción de misterio: …») | 4 | 4 | – | 60 | azul noche |
| 2N | Historia | 4 | 4 | – | 60 | sepia |
| 2O | Viajes a otros mundos (un mundo sin magia… con wifi) | 4 | 8 | – | 80 | turquesa «tecnológico» |
| 2P | Mazmorras | 4 | 4 | – | 60 | piedra y **marrón** (se solapa con 1A) |
| 2Q | Idiomas (élfico, enano, dracónico…) | 4 | 4 | – | 60 | variados |

**Totales comprobados con `assert` en `BookData.luau`:** 256 series de 10 + 40 de 5 + 104 de 3 = **400**;
2.560 + 200 + 312 = **3.072 libros**; **128 series de 10 en cada planta**.

### 3.1 Planta del edificio (supuesto: no se conoce la exacta)

- Sala rectangular de **64 × 120 studs**; planta 1 en `y = 0`, planta 2 (galería) en `y = 14`, techo en `y = 30`.
- **Planta 2 = galería en anillo** de 14 studs de ancho pegada a las paredes, con **barandilla**; el centro
  (36 × 92) queda abierto: desde arriba se ve la planta 1 y se pueden **tirar libros por la barandilla**.
- **Zigzag como el original:** letras **impares a la izquierda**, **pares a la derecha** y algunas en la **pared
  del fondo** (1M y 1N en la planta 1; 2M, 2N, 2O, 2P y 2Q en la planta 2).
- **Una sola escalera** en el centro: tramo 1 (z −70 → −84), **rellano trasero** a media altura (y = 7,
  z −84 → −92) con el **podio del cristal** y el **jarrón** de la llave amarilla, tramo 2 hasta la galería del fondo.
- **Mapas** al pie de la escalera de cada planta (también en la interfaz, tecla **M**, con el mismo dibujo).
- Entrada con puerta encantada y **escudo** encima; mesas, bancos, jarrones, lámparas, ventanales y claraboya.
- **Punto de salto a la planta 2** (para el salto alto): un **reloj de pie** junto a la galería derecha con un
  hueco en la barandilla encima (`Layout.luau`).

## 4. Libros y títulos (`BookData.luau`)

- 400 series con `id`, `section`, `volumes`, `es`, `en` y `cover = { base, text, band, pos, sym }`.
- **Pistas:** cada título lleva **palabras clave** de su sección (lista en `tools/harness/check_books.py`,
  que lo comprueba). Prefijos que también dicen la longitud, como en el original:
  - 1M: «Libro de hechizos: Fuego/Hielo/Rayo/Tierra – **Novato/Adepto/Experto**» = 10 tomos; «– **Maestro/Legendario**» = 5.
  - 1N: «**Libros** de alquimia: …» = 10 tomos; «**Tomos** de alquimia: …» = 5.
  - 2L: «Novela romántica: …» · 2M: «Ficción de misterio: …».
- **Portadas:** color base + franja (arriba/centro/abajo) + símbolo, sacados de la paleta de la sección; las
  paletas se **solapan a propósito** (tabla de §3). Dentro de una sección no hay dos portadas iguales.
- **Montón de inicio:** las 2 primeras series de 1A son muy reconocibles: *Guía del búho blanco gigante*
  (franja blanca y búho 🦉) y *Dragones para principiantes absolutos* (franja naranja y dragón 🐉).
- **Número de tomo** visible en el lomo de cerca (etiquetas reutilizables, ver §15) y siempre en la lista de mano.
- Comprobación automática: títulos únicos, ES y EN presentes, ≤ 70 caracteres, recuentos, palabras clave,
  portadas distintas y **palabras prohibidas** (también en todos los textos de `Lang.luau`).

## 5. Coger, llevar y colocar

| Acción | PC | Móvil | Mando |
|---|---|---|---|
| Coger / colocar (lo que marque la cruceta) | E o clic izquierdo | botón **USAR** | RT |
| Soltar el de arriba / mantener = soltar toda la pila en un montón | R | Soltar (mantener) | X |
| Lanzar el de arriba en arco | F **(supuesto)** | Lanzar | Y |
| Pasar el de arriba al fondo (reordenar a mano) | clic derecho | Rotar | RB |
| Lista de libros en mano (título, tomo, sección; ▲▼ para reordenar) | Tab | Lista | B |
| Magia mayor 1–5 | 1–5 | 5 botones con enfriamiento | cruceta + LB |
| Mapa / Manual / Menú | M / B / P | botones | Select / — / — |
| Saltar / Correr (cuando se desbloquean) | Espacio / Mayús | botones | A / L3 |

- **Cruceta:** rayo desde el centro de la cámara, alcance **10 studs**; resalta en **verde** dónde puedes actuar
  y en **rojo** si está bloqueado (manos llenas, manos vacías, cofre sin llave…).
- Se pueden **sacar libros de las estanterías** para rehacer filas. Al sacar un libro de un montón, los de
  encima bajan.
- **Capacidad 10** libros; **+3** y **+2** con los cofres (máximo 15).
- **Movimiento:** andar **12** (supuesto), **sin saltar** al principio (salto de Roblox anulado), correr **22**
  (supuesto) con Mayús tras la llave verde, salto alto **10** de altura (supuesto; el normal de Roblox es 7,2).

## 6. Validación (deducción de las guías: **supuesto** en los detalles)

- **Fila correcta** = todos sus huecos llenos con los tomos 1…N de **la misma serie**, en orden, la serie es
  de esa sección y la longitud de la estantería es la de la serie.
- Por libro, al colocarlo:
  - **dorado** si su sección es la de la estantería, la longitud coincide, está en el hueco de su tomo y no hay
    en la fila libros de otra serie;
  - **rojo tenue** si la sección es la correcta pero falla lo demás;
  - **sin brillo** si la sección es otra.
- La **placa** de una sección se pone **azul** (con sonido) cuando todas sus filas son correctas, y se apaga si
  deshaces una.
- Que un libro «encaje» en un hueco no significa que la fila esté bien.
- Contadores: **filas correctas x/400** (arriba), **libros en estanterías x/3.072** (abajo) y «faltan N filas
  para el siguiente punto».

## 7. Puntos y magia mayor (manual personal, tecla B)

- Puntos por el **récord** de filas correctas alcanzado (no por romper y rehacer la misma fila).
- **(supuesto)** filas 1–20 → 1 punto cada 2 · 21–80 → cada 4 · 81–200 → cada 6. **Total 45 puntos**, justo
  lo que cuesta subirlo todo al máximo (el original: «con unas 200–250 filas se puede tener todo»).
- Cada nivel cuesta 1 punto; el nivel 1 compra el hechizo; cualquier orden.
- El **enfriamiento empieza cuando el efecto termina** (supuesto).
- Máximos sacados de las guías; **niveles intermedios interpolados (supuesto)**:

| Tecla | Hechizo | Qué hace | Niv. máx. | Efecto por nivel (1 → máx.) | Enfriamiento por nivel (1 → máx.) |
|---|---|---|---|---|---|
| 1 | **Ordenar** | Ordena tu pila por serie y tomo | 5 | instantáneo | 30 · 24 · 18 · 11 · **5** s |
| 2 | **Guía de estantería** | Resalta la sección (y sus filas libres de la longitud buena) del libro de arriba | 10 | 15 · 20 · 25 · 30 · 35 · 40 · 45 · 50 · 55 · **60** s | 60 · 54 · 48 · 42 · 36 · 29 · 23 · 17 · 11 · **5** s |
| 3 | **Revelar** | Brillan los demás tomos de la serie del de arriba (sigue al libro de arriba) | 10 | 10 · 13 · 17 · 20 · 23 · 27 · 30 · 33 · 37 · **40** s; alcance 25 → 250 studs | 60 · 56 · 51 · 47 · 42 · 38 · 33 · 29 · 24 · **20** s |
| 4 | **Autocolocar** | Mientras dura, apuntar a una sección y pulsar coloca en sus filas correctas todos tus libros de esa sección | 10 | 10 · 15 · … · 50 · **55** s | 120 · 108 · 96 · 83 · 71 · 59 · 47 · 34 · 22 · **10** s |
| 5 | **Reunir** | Atrae a tu mano otros tomos de la serie del de arriba **desde suelo y mesas, nunca de estanterías**, hasta llenar | 10 | 1 · 2 · 3 · 4 · 5 · 5 · 6 · 7 · 8 · **9** libros | 90 · 81 · 72 · 63 · 54 · 46 · 37 · 28 · 19 · **10** s |

- **Autocolocar** elige fila así (supuesto): primero una fila de esa sección que ya tenga tomos de la serie (y solo
  de ella); si no, una fila vacía de la longitud correcta. Si el hueco está ocupado, ese libro se queda en la mano.
- Los libros **vuelan** hacia ti o hacia su hueco (animación en el cliente; el servidor decide).
- La partida guarda si se ha **comprado o usado** alguna magia mayor (para «Sin magia»).

## 8. Magia menor: 4 llaves → 4 cofres

| Llave | Escondite (adaptado a nuestro mapa) | Cofre (y cuadro con la pista encima) | Da |
|---|---|---|---|
| **Roja** (rombo) | En la pared de la entrada, junto al **escudo**: se ve al darse la vuelta al empezar | Planta 1, esquina delantera izquierda | **Salto alto** |
| **Verde** (hoja) | **Bajo un montón de libros** en el primer banco a la derecha del inicio (hay que quitar los libros) | Planta 1, esquina delantera derecha | **Correr** |
| **Amarilla** (sol) | Dentro de un **jarrón sobre un pilar del rellano** de la escalera (hay que saltar) | Planta 2, galería delantera izquierda | **Capacidad +3** |
| **Azul** (gota) | **Encima de las estanterías del fondo de la planta 2**, junto a Otros mundos y Mazmorras (hay que saltar) | Planta 2, galería delantera derecha | **Capacidad +2** |

- Cada cofre tiene una **nota graciosa de la rectora**. Las llaves se cogen de cerca (`KEY_REACH` 4,5 studs):
  así las altas exigen saltar. La magia menor **no** cuenta como magia para «Sin magia».

## 9. Cristal de recuperación

- En el **podio del rellano**. Trae al podio hasta **20 libros** perdidos que no estén en ninguna estantería ni
  en tu mano. **Perdido (supuesto):** fuera del edificio, a más de 4 studs por encima del suelo de su planta
  (encima de estanterías, barandillas…) o dentro de un hueco inaccesible. No cuenta como magia.
- Los libros que caen **fuera del mapa** vuelven solos a su sitio inicial.

## 10. Salida, evaluación y finales

- La **puerta** solo se abre con los **3.072 libros en estanterías** (bien o mal). Antes, avisa de cuántos faltan.
- **Pantalla de resultados:** tiempo jugado, filas correctas, magia mayor usada (sí/no), llaves (x/4), mejor
  tiempo y **rango**.
- **Rangos (supuesto):**

| Rango | Nombre | Condición |
|---|---|---|
| 1 | **¡Despedido!** | 0 filas correctas |
| 2 | Aprendiz despistado | menos del 50 % de filas |
| 3 | Ayudante de archivo | menos del 100 % |
| 4 | Guardián de los estantes | 400/400 |
| 5 | Gran bibliotecario | 400/400 y (≤ 6 h **o** sin magia) |
| 6 | Leyenda de Brumaluna | 400/400 y (≤ 3 h **o** sin magia y ≤ 8 h) |

- **Finales:** **Normal** (400/400; la pizza llega fría) · **Sin magia** (400/400 sin comprar ni usar magia
  mayor) · **Pizza** (supuesto: 400/400 en **menos de 3 h** de juego) · **Despedido** (todo colocado y **0** filas
  correctas: nota furiosa) · «Casi…» (todo colocado y algunas filas mal).
- **Récord:** solo partidas con la biblioteca entera bien (400/400). La fase especial no cuenta.

## 11. Fase especial y habilidad definitiva (supuesto: no se conoce su contenido)

- Se desbloquea en el menú al **terminar una partida**. Es **el Archivo**, un ala aparte con **300 libros**
  revueltos (30 series de 10, copias de series de 1A, 1I y 2E) en 3 estanterías.
- La barra de la **definitiva** se carga en **600 s** (supuesto ~10 min) y **+4 s por libro colocado**. Con **Z**,
  todos los libros vuelan a su sitio. Al salir por la puerta del Archivo tras usarla: insignia «Sin horas extra».
  Si se termina a mano no hay insignia. No se guarda (es corta) y no cuenta como récord.

## 12. Opciones, modo acogedor, luz y música

- Opciones: idioma ES/EN (por defecto según el idioma de Roblox), sensibilidad, campo de visión, balanceo de
  cabeza, volumen de música y efectos, **modo acogedor**, botones táctiles para **zurdos**.
- **Modo acogedor:** oculta el cronómetro y congela la luz; avisa de que la evaluación sigue contando el tiempo.
- **Luz:** empieza a **media tarde** (15:30) y a las **3 h** de juego es **noche cerrada** (21:30), la broma de las
  «horas extra». `Lighting.Technology = Future` en `default.project.json`.
- **Música por tramos** según el % de filas correctas (0 %, 25 %, 50 %, 85 %), IDs en `Config.Music` (vacíos de
  momento: hay que elegir pistas con licencia de la Creator Store). **Sonidos:** coger/colocar (clic), golpe
  sordo al soltar, silbido al lanzar, campanita al completar fila y al poner la placa azul (sonidos incluidos en
  Roblox). Pasos: los de serie del personaje de Roblox.

## 13. Guardado y menú de título

- **Menú de título:** Continuar, Nueva partida, **3 ranuras**, Fase especial (si está desbloqueada), Opciones,
  Logros. Fondo: la biblioteca vista desde arriba.
- **Por ranura:** dónde está cada uno de los 3.072 libros, mano, récord de filas, puntos gastados, niveles,
  llaves y cofres, tiempo jugado, si se ha usado magia, posición del jugador, terminada, final y rango.
- **Formato compacto:** una cadena de **8 caracteres por libro** (tipo de sitio + hueco o posición x/y/z con
  precisión de 0,1 studs + giro): unos **24.600 caracteres por ranura** (~75 KB las 3), muy por debajo de 4 MB.
- **Disparadores del original** (fila completada, magia menor, salir, volver al menú, cada 50 libros), pero
  **agrupados**: se marca «pendiente» y se guarda **como mucho cada 30 s**, más al salir y en `BindToClose`;
  también cada 2 min si solo ha corrido el tiempo. **Todo el DataStore en `pcall`.** Si la carga falla, **no se
  guarda** (para no machacar). En Studio sin publicar: aviso en pantalla.

## 14. Logros → 12 insignias (`Config.Badges`, 0 = desactivada; se guardan igual en la partida)

1 Primera fila · 2 Cincuenta filas · 3 Doscientas filas · 4 Todo en azul (400) · 5 Primer hechizo ·
6 Las cinco magias · 7 Cazallaves (4 cofres) · 8 Manual completo · 9 Sin horas extra (definitiva) ·
10 ¡Despedido! (todo colocado y 0 filas) · 11 La pizza sigue caliente (< 3 h) · 12 A la antigua (sin magia mayor).

## 15. Adaptación a Roblox

- **1 jugador por servidor:** el usuario pone **Max Players = 1** en el Creator Hub. Si entra un 2.º jugador
  (por error o porque la opción no estuviera disponible), el servidor lo manda a un **servidor reservado**
  propio (`TeleportService:ReserveServer`, en `pcall`); si el teletransporte falla (Studio), se queda mirando sin
  poder tocar nada. Nada se rompe.
- **El servidor manda:** el estado de los libros vive en el servidor. El cliente pide acciones por un
  `RemoteFunction` (`pick place drop dropAll throw cycle reorder cast autoPlace buySkill takeKey openChest
  useCrystal exitDoor ultimate setOption selectSlot newGame deleteSlot startSpecial toMenu readLetter`) y el
  servidor valida distancia, capacidad, enfriamientos y **25 acciones/s** como mucho.
- **Nada de estado completo cada segundo:** una **foto** al cargar la partida (la misma cadena del guardado) y
  luego **deltas** («el libro 1234 ha ido al hueco X»). El estado pequeño (contadores, mano, hechizos) va aparte.
- **Rendimiento:** los libros son `Part` sencillas **ancladas**, creadas por el cliente (cuerpo + franja), sin
  colisión con el personaje pero visibles para el rayo de la cruceta. **Sin física real:** el lanzamiento es una
  parábola calculada en el servidor contra cajas del edificio (`Geo.luau`) y animada con tweens; al caer queda
  anclado. Brillos: una pieza fina detrás de cada hueco (no `Highlight`, que Roblox limita a ~31). Revelar usa
  material Neón; Guía usa `SelectionBox`. Lomos con texto: **grupo reutilizable** de ~40 etiquetas solo para los
  libros cercanos. **StreamingEnabled desactivado** (Revelar necesita todos los libros en el cliente).
  Presupuesto: **< 15.000 piezas**; se mide en el harness.
- **Primera persona** forzada (`CameraMode = LockFirstPerson`), cruceta en el centro. Los menús liberan el ratón.
- **Idiomas ES/EN** desde el principio (`Lang.luau` + títulos en `BookData.luau`).

## 16. Críticas al original (NO se cambian salvo que el usuario lo pida; opciones)

- **Las letras de las secciones van en zigzag** → opción: numeración seguida por pared, o flechas en el suelo.
- **Solo hay una escalera** → opción: una segunda escalera de caracol en la esquina delantera.
- **El principio es lento** (sin saltar ni correr, 10 libros) → opción: llave verde más a la vista, o
  capacidad inicial 12.

## 17. Lista de supuestos (todos en `Config.luau`)

| Dato desconocido | Valor elegido |
|---|---|
| Tabla de puntos por fila | 1–20 cada 2 · 21–80 cada 4 · 81–200 cada 6 (45 puntos) |
| Niveles intermedios de cada hechizo | interpolación lineal (tabla §7) |
| Niveles máximos de Revelar y Guía | 10 |
| Cuándo empieza el enfriamiento | al terminar el efecto |
| Alcance de Revelar | 25 → 250 studs |
| Regla exacta de brillo por libro | la de §6 |
| Condición del final Pizza | 400/400 en < 3 h de juego |
| Umbrales de los 6 rangos | tabla §10 |
| Contenido de la fase especial | el Archivo: 300 libros, definitiva en 600 s + 4 s/libro |
| Planta exacta del edificio | §3.1 |
| Andar / correr / salto alto | 12 / 22 / 10 |
| Capacidad inicial | 10 (las reseñas dicen 10) |
| Tecla de lanzar | F |
| «Libro perdido» para el cristal | fuera del edificio, > 4 studs sobre su suelo o en hueco inaccesible |
| Hora del modo acogedor | 16:30 fija (también en la fase especial) |
| Magia en la fase especial | toda la menor (salto, correr, 15 libros); sin magia mayor |
| Fila que elige Autocolocar | la que ya tiene la serie; si no, una vacía de la longitud correcta |

## 18. Estado y verificación

| Fase | Qué incluye | Estado |
|---|---|---|
| 1 | Documentos, herramientas, `Config`, `Lang`, `BookData` (400 títulos) | ✅ comprobado con `check_books.py` |
| 2 | Edificio y 3.072 libros en sus montones iniciales | ✅ comprobado con `run_world.luau` (planos en `docs/`) |
| 3 | Bucle principal jugable | ✅ bot de servidor (partida entera 400/400) y cliente PC/móvil |
| 4 | Puntos, manual, magias, llaves, cristal | ✅ bot: 4 llaves (altas solo saltando), cofres, cristal, 5 hechizos al máximo con 45 puntos |
| 5 | Guardado, menú, opciones, luz, música, puerta, finales, insignias, fase especial | ✅ bot: guardar/salir/entrar idéntico, 4 finales, 6 rangos, 12 insignias, definitiva |
| 6 | Táctil, mando, rendimiento, revisión ES/EN, README | pendiente |
| 7 | Monetización (solo si el usuario la aprueba) | sin empezar |
