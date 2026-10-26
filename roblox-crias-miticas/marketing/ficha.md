# Ficha del juego — Mythic Hatchlings (Crías Míticas) · v0.4

> Para pegar en Creator Hub → la experiencia → **Configure** (inglés = idioma principal) y en
> **Localization → Game Information → Spanish** (versión en español). Todo lo que dice existe en la v0.4
> (números sacados de `src/ReplicatedStorage/Config.luau` y `Lang.luau`, 2026-10-26).
> Ya **no** existen (no los menciones nunca): Renacer/Rebirth como reinicio, crías Doradas/Arcoíris, puertas que cuestan monedas.

## Título

| | Texto | Por qué |
|---|---|---|
| **EN (principal)** | `Mythic Hatchlings: Hatch & Fuse Pets` | Nombre propio + las 2 acciones del juego. «Hatch» y «Pets» son lo que la gente busca; «Fuse» dice qué lo hace distinto. 36 caracteres (límite 50). |
| **ES** | `Crías Míticas: Abre Huevos y Fusiona` | Mismo esquema en español. 36 caracteres. |

Sin emojis en el título (≈ Roblox limita símbolos en títulos; no lo he comprobado hoy). Nunca: «Free», «UPDATE» falso, «x1000» ni el nombre de otro juego.

## Descripción EN (≤ 1.000 caracteres)

```
Hatch eggs and collect 72 pets that follow you and break crystals for coins! 🐣
Fuse 5 alike to rank them up all the way to Mythic, earn Rebirth Stones and grow your Upgrade Garden.

🥚 9 islands, 72 pets, 8 rarities: Common → Uncommon → Rare → Epic → Legendary → Prodigious → Ascended → Mythic
🌀 Fusion Altar: 5 alike from one island → the next rarity (3 from Prodigious)
🪨 Every Mythic you create = 1 Rebirth Stone
🌳 Upgrade Garden: 12 upgrades on glowing pedestals (more coins, more pets equipped, faster hatching…)
📖 Discover pets in the Index to open new islands
✨ 1% Shiny pets (x2 power). Reach 200 Shiny score to open island 9: Aurora Sanctuary
🌟 A Golden Crystal appears every 3 minutes
🎯 3 daily missions + 7-day reward streak
👥 +10% coins for each friend in your server (up to 4)
🌍 English & Español

Eggs are bought with in-game coins and show their odds. Stones and upgrades are earned only by playing.
```

## Descripción ES

```
¡Abre huevos y colecciona 72 crías que te siguen y rompen cristales para darte monedas! 🐣
Fusiona 5 iguales para subirlas de rareza hasta Mítica, gana Piedras de Renacimiento y haz crecer tu Jardín de Mejoras.

🥚 9 islas, 72 crías y 8 rarezas: Común → Poco común → Rara → Épica → Legendaria → Prodigiosa → Ascendida → Mítica
🌀 Altar de Fusión: 5 iguales de una isla → la rareza siguiente (3 desde Prodigiosa)
🪨 Cada Mítica que creas = 1 Piedra de Renacimiento
🌳 Jardín de Mejoras: 12 mejoras en pedestales (más monedas, más crías equipadas, abrir más rápido…)
📖 Descubre crías en el Álbum para abrir islas nuevas
✨ Brillantes al 1 % (poder x2). Con 200 de puntuación Brillante se abre la isla 9: Santuario Aurora
🌟 Cada 3 minutos aparece un Cristal Dorado
🎯 3 misiones diarias + racha diaria de 7 días
👥 +10 % de monedas por cada amigo en tu servidor (máx. 4)
🌍 English y Español

Los huevos se compran con monedas del juego y muestran sus probabilidades. Piedras y mejoras solo se ganan jugando.
```

(Las notas de la versión van aparte: `notas-v0.4.md`. Si quieres, pégalas debajo de la descripción.)

### Por qué estas frases
- **Línea 1** = qué haces + la gracia (las crías trabajan por ti). En el móvil es casi lo único que se lee.
- **Línea 2** = la meta larga en orden real: fusión → Mítica → piedras → Jardín. Es lo que hace volver.
- La cadena de 8 rarezas escrita entera: enseña que hay mucho camino sin prometer tiempos.
- «Los huevos… muestran sus probabilidades» y «piedras y mejoras solo se ganan jugando» dan confianza a padres y jugadores
  y son verdad (la tienda solo tiene pases; ver abajo).
- **No** digo cuánto se tarda en la 1.ª Mítica: según el bot ≈ 2 h, una persona ≈ 4 h (DISENO.md §5). Prometer «rápido» sería engañoso.
- No nombra ningún otro juego ni menciona pases o precios: la ficha vende el juego.

## Ajustes recomendados (Creator Hub)

| Ajuste | Valor |
|---|---|
| Género | **Simulation** (≈ es donde Roblox pone los juegos de mascotas/coleccionar) |
| Dispositivos | Todos. Interfaz probada con capturas en PC y móvil; consola **sin probar** |
| Max Players | **8** (islas compartidas; manda el valor que ya tenga el lugar) |
| Cuestionario de contenido | Todo «No». Artículos aleatorios de pago: **No**, siempre que solo se creen los **5 pases** |
| Idioma principal | English; añadir traducción Spanish en Localization |
| Icono | `docs/arte/icono_juego.png` (sigue valiendo: huevo + «HATCH!») |
| Miniaturas | Ver aviso ⚠️ abajo |

### ⚠️ Monetización: solo pases
- Pases (`Config.GamePasses`): Monedas x2, +3 huecos, Abrir x3, Auto-abrir, Mochila +100. Ninguno da huevos, suerte, piedras ni mejoras.
- En `Config.Products` siguen los packs de monedas y el boost (`cash_s`, `cash_l`, `boost`, con `id = 0` = no se venden).
  **No los crees**: con monedas compradas se podrían pagar huevos (aleatorios) con Robux y la respuesta del cuestionario
  dejaría de ser «No». Si algún día se crean, hay que cambiar esta ficha y el cuestionario.

### ⚠️ Miniaturas: la 2 está desfasada
- `docs/arte/miniatura_2.png` dice **«56 PETS · 8 ISLANDS · Fuse 5 → Golden → Rainbow»**: ya no es verdad. **No la subas.**
- `docs/arte/miniatura_1.png` («Hatch eggs · Pets farm coins for you») sigue siendo correcta.
- Propuesta para rehacer la 2 (lo hace quien pueda tocar `docs/arte/encargo.json`, con la skill `arte-roblox`):
  título `72 PETS\n9 ISLANDS`, subtítulo `Fuse 5 → … → MYTHIC 🌀`, emoji `🪨` o `🌳`.
  Mejor aún: una **captura real** del Jardín de Mejoras con los caminos de neón encendidos (ver `plan.md`, semana 0).

## Palabras clave (para vídeos, grupo y Discord; Roblox no tiene campo de etiquetas libre)

EN: `pet game`, `hatch eggs`, `fuse pets`, `collect pets`, `mythic pets`, `shiny pets`, `upgrade tree`, `roblox pets`
ES: `abrir huevos`, `fusionar mascotas`, `coleccionar mascotas`, `mascotas míticas`, `mascotas brillantes`, `juego de mascotas roblox`
Hashtags: `#roblox #robloxpets #hatching #mythichatchlings #robloxgame` (ES: `#robloxespañol`)
