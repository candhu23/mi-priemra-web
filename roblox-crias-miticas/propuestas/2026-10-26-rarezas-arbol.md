# Ficha — 8 rarezas por fusión, 72 crías, Brillantes, piedras y Jardín de Mejoras (Crías Míticas)

Autor: Nico (diseño) · Fecha: 2026-10-26 · Para: Leo (2a núcleo, 2b mundo) y Vega (pantallas) · Estado: 💡 propuesta (pedido literal del usuario)
Base: `PLAN.md` (respuestas del usuario), `Config.luau` actual (con los cristales de Leo-1: monedas ×17,5 y vida ×7 por zona),
`Main.server.luau` (`hatch`, `fuse`, `unlockZone`, `rebirth`), `World.luau` (`World.GRID`, huevo sobre pilar).

**Decisiones del usuario ya confirmadas (2026-10-26):** zona 7 = huevo **Épico** ✔ · zona 9 = huevo **Prodigioso** (rosa/magenta; la única
excepción a «huevos solo hasta Legendario») ✔ · modelos de animales **Quaternius (17, CC0)** ✔.
**Decisiones de Álex que sigo:** Brillante mínimo · 72 crías (9 × 8) · Jardín en la celda (-1,0) · zona 9 en (2,2) · altar de fusión en
zona 1 y en el Jardín · DataStore `MythicHatchlings_v2`.
**Pendiente (pregunta para el usuario, §12):** ¿fusionar solo en el altar o en cualquier sitio?

Todos los ritmos de esta ficha salen de un **simulador en Python aparte** (copia de la lógica del bot `ritmo.luau`, 10 partidas,
EFICIENCIA 0,75, sin Montón Dorado, sin pases). **No** he ejecutado el harness ni `check.sh` (Leo los está usando). Leo debe
volver a medirlo con `ritmo.luau` al programarlo (§10).

---

# PARTE A — Núcleo (ronda Leo-2a)

## 1. Las 8 rarezas

Regla única de poder: **cada rareza tiene ×3 de poder que la anterior** (`power = 3^(i-1)`). Por qué ×3: con 3 huecos, fusionar
nunca baja el poder del equipo (5 Comunes equipadas = 3 de poder → 1 Poco común = 3 + las que queden); y si fuese ×5 el
ingreso crecía tan rápido que el juego se acababa en 12 minutos (lo medí: con ×4 por paso, de la zona 2 a la 8 en 9 minutos).

`Config.Rarities` (orden fijo; **sin** `weight`: ahora cada huevo es de una sola rareza):

| i | `id` | `power` | `fuseNeed` (para subir a la siguiente) | `color` (RGB) | `size` | `aura` | `shinyPoints` | ES (`rar_<id>`) | EN |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `common` | 1 | 5 | 148, 163, 184 (gris) | 1.0 | no | 1 | Común | Common |
| 2 | `uncommon` | 3 | 5 | 34, 197, 94 (verde) | 1.1 | no | 2 | Poco común | Uncommon |
| 3 | `rare` | 9 | 5 | 59, 130, 246 (azul) | 1.2 | no | 4 | Rara | Rare |
| 4 | `epic` | 27 | 5 | 168, 85, 247 (morado) | 1.35 | sí, suave | 8 | Épica | Epic |
| 5 | `legendary` | 81 | 5 | 250, 204, 21 (dorado) | 1.5 | sí | 15 | Legendaria | Legendary |
| 6 | `prodigious` | 243 | 3 | 236, 72, 153 (rosa/magenta) | 1.7 | sí | 25 | Prodigiosa | Prodigious |
| 7 | `ascended` | 729 | 3 | 34, 211, 238 (turquesa) | 1.9 | sí, fuerte | 40 | Ascendida | Ascended |
| 8 | `mythic` | 2187 | — (no se fusiona) | 244, 63, 94 (carmesí) | 2.2 | sí, fuerte + luz | 60 | Mítica | Mythic |

- Poder real de una cría = `Zones[zona].petBase × Rarities[i].power × (2 si es Brillante)`.
- Coste en crías del huevo de su rareza: Poco común 5 · Rara 25 · Épica 125 · Legendaria 625 · Prodigiosa 3.125 · Ascendida 9.375 ·
  **Mítica 28.125 Comunes** (zona 1) · 45 Legendarias (zona 8) · **9 Prodigiosas (zona 9)**.
- `Config.HATCH_MEDIUM_FROM` / `HATCH_BIG_FROM` dejan de mirar la rareza del huevo (ahora es fija): ver §5 (gran momento = Brillante o cría nueva).

## 2. 9 zonas × 8 crías (72) — familias con los animales Quaternius

**Cómo cuadran 72 crías si el huevo solo da una rareza:** si cada familia tuviese 1 cría por rareza, en la zona 3 (huevo Poco común)
la Común sería imposible de conseguir. Solución: la familia **empieza en la rareza del huevo**, y los huecos que sobran son
**varias especies del huevo** (mismo animal, distinto color). Así cada zona tiene 8 crías y **todas se pueden conseguir**:

| Zona | Huevo | Especies que da el huevo (prob. igual) | Por encima, 1 por rareza | Total |
|---|---|---|---|---|
| 1, 2 | Común | 1 | U, R, E, L, P, A, M (7) | 8 |
| 3, 4 | Poco común | 2 (50 % c/u) | R, E, L, P, A, M (6) | 8 |
| 5 | Rara | 3 (33,3 %) | E, L, P, A, M (5) | 8 |
| 6, 7 | Épica | 4 (25 %) | L, P, A, M (4) | 8 |
| 8 | Legendaria | 5 (20 %) | P, A, M (3) | 8 |
| 9 | Prodigiosa | 6 (16,7 %) | A, M (2) | 8 |

**Regla de fusión para niños (cabe en un botón):** «5 crías **de la misma isla y el mismo color** → la siguiente de esa isla»
(3 desde Prodigiosa). Las especies del huevo se pueden mezclar (5 Legendarias de la zona 8 de cualquier gato → la Prodigiosa
de la zona 8). Por encima del huevo solo hay una cría por rareza, así que no hay dudas de qué sale.

Campos de cada cría en `Config.Zones[i].pets` (se mantiene la lista y se añaden campos): `{ id, emoji, color, model, rarity }`.
`model` = nombre del modelo Quaternius en `ServerStorage.Modelos` (alias propuesto en CamelCase sin espacios: `Chick, Bird, Eagle,
RedFox, Cat, Wolf, Fish, Piranha, Whale, Llama, Horse, Zebra, Pig, Cow, Pug, Dog, Sheep`). `color` = color principal del
recoloreado. El nombre ES/EN va en `Lang` con clave `pet_<id>`. Tamaño y aura salen de la rareza (§1); sin modelos → bola + emoji
como hoy. Los 17 modelos se usan todos.

### Zona 1 · Pradera Brote (`meadow`) — huevo Común — Chick → Bird → Eagle
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Común | `sproutchick` | Pío Brote | Sprout Chick | 🐣 | Chick | 255, 225, 90 |
| Poco común | `cloverchick` | Pío Trébol | Clover Chick | 🐥 | Chick | 170, 220, 90 |
| Rara | `meadowsparrow` | Gorrión del Prado | Meadow Sparrow | 🐦 | Bird | 190, 140, 90 |
| Épica | `dewblackbird` | Mirlo Rocío | Dew Blackbird | 🐦 | Bird | 70, 90, 150 |
| Legendaria | `sunhummer` | Colibrí Solar | Sun Hummer | 🐦 | Bird | 250, 190, 40 |
| Prodigiosa | `bloomeagle` | Águila Floral | Bloom Eagle | 🦅 | Eagle | 240, 140, 190 |
| Ascendida | `dawneagle` | Águila del Alba | Dawn Eagle | 🦅 | Eagle | 255, 170, 110 |
| Mítica | `meadowskylord` | Señor del Cielo Verde | Meadow Skylord | 🦅 | Eagle | 120, 230, 140 |

### Zona 2 · Bosque Seta (`mushroom`) — huevo Común — RedFox → Cat → Wolf
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Común | `mosskit` | Zorrito Musgo | Moss Kit | 🦊 | RedFox | 200, 120, 60 |
| Poco común | `capfox` | Zorro Seta | Cap Fox | 🦊 | RedFox | 220, 70, 70 |
| Rara | `fernfox` | Zorro Helecho | Fern Fox | 🦊 | RedFox | 90, 170, 90 |
| Épica | `fireflyfox` | Zorro Luciérnaga | Firefly Fox | 🦊 | RedFox | 230, 230, 110 |
| Legendaria | `forestlynx` | Lince del Bosque | Forest Lynx | 🐈 | Cat | 190, 150, 90 |
| Prodigiosa | `sporecat` | Gato Espora | Spore Cat | 🐈 | Cat | 180, 110, 220 |
| Ascendida | `shadewolf` | Lobo Umbrío | Shade Wolf | 🐺 | Wolf | 90, 90, 130 |
| Mítica | `elderwolf` | Lobo Ancestral | Elder Wolf | 🐺 | Wolf | 150, 255, 170 |

### Zona 3 · Playa Coral (`coral`) — huevo Poco común (2 especies) — Fish → Piranha → Whale
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Poco común | `coralclown` | Pez Payaso Coral | Coral Clownfish | 🐠 | Fish | 250, 130, 50 |
| Poco común | `lagoontang` | Pez Cirujano Laguna | Lagoon Tang | 🐟 | Fish | 60, 130, 240 |
| Rara | `bubblepuffer` | Pez Globo Burbuja | Bubble Puffer | 🐡 | Fish | 240, 220, 120 |
| Épica | `reefpiranha` | Piraña de Arrecife | Reef Piranha | 🐟 | Piranha | 230, 90, 90 |
| Legendaria | `pearlpiranha` | Piraña Perla | Pearl Piranha | 🐟 | Piranha | 245, 235, 250 |
| Prodigiosa | `foamcalf` | Ballenato Espuma | Foam Calf | 🐳 | Whale | 150, 210, 240 |
| Ascendida | `tidewhale` | Ballena Marea | Tide Whale | 🐋 | Whale | 60, 120, 210 |
| Mítica | `coralleviathan` | Leviatán de Coral | Coral Leviathan | 🐋 | Whale | 255, 120, 200 |

### Zona 4 · Dunas Doradas (`dunes`) — huevo Poco común (2 especies) — Llama → Horse → Zebra
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Poco común | `dunellama` | Llama Duna | Dune Llama | 🦙 | Llama | 235, 200, 140 |
| Poco común | `oasisllama` | Llama Oasis | Oasis Llama | 🦙 | Llama | 120, 200, 190 |
| Rara | `caravanllama` | Llama Caravana | Caravan Llama | 🦙 | Llama | 200, 110, 70 |
| Épica | `sandstallion` | Corcel de Arena | Sand Stallion | 🐎 | Horse | 210, 170, 110 |
| Legendaria | `sunstallion` | Corcel Solar | Sun Stallion | 🐎 | Horse | 250, 180, 40 |
| Prodigiosa | `miragezebra` | Cebra Espejismo | Mirage Zebra | 🦓 | Zebra | 120, 220, 230 |
| Ascendida | `amberzebra` | Cebra Ámbar | Amber Zebra | 🦓 | Zebra | 230, 140, 40 |
| Mítica | `pharaohzebra` | Cebra Faraona | Pharaoh Zebra | 🦓 | Zebra | 250, 215, 90 |

### Zona 5 · Volcán Brasa (`volcano`) — huevo Raro (3 especies) — Pig → Cow (toro)
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Rara | `emberpiglet` | Cerdito Brasa | Ember Piglet | 🐷 | Pig | 250, 140, 60 |
| Rara | `ashpiglet` | Cerdito Ceniza | Ash Piglet | 🐷 | Pig | 130, 130, 140 |
| Rara | `lavapiglet` | Cerdito Lava | Lava Piglet | 🐷 | Pig | 220, 50, 40 |
| Épica | `magmaboar` | Jabalí Magma | Magma Boar | 🐗 | Pig | 150, 50, 30 |
| Legendaria | `cinderbull` | Toro Carbón | Cinder Bull | 🐂 | Cow | 70, 60, 60 |
| Prodigiosa | `flarebull` | Toro Llamarada | Flare Bull | 🐂 | Cow | 255, 110, 40 |
| Ascendida | `obsidianbull` | Toro Obsidiana | Obsidian Bull | 🐂 | Cow | 60, 40, 90 |
| Mítica | `volcanotitan` | Titán del Volcán | Volcano Titan | 🐂 | Cow | 255, 70, 30 |

### Zona 6 · Glaciar Cristal (`glacier`) — huevo Épico (4 especies) — Pug → Dog → Wolf
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Épica | `frostpug` | Carlino Escarcha | Frost Pug | 🐶 | Pug | 190, 220, 250 |
| Épica | `snowpug` | Carlino Nevado | Snowy Pug | 🐶 | Pug | 245, 245, 250 |
| Épica | `sledpup` | Perrito Trineo | Sled Pup | 🐕 | Dog | 170, 120, 80 |
| Épica | `icehound` | Sabueso de Hielo | Ice Hound | 🐕 | Dog | 110, 170, 230 |
| Legendaria | `glacierhusky` | Husky Glaciar | Glacier Husky | 🐕 | Dog | 200, 215, 235 |
| Prodigiosa | `blizzardwolf` | Lobo Ventisca | Blizzard Wolf | 🐺 | Wolf | 230, 240, 255 |
| Ascendida | `crystalwolf` | Lobo de Cristal | Crystal Wolf | 🐺 | Wolf | 140, 220, 255 |
| Mítica | `polarwarden` | Guardián Polar | Polar Warden | 🐺 | Wolf | 120, 255, 220 |

### Zona 7 · Mar de Nubes (`clouds`) — huevo Épico (4 especies) — Sheep → Horse (pegaso)
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Épica | `cloudlamb` | Corderito Nube | Cloud Lamb | 🐑 | Sheep | 250, 250, 255 |
| Épica | `mistlamb` | Corderito Niebla | Mist Lamb | 🐑 | Sheep | 200, 210, 230 |
| Épica | `rainlamb` | Corderito Lluvia | Rain Lamb | 🐑 | Sheep | 150, 190, 250 |
| Épica | `sunsetlamb` | Corderito Ocaso | Sunset Lamb | 🐑 | Sheep | 255, 180, 200 |
| Legendaria | `thunderram` | Carnero Trueno | Thunder Ram | 🐏 | Sheep | 255, 230, 90 |
| Prodigiosa | `skypony` | Potro Celeste | Sky Pony | 🐴 | Horse | 180, 210, 255 |
| Ascendida | `windpegasus` | Pegaso del Viento | Wind Pegasus | 🐴 | Horse | 230, 240, 255 |
| Mítica | `stormpegasus` | Pegaso Tormenta | Storm Pegasus | 🐴 | Horse | 140, 120, 255 |

### Zona 8 · Cosmos (`cosmos`) — huevo Legendario (5 especies) — Cat → Whale
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Legendaria | `mooncat` | Gato Luna | Moon Cat | 🐱 | Cat | 210, 210, 235 |
| Legendaria | `starcat` | Gato Estrella | Star Cat | 🐱 | Cat | 255, 230, 100 |
| Legendaria | `cometcat` | Gato Cometa | Comet Cat | 🐱 | Cat | 100, 200, 255 |
| Legendaria | `nebulacat` | Gato Nebulosa | Nebula Cat | 🐱 | Cat | 200, 120, 255 |
| Legendaria | `eclipsecat` | Gato Eclipse | Eclipse Cat | 🐱 | Cat | 50, 40, 80 |
| Prodigiosa | `stardustwhale` | Ballena Polvo Estelar | Stardust Whale | 🐋 | Whale | 170, 130, 255 |
| Ascendida | `galaxywhale` | Ballena Galaxia | Galaxy Whale | 🐋 | Whale | 90, 60, 200 |
| Mítica | `cosmoswhale` | Ballena del Cosmos | Cosmos Whale | 🐋 | Whale | 255, 90, 220 |

### Zona 9 · Santuario Aurora (`aurora`, NUEVA) — huevo Prodigioso (6 especies) — RedFox → Wolf → RedFox
| Rareza | `id` | ES | EN | emoji | `model` | `color` |
|---|---|---|---|---|---|---|
| Prodigiosa | `greenaurorafox` | Zorro Aurora Verde | Green Aurora Fox | 🦊 | RedFox | 90, 240, 160 |
| Prodigiosa | `pinkaurorafox` | Zorro Aurora Rosa | Pink Aurora Fox | 🦊 | RedFox | 255, 130, 200 |
| Prodigiosa | `blueaurorafox` | Zorro Aurora Azul | Blue Aurora Fox | 🦊 | RedFox | 90, 170, 255 |
| Prodigiosa | `violetaurorafox` | Zorro Aurora Violeta | Violet Aurora Fox | 🦊 | RedFox | 170, 110, 255 |
| Prodigiosa | `goldaurorafox` | Zorro Aurora Dorado | Gold Aurora Fox | 🦊 | RedFox | 255, 210, 80 |
| Prodigiosa | `silveraurorafox` | Zorro Aurora Plateado | Silver Aurora Fox | 🦊 | RedFox | 220, 225, 240 |
| Ascendida | `borealwolf` | Lobo Boreal | Boreal Wolf | 🐺 | Wolf | 120, 255, 230 |
| Mítica | `celestialfox` | Zorro Celestial | Celestial Fox | 🦊 | RedFox | 255, 245, 255 |

Nombres de zona nuevos en `Lang`: `zone_aurora` = «Santuario Aurora» / «Aurora Sanctuary»; `zone_garden` = «Jardín de Mejoras» / «Upgrade Garden».
`Config.STARTER_PET = "sproutchick"`. Los nombres son genéricos (pollito, zorro, ballena…): no copian Collect All Pets.

## 3. Huevo de cada zona y números por zona

`Config.Zones[i]` gana campos explícitos (se **quitan** de la fórmula `eggCost`, `petBase` y `doorCost`; `pileHp` y `pileCoins`
siguen con la fórmula de Leo-1: `12·7^k` y `6·17,5^k`, k = zona − 1, también para la zona 9).

| Zona | `eggRarity` | color del huevo (`Config.EggColors[eggRarity]`) | `eggCost` (monedas) | `petBase` | Poder de la cría del huevo | `needDiscovered` | `needShiny` |
|---|---|---|---|---|---|---|---|
| 1 Pradera Brote | 1 Común | blanco | 50 | 3 | 3 | — | — |
| 2 Bosque Seta | 1 Común | blanco | 1.100 | 35 | 35 | 3 | — |
| 3 Playa Coral | 2 Poco común | verde | 300.000 | 400 | 1.200 | 7 | — |
| 4 Dunas Doradas | 2 Poco común | verde | 7.000.000 | 4.500 | 13.500 | 11 | — |
| 5 Volcán Brasa | 3 Rara | azul | 1.400.000.000 (1,4B) | 50.000 | 450.000 | 16 | — |
| 6 Glaciar Cristal | 4 Épica | morado | 50.000.000.000 (50B) | 190.000 | 5,13M | 21 | — |
| 7 Mar de Nubes | 4 Épica | morado | 1.700.000.000.000 (1,7T) | 2.100.000 | 56,7M | 27 | — |
| 8 Cosmos | 5 Legendaria | dorado | 28.000.000.000.000 (28T) | 8.000.000 | 648M | 33 | — |
| 9 Santuario Aurora | 6 Prodigiosa | rosa/magenta | 1.000.000.000.000.000 (1Qa) | 90.000.000 | 21,9B | — | 200 |

Por qué estos números:
- `petBase`: la cría del huevo nuevo es **≈ ×1,2 lo mejor que sacas fusionando en la zona anterior** (lo que pide la puerta).
  Ej.: zona 1 llegas a Rara = 3·9 = 27 → la Común de la zona 2 da 35. Zona 2 llegas a Épica = 35·27 = 945 → la Poco común de la
  zona 3 da 1.200. Así **cada huevo nuevo se nota** y lo viejo no se tira de golpe.
- `eggCost`: calibrado con el simulador para que el bot llegue a cada zona en el minuto objetivo (§10). Los saltos no son
  regulares porque el huevo cambia de rareza (zona 2→3 es ×270 porque pasas de Común a Poco común y los cristales dan ×2,5).
- Zona 9: huevo caro a propósito (≈16 s de ingreso al entrar) porque 9 Prodigiosas = 1 Mítica = 1 piedra (§7).
- Huevo de la zona 9: **Brillante ×2** (`Zones[9].shinyMult = 2`, decisión de Álex que se mantiene como premio de la última zona).
- El cliente ya escribe hasta `Qi` (`Kit.luau` SUFIJOS); con la zona 9 las monedas de toda la vida pueden pasar de 1e18 → Leo: añadir `Sx, Sp`.

Colores de huevo (`Config.EggColors`, por rareza; `shell` = cáscara, `spots` = manchas):

| rareza | `shell` | `spots` | `spotCount` | `glow` |
|---|---|---|---|---|
| 1 Común | 245, 245, 240 (blanco) | 200, 200, 195 | 5 | no |
| 2 Poco común | 110, 220, 120 (verde) | 40, 150, 70 | 6 | no |
| 3 Rara | 90, 160, 250 (azul) | 30, 80, 200 | 7 | no |
| 4 Épica | 180, 110, 245 (morado) | 110, 40, 180 | 8 | suave (PointLight 6) |
| 5 Legendaria | 250, 205, 40 (dorado) | 255, 245, 190 | 9 | sí (PointLight 10) |
| 6 Prodigiosa | 236, 72, 153 (magenta) | 255, 200, 235 | 10 | sí (PointLight 12) |

**Probabilidades visibles** en el cartel del huevo (obligatorio): cada especie con su % (100 % / 50 % / 33,3 % / 25 % / 20 % /
16,7 %) **y** «✨ Brillante 1 %» (o lo que dé la suerte, §5). `Config.eggOdds(zone, data, bonuses)` devuelve
`{ species = { { kind, pct } }, shinyPct }` y el servidor manda la `chance` real con cada apertura (como hoy).

## 4. Fusión 5/5/5/5/5/3/3 y «Fusionar todo»

- **Qué se fusiona:** `fuseNeed` crías con la **misma zona, misma rareza y mismo estado Brillante** → 1 cría de la rareza siguiente
  de esa zona (`Config.fuseResult(zone, rarity)` = la única cría de esa zona con `rarity + 1`). Normales y Brillantes **nunca** se mezclan.
- **Orden de qué crías se gastan** (en las especies mezclables del huevo): primero las **no equipadas**; dentro de eso, de la
  especie con **más copias** (así te quedas con variedad). Las equipadas solo si no hay bastantes sin equipar.
- **Equipadas:** si una fusión gasta alguna equipada, al terminar el servidor hace `equipBest` (la cría nueva suele ser la mejor).
  Igual tras «Fusionar todo».
- **«Fusionar todo»** (botón principal de la pantalla de fusión): repite fusiones mientras haya algún grupo con `fuseNeed`, de abajo arriba
  (Común primero, para que lo nuevo pueda volver a fusionarse en la misma pulsación), en **todas las zonas** e incluidas las Brillantes
  (5 Brillantes iguales → 1 Brillante). Tope de seguridad `FUSE_ALL_MAX = 500` fusiones por pulsación. Devuelve el resumen
  `{ count, made = { {kind, shiny, new} }, stones }` para que el cliente diga «¡12 fusiones! Nuevas: Zorro Helecho».
- **Mochila:** fusionar nunca falla por mochila llena (siempre baja el número de crías). Abrir sí (como hoy).
- **Caso raro:** con 6+ huecos y 5 equipadas iguales, una fusión puede bajar el poder total un poco (×3 < 5). Es raro y el resultado es
  una cría nueva; el cliente muestra «Poder: 1,2K → 1,1K» en el resumen para que no sea sorpresa. Si molesta, ampliación: casilla «🔒 proteger».
- Misiones: `fused` cuenta **cada** fusión (Fusionar todo puede sumar muchas) → subir `MissionPool.medium` fused a **5** y `hard` a **25**.

## 5. Brillante mínimo

| Campo | Valor | Por qué |
|---|---|---|
| `SHINY_CHANCE` | 0.01 (1 %) | 1.ª Brillante del bot a los ~8 min (mediana; 3–29 min). Con 2 % la zona 9 llegaba demasiado pronto |
| `SHINY_POWER` | 2 | Una Brillante = el doble que su normal. Se nota pero no rompe (vale menos que la rareza siguiente, ×3) |
| `Zones[9].shinyMult` | 2 | Huevo de la zona 9 = 2 % |
| Suerte de misiones (`LUCK_MULT`) | 2 | El «🍀 suerte x2» de completar las 3 misiones ahora **duplica la probabilidad de Brillante** (ya no hay rarezas al azar) |
| Mejora «Flor Destello» (§8) | ×1,5 | Se multiplican: 1 % × 1,5 × 2 (suerte) × 2 (zona 9) = máx. 6 % |

- Fórmula: `Config.shinyChance(zone, data, bonuses) = SHINY_CHANCE × (Zones[zone].shinyMult or 1) × (luck and LUCK_MULT or 1) × (1 + mejoras shiny)`.
- Al abrir: el servidor tira 2 números (especie y Brillante). La Brillante se ve con destellos (ParticleEmitter «Sparkles» en 3D y ✨ en la tarjeta).
- **Gran momento** (ficha momento-raro, se adapta): normal = cría repetida · mediano = **cría nueva en el Índice** · grande + aviso a todo el servidor =
  **Brillante** o **crear una Mítica** (`Config.HATCH_*` pasan a mirar `new`/`shiny`; el enfriamiento de 10 s sigue).
- **Puntuación Brillante** (`Config.shinyScore(data)`) = suma de `Rarities[r].shinyPoints` de cada cría **distinta** que has tenido en
  versión Brillante (`data.shinyIndex[kind] = true`). **No baja nunca** (fusionar o soltar Brillantes no la reduce) y premia la variedad.
  Puntos: Común 1 · Poco común 2 · Rara 4 · Épica 8 · Legendaria 15 · Prodigiosa 25 · Ascendida 40 · Mítica 60. Máximo de las zonas 1–8 = 1.326 (solo la zona 8 completa en Brillante = 200).
  Ejemplo de 200: las 5 Brillantes del huevo de la zona 8 (75) + su Prodigiosa (25) + Ascendida (40) + Brillantes sueltas de las zonas 1–7 (~60).
  El bot llega a 200 a las ~3 h 40 (§10).

## 6. Puertas: crías descubiertas (zonas 2–8) y puntuación Brillante (zona 9)

- **Cómo se cuenta:** `Config.albumCount(data)` = nº de crías **distintas** en `data.album` (clave = `kind`, ya sin «:versión»), de **todas** las
  zonas. La starter cuenta. Se apunta al abrir **y** al fusionar (`addPet`). Una Brillante también marca la normal como descubierta.
- `Actions.unlockZone(zone)`: `zone == d.zones + 1`, entero 2..9; zonas 2–8: `albumCount(d) >= Zones[zone].needDiscovered`; zona 9:
  `shinyScore(d) >= Zones[9].needShiny`. **No cuesta monedas.** Error: `n_need_index` («Descubre {n} crías para abrirla» / «Discover {n} hatchlings to open it»)
  o `n_need_shiny` («Consigue {n} de puntuación Brillante» / «Reach {n} Shiny score»).
- Lo que pide cada puerta (total acumulado) y qué significa en la zona anterior:

| Puerta | `needDiscovered` | Lo normal para llegar (zona anterior) | Huevos de esa zona |
|---|---|---|---|
| 2 | 3 | Pradera: Común + Poco común + Rara | 25 |
| 3 | 7 | Bosque: hasta Épica (4) | 125 |
| 4 | 11 | Playa: 2 especies + Rara + Épica (4) | 25 + suerte de ver las 2 |
| 5 | 16 | Dunas: hasta Legendaria (5) | 125 |
| 6 | 21 | Volcán: 3 especies + Épica + Legendaria (5) | 25 |
| 7 | 27 | Glaciar: 4 especies + Legendaria + Prodigiosa (6) | 125 |
| 8 | 33 | Mar de Nubes: igual (6) | 125 |
| 9 | ✨ 200 | Brillantes (§5) | — |

  También vale descubrir crías de zonas viejas (más baratas pero hacen falta muchas): es otro camino legítimo, no un truco.
- Cartel de la puerta (Mundo3D): «📖 9/11 crías» o «✨ 143/200»; cuando se cumple, la puerta se abre sola en el cliente y el servidor la apunta
  al entrar (o el botón «Abrir» de hoy llama a `unlockZone`). El bot de Leo llama a `unlockZone` como hasta ahora.

## 7. Piedras de Renacimiento (1 por Mítica)

- `d.stones += 1` y `d.stats.mythics += 1` **dentro de la misma fusión** que crea una Mítica (cualquier zona, normal o Brillante). Aviso
  `n_stone` («🪨 ¡Piedra de Renacimiento! Úsala en el Jardín» / «🪨 Rebirth Stone! Spend it in the Garden») + gran momento.
  Nombre: «Piedra de Renacimiento» lo pidió el usuario; aunque ya no hay renacer, se queda (el usuario lo eligió). Emoji 🪨. EN «Rebirth Stone».
- **Por qué no se puede farmear (abusar):**
  1. Solo nace en el servidor, en `fuse`, al consumir 3 Ascendidas reales de la partida (y la piedra y las crías se guardan en la misma tabla:
     si el servidor se cae antes de guardar, se pierden las dos cosas a la vez, nunca se duplica).
  2. No hay huevo de Mítica, ni intercambio, ni «desfusionar», ni devolución al soltar. Soltar una Mítica no quita ni da piedra.
  3. Cada piedra cuesta como mínimo 45 huevos Legendarios (28T cada uno) o 9 Prodigiosos (1Qa cada uno), y abrir tiene enfriamiento de 0,9 s.
  4. **No se vende** por Robux (ni piedras, ni mejoras, ni huevos, ni suerte). Los pases x2/abrir x3 aceleran, como ya aceleran todo.
- ≈ Lo que sí pasa (honesto): en la zona 9 un jugador fuerte saca **cientos de piedras por hora** (bot: 200→400 Míticas en ~20 min). Como el árbol
  cuesta 307 en total, al acabarlo las piedras **no tienen uso** → no se pueden abusar, pero hace falta un sumidero más adelante (ampliación).

## 8. Jardín de Mejoras: 12 pedestales

Cada mejora se compra **una vez**, con piedras, si tienes las que pide antes. Los efectos se suman entre sí (aditivo) y multiplican al resto.

`Config.Upgrades` (lista ordenada; `pos` = posición en studs respecto al centro del Jardín, X hacia la zona 1, Z hacia el sur):

| # | `id` | ES | EN | Efecto (`effect`, `value`) | `cost` 🪨 | `req` | `pos` (x, z) |
|---|---|---|---|---|---|---|---|
| 1 | `goldenroot` | Raíz Dorada | Golden Root | `coins` +0.25 (+25 % monedas) | 1 | — | (60, 0) |
| 2 | `swiftsprout` | Brote Veloz | Swift Sprout | `walk` +4 (andar 16 → 20) | 3 | goldenroot | (25, -45) |
| 3 | `buddybranch1` | Rama Compañera I | Buddy Branch I | `slots` +1 | 8 | goldenroot | (25, 0) |
| 4 | `thriftynest` | Nido Ahorrador | Thrifty Nest | `egg` −0.20 (huevos −20 %) | 5 | goldenroot | (25, 45) |
| 5 | `leafpouch` | Bolsa de Hojas | Leaf Pouch | `bag` +50 | 10 | swiftsprout | (-10, -70) |
| 6 | `mightysap` | Savia Fuerte | Mighty Sap | `power` +0.25 (+25 % poder) | 20 | buddybranch1 | (-10, 0) |
| 7 | `dewyhands` | Manos de Rocío | Dewy Hands | `hatch` −0.2 s (abrir 0,9 → 0,7 s) | 15 | thriftynest | (-10, 70) |
| 8 | `barkchest` | Baúl de Corteza | Bark Chest | `bag` +100 | 30 | leafpouch | (-45, -70) |
| 9 | `buddybranch2` | Rama Compañera II | Buddy Branch II | `slots` +1 | 40 | mightysap | (-45, -25) |
| 10 | `goldenrain` | Lluvia de Oro | Golden Rain | `coins` +0.50 | 50 | mightysap **y** thriftynest | (-45, 25) |
| 11 | `sparklebloom` | Flor Destello | Sparkle Bloom | `shiny` +0.5 (Brillante ×1,5) | 25 | dewyhands | (-45, 70) |
| 12 | `gardencrown` | Corona del Jardín | Garden Crown | `slots` +1 **y** `power` +0.5 | 100 | buddybranch2 **y** goldenrain **y** sparklebloom | (-80, 0) |

Total: **307 piedras**. Costes que suben (1 → 100) porque las Míticas salen cada vez más rápido (§10). La 1.ª cuesta 1: la primera Mítica
ya compra algo (momento importante).

**Lo que venía de renacer pasa aquí:** huecos 3 → +3 (Rama I, Rama II, Corona) = 6 (+3 con pase = 9, el mismo máximo que antes);
mochila 50 → +150 = 200 (+100 con pase).

Fórmulas nuevas (`Config`): `upgradeBonus(data, effect)` = suma de `value` de las compradas · `slots = SLOTS_BASE + upgradeBonus(slots) + pase` ·
`backpack = BACKPACK_BASE + upgradeBonus(bag) + pase` · `coinMult` × `(1 + upgradeBonus(coins))` · `teamPower` × `(1 + upgradeBonus(power))` ·
`eggCost(zone, data) = floor(Zones[zone].eggCost × (1 + upgradeBonus(egg)))` · `hatchCooldown(data) = HATCH_COOLDOWN (0.9) + upgradeBonus(hatch)` ·
`walkSpeed(data) = 16 + upgradeBonus(walk)` (el servidor pone `Humanoid.WalkSpeed` al cargar y al comprar).

Dibujo (visto desde arriba; la zona 1 está a la derecha, se entra por el hueco del muro):

```
                         z = -70        z = -45/-25     z = 0          z = +25/+45      z = +70
  x = +60                                               [1 Raíz]  ◄──── entrada desde la zona 1 (x = +100)
                                       ┌────────────────┼────────────────┐
  x = +25                         [2 Brote]        [3 Rama I]        [4 Nido]
                                  │                     │              │    ╲
  x = -10          [5 Bolsa]──────┘                [6 Savia]           [7 Manos]╲
                   │                          ┌─────────┼───────┐          │     ╲
  x = -45          [8 Baúl]          [9 Rama II]        │  [10 Lluvia]◄────┼──────(de 4 Nido)
                                              │         │       │      [11 Destello]
                                              └────┐    │   ┌───┘          │
  x = -80                                          [12 Corona]◄────────────┘
```

Caminos (`Config.UpgradeLinks` se deduce de `req`): 1-2, 1-3, 1-4, 2-5, 5-8, 3-6, 6-9, 6-10, 4-10, 4-7, 7-11, 9-12, 10-12, 11-12.

Acción `Actions.buyUpgrade(id)` (§11 para el ProximityPrompt): `id` string que existe en `Config.Upgrades` · no comprada · todas sus `req`
compradas · `d.stones >= cost` · jugador a ≤ `UPGRADE_REACH = 14` studs de **ese** pedestal (como el huevo) · límite general de 10/s.
Efecto: resta piedras, `d.upgrades[id] = true`, recalcula velocidad de andar, `syncPets`, `n_upgrade` («¡{name} comprada!» / «{name} unlocked!»).
Errores: `n_need_stones` («Te faltan {n} 🪨» / «You need {n} more 🪨»), `n_need_upgrade` («Antes compra {name}» / «Unlock {name} first»), `n_go_pedestal`.

## 9. Qué se quita y qué pasa con lo demás

| Se quita | Dónde |
|---|---|
| Acción `rebirth`, pestaña/pantalla Renacer, textos `n_rebirth*` y del menú | Main, Client, Lang |
| `REBIRTH_BONUS`, `REBIRTH_MIN_ZONE`, `REBIRTH_COST_MULT`, `REBIRTH_COST_GROWTH`, `SLOTS_REBIRTH`, `BACKPACK_PER_REBIRTH`, `rebirthZone()`, `rebirthCost()` | Config |
| `data.rebirths`, `stats.rebirths`, estado `rebirths / rebirthZone / rebirthCost`; leaderstats «Rebirths» → **«Índice»** (nº descubiertas) | Data, Main |
| `TIER_MULT`, `MAX_TIER`, `FUSE_COUNT`, campo `tier` de cada cría (Dorada/Arcoíris); `pets[i].tier` → `pets[i].shiny` (boolean) | Config, Main, Client, Mundo3D (atributo `Pets` pasa a `"kind:0|1"`, 1 = Brillante) |
| `doorCost` y su fórmula (`ZONE_GROWTH.doorCost`, `ZONE_BASE.doorCost`, `eggCost`, `petBase`) → tablas de §3 | Config |
| `Rarities[*].weight`, la «common» repetida, `LUCK_FROM_INDEX` | Config |

| Sistema | Qué pasa |
|---|---|
| **Álbum/Índice** | 72 entradas (clave `kind`). Hitos `AlbumMilestones` iguales (10/25/50/75/100 % → +5/10/15/20/50 % monedas) sobre 72. Bot: 10 % ≈ zona 2, 25 % ≈ zona 5, 50 % ≈ zona 8; 75–100 % piden Míticas de zonas viejas (zona 1 = 28.125 huevos): meta de semanas. Pestaña nueva «✨» o filtro: Índice Brillante (72 casillas más, solo para la puntuación) |
| **Misiones** | `fused`: medium 1 → **5**, hard 4 → **25** (§4). El resto igual. «🍀 suerte x2» = Brillante ×2 (§5) |
| **Montón Dorado, diaria, offline, tutorial** | Igual. El paso del tutorial de «junta 5 iguales para una Dorada» → «junta 5 iguales en el altar para subir de rareza» |
| **Tienda** | Igual (pases y productos con id = 0). Nada nuevo. «Abrir x3» y «Auto-abrir» siguen; ojo: abrir x3 respeta `hatchCooldown` |
| **Datos** | DataStore `MythicHatchlings_v2` (juego sin publicar: solo se pierden partidas de prueba). `newData()`: quitar `rebirths`; `pets = {{uid=1, kind="sproutchick", shiny=false}}`; `album = {sproutchick=true}`; **nuevos** `shinyIndex = {}` (kind=true), `stones = 0` (number), `upgrades = {}` (id=true), `stats.mythics = 0`, `stats.shinies = 0`. Sin migración |
| **Estado al cliente** (nuevos) | `stones`, `upgrades`, `shinyScore`, `shinyIndex`, `albumCount`, `albumTotal = 72`, `nextZone = { zone, needDiscovered | needShiny, have }`, `hatchCooldown`, `walkSpeed`; cada cría lleva `shiny` |

---

# Ritmo

## 10. Ritmo objetivo (bot) y cuenta

Simulador en Python aparte (lógica copiada de `ritmo.luau`: el bot pica en su mejor zona, abre el huevo más alto que puede pagar, «Fusionar todo»,
equipa lo mejor, abre puerta en cuanto cumple, compra mejoras en cuanto puede; 10 partidas; sin Montón Dorado ni pases; persona ≈ ×2).

| Hito | Bot (mediana, mín–máx) | Persona ≈ ×2 | Objetivo |
|---|---|---|---|
| 1.er huevo | 0:45 | ~1:30 | < 1 min bot ✔ |
| 1.ª Poco común (1.ª fusión) | 1:37 | ~3 min | — |
| 1.ª Brillante | 8 min (3–29) | ~15 min | sorpresa en la 1.ª sesión (≈ 50 %) |
| **Zona 2** | **3:53** | ~8 min | ~4 min bot |
| Zona 3 | 9:56 | ~20 min | ~10 |
| Zona 4 | 19:56 | ~40 min | ~20 |
| **Zona 5** | **35:31** | ~1 h 10 | ~35 |
| Zona 6 | 55:21 | ~1 h 50 | ~55 |
| Zona 7 | 80:16 | ~2 h 40 | ~80 |
| **Zona 8** | **1 h 50** (1 h 47–1 h 50) | ~3 h 40 (2–4 días) | ~110 min |
| **1.ª Mítica = 1.ª piedra** (Raíz Dorada) | **2 h 10** (2 h 07–2 h 11) | ~4 h 20 | ~130 min |
| 5 / 20 / 50 Míticas | 2 h 18 / 2 h 36 / 3 h 03 | — | — |
| Rama Compañera I (8 🪨) · Savia (20) | 2 h 34 · 3 h 14 | — | — |
| **✨ 200 Brillante = zona 9** | **3 h 39** (3 h 19–3 h 49) | ~7 h 20 (1–2 semanas) | ~3,5–5 h bot |
| Árbol completo (307 🪨) | 4 h 05 (3 h 47–4 h 13) | ~8 h | — |

Cuenta a mano de los primeros minutos (comprueba el simulador): ingreso = poder × monedas por vida × 0,75. Zona 1: monedas por vida =
6/12 = 0,5. Starter = 3 de poder → 3 × 0,5 × 0,75 = **1,125 monedas/s** → huevo de 50 a los 50/1,125 = **44 s** ✔. Con 3 Comunes equipadas:
9 × 0,375 = 3,4/s → cada huevo ~15 s; la 5.ª Común (4 huevos) da la Poco común a ~1:37 ✔. Para la Rara hacen falta 25 Comunes = 24 huevos
= 1.200 monedas; con un ingreso medio de ~5/s son ~4 min → puerta 2 a las ~3:53 ✔.
Entrada a cada zona (bot, partida 1): z2 ingreso 25/s y huevo 1.100 (44 s/huevo) · z3 2.540/s y 300K (2 min/huevo al principio, luego
baja) · z5 6,1M/s y 1,4B · z8 1,3e11/s y 28T (≈ 3,6 min/huevo al entrar). Mítica de la zona 8 = 45 Legendarias.

Cómo lo mide Leo: `ritmo.luau` adaptado (fusionar todo, puertas por Índice/Brillante, piedras, compra de mejoras) con hitos «zona N», «1.ª Mítica»,
«1.ª piedra», «árbol: <id>», «Brillante 200», «zona 9». **Aceptación de ritmo:** mediana de 10 partidas con zona 2 en 3–6 min, zona 5 en 30–45,
zona 8 en 1 h 30–2 h 15, 1.ª piedra en 1 h 50–2 h 40, zona 9 en 3–5 h. Si sale fuera, se toca solo `eggCost` (tabla §3) y se re-mide.

---

# PARTE B — Mundo (ronda Leo-2b)

## 11. Jardín, zona 9, altares y huevo 3D

**Jardín de Mejoras** (celda (-1,0), centro `(-200, TOP, 0)`, 200×200):
- No es una zona de `Config.Zones` (no tiene huevo ni cristales). Lo construye `World.buildGarden()`. `World.GRID` no cambia para él; la zona 9 se
  añade como `{ 2, 2 }` al final (es vecina de la 8 en (1,2) → la pared 8|9 sale con puerta sola porque 9 = 8 + 1; la pared 4|9 queda de acantilado).
- Muro oeste de la zona 1 (x = −100): hoy es acantilado entero (no hay zona en (-1,0)) → abrir un hueco de `World.GATE` (28) **sin puerta**, con dos
  columnas y un arco de hojas y el cartel «🌳 Jardín de Mejoras / Upgrade Garden». Los otros 3 lados del Jardín: acantilado.
- Suelo de césped más oscuro (`Color3.fromRGB(80, 170, 90)`, Grass), algunos árboles/flores del pack Kenney en los bordes (sin tapar caminos).
- **12 pedestales** en `pos` (§8): cilindro de piedra de pie (diámetro 10, alto 3; recuerda: girar 90° en Z), encima un **orbe** (Ball 4, Neon)
  y un **cartel flotante** (BillboardGui a 9 studs, `MaxDistance` 80): nombre, efecto y «🪨 20» / «✅ Comprada» / «🔒 Antes: Savia Fuerte».
  Tag `Upgrade`, atributo `UpgradeId`.
- **Colores por jugador** (cada cliente pinta lo suyo, como las puertas): orbe y anillo del pedestal **verde neón** (34,197,94) = comprada ·
  **amarillo** (250,204,21) con pulso = se puede comprar ya · **gris** (100,116,139, SmoothPlastic, sin neón) = bloqueada.
- **Caminos de neón** entre pedestales (`UpgradeLinks`): losas Neon de 3 de ancho y 0,3 de alto, un poco por encima del suelo, rectas de centro a
  centro (el 4-10 es diagonal). **Verde** si los dos extremos están comprados; **gris** si no. Tag `UpgradeLink`, atributos `From`, `To`.
- **ProximityPrompt** en cada pedestal (`MaxActivationDistance = 12`, `HoldDuration = 0.5`, `RequiresLineOfSight = false`): el servidor
  conecta `Triggered` → llama a la misma `buyUpgrade` (mismas validaciones). El cliente cambia el `ActionText` localmente («Comprar (🪨 20)» /
  «Comprada» / «Bloqueada»; EN «Unlock (🪨 20)» / «Owned» / «Locked»). El bot llama `buyUpgrade` directamente.
- Contador grande de piedras en el Jardín (cartel en la entrada: «🪨 Tienes 12») y en el HUD cuando `stones > 0`.
- Teletransporte: `Actions.teleport(0)` = Jardín (siempre permitido). Menú Islas: botón «🌳 Jardín» arriba del todo.

**Zona 9 · Santuario Aurora** (celda (2,2)): `THEMES[9]` = suelo `Color3.fromRGB(40, 60, 80)`, material Slate; roca 30,40,60; deco «aurora»:
piedras y árboles pintados en turquesa/rosa, algunos cristales grandes de adorno. `crystalColors` = (90,240,200), (255,120,220), (120,170,255),
(200,140,255). Puerta en la pared 8|9 con cartel «✨ 143/200» (§6). Huevo Prodigioso magenta en su pilar.

**Altares de fusión** (2): «Altar de Fusión / Fusion Altar».
- Zona 1 a ~20 studs del spawn (sin tapar el huevo), y Jardín en (70, -60). Pieza: plataforma redonda de piedra (diámetro 14) + caldero/anillo
  Neon morado girando (en el cliente) + cartel «✨ Fusionar» . Tag `FuseStation`.
- ProximityPrompt «Fusionar» (`MaxActivationDistance = 12`): **en el cliente** (`ProximityPromptService.PromptTriggered`) abre la pantalla de
  fusión. Esa pantalla: lista por zona y rareza con «4/5», botón grande **«Fusionar todo»** (ES) / **«Fuse all»** (EN) y botón pequeño por grupo.
  Móvil: el botón «Fusionar todo» abajo a la derecha, mínimo 56 px de alto (Vega).
- Validación del servidor (**según la respuesta del usuario, §12 pregunta 1**): opción recomendada A = `fuse`/`fuseAll` solo si el jugador está a ≤
  `FUSE_REACH = 20` de algún `FuseStation` (error `n_go_altar`: «Ve a un Altar de Fusión (zona 1 o Jardín)» / «Go to a Fusion Altar (Island 1 or Garden)»),
  y la pantalla tiene un botón «🌀 Ir al altar» que teletransporta al Jardín. Opción B = se fusiona en cualquier sitio y el altar es solo el atajo.

**Huevo 3D por rareza** (`tools/modelos/construir_pack.py` y versión de piezas):
- Pack: **ya existe** el modelo «Huevo» en `construir_pack.py` (`huevo()`: cáscara + 7 manchas, materiales `eggShell` / `eggSpots`; lo vi al
  cerrar la ficha, lo hizo Leo-1). Falta solo que `World.place` pinte `Huevo__eggShell` con `EggColors[r].shell` y `Huevo__eggSpots` con
  `EggColors[r].spots` según `Zones[i].eggRarity`; con el pack, `spotCount` no se usa (salen las 7). Modelos en `ReplicatedStorage.Modelos` (o ServerStorage).
- Sin modelos (piezas): Ball 7×9×7 SmoothPlastic con `shell` + `spotCount` bolas pequeñas (diámetro 1,2–2,2) medio hundidas en la superficie con
  `spots` (posición fija por semilla para que no cambie al reiniciar). Épica+: `PointLight` (`glow`); Legendaria/Prodigiosa: Material Glass encima o
  Neon en las manchas. Sigue con atributo `Zone` y tag `Egg`.
- Cartel del huevo: nombre de la zona, rareza («Huevo Épico» / «Epic Egg»), precio y probabilidades (§3).

**Crías 3D** (los 17 Quaternius ya van en el pack; cuando el usuario lo importe a `ReplicatedStorage.Modelos`): `model` de cada cría; escala = `Rarities[r].size`; pintar con
`color` (y un poco más claro el vientre si el modelo tiene 2 materiales); aura `Highlight` o `ParticleEmitter` desde Épica con el color de la rareza;
Brillante = `ParticleEmitter` «Sparkles» blanco. Sin modelo → bola + emoji como hoy.

**Pruebas del bot** (para `run_juego.luau`): abrir hasta Rara → fusionar (5→1) y «fusionar todo» · fusión con equipadas (vuelve a equipar lo mejor)
· no fusionar Brillante con normal · `unlockZone` falla sin Índice y funciona con él · zona 9 falla con 199 y funciona con 200 (forzar `shinyIndex`) ·
crear Mítica (forzar 3 Ascendidas) → `stones == 1` · `buyUpgrade` falla sin piedras, sin requisito, lejos del pedestal y funciona cerca; el 2.º intento de
la misma falla · `slots`/`backpack`/`walkSpeed` suben · `rebirth` ya no existe (devuelve false) · guardar/cargar `stones/upgrades/shinyIndex` ·
mundo: 12 pedestales, 14 caminos, 2 altares, hueco del Jardín en el muro de la zona 1, puerta 8|9, 9 huevos con su color.

## 12. Riesgos, lo que no se puede probar sin Studio y preguntas

**Pre-mortem («dentro de un mes no ha funcionado, ¿por qué?»):**
1. *«Los huevos aburren»*: casi todos dan siempre lo mismo (zonas 1–2: 1 especie). → El gran momento pasa a «cría nueva» y «Brillante»; la barra
   «4/5 para la siguiente» se ve en el HUD tras cada apertura; «Fusionar todo» da el subidón.
2. *«El árbol llega tarde»*: la 1.ª piedra a las ~4 h de una persona (lo decidió la regla del usuario: 1 por Mítica). → El Jardín está abierto desde el
   minuto 1 junto al spawn con los 12 pedestales grises y «Consigue una Mítica» (meta larga a la vista). Si el usuario lo quiere antes: bajar `eggCost` de
   las zonas 6–8 o `needDiscovered` (no tocar la regla de la piedra).
3. *«Al final sobran piedras»* (zona 9 = cientos/h). → Aceptado en la versión mínima; ampliación: segundo anillo de pedestales o mejoras repetibles.
4. *«La mochila se llena de Míticas»* (el bot hace cientos): hay que soltarlas. → Ampliación pequeña: «Soltar repetidas» por grupo. En la mínima, el
   aviso de mochila llena ya dice «suelta o fusiona».
5. *«Números gigantes ilegibles»* (1Qa): el formato ya abrevia; añadir `Sx, Sp`.

**Normas (CLAUDE.md §11):** el huevo es aleatorio (especie y Brillante) pero **no se paga con Robux** ✔; probabilidades en cada huevo ✔; piedras,
mejoras y suerte solo jugando ✔. Sigue la nota vieja: si se crean los packs de monedas, los huevos se pagarían indirectamente con Robux → revisar el
cuestionario antes de crearlos.

**No se puede probar aquí (sin Studio):** que los caminos de neón y los carteles se lean bien desde lejos y en móvil; que el ProximityPrompt salga a la
distancia correcta y no se solape con los vecinos (pedestales a ≥ 35 studs, prompts a 12); que los modelos Quaternius se vean bien escalados ×2,2; las
luces de los huevos de noche; el rendimiento con 8 jugadores × 6–9 crías con partículas. Lune no simula `ProximityPrompt.Triggered` (el harness llama a la
acción directamente).

**Preguntas para el usuario (máx. 2):**
1. ¿Fusionar **solo en el Altar** (A, recomendado: es «el sitio» que pediste; desde cualquier isla hay botón para ir) o **en cualquier sitio** (B, el altar es solo bonito)?
2. ¿La 1.ª piedra a las ~4 h de juego te parece bien (A) o la quieres antes, hacia la zona 6 (~2 h) (B: abarato los huevos de las zonas 6–8)?

**Supuestos (≈):** ritmo de persona = bot × 2 (sin medir con personas); el simulador Python no incluye Montón Dorado (≈ −5 % de tiempo), andar ni
menús; las cifras de Leo-1 (×17,5 / ×7) pueden cambiar → re-calibrar `eggCost`.
