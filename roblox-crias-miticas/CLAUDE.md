# CLAUDE.md — «Crías Míticas» (`roblox-crias-miticas/`)

Juego creado con la plantilla `.claude/skills/nuevo-juego`. Lee también el `CLAUDE.md` de la raíz
(§2 cómo es el usuario, §11 normas de Roblox, §15 herramientas de Claude).

## 1. Estado

- **Versión: 0.4** (`Config.VERSION`; súbela en cada versión). **No publicado.** Juego tipo «coleccionar mascotas»
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
├── src/ServerScriptService/Data.luau         # DataStore MythicHatchlings_v2 (todo en pcall; sin publicar → sin guardar)
├── src/ServerScriptService/World.luau        # Mapa continuo: 9 zonas (World.GRID 3×3 lleno, 200×200) con acantilados, puertas en las paredes,
│                                             #   decoración por tema, huevo por rareza sobre pilar, World.crystal (cristales),
│                                             #   Jardín de Mejoras (casilla (-1,0)), Altares de Fusión y cielo de aurora (zona 9)
├── src/StarterPlayerScripts/Client.client.luau  # Toda la interfaz (bloques do…end por pantalla)
├── src/StarterPlayerScripts/UI/Kit.luau      # Piezas de UI con estilo (botón grueso, tarjetas, escala 960×540)
├── src/StarterPlayerScripts/UI/Mundo3D.luau  # Crías (animales del pack o bolas), carteles de huevos/puertas/pedestales/altares,
│                                             #   colores del Jardín por jugador, «+🪙» flotante
├── modelos/                    # CriasMiticas_Modelos.glb (Kenney + Quaternius, CC0; tools/modelos/construir_pack.py) + LEEME.md (importarlo en Studio) + vista
└── tools/  setup.sh · check.sh · harness/ (mock, run_juego, ritmo, vista_mundo, volcado, check_lang.py)
```

## 3. Arquitectura

- **El servidor manda.** Remotes en `ReplicatedStorage.MythicHatchlingsRemotes`: `Action` (RemoteFunction,
  `(acción, a, b) → (ok, claveTexto?, params?)`), `State` (estado completo cada segundo y tras cada acción),
  `Notify` (`(tipo, claveTexto, params)`). Tipos especiales: `coins` (número flotante), `rare` (a todos con `FireAllClients`:
  `{uid,name,pet,rarity}`; el cliente lo ignora si `uid` es el suyo) y `gold` (toast dorado de 5 s).
- Acciones: `target(pileId) setAuto(bool) hatch(isla, 1|3, auto) equip(uid) unequip(uid) equipBest fuse(isla, rareza, brillante)
  fuseAll release(uid) releaseDupes unlockZone(isla) teleport(isla|0 = Jardín) buyUpgrade(id) claimDaily claimMission(i) claimAlbum(i) finishTutorial
  setLang(""|"es"|"en") setMuted(bool)`. Límite 10/s; abrir huevo cada `Config.hatchCooldown` (0,9 s; 0,7 con mejora);
  huevo a ≤ 18 studs; montón a ≤ 70; fusionar a ≤ `FUSE_REACH` (20) de un altar (`FUSE_NEEDS_ALTAR = true`, confirmado por el
  usuario). **Ya no existe `rebirth`.**
- **Mundo de la ronda 2b**: Jardín de Mejoras en la casilla (-1,0) (`World.garden`, modelo «Jardin»), paso desde la zona 1 por un
  hueco sin puerta con arco de hojas. 12 «Pedestal» (atributo `UpgradeId`, etiqueta `Upgrade`, hijos «Orbe»/«Anillo» con el
  mismo atributo, ProximityPrompt `PROMPT_REACH` con 0,5 s: el servidor lo conecta a `buyUpgrade` y responde con un aviso) en
  `Config.Upgrades[i].pos`; 14 «Camino» de neón (`From`/`To`, etiqueta `UpgradeLink`); «CartelJardin». 2 Altares de Fusión
  («Altar», etiqueta `FuseStation`, ProximityPrompt; `World.altars`/`altarParts`): zona 1 junto a la aparición y en el Jardín;
  el prompt lo escucha el CLIENTE (`Mundo3D.onAltar` → ventana Crías con «Fusionar todo»). Colores del Jardín en el cliente:
  verde neón comprado, amarillo con pulso se puede, gris bloqueado; camino verde si sus dos extremos están comprados.
  `World.pedestals[id]` = punto para `UPGRADE_REACH`; la ventana 🌳 solo compra estando al lado (si no, «🌳 Ir»).
- Huevo (`makeEgg`): con modelos, caja invisible «Huevo» + modelo «Huevo» (`eggShell`/`eggSpots` de `Config.EggColors`);
  sin modelos, elipsoide con `spotCount` «Mancha»; luz desde Épico, manchas de neón en Legendario/Prodigioso.
- Crías con modelos (solo `ReplicatedStorage.Modelos`: el cliente no ve ServerStorage): `Mundo3D` normaliza cada modelo una vez
  (plantilla), clona sus piezas al cambiar el equipo y cada frame solo las mueve (ancla «Cria» invisible + piezas dentro);
  altura `PET_MODEL_HEIGHT × rareza`, pieza más grande con el color de la cría, el resto tirando a él; `PET_MODEL_YAW` por si
  andan de espaldas. «Soltar repetidas»: `Config.dupesToRelease` (Míticas o crías de rareza ≤ huevo de islas anteriores, nunca equipadas, Brillantes
  ni la última normal de cada especie).
- **Rarezas por fusión** (ficha `propuestas/2026-10-26-rarezas-arbol.md`): 8 rarezas (`Config.Rarities`, poder ×3, `fuseNeed`
  5/5/5/5/5/3/3), 72 crías (`Config.Zones[i].pets` con `rarity`, `model`, `color`). Cada huevo da una rareza (`eggRarity`) y
  1–6 especies al mismo %. `fuse`/`fuseAll`: misma isla + rareza + Brillante → la siguiente de esa isla (`Config.fuseResult`);
  gasta primero las no equipadas y la especie con más copias; si gasta equipadas, `equipBest`. Crear una Mítica da
  `stones += 1` en la misma fusión (+ aviso `n_stone` y `rare`/`n_mythic_made` a todos). `fuseAll` tope `FUSE_ALL_MAX`.
- **Brillante**: `Config.shinyChance` (1 % × isla 9 ×2 × suerte ×2 × mejora ×1,5), ×2 de poder; `shinyIndex[kind]` y
  `Config.shinyScore` (no baja). Puertas: `Config.zoneNeed` (`needDiscovered` o `needShiny` en la 9), sin monedas.
- **Mejoras** (`Config.Upgrades`, 12, `effects`, `req`, `cost` en 🪨): `buyUpgrade` valida id, no comprada, requisitos y
  piedras (`Config.canBuyUpgrade`); con `UPGRADE_NEEDS_PEDESTAL = true` (ronda 2b) también ≤ `UPGRADE_REACH` de `World.pedestals[id]`.
  Efectos en fórmulas: `coinMult`, `teamPower`, `slots`, `backpack`, `eggCost`, `hatchCooldown`, `walkSpeed` (el servidor pone
  `Humanoid.WalkSpeed` al entrar, al reaparecer y al comprar). Ventana temporal «🌳 Mejoras» en el menú (en el sitio de Renacer).
- Datos (`MythicHatchlings_v2`, sin migración de v1): `coins lifetimeCoins zones pets[{uid,kind,shiny}] equipped[uid] nextUid
  album{kind} shinyIndex{kind} albumClaimed{"i"} stones upgrades{id} daily missions{day,list,bonusGiven} boosts{coinsUntil,luckUntil}
  tutorialDone receipts stats{piles,hatched,fused,mythics,shinies} settings{lang,muted,auto} lastOnline`. Añadir un campo a
  `Data.newData()` basta (reconcile **no** entra en listas). leaderstats: `Coins` e `Index` (crías descubiertas).
- Estado al cliente (además de lo de siempre): `stones upgrades shinyIndex shinyScore albumCount albumTotal
  nextZone{zone,ok,kind,need,have} hatchCooldown walkSpeed nearAltar`.
- `hatch` devuelve `{ hatched = { {kind, new, shiny, rarity, chance} } }` (`chance` = % de la especie o, si es Brillante, el % de
  Brillante): lo decide el servidor (`Config.rollPet`, `Config.rollShiny`); el cliente solo dibuja el momento
  (`Config.hatchLevel`: repetida / nueva en el Índice / Brillante o Mítica). Una Brillante se anuncia a todos (`n_shiny_hatch`,
  máx. 1 cada `RARE_ANNOUNCE_COOLDOWN` s; `Session.lastAnnounce`).
- **Modelos 3D**: `ReplicatedStorage.Modelos` (también vale ServerStorage; lo importa el usuario, `modelos/LEEME.md`) o `Config.MODELS_ASSET_ID` (InsertService).
  Cada modelo «Alias» tiene piezas «Alias__material»; `World.place` los escala, gira y pinta por material y zona (`MAT_COLORS`,
  `ZONE_MATS`). Sin modelos todo sale con piezas básicas. Pack (51): Kenney Nature Kit + 17 animales de
  Quaternius (Cow, Horse, Llama, Pig, Pug, Sheep, Zebra, Cat, Dog, Eagle, Piranha, Wolf, Chick, Fish, RedFox, Whale, Bird) +
  Cristal1/Cristal2/CristalGrande + Huevo (eggShell/eggSpots). `ModelColors.luau` (generado) = color de cada pieza. El bot prueba los dos casos (modelos falsos en ReplicatedStorage, con animales y huevo).
- Montones = **cristales** (el usuario probó rocas y prefirió cristales, 2026-10-26). `Workspace.Mundo.Montones`, aspecto en
  `World.crystal`: con modelos, racimos «Cristal1/Cristal2/CristalGrande» (generados en `construir_pack.py`) dentro de una caja
  invisible; sin modelos, cristales de piezas con punta y sin base. Color: uno de `Config.Zones[i].crystalColors` (paleta de la
  isla); tamaño: `Config.PileKinds[k].size` ± `PILE_SIZE_JITTER` (dorado: `GOLD_SIZE`). El aviso `coins` lleva `rel` (premio frente
  a `Config.pileTypicalCoins(isla)`) y el «+🪙» crece con él (`Config.FLOAT_TEXT`); la puerta dice «Cristales ×N» (`Config.zoneCrystalMult`).
  Atributo `Radius` para las crías: los crea el servidor (32 por zona, reaparecen a los 6 s). Se eligen tocándolos
  (ClickDetector) o en modo Auto (el más cercano a ≤ 45). Cada segundo restan el poder del equipo; al romperse las monedas
  se reparten según el daño de cada jugador. Al desaparecer un montón se quita el objetivo a todos los que lo picaban.
- **Montón Dorado**: cada `GOLD_INTERVAL` s (`spawnGold` en el bucle) uno en la isla más alta abierta de cada jugador (sin
  repetir isla ni duplicar), atributo `Gold`, vida/monedas ×`GOLD_HP`/`GOLD_COINS`, no reaparece y caduca a los
  `GOLD_LIFETIME` s. Mismo reparto por daño. El cliente le pone la estrella `MarcaDorada` (Mundo3D).
- Crías en 3D: el servidor pone en cada jugador los atributos `Pets` ("cría:0|1,…", 1 = Brillante) y `Target` (PileId); cada cliente
  las dibuja (piezas locales, ancladas, sin colisión). Puertas: el cliente las abre localmente si ya abrió la isla; el
  servidor no deja picar montones ni abrir huevos de islas no abiertas.
- Compras: `ProcessReceipt` idempotente (`receipts`) y solo confirma tras guardar.

## 4. Verificación (OBLIGATORIO antes de cada commit)

`roblox-crias-miticas/tools/check.sh` → compila, analiza tipos (0 avisos), textos ES/EN, juego completo con bot
(guardar/cargar, sin DataStore, inglés), capturas + auditoría de diseño (PC y móvil) y construye `MythicHatchlings.rbxl`.
**Si añades una acción, añádela a `run_juego.luau`.** Ver el mundo 3D: `lune run tools/harness/vista_mundo.luau
tools/out/test.rbxl tools/out/mundo.rbxlx` + `vista3d.py` (skill `roblox-3d-vista`).

Trampas de Lune ya resueltas en `mock.luau`: `Position` de una pieza se lee/escribe vía `CFrame`; las listas que devuelven
`GetChildren`/`GetDescendants` se envuelven; `MouseClick` es una señal. Lune no tiene `PivotTo`: el servidor mueve al
jugador con `HumanoidRootPart.CFrame` (igual de válido en Roblox). `Clone()` en el mock quita el atributo `__hid` (si no, la copia se confundía con el original). **`CFrame.lookAt` de Lune sale girado al revés**:
en el código del mundo se usa `facing()` con `CFrame.fromMatrix` (igual en Lune y en Roblox).
En Lune `math` es de solo lectura: para forzar una Brillante en `run_juego.luau` se envuelve `Config.rollShiny` (tabla compartida;
las probabilidades no cambian) y para no esperar 3 min se baja `Config.GOLD_INTERVAL` dentro de la prueba. Leer una pieza
**destruida** da error en Lune (en Roblox no): por eso el servidor quita el objetivo a todos al desaparecer un montón.

## 5. Pendiente

- [ ] Que el usuario lo pruebe en Studio (Play) y mande capturas: crías siguiendo, montones, huevo, puertas.
- [ ] Primera publicación en Studio (Publish to Roblox As… → experiencia NUEVA) y poner IDs en `juegos.json`.
- [ ] Crear pases/productos (`roblox-nube`); iconos ya hechos en `docs/arte/`. Pases: x2, slots, hatch3, autoHatch, backpack.
      **Ojo:** crear los packs de monedas (cash_s/cash_l) hace que los huevos se puedan pagar indirectamente con Robux →
      revisar la norma de artículos aleatorios de pago (cuestionario, PolicyService) antes.
- [ ] Fase A pendiente (tras el mapa): HUD estilo Collect All Pets, Índice con tarjetas por rareza, imán de monedas.
- [ ] Ver en Studio con el pack importado: que los animales miren hacia delante (si no, `Config.PET_MODEL_YAW = math.pi`),
      su tamaño y color, y el huevo «Huevo» pintado por rareza.
- [ ] Fase B: variantes Metallic/Giant, insignias, estadísticas, misiones encadenadas, sumidero de piedras tras el árbol.
- [ ] Ideas: intercambio entre jugadores (con cuidado con estafas), eventos con huevo especial, clasificación.
