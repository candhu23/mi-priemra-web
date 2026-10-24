---
name: roblox-ui-estilo
description: Da a la interfaz de un juego de Roblox un estilo profesional y coherente — elige un tema de colores con contraste comprobado (tema.py → Tema.luau), fija letras, tamaños, espaciado y jerarquía, y revisa el código Luau de la UI con revisar_ui.py (texto pequeño en móvil, TextScaled sin límites, MouseButton1Click, UIGradient sobre texto, poco contraste, botones pequeños, fuentes antiguas…). Úsala al empezar la interfaz de un juego, cuando el usuario diga "se ve feo / amateur / soso", "cambia los colores", "que parezca un juego de verdad", o antes de publicar cambios de interfaz.
---

# roblox-ui-estilo — que la interfaz parezca de un juego top

Herramientas (en la carpeta de esta skill; búscala con `find / -path "*roblox-ui-estilo/tema.py" 2>/dev/null | head -1` si no sabes dónde está):

| Archivo | Para qué |
|---|---|
| `tema.py` | `python3 tema.py lista` · `python3 tema.py caramelo src/ReplicatedStorage/Tema.luau --muestra tema.png [--primario #hex] [--fondo #hex]` → módulo Luau con colores, letras, tamaños y espaciado + comprobación de contraste + muestra PNG |
| `revisar_ui.py` | `python3 revisar_ui.py src [--informe informe.md]` → avisos con `archivo:línea` y cómo arreglarlo (códigos UI01–UI12) |

Va en equipo con: **roblox-ui-componentes** (UIKit, usa el Tema), **roblox-ui-pantallas** (pantallas hechas + ver capturas), **roblox-ui-movil**, **roblox-ui-animaciones**.

## Flujo
1. Pregunta (o deduce) el ambiente del juego → elige estilo: `caramelo` (mascotas, dulces), `noche` (todo terreno), `bosque`, `oceano`, `lava`, `espacio`, `pastel`, `oro` (tycoons). Genera `Tema.luau` y **mira la muestra** (Read del PNG).
2. Todo color de la UI sale del Tema. Nada de `Color3.fromRGB` sueltos por el código.
3. Aplica las reglas de abajo. Pasa `revisar_ui.py` y arregla los avisos de UI01–UI08 siempre; UI09–UI12 según el caso.
4. Si puedes, **mira la interfaz** con la skill roblox-ui-pantallas (capturas PC 1280×720 y móvil 844×390).

## Reglas de estilo (lo que separa un juego «pro» de uno amateur)
**Jerarquía**: 1 cosa principal por pantalla (el botón de acción o la recompensa), grande y con color fuerte; lo secundario más pequeño y apagado (`panel2`, `textoSuave`). Si todo brilla, nada destaca.

**Color**
- Fondo oscuro y desaturado + 1 color primario + 1 acento. Verde = comprar/aceptar, rojo = cerrar/peligro, amarillo/oro = dinero y premios. No cambies este significado.
- Colores de rareza fijos en todo el juego (Común gris, Poco común verde, Raro azul, Épico morado, Legendario naranja, Mítico rosa, Secreto negro/arcoíris).
- Contraste: texto normal ≥ 4,5:1; títulos grandes ≥ 3:1. Texto blanco encima de botones de color SIEMPRE con contorno (`UIStroke` Contextual, 2 px, color `borde`).

**Letra**: FredokaOne (o GothamBlack) para títulos, botones y cifras; BuilderSans Bold para texto. Tamaños de diseño (pantalla base 1280×720): enorme 56 · título 36 · botón 28 · normal 22 · pequeña 18. **Nunca menos de 18** (en el móvil se ve ×0,66).

**Formas**: esquinas redondeadas (12–18), borde oscuro de 3 px, botones «gruesos» con sombra debajo que se hunden al pulsar. Iconos/emoji grandes en botones del HUD con un rótulo corto debajo.

**Espaciado**: múltiplos de 4 (4, 8, 12, 16, 24). Márgenes de 16 a los bordes de la pantalla. Elementos alineados en rejilla; nada «flotando» a ojo.

**Números**: formato corto (1.5K, 2.3M, 4.1B); dinero siempre con su icono; las cifras que suben se animan (roblox-ui-animaciones).

**Texto para jugadores**: corto, en imperativo y con emoji guía («🥚 Abre un huevo»). Sin jerga. Todo texto pasa por el sistema de idiomas si el juego tiene inglés.

## Trampas de Roblox (no las repitas)
- `UIGradient` dentro de TextLabel/TextButton **tiñe las letras** → el degradado va en un Frame de fondo.
- **Solo un UIScale por objeto**: si ya escala la pantalla, anima un Frame contenedor.
- `TextScaled` sin `UITextSizeConstraint` → letras gigantes en PC o diminutas en móvil.
- `ScreenGui.ResetOnSpawn = false` siempre (si no, la UI se recrea al morir).
- Botones con `.Activated` (ratón, dedo y mando), nunca `MouseButton1Click`.
- `ZIndexBehavior = Sibling` y ZIndex pequeños; las ventanas modales encima con un velo oscuro.

## Al terminar
Di al usuario qué cambió, enséñale la muestra o capturas, qué no pudiste comprobar (no hay Studio: fuentes y medidas son aproximadas) y tu % de confianza.
