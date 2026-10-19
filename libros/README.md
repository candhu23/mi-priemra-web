# Libros

Aquí van los libros que escribimos juntos. Cada libro tiene su carpeta (la crea la skill `libro-biblia`):

```
libros/<titulo>/
├── BIBLIA.md     memoria del libro: idea, voz, personajes, mundo, línea temporal, continuidad
├── PLAN.md       estructura y escaleta capítulo a capítulo
├── ESTADO.md     en qué punto está cada capítulo y decisiones del autor
├── capitulos/    01-titulo.md, 02-titulo.md…
└── revision/     informes del analizador y del lector beta
```

## Los 5 plugins de escritura (en `.claude/skills/`)

| Plugin | Para qué |
|---|---|
| `libro-biblia` | Memoria del libro + `crear_libro.py` + `comprobar_continuidad.py` (nombres sin documentar, erratas de nombres, personajes olvidados) |
| `libro-plan` | Estructura según el género y escaleta con objetivo, conflicto, giro y gancho por capítulo |
| `libro-escribir` | Reglas de oficio para redactar cada capítulo (escenas, mostrar, diálogo, ritmo, español RAE) y rutina de después |
| `libro-revisar` | Editor en 4 pasadas + `analizar_texto.py` (legibilidad INFLESZ, ritmo, repeticiones, muletillas, giros de IA, diálogos con raya, dequeísmo…) |
| `libro-lector` | Lector beta independiente que solo lee los capítulos (agente `lector-beta` en `.claude/agents/`) |

Flujo: **biblia → plan → (escribir → revisar → actualizar biblia) por capítulo → lector beta cada 3–5 capítulos**.

## Usarlos también en claude.ai (chat normal, móvil)

En `skills-para-claude-ai/` hay un `.zip` por plugin. En claude.ai: **Ajustes → Capacidades → Skills →
Subir skill** y sube cada `.zip` (hace falta tener activada la ejecución de código). Allí no hay agentes,
así que `libro-lector` hace la lectura en una pasada aparte.
