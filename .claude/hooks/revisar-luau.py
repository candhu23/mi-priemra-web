#!/usr/bin/env python3
"""Guardián: se ejecuta DESPUÉS de cada Edit/Write de Claude (hook PostToolUse).
Si el archivo es .luau: lo compila al momento (sintaxis y límite de 200 locales) y busca trampas
conocidas del repo (CLAUDE.md §9) y de Roblox. Un error de compilación BLOQUEA (Claude tiene que
arreglarlo ya); las trampas se le avisan como contexto. Nunca rompe nada: ante cualquier fallo, sale en silencio.
"""
import json
import os
import re
import subprocess
import sys

TRAMPAS = [
	(r"(?<![\w.])wait\(", "usa task.wait() (wait() está obsoleto)"),
	(r"(?<![\w.])spawn\(", "usa task.spawn() (spawn() está obsoleto)"),
	(r"(?<![\w.])delay\(", "usa task.delay() (delay() está obsoleto)"),
	(r":IsFriendsWith\(", "usa IsFriendsWithAsync (CLAUDE.md §9)"),
	(r":IsInGroup\(", "usa IsInGroupAsync (CLAUDE.md §9)"),
	(r"Instance\.new\(\s*\"[^\"]+\"\s*,", "no pases el padre a Instance.new: pon .Parent al final (rendimiento)"),
	(r"\bloadstring\(", "loadstring no se debe usar"),
	(r"Lighting\.Technology\s*=", "Lighting.Technology no se puede cambiar por script: va en default.project.json"),
]


def avisos_texto(texto):
	salida = []
	# Solo código (sin comentarios), para no avisar por un comentario que explica la trampa
	lineas = [l.split("--", 1)[0] for l in texto.splitlines()]
	for n, codigo in enumerate(lineas, 1):
		for patron, consejo in TRAMPAS:
			if re.search(patron, codigo):
				salida.append(f"línea {n}: {consejo}")
		# GetDataStore sin pcall cerca (rompe el servidor en Studio sin publicar: fallo de AeroCarga v0.1)
		if re.search(r":GetDataStore\(|:GetOrderedDataStore\(", codigo):
			cerca = "\n".join(lineas[max(0, n - 4): n + 1])
			if "pcall" not in cerca:
				salida.append(f"línea {n}: GetDataStore sin pcall → en Studio sin publicar para el servidor")
		# UIGradient dentro de un objeto con texto (tiñe el texto: CLAUDE.md §9)
		if "UIGradient" in codigo:
			cerca = "\n".join(lineas[max(0, n - 6): n + 2])
			if re.search(r"TextLabel|TextButton|TextBox", cerca):
				salida.append(f"línea {n}: ¿UIGradient en un TextLabel/TextButton? Tiñe también el texto: ponlo en un Frame de fondo")
	return salida[:12]


def main():
	try:
		datos = json.load(sys.stdin)
	except Exception:
		return
	entrada = datos.get("tool_input") or {}
	ruta = entrada.get("file_path") or ""
	if not ruta.endswith(".luau") or not os.path.isfile(ruta):
		return
	# Buscar el luau-compile del juego al que pertenece el archivo (o de cualquiera)
	raiz = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
	compilador = None
	d = os.path.dirname(os.path.abspath(ruta))
	while d and d != os.path.dirname(d):
		c = os.path.join(d, "tools", "bin", "luau-compile")
		if os.path.isfile(c):
			compilador = c
			break
		d = os.path.dirname(d)
	if not compilador:
		for juego in sorted(os.listdir(raiz)):
			c = os.path.join(raiz, juego, "tools", "bin", "luau-compile")
			if os.path.isfile(c):
				compilador = c
				break
	errores = ""
	if compilador:
		try:
			r = subprocess.run([compilador, "--null", ruta], capture_output=True, text=True, timeout=20)
			if r.returncode != 0:
				errores = (r.stderr or r.stdout).strip()[:1500]
		except Exception:
			pass
	try:
		avisos = avisos_texto(open(ruta, encoding="utf-8").read())
	except Exception:
		avisos = []
	nombre = os.path.relpath(ruta, raiz)
	if errores:
		print(json.dumps({
			"decision": "block",
			"reason": f"🛡️ Guardián: {nombre} NO compila. Arréglalo antes de seguir:\n{errores}",
		}, ensure_ascii=False))
		return
	if avisos:
		print(json.dumps({
			"hookSpecificOutput": {
				"hookEventName": "PostToolUse",
				"additionalContext": f"🛡️ Guardián ({nombre}) compila, pero revisa:\n- " + "\n- ".join(avisos),
			}
		}, ensure_ascii=False))


if __name__ == "__main__":
	try:
		main()
	except Exception:
		pass
