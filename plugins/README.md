# Plugins de Claude para juegos de Roblox

## ⭐ `equipo-roblox`: tu equipo de 5 agentes (en cualquier proyecto)

Álex (jefe), Nico (diseño), Leo (programación), Vega (interfaz y pruebas) e Iris (jugadores y lanzamiento), más el
revisor, `/equipo-roblox:equipo` y las skills `nuevo-juego`, `disenar-juego`, `disenar-interfaz` y `arte-roblox`.
Detalles: `equipo-roblox/README.md`.

- **Instalar en claude.ai** (todas las sesiones, también en la nube): descarga `zips-para-claude-ai/equipo-roblox.zip`
  → claude.ai → **Personalizar → Plugins → Añadir → Subir plugin**. Ojo: este va en **Plugins**, no en Skills,
  porque lleva agentes (los otros 10 zips son skills sueltas).
- **En tu PC**: `claude plugin install equipo-roblox@candu-roblox` (tras añadir el marketplace, ver B).
- **Mantenimiento**: la fuente es `.claude/agents` y `.claude/skills` del repo; tras cambiarlos,
  `python3 -I plugins/construir_equipo_roblox.py` (regenera `equipo-roblox/` y su zip) y vuelve a subir el zip.

---

## 10 plugins de interfaz y 3D

Todos en español, pensados para que Claude haga interfaces bonitas que funcionen en móvil y cosas 3D con buen aspecto,
y para que pueda **verlas sin abrir Studio** (capturas PNG).

| Plugin | Qué hace | Herramientas |
|---|---|---|
| `roblox-ui-estilo` | Tema de colores con contraste comprobado, reglas de estilo, revisor del código de la UI | `tema.py`, `revisar_ui.py` |
| `roblox-ui-componentes` | Botones gruesos, ventanas, pestañas, barras, contador de monedas, rejillas, avisos… | `UIKit.luau` |
| `roblox-ui-pantallas` | HUD, tienda, inventario de mascotas, apertura de huevo, recompensa, tutorial + capturas sin Studio | `Pantallas.luau`, `probar_pantallas.luau`, `ver_interfaz.py` |
| `roblox-ui-movil` | Escala, táctil/ratón/mando, zona segura, zona del pulgar, medidas para el dedo | `Adaptable.luau` |
| `roblox-ui-animaciones` | Rebotes, sacudidas, latidos, contadores, textos flotantes, brillos, confeti | `Animar.luau` |
| `roblox-3d-construir` | Construir con código: casas, árboles, vallas, caminos, puertas de zona, pedestales, islas | `Constructor.luau` |
| `roblox-3d-mallas` | Modelos 3D low-poly para importar (huevo, moneda, gema, cofre, mascota…) | `mallas.py` → `.glb`/`.obj`/`.png` |
| `roblox-3d-terreno` | Islas, colinas, agua, ríos, montañas, zonas de simulador, reparto natural | `Terreno.luau` |
| `roblox-3d-ambiente` | 8 ambientes de luz, día/noche, partículas, auras por rareza, estelas, neón | `Ambiente.luau` |
| `roblox-3d-vista` | Dibuja en PNG lo construido (o un .rbxlx/.rbxmx) y avisa de parpadeos y piezas sueltas | `volcar.luau`, `vista3d.py` |

## Cómo tenerlos en CUALQUIER proyecto nuevo

### A) En claude.ai y en las sesiones de Claude Code en la nube (recomendado)
Las skills que activas en claude.ai se cargan solas en **todas** las sesiones nuevas, de cualquier repositorio.
1. Descarga los 10 `.zip` de `plugins/zips-para-claude-ai/` (en GitHub: entra en cada archivo → botón de descarga).
2. claude.ai → **Ajustes → Capacidades** → activa la ejecución de código si no lo está → **Skills → Subir skill** → sube cada `.zip`.
3. Comprueba que están activadas (interruptor encendido).

### B) Claude Code en tu PC (PowerShell)
```powershell
claude plugin marketplace add candhu23/mi-priemra-web#claude/confident-johnson-v5zy5f
claude plugin install roblox-ui-estilo@candu-roblox
claude plugin install roblox-ui-componentes@candu-roblox
claude plugin install roblox-ui-pantallas@candu-roblox
claude plugin install roblox-ui-movil@candu-roblox
claude plugin install roblox-ui-animaciones@candu-roblox
claude plugin install roblox-3d-construir@candu-roblox
claude plugin install roblox-3d-mallas@candu-roblox
claude plugin install roblox-3d-terreno@candu-roblox
claude plugin install roblox-3d-ambiente@candu-roblox
claude plugin install roblox-3d-vista@candu-roblox
```
Se instalan para tu usuario (todos tus proyectos del PC). Si el repo es privado, antes: `gh auth login` y `gh auth setup-git`.
Cuando esta rama se una a `main`, puedes quitar `#claude/confident-johnson-v5zy5f`. Para actualizar: `claude plugin marketplace update candu-roblox`.
Ojo: las herramientas de capturas (Lune, Chromium) son para Linux; en Windows úsalas desde WSL o deja que Claude las ejecute en la nube.

### C) En este repositorio
Ya están en `.claude/skills/` (copia). Se usan solas.

## Mantenimiento
La fuente de verdad es `plugins/<nombre>/skills/<nombre>/`. Después de cambiar algo:
```bash
plugins/sincronizar.sh        # copia a .claude/skills/ y rehace los .zip
claude plugin validate .      # comprueba el marketplace
```
Y vuelve a subir a claude.ai los `.zip` que hayan cambiado.

## Capturas de ejemplo

`plugins/capturas/`: catálogo de mallas, pueblo dibujado con vista3d (4 vistas), inventario en móvil y apertura de huevo en PC.

## Qué está comprobado (y qué no)
- Módulos Luau: compilan y pasan `luau-lsp` con los tipos de Roblox sin avisos; UIKit, Animar, Adaptable, Pantallas, Constructor y Ambiente se ejecutaron en Lune con instancias reales (nombres y tipos de propiedades válidos).
- Pantallas fotografiadas en 1280×720 y 844×390 sin problemas graves; mallas leídas con un lector glTF/OBJ externo; marketplace validado e instalado con `claude plugin install`.
- **No** probado dentro de Roblox Studio (no hay Studio en la nube): Terrain, el importador 3D y el aspecto exacto de luces y fuentes hay que mirarlos allí.
