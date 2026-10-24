---
name: roblox-3d-ambiente
description: Iluminación, ambiente y efectos 3D para juegos de Roblox con Ambiente.luau — 8 presets probados (soleado, atardecer, noche, mágico, caramelo, cueva, espacio, submarino) con Atmosphere, ColorCorrection, Bloom y SunRays, transiciones suaves por zona, ciclo día/noche, desenfoque de fondo, y recetas de partículas (destellos, humo, fuego, magia, monedas, confeti, polvo), auras por rareza para mascotas, estallidos, estelas, haces, resaltado y neón. Úsala cuando el usuario diga "se ve plano/feo/oscuro", "ponle luces", "efectos", "partículas", "brillos", "que la mascota legendaria brille", "de noche", o al dar el toque final a un mapa.
---

# roblox-3d-ambiente — Ambiente

`Ambiente.luau` (carpeta de esta skill) → ReplicatedStorage (sirve en servidor y cliente). Sin dependencias.
**Antes**: en Studio pon `Lighting.Technology = Future` (no se puede por script; con Rojo va en `default.project.json`).

## API
| Función | Hace |
|---|---|
| `Ambiente.preset("soleado")` | aplica luz + Atmosphere + ColorCorrection + Bloom + SunRays (crea lo que falte) |
| `Ambiente.transicion("magico", 2)` | cambio suave (úsalo en el CLIENTE al entrar en una zona) |
| `Ambiente.cicloDiaNoche(960, 2)` | día de 16 min, la noche pasa ×2 (servidor). Devuelve `parar()` |
| `Ambiente.desenfoqueFondo(0.25)` | fondo ligeramente borroso, look «de juguete» (cliente) |
| `Ambiente.particulas(pieza, "destellos", {color, ritmo, tamano})` | recetas: destellos, humo, fuego, magia, monedas, confeti, polvo |
| `Ambiente.aura(pieza, "Legendario")` | aura de rareza (las comunes no llevan; Legendario+ con luz; Secreto arcoíris) |
| `Ambiente.estallido(pos, "monedas", 40, color?)` | explosión puntual que se borra sola (abrir huevo, recoger) |
| `Ambiente.estela(pieza, color)` · `Ambiente.haz(a, b, color)` | rastro de movimiento · rayo entre dos piezas |
| `Ambiente.resaltar(objeto, color)` · `Ambiente.neon(pieza, color)` | contorno (lo que se puede recoger/seleccionado) · brillo con luz |

## Recetas por tipo de juego
- **Simulador de mascotas**: `soleado` en la zona 1, `caramelo`/`magico` en zonas avanzadas (transición al cruzar la puerta); monedas con `destellos`; mascotas raras con `aura`; abrir huevo → `estallido(pos, "confeti")`.
- **Tycoon**: `soleado` + `cicloDiaNoche` (de noche luces de neón en los edificios = se ve que «creces»).
- **Obby**: `atardecer` o `espacio`; checkpoints con `neon` verde y `estallido` al tocarlos.
- **Terror suave / cueva**: `cueva` + `polvo` + farolas (PointLight) para guiar.

## Reglas
- Un preset por zona; cambia el ambiente al cambiar de zona: refuerza la sensación de progreso.
- Partículas: pocas y con sentido. En móvil, < ~20 emisores activos cerca y `Rate` bajo. Las de premio, con `Emit` puntual, no continuas.
- Luces: `Shadows = false` en PointLights decorativas; < 40 luces visibles a la vez.
- Neón con moderación: marca lo importante (lo que se puede tocar, el siguiente objetivo).
- Texturas de partículas: usa las de Roblox (`rbxasset://textures/particles/…`, ya incluidas) o sube las tuyas.

## Comprobar
Los nombres y tipos de todas las propiedades se validan en Lune (`volcar.luau` de roblox-3d-vista ejecuta el módulo con instancias reales).
El aspecto final (colores de cielo, bloom) solo se ve en Studio: pide una captura al usuario. Confianza alta en que funciona; media en
que el preset le guste a la primera: ofrece cambiar entre 2–3 presets.
