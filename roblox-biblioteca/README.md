# Estanterías Hechizadas (*Spellbound Shelves*)

Juego de Roblox para ordenar, en primera persona, los **3.072 libros** de una biblioteca mágica.
El diseño completo (reglas, números y supuestos) está en [`DISENO.md`](DISENO.md).

> **Estado:** juego completo (fases 1–6) **pendiente de probar en Studio** y sin publicar.
> Lo he verificado con mis herramientas (bots que juegan partidas enteras y prueban todos los botones), pero
> **no puedo abrir Roblox Studio**: mándame capturas si algo se ve raro o sale algo rojo en *Output*.

---

## 1. Probar en Roblox Studio

1. Descarga el lugar (ábrelo y pulsa *Download raw file*):
   `https://github.com/candhu23/mi-priemra-web/raw/claude/biblioteca-arcana/roblox-biblioteca/Biblioteca.rbxl`
2. Ábrelo con doble clic (se abre en Roblox Studio).
3. Pulsa **Play** (pestaña *Home*). Sale el **menú de título**: **Nueva partida** → **Empezar aquí** (ranura 1).
4. Qué mirar (por orden):
   - Date la vuelta: junto a la puerta hay una **llave roja** brillando. Cógela con **E**.
   - Mira la **carta** del atril de tu izquierda y pulsa **E**: la carta de la rectora.
   - En la mesa de tu izquierda hay libros del **búho** y de **dragones**: cógelos (**E** o clic) y colócalos en la
     estantería **1A**, en un estante largo, del tomo 1 (izquierda) al 10 (derecha). Bien puesto = brillo
     **dorado**; mal puesto en su sección = **rojo**. Con toda la sección bien, su **placa se pone azul**.
   - Con 2 filas correctas ganas tu primer **punto**: **B** abre el manual; los hechizos se lanzan con **1–5**.
   - El **cofre rojo** (esquina delantera izquierda) da el **salto alto** (Espacio).
   - **R** suelta un libro (mantén R: toda la pila), **F** lo lanza, **clic derecho** pasa el de arriba al fondo,
     **Tab** abre la lista de lo que llevas, **M** el mapa, **P** la pausa (opciones, logros, volver al menú).
5. Si algo falla, abre **View → Output** y mándame una captura de los mensajes en rojo.

**En el móvil** (Studio: pestaña *Test* → *Device* → un teléfono): botones grandes USAR, Soltar (mantener = todo),
Lanzar, Rotar, Correr (cuando lo desbloqueas) y arriba Lista, Mapa, Manual y Menú. **Mando**: RT usar, X soltar,
Y lanzar, RB rotar, B lista/atrás, cruceta y LB magia, LT manual, Select mapa, A saltar.

> En Studio la partida **no se guarda** hasta que publiques y actives *API Services* (sección 2, paso 4). Mientras, sale un
> aviso de que no se guardará; es normal y no rompe nada.

---

## 2. Publicar (experiencia NUEVA)

1. Con el lugar abierto en Studio: **File → Publish to Roblox As…**
2. Elige **crear una experiencia NUEVA** (*Create new experience*). **¡No elijas *Web Empire Tycoon*!**
   Nombre: **Spellbound Shelves** (o *Estanterías Hechizadas*). Pulsa **Create**.
3. **1 jugador por servidor** (la biblioteca es tuya): en el Creator Hub → *Creations* → tu experiencia →
   **Places** → en el lugar, botón **⋯ → Configure Place** → **Max players = 1** → *Save*.
   (Si entrase un segundo jugador por error, el juego lo manda a otro servidor o lo deja mirando sin tocar nada.)
4. **Guardado:** en Studio, **Home → Game Settings → Security → Enable Studio Access to API Services → Save**.
5. **Icono:** sube `docs/icono_juego.png` (512 × 512) en los ajustes de la experiencia. Para las miniaturas, haz
   capturas en Studio mirando las estanterías.

### 2.1 Insignias (12 logros)

Se crean en el Creator Hub: pasa el ratón por la miniatura de la experiencia → **⋯ → Create Badge** → *Upload
Image* (la de la tabla, 512 × 512, carpeta `docs/insignias/`) → nombre y descripción → **Create Badge**.
Las 5 primeras de cada día son **gratis** (después cuestan 100 Robux cada una): **crea 5 al día durante 3 días**.
Para copiar el ID: *Engagement → Badges* → **⋯ → Copy Asset ID**. **Mándame los 12 IDs** y los pongo en el juego
(`Config.Badges`). Mientras tanto los logros se guardan igual en la partida.

| # | Clave | Nombre (ES / EN) | Descripción | Imagen |
|---|---|---|---|---|
| 1 | `first_row` | Primera fila / First Row | Completa tu primera fila correcta. | `insignia_first_row.png` |
| 2 | `rows_50` | Cincuenta filas / Fifty Rows | Llega a 50 filas correctas. | `insignia_rows_50.png` |
| 3 | `rows_200` | Doscientas filas / Two Hundred Rows | Llega a 200 filas correctas. | `insignia_rows_200.png` |
| 4 | `rows_400` | Todo en azul / All Plates Blue | Las 400 filas correctas. | `insignia_rows_400.png` |
| 5 | `first_spell` | Primer hechizo / First Spell | Aprende tu primera magia mayor. | `insignia_first_spell.png` |
| 6 | `all_spells` | Las cinco magias / All Five Spells | Aprende las 5 magias mayores. | `insignia_all_spells.png` |
| 7 | `chests` | Cazallaves / Key Hunter | Abre los 4 cofres. | `insignia_chests.png` |
| 8 | `spells_max` | Manual completo / Fully Studied | Sube todas las magias al máximo. | `insignia_spells_max.png` |
| 9 | `ultimate` | Sin horas extra / No Overtime | Usa la definitiva en la fase especial y sal. | `insignia_ultimate.png` |
| 10 | `fired` | ¡Despedido! / You're Fired! | Sal con todo colocado y 0 filas correctas. | `insignia_fired.png` |
| 11 | `pizza` | La pizza sigue caliente / Pizza's Still Hot | Ordénalo todo bien en menos de 3 h. | `insignia_pizza.png` |
| 12 | `nomagic` | A la antigua / The Old-Fashioned Way | Ordénalo todo bien sin magia mayor. | `insignia_nomagic.png` |

### 2.2 Cuestionario de contenido

- Violencia, sangre, miedo, humor grosero, palabrotas, alcohol, apuestas: **No**.
  Los títulos de los libros son humorísticos y aptos para todos. Hay una sección de «Novela romántica» con
  títulos inocentes (p. ej. *El dragón que quería un abrazo*); si el cuestionario pregunta por temas románticos,
  **elige la opción más baja**: no hay escenas ni imágenes.
- Artículos aleatorios de pago: **No** (el juego no vende nada).
- Recuerda (normas de 2026): las experiencias nuevas salen limitadas a 16+ hasta llegar a 250 jugadores activos.

### 2.3 Descripción para la página (sin mencionar ningún otro juego)

**English:**
> Scribble, the academy's winged cat, knocked all 3,072 books of the Mistmoon Library onto the floor — and the
> Headmistress won't let you leave until every one is back on a shelf. Read the titles, find each book's section,
> keep every series together and put the volumes in order. Earn points, learn handy spells, hunt for four hidden
> keys and see if the Headmistress keeps her promise: pizza! A cozy single-player tidying game with 3 save slots,
> cozy mode, achievements and a special stage. In English and Spanish.

**Español:**
> Garabato, el gato alado de la academia, ha tirado al suelo los 3.072 libros de la Biblioteca de Brumaluna, y la
> rectora no te deja salir hasta que estén todos en una estantería. Lee los títulos, busca la sección de cada libro,
> junta cada serie y pon los tomos en orden. Gana puntos, aprende hechizos, busca cuatro llaves escondidas y
> comprueba si la rectora cumple su promesa: ¡pizza! Juego tranquilo para un jugador con 3 ranuras de guardado,
> modo acogedor, logros y fase especial. En español e inglés.

### 2.4 Música (opcional)

El juego no trae música (solo sonidos incluidos en Roblox). Si quieres: en la **Creator Store** busca *Audio*
con licencia (música tranquila: «calm», «ambient», «library»), copia de 1 a 4 IDs y mándamelos: sonarán por tramos
según avanzas (0 %, 25 %, 50 % y 85 % de filas correctas).

---

## 3. Actualizar una versión ya publicada

1. Descarga el `.rbxl` nuevo (enlace del paso 1), ábrelo y pulsa **Stop** si hay una prueba en marcha.
2. **File → Publish to Roblox As… → Spellbound Shelves → Replace** (nunca «Web Empire Tycoon»).
3. Creator Hub → *Places* → **⋯ → Shut Down All Servers** (o *Migrate to Latest Update*).
   Las partidas guardadas y los ajustes de la página **no se pierden**.
