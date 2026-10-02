# 👽 Steal an Alien

Juego de Roblox del género **"Steal a…"**: compra aliens en una cinta espacial, gana dinero cada segundo, roba los aliens de otros jugadores y protege los tuyos.

| Documento | Contenido |
|---|---|
| [`GUIA_LANZAMIENTO.md`](GUIA_LANZAMIENTO.md) | **Empieza aquí.** Pasos para probar, publicar, monetizar y lanzar |
| [`ESTRATEGIA.md`](ESTRATEGIA.md) | Estudio de mercado, comparativa, normativa, dinero y fiscalidad en España |
| `build/StealAnAlien.rbxlx` | **El juego listo para abrir en Roblox Studio** |
| `assets/` | Icono (512×512) y miniaturas (1920×1080) para la ficha del juego |

## Cómo se juega
1. **Compra** aliens en la cinta central (mantén **E**). El primero cuesta $25 y empiezas con $100.
2. Tus aliens generan **dinero por segundo**. Pisa la **placa verde** de tu base para cobrar.
3. **Roba**: entra en otra base, mantén **E** sobre un alien y corre a tu base.
4. **Defiende**: usa **Slap** sobre los ladrones para que suelten tu alien, o pisa la **placa roja** para cerrar tu base.
5. **Mejora**: tienda de velocidad ⚡ y **Rebirth** 🌌 (+50 % de ingresos y +1 pedestal para siempre).
6. **Eventos**: 🍀 *Lucky Belt* cada 10 min (aliens raros ×4) y ☄️ *Meteor Shower* cada 15 min (cristales con dinero).
7. **Extras**: 16 aliens y variantes ✨ Shiny, Índice de colección, recompensa diaria con racha, ganancias mientras no juegas, bonus por jugar con amigos y por estar en el grupo, códigos promocionales y rankings globales.
8. Pulsa **F** sobre tus aliens para venderlos a mitad de precio.

## Estructura del código

```
src/
  shared/   → ReplicatedStorage/Compartido (lo usan servidor y cliente)
    Config.luau          ← ⭐ TODO lo configurable: aliens, precios, tiempos, IDs de la tienda
    Formato.luau         números y tiempos en pantalla
    Probabilidades.luau  probabilidades de la cinta (las mismas que muestra el Índice)
  server/   → ServerScriptService/Servidor
    Main.server.luau     lógica del juego
    Datos.luau           guardado con bloqueo de sesión (evita perder datos al cambiar de servidor)
    Perfil.luau          estructura y limpieza de los datos guardados
    Mapa.luau            construye el mapa al arrancar
    Modelos.luau         construye los aliens
    Codigos.luau         ← códigos promocionales
  client/   → StarterPlayerScripts/Cliente
    Main.client.luau     interfaz, tutorial, animaciones y sonidos
tests/run.luau           tests de la lógica (economía, probabilidades, datos)
assets/                  icono, miniaturas y el script que las genera
```

## Cambiar cosas habituales
- **Añadir un alien:** añade una línea en `Config.ALIENS` (con un `id` nuevo que no cambies nunca).
- **Equilibrar la economía:** precios e ingresos en `Config.ALIENS`; fórmulas (`costeRebirth`, `costeVelocidad`…) al final de `Config`.
- **IDs de pases y productos:** `Config.TIENDA`.
- **Códigos:** `server/Codigos.luau`.
- **Modelos 3D personalizados:** crea `ReplicatedStorage/ModelosAlien` y mete un *Model* por alien llamado como su `id` (por ejemplo `blorp`), con su `PrimaryPart` puesto. El juego lo usará en lugar del modelo generado.

## Para programadores (opcional)
- Compilar el juego: `rojo build default.project.json -o build/StealAnAlien.rbxlx` ([Rojo](https://rojo.space) 7.x).
- Sincronizar en vivo con Studio: `rojo serve` y el plugin de Rojo.
- Tests: `luau tests/run.luau`.
- Análisis de tipos: `luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src`.
- Regenerar el arte: `node assets/generar_arte.js <carpeta-con-LilitaOne.ttf-y-Fredoka.ttf>` (necesita Playwright).

## Limitaciones conocidas
- **No se ha podido ejecutar dentro de Roblox** (no hay Roblox Studio en Linux). El código está validado con el analizador de tipos oficial de Luau usando las definiciones de la API de Roblox, con tests de la lógica y con la compilación de Rojo. Aun así, **haz la lista de comprobación de `GUIA_LANZAMIENTO.md` antes de publicar**.
- Los aliens son modelos hechos con piezas básicas. Es lo que más diferencia el juego de los grandes del género.
- Sin sonidos hasta que pongas IDs de audio en `Config.SONIDOS`.
