# CLAUDE.md — Contexto del proyecto «Web Empire Tycoon» (Imperio Web Tycoon)

Este documento es el punto de partida para cualquier sesión nueva de Claude Code en este
repositorio. Léelo entero antes de tocar nada.

---

## 1. Qué es y en qué estado está

- **Juego de Roblox** tipo *tycoon* en Luau: eres un emprendedor que programa páginas web,
  las monetiza con apps de anuncios, las vende a empresas según sus visitas, trabaja en
  empresas ficticias, funda su agencia de programadores y sale a bolsa.
- **Versión actual del código: 1.3** (`Config.VERSION` en `TycoonConfig.luau`; súbelo en
  cada versión nueva).
- **Publicado en Roblox** como *Web Empire Tycoon* (creador: `Candu231`).
  - Experience (universe) ID: `10769603072`
  - Place ID (lugar de inicio): `129921526137293`
- **Repo:** `candhu23/mi-priemra-web`. La v1.2 (rama `claude/roblox-game-h5olkl`) ya está
  fusionada en `main`. La **v1.3** está en `claude/optimistic-thompson-296nik`. Cada sesión
  trabaja en la rama que le indique el sistema.
  El juego vive en `roblox-imperio-web/`. `index.html` en la raíz es una web personal del
  usuario, no tiene relación con el juego. Otras ramas del repo tienen otros juegos/proyectos
  del usuario (Steal an Alien, Obby de las Monedas, web SEO…): no mezclar.
- **Descarga directa del lugar** (lo que el usuario abre en Studio), v1.3:
  `https://github.com/candhu23/mi-priemra-web/raw/claude/optimistic-thompson-296nik/roblox-imperio-web/ImperioWeb.rbxl`

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
    │   ├── CareerConfig.luau   # Nichos, 500 empresas, puestos, ofertas, rarezas, agencia
    │   ├── Locale.luau         # Idiomas: resolve / t / f / translate (ver §6 Idiomas)
    │   └── LocaleEN.luau       # Diccionario español → inglés (~575 textos)
    ├── ServerScriptService/
    │   ├── TycoonServer.server.luau  # Script principal: datos, acciones, tick, compras, guardado
    │   ├── CareerService.luau        # Lógica de carrera: XP, trabajo, ofertas, agencia, fichajes
    │   ├── PlotManager.luau          # Parcelas (8), cartel con "Ver imperio", terminal con ProximityPrompt
    │   ├── Showcase.luau             # Escaparate de cada parcela: oficina con programadores,
    │   │                             #   paseo de la fama (pedestales por tipo de web), pantalla
    │   ├── Building.luau             # Generador del rascacielos por plantas
    │   └── World.luau                # Ciudad, iluminación, día/noche, clasificación global
    └── StarterPlayerScripts/
        └── TycoonClient.client.luau  # TODA la interfaz (≈3.200 líneas)
```

Rojo mapea `src/<Servicio>` → el servicio de mismo nombre. `*.server.luau` = Script,
`*.client.luau` = LocalScript, el resto = ModuleScript.

## 4. Arquitectura

- **El servidor manda.** El cliente solo muestra y pide acciones.
- Remotes (los crea el servidor en `ReplicatedStorage.TycoonRemotes`):
  - `Action` (RemoteFunction): `InvokeServer(action, a, b)` → devuelve `(ok, mensaje?, extra?)`.
    `extra` puede llevar `{ money = true }` (suena dinero), `{ crit, power }` (clic crítico),
    `{ recruit = programador }` (animación de fichaje).
  - `State` (RemoteEvent): el servidor envía el **estado completo** cada segundo y tras cada acción.
  - `Notify` (RemoteEvent): `(texto, tipo, cuerpo?)`. tipo `popup` = ventana emergente;
    `success|error|event|goal|money|info` = avisos.
  - `OpenComputer` (RemoteEvent): abre la ventana (desde el ProximityPrompt del terminal).
  - `Visit` (RemoteEvent): ficha del imperio de otro jugador (cartel "Ver imperio" o
    acción `visitPlot`): plantas, ganado, web estrella, agencia, me gusta, `liked`, `likeReward`.
- Límite: 10 acciones/s por jugador (los clics van aparte: 15/s).
- **Acciones del servidor** (`Actions.*` en TycoonServer + `CareerService.Actions`):
  `click, startProject, cancelProject, setAuto, upgradeSeo, upgradeDesign, setNetwork,
  setNetworkAll, setAdLevel, unlockNetwork, buyCompany, sellToOffer, quickSell, ipo,
  setNiche, claimGoal, claimDailyMission, finishTutorial, setMuted, claimDaily, claimGift,
  saveNow, acceptJobOffer, sendCV, quitJob, solveTask, foundAgency, upgradeOffice,
  recruit, redeemTicket, trainProgrammer, fireProgrammer, setLanguage, visitPlot, likePlot`.
  `ACTION_STATS` en el servidor mapea acciones → contadores de misiones diarias.
- Bucle del servidor (1 s): eventos aleatorios, boost, carrera (`CareerService.tick`:
  XP del trabajo, ascensos, ofertas de empleo), ingresos, visitas por web, trabajo
  automático, ofertas de clientes, objetivos, rascacielos, `sendState`.
- `bonuses` por sesión (servidor): `pass, turbo, slotsPass, agencyPro, xpPass` (Game Passes),
  `boost` (temporal), `friends, premium, group`, `randomRestricted` (PolicyService),
  `agencyWork, agencyBonus` (de los programadores), `weekend` (id del evento de fin de semana
  activo o nil). Las fórmulas de `TycoonConfig` los reciben.
- El estado también lleva `weekly{earned,resetIn,top}`, `weekend{id,endsIn,nextId,startsIn}`,
  `goldLeft`, `likes`, `neighbors[]` (otros jugadores del servidor) y `globalTop[]`.

## 5. Datos guardados

- DataStore `ImperioWeb_v1`, clave `player_<UserId>`. Clasificación: OrderedDataStore
  `ImperioWebTop_v1`, valor = `floor(log10(1 + lifetimeEarned) * 1e14)` (para cifras enormes).
  Ranking semanal: un OrderedDataStore por semana `ImperioWebSemana_v1_<semana>` (misma
  escala, con `weekly.earned`). Semana = `Config.weekIndex` (empieza el lunes 00:00 UTC).
- Guardado: cada 60 s, al salir, en `BindToClose` (espera a los pendientes), tras cada compra
  de producto, y manual (`saveNow`, enfriamiento 30 s). Si la carga falla, `canSave = false`
  y **no se guarda** (para no machacar datos). En Studio sin publicar → aviso rojo en pantalla.
- `reconcile()` rellena campos nuevos en partidas viejas. **Si añades un campo a `newData()`,
  las partidas antiguas lo reciben solas**; para campos de cada web hay una migración en
  `onPlayerAdded`.
- Campos de `data`: `money, totalEarned (se reinicia al IPO), lifetimeEarned, reputation,
  shares, ipoCount, sites[], project, autoType, companies{}, unlockedAds{}, maintenance,
  goals{id=true → reclamado}, nextSiteId, stats{built,sold,clicks,crits,byType}, daily{lastDay,streak},
  boostUntil, receipts{purchaseId=time} (últimas 50), selectedNiche, career{…}, tutorialDone,
  dailyMissions{day,list,bonusGiven}, settings{muted, lang="auto"|"es"|"en"}, lastOnline,
  weekly{week,earned,prevWeek,prevEarned,rewardedWeek}, goldUntil, likes, likesGiven{day,ids{"u<id>"=true}}`.
- `career`: `xp{nicho=xp}, job{companyId,rank,rankSince,salaryMult,xpMult}, agency{name,officeLevel},
  programmers[{id,name,rarity,niche,level}], nextProgrammerId, pity, tickets{premium,legendary}, stats{…}`.
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
- **Carrera**: 500 empresas (`CareerConfig`, 50 por nicho, deterministas). Cada empresa tiene
  `payScale` fijo 0,75–1,35. **Las ofertas de empleo llegan solas** cada 50–100 s (máx. 4,
  caducan en 3–5 min) con multiplicadores aleatorios de sueldo (0,7–1,6) y XP (0,8–1,5);
  se puede **enviar currículum** (enfriamiento 45 s). Puestos Junior→CTO con ascenso
  automático por tiempo + nivel. Tarea cada 40 s (paga 60 s de sueldo).
- **Agencia** (nivel de programador 8, $2.500): programadores de 6 rarezas
  (Común 60 %, Poco común 25 %, Raro 10 %, Épico 4 %, Legendario 0,9 %, Mítico 0,1 %).
  Cada uno da trabajo/s y **% extra a todo el dinero**. Legendario garantizado cada 60
  entrevistas (`pity`). Tickets: Headhunter Premium (aleatorio, oculto si
  `randomRestricted`) y Contrato Legendario (eliges nicho, no aleatorio).
- **Misiones**: pestaña 🎯. 3 diarias (fácil/media/difícil, `Config.DailyMissionPool`,
  premio en minutos de ingresos; completar las 3 da boost x2 10 min) + 30 objetivos
  (`Config.Goals`) que **se reclaman a mano** (`claimGoal`). Premios escalados con
  `Config.GOAL_REWARD_SCALE = 0.5`.
- **Tutorial** interactivo de 7 pasos (cliente), una vez por jugador (`tutorialDone`),
  premio $100, se puede repetir desde Misiones.
- Otros: recompensa diaria (racha de 7, el 7º da boost), regalo cada 10 min, eventos
  aleatorios (viral, buscador, caída, inversor, VIP), ganancias offline (50 %, 8 h),
  clics críticos (6 %, x5), bonus amigos (+10 % c/u, máx 4), Premium +10 %, grupo +10 %
  (`GROUP_ID = 0`, desactivado).
- **Rascacielos**: plantas = `1 + floor(2,6·log10(1 + lifetimeEarned/100))`, máx 40.
  Retranqueos a 16 y 28 plantas; azotea cambia a 6/16/28 plantas. Nunca encoge.
- **Mundo**: 8 parcelas (por eso **Max Players = 8**), avenida, plaza con fuente,
  SpawnLocation, panel de clasificación, día/noche de 16 min (la noche va x2). Panel del
  **top semanal** de dos caras en mitad de la avenida (x = 0).
- **Escaparate de la parcela** (`Showcase.luau`, coordenadas locales de la parcela; −Z = avenida):
  oficina al aire libre a la derecha (x≈23, 8 mesas 2×4 con los mejores programadores; rareza
  ≥ Legendario → PointLight + aureola + partículas), paseo de la fama a la izquierda (8
  pedestales, Neon si `stats.byType[tipo] > 0`, el mejor con luz), pantalla en la 1ª planta
  de la fachada con la web estrella. Solo se reconstruye cuando cambia (claves `teamKey`/`fameKey`).
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
  rotan por semana): `money` (moneyMult x2), `viral` (visitas x1.5 en `visitMult`), `jobs`
  (sueldo y XP x1.5, ofertas de empleo el doble de rápido, en CareerService).
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

## 7. Monetización

`Config.Monetization` en `TycoonConfig.luau`. `id = 0` → el artículo no aparece.

| key | Tipo | ID real | Precio actual |
|---|---|---|---|
| `pass` | Game Pass x2 Money | `2008580363` | 99 |
| `turbo` | Game Pass Turbo Coder | `2009090346` | 149 |
| `slotsPass` | Game Pass +3 Website Slots | `2006769799` | 49 |
| `agencyPro` | Game Pass Agency Pro | `2008664354` | 239 |
| `xpPass` | Game Pass Mentor x2 XP | `2006871734` | 99 |
| `cash_small`, `cash_big`, `boost`, `finish`, `headhunter`, `headhunter5`, `legendary` | Developer Products | **pendientes (id = 0)** | — |

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
6. `sim.luau`: bot de economía 6 h (ritmo actual: $1M ≈ 11 min, Metaverso ≈ 56 min
   para un bot perfecto; un humano va bastante más lento).
7. `rojo build` → regenera `ImperioWeb.rbxl` (solo si todo lo anterior pasa). **Súbelo en el commit.**

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
- [ ] Publicar la v1.3. Poner en la descripción del juego (en inglés) los eventos de fin
      de semana y el ranking semanal.
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
