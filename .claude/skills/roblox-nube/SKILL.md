---
name: roblox-nube
description: Opera los juegos de Roblox de este repo desde la nube con la API oficial Open Cloud, sin abrir Studio — subir una versión guardada, probarla en un servidor REAL de Roblox, publicarla, reiniciar servidores, listar/crear pases y Developer Products (escribiendo el ID en el código) y cambiar precios. Úsala cuando el usuario pida publicar, actualizar el juego, "que los jugadores vean la versión nueva", reiniciar servidores, crear productos o pases, cambiar un precio, o comprobar que los IDs de la tienda están bien. También para explicarle cómo activar la clave ROBLOX_API_KEY.
---

# roblox-nube — Roblox Open Cloud para Web Empire Tycoon y AeroCarga

Herramienta: `python3 -I .claude/skills/roblox-nube/roblox_cloud.py <orden> <juego> …`
(`<juego>` = `imperio` | `aerocarga` | `biblioteca`; datos en `juegos.json`). Solo librería estándar.
Endpoints verificados en la documentación oficial (create.roblox.com/docs/cloud, octubre 2026).

## 0. ¿Está activada?

`roblox_cloud.py estado imperio`. Si dice `ROBLOX_API_KEY: NO configurada`, el usuario tiene que crear la
clave (pasos de §4). **Nunca le pidas que pegue la clave en el chat.** Mientras no exista, el flujo de
publicación es el manual de Studio (CLAUDE.md raíz §10).

## 1. Órdenes

| Orden | Qué hace | ¿Riesgo? |
|---|---|---|
| `estado <juego>` | IDs, si hay clave y qué permisos de lectura funcionan | Ninguno |
| `pases <juego>` / `productos <juego>` | Compara lo que hay en Roblox con los IDs del código (`✅ ⚪ ❌ ❔`) | Ninguno |
| `guardar <juego>` | Sube el `.rbxl` como versión **guardada** (los jugadores no la ven) | Ninguno para jugadores |
| `probar <juego> [--version N]` | Guarda (si no das versión) y ejecuta `prueba_real.luau` en un servidor real de Roblox | Ninguno para jugadores |
| `publicar <juego> --confirmo [--reiniciar --minutos 5]` | Publica para **todos** | ALTO: confirmar antes |
| `reiniciar <juego> --confirmo [--minutos N] [--todas]` | Cierra servidores con versión antigua (con `--minutos` los vacía poco a poco, 1–60) | Medio: echa a jugadores |
| `crear-producto` / `crear-pase <juego> --clave K --nombre N --precio P [--descripcion D] [--imagen F.png] --confirmo` | Crea el artículo a la venta y **escribe su ID** en el archivo de config (solo si allí era `id = 0`) | Medio: aparece en la tienda |
| `precio <juego> pase\|producto <id> <robux> --confirmo` | Cambia el precio | Medio |
| `imagen <juego> pase\|producto <id> <archivo.png> --confirmo` | Sube el icono (hecho con la skill `arte-roblox`) | Bajo: Roblox lo modera antes |

`--confirmo` es obligatorio en las órdenes que cambian cosas: **antes de ponerlo, pide un «sí» explícito
al usuario** diciendo exactamente qué vas a hacer (juego, versión, precio). Un «sí» vale para esa acción, no
para las siguientes.

## 2. Qué comprueba la prueba real (`prueba_real.luau`)

Se ejecuta con el motor de Roblox de verdad contra una versión guardada: cuenta los scripts, hace `require`
de todos los ModuleScripts de ReplicatedStorage y ServerScriptService, construye la ciudad y un rascacielos
de 30 plantas si existen `PlotManager/World/Building`, y comprueba cada ID de `GamePasses`/`Products` con
`MarketplaceService:GetProductInfo` (existe, precio, a la venta). Acaba en `PRUEBA REAL OK ✅` o lista fallos.

Límites (dilo al usuario): los Scripts del juego **no** se ejecutan solos (no prueba el bucle del servidor
ni la interfaz, eso ya lo hace `tools/check.sh` con Lune); no hay física ni jugadores; los DataStores
**son los reales**, así que nunca añadas a la prueba nada que guarde datos. Límite de Roblox: 5 tareas/min.

## 3. Reglas

- Antes de `guardar`/`probar`/`publicar`: estar en la rama del juego, `tools/check.sh` en verde y el `.rbxl`
  regenerado y subido a git (así el commit es la copia exacta de lo publicado).
- Si creas un producto/pase: después `tools/check.sh`, commit y push (el ID queda en el código), y la
  versión con el ID nuevo hay que publicarla para que salga en el juego.
- Artículos aleatorios de pago (Headhunter): no los crees salvo que el usuario lo pida sabiendo que implica
  responder «Sí» en el cuestionario de contenido (CLAUDE.md §7 y §11).
- **AeroCarga** no tiene IDs: su primera publicación es en Studio (*Publish to Roblox As… → nueva
  experiencia*). Luego pon `universeId` y `placeId` en `juegos.json`.
- El API no actualiza `PartOperation`, `SurfaceAppearance`, `EditableImage/Mesh` ni `BaseWrap`: si algún día
  el juego los usa, publicar desde Studio.
- **Volver atrás** si una versión sale mal: (a) Creator Hub → la experiencia → Places → el lugar → *Version
  History* → *Restore* en la anterior (lo hace el usuario), o (b) tú: `git checkout <commit bueno> -- <carpeta>`,
  `tools/check.sh`, `publicar … --confirmo --reiniciar`, y deshacer el checkout.
- Errores 401/403: la herramienta dice qué permiso falta. 429: espera un minuto.

## 4. Cómo activar la clave (pasos para el usuario, de clic en clic)

1. Entra en **create.roblox.com** → arriba **Dashboard** → menú izquierdo **Open Cloud → API Keys** →
   **Create API Key**.
2. Nombre: `Claude`. En **Access Permissions** → *Select API System* añade y, en cada uno, elige la
   experiencia **Web Empire Tycoon** (y AeroCarga cuando exista) con estas operaciones:
   - `universe-places` → **Write** (publicar)
   - `universe` → **Write** (reiniciar servidores)
   - `universe.place.luau-execution-session` → **Read** y **Write** (prueba real)
   - `game-pass` → **Read** y **Write**
   - `developer-product` → **Read** y **Write**
3. **Security → Accepted IP Addresses**: `0.0.0.0/0` (Claude trabaja desde la nube con IPs que cambian).
   Pon **fecha de caducidad** (p. ej. 90 días). Guarda y **copia la clave** (solo se ve una vez).
4. En la app de Claude: menú del entorno (barra de título de la sesión) → **Edit** → en *Network secrets*
   (o *Environment variables*) añade `ROBLOX_API_KEY` = la clave. Debe tener permitido `apis.roblox.com`
   en el acceso a red (hoy ya funciona).
5. Abre una sesión nueva: el aviso de inicio dirá `ROBLOX_API_KEY presente`.

Si la clave se filtra: Creator Hub → API Keys → **Disable/Delete** y crear otra. Se puede limitar a una sola
experiencia y a solo lectura si prefiere ir poco a poco (entonces solo funcionarán `estado`, `pases`, `productos`).
