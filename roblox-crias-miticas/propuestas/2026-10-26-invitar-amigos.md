# Ficha: Botón «Invitar amigos» (con el bonus de amigos a la vista)

> Autor: Nico (diseño) · 2026-10-26 · Origen: idea (b) de Iris · Estado: 💤 aplazada por elección del usuario (2026-10-26)
> Encargo para Leo: **media sesión**. Solo cliente + textos. Sin acción nueva, sin datos guardados nuevos.

## 0. Por qué

- ✔ El juego ya da **+10 % de monedas por amigo en el servidor (máx. 4)** (`Config.coinMult`, `Main.server.luau`
  `updateFriends`, con `pcall`), y `s.bonuses.friends` ya viaja en el estado. Pero **el jugador no lo ve en ningún sitio**
  y no hay forma de traer a un amigo desde dentro del juego.
- La fase siguiente (publicar y llegar a 250 jugadores 16+, `marketing/plan.md`) necesita motivos para traer gente.
  Iris ya promete en el evento «Play with friends: +10% coins for each friend in the server»: el juego debe enseñarlo.
- `tools/harness/mock.luau` ya simula `SocialService.PromptGameInvite` y `CanSendGameInviteAsync` (anota `"invite"` en `W.prompts`).

## 1. Para el jugador

- A la **derecha, a media altura**, un botón grueso azul **«👥 Invitar»** y debajo una etiqueta pequeña:
  - sin amigos: **«+10 % por amigo»**;
  - con amigos: **«Amigos: 2 · +20 %»** (en verde).
- Al tocarlo se abre la ventana oficial de Roblox para invitar amigos. Si no se puede (p. ej. en Studio o cuenta sin
  permiso), sale un aviso: «Ahora no se puede invitar desde aquí».
- Primeros 30 s: no molesta (no sale nada solo, no parpadea). Lo descubre al mirar la pantalla.
- Por qué vuelve: jugar con amigos da más monedas y es más divertido; la invitación trae al amigo al mismo servidor.

## 2. Versión mínima y ampliaciones

**Mínima (esta ficha):** botón + etiqueta del bonus + aviso si no se puede invitar.
**Ampliaciones (después, no ahora):**
- Aviso cuando entra un amigo: «¡Ana ha entrado! +10 % de monedas» (servidor, en `onPlayerAdded` tras `updateFriends`).
- Recordar `updateFriends` cada 60 s (hoy solo al entrar/salir alguien; basta así).
- **No** dar premios por *enviar* invitaciones (ver §11).

## 3. Datos guardados

Ninguno.

## 4. Config

Sin números nuevos. (El 10 % y el máximo de 4 ya están en `Config.coinMult`. Leo: si quieres, sácalos a
`Config.FRIEND_BONUS = 0.1` y `Config.FRIEND_MAX = 4` y úsalos en `coinMult` y en la etiqueta, para que no se desincronicen.)

## 5. Servidor

**Ningún cambio** en la versión mínima (no hace falta acción nueva: la invitación la pide el cliente directamente a
Roblox y no da nada que haya que validar).

## 6. Estado

Sin campos nuevos: se usa `s.bonuses.friends` (ya está en `buildState`).

## 7. Pantallas (cliente — Leo lo programa; Vega revisa capturas)

Vega está cambiando ahora `Client.client.luau` y `Lang.luau`: **Leo debe partir de la versión de Vega ya subida**.

| Archivo | Parte | Cambio |
|---|---|---|
| `Client.client.luau` | arriba: `local SocialService = game:GetService("SocialService")` | nuevo servicio |
| `Client.client.luau` | **bloque nuevo** `do … end` justo después del bloque del botón **Auto** | `Frame` contenedor `Invitar` (AnchorPoint (1, 0.5), Position (1, -12, 0.5, 0), tamaño 150×86 de diseño) con `Kit.button(…, "👥 " .. T("invite"), "blue", …)` llamado `BotonInvitar` (150×56) y debajo `Kit.title` 16 px `EtiquetaAmigos` con `Kit.textStroke(2)` |
| mismo bloque | al pulsar | `task.spawn`: `local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)`; si `ok and can` → `pcall(SocialService.PromptGameInvite, SocialService, player)`; si no, `showToast(T("invite_fail"), "error")`. Enfriamiento local 2 s para que no se abran dos ventanas |
| `refreshAll` (o la función que refresca el HUD con el estado) | etiqueta | `local n = s.bonuses.friends or 0` → `n == 0`: `T("invite_hint")` en blanco; si no, `T("invite_friends", { n = n, pct = 10 * math.min(n, 4) })` en verde |
| `menuLabels` / cambio de idioma | | refrescar el texto del botón al cambiar de idioma |

- **No** meterlo en el dock de la izquierda: ya tiene 8 botones (2×4) y en móvil ocupa todo el alto.
- No arriba a la derecha: en PC ahí está la lista de jugadores de Roblox (`leaderstats`).
- **Móvil** (844×390): a la derecha y a media altura no choca con el botón Auto (abajo a la derecha) ni con el de
  saltar de Roblox (abajo a la derecha, más abajo) — ≈ **Vega debe comprobarlo** en las capturas de móvil; si choca,
  subirlo a Position (1, -12, 0.42, 0). Botón ≥ 44 px reales de alto.
- La ventana de apertura de huevo y las ventanas centradas deben quedar **por encima** (ZIndex menor que el overlay).

Textos (`Lang.luau`, `es` y `en`):

| Clave | ES | EN |
|---|---|---|
| `invite` | Invitar | Invite |
| `invite_hint` | +10 % por amigo | +10% per friend |
| `invite_friends` | Amigos: {n} · +{pct} % | Friends: {n} · +{pct}% |
| `invite_fail` | Ahora no se puede invitar desde aquí | Inviting isn't available right now |

## 8. Tienda

No aplica.

## 9. Pruebas (`tools/harness/run_juego.luau`)

Sin acción nueva → no hay que añadir acciones al harness. Añadir, tras la prueba de la interfaz principal:

1. `assert(named(gui, "BotonInvitar"), "falta el botón Invitar")` y que su contenedor `Invitar` es visible.
2. `pressNamed(W, gui, "BotonInvitar")`, un `frame(W)` y `assert(table.find(W.prompts, "invite"), "Invitar no abre la ventana de Roblox")`.
3. Etiqueta: con el estado normal (0 amigos) el texto de `EtiquetaAmigos` es el de `invite_hint`; poner a mano
   `lastState(W).bonuses.friends = 2` (o mandar un estado con `friends = 2` por la señal `State`) → el texto contiene «+20».
4. Fallo: cambiar en el mock `CanSendGameInviteAsync` para que devuelva `false`, pulsar → no se añade otro `"invite"` y
   sale un toast con `invite_fail`. (Restaurar el mock después.)
5. Capturas `00_inicio` de PC y móvil: el botón no tapa nada (auditoría de diseño sin avisos nuevos).
6. `check_lang.py` pasa con las 4 claves.

## 10. Objetivo medible

- En el harness: el botón existe, abre el aviso de Roblox y la etiqueta cambia con los amigos (§9).
- Tras publicar (Creator Hub → Analytics): **≈ no se puede medir directamente** cuántas invitaciones se envían sin
  analíticas propias; se mira si sube la proporción de sesiones con amigos / jugadores únicos semana a semana.
  (Ampliación posible: `AnalyticsService:LogCustomEvent` al pulsar — ≈ comprobar que está disponible antes.)

## 11. Riesgos, qué NO hacer y pre-mortem

- **No** dar premios por enviar invitaciones ni por «invitar a 5 amigos»: es fácil de abusar y ≈ no tengo claro qué
  permiten hoy las normas de Roblox sobre recompensar invitaciones. El premio honesto ya existe: +10 % mientras jugáis juntos.
- **No** abrir la ventana de invitar sola (ni al entrar ni al sacar una Mítica): solo cuando el jugador pulsa.
- `PromptGameInvite` y `CanSendGameInviteAsync` siempre en `pcall` (pueden fallar o no estar en Studio).
- Mientras el juego esté **limitado a 16+** (CLAUDE.md raíz §11), los amigos menores de 16 recibirán la invitación pero
  **no podrán entrar** (≈ cómo lo muestra Roblox no lo sé). No prometer nada en el texto del botón.
- **Pre-mortem** — «un mes después no ha servido porque…»:
  1. *Nadie lo pulsó*: estaba escondido o parecía un anuncio → botón azul normal con texto claro, a la vista, sin parpadeo.
  2. *Los amigos no podían entrar* (16+) → es un límite del juego, no del botón; el plan de Iris ya busca jugadores 16+.
  3. *El bonus no se notaba* → la etiqueta enseña «+20 %» en verde en cuanto hay amigos.

## Lo que no sé (≈)

- Cómo se ve exactamente la ventana de invitar de Roblox en móvil y si funciona en Studio (creo que no: por eso el aviso).
- Si Roblox muestra algo especial al invitar a alguien que no puede entrar por la limitación 16+.
