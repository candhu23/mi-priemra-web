"""Dibuja la planta de la biblioteca (vista desde arriba) a partir de tools/out/world.json.
Uso: python3 -I plan.py <world.json> <carpeta salida>  → plan_planta1.svg y plan_planta2.svg
Solo es una ayuda para revisar la distribución (no es Roblox)."""
import json
import os
import sys

data = json.load(open(sys.argv[1]))
out = sys.argv[2]
S = 8  # píxeles por stud
X0, Z0 = -36, 4

def px(x):
	return (x - X0) * S

def pz(z):
	return (Z0 - z) * S

for floor, (ylo, yhi) in ((1, (-1.5, 13)), (2, (13, 29))):
	W, H = 72 * S, 128 * S
	parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W + 260}" height="{H}" style="background:#1b1b1f;font-family:sans-serif">']
	# piezas que están en esta planta (por su centro), de abajo arriba
	pieces = [p for p in data["pieces"] if ylo <= p["y"] < yhi and p["sx"] < 100]
	pieces.sort(key=lambda p: p["y"] + p["sy"] / 2)
	for p in pieces:
		col = f'rgb({int(p["r"]*255)},{int(p["g"]*255)},{int(p["b"]*255)})'
		op = 1 - min(0.9, p["t"])
		parts.append(f'<rect x="{px(p["x"] - p["sx"]/2):.1f}" y="{pz(p["z"] + p["sz"]/2):.1f}" width="{p["sx"]*S:.1f}" height="{p["sz"]*S:.1f}" fill="{col}" fill-opacity="{op:.2f}" stroke="#000" stroke-opacity="0.25" stroke-width="0.5"/>')
	for b in data["books"]:
		if ylo <= b["y"] - 0.2 < yhi:
			parts.append(f'<circle cx="{px(b["x"]):.1f}" cy="{pz(b["z"]):.1f}" r="2.2" fill="{b["c"]}" stroke="#fff" stroke-width="0.4"/>')
	for s in data["sections"]:
		if s["floor"] == floor:
			cx, cz = (s["x0"] + s["x1"]) / 2, (s["z0"] + s["z1"]) / 2
			parts.append(f'<text x="{px(cx):.1f}" y="{pz(cz)+5:.1f}" fill="#ffe" font-size="15" font-weight="bold" text-anchor="middle">{s["code"]}</text>')
	for k, v in data["interact"].items():
		if ylo <= v["y"] < yhi + 3:
			parts.append(f'<circle cx="{px(v["x"]):.1f}" cy="{pz(v["z"]):.1f}" r="5" fill="none" stroke="#0ff" stroke-width="2"/>')
			parts.append(f'<text x="{px(v["x"])+7:.1f}" y="{pz(v["z"])-6:.1f}" fill="#0ff" font-size="11">{k}</text>')
	parts.append(f'<text x="{W+10}" y="30" fill="#fff" font-size="20">Planta {floor}</text>')
	parts.append(f'<text x="{W+10}" y="56" fill="#aaa" font-size="13">arriba = entrada (z 0)</text>')
	parts.append(f'<text x="{W+10}" y="74" fill="#aaa" font-size="13">abajo = fondo (z -120)</text>')
	parts.append("</svg>")
	open(os.path.join(out, f"plan_planta{floor}.svg"), "w").write("\n".join(parts))
print("planos escritos")
