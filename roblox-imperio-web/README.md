# 🌐 Imperio Web Tycoon (juego de Roblox)

Eres un emprendedor que programa páginas web. Las monetizas con anuncios, las vendes a empresas según sus visitas, fundas tus propias empresas y acabas sacando tu imperio a bolsa. **El objetivo: ganar todo el dinero posible.**

## Cómo se juega

1. **🖥️ Crear**: eliges qué web programar (Landing Page → Blog → Tienda Online → Periódico Digital → Red Social → Streaming → App de IA → Metaverso) y pulsas **PROGRAMAR**. Cada tipo nuevo se desbloquea con ⭐ reputación.
2. **🌐 Mis webs**: cada web tiene visitas por segundo y gana dinero con anuncios. Puedes:
   - mejorar su **SEO** (más visitas),
   - cambiar la **app de anuncios** que usa,
   - elegir **cuántos anuncios** pone (Pocos / Normal / Muchos: más anuncios dan más dinero pero espantan visitas),
   - venderla rápido (paga menos).
3. **🤝 Clientes**: empresas que quieren comprar un tipo de web. **Pagan según las visitas** de tu web, multiplicado por su oferta (los clientes 👑 VIP pagan ×3.5). Cada venta te da reputación y un **contrato de mantenimiento** que te paga para siempre.
4. **📢 Anuncios**: 7 apps de anuncios (AdSimple, ClickBoom, BannerPro, VideoMax, InfluAds, PremiumAds Global, NeuroAds IA). Cada una paga distinto por visita y molesta más o menos a los visitantes.
5. **🏢 Empresas**: funda y mejora 8 empresas. Cada una da dinero por segundo y una ventaja:
   | Empresa | Ventaja |
   |---|---|
   | 👩‍💻 Equipo de Programadores | programan solos |
   | ☁️ Hosting Nube | más huecos para tener webs |
   | 📣 Agencia de Marketing | +10 % de visitas |
   | 🎨 Estudio de Diseño | webs de más calidad |
   | 🤝 Agencia Comercial | vendes más caro |
   | 🧪 Laboratorio de IA | programa más rápido y activa el **modo automático** |
   | 📡 Red de Anuncios Propia | +15 % de dinero por anuncios |
   | 🏭 Centro de Datos | +5 % a todo y tus webs no se caen |
6. **📈 Bolsa**: cuando ganas $1M puedes **salir a bolsa**. Se reinicia la partida pero consigues **acciones**, y cada una te da +5 % de dinero para siempre. También están los 🎯 objetivos (con premios) y tus estadísticas.

Además hay:
- **Eventos aleatorios**: una web se hace viral (×5 visitas), el buscador te favorece, caída de servidores, inversores que te dan dinero y clientes VIP.
- **Ciudad 3D**: cada jugador tiene una parcela con un ordenador (para abrir el menú) y un **rascacielos que gana plantas** a medida que crece su imperio.
- **Guardado automático** y **ganancias mientras no juegas** (50 % de lo normal, hasta 8 h).
- Tabla de clasificación con 💰 Dinero y 📈 Acciones.

## Cómo probarlo en Roblox Studio

### Opción A (la más fácil): abrir el archivo ya montado
1. Descarga `ImperioWeb.rbxl` de esta carpeta.
2. Ábrelo con **Roblox Studio** (doble clic o *File → Open from File*).
3. Pulsa **▶ Play**.

### Opción B: con Rojo (si programas desde VS Code)
```bash
rojo serve default.project.json
```
Y conéctate desde el plugin de Rojo en Studio. Para regenerar el `.rbxl`:
```bash
rojo build default.project.json --output ImperioWeb.rbxl
```

### Opción C: copiar y pegar a mano
Crea en Studio estos objetos (con estos nombres exactos) y pega el código de cada archivo:

| Dónde (Explorer) | Tipo | Nombre | Archivo |
|---|---|---|---|
| ReplicatedStorage | ModuleScript | `TycoonConfig` | `src/ReplicatedStorage/TycoonConfig.luau` |
| ServerScriptService | ModuleScript | `PlotManager` | `src/ServerScriptService/PlotManager.luau` |
| ServerScriptService | Script | `TycoonServer` | `src/ServerScriptService/TycoonServer.server.luau` |
| StarterPlayer → StarterPlayerScripts | LocalScript | `TycoonClient` | `src/StarterPlayerScripts/TycoonClient.client.luau` |

## Guardar partidas
El guardado usa DataStores, que solo funcionan en un juego **publicado**:
1. *File → Publish to Roblox*.
2. *Home → Game Settings → Security* → activa **Enable Studio Access to API Services**.

Sin esto el juego funciona igual, pero avisa de que la partida no se guardará.

## Ganar Robux (opcional)
Hay un **Pase x2 Dinero** preparado:
1. En el [Creator Hub](https://create.roblox.com/) crea un *Game Pass* para tu juego.
2. Copia su ID en `TycoonConfig.luau` → `Config.Monetization.DOUBLE_MONEY_GAMEPASS_ID`.
3. Aparecerá un botón de compra en la pestaña 📈 Bolsa.

Con el ID en `0`, la tienda no aparece.

## Cambiar el equilibrio del juego
Todos los números están en `src/ReplicatedStorage/TycoonConfig.luau`: precios, visitas, reputación necesaria, apps de anuncios, empresas, objetivos, eventos y nombres de clientes. Puedes añadir un tipo de web, una app o una empresa nueva copiando una línea y cambiando sus valores.

## Estructura
```
roblox-imperio-web/
├── default.project.json        # proyecto de Rojo
├── ImperioWeb.rbxl             # lugar listo para abrir en Studio
└── src/
    ├── ReplicatedStorage/TycoonConfig.luau            # datos y fórmulas
    ├── ServerScriptService/PlotManager.luau           # ciudad, parcelas y rascacielos
    ├── ServerScriptService/TycoonServer.server.luau   # economía, guardado, acciones
    └── StarterPlayerScripts/TycoonClient.client.luau  # toda la interfaz
```

El servidor es quien decide todo (dinero, compras, ventas). El cliente solo muestra la información y pide acciones, así que es difícil hacer trampas.
