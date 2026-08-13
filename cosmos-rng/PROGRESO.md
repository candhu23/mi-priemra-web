# PROGRESO — Cosmos RNG

Estado real del proyecto. Lo actualizo yo (Claude) al final de cada hito.
Última actualización: 2026-08-13.

---

## Estado global

**Fase actual:** Hito 0 — no iniciado (esperando confirmación de Jorge).
**Código escrito:** ninguno. Este documento es el único archivo del proyecto.
**Probado en Roblox Studio:** nada. No tengo acceso a Studio; todo el código
Luau que entregue será NO PROBADO hasta que tú lo pruebes.

---

## Mapa de hitos

| Hito | Qué contiene | Estado |
|------|--------------|--------|
| 0 | Instalación (Rojo, Studio, plugin) y sincronización verificada | Pendiente |
| 1 | Tabla de rarezas + tirada servidor-autoritativa + panel de probabilidades | Pendiente |
| 2 | Persistencia (DataStore con bloqueo de sesión) e inventario | Pendiente |
| 3 | La sensación: UI móvil, anticipación, revelación, sonido, anuncio global | Pendiente |
| 4 | Objeto equipado: órbita, luz, rastro, escala por tier | Pendiente |
| 5 | Colección/Índice, Suerte, recompensas diarias y racha | Pendiente |
| 6 | Monetización: gamepasses, productos, ProcessReceipt, PolicyService | Pendiente |
| 7 | Mapa mínimo, anti-exploit, rendimiento móvil, checklist de publicación | Pendiente |

---

## Decisiones tomadas

- Temática: cuerpos celestes reales o plausibles (Bloque 0 del encargo).
- Lenguaje: Luau. Flujo: carpeta local sincronizada a Studio con Rojo.
- Arquitectura: servidor autoritativo. El cliente nunca calcula una tirada.
- Cero assets externos: geometría primitiva, materiales y partículas de Roblox.

## Decisiones pendientes de Jorge

Ver la lista numerada en la respuesta del Bloque 9 (12 puntos abiertos).
Los que bloquean el Hito 1 son: modelo de suerte, cooldown base, techo de
rareza y número exacto de objetos.

---

## Riesgos abiertos

1. **Política de Paid Random Items.** No he podido abrir la documentación
   oficial desde este entorno (proxy de red bloquea `create.roblox.com` y
   `devforum.roblox.com`). Trabajo con resúmenes de búsqueda. A VERIFICAR
   antes de publicar.
2. **Techo de 1/10.000.000.** Con cooldown de 3 s es inalcanzable en la
   práctica. Propuesta: techo real en 1/1.000.000–1/2.000.000 para la v1.
3. **Rendimiento móvil** de los efectos Mítico/Cósmico. Requiere prueba en
   un Android real, no solo en Studio.
4. **Ubicación del proyecto:** ahora mismo vive dentro del repo
   `mi-priemra-web`, que contiene una web sin relación. Pendiente de decidir.

---

## Qué debo probar yo (Jorge)

Nada todavía. Al cerrar cada hito, esta sección tendrá un checklist concreto
de qué pulsar y qué deberías ver en pantalla.
