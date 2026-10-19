---
name: "roblox-level-design"
description: "Diseñar y construir mapas de Roblox: escala respecto al personaje, greybox, recorridos, iluminación, organización del Workspace y presupuesto de piezas. Úsala cuando Jorge pida ayuda para planificar o construir un mapa o nivel."
---

# Diseño de niveles en Roblox

## Flujo de trabajo
1. **Objetivo del mapa**: qué hace el jugador aquí (combate, obby, exploración, tienda) y cuánto dura una vuelta.
2. **Greybox primero**: bloques grises sin detalle para probar recorrido, distancias y saltos. Pruébalo jugando antes de decorar.
3. **Hitos visuales**: 1 elemento grande visible desde casi todo el mapa para orientarse; caminos que guían hacia objetivos.
4. **Detalle y decoración** solo cuando el recorrido funcione. Con plugins JRT: Clonador (vallas, columnas, rejillas), Dispersar (vegetación, rocas), Alinear (ordenar y bajar al suelo).
5. **Iluminación y ambiente** al final.
6. **Pasada de rendimiento** con el Auditor JRT.

## Escala (valores por defecto; comprueba si el juego los cambia)
- Personaje ≈ 5 studs de alto. WalkSpeed por defecto 16 studs/s.
- Salto por defecto ≈ 7 studs de altura: los saltos obligatorios deben quedar holgadamente por debajo, y los imposibles claramente por encima.
- Puertas ≥ 8 de alto y ≥ 5 de ancho; pasillos ≥ 6 de ancho para que la cámara no choque.
- Si un espacio se siente vacío, suele ser demasiado grande, no falta de objetos.

## Organización del Workspace
- Carpetas: `Mapa/Suelo`, `Mapa/Edificios`, `Mapa/Decoración`, `Zonas` (Parts invisibles de lógica), `Spawns`.
- Todo anclado salvo lo que deba moverse. Zonas de lógica: Transparency 1, CanCollide false, CanQuery según uso.
- Nombres claros: los scripts encuentran cosas por nombre o por etiquetas de CollectionService.

## Iluminación
- Lighting.Technology Future para interiores con luces; ShadowMap en exteriores grandes si hay que ahorrar.
- Atmosphere para profundidad, ColorCorrection y Bloom suaves. Pocas luces con sombras.

## Rendimiento
- StreamingEnabled en mapas grandes o pensados para móvil.
- Reutiliza meshes; evita miles de piezas diminutas de decoración; colisión Box o Hull en decoración.
- Prueba en el emulador de dispositivos de Studio (móvil) antes de dar el mapa por bueno.

## Al responder
Propón primero el greybox y el recorrido, después el detalle. Indica a Jorge el nivel de confianza (%) y qué datos faltan (género, número de jugadores, plataforma objetivo).