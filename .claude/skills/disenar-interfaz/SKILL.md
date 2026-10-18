---
name: disenar-interfaz
description: Diseña, revisa y mejora la interfaz (GUI) de los juegos de Roblox del repo VIÉNDOLA — vuelca la interfaz desde las pruebas de Lune, la dibuja como PNG en tamaño PC y móvil, la audita automáticamente (texto pequeño, cortado o tapado, contraste, botones pequeños para el dedo, cosas fuera de pantalla, UIGradient sobre texto) y aplica la guía de estilo de abajo. Úsala siempre que crees o cambies una pantalla, menú, HUD, tienda o ventana, cuando el usuario diga "se ve feo", "mejora el diseño", "no se lee", "en el móvil se ve mal", o antes de publicar una versión con cambios visibles.
---

# disenar-interfaz — ver, auditar y mejorar la interfaz

No puedo abrir Studio, pero sí **ver** la interfaz: el código real del cliente se ejecuta en Lune, se vuelca
el árbol de la GUI a JSON y `ver_interfaz.py` lo dibuja con Chromium y lo revisa. Es una aproximación
(fuentes parecidas, sin 3D), buena para distribución, tamaños, colores y solapes.

## 1. Bucle de trabajo (síguelo siempre que toques la interfaz)

1. **Volcar**: el harness del cliente del juego llama a `volcado.luau` en cada pantalla importante
   (AeroCarga: `run_game.luau <rbxl> <carpeta>`; Imperio: `run_client.luau <src> <carpeta> [ancho alto]`;
   juegos de la plantilla: `run_juego.luau <rbxl> <carpeta> [ancho alto]`). Para auditar **móvil**, el volcado
   tiene que hacerse con la pantalla del móvil (844×390), porque el UIScale se calcula con ella.
2. **Ver y auditar**: `python3 -I .claude/skills/disenar-interfaz/ver_interfaz.py <carpeta> [--movil]`
   → `<pantalla>.png`, `<pantalla>_problemas.png` (recuadros rojos numerados) e `informe_diseno.md`.
3. **Mirar las capturas con Read** (no te fíes solo del informe) y anotar qué falla de verdad.
4. Arreglar en el código → `tools/check.sh` → repetir 1–3 hasta que el informe no tenga problemas graves
   (cortado, tapado/solape, fuera de pantalla, gradiente) y los visuales te convenzan.
5. Enseñar al usuario 1–3 capturas del antes/después (SendUserFile) y decir que son aproximadas.

El informe agrupa cada fallo una vez. Prioridad: **cortado > tapado/solape > fuera > gradiente > pequeño > contraste > botón**.
Falsas alarmas conocidas: emojis ligeramente más anchos que en Roblox; insignias pequeñas encima de
iconos (ya se ignoran); paneles que tapan a propósito parte del HUD (decide tú si es feo).

## 2. Guía de estilo para juegos de Roblox (lo que hace que un juego «se vea pro»)

**Escala y móvil (más de la mitad de los jugadores usan móvil)**
- Diseña en unidades de una pantalla base (p. ej. 960×540 o 1280×720) y un `UIScale` en un Frame raíz:
  `escala = clamp(min(ancho/BASE_X, alto/BASE_Y), 0.7, 1.25)`. **Nunca bajes de ~0,7**: con 0,55 el texto de
  16 px queda en 9 px en un móvil (ilegible).
- Texto: cuerpo ≥ 16 px de diseño, etiquetas ≥ 14, nada < 12. Tras escalar, ≥ 11 px reales en móvil.
- Botones ≥ 44×44 px de diseño (≥ 36 reales en móvil); separación ≥ 8 px. Lo importante, abajo y a los lados
  (zona del pulgar); deja libre la esquina superior izquierda (menú de Roblox) y respeta `GuiInset` (58 px).
- Solo **un `UIScale` por objeto** (el botón ya puede tener uno para animar → escala el contenedor).

**Jerarquía y claridad**
- Una acción principal por pantalla: el botón más grande y de color más vivo. El resto, secundario (blanco/gris).
- Máximo 3 tamaños de texto por pantalla (título 28–40, normal 16–20, pequeño 14). Números de dinero grandes.
- Agrupa en tarjetas (Frame claro, `UICorner` 12–16, `UIPadding` 12–16, `UIListLayout` con 8–12 de hueco).
- Iconos/emoji junto a cada número (💰 dinero, ⭐ nivel, ⏱️ tiempo): se entiende sin leer.
- Texto que puede crecer (nombres, traducciones al inglés, precios grandes): `TextScaled` con
  `UITextSizeConstraint` (MaxTextSize) o `TextTruncate.AtEnd`, y prueba con el texto más largo.

**Color**
- Paleta fija en tokens (`Config.Colors`/`THEME`): 1 color de marca, 1 de acción (verde/naranja), dorado
  para recompensas, rojo solo para errores/avisos, neutros para paneles. No inventes colores sueltos.
- Contraste: texto normal 4,5:1, texto grande o negrita ≥ 18 px 3:1. Blanco sobre naranja/amarillo/verde
  claro NO llega: usa texto oscuro, o borde (`UIStroke` 2–3 px oscuro en el texto) o un tono más oscuro.
- **`UIGradient` en un TextLabel/TextButton tiñe también el texto** → pon el degradado en un Frame de fondo.

**Sensación de juego («juice»), siempre con moderación**
- Botón «grueso»: base oscura 4 px debajo y cara que baja 3 px al pulsar + sonido de clic.
- Al ganar: número flotante «+$X» que sube y se desvanece; al subir de nivel: ventana con confeti.
- Transiciones cortas (0,12–0,25 s, `Quad`/`Back`), nada que tape la partida más de 2 s.
- Puntos rojos de aviso (●/número) en los botones con algo por recoger: engancha sin molestar.

**Tienda y monetización (normas de Roblox, ver CLAUDE.md §11)**
- Precio en Robux visible, qué da exactamente y «para siempre»/«una vez». Nada de «GRATIS» engañoso.
- Si algo es aleatorio, probabilidades visibles en la misma pantalla.
- La tienda no debe abrirse sola al entrar ni tapar el juego; ofrécela en el momento útil
  (p. ej. «te faltan $200 → 💼 Maletín»).

## 3. Archivos

| Archivo | Para qué |
|---|---|
| `volcado.luau` | Módulo de Lune: `volcar(playerGuiReal, ruta.json)`. Cópialo a `<juego>/tools/harness/` |
| `ver_interfaz.py` | JSON → HTML → PNG + auditoría + `informe_diseno.md` (`--movil`, `--ancho/--alto`, `--estricto`) |
| `capturar.js` | Chromium (Playwright): maqueta, fotografía y audita cada pantalla |
