#!/usr/bin/env python3
"""mallas.py — genera modelos 3D low-poly con estilo «cartoon» listos para importar en Roblox Studio
(huevos, monedas, gemas, cristales, rocas, árboles, setas, cofres, mascotas, estrellas, nubes…).

Para cada modelo escribe:
  <nombre>.glb   glTF binario: una malla por COLOR (Roblox crea un MeshPart por parte, con su color)
  <nombre>.obj + .mtl   lo mismo en OBJ (alternativa si el .glb da problemas)
  <nombre>.png   vista previa para comprobarlo sin abrir Studio

Uso:
  python3 mallas.py lista                              → modelos disponibles
  python3 mallas.py huevo salida/ [--tamano 4] [--semilla 3] [--color cuerpo=#ff88cc --color manchas=#ffffff]
  python3 mallas.py todos salida/                      → todos + catalogo.png

--tamano  alto final en studs (por defecto 4). En el importador de Studio deja la escala en 1.
--semilla cambia las partes aleatorias (rocas, cristales, manchas).
--color   cambia el color de una parte (los nombres de parte salen en la lista y en el .png).

Necesita numpy y Pillow. Importar en Studio: Home/Avatar → Import 3D → elige el .glb → Import.
"""
import argparse
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------------------------------------
# Primitivas (cada una devuelve (vertices Nx3, triangulos Mx3))
# ---------------------------------------------------------------------------------------------


def torno(perfil, lados=12, giro=0.0):
    """Revoluciona un perfil [(radio, y), ...] (de abajo arriba) alrededor del eje Y."""
    v, t = [], []
    anillos = []
    for r, y in perfil:
        if r <= 1e-6:
            anillos.append([len(v)])
            v.append([0, y, 0])
        else:
            idx = []
            for i in range(lados):
                a = 2 * math.pi * i / lados + giro
                idx.append(len(v))
                v.append([r * math.cos(a), y, r * math.sin(a)])
            anillos.append(idx)
    for a, b in zip(anillos, anillos[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(lados):
                t.append([a[0], b[(i + 1) % lados], b[i]])
        elif len(b) == 1:
            for i in range(lados):
                t.append([a[i], a[(i + 1) % lados], b[0]])
        else:
            for i in range(lados):
                j = (i + 1) % lados
                t += [[a[i], b[j], b[i]], [a[i], a[j], b[j]]]
    # Tapas planas si el perfil empieza/acaba con radio > 0
    if len(anillos[0]) > 1:
        c = len(v)
        v.append([0, perfil[0][1], 0])
        for i in range(lados):
            t.append([c, anillos[0][i], anillos[0][(i + 1) % lados]])
    if len(anillos[-1]) > 1:
        c = len(v)
        v.append([0, perfil[-1][1], 0])
        for i in range(lados):
            t.append([c, anillos[-1][(i + 1) % lados], anillos[-1][i]])
    return np.array(v, float), np.array(t, int)


def icosfera(sub=1):
    f = (1 + 5 ** 0.5) / 2
    v = [[-1, f, 0], [1, f, 0], [-1, -f, 0], [1, -f, 0], [0, -1, f], [0, 1, f], [0, -1, -f], [0, 1, -f],
         [f, 0, -1], [f, 0, 1], [-f, 0, -1], [-f, 0, 1]]
    t = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
         [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
         [8, 6, 7], [9, 8, 1]]
    v = [list(np.array(p) / np.linalg.norm(p)) for p in v]
    for _ in range(sub):
        cache = {}
        nt = []

        def medio(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                m = (np.array(v[a]) + np.array(v[b])) / 2
                v.append(list(m / np.linalg.norm(m)))
                cache[k] = len(v) - 1
            return cache[k]

        for a, b, c in t:
            ab, bc, ca = medio(a, b), medio(b, c), medio(c, a)
            nt += [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]
        t = nt
    return np.array(v, float), np.array(t, int)


def caja(sx=1, sy=1, sz=1):
    v = np.array([[x, y, z] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float) * [sx / 2, sy / 2, sz / 2]
    caras = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    t = []
    for a, b, c, d in caras:
        t += [[a, b, c], [a, c, d]]
    return v, np.array(t, int)


def prisma(poligono, alto):
    """Extruye un polígono 2D [(x,z)...] (antihorario visto desde arriba) entre y=0 e y=alto."""
    n = len(poligono)
    v = [[x, 0, z] for x, z in poligono] + [[x, alto, z] for x, z in poligono]
    v += [[0, 0, 0], [0, alto, 0]]
    t = []
    for i in range(n):
        j = (i + 1) % n
        t += [[i, j, n + j], [i, n + j, n + i]]
        t.append([2 * n, j, i])
        t.append([2 * n + 1, n + i, n + j])
    return np.array(v, float), np.array(t, int)


def mover(vt, escala=(1, 1, 1), rot=(0, 0, 0), pos=(0, 0, 0)):
    v, t = vt
    v = v * np.array(escala, float)
    rx, ry, rz = [math.radians(a) for a in rot]
    Rx = np.array([[1, 0, 0], [0, math.cos(rx), -math.sin(rx)], [0, math.sin(rx), math.cos(rx)]])
    Ry = np.array([[math.cos(ry), 0, math.sin(ry)], [0, 1, 0], [-math.sin(ry), 0, math.cos(ry)]])
    Rz = np.array([[math.cos(rz), -math.sin(rz), 0], [math.sin(rz), math.cos(rz), 0], [0, 0, 1]])
    v = v @ (Rz @ Ry @ Rx).T
    return v + np.array(pos, float), t


def juntar(*partes):
    vs, ts, base = [], [], 0
    for v, t in partes:
        vs.append(v)
        ts.append(t + base)
        base += len(v)
    return np.concatenate(vs), np.concatenate(ts)


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


# ---------------------------------------------------------------------------------------------
# Modelos: cada uno devuelve {parte: ((v, t), "#color", metalico)}
# ---------------------------------------------------------------------------------------------
def m_huevo(rng):
    R, H, n = 0.62, 1.6, 14
    perfil = []
    for k in range(n + 1):
        t = math.pi * k / n
        y = H * (1 - math.cos(t)) / 2
        r = R * math.sin(t) * (1.08 - 0.3 * (y / H))  # más ancho abajo, más estrecho arriba
        perfil.append((r if 0 < k < n else 0, y))
    cuerpo = torno(perfil, 16)
    ys, rs = [p[1] for p in perfil], [p[0] for p in perfil]
    manchas = []
    for _ in range(8):
        y = rng.uniform(0.35, 1.25)
        a = rng.uniform(0, 2 * math.pi)
        r = float(np.interp(y, ys, rs))
        sz = rng.uniform(0.11, 0.17)
        # Esfera aplastada en X (el eje que luego apunta hacia fuera del huevo)
        manchas.append(mover(icosfera(1), (sz * 0.4, sz, sz), (0, -math.degrees(a), 0), (r * math.cos(a), y, r * math.sin(a))))
    return {"cuerpo": (cuerpo, "#ffb6d9", 0), "manchas": (juntar(*manchas), "#ffffff", 0)}


def m_moneda(rng):
    canto = torno([(0.85, -0.12), (1, -0.08), (1, 0.08), (0.85, 0.12)], 16)
    caras = torno([(0.85, -0.1), (0.85, 0.1)], 16)
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 0.55 if i % 2 == 0 else 0.24
        pts.append((r * math.cos(a), r * math.sin(a)))
    estrella = juntar(mover(prisma(pts, 0.05), pos=(0, 0.1, 0)), mover(prisma(pts, 0.05), pos=(0, -0.15, 0)))
    m = {"canto": (canto, "#e8a417", 0.5), "caras": (caras, "#ffd447", 0.5), "simbolo": (estrella, "#fff3a8", 0.5)}
    # De pie (como se ven en los simuladores)
    return {k: (mover(v, rot=(90, 0, 0), pos=(0, 1, 0)), c, mt) for k, (v, c, mt) in m.items()}


def m_gema(rng):
    gema = torno([(0, 0), (1, 0.9), (0.62, 1.35), (0, 1.35)], 8, giro=math.pi / 8)
    return {"gema": (gema, "#3fd0ff", 0.2)}


def m_cristales(rng):
    partes = []
    for i in range(5):
        alto = rng.uniform(1.2, 2.4) if i else 2.8
        r = rng.uniform(0.25, 0.4) if i else 0.5
        p = torno([(r, 0), (r, alto * 0.75), (0, alto)], 6)
        ang = rng.uniform(0, 360)
        incl = 0 if i == 0 else rng.uniform(18, 38)
        d = 0 if i == 0 else rng.uniform(0.35, 0.6)
        partes.append(mover(p, rot=(incl, ang, 0), pos=(d * math.cos(math.radians(ang)), 0, d * math.sin(math.radians(ang)))))
    base = mover(icosfera(1), (0.9, 0.35, 0.9))
    return {"cristales": (juntar(*partes), "#b07cff", 0.1), "base": (base, "#7d7f8c", 0)}


def m_roca(rng):
    v, t = icosfera(1)
    v = v * (1 + np.array([rng.uniform(-0.18, 0.18) for _ in range(len(v))]))[:, None]
    v = v * [1.2, 0.75, 1]
    v[:, 1] = np.maximum(v[:, 1], -0.25)
    v[:, 1] += 0.25
    return {"roca": ((v, t), "#8d919c", 0)}


def m_arbol(rng):
    tronco = torno([(0.22, 0), (0.18, 1.3), (0, 1.35)], 7)
    copas = [mover(icosfera(1), (s, s * 0.9, s), (0, rng.uniform(0, 90), 0), p) for s, p in
             ((0.95, (0, 2.0, 0)), (0.7, (0.55, 1.75, 0.2)), (0.65, (-0.5, 1.8, -0.25)), (0.6, (0.05, 2.65, 0.05)))]
    return {"tronco": (tronco, "#8a5a35", 0), "copa": (juntar(*copas), "#5cbf4a", 0)}


def m_pino(rng):
    tronco = torno([(0.2, 0), (0.16, 0.8), (0, 0.85)], 6)
    capas = [mover(torno([(r, 0), (0, h)], 7, giro=rng.uniform(0, 1)), pos=(0, y, 0)) for r, h, y in
             ((1.0, 1.3, 0.5), (0.78, 1.1, 1.15), (0.55, 0.95, 1.75))]
    return {"tronco": (tronco, "#7a4a2a", 0), "hojas": (juntar(*capas), "#2f8f5a", 0)}


def m_seta(rng):
    pie = torno([(0.28, 0), (0.24, 0.6), (0.2, 0.9), (0, 0.92)], 9)
    som = torno([(0.3, 0.8), (0.95, 0.85), (0.9, 1.1), (0.7, 1.35), (0.35, 1.52), (0, 1.56)], 12)
    puntos = []
    for i in range(6):
        a = i * math.pi / 3 + rng.uniform(-0.2, 0.2)
        mancha = mover(icosfera(1), (0.16, 0.07, 0.16), rot=(0, 0, -38))  # inclinada hacia fuera
        puntos.append(mover(mancha, rot=(0, -math.degrees(a), 0), pos=(0.66 * math.cos(a), 1.36, 0.66 * math.sin(a))))
    puntos.append(mover(icosfera(1), (0.18, 0.06, 0.18), pos=(0, 1.56, 0)))
    return {"pie": (pie, "#f4ead2", 0), "sombrero": (som, "#e8463c", 0), "puntos": (juntar(*puntos), "#ffffff", 0)}


def m_cofre(rng):
    cuerpo = mover(caja(2, 1, 1.3), pos=(0, 0.5, 0))
    # Tapa: medio cilindro tumbado a lo largo de X
    arco = [(-0.5 * math.sin(math.pi * k / 8), 0.65 * math.cos(math.pi * k / 8)) for k in range(9)]
    tapa = mover(prisma(arco, 2), rot=(0, 0, -90), pos=(-1, 1, 0))
    bandas = juntar(*[mover(caja(0.18, 1.04, 1.34), pos=(x, 0.5, 0)) for x in (-0.75, 0.75)],
                    *[mover(prisma([(p * 1.06, q * 1.04) for p, q in arco], 0.18), rot=(0, 0, -90), pos=(x - 0.09, 1.0, 0))
                      for x in (-0.75, 0.75)])  # un poco más grandes que la tapa: si coinciden, parpadean
    cerradura = mover(caja(0.3, 0.4, 0.12), pos=(0, 0.95, -0.69))
    return {"madera": (juntar(cuerpo, tapa), "#9c6234", 0), "metal": (juntar(bandas, cerradura), "#f2c23a", 0.6)}


def m_mascota(rng):
    cuerpo = mover(icosfera(2), (0.75, 0.62, 0.68), pos=(0, 0.62, 0.15))
    cabeza = mover(icosfera(2), (0.62, 0.56, 0.58), pos=(0, 1.35, -0.25))
    orejas = juntar(*[mover(torno([(0.2, 0), (0, 0.45)], 6), rot=(0, 0, -18 * s), pos=(0.34 * s, 1.72, -0.2)) for s in (1, -1)])
    patas = juntar(*[mover(icosfera(1), (0.2, 0.15, 0.22), pos=(x, 0.12, z)) for x in (-0.38, 0.38) for z in (-0.25, 0.5)])
    cola = mover(torno([(0.12, 0), (0.08, 0.5), (0, 0.6)], 6), rot=(-55, 0, 0), pos=(0, 0.75, 0.75))
    ojos = juntar(*[mover(icosfera(1), (0.1, 0.13, 0.06), pos=(0.22 * s, 1.42, -0.79)) for s in (1, -1)])
    brillos = juntar(*[mover(icosfera(0), (0.035, 0.035, 0.02), pos=(0.24 * s, 1.47, -0.85)) for s in (1, -1)])
    nariz = mover(icosfera(1), (0.07, 0.05, 0.05), pos=(0, 1.3, -0.82))
    mejillas = juntar(*[mover(icosfera(1), (0.1, 0.06, 0.03), pos=(0.36 * s, 1.27, -0.72)) for s in (1, -1)])
    return {
        "pelo": (juntar(cuerpo, cabeza, orejas, patas, cola), "#ffb347", 0),
        "ojos": (juntar(ojos, nariz), "#2a2230", 0),
        "brillo": (brillos, "#ffffff", 0),
        "mejillas": (mejillas, "#ff8fa8", 0),
    }


def m_estrella(rng):
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 1 if i % 2 == 0 else 0.45
        pts.append((r * math.cos(a), r * math.sin(a)))
    v = [[x, y, 0] for x, y in pts] + [[0, 0, 0.35], [0, 0, -0.35]]
    t = []
    for i in range(10):
        j = (i + 1) % 10
        t += [[i, j, 10], [j, i, 11]]
    return {"estrella": (mover((np.array(v, float), np.array(t, int)), pos=(0, 1, 0)), "#ffd23f", 0.3)}


def m_nube(rng):
    bolas = [mover(icosfera(1), (s, s * 0.8, s), pos=p) for s, p in
             ((0.8, (0, 0.8, 0)), (0.6, (0.75, 0.62, 0.1)), (0.6, (-0.75, 0.62, -0.05)), (0.55, (0.3, 1.25, 0)), (0.45, (-0.35, 1.15, 0.2)))]
    return {"nube": (juntar(*bolas), "#f6f9ff", 0)}


MODELOS = {
    "huevo": m_huevo, "moneda": m_moneda, "gema": m_gema, "cristales": m_cristales, "roca": m_roca,
    "arbol": m_arbol, "pino": m_pino, "seta": m_seta, "cofre": m_cofre, "mascota": m_mascota,
    "estrella": m_estrella, "nube": m_nube,
}


def construir(nombre, tamano, semilla, colores):
    rng = np.random.default_rng(semilla)

    class R:  # envoltorio con la misma interfaz para todos
        uniform = staticmethod(lambda a, b: float(rng.uniform(a, b)))

    partes = MODELOS[nombre](R)
    # Escala: alto total = tamano, apoyado en y = 0, centrado en X/Z
    todo = np.concatenate([v for (v, t), c, m in partes.values()])
    lo, hi = todo.min(0), todo.max(0)
    f = tamano / max(hi[1] - lo[1], 1e-6)
    centro = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    out = {}
    for k, ((v, t), c, m) in partes.items():
        out[k] = ((v - centro) * f, t, hex2rgb(colores.get(k, c)), m)
    return out


# ---------------------------------------------------------------------------------------------
# Exportar
# ---------------------------------------------------------------------------------------------
def plano(v, t):
    """Vértices sin compartir (aspecto facetado) + normales por cara, con caras hacia fuera."""
    tri = v[t]  # M,3,3
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    ln = np.linalg.norm(n, axis=1)
    ok = ln > 1e-12
    tri, n, ln = tri[ok], n[ok], ln[ok]
    n = n / ln[:, None]
    return tri.reshape(-1, 3).astype(np.float32), np.repeat(n, 3, axis=0).astype(np.float32)


def componentes(t, n_vertices):
    """Etiqueta cada triángulo con su trozo conexo (cada primitiva unida con juntar() es un trozo)."""
    padre = list(range(n_vertices))

    def raiz(x):
        while padre[x] != x:
            padre[x] = padre[padre[x]]
            x = padre[x]
        return x

    for a, b, c in t:
        ra, rb, rc = raiz(a), raiz(b), raiz(c)
        padre[rb] = ra
        padre[raiz(rc)] = ra
    return np.array([raiz(a) for a, _, _ in t])


def corregir_orientacion(partes):
    """Hace que todas las caras miren hacia FUERA de su trozo (Roblox no dibuja la cara de atrás)."""
    out = {}
    for k, (v, t, c, m) in partes.items():
        t = t.copy()
        etiqueta = componentes(t, len(v))
        tri = v[t]
        n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        centros = {}
        for e in np.unique(etiqueta):
            centros[e] = v[np.unique(t[etiqueta == e])].mean(0)
        centro = np.array([centros[e] for e in etiqueta])
        fuera = ((tri.mean(1) - centro) * n).sum(1) < 0
        t[fuera] = t[fuera][:, [0, 2, 1]]
        out[k] = (v, t, c, m)
    return out


def srgb_a_lineal(c):
    return [((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


def escribir_glb(partes, ruta):
    binario = bytearray()
    vistas, accesos, mallas, nodos, materiales = [], [], [], [], []
    for i, (k, (v, t, c, m)) in enumerate(partes.items()):
        pos, nor = plano(v, t)
        for datos, tipo in ((pos, "POSITION"), (nor, "NORMAL")):
            while len(binario) % 4:
                binario.append(0)
            inicio = len(binario)
            binario += datos.tobytes()
            vistas.append({"buffer": 0, "byteOffset": inicio, "byteLength": datos.nbytes, "target": 34962})
            acc = {"bufferView": len(vistas) - 1, "componentType": 5126, "count": len(datos), "type": "VEC3"}
            if tipo == "POSITION":
                acc["min"] = datos.min(0).tolist()
                acc["max"] = datos.max(0).tolist()
            accesos.append(acc)
        materiales.append({"name": k, "pbrMetallicRoughness": {"baseColorFactor": srgb_a_lineal(c) + [1.0],
                                                               "metallicFactor": float(m), "roughnessFactor": 0.55 if m else 0.85}})
        mallas.append({"name": k, "primitives": [{"attributes": {"POSITION": len(accesos) - 2, "NORMAL": len(accesos) - 1},
                                                  "material": i}]})
        nodos.append({"name": k, "mesh": i})
    while len(binario) % 4:
        binario.append(0)
    gltf = {"asset": {"version": "2.0", "generator": "mallas.py"}, "scene": 0,
            "scenes": [{"nodes": list(range(len(nodos)))}], "nodes": nodos, "meshes": mallas,
            "materials": materiales, "accessors": accesos, "bufferViews": vistas,
            "buffers": [{"byteLength": len(binario)}]}
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(binario)
    with open(ruta, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binario), 0x004E4942) + bytes(binario))


def escribir_obj(partes, ruta_obj):
    base = os.path.splitext(os.path.basename(ruta_obj))[0]
    with open(ruta_obj[:-4] + ".mtl", "w") as f:
        for k, (v, t, c, m) in partes.items():
            f.write(f"newmtl {k}\nKd {c[0]:.4f} {c[1]:.4f} {c[2]:.4f}\nKa 0 0 0\nKs 0.1 0.1 0.1\nd 1\n\n")
    with open(ruta_obj, "w") as f:
        f.write(f"# mallas.py\nmtllib {base}.mtl\n")
        desfase = 1
        for k, (v, t, c, m) in partes.items():
            f.write(f"o {k}\nusemtl {k}\n")
            for x, y, z in v:
                f.write(f"v {x:.4f} {y:.4f} {z:.4f}\n")
            for a, b, cc in t:
                f.write(f"f {a + desfase} {b + desfase} {cc + desfase}\n")
            desfase += len(v)


# ---------------------------------------------------------------------------------------------
# Vista previa (z-buffer sencillo)
# ---------------------------------------------------------------------------------------------
def vista(partes, ancho=480, alto=480, fondo=(232, 240, 255)):
    ss = 2
    W, H = ancho * ss, alto * ss
    giro, incl = math.radians(30), math.radians(22)
    hacia = np.array([math.sin(giro) * math.cos(incl), math.sin(incl), -math.cos(giro) * math.cos(incl)])
    adelante = -hacia
    derecha = np.cross(adelante, [0, 1, 0])
    derecha /= np.linalg.norm(derecha)
    arriba = np.cross(derecha, adelante)
    sol = np.array([0.4, 0.85, -0.35])
    sol /= np.linalg.norm(sol)
    tris, cols = [], []
    for k, (v, t, c, m) in partes.items():
        pos, nor = plano(v, t)
        tri = pos.reshape(-1, 3, 3)
        n = nor[::3]
        luz = 0.5 + 0.5 * np.clip(n @ sol, 0, 1) + 0.12 * np.clip(n[:, 1], 0, 1)
        brillo = (np.clip(n @ (sol - adelante) / np.linalg.norm(sol - adelante), 0, 1) ** 24) * (0.5 + m)
        col = np.clip(np.array(c)[None, :] * luz[:, None] + brillo[:, None], 0, 1)
        tris.append(tri)
        cols.append(col)
    tris = np.concatenate(tris)
    cols = np.concatenate(cols)
    px, py = tris @ derecha, tris @ arriba
    esc = 0.8 * min(W / (px.max() - px.min()), H / (py.max() - py.min()))
    cx, cy = (px.max() + px.min()) / 2, (py.max() + py.min()) / 2
    sx = (px - cx) * esc + W / 2
    sy = H / 2 - (py - cy) * esc
    sz = tris @ adelante
    img = np.zeros((H, W, 3))
    img[:] = np.array(fondo) / 255
    zb = np.full((H, W), np.inf)
    for i in range(len(tris)):
        x, y, z = sx[i], sy[i], sz[i]
        x0, x1 = max(int(x.min()), 0), min(int(x.max()) + 1, W - 1)
        y0, y1 = max(int(y.min()), 0), min(int(y.max()) + 1, H - 1)
        if x0 > x1 or y0 > y1:
            continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
        if abs(d) < 1e-9:
            continue
        w0 = ((y[1] - y[2]) * (X - x[2]) + (x[2] - x[1]) * (Y - y[2])) / d
        w1 = ((y[2] - y[0]) * (X - x[2]) + (x[0] - x[2]) * (Y - y[2])) / d
        w2 = 1 - w0 - w1
        dentro = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        zz = w0 * z[0] + w1 * z[1] + w2 * z[2]
        zona = zb[y0:y1 + 1, x0:x1 + 1]
        vis = dentro & (zz < zona)
        zona[vis] = zz[vis]
        img[y0:y1 + 1, x0:x1 + 1][vis] = cols[i]
    # Sombra suave en el suelo
    out = Image.fromarray((img * 255).astype(np.uint8)).resize((ancho, alto), Image.LANCZOS)
    return out


# ---------------------------------------------------------------------------------------------
def generar(nombre, carpeta, tamano, semilla, colores):
    partes = corregir_orientacion(construir(nombre, tamano, semilla, colores))
    os.makedirs(carpeta, exist_ok=True)
    escribir_glb(partes, os.path.join(carpeta, nombre + ".glb"))
    escribir_obj(partes, os.path.join(carpeta, nombre + ".obj"))
    img = vista(partes)
    d = ImageDraw.Draw(img)
    tris = sum(len(t) for v, t, c, m in partes.values())
    texto = f"{nombre} · {tris} triángulos · partes: {', '.join(partes)}"
    d.rectangle([0, img.height - 26, img.width, img.height], fill=(255, 255, 255))
    d.text((8, img.height - 20), texto, fill=(40, 40, 50), font=ImageFont.load_default())
    img.save(os.path.join(carpeta, nombre + ".png"))
    return img, tris, list(partes)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("modelo", help="nombre del modelo, «todos» o «lista»")
    ap.add_argument("carpeta", nargs="?", default="mallas")
    ap.add_argument("--tamano", type=float, default=4)
    ap.add_argument("--semilla", type=int, default=1)
    ap.add_argument("--color", action="append", default=[], help="parte=#rrggbb")
    a = ap.parse_args()
    colores = dict(c.split("=", 1) for c in a.color)
    if a.modelo == "lista":
        for n in MODELOS:
            partes = construir(n, 4, 1, {})
            print(f"{n:10s} partes: {', '.join(partes)}")
        return
    nombres = list(MODELOS) if a.modelo == "todos" else [a.modelo]
    for n in nombres:
        if n not in MODELOS:
            sys.exit(f"No existe el modelo «{n}». Disponibles: {', '.join(MODELOS)}")
    imagenes = []
    for n in nombres:
        img, tris, partes = generar(n, a.carpeta, a.tamano, a.semilla, colores)
        aviso = "  ⚠️ muchos triángulos para móvil" if tris > 10000 else ""
        print(f"{n}: {tris} triángulos, partes {partes} → {a.carpeta}/{n}.glb .obj .png{aviso}")
        imagenes.append(img)
    if len(imagenes) > 1:
        cols = 4
        filas = math.ceil(len(imagenes) / cols)
        w, h = imagenes[0].size
        hoja = Image.new("RGB", (cols * w, filas * h), (255, 255, 255))
        for i, im in enumerate(imagenes):
            hoja.paste(im, ((i % cols) * w, (i // cols) * h))
        hoja.save(os.path.join(a.carpeta, "catalogo.png"))
        print(f"Catálogo: {a.carpeta}/catalogo.png")


if __name__ == "__main__":
    main()
