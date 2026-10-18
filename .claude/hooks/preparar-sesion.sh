#!/bin/bash
# Al empezar una sesión en la nube: deja listas las herramientas de verificación de cada
# juego (luau-lsp, luau, rojo, lune → <juego>/tools/bin) y dice si Open Cloud está listo.
# Lo que se imprime aquí lo lee Claude al empezar. Nunca bloquea la sesión si algo falla.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

RAIZ="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$RAIZ" || exit 0

# Cualquier carpeta de juego con tools/setup.sh (también los creados con la skill nuevo-juego)
for setup in */tools/setup.sh; do
	[ -f "$setup" ] || continue
	juego="${setup%%/*}"
	if [ -x "$juego/tools/bin/lune" ] && [ -x "$juego/tools/bin/rojo" ]; then
		echo "[$juego] herramientas ya instaladas"
	elif bash "$setup" > "/tmp/setup-$juego.log" 2>&1; then
		echo "[$juego] herramientas instaladas (tools/bin)"
	else
		echo "[$juego] ⚠️ no se pudieron instalar las herramientas (ver /tmp/setup-$juego.log); tools/check.sh lo reintentará"
	fi
done

if [ -n "${ROBLOX_API_KEY:-}" ]; then
	echo "Open Cloud: ROBLOX_API_KEY presente → puedes publicar/probar con la skill roblox-nube"
else
	echo "Open Cloud: sin ROBLOX_API_KEY → publicar es manual desde Studio (ver skill roblox-nube para activarlo)"
fi
exit 0
