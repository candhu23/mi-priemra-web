#!/usr/bin/env python3
"""Crea la carpeta de un libro nuevo con sus documentos de trabajo.

Uso: python3 -I .claude/skills/libro-biblia/crear_libro.py "<Título>" [--raiz libros]
Crea libros/<titulo-en-minusculas>/ con:
  BIBLIA.md   memoria del libro (idea, voz, personajes, mundo, línea temporal, registro de continuidad)
  PLAN.md     estructura y escaleta capítulo a capítulo (la rellena la skill libro-plan)
  ESTADO.md   en qué punto está cada capítulo
  capitulos/  un .md por capítulo (01-titulo.md, 02-…)
  revision/   informes del analizador y del lector beta
"""
import argparse
import datetime
import os
import re
import sys
import unicodedata

AQUI = os.path.dirname(os.path.abspath(__file__))


def slug(texto):
	t = unicodedata.normalize("NFD", texto.lower())
	t = "".join(c for c in t if unicodedata.category(c) != "Mn")
	return re.sub(r"[^a-z0-9]+", "-", t).strip("-")[:60] or "libro"


def main():
	p = argparse.ArgumentParser()
	p.add_argument("titulo")
	p.add_argument("--raiz", default=os.path.abspath(os.path.join(AQUI, "..", "..", "..", "libros")))
	a = p.parse_args()
	destino = os.path.join(a.raiz, slug(a.titulo))
	if os.path.exists(destino):
		sys.exit(f"Ya existe {destino}")
	os.makedirs(os.path.join(destino, "capitulos"))
	os.makedirs(os.path.join(destino, "revision"))
	hoy = datetime.date.today().isoformat()
	for nombre in ("BIBLIA.md", "PLAN.md", "ESTADO.md"):
		texto = open(os.path.join(AQUI, "plantillas", nombre), encoding="utf-8").read()
		texto = texto.replace("{{TITULO}}", a.titulo).replace("{{FECHA}}", hoy)
		with open(os.path.join(destino, nombre), "w", encoding="utf-8") as f:
			f.write(texto)
	print(f"✅ Libro creado en {destino}")


if __name__ == "__main__":
	main()
