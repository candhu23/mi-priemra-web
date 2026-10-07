# ⚔️ Dungeon Ascend (v0.1)

Juego de Roblox de mazmorras: subes de nivel, consigues botín, lo mejoras en la forja
y vences al jefe de cada zona para desbloquear la siguiente, con enemigos más fuertes.
Cooperativo: todos los jugadores del servidor comparten las zonas.

## Qué incluye esta versión

| Sistema | Detalle |
|---|---|
| **Ciudad** | Plaza con zona de aparición, 3 portales, forja, tienda y clasificación de los mejores aventureros |
| **3 zonas** | 🌲 Bosque Encantado (nivel 1) → 💎 Cueva de Cristal (nivel 15) → 🏰 Castillo Maldito (nivel 30) |
| **Enemigos** | 3 tipos por zona (12 en total por zona) que te persiguen, atacan, vuelven a su sitio y reaparecen |
| **Jefes** | Rey Goblin, Gólem de Cristal y Señor Lich. Dan un golpe de área con **aviso rojo en el suelo**: ¡apártate! |
| **Habilidades** | ⚔️ Atacar (clic) · 🌀 Torbellino (Q, nivel 3) · 💨 Embestida (E, nivel 6) · 💚 Curación (R, nivel 10) |
| **Nivel** | Del 1 al 100. Cada nivel da más vida y daño |
| **Equipo** | Arma, armadura y amuleto. 5 rarezas (Común → Legendario) con **probabilidades a la vista** |
| **Forja** | Mejoras de +1 a +10 con oro (sin probabilidad de fallo) y cofres que se pagan con oro |
| **Otros** | Tutorial, recompensa diaria (racha de 7 días), +10 % por cada amigo en el servidor, venta automática de objetos comunes |

**Controles en PC:** clic = atacar · Q, E, R = habilidades (también 1-4) · F = usar portales y carteles.
**En móvil o tablet:** botones de abajo.

## Cómo probarlo en Roblox Studio

1. Descarga el lugar:
   **https://github.com/candhu23/mi-priemra-web/raw/claude/dungeon-ascend/roblox-dungeon/DungeonAscend.rbxl**
2. Ábrelo con doble clic (se abre en Roblox Studio).
3. Pulsa **▶ Play** (arriba) para probarlo.

> ⚠️ En Studio, sin publicar, saldrá un aviso rojo: «Guardado desactivado». Es normal.
> El progreso solo se guarda cuando el juego está publicado y tiene activado *Enable Studio Access to API Services*.

## Cómo publicarlo como juego NUEVO

> ❗ **No lo publiques encima de Web Empire Tycoon.** Este es otro juego.

1. Con el archivo abierto en Studio: **File → Publish to Roblox As…**
2. Elige **Create new experience**, no un juego que ya exista.
3. Nombre: **Dungeon Ascend**. Descripción en inglés, por ejemplo:
   *"Fight monsters, level up, collect epic loot and defeat the bosses to unlock new dungeons! Play with friends!"*
4. Luego, en el **Creator Hub** (create.roblox.com → tu experiencia):
   - **Places → Max Players: 12** (las zonas son compartidas y caben bien 12).
   - **Settings → Security → Enable Studio Access to API Services** (para guardar al probar en Studio).
   - Rellena el cuestionario de contenido. Aquí, a diferencia del tycoon, **sí hay combate**:
     en **violencia** marca la opción **leve / no realista** (espadas contra monstruos de bloques
     que desaparecen, sin sangre). Si dudas entre dos opciones, elige la más prudente.
     El resto (sangre, miedo, humor grosero, palabrotas…): **"No"**.
     En "artículos aleatorios de pago" responde **"No"**: los cofres se pagan con oro del juego, no con Robux.

## Tienda (Robux): pendiente de que crees los artículos

Ahora mismo la tienda dice «abrirá pronto», porque los artículos no existen todavía en Roblox.
Cuando quieras activarla:

1. En el Creator Hub → tu experiencia → **Monetization**:
   - **Passes**: crea estos 4 (puedes cambiar el precio):

     | Pase | Precio sugerido |
     |---|---|
     | 🪙 x2 Oro | 149 |
     | ⭐ x2 XP | 149 |
     | 🤖 Auto-ataque | 99 |
     | 🎒 Mochila grande (+40 huecos) | 49 |

   - **Developer Products**: crea estos 4:

     | Producto | Precio sugerido |
     |---|---|
     | 💰 Bolsa de oro (oro de 20 min) | 25 |
     | 🏆 Cofre de oro (oro de 2 h) | 99 |
     | 🚀 Boost x2 de oro y XP (15 min) | 39 |
     | 💖 Revivir aquí | 15 |

2. Mándame los **números de ID** de cada uno (salen en la página de cada artículo) y yo los pongo en el juego.

## Para Claude (verificación)

```bash
cd roblox-dungeon && tools/check.sh
```

Compila, analiza tipos con la API de Roblox, ejecuta el servidor y la interfaz reales con Lune,
simula la economía y genera `DungeonAscend.rbxl`. Ver `CLAUDE.md`.
