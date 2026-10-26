# Modelos 3D de Crías Míticas (rocas, árboles, setas, palmeras, cactus, flores…)

Son 30 modelos del **Kenney Nature Kit** (licencia CC0: gratis, también para uso comercial, sin pedir permiso),
recoloreados para el juego. El juego los pinta según la zona. Si no están, usa piezas básicas.

## Importarlos (una sola vez, ~3 minutos)

1. Descarga el archivo:
   `https://github.com/candhu23/mi-priemra-web/raw/claude/confident-johnson-v5zy5f/roblox-crias-miticas/modelos/CriasMiticas_Modelos.glb`
2. Abre el juego en Studio (el `.rbxl` de siempre).
3. Arriba: pestaña **Avatar** → **Importar 3D** (si no lo ves: **Archivo → Importar 3D**). Elige el `.glb`.
4. En la ventana de importación deja todo como está y pulsa **Importar**. Se suben los modelos a tu cuenta (gratis).
5. En el **Explorador** aparece `CriasMiticas_Modelos` dentro de **Workspace**. Arrástralo dentro de **ServerStorage**
   y cámbiale el nombre (clic y **F2**) a **`Modelos`** (exactamente así).
6. Pulsa **Probar ▶**: deberías ver rocas y árboles de verdad. Mándale a Claude una captura.

## Para que no se pierdan con cada versión nueva

Cada versión nueva del juego es un `.rbxl` nuevo y la carpeta `Modelos` no viene dentro. Para no repetir los pasos:

7. Clic derecho en `Modelos` (en ServerStorage) → **Guardar en Roblox…** → **Crear nuevo** → nombre
   «Modelos Crías Míticas» → **Enviar**.
8. Creator Hub → **Creaciones → Modelos** → en «Modelos Crías Míticas» pulsa **⋯ → Copiar ID del recurso**.
9. Pásale ese número a Claude: lo pone en `Config.MODELS_ASSET_ID` y el juego los carga solo desde entonces.

## Si algo no sale

- Si tras el paso 6 sigue igual: mira en el Explorador que se llame `Modelos` y esté **en ServerStorage**
  (no en Workspace) y manda una captura del Explorador con `Modelos` desplegado.
- Si los colores salen raros o algún modelo no aparece, también: captura del Explorador.

Regenerar el archivo (Claude): `python3 -I tools/modelos/construir_pack.py` (descarga el kit y dibuja `vista_modelos.png`).
