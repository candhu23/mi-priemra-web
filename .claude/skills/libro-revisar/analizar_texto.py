#!/usr/bin/env python3
"""Analizador de prosa en ESPAÑOL para revisar capítulos de un libro (solo librería estándar).

Mide cosas objetivas que un editor revisaría y las señala con su línea:
  - Legibilidad INFLESZ (Szigriszt-Pazos/Barrio) y longitud de frases (media, variación, frases muy largas)
  - Palabras repetidas cerca (mismo «tronco» en menos de 40 palabras)
  - Adverbios en -mente, gerundios, pasivas con «ser + participio»
  - Muletillas, clichés y giros típicos de texto generado por IA
  - «Decir» las emociones en vez de mostrarlas («estaba triste», «sintió miedo»)
  - Verbos filtro («vio que», «notó que», «pensó que») que alejan al lector
  - Diálogos: comillas o guion corto en vez de raya (—), espacio tras la raya, acotaciones
  - Dequeísmo frecuente («pienso de que», «me dijo de que»)
  - Verbos de habla rebuscados («espetó», «inquirió»…) frente a «dijo»

Uso:
  python3 -I analizar_texto.py <archivo.md | carpeta> [--salida informe.md] [--max 25]
Con una carpeta, analiza cada .md/.txt (capítulos) y añade una tabla por capítulo.
Es una AYUDA: cada aviso hay que mirarlo en contexto (a veces una repetición o un gerundio están bien).
"""
import argparse
import os
import re
import statistics
import sys
import unicodedata

LETRAS = "A-Za-zÁÉÍÓÚÜÑáéíóúüñ"
RE_PALABRA = re.compile(rf"[{LETRAS}]+")
FUERTES = set("aeoáéó")
VOCALES = set("aeiouáéíóúü")

STOP = set("""a al algo algunas algunos ante antes aquel aquella aquellas aquellos aqui aquí así aun aún bajo bien cada casi
como cómo con contra cual cuál cuando cuándo de del desde donde dónde dos el él ella ellas ello ellos en entre era eran
eres es esa esas ese eso esos esta está estaba estaban estado estar estas este esto estos fue fueron ha había habían han
hasta hay la las le les lo los más me mi mí mis mucho muy nada ni no nos nosotros o otra otras otro otros para pero poco
por porque que qué quien quién se sea ser si sí sido sin sobre solo sólo son su sus también tan tanto te tenía tiene
todo todos tu tú tus un una uno unos unas usted ya yo cosa cosas hacia mientras después entonces luego siempre nunca
había habría hubiera había tenía tener hacer hizo dijo decir dice iba ir vez veces aunque mismo misma""".split())

MULETILLAS = [
	"de repente", "de pronto", "en ese momento", "en aquel momento", "en ese instante", "acto seguido",
	"sin previo aviso", "comenzó a", "empezó a", "se dio cuenta", "no pudo evitar", "no podía evitar",
	"un escalofrío le recorrió", "un escalofrío recorrió", "contuvo la respiración", "contuvo el aliento",
	"soltó un suspiro", "dejó escapar un suspiro", "como platos", "el corazón le latía", "el corazón le dio un vuelco",
	"tragó saliva", "se le heló la sangre", "una sonrisa se dibujó", "una lágrima rodó", "sus miradas se cruzaron",
	"el tiempo se detuvo", "a decir verdad", "por así decirlo", "cabe destacar", "cabe mencionar", "es importante",
	"sin lugar a dudas", "de alguna manera", "de algún modo", "en cierto modo", "un sinfín de", "blanco como la nieve",
	"negro como la noche", "frío como el hielo", "silencio sepulcral", "más allá de las palabras",
]
FRASES_IA = [
	"tapiz", "un baile de", "una danza de", "danzaban", "sinfonía de", "susurro del viento", "en un mundo donde",
	"testamento de", "testimonio silencioso", "intrincad", "palpable", "eco de", "resonaba en su alma",
	"crisol", "vibrante", "entrelazad", "navegar por", "un viaje de autodescubrimiento", "en el corazón de",
	"no era solo", "no solo era", "algo cambió para siempre", "nada volvería a ser igual", "mezcla de emociones",
	"cada fibra de su ser", "sin saber que", "lo que no sabía era", "el destino tenía otros planes",
]
EMOCIONES = r"(triste|tristeza|feliz|felicidad|furios[oa]|enfadad[oa]|rabia|ira|asustad[oa]|miedo|nervios[oa]|nervios|celos[oa]|celos|ansios[oa]|ansiedad|emocionad[oa]|avergonzad[oa]|vergüenza|aliviad[oa]|alivio|culpable|culpa|sorprendid[oa]|sorpresa|confundid[oa]|frustrad[oa]|frustración|desesperad[oa]|orgullos[oa]|orgullo|solitari[oa]|soledad|enamorad[oa]|angustia|angustiad[oa])"
RE_DECIR_EMOCION = re.compile(rf"\b(estaba|estaban|se sentía|se sentían|sintió|sentía|sentían|notaba|se notaba)\s+(un[ao]?\s+|much[oa]\s+|tant[oa]\s+|muy\s+|algo\s+|de\s+)?{EMOCIONES}\b", re.I)
RE_FILTRO = re.compile(r"\b(vio|veía|oyó|oía|escuchó|sintió|notó|notaba|pensó|pensaba|se dio cuenta de|observó|percibió|recordó|sabía)\s+que\b", re.I)
RE_DEQUEISMO = re.compile(r"\b(pienso|piensa|pensaba|creo|cree|creía|opino|opina|dijo|dije|digo|me dijo|le dijo|supongo|resulta|parece|considero|considera|es seguro|es posible|es probable)\s+de\s+que\b", re.I)
RE_PASIVA = re.compile(r"\b(fue|fueron|era|eran|será|serán|sido|ser)\s+([a-záéíóúñ]+(ado|ada|ados|adas|ido|ida|idos|idas)|(abiert|escrit|hech|dich|vist|puest|rot|muert|cubiert|vuelt|resuelt|descubiert|devuelt|impres)[oa]s?)\b", re.I)
RE_GERUNDIO = re.compile(r"\b[a-záéíóúñ]+(ando|iendo|yendo)\b", re.I)
RE_MENTE = re.compile(r"\b[a-záéíóúñ]{3,}mente\b", re.I)
VERBOS_HABLA_RAROS = ["espetó", "inquirió", "masculló", "farfulló", "musitó", "bramó", "siseó", "rugió", "exclamó",
	"replicó", "repuso", "terció", "barbotó", "graznó", "gruñó", "vociferó", "sentenció", "concluyó", "aseveró"]


def sin_tildes(s):
	return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


def silabas(palabra):
	p = palabra.lower()
	p = re.sub(r"(?<=[qg])u(?=[eiéí])", "", p).replace("ü", "u")
	n, anterior = 0, None
	for c in p:
		if c in VOCALES:
			if anterior is None:
				n += 1
			elif (anterior in FUERTES and c in FUERTES) or c in "íú" or anterior in "íú":
				n += 1  # hiato
			anterior = c
		else:
			anterior = None
	return max(1, n)


def tronco(p):
	p = sin_tildes(p.lower())
	for fin in ("amente", "mente", "aciones", "acion", "ando", "iendo", "aban", "iban", "aron", "ieron", "aba", "ian",
				"ados", "adas", "idos", "idas", "ado", "ada", "ido", "ida", "es", "s"):
		if p.endswith(fin) and len(p) - len(fin) >= 4:
			return p[: -len(fin)]
	return p


def frases(texto):
	# Separar por fin de frase y por cambios de párrafo (cada línea de diálogo cuenta)
	trozos = []
	for parrafo in re.split(r"\n\s*\n|\n(?=\s*[—\-«\"])", texto):
		for f in re.split(r"(?<=[.!?…])[»\"”]?\s+", parrafo):
			if RE_PALABRA.search(f):
				trozos.append(f.strip())
	return trozos


def inflesz(n_sil, n_pal, n_fra):
	if not n_pal or not n_fra:
		return None
	return 206.835 - 62.3 * (n_sil / n_pal) - (n_pal / n_fra)


def nivel_inflesz(v):
	if v is None:
		return "—"
	if v < 40:
		return "muy difícil"
	if v < 55:
		return "algo difícil"
	if v < 65:
		return "normal"
	if v < 80:
		return "bastante fácil"
	return "muy fácil"


def analizar(texto, nombre=""):
	lineas = texto.splitlines()
	# Quitar cabeceras Markdown y comentarios de la cuenta
	cuerpo = "\n".join(l for l in lineas if not l.lstrip().startswith(("#", "<!--", ">")))
	palabras = RE_PALABRA.findall(cuerpo)
	n_pal = len(palabras)
	fr = frases(cuerpo)
	largos = [len(RE_PALABRA.findall(f)) for f in fr]
	n_sil = sum(silabas(p) for p in palabras)
	avisos = []  # (tipo, línea, texto)

	def marcar(tipo, idx, detalle):
		avisos.append((tipo, idx + 1, detalle))

	dialogos = 0
	for i, l in enumerate(lineas):
		s = l.strip()
		if not s or s.startswith(("#", "<!--", ">")):
			continue
		bajo = s.lower()
		# Diálogos
		if s.startswith("—"):
			dialogos += 1
			if re.match(r"—\s", s):
				marcar("dialogo", i, "espacio después de la raya de apertura: «— Hola» → «—Hola»")
		elif re.match(r"^[-–]\s?\S", s):
			marcar("dialogo", i, "diálogo con guion corto: usa la raya larga (—)")
		elif re.match(r'^[«"“]', s) and re.search(r'[»"”]\s*[,.]?\s*[—-]?\s*(dijo|preguntó|respondió|contestó)', s):
			marcar("dialogo", i, "diálogo entre comillas: en narrativa en español va con raya (—)")
		for m in re.finditer(r"—\s?([A-ZÁÉÍÓÚ][a-záéíóú]+)ó\b", s):
			if m.group(1).lower() + "ó" in ("dijo", "preguntó", "respondió", "contestó", "murmuró", "gritó"):
				marcar("dialogo", i, f"acotación en mayúscula («—{m.group(1)}ó»): tras la raya, el verbo de habla va en minúscula")
		# Muletillas, clichés y giros de IA
		for f in MULETILLAS:
			if f in bajo:
				marcar("muletilla", i, f"«{f}»")
		for f in FRASES_IA:
			if f in bajo:
				marcar("ia", i, f"«{f}» (suena a texto genérico/IA)")
		for m in RE_DECIR_EMOCION.finditer(l):
			marcar("emocion", i, f"«{m.group(0)}»: nombra la emoción; muéstrala (cuerpo, acción, diálogo)")
		for m in RE_FILTRO.finditer(l):
			marcar("filtro", i, f"«{m.group(0)}»: verbo filtro; prueba a contar directamente lo que ve/oye/siente")
		for m in RE_DEQUEISMO.finditer(l):
			marcar("dequeismo", i, f"«{m.group(0)}»: ¿dequeísmo? (normalmente sin «de»)")
		for v in VERBOS_HABLA_RAROS:
			if re.search(rf"\b{v}\b", bajo):
				marcar("habla", i, f"«{v}»: verbo de habla llamativo; «dijo» o una acción suelen funcionar mejor")
		# Frases muy largas de esta línea
		for f in re.split(r"(?<=[.!?…])\s+", s):
			n = len(RE_PALABRA.findall(f))
			if n > 45:
				marcar("larga", i, f"frase de {n} palabras: «{f[:60]}…»")

	# Repeticiones cercanas (por tronco, ignorando palabras vacías y nombres propios)
	vistos = {}
	pos = 0
	repes = set()
	for i, l in enumerate(lineas):
		if l.lstrip().startswith(("#", "<!--", ">")):
			continue
		for m in RE_PALABRA.finditer(l):
			w = m.group(0)
			pos += 1
			if len(w) < 5 or w.lower() in STOP:
				continue
			if w[0].isupper() and m.start() > 0 and not re.search(r"[.!?…—«\"]\s*$", l[: m.start()]):
				continue  # nombre propio en mitad de frase
			t = tronco(w)
			if t in vistos and pos - vistos[t][0] <= 40 and (t, vistos[t][1]) not in repes:
				repes.add((t, vistos[t][1]))
				marcar("repeticion", i, f"«{w}» repetida (antes en la línea {vistos[t][1] + 1})")
			vistos[t] = (pos, i)

	mente = RE_MENTE.findall(cuerpo)
	gerundios = RE_GERUNDIO.findall(cuerpo)
	pasivas = RE_PASIVA.findall(cuerpo)
	dijo = len(re.findall(r"\b(dijo|preguntó|respondió|contestó)\b", cuerpo, re.I))
	return {
		"nombre": nombre, "palabras": n_pal, "frases": len(fr), "silabas": n_sil,
		"media_frase": statistics.mean(largos) if largos else 0,
		"desv_frase": statistics.pstdev(largos) if len(largos) > 1 else 0,
		"pct_largas": (100 * sum(1 for x in largos if x > 30) / len(largos)) if largos else 0,
		"inflesz": inflesz(n_sil, n_pal, len(fr)),
		"mente": len(mente), "gerundios": len(gerundios), "pasivas": len(pasivas),
		"dialogos": dialogos, "lineas": len([l for l in lineas if l.strip()]), "dijo": dijo,
		"avisos": sorted(avisos, key=lambda a: a[1]),
	}


NOMBRES = {
	"repeticion": "Repeticiones cercanas", "muletilla": "Muletillas y clichés", "ia": "Giros de texto genérico/IA",
	"emocion": "Emociones dichas (no mostradas)", "filtro": "Verbos filtro", "dialogo": "Puntuación de diálogos",
	"dequeismo": "Posible dequeísmo", "habla": "Verbos de habla llamativos", "larga": "Frases muy largas (> 45 palabras)",
}
ORDEN = ["dialogo", "dequeismo", "ia", "muletilla", "emocion", "repeticion", "filtro", "larga", "habla"]


def por_mil(n, total):
	return 1000 * n / total if total else 0


def informe(resultados, maximo):
	total = {k: sum(r[k] for r in resultados) for k in ("palabras", "frases", "silabas", "mente", "gerundios", "pasivas", "dialogos", "lineas", "dijo")}
	todos = [a for r in resultados for a in r["avisos"]]
	media = statistics.mean([r["media_frase"] for r in resultados if r["frases"]] or [0])
	ifz = inflesz(total["silabas"], total["palabras"], total["frases"])
	P = total["palabras"]
	o = ["# Informe de revisión", ""]
	o.append(f"**{P:,} palabras** · {total['frases']} frases · media {media:.1f} palabras/frase · "
		f"legibilidad INFLESZ **{ifz:.0f} ({nivel_inflesz(ifz)})**".replace(",", "."))
	o.append("")
	o.append("| Indicador | Valor | Orientación |")
	o.append("|---|---|---|")
	o.append(f"| Adverbios en -mente | {por_mil(total['mente'], P):.1f} / 1.000 pal. | ≤ 6 está bien; > 10 cansa |")
	o.append(f"| Gerundios | {por_mil(total['gerundios'], P):.1f} / 1.000 | ≤ 10; vigila los «de posterioridad» |")
	o.append(f"| Pasivas «ser + participio» | {por_mil(total['pasivas'], P):.1f} / 1.000 | ≤ 3 en narrativa |")
	o.append(f"| Líneas de diálogo | {100 * total['dialogos'] / max(1, total['lineas']):.0f} % de los párrafos | depende del género (novela juvenil/comercial: 30–50 %) |")
	desv = statistics.mean([r["desv_frase"] for r in resultados if r["frases"]] or [0])
	o.append(f"| Variación de longitud de frase | ±{desv:.1f} palabras | < 6 suena monótono; 8–14 tiene ritmo |")
	o.append("")
	o.append("## Avisos por tipo")
	conteo = {}
	for t, _, _ in todos:
		conteo[t] = conteo.get(t, 0) + 1
	if not conteo:
		o.append("Sin avisos ✅")
	for t in ORDEN:
		if t in conteo:
			o.append(f"- **{NOMBRES[t]}**: {conteo[t]} ({por_mil(conteo[t], P):.1f} / 1.000 pal.)")
	if len(resultados) > 1:
		o += ["", "## Por capítulo", "", "| Capítulo | Palabras | Media frase | INFLESZ | Avisos /1.000 |", "|---|---|---|---|---|"]
		for r in resultados:
			v = r["inflesz"]
			o.append(f"| {r['nombre']} | {r['palabras']} | {r['media_frase']:.1f} | {v:.0f} |" if v is not None else f"| {r['nombre']} | {r['palabras']} | — | — |")
			o[-1] += f" {por_mil(len(r['avisos']), max(1, r['palabras'])):.1f} |"
	for r in resultados:
		if not r["avisos"]:
			continue
		o += ["", f"## Detalle: {r['nombre']}"]
		for t in ORDEN:
			lista = [a for a in r["avisos"] if a[0] == t]
			if not lista:
				continue
			o.append(f"**{NOMBRES[t]}**")
			for _, ln, det in lista[:maximo]:
				o.append(f"- l. {ln}: {det}")
			if len(lista) > maximo:
				o.append(f"- … y {len(lista) - maximo} más")
	o += ["", "_Ayuda automática: revisa cada aviso en contexto antes de cambiar nada._"]
	return "\n".join(o) + "\n"


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("ruta")
	ap.add_argument("--salida")
	ap.add_argument("--max", type=int, default=25, help="avisos máximos por tipo y capítulo")
	a = ap.parse_args()
	archivos = []
	if os.path.isdir(a.ruta):
		for raiz, _, fs in os.walk(a.ruta):
			for f in sorted(fs):
				if f.endswith((".md", ".txt")) and not f.upper().startswith(("README", "INFORME")):
					archivos.append(os.path.join(raiz, f))
		archivos.sort()
	else:
		archivos = [a.ruta]
	if not archivos:
		sys.exit("No hay archivos .md o .txt")
	resultados = [analizar(open(f, encoding="utf-8").read(), os.path.relpath(f, a.ruta) if os.path.isdir(a.ruta) else os.path.basename(f)) for f in archivos]
	resultados = [r for r in resultados if r["palabras"] > 0]
	texto = informe(resultados, a.max)
	if a.salida:
		with open(a.salida, "w", encoding="utf-8") as f:
			f.write(texto)
		print(f"Informe: {a.salida}")
		print(texto.split("## Avisos por tipo")[0].strip())
	else:
		print(texto)


if __name__ == "__main__":
	main()
