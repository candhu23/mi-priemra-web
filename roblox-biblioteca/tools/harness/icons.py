"""Genera las imágenes de las 12 insignias (512×512) y el icono del juego con Chromium.
Dibujos propios: círculo con degradado, un símbolo y el nombre. Uso: python3 -I icons.py <carpeta salida>
(Las imágenes se suben a mano en el Creator Hub al crear cada insignia.)"""
import os
import subprocess
import sys

OUT = sys.argv[1]
# id, símbolo, nombre ES, colores
BADGES = [
	("first_row", "📚", "Primera fila", "#f0c35a", "#8a5a1c"),
	("rows_50", "50", "Cincuenta filas", "#e6a94a", "#7a4012"),
	("rows_200", "200", "Doscientas filas", "#d98c3c", "#6a2a10"),
	("rows_400", "🟦", "Todo en azul", "#6aa8ff", "#1d3a7a"),
	("first_spell", "✦", "Primer hechizo", "#b99cff", "#3a2378"),
	("all_spells", "✶", "Las cinco magias", "#9f7bff", "#2a1560"),
	("chests", "🗝️", "Cazallaves", "#ffd36e", "#6b4a10"),
	("spells_max", "📖", "Manual completo", "#8ad0ff", "#123a5a"),
	("ultimate", "⚡", "Sin horas extra", "#7f6bff", "#1c1450"),
	("fired", "📝", "¡Despedido!", "#ff8a7a", "#6a1410"),
	("pizza", "🍕", "La pizza sigue caliente", "#ffb35a", "#7a3010"),
	("nomagic", "🧹", "A la antigua", "#9fd38a", "#204a18"),
]
HEAD = """<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@700&family=Noto+Color+Emoji&family=Montserrat:wght@900&display=block" rel="stylesheet">
<style>html,body{margin:0;width:512px;height:512px;background:transparent}
.c{position:absolute;inset:8px;border-radius:50%;display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:inset 0 0 0 14px rgba(255,240,200,.85),inset 0 0 0 22px rgba(0,0,0,.25)}
.s{font:900 190px Montserrat,'Noto Color Emoji';color:#fff8e6;text-shadow:0 6px 0 rgba(0,0,0,.25);line-height:1}
.n{margin-top:18px;max-width:330px;text-align:center;font:700 44px 'EB Garamond';color:#fff8e6;line-height:1.05;text-shadow:0 3px 0 rgba(0,0,0,.35)}
</style></head><body>"""
files = []
for bid, sym, name, a, b in BADGES:
	html = HEAD + f'<div class="c" style="background:radial-gradient(circle at 35% 30%,{a},{b})"><div class="s">{sym}</div><div class="n">{name}</div></div></body></html>'
	path = os.path.abspath(os.path.join(OUT, f"insignia_{bid}.html"))
	open(path, "w").write(html)
	files.append(path)
# Icono del juego: pila de libros con el título
icon = HEAD.replace("border-radius:50%", "border-radius:64px") + """<div class="c" style="background:radial-gradient(circle at 40% 30%,#6b4a30,#1e140c);inset:0">
<div style="display:flex;gap:8px;align-items:flex-end;height:220px">
<div style="width:46px;height:200px;background:#2b1f4f;border-radius:6px;box-shadow:inset 0 30px 0 #ffd36e"></div>
<div style="width:52px;height:220px;background:#6b4423;border-radius:6px;box-shadow:inset 0 -40px 0 #fff"></div>
<div style="width:44px;height:180px;background:#a32121;border-radius:6px;box-shadow:inset 0 24px 0 #cfd8dc"></div>
<div style="width:50px;height:210px;background:#1f6b5c;border-radius:6px;box-shadow:inset 0 -30px 0 #f2c14e"></div>
<div style="width:46px;height:190px;background:#5b2a86;border-radius:6px;box-shadow:inset 0 36px 0 #7fe0ff;transform:rotate(8deg);transform-origin:bottom left"></div>
</div>
<div class="n" style="font-size:58px;max-width:440px;margin-top:26px;color:#f0c35a">Estanterías Hechizadas</div></div></body></html>"""
path = os.path.abspath(os.path.join(OUT, "icono_juego.html"))
open(path, "w").write(icon)
files.append(path)
js = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_shot.js")
subprocess.run(["node", js, "512", "512", "1"] + files, check=True,
	env={**os.environ, "NODE_PATH": subprocess.check_output(["npm", "root", "-g"], text=True).strip()}, stdout=subprocess.DEVNULL)
for f in files:
	os.remove(f)
print(f"{len(files)} imágenes en {OUT}")
