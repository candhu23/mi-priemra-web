# Prompt para PowerShell — juego tipo «Collect All Pets» (Crías Míticas)

## Antes de nada (una sola vez)

```powershell
# 1) Instalar Claude Code (si no lo tienes)
irm https://claude.ai/install.ps1 | iex

# 2) Bajar el repo y ponerte en la rama del juego
git clone https://github.com/candhu23/mi-priemra-web.git
cd mi-priemra-web
git checkout claude/confident-johnson-v5zy5f
```

> OJO: las herramientas de verificación del repo (`tools/check.sh`, `setup.sh`) son para Linux/bash.
> En Windows hay que ejecutarlas dentro de **WSL** (Ubuntu) o dejar que Claude lo haga en la nube.

## El comando (pégalo entero en PowerShell, dentro de la carpeta del repo)

```powershell
$prompt = @'
Lee CLAUDE.md (raíz) y roblox-crias-miticas/CLAUDE.md. Trabaja en roblox-crias-miticas/ en la rama
claude/confident-johnson-v5zy5f. Usa las skills disenar-juego, disenar-interfaz y arte-roblox.

OBJETIVO: convertir «Crías Míticas» en un juego de Roblox del estilo «Collect All Pets»
(coleccionar mascotas). Quiero la MISMA IDEA DE JUEGO, pero con nombres, arte y textos ORIGINALES
(no copies nombres, imágenes ni sonidos del juego original).

BUCLE QUE QUIERO (adáptalo si ves algo mejor, y dime por qué):
1. Zonas/mundos con monedas y objetos que recoger; las mascotas equipadas siguen al jugador y los recogen solas.
2. Huevos que se compran con monedas; al abrirlos sale una mascota con rareza (Común, Poco común, Raro, Épico, Legendario, Mítico).
3. Mejorar mascotas (fusionar duplicadas), equipar las mejores (límite de huecos), inventario y colección (álbum).
4. Renacer (rebirth) con multiplicadores permanentes y zonas nuevas que se desbloquean.
5. Recompensa diaria, misiones, y un 'Colecciona todas' con progreso visible.
6. Tienda con Game Passes (x2 monedas, más huecos de mascotas, auto-abrir huevos) con id = 0 hasta crearlos.

REGLAS:
- Probabilidades de los huevos VISIBLES para el jugador (norma de Roblox).
- Nada engañoso; monetización legítima. El servidor manda; el cliente solo muestra.
- Guardado a prueba de fallos, textos ES/EN, interfaz legible en móvil.
- Antes de programar, rellena roblox-crias-miticas/DISENO.md y enséñamelo para que lo apruebe.
- Después de programar: ejecuta roblox-crias-miticas/tools/check.sh (hasta 0 avisos y TODO OK),
  usa el agente revisor-juego, haz commit y push a la misma rama.
- Háblame en español claro, sin jerga. Dime qué verificaste, qué NO pudiste verificar y tu % de confianza.
'@

claude $prompt
```

Si prefieres ir paso a paso, empieza solo con el diseño: cambia la última línea por
`claude "Lee CLAUDE.md y roblox-crias-miticas/CLAUDE.md y rellena DISENO.md para un juego tipo Collect All Pets. No programes todavía."`
