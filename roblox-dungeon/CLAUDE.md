# CLAUDE.md — «Dungeon Ascend» (juego de mazmorras de Roblox)

Segundo juego del usuario en este repo (el primero es Web Empire Tycoon, en
`roblox-imperio-web/`, con su propio contexto en el `CLAUDE.md` de la raíz). Lee también
la raíz para las preferencias del usuario: **español, sin jerga, da tu % de confianza y
qué te falta; no quiere tocar código; pasos de clic en clic; usa Windows y Roblox Studio.**

## 1. Estado

- **Versión 0.1** (`Config.VERSION` en `GameConfig.luau`; súbelo en cada versión).
- **Sin publicar todavía.** Cuando se publique, apunta aquí el universe ID y el place ID.
- Rama de trabajo: **`claude/dungeon-ascend`**. Descarga del lugar:
  `https://github.com/candhu23/mi-priemra-web/raw/claude/dungeon-ascend/roblox-dungeon/DungeonAscend.rbxl`
- Decisiones del usuario: combate de **acción con habilidades**, **cooperativo en zonas
  compartidas**, nombre **Dungeon Ascend**.

## 2. Archivos

```
roblox-dungeon/
├── default.project.json   # Rojo. Lighting.Technology = Future (no se puede por script)
├── DungeonAscend.rbxl     # generado por tools/check.sh (súbelo en cada commit)
├── README.md              # guía para el usuario
├── docs/                  # render_*.png (mapas y enemigos dibujados por las pruebas)
├── tools/                 # setup.sh, check.sh, harness/, sim/ (bin/ y out/ en .gitignore)
└── src/
    ├── ReplicatedStorage/GameConfig.luau        # TODOS los datos y fórmulas
    ├── ServerScriptService/
    │   ├── GameServer.server.luau  # datos, sesiones, acciones, botín, XP, compras, guardado
    │   ├── CombatService.luau      # IA de enemigos, jefes (golpe con aviso), habilidades, daño
    │   ├── EnemyModels.luau        # modelos de enemigos hechos con piezas
    │   └── World.luau              # Ciudad, portales, forja, tienda, clasificación, 3 zonas
    └── StarterPlayerScripts/GameClient.client.luau  # toda la interfaz y efectos
```

## 3. Arquitectura

- **El servidor manda.** Remotes en `ReplicatedStorage.DungeonRemotes`:
  - `Action` (RemoteFunction) `(action, a, b) → (ok, mensaje?, extra?)`. Acciones:
    `teleport, equip, sell, sellJunk, upgrade, buyChest, claimDaily, finishTutorial,
    setMuted, setAutoSell, saveNow`. Máx. 10/s.
  - `Combat` (RemoteEvent). Cliente→servidor: `("skill", id)` (máx. 20/s; el servidor
    comprueba nivel y recarga con 0,15 s de margen). Servidor→cliente: `hits {p,d,c}`,
    `hurt`, `reward (pos, xp, oro)`, `loot (item, esMejor)`, `levelup`, `died (zona, s)`,
    `fx (tipo, pos, extra, userIdOrigen)` a todos.
  - `State` (estado completo; al cambiar algo, máx. 4/s, y cada 2 s), `Notify`
    (`popup|success|error|info|loot|boss`), `OpenMenu (pestaña)` desde los carteles.
- **Enemigos = piezas ancladas** movidas por el servidor (`CombatService.step`, 15 Hz con
  `Heartbeat`), sin Humanoid ni física. Solo piensan si hay alguien en su zona. Botín
  **personal**: todos los que dañan a un enemigo reciben XP, oro y su propia tirada de botín.
- Zonas en `z = -1000·índice`, 240×320. `World.zoneAt(pos)` dice en qué zona estás.
- La Embestida mueve al personaje en el **cliente** (LinearVelocity 0,22 s); el servidor
  calcula el daño en línea desde la posición del personaje.
- Arma visible soldada a la mano (`ArmaEquipada`), color del objeto, brilla si es épica o más.

## 4. Datos guardados

DataStore `DungeonAscend_v1`, clave `player_<UserId>`; clasificación OrderedDataStore
`DungeonAscendTop_v1` = `nivel·1e9 + xp`. Mismo sistema que el tycoon: guarda cada 60 s,
al salir, en `BindToClose`, tras cada compra y a mano; si la carga falla no se guarda.
`reconcile()` rellena campos nuevos salvo dentro de `inventory, equipped, bossKills, receipts`.

Campos: `level, xp, gold, lifetimeGold, inventory[{id,def,rarity,up}], equipped{slot=id},
nextItemId, unlockedZone, bossKills{zona=n}, stats{kills,bossKills,deaths,itemsFound,upgrades,chests},
daily{lastDay,streak}, boostUntil, receipts, tutorialDone, settings{muted,autoSell}, lastOnline`.

## 5. Equilibrio (`tools/sim/run.sh`)

Bot «humano razonable» (70 % de eficiencia): jefe 1 ≈ 23 min, jefe 2 ≈ 62 min,
jefe 3 ≈ 105 min, nivel ≈ 78 a las 5 h. Un jugador real irá más lento (×1,5–3).
Al final sobra oro (no hay en qué gastarlo tras +10): las zonas nuevas lo arreglarán.

## 6. Monetización

`Config.Monetization`: `id = 0` → el artículo no aparece. **Todos a 0 (pendientes).**
Pases: `goldPass` 149, `xpPass` 149, `autoPass` 99, `bagPass` 49.
Productos: `gold_small` 25, `gold_big` 99, `boost` 39, `revive` 15 (botón en la pantalla de muerte).
Sin artículos aleatorios de pago (los cofres se pagan con oro del juego).

## 7. Verificación (OBLIGATORIO antes de cada commit)

```bash
cd roblox-dungeon && tools/check.sh   # la 1ª vez descarga las herramientas
```
1. `luau-compile` (sintaxis y 200 locales). 2. `luau-lsp analyze` → **0 avisos**.
3. `run_server.luau`: mundo + enemigos reales, jugador falso con personaje que viaja, lucha,
   sube de nivel, equipa, vende, forja, vence al jefe, desbloquea la Cueva, compra, muere,
   revive, guarda, sale y vuelve → `TODO OK`. Vuelca `world.json`.
4. `run_client.luau`: crea la interfaz, simula eventos de combate, pulsa todos los botones,
   teclas, auto-ataque y tutorial → `CLIENTE OK`.
5. Simulador de equilibrio. 6. `render.py` (si hay matplotlib) y `rojo build`.

Trampas de Lune (ya resueltas en el harness): `Position` no se calcula desde `CFrame`;
`Model:PivotTo` no existe (lo simula el harness); **`CFrame.lookAt` de Lune gira al revés**
(usa `CFrame.Angles(0, atan2(-dx, -dz), 0)`); `Humanoid.Health` no tiene valor por defecto.
Las del tycoon también aplican (ver `CLAUDE.md` de la raíz, §8–§9).

## 8. Lo que NO se puede verificar aquí (pedir capturas al usuario)

- La sensación del combate: que los enemigos se vean fluidos a 15 Hz y que la Embestida
  no atraviese paredes de forma rara.
- Que la Cueva (con techo) no quede demasiado oscura.
- Cómo queda el arma en la mano (R15 y R6).

## 9. Ideas siguientes

- [ ] Publicar y poner los IDs de pases y productos.
- [ ] Más zonas (cada una: 3 enemigos, jefe, 3 objetos; el sistema es por datos en `GameConfig`).
- [ ] Más habilidades o clases, mascotas que ayudan, misiones diarias, renacer (rebirth).
- [ ] Movimiento de enemigos más suave (interpolar en el cliente).
- [ ] Idiomas ES/EN.
