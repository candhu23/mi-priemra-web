# 👽 Steal an Alien

Juego de Roblox del género **"Steal a ..."** (compra, genera dinero, roba a otros jugadores), el formato con más éxito de 2025-2026.
El estudio de mercado y el plan para ganar dinero están en [`ESTRATEGIA.md`](ESTRATEGIA.md).

## Cómo se juega
1. Por la **cinta central** pasan aliens. Mantén **E** para comprar los que puedas pagar.
2. Cada alien de tu base genera dinero por segundo. Pisa la **placa verde** de tu base para cobrar.
3. Entra en otras bases y mantén **E** sobre un alien para **robarlo**. Corre a tu base: si el dueño te alcanza, lo recupera.
4. Pisa la **placa roja** para cerrar tu base con un láser (60 s, 120 s con VIP).
5. Plaza: **⚡ Speed** (más velocidad) y **🌌 Rebirth** (reinicia, pero +50 % de ingresos para siempre).
6. Cada 10 minutos hay un evento gratuito **🍀 Lucky Belt** (aliens raros x4).
7. Pulsa **F** sobre tus aliens para venderlos a mitad de precio.

Se guarda el progreso (dinero, aliens, rebirths, velocidad).

## Instalación en Roblox Studio (copiar y pegar)
1. Roblox Studio → **New** → plantilla **Baseplate**.
2. *Explorer* → clic derecho en **ServerScriptService** → *Insert Object* → **Script**. Pega `src/ServerScriptService/Juego.server.lua`.
3. *Explorer* → **StarterPlayer** → clic derecho en **StarterPlayerScripts** → *Insert Object* → **LocalScript**. Pega `src/StarterPlayerScripts/Interfaz.client.lua`.
4. *Home* → **Game Settings** → *Security* → activa **Enable Studio Access to API Services** (para probar el guardado).
5. Para probar el robo necesitas 2 jugadores: pestaña *Test* → *Clients and Servers* → **2 Players** → *Start*.

> Alternativa para programadores: el proyecto es compatible con [Rojo](https://rojo.space) (`rojo serve`).

## Activar la monetización
1. Publica el juego: *File* → **Publish to Roblox**.
2. En el [Creator Hub](https://create.roblox.com/dashboard/creations) → tu juego → **Monetization**:
   - **Passes**: crea *2x Cash* y *VIP*.
   - **Developer Products**: crea *Cash Pack*, *Mega Cash* y *Server Luck*.
3. Copia cada ID en la tabla `MONETIZACION` al principio de `Juego.server.lua`. Mientras un ID sea `0`, ese botón de la tienda sale como "Coming soon".

Precios orientativos (ajústalos según tus datos): 2x Cash 199 R$ · VIP 349 R$ · Server Luck 99 R$ · Cash Pack 49 R$ · Mega Cash 199 R$.

## Personalizar
- `CONFIG`: velocidades, tiempos, duración del candado, eventos de suerte.
- `ALIENS`: añade aliens nuevos (nombre, rareza, precio, ingreso, color, tamaño). **Añadir aliens nuevos cada semana es la actualización más barata y eficaz.**
- `RAREZAS`: probabilidades de cada rareza.

## Limitaciones conocidas
- Los aliens son figuras sencillas hechas con piezas. Para competir de verdad hacen falta modelos 3D atractivos, un icono y miniaturas de calidad.
- No se ha podido probar dentro de Roblox Studio (solo se ha validado la sintaxis).
