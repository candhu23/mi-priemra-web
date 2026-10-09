# CLAUDE.md — Contexto del proyecto «Web Empire Tycoon» (Imperio Web Tycoon)

Este documento es el punto de partida para cualquier sesión nueva de Claude Code en este
repositorio. Léelo entero antes de tocar nada.

---

## 1. Qué es y en qué estado está

- **Juego de Roblox** tipo *tycoon* en Luau: eres un emprendedor que programa páginas web,
  las monetiza con apps de anuncios, las vende a empresas según sus visitas, hace encargos
  para empresas ficticias, funda su agencia de programadores, invierte en la Bolsa y sale a bolsa.
- **Versión actual del código: 4.0-alpha.5** (`Config.VERSION` en `TycoonConfig.luau`;
  súbelo en cada versión nueva). **La v4 está a medias: mira §14** (qué está hecho y qué falta)
  y el encargo completo en `PROMPT_V4.md` (raíz del repo).
- **Publicado en Roblox** como *Web Empire Tycoon* (creador: `Candu231`).
  - Experience (universe) ID: `10769603072`
  - Place ID (lugar de inicio): `129921526137293`
- **Repo:** `candhu23/mi-priemra-web`. La v1.2 (rama `claude/roblox-game-h5olkl`) ya está
  fusionada en `main`. La **v1.3, v2.0, v2.1, v3.0 y v3.1** están en `claude/optimistic-thompson-296nik`.
  La **v4** se hace en `claude/ecstatic-curie-dcuw5x` (parte de la v3.1). Cada sesión
  trabaja en la rama que le indique el sistema.
  El juego vive en `roblox-imperio-web/`. `index.html` en la raíz es una web personal del
  usuario, no tiene relación con el juego. Otras ramas del repo tienen otros juegos/proyectos
  del usuario (Steal an Alien, Obby de las Monedas, web SEO…): no mezclar.
- **Descarga directa del lugar** (lo que el usuario abre en Studio), v4 en curso:
  `https://github.com/candhu23/mi-priemra-web/raw/claude/ecstatic-curie-dcuw5x/roblox-imperio-web/ImperioWeb.rbxl`
  (la v3.1: `.../raw/claude/optimistic-thompson-296nik/roblox-imperio-web/ImperioWeb.rbxl`)

## 2. Sobre el usuario (cómo trabajar con él)

- Habla **español**; responde siempre en español, claro y sin jerga innecesaria.
- Preferencia explícita: **sé conservador en tus afirmaciones, da siempre tu nivel de
  confianza (%) y di qué información te falta.**
- Usa **Windows** y Roblox Studio. **No quiere tocar código**: prefiere que lo hagas tú y
  le des pasos de clic en clic. Te manda **fotos/capturas** de su pantalla.
- Tú (Claude) trabajas en un contenedor Linux en la nube: **no puedes abrir Studio ni ver
  su pantalla**. Todo lo que verifiques es con las herramientas de `tools/` (ver §8).
- Objetivo declarado del usuario: **maximizar enganche y ganancias (Robux)**. Hazlo con
  prácticas legítimas: probabilidades visibles, nada engañoso, respetar las normas de Roblox.

## 3. Estructura de archivos

```
roblox-imperio-web/
├── default.project.json        # Proyecto Rojo. Fija Lighting.Technology = Future (un script NO puede)
├── ImperioWeb.rbxl             # Lugar generado con rojo build (lo que se publica)
├── README.md                   # Guía para el usuario (en español)
├── docs/                       # Imágenes: rascacielos.png, ciudad.png, iconos/mentor_x2_xp.png
├── tools/                      # Verificación (ver §8). bin/ y out/ están en .gitignore
│   ├── setup.sh                # Descarga luau-lsp, luau, rojo 7.4.4, lune 0.10.4
│   ├── check.sh                # Verificación completa + rojo build
│   ├── harness/                # run_world / run_server / run_client (.luau para Lune) + render.py
│   └── sim/sim.luau            # Simulador de economía (bot)
└── src/
    ├── ReplicatedStorage/
    │   ├── TycoonConfig.luau   # TODOS los datos y fórmulas de economía, objetivos, tienda, sonidos,
    │   │                       #   ranking semanal (WeeklyPrizes) y eventos de fin de semana
    │   ├── CareerConfig.luau   # Nichos, 500 empresas, rangos y encargos, rarezas, especialidades
    │   │                       #   y rasgos de programadores, agencia
    │   ├── MarketConfig.luau   # Bolsa (v3): 6 empresas cotizadas, tendencias, noticias, comisión
    │   ├── CityLayout.luau     # (v3.1) Plano de la ciudad compartido: parcelas, glorieta, recorrido
    │   │                       #   de los coches (trafficPath)
    │   ├── Traffic.luau        # (v3.1) Coches que circulan: start(parent) / step(dt), en el CLIENTE
    │   ├── Locale.luau         # Idiomas: resolve / t / f / translate (ver §6 Idiomas)
    │   ├── LocaleEN.luau       # Diccionario español → inglés (~950 textos; sus claves son la lista oficial)
    │   ├── LocalePT.luau       # (v4) Diccionario español → portugués de Brasil (mismas claves)
    │   ├── Validate.luau       # (v4) number/integer/text/args: valida TODO lo que manda el cliente
    │   ├── StatePatch.luau     # (v4) diff/apply/copy/sig3/timer: el estado viaja por diferencias
    │   └── StoryConfig.luau    # (v4) Modo Historia: 5 capítulos × 6 misiones (mentora Ada)
    │   (Eras, Fusión, Legado y mecánicas de los productos nuevos: en TycoonConfig)
    ├── ServerScriptService/
    │   ├── TycoonServer.server.luau  # (v4) Orquestador: junta las acciones de los módulos, entrar/salir,
    │   │                             #   tickPlayer (1 s), bucles (guardado, ranking, analítica, envíos)
    │   ├── ServerState.luau          # (v4) sesiones, remotes, `world` (evento del servidor, meta común,
    │   │                             #   clasificaciones), notify/popup/notifyAll, gain(data, x, tag)/spend, tipos
    │   ├── Economy.luau              # (v4) ingresos, visitMult, boost, paidReward/incomeReward
    │   ├── SaveService.luau          # (v4) DataStore, newData/reconcile/migrate, bloqueo, load/save
    │   ├── RewardService.luau        # (v4) misiones, objetivos, pase, premios, diaria, regalo, códigos, I+D, tutorial
    │   ├── SiteService.luau          # (v4) webs, ofertas, negociaciones, empresas, anuncios, Bolsa, salir a bolsa
    │   ├── WorldEvents.luau          # (v4) eventos aleatorios, eventos del servidor, meta común
    │   ├── StateService.luau         # (v4) buildState/sendState/requestState (parches)
    │   ├── VisitService.luau         # (v4) visitas, me gusta, amigos
    │   ├── PurchaseService.luau      # (v4) ProcessReceipt y Game Passes
    │   ├── LeaderboardService.luau   # (v4) clasificación global/semanal y premios
    │   ├── Analytics.luau            # (v4) AnalyticsService: embudos, economía (cada 5 min), progresión
    │   ├── BadgeAwards.luau          # (v4) da las insignias de Config.Badges
    │   ├── StoryService.luau         # (v4) Modo Historia (misiones, avisos de Ada, capítulos)
    │   ├── MentorNpc.luau            # (v4) Ada en 3D (plaza y parcelas)
    │   ├── EraService.luau           # (v4) Fusión (pasar de era) y árbol de Legado
    │   ├── CareerService.luau        # Carrera: XP, encargos (tablón/aceptados/entrega), rangos,
    │   │                             #   agencia, fichajes, XP pasiva de programadores
    │   ├── MarketService.luau        # Bolsa: precios por tick (30 s), dividendos, buy/sell
    │   ├── PlotManager.luau          # Parcelas (8), cartel con "Ver imperio", terminal con ProximityPrompt
    │   ├── Showcase.luau             # Escaparate de cada parcela: edificio de la agencia,
    │   │                             #   paseo de la fama (pedestales por tipo de web), pantalla
    │   ├── AgencyOffice.luau         # (v3.1) Edificio de la agencia: plantas, mesas con gente,
    │   │                             #   salas de las mejoras de la oficina, solar en obras
    │   ├── Building.luau             # Generador del rascacielos por plantas
    │   └── World.luau                # Ciudad, iluminación, día/noche, clasificación global,
    │                                 #   edificio de la Bolsa (setMarketBoard), coches, cartel de ayuda
    └── StarterPlayerScripts/
        ├── TycoonClient.client.luau  # (v4) Junta ClientUI y hace lo común: clic, estado, idioma, carteles
        ├── ClientUI/                 # (v4) Core.luau (núcleo: piezas de interfaz, ventana, avisos,
        │                             #   ventanas emergentes; devuelve la tabla `ui`) + Tab*.luau (una
        │                             #   pestaña por módulo: `return function(ui) ... end`) + Tutorial + HudExtras
        └── TrafficClient.client.luau # Arranca Traffic y lo mueve en Heartbeat
```

Rojo mapea `src/<Servicio>` → el servicio de mismo nombre. `*.server.luau` = Script,
`*.client.luau` = LocalScript, el resto = ModuleScript.

## 4. Arquitectura

- **El servidor manda.** El cliente solo muestra y pide acciones.
- Remotes (los crea el servidor en `ReplicatedStorage.TycoonRemotes`):
  - `Action` (RemoteFunction): `InvokeServer(action, a, b)` → devuelve `(ok, mensaje?, extra?)`.
    `extra` puede llevar `{ money = true }` (suena dinero), `{ crit, power }` (clic crítico),
    `{ recruit = programador }` (animación de fichaje).
  - `State` (RemoteEvent): **v4: `FireClient(payload, isPatch)`**. La primera vez (o tras la
    acción `requestState`) va el estado completo (`isPatch = false`); luego solo un **parche**
    con lo que cambia (`StatePatch.diff` contra `session.sent`, la copia de lo último enviado).
    Se envía cada segundo (bucle) y tras cada acción salvo `click`, como mucho cada
    `Config.STATE_MIN_INTERVAL` (0,25 s; si no, `session.dirty` y lo manda un bucle rápido).
    Totales que crecen cada segundo van redondeados a 3 cifras (`StatePatch.sig3`) y los
    temporizadores en segundos enteros. Media medida ≈ 1,2 KB/s (antes ~15 KB/s + 15 KB por clic). Los temporizadores de más de 1 h van al minuto (`StatePatch.timer`).
  - `Notify` (RemoteEvent): `(texto, tipo, cuerpo?)`. tipo `popup` = ventana emergente;
    `success|error|event|goal|money|info` = avisos.
  - `OpenComputer` (RemoteEvent): abre la ventana (desde el ProximityPrompt del terminal).
  - `Visit` (RemoteEvent): ficha del imperio de otro jugador (cartel "Ver imperio" o
    acción `visitPlot`): plantas, ganado, web estrella, agencia, me gusta, `liked`, `likeReward`.
- Límite: 10 acciones/s por jugador (los clics van aparte: 15/s). **v4:** antes de cualquier
  acción `Validate.args(a, b)` rechaza NaN, infinitos y textos de más de 200 caracteres; cada
  acción valida además sus índices con `Validate.integer`.
- **Acciones del servidor** (`Actions.*` en TycoonServer + `CareerService.Actions`):
  `click, startProject, cancelProject, setAuto, upgradeSeo, upgradeDesign, setNetwork,
  setNetworkAll, setAdLevel, unlockNetwork, buyCompany, sellToOffer, quickSell, ipo,
  setNiche, claimGoal, claimDailyMission, finishTutorial, setMuted, claimDaily, claimGift,
  saveNow, acceptContract(id), abandonContract(id), workOnContract(id), askContract,
  buyStock(id, fracción del dinero), sellStock(id, fracción 0..1], foundAgency, upgradeOffice,
  recruit, redeemTicket, trainProgrammer, fireProgrammer, setLanguage, visitPlot, likePlot,
  buyResearch, claimSeason(tier, premium), claimPlaytime(i), redeemCode(texto), claimWeeklyMission(i)`;
  v4: `requestState, setVolume(0..1), setMusic(bool)`.
  `buyCompany(id, 1|10|"max")`. **`sellToOffer` ya no vende al momento**: crea `site.deal
  {endsAt, price, buyer, specialist}` y `finishDeals` (tick) cobra al acabar (también offline).
  `ACTION_FEATURES` bloquea acciones de partes no desbloqueadas (`Config.Unlocks`).
  `click` devuelve también `combo` y `comboMult`. Notify tipo `rare` = aviso grande de web rara.
  `ACTION_STATS` en el servidor mapea acciones → contadores de misiones diarias.
- Bucle del servidor (1 s): `MarketService.tick` (global), eventos aleatorios, boost, carrera
  (`CareerService.tick`: tablón de encargos, plazos, rango, XP pasiva de programadores),
  ingresos, `peakIncome`, visitas por web, trabajo automático, ofertas de clientes, objetivos,
  rascacielos, ventanas de desbloqueo (`UNLOCK_INFO`), `sendState`.
- `bonuses` por sesión (servidor): `pass, turbo, slotsPass, agencyPro, xpPass` (Game Passes),
  `boost` (temporal), `friends, premium, group`, `randomRestricted` (PolicyService),
  `agencyWork, agencyBonus (dinero), agencyQuality, agencyVisits, agencySale, agencyRare` (de los
  programadores según su especialidad: calidad en `finishProject`, visitas en `visitMult`, venta
  en `Config.saleBase(…, bonuses)`, raras en `variantChanceMult`), `weekend` (id del evento de fin de semana
  activo o nil). Las fórmulas de `TycoonConfig` los reciben.
- El estado también lleva `weekly{earned,resetIn,top}`, `weekend{id,endsIn,nextId,startsIn}`,
  `goldLeft`, `likes`, `neighbors[]` (otros jugadores del servidor) y `globalTop[]`; y desde la
  v2.0 `collection, research, patents, ipoPatents, combo, bestCombo, season{id,xp,free,premiumClaimed,
  premium,endsIn}, playtime{seconds,claimed}, starterLeft, serverEvent{id,endsIn}, community{target,
  progress,endsIn}` y `variant` en cada web. `maintenance` ya incluye la mejora de I+D.

## 5. Datos guardados

- DataStore `ImperioWeb_v1`, clave `player_<UserId>`. Clasificación: OrderedDataStore
  `ImperioWebTop_v1`, valor = `floor(log10(1 + lifetimeEarned) * 1e14)` (para cifras enormes).
  Ranking semanal: un OrderedDataStore por semana `ImperioWebSemana_v1_<semana>` (misma
  escala, con `weekly.earned`). Semana = `Config.weekIndex` (empieza el lunes 00:00 UTC).
- Guardado: cada 60 s, al salir, en `BindToClose` (espera a los pendientes), tras cada compra
  de producto, y manual (`saveNow`, enfriamiento 30 s). Si la carga falla, `canSave = false`
  y **no se guarda** (para no machacar datos). En Studio sin publicar → aviso rojo en pantalla.
- **v4 · Bloqueo de sesión (F1)**: la carga es un `UpdateAsync` que pone `data._lock =
  { jobId = game.JobId, t }`. Si otro servidor tiene un bloqueo con menos de
  `SESSION_LOCK_STALE` (300 s; se renueva en cada guardado, cada 60 s) se reintenta
  `LOCK_RETRIES` × `LOCK_RETRY_WAIT` (6 × 5 s) y si sigue, **se echa al jugador** con aviso
  traducido (`kickText`). Un bloqueo más viejo es de un servidor caído y se quita. Cada guardado
  comprueba que el bloqueo es nuestro (si no: `canSave = false`, no escribe y echa al jugador).
  Al salir (`saveData(..., true)`) se guarda y se libera. `session.closed` impide que algo
  pendiente (premio semanal…) vuelva a guardar después. `releasing[userId]` hace esperar a una
  reentrada rápida en el mismo servidor. Si el jugador se va mientras carga, `releaseLock`.
- **v4 · Compras (F2)**: si `not canSave` y no es Studio, `ProcessReceipt` devuelve
  `NotProcessedYet` sin dar nada (Roblox lo reintenta cuando vuelva).
- **v4 · Versión de la partida**: `dataVersion` (= `Config.DATA_VERSION`, 5) y `migrate(data,
  fromVersion)` tras `reconcile`. Migración a 4: `peakIncome = 0` (se recalcula sin boosts).
  Migración a 5: `story.done = true` si ya salió a bolsa o lleva ≥ $10M ganados (veteranos).
- v4 · Eras: `era` (1–3), `eraIpos` (salidas a bolsa en esta era), `eraEarned` (lo suma `gain`),
  `fusions`, `legacy` (🧬 sin gastar), `legacyTree{id=nivel}`. La Fusión reinicia como salir a
  bolsa (`SiteService.resetRun`) + `shares = 0`; NO toca I+D, patentes, colección, carrera,
  historia ni `ipoCount`.
  `reconcile` no rellena por dentro los mapas de `RECONCILE_MAPS` (sites, receipts, goals…).
- `reconcile()` rellena campos nuevos en partidas viejas. **Si añades un campo a `newData()`,
  las partidas antiguas lo reciben solas**; para campos de cada web hay una migración en
  `onPlayerAdded`.
- Campos de `data`: `money, totalEarned (se reinicia al IPO), lifetimeEarned, reputation,
  shares, ipoCount, sites[], project, autoType, companies{}, unlockedAds{}, maintenance,
  goals{id=true → reclamado}, nextSiteId, stats{built,sold,clicks,crits,byType}, daily{lastDay,streak},
  boostUntil, receipts{purchaseId=time} (últimas 50), selectedNiche, career{…}, tutorialDone,
  dailyMissions{day,list,bonusGiven}, settings{muted, lang="auto"|"es"|"en", volume (v4), music (v4)}, lastOnline,
  weekly{week,earned,prevWeek,prevEarned,rewardedWeek}, goldUntil, likes, likesGiven{day,ids{"u<id>"=true}},
  collection{tipo={normal|brillante|…=true}}, research{id=nivel}, patents, season{id,xp,free{"n"},
  premiumClaimed{"n"},premium}, playtime{day,seconds,claimed{"i"}}, codes{CÓDIGO=true}, firstJoin,
  starterBought, bestCombo, weeklyMissions{week,list,bonusGiven}`; `stats.missions` (misiones
  completadas). Cada web: `variant` (nil o id de `Config.Variants`) y `deal` (venta en curso).
- **Salir a bolsa** también da `patents` y respeta I+D (`capital` = dinero inicial, `autolab` = Lab IA 1).
  **No** se pierden colección, I+D, patentes ni pase.
- `career`: `xp{nicho=xp}, contracts[{id,companyId,type,niche,pay,rep,xp,duration,deadline(os.time)}],
  nextContractId, agency{name,officeLevel}, programmers[{id,name,rarity,niche,level,role,trait,xp}],
  nextProgrammerId, pity, tickets{premium,legendary}, stats{contracts,rank,bestRank,devLevel,expired,…}`.
  El tablón de encargos va en la sesión (`session.contractBoard`, no se guarda). `CareerService.migrate`
  quita el `job` de partidas viejas y da especialidad/rasgo a programadores antiguos.
- v3: `portfolio{empresa={units,invested}}` (Bolsa), `peakIncome` (máximo invertible = 15 min de
  esto), `stats.marketProfit`. Al salir a bolsa se vacía `portfolio` y `peakIncome`.
- **Salir a bolsa** reinicia dinero, webs, empresas, apps, reputación y mantenimiento.
  **NO** reinicia carrera, agencia, programadores, tickets, acciones, objetivos ni rascacielos.

## 6. Sistemas de juego (dónde se tocan)

Todo número de equilibrio está en `TycoonConfig.luau` o `CareerConfig.luau`.

- **Webs** (`Config.WebTypes`, 8 tipos Landing→Metaverso): trabajo, coste, visitas,
  reputación. Calidad aleatoria × Estudio de Diseño × bonus de nicho.
  Visitas = base × calidad × (1+0,1·rediseño) × 1,25^SEO × marketing × anuncios.
- **Apps de anuncios** (`Config.AdNetworks`, 7) con `rpv` (dinero/visita) y `penalty`;
  cantidad de anuncios Pocos/Normal/Muchos (`Config.AdLevels`).
- **Venta**: `saleBase = visitas × 150 × mejor rpv desbloqueado × comercial × mult`.
  Ofertas de clientes (empresas de las 500); mismo nicho ×1,5. Venta rápida ×0,6.
  Cada venta suma un contrato de mantenimiento (0,02 %/s del precio, para siempre).
- **Empresas propias** (`Config.Companies`, 8): coste `baseCost × growth^nivel`.
- **Nichos** (10) con nivel propio (XP: `40·(L-1)^1.8`). +2 % de calidad por nivel.
- **Carrera (v3: ENCARGOS)**: 500 empresas (`CareerConfig`, 50 por nicho, deterministas). Cada
  empresa tiene `payScale` fijo 0,75–1,35. Tablón de 3 encargos (llega uno cada 60–120 s, duran
  4–7 min sin aceptar; botón "pedir encargo" cada 60 s). Un encargo pide tipo de web (de los 3
  mejores que sabes hacer) + nicho, con plazo = 3 × lo que tardarías (mín. 3 min, máx. 30) y paga
  `CONTRACT_PAY` (2) × venta de una web de calidad 1 × `payMult` del rango × `payScale`.
  `workOnContract` elige el nicho y empieza la web (no ocupa hueco). Al terminarla,
  `CareerService.tryDeliver` (en `finishProject`) la entrega: cobra (x2 si sale rara), reputación,
  XP x2 y misión "contracts"; no se añade a tus webs. Rangos `Career.Ranks` (Junior→CTO) por
  encargos entregados + nivel de programador: más huecos (1/1/2/2/3) y paga (x1→x2,2).
  **Ya no hay sueldo, tareas ni ofertas de empleo.**
- **Agencia** (nivel de programador 8, $2.500): programadores de 6 rarezas
  (Común 60 %, Poco común 25 %, Raro 10 %, Épico 4 %, Legendario 0,9 %, Mítico 0,1 %).
  **Mejoras de oficina** `Career.OfficePerks` (cafe 2: XP x1.3; meeting 4: +10 %; lounge 6:
  trabajo x1.2; lab 8: +0,10 raras; rooftop 10: +20 %) y **equipo completo** (una de cada
  especialidad, +15 %), aplicados en `Career.agencyTotals`. Cada uno tiene **especialidad** (`Career.Roles`: dev=dinero, design=calidad, marketing=visitas,
  sales=venta, data=raras) y **rasgo** (`Career.Traits`: rápido, perfeccionista, noctámbulo (usa
  `World.isNight`), carismático, suertudo, mentor, incansable); `Career.programmerPower` devuelve
  (trabajo, {money,quality,visits,sale,rare}). Suben de nivel solos (`programmerXpNeeded` =
  240·L² s de trabajo). Legendario garantizado cada 60
  entrevistas (`pity`). Tickets: Headhunter Premium (aleatorio, oculto si
  `randomRestricted`) y Contrato Legendario (eliges nicho, no aleatorio).
- **Misiones**: pestaña 🎯. **6 diarias** (2 fáciles, 2 medias, 2 difíciles; tier = (i+1)//2;
  premios 1,5/3/5 min de ingresos × `REWARD_SCALE`; completarlas todas da boost x2 10 min),
  **6 semanales** difíciles (`WeeklyMissionPool`, 20 min de ingresos cada una) + objetivos
  (`Config.Goals`) que **se reclaman a mano** (`claimGoal`, `GOAL_REWARD_SCALE = 0.2`).
  Los **logros** tienen su propia pestaña 🏅 (`renderers.achievements`).
- **Ventas (v3.1, más lentas)**: `DealSeconds` 60 s (landing) → 900 s (metaverso), -2 %/nivel
  de Comercial (mín. x0,6); `maxDeals` 2 (+1 cada 15 niveles, máx. 4); ofertas de una en una
  cada `OFFER_INTERVAL` 45 s (máx. 3); venta rápida x0,5 y cada `QUICK_SALE_COOLDOWN` 90 s.
- **Tutorial** interactivo de 7 pasos (cliente), una vez por jugador (`tutorialDone`),
  premio $100, se puede repetir desde Misiones.
- **v4 · arreglos**: premios por tiempo con `atMinutes` (umbral) y `minutes` (premio) — en la
  v3.1 pagaban el umbral (F3). Salir a bolsa cobra antes las negociaciones en curso (F9).
  Offline (F10) en trozos de 10 min: boost x2 solo hasta `boostUntil`, x2 de fin de semana solo
  si lo había. Bucle de economía: `tickPlayer` con `pcall` por jugador (F8, `reportLoopError`),
  y también guardado automático, clasificación y envíos de estado. Nombres del ranking: máx. 10
  `GetNameFromUserIdAsync` por actualización. Confirmaciones reales (F12): `showConfirm` en el
  cliente (despedir, con aviso extra para Legendario/Mítico; salir a bolsa, con lo que se pierde).
  Sonido (F11): `Config.Sounds` por categorías (click, crit, success, money, error, levelUp,
  unlock, recruit, rare) con `id = ""` → "ping" con otro tono; `Config.Music` (día/noche, sin id
  no suena); botón 🔊/🔉/🔇 (`VOLUME_STEPS`) y 🎵 en la cabecera del ordenador.
- Otros: recompensa diaria (racha de 7, el 7º da boost), regalo cada 10 min, eventos
  aleatorios (viral, buscador, caída, inversor, VIP), ganancias offline (50 %, 8 h),
  clics críticos (6 %, x5), bonus amigos (+10 % c/u, máx 4), Premium +10 %, grupo +10 %
  (`GROUP_ID = 0`, desactivado).
- **Rascacielos**: plantas = `1 + floor(2,6·log10(1 + lifetimeEarned/100))`, máx 40.
  Retranqueos a 16 y 28 plantas; azotea cambia a 6/16/28 plantas. Nunca encoge.
- **Mundo (v3.1, medidas en `CityLayout`)**: glorieta en el centro (0,0,0): isla-plaza r=40 con
  fuente, SpawnLocation y cartel de ayuda; calzada hasta r=56; acera hasta r=64. Avenida en X
  hasta ±330 con rotondas en las puntas. 8 parcelas de 96 (`PLOT_X` = ±130, ±246; z = ±70) →
  **Max Players = 8**. Bolsa en z=-100, paneles (global y semanal) en z=+96. Día/noche de 16 min.
  **Coches**: los crea y mueve cada cliente (`Traffic`, CanCollide false) por `City.trafficPath()`
  (carril z=+7 hacia +X, media glorieta por el norte, vuelta en la punta, z=-7 hacia -X…).
  Ojo: en Lune `CFrame.lookAt` mira al revés; `run_world` lo corrige para los dibujos.
- **Parcela (v3.1)** (coordenadas locales; −Z = avenida): rascacielos en (-20, 12), agencia
  (`AgencyOffice`, 36×24, 1–3 plantas de 9 según `officeLevel` 1/4/8, 8 mesas por planta, mesas
  vacías = puestos libres, salas de `Career.OfficePerks`) en (24, 10), paseo de la fama en fila
  en z=-22, ordenador en (10, -34), cartel en (30, -44), piscina y pícnic detrás. Pantalla de
  la web estrella en la fachada del rascacielos. Solo se reconstruye cuando cambia (claves `teamKey`/`fameKey`).
  `PlotManager.update(player, lifetimeEarned, income, extra)` con `extra = plotExtras(session)`.
- **Visitas y me gusta**: ProximityPrompt "Ver imperio" en el cartel (12 studs, el del
  ordenador llega a 14) o botón en 🏆 Ranking. 1 me gusta por imperio y día, máx. 20/día;
  dueño +2 min de ingresos, visitante +1 min (`Config.LIKE_*`).
- **Ranking semanal**: `gain()` suma a `weekly.earned`. Al cambiar de semana (`rolloverWeek`,
  al entrar y cada segundo) lo ganado pasa a `prev*`; 10 min después (`WEEKLY_GRACE`) se mira
  el top 100 de esa semana (`ranksOfWeek`, cacheado) y se da el premio de `Config.WeeklyPrizes`
  una sola vez (`rewardedWeek`). Premio: ingresos, Contrato Legendario, `goldUntil` (rascacielos
  dorado: `Building.GOLD_STYLE`, cartel con 👑).
- **Eventos de fin de semana** (`Config.weekendStatus(t)`, viernes 20:00 → lunes 04:00 UTC,
  rotan por semana): `money` (moneyMult x2), `viral` (visitas x1.5 en `visitMult`), `contracts`
  (Feria de Encargos: pagan x1.5 y llegan el doble de rápido, en CareerService).
- **Bolsa v4 (F4/F5)**: precios **iguales en todos los servidores**. Tick global =
  `os.time() // 30`. `Market.hash(a,b,c)` es un "dado" fijo (xorshift con `bit32`); tendencia por
  bloques de 10 ticks (`Market.modeAt`), noticias por tick (`Market.newsAt`, fijan la tendencia
  6 ticks) y precio en escala log `x = (1-0,03)·x + tendencia + ruido` (`Market.step`), que olvida
  el pasado: al arrancar se calculan los últimos `WINDOW` = 1000 ticks (`Market.xAt`, ~20 ms) y
  da igual cuándo arrancó cada servidor. El historial es un anillo (`history` + `head`). La
  tendencia real **no se envía**: el cliente ve `rumor` (up/down/flat) del analista, que acierta
  `RUMOR_ACCURACY` 60 % + I+D `analyst` (+5 %/nivel, máx. 80 %); es fijo por (empresa, bloque,
  jugador). Dividendo 0,05 %/tick. `peakIncome` se calcula sin boost ni x2 de fin de semana.
  Lo de abajo (v3) sigue valiendo salvo el movimiento de precios:
- **Bolsa (v3)** (`MarketConfig` + `MarketService`, idea del mercado de Cookie Clicker): 6 empresas
  con `rest` (valor justo) y `vol`. Cada `TICK` (30 s) el precio cambia por la tendencia (`Modes`:
  stable/slowRise/slowFall/fastRise/fastFall/chaotic) + ruido + un 3 % de vuelta al valor justo,
  limitado a ×0,2–×4. Tras dispararse, 60 % de hundirse. `NEWS_CHANCE` 8 %/tick: noticia a todo el
  servidor que fija fastRise/fastFall. Inversión en participaciones (dinero/precio), comisión 2 %,
  dividendo 0,15 %/tick, máximo por empresa `Market.cap(peakIncome)`. Al vender, solo el
  beneficio cuenta como ganado (`gain`). Mundo: `World.setMarketBoard` en cada tick.
- **Claridad (v3)**: `TAB_HELP` (línea "ℹ️" arriba de cada pestaña; sus claves en LocaleEN llevan
  el "ℹ️ "), `UNLOCK_INFO` (ventana al desbloquear cada parte), empresas con "Ahora → al subir"
  (`companyEffect` en el cliente), pestaña propia **💡 I+D** (`research`, feature "market").
- **v4 · Idiomas**: español, inglés y **portugués de Brasil** (`LocalePT`, mismas claves que
  `LocaleEN`). Botón 🌐 ES → EN → PT. "auto": `pt*` → portugués. `Locale.isValid(lang)` en el
  servidor. **Todo texto nuevo va a LocaleEN y a LocalePT** (los harness fallan si falta).
- **Idiomas** (`Locale` + `LocaleEN`): el código sigue en español. El cliente traduce:
  `T("texto")` / `T("plantilla %s", x)` para lo suyo; `create()` traduce solo los textos fijos
  que estén en el diccionario (y guarda `SrcText` para cambiar de idioma en caliente);
  `setButton` también; `bindText(obj, fn)` para textos fijos calculados. Lo que manda el servidor
  (toasts, popups, nombre de evento, motivo de ascenso) y los carteles del mundo se traducen con
  `TR()` = `Locale.translate`, que busca qué plantilla encaja (las claves de LocaleEN con %s/%d
  sirven de patrón) y traduce los trozos. **El servidor no traduce nada**: sus mensajes nuevos
  hay que añadirlos a LocaleEN con la forma final (literal `%` como `%%`). Idioma = `settings.lang`
  o, en "auto", `Player.LocaleId` (es* → español; si no, inglés). Nombres de empresas, de
  programadores y de webs NO se traducen (son nombres propios).

- **v2.0 (todo en `TycoonConfig`)**:
  - **Webs raras** `Config.Variants` (se tira de la más rara a la menos; `variantChanceMult` = I+D
    "luck" × Tormenta de datos x5, tope x10) → multiplican visitas en `siteVisits`.
  - **Colección** `collectionStats/collectionBonus` (+1 %/casilla, +10 %/tipo completo) en `moneyMult`.
  - **I+D** `Config.Research` (4 ramas, 12 mejoras), `research()/researchValue()/researchCost()`;
    patentes = acciones/4 (mín. 1).
  - **Hitos** `COMPANY_MILESTONES` x1.5 cada uno (`companyMult`), compra en bloque `companyAffordable`.
  - **Combo** `comboMult` (hasta x3 con 50 clics seguidos, ventana 0,8 s; sesión, no se guarda).
  - **Pase** temporadas de 4 semanas (`seasonIndex`), 30 niveles × 200 ⭐ (`Config.SeasonXp`),
    premios `Config.seasonReward(tier, premium)`. Premium = Developer Product `seasonPremium`.
  - **Premios por tiempo** `Config.PlaytimeRewards` (por día UTC). **Códigos** `Config.Codes`.
  - **Eventos del servidor** `Config.ServerEvents` (globales en TycoonServer: `serverEvent`,
    `serverEventIs`, tinte con `PlotManager.setEventTint`). **Meta común** `community` (objetivo =
    7 min de ingresos de todos; recompensa 8 min de ingresos + ⭐).
  - **Pack de inicio** producto `starter` (72 h desde `firstJoin`, una vez).
- **v2.1 (más difícil, a petición del usuario)**:
  - **Desbloqueo progresivo** `Config.Unlocks` por planta del rascacielos (clientes 2, anuncios y
    ranking 3, empresas y pase 4, carrera 5, colección 6, agencia 7, bolsa/I+D 9). Cliente:
    `TAB_FEATURES`, `tabLocked`, `refreshTabButtons`; servidor: `ACTION_FEATURES` + aviso
    "🔓 Desbloqueado" al subir de planta (`UNLOCK_NAMES`).
  - **Negociaciones**: `Config.DealSeconds` por tipo (20 s → 180 s; -3 %/nivel de Agencia Comercial,
    tope -50 %), `Config.maxDeals` (2 + 1 cada 10 niveles de Comercial, máx. 5). Venta rápida sigue
    siendo instantánea (x0,6).
  - **Misiones semanales** `Config.WeeklyMissionPool` (4 por semana, cuentan las mismas
    estadísticas que las diarias en `progressDaily`); completar las 4 = 2 patentes + boost 30 min.
    Diarias más difíciles (cantidades ~x1,7).
  - **Logros** `Config.Achievements` (10 logros × 5 niveles, bonus permanente por nivel:
    money/click/visits/sale/work/rare vía `Config.achievementBonus`).
  - **Recompensas gratis rebajadas**: `Config.REWARD_SCALE = 0.6` en `incomeReward` (las compras
    con Robux usan `paidReward`, sin rebaja). Objetivos ×0,35, offline 35 %, regalo 2 min,
    `SALE_SECONDS` 130.

- **v4 · Interfaz por centros** (`ClientUI/Core`): `HUBS` = 5 centros (🛠️ Producción: create,
  sites, ads · 💼 Negocio: clients, companies, career, agency · 📈 Inversión: market, research,
  ipo · 🎯 Progreso: missions, achievements, season, collection · 🛒 Tienda y social: shop,
  ranking). Barra de centros (54 de alto) y debajo las sub-pestañas del centro (52), nunca más de
  5 por fila. `selectHub(id)` abre la última pestaña vista del centro; `hubOfTab`, `TabById`,
  `ui.currentHub`; avisos (!) por pestaña y sumados por centro. Pestaña nueva `ipo` (🔔 Salir a
  bolsa: tarjeta de salida a bolsa + estadísticas; `renderers.ipo = renderers.market`). La
  ventana tiene escala propia (`ui.resizeWindow`, mín. 0,85: botones ≥ 44 px en móvil) y en
  pantallas bajas se acorta (descuenta `GuiService:GetGuiInset()`). Para añadir una pestaña:
  entrada en `TABS`, en un `HUBS[].tabs`, `TAB_HELP`, `TAB_FEATURES` si se desbloquea, y su módulo.
- **v4 · Analítica** (`Analytics.luau`, todo con pcall): embudo de los primeros minutos
  (`Analytics.Onboarding`, un paso por jugador nuevo en su primera hora, `data.analytics.onboarding`),
  embudo "Tutorial" (el cliente manda `tutorialStep(i)`), economía: `gain(data, x, tag)` y
  `spend(data, x, tag)` suman por categoría y se envía cada `FLUSH_INTERVAL` (300 s) y al salir;
  progresión "Rascacielos" (plantas) y "SalidasABolsa"; eventos sueltos (WebRara, Codigo).
  Se ve en Creator Hub → experiencia → Analytics (Funnels, Economy, Progression, Custom).
- **v4 · Insignias** `Config.Badges` (12, al final de TycoonConfig, `id = 0` = desactivada):
  `BadgeAwards.check` cada 10 s y `BadgeAwards.give(…, "weekly_top")` al dar el premio semanal.
  `data.badges[key] = true` cuando ya se dio; si Roblox falla, reintento a los 5 min.

## 7. Monetización

`Config.Monetization` en `TycoonConfig.luau`. `id = 0` → el artículo no aparece.

| key | Tipo | ID real | Precio actual |
|---|---|---|---|
| `pass` | Game Pass x2 Money | `2008580363` | 99 |
| `turbo` | Game Pass Turbo Coder | `2009090346` | 149 |
| `slotsPass` | Game Pass +3 Website Slots | `2006769799` | 49 |
| `agencyPro` | Game Pass Agency Pro | `2008664354` | 239 |
| `xpPass` | Game Pass Mentor x2 XP | `2006871734` | 99 |
| `cash_small`, `cash_big`, `boost`, `finish`, `headhunter`, `headhunter5`, `legendary`, `starter`, `seasonPremium` | Developer Products | **pendientes (id = 0)** | — |

- `ProcessReceipt` es idempotente (`data.receipts`) y solo confirma tras guardar.
- **El creador es dueño de sus propios pases**: en su cuenta la tienda muestra "✓ Ya lo tienes".
- Recomendado al usuario: **no crear los Headhunter** (artículo aleatorio de pago) para no
  complicar el cuestionario de contenido; el Contrato Legendario sí.

## 8. Verificación (OBLIGATORIO antes de cada commit)

```bash
cd roblox-imperio-web && tools/check.sh      # descarga herramientas la 1ª vez (tools/setup.sh)
```

1. `luau-compile` de cada archivo (detecta sintaxis y el **límite de 200 locales**).
2. `luau-lsp analyze` con definiciones de la API de Roblox → debe dar **0 avisos**.
3. `run_world.luau` (Lune): ejecuta World/Building/PlotManager reales con instancias de Lune
   (valida nombres y tipos de propiedades) y vuelca las piezas.
4. `run_server.luau`: arranca el servidor real con servicios simulados y dos jugadores falsos
   que recorre todas las acciones, compras, guardado, salida y reentrada. Debe acabar en `TODO OK`.
   Además traduce al inglés todo lo que ha dicho el servidor y falla si algo se queda en español
   (el detalle de cada traducción está en `tools/out/server.txt`, líneas `[en]`).
5. `run_client.luau`: crea toda la interfaz, le pasa el estado real del servidor
   (`tools/out/state.json`, `visit.json`) y **pulsa todos los botones** + recorre el tutorial.
   Luego cambia a inglés con el botón 🌐, vuelve a pulsarlo todo y falla si queda algún texto
   en español o si el cliente pide una clave que no está en LocaleEN. Debe dar `CLIENTE OK`.
6. `sim.luau`: bot de economía 6 h (ritmo actual, v3.1 con ventas lentas: $1M ≈ 42 min,
   $100M ≈ 1 h 25 min, Metaverso ≈ 4 h 45 min para un bot perfecto; un humano va bastante más
   lento; en la v3.1 se bajó la reputación de Red Social/Streaming/IA/Metaverso para compensar). Ajuste v3 sobre la v2.1: rpv ×0,75, ingresos de
   empresas ×0,75, coste base de empresas ×1,5, reputación de webs ×1,4, trabajo de webs ×1,3.
   El bot no cuenta las webs raras (≈ +20 % de dinero de media) ni la Bolsa.
7. `rojo build` → regenera `ImperioWeb.rbxl` (solo si todo lo anterior pasa). **Súbelo en el commit.**

**v4 en el harness del servidor**: el DataStore simulado guarda **copias JSON** (como Roblox) y
admite que `UpdateAsync` cancele (devolver nil); `storeFail[clave]` simula una caída;
`game.JobId = "servidor-A"`; `RunService:IsStudio()` = `studioMode`. `FireClient` también copia
en JSON y `lastState(who)` **reconstruye** el estado aplicando los parches (como el cliente) y
devuelve una copia. `Config.STATE_MIN_INTERVAL = 0` en el harness (la prueba F7 lo activa).
`task.wait` solo cede dentro de `task.spawn` (en el hilo principal no espera). Las pruebas de
los fallos F1–F10 usan `check(id, cond, texto)` y fallan todas juntas al final; hay jugadores
extra con `makePlayer(nombre, userId)` (Luis 44, Marta 45, Pablo 46). El harness del cliente
también prueba un parche de estado.

Limitaciones de Lune a recordar (el harness ya las simula): no tiene eventos (`Activated`,
`Touched`…), ni `AbsolutePosition`, ni `ViewportSize`; `fs.readFile` es asíncrono (precargar);
devuelve objetos distintos para la misma instancia (se identifican por el atributo `__hid`);
`GetTagged` simulado debe ignorar instancias destruidas. Si añades acciones nuevas, **añádelas
al harness del servidor**. En el harness del servidor hay dos jugadores (Jorge 42 y Ana 43):
`lastState(who)` filtra por destinatario; hay un límite de 10 acciones/s (avanza `fakeTime`).
Las clasificaciones simuladas se guardan por nombre y se ordenan.

## 9. Trampas ya encontradas (no las repitas)

- **`UIGradient` dentro de un TextLabel/TextButton tiñe también el TEXTO.** Para objetos con
  texto usa `shade()` (degradado gris) y pon el color en `BackgroundColor3`.
- **Luau: máximo 200 variables locales por función.** El cliente está dividido en bloques
  `do ... end` por pestaña; lo que se comparte entre pestañas se declara arriba
  ("Variables compartidas entre pestañas") y se asigna dentro con `function nombre()` / `nombre =`.
- Una función local usada antes de su `local function` es un **global nil** en ejecución:
  declara antes (`local f: tipo` y luego `function f()`), como `progressDaily`.
- **Solo un `UIScale` por objeto**: `makeButton` ya crea uno (animación). Para escalar un botón
  suelto, mételo en un Frame contenedor con `autoScale()` (ver `computerHolder`).
- `Lighting.Technology` no se puede cambiar por script → va en `default.project.json`.
- Los cilindros de Roblox van a lo largo del eje X: girar 90° en Z para ponerlos de pie.
- Usa `IsFriendsWithAsync` / `IsInGroupAsync` (las versiones sin Async están obsoletas).
- Traducciones: una clave de LocaleEN con `%s` encaja también en textos de **varias líneas**
  (el `.` de Lua coge saltos de línea); por eso `translate` solo prueba plantillas multilínea
  con textos multilínea y si no, traduce línea a línea. Ojo con `"+10 % de"`: `% d` es un
  especificador de formato; en plantillas escribe `%%`.
- El botón 🌐 cambia el idioma: en el harness del cliente se salta al pulsar "todos los botones"
  en español (si no, cambia de idioma un número impar de veces).
- (v4) El **cliente está al límite de 200 locales en el nivel superior**: lo nuevo va en tablas
  (`audio`) o en bloques `do … end` (el manejador del estado). El bloque 2 de la v4 lo divide
  en módulos.
- (v4) `UpdateAsync` puede llamar a la función varias veces: reinicia en ella todo lo que
  calcule (`locked`, `loaded`…).
- (v4) El detector de "texto en español" del harness es una lista de palabras; añade palabras
  si un texto nuevo se le escapa (pasó con "Se cerraron N ventas que…").
- (v4) Una tabla del estado que se ordena de nuevo cada segundo hace parches enormes: manda las
  listas en orden fijo (p. ej. programadores por id) y ordena en el cliente.
- (v4) **Módulos del cliente**: lo que cambia en caliente o lo define una pestaña y lo usa otra va
  en la tabla `ui` (`ui.state`, `ui.lang`, `ui.doClick`, `ui.nicheLabel`, `ui.currentTab`…);
  los alias `local x = ui.x` del principio de cada módulo solo sirven para cosas que no cambian.
  Los módulos del servidor siguen un orden sin ciclos: ServerState → Economy → SaveService →
  RewardService → SiteService → WorldEvents → StateService → VisitService → PurchaseService →
  LeaderboardService (uno solo puede requerir a los anteriores).
- (v4) En TycoonConfig, una función que use `Config.algo` definido más abajo hace fallar el
  análisis de tipos: pon esos bloques al final (como `Config.Badges`).

## 10. Publicar una versión nueva (flujo del usuario)

1. Tú: cambias código → `tools/check.sh` → commit + push (con el `.rbxl` regenerado).
2. Usuario: descarga el `.rbxl` (enlace de §1), lo abre en Studio, **Stop** si hay prueba en
   marcha, **File → Publish to Roblox As… → Web Empire Tycoon → Reemplazar**
   (nunca "añadir lugar nuevo": el lugar de inicio no se puede cambiar).
3. Para que los servidores abiertos cojan la versión: Creator Hub → Places → ⋯ →
   *Shut Down All Servers* / *Migrate to Latest Update*.
- Si "Publish As" se queda colgado: reiniciar Studio, mirar status.roblox.com; plan B =
  abrir la experiencia desde *Mis experiencias* y editar ahí.
- Los ajustes de la web (nombre, descripción, Max Players 8, pases, iconos, API Services)
  y las partidas guardadas **no se pierden** al reemplazar.

## 11. Normas de Roblox que afectan (2026)

- **Juegos nuevos limitados a 16+** hasta tener **250 jugadores muy activos** (16+ con edad
  verificada) o pagar **50.000 Robux** (reembolsables a 90 días). El contenido del juego es
  "Minimal"; no es culpa del cuestionario. El usuario tiene ~7 Robux → camino gratis.
- Cuestionario de contenido: todo "No" (no hay violencia, sangre, miedo, humor grosero,
  palabrotas…). Artículos aleatorios de pago: responder "Sí" solo si se venden Headhunters.
- Probabilidades visibles obligatorias para artículos aleatorios (el juego las muestra).
- Studio necesita "Enable Studio Access to API Services" para guardar al probar.
- Las miniaturas pasan moderación antes de verse (sale la imagen por defecto mientras).

## 12. Pendiente / ideas siguientes

- [ ] Crear Developer Products y poner sus IDs (sin Headhunters si se sigue el consejo).
- [ ] Publicar la versión con tutorial, misiones, ofertas de empleo y botón único (v1.2).
- [ ] Imágenes de los Game Passes (4 en Canva + `docs/iconos/mentor_x2_xp.png`).
- [x] **Sistema de idiomas ES/EN** (v1.3).
- [x] Escaparate 3D, visitas y me gusta; ranking semanal con premios; eventos de fin de
      semana (v1.3). **Sin probar en Studio** todavía: revisar con el usuario cómo se ven.
- [x] v2.0: webs raras, colección, I+D, pase, premios por tiempo, eventos del servidor, meta
      común, combo, hitos y compra en bloque, códigos, pack de inicio. **Sin probar en Studio.**
- [x] v2.1: desbloqueo por plantas, negociaciones de venta, misiones semanales, logros, recompensas
      rebajadas. **Sin probar en Studio.**
- [x] v3.0: Bolsa nueva (el usuario dijo que olvidara Fleet Empire), carrera de encargos con
      rangos, programadores con especialidad/rasgo y XP pasiva, ayudas por pestaña y al
      desbloquear, I+D en su pestaña, mapa (Bolsa, coches, pasos de cebra, cartel de ayuda),
      economía más lenta. **Sin probar en Studio.**
- [x] v3.1: ciudad con glorieta central y tráfico, parcelas de 96, edificio de la agencia con
      gente y mejoras de oficina, ventas más lentas, 6+6 misiones, logros aparte. **Sin probar en Studio.**
- [ ] Publicar la v3.1. Poner en la descripción (en inglés) las novedades y los códigos.
- [ ] Crear los productos `starter` (pack de inicio, ~99–199 R$) y `seasonPremium` (~199–399 R$).
- [ ] Conseguir los 250 jugadores 16+ (TikTok/Discord) para abrir a todas las edades.
- [ ] Ajustar precios de pases (x2 Money a 99 parece barato; 199–299 es lo habitual).
- [ ] Ideas: mascotas/skins del rascacielos, más idiomas (portugués: Brasil es un mercado
      enorme en Roblox), insignias (Badges) para el top semanal.

## 13. Convenciones

- Código y comentarios en **español**, estilo del archivo que toques (tabs, `--` cortos).
- Commits en español, en la rama que indique el sistema, con las líneas de atribución
  que indique el sistema. No crear PR salvo que el usuario lo pida.
- Textos nuevos visibles: escríbelos en español en el código y añade su traducción a
  `LocaleEN.luau` (en el cliente, envuelve con `T(...)`).
- No poner identificadores de modelo de IA en commits ni en el código.
- Tras cambiar algo visible, explica al usuario qué cambia, qué verificaste, qué NO pudiste
  verificar (no hay Studio aquí) y tu % de confianza.

## 14. Estado de la v4.0 (encargo en `PROMPT_V4.md`)

Se hace por bloques, un commit por bloque con `check.sh` en verde:

- [x] **Bloque 1 · fallos F1–F12** (4.0-alpha.1). Pruebas en `run_server.luau` (F1a–g, F2a–b,
  F3, F4a–b, F5a–c, F6, F7a–c, F8, F9, F10). F10 tal como lo describía el encargo no ocurría
  (si el boost sigue activo al entrar, estuvo activo todo el rato offline); se arregló el caso
  contrario (boost que acabó estando fuera) y el x2 de fin de semana.
- [x] **Bloque 2 · base técnica** (4.0-alpha.2): servidor en 12 módulos, cliente en ClientUI/
  (Core + 15 pestañas + Tutorial + HudExtras), analítica, 12 insignias, portugués (947 textos).
  Pruebas A1–A4 y B1 en `run_server.luau`; pasada completa en PT en `run_client.luau`.
- [x] **Bloque 3 · interfaz por 5 centros** (4.0-alpha.3). Harness del cliente: tamaños en
  844×390, 390×844 y 1920×1080 (≥ 44 px, cabe), 5 centros, cada pestaña en uno, cada centro abre lo suyo.
- [x] **Bloque 4 · Modo Historia** (4.0-alpha.4). `StoryConfig` (5 capítulos × 6 misiones con
  `value(d)`/`target`, premio por misión en minutos de ingresos y premio por capítulo con
  `RewardService.giveReward`), `StoryService` (mira la misión cada segundo, máx. una por tick;
  Notify `story` = aviso de Ada, `chapter` = ventana de capítulo; embudo de analítica "Historia";
  acción `talkToAda`), `MentorNpc` (Ada hecha con piezas: en la plaza y junto al ordenador de cada
  parcela, ProximityPrompt → abre la pestaña 📖 Historia y saluda). Cliente: `TabStory` (centro
  🎯 Progreso, primera pestaña), la tarjeta de misión del HUD muestra la de la historia mientras
  no esté acabada, y al acabar un capítulo hay media vuelta de cámara (6 s) alrededor de tu parcela.
  `data.story = {chapter, mission, done}`. Pruebas H1–H9 y A5 en `run_server.luau`.
  Para que los parches sigan < 2 KB: progreso/premio con `sig3` y `StatePatch.timer` (los
  temporizadores de más de 1 h van al minuto; `formatTime` no enseña segundos ahí).
- [x] **Bloque 5 · productos nuevos + Eras y Fusión** (4.0-alpha.5). En `TycoonConfig`:
  - 6 `WebTypes` con `era` (2: buscador, banco, cloud · 3: videojuego, superapp, cuantica) y
    `mech` → `Config.Mechanics` (search: +8 % visitas a las demás; bank: intereses 0,01 %/s del
    dinero con tope 3× su ingreso, en `siteIncome`; cloud: +2 huecos en `slots`; seasons: x3
    2,5 min de cada 10 con `Config.gameSeason(Config.clock())`; superapp: +3 % por tipo distinto;
    quantum: x2 raras en `variantChanceMult`). Cada mecánica cuenta hasta `MECH_MAX` = 4 webs.
  - 3 `AdNetworks` y 3 `Companies` con `era` (fintech, gamestudio, quantumlab).
    `Config.eraAllows(data, def)` lo comprueban servidor (crear, auto, anuncios, empresas,
    ofertas, encargos) y cliente (candados "🔒 Era N").
  - `Config.Eras` (moneyMult x1/x2/x4), `Config.Fusions` ({ipos 5, $5e15}, {ipos 6, $5e20}),
    `LEGACY_PER_SQRT` (🧬 = 2·√acciones), `LegacyTree` (15 nodos en 3 ramas, `requires`) con
    `Config.legacy/legacyValue/legacyCost`; sus efectos están en las fórmulas (moneyMult,
    siteVisits, workPerSec, clickPower, saleBase, dealSeconds, slots, companiesIncome,
    patentsForShares/sharesForIpo con `data`, `startMoney`, `startReputation`, `repReward`).
  - **Cambio de equilibrio importante**: el simulador mostró que salir a bolsa una y otra vez
    se disparaba sin fin (10¹⁷ acciones en 3 h; el dinero de una partida crece ~x75 cuando el
    multiplicador crece x3). Ahora `sharesForIpo = 10·(1+log10(ganado/$1M))^SHARES_POWER(2)` (igual
    que antes con $1M–$100M) y `Config.shareMult` con tope suave: +5 %/acción hasta
    `SHARE_SOFTCAP` (100), luego ×(acciones/100)^0,5. Usa siempre `Config.shareMult`.
  - Servidor: `EraService` (acciones `fusion`, `buyLegacy`; feature "market"), estado `eras{…}`
    + `era` + `legacyTree`. Insignia `first_fusion`. Rascacielos por era (`Building.ERA_STYLES`,
    anillo de neón `AnilloEra`, holograma en la Era 3; `PlotManager` reconstruye si cambia `era`).
  - Cliente: pestaña `TabFusion` (🧬 Fusión, centro Inversión) con confirmación y árbol.
  - `sim.luau [horas] [debug]` ahora sale a bolsa (cuando el bonus x2, o tras 2,5 h si x1,25),
    compra I+D y Legado y fusiona. `Config.clock` lo sustituye el simulador. `check.sh` lo corre
    40 h. Bot perfecto: $1M 42 min · $1B 2 h 18 · 1ª salida 50 min · **1ª Fusión 11 h 48 ·
    Era 3 28 h 25**. Con las reglas de la v3.1: 479 millones de acciones a las 12 h.
  - Pruebas E1–E11 en `run_server.luau`; el harness del cliente pone Legado y Fusión lista.
- [ ] Bloque 6 · sede 3D jugable + minijuegos.
- [ ] Bloque 7 · P2 (rivales, vehículos, estilos, bots, eventos de temporada, social).
- [ ] Bloque 8 · P3 (consorcios: explicar riesgos antes).

