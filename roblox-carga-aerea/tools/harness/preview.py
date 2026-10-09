"""Vista previa APROXIMADA de la interfaz: convierte el volcado JSON del harness
(run_client.luau <src> <carpeta>) en HTML y lo fotografía con Chromium.

No es Roblox: las fuentes son parecidas (Fredoka One real; Builder Sans → Nunito Sans; emojis de Noto),
AutomaticSize y el texto ajustado se aproximan. Sirve para ver colores,
distribución y solapes, no para medir píxeles.
Uso: python3 -I preview.py <carpeta con los .json> <ancho> <alto> [escala]
"""
import html
import json
import os
import subprocess
import sys

DIR = sys.argv[1]
WIDTH, HEIGHT = int(sys.argv[2]), int(sys.argv[3])
SCALE = float(sys.argv[4]) if len(sys.argv) > 4 else 1
TOPBAR = 58  # franja de botones de Roblox (IgnoreGuiInset = false)


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


GUI = {"Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame"}


def render(node, parent_layout=None):
	cls = node["class"]
	if cls not in GUI:
		return ""
	if node.get("Visible") is False:
		return ""
	style = []
	attrs = []
	size = node.get("Size", [0, 0, 0, 0])
	auto = node.get("AutomaticSize", "None")
	w = udim(size[:2])
	h = udim(size[2:])
	if parent_layout == "grid":
		# En una cuadrícula, Roblox usa el tamaño de la celda e ignora Size
		style.append("width:100%;height:100%")
	elif auto in ("X", "XY"):
		style.append(f"min-width:{w};width:max-content")
	else:
		style.append(f"width:{w}")
	if parent_layout == "grid":
		pass
	elif auto in ("Y", "XY"):
		style.append(f"min-height:{h};height:auto")
	else:
		style.append(f"height:{h}")
	ap = node.get("AnchorPoint", [0, 0])
	rot = node.get("Rotation", 0) or 0
	transform = []
	if parent_layout is None:
		pos = node.get("Position", [0, 0, 0, 0])
		style.append(f"position:absolute;left:{udim(pos[:2])};top:{udim(pos[2:])}")
		if ap != [0, 0]:
			transform.append(f"translate({-ap[0] * 100}%,{-ap[1] * 100}%)")
	else:
		style.append(f"position:relative;flex:none;order:{node.get('LayoutOrder', 0)}")
	if rot:
		transform.append(f"rotate({rot}deg)")
	if transform:
		style.append("transform:" + " ".join(transform))
	style.append(f"z-index:{node.get('ZIndex', 1)}")
	bt = node.get("BackgroundTransparency", 0)
	grad = mod(node, "UIGradient")
	if bt < 1 and grad and isinstance(grad.get("Color"), list) and len(grad["Color"]) == 2:
		a, b = grad["Color"]
		style.append(f"background:linear-gradient({grad.get('Rotation', 0) + 90}deg,{rgba(a, bt)},{rgba(b, bt)})")
	elif bt < 1 and node.get("BackgroundColor3"):
		style.append("background:" + rgba(node["BackgroundColor3"], bt))
	sc = mod(node, "UISizeConstraint")
	if sc and sc.get("MaxSize"):
		style.append(f"max-width:{sc['MaxSize'][0]}px")
	c = mod(node, "UICorner")
	if c:
		r = c["CornerRadius"]
		if r[0] == 0:
			style.append(f"border-radius:{r[1]}px")
		else:
			attrs.append(f'data-radius="{r[0]}"')
	st = mod(node, "UIStroke")
	if st and st.get("Thickness", 0) > 0:
		style.append(f"box-shadow:0 0 0 {st['Thickness']}px {rgba(st['Color'], st.get('Transparency', 0))}")
	if node.get("ClipsDescendants") or cls == "ScrollingFrame":
		style.append("overflow:hidden")
	ar = mod(node, "UIAspectRatioConstraint")
	if ar:
		attrs.append(f'data-aspect="{ar["AspectRatio"]}"')
	# Imagen (hoja de iconos: máscara teñida; ilustraciones: imagen tal cual)
	img = node.get("Image")
	if cls in ("ImageLabel", "ImageButton") and img:
		rect = node.get("ImageRectSize", [0, 0])
		col = node.get("ImageColor3", [255, 255, 255])
		attrs.append(f'data-img="file://{html.escape(img)}" data-rect="{node.get("ImageRectOffset", [0, 0])[0]},{node.get("ImageRectOffset", [0, 0])[1]},{rect[0]},{rect[1]}"')
		attrs.append(f'data-tint="{rgba(col, node.get("ImageTransparency", 0))}" data-fit="{node.get("ScaleType", "Stretch")}"')
	# Contenido: capa interior con el relleno (UIPadding)
	pad = mod(node, "UIPadding")
	inset = [0, 0, 0, 0]
	if pad:
		inset = [pad["PaddingTop"][1], pad["PaddingRight"][1], pad["PaddingBottom"][1], pad["PaddingLeft"][1]]
	inner_style = [f"position:absolute;top:{inset[0]}px;right:{inset[1]}px;bottom:{inset[2]}px;left:{inset[3]}px"]
	if auto != "None":
		inner_style = [f"position:relative;padding:{inset[0]}px {inset[1]}px {inset[2]}px {inset[3]}px"]
	layout = mod(node, "UIListLayout")
	grid = mod(node, "UIGridLayout")
	kids_layout = None
	if layout:
		horiz = layout["FillDirection"] == "Horizontal"
		jus = {"Left": "flex-start", "Center": "center", "Right": "flex-end", "Top": "flex-start", "Bottom": "flex-end"}
		main = jus[layout["HorizontalAlignment"] if horiz else layout["VerticalAlignment"]]
		cross = jus[layout["VerticalAlignment"] if horiz else layout["HorizontalAlignment"]]
		inner_style.append(f"display:flex;flex-direction:{'row' if horiz else 'column'};gap:{layout['Padding'][1]}px;justify-content:{main};align-items:{cross}")
		kids_layout = "list"
	elif grid:
		cs, cp = grid["CellSize"], grid["CellPadding"]
		inner_style.append(f"display:grid;grid-template-columns:repeat(auto-fill,{udim(cs[:2])});grid-auto-rows:{udim(cs[2:])};gap:{cp[3]}px {cp[1]}px;align-content:start")
		kids_layout = "grid"
	text = ""
	if cls in ("TextLabel", "TextButton") and node.get("Text"):
		fam = node.get("FontFace", ["", "Regular"])
		family = "Fredoka One" if "Fredoka" in fam[0] else ("Oswald" if "Oswald" in fam[0] else "Nunito Sans")
		weight = {"Bold": 700, "Medium": 500, "SemiBold": 600, "Regular": 400, "Heavy": 800}.get(fam[1], 400)
		xa = {"Left": "flex-start", "Center": "center", "Right": "flex-end"}[node.get("TextXAlignment", "Center")]
		ya = {"Top": "flex-start", "Center": "center", "Bottom": "flex-end"}[node.get("TextYAlignment", "Center")]
		wrap = node.get("TextWrapped")
		ta = {"Left": "left", "Center": "center", "Right": "right"}[node.get("TextXAlignment", "Center")]
		tstyle = (
			f"display:flex;justify-content:{xa};align-items:{ya};width:100%;height:100%;"
			f"font-family:'{family}','Noto Color Emoji';font-weight:{weight};font-size:{node.get('TextSize', 14)}px;line-height:1.1;"
			f"color:{rgba(node.get('TextColor3', [0, 0, 0]), node.get('TextTransparency', 0))};text-align:{ta}"
		)
		span = "overflow:hidden;text-overflow:ellipsis;" + ("white-space:normal" if wrap else "white-space:nowrap")
		sk = node.get("TextStrokeTransparency", 1)
		if sk is not None and sk < 1:
			span += f";-webkit-text-stroke:1.5px {rgba(node.get('TextStrokeColor3', [0, 0, 0]), sk)};paint-order:stroke fill"
		text = f'<div style="{tstyle}"><span style="{span};max-width:100%">{html.escape(node["Text"])}</span></div>'
	kids = "".join(render(k, kids_layout) for k in sorted(node["children"], key=lambda k: k.get("LayoutOrder", 0)))
	inner = f'<div style="{";".join(inner_style)}">{text}{kids}</div>'
	return f'<div class="g {cls}" style="{";".join(style)}" {" ".join(attrs)}>{inner}</div>'


SCRIPT = """
<script>
// Relación de aspecto (UIAspectRatioConstraint) e imágenes de hojas de sprites
document.querySelectorAll('[data-radius]').forEach(el => {
	const b = el.getBoundingClientRect();
	el.style.borderRadius = (parseFloat(el.dataset.radius) * Math.min(b.width, b.height)) + 'px';
});
document.querySelectorAll('[data-aspect]').forEach(el => {
	const p = el.parentElement.getBoundingClientRect();
	const r = parseFloat(el.dataset.aspect);
	let w = p.width, h = w / r;
	if (h > p.height) { h = p.height; w = h * r; }
	el.style.width = w + 'px'; el.style.height = h + 'px';
});
const sizes = {};
async function sheetSize(url) {
	if (sizes[url]) return sizes[url];
	const im = new Image(); im.src = url; await im.decode();
	return sizes[url] = [im.naturalWidth, im.naturalHeight];
}
(async () => {
	for (const el of document.querySelectorAll('[data-img]')) {
		const url = el.dataset.img;
		const [ox, oy, rw0, rh0] = el.dataset.rect.split(',').map(Number);
		const [SW, SH] = await sheetSize(url);
		const rw = rw0 || SW, rh = rh0 || SH;
		const box = el.getBoundingClientRect();
		let w = box.width, h = box.height, x = 0, y = 0;
		if (el.dataset.fit === 'Fit') {
			const s = Math.min(w / rw, h / rh); x = (w - rw * s) / 2; y = (h - rh * s) / 2; w = rw * s; h = rh * s;
		}
		const layer = document.createElement('div');
		const sx = w / rw, sy = h / rh;
		Object.assign(layer.style, { position: 'absolute', left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
		const props = `url("${url}") ${-ox * sx}px ${-oy * sy}px / ${SW * sx}px ${SH * sy}px no-repeat`;
		if (el.dataset.tint.startsWith('rgba(255,255,255') || el.dataset.fit === 'Fit' || !rw0) {
			layer.style.background = props;
		} else {
			layer.style.webkitMask = props; layer.style.background = el.dataset.tint;
		}
		el.prepend(layer);
	}
	document.body.dataset.ready = '1';
})();
</script>
"""

HEAD = """<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Oswald:wght@400;700&family=Fredoka+One&family=Noto+Color+Emoji&family=Nunito+Sans:wght@500;700&display=block" rel="stylesheet">
<style>body{margin:0;background:#3a4256;font-family:'Nunito Sans'} .g{box-sizing:border-box} .g>div{box-sizing:border-box}</style></head><body>"""

shots = []
for name in sorted(os.listdir(DIR)):
	if not name.endswith(".json"):
		continue
	guis = json.load(open(os.path.join(DIR, name)))
	body = f'<div style="position:absolute;left:0;top:0;width:{WIDTH}px;height:{TOPBAR}px;background:#1d2230;color:#9aa3b5;font:600 14px Nunito Sans;display:flex;align-items:center;padding-left:16px;box-sizing:border-box">· · ·  (botones de Roblox)</div>'
	body += f'<div style="position:absolute;left:0;top:{TOPBAR}px;width:{WIDTH}px;height:{HEIGHT - TOPBAR}px;overflow:hidden">'
	for g in guis:
		inner = "".join(render(k) for k in g["children"])
		body += f'<div style="position:absolute;inset:0">{inner}</div>'
	body += "</div>"
	path = os.path.join(DIR, name.replace(".json", ".html"))
	with open(path, "w") as f:
		f.write(HEAD + body + SCRIPT + "</body></html>")
	shots.append(path)

js = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_shot.js")
subprocess.run(["node", js, str(WIDTH), str(HEIGHT), str(SCALE)] + shots, check=True,
	env={**os.environ, "NODE_PATH": subprocess.check_output(["npm", "root", "-g"], text=True).strip()})
