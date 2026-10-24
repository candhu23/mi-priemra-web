# CLAUDE.md — «Crías Míticas» (`roblox-crias-miticas/`)

Juego creado con la plantilla `.claude/skills/nuevo-juego`. Lee también el `CLAUDE.md` de la raíz
(§2 cómo es el usuario, §11 normas de Roblox, §15 herramientas de Claude).

## 1. Estado

- **Versión: 0.1** (`Config.VERSION`; súbela en cada versión). **No publicado.**
- Nombre en inglés: *Mythic Hatchlings*. Rama de trabajo: `claude/confident-johnson-v5zy5f`.
- Descarga del lugar: `https://github.com/candhu23/mi-priemra-web/raw/claude/confident-johnson-v5zy5f/roblox-crias-miticas/MythicHatchlings.rbxl`
- Diseño del juego (qué es, bucle, economía, tienda): **`DISENO.md`** (rellénalo con la skill `disenar-juego`).

## 2. Estructura

```
roblox-crias-miticas/
├── default.project.json        # Rojo (Lighting.Technology = Future)
├── MythicHatchlings.rbxl                    # Lo genera tools/check.sh (súbelo en cada commit)
├── DISENO.md                   # Documento de diseño
├── src/ReplicatedStorage/Config.luau   # TODOS los números, tienda (id = 0 → no se vende), colores, fórmulas
├── src/ReplicatedStorage/Lang.luau     # Textos ES/EN. El servidor manda claves; el cliente traduce
├── src/ServerScriptService/Main.server.luau  # Remotes, sesiones, acciones, compras, bucle 1 s, guardado
├── src/ServerScriptService/Data.luau         # DataStore MythicHatchlings_v1 (todo en pcall; sin publicar → sin guardar)
├── src/StarterPlayerScripts/Client.client.luau  # Toda la interfaz
├── src/StarterPlayerScripts/UI/Kit.luau      # Piezas de UI con estilo (botón grueso, tarjetas, escala 960×540)
└── tools/  setup.sh · check.sh · harness/ (mock.luau, run_juego.luau, volcado.luau, check_lang.py)
```

## 3. Arquitectura

- **El servidor manda.** Remotes en `ReplicatedStorage.MythicHatchlingsRemotes`: `Action` (RemoteFunction,
  `(acción, a, b) → (ok, claveTexto?, params?)`), `State` (estado completo cada segundo y tras cada acción),
  `Notify` (`(tipo, claveTexto, params)`).
- Acciones: `click buy(id) upgradeClick claimDaily setLang(""|"es"|"en") setMuted(bool)`. Límite 10/s (clic 15/s).
- Datos: `money lifetimeEarned generators{} clickLevel daily{lastDay,streak} receipts{} stats settings lastOnline`.
  Añadir un campo a `Data.newData()` basta: las partidas viejas lo reciben solas.
- Compras: `ProcessReceipt` idempotente (`receipts`) y solo confirma tras guardar.

## 4. Verificación (OBLIGATORIO antes de cada commit)

`roblox-crias-miticas/tools/check.sh` → compila, analiza tipos (0 avisos), textos ES/EN, juego completo con bot
(guardar/cargar, sin DataStore, inglés), capturas + auditoría de diseño (PC y móvil) y construye `MythicHatchlings.rbxl`.
**Si añades una acción, añádela a `run_juego.luau`.**

## 5. Pendiente

- [ ] Rellenar `DISENO.md` y cambiar el tema (negocios, textos, colores) con la skill `disenar-juego`.
- [ ] Primera publicación en Studio (Publish to Roblox As… → experiencia NUEVA) y poner IDs en `juegos.json`.
- [ ] Crear pases/productos (`roblox-nube`) e iconos (`arte-roblox`).
