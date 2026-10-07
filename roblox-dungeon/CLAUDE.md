# CLAUDE.md — «Dungeon Ascend» (juego de hordas estilo "survivors" de Roblox)

Segundo juego del usuario en este repo (el primero es Web Empire Tycoon, en
`roblox-imperio-web/`, con su propio contexto en el `CLAUDE.md` de la raíz). Lee también
la raíz para las preferencias del usuario: **español, sin jerga, da tu % de confianza y
qué te falta; no quiere tocar código; pasos de clic en clic; usa Windows y Roblox Studio.**

## 1. Estado

- **Versión 0.2** (`Config.VERSION` en `GameConfig.luau`; súbelo en cada versión).
  v0.1 era un RPG de zonas con habilidades; el usuario pidió **parecerse lo más posible a
  Survive the Swarm y Final Swarm** → en v0.2 se reconvirtió en "survivors" (armas
  automáticas, hordas, mejoras 1 de 3, jefe y portal, mejoras permanentes).
  Decisiones del usuario: **solo o en grupo de hasta 4**; al elegir mejora, **cámara lenta**
  para los enemigos que te persiguen (no pausa).
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
├── docs/                  # render_*.png (lobby, arenas y enemigos dibujados por las pruebas)
├── tools/                 # setup.sh, check.sh, harness/ (bin/ y out/ en .gitignore)
└── src/
    ├── ReplicatedStorage/
    │   ├── GameConfig.luau     # TODOS los datos: armas, pasivas, clases, mapas, enemigos, economía, tienda
    │   └── EnemyModels.luau    # modelos de enemigos con piezas (los usa el CLIENTE)
    ├── ServerScriptService/
    │   ├── GameServer.server.luau  # datos, acciones, grupos, recompensas, compras, guardado
    │   ├── RunManager.luau         # LAS PARTIDAS: oleadas, enemigos, armas, cristales, mejoras, jefe, portal
    │   └── World.luau              # lobby y arenas (una por partida, se crean y se borran)
    └── StarterPlayerScripts/
        ├── GameClient.client.luau  # interfaz del lobby y de la partida
        └── SwarmView.luau          # dibuja la horda, cristales y efectos (ModuleScript)
```

## 3. Arquitectura

- **El servidor manda.** Remotes en `ReplicatedStorage.DungeonRemotes`:
  - `Action` (RemoteFunction) `(action, a, b) → (ok, mensaje?, extra?)`. Acciones:
    `playSolo, createGroup, joinGroup, leaveGroup, startGroup, choose, reroll, leaveRun,
    buyUpgrade, buyClass, equip, sell, sellJunk, upgrade, buyChest, claimDaily,
    finishTutorial, setMuted, setAutoSell, saveNow`. Máx. 10/s.
  - `Swarm` (RemoteEvent). Servidor→cliente 10 veces/s: `(buffer, gemAdds, gemRemoves, fx)`.
    Buffer: `u16 n` + por enemigo 9 bytes `u16 id, u8 tipo (índice en Config.EnemyList),
    u8 vida 0-255, u8 flags (1 élite, 2 jefe, 4 cargando golpe), i16 x·4, i16 z·4`
    (relativo al centro de la arena). `gemAdds` = `[id, tipo, x·4, z·4]…` (1 XP, 2 corazón,
    3 cofre); `gemRemoves` = `[id, userIdQueLoRecoge]…`; `fx` = `{tipo, …}` (slash, bolt,
    dagger, lightning, slamwarn, slam, death, levelup, revive, evolve, portal).
    Cliente→servidor: `("dash")`.
  - `State` (estado completo; si hay partida incluye `run` con reloj, XP, armas, oferta de
    mejoras, jefe, portal…; cada 0,5 s en partida, 2 s en el lobby, o al cambiar algo),
    `Notify` (`popup|success|error|info|loot|boss`, más `loot_item` y `summary` con tabla),
    `OpenMenu (pestaña, mapa?)` desde los portales y carteles.
- **Enemigos = datos en el servidor** (`RunManager`, 15 Hz con `Heartbeat`): persiguen al
  jugador vivo más cercano, se separan con una rejilla de 4 studs, golpean al tocar
  (1/s). Tope 200 por partida. El **cliente** los dibuja con `EnemyModels`, los interpola y los
  mueve con `Workspace:BulkMoveTo`. Sin sombras (rendimiento) salvo jefes.
- Armas en `RunManager.fireWeapon`. Los orbes golpean cada 0,5 s por enemigo; el aura cada
  `cooldown`. El aura y los orbes se DIBUJAN en el cliente a partir de `run.team[].weapons`.
- XP **compartida por el equipo**; cada uno elige su mejora. Oro: cada enemigo da oro a
  **todos** los del equipo. La mitad de los enemigos aparece **por delante** de hacia donde
  corre el jugador (si no, los más lentos nunca te alcanzan y la espada no mata).
- Arenas en `x = 2000 + 600·(hueco-1)`, 8 huecos (`Config.ARENA_SLOTS`). Cámara alejada en partida.
- Fin de partida por jugador (`finishMember`): `win` (portal) = oro ×1,5 + objeto del jefe +
  siguiente mapa; `dead`/`left` = oro ×0,5. Caído: 20 s para revivir (producto) antes de salir.
  Salir del juego a mitad = `left` (se cobra antes de guardar).

## 4. Datos guardados

DataStore `DungeonAscend_v2` (v0.1 usaba `_v1`; nunca se publicó), clave `player_<UserId>`;
clasificación OrderedDataStore `DungeonAscendKills_v2` = enemigos derrotados.
Guarda cada 60 s, al salir, en `BindToClose`, tras cada compra y a mano; si la carga falla no
se guarda. `reconcile()` no entra en `inventory, equipped, upgrades, classes, mapWins,
bestTime, receipts`.

Campos: `gold, lifetimeGold, inventory[{id,def,rarity,up}], equipped{slot=id}, nextItemId,
upgrades{id=nivel}, classes{id=true}, selectedClass, unlockedMap, mapWins{mapa=n},
bestTime{mapa=s}, stats{runs,wins,kills,bossKills,deaths,itemsFound,upgrades,chests},
daily{lastDay,streak}, boostUntil, receipts, tutorialDone, settings{muted,autoSell}, lastOnline`.

## 5. Equilibrio (`run_server.luau <src> bot`, lo ejecuta check.sh)

Bots que juegan partidas completas con el código real, esquivando en círculos (cambian de
sentido cada 15 s y se apartan de enemigos a <12 studs). Resultado actual: escapan del
Bosque hacia el minuto 9 (nivel ~20, ~2.000 enemigos, ~1.700 oro); el Castillo sin equipo
no se supera. El bot esquiva MEJOR que un humano novato: es un límite optimista.
**Hay que ajustar con pruebas reales** (pedir al usuario cuánto aguanta y a qué minuto cae).

## 6. Monetización

`Config.Monetization`: `id = 0` → no aparece. **Todos a 0 (pendientes).**
Pases: `goldPass` 149, `choicePass` 199 (4 opciones), `rerollPass` 99 (+3 rerolls), `bagPass` 49.
Productos: `gold_small` 25, `gold_big` 99, `boost` 39, `revive` 15 (en la pantalla al caer).
Sin artículos aleatorios de pago (los cofres se pagan con oro).

## 7. Verificación (OBLIGATORIO antes de cada commit)

```bash
cd roblox-dungeon && tools/check.sh   # la 1ª vez descarga las herramientas
```
1. `luau-compile`. 2. `luau-lsp analyze` → **0 avisos**. 3. `run_server.luau`: lobby,
partida solo completa (oleadas, mejoras, reroll, esquivar, todas las armas, élites, jefe con
golpe avisado, portal, victoria y recompensas), grupo de 2 (unirse, revivir con producto,
abandonar, caer sin revivir), mejoras, clases, mochila, compras, salir a mitad de partida y
volver → `TODO OK`; vuelca `world.json`, `state.json`, `state_run.json`.
4. `run_client.luau`: lobby y partida, foto de horda con todos los enemigos, cristales y
efectos, todos los botones, teclas, muerte, resumen y tutorial → `CLIENTE OK`.
5. Bots de equilibrio. 6. `render.py` (si hay matplotlib) y `rojo build`.

Trampas de Lune (resueltas en los harness): `Position` no se calcula desde `CFrame`;
`Model:PivotTo` y `Workspace:BulkMoveTo` no existen (los simulan); **`CFrame.lookAt` de
Lune gira al revés** (usa `CFrame.Angles(0, atan2(-dx, -dz), 0)`); `Humanoid.Health` no tiene
valor por defecto y `TakeDamage`/`Died` hay que simularlos; Vector3 no cabe en JSON.

## 8. Lo que NO se puede verificar aquí (pedir capturas al usuario)

- Rendimiento real con 200 enemigos (sobre todo en móvil) y lo suave que se ve la horda.
- Que la cámara alejada sea cómoda y que el esquive (LinearVelocity) no atraviese muros.
- Dificultad real para una persona (ver §5).

## 9. Ideas siguientes

- [ ] Publicar y poner los IDs de pases y productos.
- [ ] Más mapas (Survive the Swarm tiene 20): cada uno es un bloque en `Config.Maps` + tema en `World`.
- [ ] Más armas y evoluciones, más clases, árbol de habilidades, "bancar o arriesgar" el oro.
- [ ] Revivir a compañeros caídos quedándose cerca; modo infinito; clasificación semanal.
- [ ] Modelos de enemigos más bonitos (Toolbox/IA → `.rbxm` en GitHub; ver conversación).
- [ ] Idiomas ES/EN.
