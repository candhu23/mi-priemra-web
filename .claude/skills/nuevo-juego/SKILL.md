---
name: nuevo-juego
description: Crea un juego de Roblox NUEVO en este repo en minutos, a partir de una plantilla probada — Rojo, servidor con remotes seguros y límites, guardado en DataStore a prueba de fallos, compras idempotentes, textos en español e inglés, interfaz con buen diseño (botones gruesos, escala para móvil) y verificación completa (tipos, bot que juega, guardar/cargar, capturas y auditoría de diseño). Úsala cuando el usuario diga "haz un juego nuevo", "quiero otro juego de…", "empieza un tycoon/simulador de…".
---

# nuevo-juego — de idea a juego jugable y verificado

## Pasos

1. **Idea** (máx. 2 preguntas al usuario si no la ha dicho): tema y nombre en español e inglés. Comprueba
   que no copia un juego existente (nombre, logo, personajes) — el usuario lo pidió con AeroCarga.
2. **Rama**: `git checkout -b claude/<nombre-corto>` desde `main` (o la que asigne el sistema).
3. **Crear**: `python3 -I .claude/skills/nuevo-juego/crear_juego.py roblox-<nombre> "<Nombre ES>" "<Nombre EN>"`
   → copia `plantilla/`, rellena nombres, lo registra en `roblox-nube/juegos.json` y reutiliza las
   herramientas ya descargadas. El hook de inicio instala `tools/bin` de cualquier carpeta con `tools/setup.sh`.
4. **Verificar tal cual**: `roblox-<nombre>/tools/check.sh` → debe dar `TODO CORRECTO ✅` (la plantilla sale
   con 0 avisos de tipos, bot OK, guardar/cargar OK y 0 problemas de diseño en PC y móvil).
5. **Darle su identidad** con la skill `disenar-juego`: rellena `DISENO.md`, cambia en `Config.luau` los
   negocios/números/colores y en `Lang.luau` los textos (ES y EN), añade la mecánica propia del juego.
   Tras cada cambio: `tools/check.sh` y mirar las capturas (`tools/out/vista*/`) con la skill `disenar-interfaz`.
6. **Arte**: icono, miniatura e iconos de pases con `arte-roblox`.
7. Commit + push (con el `.rbxl`), y al usuario: enlace de descarga, pasos de Studio (README del juego) y
   las capturas aproximadas. Su primera publicación es en Studio (*Publish As → experiencia nueva*);
   después pon `universeId`/`placeId` en `juegos.json` y publicar ya lo hace `/publicar`.
8. Añade el juego a la tabla §0 del `CLAUDE.md` de la raíz.

## Qué trae la plantilla (y por qué)

| Pieza | Qué evita |
|---|---|
| `Data.luau`: `GetDataStore` y todo el guardado en `pcall`, 3 reintentos, `canSave=false` si falla la carga | El fallo de AeroCarga v0.1 (servidor parado en Studio sin publicar) y machacar partidas buenas |
| `reconcile()` | Partidas viejas sin los campos nuevos |
| `ProcessReceipt` con `receipts` y confirmar solo tras guardar | Cobrar sin dar, o dar dos veces |
| Acciones validadas en el servidor + límite 10/s (clic 15/s) | Trampas y spam desde el cliente |
| `Lang.luau` + `check_lang.py` | Textos sin traducir (Web Empire está solo en español) |
| `UI/Kit.luau`: escala 960×540 con mínimo 0,7, `Kit.fit` (el texto se encoge, no se corta), botones ≥ 44 px | Texto ilegible y botones diminutos en móvil |
| `run_juego.luau` + `mock.luau` | Probar el juego completo sin Studio |
| `volcado.luau` + `check.sh` paso 5 | Ver las pantallas (PC y móvil) y auditarlas en cada verificación |

La economía de ejemplo (pulsar → negocios → ingresos pasivos → diario) es un punto de partida: cámbiala.
Si añades una acción al servidor, pruébala en `run_juego.luau`.
