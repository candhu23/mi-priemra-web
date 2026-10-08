#!/usr/bin/env bash
# Verificación completa de Air Cargo Empire. Ejecutar: roblox-carga-aerea/tools/check.sh
# Sale con error si algo falla. Genera AirCargo.rbxl al final si todo va bien.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/bin"
OUT="$ROOT/tools/out"
SRC="$ROOT/src"
mkdir -p "$OUT"
[ -x "$BIN/lune" ] || "$ROOT/tools/setup.sh"
status=0

echo "== 1/5 Compilación (sintaxis y límite de 200 variables locales por función)"
for f in $(find "$SRC" -name '*.luau'); do
	"$BIN/luau-compile" --null "$f" > /dev/null || { echo "FALLA: $f"; status=1; }
done

echo "== 2/5 Análisis de tipos con la API de Roblox"
"$BIN/rojo" sourcemap "$ROOT/default.project.json" --output "$OUT/sourcemap.json" > /dev/null
analysis=$(cd "$ROOT" && "$BIN/luau-lsp" analyze --sourcemap="$OUT/sourcemap.json" --definitions="$BIN/globalTypes.d.luau" --platform=roblox src 2>&1 | grep -v INFO | grep -v didChange || true)
if [ -n "$analysis" ]; then echo "$analysis"; status=1; else echo "0 avisos"; fi

cd "$OUT"
echo "== 3/5 Servidor: un jugador falso juega y recorre todas las acciones (Lune)"
if "$BIN/lune" run "$ROOT/tools/harness/run_server.luau" "$SRC" > "$OUT/server.txt" 2>&1 && grep -q "TODO OK" "$OUT/server.txt"; then
	grep "^\s*\[" "$OUT/server.txt"
	echo "OK (detalle en tools/out/server.txt)"
else
	tail -20 "$OUT/server.txt"; status=1
fi

echo "== 4/5 Interfaz: se crea entera y se pulsan todos los botones (Lune)"
if "$BIN/lune" run "$ROOT/tools/harness/run_client.luau" "$SRC" > "$OUT/client.txt" 2>&1 && grep -q "CLIENTE OK" "$OUT/client.txt"; then
	tail -4 "$OUT/client.txt"
else
	tail -20 "$OUT/client.txt"; status=1
fi

# Vista previa aproximada (opcional: necesita Chromium + Playwright)
if [ $status -eq 0 ] && command -v node > /dev/null && NODE_PATH=$(npm root -g) node -e "require('playwright')" 2> /dev/null; then
	rm -rf "$OUT/preview" && mkdir -p "$OUT/preview"
	"$BIN/lune" run "$ROOT/tools/harness/run_client.luau" "$SRC" "$OUT/preview" "$ROOT/assets" > /dev/null 2>&1 \
		&& python3 -I "$ROOT/tools/harness/preview.py" "$OUT/preview" 1280 720 1 > /dev/null \
		&& echo "Vista previa: tools/out/preview/*.png"
fi

echo "== 5/5 Construir AirCargo.rbxl"
if [ $status -eq 0 ]; then
	"$BIN/rojo" build "$ROOT/default.project.json" --output "$ROOT/AirCargo.rbxl"
	echo "TODO CORRECTO ✅"
else
	echo "HAY FALLOS ❌ (no se ha regenerado el .rbxl)"
fi
exit $status
