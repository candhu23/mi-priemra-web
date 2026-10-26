"""Prepara el pack de modelos 3D de Crías Míticas para importarlo en Roblox Studio de una vez.

Fuente: Kenney Nature Kit (CC0, https://kenney.nl/assets/nature-kit). Se descarga solo.
Salida (en roblox-crias-miticas/modelos/):
  - CriasMiticas_Modelos.glb  → un modelo por alias (Roca, Pino…) con una pieza por color: «<Alias>__<material>».
                                El juego repinta cada pieza según el material y la zona (World.luau).
  - vista_modelos.png         → hoja con todos los modelos (dibujo aproximado, para enseñarlo).
Uso: python3 -I tools/modelos/construir_pack.py   (desde roblox-crias-miticas/; necesita trimesh: pip install trimesh)
"""
import io
import math
import os
import sys
import urllib.request
import zipfile

import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SALIDA = os.path.join(RAIZ, "modelos")
CACHE = os.path.join(RAIZ, "tools", "out", "kenney_nature")
URL = "https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip"
ESCALA = 10  # Kenney mide en metros pequeños: ×10 para que en Studio no salgan diminutos (el juego reescala igual)

# alias en el juego → archivo de Kenney
MODELOS = {
    # Rocas que rompen las crías (sustituyen a los cristales)
    "PiedraA": "stone_largeA", "PiedraB": "stone_largeC", "PiedraC": "stone_largeE",
    "PiedraAlta": "stone_tallA", "PiedraAltaB": "stone_tallB", "RocaMusgo": "rock_largeB",
    # Árboles y plantas
    "Roble": "tree_oak", "Arbol": "tree_default", "ArbolDetallado": "tree_detailed", "ArbolGordo": "tree_fat",
    "ArbolCono": "tree_cone", "Pino": "tree_pineTallA", "PinoRedondo": "tree_pineRoundA",
    "Palmera": "tree_palmTall", "PalmeraCurva": "tree_palmBend",
    "SetaRoja": "mushroom_red", "SetaAlta": "mushroom_redTall", "SetaTan": "mushroom_tanTall",
    "CactusAlto": "cactus_tall", "CactusBajo": "cactus_short",
    "Arbusto": "plant_bushLarge", "Arbusto2": "plant_bush", "Hierba": "grass_large",
    "FlorRoja": "flower_redA", "FlorAmarilla": "flower_yellowA", "FlorMorada": "flower_purpleA",
    "Tronco": "log_large", "Tocon": "stump_round",
    # Rocas de decoración y acantilados
    "RocaDeco": "rock_largeA", "RocaAlta": "rock_tallA",
}


# Colores de serie (estilo cartoon vivo). El juego los vuelve a pintar por zona (World.luau, MAT_COLORS)
COLORES = {
    "leafsGreen": (110, 195, 70), "leafsDark": (60, 145, 75), "grass": (115, 205, 80), "dirt": (150, 105, 70),
    "woodBark": (135, 88, 55), "woodBarkDark": (100, 66, 45), "woodInner": (225, 195, 145), "stone": (150, 155, 165),
    "_defaultMat": (240, 235, 225), "colorRed": (225, 60, 60), "colorTan": (235, 170, 100), "colorYellow": (250, 205, 60),
    "colorPurple": (150, 100, 220),
}


def descargar() -> str:
    carpeta = os.path.join(CACHE, "Models", "GLTF format")
    if os.path.isdir(carpeta):
        return carpeta
    os.makedirs(CACHE, exist_ok=True)
    print("Descargando Kenney Nature Kit…")
    datos = urllib.request.urlopen(URL, timeout=120).read()
    with zipfile.ZipFile(io.BytesIO(datos)) as z:
        for n in z.namelist():
            if n.startswith("Models/GLTF format/") or n == "License.txt":
                z.extract(n, CACHE)
    return carpeta


def piezas(ruta: str):
    """Devuelve [(material, malla en coordenadas del modelo)] juntando las mallas del mismo material."""
    escena = trimesh.load(ruta)
    por_mat: dict[str, list] = {}
    for nodo in escena.graph.nodes_geometry:
        tf, nombre_geo = escena.graph[nodo]
        g = escena.geometry[nombre_geo].copy()
        g.apply_transform(tf)
        mat = getattr(getattr(g.visual, "material", None), "name", None) or "_defaultMat"
        por_mat.setdefault(mat, []).append(g)
    out = []
    for mat, lista in por_mat.items():
        m = trimesh.util.concatenate(lista) if len(lista) > 1 else lista[0]
        out.append((mat, m))
    return out


def color_de(malla) -> tuple:
    try:
        c = malla.visual.material.baseColorFactor
        return tuple(int(v) for v in c[:3])
    except Exception:
        try:
            c = malla.visual.material.main_color
            return tuple(int(v) for v in c[:3])
        except Exception:
            return (200, 200, 200)


def main():
    carpeta = descargar()
    os.makedirs(SALIDA, exist_ok=True)
    escena = trimesh.Scene()
    fichas = []
    x = 0.0
    for alias, archivo in MODELOS.items():
        partes = piezas(os.path.join(carpeta, archivo + ".glb"))
        todas = trimesh.util.concatenate([m for _, m in partes])
        mn, mx = todas.bounds
        centro = np.array([(mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2])  # base en el suelo, centrado
        ancho = (mx[0] - mn[0]) * ESCALA
        # nodo vacío del modelo (en Studio sale como un Model con este nombre)
        escena.graph.update(frame_to=alias, frame_from=escena.graph.base_frame, matrix=trimesh.transformations.translation_matrix([x + ancho / 2, 0, 0]))
        lista = []
        for mat, m in partes:
            m = m.copy()
            if mat in COLORES:
                try:
                    m.visual.material.baseColorFactor = list(COLORES[mat]) + [255]
                except Exception:
                    pass
            m.apply_translation(-centro)
            m.apply_scale(ESCALA)
            nombre = f"{alias}__{mat}"
            escena.add_geometry(m, node_name=nombre, geom_name=nombre, parent_node_name=alias)
            lista.append((mat, m, color_de(m)))
        fichas.append((alias, lista))
        x += ancho + 6
    destino = os.path.join(SALIDA, "CriasMiticas_Modelos.glb")
    escena.export(destino)
    print(f"{len(MODELOS)} modelos → {destino} ({os.path.getsize(destino) // 1024} KB)")
    hoja(fichas, os.path.join(SALIDA, "vista_modelos.png"))


# --- Dibujo aproximado (sin OpenGL): triángulos proyectados, de atrás adelante, con luz plana ---
def dibujar(lista, tam=220):
    img = Image.new("RGB", (tam, tam), (235, 242, 250))
    d = ImageDraw.Draw(img)
    rot = trimesh.transformations.rotation_matrix(math.radians(35), [0, 1, 0])
    tri_all = []
    for _, m, col in lista:
        v = trimesh.transform_points(m.vertices, rot)
        for f, n in zip(m.faces, m.face_normals):
            nr = rot[:3, :3] @ n
            tri_all.append((v[f], col, nr))
    if not tri_all:
        return img
    pts = np.concatenate([t[0] for t in tri_all])
    # proyección isométrica suave: x, y - z*0.35
    def proy(p):
        return np.stack([p[:, 0] + p[:, 2] * 0.35, -(p[:, 1] - p[:, 2] * 0.25)], axis=1)
    pp = proy(pts)
    mn, mx = pp.min(0), pp.max(0)
    esc = (tam - 30) / max(mx - mn)
    luz = np.array([0.4, 0.8, 0.5])
    luz /= np.linalg.norm(luz)
    tri_all.sort(key=lambda t: t[0][:, 2].mean())  # de atrás (z bajo) a delante
    for tri, col, n in tri_all:
        p2 = (proy(tri) - mn) * esc + 15
        k = 0.55 + 0.45 * max(0, float(np.dot(n, luz)))
        c = tuple(min(255, int(ch * k)) for ch in col)
        d.polygon([tuple(q) for q in p2], fill=c)
    return img


def hoja(fichas, destino):
    cols = 8
    filas = math.ceil(len(fichas) / cols)
    hoja = Image.new("RGB", (cols * 230, filas * 250), (250, 250, 252))
    d = ImageDraw.Draw(hoja)
    for i, (alias, lista) in enumerate(fichas):
        img = dibujar(lista)
        x, y = (i % cols) * 230 + 5, (i // cols) * 250 + 5
        hoja.paste(img, (x, y))
        d.text((x + 6, y + 224), alias, fill=(30, 40, 60))
    hoja.save(destino)
    print("Vista →", destino)


if __name__ == "__main__":
    sys.exit(main())
