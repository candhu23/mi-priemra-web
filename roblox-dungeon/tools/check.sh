#!/usr/bin/env bash
# Verificación completa de Dungeon Ascend. Ejecutar: roblox-dungeon/tools/check.sh
# Sale con error si algo falla. Genera DungeonAscend.rbxl al final si todo va bien.
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

cd "$OUT"
echo "== 3/6 Servidor: lobby, partidas solo y en grupo, tienda y guardado (Lune)"
if "$BIN/lune" run "$ROOT/tools/harness/run_server.luau" "$SRC" > "$OUT/server.txt" 2>&1 && grep -q "TODO OK" "$OUT/server.txt"; then
	head -1 "$OUT/server.txt"
	echo "OK (detalle en tools/out/server.txt)"
else
	tail -20 "$OUT/server.txt"; status=1
fi

echo "== 4/6 Interfaz: lobby, partida y horda; se pulsan todos los botones (Lune)"
if "$BIN/lune" run "$ROOT/tools/harness/run_client.luau" "$SRC" > "$OUT/client.txt" 2>&1 && grep -q "CLIENTE OK" "$OUT/client.txt"; then
	grep -E "Horda dibujada|CLIENTE OK" "$OUT/client.txt"
else
	tail -20 "$OUT/client.txt"; status=1
fi

echo "== 5/6 Equilibrio: bots que juegan partidas completas con el código real (~1 min)"
"$BIN/lune" run "$ROOT/tools/harness/run_server.luau" "$SRC" bot 2>&1 | grep -E "^  [A-Z]" || status=1

if command -v python3 > /dev/null && python3 -c "import matplotlib" 2> /dev/null; then
	python3 "$ROOT/tools/harness/render.py" "$OUT/world.json" "$OUT/render" > /dev/null && echo "Dibujos: tools/out/render_ciudad.png, render_zonas.png y render_enemigos.png"
fi

echo "== 6/6 Construir DungeonAscend.rbxl"
if [ $status -eq 0 ]; then
	"$BIN/rojo" build "$ROOT/default.project.json" --output "$ROOT/DungeonAscend.rbxl"
	echo "TODO CORRECTO ✅"
else
	echo "HAY FALLOS ❌ (no se ha regenerado el .rbxl)"
fi
exit $status
