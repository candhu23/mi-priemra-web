# CLAUDE.md — «Dungeon Ascend» (juego de hordas estilo "survivors" de Roblox)

Segundo juego del usuario en este repo (el primero es Web Empire Tycoon, en
`roblox-imperio-web/`, con su propio contexto en el `CLAUDE.md` de la raíz). Lee también
la raíz para las preferencias del usuario: **español, sin jerga, da tu % de confianza y
qué te falta; no quiere tocar código; pasos de clic en clic; usa Windows y Roblox Studio.**

## 1. Estado

- **Versión 0.3** (`Config.VERSION` en `GameConfig.luau`; súbelo en cada versión).
  v0.1 era un RPG de zonas con habilidades; el usuario pidió **parecerse lo más posible a
  Survive the Swarm y Final Swarm** → en v0.2 se reconvirtió en "survivors" (armas
  automáticas, hordas, mejoras 1 de 3, jefe y portal, mejoras permanentes).
  Decisiones del usuario: **solo o en grupo de hasta 4**; al elegir mejora, **cámara lenta**
  para los enemigos que te persiguen (no pausa).
  **v0.3** (peticiones del usuario): **oleadas** (10/11/12 por mapa, jefe en la última),
  **cada arma con su imagen** (iconos dibujados en `Icons.luau` + efectos 3D en SwarmView),
  **iconos por toda la interfaz**, **cofre de armas** (desbloquea armas nuevas con Coronas),
  **3 dificultades por mapa** (Normal → Difícil → Pesadilla), **ambiente medieval** (castillo
  con puente, taberna, cabañas de paja, pozo; cabañas de leñador en el Bosque, mina en la
  Cueva; interfaz de madera y oro con letra gótica), **mejoras en un árbol de una sola
  página** (3 ramas, cada nodo se abre al comprar el anterior) y **moneda nueva: Coronas**
  (`Config.CURRENCY`, `Config.money(n)`; internamente el campo sigue llamándose `gold`).
- **Sin publicar todavía.** Cuando se publique, apunta aquí el universe ID y el place ID.
- Rama: **`claude/dungeon-ascend`**. Descarga:
  `https://github.com/candhu23/mi-priemra-web/raw/claude/dungeon-ascend/roblox-dungeon/DungeonAscend.rbxl`
- **No copiar** nombres, logos, arte ni la interfaz exacta de esos juegos (solo la mecánica).

## 2. Archivos

```
roblox-dungeon/
├── default.project.json   # Rojo. Lighting.Technology = Future (no se puede por script)
├── DungeonAscend.rbxl     # generado por tools/check.sh (súbelo en cada commit)
├── README.md              # guía para el usuario
├── docs/                  # render_*.png (lobby, castillo, arenas, enemigos e iconos dibujados por las pruebas)
├── tools/                 # setup.sh, check.sh, harness/ (bin/ y out/ en .gitignore)
└── src/
    ├── ReplicatedStorage/
    │   ├── GameConfig.luau     # TODOS los datos: armas, pasivas, clases, mapas, oleadas, dificultades,
    │   │                       #   árbol de mejoras (Config.Tree), cofre de armas, enemigos, economía, tienda
    │   ├── Icons.luau          # iconos dibujados con Frames (moneda, armas, mejoras, menú…); sin imágenes subidas
    │   ├── Ambience.luau       # luz de cada lugar (lobby, bosque, cueva, castillo): hora, niebla, bloom…
    │   └── EnemyModels.luau    # modelos de enemigos con piezas (los usa el CLIENTE)
    ├── ServerScriptService/
    │   ├── GameServer.server.luau  # datos, acciones, grupos, recompensas, compras, guardado
    │   ├── RunManager.luau         # LAS PARTIDAS: oleadas, enemigos, armas, cristales, mejoras, jefe, portal
    │   └── World.luau              # lobby (isla) y arenas con TERRENO + piezas (ver §3b)
    └── StarterPlayerScripts/
        ├── GameClient.client.luau  # interfaz del lobby y de la partida
        └── SwarmView.luau          # dibuja la horda, cristales y efectos (ModuleScript)
```

## 3. Arquitectura

- **El servidor manda.** Remotes en `ReplicatedStorage.DungeonRemotes`:
  - `Action` (RemoteFunction) `(action, a, b) → (ok, mensaje?, extra?)`. Acciones:
    `playSolo, createGroup, joinGroup, leaveGroup, startGroup, choose, reroll, leaveRun,
    buyNode, buyWeaponChest, buyClass, equip, sell, sellJunk, upgrade, buyChest, claimDaily,
    finishTutorial, setMuted, setAutoSell, saveNow`. Máx. 10/s.
    `playSolo(mapa, dificultad)` y `createGroup(mapa, dificultad)`; dificultad 1-3.
  - `Swarm` (RemoteEvent). Servidor→cliente 10 veces/s: `(buffer, gemAdds, gemRemoves, fx)`.
    Buffer: `u16 n` + por enemigo 9 bytes `u16 id, u8 tipo (índice en Config.EnemyList),
    u8 vida 0-255, u8 flags (1 élite, 2 jefe, 4 cargando golpe), i16 x·4, i16 z·4`
    (relativo al centro de la arena). `gemAdds` = `[id, tipo, x·4, z·4]…` (1 XP, 2 corazón,
    3 cofre); `gemRemoves` = `[id, userIdQueLoRecoge]…`; `fx` = `{tipo, …}` (slash, bolt,
    dagger, lightning, axe, bomb, quake, slamwarn, slam, death, levelup, revive, evolve,
    portal, wave, wavedone). Las armas mandan su nivel al final (6 = evolucionada).
    Cliente→servidor: `("dash")`.
  - `State` (estado completo; si hay partida incluye `run` con reloj, XP, armas, oferta de
    mejoras, jefe, portal…; cada 0,5 s en partida, 2 s en el lobby, o al cambiar algo),
    `Notify` (`popup|success|error|info|loot|boss`, más `loot_item` y `summary` con tabla),
    `OpenMenu (pestaña, mapa?)` desde los portales y carteles.
- **Enemigos = datos en el servidor** (`RunManager`, 15 Hz con `Heartbeat`): persiguen al
  jugador vivo más cercano, se separan con una rejilla de 4 studs, golpean al tocar
  (1/s). Tope 200 por partida. El **cliente** los dibuja con `EnemyModels`, los interpola y los
  mueve con `Workspace:BulkMoveTo`. Sin sombras (rendimiento) salvo jefes.
- Armas en `RunManager.fireWeapon` (kinds: slash, bolt, dagger, aura, orbit, boomerang =
  hacha, bomb = bomba con daño retrasado `Config.BOMB_FLIGHT` en `run.delayed`, lightning,
  quake = martillo). Los orbes golpean cada 0,5 s por enemigo; el aura cada `cooldown`.
  El aura y los orbes se DIBUJAN en el cliente a partir de `run.team[].weapons`.
  Al subir de nivel **solo se ofrecen armas desbloqueadas** (`member.unlocked`: las 3 de inicio
  + las del cofre + la de tu clase).
- **Oleadas** (`updateWaves`): descanso (`WAVE_BREAK` 6 s, los cristales vuelan solos) →
  manadas durante `WAVE_SPAWN_TIME` (40 s) → superada si quedan < 12 % o tras +20 s
  (`WAVE_OVERTIME`) empieza la siguiente igualmente. Tamaño `Config.waveSize`; tope vivos
  `Config.maxAlive`. En la última oleada sale el jefe; al vencerlo, portal.
  Vida de los enemigos +20 %/oleada (`HP_PER_WAVE`), velocidad +2,5 %/oleada (máx +30 %).
- **Dificultades** (`Config.Difficulties`): hp, damage, speed, count (más enemigos), gold y
  rarityBoost (botín del jefe). Cada una se abre superando la anterior en ESE mapa
  (`Config.difficultyUnlocked`). El grupo usa la dificultad del líder y todos deben tenerla.
- **SwarmView**: animaciones cortas con `animate(dur, step, done)` que corren cada fotograma;
  espada que gira con estela (Trail), hacha que va y vuelve, bombas en parábola, rayos en
  zigzag, rocas del martillo, chispas; enemigos con sombra, salen del suelo, parpadean en
  blanco al recibir daño (máx. 40 por foto) y estallan en trocitos al morir.
- XP **compartida por el equipo**; cada uno elige su mejora. Oro: cada enemigo da oro a
  **todos** los del equipo. La mitad de los enemigos aparece **por delante** de hacia donde
  corre el jugador (si no, los más lentos nunca te alcanzan y la espada no mata).
- Arenas en `x = 2000 + 600·(hueco-1)`, 8 huecos (`Config.ARENA_SLOTS`). Cámara alejada en partida.
- Fin de partida por jugador (`finishMember`): `win` (portal) = Coronas ×1,5 + objeto del jefe +
  siguiente mapa + siguiente dificultad de ese mapa; `dead`/`left` = Coronas ×0,5. Caído: 20 s para revivir (producto) antes de salir.
  Salir del juego a mitad = `left` (se cobra antes de guardar).

## 3b. Mundo y gráficos (v0.2.1)

- **Terreno de Roblox** (`Workspace.Terrain:FillBlock/FillBall/FillCylinder`) para suelo, agua,
  montañas, colinas, acantilados y caminos; piezas para edificios, árboles y detalles.
  El suelo jugable de las arenas queda **exactamente en y = 0** (los enemigos son datos en ese plano).
  Ayudas: `tPatch` (cambia la capa de arriba), `tRound`, `tBlob` (mancha natural con círculos),
  `tTrail` (camino serpenteante). Las rocas/colinas del borde se colocan a `half + radio`
  para que **nunca invadan la zona jugable** (bloquearían al jugador pero no a los enemigos).
- Lobby: isla radio 140 (playa hasta 156) en un lago (agua arriba en y = -4) con 16 montañas;
  terraza de portales arriba en y = 8 al norte (z ≈ -104) con escalones de terreno;
  forja (x = -78), mercado (x = 80), clasificación (z = 76), estanque (80, 90),
  entrenamiento (92, -42), campamento (-94, -42).
  **Medieval (v0.3)**: castillo grande sobre una colina en el lago (centro (0, 18, -236), de
  adorno, fuera del límite) con puente de piedra desde la orilla norte; aldea con taberna
  (-50, 52), 4 cabañas de paja (`cottage`), pozo (-26, 42) y huertos. Ayudas: `wedge`,
  `gableRoof`, `window`, `smoke`, `cottage`, `tavern`, `well`, `castleTower`, `castleWall`.
  Bosque: 4 cabañas de leñador en el borde (fuera de la zona jugable). Cueva: entibados de
  mina con farolillos, vías y vagonetas con mineral.
- **Ambience**: el servidor aplica `lobby` al arrancar; el CLIENTE aplica el del mapa al entrar
  en partida y `lobby` al salir (cambios locales en Lighting). `Terrain.Decoration` se intenta
  activar con `pcall` (puede no ser scriptable: en ese caso se activa en Studio).
- Arenas: se **reutilizan** (no se borran al acabar); `RunManager` elige hueco libre que ya
  tenga ese mapa, luego uno vacío. La del Bosque se construye al arrancar (hueco 1).
- `render.py` dibuja terreno + piezas: `render_ciudad.png` (arriba e isla),
  `render_ciudad_perspectiva.png`, `render_castillo.png` y `render_zonas.png` (línea = zona
  jugable). `render_icons.py` dibuja `icons.json` (volcado por run_client) en
  `render_iconos.png`. Úsalos para revisar: es la única forma de "ver" desde aquí.

## 4. Datos guardados

DataStore `DungeonAscend_v2` (v0.1 usaba `_v1`; nunca se publicó), clave `player_<UserId>`;
clasificación OrderedDataStore `DungeonAscendKills_v2` = enemigos derrotados.
Guarda cada 60 s, al salir, en `BindToClose`, tras cada compra y a mano; si la carga falla no
se guarda. `reconcile()` no entra en `inventory, equipped, tree, weapons, classes, mapWins,
bestTime, receipts`. Al cargar, `mapWins` antiguos numéricos pasan a `{normal = n}`.

Campos: `gold (= Coronas), lifetimeGold, inventory[{id,def,rarity,up}], equipped{slot=id}, nextItemId,
tree{nodo=true}, weapons{arma=true} (las del cofre), classes{id=true}, selectedClass,
unlockedMap, mapWins{mapa={normal=n, dificil=n, pesadilla=n}},
bestTime{mapa=s}, stats{runs,wins,kills,bossKills,deaths,itemsFound,upgrades,chests},
daily{lastDay,streak}, boostUntil, receipts, tutorialDone, settings{muted,autoSell}, lastOnline`.

## 5. Equilibrio (`run_server.luau <src> bot`, lo ejecuta check.sh)

Bots que juegan partidas completas con el código real, esquivando en círculos (cambian de
sentido cada 15 s y se apartan de enemigos a <12 studs). Resultado v0.3: escapan del
Bosque en Normal hacia el minuto 7-8,5 (oleada 10, nivel ~27, ~2.600 enemigos, ~2.200
Coronas); el Castillo sin mejoras NO se supera (llega al jefe pero no lo mata en 14 min);
con todo el árbol escapan de Difícil y Pesadilla del Bosque (~8 min). El bot casi nunca
recibe golpes (esquiva MEJOR que una persona): es un límite muy optimista.
**Hay que ajustar con pruebas reales** (pedir al usuario cuánto aguanta y a qué minuto cae).

## 6. Monetización

`Config.Monetization`: `id = 0` → no aparece. **Todos a 0 (pendientes).**
Pases: `goldPass` 149 (x2 Coronas), `choicePass` 199 (4 opciones), `rerollPass` 99 (+3 rerolls), `bagPass` 49.
Productos: `gold_small` 25, `gold_big` 99, `boost` 39, `revive` 15 (en la pantalla al caer).
Sin artículos aleatorios de pago (el cofre de objetos y el cofre de armas se pagan con
Coronas; probabilidades a la vista).

## 7. Verificación (OBLIGATORIO antes de cada commit)

```bash
cd roblox-dungeon && tools/check.sh   # la 1ª vez descarga las herramientas
```
1. `luau-compile`. 2. `luau-lsp analyze` → **0 avisos**. 3. `run_server.luau`: lobby,
partida solo completa (oleadas, mejoras, reroll, esquivar, las 9 armas, élites, jefe en la
última oleada con golpe avisado, portal, victoria, recompensas y dificultad desbloqueada),
grupo de 2 (unirse con mapa/dificultad, revivir con producto, abandonar, caer sin revivir),
árbol (orden de nodos), cofre de armas, dificultades (Pesadilla bloqueada, Difícil sí; solo
se ofrecen armas desbloqueadas), clases, mochila, compras, salir a mitad de partida y
volver → `TODO OK`; vuelca `world.json`, `state.json`, `state_run.json`.
4. `run_client.luau`: dibuja todos los iconos (→ `icons.json`), lobby y partida, foto de
horda con todos los enemigos, cristales y efectos de las 9 armas y oleadas, todos los
botones (árbol y cofre incluidos), teclas, muerte, resumen y tutorial → `CLIENTE OK`.
5. Bots de equilibrio. 6. `render.py` (si hay matplotlib) y `rojo build`.

Trampas de Lune (resueltas en los harness): no hay `Terrain` (el harness lo simula y apunta
los rellenos para dibujarlos); `Position` no se calcula desde `CFrame`;
`Model:PivotTo` y `Workspace:BulkMoveTo` no existen (los simulan); **`CFrame.lookAt` de
Lune gira al revés** (usa `CFrame.Angles(0, atan2(-dx, -dz), 0)`); `Humanoid.Health` no tiene
valor por defecto y `TakeDamage`/`Died` hay que simularlos; Vector3 no cabe en JSON.

## 8. Lo que NO se puede verificar aquí (pedir capturas al usuario)

- Rendimiento real con 200 enemigos (sobre todo en móvil) y lo suave que se ve la horda.
- Que la cámara alejada sea cómoda y que el esquive (LinearVelocity) no atraviese muros.
- El aspecto real del terreno y la luz (la Cueva podría quedar demasiado oscura; ajustar
  `Ambience.Presets`), y el tiempo que tarda en construirse una arena nueva (terreno).
- Dificultad real para una persona (ver §5).
- Cómo se ven de verdad los iconos dibujados con Frames (el render es aproximado: sin
  degradados) y la letra gótica `GrenzeGotisch` en móvil (si cuesta leerla, cambiar
  `TITLE_FONT` en GameClient).

## 9. Ideas siguientes

- [ ] Publicar y poner los IDs de pases y productos.
- [ ] Más mapas (Survive the Swarm tiene 20): cada uno es un bloque en `Config.Maps` + tema en `World`.
- [ ] Más armas y evoluciones, más clases, más ramas del árbol, "bancar o arriesgar" las Coronas.
- [ ] Revivir a compañeros caídos quedándose cerca; modo infinito; clasificación semanal.
- [ ] Modelos de enemigos más bonitos (Toolbox/IA → `.rbxm` en GitHub; ver conversación).
- [ ] Idiomas ES/EN.
