---
name: publicar
description: Saca una versión nueva de uno de los juegos de Roblox del repo (Web Empire Tycoon o AeroCarga España) de principio a fin — verificación completa, subir la versión en el código, regenerar el .rbxl, commit y push, prueba en un servidor real de Roblox, publicación (con la clave Open Cloud) o pasos de Studio de clic en clic (sin ella), y notas de la versión en español e inglés. Úsala cuando el usuario diga "publica", "sube la versión", "saca la actualización", "ya está, súbelo al juego" o escriba /publicar.
---

# /publicar — sacar una versión nueva

Argumento opcional: `imperio` o `aerocarga`. Si no lo dice, dedúcelo de la conversación (CLAUDE.md §0); si
hay duda, pregunta con una sola pregunta de opciones.

## Pasos (en orden; si uno falla, para y explícalo)

1. **Rama correcta.** `git fetch` y `git checkout` de la rama del juego (`.claude/skills/roblox-nube/juegos.json`
   → `rama`), salvo que el sistema te haya asignado otra (dilo). `git status` limpio o con cambios que sean
   de esta versión. Si al cambiar de rama desaparece `.claude/` (la rama aún no lo tiene), tráelo con
   `git checkout origin/main -- .claude` y súbelo en el mismo commit.
2. **Número de versión.** Sube `Config.VERSION` (Imperio: `src/ReplicatedStorage/TycoonConfig.luau`;
   AeroCarga: `src/ReplicatedStorage/Config.luau`) y actualiza el CLAUDE.md del juego si cambia algo que
   documenta. Cambio pequeño → +0.1; si el usuario lo llama «gran actualización» → siguiente entero.
3. **Verificación completa:** `cd <carpeta> && tools/check.sh` → tiene que acabar en `TODO CORRECTO ✅`
   (regenera el `.rbxl`). Si no, arregla y repite. No sigas con fallos.
3b. **Revisión antes de subir** (automático, no lo saltes):
   - Agente `revisor-juego` sobre el diff de esta versión → arregla lo 🔴 y 🟠 antes de seguir.
   - Si cambió algo visible: capturas y auditoría con la skill `disenar-interfaz` (PC y móvil); mira las
     capturas y corrige lo grave (texto cortado/tapado, fuera de pantalla).
   - `python3 -I .claude/skills/disenar-juego/mapa_juego.py <carpeta>`: ninguna acción nueva sin probar (❌).
4. **Commit y push** del código + `.rbxl` (mensaje en español, atribución del sistema; nunca identificadores
   de modelo). `git push -u origin <rama>`.
5. **¿Hay clave Open Cloud?** `python3 -I .claude/skills/roblox-nube/roblox_cloud.py estado <juego>`.
   - **Sí** → `… probar <juego>` (guarda una versión NO publicada y la prueba en un servidor real).
     Si da `PRUEBA REAL OK ✅`, enséñale al usuario el resumen (versión, qué cambia, avisos) y **pregunta
     si publicar ya**. Con su «sí»: `… publicar <juego> --confirmo --reiniciar --minutos 5`
     (los servidores viejos se vacían en 5 min; si hay pocos jugadores o es urgente, sin `--minutos`).
   - **No** (o el juego no tiene IDs, como AeroCarga antes de su primera publicación) → dale los pasos de
     Studio de clic en clic (CLAUDE.md raíz §10 / README del juego) con el enlace directo al `.rbxl`
     de su rama, y menciónale una vez que con la clave (skill `roblox-nube` §4) esto lo harías tú.
6. **Notas de la versión**, cortas y sin exagerar (nada de «gratis», «Robux gratis» ni promesas falsas —
   normas de Roblox):
   - 3–5 viñetas en **español** y lo mismo en **inglés** (la ficha del juego está en inglés), para la
     descripción del juego / Discord.
   - Una línea tipo «🆕 v1.3: …» para poner al principio de la descripción.
   - Si es una actualización grande: miniatura nueva con etiqueta «🆕 UPDATE» (skill `arte-roblox`).
7. **Resumen final al usuario** (formato de CLAUDE.md §13): qué cambia para el jugador, qué verificaste
   (check.sh, prueba real), qué NO pudiste verificar (no hay Studio aquí: aspecto visual exacto, móvil,
   compras reales), tu % de confianza y cómo volver atrás si algo sale mal (skill `roblox-nube` §3).

## No hagas

- Publicar sin `TODO CORRECTO ✅` ni sin el «sí» del usuario en esta conversación.
- Crear productos/pases o cambiar precios dentro de este flujo sin pedirlo aparte.
- Usar «Publish As» → *nuevo lugar* para un juego ya publicado (el lugar de inicio no se puede cambiar).
