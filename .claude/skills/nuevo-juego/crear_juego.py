#!/usr/bin/env python3
"""Crea un juego de Roblox nuevo en el repo a partir de plantilla/ y lo registra.

Uso: python3 -I .claude/skills/nuevo-juego/crear_juego.py <carpeta> "<Nombre ES>" "<Nombre EN>" [--prefijo P] [--rama R] [--raiz DIR]
  carpeta: p. ej. roblox-pizzeria (minúsculas y guiones)
  prefijo: nombre técnico sin espacios (DataStore, remotes, .rbxl). Por defecto, el nombre EN sin espacios.
Hace: copia la plantilla, rellena {{NOMBRE}} {{NOMBRE_EN}} {{PREFIJO}} {{CARPETA}} {{RBXL}} {{RAMA}},
la añade a .claude/skills/roblox-nube/juegos.json (sin IDs hasta la primera publicación).
Después: <carpeta>/tools/check.sh
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
PLANTILLA = os.path.join(AQUI, "plantilla")


def main():
	p = argparse.ArgumentParser()
	p.add_argument("carpeta")
	p.add_argument("nombre")
	p.add_argument("nombre_en")
	p.add_argument("--prefijo")
	p.add_argument("--rama")
	p.add_argument("--raiz", default=os.path.abspath(os.path.join(AQUI, "..", "..", "..")))
	a = p.parse_args()
	if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", a.carpeta):
		sys.exit("La carpeta debe ir en minúsculas, números y guiones (p. ej. roblox-pizzeria)")
	prefijo = a.prefijo or re.sub(r"[^A-Za-z0-9]", "", a.nombre_en.title())
	if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]{2,30}", prefijo):
		sys.exit(f"Prefijo no válido: «{prefijo}» (letras y números, empieza por letra)")
	destino = os.path.join(a.raiz, a.carpeta)
	if os.path.exists(destino):
		sys.exit(f"Ya existe {destino}")
	rama = a.rama
	if not rama:
		try:
			rama = subprocess.check_output(["git", "-C", a.raiz, "branch", "--show-current"], text=True).strip()
		except Exception:
			rama = "main"
	valores = {
		"{{NOMBRE}}": a.nombre, "{{NOMBRE_EN}}": a.nombre_en, "{{PREFIJO}}": prefijo,
		"{{CARPETA}}": a.carpeta, "{{RBXL}}": prefijo + ".rbxl", "{{RAMA}}": rama,
	}
	shutil.copytree(PLANTILLA, destino)
	for raiz, _, archivos in os.walk(destino):
		for nombre in archivos:
			ruta = os.path.join(raiz, nombre)
			try:
				texto = open(ruta, encoding="utf-8").read()
			except UnicodeDecodeError:
				continue
			for k, v in valores.items():
				texto = texto.replace(k, v)
			with open(ruta, "w", encoding="utf-8") as f:
				f.write(texto)
			if nombre.endswith(".sh"):
				os.chmod(ruta, 0o755)
	restos = subprocess.run(["grep", "-rl", "{{", destino], capture_output=True, text=True).stdout.strip()
	if restos:
		print("⚠️  Quedan marcadores sin rellenar en:\n" + restos)
	# Registrar en juegos.json (si este repo tiene la skill roblox-nube)
	registro = os.path.join(a.raiz, ".claude", "skills", "roblox-nube", "juegos.json")
	if os.path.isfile(registro):
		juegos = json.load(open(registro, encoding="utf-8"))
		clave = a.carpeta.removeprefix("roblox-").replace("-", "")
		juegos[clave] = {
			"nombre": f"{a.nombre} ({a.nombre_en})", "carpeta": a.carpeta, "rbxl": prefijo + ".rbxl",
			"config": "src/ReplicatedStorage/Config.luau", "rama": rama, "universeId": None, "placeId": None,
		}
		with open(registro, "w", encoding="utf-8") as f:
			json.dump(juegos, f, ensure_ascii=False, indent=2)
			f.write("\n")
		print(f"Registrado en juegos.json como «{clave}»")
	# Reutilizar las herramientas ya descargadas de otro juego (ahorra la descarga)
	for otro in ("roblox-imperio-web", "roblox-carga-aerea"):
		binarios = os.path.join(a.raiz, otro, "tools", "bin")
		if os.path.isdir(binarios):
			shutil.copytree(binarios, os.path.join(destino, "tools", "bin"))
			break
	print(f"✅ Juego creado en {destino} (prefijo {prefijo}). Siguiente: {a.carpeta}/tools/check.sh")


if __name__ == "__main__":
	main()
