# 🌐 Imperio Web Tycoon · v2.0 (juego de Roblox)

Eres un emprendedor que programa páginas web. Las monetizas con anuncios, las vendes a empresas según sus visitas, fundas tus propias empresas y acabas sacando tu imperio a bolsa mientras tu rascacielos se convierte en el más alto de Ciudad Web. **El objetivo: ganar todo el dinero posible.**

## Novedades de la v2.0
Ideas sacadas de los juegos que mejor funcionan (Grow a Garden, Pet Simulator 99, AdVenture Capitalist, Egg Inc. y las guías oficiales de Roblox):
- **✨ Webs raras** (como las mutaciones): al terminar una web puede salir ✨ Brillante (x2 visitas, 8 %), 🌈 Arcoíris (x4, 2 %), 💎 Diamante (x10, 0,5 %) o 🌌 Cósmica (x30, 0,1 %). Las 💎 y 🌌 se anuncian a todo el servidor. Probabilidades visibles.
- **📖 Colección**: casillas tipo de web × rareza. Cada casilla nueva da **+1 % de dinero para siempre** y cada tipo completo **+10 %**.
- **💡 Patentes e I+D**: al salir a bolsa ganas patentes y las gastas en 12 mejoras **permanentes** (dinero inicial, ventas, clics, huecos, visitas, suerte, oficina…), en la pestaña 📈 Bolsa.
- **🎫 Pase de temporada** (4 semanas, 30 niveles): ⭐ con misiones, objetivos, tiempo jugado, ventas y metas del servidor. Columna gratis y columna Premium (Developer Product).
- **⏱️ Premios por tiempo jugado** cada día (5, 10, 15, 25, 40, 60 y 90 min) y nueva misión "Juega X minutos".
- **⚡ Eventos del servidor** para todos a la vez, cada 8–14 min: Hora punta (visitas x2), Tormenta de datos (webs raras x5), Black Friday (clientes x2), Hackatón (clics x3). El cielo cambia de color.
- **🤝 Meta del servidor**: entre todos hay que ganar una cantidad en 15 min y el premio es para todos.
- **🔥 Combo de clics**: si tecleas seguido, cada clic vale hasta x3.
- **🏢 Empresas**: comprar **x1 / x10 / MÁX** e **hitos** a los niveles 10, 25, 50, 100, 150 y 200 (cada uno x1,5).
- **🎟️ Códigos** en la Tienda (para TikTok/Discord): `LANZAMIENTO`, `WEBEMPIRE`, `V2`.
- **🎁 Pack de inicio** (Developer Product, solo las primeras 72 h, una vez) y nuevas misiones y objetivos.

## Novedades de la v1.3
- **Inglés y español**: el juego usa el idioma de la cuenta de Roblox de cada jugador (español si la tiene en español; si no, inglés). Botón **🌐 ES / EN** arriba en la ventana del ordenador para cambiarlo (se guarda). También se traducen los carteles de la ciudad, solo en la pantalla de cada uno.
- **Tu imperio se ve en la parcela**:
  - **Oficina de la agencia** al aire libre: tus 8 mejores programadores trabajando en su mesa, con el color de su rareza y su nombre encima. Los **Legendarios y Míticos brillan** y llevan aureola.
  - **Paseo de la fama**: un pedestal por cada tipo de web que se ilumina cuando la has programado (con cuántas llevas). La mejor brilla.
  - **Pantalla en la fachada** con tu web estrella y sus visitas.
  - **Visitas y "me gusta"**: en el cartel de cada parcela hay **Ver imperio**. Se abre la ficha del jugador y puedes darle **👍 Me gusta** una vez al día: los dos ganáis dinero.
- **Pestaña 🏆 Ranking**:
  - **Ranking semanal** (dinero ganado en la semana; se reinicia el lunes a las 00:00 UTC) con premios: #1 y #2–3 → Contrato Legendario + **rascacielos dorado 7 días** + horas de ingresos; #4–10 → dorado + ingresos; #11–100 → ingresos.
  - Panel del top semanal **en mitad de la avenida**.
  - Lista de jugadores del servidor para visitarlos.
- **Eventos de fin de semana** (viernes 20:00 → lunes 04:00 UTC), uno distinto cada semana: **💰 x2 Dinero**, **🔥 Viral** (+50 % visitas) y **💼 Feria de Empleo** (ofertas el doble de rápido, sueldo y XP x1.5). Aviso al entrar y cuenta atrás en pantalla.

## Novedades de la v1.2
- **Tutorial interactivo** al empezar (para todos los jugadores, una vez): resalta cada botón y da $100 al terminarlo. Se puede repetir desde 🎯 Misiones.
- **Pestaña 🎯 Misiones**: 3 misiones diarias (fácil, media y difícil; completar las 3 da un boost x2) y todos los objetivos con barra de progreso y botón **Reclamar**. Premios de los objetivos a la mitad.
- **Un solo botón 💻 Ordenador** en el lateral, con contador de avisos; las pestañas de dentro muestran sus propios avisos.
- **Ofertas de empleo aleatorias**: cada empresa paga distinto y las ofertas te llegan solas con sueldo y XP aleatorios (también puedes enviar currículums).
- Botón para silenciar los sonidos (se guarda).
- `CLAUDE.md` en la raíz con todo el contexto del proyecto y `tools/check.sh` para verificarlo todo.

## Novedades de la v1.1
- **Arreglado**: los textos de los botones (precios, mejoras...) no se veían. Era un degradado que también teñía el texto.
- **Arreglado**: la interfaz superaba el límite de 200 variables locales de Luau y no habría arrancado; ahora cada pestaña va en su bloque.
- **Ficha de cada web** (🌐 Webs → 🔍 Abrir): visitas en directo con gráfica, visitas y dinero totales, comparativa de **lo que pagaría cada app de anuncios** por visita en esa web, cantidad de anuncios con lo que ganarías, mejoras (SEO y rediseño) y la mejor oferta de compra.
- **Nichos** (10): eliges el nicho de tus webs. Cada nicho tiene nivel propio: +2 % de calidad por nivel, y las empresas de ese nicho pagan **x1.5**.
- **💼 Carrera**: 500 empresas ficticias (50 por nicho) donde puedes trabajar. Cobras sueldo, resuelves tareas cada 40 s y asciendes de Junior a CTO.
- **👥 Agencia** (desde nivel de programador 8): ficha programadores de 6 rarezas (Común → Mítico). Programan por ti y dan un % extra de TODO tu dinero. Puedes entrenarlos y ampliar la oficina. Hay un Legendario garantizado cada 60 entrevistas. La carrera y la agencia **no se pierden al salir a bolsa**.
- **Guardado**: ahora cada 60 s, botón **💾 Guardar ahora** (📈 Bolsa), indicador del último guardado y aviso rojo con instrucciones si está desactivado.
- **Tienda**: nuevos pases (🏙️ Agencia Pro, 🎓 Mentor x2 XP) y productos (🎯 Headhunter Premium x1/x5, 👑 Contrato Legendario).

## Novedades de la v1.0
- **Ciudad nueva**: iluminación realista (*Future*), atmósfera, *bloom*, ciclo de día y noche (las ventanas y farolas se encienden de noche), avenida con aceras y farolas, plaza con fuente, árboles, arco de bienvenida y un horizonte de edificios al fondo.
- **Rascacielos rehecho**: vestíbulo con marquesina y letrero, plantas con ventanales y montantes, retranqueos al crecer y una azotea que evoluciona (máquinas → depósito de agua → helipuerto con baliza → corona con aguja). Las plantas nuevas aparecen con animación y destellos. **Crece con todo lo que has ganado y nunca encoge.**
- **Interfaz nueva**: menú lateral con avisos (!), misión guiada en pantalla, botón **PROGRAMAR** siempre visible (tecla **F**), golpes críticos, números flotantes, sonidos, ventanas emergentes y escalado automático para móvil, tablet y PC.
- **Para que vuelvan**: recompensa diaria con racha de 7 días (el día 7 da un boost x2), regalo gratis cada 10 minutos, 23 objetivos con premio, bonus por jugar con amigos (+10 % cada uno), bonus Premium y de grupo, y clasificación global en la plaza.
- **Para ganar Robux**: 3 Game Passes y 4 Developer Products preparados (ver abajo).

## Cómo se juega
1. **🖥️ Crear**: elige una web (Landing Page → Blog → Tienda Online → Periódico Digital → Red Social → Streaming → App de IA → Metaverso) y pulsa **PROGRAMAR**. Los tipos nuevos se desbloquean con ⭐ reputación.
2. **🌐 Webs**: cada web tiene visitas por segundo y gana dinero con anuncios. Puedes mejorar su **SEO**, cambiar su **app de anuncios**, elegir **cuántos anuncios** pone o venderla rápido.
3. **🤝 Clientes**: empresas que compran webs y **pagan según sus visitas** (los 👑 VIP pagan x3.5). Cada venta da reputación y un **contrato de mantenimiento** que paga para siempre.
4. **📢 Anuncios**: 7 apps de anuncios. Cada una paga distinto por visita y espanta más o menos visitas.
5. **🏢 Empresas**: 8 empresas (Programadores, Hosting, Marketing, Diseño, Comercial, Laboratorio de IA con **modo automático**, Red de Anuncios y Centro de Datos).
6. **📈 Bolsa**: a partir de $1M puedes **salir a bolsa**. Se reinicia la partida, pero ganas **acciones** (+5 % de dinero cada una, para siempre).
7. **🛒 Tienda**: regalo gratis, recompensa diaria, tus bonus, invitar amigos y la tienda de Robux.
8. **🏆 Ranking**: evento de fin de semana, ranking semanal con premios, jugadores del servidor para visitar y los más ricos de siempre.

## Probarlo en Roblox Studio
1. Descarga `ImperioWeb.rbxl` ([enlace directo a la v2.0](https://github.com/candhu23/mi-priemra-web/raw/claude/optimistic-thompson-296nik/roblox-imperio-web/ImperioWeb.rbxl)).
2. Ábrelo con **Roblox Studio** y pulsa **▶ Play**.
3. Abre **View → Output** para ver posibles errores.

Para ver la ciudad con varios jugadores: pestaña **Test → Clients and Servers → 2 jugadores → Start**.

> Si ya tenías la versión anterior abierta, cierra ese archivo y abre el nuevo: los scripts han cambiado y hay módulos nuevos (`Locale`, `LocaleEN` y `Showcase`).

Para probar el juego en inglés en Studio: pulsa el botón **🌐 ES** de la ventana del ordenador.

### Con Rojo (opcional)
```bash
rojo serve default.project.json        # sincroniza con Studio
rojo build default.project.json --output ImperioWeb.rbxl
```

## Guardar partidas y clasificación
El progreso **ya se guarda solo** (cada 60 s, al salir y al cerrar el servidor), pero Roblox solo permite guardar en juegos **publicados**. Para que funcione también al probar en Studio:
1. *File → Publish to Roblox* (créalo como experiencia nueva).
2. *Home → Game Settings → Security* → activa **Enable Studio Access to API Services** → *Save*.
3. Para la prueba (*Stop*) y vuelve a pulsar *Play*.

Si el guardado está desactivado verás un **aviso rojo** arriba a la izquierda; al pulsarlo te explica estos pasos. Jugando al juego publicado desde la web o la app se guarda siempre.

## Ganar Robux
En `src/ReplicatedStorage/TycoonConfig.luau` → `Config.Monetization`:

| Tipo | Artículo | Qué hace | Precio orientativo* |
|---|---|---|---|
| Game Pass | 💎 x2 Dinero | doble de dinero para siempre | 199–399 R$ |
| Game Pass | ⚡ Programador Turbo | programa x2 de rápido | 99–199 R$ |
| Game Pass | 🗄️ +3 Huecos | 3 webs más a la vez | 99–149 R$ |
| Producto | 💼 Maletín / 🚚 Camión | 15 min / 2 h de ingresos al instante | 25–49 / 99–149 R$ |
| Producto | 🚀 Boost x2 30 min | dinero x2 durante 30 min | 49–79 R$ |
| Producto | ⏩ Terminar web ya | termina la web que programas | 15–25 R$ |
| Game Pass | 🏙️ Agencia Pro | +5 puestos y programadores +25 % | 199–299 R$ |
| Game Pass | 🎓 Mentor x2 XP | sube de nivel el doble de rápido | 99–199 R$ |
| Producto | 🎯 Headhunter Premium (x1 / x5) | fichaje Raro o mejor (aleatorio) | 49–79 / 199–299 R$ |
| Producto | 👑 Contrato Legendario | Legendario del nicho que elijas | 299–499 R$ |

\* Son precios típicos en tycoons de Roblox, no datos comprobados de este juego: ajústalos según veas qué compra la gente.

Pasos:
1. En el [Creator Hub](https://create.roblox.com/) → tu experiencia → **Monetization** → crea los *Passes* y *Developer Products*.
2. Copia cada ID en el campo `id` correspondiente (con `id = 0` el artículo no aparece).
3. Opcional: pon el ID de tu **grupo** de Roblox en `GROUP_ID` para dar +10 % a quien se una (ayuda a conseguir jugadores).

Las compras de productos se guardan antes de confirmarse a Roblox y no se pueden cobrar dos veces.

**Artículos aleatorios (Headhunter Premium)**: Roblox exige mostrar las probabilidades antes de comprar (el juego las muestra en la tienda y en la agencia) y los restringe en algunos países. El juego consulta `PolicyService` y oculta esos artículos a quien no pueda comprarlos. El 👑 Contrato Legendario no es aleatorio (eliges el nicho), así que está disponible para todos.

## Cambiar el juego
- **Economía**: todos los números están en `TycoonConfig.luau` (precios, visitas, reputación, empresas, objetivos, recompensas...).
- **Sonidos**: `Config.Sounds`. Puedes poner IDs de la Creator Store (`rbxassetid://...`).
- **Velocidad del día**: `Config.DAY_LENGTH_MINUTES`.
- **Textos en inglés**: `LocaleEN.luau` (clave = texto en español exacto, valor = inglés). Si cambias un texto en español, cambia también su clave allí.
- **Premios del ranking semanal y eventos de fin de semana**: `Config.WeeklyPrizes` y `Config.WeekendEvents` en `TycoonConfig.luau`.
- **Códigos**: `Config.Codes` (código en MAYÚSCULAS, premio en minutos de ingresos, `expires` opcional). Añade uno nuevo cada vez que publiques un vídeo.
- **Webs raras, I+D, pase, premios por tiempo, eventos del servidor y meta común**: `Config.Variants`, `Config.Research`, `Config.seasonReward`, `Config.PlaytimeRewards`, `Config.ServerEvents`, `Config.COMMUNITY_*`.

## Estructura
```
roblox-imperio-web/
├── default.project.json   # proyecto de Rojo (incluye iluminación Future)
├── ImperioWeb.rbxl        # lugar listo para abrir en Studio
└── src/
    ├── ReplicatedStorage/TycoonConfig.luau            # datos y fórmulas
    ├── ReplicatedStorage/CareerConfig.luau            # nichos, 500 empresas, puestos, rarezas
    ├── ReplicatedStorage/Locale.luau                  # idiomas (detecta y traduce)
    ├── ReplicatedStorage/LocaleEN.luau                # textos en inglés
    ├── ServerScriptService/Showcase.luau              # oficina, paseo de la fama y pantalla de cada parcela
    ├── ServerScriptService/CareerService.luau         # trabajos, agencia y fichajes (servidor)
    ├── ServerScriptService/World.luau                 # ciudad, luces, día/noche, clasificación
    ├── ServerScriptService/Building.luau              # generador de rascacielos
    ├── ServerScriptService/PlotManager.luau           # parcelas de los jugadores
    ├── ServerScriptService/TycoonServer.server.luau   # economía, guardado, tienda, acciones
    └── StarterPlayerScripts/TycoonClient.client.luau  # toda la interfaz
```

El servidor decide todo (dinero, compras, ventas). El cliente solo muestra la información y pide acciones, así que es difícil hacer trampas.
