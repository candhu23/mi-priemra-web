# PROMPT · Web Empire Tycoon v4.0 «Imperio Digital»

> Prompt para pegar en una sesión nueva de Claude Code sobre el repo `candhu23/mi-priemra-web`.
> Lo redactó una sesión anterior tras revisar a fondo la v3.1 (código, verificación automática y
> economía). Copia desde la línea `=== INICIO DEL PROMPT ===` hasta el final.

---

=== INICIO DEL PROMPT ===

Eres el desarrollador de **Web Empire Tycoon** (Imperio Web Tycoon), mi juego de Roblox en Luau.
Quiero la **versión 4.0**: un cambio grande que (1) arregle los fallos que tiene la v3.1, (2)
ponga una base técnica sólida y (3) añada **mucho contenido nuevo**. Trabaja tú en el código;
yo no toco código, solo abro Studio y publico. Háblame siempre en español, sé conservador en
lo que afirmas, dame tu **% de confianza** en cada respuesta y di **qué información te falta**.

## 0. Antes de empezar (obligatorio)

1. La última versión del juego **NO está en `main`**: está en la rama
   `claude/optimistic-thompson-296nik` (v3.1, commit `a65bfe6`). `main` tiene la v1.2.
   Trae la v3.1 a tu rama de trabajo (la que te indique el sistema) con un merge de
   `origin/claude/optimistic-thompson-296nik` y trabaja sobre ella. No toques otras ramas
   (hay otros juegos míos: Steal an Alien, Dungeon Ascend, etc.).
2. Lee **entero** el `CLAUDE.md` de la v3.1 (raíz del repo). Tiene la arquitectura, los datos
   guardados, las trampas ya encontradas (§9) y el flujo de verificación (§8). Respétalo.
3. Ejecuta `cd roblox-imperio-web && tools/check.sh`. En la v3.1 da **TODO CORRECTO ✅**
   (0 avisos, servidor `TODO OK`, `CLIENTE OK`). Tiene que seguir así tras cada bloque de trabajo.
4. Ojo: desde la v1.3 **nada se ha probado en Studio** (solo con el harness de Lune). Todo lo
   que hagas debe poder verificarse con `tools/` y además debes darme al final una lista de
   comprobaciones para hacer yo en Studio (paso a paso, de clic en clic).

## 1. Fallos encontrados en la v3.1 (arréglalos PRIMERO, con prueba en el harness)

Las líneas son de la v3.1. Para cada fallo: reprodúcelo en `tools/harness/run_server.luau`
(que falle), arréglalo y comprueba que la prueba pasa.

| # | Gravedad | Fallo | Dónde | Arreglo esperado |
|---|---|---|---|---|
| F1 | 🔴 Alta | **Sin bloqueo de sesión en el guardado.** `GetAsync` al entrar y `UpdateAsync` que devuelve `session.data` a ciegas. Si el jugador cambia de servidor rápido (o vuelve al mismo antes de que acabe el guardado de salida) el servidor nuevo carga datos viejos y luego uno machaca al otro → **pérdida de progreso o de compras con Robux**. | `TycoonServer.server.luau:1869` (loadData) y `:1907` (saveData) | Bloqueo de sesión dentro de `UpdateAsync`: campo `data._lock = { jobId = game.JobId, t = os.time() }`; al cargar, si hay un lock de otro servidor con menos de 30 min, reintentar varias veces (p. ej. 6 × 5 s) y si sigue, robarlo solo si está caducado; al guardar, comprobar que el lock es nuestro (si no, no guardar y avisar); al salir, liberar el lock. Añade `dataVersion = 4` y una función `migrate(data)` por versión. (Alternativa válida: integrar ProfileStore de loleris, licencia MIT, si lo ves más seguro; explica por qué). |
| F2 | 🔴 Alta | **Compra con Robux perdida si la carga falló.** Si `canSave = false` (DataStore caído al entrar) `ProcessReceipt` da el producto y devuelve `PurchaseGranted` sin guardar: al volver a entrar el jugador no lo tiene. | `TycoonServer.server.luau:1810` | Si `not session.canSave` y no estamos en Studio → `NotProcessedYet` (Roblox lo reintenta cuando el jugador vuelva). En Studio sin publicar, se puede seguir concediendo para probar. |
| F3 | 🔴 Alta | **Premios por tiempo jugado pagan de más.** `giveReward` usa `reward.minutes` antes que `rewardMinutes`/`boostMinutes`, pero en `Config.PlaytimeRewards` `minutes` es el **umbral** (5, 10, 15, 25, 40, 60). Resultado: el de 40 min paga 40 min de ingresos (anuncia 15) y el de 60 min da **boost de 60 min** (anuncia 20). El harness nunca lo detectó porque no llega a reclamar ninguno. | `TycoonServer.server.luau:1566` y `:1570`; datos en `TycoonConfig.luau` `PlaytimeRewards` | Renombrar el umbral a `atMinutes` (o pasar a `giveReward` un objeto premio limpio) y añadir al harness una prueba que avance el tiempo, reclame los 7 premios y compruebe la cantidad exacta. |
| F4 | 🔴 Alta | **La Bolsa se puede explotar cambiando de servidor.** Cada servidor tiene precios propios (empiezan en `rest × 0,85–1,15`). Compras cuando está a ×0,2 del valor justo, cambias de servidor y vendes a ~×1: hasta **×5** sobre el máximo invertible (15 min de ingresos × 6 empresas). | `MarketService.luau:64` | **Precios deterministas iguales en todos los servidores**: tick global = `os.time() // 30`; semilla por (empresa, día UTC); al empezar el día el precio es `rest` y se simula hacia delante hasta el tick actual (≤ 2.880 pasos, barato); tendencias y noticias también sembradas por tick. Así todos los servidores ven el mismo precio a la vez. |
| F5 | 🟠 Media | **La Bolsa es dinero gratis**: la tendencia real (`mode`) se envía al cliente y se muestra («Tendencia: 🚀 Se dispara»), y además el dividendo es 0,15 %/tick (≈18 %/hora). | `MarketService.luau:147`; cliente `TycoonClient.client.luau:3116` | Ocultar la tendencia. En su lugar, «📰 Rumor del analista» que acierta un 60 % (mejorable con I+D hasta ~80 %). Dividendo a ~0,05 %/tick. `peakIncome` sin contar boosts temporales (ahora un boost x2 sube el máximo invertible para siempre: `:2657`). |
| F6 | 🟠 Media | **NaN en `sellStock`**: `buy` comprueba `fraction ~= fraction` pero `sell` no. Un exploiter que mande NaN deja su `money` en NaN y puede romper su guardado. | `MarketService.luau:191` | Validar NaN e infinito. Crear un helper común `validNumber(x, min, max)` y usarlo en **todas** las acciones que reciben números (índices, niveles, fracciones, ids). |
| F7 | 🟠 Media | **El estado completo se envía demasiado.** `sendState` manda todo (≈15 KB con 6 webs; la Bolsa sola ≈6 KB con 288 puntos de historial) **cada segundo y tras cada acción, incluidos los clics (hasta 15/s)** → hasta cientos de KB/s por jugador. Probable lag en móvil. | `TycoonServer.server.luau:900` y el despachador `:1719-1723` | Estado en dos partes: «rápido» (dinero, ingresos, progreso, temporizadores) cada 1 s, y «completo» solo cuando algo cambió (marca `session.dirty`). El clic NO manda estado (el cliente ya predice el progreso). Historial de la Bolsa solo cuando cambia el tick. Máx. 4 envíos/s por jugador. Mide el tamaño en el harness y falla si el estado rápido pasa de ~2 KB. |
| F8 | 🟠 Media | **Un error en un jugador para la economía de todo el servidor**: el bucle principal `while true do` no tiene `pcall` por jugador; si algo da error con los datos de uno, el bucle muere y nadie gana dinero ni se guarda en automático. | `TycoonServer.server.luau:2563` | `pcall` por jugador dentro del bucle (con `warn` y contador de errores), y bucles de guardado/clasificación también protegidos. |
| F9 | 🟡 Baja | Salir a bolsa **borra las negociaciones en curso** sin avisar (se pierde ese dinero). | `TycoonServer.server.luau:1246` | Cobrarlas al salir a bolsa o avisar en la confirmación cuánto se pierde. |
| F10 | 🟡 Baja | Ganancias offline: si al entrar sigue activo un boost, se aplica x2 a **todas** las horas offline aunque el boost acabara antes. | `TycoonServer.server.luau:2219` | Calcular offline sin boost + la parte con boost solo hasta `boostUntil`. |
| F11 | 🟡 Baja | **Todos los sonidos son el mismo** (`electronicpingshort.wav` con distinto tono) y no hay música. | `TycoonConfig.luau` `Config.Sounds` | Sistema de sonido con categorías (clic, crítico, dinero, error, subir de nivel, desbloqueo, fichaje, música de fondo por día/noche) y volumen/música desactivables. Los IDs de la Creator Store **los tengo que elegir yo**: déjalos en `Config.Sounds` con un comentario claro y dame la lista de qué buscar. |
| F12 | 🟡 Baja | Despedir programadores y salir a bolsa solo se confirman en el cliente (doble pulsación). | Cliente `:2447`, `:3087` | Ventana de confirmación real; para Legendarios/Míticos y para la salida a bolsa, mostrar lo que se pierde. |

También revisa (no lo he comprobado del todo): `reconcile` recorre `receipts`/`goals` como
plantillas (correcto pero frágil); los nombres de jugador del ranking (`GetNameFromUserIdAsync`)
sin límite de llamadas; y que ningún `task.spawn`/`task.delay` use una sesión ya cerrada.

## 2. Base técnica de la v4 (después de los fallos)

1. **Analítica** con `AnalyticsService` (embudo del tutorial y de los primeros 30 min,
   eventos de economía de entrada/salida de dinero, progresión por planta). Comprueba en
   `globalTypes.d.luau` los nombres exactos de los métodos antes de usarlos. Sin esto no
   sabremos qué funciona: es prioritario para «maximizar enganche».
2. **Insignias** (`BadgeService`): 12 hitos (primera web, primera venta, planta 10/20/40,
   primera salida a bolsa, primer Legendario, top 100 semanal…). Los IDs los creo yo en el
   Creator Hub: déjalos en `Config.Badges` con `id = 0` = desactivada, y dame los pasos.
3. **Organización del código**: el cliente tiene ≈4.150 líneas en un archivo y el servidor
   ≈2.700. Divide en módulos (`ClientUI/` por centro, `Economy`, `SaveService`,
   `RewardService`, `StateService`…) sin cambiar el comportamiento. Mantén el límite de 200
   locales y actualiza los harness.
4. **Idioma portugués (pt-BR)** además de ES/EN (Brasil es un mercado enorme en Roblox):
   `LocalePT.luau` con la misma mecánica que `LocaleEN`, y el harness del cliente también
   debe fallar si queda texto sin traducir en portugués.

## 3. Contenido nuevo de la v4 (lo grande)

Prioridades: **P1** = imprescindible en la 4.0; **P2** = 4.1; **P3** = 4.2 si da tiempo.
Todos los números de equilibrio en `TycoonConfig`/`CareerConfig`/módulos de config nuevos.
Cada sistema nuevo: datos en `newData()` (las partidas viejas lo reciben solas con
`reconcile`), acciones validadas en el servidor, añadidas al harness, textos en ES/EN/PT.

### 3.1 Interfaz nueva por «centros» (P1)
15 pestañas son demasiadas (sobre todo en móvil). Reorganiza en **5 centros** con
sub-pestañas: **🛠️ Producción** (Crear, Webs, Anuncios) · **💼 Negocio** (Clientes, Empresas,
Carrera, Agencia) · **📈 Inversión** (Bolsa, I+D, Salir a bolsa, Fusión) · **🎯 Progreso**
(Misiones, Historia, Logros, Pase, Colección) · **🛒 Tienda y social** (Tienda, Ranking,
Amigos, Personalizar). Diseño pensado primero para **móvil** (botones ≥ 44 px, nada de 8
pestañas por fila). Mantén los avisos (!) por centro.

### 3.2 Modo Historia «Del garaje al imperio» (P1)
Sustituye/amplía el tutorial: **5 capítulos × 6 misiones** guiadas por una mentora PNJ
(«Ada», en la plaza y en tu sede), con diálogos cortos, recompensas y una cinemática simple
de cámara al acabar cada capítulo (Garaje → Startup → Empresa → Corporación → Imperio). Debe
llevar de la mano los primeros **30–45 minutos** y presentar cada parte del juego justo
cuando se desbloquea. Registra cada paso en la analítica (embudo).

### 3.3 Nuevos productos digitales: 6 tipos más (de 8 a 14) (P1)
Tras el Metaverso, en dos tandas (Era 2 y Era 3, ver 3.4):
Buscador 🔎 · Banco Digital 🏦 · Plataforma Cloud ☁️ · Videojuego Online 🎮 · Superapp 📱 ·
Red Cuántica ⚛️. Cada uno con trabajo, coste, visitas, reputación, tiempo de negociación y
**una mecánica propia** (ej.: el Banco Digital paga intereses según su tamaño, el Videojuego
tiene «temporadas» con picos de visitas, el Cloud alquila capacidad a tus otras webs).
Añade 3 apps de anuncios y 3 empresas nuevas acordes, y sus casillas en la Colección.

### 3.4 Eras y «Fusión» (segunda capa de prestigio) (P1)
Ahora el final del juego es salir a bolsa una y otra vez. Añade **Eras**: Era 1 «Web clásica»
(lo actual) → Era 2 «Plataformas» → Era 3 «Futuro». Se pasa de era con una **Fusión**: requiere
X salidas a bolsa y un mínimo de ganado; reinicia también acciones y empresas, pero da
**🧬 Legado** (moneda permanente) para un árbol de mejoras propio (≈15 nodos) y desbloquea los
tipos de web de la era. La ciudad cambia de aspecto por era en tu parcela (fachada, luces,
azotea). Ajusta con `sim.luau` para que un bot perfecto llegue a la primera Fusión en ~10–12 h
de juego y a la Era 3 en ~30 h (un humano tardará bastante más). Explica la curva.

### 3.5 Sede 3D jugable: que el mundo sirva para algo (P1)
Hoy casi todo pasa en una ventana. Convierte la parcela en una **sede por la que se camina**
con puestos interactivos (ProximityPrompt) que abren su parte del ordenador y tienen efecto
visible: **Ordenador** (crear), **Sala de servidores** (un rack por web, luces según sus
visitas; si hay «caída», ir a repararla da un bonus), **Sala de juntas** (negociaciones),
**Oficina** (tus programadores sentados con su rareza visible), **Laboratorio** (I+D) y
**Garaje** (vehículos, 3.8). Reutiliza `Showcase`/`AgencyOffice`/`Building`. Cuida el
rendimiento: en la v3.1 hay ≈3.500 piezas; marca un tope (p. ej. 6.000 con 8 jugadores) y
usa `StreamingEnabled` si hace falta (comprueba qué rompe en el cliente).

### 3.6 Minijuegos cortos y opcionales (P1)
Tres minijuegos de 10–20 s, sin castigo si fallas, que dan multiplicadores:
- **🐛 Depurar**: aparece código con 3 bugs resaltables; encuéntralos antes de que acabe el
  tiempo → la web sale con +calidad (hasta +25 %). Cada 2 min como máximo.
- **🤝 Negociar**: barra de regateo con «zona buena» que se mueve; pararla a tiempo sube el
  precio de la venta (0–20 %) o acorta la negociación.
- **🛡️ Ciberataque**: cuando un evento de hackers ataca tus webs, tocas los ataques que llegan
  (tipo «whack-a-mole»); si los paras no pierdes visitas.
Todo se valida en el servidor (el cliente solo manda el resultado; el servidor limita el
máximo posible por tiempo y frecuencia para que no se pueda trucar).

### 3.7 Rivales y ciberseguridad (P2)
**5 corporaciones rivales (PNJ)** con nombre, logo y personalidad, que compiten por **cuota de
mercado por nicho**. Cada semana hay una «guerra de cuota» en un nicho: si superas al rival
ganas premios y un trofeo en tu parcela. Eventos de **hackers** (con el minijuego 3.6) y una
empresa nueva **🔐 Ciberseguridad** que reduce daños. Nada de robar a otros jugadores (es
PvE, para que no sea tóxico).

### 3.8 Vehículos y personalización (P2)
- **Vehículos**: comprar coches/motos/patinetes con dinero del juego y conducirlos por la
  avenida y la glorieta (ya existen). Más velocidad para ir al panel, la Bolsa, la plaza.
  Modelos simples hechos con piezas (sin mallas externas).
- **Estilos de rascacielos**: Cristal, Neón, Art Decó, Eco (con jardines), Cyberpunk. Se
  consiguen con logros, eventos y algunos con Robux (cosméticos, no dan ventaja).
- **Bots compañeros** (mascotas tech: dron, robot, gato píxel…) que te siguen y dan un bonus
  pequeño. Se consiguen con misiones/eventos o compra directa **no aleatoria**. Si haces
  alguna caja aleatoria, solo con moneda del juego (nunca Robux) y con probabilidades visibles.

### 3.9 Eventos de temporada con moneda propia (P2)
Un sistema genérico de eventos de 1–2 semanas (Halloween hacker, Black Friday digital,
Navidad en la nube, Verano gamer…): moneda del evento, misiones del evento, tienda del evento
con cosméticos exclusivos y una web de edición limitada en la Colección. Que se puedan
programar por fechas en la config sin tocar código.

### 3.10 Social (P2–P3)
- **Ayudar a un amigo**: en su parcela puedes «echar una mano» (clics a su web) una vez cada
  X min; los dos ganáis algo.
- **Proyecto conjunto del servidor** (mejorar la «meta común» actual): un megaproyecto con
  barra visible en la plaza.
- **Consorcios** (clanes entre servidores) con ranking semanal propio (P3, solo si da tiempo:
  necesita DataStore/MemoryStore y es lo más arriesgado; explícame los riesgos antes).
- **Calendario de 30 días** (sustituye la racha de 7) con premio grande el día 30.
- **Notificaciones de experiencia** opcionales («tu negociación ha terminado», «tu
  recompensa diaria te espera») si Roblox lo permite para este juego: compruébalo y dime qué
  tengo que activar.

## 4. Monetización (legítima, respetando las normas de Roblox)

1. Lo que más dinero deja ahora mismo **no es código**: los **9 Developer Products tienen
   `id = 0`** y no aparecen en la tienda. Dame una guía de clic en clic para crearlos en el
   Creator Hub y pon sus IDs cuando te los pase. Recomendación: **no** crear los Headhunter
   (artículos aleatorios de pago), sí el resto.
2. Pases nuevos propuestos (dime precio orientativo y que es orientativo):
   **⏰ Gestor nocturno** (offline 35 % → 70 % y 8 h → 16 h), **🤖 Asistente automático**
   (auto-vender a la mejor oferta y auto-reclamar misiones), **🏎️ Garaje VIP** (vehículo
   exclusivo), **👑 VIP** (etiqueta en el chat, estilo dorado, +10 % de dinero).
3. Cosméticos con Robux (estilos de rascacielos, bots compañeros, vehículos): **nunca
   aleatorios con Robux**.
4. Ventanas de oferta en momentos clave (al desbloquear algo, al acabar el boost, al
   quedarse sin huecos) pero **sin ser pesadas**: como mucho 1 cada 10 min y con «no volver a
   mostrar».
5. Nada que dé ventaja en el ranking semanal solo por pagar más allá de los multiplicadores
   que ya existen; y mantén `PolicyService` para ocultar lo que Roblox restrinja a cada jugador.

## 5. Equilibrio y verificación

- Actualiza `sim.luau` para que simule también las Eras, la Fusión, los minijuegos (con una
  tasa de acierto realista) y la Bolsa nueva. Dame una tabla: tiempo hasta $1M, $1B, primera
  salida a bolsa, primera Fusión, Era 3, comparada con la v3.1.
- Amplía `run_server.luau` y `run_client.luau` con **todas** las acciones nuevas (y las
  pruebas de F1–F10). `tools/check.sh` debe acabar en **TODO CORRECTO ✅** antes de cada commit.
- Regenera `ImperioWeb.rbxl` con `rojo build` y súbelo en cada commit.

## 6. Forma de trabajar y entrega

- Es mucho trabajo: hazlo **por bloques**, en este orden, con un commit (en español) por
  bloque y `check.sh` en verde: (1) fallos F1–F12 → (2) base técnica → (3) interfaz por
  centros → (4) Historia → (5) productos nuevos + Eras/Fusión → (6) sede 3D + minijuegos →
  (7) P2 → (8) P3. Sube `Config.VERSION` («4.0-alpha.N» mientras tanto, «4.0» al acabar P1).
- Si se te acaba el contexto, **deja escrito en `CLAUDE.md` qué está hecho y qué falta**
  para que otra sesión siga sin perderse.
- Actualiza `CLAUDE.md` (secciones de archivos, datos guardados, sistemas, monetización,
  trampas nuevas) y el `README.md` del juego con «Novedades de la v4».
- No crees PR salvo que te lo pida. No pongas identificadores de modelo de IA en commits ni
  en el código.
- Al terminar cada bloque, dime: qué cambia para el jugador, qué verificaste, **qué NO pudiste
  verificar** (no tienes Studio), tu % de confianza, y una **lista de pruebas en Studio** para
  mí (qué pulsar y qué debería ver). Dame también el enlace directo de descarga del `.rbxl`
  de tu rama y recuérdame: Publish to Roblox As… → Web Empire Tycoon → Reemplazar.

## 7. Lo que no sé (pregúntamelo si lo necesitas)

- Si la v3.1 está publicada ya y cuántos jugadores tiene (jugadores simultáneos, retención
  D1/D7, cuánto se ha vendido). Si te paso capturas del panel de Analytics del Creator Hub,
  úsalas para priorizar.
- Si ya he creado algún Developer Product o cambiado precios de pases.
- Si tengo grupo de Roblox (para activar `GROUP_ID`) o servidor de Discord.
- Si quiero que la v4 reinicie el progreso de los jugadores (**recomendado: NO**, migrar las
  partidas) o los rankings.

=== FIN DEL PROMPT ===
