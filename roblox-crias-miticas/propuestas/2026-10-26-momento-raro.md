# Ficha: Gran momento al salir una cría rara (Épica / Legendaria / Mítica)

> Autor: Nico (diseño) · 2026-10-26 · Origen: idea (c) de Iris · Estado: ✅ aprobada por el usuario (2026-10-26)
> Encargo para Leo: **1 sesión**. Sin acción nueva, sin datos guardados nuevos, nada de pago.

## 0. Por qué (con datos)

Medido a un lado con una copia de `tools/harness/ritmo.luau` (40 partidas de 40 min, bot sin suerte ×2; un humano va ≈ ×2 más lento):

| Rareza | Prob. por huevo (`Config.Rarities`) | Bot: 1.ª vez | Bot: partidas que la consiguen |
|---|---|---|---|
| Épica | 6 % | mediana ≈ 1:20, 38/40 antes de 6 min | 40/40 |
| Legendaria | 1,8 % | muy variable (0:32 → 39:58) | 14/40 antes de 10 min · 31/40 en 40 min |
| Mítica | 0,2 % | — | 3/40 antes de 10 min · 10/40 en 40 min |

Conclusión: si el «gran momento» fuera solo para Legendaria/Mítica, **más de la mitad de los jugadores no lo vería en su
primera sesión** (≈ 35 % de humanos ve una Legendaria en sus primeros ~20 min). Por eso hay **dos niveles**: un momento
mediano con la Épica (casi todos lo viven en los primeros ~3 min de persona) y el gran momento con Legendaria/Mítica
(el que se graba para TikTok y el que ve todo el servidor).

Hoy (✔ `Client.client.luau`, función `showHatch`): la apertura es igual para una Común que para una Mítica; solo cambia el
color del borde y la etiqueta; se cierra sola a los 2,4 s.

## 1. Para el jugador

- **Épica (momento mediano)**: el huevo tiembla más rato (0,9 s en vez de 0,6), la tarjeta da un «bote» (escala 1 → 1,15 → 1),
  borde morado grueso, título **«¡ÉPICA!»** encima y la ventana dura 3,5 s.
- **Legendaria / Mítica (gran momento)**:
  1. El huevo tiembla 1,2 s y la pantalla se oscurece un poco más.
  2. **Destello** a pantalla completa del color de la rareza (de 0,3 a transparente en 0,5 s).
  3. Título enorme **«¡¡LEGENDARIA!!» / «¡¡MÍTICA!!»** con borde blanco, que entra creciendo.
  4. Debajo, la probabilidad real: **«Probabilidad: 1,8 %»** (o la que toque, con suerte ×2 incluida). Es el gancho del
     vídeo 1 de `marketing/videos.md` y refuerza que las probabilidades son visibles.
  5. 12 «chispas» (✨⭐) que salen del centro hacia fuera y se desvanecen. Sonido especial (si no está silenciado).
  6. La ventana dura 5 s (se puede cerrar antes tocando, como ahora).
- **Los demás jugadores del servidor** ven un aviso arriba, del color de la rareza, 5 s:
  «🌟 ¡Ana ha sacado una cría Mítica: Fénix Estelar!». Quien la saca **no** ve este aviso (ya tiene su momento).
- Por qué vuelve: no es un motivo de vuelta por sí mismo; hace que la primera sesión tenga un pico de emoción y que
  haya algo que **grabar y enseñar** (fase B: conseguir jugadores).

## 2. Versión mínima (ahora) y ampliaciones (después)

**Mínima (esta ficha):** los dos niveles en la ventana de apertura + aviso al servidor con enfriamiento.
**Ampliaciones (no ahora):** columna de luz 3D sobre el jugador durante 3 s (`Mundo3D`); «Primera Mítica del servidor
hoy»; contador en el Álbum de cuántas Legendarias/Míticas tienes.

## 3. Datos guardados

Ninguno. (No hace falta migración.)

## 4. Config (`src/ReplicatedStorage/Config.luau`, junto a `Config.Rarities`)

```lua
-- Gran momento al abrir un huevo (índices de Config.Rarities: 5 = Épica, 6 = Legendaria, 7 = Mítica)
Config.HATCH_MEDIUM_FROM = 5     -- desde Épica: momento mediano (casi todos lo ven en ~3 min, ver ficha)
Config.HATCH_BIG_FROM = 6        -- desde Legendaria: gran momento + aviso a todo el servidor
Config.RARE_ANNOUNCE_COOLDOWN = 10 -- s entre avisos al servidor del mismo jugador (con x3 o Auto no hace spam)
Config.HATCH_SHOW_TIME = { 2.4, 3.5, 5 } -- s que dura la ventana: normal, mediano, grande
```

Por qué el enfriamiento: con el pase Auto-abrir se abre un huevo cada 0,9 s; sin límite, un jugador con suerte ×2 podría
llenar la pantalla de los demás. Si en 10 s saca dos, solo se anuncia la primera (su propia ventana sí sale siempre).

## 5. Servidor (`src/ServerScriptService/Main.server.luau`)

**Sin acción nueva.** Cambios:

1. En `Session` (tipo y creación en `onPlayerAdded`): campo `lastAnnounce: number` = 0 (solo en memoria, no se guarda).
2. Nueva función local `announceRare(player, s, kind)` (declararla **antes** de `Actions.hatch`):
   - `local r = Config.PetById[kind].rarity`; si `r < Config.HATCH_BIG_FROM` → no hace nada.
   - Si `os.clock() - s.lastAnnounce < Config.RARE_ANNOUNCE_COOLDOWN` → no hace nada.
   - `s.lastAnnounce = os.clock()`
   - `notifyRemote:FireAllClients("rare", "n_rare_hatch", { uid = player.UserId, name = player.DisplayName, pet = kind, rarity = Config.Rarities[r].id })`
3. En `Actions.hatch`, dentro del bucle `for _ = 1, count`, tras `addPet`: añadir a cada resultado `rarity = Config.PetById[kind].rarity`
   y, al acabar el bucle, llamar a `announceRare` con **la cría más rara** del lote (una sola vez por apertura).
4. Nada del cliente se cree: el servidor decide la rareza, el cliente solo dibuja. Los nombres van por clave (el cliente
   traduce `pet` y `rarity`), según la regla de `Lang.luau`. `DisplayName` ya lo filtra Roblox (≈, no es texto libre del jugador en el chat).

## 6. Estado

Sin campos nuevos. El resultado de `hatch` lleva por cría `{ kind, new, rarity }` (antes `{ kind, new }`).

## 7. Pantallas (cliente — Leo lo programa; Vega revisa capturas)

Partes del cliente que se tocan (Vega está cambiando ahora `Client.client.luau`, `UI/Mundo3D.luau` y `Lang.luau`:
**Leo debe partir de la versión de Vega ya subida**):

| Archivo | Parte | Cambio |
|---|---|---|
| `Client.client.luau` | bloque de la **apertura** (`showHatch`, overlay «Apertura») | Calcular `best = max(rarity)` del lote. Según `best`: tiempo de temblor (0,6 / 0,9 / 1,2 s), bote de la tarjeta (`UIScale` nuevo **en un Frame contenedor**, no en un botón: trampa §9 «un solo UIScale»), título `rare_mid` / `rare_big_legendary` / `rare_big_mythic`, línea de probabilidad, destello y chispas, y `task.delay(Config.HATCH_SHOW_TIME[nivel])` en vez del 2.4 fijo. Nombres: `MomentoRaro` (Frame del título), `Destello` (Frame a pantalla completa) |
| `Client.client.luau` | bloque del **panel del huevo** (donde se llama a `showHatch`, 3 sitios: abrir, x3, auto) | pasar la isla del huevo: `showHatch(params.hatched, egg)` para calcular la probabilidad con `Config.eggOdds(egg, s.luckLeft > 0)` |
| `Client.client.luau` | `niceParams` | si `p.pet` es texto → `petName(p.pet)`; si `p.rarity` es texto → `T("rar_" .. p.rarity)` |
| `Client.client.luau` | `notifyRemote.OnClientEvent` | si `kind == "rare"`: si `params.uid == LocalPlayer.UserId` → no hace nada; si no, `showToast(texto, "rare", color de la rareza)` con 5 s |
| `Client.client.luau` | bloque de **avisos** (`showToast`) | aceptar un color opcional y una duración (por defecto 3 s), alto 52 en vez de 44 para `rare` |
| `UI/Kit.luau` | `setupSounds` | 2.º sonido `rareSound` + `Kit.playRare()` que respeta `muted`. Sonido: probar `rbxasset://sounds/victory.wav` (≈ no sé si existe en el contenido de Roblox: **compruébalo**; si no, `electronicpingshort.wav` con `PlaybackSpeed = 0.8`) |

- Destello: `Frame` de 100 % × 100 %, `BackgroundColor3` = color de la rareza, sin texto (si se usa `UIGradient`, que sea
  en un Frame **sin texto**: trampa §9), `ZIndex` por debajo de la tarjeta, `Active = false` (que el toque llegue al overlay).
- Título: `Kit.title` 56 (diseño 960×540), `Kit.fit`, borde con `Kit.textStroke(3)`.
- Chispas: 12 `TextLabel` «✨»/«⭐» de 28 px, `Kit.tween` hacia fuera 0,8 s y se destruyen. Pocas: el móvil va justo.
- **Móvil** (844×390): título como máximo 80 % del ancho, la tarjeta y la línea de probabilidad no deben salirse por abajo
  (hoy la tarjeta mide 250 de alto + título ≈ 60 + línea ≈ 30 → cabe en 540 de diseño). El aviso al servidor es un toast
  arriba (ya existe `toastHolder`, que baja si hay tutorial).

Textos (`Lang.luau`, en `es` y `en`):

| Clave | ES | EN |
|---|---|---|
| `rare_mid` | ¡ÉPICA! | EPIC! |
| `rare_big_legendary` | ¡¡LEGENDARIA!! | LEGENDARY!! |
| `rare_big_mythic` | ¡¡MÍTICA!! | MYTHIC!! |
| `rare_odds` | Probabilidad: {pct} % | Chance: {pct}% |
| `n_rare_hatch` | 🌟 ¡{name} ha sacado una cría {rarity}: {pet}! | 🌟 {name} hatched a {rarity} pet: {pet}! |

`{pct}` con el mismo formato que las tarjetas de probabilidad del panel del huevo (1 decimal si < 1).

## 8. Tienda

No aplica. **No** añadir nada de pago aquí (ni «suerte», ni «ver más Míticas»). No poner botones de compra en esta ventana.

## 9. Pruebas (`tools/harness/run_juego.luau`)

Tras la prueba actual «Ir al huevo y abrirlo» (después de `02_apertura`):

1. Forzar una Mítica: guardar `local r0 = math.random`, poner `math.random = function(a, b) if a then return r0(a, b) end return 0.9999 end`
   (el `Random` del mock usa `math.random`; ≈ comprobar que el cambio llega al entorno del servidor; si no, añadir al mock
   un `W.forceRoll` que use `NextNumber`), dar monedas al jugador si faltan (`hatch` cuesta `eggCost`), esperar ≥ 0,9 s de
   `W.fakeTime` y abrir con el botón `AbrirHuevo`. Restaurar `math.random = r0`.
2. Comprobar:
   - la cría añadida es la de índice 7 de la isla 1 (`dawngriffin`) y el resultado lleva `rarity = 7`;
   - `named(gui, "MomentoRaro").Visible` y su texto es el de `rare_big_mythic`;
   - en `W.fired` hay **una** entrada `{ "Notify", "all", "rare", "n_rare_hatch", { uid = W.player.UserId, … } }`;
   - el propio jugador **no** recibe toast de `n_rare_hatch` (no hay TextLabel con ese texto en `toastHolder`).
   - volcar `02b_apertura_mitica` (PC y móvil) para las capturas.
3. Enfriamiento: forzar otra al cabo de 1 s → ventana grande sí, pero **no** hay un 2.º `"all"` en `W.fired`; avanzar
   `W.fakeTime` 11 s y forzar otra → sí hay un 2.º.
4. Aviso de otro jugador: disparar a mano la señal `OnClientEvent` del `Notify` con `("rare", "n_rare_hatch", { uid = 999, name = "Ana", pet = "dawngriffin", rarity = "mythic" })`
   → hay un toast con «Ana» y el nombre traducido de la cría; volcar `02c_aviso_raro`. Repetir en inglés (la pasada EN ya existe).
5. `check_lang.py` debe pasar (las 5 claves en ES y EN).

## 10. Objetivo de ritmo medible

- Que **≥ 90 %** de las partidas del bot vean el momento mediano antes de **3 min** de bot (hoy 38/40 antes de 6 min;
  con `HATCH_MEDIUM_FROM = 5` se mide añadiendo un hito «1.ª Épica» a una copia de `ritmo.luau`, como en §0).
- El gran momento: ≈ 35 % de jugadores en la 1.ª sesión (no se cambia la probabilidad: **no** subir las rarezas para
  forzarlo; si se quiere más, la vía legítima es la suerte ×2 que ya dan las misiones).
- Tras publicar (Creator Hub): duración media de sesión antes/después (meta ≈ ≥ 8 min, `marketing/plan.md`).

## 11. Riesgos, qué NO hacer y pre-mortem

- **No** cambiar probabilidades, **no** mostrar probabilidades falsas ni redondeadas hacia arriba, **no** anunciar
  Míticas inventadas para «animar» el servidor (sería engañoso).
- **No** abrir la tienda ni ofrecer compras en este momento (normas: nada que se abra solo para vender).
- Rendimiento móvil: máx. 12 chispas y destruirlas; nada de partículas 3D en la versión mínima.
- Spam: enfriamiento de 10 s por jugador; con x3 se anuncia solo la más rara del lote.
- **Pre-mortem** — «un mes después no ha servido porque…»:
  1. *Casi nadie lo vio* (la Legendaria es 1,8 %) → por eso existe el nivel Épica; medirlo con el objetivo de §10.
  2. *Molesta* (con Auto-abrir, 5 s de ventana cada vez que sale algo raro tapan el juego) → con `auto == true` usar el
     tiempo del nivel mediano (3,5 s) aunque sea Legendaria; el toque cierra siempre.
  3. *No se graba bien* (el destello tapa la cría) → el destello va debajo de la tarjeta y dura 0,5 s; revisar en la
     captura `02b_apertura_mitica` de móvil.

## Lo que no sé (≈)

- Si `rbxasset://sounds/victory.wav` existe (Leo lo comprueba; hay plan B).
- Cómo se ve en un móvil real (solo hay capturas del harness); el usuario debería grabar una apertura en Studio.
- Si de verdad aumenta la sesión: sin analíticas hasta publicar.
