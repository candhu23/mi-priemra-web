#!/usr/bin/env python3
"""Vista previa APROXIMADA + auditoría de diseño de una interfaz de Roblox.

Convierte los volcados JSON (volcado.luau) en HTML, los fotografía con Chromium y revisa
automáticamente cada pantalla: texto pequeño, texto cortado, contraste bajo, botones pequeños
para el dedo, elementos fuera de pantalla y textos que se pisan.

No es Roblox: fuentes parecidas (Gotham → Montserrat, Builder Sans → Nunito Sans, Fredoka One real),
AutomaticSize/TextScaled aproximados. Sirve para ver colores, distribución y solapes, no para medir
píxeles exactos. Ver SKILL.md.

Uso: python3 -I ver_interfaz.py <carpeta con .json> [--ancho 1280 --alto 720] [--movil]
                                [--escala 1] [--barra 58] [--estricto]
  --movil   = 844×390 (móvil horizontal típico) con umbrales táctiles
Salida en la misma carpeta: <pantalla>.png, <pantalla>_problemas.png (si hay) e informe_diseno.md
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))

FUENTES = [  # (trozo del nombre de familia de Roblox, familia CSS de Google Fonts)
	("Fredoka", "Fredoka One"), ("Gotham", "Montserrat"), ("Montserrat", "Montserrat"),
	("Builder", "Nunito Sans"), ("Nunito", "Nunito"), ("Oswald", "Oswald"), ("SourceSans", "Source Sans 3"),
	("Roboto", "Roboto"), ("Luckiest", "Luckiest Guy"), ("Bangers", "Bangers"), ("PermanentMarker", "Permanent Marker"),
	("Ubuntu", "Ubuntu"), ("Michroma", "Michroma"), ("PressStart", "Press Start 2P"), ("Arcade", "Press Start 2P"),
	("Merriweather", "Merriweather"), ("Kalam", "Kalam"), ("Creepster", "Creepster"), ("Arial", "Arial"),
]
GOOGLE = ("https://fonts.googleapis.com/css2?family=Fredoka+One&family=Montserrat:wght@400;500;600;700;800"
	"&family=Nunito+Sans:wght@400;600;700;800&family=Nunito:wght@400;700;800&family=Oswald:wght@400;700"
	"&family=Source+Sans+3:wght@400;600;700&family=Roboto:wght@400;700&family=Luckiest+Guy&family=Bangers"
	"&family=Noto+Color+Emoji&display=block")
PESOS = {"Thin": 100, "ExtraLight": 200, "Light": 300, "Regular": 400, "Medium": 500, "SemiBold": 600,
	"Bold": 700, "ExtraBold": 800, "Heavy": 900}
GUI = {"Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ScrollingFrame", "CanvasGroup", "ViewportFrame"}


def rgba(c, t=0):
	return f"rgba({c[0]},{c[1]},{c[2]},{1 - (t or 0):.3f})"


def udim(u):
	s, o = u
	if s == 0:
		return f"{o}px"
	return f"calc({s * 100:.4f}% + {o}px)"


def mod(node, cls):
	for c in node["children"]:
		if c["class"] == cls:
			return c
	return None


def familia(font):
	fam = (font or ["", "Regular"])[0] or ""
	for trozo, css in FUENTES:
		if trozo.lower() in fam.lower():
			return css
	return "Nunito Sans"


def render(node, ruta, parent_layout=None):
	cls = node["class"]
	if cls not in GUI or node.get("Visible") is False:
		return ""
	ruta = f"{ruta}/{node.get('name', cls)}"
	style, attrs = [], [f'data-ruta="{html.escape(ruta)}"']
	size = node.get("Size", [0, 0, 0, 0])
	auto = node.get("AutomaticSize", "None")
	w, h = udim(size[:2]), udim(size[2:])
	if parent_layout == "grid":
		style.append("width:100%;height:100%")
	else:
		style.append(f"min-width:{w};width:max-content" if auto in ("X", "XY") else f"width:{w}")
		style.append(f"min-height:{h};height:auto" if auto in ("Y", "XY") else f"height:{h}")
	ap = node.get("AnchorPoint", [0, 0])
	transform = []
	if parent_layout is None:
		pos = node.get("Position", [0, 0, 0, 0])
		style.append(f"position:absolute;left:{udim(pos[:2])};top:{udim(pos[2:])}")
		if ap != [0, 0]:
			transform.append(f"translate({-ap[0] * 100}%,{-ap[1] * 100}%)")
	else:
		style.append(f"position:relative;flex:none;order:{node.get('LayoutOrder', 0)}")
	if node.get("Rotation"):
		transform.append(f"rotate({node['Rotation']}deg)")
	esc = mod(node, "UIScale")
	if esc and esc.get("Scale", 1) not in (1, None):
		transform.append(f"scale({esc['Scale']})")
		style.append(f"transform-origin:{ap[0] * 100}% {ap[1] * 100}%")
	if transform:
		style.append("transform:" + " ".join(transform))
	style.append(f"z-index:{node.get('ZIndex', 1)}")
	bt = node.get("BackgroundTransparency", 0)
	grad = mod(node, "UIGradient")
	if grad and isinstance(grad.get("Color"), list) and grad["Color"] and len(grad["Color"][0]) == 3:
		# Algunos volcados (AeroCarga) traen [[r,g,b],…] sin tiempo: se reparten de 0 a 1
		n = len(grad["Color"])
		grad = {**grad, "Color": [[i / max(n - 1, 1)] + list(k) for i, k in enumerate(grad["Color"])]}
	es_texto = cls in ("TextLabel", "TextButton", "TextBox")
	if bt < 1 and grad and isinstance(grad.get("Color"), list) and len(grad["Color"]) >= 2:
		# Roblox MULTIPLICA el degradado por BackgroundColor3 (y también por el color del texto)
		base = node.get("BackgroundColor3") or [255, 255, 255]
		con_color = any(max(k[1:4]) - min(k[1:4]) > 30 for k in grad["Color"])
		grad = {**grad, "Color": [[k[0]] + [round(k[i + 1] * base[i] / 255) for i in range(3)] for k in grad["Color"]]}
		stops = ",".join(f"{rgba(k[1:4], bt)} {k[0] * 100:.1f}%" for k in grad["Color"])
		style.append(f"background:linear-gradient({grad.get('Rotation', 0) + 90}deg,{stops})")
		medio = grad["Color"][len(grad["Color"]) // 2]
		if bt < 0.15:
			attrs.append(f'data-bg="{medio[1]},{medio[2]},{medio[3]}"')
		# Solo es problema si el degradado tiene COLOR (uno gris/blanco, como shade() de Imperio, no tiñe)
		if es_texto and con_color:
			attrs.append('data-gradiente-texto="1"')
	elif bt < 1 and node.get("BackgroundColor3"):
		style.append("background:" + rgba(node["BackgroundColor3"], bt))
		if bt < 0.15:
			c = node["BackgroundColor3"]
			attrs.append(f'data-bg="{c[0]},{c[1]},{c[2]}"')
	sc = mod(node, "UISizeConstraint")
	if sc and sc.get("MaxSize") and sc["MaxSize"][0] < 1e8:
		style.append(f"max-width:{sc['MaxSize'][0]}px;max-height:{sc['MaxSize'][1]}px")
	c = mod(node, "UICorner")
	if c:
		r = c["CornerRadius"]
		if r[0] == 0:
			style.append(f"border-radius:{r[1]}px")
		else:
			attrs.append(f'data-radius="{r[0]}"')
	st = mod(node, "UIStroke")
	trazo_texto = False
	if st and st.get("Thickness", 0) > 0 and st.get("Transparency", 0) < 1:
		if es_texto and st.get("ApplyStrokeMode", "Contextual") == "Contextual":
			trazo_texto = (st["Color"], st["Thickness"], st.get("Transparency", 0))
		else:
			style.append(f"box-shadow:0 0 0 {st['Thickness']}px {rgba(st['Color'], st.get('Transparency', 0))}")
	if node.get("ClipsDescendants") or cls in ("ScrollingFrame", "CanvasGroup"):
		style.append("overflow:hidden")
		attrs.append('data-recorta="1"')
	ar = mod(node, "UIAspectRatioConstraint")
	if ar:
		attrs.append(f'data-aspect="{ar["AspectRatio"]}"')
	img = node.get("Image")
	if cls in ("ImageLabel", "ImageButton") and img:
		if os.path.isfile(img):
			rect = node.get("ImageRectSize", [0, 0])
			col = node.get("ImageColor3", [255, 255, 255])
			off = node.get("ImageRectOffset", [0, 0])
			attrs.append(f'data-img="file://{html.escape(img)}" data-rect="{off[0]},{off[1]},{rect[0]},{rect[1]}"')
			attrs.append(f'data-tint="{rgba(col, node.get("ImageTransparency", 0))}" data-fit="{node.get("ScaleType", "Stretch")}"')
		else:  # rbxassetid:// no se puede ver aquí
			style.append("outline:1px dashed rgba(255,255,255,.35);outline-offset:-1px")
	pad = mod(node, "UIPadding")
	inset = [0, 0, 0, 0]
	if pad:
		inset = [pad.get("PaddingTop", [0, 0])[1], pad.get("PaddingRight", [0, 0])[1], pad.get("PaddingBottom", [0, 0])[1], pad.get("PaddingLeft", [0, 0])[1]]
	inner_style = [f"position:absolute;top:{inset[0]}px;right:{inset[1]}px;bottom:{inset[2]}px;left:{inset[3]}px"]
	if auto != "None":
		inner_style = [f"position:relative;padding:{inset[0]}px {inset[1]}px {inset[2]}px {inset[3]}px"]
	layout, grid = mod(node, "UIListLayout"), mod(node, "UIGridLayout")
	kids_layout = None
	if layout:
		horiz = layout.get("FillDirection") == "Horizontal"
		jus = {"Left": "flex-start", "Center": "center", "Right": "flex-end", "Top": "flex-start", "Bottom": "flex-end"}
		main = jus[layout.get("HorizontalAlignment", "Left") if horiz else layout.get("VerticalAlignment", "Top")]
		cross = jus[layout.get("VerticalAlignment", "Top") if horiz else layout.get("HorizontalAlignment", "Left")]
		inner_style.append(f"display:flex;flex-direction:{'row' if horiz else 'column'};gap:{layout.get('Padding', [0, 0])[1]}px;justify-content:{main};align-items:{cross}")
		kids_layout = "list"
	elif grid:
		cs, cp = grid["CellSize"], grid["CellPadding"]
		inner_style.append(f"display:grid;grid-template-columns:repeat(auto-fill,{udim(cs[:2])});grid-auto-rows:{udim(cs[2:])};gap:{cp[3]}px {cp[1]}px;align-content:start")
		kids_layout = "grid"
	text = ""
	if es_texto and node.get("Text"):
		fam = familia(node.get("FontFace"))
		weight = PESOS.get((node.get("FontFace") or ["", "Regular"])[1], 400)
		xa = {"Left": "flex-start", "Center": "center", "Right": "flex-end"}[node.get("TextXAlignment", "Center")]
		ya = {"Top": "flex-start", "Center": "center", "Bottom": "flex-end"}[node.get("TextYAlignment", "Center")]
		ta = {"Left": "left", "Center": "center", "Right": "right"}[node.get("TextXAlignment", "Center")]
		fg = node.get("TextColor3", [0, 0, 0])
		g0 = mod(node, "UIGradient")
		if g0 and isinstance(g0.get("Color"), list) and g0["Color"]:
			medio = g0["Color"][len(g0["Color"]) // 2]
			fg = [round(fg[i] * medio[i + 1] / 255) for i in range(3)]
		escalado = bool(node.get("TextScaled"))
		wrap = node.get("TextWrapped") or escalado
		tsc = mod(node, "UITextSizeConstraint")
		maxts = (tsc or {}).get("MaxTextSize", 100)
		tstyle = (
			f"display:flex;justify-content:{xa};align-items:{ya};width:100%;height:100%;"
			f"font-family:'{fam}','Noto Color Emoji';font-weight:{weight};font-size:{node.get('TextSize', 14)}px;line-height:1.15;"
			f"color:{rgba(fg, node.get('TextTransparency', 0))};text-align:{ta}"
		)
		span = "overflow:hidden;text-overflow:ellipsis;" + ("white-space:normal" if wrap else "white-space:nowrap")
		sk = node.get("TextStrokeTransparency", 1)
		borde = False
		if sk is not None and sk < 0.85:
			span += f";-webkit-text-stroke:1.5px {rgba(node.get('TextStrokeColor3', [0, 0, 0]), sk)};paint-order:stroke fill"
			borde = True
		if trazo_texto:
			col, grosor, tr = trazo_texto
			span += f";-webkit-text-stroke:{grosor * 2}px {rgba(col, tr)};paint-order:stroke fill"
			borde = tr < 0.85
		content = html.escape(node["Text"])
		if node.get("RichText"):
			content = re.sub(r'&lt;font color=&quot;(#[0-9A-Fa-f]{6})&quot;&gt;', r'<span style="color:\1">', content)
			content = re.sub(r"&lt;/?(font|b|i|u|stroke)[^&]*&gt;", "", content.replace("&lt;/font&gt;", "</span>"))
		extra = f' data-escalado="{maxts}"' if escalado else ""
		text = (f'<div class="txt" data-fg="{fg[0]},{fg[1]},{fg[2]}" data-borde="{int(borde)}"{extra} style="{tstyle}">'
			f'<span style="{span};max-width:100%;max-height:100%">{content}</span></div>')
	kids = "".join(render(k, ruta, kids_layout) for k in sorted(node["children"], key=lambda k: k.get("LayoutOrder", 0)))
	inner = f'<div style="{";".join(inner_style)}">{text}{kids}</div>'
	return f'<div class="g {cls}" style="{";".join(style)}" {" ".join(attrs)}>{inner}</div>'


HEAD = f"""<!doctype html><html><head><meta charset="utf-8">
<link href="{GOOGLE}" rel="stylesheet">
<style>body{{margin:0;background:#4a5568;font-family:'Nunito Sans';overflow:hidden}} .g{{box-sizing:border-box}} .g>div{{box-sizing:border-box}}
body::before{{content:'';position:fixed;inset:0;background:linear-gradient(180deg,#8fb7d9 0%,#b9d3e6 55%,#6b8f5e 56%,#52734a 100%);z-index:-1}}</style>
</head><body>"""


def pagina(guis, ancho, alto, barra):
	body = (f'<div style="position:absolute;left:0;top:0;width:{ancho}px;height:{barra}px;background:rgba(20,24,34,.55);'
		f'color:#cfd6e4;font:600 13px Nunito Sans;display:flex;align-items:center;padding-left:14px;box-sizing:border-box;z-index:0">'
		f'☰ · · ·  (botones de Roblox)</div>')
	for g in guis:
		if g.get("Enabled") is False:
			continue
		top = 0 if g.get("IgnoreGuiInset") else barra
		inner = "".join(render(k, g.get("name", "Gui")) for k in g["children"])
		body += (f'<div class="gui" style="position:absolute;left:0;top:{top}px;width:{ancho}px;height:{alto - top}px;'
			f'z-index:{(g.get("DisplayOrder") or 0) + 1}">{inner}</div>')
	return HEAD + body + "</body></html>"


ORDEN = ["cortado", "solape", "fuera", "gradiente", "pequeno", "contraste", "boton"]
TIPOS = {
	"pequeno": "Texto demasiado pequeño", "cortado": "Texto cortado (no cabe)", "contraste": "Contraste bajo",
	"boton": "Botón pequeño para el dedo", "fuera": "Se sale de la pantalla", "solape": "Textos que se pisan",
	"gradiente": "UIGradient dentro de un objeto con texto (tiñe el texto)",
}


def informe(carpeta, resultados, ancho, alto, movil):
	unicos = {}
	for nombre, res in resultados:
		for p in res["problemas"]:
			ruta = "/".join(p["ruta"].split("/")[-3:])
			# Contraste/tamaño/botón: se agrupan por pieza y medida (mismo fallo en muchos textos)
			agrupar = p["tipo"] in ("contraste", "pequeno", "boton")
			clave = (p["tipo"], ruta, p["detalle"] if agrupar else p["texto"][:30])
			u = unicos.setdefault(clave, {**p, "ruta_corta": ruta, "pantallas": [], "textos": set()})
			u["textos"].add(p["texto"][:30])
			if nombre not in u["pantallas"]:
				u["pantallas"].append(nombre)
	lista = sorted(unicos.values(), key=lambda u: (ORDEN.index(u["tipo"]) if u["tipo"] in ORDEN else 99, -len(u["pantallas"])))
	total = {}
	for u in lista:
		total[u["tipo"]] = total.get(u["tipo"], 0) + 1
	lineas = [f"# Informe de diseño ({ancho}×{alto}{', móvil' if movil else ''})", "",
		"Aproximado (no es Roblox: fuentes y medidas parecidas, no exactas). Cada problema sale UNA vez aunque se repita.",
		"Las capturas `<pantalla>_problemas.png` marcan en rojo, numerados, los problemas de esa pantalla.", "", "## Resumen (problemas distintos)"]
	if not lista:
		lineas.append("Sin problemas detectados ✅")
	for t in ORDEN:
		if t in total:
			lineas.append(f"- **{TIPOS[t]}**: {total[t]}")
	actual = None
	for u in lista:
		if u["tipo"] != actual:
			actual = u["tipo"]
			lineas += ["", f"## {TIPOS.get(actual, actual)}"]
		donde = u["pantallas"][0] + (f" y {len(u['pantallas']) - 1} más" if len(u["pantallas"]) > 1 else "")
		otros = f" (+{len(u['textos']) - 1} textos iguales)" if len(u["textos"]) > 1 else ""
		lineas.append(f"- «{u['texto'][:45]}»{otros} — {u['detalle']} · `{u['ruta_corta']}` · {donde}")
	ruta = os.path.join(carpeta, "informe_diseno.md")
	with open(ruta, "w", encoding="utf-8") as f:
		f.write("\n".join(lineas) + "\n")
	return ruta, total


def main():
	p = argparse.ArgumentParser()
	p.add_argument("carpeta")
	p.add_argument("--ancho", type=int, default=1280)
	p.add_argument("--alto", type=int, default=720)
	p.add_argument("--movil", action="store_true")
	p.add_argument("--escala", type=float, default=1)
	p.add_argument("--barra", type=int, default=58)
	p.add_argument("--estricto", action="store_true", help="sale con error si hay problemas graves")
	a = p.parse_args()
	a.carpeta = os.path.abspath(a.carpeta)
	if a.movil and a.ancho == 1280:
		a.ancho, a.alto = 844, 390
	paginas = []
	for nombre in sorted(os.listdir(a.carpeta)):
		if nombre.endswith(".json") and not nombre.endswith(".auditoria.json"):
			guis = json.load(open(os.path.join(a.carpeta, nombre), encoding="utf-8"))
			ruta = os.path.join(a.carpeta, nombre[:-5] + ".html")
			with open(ruta, "w", encoding="utf-8") as f:
				f.write(pagina(guis, a.ancho, a.alto, a.barra))
			paginas.append(ruta)
	if not paginas:
		sys.exit(f"No hay volcados .json en {a.carpeta}")
	umbrales = {"texto": 11 if a.movil else 12, "boton": 36 if a.movil else 24}
	env = {**os.environ, "NODE_PATH": subprocess.check_output(["npm", "root", "-g"], text=True).strip()}
	subprocess.run(["node", os.path.join(AQUI, "capturar.js"), str(a.ancho), str(a.alto), str(a.escala),
		json.dumps(umbrales)] + paginas, check=True, env=env)
	resultados = []
	for ruta in paginas:
		res = json.load(open(ruta[:-5] + ".auditoria.json", encoding="utf-8"))
		resultados.append((os.path.basename(ruta)[:-5], res))
	ruta, total = informe(a.carpeta, resultados, a.ancho, a.alto, a.movil)
	print(f"Capturas: {a.carpeta}/*.png · informe: {ruta}")
	print("Problemas:", ", ".join(f"{k}={v}" for k, v in total.items()) or "ninguno")
	graves = sum(total.get(k, 0) for k in ("cortado", "fuera", "solape", "gradiente"))
	if a.estricto and graves:
		sys.exit(1)


if __name__ == "__main__":
	main()
