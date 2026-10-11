--!strict
-- Las 31 secciones y las 400 series (3.072 libros). Títulos ORIGINALES, en español e inglés.
-- Cada título lleva palabras clave de su sección (tools/harness/check_books.py lo comprueba).
-- Portadas: cada sección tiene una paleta; los colores se solapan A PROPÓSITO entre secciones
-- (blancos: sanación / luz sagrada / filosofía; negro con letras rojas: maldiciones / nigromancia;
-- morados y azules: ilusiones / invocación; marrones: criaturas / mazmorras) para obligar a leer el título.
-- Formato de una serie: S(sección, tomos, "título ES", "título EN", portada opcional).

local BookData = {}

export type Cover = { base: string, text: string, band: string, pos: number, sym: string }
export type Series = { id: number, section: string, volumes: number, es: string, en: string, cover: Cover }
export type Section = {
	code: string,
	floor: number,
	n10: number,
	n5: number,
	n3: number,
	levels: number,
	es: string,
	en: string,
	palette: { base: { string }, band: { string }, text: string, sym: { string } },
	series: { number },
}

-- Secciones: código, planta, nº de series de 10/5/3 tomos, baldas del mueble, tema y paleta
BookData.Sections = ({
	{ code = "1A", floor = 1, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Criaturas y monstruos", en = "Creatures & Monsters",
		palette = { base = { "#6b4423", "#7a5230", "#5a3a1e", "#8b5e3c" }, band = { "#c9a066", "#3d2614", "#a0522d" }, text = "#f2e2c4", sym = { "🐲", "🐺", "🦇", "🐙", "🦂", "🐗", "🐍" } } },
	{ code = "1B", floor = 1, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Astros y adivinación", en = "Stars & Divination",
		palette = { base = { "#1d2a5a", "#2b1f4f", "#16324f" }, band = { "#9ad7ff", "#e0c3ff", "#ffd36e", "#ffffff" }, text = "#ffe9a8", sym = { "✦", "★", "☾", "🔮", "💎" } } },
	{ code = "1C", floor = 1, n10 = 4, n5 = 0, n3 = 8, levels = 4, es = "Maldiciones y cómo romperlas", en = "Curses & Curse-Breaking",
		palette = { base = { "#141414", "#1f1a1a", "#241418" }, band = { "#5b0f12", "#4a4a4a", "#8a1c1c", "#2e1f3a" }, text = "#d6332f", sym = { "⛓", "🕯", "👁", "🗝", "🌑" } } },
	{ code = "1D", floor = 1, n10 = 4, n5 = 0, n3 = 8, levels = 4, es = "Bardos y música mágica", en = "Bards & Spell-Songs",
		palette = { base = { "#b5651d", "#c47a2c", "#8c4a1a", "#a33b20" }, band = { "#ffd36e", "#5a2a10", "#fff1d6" }, text = "#fff1d6", sym = { "♪", "♫", "🎻", "🥁", "🎺" } } },
	{ code = "1E", floor = 1, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Nigromancia", en = "Necromancy",
		palette = { base = { "#101010", "#1a1a1f", "#18120f" }, band = { "#4a4a4a", "#701818", "#2a2a2a", "#3d3d52" }, text = "#e03a3a", sym = { "💀", "🦴", "👻", "🕯", "🌙" } } },
	{ code = "1F", floor = 1, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Transformaciones", en = "Transfiguration",
		palette = { base = { "#1f6b5c", "#2e7d4f", "#15524a", "#3c8a6e" }, band = { "#9be3c9", "#f2c14e", "#0f3a33" }, text = "#e8fff4", sym = { "🐸", "🦋", "🐛", "🐇", "🍄" } } },
	{ code = "1G", floor = 1, n10 = 4, n5 = 0, n3 = 8, levels = 4, es = "Artefactos y encantamientos", en = "Artifacts & Enchanting",
		palette = { base = { "#8a6a2e", "#6e5427", "#a17d3a" }, band = { "#3b6ea5", "#2f2f2f", "#d9b44a", "#7a2e2e" }, text = "#fff7da", sym = { "💍", "🗝", "⚙", "🏺", "✨" } } },
	{ code = "1H", floor = 1, n10 = 4, n5 = 0, n3 = 8, levels = 4, es = "Sigilo e invisibilidad", en = "Stealth & Invisibility",
		palette = { base = { "#2f3236", "#3c3f45", "#25282c" }, band = { "#5d6670", "#1b1d20", "#8a939c", "#46505a" }, text = "#c8ccd2", sym = { "👣", "🌫", "🐾", "🌘", "🎭" } } },
	{ code = "1I", floor = 1, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Ilusiones", en = "Illusions",
		palette = { base = { "#5b2a86", "#6a3fa0", "#47206b", "#3a2a7a" }, band = { "#ff9de2", "#7fe0ff", "#f3e6ff" }, text = "#f3e6ff", sym = { "🌀", "🎩", "👁", "✨", "🃏" } } },
	{ code = "1J", floor = 1, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Invocación", en = "Summoning",
		palette = { base = { "#2a3f8f", "#3a2f8f", "#1f4f9a" }, band = { "#b39dff", "#7fe0ff", "#ffd36e", "#e6f0ff" }, text = "#e6f0ff", sym = { "⭕", "✴", "🌀", "🐾", "🔥" } } },
	{ code = "1K", floor = 1, n10 = 8, n5 = 0, n3 = 0, levels = 4, es = "Sanación", en = "Healing",
		palette = { base = { "#f2f0ea", "#eef3f0", "#f5efe6" }, band = { "#7cc79a", "#e57373", "#4fa3a3", "#b5c99a" }, text = "#2f6f4f", sym = { "🌿", "💚", "🍃", "✚", "🌼" } } },
	{ code = "1L", floor = 1, n10 = 8, n5 = 0, n3 = 0, levels = 4, es = "Luz sagrada", en = "Holy Light",
		palette = { base = { "#f7f3e3", "#f0ece0", "#fbf8ef" }, band = { "#e6c55a", "#8fb3d9", "#d9a441", "#c9d9e6" }, text = "#b08a2e", sym = { "☀", "✧", "🕊", "🌅", "🔆" } } },
	{ code = "1M", floor = 1, n10 = 12, n5 = 8, n3 = 0, levels = 4, es = "Hechizos elementales", en = "Elemental Spells",
		palette = { base = { "#a32121" }, band = { "#cfd8dc" }, text = "#ffffff", sym = { "💎" } } },
	{ code = "1N", floor = 1, n10 = 12, n5 = 8, n3 = 0, levels = 4, es = "Alquimia y pociones", en = "Alchemy & Potions",
		palette = { base = { "#4f6b2a", "#7a5a1a", "#2f5f3f", "#6b3f1f" }, band = { "#e0a030", "#7fd17f", "#f6f0c8" }, text = "#f6f0c8", sym = { "⚗", "🧪", "🌱", "🔥", "💧" } } },

	{ code = "2A", floor = 2, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Guerreros", en = "Warriors",
		palette = { base = { "#5a5f66", "#6b2020", "#4a4f55", "#3e4248" }, band = { "#b22222", "#d4af37", "#e0e0e0" }, text = "#f0f0f0", sym = { "⚔", "🛡", "🗡", "🏰", "🐴" } } },
	{ code = "2B", floor = 2, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Tiro con arco", en = "Archery",
		palette = { base = { "#2f5a2a", "#3d6b35", "#24481f" }, band = { "#a0522d", "#e3c16f", "#f5f0d5", "#1a3015" }, text = "#f5f0d5", sym = { "🏹", "🎯", "🍃", "🌲", "🦅" } } },
	{ code = "2C", floor = 2, n10 = 6, n5 = 0, n3 = 12, levels = 3, es = "Magia del día a día", en = "Everyday Magic",
		palette = { base = { "#f3c6d3", "#c6e2f3", "#f3eac6", "#d3f3c6" }, band = { "#ffffff", "#9a7fb8", "#e0896a" }, text = "#4a3a5a", sym = { "🧹", "🍳", "🧺", "☕", "🧦", "🕯", "🧽" } } },
	{ code = "2D", floor = 2, n10 = 6, n5 = 0, n3 = 12, levels = 3, es = "Aritmancia", en = "Arithmancy",
		palette = { base = { "#1d2f4f", "#203a5f", "#2a2f5f" }, band = { "#f2c14e", "#7fd1ff", "#ffffff", "#ff8a65" }, text = "#ffffff", sym = { "π", "∑", "√", "∞", "÷", "%", "7" } } },
	{ code = "2E", floor = 2, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Bellas artes", en = "Fine Arts",
		palette = { base = { "#d94f4f", "#f2a03d", "#3d8fd9", "#7bc86c", "#b56cd9" }, band = { "#222222", "#ffffff", "#f2e600" }, text = "#ffffff", sym = { "🎨", "🖌", "🗿", "🎭", "🖼" } } },
	{ code = "2F", floor = 2, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Gestión de gremios", en = "Guild Management",
		palette = { base = { "#6b1f2f", "#5a1a28", "#7a2a3a" }, band = { "#d4af37", "#2f2f2f", "#f2e6c9", "#3a5a8a" }, text = "#f2d77a", sym = { "🏰", "📜", "🤝", "🔨", "⚒" } } },
	{ code = "2G", floor = 2, n10 = 6, n5 = 0, n3 = 12, levels = 3, es = "Economía mágica", en = "Magical Economics",
		palette = { base = { "#2e5e3a", "#3a6e44", "#24502e" }, band = { "#d4af37", "#ffffff", "#9ccc65", "#1b3a22" }, text = "#f2d77a", sym = { "💰", "📈", "📉", "⚖", "🏦" } } },
	{ code = "2H", floor = 2, n10 = 6, n5 = 0, n3 = 12, levels = 3, es = "Sociología", en = "Sociology",
		palette = { base = { "#2a7f7f", "#d9773d", "#3a6f8f", "#b8902e" }, band = { "#ffd36e", "#1f1f1f", "#ffffff" }, text = "#ffffff", sym = { "👥", "🏘", "🗣", "🤝", "🎪" } } },
	{ code = "2I", floor = 2, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Psicología", en = "Psychology",
		palette = { base = { "#6e1a1a", "#7a2222", "#5c1515" }, band = { "#e8a0a0", "#2a1010", "#f5d0c0", "#a33a3a" }, text = "#f5d0c0", sym = { "🧠", "💭", "🛋", "❓", "🌀" } } },
	{ code = "2J", floor = 2, n10 = 12, n5 = 0, n3 = 0, levels = 4, es = "Filosofía", en = "Philosophy",
		palette = { base = { "#f4f1ea", "#ece8de", "#f8f6f0" }, band = { "#5a5a8a", "#c0b090", "#8a8a8a", "#2f4a6a" }, text = "#3a3a5a", sym = { "🤔", "🦉", "⏳", "💡", "∞" } } },
	{ code = "2K", floor = 2, n10 = 6, n5 = 0, n3 = 12, levels = 3, es = "Leyes y tribunales", en = "Law & Courts",
		palette = { base = { "#5a3a2a", "#4a2a20", "#6a2a2a" }, band = { "#1f3a5f", "#d4af37", "#e8d8b0", "#2a2a2a" }, text = "#e8d8b0", sym = { "⚖", "📜", "🔨", "🏛", "✒" } } },
	{ code = "2L", floor = 2, n10 = 6, n5 = 0, n3 = 12, levels = 3, es = "Novela romántica", en = "Romance Novels",
		palette = { base = { "#e87fa5", "#d9608a", "#f2a7c1", "#c94f7c" }, band = { "#ffffff", "#b0306a", "#ffd1e3" }, text = "#ffffff", sym = { "💌", "🌹", "💞", "🌸", "🎀" } } },
	{ code = "2M", floor = 2, n10 = 4, n5 = 4, n3 = 0, levels = 4, es = "Novela de misterio", en = "Mystery Fiction",
		palette = { base = { "#1f2433", "#2a2f40", "#33303a" }, band = { "#8a1c1c", "#c0c0c0", "#f2e2a0", "#3a5a6a" }, text = "#f2e2a0", sym = { "🔍", "🗝", "❓", "🕰", "🎩" } } },
	{ code = "2N", floor = 2, n10 = 4, n5 = 4, n3 = 0, levels = 4, es = "Historia", en = "History",
		palette = { base = { "#8a6f4a", "#7a5f3a", "#9a7f55" }, band = { "#4a3520", "#d9c39a", "#2a1f10", "#6a4a2a" }, text = "#2a1f10", sym = { "🏛", "⏳", "📜", "👑", "🗺" } } },
	{ code = "2O", floor = 2, n10 = 4, n5 = 8, n3 = 0, levels = 4, es = "Viajes a otros mundos", en = "Other-World Journeys",
		palette = { base = { "#1aa3a3", "#2a8fbf", "#1f6f8f" }, band = { "#ff6ad5", "#f2f2f2", "#c6ff6a", "#1a1a1a" }, text = "#ffffff", sym = { "📶", "💻", "📱", "🚗", "🌐", "🛰" } } },
	{ code = "2P", floor = 2, n10 = 4, n5 = 4, n3 = 0, levels = 4, es = "Mazmorras", en = "Dungeons",
		palette = { base = { "#5a5550", "#6b5a45", "#4a4540" }, band = { "#8b5e3c", "#2a2a2a", "#c9b38a", "#3d4a3d" }, text = "#e8e0c8", sym = { "🗝", "🕯", "⛓", "🧱", "💰" } } },
	{ code = "2Q", floor = 2, n10 = 4, n5 = 4, n3 = 0, levels = 4, es = "Idiomas", en = "Languages",
		palette = { base = { "#3a6e5a", "#5a3a6e", "#6e5a3a", "#3a4a6e" }, band = { "#f2c14e", "#ffffff", "#ff8a80" }, text = "#ffffff", sym = { "🗣", "Aa", "ᚱ", "✒", "📖" } } },
} :: any) :: { Section } -- `series` se rellena justo debajo

BookData.SectionByCode = {} :: { [string]: Section }
for _, sec in BookData.Sections do
	sec.series = {}
	BookData.SectionByCode[sec.code] = sec
end

BookData.Series = {} :: { Series }
local countIn: { [string]: number } = {}

-- Añade una serie. La portada sale de la paleta de su sección (o de `cover` si se da).
local function S(code: string, volumes: number, es: string, en: string, cover: { [string]: any }?)
	local sec = assert(BookData.SectionByCode[code], "sección desconocida " .. code)
	local i0 = countIn[code] or 0
	countIn[code] = i0 + 1
	local p = sec.palette
	local c: Cover = {
		base = p.base[i0 % #p.base + 1],
		band = p.band[i0 % #p.band + 1],
		pos = (i0 + i0 // #p.base) % 3 + 1,
		sym = p.sym[i0 % #p.sym + 1],
		text = p.text,
	}
	if cover then
		for k, v in cover do
			(c :: any)[k] = v
		end
	end
	local id = #BookData.Series + 1
	BookData.Series[id] = { id = id, section = code, volumes = volumes, es = es, en = en, cover = c }
	table.insert(sec.series, id)
end

---------------------------------------------------------------------
-- PLANTA 1 — magia y criaturas
---------------------------------------------------------------------
-- 1A · Criaturas y monstruos (las dos primeras son las del montón de inicio)
S("1A", 10, "Guía del búho blanco gigante", "The Giant White Owl Handbook", { base = "#6b4423", band = "#ffffff", sym = "🦉", pos = 2 })
S("1A", 10, "Dragones para principiantes absolutos", "Dragons for Total Beginners", { base = "#4a2e17", band = "#e8742c", sym = "🐉", pos = 2 })
S("1A", 10, "Cómo hacerse amigo de un troll de puente", "Befriending a Bridge Troll")
S("1A", 10, "Grifos: plumas, cuidados y pataletas", "Griffins: Feathers, Care and Tantrums")
S("1A", 10, "El kraken que tenía miedo al agua", "The Kraken Who Was Afraid of Water")
S("1A", 10, "Basiliscos: mírales solo los pies", "Basilisks: Only Look at Their Feet")
S("1A", 10, "Hidras: ¿qué cabeza manda aquí?", "Hydras: Which Head Is in Charge?")
S("1A", 10, "Bestias del pantano y sus manías", "Swamp Beasts and Their Quirks")
S("1A", 10, "Quimeras: tres animales, cero acuerdos", "Chimeras: Three Animals, Zero Agreements")
S("1A", 10, "El yeti que siempre tenía frío", "The Yeti Who Was Always Cold")
S("1A", 10, "Criaturas bajo la cama que no pagan alquiler", "Under-the-Bed Creatures Who Pay No Rent")
S("1A", 10, "Ogros: modales en la mesa", "Ogres: Table Manners")

-- 1B · Astros y adivinación
S("1B", 10, "Lo que las estrellas opinan de tu peinado", "What the Stars Think of Your Haircut")
S("1B", 10, "Bola de cristal: manual de limpieza", "Crystal Ball: A Cleaning Manual")
S("1B", 10, "Constelaciones que parecen patos", "Constellations That Look Like Ducks")
S("1B", 10, "Horóscopo para gente que nunca madruga", "Horoscopes for People Who Sleep In")
S("1B", 10, "Profecías que casi aciertan", "Prophecies That Were Almost Right")
S("1B", 10, "La luna llena y otros días de pelo raro", "The Full Moon and Other Bad Hair Days")
S("1B", 10, "Cometas: llegan tarde pero llegan", "Comets: Late, but They Get There")
S("1B", 10, "Adivinación con hojas de té frío", "Divination with Cold Tea Leaves")
S("1B", 10, "Planetas en retroceso y llaves perdidas", "Planets in Retrograde and Lost Keys")
S("1B", 10, "El zodiaco de las mascotas", "The Pet Zodiac")
S("1B", 10, "Cómo leer el destino en un cuenco de sopa", "Reading Your Fate in a Bowl of Soup")
S("1B", 10, "Astrología avanzada para indecisos", "Advanced Astrology for the Undecided")

-- 1C · Maldiciones y cómo romperlas
S("1C", 10, "Maldiciones comunes y cómo romperlas", "Common Curses and How to Break Them")
S("1C", 10, "Mi tetera está maldita: memorias", "My Teapot Is Cursed: A Memoir")
S("1C", 10, "Embrujos de mala suerte nada graves", "Harmless Bad-Luck Hexes")
S("1C", 10, "Contramaldiciones de bolsillo", "Pocket-Sized Curse Breakers")
S("1C", 3, "La maldición del calcetín desparejado", "The Curse of the Odd Sock")
S("1C", 3, "Gafes y otros embrujos de lunes", "Monday Jinxes and Other Hexes")
S("1C", 3, "Romper maldiciones sin romper la vajilla", "Breaking Curses Without Breaking Plates")
S("1C", 3, "El espejo embrujado que solo da la hora", "The Hexed Mirror That Only Tells the Time")
S("1C", 3, "Maldiciones suaves de la abuela", "Grandma's Book of Gentle Curses")
S("1C", 3, "¿Mala suerte o maldición? Test rápido", "Bad Luck or Curse? A Quick Quiz")
S("1C", 3, "El sombrero maldito que no se quita", "The Cursed Hat That Won't Come Off")
S("1C", 3, "Maldiciones antiguas explicadas a mi gato", "Ancient Curses Explained to My Cat")

-- 1D · Bardos y música mágica
S("1D", 10, "El laúd encantado y sus cuerdas rebeldes", "The Enchanted Lute and Its Rebel Strings")
S("1D", 10, "Baladas para dormir dragones", "Ballads to Put Dragons to Sleep")
S("1D", 10, "Bardos ambulantes: guía de supervivencia", "Wandering Bards: A Survival Guide")
S("1D", 10, "Canciones que hacen crecer las plantas", "Songs That Make Plants Grow")
S("1D", 3, "La flauta que solo sabe una melodía", "The Flute That Knows Only One Tune")
S("1D", 3, "Rimas mágicas que no riman", "Magic Rhymes That Don't Rhyme")
S("1D", 3, "Coro de ranas: dirección musical", "Frog Choir: A Conductor's Guide")
S("1D", 3, "El tambor del trueno (bajito, por favor)", "The Thunder Drum (Quietly, Please)")
S("1D", 3, "Arpa para dedos torpes", "Harp for Clumsy Fingers")
S("1D", 3, "Partituras que se escapan del atril", "Sheet Music That Runs Off the Stand")
S("1D", 3, "Cantar bajo la lluvia mágica", "Singing in the Magic Rain")
S("1D", 3, "El bardo que olvidó la letra", "The Bard Who Forgot the Lyrics")

-- 1E · Nigromancia
S("1E", 10, "Esqueletos: postura y buena espalda", "Skeletons: Posture and a Healthy Spine")
S("1E", 10, "Nigromancia para gente muy ordenada", "Necromancy for Very Tidy People")
S("1E", 10, "Mi zombi no quiere ir al colegio", "My Zombie Won't Go to School")
S("1E", 10, "Fantasmas: cómo pedirles que bajen la voz", "Ghosts: How to Ask Them to Keep It Down")
S("1E", 10, "Almas en pena y sus quejas por escrito", "Restless Souls and Their Written Complaints")
S("1E", 10, "La cripta de los calcetines perdidos", "The Crypt of Lost Socks")
S("1E", 10, "Momias: vendajes a la moda", "Mummies: Fashionable Wrappings")
S("1E", 10, "No-muertos en el gimnasio", "The Undead at the Gym")
S("1E", 10, "Huesos que bailan: coreografías", "Dancing Bones: Choreographies")
S("1E", 10, "El nigromante que temía a la oscuridad", "The Necromancer Who Feared the Dark")
S("1E", 10, "Espectros y corrientes de aire", "Specters and Drafty Hallways")
S("1E", 10, "Cómo despertar a un esqueleto con educación", "How to Politely Wake a Skeleton")

-- 1F · Transformaciones
S("1F", 10, "Convertir ranas en príncipes (y al revés)", "Turning Frogs into Princes (and Back)")
S("1F", 10, "Transformaciones que se quedan a medias", "Transformations That Stop Halfway")
S("1F", 10, "Metamorfosis para orugas impacientes", "Metamorphosis for Impatient Caterpillars")
S("1F", 10, "Transfiguración básica: tazas en ratones", "Basic Transfiguration: Mugs into Mice")
S("1F", 10, "Cambiar de forma sin perder las gafas", "Shapeshifting Without Losing Your Glasses")
S("1F", 10, "Cómo transformar una calabaza en algo útil", "How to Transform a Pumpkin into Something Useful")
S("1F", 10, "Me convertí en tetera y nadie lo notó", "I Turned into a Teapot and Nobody Noticed")
S("1F", 10, "Transformar el desayuno en almuerzo", "Transforming Breakfast into Lunch")
S("1F", 10, "Metamorfosis de muebles caprichosos", "Metamorphosis of Moody Furniture")
S("1F", 10, "Transfiguración avanzada: ¿y si es un pato?", "Advanced Transfiguration: What If It's a Duck?")
S("1F", 10, "Cambio de color de pelo en tres pasos", "Changing Hair Color in Three Steps")
S("1F", 10, "Transformaciones de emergencia en clase", "Emergency Transformations in Class")

-- 1G · Artefactos y encantamientos
S("1G", 10, "Encantar objetos sin que se quejen", "Enchanting Objects Without Complaints")
S("1G", 10, "Artefactos antiguos y sus instrucciones perdidas", "Ancient Artifacts and Their Lost Manuals")
S("1G", 10, "Varitas: elegir la tuya sin pelearte", "Wands: Choosing Yours Without a Fuss")
S("1G", 10, "Anillos mágicos que nunca son de tu talla", "Magic Rings That Are Never Your Size")
S("1G", 3, "El amuleto que solo protege del aburrimiento", "The Amulet That Only Protects from Boredom")
S("1G", 3, "Runas para etiquetar tarros", "Runes for Labeling Jars")
S("1G", 3, "Talismanes de oficina", "Office Talismans")
S("1G", 3, "Reliquias que hacen ruido de noche", "Relics That Rattle at Night")
S("1G", 3, "Encantamientos para zapatos que bailan", "Enchantments for Dancing Shoes")
S("1G", 3, "El artefacto que solo hace tostadas", "The Artifact That Only Makes Toast")
S("1G", 3, "Cómo recargar una varita gastada", "How to Recharge a Worn-Out Wand")
S("1G", 3, "Objetos mágicos perdidos en el sofá", "Magic Items Lost in the Sofa")

-- 1H · Sigilo e invisibilidad
S("1H", 10, "Invisibilidad para gente que tropieza", "Invisibility for People Who Trip")
S("1H", 10, "Sigilo en suelos que crujen", "Stealth on Creaky Floors")
S("1H", 10, "El arte de esconderse detrás de una escoba", "The Art of Hiding Behind a Broom")
S("1H", 10, "Capas de invisibilidad: lavado y planchado", "Invisibility Cloaks: Washing and Ironing")
S("1H", 3, "De puntillas por la biblioteca", "Tiptoeing Through the Library")
S("1H", 3, "Sombras que te siguen demasiado", "Shadows That Follow Too Closely")
S("1H", 3, "Pasar desapercibido en una fiesta", "Going Unnoticed at a Party")
S("1H", 3, "Silencio absoluto para quien estornuda", "Total Silence for Sneezers")
S("1H", 3, "Me hice invisible y olvidé cómo volver", "I Went Invisible and Forgot How to Come Back")
S("1H", 3, "Escondites clásicos del gato del castillo", "Classic Hiding Spots of the Castle Cat")
S("1H", 3, "Sigilo nocturno para picar galletas", "Midnight Stealth for Cookie Snacking")
S("1H", 3, "Pasos silenciosos con botas de hierro", "Silent Steps in Iron Boots")

-- 1I · Ilusiones
S("1I", 10, "Ilusiones ópticas para despistar a tu hermano", "Optical Illusions to Confuse Your Brother")
S("1I", 10, "Espejismos en el desierto de la cocina", "Mirages in the Kitchen Desert")
S("1I", 10, "Trucos de magia que salen mal a propósito", "Magic Tricks That Fail on Purpose")
S("1I", 10, "El espejo que te enseña con sombrero", "The Mirror That Shows You in a Hat")
S("1I", 10, "Ilusionismo para tímidos", "Illusions for Shy People")
S("1I", 10, "Puertas falsas y otras ilusiones de pasillo", "Fake Doors and Other Hallway Illusions")
S("1I", 10, "Disfraces ilusorios de último minuto", "Last-Minute Illusory Disguises")
S("1I", 10, "La ilusión de haber hecho los deberes", "The Illusion of Finished Homework")
S("1I", 10, "Trucos de luz con velas y cucharas", "Light Tricks with Candles and Spoons")
S("1I", 10, "Espejismos de pastel: no muerdas", "Cake Mirages: Do Not Bite")
S("1I", 10, "Ilusiones gigantes en sitios pequeños", "Giant Illusions in Small Spaces")
S("1I", 10, "Cuando la ilusión te mira de vuelta", "When the Illusion Looks Back")

-- 1J · Invocación
S("1J", 10, "Invocar sin querer a tu vecino", "Accidentally Summoning Your Neighbor")
S("1J", 10, "Círculos de invocación con tiza de colores", "Summoning Circles in Colored Chalk")
S("1J", 10, "Familiares: elegir mascota mágica", "Familiars: Choosing a Magical Pet")
S("1J", 10, "Portales de bolsillo y sus corrientes de aire", "Pocket Portals and Their Drafts")
S("1J", 10, "Invocar elementales con buenos modales", "Summoning Elementals with Good Manners")
S("1J", 10, "Lo que llega cuando invocas un martes", "What Shows Up When You Summon on a Tuesday")
S("1J", 10, "Invocar pizza: teoría y práctica", "Summoning Pizza: Theory and Practice")
S("1J", 10, "Mi familiar es un pez y no sé qué hacer", "My Familiar Is a Fish and I Don't Know What to Do")
S("1J", 10, "Convocar nubes para regar el huerto", "Conjuring Clouds to Water the Garden")
S("1J", 10, "Invocaciones dobles: cuando vienen dos", "Double Summons: When Two Show Up")
S("1J", 10, "Portales que siempre dan a una cocina", "Portals That Always Lead to a Kitchen")
S("1J", 10, "Devolver lo invocado: política de devoluciones", "Returning Summoned Things: A Refund Policy")

-- 1K · Sanación
S("1K", 10, "Sanación básica para rodillas raspadas", "Basic Healing for Scraped Knees")
S("1K", 10, "Hierbas curativas que saben fatal", "Healing Herbs That Taste Awful")
S("1K", 10, "Remedios caseros para el hipo mágico", "Home Remedies for Magic Hiccups")
S("1K", 10, "Vendajes encantados que se atan solos", "Enchanted Bandages That Tie Themselves")
S("1K", 10, "Curar resfriados de dragón", "Curing Dragon Colds")
S("1K", 10, "Sanar con sopa y paciencia", "Healing with Soup and Patience")
S("1K", 10, "La salud del mago que nunca duerme", "Health Tips for Wizards Who Never Sleep")
S("1K", 10, "Curas rápidas para escobas voladoras", "Quick Cures for Flying Brooms")

-- 1L · Luz sagrada
S("1L", 10, "Luz sagrada para habitaciones oscuras", "Holy Light for Dark Bedrooms")
S("1L", 10, "Bendiciones para el pan del desayuno", "Blessings for Breakfast Bread")
S("1L", 10, "Santuarios portátiles para viajeros", "Portable Sanctuaries for Travelers")
S("1L", 10, "Escudos de luz divina, talla única", "Divine Light Shields, One Size Fits All")
S("1L", 10, "El templo que cerraba a la hora de la siesta", "The Temple That Closed for Naptime")
S("1L", 10, "Conjuros celestiales para días nublados", "Celestial Spells for Cloudy Days")
S("1L", 10, "Bendecir un sombrero paso a paso", "How to Bless a Hat, Step by Step")
S("1L", 10, "El arte sagrado de no hacer ruido", "The Sacred Art of Being Quiet")

-- 1M · Hechizos elementales: «Libro de hechizos: <elemento> – <rango>»
-- Novato/Adepto/Experto = 10 tomos; Maestro/Legendario = 5 tomos
do
	local ELEMENTS = {
		{ es = "Fuego", en = "Fire", color = "#a32121" },
		{ es = "Hielo", en = "Ice", color = "#2f7fb8" },
		{ es = "Rayo", en = "Lightning", color = "#b8960e" },
		{ es = "Tierra", en = "Earth", color = "#6b5a2a" },
	}
	local RANKS = {
		{ es = "Novato", en = "Novice", vols = 10, band = "#cfd8dc", sym = "🔹", pos = 1 },
		{ es = "Adepto", en = "Adept", vols = 10, band = "#64b5f6", sym = "🔷", pos = 2 },
		{ es = "Experto", en = "Expert", vols = 10, band = "#ba68c8", sym = "💠", pos = 3 },
		{ es = "Maestro", en = "Master", vols = 5, band = "#ffd54f", sym = "💎", pos = 1 },
		{ es = "Legendario", en = "Legendary", vols = 5, band = "#ffffff", sym = "👑", pos = 2 },
	}
	for _, r in RANKS do
		for _, e in ELEMENTS do
			S("1M", r.vols, "Libro de hechizos: " .. e.es .. " – " .. r.es, "Spellbook: " .. e.en .. " – " .. r.en,
				{ base = e.color, band = r.band, sym = r.sym, pos = r.pos })
		end
	end
end

-- 1N · Alquimia y pociones: «Libros de alquimia» = 10 tomos; «Tomos de alquimia» = 5 tomos
S("1N", 10, "Libros de alquimia: Pociones que burbujean de alegría", "Alchemy Books: Potions That Bubble with Joy")
S("1N", 10, "Libros de alquimia: Plomo en plomo más brillante", "Alchemy Books: Lead into Shinier Lead")
S("1N", 10, "Libros de alquimia: El caldero perfecto", "Alchemy Books: The Perfect Cauldron")
S("1N", 10, "Libros de alquimia: Ingredientes que huelen a calcetín", "Alchemy Books: Ingredients That Smell Like Socks")
S("1N", 10, "Libros de alquimia: Pociones para plantas tímidas", "Alchemy Books: Potions for Shy Plants")
S("1N", 10, "Libros de alquimia: Destilar luz de luna", "Alchemy Books: Distilling Moonlight")
S("1N", 10, "Libros de alquimia: Errores que hacen ¡puf!", "Alchemy Books: Mistakes That Go Poof")
S("1N", 10, "Libros de alquimia: Piedra filosofal de segunda mano", "Alchemy Books: A Second-Hand Philosopher's Stone")
S("1N", 10, "Libros de alquimia: Elixires para no perder las llaves", "Alchemy Books: Elixirs for Remembering Keys")
S("1N", 10, "Libros de alquimia: Mezclas que cambian de color", "Alchemy Books: Mixtures That Change Color")
S("1N", 10, "Libros de alquimia: Invisibilidad a medias", "Alchemy Books: Half-Strength Invisibility")
S("1N", 10, "Libros de alquimia: El laboratorio ordenado", "Alchemy Books: The Tidy Laboratory")
S("1N", 5, "Tomos de alquimia: Grandes maestros del matraz", "Alchemy Tomes: Great Masters of the Flask")
S("1N", 5, "Tomos de alquimia: Recetas prohibidas por la cocinera", "Alchemy Tomes: Recipes Banned by the Cook")
S("1N", 5, "Tomos de alquimia: Oro, plata y otras excusas", "Alchemy Tomes: Gold, Silver and Other Excuses")
S("1N", 5, "Tomos de alquimia: Antídotos para pociones de risa", "Alchemy Tomes: Antidotes for Laughing Potions")
S("1N", 5, "Tomos de alquimia: El alambique que silbaba", "Alchemy Tomes: The Whistling Alembic")
S("1N", 5, "Tomos de alquimia: Transmutar sin dolor de cabeza", "Alchemy Tomes: Transmuting Without a Headache")
S("1N", 5, "Tomos de alquimia: Pociones de valor para exámenes", "Alchemy Tomes: Courage Potions for Exams")
S("1N", 5, "Tomos de alquimia: Polvo de hada y sus alergias", "Alchemy Tomes: Fairy Dust and Its Allergies")

---------------------------------------------------------------------
-- PLANTA 2 — oficios, sociedad, ficción y estudio
---------------------------------------------------------------------
-- 2A · Guerreros
S("2A", 10, "Guerreros que no madrugan", "Warriors Who Don't Get Up Early")
S("2A", 10, "Armaduras que chirrían: mantenimiento", "Squeaky Armor: A Maintenance Guide")
S("2A", 10, "Entrenamiento de caballeros para principiantes", "Knight Training for Beginners")
S("2A", 10, "Escudos con estilo", "Stylish Shields")
S("2A", 10, "La espada que quería ser cuchara", "The Sword That Wanted to Be a Spoon")
S("2A", 10, "Yelmos y cómo quitárselos sin ayuda", "Helmets and How to Remove Them Alone")
S("2A", 10, "El guerrero valiente que temía a las arañas", "The Brave Warrior Afraid of Spiders")
S("2A", 10, "Duelos de miradas: técnica avanzada", "Staring Duels: Advanced Technique")
S("2A", 10, "Caballeros sin caballo", "Knights Without Horses")
S("2A", 10, "La dieta del guerrero: mucho pan", "The Warrior Diet: Lots of Bread")
S("2A", 10, "Armadura ligera para días de calor", "Light Armor for Hot Days")
S("2A", 10, "Gritos de guerrero que no asustan a nadie", "Warrior Shouts That Scare No One")

-- 2B · Tiro con arco
S("2B", 10, "Puntería para quien no sabe guiñar", "Aim for People Who Can't Wink")
S("2B", 10, "Flechas que vuelven solas", "Arrows That Come Back on Their Own")
S("2B", 10, "El arquero y la manzana nerviosa", "The Archer and the Nervous Apple")
S("2B", 10, "Tiro con arco en días de viento", "Archery on Windy Days")
S("2B", 10, "Dianas que se mueven por diversión", "Targets That Move for Fun")
S("2B", 10, "Carcaj ordenado, mente ordenada", "Tidy Quiver, Tidy Mind")
S("2B", 10, "Arcos largos, brazos cortos", "Long Bows, Short Arms")
S("2B", 10, "Flechas con plumas de pavo real", "Arrows with Peacock Feathers")
S("2B", 10, "Arqueras del bosque: diario de ruta", "Forest Archers: A Trail Diary")
S("2B", 10, "Cómo encontrar flechas en la hierba alta", "Finding Arrows in Tall Grass")
S("2B", 10, "Puntería mágica sin hacer trampas", "Magic Aim Without Cheating")
S("2B", 10, "La diana perfecta existe", "The Perfect Bullseye Exists")

-- 2C · Magia del día a día
S("2C", 10, "Hechizos de limpieza para perezosos", "Cleaning Spells for Lazy Wizards")
S("2C", 10, "La escoba que barre y opina", "The Broom That Sweeps and Judges")
S("2C", 10, "Magia de cocina en cinco minutos", "Five-Minute Kitchen Magic")
S("2C", 10, "Colada sin calcetines perdidos", "Laundry Without Lost Socks")
S("2C", 10, "Encantamientos domésticos del día a día", "Everyday Household Charms")
S("2C", 10, "Ordenar la casa con un chasquido", "Tidying the House with a Snap")
S("2C", 3, "Planchar en casa con aliento de dragón", "Household Ironing with Dragon Breath")
S("2C", 3, "Recados mágicos sin salir de casa", "Magic Errands Without Leaving Home")
S("2C", 3, "Platos de cocina que se friegan solos", "Kitchen Plates That Wash Themselves")
S("2C", 3, "La tetera cotidiana que canta", "The Everyday Teapot That Sings")
S("2C", 3, "Velas que se encienden al llegar a casa", "Candles That Light When You Get Home")
S("2C", 3, "Tareas del hogar para aprendices", "Household Chores for Apprentices")
S("2C", 3, "Hechizos para encontrar cosas en casa", "Spells for Finding Things at Home")
S("2C", 3, "Huerto de casa con magia de balcón", "Home Balcony Garden Magic")
S("2C", 3, "Doblar la colada con la mirada", "Folding Laundry with a Glance")
S("2C", 3, "Cocina mágica para el desayuno", "Magic Kitchen Breakfasts")
S("2C", 3, "Limpieza de chimeneas sin hollín", "Soot-Free Chimney Cleaning")
S("2C", 3, "Magia cotidiana para lunes difíciles", "Everyday Magic for Tough Mondays")

-- 2D · Aritmancia (matemáticas mágicas)
S("2D", 10, "Aritmancia para quien cuenta con los dedos", "Arithmancy for Finger Counters")
S("2D", 10, "Números de la suerte y de la mala suerte", "Lucky and Unlucky Numbers")
S("2D", 10, "Geometría de los círculos mágicos", "The Geometry of Magic Circles")
S("2D", 10, "Ecuaciones que se resuelven solas", "Equations That Solve Themselves")
S("2D", 10, "Matemáticas de bolsillo para magos", "Pocket Mathematics for Wizards")
S("2D", 10, "Calcular pociones de cabeza", "Calculating Potions in Your Head")
S("2D", 3, "Fracciones de pizza: el reparto justo", "Pizza Fractions: Fair Shares")
S("2D", 3, "El triángulo que quería ser cuadrado", "The Triangle That Wanted to Be a Square")
S("2D", 3, "Multiplicar conejos con magia (no lo hagas)", "Multiplying Rabbits with Magic (Don't)")
S("2D", 3, "El número siete y sus manías", "The Number Seven and Its Habits")
S("2D", 3, "Sumas encantadas que dan un poco más", "Enchanted Sums That Add Up a Bit More")
S("2D", 3, "Restas para cuando faltan galletas", "Subtraction for When Cookies Go Missing")
S("2D", 3, "Geometría de las escobas", "Broomstick Geometry")
S("2D", 3, "Ecuaciones con ingredientes", "Equations with Ingredients")
S("2D", 3, "Cifras que cambian de sitio", "Digits That Swap Places")
S("2D", 3, "Matemáticas del calendario lunar", "Lunar Calendar Mathematics")
S("2D", 3, "Números primos y sus primos", "Prime Numbers and Their Cousins")
S("2D", 3, "Aritmancia del cumpleaños", "Birthday Arithmancy")

-- 2E · Bellas artes
S("2E", 10, "Retratos que te siguen con la mirada", "Portraits That Follow You with Their Eyes")
S("2E", 10, "Pintura mágica: colores que se mueven", "Magic Painting: Colors That Move")
S("2E", 10, "Escultura de nubes para principiantes", "Cloud Sculpture for Beginners")
S("2E", 10, "El pincel que pinta lo que quiere", "The Brush That Paints Whatever It Wants")
S("2E", 10, "Acuarelas que se escapan del lienzo", "Watercolors That Escape the Canvas")
S("2E", 10, "Dibujar dragones sin que se ofendan", "Drawing Dragons Without Offending Them")
S("2E", 10, "Museos encantados: guía de visita", "Enchanted Museums: A Visitor's Guide")
S("2E", 10, "Arte abstracto explicado por un troll", "Abstract Art Explained by a Troll")
S("2E", 10, "Cuadros que cambian con el tiempo", "Pictures That Change with the Weather")
S("2E", 10, "Pintar bodegones con fruta inquieta", "Painting Still Lifes with Restless Fruit")
S("2E", 10, "El arte de la caligrafía voladora", "The Art of Flying Calligraphy")
S("2E", 10, "Grandes artistas que eran gatos", "Great Artists Who Were Cats")

-- 2F · Gestión de gremios
S("2F", 10, "Gestión de gremios para recién llegados", "Guild Management for Newcomers")
S("2F", 10, "Reuniones del gremio que pudieron ser una carta", "Guild Meetings That Could Have Been a Letter")
S("2F", 10, "Cuotas del gremio y quién no las paga", "Guild Dues and Who Never Pays Them")
S("2F", 10, "Aprendices: manual de instrucciones", "Apprentices: An Instruction Manual")
S("2F", 10, "El gremio de herreros y su eterna siesta", "The Blacksmiths' Guild and Its Eternal Nap")
S("2F", 10, "Estatutos del gremio en verso", "Guild Bylaws in Verse")
S("2F", 10, "Talleres ordenados, gremios felices", "Tidy Workshops, Happy Guilds")
S("2F", 10, "Cómo fundar un gremio sin discutir", "How to Found a Guild Without Arguing")
S("2F", 10, "Liderar un gremio de magos despistados", "Leading a Guild of Absent-Minded Mages")
S("2F", 10, "El tablón de encargos del gremio", "The Guild Job Board")
S("2F", 10, "Gremios rivales y sus fiestas aburridas", "Rival Guilds and Their Boring Parties")
S("2F", 10, "Miembros fantasma del gremio", "Ghost Members of the Guild")

-- 2G · Economía mágica
S("2G", 10, "Monedas de maná: guía para ahorrar", "Mana Coins: A Saving Guide")
S("2G", 10, "Impuestos sobre el polvo de hada", "Taxes on Fairy Dust")
S("2G", 10, "El mercado de pociones de los martes", "The Tuesday Potion Market")
S("2G", 10, "Economía de los tesoros de dragón", "The Economics of Dragon Hoards")
S("2G", 10, "Precios que suben cuando llegas tú", "Prices That Rise When You Arrive")
S("2G", 10, "Bancos mágicos con colas eternas", "Magic Banks with Endless Lines")
S("2G", 3, "Inflación de calabazas en otoño", "Pumpkin Inflation in Autumn")
S("2G", 3, "Comercio de cromos de hechiceros", "Wizard Card Trading")
S("2G", 3, "Ahorrar monedas en un calcetín encantado", "Saving Coins in an Enchanted Sock")
S("2G", 3, "Las acciones del gremio de escobas", "Broom Guild Stocks")
S("2G", 3, "Dinero que se evapora en la feria", "Money That Evaporates at the Fair")
S("2G", 3, "Mercadillo de trueque de galletas", "The Cookie Swap Market")
S("2G", 3, "Impuestos en el país de los gnomos", "Taxes in Gnome Country")
S("2G", 3, "Precio justo de una escoba usada", "The Fair Price of a Used Broom")
S("2G", 3, "Economía doméstica del aprendiz", "An Apprentice's Home Economics")
S("2G", 3, "Monedas de maná falsas y cómo detectarlas", "Spotting Fake Mana Coins")
S("2G", 3, "El banco de las ranas ahorradoras", "The Bank of Thrifty Frogs")
S("2G", 3, "Mercados que solo abren con luna llena", "Markets That Open Only at Full Moon")

-- 2H · Sociología
S("2H", 10, "Sociología de las colas en la panadería", "The Sociology of Bakery Lines")
S("2H", 10, "Vecinos mágicos y sus costumbres raras", "Magic Neighbors and Their Odd Customs")
S("2H", 10, "La sociedad secreta de los que llegan tarde", "The Secret Society of Latecomers")
S("2H", 10, "Comunidades de gnomos de jardín", "Garden Gnome Communities")
S("2H", 10, "Costumbres sociales de los trolls", "Social Customs of Trolls")
S("2H", 10, "Grupos de estudio que nunca estudian", "Study Groups That Never Study")
S("2H", 3, "Convivencia en una torre de magos", "Community Life in a Wizard Tower")
S("2H", 3, "La tribu que nunca apaga la luz", "The Tribe That Never Turns Off the Lights")
S("2H", 3, "Pueblos pequeños, rumores grandes", "Small Villages, Big Rumors")
S("2H", 3, "Gente que habla en el teatro de sombras", "People Who Talk at the Shadow Theater")
S("2H", 3, "La sociedad de las escobas jubiladas", "The Society of Retired Brooms")
S("2H", 3, "Vecinos que piden sal de madrugada", "Neighbors Who Borrow Salt at Dawn")
S("2H", 3, "Sociología del recreo", "Playground Sociology")
S("2H", 3, "Costumbres de cumpleaños en otros reinos", "Birthday Customs in Other Kingdoms")
S("2H", 3, "Grupos de cotilleo por lechuza", "Owl-Post Gossip Groups")
S("2H", 3, "La comunidad del gato del pueblo", "The Village Cat Community")
S("2H", 3, "Normas sociales del comedor escolar", "Social Rules of the School Cafeteria")
S("2H", 3, "Sociedades de fans de los bardos", "Bard Fan Societies")

-- 2I · Psicología
S("2I", 10, "Psicología de dejarlo todo para mañana", "The Psychology of Leaving It All for Tomorrow")
S("2I", 10, "La mente del gato que tira cosas", "The Mind of a Cat That Knocks Things Over")
S("2I", 10, "Emociones de un dragón incomprendido", "Emotions of a Misunderstood Dragon")
S("2I", 10, "Hábitos de magos muy desordenados", "Habits of Very Messy Wizards")
S("2I", 10, "Sueños raros y lo que no significan", "Weird Dreams and What They Don't Mean")
S("2I", 10, "Motivación para levantarse del sofá", "Motivation to Get Off the Sofa")
S("2I", 10, "Conducta de los aprendices en exámenes", "Apprentice Behavior During Exams")
S("2I", 10, "Tu personalidad según tu sombrero favorito", "Your Personality According to Your Favorite Hat")
S("2I", 10, "El cerebro y las llaves que nunca encuentras", "The Brain and the Keys You Never Find")
S("2I", 10, "Pensar en positivo bajo la lluvia", "Positive Thinking in the Rain")
S("2I", 10, "Psicología de la última galleta", "The Psychology of the Last Cookie")
S("2I", 10, "La mente en blanco el día del examen", "A Blank Mind on Exam Day")

-- 2J · Filosofía
S("2J", 10, "Filosofía para despertarse los lunes", "Philosophy for Waking Up on Mondays")
S("2J", 10, "Pregunta: si un libro cae y nadie lo ordena", "Question: If a Book Falls and No One Shelves It")
S("2J", 10, "La verdad sobre las medias verdades", "The Truth About Half-Truths")
S("2J", 10, "Existir sin prisa", "Existence Without Hurry")
S("2J", 10, "Sabiduría de búho", "Owl Wisdom")
S("2J", 10, "Ética para dragones con tesoro", "Ethics for Dragons with Treasure")
S("2J", 10, "Pensamientos profundos en la bañera", "Deep Thoughts in the Bathtub")
S("2J", 10, "La razón de los calcetines desparejados", "The Reason for Mismatched Socks")
S("2J", 10, "Ideas que llegan justo antes de dormir", "Ideas That Arrive Right Before Sleep")
S("2J", 10, "El sentido de la vida de una seta", "The Meaning of Life for a Mushroom")
S("2J", 10, "Filósofos que no sabían hervir agua", "Philosophers Who Couldn't Boil Water")
S("2J", 10, "Preguntas sin respuesta de un aprendiz", "An Apprentice's Unanswered Questions")

-- 2K · Leyes y tribunales
S("2K", 10, "Leyes mágicas que nadie recuerda", "Magic Laws Nobody Remembers")
S("2K", 10, "Tribunal de dragones: casos curiosos", "The Dragon Court: Curious Cases")
S("2K", 10, "Contratos con letra muy pequeña", "Contracts in Very Small Print")
S("2K", 10, "Derecho de propiedad de las escobas", "Broomstick Property Law")
S("2K", 10, "El juez que dormía la siesta", "The Judge Who Napped in Court")
S("2K", 10, "Normas del castillo para fantasmas", "Castle Rules for Ghosts")
S("2K", 3, "Demandas por ruido contra los grifos", "Noise Lawsuits Against Griffins")
S("2K", 3, "Código de vestimenta para magos", "Dress Code for Wizards")
S("2K", 3, "Juicio al gato que se llevó el pescado", "The Trial of the Fish-Snatching Cat")
S("2K", 3, "Abogados para ranas encantadas", "Lawyers for Enchanted Frogs")
S("2K", 3, "Leyes del recreo", "Playground Laws")
S("2K", 3, "Derecho de paso en puentes de troll", "Legal Right of Way on Troll Bridges")
S("2K", 3, "Contratos firmados con tinta mágica", "Contracts Signed in Magic Ink")
S("2K", 3, "Tribunal de las hadas: apelaciones", "Fairy Court Appeals")
S("2K", 3, "La ley de la última palabra", "The Law of the Last Word")
S("2K", 3, "Normas para prestar libros (y devolverlos)", "Rules for Lending Books (and Returning Them)")
S("2K", 3, "Juezas sabias de los pantanos", "Wise Judges of the Swamps")
S("2K", 3, "Código civil de los gnomos", "The Gnome Civil Code")

-- 2L · Novela romántica: «Novela romántica: …»
S("2L", 10, "Novela romántica: El dragón que quería un abrazo", "Romance Novel: The Dragon Who Wanted a Hug")
S("2L", 10, "Novela romántica: Cartas de amor por lechuza", "Romance Novel: Love Letters by Owl Post")
S("2L", 10, "Novela romántica: Un picnic bajo dos lunas", "Romance Novel: A Picnic Under Two Moons")
S("2L", 10, "Novela romántica: El caballero y la panadera", "Romance Novel: The Knight and the Baker")
S("2L", 10, "Novela romántica: Baile en la torre del reloj", "Romance Novel: A Dance in the Clock Tower")
S("2L", 10, "Novela romántica: Corazones en la biblioteca", "Romance Novel: Hearts in the Library")
S("2L", 3, "Novela romántica: La sirena y el farero", "Romance Novel: The Mermaid and the Lighthouse Keeper")
S("2L", 3, "Novela romántica: Amor a primera poción", "Romance Novel: Love at First Potion")
S("2L", 3, "Novela romántica: El príncipe que prefería ser rana", "Romance Novel: The Prince Who Preferred Being a Frog")
S("2L", 3, "Novela romántica: Flores que solo crecen para ti", "Romance Novel: Flowers That Only Grow for You")
S("2L", 3, "Novela romántica: Una cita en el mercado de maná", "Romance Novel: A Date at the Mana Market")
S("2L", 3, "Novela romántica: El bardo enamorado de la luna", "Romance Novel: The Bard Who Loved the Moon")
S("2L", 3, "Novela romántica: Dos escobas y un destino", "Romance Novel: Two Brooms and One Destiny")
S("2L", 3, "Novela romántica: Suspiros entre estanterías", "Romance Novel: Sighs Between the Shelves")
S("2L", 3, "Novela romántica: El mago que nunca olvidaba un aniversario", "Romance Novel: The Wizard Who Never Forgot an Anniversary")
S("2L", 3, "Novela romántica: Paseos en barca por el lago encantado", "Romance Novel: Boat Rides on the Enchanted Lake")
S("2L", 3, "Novela romántica: Cartas que se escriben solas", "Romance Novel: Letters That Write Themselves")
S("2L", 3, "Novela romántica: Un sombrero para dos", "Romance Novel: One Hat for Two")

-- 2M · Novela de misterio: «Ficción de misterio: …»
S("2M", 10, "Ficción de misterio: ¿Quién se comió la tarta del claustro?", "Mystery Fiction: Who Ate the Faculty Cake?")
S("2M", 10, "Ficción de misterio: El caso del calcetín desaparecido", "Mystery Fiction: The Case of the Vanishing Sock")
S("2M", 10, "Ficción de misterio: Pisadas de barro en el tejado", "Mystery Fiction: Muddy Footprints on the Roof")
S("2M", 10, "Ficción de misterio: La llave que lo abría todo menos una puerta", "Mystery Fiction: The Key That Opened All but One Door")
S("2M", 5, "Ficción de misterio: El reloj que se adelantaba a propósito", "Mystery Fiction: The Clock That Ran Fast on Purpose")
S("2M", 5, "Ficción de misterio: Huellas de gato en la tinta", "Mystery Fiction: Cat Prints in the Ink")
S("2M", 5, "Ficción de misterio: El misterio de la biblioteca desordenada", "Mystery Fiction: The Mystery of the Messy Library")
S("2M", 5, "Ficción de misterio: Un detective con sombrero de copa", "Mystery Fiction: A Detective in a Top Hat")

-- 2N · Historia
S("2N", 10, "Historia de los reinos olvidados", "A History of Forgotten Kingdoms")
S("2N", 10, "Crónicas del rey que no quería corona", "Chronicles of the King Who Didn't Want a Crown")
S("2N", 10, "Castillos antiguos y sus goteras", "Ancient Castles and Their Leaky Roofs")
S("2N", 10, "El imperio de los gatos", "The Cat Empire")
S("2N", 5, "Reinas que inventaron el té", "Queens Who Invented Tea")
S("2N", 5, "Siglos de sombreros puntiagudos", "Centuries of Pointy Hats")
S("2N", 5, "La era de las escobas de carreras", "The Era of Racing Brooms")
S("2N", 5, "Dinastías de dragones bibliotecarios", "Dynasties of Librarian Dragons")

-- 2O · Viajes a otros mundos (un mundo sin magia… pero con wifi)
S("2O", 10, "Despertar en un mundo sin magia", "Waking Up in a World Without Magic")
S("2O", 10, "El misterio del wifi: magia invisible", "The Wifi Mystery: Invisible Magic")
S("2O", 10, "Internet para magos: primeros pasos", "Internet for Wizards: First Steps")
S("2O", 10, "Carruajes sin caballos llamados coches", "Horseless Carriages Called Cars")
S("2O", 5, "La caja que brilla y se llama pantalla", "The Glowing Box Called a Screen")
S("2O", 5, "Contraseñas: hechizos que siempre olvidas", "Passwords: Spells You Always Forget")
S("2O", 5, "Batería baja: una maldición moderna", "Low Battery: A Modern Curse")
S("2O", 5, "Mi móvil no lanza bolas de fuego", "My Phone Can't Cast Fireballs")
S("2O", 5, "Máquinas que hacen café sin conjuros", "Machines That Make Coffee Without Spells")
S("2O", 5, "Viaje a otro mundo con billete de vuelta", "A Trip to Another World, Return Ticket Included")
S("2O", 5, "El ordenador que no obedece a la varita", "The Computer That Ignores Your Wand")
S("2O", 5, "Volver del otro mundo con recuerdos", "Back from the Other World with Souvenirs")

-- 2P · Mazmorras
S("2P", 10, "Mazmorras para principiantes con farol", "Dungeons for Beginners with a Lantern")
S("2P", 10, "Trampas que solo pillan a quien las pone", "Traps That Only Catch Whoever Set Them")
S("2P", 10, "Pasadizos secretos detrás de los cuadros", "Secret Passages Behind Paintings")
S("2P", 10, "El laberinto que cambiaba los lunes", "The Labyrinth That Changed on Mondays")
S("2P", 5, "Cofres del tesoro que mordisquean un poco", "Treasure Chests That Nibble a Little")
S("2P", 5, "Túneles húmedos y calcetines mojados", "Damp Tunnels and Wet Socks")
S("2P", 5, "El sótano de la academia: no bajar", "The Academy Cellar: Do Not Enter")
S("2P", 5, "Mapas de mazmorras dibujados con prisa", "Dungeon Maps Drawn in a Hurry")

-- 2Q · Idiomas
S("2Q", 10, "Élfico para viajeros: frases útiles", "Elvish for Travelers: Useful Phrases")
S("2Q", 10, "Gramática enana sin lágrimas", "Dwarvish Grammar Without Tears")
S("2Q", 10, "Dracónico básico: cómo pedir perdón", "Basic Draconic: How to Say Sorry")
S("2Q", 10, "Diccionario de palabras que no existen", "A Dictionary of Words That Don't Exist")
S("2Q", 5, "Traducir lo que dice tu gato", "Translating What Your Cat Says")
S("2Q", 5, "Verbos irregulares de los trolls", "Irregular Verbs of the Trolls")
S("2Q", 5, "Pronunciación de hechizos larguísimos", "Pronouncing Very Long Spells")
S("2Q", 5, "Idiomas de las sirenas: burbujas y tonos", "Mermaid Languages: Bubbles and Tones")

---------------------------------------------------------------------
-- Comprobaciones (si algo no cuadra, el juego no arranca)
---------------------------------------------------------------------
do
	local n10, n5, n3, books = 0, 0, 0, 0
	local perFloor = { 0, 0 }
	for _, sec in BookData.Sections do
		local c = { [10] = 0, [5] = 0, [3] = 0 }
		for _, id in sec.series do
			local s = BookData.Series[id]
			c[s.volumes] += 1
			books += s.volumes
			if s.volumes == 10 then
				perFloor[sec.floor] += 1
			end
		end
		assert(c[10] == sec.n10 and c[5] == sec.n5 and c[3] == sec.n3, "recuento de series incorrecto en " .. sec.code)
		n10 += c[10]
		n5 += c[5]
		n3 += c[3]
	end
	assert(#BookData.Sections == 31, "deben ser 31 secciones")
	assert(n10 == 256 and n5 == 40 and n3 == 104, "deben ser 256 series de 10, 40 de 5 y 104 de 3")
	assert(#BookData.Series == 400, "deben ser 400 series")
	assert(books == 3072, "deben ser 3.072 libros")
	assert(perFloor[1] == 128 and perFloor[2] == 128, "deben ser 128 series de 10 en cada planta")
end

-- Pasa "#rrggbb" a Color3
function BookData.color(hex: string): Color3
	local r = tonumber(string.sub(hex, 2, 3), 16) or 0
	local g = tonumber(string.sub(hex, 4, 5), 16) or 0
	local b = tonumber(string.sub(hex, 6, 7), 16) or 0
	return Color3.fromRGB(r, g, b)
end

-- Título en el idioma pedido
function BookData.title(seriesId: number, lang: string): string
	local s = BookData.Series[seriesId]
	return if lang == "es" then s.es else s.en
end

function BookData.sectionName(code: string, lang: string): string
	local sec = BookData.SectionByCode[code]
	if not sec then
		return code
	end
	return if lang == "es" then sec.es else sec.en
end

return BookData
