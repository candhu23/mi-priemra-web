#!/usr/bin/env python3
"""Mapa rápido de un juego del repo: qué tablas de configuración tiene, qué acciones acepta el servidor,
cuáles NO prueba ningún harness, textos ES/EN, tienda y tamaño del código.
Sirve para entender un juego en un minuto antes de diseñar o añadir algo.

Uso: python3 -I .claude/skills/disenar-juego/mapa_juego.py <carpeta del juego>
"""
import os
import re
import sys

CARPETA = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
SRC = os.path.join(CARPETA, "src")
HARNESS = os.path.join(CARPETA, "tools", "harness")
if not os.path.isdir(SRC):
	sys.exit(f"No hay src/ en {CARPETA}")


def luau(raiz):
	for r, _, fs in os.walk(raiz):
		for f in fs:
			if f.endswith(".luau"):
				yield os.path.join(r, f)


archivos = {p: open(p, encoding="utf-8").read() for p in luau(SRC)}
print(f"# Mapa de {os.path.basename(CARPETA)}\n")

print("## Código")
total = 0
for p, t in sorted(archivos.items(), key=lambda x: -len(x[1].splitlines())):
	n = len(t.splitlines())
	total += n
	print(f"- `{os.path.relpath(p, SRC)}`: {n} líneas")
print(f"- **Total: {total} líneas**\n")

version = None
for t in archivos.values():
	m = re.search(r'Config\.VERSION\s*=\s*"([^"]+)"', t)
	if m:
		version = m.group(1)
print(f"Versión: **{version or '?'}**\n")

print("## Configuración (tablas `Config.X = …`)")
for p, t in archivos.items():
	nombres = re.findall(r"^Config\.([A-Za-z_]\w*)\s*=", t, re.M)
	if nombres:
		print(f"- `{os.path.relpath(p, SRC)}`: " + ", ".join(dict.fromkeys(nombres)))
print()

acciones = {}
for p, t in archivos.items():
	for a in re.findall(r"function\s+Actions\.(\w+)", t) + re.findall(r"^\s*Actions\.(\w+)\s*=", t, re.M):
		acciones.setdefault(a, os.path.relpath(p, SRC))
textos_harness = ""
if os.path.isdir(HARNESS):
	for p in luau(HARNESS):
		textos_harness += open(p, encoding="utf-8").read()
# Los clientes pulsan botones que envían acciones: cuentan como probadas si el harness pulsa todos los botones
pulsa_todo = "Activated" in textos_harness
envia_cliente = set()
for p, t in archivos.items():
	if ".client." in p or "StarterPlayerScripts" in p:
		envia_cliente |= set(re.findall(r'(?:send|sendAction|InvokeServer)\(\s*"(\w+)"', t))
print(f"## Acciones del servidor ({len(acciones)})")
sin_probar = []
for a, donde in sorted(acciones.items()):
	directa = f'"{a}"' in textos_harness
	por_boton = pulsa_todo and a in envia_cliente
	marca = "✅" if directa else ("🟡 por botón" if por_boton else "❌ sin probar")
	if not directa and not por_boton:
		sin_probar.append(a)
	print(f"- `{a}` ({donde}) {marca}")
if sin_probar:
	print(f"\n**Acciones que ninguna prueba ejecuta:** {', '.join(sin_probar)} → añádelas al harness.")
print()

lang = next((t for p, t in archivos.items() if p.endswith("Lang.luau")), None)
if lang:
	def claves(idioma):
		m = re.search(r"Lang\." + idioma + r"\s*=\s*\{(.*?)\n\}", lang, re.S)
		return set(re.findall(r"^\s*(\w+)\s*=", m.group(1), re.M)) if m else set()
	es, en = claves("es"), claves("en")
	print(f"## Textos: {len(es)} ES · {len(en)} EN" + ("" if es == en else f" · ⚠️ distintos: {sorted(es ^ en)[:10]}"))
else:
	print("## Textos: ⚠️ sin Lang.luau (todo en un idioma, escrito en el código)")
print()

print("## Tienda")
for p, t in archivos.items():
	for seccion in ("GamePasses", "Products"):
		m = re.search(seccion + r"\s*=\s*\{", t)
		if not m:
			continue
		nivel, i = 0, m.end() - 1
		while i < len(t):
			nivel += {"{": 1, "}": -1}.get(t[i], 0)
			if nivel == 0:
				break
			i += 1
		trozo = t[m.end() - 1: i + 1]
		items = re.findall(r'\{\s*key\s*=\s*"(\w+)"\s*,\s*id\s*=\s*(\d+)[^}\n]*?(?:price\s*=\s*(\d+))?', trozo)
		if items:
			print(f"- {seccion}: " + ", ".join(f"{k}={'✅' if i != '0' else '⚪ sin crear'}" + (f" ({pr} R$)" if pr else "") for k, i, pr in items))
