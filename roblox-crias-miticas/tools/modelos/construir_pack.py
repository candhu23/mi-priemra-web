"""Prepara el pack de modelos 3D de Crías Míticas para importarlo en Roblox Studio de una vez.

Fuentes (todas CC0, se descargan solas):
  - Kenney Nature Kit (https://kenney.nl/assets/nature-kit): árboles, rocas, setas, cactus, flores…
  - Quaternius (OpenGameArt): Farm Animals, Animal Pack Vol.2 y Animals Pack → 17 animales para las crías.
  - Generados aquí: racimos de cristal y el huevo (cáscara + manchas).
Salida (en roblox-crias-miticas/modelos/):
  - CriasMiticas_Modelos.glb  → un modelo por alias (Roca, Pino…) con una pieza por color: «<Alias>__<material>».
                                El juego repinta cada pieza según el material y la zona (World.luau).
  - vista_modelos.png         → hoja con todos los modelos (dibujo aproximado, para enseñarlo).
  - src/ReplicatedStorage/ModelColors.luau → color de cada pieza «Alias__material» (el importador de Studio puede no
                                traer los colores: el juego los pone con esta tabla).
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

# alias en el juego → archivo de Kenney (o generado aquí: los cristales)
MODELOS = {
    # Cristales que rompen las crías (generados: prismas hexagonales con punta, en racimo)
    "Cristal1": ("gen", 3, 11), "Cristal2": ("gen", 5, 22), "CristalGrande": ("gen", 7, 33),
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


# Animales de Quaternius (OpenGameArt, CC0): alias → (zip, archivo OBJ, colores por material)
QUATERNIUS_ZIPS = {
    "farm": "https://opengameart.org/sites/default/files/Farm%20Animals%20by%20%40Quaternius.zip",
    "vol2": "https://opengameart.org/sites/default/files/Animal%20Pack%20Vol.2%20by%20%40Quaternius.zip",
    "pack": "https://opengameart.org/sites/default/files/Animals%20Pack%20by%20Quaternius.zip",
}
ANIMALES = {
    "Cow": ("farm", "Cow", {"Black": (45, 40, 40), "Pink": (240, 170, 170), "White": (245, 245, 240)}),
    "Horse": ("farm", "Horse", {"Material.003": (150, 95, 55), "Material.006": (60, 40, 30)}),
    "Llama": ("farm", "Llama", {"Brown": (140, 95, 60), "Grey": (90, 90, 95), "White": (240, 235, 225)}),
    "Pig": ("farm", "Pig", {"Material": (90, 60, 60), "Material.003": (245, 165, 175)}),
    "Pug": ("farm", "Pug", {"Beige": (225, 195, 150), "Brown": (110, 75, 50)}),
    "Sheep": ("farm", "Sheep", {"Black": (60, 55, 55), "White": (245, 245, 240)}),
    "Zebra": ("farm", "Zebra", {"Black": (40, 40, 45), "White": (245, 245, 245)}),
    "Cat": ("vol2", "Cat", {"Grey": (150, 150, 155), "Pink": (245, 170, 180), "White": (245, 245, 245)}),
    "Dog": ("vol2", "Dog", {"Dog": (200, 140, 80)}),
    "Eagle": ("vol2", "Eagle", {"Beak": (250, 200, 60), "Claws": (60, 50, 40), "Head": (245, 245, 245), "Wings": (110, 75, 45)}),
    "Piranha": ("vol2", "Piranha", {"Black": (40, 40, 45), "Brown": (150, 90, 60), "LightYellow": (250, 230, 150), "White": (245, 245, 245)}),
    "Wolf": ("vol2", "Wolf", {"Wolf": (150, 155, 165)}),
    "Chick": ("pack", "Chick", {"Material.001": (255, 220, 80), "Material.002": (250, 150, 40)}),
    "Fish": ("pack", "Fish", {"Material.001": (250, 140, 60)}),
    "RedFox": ("pack", "Red Fox", {"Material.001": (235, 120, 50), "Material.002": (245, 245, 240)}),
    "Whale": ("pack", "Whale", {"Material.001": (80, 120, 190), "Material.002": (230, 235, 245)}),
    "Bird": ("pack", "bird", {"Material.002": (90, 150, 230), "Material.006": (250, 200, 60)}),
}


# Hacia dónde mira la cabeza de cada animal en su archivo (comprobado dibujándolos desde arriba).
# Se giran todos para que miren a −Z, que es «delante» en Roblox (LookVector).
CABEZA = {
    "Cow": "+Z", "Horse": "+Z", "Llama": "+Z", "Pig": "+Z", "Pug": "+Z", "Sheep": "+Z", "Zebra": "-Z",
    "Cat": "+X", "Dog": "+X", "Eagle": "-Z", "Piranha": "+Z", "Wolf": "+X", "Chick": "+X",
    "Fish": "+Z", "RedFox": "-Z", "Whale": "+Z", "Bird": "-Z",
}
GIRO = {"-Z": 0, "+Z": math.pi, "+X": math.pi / 2, "-X": -math.pi / 2}


def descargar_quaternius() -> dict:
    """Devuelve {zip: carpeta OBJ} (descarga y descomprime la 1.ª vez)."""
    out = {}
    for clave, url in QUATERNIUS_ZIPS.items():
        dest = os.path.join(RAIZ, "tools", "out", "quaternius_" + clave)
        if not os.path.isdir(dest):
            print("Descargando", clave, "…")
            datos = urllib.request.urlopen(url, timeout=180).read()
            with zipfile.ZipFile(io.BytesIO(datos)) as z:
                z.extractall(dest)
        for raiz, _, archivos in os.walk(dest):
            if os.path.basename(raiz) == "OBJ":
                out[clave] = raiz
    return out


def animal(ruta: str, colores: dict):
    s = trimesh.load(ruta, group_material=True)
    geoms = s.geometry.items() if isinstance(s, trimesh.Scene) else [("Body", s)]
    out = []
    for gname, g in geoms:
        mat = getattr(getattr(g.visual, "material", None), "name", None) or gname
        g = g.copy()
        c = colores.get(mat, (200, 200, 200))
        g.visual = trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(name=mat, baseColorFactor=list(c) + [255]))
        out.append((mat.replace(".", ""), g))
    return out


def girar(partes, angulo):
    rot = trimesh.transformations.rotation_matrix(angulo, [0, 1, 0])
    for _, m in partes:
        m.apply_transform(rot)
    return partes


def huevo():
    """Huevo: cáscara (esfera estirada) + 7 manchas redondas pegadas. Materiales eggShell / eggSpots (el juego los pinta por rareza)."""
    cas = trimesh.creation.icosphere(subdivisions=3, radius=1.0)
    v = cas.vertices.copy()
    v[:, 1] *= 1.32
    v[:, 1] += np.where(v[:, 1] > 0, v[:, 1] * 0.0, v[:, 1] * 0.12)  # la parte de abajo algo más ancha
    cas.vertices = v
    cas.apply_translation([0, 1.32, 0])
    rng = np.random.default_rng(5)
    manchas = []
    for k in range(7):
        a = k / 7 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        y = rng.uniform(0.6, 2.0)
        r = math.sqrt(max(0.05, 1 - ((y - 1.32) / 1.32) ** 2))
        m = trimesh.creation.icosphere(subdivisions=1, radius=rng.uniform(0.18, 0.3))
        m.apply_scale([1, 1, 0.35])
        m.apply_transform(trimesh.transformations.rotation_matrix(-a + math.pi / 2, [0, 1, 0]))
        m.apply_translation([math.cos(a) * r * 1.03, y, math.sin(a) * r * 1.03])
        manchas.append(m)
    sp = trimesh.util.concatenate(manchas)
    for g, nombre, c in ((cas, "eggShell", (245, 245, 245)), (sp, "eggSpots", (150, 200, 255))):
        g.visual = trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(name=nombre, baseColorFactor=list(c) + [255]))
    return [("eggShell", cas), ("eggSpots", sp)]


# Colores de serie (estilo cartoon vivo). El juego los vuelve a pintar por zona (World.luau, MAT_COLORS)
COLORES = {
    "leafsGreen": (110, 195, 70), "leafsDark": (60, 145, 75), "grass": (115, 205, 80), "dirt": (150, 105, 70),
    "woodBark": (135, 88, 55), "woodBarkDark": (100, 66, 45), "woodInner": (225, 195, 145), "stone": (150, 155, 165),
    "_defaultMat": (240, 235, 225), "colorRed": (225, 60, 60), "colorTan": (235, 170, 100), "colorYellow": (250, 205, 60),
    "colorPurple": (150, 100, 220), "crystal": (120, 220, 255),
}


def cristal(n: int, semilla: int):
    """Racimo de n cristales: prisma de 6 caras + punta, el central más alto, los demás inclinados hacia fuera."""
    rng = np.random.default_rng(semilla)
    mallas = []
    for k in range(n):
        h = rng.uniform(2.0, 2.4) if k == 0 else rng.uniform(1.2, 1.9)
        r = 0.45 if k == 0 else rng.uniform(0.28, 0.38)
        cuerpo = trimesh.creation.cylinder(radius=r, height=h, sections=6)
        punta = trimesh.creation.cone(radius=r, height=r * 1.8, sections=6)
        punta.apply_translation([0, 0, h / 2])
        c = trimesh.util.concatenate([cuerpo, punta])
        c.apply_translation([0, 0, h / 2])  # base en z = 0
        c.apply_transform(trimesh.transformations.rotation_matrix(math.radians(-90), [1, 0, 0]))  # z → y (de pie)
        c.apply_transform(trimesh.transformations.rotation_matrix(rng.uniform(0, math.pi), [0, 1, 0]))
        if k > 0:
            ang = k / (n - 1) * 2 * math.pi + rng.uniform(-0.3, 0.3)
            eje = [math.cos(ang + math.pi / 2), 0, math.sin(ang + math.pi / 2)]
            c.apply_transform(trimesh.transformations.rotation_matrix(math.radians(rng.uniform(28, 42)), eje))
            d = rng.uniform(0.6, 0.85)
            c.apply_translation([math.cos(ang) * d, -0.05, math.sin(ang) * d])
        mallas.append(c)
    m = trimesh.util.concatenate(mallas)
    m.visual = trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(name="crystal", baseColorFactor=[120, 220, 255, 255]))
    return [("crystal", m)]


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
    obj = descargar_quaternius()
    fuentes = []
    for alias, archivo in MODELOS.items():
        fuentes.append((alias, lambda archivo=archivo: cristal(archivo[1], archivo[2]) if isinstance(archivo, tuple) else piezas(os.path.join(carpeta, archivo + ".glb"))))
    for alias, (zipk, nombre, colores) in ANIMALES.items():
        fuentes.append((alias, lambda zipk=zipk, nombre=nombre, colores=colores, alias=alias: girar(animal(os.path.join(obj[zipk], nombre + ".obj"), colores), GIRO[CABEZA[alias]])))
    fuentes.append(("Huevo", huevo))
    colores_luau = {}
    for alias, fuente in fuentes:
        partes = fuente()
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
            colores_luau[nombre] = color_de(m)
        fichas.append((alias, lista))
        x += ancho + 6
    destino = os.path.join(SALIDA, "CriasMiticas_Modelos.glb")
    escena.export(destino)
    print(f"{len(fuentes)} modelos → {destino} ({os.path.getsize(destino) // 1024} KB)")
    luau = os.path.join(RAIZ, "src", "ReplicatedStorage", "ModelColors.luau")
    with open(luau, "w", encoding="utf-8") as f:
        f.write("-- GENERADO por tools/modelos/construir_pack.py: color de cada pieza «Alias__material» del pack de modelos.\n")
        f.write("-- El importador de Studio puede no traer los colores; el juego los pone con esta tabla.\nreturn {\n")
        for k in sorted(colores_luau):
            r, g, b = colores_luau[k]
            f.write(f'\t["{k}"] = Color3.fromRGB({r}, {g}, {b}),\n')
        f.write("}\n")
    print("Colores →", luau)
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
    cols = 9
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
