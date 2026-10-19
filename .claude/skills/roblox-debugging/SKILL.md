---
name: "roblox-debugging"
description: "Depurar errores y comportamientos raros en juegos de Roblox: leer Output, errores típicos de Luau, problemas cliente/servidor, breakpoints y MicroProfiler. Úsala cuando Jorge pegue un error de Roblox o diga que algo no funciona en su juego."
---

# Depuración en Roblox

## Método
1. **Reproducir**: qué hace exactamente, en Play solo o con varios clientes (Test → Clients and Servers).
2. **Leer el error completo** en Output: script, línea y la pila. Pide a Jorge que lo pegue entero si falta.
3. **¿Cliente o servidor?** El Output separa mensajes del cliente y del servidor. Mucho bug viene de hacer algo en el lado equivocado.
4. **Aislar** con `print`/`warn` o breakpoints (clic en el margen del editor, Watch, Call Stack).
5. **Arreglar la causa**, no el síntoma, y explicar por qué pasaba.

## Errores típicos y su causa habitual
- `attempt to index nil with 'X'`: el objeto aún no existe o el nombre está mal. En cliente usa `WaitForChild`; comprueba mayúsculas.
- `Infinite yield possible on 'X:WaitForChild("Y")'`: Y no existe nunca, existe en otro sitio o solo existe en el servidor (ServerStorage/ServerScriptService no se ven desde el cliente).
- El script no hace nada y no da error: está en un sitio donde no se ejecuta (LocalScript en Workspace fuera de un personaje, Script en ReplicatedStorage) o está desactivado. El Auditor JRT lo detecta.
- Cambio visible solo para un jugador: se hizo en un LocalScript; los cambios del cliente no se replican al servidor.
- RemoteEvent «no llega»: escucha en el lado equivocado (`OnServerEvent` vs `OnClientEvent`), el Remote se creó en el cliente, o el primer argumento en el servidor es siempre el jugador.
- Algo se cae al empezar: piezas sin anclar ni soldar.
- Funciona en Studio pero no en el juego publicado: API Services/HTTP desactivados en el juego, permisos de assets, o diferencias de tiempo de carga (usa WaitForChild).
- Lag progresivo: conexiones que nunca se desconectan o bucles que crean instancias sin destruirlas. Mira Developer Console (F9) → Memory.

## Rendimiento
- MicroProfiler (Ctrl+Alt+F6 en el cliente) para ver qué tarda en cada frame.
- Script Performance en Studio para ver qué scripts consumen más.

## Al responder
Da la causa más probable primero, cómo comprobarla y el arreglo. Indica a Jorge tu nivel de confianza (%) y qué información falta (código completo, dónde está el script, si es cliente o servidor).