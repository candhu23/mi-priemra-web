"""Genera src/ReplicatedStorage/MapData.luau: el mapa de España en franjas horizontales.

El cliente dibuja cada franja como un Frame, así el mapa se ve SIN subir imágenes.
Datos: Natural Earth 1:10m (provincias y países), dominio público.
Uso: python3 -I tools/assets/build_spain.py <carpeta con ne_10m_admin_1_states_provinces.shp y ne_10m_admin_0_countries.shp>

Proyección: x = (lon - LON0) * cos(40°), y = LAT_TOP - lat, normalizado a 0..1.
Canarias va en un recuadro abajo a la izquierda (como en los mapas españoles).
"""
import math
import os
import sys

import shapefile  # pyshp

NE = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "src", "ReplicatedStorage", "MapData.luau")

LON0, LON1 = -10.2, 4.7
LAT_TOP, LAT_BOTTOM = 44.2, 34.6
K = math.cos(math.radians(40))
W = (LON1 - LON0) * K
H = LAT_TOP - LAT_BOTTOM
ROWS = 130
ROW_H = H / ROWS

# Recuadro de Canarias: zona real y dónde se coloca (unidades del mapa)
CAN_LON0, CAN_LON1, CAN_LAT_TOP, CAN_LAT_BOTTOM = -18.3, -13.3, 29.5, 27.5
CAN_K = math.cos(math.radians(28.5))
CAN_SCALE = 0.6
CAN_X, CAN_Y = 0.2, H - (CAN_LAT_TOP - CAN_LAT_BOTTOM) * CAN_SCALE - 0.2

# Regiones del juego (orden = índice en Luau, empezando en 1)
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
FOREIGN = {"Portugal", "France", "Andorra", "Morocco", "Algeria", "Gibraltar"}


def project(lon, lat):
	return (lon - LON0) * K, LAT_TOP - lat


def project_can(lon, lat):
	return CAN_X + (lon - CAN_LON0) * CAN_K * CAN_SCALE, CAN_Y + (CAN_LAT_TOP - lat) * CAN_SCALE


def rings(shape):
	pts = shape.points
	parts = list(shape.parts) + [len(pts)]
	for a, b in zip(parts[:-1], parts[1:]):
		yield pts[a:b]


def scan(polys, region):
	"""Intersecta cada fila con los polígonos (regla par-impar) → lista de (fila, x0, x1, región)."""
	out = []
	for row in range(ROWS):
		y = (row + 0.5) * ROW_H
		xs = []
		for ring in polys:
			for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
				if (y1 <= y < y2) or (y2 <= y < y1):
					xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
		xs.sort()
		for i in range(0, len(xs) - 1, 2):
			if xs[i + 1] - xs[i] > 0.004:
				out.append((row, xs[i], xs[i + 1], region))
	return out


spans = []
prov = shapefile.Reader(os.path.join(NE, "ne_10m_admin_1_states_provinces.shp"))
fields = [f[0] for f in prov.fields[1:]]
by_region = {r: [] for r in REGIONS}
for rec, shape in zip(prov.iterRecords(), prov.iterShapes()):
	d = dict(zip(fields, rec))
	if d["admin"] != "Spain":
		continue
	region = COMMUNITY[d["region"]]
	proj = project_can if region == "CAN" else project
	for ring in rings(shape):
		by_region[region].append([proj(lon, lat) for lon, lat in ring])
for i, region in enumerate(REGIONS):
	spans += scan(by_region[region], i + 1)

countries = shapefile.Reader(os.path.join(NE, "ne_10m_admin_0_countries.shp"))
cfields = [f[0] for f in countries.fields[1:]]
foreign = []
for rec, shape in zip(countries.iterRecords(), countries.iterShapes()):
	d = dict(zip(cfields, rec))
	if d["ADMIN"] in FOREIGN:
		for ring in rings(shape):
			foreign.append([project(lon, lat) for lon, lat in ring])
foreign_spans = scan(foreign, 0)
# Quitar lo que caiga dentro del recuadro de Canarias
can_w = (CAN_LON1 - CAN_LON0) * CAN_K * CAN_SCALE
can_h = (CAN_LAT_TOP - CAN_LAT_BOTTOM) * CAN_SCALE
box = (CAN_X - 0.15, CAN_Y - 0.15, CAN_X + can_w + 0.15, CAN_Y + can_h + 0.15)
clean = []
for row, x0, x1, reg in foreign_spans:
	y = (row + 0.5) * ROW_H
	if box[1] <= y <= box[3] and x1 > box[0] and x0 < box[2]:
		if x0 < box[0]:
			clean.append((row, x0, box[0], reg))
		if x1 > box[2]:
			clean.append((row, box[2], x1, reg))
	else:
		clean.append((row, x0, x1, reg))
spans = clean + spans

# Unir franjas contiguas de la misma región en la misma fila
spans.sort(key=lambda s: (s[0], s[3], s[1]))
merged = []
for s in spans:
	if merged and merged[-1][0] == s[0] and merged[-1][3] == s[3] and s[1] - merged[-1][2] < 0.01:
		merged[-1] = (s[0], merged[-1][1], max(merged[-1][2], s[2]), s[3])
	else:
		merged.append(s)

lines = [
	"-- GENERADO por tools/assets/build_spain.py (Natural Earth, dominio público). No editar a mano.",
	"-- Mapa de España en franjas: { fila, x0, x1, región } con x en 0..1 y región = índice de",
	"-- MapData.regions (0 = país vecino). Canarias va en un recuadro abajo a la izquierda.",
	"",
	"local MapData = {}",
	f"MapData.aspect = {W / H:.5f} -- ancho / alto",
	f"MapData.rows = {ROWS}",
	"MapData.regions = { " + ", ".join(f'"{r}"' for r in REGIONS) + " }",
	f"MapData.canaryBox = {{ {CAN_X / W:.4f}, {CAN_Y / H:.4f}, {can_w / W:.4f}, {can_h / H:.4f} }} -- x, y, ancho, alto",
	"",
	"-- Posición (0..1) de una coordenada real; Canarias se lleva a su recuadro",
	"function MapData.project(lat: number, lon: number): (number, number)",
	f"\tif lon < -12.5 and lat < 30 then",
	f"\t\treturn ({CAN_X} + (lon - ({CAN_LON0})) * {CAN_K:.5f} * {CAN_SCALE}) / {W:.5f}, ({CAN_Y:.5f} + ({CAN_LAT_TOP} - lat) * {CAN_SCALE}) / {H:.5f}",
	"\tend",
	f"\treturn (lon - ({LON0})) * {K:.5f} / {W:.5f}, ({LAT_TOP} - lat) / {H:.5f}",
	"end",
	"",
	"MapData.spans = {",
]
for row, x0, x1, reg in merged:
	lines.append(f"\t{{ {row}, {x0 / W:.4f}, {x1 / W:.4f}, {reg} }},")
lines += ["}", "", "return MapData", ""]
with open(OUT, "w") as f:
	f.write("\n".join(lines))
print(OUT, len(merged), "franjas")
