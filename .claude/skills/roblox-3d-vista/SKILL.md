---
name: roblox-3d-vista
description: Permite VER lo que hay construido en 3D en un juego de Roblox sin abrir Studio y revisarlo — volcar.luau ejecuta en Lune el código que construye (mapas, edificios, zonas) y vuelca las piezas; vista3d.py lo dibuja en PNG (isométrica, frente, lado, arriba o las 4) desde ese volcado o desde un .rbxlx/.rbxmx, y avisa de piezas que parpadean (caras en el mismo plano), piezas sin anclar que se caerán, demasiadas piezas o luces y neón excesivo. Úsala siempre que crees o cambies cosas 3D por código, cuando el usuario pregunte "¿cómo queda?", "enséñame el mapa", o antes de publicar cambios del mundo.
---

# roblox-3d-vista — ver y revisar el 3D sin Studio

Archivos en la carpeta de esta skill: `volcar.luau` (Lune) y `vista3d.py` (numpy + Pillow).
Lune 0.10.x: `https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip` (descomprimir y `chmod +x lune`).

## 1. Volcar lo que construye un script
```bash
# El módulo devuelve una función (o tabla con .construir): se le llama con workspace
lune run volcar.luau src/ServerScriptService/Mundo.luau out.json --modulo ReplicatedStorage/Constructor=src/ReplicatedStorage/Constructor.luau
# O código suelto con M = el módulo
lune run volcar.luau Constructor.luau out.json --codigo "M.casa(workspace, CFrame.new()); M.arbol(workspace, Vector3.new(20,0,0), {})"
```
- `--modulo Servicio/Nombre=ruta` (repetible) registra los ModuleScripts que el código pide con `require`.
- Lune valida nombres y tipos de propiedades: un error aquí = un error que también saldría en Roblox.
- No simula: Terrain, física, eventos ni esperas reales (`task.wait` para los bucles; lo construido antes se vuelca igual).

**Lugar ya hecho** (piezas colocadas a mano en Studio): con Rojo `rojo build -o lugar.rbxlx` y pásale el `.rbxlx` a vista3d.py. Un `.rbxmx` (modelo exportado desde Studio: clic derecho → Save to File → .rbxmx) también vale.

## 2. Dibujar y revisar
```bash
python3 vista3d.py out.json vista.png --vista todas --informe revision.md   # hoja 2×2: iso, frente, lado, arriba
python3 vista3d.py lugar.rbxlx mapa.png --vista arriba --filtro Zona2           # solo lo que contenga «Zona2» en su ruta
```
Después **mira el PNG con Read**. Las piezas transparentes salen translúcidas; el contorno oscuro separa piezas.

## 3. Qué revisa
| Aviso | Qué significa | Arreglo |
|---|---|---|
| caras en el mismo plano | en Roblox **parpadean** (z-fighting) | separa 0,01–0,1 o mete una pieza dentro de la otra |
| piezas SIN anclar | se caerán o se moverán con la física | `Anchored = true` (o `Constructor.optimizar`) |
| > 2.000 / 5.000 piezas | lento en móviles | junta piezas, usa MeshParts (roblox-3d-mallas), StreamingEnabled |
| > 40 luces | caro en móvil | quita luces o `Shadows = false` |
| mucho Neon | todo brilla = nada destaca | resérvalo para lo importante |
También imprime el tamaño total en studs y los materiales más usados (útil para comprobar escala: un personaje mide ~5 studs).

## Límites (dilo al usuario)
Es una aproximación: sin texturas, sin sombras proyectadas, sin Terrain; MeshParts y Unions se dibujan como su caja; una pieza
con SpecialMesh de esfera se dibuja como elipsoide. Sirve para forma, proporciones, colores y colocación. Confianza alta en
geometría y colores; el aspecto con la iluminación de Roblox puede variar.
