#!/usr/bin/env python3
"""Convierte los capítulos .md de la temporada 6 al formato del artefacto «Biblioteca».

Uso:  python3 construir_biblioteca.py
Genera, junto a este script:
  - ultimo-reino-t6.json        (el libro: capítulos en HTML)
  - ultimo-reino-t6.extra.json  (resúmenes y personajes, copiados de t6.extra.json)
  - entrada-indice.json         (la ficha que hay que añadir a libros/index.json del artefacto)
"""
import html
import json
import re
from pathlib import Path

AQUI = Path(__file__).resolve().parent
CAPS = AQUI.parent / "capitulos"
ID = "ultimo-reino-t6"

# (archivo, episodio, título que se muestra)
ORDEN = [
    (None, "Antes de empezar", "Dónde lo dejamos"),
    ("00-prologo-manos-que-no-son-las-mias.md", "PRÓLOGO", "Manos que no son las mías"),
    ("01-el-hijo-escondido.md", "EPISODIO 1", "Capítulo 1. El hijo escondido"),
    ("02-la-isla-santa.md", "EPISODIO 2", "Capítulo 2. La isla santa"),
    ("03-tierras-y-casas.md", "EPISODIO 3", "Capítulo 3. Tierras y casas"),
    ("04-la-flecha.md", "EPISODIO 4", "Capítulo 4. La flecha"),
    ("05-bakewell.md", "EPISODIO 5", "Capítulo 5. Bakewell"),
    ("06-el-tuerto.md", "EPISODIO 6", "Capítulo 6. El Tuerto"),
    ("07-ceaster.md", "EPISODIO 7", "Capítulo 7. Ceaster"),
    ("08-farndon.md", "EPISODIO 8", "Capítulo 8. Farndon"),
    ("09-dieciseis-dias.md", "EPISODIO 9", "Capítulo 9. Dieciséis días"),
    ("10-sangre-de-reyes.md", "EPISODIO 10", "Capítulo 10. Sangre de reyes"),
]

DONDE_LO_DEJAMOS = """Al final de la temporada 5, Uhtred, hijo de Uhtred, recuperó por fin Bebbanburg, la fortaleza que le robaron de niño. Entró por la puerta del mar con Finan y Sihtric, mató a su primo Wihtgar y vio morir a Aethelhelm, el enemigo de toda su vida. Los daneses que Stiorra trajo del bosque cambiaron la batalla, Constantín de Escocia se retiró y una lluvia salvó la fortaleza del incendio.

Antes, en esa misma temporada, Uhtred había perdido a Aethelflaed, que murió en sus brazos, y a Osferth. A su hijo, el padre Uhtred, Brida lo castró. Sigtryggr murió a manos de Uhtred, porque él mismo se lo pidió, y Stiorra mató a Brida de un flechazo.

En el banquete de la victoria, Uhtred hizo un trato. Reconoció al rey Eduardo como su señor y le prometió homenaje, pero le dijo a la cara que estas tierras «no serán parte de Inglaterra mientras tú vivas». A los daneses les juró tierras y casas. Eduardo, humillado y agradecido a la vez, lo aceptó.

Eadith se quedó para cuidar a los heridos: «quizá». Lady Aelswith pidió habitaciones con vistas al mar. Y por la playa, de la mano de la madre Hild, llegaba un muchacho llamado Osbert, que no sabía quién era su padre.

Esta continuación ignora la película «Siete reyes deben morir»."""

CURSIVA = re.compile(r"\*(.+?)\*")
NEGRITA = re.compile(r"\*\*(.+?)\*\*")


def a_html(md: str) -> str:
    # Quita los encabezados (#, ##): el título ya lo pone la Biblioteca
    lineas = [l for l in md.splitlines() if not l.startswith("#")]
    bloques = re.split(r"\n\s*\n", "\n".join(lineas).strip())
    out = []
    for b in bloques:
        b = " ".join(x.strip() for x in b.splitlines()).strip()
        if not b:
            continue
        if re.fullmatch(r"-{3,}|\*{3,}", b):
            out.append("<hr>")
            continue
        t = html.escape(b, quote=False)
        t = NEGRITA.sub(r"<strong>\1</strong>", t)
        t = CURSIVA.sub(r"<em>\1</em>", t)
        # Rótulos de lugar y tiempo («Winchester, cinco semanas después»): cortos y sin punto final
        if not t.startswith("<em>") and len(b.split()) <= 9 and not re.search(r"[.!?…»:;—]$", b):
            t = f"<em>{t}</em>"
        out.append(f"<p>{t}</p>")
    return "\n".join(out)


def contar(htmltxt: str) -> int:
    return len(re.sub(r"<[^>]+>", " ", htmltxt).split())


def main():
    caps = []
    for archivo, ep, titulo in ORDEN:
        md = DONDE_LO_DEJAMOS if archivo is None else (CAPS / archivo).read_text(encoding="utf-8")
        caps.append({"episode": ep, "title": titulo, "html": a_html(md)})
    palabras = sum(contar(c["html"]) for c in caps)
    meta = {
        "id": ID,
        "title": "El Último Reino",
        "subtitle": "Temporada 6 — Mientras viva el rey",
        "kind": "Continuación de fans (no oficial)",
        "date": "2026-10-21",
        "words": palabras,
        "pages": round(palabras / 215),
        "synopsis": ("Uhtred tiene por fin Bebbanburg y le ha prometido al rey Eduardo que Northumbria no será parte de "
                     "Inglaterra mientras él viva. Pero un muchacho que no sabe quién es su padre acaba de llegar a la "
                     "fortaleza, una flecha de Stiorra aparece clavada en el pecho de un rey, y en Winchester un hombre "
                     "gordo y amable empieza a tejer. Cuando el rey tose sangre, todos empiezan a contar los días: "
                     "mientras viva el rey, la promesa vale. ¿Y después?"),
        "note": ("Obra de fans sin ánimo de lucro. Los personajes y el mundo de The Last Kingdom pertenecen a Bernard "
                 "Cornwell y a los productores de la serie (Carnival Films, BBC y Netflix). Ignora la película "
                 "«Siete reyes deben morir»."),
        "file": f"libros/{ID}.json",
        "chapters": len(caps),
        "color": "#7A2A1E",
        "spine": "El Último Reino · T6",
    }
    libro = dict(meta)
    libro["chapters"] = caps
    (AQUI / f"{ID}.json").write_text(json.dumps(libro, ensure_ascii=False), encoding="utf-8")
    extra = json.loads((AQUI / "t6.extra.json").read_text(encoding="utf-8"))
    assert len(extra["summaries"]) == len(caps), (len(extra["summaries"]), len(caps))
    (AQUI / f"{ID}.extra.json").write_text(json.dumps(extra, ensure_ascii=False), encoding="utf-8")
    (AQUI / "entrada-indice.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(caps)} capítulos · {palabras} palabras · {meta['pages']} páginas")


if __name__ == "__main__":
    main()
