# CLAUDE.md — «AeroCarga España» (`roblox-carga-aerea/`)

Contexto completo de este juego para cualquier conversación nueva de Claude Code.
Léelo entero antes de tocar nada. (El `CLAUDE.md` de la raíz habla del otro juego del repo,
*Web Empire Tycoon*, y de cómo trabajar con el usuario: **léelo también, sobre todo §2 y §11**.)

---

## 1. Qué es y en qué estado está

- **Juego de Roblox 2D** (todo interfaz, sin personaje) en Luau: gestionas una aerolínea de carga por
  **España**. Llevas productos típicos de cada zona entre 41 aeropuertos reales, compras aviones, fichas
  pilotos y **pintas el mapa** al desbloquear regiones. Nombre en inglés: *Spain Air Cargo Tycoon*.
- **Versión: 0.3** (`Config.VERSION`; súbela en cada versión). La v0.3 es la «gran mejora» tras «le falta algo, es
  muy simple»: demanda viva, eventos de España, contratos, rasgos de pilotos, aterrizaje perfecto, chárter, pasaporte,
  salir a bolsa (prestigio), tu aerolínea, tráfico de otros jugadores y ranking semanal (resumen en `DISENO.md` §1 bis).
- **Estado: NO publicado todavía.** El usuario probó la v0.1 en Studio y no veía aviones ni podía fichar
  (causa: `GetDataStore` sin `pcall` paraba el servidor en Studio sin publicar). La v0.2 lo arregla, pero
  **el usuario aún no ha confirmado que la v0.2/v0.3 funcione en su Studio**. Pídele capturas.
- **Rama de trabajo:** `claude/zealous-dirac-ejfljx` (repo `candhu23/mi-priemra-web`).
  Si la conversación empieza en `main` y esta carpeta no existe ahí, haz
  `git fetch origin claude/zealous-dirac-ejfljx && git checkout claude/zealous-dirac-ejfljx`.
- **Descarga directa del lugar** (lo que el usuario abre en Studio):
  `https://github.com/candhu23/mi-priemra-web/raw/claude/zealous-dirac-ejfljx/roblox-carga-aerea/AeroCarga.rbxl`
- Historia: lo inspiró un juego de **camiones** (EE. UU., interfaz oscura, agencias con sorteo). El usuario
  pidió expresamente que **NO se parezca**: tema, país, estilo claro, estructura y fichajes son distintos
  (tabla en `DISENO.md` §2). No copies nada de ese juego ni lo menciones en la ficha de Roblox.

## 2. Documentos de esta carpeta

| Archivo | Para qué |
|---|---|
| `DISENO.md` | Diseño, economía (tablas), enganche, tienda con precios recomendados, qué está verificado |
| `README.md` | Guía para el usuario: probar en Studio, publicar como experiencia NUEVA, crear pases, descripción |
| `docs/*.jpg` | Capturas de la **vista previa aproximada** (navegador, no Roblox) |

## 3. Estructura

```
roblox-carga-aerea/
├── default.project.json   # Rojo: Players.CharacterAutoLoads=false, Lighting.Technology=Future
├── AeroCarga.rbxl         # Lo genera tools/check.sh (súbelo en cada commit)
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Config.luau    # TODOS los datos/fórmulas: aeropuertos, productos, aviones, regiones, mejoras,
│   │   │                  # pilotos, exprés, XP, misiones, objetivos, premio diario, tienda (IDs)
│   │   ├── Lang.luau      # Textos EN/ES. Lang.t(lang, clave, params) con {param}
│   │   ├── Rules.luau     # COMPARTIDO servidor/cliente: Rules.quote/canFly (pago con todos los modificadores),
│   │   │                  # eventAt/wantedAt (deterministas por hora), satMult, pasaporte (stamps, medals)
│   │   └── MapData.luau   # GENERADO (no editar): mapa en franjas + MapData.project(lat, lon)
│   ├── ServerScriptService/
│   │   ├── GameServer.server.luau  # Remotes, entrada/salida, sendState, leaderstats, ranking, bucle 1 s
│   │   └── Cargo/
│   │       ├── Data.luau  # newData, reconcile, load/save, ranking. TODO el DataStore en pcall
│   │       ├── Game.luau  # Lógica: tablones, vuelos, pilotos, exprés, misiones, objetivos, tutorial,
│   │       │              # offline, bonus sociales, autodespacho y Game.Actions
│   │       └── Shop.luau  # Pases y productos: ProcessReceipt idempotente
│   └── StarterPlayerScripts/
│       ├── GameClient.client.luau  # Arranque: escala, remotes, build(), traducción de avisos
│       └── UI/
│           ├── Kit.luau        # ctx compartido + piezas (button «grueso», card, label, tabs, syncList…)
│           │                   # + reglas para estimar (quote, flyBlock) iguales a las del servidor
│           ├── PlaneArt.luau   # Aviones dibujados con Frames: side() (tarjetas) y top() (mapa)
│           ├── MapView.luau    # Mapa de España: franjas, regiones, pins, rutas, aviones, dinero flotante
│           ├── Hud.luau        # Dinero (+ingresos/min), nivel, botones redondos (bolsa…), evento, contratos en marcha,
│           │                   # «aviones esperando», monedas, objetivo, exprés y barra de 7 botones
│           ├── Screens.luau    # Ventanas sobre el mapa, modal, avisos, confeti, título, bienvenida,
│           │                   # subida de nivel, celebraciones y TUTORIAL con flecha
│           ├── FleetPanel / CargoPanel / PilotsPanel / SpainPanel (regiones + pasaporte) / MissionsPanel / ShopPanel.luau
│           ├── ContractsPanel.luau  # Contratos (en marcha + ofertas)
│           ├── IpoPanel.luau        # Bolsa (prestigio)
│           └── SystemPanels.luau  # Ranking (semana / siempre) y Ajustes (tu aerolínea, idioma, sonido…)
└── tools/   (bin/ y out/ en .gitignore)
    ├── setup.sh  check.sh
    ├── assets/build_spain.py     # Natural Earth 10m → MapData.luau
    └── harness/  mock.luau · run_server.luau · run_game.luau · check_lang.py · preview.py · preview_shot.js
```

Rojo: `src/<Servicio>` → servicio; `*.server.luau` = Script, `*.client.luau` = LocalScript, resto = ModuleScript;
las carpetas (`Cargo/`, `UI/`) son Folders.

## 4. Arquitectura

- **El servidor manda.** El cliente solo muestra y pide acciones. Remotes en `ReplicatedStorage.CargoRemotes`:
  - `Action` (RemoteFunction): `InvokeServer(acción, a, b, c)` → `(ok, claveTexto?, params?, extra?)`.
    `extra`: `{ money = true }`, `{ pilot = … }` (fichaje), `{ region = id }`, `{ takeoff = planeId }`, `{ top, week }`,
    `{ ipo, total, count }` (salir a bolsa).
  - `State` (RemoteEvent): estado completo cada segundo y tras cada acción/compra (`Game.pushState`).
  - `Notify` (RemoteEvent): `(tipo, clave, params)`. Tipos: `success error info money goal express feed event`
    (avisos), `landed` (dinero flotante en el mapa), `level` (ventana con confeti), `welcome` (bienvenida
    con ganancias offline). **El servidor manda claves de `Lang`, nunca textos**; el cliente las traduce
    (`translate` formatea dinero en `net value amount fuel cost offline` y traduce `region plane upgrade item company good event`).
    `landed` lleva además `landing` ("perfect"/"good") o `charter = true`.
- **Acciones** (`Game.Actions` + `getTop` en GameServer): `dispatch(planeId, loadId, pilotId) ferry(planeId, code)
  refreshBoard(code) buyPlane(model) sellPlane(id) repair(id) hire(candidateId) searchCandidates()
  firePilot(id) buyRegion(id) buyUpgrade(id) setAuto(bool) setLang("", "en", "es") setMuted(bool)
  claimDaily() claimMission(i) claimGoal(id) tutorial("start"|"skip") getTop()` y, desde la v0.3:
  `charter(planeId, "c1"|"c4"|"c8") land(planeId, "perfect"|"good") acceptContract(offerId) abandonContract(id)
  goPublic() setAirline({a,b,c}, color) claimGoals()`.
  Límite: 10 acciones/s (getTop no cuenta). **Si añades una acción, añádela a los harness.**
- **Estado** que llega al cliente: `money xp level planes pilots candidates candidatesIn regions upgrades
  settings stats goals missions daily{available,streak,lost} tutorial now fuelPrice boards refresh express
  maxPlanes autoUnlocked passes moneyMult social boostLeft timeMult cash starterBought rewardScale canSave version`
  + v0.3: `incomePerMin event eventLeft wanted{IATA=mult} wantedLeft sat{IATA=mult} album stamps stampsMax
  contracts{offers,active,slots,nextIn} charterPay{c1,c4,c8} shares newShares ipoCount runEarned airline traffic[]`.
  `boards` solo trae los aeropuertos donde hay aviones en tierra. `rewardScale` = `Game.rewardBase` (crece con los ingresos).
- **Pago** (Rules.quote, igual en servidor y cliente): base × comercial × moneyMult (incluye acciones) × piloto (estrellas,
  nivel y rasgo) × evento × ciudad en auge × saturación × ruta nueva (×1,5) × región con todos los sellos (+3 %).
  El servidor arma la «view» con `Game.view(session)` y el cliente con `Kit.view()` (mismos campos del estado).
- **Bucle del servidor (1 s)**: mundo (`Game.updateWorld`: evento y ciudades en auge), aterrizajes, saturación,
  exprés, contratos (ofertas cada 8 min, caducidad), autodespacho, candidatos, misiones del día, ritmo de ganancias
  (cada 60 s), leaderstats, `sendState`; guardado cada 60 s si hay cambios; ranking (siempre y semanal) cada 120 s.
- **Cliente**: `Kit.ctx` es el estado compartido (`state, lang, panel, selectPlane, targets, tickers,
  refreshers, act, toast, openModal, openPanel, closePanel, refreshAll, rebuild, scale, compact…`).
  `ctx.tickers` se llaman 5 veces/s; `ctx.refreshers` con cada estado. **Cambiar de idioma reconstruye toda
  la interfaz** (`ctx.rebuild`). Diseño en unidades de 1280 de ancho; un `UIScale` adapta a la pantalla;
  `ctx.compact` = pantalla baja (móvil): el mapa oculta los nombres de ciudad.
- **Tutorial** (servidor `data.tutorial`): 0 bienvenida · 1 despacha (carga especial ⭐ Madrid→Valencia,
  15 s, $3.000) · 2 espera aterrizaje (+$5.000) · 3 compra avión · 4 ficha piloto (siempre hay un candidato de
  1★ barato) · 5 reclama un objetivo (+$10.000) · 99 hecho. El cliente señala botones con `ctx.targets`:
  `play, dock_<panel>, fly_first, buy_<modelo>, hire_first, goal_claim, tab_<pestaña>, pin_<IATA>, region_<id>`.

## 5. Datos guardados

- DataStore `AeroCarga_v1`, clave `player_<UserId>`. Ranking: OrderedDataStore `AeroCargaTop_v1`,
  valor `floor(log10(1 + earned) * 1e12)`.
- Campos: `money xp planes[{id,model,airport,condition,flight?}] nextId pilots[{id,name,avatar,stars,level,flights}]
  candidates[] candidatesAt regions{id=true} upgrades{hangar,sales,fuel,fast,cold} settings{lang,muted,auto}
  stats{flights,km,tons,earned,express,localGoods,purchases,contracts,perfect,charters,newRoutes} goals{id=true}
  missions{day,list,bonusGiven} daily{last,streak} tutorial boostUntil rate receipts{} starterBought lastOnline`
  + v0.3: `album{airports{IATA=true},goods{id=n}} contracts{offers[],active[],nextAt} shares ipoCount run{earned}
  airline{a,b,c,color} week{id,earned}`. Los pilotos llevan `trait` (en partidas viejas se pone en `Game.onJoin`).
- Ranking semanal: OrderedDataStore `AeroCargaWeek_<semana>` (semana = ⌊(t − 345600) / 604800⌋, empieza el lunes UTC).
- `flight`: `{from,to,good,weight,dist,gross,fuel,fee,pilot,startT,endT,express,landing?,city?}`; `good = "ferry"` = vuelo
  vacío; `good = "charter"` = chárter (`to = from`, `pilot = -2`, `city` = destino extranjero, no sale en el mapa);
  `pilot = 0` tú, `-1` reposicionamiento. Los vuelos aterrizan aunque el jugador salga (`Game.onJoin`).
- `reconcile()` rellena campos nuevos en partidas viejas (diccionarios no vacíos).
- Si la carga falla → `canSave = false`: se juega pero **no se guarda** y sale un aviso.

## 6. Economía y sistemas (números en `Config.luau`; tablas en `DISENO.md` §5)

- Pago = t × km × `RATE` 8 × producto (📦1 … 💊1,8) × (1 + 5 % comercial) × (1 + bonus piloto) × `moneyMult`
  (amigos +10 % c/u máx 4, Premium +10 %, grupo +10 % si `GROUP_ID`≠0, VIP ×2, turbo ×2). Combustible al aterrizar.
- 6 aviones (Gorrión→Ballena), 9 regiones (Centro y Levante gratis), 5 mejoras (la frigorífica permite 🐟 y 💊).
- Pilotos: candidatos visibles (1–5★, sin sorteo de pago), suben de nivel volando; cobran el 10 %.
- Exprés cada 90–150 s en un aeropuerto con avión libre: ×2,5, caduca en 80 s (solo tras el tutorial).
- Misiones diarias (3) → x2 15 min al reclamar las 3; 41 objetivos en cadena; premio diario racha de 7.
- XP para nivel L = `220 × (L−1)^2.35`. Autodespacho desde nivel 5 (o pase). Offline: `rate × tiempo` (máx 8 h)
  × 50 % (100 % con pase), solo si el autodespacho estaba activo.
- **v0.3**: demanda (`WANTED_*`, `SAT_*`, `NEW_ROUTE_MULT`), eventos (`Config.Events`, 7 min: 5 de evento + 2 de calma),
  contratos (`Config.Companies`, nv 3, 2 huecos), chárter (`Config.Charters`, nv 2, uno a la vez), aterrizaje
  (`Config.LANDING`), bolsa (`IPO_LEVEL` 12, `IPO_MIN_SHARES` 5, `SHARE_BONUS` 0,2 de pago, `SHARE_XP_BONUS` 0,25 de XP,
  `Config.IpoPerks`), aerolínea (`Config.AirlineParts/AirlineColors`, el oro exige 1 salida a bolsa).
- Generador determinista `Config.prng(seed)` (Park-Miller): eventos y ciudades en auge iguales en todos los servidores.
  ¡No uses `Random.new(seed)` para eso! (el mock de Lune ignora la semilla).
- **Ritmo del bot perfecto**: nv 5 ≈ 8 min, nv 10 ≈ 19 min, 1.ª salida a bolsa ≈ 40–50 min, 2.ª partida nv 10 ≈ 12–13 min
  (una persona, 2–3 veces más).

## 7. Monetización

`Config.GamePasses` y `Config.Products` (`id = 0` → oculto en el juego publicado; en Studio sale como
«Muestra»). **Ningún artículo de pago es aleatorio.** Pases: `vip autopilot hangarxl turbo`. Productos:
`starter cash_s cash_m cash_l boost landall star_pilot offline2x` (4 pases y **8** productos). Precios en `DISENO.md` §6.
«Aterrizar todos» no afecta a los chárter; el piloto estrella trae el rasgo fijo `ace`.
**Pendiente: el usuario crea los artículos en el Creator Hub y te pasa los IDs.**

## 8. Verificación (OBLIGATORIO antes de cada commit)

```bash
cd roblox-carga-aerea && tools/check.sh   # la 1.ª vez descarga las herramientas (tools/setup.sh)
```

1. `luau-compile` de cada archivo (sintaxis y límite de 200 locales).
2. `luau-lsp analyze` con la API de Roblox → **0 avisos**.
3. `check_lang.py` → todas las claves usadas existen en EN y ES (incluidas las formadas con datos de Config).
4. `run_server.luau` en modo **`sin-datastore`** (Studio sin publicar) y normal (tutorial, errores, bot que
   juega 25 min y mide el ritmo, salida/entrada con offline, compras con recibos repetidos, todo desbloqueado).
5. `run_game.luau`: **servidor + interfaz reales a la vez** (remotes simulados en `mock.luau`): JUGAR, tutorial
   siguiendo `ctx.targets` (comprueba que CARGAS se cierra al despegar y pulsa ATERRIZA), todas las ventanas/pestañas,
   >10.000 botones, venta con confirmación, chárter, salir a bolsa desde la interfaz, cambio de idioma.
   Debe acabar en `JUEGO OK`. Vuelca la interfaz en `tools/out/preview/*.json`.
6. `preview.py` (Chromium + Playwright) → `tools/out/preview/*.png`: **vista previa aproximada**. Mírala tras
   cualquier cambio visual (lee los PNG). Para móvil: `python3 -I tools/harness/preview.py <carpeta> 1280 561 1`.
7. Copia el lugar a `AeroCarga.rbxl`. **Súbelo en el commit.**

## 9. Trampas encontradas (no las repitas)

- `DataStoreService:GetDataStore()` **da error en Studio sin publicar**: siempre dentro de `pcall`.
- El harness usa el lugar real construido por Rojo (`tools/out/test.rbxl`). Lune no tiene eventos,
  `AbsolutePosition` ni `ViewportSize`: `mock.luau` los simula. Pulsar un botón puede destruir otros (cambio de
  pestaña/avión) → comprobar que siguen vivos antes de pulsarlos.
- `UICorner` con escala: Roblox limita el radio a la mitad del lado corto (la vista previa lo imita).
- **No rotes contenedores con hijos** (no está claro que los hijos giren): el avión del mapa se dibuja mirando
  a izquierda o derecha. Solo llevan `Rotation` los Frames sin hijos.
- `UIGridLayout` puede pasar a otra fila por redondeos: para filas fijas usa `UIListLayout` con anchos `1/n`.
- En la cadena de objetivos el orden importa: el primero tiene que poder completarse al acabar el tutorial.
- Los tablones se generan según los aviones en tierra en ESE aeropuerto (si no, salen cargas que no caben).
- Remotes: nada de funciones ni claves mixtas en las tablas del estado (`mock.luau` lo comprueba).
- `mock.luau` conserva los `nil` en medio de argumentos y respuestas (`table.pack`), como Roblox. Antes los perdía.
- Conexiones a `RenderStepped` fuera de `ctx.tickers` hay que desconectarlas al reconstruir (cambio de idioma):
  ver `landingConn` en `Screens.landing`. El mock ya desconecta de verdad.
- En `task.delay` del cliente, comprueba `obj.Parent` antes de animar (el objeto puede haberse destruido).
- Cuadrículas de N columnas: usa celdas `UDim2.new(1/N, -(hueco+2), …)` para que el redondeo no pase una celda de fila.

## 10. Pendiente

- [ ] El usuario prueba la v0.2 en Studio y manda capturas (sobre todo móvil y la ventana Output si hay errores).
- [ ] Publicar como **experiencia nueva** (nunca reemplazar Web Empire Tycoon) y activar API Services.
- [ ] Crear los 4 pases y 8 productos y poner sus IDs en `Config`.
- [ ] Icono y miniaturas para la página de Roblox (no hechos todavía).
- [ ] Ajustar el ritmo cuando haya datos de personas reales.
- [ ] Probar con personas la v0.3: ¿se entiende el minijuego de aterrizaje y las etiquetas 🔥 ✨ 📉 📜?
- [ ] Ideas siguientes (investigación en `DISENO.md` §1 bis): carga combinada (llenar el avión con varias cargas al mismo
      destino), bases/hubs, combustible con depósito y precio cada 30 min, elegir 1 de 3 ventajas al subir de nivel,
      pase de temporada mensual, operación cooperativa semanal, sonidos propios (IDs de audio de Roblox), Roblox Plus
      (`HasRobloxSubscription`), más aviones y pinturas.

## 11. Convenciones

- Código y comentarios en **español**, tabs, estilo del archivo. Commits en español en la rama de §1 con las
  líneas de atribución del sistema. Sin identificadores de modelo de IA en commits ni código. No crear PR
  salvo que el usuario lo pida.
- Tras cambios visibles: explica qué cambia, qué verificaste, qué NO (no hay Studio) y tu % de confianza.
