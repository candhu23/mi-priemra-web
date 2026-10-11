-- Textos del juego en español (es) e inglés (en). Los títulos de los libros están en BookData.
-- Uso: Lang.t("es", "hud_rows", { n = 12, total = 400 }) → reemplaza {n} y {total}.
-- Si falta una clave en un idioma se usa la inglesa; si falta en los dos, se muestra la clave.
-- Personajes y lugar (originales): la rectora Ofelia Tintero, el gato alado Garabato y la Academia Brumaluna.

local Lang = {}

Lang.es = {
	-- General y menú de título
	loading = "Abriendo la biblioteca…",
	menu_continue = "Continuar", menu_new = "Nueva partida", menu_special = "Fase especial", menu_options = "Opciones",
	menu_achievements = "Logros", menu_back = "Volver", menu_slots = "Elige una ranura",
	slot_n = "Ranura {n}", slot_empty = "Vacía", slot_info = "{rows}/400 filas · {books}/3.072 libros · {time}",
	slot_finished = "Terminada · {rank}", slot_play = "Jugar", slot_start = "Empezar aquí", slot_delete = "Borrar",
	confirm_delete = "¿Borrar la ranura {n}? No se puede deshacer.", confirm_overwrite = "Esta ranura ya tiene una partida. ¿Empezar de cero?",
	btn_yes = "Sí", btn_no = "No", btn_ok = "Vale", btn_close = "Cerrar", best_time = "Mejor tiempo: {time}", best_none = "Mejor tiempo: —",
	warn_no_save = "Studio sin publicar o sin acceso a DataStore: la partida NO se guardará.",
	warn_load_failed = "No se pudo cargar tu partida: esta sesión no se guardará para no borrar nada.",
	warn_guest = "Esta biblioteca es de otra persona. Te llevamos a la tuya…",
	special_locked = "Termina una partida para desbloquearla.",

	-- Contadores y mano
	hud_rows = "Filas correctas {n}/{total}", hud_books = "Libros en estanterías {n}/{total}",
	hud_next = "Faltan {n} filas para el siguiente punto", hud_next_max = "¡Ya tienes todos los puntos!",
	hud_points = "{n} punto(s) para el manual ({key})", hud_hand = "{n}/{cap}", hud_hand_empty = "Manos vacías",
	hud_vol = "Tomo {v}/{n}", hud_section = "Sección {code}", hud_cozy = "Modo acogedor",
	hud_saving = "Guardando…", hud_saved = "Partida guardada", hud_not_saved = "Sin guardar",

	-- Cruceta (lo que pasa si pulsas)
	aim_pick = "Coger", aim_place = "Colocar", aim_full = "Llevas demasiados libros", aim_empty = "No llevas libros",
	aim_key = "Coger la llave", aim_chest = "Abrir el cofre", aim_chest_locked = "Necesitas la llave {color}",
	aim_chest_open = "Cofre abierto", aim_crystal = "Usar el cristal", aim_door = "Salir de la biblioteca",
	aim_door_locked = "Faltan {n} libros por poner en estanterías", aim_letter = "Leer la carta", aim_map = "Ver el mapa",
	aim_exit_special = "Salir del archivo", aim_painting = "Un cuadro…",

	-- Botones
	btn_use = "USAR", btn_drop = "Soltar", btn_throw = "Lanzar", btn_list = "Lista", btn_jump = "Saltar", btn_run = "Correr",
	btn_manual = "Manual", btn_map = "Mapa", btn_options = "Opciones", btn_menu = "Menú", btn_cycle = "Rotar",
	btn_learn = "Aprender", btn_upgrade = "Mejorar", btn_to_menu = "Volver al menú", btn_continue = "Seguir ordenando",
	btn_ultimate = "Z", btn_floor1 = "Planta 1", btn_floor2 = "Planta 2",

	-- Hechizos (manual personal)
	manual_title = "Manual personal", manual_points = "Puntos: {n}", manual_hint = "Ganas puntos con tu récord de filas correctas. Cada nivel cuesta 1 punto.",
	sk_sort = "Ordenar", sk_sort_d = "Ordena los libros que llevas por serie y número de tomo.",
	sk_guide = "Guía de estantería", sk_guide_d = "Señala la estantería donde va el libro de arriba de tu pila.",
	sk_reveal = "Revelar", sk_reveal_d = "Hace brillar los demás tomos de la serie del libro de arriba. Si cambias de libro, cambia la serie.",
	sk_auto = "Autocolocar", sk_auto_d = "Mientras dura, apunta a una sección y pulsa otra vez: coloca en su sitio todos tus libros de esa sección.",
	sk_gather = "Reunir", sk_gather_d = "Atrae a tu mano otros tomos de la serie del libro de arriba (del suelo y las mesas, nunca de las estanterías).",
	sk_level = "Nivel {l}/{max}", sk_locked = "Sin aprender", sk_cd = "Enfriamiento {s} s", sk_dur = "Dura {s} s",
	sk_count = "Atrae {n} libro(s)", sk_range = "Alcance {n}", sk_instant = "Instantáneo", sk_next = "Siguiente nivel: {text}",
	n_sorted = "Pila ordenada", n_guide = "Guía activada", n_reveal = "Revelar activado", n_auto = "Autocolocar: apunta a una sección y pulsa {key}",
	n_auto_placed = "{n} libro(s) colocado(s)", n_gathered = "{n} libro(s) reunido(s)", n_learned = "Has aprendido {name}", n_upgraded = "{name} sube al nivel {l}",

	-- Llaves, cofres y cristal
	key_red = "roja", key_green = "verde", key_yellow = "amarilla", key_blue = "azul",
	n_key = "¡Llave {color}! Busca su cofre.", n_chest = "¡Cofre abierto!",
	reward_jump = "Salto alto: ya puedes saltar (Espacio) y muy alto.", reward_run = "Correr: mantén Mayús (o el botón Correr).",
	reward_cap3 = "Capacidad +3: ahora llevas hasta {cap} libros.", reward_cap2 = "Capacidad +2: ahora llevas hasta {cap} libros.",
	note_title = "Nota de la rectora",
	note_red = "Así que de vez en cuando miras hacia atrás. Bien. Este hechizo te deja saltar muy alto: úsalo para llegar a sitios raros, no para alcanzar las galletas de la sala de profesores. — O. T.",
	note_green = "Correr por los pasillos está prohibido. Salvo hoy. Salvo tú. — O. T.",
	note_yellow = "Ese jarrón era de mi abuela. Si se rompe, también ordenas el sótano. A cambio, podrás llevar 3 libros más. — O. T.",
	note_blue = "¿Qué hacías encima de las estanterías? Prefiero no saberlo. Toma: 2 libros más de capacidad. — O. T.",
	n_crystal = "{n} libro(s) perdido(s) han vuelto al podio del rellano.",
	painting_red = "Un escudo junto a una puerta… y algo rojo brillando cerca.",
	painting_green = "Un banco lleno de libros. Debajo asoma algo verde.",
	painting_yellow = "Un jarrón alto sobre la barandilla de la escalera.",
	painting_blue = "Las estanterías del fondo de la planta 2, vistas desde muy arriba.",

	-- Avisos
	n_row = "¡Fila correcta!", n_section = "¡Sección {code} completa! Su placa ya es azul.", n_point = "¡Nuevo punto! Gástalo en el manual ({key}).",
	n_achievement = "Logro: {name}", n_welcome = "Bienvenido/a a la Biblioteca de Brumaluna", n_door_open = "¡Todos los libros están en estanterías! La puerta ya se abre.",
	n_ultimate_ready = "¡La definitiva está cargada! Pulsa Z.", n_ultimate = "¡Todos los libros vuelan a su sitio!",
	n_returned = "El libro ha caído fuera y vuelve a su sitio inicial.", n_special = "Fase especial: el Archivo. Carga la definitiva y pulsa Z.",

	-- Errores
	err_generic = "No se puede.", err_slow = "¡Más despacio!", err_reach = "Está demasiado lejos.", err_full = "No te caben más libros.",
	err_empty = "No llevas libros.", err_taken = "Ese hueco ya está ocupado.", err_gone = "Ese libro ya no está ahí.",
	err_no_points = "No tienes puntos. Completa filas para ganarlos.", err_maxed = "Ya está al máximo.", err_not_learned = "Aún no has aprendido ese hechizo (manual: {key}).",
	err_cooldown = "Espera {s} s.", err_no_section_books = "No llevas libros de esa sección.", err_aim_section = "Apunta a una sección.",
	err_nothing_to_gather = "No quedan tomos de esa serie por el suelo ni en las mesas.", err_active = "Ya está activo.",
	err_key_covered = "Hay libros encima de la llave: quítalos primero.", err_key_high = "No llegas: está demasiado alta.",
	err_need_key = "Necesitas la llave {color}.", err_crystal_none = "No hay libros perdidos.",
	err_door_locked = "La puerta no se abre: aún hay {n} libro(s) fuera de las estanterías.", err_not_owner = "Esta biblioteca es de otra persona.",
	err_menu = "Primero elige una partida.", err_ultimate = "La definitiva aún no está cargada.", err_no_jump = "Aún no sabes saltar.",
	err_auto_off = "Primero activa Autocolocar (tecla {key}).",

	-- Historia
	letter_title = "Carta de la rectora",
	letter_body = "Hola, ayudante de biblioteca:\n\nGarabato, el gato alado de la academia, ha vuelto a hacer de las suyas: anoche tiró al suelo TODOS los libros de la Biblioteca de Brumaluna. Los 3.072.\n\nLa puerta está encantada y no se abrirá hasta que cada libro vuelva a una estantería.\n\n• Cada libro tiene su sección (1A, 1B… 2Q). Fíate de las palabras del título; el color de la portada ayuda, pero a veces engaña.\n• Una serie entera va junta en una sola fila, del tomo 1 (izquierda) al último (derecha).\n• Las series de 10 tomos van en los estantes largos; las de 5 y 3, en los cortos.\n• Brillo dorado: bien colocado. Brillo rojo: sección correcta, pero algo falla.\n• Cuando todas las filas de una sección están bien, su placa se pone azul.\n\nSi lo dejas todo perfecto, habrá pizza. Mucha pizza.\n\nP. D.: En la mesa de al lado tienes dos series para practicar. Van en la 1A.\n\n— Ofelia Tintero, rectora de la Academia Brumaluna",
	door_title = "La puerta encantada",
	door_locked_body = "La puerta no se mueve. Una voz cansada sale de la cerradura: «Hasta que no estén los 3.072 libros en estanterías, de aquí no sale nadie». Faltan {n}.",

	-- Tutorial (pistas en pantalla)
	tut_letter = "Lee la carta de la rectora: mírala y pulsa {key}.",
	tut_pick = "Coge los libros de la mesa de al lado: mira uno y pulsa {key}.",
	tut_place = "Ve a la sección 1A (a tu izquierda) y coloca una serie en un estante largo: tomo 1 a la izquierda… tomo 10 a la derecha.",
	tut_row = "¡Fila correcta! Coloca la otra serie y mira cómo se pone azul la placa cuando toda la sección esté bien.",
	tut_free = "Ahora, el resto de la biblioteca. Mapa: {map} · Lista de libros: {list} · Manual: {manual}",

	-- Evaluación y finales
	res_title = "Evaluación de la rectora", res_time = "Tiempo de juego: {time}", res_rows = "Filas correctas: {n}/400",
	res_magic = "Magia mayor usada: {v}", res_keys = "Llaves encontradas: {n}/4", res_best = "Mejor tiempo: {time}", res_rank = "Rango",
	res_yes = "sí", res_no = "no", res_new_best = "¡Nuevo récord!",
	rank_1 = "¡Despedido!", rank_2 = "Aprendiz despistado", rank_3 = "Ayudante de archivo",
	rank_4 = "Guardián de los estantes", rank_5 = "Gran bibliotecario", rank_6 = "Leyenda de Brumaluna",
	end_normal = "Biblioteca en orden",
	end_normal_d = "La rectora recorre los pasillos sin decir nada. Se para ante una placa azul, luego ante otra… y sonríe. «Bien hecho». La pizza llega, aunque un poco fría: ha sido una tarde muy larga.",
	end_pizza = "¡Pizza!",
	end_pizza_d = "La rectora cumple su promesa: una pizza enorme y todavía caliente te espera en la puerta. Garabato intenta llevarse un trozo volando.",
	end_nomagic = "A la antigua",
	end_nomagic_d = "«¿Sin un solo hechizo? ¿A mano? ¿Los 3.072?». La rectora te nombra miembro de honor del claustro y manda enmarcar tu escoba.",
	end_fired = "¡Despedido!",
	end_fired_d = "«¿EN SERIO? Ni una sola fila bien. Has puesto cada libro en el sitio equivocado con una puntería que casi admiro. Quedas despedido. Garabato, en cambio, queda ascendido.»",
	end_partial = "Casi…",
	end_partial_d = "Todos los libros están en estanterías… pero no todos en su sitio. La rectora suspira: «Algo es algo. Mañana seguimos».",

	-- Logros (insignias)
	ach_first_row = "Primera fila", ach_first_row_d = "Completa tu primera fila correcta.",
	ach_rows_50 = "Cincuenta filas", ach_rows_50_d = "Llega a 50 filas correctas.",
	ach_rows_200 = "Doscientas filas", ach_rows_200_d = "Llega a 200 filas correctas.",
	ach_rows_400 = "Todo en azul", ach_rows_400_d = "Las 400 filas correctas: todas las placas en azul.",
	ach_first_spell = "Primer hechizo", ach_first_spell_d = "Aprende tu primera magia mayor.",
	ach_all_spells = "Las cinco magias", ach_all_spells_d = "Aprende las 5 magias mayores.",
	ach_chests = "Cazallaves", ach_chests_d = "Abre los 4 cofres.",
	ach_spells_max = "Manual completo", ach_spells_max_d = "Sube todas las magias al máximo.",
	ach_ultimate = "Sin horas extra", ach_ultimate_d = "Usa la definitiva en la fase especial y sal.",
	ach_fired = "¡Despedido!", ach_fired_d = "Sal con todo colocado y 0 filas correctas.",
	ach_pizza = "La pizza sigue caliente", ach_pizza_d = "Ordénalo todo bien en menos de 3 horas de juego.",
	ach_nomagic = "A la antigua", ach_nomagic_d = "Ordénalo todo bien sin magia mayor (la menor sí vale).",
	ach_locked = "Sin conseguir", ach_done = "Conseguido",

	-- Fase especial
	sp_title = "Fase especial: el Archivo", sp_ult = "Definitiva", sp_ult_charge = "Cargando {p} %", sp_ult_ready = "¡Lista! Pulsa {key}",
	sp_intro = "Trescientos libros revueltos en el Archivo. Espera a que se cargue la definitiva (colocar libros la carga más rápido) y pulsa {key}. Este tiempo no cuenta como récord.",
	sp_done = "Archivo en orden", sp_done_d = "Todos los libros del Archivo están en su sitio.", sp_badge = "Has usado la definitiva: ¡sin horas extra!",

	-- Mapa y lista
	map_title = "Mapa de la biblioteca", map_you = "Tú", map_stairs = "Escalera", map_door = "Salida", map_crystal = "Cristal",
	map_floor = "Planta {f}", map_hint = "Las letras van en zigzag: impares a un lado, pares al otro y algunas al fondo.",
	list_title = "Libros en mano ({n}/{cap})", list_empty = "No llevas ningún libro.", list_top = "ARRIBA", list_hint = "El de arriba es el que se coloca primero. Usa ▲▼ para cambiar el orden.",

	-- Opciones
	opt_title = "Opciones", opt_lang = "Idioma", opt_lang_auto = "Automático", opt_sens = "Sensibilidad", opt_fov = "Campo de visión",
	opt_bob = "Balanceo de cabeza", opt_music = "Música", opt_sfx = "Efectos", opt_cozy = "Modo acogedor",
	opt_cozy_d = "Oculta el cronómetro y congela la luz. La evaluación sigue contando el tiempo.", opt_left = "Botones para zurdos",
	opt_controls = "Controles",
	help_pc = "WASD: andar · Ratón: mirar · E o clic: coger / colocar · R: soltar (mantén: soltar todo) · F: lanzar · Clic derecho: el de arriba pasa abajo · Tab: lista · 1–5: magia · M: mapa · B: manual · P: menú · Espacio: saltar · Mayús: correr",
	help_touch = "Joystick: andar · Arrastra: mirar · USAR: coger / colocar · Soltar (mantén: todo) · Lanzar · Lista · 1–5: magia",
	help_pad = "RT: coger / colocar · X: soltar (mantén: todo) · Y: lanzar · RB: rotar pila · B: lista · Cruceta y LB: magia 1–5 · LT: manual · Select: mapa · L3: correr · A: saltar",
	-- Tienda
	btn_shop = "Tienda", shop_title = "Tienda de la academia", shop_hint = "Todo es decorativo o de apoyo: nada hace el juego más fácil.",
	shop_buy = "Comprar · {price} R$", shop_on = "Que vuele", shop_off = "A dormir", shop_owned = "✔ Lo tienes", shop_sample = "Muestra (sin ID todavía)", shop_studio = "En Studio todo está desbloqueado para probarlo.",
	item_patron = "Mecenas de la biblioteca", item_patron_d = "Los libros bien colocados brillan del color que elijas.",
	item_pet = "Garabato de mascota", item_pet_d = "El gato alado culpable de todo vuela a tu lado (y se hace el inocente).",
	item_themes = "Temas de luz", item_themes_d = "Ordena bajo una noche estrellada o una tarde de otoño.",
	item_tip_s = "Un café para la rectora", item_tip_s_d = "Propina: apoya el juego. No da nada dentro.",
	item_tip_l = "Pizza para el claustro", item_tip_l_d = "Propina grande: apoya el juego. No da nada dentro.",
	glow_gold = "Dorado", glow_green = "Verde", glow_violet = "Violeta",
	theme_normal = "Normal", theme_stars = "Noche estrellada", theme_autumn = "Otoño",
	opt_glow = "Color del brillo", opt_pet = "Mascota", opt_theme = "Tema de luz",
	n_pass = "¡Gracias! Ya tienes: {item}", n_tip = "¡Gracias por tu apoyo! La rectora brinda con chocolate caliente.",
	err_need_pass = "Necesitas el pase «{item}» (Tienda).",
	time_fmt = "{h} h {m} min",
}

Lang.en = {
	loading = "Opening the library…",
	menu_continue = "Continue", menu_new = "New game", menu_special = "Special stage", menu_options = "Options",
	menu_achievements = "Achievements", menu_back = "Back", menu_slots = "Choose a slot",
	slot_n = "Slot {n}", slot_empty = "Empty", slot_info = "{rows}/400 rows · {books}/3,072 books · {time}",
	slot_finished = "Finished · {rank}", slot_play = "Play", slot_start = "Start here", slot_delete = "Delete",
	confirm_delete = "Delete slot {n}? This can't be undone.", confirm_overwrite = "This slot already has a game. Start over?",
	btn_yes = "Yes", btn_no = "No", btn_ok = "OK", btn_close = "Close", best_time = "Best time: {time}", best_none = "Best time: —",
	warn_no_save = "Unpublished Studio or no DataStore access: this game will NOT be saved.",
	warn_load_failed = "Your save couldn't be loaded: this session won't save, so nothing gets overwritten.",
	warn_guest = "This library belongs to someone else. Taking you to yours…",
	special_locked = "Finish a game to unlock it.",

	hud_rows = "Correct rows {n}/{total}", hud_books = "Books on shelves {n}/{total}",
	hud_next = "{n} more rows for the next point", hud_next_max = "You have every point!",
	hud_points = "{n} point(s) to spend in the handbook ({key})", hud_hand = "{n}/{cap}", hud_hand_empty = "Empty hands",
	hud_vol = "Volume {v}/{n}", hud_section = "Section {code}", hud_cozy = "Cozy mode",
	hud_saving = "Saving…", hud_saved = "Game saved", hud_not_saved = "Not saved",

	aim_pick = "Pick up", aim_place = "Place", aim_full = "You're carrying too many books", aim_empty = "You aren't carrying books",
	aim_key = "Take the key", aim_chest = "Open the chest", aim_chest_locked = "You need the {color} key",
	aim_chest_open = "Chest opened", aim_crystal = "Use the crystal", aim_door = "Leave the library",
	aim_door_locked = "{n} books still need a shelf", aim_letter = "Read the letter", aim_map = "View the map",
	aim_exit_special = "Leave the Archive", aim_painting = "A painting…",

	btn_use = "USE", btn_drop = "Drop", btn_throw = "Throw", btn_list = "List", btn_jump = "Jump", btn_run = "Run",
	btn_manual = "Handbook", btn_map = "Map", btn_options = "Options", btn_menu = "Menu", btn_cycle = "Rotate",
	btn_learn = "Learn", btn_upgrade = "Upgrade", btn_to_menu = "Back to menu", btn_continue = "Keep tidying",
	btn_ultimate = "Z", btn_floor1 = "Floor 1", btn_floor2 = "Floor 2",

	manual_title = "Personal handbook", manual_points = "Points: {n}", manual_hint = "You earn points with your record of correct rows. Each level costs 1 point.",
	sk_sort = "Sort", sk_sort_d = "Sorts the books you carry by series and volume number.",
	sk_guide = "Shelf Guide", sk_guide_d = "Points out the shelf where the top book of your stack belongs.",
	sk_reveal = "Reveal", sk_reveal_d = "Makes the other volumes of the top book's series glow. Change the top book and the series changes too.",
	sk_auto = "Auto-Shelve", sk_auto_d = "While active, aim at a section and press again: every book you carry from that section goes to its place.",
	sk_gather = "Gather", sk_gather_d = "Pulls other volumes of the top book's series into your hands (from floors and tables, never from shelves).",
	sk_level = "Level {l}/{max}", sk_locked = "Not learned", sk_cd = "Cooldown {s} s", sk_dur = "Lasts {s} s",
	sk_count = "Pulls {n} book(s)", sk_range = "Range {n}", sk_instant = "Instant", sk_next = "Next level: {text}",
	n_sorted = "Stack sorted", n_guide = "Guide on", n_reveal = "Reveal on", n_auto = "Auto-Shelve: aim at a section and press {key}",
	n_auto_placed = "{n} book(s) shelved", n_gathered = "{n} book(s) gathered", n_learned = "You learned {name}", n_upgraded = "{name} is now level {l}",

	key_red = "red", key_green = "green", key_yellow = "yellow", key_blue = "blue",
	n_key = "{color} key! Find its chest.", n_chest = "Chest opened!",
	reward_jump = "High Jump: you can now jump (Space), and very high.", reward_run = "Run: hold Shift (or the Run button).",
	reward_cap3 = "Capacity +3: you can now carry {cap} books.", reward_cap2 = "Capacity +2: you can now carry {cap} books.",
	note_title = "A note from the Headmistress",
	note_red = "So you do look behind you now and then. Good. This spell lets you jump very high: use it to reach odd places, not the cookies in the staff room. — O. I.",
	note_green = "Running in the halls is forbidden. Except today. Except you. — O. I.",
	note_yellow = "That vase was my grandmother's. Break it and you'll tidy the cellar too. In return, you can carry 3 more books. — O. I.",
	note_blue = "What were you doing on top of the bookcases? I'd rather not know. Here: 2 more books of capacity. — O. I.",
	n_crystal = "{n} lost book(s) returned to the landing podium.",
	painting_red = "A crest beside a door… and something red shining nearby.",
	painting_green = "A bench covered in books. Something green peeks out underneath.",
	painting_yellow = "A tall vase on the staircase railing.",
	painting_blue = "The back bookcases of floor 2, seen from very high up.",

	n_row = "Correct row!", n_section = "Section {code} complete! Its plate is now blue.", n_point = "New point! Spend it in the handbook ({key}).",
	n_achievement = "Achievement: {name}", n_welcome = "Welcome to the Mistmoon Library", n_door_open = "Every book is on a shelf! The door opens now.",
	n_ultimate_ready = "The ultimate is charged! Press Z.", n_ultimate = "Every book flies to its place!",
	n_returned = "The book fell out and went back to where it started.", n_special = "Special stage: the Archive. Charge the ultimate and press Z.",

	err_generic = "You can't do that.", err_slow = "Slow down!", err_reach = "That's too far away.", err_full = "You can't carry any more.",
	err_empty = "You aren't carrying books.", err_taken = "That slot is taken.", err_gone = "That book isn't there anymore.",
	err_no_points = "No points. Complete rows to earn them.", err_maxed = "Already at max level.", err_not_learned = "You haven't learned that spell yet (handbook: {key}).",
	err_cooldown = "Wait {s} s.", err_no_section_books = "You aren't carrying books from that section.", err_aim_section = "Aim at a section.",
	err_nothing_to_gather = "No volumes of that series left on floors or tables.", err_active = "Already active.",
	err_key_covered = "There are books on top of the key: move them first.", err_key_high = "You can't reach: it's too high.",
	err_need_key = "You need the {color} key.", err_crystal_none = "There are no lost books.",
	err_door_locked = "The door won't open: {n} book(s) still need a shelf.", err_not_owner = "This library belongs to someone else.",
	err_menu = "Pick a game first.", err_ultimate = "The ultimate isn't charged yet.", err_no_jump = "You can't jump yet.",
	err_auto_off = "Turn on Auto-Shelve first (key {key}).",

	letter_title = "A letter from the Headmistress",
	letter_body = "Hello, library helper:\n\nScribble, the academy's winged cat, has done it again: last night it knocked EVERY book in the Mistmoon Library onto the floor. All 3,072 of them.\n\nThe door is enchanted and won't open until every book is back on a shelf.\n\n• Every book has a section (1A, 1B… 2Q). Trust the words in the title; the cover color helps, but sometimes it lies.\n• A whole series goes together in a single row, from volume 1 (left) to the last one (right).\n• 10-volume series go on long shelves; 5- and 3-volume series on short ones.\n• Golden glow: well placed. Red glow: right section, but something's off.\n• When every row of a section is right, its plate turns blue.\n\nGet it all perfect and there will be pizza. Lots of pizza.\n\nP.S.: On the table next to you there are two series to practice with. They go in 1A.\n\n— Ophelia Inkwell, Headmistress of Mistmoon Academy",
	door_title = "The enchanted door",
	door_locked_body = "The door won't budge. A tired voice comes from the keyhole: \"Nobody leaves until all 3,072 books are on shelves.\" {n} to go.",

	tut_letter = "Read the Headmistress's letter: look at it and press {key}.",
	tut_pick = "Pick up the books on the nearby table: look at one and press {key}.",
	tut_place = "Go to section 1A (on your left) and put one series on a long shelf: volume 1 on the left… volume 10 on the right.",
	tut_row = "Correct row! Shelve the other series and watch the plate turn blue once the whole section is right.",
	tut_free = "Now, the rest of the library. Map: {map} · Book list: {list} · Handbook: {manual}",

	res_title = "The Headmistress's review", res_time = "Play time: {time}", res_rows = "Correct rows: {n}/400",
	res_magic = "Major magic used: {v}", res_keys = "Keys found: {n}/4", res_best = "Best time: {time}", res_rank = "Rank",
	res_yes = "yes", res_no = "no", res_new_best = "New record!",
	rank_1 = "You're Fired!", rank_2 = "Scatterbrained Apprentice", rank_3 = "Archive Assistant",
	rank_4 = "Keeper of the Shelves", rank_5 = "Grand Librarian", rank_6 = "Legend of Mistmoon",
	end_normal = "Library restored",
	end_normal_d = "The Headmistress walks the aisles without a word. She stops at one blue plate, then another… and smiles. \"Well done.\" The pizza arrives, if a little cold: it's been a long afternoon.",
	end_pizza = "Pizza!",
	end_pizza_d = "The Headmistress keeps her promise: a huge pizza, still hot, is waiting at the door. Scribble tries to fly off with a slice.",
	end_nomagic = "The Old-Fashioned Way",
	end_nomagic_d = "\"Not a single spell? By hand? All 3,072?\" The Headmistress makes you an honorary member of the faculty and has your broom framed.",
	end_fired = "You're Fired!",
	end_fired_d = "\"SERIOUSLY? Not one correct row. You put every book in the wrong place with an aim I almost admire. You're fired. Scribble, on the other hand, is promoted.\"",
	end_partial = "Almost…",
	end_partial_d = "Every book is on a shelf… but not every book is in its place. The Headmistress sighs: \"It's a start. We'll carry on tomorrow.\"",

	ach_first_row = "First Row", ach_first_row_d = "Complete your first correct row.",
	ach_rows_50 = "Fifty Rows", ach_rows_50_d = "Reach 50 correct rows.",
	ach_rows_200 = "Two Hundred Rows", ach_rows_200_d = "Reach 200 correct rows.",
	ach_rows_400 = "All Plates Blue", ach_rows_400_d = "All 400 rows correct: every plate blue.",
	ach_first_spell = "First Spell", ach_first_spell_d = "Learn your first major magic.",
	ach_all_spells = "All Five Spells", ach_all_spells_d = "Learn all 5 major magics.",
	ach_chests = "Key Hunter", ach_chests_d = "Open all 4 chests.",
	ach_spells_max = "Fully Studied", ach_spells_max_d = "Raise every spell to max level.",
	ach_ultimate = "No Overtime", ach_ultimate_d = "Use the ultimate in the special stage and leave.",
	ach_fired = "You're Fired!", ach_fired_d = "Leave with every book shelved and 0 correct rows.",
	ach_pizza = "Pizza's Still Hot", ach_pizza_d = "Tidy everything correctly in under 3 hours of play.",
	ach_nomagic = "The Old-Fashioned Way", ach_nomagic_d = "Tidy everything correctly without major magic (minor magic is fine).",
	ach_locked = "Locked", ach_done = "Unlocked",

	sp_title = "Special stage: the Archive", sp_ult = "Ultimate", sp_ult_charge = "Charging {p}%", sp_ult_ready = "Ready! Press {key}",
	sp_intro = "Three hundred jumbled books in the Archive. Wait for the ultimate to charge (shelving books charges it faster) and press {key}. This time doesn't count as a record.",
	sp_done = "Archive restored", sp_done_d = "Every book in the Archive is in its place.", sp_badge = "You used the ultimate: no overtime!",

	map_title = "Library map", map_you = "You", map_stairs = "Stairs", map_door = "Exit", map_crystal = "Crystal",
	map_floor = "Floor {f}", map_hint = "Letters zigzag: odd on one side, even on the other, and some at the back.",
	list_title = "Books in hand ({n}/{cap})", list_empty = "You aren't carrying any books.", list_top = "TOP", list_hint = "The top book is the first one placed. Use ▲▼ to change the order.",

	opt_title = "Options", opt_lang = "Language", opt_lang_auto = "Automatic", opt_sens = "Sensitivity", opt_fov = "Field of view",
	opt_bob = "Head bob", opt_music = "Music", opt_sfx = "Sound effects", opt_cozy = "Cozy mode",
	opt_cozy_d = "Hides the timer and freezes the light. The review still counts the time.", opt_left = "Left-handed buttons",
	opt_controls = "Controls",
	help_pc = "WASD: walk · Mouse: look · E or click: pick up / place · R: drop (hold: drop all) · F: throw · Right click: top book goes to the bottom · Tab: list · 1–5: magic · M: map · B: handbook · P: menu · Space: jump · Shift: run",
	help_touch = "Joystick: walk · Drag: look · USE: pick up / place · Drop (hold: all) · Throw · List · 1–5: magic",
	help_pad = "RT: pick up / place · X: drop (hold: all) · Y: throw · RB: rotate stack · B: list · D-pad and LB: magic 1–5 · LT: handbook · Select: map · L3: run · A: jump",
	btn_shop = "Shop", shop_title = "Academy shop", shop_hint = "Everything is cosmetic or a tip: nothing makes the game easier.",
	shop_buy = "Buy · {price} R$", shop_on = "Fly with me", shop_off = "Nap time", shop_owned = "✔ Owned", shop_sample = "Sample (no ID yet)", shop_studio = "In Studio everything is unlocked for testing.",
	item_patron = "Library Patron", item_patron_d = "Well-placed books glow in the color you choose.",
	item_pet = "Scribble Pet", item_pet_d = "The winged cat who caused all this flies beside you (looking innocent).",
	item_themes = "Light Themes", item_themes_d = "Tidy up under a starry night or an autumn afternoon.",
	item_tip_s = "A Coffee for the Headmistress", item_tip_s_d = "Tip: supports the game. Gives nothing in-game.",
	item_tip_l = "Pizza for the Faculty", item_tip_l_d = "Big tip: supports the game. Gives nothing in-game.",
	glow_gold = "Gold", glow_green = "Green", glow_violet = "Violet",
	theme_normal = "Normal", theme_stars = "Starry night", theme_autumn = "Autumn",
	opt_glow = "Glow color", opt_pet = "Pet", opt_theme = "Light theme",
	n_pass = "Thank you! You now own: {item}", n_tip = "Thanks for your support! The Headmistress raises a mug of hot cocoa.",
	err_need_pass = "You need the «{item}» pass (Shop).",
	time_fmt = "{h} h {m} min",
}

function Lang.t(lang: string, key: string, params: { [string]: any }?): string
	local tbl = (Lang :: any)[lang] or Lang.en
	local text = tbl[key] or Lang.en[key] or key
	if params then
		text = string.gsub(text, "{(%w+)}", function(k)
			local v = params[k]
			return v ~= nil and tostring(v) or "{" .. k .. "}"
		end)
	end
	return text
end

-- Tiempo de juego legible: 1 h 05 min / 12 min
function Lang.time(lang: string, seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	if h == 0 then
		return string.format("%d min %02d s", m, s % 60)
	end
	return Lang.t(lang, "time_fmt", { h = h, m = string.format("%02d", m) })
end

return Lang
