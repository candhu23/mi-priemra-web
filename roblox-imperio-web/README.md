# 🌐 Imperio Web Tycoon · v1.0 (juego de Roblox)

Eres un emprendedor que programa páginas web. Las monetizas con anuncios, las vendes a empresas según sus visitas, fundas tus propias empresas y acabas sacando tu imperio a bolsa mientras tu rascacielos se convierte en el más alto de Ciudad Web. **El objetivo: ganar todo el dinero posible.**

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

## Probarlo en Roblox Studio
1. Descarga `ImperioWeb.rbxl` ([enlace directo](https://github.com/candhu23/mi-priemra-web/raw/claude/roblox-game-h5olkl/roblox-imperio-web/ImperioWeb.rbxl)).
2. Ábrelo con **Roblox Studio** y pulsa **▶ Play**.
3. Abre **View → Output** para ver posibles errores.

Para ver la ciudad con varios jugadores: pestaña **Test → Clients and Servers → 2 jugadores → Start**.

> Si ya tenías la versión anterior abierta, cierra ese archivo y abre el nuevo: los scripts han cambiado y hay dos módulos nuevos (`World` y `Building`).

### Con Rojo (opcional)
```bash
rojo serve default.project.json        # sincroniza con Studio
rojo build default.project.json --output ImperioWeb.rbxl
```

## Guardar partidas y clasificación
Funcionan con DataStores, que solo van en un juego **publicado**:
1. *File → Publish to Roblox*.
2. *Home → Game Settings → Security* → activa **Enable Studio Access to API Services**.

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

\* Son precios típicos en tycoons de Roblox, no datos comprobados de este juego: ajústalos según veas qué compra la gente.

Pasos:
1. En el [Creator Hub](https://create.roblox.com/) → tu experiencia → **Monetization** → crea los *Passes* y *Developer Products*.
2. Copia cada ID en el campo `id` correspondiente (con `id = 0` el artículo no aparece).
3. Opcional: pon el ID de tu **grupo** de Roblox en `GROUP_ID` para dar +10 % a quien se una (ayuda a conseguir jugadores).

Las compras de productos se guardan antes de confirmarse a Roblox y no se pueden cobrar dos veces.

## Cambiar el juego
- **Economía**: todos los números están en `TycoonConfig.luau` (precios, visitas, reputación, empresas, objetivos, recompensas...).
- **Sonidos**: `Config.Sounds`. Puedes poner IDs de la Creator Store (`rbxassetid://...`).
- **Velocidad del día**: `Config.DAY_LENGTH_MINUTES`.

## Estructura
```
roblox-imperio-web/
├── default.project.json   # proyecto de Rojo (incluye iluminación Future)
├── ImperioWeb.rbxl        # lugar listo para abrir en Studio
└── src/
    ├── ReplicatedStorage/TycoonConfig.luau            # datos y fórmulas
    ├── ServerScriptService/World.luau                 # ciudad, luces, día/noche, clasificación
    ├── ServerScriptService/Building.luau              # generador de rascacielos
    ├── ServerScriptService/PlotManager.luau           # parcelas de los jugadores
    ├── ServerScriptService/TycoonServer.server.luau   # economía, guardado, tienda, acciones
    └── StarterPlayerScripts/TycoonClient.client.luau  # toda la interfaz
```

El servidor decide todo (dinero, compras, ventas). El cliente solo muestra la información y pide acciones, así que es difícil hacer trampas.
