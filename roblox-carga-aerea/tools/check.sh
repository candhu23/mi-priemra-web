#!/usr/bin/env bash
# Verificación completa de AeroCarga España. Ejecutar: roblox-carga-aerea/tools/check.sh
# Sale con error si algo falla. Genera AeroCarga.rbxl al final si todo va bien.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/bin"
OUT="$ROOT/tools/out"
SRC="$ROOT/src"
mkdir -p "$OUT"
[ -x "$BIN/lune" ] || "$ROOT/tools/setup.sh"
status=0

echo "== 1/6 Compilación (sintaxis y límite de 200 variables locales por función)"
for f in $(find "$SRC" -name '*.luau'); do
	"$BIN/luau-compile" --null "$f" > /dev/null || { echo "FALLA: $f"; status=1; }
done

echo "== 2/6 Análisis de tipos con la API de Roblox"
"$BIN/rojo" sourcemap "$ROOT/default.project.json" --output "$OUT/sourcemap.json" > /dev/null
analysis=$(cd "$ROOT" && "$BIN/luau-lsp" analyze --sourcemap="$OUT/sourcemap.json" --definitions="$BIN/globalTypes.d.luau" --platform=roblox src 2>&1 | grep -v INFO | grep -v didChange || true)
if [ -n "$analysis" ]; then echo "$analysis"; status=1; else echo "0 avisos"; fi

echo "== 3/6 Textos: todas las claves existen en inglés y español"
python3 -I "$ROOT/tools/harness/check_lang.py" "$SRC" || status=1

# Lugar de prueba (el mismo que se publica)
"$BIN/rojo" build "$ROOT/default.project.json" --output "$OUT/test.rbxl" > /dev/null || status=1
cd "$OUT"
echo "== 4/6 Servidor: sin DataStore (Studio sin publicar) y partida completa de un bot"
if "$BIN/lune" run "$ROOT/tools/harness/run_server.luau" test.rbxl sin-datastore > "$OUT/server_sin_datastore.txt" 2>&1 && grep -q "SIN DATASTORE OK" "$OUT/server_sin_datastore.txt"; then
	echo "Sin DataStore: OK"
else
	tail -20 "$OUT/server_sin_datastore.txt"; status=1
fi
if "$BIN/lune" run "$ROOT/tools/harness/run_server.luau" test.rbxl > "$OUT/server.txt" 2>&1 && grep -q "TODO OK" "$OUT/server.txt"; then
	grep -E "^\s+\[" "$OUT/server.txt"
	echo "Partida del bot: OK (detalle en tools/out/server.txt)"
else
	tail -20 "$OUT/server.txt"; status=1
fi

echo "== 5/6 Juego completo: servidor + interfaz reales, tutorial y todos los botones"
rm -rf "$OUT/preview" && mkdir -p "$OUT/preview"
if "$BIN/lune" run "$ROOT/tools/harness/run_game.luau" test.rbxl "$OUT/preview" > "$OUT/game.txt" 2>&1 && grep -q "JUEGO OK" "$OUT/game.txt"; then
	grep -E "tutorial completado|botones pulsados|Acciones" "$OUT/game.txt"
	# Vista previa aproximada (opcional: necesita Chromium + Playwright)
	if command -v node > /dev/null && NODE_PATH=$(npm root -g) node -e "require('playwright')" 2> /dev/null; then
		python3 -I "$ROOT/tools/harness/preview.py" "$OUT/preview" 1280 720 1 > /dev/null && echo "Vista previa: tools/out/preview/*.png"
	fi
else
	tail -20 "$OUT/game.txt"; status=1
fi

echo "== 6/6 Construir AeroCarga.rbxl"
if [ $status -eq 0 ]; then
	cp "$OUT/test.rbxl" "$ROOT/AeroCarga.rbxl"
	echo "TODO CORRECTO ✅"
else
	echo "HAY FALLOS ❌ (no se ha regenerado el .rbxl)"
fi
exit $status
