#!/usr/bin/env python3
"""revisar_ui.py — revisa el CÓDIGO Luau de la interfaz de un juego de Roblox (sin ejecutarlo)
y avisa de los fallos de diseño y de móvil más comunes, con archivo:línea y cómo arreglarlo.

Uso:
  python3 revisar_ui.py <carpeta o archivo .luau> [más rutas…] [--informe informe.md]

Qué busca (cada regla tiene un código para poder buscarla en la guía de la skill):
  UI01 TextSize menor de 18 en diseño (en el móvil se verá con < 12 px)
  UI02 TextScaled sin UITextSizeConstraint (en pantallas grandes sale gigante, en móvil diminuta)
  UI03 MouseButton1Click en botones (no va bien con mando; usa Activated)
  UI04 ScreenGui sin ResetOnSpawn = false (la interfaz se reinicia al morir)
  UI05 UIGradient dentro de un objeto con texto (también tiñe las LETRAS)
  UI06 Fuentes antiguas (Enum.Font.Legacy / Arial / SourceSans) — usa FredokaOne, GothamBold, BuilderSans…
  UI07 Contraste bajo entre TextColor3 y BackgroundColor3 escritos en el mismo bloque
  UI08 Botón con tamaño fijo menor de 44×44 (difícil de pulsar con el dedo)
  UI09 Tamaños grandes solo en píxeles sin UIScale/Adaptable en el archivo (no se adapta a la pantalla)
  UI10 wait()/spawn()/delay() antiguos — usa task.wait / task.spawn / task.delay
  UI11 Más de un UIScale creado sobre el mismo objeto (solo cuenta el primero)
  UI12 Textos del jugador escritos a mano dentro del código de la UI (pista para traducir ES/EN)
No sustituye a ver la interfaz (plugin roblox-ui-pantallas: probar_pantallas.luau + ver_interfaz.py).
"""
import argparse
import os
import re
import sys

COLOR = re.compile(r"Color3\.fromRGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)|Color3\.fromHex\(\s*\"#?([0-9a-fA-F]{6})\"\s*\)|Color3\.new\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)")
CLASE_TEXTO = re.compile(r"[\"'](TextLabel|TextButton|TextBox)[\"']")
CLASE_BOTON = re.compile(r"[\"'](TextButton|ImageButton)[\"']")


def color_de(m):
    if m.group(1):
        return tuple(int(m.group(i)) for i in (1, 2, 3))
    if m.group(4):
        h = m.group(4)
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return tuple(round(float(m.group(i)) * 255) for i in (5, 6, 7))


def lum(c):
    def k(x):
        x /= 255
        return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    return 0.2126 * k(c[0]) + 0.7152 * k(c[1]) + 0.0722 * k(c[2])


def contraste(a, b):
    x, y = sorted((lum(a), lum(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)


def bloque(lineas, i, maximo=25):
    """Texto desde la línea i hasta que se cierran las llaves/paréntesis abiertos (o maximo líneas)."""
    prof = 0
    trozo = []
    for j in range(i, min(len(lineas), i + maximo)):
        l = lineas[j]
        trozo.append(l)
        prof += l.count("{") + l.count("(") - l.count("}") - l.count(")")
        if j > i and prof <= 0:
            break
    return "\n".join(trozo)


def revisar_archivo(ruta):
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    # Fuera los comentarios largos --[[ ... ]] (conservando los saltos de línea para no mover los números)
    texto = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: "\n" * m.group(0).count("\n"), texto, flags=re.S)
    lineas = texto.split("\n")
    hallazgos = []

    def add(codigo, n, msg):
        hallazgos.append((codigo, ruta, n + 1, msg))

    tiene_escala = bool(re.search(r"UIScale|Adaptable|UIKit|autoScale|updateScale", texto))
    tiene_constraint = "UITextSizeConstraint" in texto or "textoAjustado" in texto
    for n, l in enumerate(lineas):
        s = l.split("--")[0]
        m = re.search(r"\bTextSize\s*=\s*(\d+)", s)
        if m and int(m.group(1)) < 18:
            add("UI01", n, f"TextSize = {m.group(1)}: en el móvil (escala ~0,66) se verá a {int(m.group(1)) * 0.66:.0f} px. Usa 18 o más.")
        m = re.search(r"\btamano\s*=\s*(\d+)", s)
        if m and int(m.group(1)) < 18 and ("texto" in s.lower() or "tamano" in s):
            add("UI01", n, f"tamano = {m.group(1)}: en el móvil se verá pequeño. Usa 18 o más.")
        cerca = "\n".join(lineas[max(0, n - 15):n + 1])
        en_3d = "BillboardGui" in cerca or "SurfaceGui" in cerca  # carteles 3D: ahí TextScaled es lo normal
        if re.search(r"TextScaled\s*=\s*true", s) and not tiene_constraint and not en_3d:
            add("UI02", n, "TextScaled sin UITextSizeConstraint: pon MinTextSize ~14 y MaxTextSize (o Adaptable.textoAjustado).")
        if "MouseButton1Click" in s:
            add("UI03", n, "MouseButton1Click: cámbialo por .Activated (funciona con ratón, dedo y mando).")
        if re.search(r"Instance\.new\(\s*[\"']ScreenGui[\"']", s) or re.search(r"[\"']ScreenGui[\"']\s*,", s):
            b = bloque(lineas, n, 40)
            resto = "\n".join(lineas[n:n + 40])
            if "ResetOnSpawn" not in b and "ResetOnSpawn" not in resto:
                add("UI04", n, "ScreenGui sin ResetOnSpawn = false: al morir el jugador la interfaz se borra y se recrea.")
        if re.search(r"Enum\.Font\.(Legacy|Arial|ArialBold|SourceSans|SourceSansBold)\b", s):
            add("UI06", n, "Fuente antigua: usa FredokaOne / GothamBold / BuilderSans (Font.new(...)) para aspecto actual.")
        if re.search(r"(?<![\w.])(wait|spawn|delay)\s*\(", s) and not re.search(r"task\.(wait|spawn|delay)", s) and not re.search(r"function\s+\w*\.?(wait|spawn|delay)", s):
            add("UI10", n, "wait/spawn/delay antiguos: usa task.wait / task.spawn / task.delay.")

        # Bloques de creación de objetos con texto: contraste y gradiente
        if CLASE_TEXTO.search(s):
            b = bloque(lineas, n)
            tc = re.search(r"TextColor3\s*=\s*(" + COLOR.pattern + ")", b)
            bc = re.search(r"BackgroundColor3\s*=\s*(" + COLOR.pattern + ")", b)
            bt = re.search(r"BackgroundTransparency\s*=\s*([\d.]+)", b)
            if tc and bc and not (bt and float(bt.group(1)) >= 0.9):
                a = color_de(COLOR.search(tc.group(1)))
                c = color_de(COLOR.search(bc.group(1)))
                r = contraste(a, c)
                ts = re.search(r"TextSize\s*=\s*(\d+)", b)
                minimo = 3.0 if (ts and int(ts.group(1)) >= 28) else 4.5
                if r < minimo and "UIStroke" not in b:
                    add("UI07", n, f"Contraste {r:.1f}:1 entre texto {a} y fondo {c} (mínimo {minimo}:1). Aclara el texto, oscurece el fondo o añade UIStroke al texto.")
            if "UIGradient" in b:
                add("UI05", n, "UIGradient en un objeto con texto: tiñe también las letras. Pon el degradado en un Frame de fondo, detrás del texto.")
        if CLASE_BOTON.search(s):
            b = bloque(lineas, n)
            m = re.search(r"Size\s*=\s*UDim2\.(?:fromOffset\(\s*(\d+)\s*,\s*(\d+)\s*\)|new\(\s*0\s*,\s*(\d+)\s*,\s*0\s*,\s*(\d+)\s*\))", b)
            if m:
                w = int(m.group(1) or m.group(3))
                h = int(m.group(2) or m.group(4))
                if w < 44 or h < 44:
                    add("UI08", n, f"Botón de {w}×{h}: con el dedo hace falta al menos 44×44 (mejor 56). En el móvil aún se verá más pequeño.")
        m = re.search(r"Size\s*=\s*UDim2\.(?:fromOffset\(\s*(\d+)\s*,\s*(\d+)|new\(\s*0\s*,\s*(\d+)\s*,\s*0\s*,\s*(\d+))", s)
        if m and not tiene_escala:
            w = int(m.group(1) or m.group(3))
            h = int(m.group(2) or m.group(4))
            if w >= 500 or h >= 360:
                add("UI09", n, f"Marco de {w}×{h} píxeles fijos y el archivo no usa UIScale: en el móvil se saldrá de la pantalla. Usa Adaptable.escalar o UIKit.pantalla.")
        m = re.search(r"\bText\s*=\s*\"([^\"]{4,})\"", s)
        if m and re.search(r"[A-Za-zÁÉÍÓÚáéíóúñÑ]{3,}\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]{2,}", m.group(1)) and "Lang" not in texto and "T(" not in texto:
            add("UI12", n, f"Texto escrito a mano («{m.group(1)[:30]}»): si el juego va a tener inglés, pásalo a un módulo de traducciones.")

    # UI11: varios UIScale sobre el mismo padre (heurística por variable)
    padres = {}
    for n, l in enumerate(lineas):
        m = re.search(r"UIScale.*Parent\s*=\s*([\w.]+)", l) or re.search(r"(\w+)\s*:\s*FindFirstChildOfClass\(\"UIScale\"\)", l)
        if m and "UIScale" in l:
            padres.setdefault(m.group(1), []).append(n)
    for p, ns in padres.items():
        if len(ns) > 1:
            add("UI11", ns[1], f"Varios UIScale en «{p}» (líneas {', '.join(str(x + 1) for x in ns)}): Roblox solo usa uno. Mete el objeto en un Frame contenedor.")
    return hallazgos


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("rutas", nargs="+")
    ap.add_argument("--informe")
    a = ap.parse_args()
    archivos = []
    for r in a.rutas:
        if os.path.isdir(r):
            for raiz, _, nombres in os.walk(r):
                if any(x in raiz for x in ("/tools/", "/node_modules/", "/.git")):
                    continue
                archivos += [os.path.join(raiz, n) for n in nombres if n.endswith((".luau", ".lua"))]
        else:
            archivos.append(r)
    todos = []
    for f in sorted(archivos):
        todos += revisar_archivo(f)
    if not todos:
        print(f"✅ {len(archivos)} archivos revisados: sin problemas de los que busca este revisor.")
        return
    por_codigo = {}
    for h in todos:
        por_codigo.setdefault(h[0], []).append(h)
    salida = [f"# Revisión de interfaz ({len(archivos)} archivos, {len(todos)} avisos)\n"]
    for codigo in sorted(por_codigo):
        lista = por_codigo[codigo]
        salida.append(f"## {codigo} · {len(lista)} aviso(s)")
        for _, ruta, n, msg in lista[:30]:
            salida.append(f"- `{ruta}:{n}` — {msg}")
        if len(lista) > 30:
            salida.append(f"- … y {len(lista) - 30} más")
        salida.append("")
    texto = "\n".join(salida)
    print(texto)
    if a.informe:
        with open(a.informe, "w", encoding="utf-8") as f:
            f.write(texto)


if __name__ == "__main__":
    main()
