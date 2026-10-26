# Propuesta: 🔔 Salir a bolsa (prestigio) — AeroCarga España

- Fecha: 2026-10-24 · Autor: Nico (diseño) · Para: Leo (programar) y Vega (interfaz y pruebas)
- Estado: **propuesta, sin programar**. Versión del juego al proponer: 0.2.
- Prestigio = «empezar de cero con ventaja permanente».

## 1. Por qué (con datos medidos)

Copié el bot de `tools/harness/run_server.luau` a una carpeta temporal y lo dejé jugar hasta el nivel 22
(sin tocar `tools/out` ni el `.rbxl`). Resultado de **dos partidas** (hay azar):

| Momento | Partida 1 | Partida 2 | Dinero ganado en total (partida 2) |
|---|---|---|---|
| Nivel 10 | 22,8 min | 24,1 min | $3,9M |
| Nivel 15 | 39,8 min | 47,4 min | $13,2M |
| Último avión (Cóndor, nv 13; Ballena pide nv 18 y $20M) | 43,5 min | — | |
| Nivel 18 | 53,0 min | 64,2 min | $23,3M |
| 9/9 regiones (Canarias) | 56,7 min | 88,8 min | $46,2M (nv 22) |

Una persona va 2–3 veces más lenta → **entre 2 y 4 horas se acaba todo lo nuevo**: no quedan regiones, el
último avión ya está disponible y los objetivos terminan en nivel 20. No hay **meta larga** (pregunta 3 del
diagnóstico) y eso es justo cuando el jugador que más paga se va. El propio `CLAUDE.md` del juego (§10) ya
apunta «salir a bolsa» como idea pendiente.

## 2. Qué ve y hace el jugador

**Antes del nivel 15** (para que lo vea venir desde pronto):
- En la ventana **España**, arriba del todo, una tarjeta dorada «🔔 Salir a bolsa» con candado: «🔒 Nivel 15».
  Texto: «Empieza de cero y gana acciones: cada acción = +10 % de dinero para siempre».

**Al llegar al nivel 15** (primeros 30 s con la mecánica):
1. Aviso `goal`: «🔔 ¡Ya puedes salir a bolsa!». El botón **España** de la barra muestra «!».
2. Abre España → la tarjeta dice «Ganarías **3 📈 acciones** (+30 % de dinero para siempre)» y una barra
   «Siguiente acción a $16M ganados». Botón naranja grande: «🔔 Salir a bolsa».
3. Al pulsarlo sale una ventana de confirmación (la misma pieza que «vender avión», `ctx.openModal`):
   - ✅ **Conservas**: pilotos (con su nivel), acciones, pases, objetivos reclamados, racha diaria, misiones
     de hoy, ranking.
   - ❌ **Empiezas de cero**: dinero, aviones (vuelves con 1 Gorrión en Madrid), regiones, mejoras y nivel.
   - Botones: «Cancelar» (gris) y «🔔 ¡Salir a bolsa!» (naranja).
4. Confirma → los vuelos en el aire aterrizan y se cobran al momento → se reinicia → confeti + ventana
   «¡Tu aerolínea ya cotiza en bolsa! +3 📈 · Ahora ganas un +30 % más en cada vuelo».
5. En el HUD, junto al nivel, aparece la pastilla «📈 +30 %» (siempre visible desde la 1.ª salida).
6. La 2.ª partida se nota más rápida (más dinero por vuelo, y pilotos ya fichados esperando aviones).

Decisión que da juego: salir ya (3 acciones) o aguantar al nivel 20 (≈5 acciones). La raíz cuadrada hace que
aguantar compense, pero cada vez menos.

## 3. Datos nuevos en `Data.newData()`

| Campo | Tipo | Valor inicial | Para qué |
|---|---|---|---|
| `shares` | number | 0 | Acciones acumuladas (nunca se reinician) |
| `ipoCount` | number | 0 | Veces que ha salido a bolsa |
| `runEarned` | number | 0 | Dinero ganado en vuelos **desde la última salida** (base de las acciones) |

**Migración** (en `Data.load`, después de `reconcile`): partidas viejas no tienen `runEarned`, así que
`reconcile` les pondría 0 y perderían lo ganado. Regla:
`if data.ipoCount == 0 and data.runEarned == 0 and data.stats.earned > 0 then data.runEarned = data.stats.earned end`.
Usar `ipoCount == 0` como condición evita volver a migrar a quien ya salió a bolsa y tiene `runEarned = 0` de verdad.

`runEarned` sube **solo** en `Game.finishFlight`, en el mismo sitio que `Game.addStat(session, "earned", net)`
(premios de misiones, objetivos, diario y maletines de Robux **no** cuentan → no se puede comprar acciones con Robux).

## 4. Números para `Config`

```lua
Config.IPO = {
	level = 15,          -- nivel mínimo (bot ≈ 40–47 min; persona ≈ 1,5–2,5 h)
	unit = 1_000_000,    -- $ ganados para la 1.ª acción
	perShare = 0.10,     -- +10 % de dinero por acción
}
function Config.ipoShares(runEarned: number): number
	return math.floor(math.sqrt(math.max(0, runEarned) / Config.IPO.unit))
end
function Config.ipoNextAt(shares: number): number -- $ para la siguiente acción en esta partida
	return (shares + 1) ^ 2 * Config.IPO.unit
end
function Config.sharesMult(shares: number): number
	return 1 + Config.IPO.perShare * shares
end
```

Con los datos medidos: nv 15 ($13M) → **3 acciones (+30 %)** · nv 18 ($23M) → 4 · nv 20 ($33M) → 5 · nv 22 ($46M) → 6.

Dónde se aplica: `Game.moneyMult(session)` multiplica además por `Config.sharesMult(data.shares)`.
Ojo: la XP de cada vuelo es `sqrt(gross)` y `gross` ya incluye `moneyMult`, así que +30 % de dinero ≈ +14 % de XP
(es lo que queremos: la 2.ª partida va algo más rápida, no muchísimo).

**Objetivos de ritmo (medibles con el bot):**
- 1.ª salida disponible: bot 35–50 min (persona 1,5–2,5 h). ✔ ya cuadra con nivel 15.
- 2.ª partida con +30 %: llegar a nivel 15 en **≤ 80 %** del tiempo de la 1.ª (bot ≈ 32–38 min).
- 3.ª salida: el bot debe sacar **≥ 3 acciones** otra vez (con más multiplicador gana más por nivel).
- Si la 2.ª partida va a < 60 % del tiempo, bajar `perShare` a 0,08.

## 5. Acción nueva del servidor: `ipo()`

Sin argumentos (ignora `a, b, c`). Debe validar **en este orden**:

| Comprobación | Error (`Lang`) |
|---|---|
| `data.tutorial == 99` | `err_ipo_tutorial` |
| `Game.level(data) >= Config.IPO.level` | `req_level` con `{ level = 15 }` (clave ya existe) |
| `Config.ipoShares(data.runEarned) >= 1` | `err_ipo_none` |

Frecuencia: la cubre el límite general de 10 acciones/s; además, tras salir el nivel vuelve a 1, así que una
2.ª llamada seguida falla sola con `req_level` (no hace falta enfriamiento extra).

Efecto (en este orden):
1. Aterrizar y cobrar los vuelos en el aire: `Game.finishFlight(session, plane, true)` para cada avión con `flight`.
2. `gained = Config.ipoShares(data.runEarned)`; `data.shares += gained`; `data.ipoCount += 1`; `data.runEarned = 0`.
3. Reiniciar: `money = Config.START_MONEY`, `xp = 0`,
   `planes = { { id = data.nextId, model = "sparrow", airport = Config.START_HUB, condition = 100 } }` y `nextId += 1`
   (no reutilizar ids), `regions = { CEN = true, LEV = true }`, todas las `upgrades = 0`, `rate = 0`
   (si no, las ganancias offline usarían el ritmo viejo).
4. Sesión: `session.boards = {}`, `session.refreshAt = {}`, `session.express = nil`; `Game.refreshCandidates(session)`
   (los precios de candidatos dependen del nivel).
5. **No tocar**: `pilots`, `stats` (ranking sigue por `stats.earned`), `goals`, `missions`, `daily`, `receipts`,
   `settings`, `boostUntil`, `starterBought`, `tutorial`, pases.
6. Guardar ya (como tras una compra con Robux) y `Game.pushState`.
7. Devolver `true, "n_ipo_done", { shares = gained, total = data.shares }, { ipo = gained }` y
   `Game.notifyAll("feed", "n_ipo_feed", { name = player.DisplayName })` («Fulano ha salido a bolsa»).

Además: en `Game.tick`, cuando el nivel pasa a ≥ 15 por primera vez en la partida y `ipoShares ≥ 1`, aviso
`goal` `n_ipo_ready` (una vez; guardar un booleano de sesión, no en datos).

## 6. Campos nuevos en el estado (`sendState`)

`shares` (number) · `ipoCount` (number) · `runEarned` (number) · `ipoGain` (= `Config.ipoShares(runEarned)`) ·
`sharesMult` (number). Solo números: nada de tablas mixtas (`mock.luau` lo comprueba).

## 7. Pantallas y textos (Vega)

- **España** (`SpainPanel.luau`): tarjeta dorada arriba de las regiones, misma altura que las otras + barra.
  Botón principal naranja a la derecha (250×54 como «comprar región»); `ctx.targets.ipo_btn`.
- **Modal** de confirmación con dos columnas (Conservas / Empiezas de cero). En móvil (`ctx.compact`) una sola
  columna con scroll.
- **HUD** (`Hud.luau`): pastilla «📈 +30 %» a la derecha de la tarjeta de nivel; oculta si `shares == 0`.
- **Badge** «!» en el botón España cuando `ipoGain ≥ 1` y nivel ≥ 15 (y `ipoCount == 0`, para no molestar siempre).

| Clave | ES | EN |
|---|---|---|
| `ipo_title` | 🔔 Salir a bolsa | 🔔 Go public |
| `ipo_desc` | Empieza de cero y gana acciones: cada acción = +10 % de dinero para siempre | Start over and earn shares: each share = +10% money forever |
| `ipo_gain` | Ganarías {shares} 📈 acciones (+{pct} % para siempre) | You'd get {shares} 📈 shares (+{pct}% forever) |
| `ipo_next` | Siguiente acción a {amount} ganados | Next share at {amount} earned |
| `ipo_keep` | Conservas: pilotos, acciones, pases, objetivos, racha y ranking | You keep: pilots, shares, passes, goals, streak and ranking |
| `ipo_lose` | Empiezas de cero: dinero, aviones, regiones, mejoras y nivel | You restart: money, planes, regions, upgrades and level |
| `ipo_confirm` | 🔔 ¡Salir a bolsa! | 🔔 Go public! |
| `n_ipo_ready` | 🔔 ¡Ya puedes salir a bolsa! Mira la ventana España | 🔔 You can go public! Check the Spain window |
| `n_ipo_done` | ¡Tu aerolínea cotiza en bolsa! +{shares} 📈 (total {total}) | Your airline is public! +{shares} 📈 (total {total}) |
| `n_ipo_feed` | 🔔 {name} ha sacado su aerolínea a bolsa | 🔔 {name} took their airline public |
| `err_ipo_tutorial` | Termina el tutorial primero | Finish the tutorial first |
| `err_ipo_none` | Aún no ganarías ninguna acción | You wouldn't earn any shares yet |
| `shares_chip` | 📈 +{pct} % | 📈 +{pct}% |

## 8. Monetización asociada

**Ningún artículo nuevo.** Es legítima porque:
- Las acciones solo salen de vuelos (`runEarned`), no de Robux → no se compra ventaja en el ranking directamente.
- Los pases que ya existen (VIP x2, Piloto automático, Turbo, Hangar XL) **siguen activos en cada partida**:
  cuanto más larga la vida del juego, más vale un pase permanente. Ese es el efecto en Robux (indirecto).
- Se puede mencionar una vez en la ventana final: «Tus pases siguen activos» (solo informativo, sin abrir la tienda).
- **No** vender «acciones», «salida instantánea» ni «saltar al nivel 15»: sería pagar por el ranking.

## 9. Pruebas (harness)

`run_server.luau`:
1. Errores: `ipo` en el tutorial → `err_ipo_tutorial`; a nivel < 15 → `req_level`.
2. El bot sigue hasta nivel 15 (hoy para en 10: subir el corte a 15), apunta tiempo y `runEarned`, y hace `ipo`.
   Comprobar: nivel 1, dinero 20.000, 1 avión `sparrow` en MAD, regiones CEN+LEV, mejoras a 0, pilotos iguales,
   `shares == floor(sqrt(runEarned/1e6))`, `moneyMult` sube ×(1 + 0,1·acciones), ningún avión con `flight`.
3. 2.ª llamada seguida → falla. Salir/entrar → `shares` e `ipoCount` guardados.
4. 2.ª partida hasta nivel 15: imprimir `[xx min] 2.ª salida` y comprobar ≤ 80 % del tiempo de la 1.ª.
5. Migración: datos viejos con `stats.earned = 5e6` y sin `runEarned` → `runEarned == 5e6`; datos con
   `ipoCount = 1, runEarned = 0` → no se toca.

`run_game.luau`: abrir España con estado a nivel 15, pulsar `ipo_btn` → Cancelar (no cambia nada) → otra vez →
Confirmar; ver la pastilla del HUD. Vista previa en PC y móvil (1280×561) de la tarjeta y del modal.
`check_lang.py` debe encontrar todas las claves nuevas.

## 10. Riesgos y qué NO hacer

- **No** meter la salida a bolsa en `GOAL_TRACKS`: la cadena de objetivos muestra el siguiente sin reclamar y
  un «sal a bolsa 1 vez» bloquearía la tarjeta de objetivos 1,5 h (trampa de §9 del CLAUDE.md del juego).
- **No** reiniciar `stats` (el ranking y las misiones dependen de ellas) ni `pilots`.
- La misión diaria «gana $X» se calcula con el nivel del momento: si se creó a nivel 15, tras salir a bolsa
  costará más ese día. Aceptable (dura < 24 h); **no** regenerar misiones al salir (se podría abusar).
- Los premios de objetivos usan el nivel actual (`rewardScale`): los objetivos viejos sin reclamar pagarán
  menos tras salir. Avisarlo en el modal no hace falta; sí no permitir nada que lo explote.
- Guardar justo después (si se cae el servidor entre reinicio y guardado, el jugador volvería al estado anterior:
  es el resultado menos malo).
- Subir `Config.VERSION` y documentar acción, datos y estado en `roblox-carga-aerea/CLAUDE.md` y `DISENO.md`.

## 11. Confianza

- Números medidos con el bot (2 partidas, hay azar): **alta** (~85 %).
- Que +10 % por acción dé una 2.ª partida un 20–30 % más rápida: **estimado** (~60 %); hay que medirlo.
- Que enganche a personas reales: sin datos (el juego no está publicado) → ~65 %.
