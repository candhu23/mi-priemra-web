# Ficha: Montón Dorado (aparece cada 3 min en la isla más alta de cada jugador)

> Autor: Nico (diseño) · 2026-10-26 · Estado: ✅ aprobada por el usuario (2026-10-26)
> Encargo para Leo: **media sesión**. **Sin acción nueva**, sin datos guardados nuevos, nada de pago.

## 0. Por qué (con datos)

- El bot (30 partidas, `ritmo.luau`) llega a la isla 3 hacia el minuto 11:33 (mediana) y a la isla 4 hacia el 30:14:
  **≈ 19 min de bot (≈ 40 min de persona) ahorrando para la puerta** (952.200 monedas) sin nada nuevo que pase en el mundo.
- El Montón Dorado da **algo que pasa cada 3 min**, un aviso, una carrera hasta el montón y un premio que se nota,
  y en un servidor con varios jugadores, un momento para romperlo juntos. No es un sistema nuevo: reutiliza
  los montones, el reparto por daño y los avisos que ya existen.

## 1. Para el jugador

- Cada 3 min sale un aviso arriba (toast dorado, 5 s): **«🌟 ¡Montón Dorado en Playa Coral! Rómpelo antes de 60 s»**.
- En su isla aparece un montón **dorado y grande** (8×5×8, brillante) con una estrella 🌟 enorme encima que se ve
  **desde lejos y a través de todo** (hasta 400 studs). Tiene la barra de vida de siempre.
- Lo toca (o el modo Auto lo elige si está a ≤ 45 studs) → sus crías van a por él → se rompe en ≈ 5–15 s → monedas
  volando como siempre, pero muchas: **≈ 33 veces un montón normal**.
- Si nadie lo rompe en 60 s, desaparece (sin aviso de castigo).
- Por qué vuelve/sigue: hay un «evento» pequeño cada 3 min mientras ahorra para la siguiente puerta.

## 2. Decisión: en qué isla y cómo llega cada uno

**Elegido: uno por isla en la isla más alta abierta de cada jugador** (conjunto sin repetir: con 1 jugador → 1 montón; con
3 jugadores en las islas 2, 3 y 3 → montones en la 2 y en la 3).

Por qué:
- ✔ El servidor solo deja picar montones de islas pagadas (`pileInReach` / `nearestPile`: `pile.zone <= s.data.zones`).
  La isla más alta de cada jugador **siempre** la tiene pagada → nadie recibe un montón al que no puede llegar.
- Es donde el jugador ya está picando (es la isla que más paga) → normalmente le queda a pocos pasos. Si está en otra, la
  ventana 🗺️ Islas ya tiene el teletransporte (`teleport(isla)`): no hace falta nada nuevo.
- El premio escala solo con la isla (`pileCoins` de esa isla) y sigue la misma economía que todo lo demás.
- Descartado «siempre en isla 1 con premio por `coinsPerHp` de cada jugador»: obliga a todos a ir a la isla 1 (lejos
  de donde juegan) y necesita un reparto distinto del de siempre (más código y más fácil de romper).
- Efecto aceptado: un jugador más avanzado puede ayudar a romper el montón de una isla más baja y se lleva su parte por
  daño (como en los montones normales). Para él es poco dinero (es de una isla baja); para el otro, es ayuda.

## 3. Datos guardados

Ninguno. Todo vive en el servidor mientras dura la partida.

## 4. Config (`src/ReplicatedStorage/Config.luau`, junto a `Config.PileKinds`)

```lua
-- Montón Dorado: cada GOLD_INTERVAL s, uno en la isla más alta abierta de cada jugador (sin repetir isla)
Config.GOLD_INTERVAL = 180  -- s. «Algo nuevo» cada 3 min sin agobiar
Config.GOLD_LIFETIME = 60   -- s. Si no se rompe, desaparece
Config.GOLD_HP = 10         -- × pileHp de la isla (un cristal es ×8): aguanta lo bastante para llegar y verlo
Config.GOLD_COINS = 33      -- × pileCoins de la isla = ×10 lo que da un Cofre (3,3) → rinde ×3,3 por punto de vida
```

Por qué así y no «×10 de un montón normal»: un montón de monedas normal de la isla 3 da 486 monedas ≈ **1–2 s** de
ingresos del bot a esas alturas; ×10 serían ~15 s de ingresos: no se nota. Con ×33 (= ×10 de un Cofre) en la isla 3:
vida 5.880, monedas 16.038 (≈ 20–50 s de ingresos según el poder), y se rompe en ≈ 12 s con poder 472 y ≈ 6 s con
poder 1.060 (poderes del bot al llegar y al salir de la isla 3).
Isla 1: vida 120, monedas 198 (el primer dorado sale a los 3 min, con poder ≈ 30 → ≈ 4 s).
**En pantalla no se escribe «×10» ni «×33»** (no prometer un número que el jugador no puede comprobar): solo «Montón Dorado».

### Ritmo medido (≈ simulación: cada 180 s se suma lo que gana de más el dorado frente a picar normal)

Copia de `ritmo.luau` a un lado, 30 partidas por caso, 45 min de bot:

| Hito (bot) | Sin dorado (mediana) | Con dorado (mediana) | Cambio |
|---|---|---|---|
| Isla 2 | 3:51 | 3:52 | 0 % (el 1.º sale a los 3:00 y es pequeño) |
| Isla 3 | 11:33 | 10:58 | −5 % |
| Isla 4 | 30:14 | 28:17 | −6,5 % |

✔ Ningún hito de `DISENO.md` §5 se adelanta más del ~20 % pedido. Supone que el bot rompe **todos** los dorados él solo;
una persona romperá menos (anda, está en menús) → el efecto real será igual o menor.
Para medirlo de nuevo: en una copia de `ritmo.luau`, tras la línea que suma las monedas por segundo, añadir
`if t % Config.GOLD_INTERVAL == 0 then data.coins += (Config.GOLD_COINS * z.pileCoins - Config.GOLD_HP * z.pileHp * Config.coinsPerHp(data.zones)) * Config.coinMult(data, bonuses) end`
(con `z = Config.Zones[data.zones]`) y comparar medianas de 30 partidas.

## 5. Servidor (`src/ServerScriptService/Main.server.luau`) — sin acción nueva

1. **Tipo `Pile`**: añadir `gold: boolean?`.
2. **`PILE_LOOK`**: añadir `gold = { size = Vector3.new(8, 5, 8), shape = Enum.PartType.Block, color = Config.Colors.gold, material = Enum.Material.Neon }`.
3. **`spawnPile(zone, gold: boolean?)`**: si `gold`, en vez de `pickKind()` usar
   `{ id = "gold", hp = Config.GOLD_HP, coins = Config.GOLD_COINS }` (misma forma que `PileKinds`, así `maxHp` y `coins`
   salen con las fórmulas de siempre). Poner `p:SetAttribute("Gold", true)`, `pile.gold = true`, y
   `task.delay(Config.GOLD_LIFETIME, function() if piles[id] == pile then piles[id] = nil; p:Destroy() end end)`.
   El ClickDetector, la barra de vida y `Kind = "gold"` igual que los demás.
4. **`breakPile`**: el reparto por daño **no se toca**. Solo cambia la última línea:
   `if not pile.gold then task.delay(Config.PILE_RESPAWN, spawnPile, pile.zone) end` (el dorado no reaparece).
   Cuenta como un montón más para las misiones (`stats.piles`), como ya hace.
5. **`spawnGold()`** (local, declarada antes del bucle principal):
   - zonas = conjunto de `s.data.zones` de todas las sesiones;
   - por cada zona: si ya hay un `pile.gold` vivo en esa zona → saltar; si no, `spawnPile(zona, true)`;
   - aviso por cada montón creado, a **todos** los jugadores, con `notifyRemote:FireClient` por jugador:
     `notify(jugador, "gold", if s.data.zones >= zona then "n_gold_pile" else "n_gold_pile_locked", { zone = zona })`
     (así quien no puede llegar no corre a una isla cerrada, pero se entera y le dan ganas de abrirla).
6. **Bucle principal (1 s)**: `local goldTimer = 0` junto a `saveTimer`; cada vuelta `goldTimer += 1`;
   `if goldTimer >= Config.GOLD_INTERVAL then goldTimer = 0; spawnGold() end`. Si no hay sesiones, no hace nada.
7. Nada que validar nuevo: se pica con `target`/Auto, que ya comprueban que el montón existe, está en isla pagada y a ≤ 70.
   Si un jugador tenía de objetivo un dorado que caduca, `piles[s.target]` es nil → el bucle ya lo limpia (`s.target = 0`).

## 6. Estado

Sin campos nuevos. El cliente sabe del dorado por el atributo `Gold` del montón y por el aviso.

## 7. Pantallas (cliente — Leo lo programa; Vega revisa capturas)

Vega está cambiando ahora `Client.client.luau`, `UI/Mundo3D.luau` y `Lang.luau`: **Leo debe partir de su versión ya subida**.

| Archivo | Parte | Cambio |
|---|---|---|
| `UI/Mundo3D.luau` | `step`, donde se rellena `pileById` cada 0,4 s | Si `p:GetAttribute("Gold")` y aún no tiene marca: crear (local) un `BillboardGui` llamado `MarcaDorada` en el montón: `Size` 120×120, `StudsOffset` (0, 7, 0), `AlwaysOnTop = true`, `MaxDistance = 400`, con un `TextLabel` «🌟» de 90 px y borde. Cada frame, que la estrella suba y baje un poco (`math.sin(clock * 3) * 0.6` en `StudsOffset.Y`). Al destruirse el montón, se va con él |
| `Client.client.luau` | `notifyRemote.OnClientEvent` | `kind == "gold"` → `showToast(T(textKey, niceParams(params)), "gold")` (ya traduce `zone` con `niceParams`) |
| `Client.client.luau` | bloque de avisos (`showToast`) | color para `"gold"`: `C.gold` con texto oscuro (`C.ink`) por contraste, y que dure 5 s (las demás, 3 s). Si Leo hace también la ficha del «gran momento», es el mismo cambio (color y duración opcionales) |

- Móvil: el toast ya existe y baja si hay tutorial; la estrella es 3D (BillboardGui), no ocupa interfaz.
- Sin flecha en la versión mínima (la estrella se ve a través de todo; la flecha sería una ampliación).

Textos (`Lang.luau`, en `es` y `en`):

| Clave | ES | EN |
|---|---|---|
| `n_gold_pile` | 🌟 ¡Montón Dorado en {zone}! Rómpelo antes de 60 s | 🌟 Golden Pile on {zone}! Break it within 60 s |
| `n_gold_pile_locked` | 🌟 Montón Dorado en {zone} (abre esa isla para llegar) | 🌟 Golden Pile on {zone} (unlock that island to reach it) |

(Si cambia `GOLD_LIFETIME`, cambiar el «60 s»: o mejor, pasar `{ secs = Config.GOLD_LIFETIME }` y usar `{secs}`.)

## 8. Tienda

No aplica. **No** vender «más dorados», ni avisos, ni nada relacionado.

## 9. Pruebas (`tools/harness/run_juego.luau`)

Sin acción nueva → no hay que añadir acciones. Añadir tras la prueba «Tocar un montón…» (antes del huevo, con el jugador en la isla 1):

1. **Aparece**: avanzar `frame(W)` hasta que haya en `Montones` una pieza con atributo `Gold` (máx. `Config.GOLD_INTERVAL + 5` vueltas;
   ojo: si la prueba anterior ya gastó 60 vueltas, descontar). Comprobar:
   - está en la isla 1 (`GetAttribute("Zone") == 1`), `MaxHp == Config.GOLD_HP * Config.Zones[1].pileHp`;
   - solo hay **un** dorado (1 jugador → 1 isla);
   - en `W.fired` hay `{ "Notify", W.player, "gold", "n_gold_pile", { zone = 1 } }`;
   - en el cliente hay un `BillboardGui` `MarcaDorada` (si Mundo3D corre en el harness; si no, comprobarlo en `vista_mundo`).
2. **Se rompe y paga ×33 con reparto por daño**: guardar `c0 = lastState(W).coins`, acercar `hrp` al dorado, disparar su
   `ClickDetector` (como con el montón normal) y avanzar vueltas hasta que desaparezca. Comprobar que
   `coins − c0 ≥ Config.GOLD_COINS * Config.Zones[1].pileCoins * lastState(W).coinMult * 0.99` (1 jugador = todo el daño
   = todo el premio; el resto de monedas de esas vueltas solo suma).
3. **No reaparece**: avanzar `Config.PILE_RESPAWN + 2` vueltas → no hay ninguna pieza con `Gold`.
4. **Caduca**: avanzar hasta el siguiente dorado, **no** tocarlo, poner Auto a NO (`setAuto(false)`) y alejar al jugador;
   avanzar `Config.GOLD_LIFETIME + 1` vueltas → ya no está y las monedas no han subido por él. Volver a dejar Auto como estaba.
5. Pasada en inglés: el toast sale con el texto EN. `check_lang.py` pasa con las 2 claves.
6. Si el harness se hace muy lento con 180 + 60 vueltas: ≈ añadir al mock una forma de bajar `Config.GOLD_INTERVAL` antes de
   arrancar el servidor (p. ej. cambiar el valor en la tabla `Config` cargada) y documentarlo en el propio test.

## 10. Objetivo de ritmo medible

- Con la simulación de §4: ningún hito de `DISENO.md` §5 se adelanta más del 20 % (medido: isla 2 0 %, isla 3 −5 %, isla 4 −6,5 %).
- En el hueco isla 3→4 hay ≈ 6 dorados (19 min de bot / 3 min) ≈ 13 en tiempo de persona: un evento cada 3 min.
- Tras publicar: duración media de sesión (meta ≈ ≥ 8–10 min, `marketing/plan.md`).

## 11. Riesgos, qué NO hacer y pre-mortem

- **No** tocar el reparto por daño ni las probabilidades; **no** ponerle precio; **no** escribir multiplicadores falsos en el aviso.
- Rendimiento: como mucho 1 dorado por isla con jugadores (≤ 8, en la práctica 1–3) y 60 s de vida.
- Con 8 jugadores el toast sale una vez por isla distinta: como mucho unos pocos avisos cada 3 min (aceptable).
- **Pre-mortem** — «un mes después no ha servido porque…»:
  1. *Nadie lo veía* (estaba detrás o lejos) → estrella `AlwaysOnTop` a 400 studs + aviso; revisar en Studio con capturas.
  2. *Se lo comía el modo Auto sin que el jugador se diera cuenta* → no es malo (ganó monedas), pero el aviso y la
     estrella lo hacen visible; si molesta, ampliación: el «+🪙» flotante del dorado más grande.
  3. *Rompió el ritmo* → ya medido (§4); si las analíticas dicen otra cosa, bajar `GOLD_COINS` en Config (un número).

## Lo que no sé (≈)

- La simulación suma el premio de golpe y supone que el bot rompe todos los dorados; no simula andar hasta él.
- Si `Enum.Material.Neon` dorado se ve bien con `Lighting.Technology = Future` (que lo mire Vega en Studio o en la vista 3D).
- Si en el harness `Mundo3D` se ejecuta y se puede comprobar la `MarcaDorada` (si no, en `vista_mundo`).
