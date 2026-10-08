# ⚔️ Dungeon Ascend (v0.3) — juego de hordas estilo "survivors" medieval

Juego de Roblox inspirado en el género de **Survive the Swarm** y **Final Swarm** (y Vampire
Survivors). Copia la mecánica, no los nombres, dibujos ni la interfaz de esos juegos:
**tú solo te mueves y esquivas; tus armas atacan solas** contra oleadas de cientos de
enemigos. Subes de nivel, eliges mejoras, vences al jefe y **escapas por el portal**.
Con las **Coronas** (la moneda del juego) te haces más fuerte para la siguiente partida.

## Cómo es una partida (7–10 minutos)

1. En el lobby pulsas **JUGAR** (o te acercas a un portal), eliges **mapa y dificultad**
   (Normal → Difícil → Pesadilla; cada una se abre al superar la anterior en ese mapa) y
   juegas **solo** o creas un **grupo de hasta 4** con amigos.
2. Llegan **oleadas** de enemigos (10, 11 o 12 según el mapa). Entre oleadas hay unos
   segundos de respiro y los cristales vuelan solos hacia ti. A veces sale un **élite** que suelta un cofre.
3. Los enemigos sueltan **cristales morados**. Al subir de nivel eliges **1 de 3 mejoras**
   (4 con el pase) mientras tus enemigos van en **cámara lenta**. Cada carta lleva su imagen:
   - **Armas** (máx. 4): Espada · Varita mágica · Dagas (las 3 de inicio) y, si las sacas del
     cofre de armas: Aura sagrada · Orbes · Hacha arrojadiza · Bomba de fuego · Relámpago · Martillo sísmico
   - **Mejoras pasivas** (máx. 4): Fuerza, Rapidez, Área, Vida, Botas, Imán, Armadura, Regeneración
   - **Evoluciones**: arma al nivel 5 + su pasiva pareja → arma legendaria (Hoja del Rey,
     Hachas del Berserker, Lluvia de Meteoritos, Martillo de los Titanes…)
4. En la **última oleada** llega el **jefe**. Pinta un **círculo rojo** antes de su golpe: ¡apártate!
5. Al vencerlo se abre un **portal**: entra en menos de 60 s para **escapar con todas las Coronas +50 %**.
   Si caes o abandonas te quedas **la mitad**.

## El mundo (medieval)

- **Lobby en una isla**: hierba animada, playa, lago con olas y montañas nevadas alrededor.
  Al norte, sobre el lago, un **castillo grande** con torres de tejado cónico, banderas,
  torre del homenaje y un **puente de piedra** con farolas. Plaza con fuente y estatua del
  héroe, **terraza con los 3 portales**, **aldea** con **taberna**, **cabañas de paja** con
  chimeneas que echan humo, **pozo** y huertos, **forja**, **mercado**, campo de
  entrenamiento, campamento con hoguera, estanque con muelle y bosquecillos.
- **Arenas** con bordes naturales y luz propia (solo cambia en tu pantalla):
  🌲 Bosque soleado con **cabañas de leñador** · 💎 Cueva-**mina** con entibados de madera,
  farolillos, vías y vagonetas de mineral · 🏰 Castillo al atardecer con murallas, torres,
  braseros, cementerio y grietas de lava.

> Si en Studio no ves la hierba "con pelitos": pestaña **Terrain** (Editor de terreno) → ⚙️ y
> activa **Decoration**. El juego intenta activarla solo, pero Roblox a veces no lo permite por script.

## Fuera de la partida (lobby)

| Pestaña | Qué hay |
|---|---|
| Jugar | Mapas (Bosque → Cueva → Castillo, se desbloquean escapando), dificultad, jugar solo, grupos |
| Clases | Guerrero (gratis), Mago (2.000 Coronas), Pícaro (5.000 Coronas), cada una con su arma inicial |
| Árbol | **Árbol de mejoras en una sola página**: 3 ramas (Ataque, Defensa, Fortuna), 24 nodos; cada uno se abre al comprar el anterior |
| Armas | **Cofre de armas**: te da un arma nueva que aún no tienes (probabilidades a la vista) y la colección de las 9 armas |
| Mochila | Objetos que dan % de daño, vida o % de Coronas (salen del cofre del jefe y de los cofres de la forja) |
| Forja | Mejorar objetos hasta +10 y cofres que se pagan con **Coronas** (probabilidades a la vista) |
| 🛒 Tienda | Pases y productos con Robux (ver abajo) |
| 🎁 Diario | Recompensa diaria con racha de 7 días |

**Controles:** moverse (WASD o joystick) · **Q / Shift / botón 💨** = esquivar (te hace invulnerable un instante) ·
**1-4** = elegir mejora · **F** = usar portales y carteles del lobby.

## Cómo probarlo en Roblox Studio

1. Descarga el lugar:
   **https://github.com/candhu23/mi-priemra-web/raw/claude/dungeon-ascend/roblox-dungeon/DungeonAscend.rbxl**
2. Ábrelo con doble clic (se abre en Roblox Studio).
3. Pulsa **▶ Play**.
   - Para probar el **grupo** sin amigos: pestaña **Test** → **Clients and Servers** → 2 jugadores → **Start**.

> ⚠️ En Studio sin publicar saldrá un aviso rojo: «Guardado desactivado». Es normal.

## Cómo publicarlo como juego NUEVO

> ❗ **No lo publiques encima de Web Empire Tycoon.** Es otro juego.

1. En Studio: **File → Publish to Roblox As… → Create new experience**. Nombre: **Dungeon Ascend**.
2. Descripción en inglés, por ejemplo:
   *"Survive the endless horde! Your weapons attack automatically — dodge, level up, pick upgrades,
   evolve your weapons, beat the boss and escape through the portal. Play solo or with up to 4 friends!"*
3. En el **Creator Hub** (create.roblox.com → tu experiencia):
   - **Places → Max Players: 8.**
   - **Settings → Security → Enable Studio Access to API Services** (para guardar al probar en Studio).
   - Cuestionario de contenido: en **violencia** marca **leve / no realista** (armas mágicas contra
     monstruos de bloques que desaparecen, sin sangre). El resto (sangre, miedo, palabrotas…): **"No"**.
     En "artículos aleatorios de pago": **"No"** (los cofres se pagan con Coronas del juego, no con Robux).

## Tienda (Robux): pendiente de que crees los artículos

Ahora la tienda dice «abrirá pronto». Para activarla, en el Creator Hub → **Monetization**:

| Tipo | Artículo | Precio sugerido |
|---|---|---|
| Pase | 👑 x2 Coronas | 149 |
| Pase | 🃏 4 opciones al subir de nivel | 199 |
| Pase | 🎲 Rerolls +3 (cambiar las mejoras ofrecidas) | 99 |
| Pase | 🎒 Mochila grande (+40 huecos) | 49 |
| Producto | 💰 Bolsa de Coronas (20 min) | 25 |
| Producto | 🏆 Cofre de Coronas (2 h) | 99 |
| Producto | 🚀 Boost x2 Coronas (15 min) | 39 |
| Producto | 💖 Revivir (vuelves a la partida) | 15 |

Mándame los **números de ID** de cada uno y los pongo en el juego.

## Para Claude (verificación)

```bash
cd roblox-dungeon && tools/check.sh
```

Compila, analiza tipos con la API de Roblox, ejecuta el servidor y la interfaz reales con Lune,
juega partidas completas con bots para medir el equilibrio y genera `DungeonAscend.rbxl`.
Ver `CLAUDE.md`.
