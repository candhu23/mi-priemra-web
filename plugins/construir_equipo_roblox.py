"""Construye el plugin «equipo-roblox» a partir de .claude/ de este repo (la única fuente de verdad).

Uso (desde la raíz del repo): python3 -I plugins/construir_equipo_roblox.py
Genera plugins/equipo-roblox/ (el plugin) y plugins/equipo-roblox.zip (para subirlo en claude.ai).
Vuelve a ejecutarlo cada vez que cambies un agente o una skill del equipo.
"""
import json, os, re, shutil, zipfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "plugins", "equipo-roblox")
ZIP = os.path.join(RAIZ, "plugins", "equipo-roblox.zip")
VERSION = "1.0.0"

AGENTES = ["jefe-equipo", "disenador-juego", "programador-luau", "interfaz-probador", "crecimiento-lanzamiento", "revisor-juego"]
SKILLS = ["equipo", "disenar-juego", "disenar-interfaz", "arte-roblox", "nuevo-juego"]
IGNORAR = shutil.ignore_patterns("__pycache__", "*.pyc", "bin", "out", "node_modules")


def main():
	if os.path.exists(DESTINO):
		shutil.rmtree(DESTINO)
	os.makedirs(os.path.join(DESTINO, ".claude-plugin"))
	os.makedirs(os.path.join(DESTINO, "agents"))
	for a in AGENTES:
		shutil.copy(os.path.join(RAIZ, ".claude", "agents", a + ".md"), os.path.join(DESTINO, "agents"))
	for s in SKILLS:
		origen = os.path.join(RAIZ, ".claude", "skills", s)
		destino = os.path.join(DESTINO, "skills", s)
		shutil.copytree(origen, destino, ignore=IGNORAR)
		# En el plugin, las rutas a los archivos de la propia skill pasan a ${CLAUDE_SKILL_DIR}
		p = os.path.join(destino, "SKILL.md")
		t = open(p, encoding="utf-8").read()
		t = t.replace(f".claude/skills/{s}/", "${CLAUDE_SKILL_DIR}/")
		open(p, "w", encoding="utf-8").write(t)
	manifiesto = {
		"name": "equipo-roblox",
		"version": VERSION,
		"description": "Equipo de 5 agentes para crear, diseñar, programar, probar y lanzar juegos de Roblox (Luau + Rojo) en español: "
			"Álex (jefe), Nico (diseño), Leo (programación), Vega (interfaz y pruebas), Iris (jugadores y lanzamiento), "
			"más el revisor, la skill /equipo y las herramientas para crear juegos nuevos, ver la interfaz y hacer iconos.",
		"author": {"name": "Candu231"},
		"keywords": ["roblox", "luau", "rojo", "game-design", "agents", "espanol"],
	}
	with open(os.path.join(DESTINO, ".claude-plugin", "plugin.json"), "w", encoding="utf-8") as f:
		json.dump(manifiesto, f, ensure_ascii=False, indent=2)
		f.write("\n")
	shutil.copy(os.path.join(RAIZ, "plugins", "LEEME-equipo-roblox.md"), os.path.join(DESTINO, "README.md"))
	shutil.copy(os.path.join(RAIZ, "plugins", "arte", "icono-equipo-roblox.png"), os.path.join(DESTINO, ".claude-plugin", "icon.png"))
	# Zip con el plugin en la raíz del archivo
	if os.path.exists(ZIP):
		os.remove(ZIP)
	with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
		for base, _, archivos in os.walk(DESTINO):
			for a in sorted(archivos):
				ruta = os.path.join(base, a)
				z.write(ruta, os.path.relpath(ruta, DESTINO))
	n = sum(len(a) for _, _, a in os.walk(DESTINO))
	print(f"Plugin: {os.path.relpath(DESTINO, RAIZ)} ({n} archivos) · zip: {os.path.relpath(ZIP, RAIZ)} ({os.path.getsize(ZIP) // 1024} KB)")


main()
