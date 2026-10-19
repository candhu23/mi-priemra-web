#!/usr/bin/env bash
# Verificación completa de Imperio Web Tycoon. Ejecutar: roblox-imperio-web/tools/check.sh
# Sale con error si algo falla. Genera ImperioWeb.rbxl al final si todo va bien.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/bin"
OUT="$ROOT/tools/out"
SRC="$ROOT/src"
mkdir -p "$OUT"
[ -x "$BIN/lune" ] || "$ROOT/tools/setup.sh"
status=0

echo "== 1/7 Compilación (sintaxis y límite de 200 variables locales por función)"
for f in $(find "$SRC" -name '*.luau'); do
	"$BIN/luau-compile" --null "$f" > /dev/null || { echo "FALLA: $f"; status=1; }
done

echo "== 2/7 Análisis de tipos con la API de Roblox"
"$BIN/rojo" sourcemap "$ROOT/default.project.json" --output "$OUT/sourcemap.json" > /dev/null
analysis=$(cd "$ROOT" && "$BIN/luau-lsp" analyze --sourcemap="$OUT/sourcemap.json" --definitions="$BIN/globalTypes.d.luau" --platform=roblox src 2>&1 | grep -v INFO | grep -v didChange || true)
if [ -n "$analysis" ]; then echo "$analysis"; status=1; else echo "0 avisos"; fi

cd "$OUT"
echo "== 3/7 Mundo y rascacielos (Lune)"
"$BIN/lune" run "$ROOT/tools/harness/run_world.luau" "$SRC" "$OUT/world.json" || status=1

echo "== 4/7 Servidor: jugador simulado recorre todas las acciones (Lune)"
if "$BIN/lune" run "$ROOT/tools/harness/run_server.luau" "$SRC" > "$OUT/server.txt" 2>&1 && grep -q "TODO OK" "$OUT/server.txt"; then
	echo "OK (detalle en tools/out/server.txt)"
else
	tail -20 "$OUT/server.txt"; status=1
fi

echo "== 5/7 Interfaz: se crea entera y se pulsan todos los botones (Lune)"
"$BIN/lune" run "$ROOT/tools/harness/run_client.luau" "$SRC" | tail -3 || status=1

# Capturas de la interfaz en PC y móvil + auditoría de diseño (skill disenar-interfaz; informativo)
rm -rf "$OUT/vista" "$OUT/vista_movil" && mkdir -p "$OUT/vista" "$OUT/vista_movil"
"$BIN/lune" run "$ROOT/tools/harness/run_client.luau" "$SRC" "$OUT/vista" > /dev/null 2>&1 || true
"$BIN/lune" run "$ROOT/tools/harness/run_client.luau" "$SRC" "$OUT/vista_movil" 844 390 > /dev/null 2>&1 || true
VER="$ROOT/../.claude/skills/disenar-interfaz/ver_interfaz.py"
if [ -f "$VER" ] && command -v node > /dev/null && NODE_PATH=$(npm root -g) node -e "require('playwright')" 2> /dev/null; then
	echo "-- Diseño (aproximado): PC $(python3 -I "$VER" "$OUT/vista" | tail -1) · móvil $(python3 -I "$VER" "$OUT/vista_movil" --movil | tail -1)"
	echo "   Capturas e informes: tools/out/vista/ y tools/out/vista_movil/"
fi

echo "== 6/7 Economía: bot de 6 horas (luau)"
mkdir -p "$OUT/sim"
cp "$SRC/ReplicatedStorage/TycoonConfig.luau" "$OUT/sim/"
{ echo 'local Color3 = { fromRGB = function() return {} end }'; cat "$SRC/ReplicatedStorage/CareerConfig.luau"; } > "$OUT/sim/CareerConfig.luau"
cp "$ROOT/tools/sim/sim.luau" "$OUT/sim/"
(cd "$OUT/sim" && "$BIN/luau" sim.luau -a career | grep -E "ganado \\\$(1.00K|100K|1.00M|100M)|primera (Red|Metaverso)|funda") || status=1

if command -v python3 > /dev/null && python3 -c "import matplotlib" 2> /dev/null; then
	python3 "$ROOT/tools/harness/render.py" "$OUT/world.json" "$OUT/render" > /dev/null && echo "Dibujos: tools/out/render_fachadas.png y render_ciudad.png"
fi

echo "== 7/7 Construir ImperioWeb.rbxl"
if [ $status -eq 0 ]; then
	"$BIN/rojo" build "$ROOT/default.project.json" --output "$ROOT/ImperioWeb.rbxl"
	echo "TODO CORRECTO ✅"
else
	echo "HAY FALLOS ❌ (no se ha regenerado el .rbxl)"
fi
exit $status
