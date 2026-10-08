# Air Cargo Empire — Documento de diseño (v0.1)

> Nombre provisional. En español: *Imperio de Carga Aérea*. Se puede cambiar sin tocar la lógica.

## 1. Idea en una frase

Empiezas con una avioneta de carga en Nueva York y construyes una aerolínea de carga mundial:
compras aviones, contratas pilotos, eliges cargas del tablón, sacas licencias y abres regiones
hasta tener una flota de cargueros gigantes volando sola por todo el mundo.

**Inspiración:** un juego de gestión de camiones que me enseñaste (capturas del 9-oct-2026).
Tomamos el **género y el tipo de interfaz** (juego casi todo de menús, mapa con rutas, tarjetas
de vehículos, pilotos con rarezas y probabilidades visibles). **No copiamos** su nombre, textos,
colores, distribución exacta ni ningún asset. Diferencias de identidad:

| | Referencia | Este juego |
|---|---|---|
| Vehículos | Camiones por EE. UU. | Aviones de carga por 6 regiones del mundo |
| Color de acento | Amarillo | Naranja + azul cielo |
| Navegación | Menú lateral | Menú lateral + pestañas propias, Despacho en una sola pantalla |
| Extras propios | — | Clima por aeropuerto que paga más, reposicionar en vacío, licencias de carga especial |

## 2. Bucle principal (lo que hace el jugador cada minuto)

1. **Despacho** → elige avión en tierra → elige quién vuela (tú o un piloto) → elige carga → **VOLAR**.
2. El avión cruza el mapa en tiempo real (1 s real = 2 min de vuelo; un vuelo dura de 15 s a ~5 min).
3. Al aterrizar cobra: **pago − combustible − comisión del piloto (10 %)** y gana XP.
4. Con el dinero: más aviones, pilotos, licencias, regiones y mejoras → vuelos más largos y caros.
5. Nivel 5: **despacho automático** (la flota trabaja sola, también con el juego cerrado: los vuelos
   en curso aterrizan aunque salgas).

Tú solo puedes pilotar **un** avión a la vez: para volar más aviones a la vez hay que contratar pilotos.

## 3. Pantallas (todas hechas por código)

| Pantalla | Contenido |
|---|---|
| **Mapa** | Mapa del mundo oscuro, aeropuertos (clima, aviones en tierra), rutas punteadas y aviones moviéndose, tarjeta "N aviones listos → despachar" |
| **Flota** | Mis aviones (estado, ubicación, condición, reparar/vender) · Concesionario · Mejoras |
| **Despacho** | Lista de aviones · tablón de cargas del aeropuerto · selector de piloto · actualizar · reposicionar · interruptor AUTO |
| **Pilotos** | Plantilla · Contratar (3 agencias con barra y lista de probabilidades) |
| **Empresa** | Resumen (nivel, XP, estadísticas) · Regiones · Licencias |
| **Ajustes** | Idioma (automático/inglés/español), sonido, versión y créditos |

Barra superior siempre visible: dinero, nivel con barra de XP, precio del combustible, aviones en el aire.

## 4. Economía (todos los números están en `src/ReplicatedStorage/Config.luau`)

**Aviones** (nombres inventados, sin marcas reales):

| Avión | Clase | Carga | Velocidad | Alcance | Consumo | Precio | Nivel | Licencia |
|---|---|---|---|---|---|---|---|---|
| SkyHopper C1 | turbohélice | 1,5 t | 340 km/h | 1.800 km | 0,6 L/km | $25.000 | 1 | — |
| Coastline T8 | turbohélice | 8 t | 500 km/h | 2.600 km | 1,6 L/km | $75.000 | 3 | Turbohélice |
| Jetline N20 | reactor | 20 t | 820 km/h | 4.200 km | 3,7 L/km | $1,5M | 6 | Reactor |
| Horizon W55 | reactor | 55 t | 870 km/h | 7.500 km | 7 L/km | $8M | 10 | Reactor |
| Titan J110 | reactor | 110 t | 900 km/h | 8.800 km | 13 L/km | $25M | 15 | Pesado |
| Goliath H150 | reactor | 150 t | 780 km/h | 5.500 km | 19 L/km | $45M | 20 | Pesado |

**Pago de una carga** = toneladas × km × $4 × tipo de carga × clima × mejoras × bonus del piloto.
Tipos de carga: general ×1, correo ×1,15, perecederos ×1,25, electrónica ×1,3, animales vivos ×1,4*,
fármacos ×1,6*, peligrosas ×1,8*, sobredimensionada ×2 (solo Goliath). *Necesitan licencia.

**Clima** (cambia cada 3 min por aeropuerto): despejado / lluvia (+5 %) / nieve (+15 %) / tormenta (+30 %, más lento y más desgaste).

**Combustible:** $2,50/L ±30 % (cambia cada 5 min). Se paga al aterrizar, así que nunca te quedas bloqueado sin dinero.

**Desgaste:** ~1,5 % por cada 1.000 km. Por debajo del 25 % no vuela hasta repararlo.

**Regiones:** Norteamérica (inicio) · Europa (nv 4, $150K) · Sudamérica (nv 6, $600K) · Asia (nv 8, $2M) ·
Oriente Medio y África (nv 10, $5M) · Oceanía (nv 13, $15M). 38 aeropuertos reales en total.

**Pilotos** (se pagan con dinero del juego, NO con Robux; probabilidades siempre visibles):

| Agencia | Nivel | Precio | Común | Poco común | Raro | Épico | Legendario |
|---|---|---|---|---|---|---|---|
| Escuela de vuelo | 1 | $5.000 | 60 % | 28 % | 10 % | 1,8 % | 0,2 % |
| Academia de aerolínea | 8 | $250K | 0 % | 38 % | 46 % | 14 % | 2 % |
| Cazatalentos de ases | 15 | $3M | 0 % | 0 % | 55 % | 38 % | 7 % |

Bonus de pago por rareza: 0 / +5 / +12 / +22 / +40 %. Máximo 20 pilotos.

**Mejoras:** Hangar (+2 plazas, empiezas con 3) · Contratos de combustible (−5 %/nivel) · Agentes de carga (+4 % de pago/nivel).

**XP y niveles:** XP por vuelo = √(pago bruto). XP para el nivel L = 150 × (L−1)².

### Ritmo medido (bot perfecto en el harness; una persona irá más lenta)

| Momento | Minuto |
|---|---|
| Nivel 2 | ~2,7 |
| 2º avión | ~4,5 |
| 1er piloto contratado | ~5,6 |
| Licencia turbohélice (nivel 3) | ~9 |
| 1er turbohélice | ~21 |
| Nivel 5 (despacho automático) | ~26 |
| Nivel 6 | ~32 |

Confianza en que el ritmo sea bueno para personas: **~50 %**. Hay que ajustarlo cuando lo pruebes:
sospecho que entre el minuto 9 y el 21 hay un tramo lento.

## 5. Gráficos: qué es código y qué son imágenes

| Elemento | Cómo se hace | Quién |
|---|---|---|
| Toda la interfaz (paneles, botones, barras, pestañas, animaciones, colores, fuentes Oswald + Builder Sans) | Código | Claude |
| Hoja de 55 iconos (`assets/iconos.png`) | Generada desde **Lucide** (licencia ISC) | Claude la genera, **tú la subes** |
| Mapa del mundo en 2 trozos (`assets/mapa_oeste.png`, `mapa_este.png`) | Dibujado desde **Natural Earth** (dominio público) | Claude lo genera, **tú lo subes** |
| Ilustraciones de los 6 aviones (`assets/aviones.png`) | Dibujadas por código (vista lateral, estilo plano) | Claude las genera, **tú las subes** |

Mientras no se suban las imágenes, el juego funciona igual pero con sustitutos de texto (iconos
como símbolos, mapa con una retícula). **Son 4 subidas en total.**

Limitación honesta: las ilustraciones de aviones son **más simples** que los camiones en 3D del juego
de referencia. Mejorarlas exigiría modelos 3D o un render profesional (fase posterior).

## 6. Monetización (preparada, sin activar: todos los `id = 0`)

Propuesta, siguiendo lo aprendido con Web Empire Tycoon (nada de artículos aleatorios de pago):
- Game Pass **Dinero x2**
- Game Pass **Piloto automático** (despacho automático desde el nivel 1)
- Game Pass **Hangar VIP** (+4 aviones)
- Developer Products de dinero (más adelante)

## 7. Fases siguientes (ideas, por orden de impacto estimado)

1. Tutorial guiado (5–6 pasos) y recompensa diaria — enganche de los primeros minutos.
2. Contratos con empresas (cargas repetidas mejor pagadas) y reputación.
3. Seguro y perfil de riesgo (incidentes en tormenta, averías).
4. Clasificación global y semanal.
5. Alianzas entre jugadores ("team up").
6. Sonidos propios, mejores ilustraciones de aviones, fondo 3D de hangar.

## 8. Qué NO está verificado

- No he podido abrirlo en Roblox Studio: la interfaz se ha probado con Lune (crea todos los objetos
  reales de Roblox y pulsa todos los botones) y con una **vista previa aproximada** en navegador
  (`docs/vista_*.jpg`). Las fuentes y algunos tamaños automáticos pueden verse algo distintos en Roblox.
- La ruta de la fuente Builder Sans (`rbxasset://fonts/families/BuilderSans.json`) no la he podido
  comprobar en Roblox; si no existiera, Roblox usa la fuente por defecto (no se rompe nada).
- El sonido usa un archivo interno de Roblox (`rbxasset://sounds/electronicpingshort.wav`); confianza ~70 %
  de que exista. Si no, simplemente no suena.
