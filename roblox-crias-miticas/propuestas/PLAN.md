# PLAN vivo — Crías Míticas (Mythic Hatchlings)

Jefe: Álex · Rama: `claude/confident-johnson-v5zy5f` · Actualizado: 2026-10-26

## Objetivo del usuario
«Haz uso de todos los agentes»: que todo el equipo mejore el juego. Antes: islas no rectas, estilo Collect All Pets
→ camino en S (hecho, commit 9aec32c).
**Éxito cuando:** las mejoras aprobadas por el usuario para la primera sesión/retención están programadas,
`tools/check.sh` = TODO CORRECTO ✅, revisor APTO, `.rbxl` regenerado y subido, y el usuario tiene los pasos para
probarlo en Studio.

## Presupuesto (el usuario se quedó sin créditos una vez)
1 ronda de ideas (Nico) · 1 de programación (Leo, máx. 2 ideas pequeñas) · 1 pasada de Vega solo si hay pantalla nueva ·
1 revisión · commit. Nada más sin preguntar.

## Rondas
| # | Quién | Qué | Estado |
|---|---|---|---|
| 0 | Iris | Ficha ES/EN, arte, plan 3 semanas, vídeos, notas v0.3 | ✅ commit 3a78e24 |
| 0 | Hilo | Camino en S (World.luau) | ✅ commit 9aec32c (.rbxl sin regenerar) |
| 1 | Vega | Jugar como 3 jugadores + pulir (Client, Mundo3D, Lang) | ⏳ en curso (sin subir) |
| 1 | Nico | Ideas: (c) momento raro I4E2R1, (b) invitar I3E1R1, (d) montón dorado I3-4E3R1; (a) grupo 🗑️ | ✅ fichas c y b; falta ficha d |
| 2 | Usuario | Eligió (c) Gran momento + (d) Montón Dorado; NO invitar | ✅ |
| 3 | Leo | (c) y luego (d) + ritmo antes/después + check.sh | ⏳ espera a Vega y a la ficha d |
| 4 | Vega | 2.ª pasada: ventana de huevo raro, aviso del servidor, cartel del Montón Dorado (PC+móvil) | previsto (sí hace falta) |
| 5 | Revisor | APTO / NO APTO de todo el diff (Vega + Leo) | — |
| 6 | Hilo | Commit + push con `.rbxl`, pasos de Studio al usuario | — |

## Decisiones y notas
- Bonus de grupo +10 %: crear un grupo cuesta ≈100 Robux (plan de Iris) y el usuario tiene ~7 → poco valor ahora.
  Si se programa, con `GROUP_ID = 0` (desactivado) y coste mínimo.
- Lo más incierto: nadie lo ha probado en Studio (crías siguiendo, puertas, camino en S). Prioridad alta tras el commit.
- Recordatorio de normas: nada de premios en Robux, probabilidades visibles, no vender huevos ni suerte (DISENO §6).
