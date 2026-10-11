# CLAUDE.md — «Estanterías Hechizadas» (`roblox-biblioteca/`)

Contexto completo de este juego para cualquier conversación nueva de Claude Code.
Léelo entero antes de tocar nada. (El `CLAUDE.md` de la raíz explica cómo trabajar con el usuario:
**léelo también, sobre todo §2, §8, §9, §10 y §11**.)

---

## 1. Qué es y en qué estado está

- **Juego de Roblox 3D en primera persona** (Luau): ordenar los 3.072 libros de una biblioteca mágica en
  31 secciones / 400 filas. Réplica fiel de las **mecánicas y números** de un simulador de Steam de 2026
  (ver `DISENO.md`); todo lo que tiene derechos de autor es **nuestro**. Nombre: *Estanterías Hechizadas* /
  *Spellbound Shelves* (`Config.GAME_NAME`). **No menciones el juego original ni a su estudio en la ficha.**
- **Versión: 0.9** (`Config.VERSION`; súbela en cada versión). **Juego completo (fases 1–6), NO publicado y
  pendiente de que el usuario lo pruebe en Studio.** Pídele capturas (sobre todo de *Output* si sale algo rojo).
- **Rama de trabajo:** `claude/biblioteca-arcana` (repo `candhu23/mi-priemra-web`). Si empiezas en `main` y
  la carpeta no existe: `git fetch origin claude/biblioteca-arcana && git checkout claude/biblioteca-arcana`.
- **Descarga directa del lugar:**
  `https://github.com/candhu23/mi-priemra-web/raw/claude/biblioteca-arcana/roblox-biblioteca/Biblioteca.rbxl`
- **Fases**: 1 datos ✅ · 2 edificio ✅ · 3 bucle jugable ✅ · 4 progresión ✅ · 5 partida completa ✅ ·
  6 plataforma y pulido ✅ · 7 tienda ✅ (aprobada por el usuario: pase de mecenas = color del brillo, mascota
  Garabato, temas de luz y 2 propinas; **solo cosmético o de apoyo, nada aleatorio ni que facilite el reto**).
  IDs en `Config.GamePasses` / `Config.Products` (0 = oculto; en Studio salen de «Muestra» y desbloqueados).
  El estado al día está en `DISENO.md` §18.

## 2. Documentos de esta carpeta

| Archivo | Para qué |
|---|---|
| `DISENO.md` | Todas las reglas y números, tabla original → nuestra versión, **supuestos** marcados, estado por fase |
| `README.md` | Guía para el usuario: probar en Studio, publicar como experiencia NUEVA, Max players 1, insignias (tabla con nombres/descripciones/imágenes), cuestionario, descripción ES/EN |
| `docs/` | Planos vistos desde arriba, `icono_juego.png` y `insignias/*.png` (512 × 512, los genera `tools/harness/icons.py`) |
| `CLAUDE.md` | Este archivo |

## 3. Estructura

```
roblox-biblioteca/
├── default.project.json   # Rojo: LockFirstPerson, sin salto (CharacterJumpHeight 0), andar 12,
│                          # StreamingEnabled=false, Lighting.Technology=Future (un script NO puede)
├── Biblioteca.rbxl        # Lo genera tools/check.sh (súbelo en cada commit)
├── docs/plan_planta1.png, plan_planta2.png   # planta vista desde arriba (la genera check.sh)
├── src/ReplicatedStorage/
│   ├── Config.luau        # TODOS los números (supuestos marcados): velocidades, capacidad, puntos,
│   │                      # hechizos por nivel, rangos, pizza, definitiva, guardado, luz, audio, insignias
│   ├── Lang.luau          # Textos ES/EN. Lang.t(lang, clave, params) con {param}; Lang.time()
│   ├── BookData.luau      # 31 secciones (paletas) + 400 series con títulos ES/EN y portadas. asserts de totales
│   ├── Layout.luau        # Geometría DETERMINISTA (generador propio con semilla): Layout.get("main"|"special")
│   │                      # → secciones, filas, huecos (slotCF), libros, montones iniciales, piezas del edificio,
│   │                      # cajas sólidas (solids) y puntos de interacción. Layout.face() en vez de CFrame.lookAt
│   ├── Rules.luau         # Fila correcta y brillos, puntos por récord, valores de hechizos, rango y final
│   ├── Codec.luau         # 8 caracteres por libro (guardado y foto inicial)
│   └── Geo.luau           # Rayos y superficies contra cajas (soltar/lanzar sin física)
├── src/ServerScriptService/
│   ├── LibraryServer.server.luau   # Construye el mundo, remotes (LibRemotes), jugador/invitados, bucle 1 s
│   └── Lib/                    # (Shop.luau: pases, propinas con ProcessReceipt idempotente, opciones con pase)
│       ├── Building.luau           # Piezas del edificio a partir de Layout (luces, puerta, spawn)
│       ├── Library.luau            # Estado de los libros de UNA biblioteca: sitios, mano, filas correctas,
│       │                           # récord, coger/colocar/soltar/lanzar (parábola contra cajas), deltas
│       ├── Game.luau               # Sesión, acciones validadas (distancia, capacidad, 25/s), estado, tutorial
│       ├── Magic.luau              # Manual (buySkill), hechizos (cast, autoPlace), llaves, cofres, cristal
│       ├── Data.luau               # DataStore EN pcall: perfil (opciones, logros, récord, especial, 3 ranuras)
│       └── Flow.luau               # Menú/ranuras, opciones, guardado agrupado, salida (rango y final),
│                                   # logros → insignias, fase especial (Archivo + definitiva)
├── src/StarterPlayerScripts/
│   ├── LibraryClient.client.luau   # Arranque: interfaz, remotes, tablones del mapa, bucle de cruceta
│   └── Client/
│       ├── Kit.luau                # ctx compartido + piezas (panel con botón Modal, botón, etiqueta, sonido)
│       ├── Books.luau              # Libros del cliente: cuerpo + franja, brillos, placas, etiquetas
│       │                           # reutilizables (36), Revelar (Neón), Guía (SelectionBox), animaciones
│       ├── Aim.luau                # Rayo de la cruceta → objetivo (libro, hueco, objeto) verde/rojo
│       ├── Input.luau              # Teclado/ratón/mando y ctx.input.* (usar, soltar, lanzar, rotar…)
│       ├── Hud.luau                # Contadores, cruceta, pila en mano, pistas, avisos, botones táctiles
│       ├── Panels.luau             # Carta/mensajes, lista de la mano (▲▼), mapa
│       ├── Spells.luau             # Barra de hechizos (1–5, enfriamientos), manual (B), efectos Guía/Revelar
│       ├── Menus.luau              # Título (Continuar, Nueva, 3 ranuras, Especial, Logros, Opciones), pausa (P),
│       │                           # opciones, logros, confirmación, evaluación, barra de la definitiva
│       ├── Ambience.luau           # Luz por tiempo de juego, modo acogedor, música por tramos, opciones,
│       │                           # balanceo de cabeza, cámara del menú
│       └── MapArt.luau             # Dibujo del mapa de una planta (tablones y ventana)
└── tools/   (bin/ y out/ en .gitignore)
    ├── setup.sh  check.sh
    └── harness/  mock.luau (Roblox simulado para Lune) · run_world.luau · run_server.luau · run_client.luau
                  · dump_data.luau · check_books.py · check_lang.py · plan.py + svg2png.js (planos)
                  · preview.py + preview_shot.js (vista previa APROXIMADA de la interfaz)
```

Rojo: `src/<Servicio>` → servicio; `*.server.luau` = Script, `*.client.luau` = LocalScript, resto = ModuleScript.

## 4. Arquitectura

- **El servidor manda** y guarda dónde está cada libro (`Lib/Library.luau`). Remotes en `ReplicatedStorage.LibRemotes`:
  - `Action` (RemoteFunction): `InvokeServer(acción, a, b, c)` → `(ok, claveTexto?, params?, extra?)`; `extra.sound`.
  - `Snapshot` (RemoteEvent): `(lib, cadena)` = foto de los libros (8 caracteres/libro, `Codec`). Se pide con `ready`.
  - `Delta` (RemoteEvent): lista de `{ id, código8, anim ("fly"|"throw"|""), desde: Vector3? }`.
  - `State` (RemoteEvent): estado pequeño (mode, lib, hand, cap, rows, best, rowsTotal, shelved, total, points,
    earned, nextAt, tut, time, door…) tras cada acción y cada 10 s.
  - `Notify` (RemoteEvent): `(tipo, clave, params)`; el cliente traduce (`popup` = ventana).
- **Acciones** (`Game.Actions`): `ready pick place drop dropAll throw cycle reorder readLetter exitDoor`
  + (Magic) `buySkill cast autoPlace takeKey openChest useCrystal` + (Flow) `selectSlot newGame deleteSlot toMenu
  setOption startSpecial ultimate`. Límite 25/s. `extra` puede traer `sound`, `spell`, `chest`/`reward`/`cap` (nota del cofre).
- Estado extra de la magia (`Game.stateHooks`): `skills{id=nivel} cd{id=s} active{id=s} keys chests jump run magic`.
  Los hechizos no guardan sus tiempos (al volver a entrar están listos). El enfriamiento empieza al acabar el efecto.
- Llaves cogidas y cofres abiertos: el servidor oculta las piezas (`Building.setVisible`, también la luz de la llave).
- Parámetros de avisos que son claves de texto (`sk_sort`, `key_red`) los traduce el cliente; `key = "B"` = tecla del manual.
  **Si añades una acción, añádela a `run_server.luau`.**
- Los **libros los crea el cliente** (cuerpo + franja, anclados, sin colisión); el edificio lo crea el servidor.
  Las filas y placas las calcula también el cliente con `Rules` (mismas reglas) para los brillos y sonidos.
- **Modos** (`s.mode`): `menu` (título; la biblioteca de la última ranura se ve de fondo, el personaje quieto),
  `main` (ranura `slotIndex`; solo aquí corre el tiempo) y `special` (el Archivo; no se guarda).
- **Guardado** (`Flow`): `dirty` + escritura como mucho cada 30 s (`SAVE_MIN_INTERVAL`); disparadores: fila hecha,
  llave/cofre, menú, cada 50 libros; cada 2 min si solo pasa el tiempo; al salir y en `BindToClose` (espera los 6 s
  de DataStore). Perfil de unos 25 KB por ranura usada. Carga fallida → `canSave = false` y aviso.
- **Salida** (`exitDoor` → `Game.onExit`): `extra.results = { kind, time, rows, total, magic, keys, best, newBest,
  rank, ending, endings }`; marca la ranura terminada, desbloquea la fase especial y da los logros de final.
- **Tutorial** (`slot.tut`): 0 leer carta · 1 coger del montón · 2 colocar en 1A · 3 una serie bien · 4 las dos
  (pista libre hasta 60 libros en estanterías).
- Cliente: `Kit.ctx` (state, lang, panel, act, toast, openPanel, closePanel, input, keyName, targets,
  refreshers, tickers). Diseño en 1280 × 720 con `UIScale`; en táctil hay botones y la pila va arriba a la izquierda.

## 5. Verificación (OBLIGATORIO antes de cada commit)

```bash
cd roblox-biblioteca && tools/check.sh   # la 1.ª vez descarga las herramientas (tools/setup.sh)
```

1. `luau-compile` de cada archivo (sintaxis y límite de 200 locales).
2. `luau-lsp analyze` con la API de Roblox → **0 avisos**.
3. `dump_data.luau` + `check_books.py`: recuentos de la tabla, títulos únicos ES/EN, ≤ 70 caracteres,
   **palabra clave de su sección** en cada título, portadas distintas, **palabras prohibidas** (también en Lang).
4. `run_world.luau`: edificio real + libros del cliente: 31 secciones, 400 filas con sus huecos ordenados de
   izquierda a derecha, 3.072 libros con sitio inicial, **ninguno dentro de paredes/muebles**, ninguno flotando,
   nunca dos tomos de la misma serie juntos, llaves (roja de pie; amarilla y azul solo saltando; verde tapada),
   salto a la planta 2, **piezas totales < 15.000** (hoy 10.562 en el peor caso) y codec de ida y vuelta.
   Después dibuja los planos (`plan.py` + Playwright).
5. `run_server.luau`: modo `sin-datastore` (se juega sin guardar, con aviso) y `normal`: menú → ranura 1: tutorial,
   errores (manos vacías/llenas, hueco ocupado, lejos, 25 acciones/s), soltar/lanzar, llaves y cofres, cristal,
   hechizos; **guarda, sale y vuelve a entrar: estado idéntico**; coloca bien los 3.072 libros → puerta → final
   Pizza, rango 6. Ranura 2 todo mal → ¡Despedido!. Ranura 3 sin magia → A la antigua. Fase especial con la
   definitiva. 12 logros = 12 insignias, opciones, borrar ranura.
6. `run_client.luau` (`pc` y `movil`): servidor + cliente reales: menú de título → nueva partida; cruceta (rayo
   simulado) sobre la carta, un libro, su hueco, un cofre y la puerta; teclas; manual, pausa, opciones (cambio a
   inglés: la interfaz se rehace), logros, evaluación, fase especial; pulsa todos los botones. Vuelca la interfaz y `preview.py`
   saca `tools/out/preview/*.png` (aproximado: mira los PNG tras cambios visuales).
7. Copia el lugar a `Biblioteca.rbxl`. **Súbelo en el commit.**

## 6. Trampas encontradas (no las repitas)

- **Lune: `CFrame.lookAt` mirando exactamente a +Z devuelve la orientación al revés.** Usa `Layout.face(pos, dir)`
  (giro en Y) en todo lo que se pruebe con Lune.
- **Lune: `Part.Position` no existe** («missing default value»): usa `part.CFrame.Position`.
- Libros tumbados en escalones: alinéalos con el escalón (si no, asoman dentro del siguiente; `run_world` lo detecta).
- El analizador no «ensancha» una variable tras `if not x then x = … end`: usa una variable nueva
  (`local existing = t[k]; if existing then return existing end; local x = Instance.new(…)`).
- `assert(x, msg)` devuelve 2 valores: no lo pases como último argumento de una función.
- **Lune: no se puede asignar `nil` a una propiedad de referencia** (`gui.Adornee = nil` falla): desactiva el objeto.
- Ventanas: la tarjeta lleva `Active = true`; si no, el clic atraviesa al fondo (que cierra la ventana).
- Los RemoteEvent disparados antes de que el cliente conecte se pierden en las pruebas: el cliente pide la foto
  con la acción `ready` cuando ya está escuchando.
- Mando: al abrir una ventana, `selectFirst` pone `GuiService.SelectedObject` en su primer botón; **B** cierra.
- **Lune: los `Enum` no sirven como clave de tabla** (cada acceso es un objeto nuevo): usa `key.Name`.
- El simulador de remotes conserva los `nil` en medio de lo que devuelve una acción (como Roblox): `(true, nil, nil, extra)`.
- En el simulador, `task.wait` en el hilo de la prueba solo avanza el reloj (si durmiera, la prueba se pararía sin
  error, p. ej. al salir el servidor espera los 6 s de DataStore).
- Cambiar idioma o «zurdos» rehace la interfaz (`ctx.rebuild`): no guardes referencias a objetos de la interfaz
  entre medias (en las pruebas, vuelve a buscarlos).
- El reloj de las pruebas no avanza solo: suma `W.fakeTime` entre pulsaciones o salta el límite de 25 acciones/s.
- En móvil: abajo a la izquierda está el joystick y abajo a la derecha el botón de saltar de Roblox; arriba a la
  izquierda, los botones de Roblox. No pongas nada ahí.

- Tablas literales con un campo que se rellena después (p. ej. `series`) no encajan con su tipo exportado:
  conviértelas con `(… :: any) :: Tipo`.
- Palabras clave: `check_books.py` exige que una palabra del título **empiece** por la clave (sin tildes);
  si añades títulos, comprueba que llevan una de su sección.

## 7. Pendiente

- [ ] El usuario prueba en Studio (PC y móvil simulado) y manda capturas. Lo no verificado está en `DISENO.md` §18.
- [ ] Publicar como **experiencia nueva**, Max players = 1, API Services, icono (`docs/icono_juego.png`).
- [ ] Crear las 12 insignias (5 gratis cada 24 h, imágenes en `docs/insignias/`) y poner sus IDs en `Config.Badges`.
- [ ] Opcional: música con licencia de la Creator Store → `Config.Music` (4 tramos).
- [ ] Tienda: el usuario crea los 3 pases y 2 productos (README §2.5) y manda los IDs → `Config.GamePasses` /
      `Config.Products`. No añadir nada que acelere el reto ni nada aleatorio de pago.

## 8. Convenciones

- Código y comentarios en **español**, tabs, estilo del archivo. Commits en español en la rama de §1 con las
  líneas de atribución del sistema. Sin identificadores de modelo de IA en commits ni código. No crear PR
  salvo que el usuario lo pida.
- Tras cambios visibles: explica qué cambia, qué verificaste, qué NO (no hay Studio) y tu % de confianza.
