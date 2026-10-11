"""Comprueba los 400 títulos y los textos del juego.
Uso: python3 -I check_books.py <datos.json>   (lo genera dump_data.luau)
- Recuentos de la tabla de secciones (31 secciones, 400 series, 3.072 libros, 10/5/3 tomos).
- Títulos únicos, en español e inglés, con longitud máxima.
- Cada título lleva al menos una PALABRA CLAVE de su sección (la pista fiable para ordenar).
- Ninguna palabra prohibida (para que el cuestionario de Roblox salga «Mínimo»), también en Lang.
- Portadas distintas dentro de cada sección.
Sale con error si algo falla.
"""
import json
import re
import sys
import unicodedata

data = json.load(open(sys.argv[1], encoding="utf-8"))
errors = []

MAX_LEN = 70

# Palabras clave por sección (sin tildes, en minúsculas; valen si una palabra del título EMPIEZA por ellas)
KEYWORDS = {
	"1A": ("monstruo, criatura, bestia, dragon, troll, grifo, buho, quimera, kraken, basilisco, hidra, yeti, ogro",
		"monster, creature, beast, dragon, troll, griffin, owl, chimera, kraken, basilisk, hydra, yeti, ogre"),
	"1B": ("estrella, astro, horoscopo, constelacion, luna, adivina, profecia, cristal, cometa, planeta, zodiaco, destino",
		"star, astrolog, horoscope, constellation, moon, divination, prophec, crystal, comet, planet, zodiac, fate"),
	"1C": ("maldicion, maldit, contramaldic, embruj, gafe, mala suerte", "curse, hex, jinx, bad luck, bad-luck"),
	"1D": ("bardo, cancion, music, melodia, laud, balada, coro, cantar, arpa, partitura, rima, flauta, tambor",
		"bard, song, music, melody, lute, ballad, choir, sing, harp, rhyme, flute, drum, tune"),
	"1E": ("nigroman, esqueleto, zombi, fantasma, alma, cripta, momia, no-muerto, hueso, espectro",
		"necroman, skeleton, zombie, ghost, soul, crypt, mumm, undead, bones, specter"),
	"1F": ("transform, transfigura, convert, metamorfosis, cambiar de forma, cambio, rana",
		"transform, transfigur, turn, metamorphosis, shapeshift, chang, frog"),
	"1G": ("encant, artefacto, varita, anillo, amuleto, runa, talisman, reliquia, objetos magicos",
		"enchant, artifact, wand, ring, amulet, rune, talisman, relic, magic items"),
	"1H": ("invisib, sigilo, escond, capa, puntillas, sombra, desapercibido, silencio",
		"invisib, stealth, hid, cloak, tiptoe, shadow, unnoticed, silen"),
	"1I": ("ilusi, ilusori, espejismo, truco, espejo, disfraz, falsa", "illusi, mirage, trick, mirror, disguise, fake"),
	"1J": ("invoca, convocar, familiar, portal", "summon, conjur, familiar, portal"),
	"1K": ("sana, curar, curativ, cura, remedio, vendaje, salud", "heal, cure, curing, remed, bandage, health"),
	"1L": ("sagrad, bendic, bendecir, santuario, divin, templo, celestial", "holy, bless, sanctuar, divine, temple, celestial, sacred"),
	"1M": ("libro de hechizos", "spellbook"),
	"1N": ("libros de alquimia, tomos de alquimia", "alchemy books, alchemy tomes"),
	"2A": ("guerrero, armadura, caballero, escudo, espada, yelmo, duelo", "warrior, armor, knight, shield, sword, helmet, duel"),
	"2B": ("punteria, flecha, arquero, arquera, arco, diana, carcaj", "aim, arrow, archer, archery, bow, bullseye, target, quiver"),
	"2C": ("limpieza, escoba, cocina, colada, domestic, casa, cotidian, hogar, dia a dia", "cleaning, broom, kitchen, laundry, household, home, house, tidy, everyday, chore"),
	"2D": ("aritmancia, numero, geometria, ecuacion, matematica, calcul, fraccion, triangulo, multiplicar, suma, resta, cifra",
		"arithmancy, number, geometry, equation, mathematic, calculat, fraction, triangle, multiplying, sum, subtraction, digit"),
	"2E": ("retrato, pintura, pintar, escultura, pincel, acuarela, dibujar, museo, arte, artista, cuadro",
		"portrait, painting, sculpture, brush, watercolor, drawing, museum, art, picture"),
	"2F": ("gremio, aprendic", "guild, apprentice"),
	"2G": ("moneda, impuesto, mercad, economia, precio, banco, inflacion, comercio, ahorrar, acciones, dinero",
		"coin, tax, market, economic, price, bank, inflation, trading, saving, stock, money"),
	"2H": ("sociolog, vecino, sociedad, comunidad, costumbre, grupo, convivencia, tribu, pueblo, gente, social",
		"sociolog, neighbor, societ, communit, custom, group, tribe, village, people, social"),
	"2I": ("psicolog, mente, emocion, habito, sueno, motivacion, conducta, personalidad, cerebro, pensar",
		"psycholog, mind, emotion, habit, dream, motivation, behavior, personality, brain, thinking"),
	"2J": ("filosof, pregunta, verdad, existir, sabiduria, etica, pensamiento, razon, idea, sentido",
		"philosoph, question, truth, existence, wisdom, ethic, thought, reason, idea, meaning"),
	"2K": ("ley, tribunal, contrato, derecho, juez, norma, demanda, codigo, juicio, abogado",
		"law, court, contract, judge, rules, lawsuit, code, trial, lawyer, legal"),
	"2L": ("novela romantica", "romance novel"),
	"2M": ("ficcion de misterio", "mystery fiction"),
	"2N": ("historia, cronica, antiguo, imperio, reina, siglo, era, dinastia", "history, chronicle, ancient, empire, queen, centur, era, dynast"),
	"2O": ("mundo, wifi, internet, coche, pantalla, contrasena, bateria, movil, maquina, ordenador",
		"world, wifi, internet, car, screen, password, battery, phone, machine, computer"),
	"2P": ("mazmorra, trampa, pasadizo, laberinto, tesoro, tunel, sotano", "dungeon, trap, passage, labyrinth, treasure, tunnel, cellar"),
	"2Q": ("elfico, enana, draconico, diccionario, traducir, verbo, pronunciacion, idioma", "elvish, dwarvish, draconic, dictionary, translat, verb, pronounc, language"),
}

# Palabras prohibidas (palabra entera, sin tildes). Nada de palabrotas, caca, insinuaciones,
# alcohol, apuestas, sangre ni muerte explícita.
FORBIDDEN = """
caca pedo pedos culo mierda joder puta puto cono gilipollas imbecil idiota estupido estupida tonto tonta
subcubo sucubo seduccion seducir seductor sexy sexo desnudo desnuda besar beso besos borracho borracha
cerveza vino vinos alcohol licor droga drogas apuesta apuestas apostar casino sangre sangriento matar mata
asesino asesinar asesinato muerte muerto muerta morir suicidio pistola arma armas tortura vomito
poop fart farts butt damn hell crap stupid idiot dumb succubus seduce seduction seductive sexy sex naked nude
kiss kissing drunk beer wine liquor alcohol drug drugs gamble gambling bet bets betting casino blood bloody
kill killing killer murder death dead die dying suicide gun guns weapon torture vomit
""".split()

def norm(text):
	t = unicodedata.normalize("NFD", text.lower())
	return "".join(c for c in t if unicodedata.category(c) != "Mn")

def words(text):
	return set(re.findall(r"[a-z0-9]+", norm(text)))

sections = {s["code"]: s for s in data["sections"]}
series = data["series"]

# Recuentos
if len(sections) != 31:
	errors.append(f"hay {len(sections)} secciones (deben ser 31)")
counts = {10: 0, 5: 0, 3: 0}
for s in series:
	counts[s["volumes"]] += 1
if len(series) != 400 or counts != {10: 256, 5: 40, 3: 104}:
	errors.append(f"recuentos de series incorrectos: {len(series)} {counts}")
if sum(s["volumes"] for s in series) != 3072:
	errors.append("no suman 3.072 libros")

seen = {"es": {}, "en": {}}
covers = {}
for s in series:
	code = s["section"]
	for lang in ("es", "en"):
		t = s[lang]
		if not t.strip():
			errors.append(f"serie {s['id']} sin título {lang}")
		if len(t) > MAX_LEN:
			errors.append(f"serie {s['id']} ({lang}) demasiado larga ({len(t)}): {t}")
		key = norm(t)
		if key in seen[lang]:
			errors.append(f"título repetido ({lang}): {t} (series {seen[lang][key]} y {s['id']})")
		seen[lang][key] = s["id"]
		kws = [k.strip() for k in KEYWORDS[code][0 if lang == "es" else 1].split(",")]
		nt = norm(t)
		if not any(re.search(r"\b" + re.escape(k), nt) for k in kws):
			errors.append(f"sin palabra clave de {code} ({lang}): {t}")
		bad = words(t) & set(FORBIDDEN)
		if bad:
			errors.append(f"palabra prohibida {bad} en: {t}")
	c = s["cover"]
	combo = (code, c["base"], c["band"], c["pos"], c["sym"])
	if combo in covers:
		errors.append(f"portada repetida en {code}: series {covers[combo]} y {s['id']}")
	covers[combo] = s["id"]

# Las frases de prefijo tienen que coincidir con la longitud (pista del original)
for s in series:
	if s["section"] == "1N":
		if s["es"].startswith("Libros de alquimia") != (s["volumes"] == 10):
			errors.append(f"prefijo de alquimia y tomos no cuadran: {s['es']}")
	if s["section"] == "1M":
		rank10 = any(r in s["es"] for r in ("Novato", "Adepto", "Experto"))
		if rank10 != (s["volumes"] == 10):
			errors.append(f"rango de hechizo y tomos no cuadran: {s['es']}")

# Textos de la interfaz: sin palabras prohibidas
for lang in ("es", "en"):
	for k, v in data["lang"][lang].items():
		if isinstance(v, str):
			bad = words(v) & set(FORBIDDEN)
			if bad:
				errors.append(f"Lang.{lang}.{k}: palabra prohibida {bad}")

if errors:
	print("\n".join(errors))
	print(f"FALLOS: {len(errors)}")
	sys.exit(1)
print(f"Libros OK: 31 secciones · 400 series · 3.072 libros · {len(seen['es'])} títulos únicos en ES y EN · palabras clave y portadas correctas")
