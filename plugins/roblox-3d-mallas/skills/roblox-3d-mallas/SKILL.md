---
name: roblox-3d-mallas
description: Genera modelos 3D low-poly estilo cartoon para importar en Roblox Studio como MeshParts (mallas.py → .glb + .obj + vista previa PNG) — huevo con manchas, moneda, gema, cristales, roca, árbol, pino, seta, cofre, mascota (gatito), estrella y nube, con colores por parte, tamaño en studs y semilla para variantes. Explica cómo importarlos, colorearlos y usarlos (huevos y monedas de simuladores, decoración, mascotas). Úsala cuando el usuario pida "un modelo 3D", "una mascota", "un huevo/moneda/cofre en 3D", "mallas", "meshes", "algo más bonito que bloques", o cuando un objeto hecho con piezas quede pobre o use demasiadas piezas.
---

# roblox-3d-mallas — modelos 3D listos para importar

`mallas.py` (carpeta de esta skill). Necesita `numpy` y `Pillow`.
```bash
python3 mallas.py lista                                   # modelos y nombres de sus partes
python3 mallas.py todos salida/                           # todos + salida/catalogo.png
python3 mallas.py huevo salida/ --tamano 5 --semilla 3 --color cuerpo=#7ad7ff --color manchas=#ffffff
```
Por modelo: `<nombre>.glb` (una malla por color), `<nombre>.obj` + `.mtl` (alternativa) y `<nombre>.png` (vista previa con nº de triángulos).
**Mira siempre el PNG** (Read) antes de dárselo al usuario.

| Modelo | Partes (para `--color`) | Para qué |
|---|---|---|
| huevo | cuerpo, manchas | huevos de mascotas (un color por huevo/zona) |
| moneda | canto, caras, simbolo | monedas para recoger, iconos 3D |
| gema / cristales | gema · cristales, base | moneda premium, decoración de cuevas |
| roca · arbol · pino · seta · nube | … | decoración low-poly (pocas caras: perfectas para móvil) |
| cofre | madera, metal | recompensas, cofres diarios |
| mascota | pelo, ojos, brillo, mejillas | mascota base (cámbiale el color de `pelo` para variantes) |
| estrella | estrella | premios, rarezas, «nivel subido» |

## Importar en Roblox Studio (díselo al usuario paso a paso)
1. Descarga el `.glb` (si el usuario no lo tiene, súbelo al repo y dale el enlace `raw` de GitHub).
2. Studio → pestaña **Home** (o Avatar) → **Import 3D** → elige el `.glb` → revisa la vista → **Import**.
3. Aparece un Model con un MeshPart por parte (cada uno con su color). Agrúpalo, ponle nombre y `Anchored = true`.
4. Si se ve oscuro o sin color: selecciona cada MeshPart y ponle `Color` a mano (el nombre de la parte dice cuál es) y Material SmoothPlastic.
5. Guárdalo en ReplicatedStorage/ServerStorage como plantilla y **clónalo** por código (no lo importes 100 veces).
Alternativa: el `.obj` se importa igual. Para subirlo sin Studio hace falta la API Open Cloud de assets (no incluida aquí).

## Reglas
- Presupuesto: < 2.000 triángulos para objetos que se repiten mucho (monedas, mascotas equipadas), < 10.000 para piezas únicas. Roblox admite hasta ~20.000 por malla.
- Mascotas: mismo modelo base con distintos colores/accesorios = muchas mascotas con poco trabajo. Las raras con aura (skill **roblox-3d-ambiente**: `Ambiente.aura`).
- Colisión: decoración `CanCollide = false`; si hace falta chocar, `CollisionFidelity = Box` (barato).
- El estilo es facetado (low-poly). Si el usuario quiere algo realista o con texturas, hace falta Blender o la tienda de Roblox: dilo.
- Comprobado: los .glb y .obj se leen bien con un lector externo (trimesh) y la vista previa se dibuja; **no** se ha probado el importador de Studio desde aquí → confianza media sobre cómo pinta los colores: pide captura al usuario la primera vez.

## Añadir un modelo nuevo
Escribe una función `m_nombre(rng)` en `mallas.py` que devuelva `{parte: ((v, t), "#color", metalico)}` usando las primitivas
`torno(perfil)`, `icosfera(sub)`, `caja(x,y,z)`, `prisma(poligono, alto)`, `mover(…, escala, rot, pos)`, `juntar(…)`, y añádela a `MODELOS`.
Las caras se orientan solas hacia fuera de cada trozo. Genera, mira el PNG y ajusta.
