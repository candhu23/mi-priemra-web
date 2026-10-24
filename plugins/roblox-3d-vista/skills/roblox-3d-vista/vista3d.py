#!/usr/bin/env python3
"""vista3d.py — dibuja en PNG lo que hay construido en un juego de Roblox, sin abrir Studio,
y revisa problemas típicos (piezas que parpadean, piezas sueltas que se caerán, demasiadas piezas…).

Entradas que acepta:
  - el JSON de volcar.luau (lo que construye un script, ejecutado en Lune)
  - un archivo .rbxlx / .rbxmx (XML; con Rojo: `rojo build -o lugar.rbxlx`)

Uso:
  python3 vista3d.py entrada.(json|rbxlx|rbxmx) salida.png [--vista iso|frente|lado|arriba|todas]
                     [--ancho 1600] [--alto 1000] [--informe informe.md] [--filtro Nombre]

  --vista todas  hace una hoja 2×2 (iso, frente, lado, arriba). Por defecto: iso.
  --filtro       solo dibuja piezas cuya ruta contiene ese texto (p. ej. un modelo concreto).

Necesita numpy y Pillow (pip install numpy pillow).
Es una aproximación: sin texturas, sin sombras proyectadas, MeshPart y Union se dibujan como su caja,
el Terrain no sale. Sirve para ver forma, proporciones, colores y colocación.
"""
import argparse
import json
import math
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# --------------------------------------------------------------------------------------------
# Lectura
# --------------------------------------------------------------------------------------------
MATERIALES = {  # valor del Enum.Material → nombre (los más usados)
    256: "Plastic", 272: "SmoothPlastic", 288: "Neon", 512: "Wood", 528: "WoodPlanks", 784: "Marble",
    788: "Basalt", 800: "Slate", 804: "CrackedLava", 816: "Concrete", 820: "Limestone", 832: "Granite",
    836: "Pavement", 848: "Brick", 864: "Pebble", 880: "Cobblestone", 896: "Rock", 912: "Sandstone",
    1040: "CorrodedMetal", 1056: "DiamondPlate", 1072: "Foil", 1088: "Metal", 1280: "Grass",
    1284: "LeafyGrass", 1296: "Sand", 1312: "Fabric", 1328: "Snow", 1344: "Mud", 1360: "Ground",
    1376: "Asphalt", 1392: "Salt", 1536: "Ice", 1552: "Glacier", 1568: "Glass", 1584: "ForceField",
}
FORMAS = {0: "Ball", 1: "Block", 2: "Cylinder", 3: "Wedge", 4: "CornerWedge"}
CLASES_PIEZA = {"Part", "WedgePart", "CornerWedgePart", "MeshPart", "UnionOperation", "SpawnLocation",
                "TrussPart", "Seat", "VehicleSeat", "IntersectOperation", "NegateOperation", "PartOperation"}


def leer_json(ruta):
    with open(ruta, encoding="utf-8") as f:
        datos = json.load(f)
    return datos.get("piezas") or datos.get("parts") or []


def _num(el, nombre, defecto=0.0):
    for hijo in el:
        if hijo.get("name") == nombre:
            try:
                return float(hijo.text)
            except (TypeError, ValueError):
                return defecto
    return defecto


def _hijo(el, nombre):
    for hijo in el:
        if hijo.get("name") == nombre:
            return hijo
    return None


def leer_xml(ruta):
    arbol = ET.parse(ruta)
    piezas = []

    def visitar(item, camino):
        clase = item.get("class")
        props = item.find("Properties")
        nombre = clase
        if props is not None:
            n = _hijo(props, "Name")
            if n is not None and n.text:
                nombre = n.text
        ruta_item = f"{camino}.{nombre}" if camino else nombre
        if clase in CLASES_PIEZA and props is not None:
            # Las propiedades con su valor por defecto no se guardan en el archivo
            cf = _hijo(props, "CFrame")
            tam = _hijo(props, "size")
            if tam is None:
                tam = _hijo(props, "Size")
            v = {"X": 0, "Y": 0, "Z": 0, "R00": 1, "R01": 0, "R02": 0, "R10": 0, "R11": 1, "R12": 0, "R20": 0, "R21": 0, "R22": 1}
            if cf is not None:
                v.update({c.tag: float(c.text) for c in cf})
            s = {"X": 4.0, "Y": 1.0, "Z": 2.0}
            if tam is not None:
                s.update({c.tag: float(c.text) for c in tam})
            if True:
                color = (0.64, 0.64, 0.64)
                c3 = _hijo(props, "Color3uint8")
                if c3 is not None and c3.text:
                    n = int(c3.text) & 0xFFFFFF
                    color = (((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255)
                forma = "Block"
                if clase == "Part":
                    tok = _hijo(props, "shape")
                    if tok is not None and tok.text is not None:
                        forma = FORMAS.get(int(tok.text), "Block")
                elif clase == "WedgePart":
                    forma = "Wedge"
                elif clase == "CornerWedgePart":
                    forma = "CornerWedge"
                mat = _hijo(props, "Material")
                material = MATERIALES.get(int(mat.text), "Plastic") if mat is not None and mat.text else "Plastic"
                anclada = _hijo(props, "Anchored")
                piezas.append({
                    "n": nombre, "ruta": ruta_item, "clase": clase,
                    "p": [v["X"], v["Y"], v["Z"]],
                    "x": [v["R00"], v["R10"], v["R20"]],
                    "y": [v["R01"], v["R11"], v["R21"]],
                    "z": [v["R02"], v["R12"], v["R22"]],
                    "s": [s["X"], s["Y"], s["Z"]],
                    "c": list(color), "t": _num(props, "Transparency"), "forma": forma, "m": material,
                    "anclada": anclada is not None and anclada.text == "true",
                })
        for hijo in item.findall("Item"):
            visitar(hijo, ruta_item)

    for item in arbol.getroot().findall("Item"):
        visitar(item, "")
    return piezas


# --------------------------------------------------------------------------------------------
# Geometría: cada pieza → triángulos en coordenadas del mundo
# --------------------------------------------------------------------------------------------
def geometria(p):
    """Devuelve (vértices Nx3 locales en unidades de media-talla, lista de triángulos)."""
    forma = p.get("forma") or p.get("shape") or "Block"
    if forma == "Block" or forma not in ("Wedge", "CornerWedge", "Cylinder", "Ball"):
        v = np.array([[x, y, z] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float)
        caras = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        tris = []
        for a, b, c, d in caras:
            tris += [(a, b, c), (a, c, d)]
        return v, tris
    if forma in ("Wedge", "CornerWedge"):
        # Cuña de Roblox: alta en +Z, la pendiente baja hacia -Z
        v = np.array([[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1], [-1, 1, 1], [1, 1, 1]], float)
        tris = [(0, 1, 2), (0, 2, 3), (3, 2, 5), (3, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5), (0, 5, 1)]
        return v, tris
    if forma == "Cylinder":
        n = 20
        v = []
        for x in (-1, 1):
            for i in range(n):
                a = 2 * math.pi * i / n
                v.append([x, math.cos(a), math.sin(a)])
        v.append([-1, 0, 0])
        v.append([1, 0, 0])
        v = np.array(v, float)
        tris = []
        for i in range(n):
            j = (i + 1) % n
            tris += [(i, j, n + j), (i, n + j, n + i)]
            tris.append((2 * n, j, i))
            tris.append((2 * n + 1, n + i, n + j))
        return v, tris
    # Ball (o elipsoide)
    filas, cols = 10, 16
    v = []
    for i in range(filas + 1):
        th = math.pi * i / filas
        for j in range(cols):
            ph = 2 * math.pi * j / cols
            v.append([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)])
    v = np.array(v, float)
    tris = []
    for i in range(filas):
        for j in range(cols):
            a = i * cols + j
            b = i * cols + (j + 1) % cols
            c = (i + 1) * cols + (j + 1) % cols
            d = (i + 1) * cols + j
            tris += [(a, b, c), (a, c, d)]
    return v, tris


def al_mundo(p, v):
    centro = np.array(p["p"], float)
    ejes = np.array([p["x"], p["y"], p["z"]], float)  # filas: ejes X, Y, Z del CFrame
    media = np.array(p["s"], float) / 2
    return centro + (v * media) @ ejes


# --------------------------------------------------------------------------------------------
# Cámara y dibujo (z-buffer con numpy)
# --------------------------------------------------------------------------------------------
VISTAS = {  # (giro, inclinación) de la cámara. Giro 0 = mirando la cara delantera (-Z) del modelo
    "iso": (math.radians(35), math.radians(30)),
    "frente": (0.0, math.radians(8)),
    "lado": (math.radians(90), math.radians(8)),
    "arriba": (0.0, math.radians(89.9)),
}
SOL = np.array([0.45, 0.8, -0.35])
SOL = SOL / np.linalg.norm(SOL)


def camara(nombre):
    giro, incl = VISTAS[nombre]
    # Dónde está la cámara respecto al modelo (por delante = -Z, como la cara Front de Roblox)
    hacia_camara = np.array([math.sin(giro) * math.cos(incl), math.sin(incl), -math.cos(giro) * math.cos(incl)])
    adelante = -hacia_camara
    ref = np.array([0.0, 1.0, 0.0]) if incl < math.radians(89) else np.array([0.0, 0.0, 1.0])
    derecha = np.cross(adelante, ref)
    derecha /= np.linalg.norm(derecha)
    arriba = np.cross(derecha, adelante)
    return derecha, arriba, adelante


def color_cara(c, normal, material, adelante):
    c = np.array(c, float)
    if material == "Neon":
        return np.clip(c * 1.15 + 0.08, 0, 1)
    luz = 0.55 + 0.45 * max(0.0, float(normal @ SOL))
    luz += 0.12 * max(0.0, float(normal @ np.array([0, 1, 0])))  # cielo
    if material in ("Glass", "ForceField", "Ice"):
        luz += 0.1
    return np.clip(c * luz, 0, 1)


def dibujar(piezas, nombre_vista, ancho, alto, fondo=(0.80, 0.90, 1.0)):
    ss = 2  # supermuestreo para suavizar bordes
    W, H = ancho * ss, alto * ss
    derecha, arriba, adelante = camara(nombre_vista)
    tris_opacos, tris_transp = [], []
    todos = []
    for idx, p in enumerate(piezas):
        if p.get("t", 0) >= 0.98:
            continue
        v, tris = geometria(p)
        mundo = al_mundo(p, v)
        alfa = 1 - float(p.get("t", 0))
        if p.get("m") == "Glass":
            alfa = min(alfa, 0.55)
        if p.get("m") == "ForceField":
            alfa = min(alfa, 0.35)
        for a, b, c in tris:
            tri = mundo[[a, b, c]]
            n = np.cross(tri[1] - tri[0], tri[2] - tri[0])
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n /= ln
            # La normal debe salir de la pieza
            if n @ (tri.mean(0) - np.array(p["p"])) < 0:
                n = -n
            col = color_cara(p["c"], n, p.get("m"), adelante)
            entrada = (tri, n, col, alfa, idx)
            (tris_opacos if alfa > 0.97 else tris_transp).append(entrada)
            todos.append(tri)
    if not todos:
        img = Image.new("RGB", (ancho, alto), tuple(int(x * 255) for x in fondo))
        return img
    puntos = np.concatenate(todos)
    px = puntos @ derecha
    py = puntos @ arriba
    margen = 0.06
    xmin, xmax, ymin, ymax = px.min(), px.max(), py.min(), py.max()
    escala = min(W * (1 - 2 * margen) / max(xmax - xmin, 1e-6), H * (1 - 2 * margen) / max(ymax - ymin, 1e-6))
    cx, cy = (xmin + xmax) / 2, (ymin + ymax) / 2

    def proyectar(tri):
        sx = (tri @ derecha - cx) * escala + W / 2
        sy = H / 2 - (tri @ arriba - cy) * escala
        sz = tri @ adelante
        return sx, sy, sz

    imagen = np.zeros((H, W, 3), float)
    # Cielo con degradado
    t = np.linspace(0, 1, H)[:, None]
    imagen[:] = (np.array(fondo) * (1 - t) + np.array([0.98, 0.98, 1.0]) * t)[:, None, :]
    zbuf = np.full((H, W), np.inf)
    idbuf = np.full((H, W), -1, int)

    def rasterizar(tri, col, alfa, idx, escribir_z):
        sx, sy, sz = proyectar(tri)
        x0, x1 = max(int(math.floor(sx.min())), 0), min(int(math.ceil(sx.max())), W - 1)
        y0, y1 = max(int(math.floor(sy.min())), 0), min(int(math.ceil(sy.max())), H - 1)
        if x0 > x1 or y0 > y1:
            return
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, bx, cx_), (ay, by, cy_) = sx, sy
        den = (by - cy_) * (ax - cx_) + (cx_ - bx) * (ay - cy_)
        if abs(den) < 1e-9:
            return
        w0 = ((by - cy_) * (xs - cx_) + (cx_ - bx) * (ys - cy_)) / den
        w1 = ((cy_ - ay) * (xs - cx_) + (ax - cx_) * (ys - cy_)) / den
        w2 = 1 - w0 - w1
        dentro = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not dentro.any():
            return
        z = w0 * sz[0] + w1 * sz[1] + w2 * sz[2]
        zona = zbuf[y0:y1 + 1, x0:x1 + 1]
        visible = dentro & (z < zona - 1e-3)
        if not visible.any():
            return
        reg = imagen[y0:y1 + 1, x0:x1 + 1]
        if alfa >= 0.97:
            reg[visible] = col
        else:
            reg[visible] = reg[visible] * (1 - alfa) + col * alfa
        if escribir_z:
            zona[visible] = z[visible]
            idbuf[y0:y1 + 1, x0:x1 + 1][visible] = idx

    for tri, n, col, alfa, idx in tris_opacos:
        rasterizar(tri, col, alfa, idx, True)
    # Transparentes de atrás a delante
    tris_transp.sort(key=lambda e: -float(e[0].mean(0) @ adelante))
    for tri, n, col, alfa, idx in tris_transp:
        rasterizar(tri, col, alfa, idx, False)

    # Contorno entre piezas distintas (estilo dibujo: ayuda a leer la forma)
    borde = np.zeros((H, W), bool)
    borde[:, 1:] |= idbuf[:, 1:] != idbuf[:, :-1]
    borde[1:, :] |= idbuf[1:, :] != idbuf[:-1, :]
    imagen[borde] *= 0.55
    img = Image.fromarray((np.clip(imagen, 0, 1) * 255).astype(np.uint8))
    return img.resize((ancho, alto), Image.LANCZOS)


# --------------------------------------------------------------------------------------------
# Revisión
# --------------------------------------------------------------------------------------------
def revisar(piezas):
    avisos = []
    n = len(piezas)
    sueltas = [p for p in piezas if p.get("anclada") is False]
    if sueltas:
        nombres = ", ".join(sorted({p["n"] for p in sueltas})[:8])
        avisos.append(f"⚠️ {len(sueltas)} piezas SIN anclar (se caerán o se moverán con la física): {nombres}")
    if n > 5000:
        avisos.append(f"⚠️ {n} piezas: mucho para móvil. Junta piezas, usa MeshParts o StreamingEnabled.")
    elif n > 2000:
        avisos.append(f"ℹ️ {n} piezas: vigila el rendimiento en móviles antiguos.")
    luces = sum(1 for p in piezas if p.get("luz"))
    if luces > 40:
        avisos.append(f"⚠️ {luces} luces: demasiadas cuestan mucho en móvil (mejor < 40 visibles a la vez).")
    neon = sum(1 for p in piezas if p.get("m") == "Neon")
    if n and neon / n > 0.25:
        avisos.append(f"ℹ️ {neon} piezas de Neon ({neon * 100 // n} %): con tanto brillo se pierde el efecto; resérvalo para lo importante.")
    pequenas_colision = [p for p in piezas if p.get("colision") and np.linalg.norm(p["s"]) < 2]
    if len(pequenas_colision) > 50:
        avisos.append(f"ℹ️ {len(pequenas_colision)} piezas pequeñas con colisión: ponles CanCollide=false si son decoración (Constructor.optimizar lo hace).")

    # Parpadeo (z-fighting): caras coplanarias que se solapan entre bloques alineados con los ejes
    planos = defaultdict(list)
    for i, p in enumerate(piezas):
        if (p.get("forma") or "Block") != "Block" or p.get("t", 0) >= 0.98:
            continue
        ejes = np.array([p["x"], p["y"], p["z"]], float)
        if not np.allclose(np.abs(ejes), np.eye(3), atol=1e-3) and not np.allclose(np.abs(ejes).sum(0), 1, atol=1e-3):
            continue
        c = np.array(p["p"], float)
        media = np.abs(ejes.T @ (np.array(p["s"], float) / 2))  # medias tallas en ejes del mundo
        for eje in range(3):
            for signo in (-1, 1):
                if eje == 1 and signo == -1:
                    continue  # caras de abajo: casi nunca se ven
                pos = round(c[eje] + signo * media[eje], 2)
                otros = [k for k in range(3) if k != eje]
                rect = (c[otros[0]] - media[otros[0]], c[otros[0]] + media[otros[0]],
                        c[otros[1]] - media[otros[1]], c[otros[1]] + media[otros[1]])
                planos[(eje, signo, pos)].append((i, rect))
    pares = set()
    for (eje, signo, pos), lista in planos.items():
        if len(lista) < 2 or len(lista) > 400:
            continue
        for a in range(len(lista)):
            for b in range(a + 1, len(lista)):
                i, r1 = lista[a]
                j, r2 = lista[b]
                solape = (min(r1[1], r2[1]) - max(r1[0], r2[0])) * (min(r1[3], r2[3]) - max(r1[2], r2[2]))
                if min(r1[1], r2[1]) - max(r1[0], r2[0]) > 0.05 and min(r1[3], r2[3]) - max(r1[2], r2[2]) > 0.05 and solape > 0.25:
                    if piezas[i]["c"] != piezas[j]["c"] or piezas[i].get("m") != piezas[j].get("m"):
                        pares.add((min(i, j), max(i, j)))
    if pares:
        ejemplos = "; ".join(f"«{piezas[i]['n']}» con «{piezas[j]['n']}»" for i, j in list(pares)[:6])
        avisos.append(f"⚠️ {len(pares)} parejas de piezas con caras en el mismo plano (PARPADEAN en Roblox): {ejemplos}. "
                      "Separa una 0,01–0,05 studs o métela dentro de la otra.")
    return avisos


def resumen(piezas):
    if not piezas:
        return ["(no hay piezas)"]
    pos = np.array([p["p"] for p in piezas], float)
    tam = np.array([p["s"] for p in piezas], float)
    lo = (pos - tam / 2).min(0)
    hi = (pos + tam / 2).max(0)
    mats = defaultdict(int)
    for p in piezas:
        mats[p.get("m", "?")] += 1
    top = ", ".join(f"{m} {k}" for m, k in sorted(mats.items(), key=lambda x: -x[1])[:6])
    return [
        f"Piezas: {len(piezas)}",
        f"Tamaño total (studs): {hi[0] - lo[0]:.0f} × {hi[1] - lo[1]:.0f} × {hi[2] - lo[2]:.0f} (ancho × alto × fondo)",
        f"Desde {lo.round(1).tolist()} hasta {hi.round(1).tolist()}",
        f"Materiales: {top}",
    ]


# --------------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("entrada")
    ap.add_argument("salida")
    ap.add_argument("--vista", default="iso", choices=list(VISTAS) + ["todas"])
    ap.add_argument("--ancho", type=int, default=1600)
    ap.add_argument("--alto", type=int, default=1000)
    ap.add_argument("--informe")
    ap.add_argument("--filtro")
    a = ap.parse_args()

    if a.entrada.endswith((".rbxlx", ".rbxmx", ".xml")):
        piezas = leer_xml(a.entrada)
    else:
        piezas = leer_json(a.entrada)
    if a.filtro:
        piezas = [p for p in piezas if a.filtro in (p.get("ruta") or p.get("n", ""))]
    # Fuera la placa base gigante y el suelo infinito (taparían todo)
    piezas = [p for p in piezas if max(p["s"]) < 2000]

    if a.vista == "todas":
        w, h = a.ancho // 2, a.alto // 2
        hoja = Image.new("RGB", (w * 2, h * 2), (255, 255, 255))
        d = ImageDraw.Draw(hoja)
        for k, v in enumerate(["iso", "frente", "lado", "arriba"]):
            img = dibujar(piezas, v, w, h)
            hoja.paste(img, ((k % 2) * w, (k // 2) * h))
            d.rectangle([(k % 2) * w + 8, (k // 2) * h + 8, (k % 2) * w + 120, (k // 2) * h + 36], fill=(255, 255, 255))
            d.text(((k % 2) * w + 16, (k // 2) * h + 14), v.upper(), fill=(30, 30, 40), font=ImageFont.load_default())
        hoja.save(a.salida)
    else:
        dibujar(piezas, a.vista, a.ancho, a.alto).save(a.salida)

    lineas = resumen(piezas)
    avisos = revisar(piezas)
    print("\n".join(lineas))
    print("\n".join(avisos) if avisos else "✅ Sin problemas detectados (parpadeo, piezas sueltas, presupuesto).")
    print(f"Imagen: {a.salida}")
    if a.informe:
        with open(a.informe, "w", encoding="utf-8") as f:
            f.write("# Revisión 3D\n\n" + "\n".join(f"- {l}" for l in lineas) + "\n\n## Avisos\n\n")
            f.write("\n".join(f"- {x}" for x in avisos) if avisos else "- ✅ Sin problemas detectados\n")
            f.write(f"\n\n![vista]({a.salida})\n")


if __name__ == "__main__":
    main()
