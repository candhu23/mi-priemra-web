# 🏆 Obby de las Monedas (Roblox)

Un juego de obstáculos para Roblox hecho en **un solo script**. Al pulsar Play, el script construye todo el mapa.

## Qué incluye
- **5 etapas** de saltos que suben poco a poco, con un **checkpoint** (verde) al final de cada una.
- **Plataformas rosas** que desaparecen al pisarlas.
- **Plataformas moradas** pequeñas (más difíciles).
- **Franjas de lava** que hay que saltar y un **suelo de lava** si te caes.
- **Monedas** doradas que giran y reaparecen a los 10 segundos.
- **Meta dorada**: +10 monedas, +1 victoria y vuelta al inicio.
- Tabla de puntuación con **Etapa**, **Monedas** y **Victorias**.

## Cómo probarlo
1. Abre **Roblox Studio** → *New* → plantilla **Baseplate**.
2. En el panel *Explorer*, clic derecho en **ServerScriptService** → *Insert Object* → **Script**.
3. Borra lo que trae y pega todo el contenido de [`ObbyDeLasMonedas.server.lua`](ObbyDeLasMonedas.server.lua).
4. Pulsa **Play** (F5).

> El script borra el *Baseplate* y el *SpawnLocation* de la plantilla para que caer sea peligroso.

## Personalizarlo
Al principio del script está la tabla `CONFIG`: puedes cambiar el número de etapas, la distancia entre saltos, la semilla (`SEMILLA`, genera otro recorrido), etc. Los colores están en `COLORES`.

## Publicarlo
En Roblox Studio: *File* → *Publish to Roblox*. Después, en el panel de creadores, pon el juego en **Public** para que otros puedan jugar.
