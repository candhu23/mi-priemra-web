"""Dibuja, a partir del volcado de tools/out/world.json:
  · render_ciudad.png   vista cenital de la Ciudad
  · render_zonas.png    vista cenital de las arenas de los 3 mapas
  · render_enemigos.png alzado frontal de cada enemigo (galería)
Proyección ortográfica con orden del pintor: no es Roblox, pero sirve para
comprobar que todo está en su sitio y tiene buena pinta."""
import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle

data = json.load(open(sys.argv[1]))
out = sys.argv[2]

def corners(p):
    c = np.array(p["p"]); X = np.array(p["x"]); Y = np.array(p["y"]); Z = np.array(p["z"])
    sx, sy, sz = np.array(p["s"]) / 2
    return np.array([c + a * sx * X + b * sy * Y + d * sz * Z for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)])

def hull(points):
    pts = sorted(set(map(tuple, np.round(points, 4))))
    if len(pts) <= 2:
        return np.array(pts)
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return np.array(lower[:-1] + upper[:-1])

def draw(ax, parts, project, depth, skip=lambda p: False):
    items = []
    for p in parts:
        if p["t"] >= 0.99 or skip(p):
            continue
        proj = np.array([project(c) for c in corners(p)])
        items.append((depth(np.array(p["p"])), p, proj))
    items.sort(key=lambda t: t[0])
    for _, p, proj in items:
        a = max(0.0, 1 - p["t"])
        color = tuple(p["c"]) + (a,)
        edge = (0, 0, 0, 0.25 * a)
        if p["shape"] == "Ball":
            r = (proj[:, 0].max() - proj[:, 0].min()) / 2
            ax.add_patch(Circle(proj.mean(axis=0), r, facecolor=color, edgecolor=edge, linewidth=0.3))
        elif p["shape"] == "Cylinder":
            # Cilindro: eje X de la pieza. Si apunta a la cámara se ve como círculo.
            axis = np.array(p["x"])
            view = np.array(project(np.array(p["p"]) + axis)) - np.array(project(np.array(p["p"])))
            if np.linalg.norm(view) < 0.2:
                r = p["s"][1] / 2
                ax.add_patch(Circle(project(np.array(p["p"])), r, facecolor=color, edgecolor=edge, linewidth=0.3))
            else:
                h = hull(proj)
                ax.add_patch(Polygon(h, closed=True, facecolor=color, edgecolor=edge, linewidth=0.3))
        else:
            h = hull(proj)
            if len(h) >= 3:
                ax.add_patch(Polygon(h, closed=True, facecolor=color, edgecolor=edge, linewidth=0.3))
    ax.set_aspect("equal")

top = (lambda c: (c[0], -c[2]), lambda c: c[1])

def group(name):
    return [p for p in data if p["g"] == name]

# Ciudad
fig, ax = plt.subplots(figsize=(10, 10))
draw(ax, group("ciudad"), *top)
ax.set_xlim(-112, 112); ax.set_ylim(-112, 112); ax.axis("off")
ax.set_title("Ciudad (vista desde arriba; el norte, con los portales, arriba)")
plt.tight_layout(); plt.savefig(out + "_ciudad.png", dpi=80); plt.close()

# Arenas de partida (una por mapa)
fig, axes = plt.subplots(1, 3, figsize=(18, 6.6))
for ax, z in zip(axes, ("bosque", "cueva", "castillo")):
    draw(ax, group(z), *top)
    ax.set_xlim(-150, 150); ax.set_ylim(-150, 150); ax.axis("off")
    ax.set_title("Arena: " + z.capitalize())
plt.tight_layout(); plt.savefig(out + "_zonas.png", dpi=70); plt.close()

# Galería de enemigos (alzado frontal: miran hacia -Z, la cámara está en -Z mirando a +Z)
fig, ax = plt.subplots(figsize=(22, 6))
gallery = group("galeria")
draw(ax, gallery, lambda c: (-c[0], c[1]), lambda c: c[2])
xs = [p["p"][0] for p in gallery]
ax.set_xlim(-max(xs) - 12, -min(xs) + 12); ax.set_ylim(-1, 26); ax.axis("off")
ax.set_facecolor((0.85, 0.9, 0.95))
plt.tight_layout(); plt.savefig(out + "_enemigos.png", dpi=80); plt.close()
print("ok")
