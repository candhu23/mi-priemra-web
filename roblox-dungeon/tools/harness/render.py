"""Dibuja, a partir del volcado de tools/out/world.json (piezas + rellenos de terreno):
  · render_ciudad.png   el lobby visto desde arriba y en perspectiva
  · render_zonas.png    las arenas de los 3 mapas vistas desde arriba
  · render_enemigos.png alzado frontal de cada enemigo (galería)
Proyección ortográfica con orden del pintor: no es Roblox (sin luces ni
texturas), pero sirve para comprobar la composición y que todo esté en su sitio."""
import json, sys, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle, Ellipse

data = json.load(open(sys.argv[1]))
out = sys.argv[2]

# Colores aproximados de los materiales del terreno de Roblox
TERRAIN = {
    "Grass": (0.42, 0.62, 0.30), "LeafyGrass": (0.36, 0.55, 0.26), "Ground": (0.47, 0.38, 0.27),
    "Mud": (0.36, 0.29, 0.22), "Sand": (0.84, 0.77, 0.58), "Water": (0.20, 0.50, 0.66),
    "Rock": (0.47, 0.47, 0.47), "Snow": (0.94, 0.96, 1.0), "Slate": (0.35, 0.38, 0.42),
    "Basalt": (0.22, 0.22, 0.25), "Salt": (0.78, 0.80, 0.82), "Glacier": (0.62, 0.80, 0.90),
    "Cobblestone": (0.55, 0.53, 0.50), "Pavement": (0.62, 0.62, 0.60), "Limestone": (0.80, 0.76, 0.64),
    "CrackedLava": (0.85, 0.35, 0.12), "Brick": (0.55, 0.30, 0.24),
}

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

def top_of(p):
    if p.get("terrain"):
        if p["kind"] == "ball":
            return p["p"][1] + p["r"]
        if p["kind"] == "cylinder":
            return p["p"][1] + p["h"] / 2
        return p["p"][1] + abs(p["s"][1]) / 2
    return p["p"][1]

def draw(ax, items, project, depth):
    queue = []
    for p in items:
        if not p.get("terrain") and p["t"] >= 0.99:
            continue
        queue.append((depth(p), p))
    queue.sort(key=lambda t: t[0])
    for _, p in queue:
        if p.get("terrain"):
            color = TERRAIN.get(p["m"], (0.6, 0.6, 0.6)) + (1,)
            if p["m"] == "Water":
                color = TERRAIN["Water"] + (0.85,)
            c = np.array(p["p"])
            if p["kind"] in ("ball", "cylinder"):
                r = p["r"]
                if p["kind"] == "ball":
                    # Una bola enterrada se ve como su corte con la altura del suelo
                    y = max(0.0, min(r, abs(c[1]) if c[1] < 0 else 0))
                    r = math.sqrt(max(r * r - y * y, 1)) if c[1] < 0 else r
                cx, cy = project(c)
                ax.add_patch(Circle((cx, cy), r, facecolor=color, edgecolor=(0, 0, 0, 0.15), linewidth=0.4))
            else:
                h = hull(np.array([project(k) for k in corners(p)]))
                if len(h) >= 3:
                    ax.add_patch(Polygon(h, closed=True, facecolor=color, edgecolor=(0, 0, 0, 0.1), linewidth=0.3))
            continue
        a = max(0.0, 1 - p["t"])
        color = tuple(p["c"]) + (a,)
        edge = (0, 0, 0, 0.25 * a)
        proj = np.array([project(k) for k in corners(p)])
        if p["shape"] == "Ball":
            r = (proj[:, 0].max() - proj[:, 0].min()) / 2
            ax.add_patch(Circle(proj.mean(axis=0), r, facecolor=color, edgecolor=edge, linewidth=0.3))
        elif p["shape"] == "Cylinder":
            axis = np.array(p["x"])
            view = np.array(project(np.array(p["p"]) + axis)) - np.array(project(np.array(p["p"])))
            if np.linalg.norm(view) < 0.2:
                ax.add_patch(Circle(project(np.array(p["p"])), p["s"][1] / 2, facecolor=color, edgecolor=edge, linewidth=0.3))
            else:
                ax.add_patch(Polygon(hull(proj), closed=True, facecolor=color, edgecolor=edge, linewidth=0.3))
        else:
            h = hull(proj)
            if len(h) >= 3:
                ax.add_patch(Polygon(h, closed=True, facecolor=color, edgecolor=edge, linewidth=0.3))
    ax.set_aspect("equal")

def group(name):
    return [p for p in data if p.get("g") == name]

top_project = lambda c: (c[0], -c[2])
top_depth = lambda p: top_of(p) + (0 if p.get("terrain") else 1000)  # piezas siempre encima del terreno

# Lobby: vista desde arriba (cerca) y vista general con montañas
fig, axes = plt.subplots(1, 2, figsize=(20, 10), facecolor=(0.55, 0.72, 0.85))
lobby = group("ciudad")
draw(axes[0], lobby, top_project, top_depth)
axes[0].set_xlim(-150, 150); axes[0].set_ylim(-150, 150); axes[0].axis("off")
axes[0].set_title("Lobby desde arriba (portales al norte, arriba)")
draw(axes[1], lobby, top_project, top_depth)
axes[1].set_xlim(-470, 470); axes[1].set_ylim(-470, 470); axes[1].axis("off")
axes[1].set_title("Isla, lago y montañas")
for ax in axes:
    ax.set_facecolor(TERRAIN["Water"])
plt.tight_layout(); plt.savefig(out + "_ciudad.png", dpi=70); plt.close()

# Lobby en perspectiva (desde el sur, un poco elevado): solo piezas y terreno cercano
def oblique(c):
    return (c[0], c[1] * 0.9 - c[2] * 0.35)
def oblique_depth(p):
    # Lo más al sur (z mayor) está más cerca de la cámara: se pinta lo último
    return p["p"][2] + (0 if not p.get("terrain") else -2000 + top_of(p))
fig, ax = plt.subplots(figsize=(18, 9), facecolor=(0.62, 0.78, 0.92))
near = [p for p in lobby if abs(p["p"][0]) < 160 and abs(p["p"][2]) < 160]
draw(ax, near, oblique, oblique_depth)
ax.set_xlim(-150, 150); ax.set_ylim(-60, 90); ax.axis("off")
ax.set_facecolor((0.62, 0.78, 0.92))
ax.set_title("Lobby en perspectiva (mirando al norte)")
plt.tight_layout(); plt.savefig(out + "_ciudad_perspectiva.png", dpi=70); plt.close()

# Castillo del lobby (al norte, sobre el lago) visto desde la orilla
fig, ax = plt.subplots(figsize=(14, 9), facecolor=(0.62, 0.78, 0.92))
castle = [p for p in lobby if abs(p["p"][0]) < 90 and -300 < p["p"][2] < -120]
draw(ax, castle, oblique, oblique_depth)
ax.set_xlim(-80, 80); ax.set_ylim(40, 150); ax.axis("off")
ax.set_facecolor((0.62, 0.78, 0.92))
ax.set_title("Castillo y puente (mirando al norte)")
plt.tight_layout(); plt.savefig(out + "_castillo.png", dpi=70); plt.close()

# Arenas de partida (una por mapa)
fig, axes = plt.subplots(1, 3, figsize=(21, 7.4))
for ax, z in zip(axes, ("bosque", "cueva", "castillo")):
    draw(ax, group(z), top_project, top_depth)
    ax.set_xlim(-235, 235); ax.set_ylim(-235, 235); ax.axis("off")
    ax.add_patch(Polygon([(-140, -140), (140, -140), (140, 140), (-140, 140)], closed=True, fill=False, edgecolor=(1, 1, 1, 0.5), linestyle="--"))
    ax.set_title("Arena: " + z.capitalize() + " (línea = zona jugable)")
plt.tight_layout(); plt.savefig(out + "_zonas.png", dpi=65); plt.close()

# Galería de enemigos (alzado frontal: miran hacia -Z; la cámara está en -Z mirando a +Z)
fig, ax = plt.subplots(figsize=(22, 6))
gallery = group("galeria")
draw(ax, gallery, lambda c: (-c[0], c[1]), lambda p: p["p"][2])
xs = [p["p"][0] for p in gallery]
ax.set_xlim(-max(xs) - 12, -min(xs) + 12); ax.set_ylim(-1, 26); ax.axis("off")
plt.tight_layout(); plt.savefig(out + "_enemigos.png", dpi=80); plt.close()
print("ok")
