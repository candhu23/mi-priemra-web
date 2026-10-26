#!/usr/bin/env python3
"""Genera iconos de pases/productos, icono del juego y miniaturas como PNG (HTML → Chromium).

Uso: python3 -I arte.py <encargo.json> <carpeta_salida>
Salida: un PNG por pieza + hoja.png (todas juntas; los iconos recortados en círculo como los
muestra Roblox, para revisarlos de un vistazo).

encargo.json:
{
  "estilo": { "fondo": ["#1e3a8a", "#38bdf8"], "texto": "#facc15", "borde": "#172554",
              "letra": "Fredoka One", "rayos": true, "chispas": true },
  "piezas": [
    { "tipo": "pase", "archivo": "x2_dinero.png", "emoji": "💰", "titulo": "x2", "subtitulo": "MONEY",
      "fondo": ["#14532d", "#4ade80"], "flechas": true },
    { "tipo": "icono", "archivo": "icono.png", "emoji": "🏙️", "titulo": "WEB EMPIRE" },
    { "tipo": "miniatura", "archivo": "mini1.png", "titulo": "WEB EMPIRE TYCOON", "subtitulo": "Code websites · Get rich",
      "emoji": "🏙️", "imagen": "ruta/captura.png", "etiqueta": "🆕 UPDATE" }
  ]
}
tipo: pase | producto | icono (512×512) · miniatura (1920×1080). Cualquier clave de «estilo» se
puede poner también dentro de una pieza. «imagen» (miniatura) = fondo con una captura o render.
"""
import html
import json
import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
TAMANOS = {"pase": (512, 512), "producto": (512, 512), "icono": (512, 512), "miniatura": (1920, 1080)}
DEFECTO = {"fondo": ["#1e3a8a", "#38bdf8"], "texto": "#facc15", "borde": "#172554", "letra": "Fredoka One",
	"rayos": True, "chispas": True, "flechas": False}
FUENTES = ("https://fonts.googleapis.com/css2?family=Fredoka+One&family=Luckiest+Guy&family=Bangers"
	"&family=Montserrat:wght@800;900&family=Nunito:wght@800;900&family=Noto+Color+Emoji&display=block")


def chispas(semilla, n, ancho, alto, maximo):
	x = sum(ord(c) for c in semilla) * 7919 + 13
	out = []
	for _ in range(n):
		x = (x * 1103515245 + 12345) % 2**31
		px = x % ancho
		x = (x * 1103515245 + 12345) % 2**31
		py = x % alto
		x = (x * 1103515245 + 12345) % 2**31
		r = 2 + x % maximo
		out.append(f'<i style="left:{px}px;top:{py}px;width:{r}px;height:{r}px;opacity:{0.35 + (x % 50) / 100:.2f}"></i>')
	return "".join(out)


def flecha(lado, tam):
	pos = "left:26px" if lado == "izq" else "right:26px"
	return (f'<svg class="flecha" style="{pos};width:{tam}px;height:{tam * 1.3}px" viewBox="0 0 40 52">'
		'<path d="M20 2 L38 24 H27 V50 H13 V24 H2 Z" fill="#22c55e" stroke="#14532d" stroke-width="3" stroke-linejoin="round"/></svg>')


def css_base(e, w, h):
	c1, c2 = e["fondo"][0], e["fondo"][-1]
	rayos = ("repeating-conic-gradient(from 0deg at 50% 45%, rgba(255,255,255,.13) 0deg 7deg, rgba(255,255,255,0) 7deg 18deg),"
		if e.get("rayos") else "")
	return f"""
	*{{box-sizing:border-box}} body{{margin:0;width:{w}px;height:{h}px;overflow:hidden}}
	.lienzo{{position:relative;width:{w}px;height:{h}px;overflow:hidden;
		background:{rayos} radial-gradient(circle at 50% 45%, {c2} 0%, {c1} 72%);}}
	.lienzo i{{position:absolute;border-radius:50%;background:#fff;box-shadow:0 0 6px #fff}}
	.brillo{{position:absolute;left:50%;top:45%;width:{w * 0.75}px;height:{w * 0.75}px;transform:translate(-50%,-50%);
		background:radial-gradient(circle, rgba(255,255,255,.55) 0%, rgba(255,255,255,0) 62%)}}
	.t{{font-family:'{e["letra"]}','Noto Color Emoji';color:{e["texto"]};line-height:1;white-space:nowrap;text-align:center;
		-webkit-text-stroke:var(--b) {e["borde"]};paint-order:stroke fill;
		filter:drop-shadow(0 calc(var(--b) * .6) 0 rgba(0,0,0,.35))}}
	.emoji{{font-family:'Noto Color Emoji';line-height:1;filter:drop-shadow(0 10px 12px rgba(0,0,0,.35))}}
	.flecha{{position:absolute;bottom:120px;filter:drop-shadow(0 4px 0 rgba(0,0,0,.3))}}
	"""


def icono(p, e, w, h):
	tiene_texto = bool(p.get("titulo"))
	em = p.get("emoji", "")
	partes = [f'<div class="brillo"></div>']
	if e.get("chispas"):
		partes.append(chispas(p["archivo"], 26, w, h, 9))
	if e.get("flechas"):
		partes += [flecha("izq", 54), flecha("der", 54)]
	if em:
		tam = 200 if tiene_texto else 330
		top = 34 if tiene_texto else 90
		partes.append(f'<div class="emoji" style="position:absolute;left:0;right:0;top:{top}px;text-align:center;font-size:{tam}px">{html.escape(em)}</div>')
	# Zona segura del círculo: el texto se encoge hasta caber en el ancho del círculo a su altura
	if tiene_texto:
		y_titulo = 238 if em else 150
		partes.append(f'<div class="t ajustar" data-max="{0.78 * w:.0f}" style="--b:14px;position:absolute;left:0;right:0;top:{y_titulo}px;font-size:{136 if em else 180}px">{html.escape(p["titulo"])}</div>')
	if p.get("subtitulo"):
		y_sub = 378 if em else 340
		partes.append(f'<div class="t ajustar" data-max="{0.66 * w:.0f}" style="--b:10px;color:#fff;position:absolute;left:0;right:0;top:{y_sub}px;font-size:62px">{html.escape(p["subtitulo"])}</div>')
	return "".join(partes)


def miniatura(p, e, w, h):
	partes = []
	if p.get("imagen"):
		ruta = os.path.abspath(p["imagen"])
		partes.append(f'<div style="position:absolute;inset:0;background:url(\'file://{html.escape(ruta)}\') center/cover;filter:saturate(1.15)"></div>')
		partes.append('<div style="position:absolute;inset:0;background:linear-gradient(90deg,rgba(0,0,0,.72) 0%,rgba(0,0,0,.35) 48%,rgba(0,0,0,0) 70%)"></div>')
	else:
		partes.append('<div class="brillo" style="left:72%"></div>')
		if e.get("chispas"):
			partes.append(chispas(p["archivo"], 70, w, h, 12))
	if p.get("emoji"):
		partes.append(f'<div class="emoji" style="position:absolute;right:120px;top:50%;transform:translateY(-50%) rotate(-6deg);font-size:520px">{html.escape(p["emoji"])}</div>')
	if p.get("etiqueta"):
		partes.append(f'<div style="position:absolute;left:90px;top:80px;background:#ef4444;color:#fff;font:900 54px Montserrat,\'Noto Color Emoji\';'
			f'padding:12px 30px;border-radius:18px;transform:rotate(-3deg);box-shadow:0 8px 0 #7f1d1d">{html.escape(p["etiqueta"])}</div>')
	titulo = html.escape(p.get("titulo", "")).replace("\\n", "<br>")
	partes.append(f'<div class="t ajustar" data-max="1100" style="--b:22px;position:absolute;left:90px;top:230px;text-align:left;font-size:180px;width:max-content;line-height:.95">{titulo}</div>')
	if p.get("subtitulo"):
		partes.append(f'<div style="position:absolute;left:96px;bottom:110px;background:rgba(255,255,255,.95);color:{e["borde"]};font:900 64px Montserrat,\'Noto Color Emoji\';'
			f'padding:16px 36px;border-radius:999px;box-shadow:0 10px 0 rgba(0,0,0,.25)">{html.escape(p["subtitulo"])}</div>')
	return "".join(partes)


AJUSTE = """<script>
document.fonts.ready.then(async () => {
	// Cargar a la fuerza los trozos de la fuente de emojis que se usan (si no, a veces salen en blanco)
	for (const el of document.querySelectorAll('.emoji, .t, [style*=Emoji]')) {
		try { await document.fonts.load('100px "Noto Color Emoji"', el.textContent); } catch (e) {}
	}
	await document.fonts.ready;
	document.querySelectorAll('.ajustar').forEach(el => {
		const max = +el.dataset.max; let fs = parseFloat(getComputedStyle(el).fontSize);
		el.style.left = '50%'; el.style.right = 'auto'; el.style.transform = 'translateX(-50%)';
		if (el.style.textAlign === 'left') { el.style.left = el.dataset.left || '90px'; el.style.transform = 'none'; }
		while (el.scrollWidth > max && fs > 20) { fs -= 4; el.style.fontSize = fs + 'px'; }
	});
	document.body.dataset.ready = '1';
});
</script>"""


def main():
	if len(sys.argv) < 3:
		sys.exit(__doc__)
	encargo = json.load(open(sys.argv[1], encoding="utf-8"))
	salida = os.path.abspath(sys.argv[2])
	os.makedirs(salida, exist_ok=True)
	base = {**DEFECTO, **encargo.get("estilo", {})}
	trabajos = []
	for p in encargo["piezas"]:
		tipo = p.get("tipo", "pase")
		if tipo not in TAMANOS:
			sys.exit(f"tipo desconocido: {tipo}")
		w, h = TAMANOS[tipo]
		e = {**base, **{k: v for k, v in p.items() if k in DEFECTO or k in ("fondo", "texto", "borde", "letra")}}
		cuerpo = miniatura(p, e, w, h) if tipo == "miniatura" else icono(p, e, w, h)
		doc = (f'<!doctype html><html><head><meta charset="utf-8"><link href="{FUENTES}" rel="stylesheet">'
			f'<style>{css_base(e, w, h)}</style></head><body><div class="lienzo">{cuerpo}</div>{AJUSTE}</body></html>')
		ruta_html = os.path.join(salida, "." + p["archivo"] + ".html")
		with open(ruta_html, "w", encoding="utf-8") as f:
			f.write(doc)
		trabajos.append({"html": ruta_html, "png": os.path.join(salida, p["archivo"]), "w": w, "h": h, "circulo": tipo != "miniatura"})
	env = {**os.environ, "NODE_PATH": subprocess.check_output(["npm", "root", "-g"], text=True).strip()}
	subprocess.run(["node", os.path.join(AQUI, "fotografiar.js"), json.dumps(trabajos), os.path.join(salida, "hoja.png")], check=True, env=env)
	for t in trabajos:
		os.remove(t["html"])
	print(f"Listo: {len(trabajos)} imágenes en {salida} (+ hoja.png para revisar)")


if __name__ == "__main__":
	main()
