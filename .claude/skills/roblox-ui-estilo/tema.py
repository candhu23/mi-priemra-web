#!/usr/bin/env python3
"""tema.py — crea el TEMA de la interfaz de un juego de Roblox (colores, letras, tamaños, esquinas)
como módulo Luau, comprueba que el texto se lee (contraste WCAG) y dibuja una muestra en PNG.

Uso:
  python3 tema.py lista                                  → estilos disponibles
  python3 tema.py <estilo> Tema.luau [--muestra tema.png] [--primario #ff5a8c] [--fondo #20203a]

Estilos: caramelo, noche, bosque, oceano, lava, espacio, pastel, oro (ver `lista`).
El Tema.luau sirve tal cual con UIKit (plugin roblox-ui-componentes): UIKit.usarTema(require(Tema)).
Necesita Pillow solo para --muestra.
"""
import argparse
import colorsys
import sys

ESTILOS = {
    # nombre: (fondo, panel, primario, acento, descripción)
    "caramelo": ("#3a1f4a", "#5a2f6e", "#ff5fa2", "#ffd23f", "Dulce y alegre (simuladores de mascotas, comida)"),
    "noche": ("#181c30", "#262c48", "#409cff", "#ffc428", "Azul oscuro neutro: vale para casi todo"),
    "bosque": ("#16281c", "#24402c", "#5cc84e", "#ffcf4a", "Naturaleza, granjas, aventuras"),
    "oceano": ("#0f2a3d", "#184560", "#2ec4e6", "#ffd166", "Mar, islas, pesca"),
    "lava": ("#2a1414", "#46201c", "#ff6a2a", "#ffd23f", "Fuego, volcanes, combates"),
    "espacio": ("#0e0b24", "#1f1a44", "#9a6bff", "#4de8ff", "Ciencia ficción, galaxias, neón"),
    "pastel": ("#2e3550", "#454e72", "#8fb8ff", "#ffb8d9", "Suave y tranquilo (decoración, rol)"),
    "oro": ("#1c1a14", "#353024", "#f2b33d", "#7fe0a0", "Lujo, dinero, tycoons"),
}


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb2hex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(x))) for x in c)


def luminancia(c):
    def canal(x):
        x /= 255
        return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    r, g, b = (canal(x) for x in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contraste(a, b):
    la, lb = sorted((luminancia(a), luminancia(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def ajustar(c, luz=0.0, sat=0.0):
    h, l, s = colorsys.rgb_to_hls(*(x / 255 for x in c))
    l = max(0, min(1, l + luz))
    s = max(0, min(1, s + sat))
    return tuple(x * 255 for x in colorsys.hls_to_rgb(h, l, s))


def oscurecer(c, f):
    return tuple(x * f for x in c)


def construir(nombre, primario=None, fondo=None):
    f, p, pr, ac, desc = ESTILOS[nombre]
    fondo_c = hex2rgb(fondo or f)
    panel = hex2rgb(p) if not fondo else ajustar(fondo_c, 0.08)
    prim = hex2rgb(primario or pr)
    t = {
        "fondo": fondo_c,
        "panel": panel,
        "panel2": ajustar(panel, 0.07),
        "borde": oscurecer(fondo_c, 0.55),
        "texto": (255, 255, 255),
        "textoSuave": ajustar((205, 210, 235), 0, 0),
        "primario": prim,
        "exito": (70, 200, 90),
        "peligro": (235, 70, 80),
        "aviso": (255, 196, 40),
        "oro": hex2rgb(ac) if nombre == "oro" else (255, 205, 60),
        "acento": hex2rgb(ac),
    }
    # El texto blanco con contorno debe leerse encima de los botones: si no, oscurecemos el botón
    for k in ("primario", "exito", "peligro"):
        intentos = 0
        while contraste(t["texto"], t[k]) < 2.2 and intentos < 20:
            t[k] = ajustar(t[k], -0.03)
            intentos += 1
    return t, desc


def comprobar(t):
    """Devuelve una lista de (pareja, ratio, mínimo, ok)."""
    pruebas = [
        ("texto sobre fondo", t["texto"], t["fondo"], 4.5),
        ("texto sobre panel", t["texto"], t["panel"], 4.5),
        ("textoSuave sobre panel", t["textoSuave"], t["panel"], 4.5),
        ("textoSuave sobre fondo", t["textoSuave"], t["fondo"], 4.5),
        ("oro (cifras) sobre panel", t["oro"], t["panel"], 3.0),
        ("texto sobre botón primario (con contorno)", t["texto"], t["primario"], 2.2),
        ("texto sobre botón éxito (con contorno)", t["texto"], t["exito"], 2.2),
    ]
    return [(n, contraste(a, b), m, contraste(a, b) >= m) for n, a, b, m in pruebas]


def luau(t, nombre, desc):
    def c3(c):
        r, g, b = (max(0, min(255, round(x))) for x in c)
        return f"Color3.fromRGB({r}, {g}, {b})"
    lineas = [
        "--!nonstrict",
        f"-- Tema «{nombre}» de la interfaz ({desc}). Generado con tema.py (plugin roblox-ui-estilo).",
        "-- Úsalo con UIKit: UIKit.usarTema(require(ReplicatedStorage.Tema))",
        "-- Regla: TODOS los colores de la interfaz salen de aquí. Nada de Color3 sueltos por el código.",
        "local Tema = {",
    ]
    for k in ("fondo", "panel", "panel2", "borde", "texto", "textoSuave", "primario", "exito", "peligro", "aviso", "oro", "acento"):
        lineas.append(f"\t{k} = {c3(t[k])},")
    lineas += [
        "\t-- Letras: títulos y botones redondeados y gruesos; texto normal muy legible",
        "\tfuenteTitulo = Font.fromEnum(Enum.Font.FredokaOne),",
        '\tfuenteTexto = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),',
        "\t-- Tamaños de letra (en la pantalla base 1280×720; en el móvil se ven ×0,66 aprox.)",
        "\tletra = { enorme = 56, titulo = 36, boton = 28, normal = 22, pequena = 18 },",
        "\t-- Espaciado en múltiplos de 4 y esquinas",
        "\tespacio = { xs = 4, s = 8, m = 12, l = 16, xl = 24 },",
        "\tesquina = 14,",
        "\ttrazo = 3,",
        "\tbase = Vector2.new(1280, 720),",
        "\tescalaMinima = 0.7,",
        "}",
        "",
        "return Tema",
        "",
    ]
    return "\n".join(lineas)


def muestra(t, ruta, nombre):
    from PIL import Image, ImageDraw, ImageFont
    W, H = 900, 420
    im = Image.new("RGB", (W, H), tuple(round(x) for x in t["fondo"]))
    d = ImageDraw.Draw(im)
    try:
        f_t = ImageFont.truetype("DejaVuSans-Bold.ttf", 30)
        f_n = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
    except OSError:
        f_t = f_n = ImageFont.load_default()
    R = lambda c: tuple(round(x) for x in c)
    d.text((24, 18), f"Tema «{nombre}»", fill=R(t["texto"]), font=f_t)
    d.rounded_rectangle([24, 70, 520, 250], 18, fill=R(t["panel"]), outline=R(t["borde"]), width=4)
    d.text((44, 88), "Título de tarjeta", fill=R(t["texto"]), font=f_t)
    d.text((44, 136), "Texto suave de descripción", fill=R(t["textoSuave"]), font=f_n)
    d.text((44, 170), "💰 15.3K", fill=R(t["oro"]), font=f_t)
    x = 24
    for k in ("primario", "exito", "peligro", "aviso"):
        c = R(t[k])
        d.rounded_rectangle([x, 280 + 6, x + 190, 350 + 6], 16, fill=R(oscurecer(t[k], 0.6)))
        d.rounded_rectangle([x, 280, x + 190, 350], 16, fill=c, outline=R(oscurecer(t[k], 0.45)), width=3)
        d.text((x + 20, 300), k.upper(), fill=(255, 255, 255), font=f_n, stroke_width=2, stroke_fill=R(t["borde"]))
        x += 210
    y = 70
    for k in ("fondo", "panel", "panel2", "borde", "textoSuave", "acento"):
        d.rounded_rectangle([560, y, 700, y + 28], 8, fill=R(t[k]), outline=(255, 255, 255), width=1)
        d.text((712, y + 4), k, fill=R(t["texto"]), font=f_n)
        y += 36
    im.save(ruta)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("estilo")
    ap.add_argument("salida", nargs="?")
    ap.add_argument("--muestra")
    ap.add_argument("--primario")
    ap.add_argument("--fondo")
    a = ap.parse_args()
    if a.estilo == "lista":
        for n, v in ESTILOS.items():
            print(f"{n:9s} {v[4]}")
        return
    if a.estilo not in ESTILOS:
        sys.exit(f"Estilo desconocido. Disponibles: {', '.join(ESTILOS)}")
    t, desc = construir(a.estilo, a.primario, a.fondo)
    malos = 0
    for n, r, m, ok in comprobar(t):
        print(f"{'✅' if ok else '⚠️'} {n}: {r:.1f}:1 (mínimo {m}:1)")
        malos += not ok
    if a.salida:
        with open(a.salida, "w", encoding="utf-8") as f:
            f.write(luau(t, a.estilo, desc))
        print(f"Tema escrito en {a.salida}")
    if a.muestra:
        muestra(t, a.muestra, a.estilo)
        print(f"Muestra: {a.muestra}")
    if malos:
        print("Hay combinaciones con poco contraste: cambia --fondo o --primario.")


if __name__ == "__main__":
    main()
