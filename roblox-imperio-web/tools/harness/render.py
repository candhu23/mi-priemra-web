"""Renderiza alzados frontales de los rascacielos y una vista cenital de la
ciudad a partir del volcado JSON (proyección ortográfica, orden del pintor)."""
import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle

data = json.load(open(sys.argv[1]))["parts"]
out = sys.argv[2]

def corners(p):
    c = np.array(p["p"]); X = np.array(p["x"]); Y = np.array(p["y"]); Z = np.array(p["z"])
    sx, sy, sz = np.array(p["s"]) / 2
    pts = []
    for a in (-1, 1):
        for b in (-1, 1):
            for d in (-1, 1):
                pts.append(c + a * sx * X + b * sy * Y + d * sz * Z)
    return np.array(pts)

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

def alpha(p):
    a = 1 - p["t"]
    if p["m"] == "Glass":
        a = min(a, 0.9)
    return max(a, 0)

def draw(ax, parts, project, depth, sky=None):
    items = []
    for p in parts:
        if p["t"] >= 0.99:
            continue
        cs = corners(p)
        proj = np.array([project(c) for c in cs])
        items.append((depth(np.array(p["p"])), p, proj))
    items.sort(key=lambda t: t[0])
    for _, p, proj in items:
        color = tuple(p["c"]) + (alpha(p),)
        if p["shape"] == "Ball":
            center = proj.mean(axis=0)
            r = (proj[:, 0].max() - proj[:, 0].min()) / 2
            ax.add_patch(Circle(center, r, facecolor=color, edgecolor=(0, 0, 0, 0.25), linewidth=0.3))
        else:
            h = hull(proj)
            if len(h) >= 3:
                ax.add_patch(Polygon(h, closed=True, facecolor=color, edgecolor=(0, 0, 0, 0.25), linewidth=0.3))
    ax.set_aspect("equal")
    ax.autoscale_view()

plots = {}
for p in data:
    if p.get("plot") is not None:
        plots.setdefault(p["plot"], []).append(p)

# Marco de cada parcela: la losa base (la pieza de 0.8 de alto más grande)
frames = {}
for idx, parts in plots.items():
    for p in parts:
        if abs(p["s"][1] - 0.8) < 0.01 and abs(p["s"][0] - p["s"][2]) < 0.01 and p["s"][0] > 60:
            if idx not in frames or p["s"][0] > frames[idx]["s"][0]:
                frames[idx] = p
occupied = sorted(i for i, parts in plots.items() if any(q["n"] == "Azotea" for q in parts))

fig, axes = plt.subplots(1, len(occupied), figsize=(4.2 * len(occupied), 9), facecolor=(0.62, 0.8, 0.95))
if len(occupied) == 1:
    axes = [axes]
for ax, idx in zip(axes, occupied):
    f = frames[idx]
    origin = np.array(f["p"]); X = np.array(f["x"]); Y = np.array(f["y"]); Z = np.array(f["z"])
    project = lambda c: (-(c - origin) @ X, (c - origin) @ Y)
    depth = lambda c: -((c - origin) @ Z)  # lejos primero
    draw(ax, plots[idx], project, depth)
    floors = [q for q in plots[idx] if q["n"].startswith("Planta")] # (las plantas son modelos; las piezas no tienen ese nombre)
    ax.set_facecolor((0.62, 0.8, 0.95))
    ax.set_title(f"Parcela {idx}", fontsize=12)
    ax.set_xlim(-50, 50)
    ax.set_ylim(-1, 260)
    ax.axis("off")
plt.tight_layout()
plt.savefig(out + "_fachadas.png", dpi=110)

# Vista cenital
fig, ax = plt.subplots(figsize=(16, 7), facecolor="white")
draw(ax, data, lambda c: (c[0], -c[2]), lambda c: c[1])
ax.set_xlim(-345, 345)
ax.set_ylim(-140, 140)
ax.axis("off")
plt.tight_layout()
plt.savefig(out + "_ciudad.png", dpi=90)
print("ok", occupied)
