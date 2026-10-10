"""Genera los mapas de relieve del juego (sin subir imágenes):
  src/ReplicatedStorage/MapData.luau    → España (regiones jugables + Canarias en un recuadro)
  src/ReplicatedStorage/MapDataFR.luau  → Francia («próximamente»)

Cómo se dibujan en Roblox: cada franja horizontal de tierra es un Frame con un UIGradient de hasta
20 colores muestreados del relieve, y el mar son filas de ancho completo con su propio degradado
(la plataforma continental sale más clara junto a la costa). Así se ve un mapa físico con pocos Frames.

Datos (dominio público, Natural Earth):
  - Fronteras: ne_10m_admin_1_states_provinces + ne_10m_admin_0_countries (vectores)
  - Relieve: HYP_50M_SR_W (Cross Blended Hypsometric Tints con relieve sombreado y agua, 1:50m)
Los colores se avivan (más saturación) para parecerse a un mapa físico escolar.

Uso: python3 -I tools/assets/build_maps.py <carpeta vectores NE 10m> <HYP_50M_SR_W.tif>
"""
import colorsys
import math
import os
import sys

import numpy as np
import shapefile  # pyshp
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
NE, TIF = sys.argv[1], sys.argv[2]
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "ReplicatedStorage")

MAX_KEYS = 20  # máximo de colores de un UIGradient
CHUNK = 0.08  # largo máximo de cada trozo de franja (fracción del ancho del mapa)
CHUNK_SEA = 0.125  # en el mar los cambios son suaves: trozos más largos
STEP = 0.0035  # separación entre muestras de color (fracción del ancho)

# ---------------------------------------------------------------------------
# Relieve: se carga solo la zona de Europa occidental y se muestrea con interpolación bilineal
# ---------------------------------------------------------------------------
LON_A, LON_B, LAT_A, LAT_B = -20.0, 12.0, 53.0, 25.0
_full = Image.open(TIF)
_W, _H = _full.size
_x0, _y0 = int((LON_A + 180) / 360 * _W), int((90 - LAT_A) / 180 * _H)
_x1, _y1 = int((LON_B + 180) / 360 * _W), int((90 - LAT_B) / 180 * _H)
RELIEF = np.asarray(_full.crop((_x0, _y0, _x1, _y1)).convert("RGB"), dtype=np.float32)
del _full


def relief(lon, lat):
	fx = (lon + 180) / 360 * _W - _x0 - 0.5
	fy = (90 - lat) / 180 * _H - _y0 - 0.5
	h, w, _ = RELIEF.shape
	fx = min(max(fx, 0), w - 1.001)
	fy = min(max(fy, 0), h - 1.001)
	ix, iy = int(fx), int(fy)
	dx, dy = fx - ix, fy - iy
	a = RELIEF[iy, ix] * (1 - dx) + RELIEF[iy, ix + 1] * dx
	b = RELIEF[iy + 1, ix] * (1 - dx) + RELIEF[iy + 1, ix + 1] * dx
	return a * (1 - dy) + b * dy


def physical(rgb):
	"""Colores de mapa físico escolar: los verdes azulados pasan a verde vivo y los tostados a amarillo/ocre."""
	h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
	if h > 0.2:
		h = 0.25 + (h - 0.2) * 0.25
		s = min(1.0, s * 2.6 + 0.12)
	else:
		if h > 0.05:
			h = 0.10 + (h - 0.05) * 0.6
		s = min(1.0, s * 2.2 + 0.08)
		v = min(1.0, v * 1.03)
	r, g, b = colorsys.hsv_to_rgb(h, s, v)
	return (r * 255, g * 255, b * 255)


def is_water(rgb):
	r, g, b = rgb
	return b >= g and b > r + 10


def land_color(lon, lat):
	return physical(relief(lon, lat))


def foreign_color(lon, lat):
	# Países vecinos: el mismo relieve pero apagado (como en los mapas físicos con el país destacado)
	r, g, b = physical(relief(lon, lat))
	k = 0.6
	return (r * (1 - k) + 236 * k, g * (1 - k) + 232 * k, b * (1 - k) + 222 * k)


def sea_color(lon, lat):
	h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in relief(lon, lat)))
	r, g, b = colorsys.hsv_to_rgb(h, min(1.0, s * 1.3), v)
	return (r * 255, g * 255, b * 255)


def sea_row(x0, x1, y, unproject, width):
	"""Muestras del mar a lo largo de una fila; donde hay tierra se copia el agua más cercana
	(si no, el degradado del mar se manchaba de verde junto a la costa)."""
	n = MAX_KEYS
	xs = [x0 + (x1 - x0) * i / (n - 1) for i in range(n)]
	raw = [relief(*unproject(x, y)) for x in xs]
	water = [is_water(c) for c in raw]
	out = []
	for i in range(n):
		if water[i]:
			out.append(sea_color(*unproject(xs[i], y)))
			continue
		best = None
		for d in range(1, n):
			for j in (i - d, i + d):
				if 0 <= j < n and water[j]:
					best = j
					break
			if best is not None:
				break
		out.append(sea_color(*unproject(xs[best], y)) if best is not None else (196, 226, 242))
	return out


def sea_rows(rows, top, height, x0, x1, unproject, width):
	"""Filas de mar troceadas (cada trozo con su degradado): [(fila, x0, x1, ref)]"""
	out = []
	n = max(1, int(math.ceil((x1 - x0) / (CHUNK_SEA * width))))
	w = (x1 - x0) / n
	for r in range(rows):
		y = top + (r + 0.5) * height / rows
		for i in range(n):
			out.append((r, x0 + i * w, x0 + (i + 1) * w, sea_row(x0 + i * w, x0 + (i + 1) * w, y, unproject, width)))
	return out


# ---------------------------------------------------------------------------
# Vectores
# ---------------------------------------------------------------------------
def rings(shape):
	pts = shape.points
	parts = list(shape.parts) + [len(pts)]
	for a, b in zip(parts[:-1], parts[1:]):
		yield pts[a:b]


def scan(polys, region, rows, row_h, min_w=0.004):
	"""Intersecta cada fila con los polígonos (regla par-impar) → [(fila, x0, x1, región)]."""
	out = []
	for row in range(rows):
		y = (row + 0.5) * row_h
		xs = []
		for ring in polys:
			for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
				if (y1 <= y < y2) or (y2 <= y < y1):
					xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
		xs.sort()
		for i in range(0, len(xs) - 1, 2):
			if xs[i + 1] - xs[i] > min_w:
				out.append((row, xs[i], xs[i + 1], region))
	return out


def clip(spans, width, min_w=0.004):
	"""Recorta las franjas al ancho del mapa (los países vecinos se salían del recuadro)."""
	out = []
	for row, x0, x1, reg in spans:
		a, b = max(0.0, x0), min(width, x1)
		if b - a > min_w:
			out.append((row, a, b, reg))
	return out


def merge(spans, gap):
	spans.sort(key=lambda s: (s[0], s[3], s[1]))
	out = []
	for s in spans:
		if out and out[-1][0] == s[0] and out[-1][3] == s[3] and s[1] - out[-1][2] < gap:
			out[-1] = (s[0], out[-1][1], max(out[-1][2], s[2]), s[3])
		else:
			out.append(s)
	return out


PROV = shapefile.Reader(os.path.join(NE, "ne_10m_admin_1_states_provinces.shp"))
PFIELDS = [f[0] for f in PROV.fields[1:]]
COUNTRIES = shapefile.Reader(os.path.join(NE, "ne_10m_admin_0_countries.shp"))
CFIELDS = [f[0] for f in COUNTRIES.fields[1:]]


def country_rings(names, proj):
	out = []
	for rec, shape in zip(COUNTRIES.iterRecords(), COUNTRIES.iterShapes()):
		d = dict(zip(CFIELDS, rec))
		if d["ADMIN"] in names:
			for ring in rings(shape):
				out.append([proj(lon, lat) for lon, lat in ring])
	return out


# ---------------------------------------------------------------------------
# Paleta común (256 colores) y codificación compacta: 2 cifras hex por color
# ---------------------------------------------------------------------------
class Palette:
	def __init__(self):
		self.samples = []

	def add(self, colors):
		start = len(self.samples)
		self.samples += colors
		return (start, len(colors))

	def build(self):
		arr = np.clip(np.array(self.samples, dtype=np.float32), 0, 255).astype(np.uint8).reshape(1, -1, 3)
		img = Image.fromarray(arr, "RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
		pal = img.getpalette()[: 256 * 3]
		self.index = list(np.asarray(img).reshape(-1))
		self.hex = "".join(f"{v:02x}" for v in pal)

	def encode(self, ref):
		start, n = ref
		idx = self.index[start : start + n]
		return "".join(f"{i:02x}" for i in idx)


def sample_row(x0, x1, y, color_at, width, max_keys=MAX_KEYS):
	n = max(2, min(max_keys, int(math.ceil((x1 - x0) / (STEP * width))) + 1))
	return [color_at(x0 + (x1 - x0) * i / (n - 1), y) for i in range(n)]


def chunks(row, x0, x1, reg, width):
	n = max(1, int(math.ceil((x1 - x0) / (CHUNK * width))))
	w = (x1 - x0) / n
	return [(row, x0 + i * w, x0 + (i + 1) * w, reg) for i in range(n)]


def write_module(path, header, body_lines):
	with open(path, "w") as f:
		f.write("\n".join(header + body_lines + ["", "return MapData", ""]))
	print(path, os.path.getsize(path) // 1024, "KB")


# ===========================================================================
# ESPAÑA
# ===========================================================================
LON0, LON1 = -10.2, 4.7
LAT_TOP, LAT_BOTTOM = 44.2, 34.6
K = math.cos(math.radians(40))
W = (LON1 - LON0) * K
H = LAT_TOP - LAT_BOTTOM
ROWS = 150
ROW_H = H / ROWS
SEA_ROWS = 48

CAN_LON0, CAN_LON1, CAN_LAT_TOP, CAN_LAT_BOTTOM = -18.3, -13.3, 29.5, 27.5
CAN_K = math.cos(math.radians(28.5))
CAN_SCALE = 0.6
CAN_X, CAN_Y = 0.2, H - (CAN_LAT_TOP - CAN_LAT_BOTTOM) * CAN_SCALE - 0.2
CAN_W = (CAN_LON1 - CAN_LON0) * CAN_K * CAN_SCALE
CAN_H = (CAN_LAT_TOP - CAN_LAT_BOTTOM) * CAN_SCALE

REGIONS = ["CEN", "LEV", "CAT", "AND", "NOR", "CYL", "GAL", "BAL", "CAN"]
COMMUNITY = {
	"Madrid": "CEN", "Castilla-La Mancha": "CEN",
	"Valenciana": "LEV", "Murcia": "LEV",
	"Cataluña": "CAT", "Aragón": "CAT",
	"Andalucía": "AND", "Ceuta": "AND", "Melilla": "AND",
	"País Vasco": "NOR", "Foral de Navarra": "NOR", "La Rioja": "NOR", "Cantabria": "NOR", "Asturias": "NOR",
	"Castilla y León": "CYL", "Extremadura": "CYL",
	"Galicia": "GAL", "Islas Baleares": "BAL", "Canary Is.": "CAN",
}
FOREIGN_ES = {"Portugal", "France", "Andorra", "Morocco", "Algeria", "Gibraltar"}


def es_project(lon, lat):
	return (lon - LON0) * K, LAT_TOP - lat


def es_unproject(x, y):
	return x / K + LON0, LAT_TOP - y


def can_project(lon, lat):
	return CAN_X + (lon - CAN_LON0) * CAN_K * CAN_SCALE, CAN_Y + (CAN_LAT_TOP - lat) * CAN_SCALE


def can_unproject(x, y):
	return (x - CAN_X) / (CAN_K * CAN_SCALE) + CAN_LON0, CAN_LAT_TOP - (y - CAN_Y) / CAN_SCALE


def in_can_box(x, y, pad=0.0):
	return CAN_X - pad <= x <= CAN_X + CAN_W + pad and CAN_Y - pad <= y <= CAN_Y + CAN_H + pad


def build_spain(pal):
	by_region = {r: [] for r in REGIONS}
	for rec, shape in zip(PROV.iterRecords(), PROV.iterShapes()):
		d = dict(zip(PFIELDS, rec))
		if d["admin"] != "Spain":
			continue
		region = COMMUNITY[d["region"]]
		proj = can_project if region == "CAN" else es_project
		for ring in rings(shape):
			by_region[region].append([proj(lon, lat) for lon, lat in ring])
	spans = []
	for i, region in enumerate(REGIONS):
		spans += scan(by_region[region], i + 1, ROWS, ROW_H)
	foreign = scan(country_rings(FOREIGN_ES, es_project), 0, ROWS, ROW_H)
	# Lo extranjero que cae dentro del recuadro de Canarias se recorta
	clean = []
	for row, x0, x1, reg in foreign:
		y = (row + 0.5) * ROW_H
		bx0, bx1 = CAN_X - 0.12, CAN_X + CAN_W + 0.12
		if CAN_Y - 0.12 <= y <= CAN_Y + CAN_H + 0.12 and x1 > bx0 and x0 < bx1:
			if x0 < bx0:
				clean.append((row, x0, bx0, reg))
			if x1 > bx1:
				clean.append((row, bx1, x1, reg))
		else:
			clean.append((row, x0, x1, reg))
	spans = clip(merge(clean + spans, 0.01), W)

	out = []
	for row, x0, x1, reg in spans:
		for c in chunks(row, x0, x1, reg, W):
			y = (c[0] + 0.5) * ROW_H
			if reg == 9:
				color_at = lambda x, yy: land_color(*can_unproject(x, yy))
			elif reg == 0:
				color_at = lambda x, yy: foreign_color(*es_unproject(x, yy))
			else:
				color_at = lambda x, yy: land_color(*es_unproject(x, yy))
			out.append((c, pal.add(sample_row(c[1], c[2], y, color_at, W))))
	# Mar: filas troceadas (la península); el recuadro de Canarias tiene su propio mar
	sea = [(r, a, b, pal.add(c)) for r, a, b, c in sea_rows(SEA_ROWS, 0, H, 0, W, es_unproject, W)]
	can_rows = 14
	sea_can = [(r, a, b, pal.add(c)) for r, a, b, c in sea_rows(can_rows, CAN_Y, CAN_H, CAN_X, CAN_X + CAN_W, can_unproject, W)]
	return out, sea, sea_can, can_rows


def emit_spain(pal, out, sea, sea_can, can_rows):
	header = [
		"-- GENERADO por tools/assets/build_maps.py (Natural Earth, dominio público). No editar a mano.",
		"-- Mapa físico de España en franjas con degradados de relieve (sin imágenes):",
		"--   spans = { fila, x0, x1, región, colores } (x en 0..1; región = índice de MapData.regions, 0 = país vecino)",
		"--   sea / seaCanary = { fila, x0, x1, colores } trozos de filas de mar (la península / el recuadro de Canarias;",
		"--   en seaCanary x va de 0 a 1 dentro del recuadro)",
		"--   colores = 2 cifras hex por color (índice en MapData.palette), repartidos a lo largo de la franja",
		"",
		"local MapData = {}",
		f"MapData.aspect = {W / H:.5f} -- ancho / alto",
		f"MapData.rows = {ROWS}",
		f"MapData.seaRows = {SEA_ROWS}",
		f"MapData.canaryRows = {can_rows}",
		"MapData.regions = { " + ", ".join(f'"{r}"' for r in REGIONS) + " }",
		f"MapData.canaryBox = {{ {CAN_X / W:.4f}, {CAN_Y / H:.4f}, {CAN_W / W:.4f}, {CAN_H / H:.4f} }} -- x, y, ancho, alto",
		"",
		"-- Posición (0..1) de una coordenada real; Canarias se lleva a su recuadro",
		"function MapData.project(lat: number, lon: number): (number, number)",
		"\tif lon < -12.5 and lat < 30 then",
		f"\t\treturn ({CAN_X} + (lon - ({CAN_LON0})) * {CAN_K:.5f} * {CAN_SCALE}) / {W:.5f}, ({CAN_Y:.5f} + ({CAN_LAT_TOP} - lat) * {CAN_SCALE}) / {H:.5f}",
		"\tend",
		f"\treturn (lon - ({LON0})) * {K:.5f} / {W:.5f}, ({LAT_TOP} - lat) / {H:.5f}",
		"end",
		"",
		f'MapData.palette = "{pal.hex}"',
		"",
	]
	body = ["MapData.spans = {"]
	for (row, x0, x1, reg), ref in out:
		body.append(f'\t{{ {row}, {x0 / W:.4f}, {x1 / W:.4f}, {reg}, "{pal.encode(ref)}" }},')
	body += ["}", "", "MapData.sea = {"]
	for r, a, b, ref in sea:
		body.append(f'\t{{ {r}, {a / W:.4f}, {b / W:.4f}, "{pal.encode(ref)}" }},')
	body += ["}", "", "MapData.seaCanary = {"]
	for r, a, b, ref in sea_can:
		body.append(f'\t{{ {r}, {(a - CAN_X) / CAN_W:.4f}, {(b - CAN_X) / CAN_W:.4f}, "{pal.encode(ref)}" }},')
	body.append("}")
	write_module(os.path.join(SRC, "MapData.luau"), header, body)
	print("España:", len(out), "franjas de tierra,", len(sea) + len(sea_can), "filas de mar")


# ===========================================================================
# FRANCIA (próximamente): mismo sistema, sin regiones jugables todavía
# ===========================================================================
FR_LON0, FR_LON1 = -5.6, 9.9
FR_LAT_TOP, FR_LAT_BOTTOM = 51.4, 41.2
FR_K = math.cos(math.radians(46.5))
FR_W = (FR_LON1 - FR_LON0) * FR_K
FR_H = FR_LAT_TOP - FR_LAT_BOTTOM
FR_ROWS = 120
FR_SEA_ROWS = 40
FOREIGN_FR = {
	"Spain", "Andorra", "Belgium", "Luxembourg", "Germany", "Switzerland", "Italy", "United Kingdom",
	"Netherlands", "Monaco", "Liechtenstein", "Austria", "Jersey", "Guernsey", "San Marino",
}


def fr_project(lon, lat):
	return (lon - FR_LON0) * FR_K, FR_LAT_TOP - lat


def fr_unproject(x, y):
	return x / FR_K + FR_LON0, FR_LAT_TOP - y


def build_france(pal):
	row_h = FR_H / FR_ROWS
	spans = scan(country_rings({"France"}, fr_project), 1, FR_ROWS, row_h)
	spans += scan(country_rings(FOREIGN_FR, fr_project), 0, FR_ROWS, row_h)
	spans = clip(merge(spans, 0.01), FR_W)
	out = []
	for row, x0, x1, reg in spans:
		for c in chunks(row, x0, x1, reg, FR_W):
			y = (c[0] + 0.5) * row_h
			if reg == 0:
				color_at = lambda x, yy: foreign_color(*fr_unproject(x, yy))
			else:
				color_at = lambda x, yy: land_color(*fr_unproject(x, yy))
			out.append((c, pal.add(sample_row(c[1], c[2], y, color_at, FR_W))))
	sea = [(r, a, b, pal.add(c)) for r, a, b, c in sea_rows(FR_SEA_ROWS, 0, FR_H, 0, FR_W, fr_unproject, FR_W)]
	return out, sea


def emit_france(pal, out, sea):
	header = [
		"-- GENERADO por tools/assets/build_maps.py (Natural Earth, dominio público). No editar a mano.",
		"-- Mapa físico de Francia («próximamente»): mismo formato que MapData (región 1 = Francia, 0 = vecino).",
		"",
		"local MapData = {}",
		f"MapData.aspect = {FR_W / FR_H:.5f}",
		f"MapData.rows = {FR_ROWS}",
		f"MapData.seaRows = {FR_SEA_ROWS}",
		"function MapData.project(lat: number, lon: number): (number, number)",
		f"\treturn (lon - ({FR_LON0})) * {FR_K:.5f} / {FR_W:.5f}, ({FR_LAT_TOP} - lat) / {FR_H:.5f}",
		"end",
		f'MapData.palette = "{pal.hex}"',
		"",
	]
	body = ["MapData.spans = {"]
	for (row, x0, x1, reg), ref in out:
		body.append(f'\t{{ {row}, {x0 / FR_W:.4f}, {x1 / FR_W:.4f}, {reg}, "{pal.encode(ref)}" }},')
	body += ["}", "", "MapData.sea = {"]
	for r, a, b, ref in sea:
		body.append(f'\t{{ {r}, {a / FR_W:.4f}, {b / FR_W:.4f}, "{pal.encode(ref)}" }},')
	body.append("}")
	write_module(os.path.join(SRC, "MapDataFR.luau"), header, body)
	print("Francia:", len(out), "franjas de tierra,", len(sea), "filas de mar")


pal_es = Palette()
es = build_spain(pal_es)
pal_es.build()
emit_spain(pal_es, *es)

pal_fr = Palette()
fr = build_france(pal_fr)
pal_fr.build()
emit_france(pal_fr, *fr)
