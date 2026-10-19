#!/usr/bin/env python3
"""Continuidad de nombres: compara los nombres propios de los capítulos con la BIBLIA.

Uso: python3 -I .claude/skills/libro-biblia/comprobar_continuidad.py libros/<libro>
Avisa de:
  - nombres que salen ≥ 2 veces en los capítulos y NO están en BIBLIA.md (hay que documentarlos)
  - nombres casi iguales (Marcos/Marco, Aitana/Aytana): posible errata o cambio sin querer
  - personajes de la BIBLIA que no aparecen en ningún capítulo (¿olvidados?)
Detecta «nombre propio» como palabra en mayúscula que no va al principio de frase. Es aproximado.
"""
import difflib
import os
import re
import sys

LETRAS = "A-Za-zÁÉÍÓÚÜÑáéíóúüñÆæØøÅåÄäÖöÐðÞþ"


def sin_tilde(c):
	return {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U"}.get(c, c)
NO_NOMBRES = set("""Dios Señor Señora Don Doña Usted Ustedes Navidad Lunes Martes Miércoles Jueves Viernes Sábado
Domingo Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre""".split())

libro = sys.argv[1] if len(sys.argv) > 1 else "."
biblia_ruta = os.path.join(libro, "BIBLIA.md")
cap_dir = os.path.join(libro, "capitulos")
if not os.path.isfile(biblia_ruta) or not os.path.isdir(cap_dir):
	sys.exit(f"No encuentro BIBLIA.md y capitulos/ en {libro}")
biblia = open(biblia_ruta, encoding="utf-8").read()
en_biblia = set(re.findall(rf"\b[A-ZÁÉÍÓÚÑÆØÅÄÖÐÞ][{LETRAS}]+", biblia))

todas = set()  # cualquier palabra en mayúscula (también a principio de frase)
usos = {}    # nombre -> capítulos donde sale
veces = {}   # nombre -> número de apariciones
for f in sorted(os.listdir(cap_dir)):
	if not f.endswith(".md"):
		continue
	for linea in open(os.path.join(cap_dir, f), encoding="utf-8"):
		if linea.lstrip().startswith("#"):
			continue
		for m in re.finditer(rf"\b[A-ZÁÉÍÓÚÑÆØÅÄÖÐÞ][{LETRAS}]+", linea):
			todas.add(m.group(0))
			antes = linea[: m.start()].rstrip()
			if not antes or antes[-1] in ".!?…—«\"(:¿¡":
				continue  # principio de frase o de diálogo: no se sabe si es nombre
			w = m.group(0)
			if w in NO_NOMBRES:
				continue
			usos.setdefault(w, set()).add(f)
			veces[w] = veces.get(w, 0) + 1

print(f"# Continuidad de nombres ({len(usos)} nombres propios en los capítulos)\n")
print("## Salen 2 o más veces y NO están en BIBLIA.md (documéntalos)")
falta = sorted(w for w in usos if w not in en_biblia and veces[w] >= 2)
print("\n".join(f"- {w} ×{veces[w]} (en {', '.join(sorted(usos[w]))})" for w in falta) or "Ninguno ✅")

print("\n## Nombres casi iguales (¿errata o cambio sin querer?)")
todos = sorted({w for w in usos if len(w) > 3} | {w for w in en_biblia if len(w) > 3})
pares = []
for i, a in enumerate(todos):
	for b in todos[i + 1:]:
		parecido = difflib.SequenceMatcher(None, a.lower(), b.lower()).ratio()
		if sin_tilde(a[0]) == sin_tilde(b[0]) and parecido >= 0.8 and (a in usos or b in usos):
			pares.append((a, b))
print("\n".join(f"- {a} / {b}" for a, b in pares) or "Ninguno ✅")

m = re.search(r"## 3\. Personajes(.*?)\n## ", biblia, re.S)
if m:
	personajes = []
	for fila in re.findall(r"^\|([^|\n]+)\|", m.group(1), re.M):
		nombre = fila.strip()
		if nombre and nombre != "Nombre" and not set(nombre) <= set("-: "):
			personajes.append(nombre)
	print("\n## Personajes de la BIBLIA que aún no salen en ningún capítulo")
	# Sale si aparece cualquiera de las palabras de su nombre (Abuela Rosa → «Rosa» o «Abuela»)
	olvidados = [p for p in personajes if not any(w in todas for w in re.findall(rf"[A-ZÁÉÍÓÚÑÆØÅÄÖÐÞ][{LETRAS}]+", p))]
	print("\n".join(f"- {p}" for p in olvidados) or "Ninguno")
