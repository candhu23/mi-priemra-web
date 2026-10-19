#!/usr/bin/env bash
# Verificación completa de {{NOMBRE}}. Ejecutar: {{CARPETA}}/tools/check.sh
# Sale con error si algo falla. Genera {{RBXL}} al final si todo va bien.
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

echo "== 3/6 Textos: todas las claves en español e inglés"
python3 -I "$ROOT/tools/harness/check_lang.py" "$SRC" || status=1

echo "== 4/6 Juego completo: servidor + interfaz reales, bot, todos los botones, guardar/cargar, sin DataStore"
"$BIN/rojo" build "$ROOT/default.project.json" --output "$OUT/test.rbxl" > /dev/null || status=1
rm -rf "$OUT/vista" "$OUT/vista_movil" && mkdir -p "$OUT/vista" "$OUT/vista_movil"
cd "$OUT"
if "$BIN/lune" run "$ROOT/tools/harness/run_juego.luau" test.rbxl "$OUT/vista" > "$OUT/juego.txt" 2>&1 && grep -q "JUEGO OK" "$OUT/juego.txt"; then
	grep -E "^  " "$OUT/juego.txt"
	echo "OK (detalle en tools/out/juego.txt)"
else
	tail -20 "$OUT/juego.txt"; status=1
fi
"$BIN/lune" run "$ROOT/tools/harness/run_juego.luau" test.rbxl "$OUT/vista_movil" 844 390 > /dev/null 2>&1 || true

echo "-- Ritmo de la economía (jugador bueno; compáralo con DISENO.md §5)"
"$BIN/lune" run "$ROOT/tools/harness/ritmo.luau" "$SRC" 90 | head -14 || true

echo "== 5/6 Diseño: capturas y auditoría (PC y móvil; aproximado)"
VER="$ROOT/../.claude/skills/disenar-interfaz/ver_interfaz.py"
if [ -f "$VER" ] && command -v node > /dev/null && NODE_PATH=$(npm root -g) node -e "require('playwright')" 2> /dev/null; then
	python3 -I "$VER" "$OUT/vista" | tail -1
	python3 -I "$VER" "$OUT/vista_movil" --movil | tail -1
	echo "Informes: tools/out/vista/informe_diseno.md y tools/out/vista_movil/informe_diseno.md"
else
	echo "(sin Playwright o sin .claude/: se salta)"
fi

echo "== 6/6 Construir {{RBXL}}"
if [ $status -eq 0 ]; then
	cp "$OUT/test.rbxl" "$ROOT/{{RBXL}}"
	echo "TODO CORRECTO ✅"
else
	echo "HAY FALLOS ❌ (no se ha regenerado el .rbxl)"
fi
exit $status
