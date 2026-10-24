---
name: roblox-3d-construir
description: Construye cosas 3D en Roblox con código (Constructor.luau) con buen aspecto y rendimiento — piezas, bloques, cilindros de pie, esferas, cuñas, vigas entre puntos, carteles flotantes, y recetas completas (casa con tejado, árboles redondo/pino/palmera, valla, escalera, camino, farola, puerta de zona con precio, pedestal de huevo, isla flotante, rocas), repeticiones en círculo/rejilla y optimización. Úsala cuando haya que crear el mapa, edificios, decoración, zonas de un simulador, lobbies u obbies por script, o cuando el usuario diga "haz el mundo", "pon casas/árboles", "una zona nueva", "decora el mapa".
---

# roblox-3d-construir — Constructor

`Constructor.luau` (carpeta de esta skill) → ServerScriptService o ReplicatedStorage. Sin dependencias.
Funciona también en **Lune**, así que lo construido se puede DIBUJAR sin Studio con la skill **roblox-3d-vista**.

## API
**Básicas** (todas ancladas, plástico liso, colores de `C.paleta`):
`C.modelo(nombre, padre)` · `C.pieza(padre, props)` · `C.bloque(padre, base, tam, color?, material?, giroY?)` (base = centro de ABAJO) ·
`C.cilindro(padre, base, alto, diametro, …)` (ya de pie) · `C.esfera(padre, centro, d, …)` · `C.cuna(padre, cf, tam, color)` (alta en +Z, baja hacia −Z) ·
`C.viga(padre, a, b, grosor, …)` · `C.cartel(pieza, "texto", alto?, color?)` (BillboardGui)

**Recetas** (origen = centro del suelo; devuelven un Model):
`C.casa(padre, CFrame, {ancho, fondo, alto, color, colorTejado})` · `C.arbol(padre, base, {alto, estilo="redondo"|"pino"|"palmera"})` ·
`C.valla(padre, a, b)` · `C.escalera(padre, base, dir, alto)` · `C.camino(padre, {puntos}, ancho?)` · `C.farola(padre, base)` ·
`C.puertaZona(padre, CFrame, {ancho, alto, texto="Zona 2 · 500 💰"})` · `C.pedestalHuevo(padre, base, {color, texto})` ·
`C.isla(padre, centro, radio)` · `C.roca(padre, base, tam, semilla)`

**Utilidades**: `C.enCirculo(n, radio, centro, f)` · `C.enRejilla(cols, filas, sep, origen, f)` · `C.optimizar(modelo)` (devuelve nº de piezas) · `C.recolorear(modelo, de, a)`

## Ejemplo (Script del servidor)
```lua
local C = require(game.ServerScriptService.Constructor)
local mundo = C.modelo("Zona1", workspace)
C.bloque(mundo, Vector3.new(0, -1, 0), Vector3.new(200, 1, 200), C.paleta.cesped, Enum.Material.Grass)
C.casa(mundo, CFrame.new(-40, 0, 30), { color = C.paleta.rosa })
C.enCirculo(10, 80, Vector3.zero, function(p) C.arbol(mundo, p, { alto = math.random(10, 16) }) end)
C.pedestalHuevo(mundo, Vector3.new(0, 0, -30), { texto = "Huevo Básico · 100 💰" })
C.puertaZona(mundo, CFrame.new(0, 0, -95), { texto = "🔒 Zona 2 · 1.000 💰" })
print("piezas:", C.optimizar(mundo))
```

## Reglas de construcción (aspecto y rendimiento)
- **Estilo**: formas simples y grandes, colores de la paleta (saturados pero no chillones), materiales lisos (SmoothPlastic, Grass, Wood, Slate). Un objeto = 2–3 colores. Proporciones exageradas (cartoon): puertas grandes, tejados altos.
- **Escala Roblox**: un personaje mide ~5 studs. Puertas 7–8 de alto, pasillos ≥ 8 de ancho, saltos ≤ 7 de alto y ≤ 12 de largo.
- **Parpadeo (z-fighting)**: dos caras en el mismo plano parpadean. Separa 0,01–0,1 o mete una pieza dentro de la otra. `roblox-3d-vista` lo detecta.
- **Rendimiento móvil**: < 5.000 piezas por zona visible; decoración pequeña sin colisión ni sombra (`C.optimizar`); repite modelos (clona) en vez de piezas sueltas; para formas complejas usa MeshParts (skill **roblox-3d-mallas**); activa StreamingEnabled en mapas grandes.
- **Orden**: todo dentro de Models con nombre claro (`Zona1/Casas/Casa3`); lo que el servidor toca (puertas, huevos) con nombre fijo o Attributes, no por posición.
- Generar por script cada partida está bien para mundos procedurales; si es un mapa fijo, ejecútalo una vez en Studio (barra de comandos) y guarda el lugar.

## Comprobar
Dibuja lo que construyes (skill **roblox-3d-vista**):
`lune run volcar.luau Constructor.luau out.json --codigo "M.casa(workspace, CFrame.new())"` → `python3 vista3d.py out.json vista.png --vista todas` → mira el PNG.
