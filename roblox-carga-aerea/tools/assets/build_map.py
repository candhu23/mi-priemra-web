"""Genera el mapa del mundo (estilo oscuro) en 2 imágenes de 1024 px para subir a Roblox.

Datos: Natural Earth 1:50m (dominio público), https://www.naturalearthdata.com/
Proyección equirrectangular: longitud -180..180, latitud 80..-60 (igual que Config.Map).
Uso: python3 -I tools/assets/build_map.py <carpeta con los .shp de Natural Earth>
Salida: assets/mapa_oeste.png (lon -180..0) y assets/mapa_este.png (lon 0..180).
"""
import os
import sys

import shapefile  # pyshp
from PIL import Image, ImageDraw, ImageFilter

NE = sys.argv[1]
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
LAT_TOP, LAT_BOTTOM = 80, -60
SS = 3  # superresolución para suavizar bordes
W, H = 2048 * SS, round(2048 * (LAT_TOP - LAT_BOTTOM) / 360) * SS

OCEAN = (9, 16, 31)
LAND = (27, 41, 64)
LAND_EDGE = (64, 100, 150)
LAKE = (12, 21, 40)
BORDER = (52, 74, 108)
GRID = (20, 31, 52)


def xy(lon, lat):
	return ((lon + 180) / 360 * W, (LAT_TOP - lat) / (LAT_TOP - LAT_BOTTOM) * H)


def rings(path):
	for shp in shapefile.Reader(path).shapes():
		pts = shp.points
		parts = list(shp.parts) + [len(pts)]
		for a, b in zip(parts[:-1], parts[1:]):
			yield [xy(lon, lat) for lon, lat in pts[a:b]]


img = Image.new("RGB", (W, H), OCEAN)
d = ImageDraw.Draw(img)
# Retícula cada 15 grados
for lon in range(-180, 181, 15):
	x, _ = xy(lon, 0)
	d.line([(x, 0), (x, H)], fill=GRID, width=SS)
for lat in range(-60, 81, 15):
	_, y = xy(0, lat)
	d.line([(0, y), (W, y)], fill=GRID, width=SS)

land = os.path.join(NE, "ne_50m_land.shp")
# Resplandor de la costa: silueta engordada y difuminada
glow = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glow)
for ring in rings(land):
	if len(ring) > 2:
		gd.polygon(ring, fill=255)
glow = glow.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(10 * SS))
img.paste(Image.new("RGB", (W, H), (30, 58, 96)), (0, 0), glow.point(lambda v: int(v * 0.55)))

for ring in rings(land):
	if len(ring) > 2:
		d.polygon(ring, fill=LAND)
for ring in rings(os.path.join(NE, "ne_50m_lakes.shp")):
	if len(ring) > 2:
		d.polygon(ring, fill=LAKE)
for ring in rings(os.path.join(NE, "ne_50m_admin_0_boundary_lines_land.shp")):
	d.line(ring, fill=BORDER, width=SS)
for ring in rings(land):
	if len(ring) > 2:
		d.line(ring + [ring[0]], fill=LAND_EDGE, width=SS)

img = img.resize((W // SS, H // SS), Image.LANCZOS)
half = img.width // 2
for name, box in (("mapa_oeste.png", (0, 0, half, img.height)), ("mapa_este.png", (half, 0, img.width, img.height))):
	tile = img.crop(box).resize((1024, round(1024 * img.height / half)), Image.LANCZOS)
	tile.save(os.path.join(ROOT, "assets", name), optimize=True)
	print("assets/" + name, tile.size)
