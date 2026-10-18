"""Comprueba que todas las claves de Lang.luau existen en español e inglés, y que las claves que
usa el código (T("..."), notify(..., "...") y returns de acciones) existen.
Uso: python3 -I check_lang.py <carpeta src>"""
import os
import re
import sys

SRC = sys.argv[1]
texto = open(os.path.join(SRC, "ReplicatedStorage", "Lang.luau"), encoding="utf-8").read()


def claves(idioma):
	m = re.search(r"Lang\." + idioma + r"\s*=\s*\{(.*?)\n\}", texto, re.S)
	if not m:
		sys.exit(f"No encuentro Lang.{idioma}")
	return set(re.findall(r"^\s*(\w+)\s*=", m.group(1), re.M))


es, en = claves("es"), claves("en")
fallos = [f"falta en inglés: {k}" for k in sorted(es - en)] + [f"falta en español: {k}" for k in sorted(en - es)]
usadas = set()
for raiz, _, archivos in os.walk(SRC):
	for a in archivos:
		if a.endswith(".luau") and a != "Lang.luau":
			codigo = open(os.path.join(raiz, a), encoding="utf-8").read()
			usadas |= set(re.findall(r'\bT\("(\w+)"\s*[,)]', codigo))
			usadas |= set(re.findall(r'notify\([^,]+,\s*"\w+",\s*"(\w+)"', codigo))
			usadas |= set(re.findall(r'return (?:true|false), "(\w+)"', codigo))
fallos += [f"el código usa una clave que no existe: {k}" for k in sorted(usadas - es)]
for f in fallos:
	print("  ✗", f)
print(f"Textos: {len(es)} claves en español, {len(en)} en inglés" + (" ✅" if not fallos else " ❌"))
sys.exit(1 if fallos else 0)
