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
- **Versión: 0.1** (`Config.VERSION`; súbela en cada versión). **No publicado.**
- **Rama de trabajo:** `claude/biblioteca-arcana` (repo `candhu23/mi-priemra-web`). Si empiezas en `main` y
  la carpeta no existe: `git fetch origin claude/biblioteca-arcana && git checkout claude/biblioteca-arcana`.
- **Descarga directa del lugar:**
  `https://github.com/candhu23/mi-priemra-web/raw/claude/biblioteca-arcana/roblox-biblioteca/Biblioteca.rbxl`
- **Fases** (cada una con commit + push y aviso al usuario): 1 datos y documentos ✅ · 2 edificio y libros ·
  3 bucle principal jugable · 4 progresión · 5 partida completa · 6 plataforma y pulido · 7 monetización
  (**solo si el usuario la aprueba**; el original es de pago y no vende ventajas: nada aleatorio de pago).
  El estado al día está en `DISENO.md` §18.

## 2. Documentos de esta carpeta

| Archivo | Para qué |
|---|---|
| `DISENO.md` | Todas las reglas y números, tabla original → nuestra versión, **supuestos** marcados, estado por fase |
| `README.md` | Guía para el usuario: probar en Studio, publicar como experiencia NUEVA, insignias, cuestionario |
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
│   ├── LibraryServer.server.luau   # Fase 2: construye la biblioteca y el Archivo
│   └── Lib/Building.luau           # Piezas del edificio a partir de Layout (luces, puerta, spawn)
├── src/StarterPlayerScripts/
│   ├── LibraryClient.client.luau   # Fase 2: dibuja los libros en sus montones iniciales
│   └── Client/Books.luau           # Libros del cliente: cuerpo + franja, brillos, placas, etiquetas
│                                   # reutilizables (36), Revelar (Neón), Guía (SelectionBox), animaciones
└── tools/   (bin/ y out/ en .gitignore)
    ├── setup.sh  check.sh
    └── harness/  mock.luau (Roblox simulado para Lune) · run_world.luau · dump_data.luau · check_books.py
                  · plan.py + svg2png.js (planos)
```

Rojo: `src/<Servicio>` → servicio; `*.server.luau` = Script, `*.client.luau` = LocalScript, resto = ModuleScript.

## 4. Arquitectura prevista (se completa en las fases 2–6)

- **El servidor manda** y guarda dónde está cada libro. El cliente pide acciones por `RemoteFunction`
  (lista en `DISENO.md` §15) y recibe **una foto** (misma cadena que el guardado) + **deltas**.
- Módulos compartidos previstos: `Layout.luau` (geometría determinista: secciones, filas, huecos, montones
  iniciales con semilla propia, cajas sólidas), `Rules.luau` (validación de filas, brillos, puntos, rangos),
  `Codec.luau` (8 caracteres por libro), `Geo.luau` (rayos contra cajas para soltar y lanzar).
- Los **libros los crea el cliente** (cuerpo + franja, anclados, sin colisión); el edificio lo crea el servidor.

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
5. Servidor con bots (fase 3+) · 6. Cliente (fase 3+): se saltan con «pendiente» hasta que existan.
7. Copia el lugar a `Biblioteca.rbxl`. **Súbelo en el commit.**

## 6. Trampas encontradas (no las repitas)

- **Lune: `CFrame.lookAt` mirando exactamente a +Z devuelve la orientación al revés.** Usa `Layout.face(pos, dir)`
  (giro en Y) en todo lo que se pruebe con Lune.
- **Lune: `Part.Position` no existe** («missing default value»): usa `part.CFrame.Position`.
- Libros tumbados en escalones: alinéalos con el escalón (si no, asoman dentro del siguiente; `run_world` lo detecta).
- El analizador no «ensancha» una variable tras `if not x then x = … end`: usa una variable nueva
  (`local existing = t[k]; if existing then return existing end; local x = Instance.new(…)`).
- `assert(x, msg)` devuelve 2 valores: no lo pases como último argumento de una función.

- Tablas literales con un campo que se rellena después (p. ej. `series`) no encajan con su tipo exportado:
  conviértelas con `(… :: any) :: Tipo`.
- Palabras clave: `check_books.py` exige que una palabra del título **empiece** por la clave (sin tildes);
  si añades títulos, comprueba que llevan una de su sección.

## 7. Pendiente

- [ ] Fases 2–6 (ver `DISENO.md` §18). Fase 7 solo con aprobación del usuario.
- [ ] Elegir música con licencia en la Creator Store y poner los IDs en `Config.Music`.
- [ ] Crear las 12 insignias (5 gratis cada 24 h) y poner sus IDs en `Config.Badges`.

## 8. Convenciones

- Código y comentarios en **español**, tabs, estilo del archivo. Commits en español en la rama de §1 con las
  líneas de atribución del sistema. Sin identificadores de modelo de IA en commits ni código. No crear PR
  salvo que el usuario lo pida.
- Tras cambios visibles: explica qué cambia, qué verificaste, qué NO (no hay Studio) y tu % de confianza.
