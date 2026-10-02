# 🚀 Guía de lanzamiento — Steal an Alien

Sigue los pasos en orden. Todo lo que dice "Creator Hub" se hace en <https://create.roblox.com/dashboard/creations>.
Tiempo estimado: 2-3 horas la primera vez, sin contar la espera de verificaciones.

---

## Paso 0 · Requisitos de tu cuenta (hazlo primero, puede tardar)

Según la documentación oficial de Roblox (octubre 2026):

| Para llegar a… | Necesitas |
|---|---|
| Jugadores de **16+** (al principio, todos los juegos nuevos) | Cuenta con 2+ días de antigüedad y buena reputación · **comprobación de edad** (selfie de estimación facial o DNI) · cuestionario de madurez completado |
| **Todas las edades** (Roblox Kids 5-8 y Select 9-15) | Lo anterior **+ verificación con documento de identidad** (eres mayor de 18) · **verificación en 2 pasos (2FA)** · **Roblox Plus/Premium durante 2 meses seguidos *o* pagar 1.000 Robux reembolsables** · superar la evaluación: **250 partidas de "jugadores muy comprometidos"** con edad comprobada en 60 días |

👉 Haz ya: verificación con DNI + activar 2FA (Configuración → Seguridad).
👉 Los 1.000 Robux de la cuota se devuelven si el juego aguanta 60 días con 25 jugadores comprometidos.
👉 Tu progreso hacia "todas las edades" se ve en el panel **Audience Reach** del Creator Hub.

> Importante: mientras no superes la evaluación, **solo te verán jugadores de 16+**. Es normal; hay que conseguir esas 250 partidas (amigos, comunidad, anuncios con el objetivo "Engagement").

---

## Paso 1 · Abrir y probar el juego en Roblox Studio

1. Descarga `build/StealAnAlien.rbxlx` y ábrelo con **Roblox Studio** (doble clic o *File → Open from File*).
   - Si cambias el código y usas Rojo: `rojo build default.project.json -o build/StealAnAlien.rbxlx`.
2. *Home → Game Settings → Security*: activa **Enable Studio Access to API Services** (para probar el guardado). El guardado solo funciona cuando el juego ya está publicado (paso 2): antes de publicar, el juego avisa de que juegas sin guardar, y es normal.
3. Pulsa **Play** (F5) y comprueba:
   - [ ] Apareces en tu base y sale el rayo del tutorial hacia la cinta.
   - [ ] Puedes comprar un alien (mantén **E**) y aparece en tu pedestal flotando.
   - [ ] La placa verde suma dinero al pisarla y la roja cierra la base.
   - [ ] El marcador de abajo muestra dinero e ingresos.
   - [ ] Los menús SHOP, INDEX/ODDS, CODES e INVITE se abren.
   - [ ] Escribe el código `RELEASE` en CODES.
4. **Comandos de prueba en el chat (solo en Studio):** `/cash 1000000`, `/luck`, `/meteors`, `/rebirths 3`.
5. Prueba con **2 jugadores**: pestaña *Test → Clients and Servers → 2 Players → Start*.
   - [ ] Con un jugador, roba un alien del otro (mantén **E** sobre su alien) y llévalo a tu base.
   - [ ] Con el otro, usa **Slap** (herramienta, tecla 1 y clic) sobre el ladrón: el alien vuelve a casa.
   - [ ] Con la base cerrada no se puede robar y la barrera expulsa.
6. Mira la ventana **Output** (*View → Output*): no deberían salir errores rojos. Si sale alguno, cópiamelo.
7. Pruébalo en móvil: *Test → Device* (por ejemplo, iPhone) y comprueba que los botones se ven bien.

---

## Paso 2 · Publicar (en privado primero)

1. *File → Publish to Roblox*.
2. **Name:** `Steal an Alien` (no lo cambies después: los cambios de nombre restan visibilidad).
3. **Description:** usa el texto del apartado "Textos de la ficha" (más abajo).
4. **Creator:** tu usuario, o mejor un **grupo** (Comunidad) si vas a trabajar con más gente.
5. **Devices:** Computer, Phone, Tablet y Console.
6. Se publica como **privado**. Vuelve a probarlo publicado (*Play* desde la web).

---

## Paso 3 · Ajustes del juego (Creator Hub → tu juego → Configure)

- **Settings → Server size (Max players): 8.** ⚠️ Imprescindible: hay 8 bases.
- **Genre:** Simulation (o el subgénero más parecido que te ofrezca).
- **Places → Icon:** sube `assets/icono_512.png`.
- **Places → Thumbnails:** sube las 3 miniaturas de `assets/` y **2-3 capturas reales del juego** (con la cámara libre de Studio: *Shift + P* en una prueba). Activa varias para usar la **personalización de miniaturas**.
- **Localization:** activa la traducción automática y añade la descripción en español (abajo).
- **Questionnaire:** responde el cuestionario de madurez (paso 4).

---

## Paso 4 · Cuestionario de madurez (Maturity & Compliance)

Respuestas recomendadas según el contenido actual del juego (revísalas tú: eres el responsable de que sean exactas):

| Pregunta | Respuesta | Por qué |
|---|---|---|
| Violence | **Sí → Mild → Repeated** | El "Slap" empuja a otros jugadores (sin daño, sin sangre, estilo dibujo), y pasa a menudo |
| Blood | No | |
| Fear | No | Los aliens son de estilo simpático |
| Crude humor | No | |
| Unplayable gambling | No | |
| Strong language / Romance / Alcohol | No | |
| Social hangout / Free-form creation | No | El juego tiene objetivos claros |
| Sensitive issues | No | |
| **Paid random items** | **Sí** | "Server Luck" se paga con Robux y **cambia probabilidades** (Roblox lo incluye expresamente: *luck boosts*) |
| ↳ ¿Respeta `ArePaidRandomItemsRestricted`? | **Sí** | Ya programado: en los países donde está restringido, el botón sale como "unavailable in your region" y el servidor bloquea la compra |
| Paid item trading | No | No hay intercambio entre jugadores |
| Media (compartir, feeds, vídeo automático) | No | Sin *feeds* (la norma que afectó a Steal An Egg) |
| AI interaction | No | |

Resultado esperado: etiqueta **Mild** (apta para Roblox Kids y Select una vez superada la evaluación).

> Si alguna vez añades sangre, terror, *feeds* de vídeo o intercambio de objetos, **tienes que repetir el cuestionario**.

---

## Paso 5 · Monetización (Creator Hub → tu juego → Monetization)

### 5.1 Pases (Passes)
Crea estos 3 pases, súbeles una imagen (puedes recortar el icono) y ponles precio:

| Clave en Config | Nombre | Precio sugerido | Referencia de mercado |
|---|---|---|---|
| `PASE_DOBLE_DINERO` | 2x Cash | **199 R$** | Steal a Brainrot: 199-299 R$ |
| `PASE_VIP` | VIP | **399 R$** | Steal a Brainrot: 499 R$ |
| `PASE_CANDADO_PLUS` | Super Lock | **149 R$** | |

### 5.2 Productos de desarrollador (Developer Products)

| Clave en Config | Nombre | Precio sugerido |
|---|---|---|
| `PRODUCTO_BOOST_X2` | 2x Boost (15 min) | **39 R$** |
| `PRODUCTO_SUERTE_SERVIDOR` | Server Luck (3 min) | **99 R$** |
| `PRODUCTO_DINERO_PEQUENO` | Cash Pack | **49 R$** |
| `PRODUCTO_DINERO_GRANDE` | Mega Cash | **199 R$** |

### 5.3 Poner los IDs en el juego
Abre en Studio `ReplicatedStorage → Compartido → Config` y, en la tabla `Config.TIENDA`, cambia cada `id = 0` por el ID numérico que te da el Creator Hub. Publica de nuevo (*File → Publish to Roblox*).

> Activa **Price optimization** en el Creator Hub para los productos cuando tengas tráfico: Roblox prueba precios automáticamente.

### 5.4 Anuncios con recompensa (más adelante)
Requisitos: juego público con **2.000+ visitantes únicos al mes**, cuenta verificada y 13+.
1. *Monetization → Ads → Settings → Rewarded Video → Serving enabled*.
2. Como recompensa, elige el producto **2x Boost**.
3. En `Config`, pon `Config.ANUNCIO_RECOMPENSA_PRODUCTO = <ID del producto 2x Boost>`.
4. Activa "Exclude your most likely purchasers" (porque el boost también se vende).

### 5.5 Grupo de Roblox
Crea un **grupo/Comunidad** del juego y pon su ID en `Config.GRUPO_ID`: sus miembros ganan +10 % (anima a unirse y te da un canal para anunciar novedades).

### 5.6 Sonidos (opcional pero recomendado)
En el **Creator Store** (Audio) busca sonidos gratuitos con licencia de Roblox y pon sus IDs en `Config.SONIDOS` (música, comprar, cobrar, robar, golpe, evento, alarma).

---

## Paso 6 · Hacerlo público

1. Creator Hub → *Configure → Settings → Audience → **Public***.
2. El primer día comparte el enlace con amigos y en tus redes: Roblox mide sobre todo **retención y tiempo de juego** de los primeros jugadores.

---

## Textos de la ficha

**Nombre:** `Steal an Alien`

**Descripción (inglés, principal):**
```
👽 Buy cute aliens on the space conveyor belt, earn cash every second and sneak into other bases to STEAL their rarest aliens!

🛸 Collect 16 aliens from Common to SECRET, and hunt for rare Shiny ones
🔒 Lock your base and SLAP thieves to get your aliens back
☄️ Meteor Showers drop space crystals full of cash
🍀 Lucky Belt events make rare aliens spawn more often
🌌 Rebirth for bonus income and extra pedestals
👥 Play with friends for bonus income!

Like the game and join the group for new aliens every week!
```

**Descripción (español, en Localization):**
```
👽 Compra aliens en la cinta espacial, gana dinero cada segundo y cuélate en otras bases para ROBAR sus aliens más raros.

🛸 Colecciona 16 aliens, de Common a SECRET, y busca los Shiny
🔒 Cierra tu base y usa SLAP para recuperar tus aliens
☄️ Las lluvias de meteoritos sueltan cristales llenos de dinero
🍀 Con el Lucky Belt salen aliens raros más a menudo
🌌 Haz Rebirth para ganar más y tener más pedestales
👥 ¡Juega con amigos y gana más!
```

**Códigos iniciales** (en `ServerScriptService → Servidor → Codigos`): `RELEASE`, `ALIENS`. Crea uno nuevo con cada actualización y anúncialo.

---

## Paso 7 · Primeras 4 semanas

| Cuándo | Qué hacer |
|---|---|
| Día 1-3 | Mira *Analytics → Engagement*: **retención D1**, **tiempo de sesión** y **tasa de abandono en los primeros 3 min**. Si mucha gente se va antes de 3 minutos, el problema es el tutorial o el primer minuto |
| Semana 1 | Anuncios (*Ads Manager*) con poco presupuesto (puedes pagar con Robux convertidos en créditos). Objetivo **Plays** para tráfico; objetivo **Engagement** si quieres llegar antes a las 250 partidas para todas las edades |
| Semana 1-2 | 3-5 vídeos cortos (TikTok / YouTube Shorts) con robos épicos y aliens Secret. Graba con la cámara libre (*Shift + P*) |
| Cada semana | **Actualización**: 1-2 aliens nuevos (una línea en `Config.ALIENS`), un código nuevo y miniaturas nuevas. Pon "[UPDATE]" o un emoji en el nombre solo durante la actualización |
| Si la retención es buena | Más eventos y bases decoradas. Plantéate un artista 3D para los aliens (ver "Modelos personalizados" en el README) |

---

## Paso 8 · Cobrar (DevEx)

- Mínimo **30.000 Robux ganados**, 13+ (tienes 19), email verificado y formulario fiscal **W-8BEN** (desde el 1/11/2026 en la página *Taxes* del Creator Hub).
- En España: declara los ingresos en el IRPF y consulta a una gestoría si pasan a ser habituales (ver `ESTRATEGIA.md`).
