"""Dibuja los iconos de Icons.luau (volcados por run_client.luau en icons.json)
para poder verlos sin Roblox. Uso: python3 render_icons.py icons.json salida.png"""
import json
import math
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
from matplotlib.transforms import Affine2D

data = json.load(open(sys.argv[1]))
names = sorted(data)
cols = 10
rows = math.ceil(len(names) / cols)
fig, axes = plt.subplots(rows, cols, figsize=(cols * 1.6, rows * 1.8))
fig.patch.set_facecolor("#2a1d12")


def draw(ax, node, px, py, pw, ph, items):
    for child in node["children"]:
        if "size" not in child:
            continue
        sx, so, sy, soy = child["size"]
        w, h = sx * pw + so, sy * ph + soy
        x0, xo, y0, yo = child["pos"]
        ax_, ay_ = child["anchor"]
        x = px + x0 * pw + xo - ax_ * w
        y = py + y0 * ph + yo - ay_ * h
        radius = 0
        stroke = None
        for sub in child["children"]:
            if "radius" in sub:
                radius = sub["radius"][0] * min(w, h) + sub["radius"][1]
            if "strokeColor" in sub:
                stroke = sub
        items.append((child.get("z", 1), child, x, y, w, h, radius, stroke))
        draw(ax, child, x, y, w, h, items)


for i, ax in enumerate(axes.flat):
    ax.set_xlim(-8, 72)
    ax.set_ylim(72, -8)
    ax.set_aspect("equal")
    ax.axis("off")
    if i >= len(names):
        continue
    name = names[i]
    root = data[name]
    items = []
    draw(ax, root, 0, 0, 64, 64, items)
    items.sort(key=lambda t: t[0])
    for _, node, x, y, w, h, radius, stroke in items:
        if node["class"] == "TextLabel":
            if node.get("text"):
                ax.text(x + w / 2, y + h / 2, node["text"], color=node["textColor"], ha="center", va="center", fontsize=10, weight="bold")
            continue
        alpha = 1 - node["transparency"]
        r = min(radius, w / 2, h / 2)
        patch = FancyBboxPatch((x + r, y + r), max(0.01, w - 2 * r), max(0.01, h - 2 * r), boxstyle=f"round,pad={r}",
                               facecolor=node["color"] if alpha > 0 else "none", alpha=None,
                               edgecolor=stroke["strokeColor"] if stroke and stroke["strokeTransparency"] < 1 else "none",
                               linewidth=(stroke["thickness"] * 0.7) if stroke else 0)
        if alpha < 1 and alpha > 0:
            patch.set_facecolor((*node["color"], alpha))
        rot = node.get("rot", 0)
        if rot:
            patch.set_transform(Affine2D().rotate_deg_around(x + w / 2, y + h / 2, rot) + ax.transData)
        ax.add_patch(patch)
    ax.set_title(name, color="#fbbf24", fontsize=8)
plt.tight_layout()
plt.savefig(sys.argv[2], dpi=90, facecolor=fig.get_facecolor())
print("ok", len(names))
