# CLAUDE.md — «Crías Míticas» (`roblox-crias-miticas/`)

Juego creado con la plantilla `.claude/skills/nuevo-juego`. Lee también el `CLAUDE.md` de la raíz
(§2 cómo es el usuario, §11 normas de Roblox, §15 herramientas de Claude).

## 1. Estado

- **Versión: 0.3** (`Config.VERSION`; súbela en cada versión). **No publicado.** Juego tipo «coleccionar mascotas»
  (idea de *Collect All Pets*, con nombres, arte y textos originales).
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
├── src/ServerScriptService/Main.server.luau  # Remotes, sesiones, montones, acciones, compras, bucle 1 s, guardado
├── src/ServerScriptService/Data.luau         # DataStore MythicHatchlings_v1 (todo en pcall; sin publicar → sin guardar)
├── src/ServerScriptService/World.luau        # 8 islas flotantes en un camino en S que sube (World.HEADINGS, RISE), puentes con puerta, huevos
├── src/StarterPlayerScripts/Client.client.luau  # Toda la interfaz (bloques do…end por pantalla)
├── src/StarterPlayerScripts/UI/Kit.luau      # Piezas de UI con estilo (botón grueso, tarjetas, escala 960×540)
├── src/StarterPlayerScripts/UI/Mundo3D.luau  # Crías de todos los jugadores, carteles de huevos/puertas, «+🪙» flotante
└── tools/  setup.sh · check.sh · harness/ (mock, run_juego, ritmo, vista_mundo, volcado, check_lang.py)
```

## 3. Arquitectura

- **El servidor manda.** Remotes en `ReplicatedStorage.MythicHatchlingsRemotes`: `Action` (RemoteFunction,
  `(acción, a, b) → (ok, claveTexto?, params?)`), `State` (estado completo cada segundo y tras cada acción),
  `Notify` (`(tipo, claveTexto, params)`). Tipos especiales: `coins` (número flotante), `rare` (a todos con `FireAllClients`:
  `{uid,name,pet,rarity}`; el cliente lo ignora si `uid` es el suyo) y `gold` (toast dorado de 5 s).
- Acciones: `target(pileId) setAuto(bool) hatch(isla, 1|3, auto) equip(uid) unequip(uid) equipBest fuse(cría, versión)
  release(uid) unlockZone(isla) teleport(isla) rebirth claimDaily claimMission(i) claimAlbum(i) finishTutorial
  setLang(""|"es"|"en") setMuted(bool)`. Límite 10/s; abrir huevo cada 0,9 s; huevo a ≤ 18 studs; montón a ≤ 70.
- Datos: `coins lifetimeCoins zones rebirths pets[{uid,kind,tier}] equipped[uid] nextUid album{"cría:versión"}
  albumClaimed{"i"} daily missions{day,list,bonusGiven} boosts{coinsUntil,luckUntil} tutorialDone receipts stats{piles,hatched,fused,rebirths}
  settings{lang,muted,auto} lastOnline`. Añadir un campo a `Data.newData()` basta (reconcile **no** entra en listas).
- `hatch` devuelve `{ hatched = { {kind, new, rarity, chance} } }`: la rareza y la probabilidad (`Config.eggOdds`, con suerte x2)
  las pone el servidor; el cliente solo dibuja el momento (normal / Épica / Legendaria-Mítica, `Config.HATCH_*`). La más
  rara del lote se anuncia al servidor si es ≥ `HATCH_BIG_FROM` (máx. 1 cada `RARE_ANNOUNCE_COOLDOWN` s; `Session.lastAnnounce`).
- Montones (`Workspace.Mundo.Montones`): los crea el servidor (14 por isla, reaparecen a los 6 s). Se eligen tocándolos
  (ClickDetector) o en modo Auto (el más cercano a ≤ 45). Cada segundo restan el poder del equipo; al romperse las monedas
  se reparten según el daño de cada jugador. Al desaparecer un montón se quita el objetivo a todos los que lo picaban.
- **Montón Dorado**: cada `GOLD_INTERVAL` s (`spawnGold` en el bucle) uno en la isla más alta abierta de cada jugador (sin
  repetir isla ni duplicar), atributo `Gold`, vida/monedas ×`GOLD_HP`/`GOLD_COINS`, no reaparece y caduca a los
  `GOLD_LIFETIME` s. Mismo reparto por daño. El cliente le pone la estrella `MarcaDorada` (Mundo3D).
- Crías en 3D: el servidor pone en cada jugador los atributos `Pets` ("cría:versión,…") y `Target` (PileId); cada cliente
  las dibuja (piezas locales, ancladas, sin colisión). Puertas: el cliente las abre localmente si ya pagó la isla; el
  servidor no deja picar montones ni abrir huevos de islas no pagadas.
- Versiones de cría: 0 normal, 1 Dorada (×3), 2 Arcoíris (×9). 5 iguales → la siguiente.
- Compras: `ProcessReceipt` idempotente (`receipts`) y solo confirma tras guardar.

## 4. Verificación (OBLIGATORIO antes de cada commit)

`roblox-crias-miticas/tools/check.sh` → compila, analiza tipos (0 avisos), textos ES/EN, juego completo con bot
(guardar/cargar, sin DataStore, inglés), capturas + auditoría de diseño (PC y móvil) y construye `MythicHatchlings.rbxl`.
**Si añades una acción, añádela a `run_juego.luau`.** Ver el mundo 3D: `lune run tools/harness/vista_mundo.luau
tools/out/test.rbxl tools/out/mundo.rbxlx` + `vista3d.py` (skill `roblox-3d-vista`).

Trampas de Lune ya resueltas en `mock.luau`: `Position` de una pieza se lee/escribe vía `CFrame`; las listas que devuelven
`GetChildren`/`GetDescendants` se envuelven; `MouseClick` es una señal. Lune no tiene `PivotTo`: el servidor mueve al
jugador con `HumanoidRootPart.CFrame` (igual de válido en Roblox). **`CFrame.lookAt` de Lune sale girado al revés**:
en el código del mundo se usa `facing()` con `CFrame.fromMatrix` (igual en Lune y en Roblox).
En Lune `math` es de solo lectura: para forzar una rareza en `run_juego.luau` se envuelve `Config.rollPet` (tabla compartida;
las probabilidades no cambian) y para no esperar 3 min se baja `Config.GOLD_INTERVAL` dentro de la prueba. Leer una pieza
**destruida** da error en Lune (en Roblox no): por eso el servidor quita el objetivo a todos al desaparecer un montón.

## 5. Pendiente

- [ ] Que el usuario lo pruebe en Studio (Play) y mande capturas: crías siguiendo, montones, huevo, puertas.
- [ ] Primera publicación en Studio (Publish to Roblox As… → experiencia NUEVA) y poner IDs en `juegos.json`.
- [ ] Crear pases/productos (`roblox-nube`); iconos ya hechos en `docs/arte/`. Pases: x2, slots, hatch3, autoHatch, backpack.
      **Ojo:** crear los packs de monedas (cash_s/cash_l) hace que los huevos se puedan pagar indirectamente con Robux →
      revisar la norma de artículos aleatorios de pago (cuestionario, PolicyService) antes.
- [ ] Arte: crías como mallas low-poly (`roblox-3d-mallas`) en vez de bola + emoji; islas más vistosas.
- [ ] Ideas: intercambio entre jugadores (con cuidado con estafas), eventos con huevo especial, clasificación.
