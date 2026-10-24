---
name: roblox-ui-movil
description: Hace que la interfaz de un juego de Roblox funcione bien en móvil, tableta, PC y consola — módulo Adaptable.luau (escala automática con mínimo legible, tipo de control táctil/ratón/mando, zona segura, texto ajustado con límites, proporciones fijas, botones en la zona del pulgar, textos de tecla por dispositivo, navegación con mando) y la lista de medidas y zonas prohibidas de Roblox en móvil. Úsala siempre que el usuario diga "en el móvil se ve mal / pequeño / no cabe / no puedo pulsar", al crear cualquier HUD o menú (más de la mitad de los jugadores de Roblox juegan en móvil) o antes de publicar cambios de interfaz.
---

# roblox-ui-movil — que se juegue bien con el dedo

`Adaptable.luau` (carpeta de esta skill) → cópialo a ReplicatedStorage. Sin dependencias.

## API
| Función | Para qué |
|---|---|
| `Adaptable.escalar(frame, Vector2.new(1280, 720), 0.7?)` | escala un diseño de tamaño fijo a cualquier pantalla, sin bajar de 0,7 (o lo que quepa a lo ancho) |
| `Adaptable.dispositivo()` | `"Tactil"`, `"Raton"` o `"Mando"` (según el último control usado) |
| `Adaptable.info()` / `Adaptable.alCambiar(f)` | ancho, alto, dispositivo, `movil`, `vertical`, escala; `alCambiar` avisa al girar la pantalla o cambiar de control |
| `Adaptable.textoAjustado(label, 14, 40)` | TextScaled con mínimo y máximo (UITextSizeConstraint) |
| `Adaptable.proporcion(obj, 16, 9)` | que no se deforme al estirar (UIAspectRatioConstraint) |
| `Adaptable.zonaSegura(frame)` / `margenSuperior()` | no tapar la barra de Roblox ni la muesca |
| `Adaptable.zonaPulgar(boton, "derecha", posRaton)` | en táctil lo pone a media altura en el lateral; con ratón donde digas |
| `Adaptable.tecla("E", "ButtonX")` | «E» / «X» / «Toca» para textos de ayuda («Pulsa E para abrir») |
| `Adaptable.seleccionarConMando(primerBoton)` | navegación con cruceta al abrir una ventana |
(Si usas UIKit, `UIKit.pantalla()` ya escala; Adaptable añade el resto.)

## Medidas (tamaño REAL en pantalla, después de escalar)
- Pantallas de prueba: **PC 1280×720**, **móvil horizontal 844×390** (iPhone) y **800×360** (Android pequeño), **tableta 1024×768**. Roblox quita ~58 px arriba (barra) si `IgnoreGuiInset = false`.
- Con diseño 1280×720 y escala mínima 0,7: en 844×390 la escala real es ≈0,66 → **texto de diseño ≥ 18** (≈12 px reales), botones de acción **≥ 56 de alto** (≈37 px). Lo ideal en el dedo: 44–48 px reales.
- Separación entre botones ≥ 8 px reales (dedos gordos).

## Zonas en móvil
```
┌──────────────────────────────────────────────┐
│ ☰ menú/chat Roblox │      (avisos)     │ ⚙  │  ← arriba: barra de Roblox (no tapar)
│ 💰 dinero           │                   │     │
│ [🛒][🐾]  ← pulgar   │   centro: mundo,   │ [⭐] │  ← laterales a media altura: botones
│ [🎯][⚙]             │   ventanas         │     │
│ (joystick)          │                   │(SALTAR)│ ← abajo: controles de Roblox: NO poner botones
└──────────────────────────────────────────────┘
```
- Nada importante en las esquinas de abajo (joystick y saltar) ni pegado arriba-izquierda (menú/chat).
- Información que NO dependa del ratón encima (hover): en móvil no existe. Usa toque o mantener pulsado.
- Ventanas: que quepan en 844×332 de alto útil; si no, se encogen (UIKit.ventana ya lo hace) y su contenido hace scroll.
- Vertical (móvil de pie): Roblox lo permite si lo activas; casi todos los juegos fuerzan horizontal (StarterGui.ScreenOrientation = LandscapeSensor).

## Comprobar
1. Revisión del código: `roblox-ui-estilo/revisar_ui.py src` (UI01 texto pequeño, UI02 TextScaled, UI03 MouseButton1Click, UI08 botones pequeños, UI09 sin escala).
2. Capturas en 844×390 con **roblox-ui-pantallas** (`probar_pantallas.luau … 844 390` + `ver_interfaz.py --movil`) y mirarlas.
3. Si el usuario puede: Studio → Test → Device (emulador) → iPhone/Android, horizontal. Pídele captura.
Di siempre qué comprobaste con capturas aproximadas y qué queda por probar en un móvil de verdad.
