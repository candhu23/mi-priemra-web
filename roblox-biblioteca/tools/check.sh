#!/usr/bin/env bash
# Verificación completa de Estanterías Hechizadas. Ejecutar: roblox-biblioteca/tools/check.sh
# Sale con error si algo falla. Genera Biblioteca.rbxl al final si todo va bien.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/bin"
OUT="$ROOT/tools/out"
SRC="$ROOT/src"
H="$ROOT/tools/harness"
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

echo "== 3/7 Libros y textos: recuentos, títulos, palabras clave y palabras prohibidas"
if "$BIN/lune" run "$H/dump_data.luau" "$SRC" "$OUT/data.json" > /dev/null; then
	python3 -I "$H/check_books.py" "$OUT/data.json" || status=1
	[ -f "$H/check_lang.py" ] && { python3 -I "$H/check_lang.py" "$SRC" || status=1; }
else
	echo "FALLA: no se pudieron cargar BookData/Lang"; status=1
fi

# Lugar de prueba (el mismo que se publica)
"$BIN/rojo" build "$ROOT/default.project.json" --output "$OUT/test.rbxl" > /dev/null || status=1
cd "$OUT"

echo "== 4/7 Mundo: biblioteca real, 31 secciones, 400 filas, 3.072 libros, piezas (Lune)"
if [ -f "$H/run_world.luau" ]; then
	if "$BIN/lune" run "$H/run_world.luau" test.rbxl > "$OUT/world.txt" 2>&1 && grep -q "MUNDO OK" "$OUT/world.txt"; then
		grep -E "^\s+·" "$OUT/world.txt"; echo "OK (detalle en tools/out/world.txt)"
		# Planos vistos desde arriba (opcional: necesita Chromium + Playwright)
		if python3 -I "$H/plan.py" "$OUT/world.json" "$OUT" > /dev/null 2>&1 && command -v node > /dev/null && NODE_PATH=$(npm root -g 2> /dev/null) node "$H/svg2png.js" "$OUT" 2> /dev/null; then
			echo "Planos: tools/out/plan_planta1.png y plan_planta2.png"
		fi
	else
		tail -25 "$OUT/world.txt"; status=1
	fi
else
	echo "(pendiente: fase 2)"
fi

echo "== 5/7 Servidor: bots que juegan la partida entera, todo mal y la fase especial (Lune)"
if [ -f "$H/run_server.luau" ]; then
	for mode in sin-datastore normal; do
		if "$BIN/lune" run "$H/run_server.luau" test.rbxl $mode > "$OUT/server_$mode.txt" 2>&1 && grep -q "TODO OK" "$OUT/server_$mode.txt"; then
			grep -E "^\s+\[" "$OUT/server_$mode.txt"; echo "$mode: OK (detalle en tools/out/server_$mode.txt)"
		else
			tail -25 "$OUT/server_$mode.txt"; status=1
		fi
	done
else
	echo "(pendiente: fase 3)"
fi

echo "== 6/7 Cliente: se crea la interfaz y se pulsan todos los botones (PC y móvil)"
if [ -f "$H/run_client.luau" ]; then
	mkdir -p "$OUT/preview"
	for device in pc movil; do
		if "$BIN/lune" run "$H/run_client.luau" test.rbxl $device "$OUT/preview" > "$OUT/client_$device.txt" 2>&1 && grep -q "CLIENTE OK" "$OUT/client_$device.txt"; then
			grep -E "^\s+\[" "$OUT/client_$device.txt"; echo "$device: OK (detalle en tools/out/client_$device.txt)"
		else
			tail -25 "$OUT/client_$device.txt"; status=1
		fi
	done
	# Vista previa aproximada de la interfaz (opcional: necesita Chromium + Playwright)
	if command -v node > /dev/null && NODE_PATH=$(npm root -g 2> /dev/null) node -e "require('playwright')" 2> /dev/null; then
		python3 -I "$H/preview.py" "$OUT/preview" 1280 720 1 pc_ > /dev/null && python3 -I "$H/preview.py" "$OUT/preview" 844 390 2 movil_ > /dev/null && echo "Vista previa: tools/out/preview/*.png"
	fi
else
	echo "(pendiente: fase 3)"
fi

echo "== 7/7 Construir Biblioteca.rbxl"
if [ $status -eq 0 ]; then
	cp "$OUT/test.rbxl" "$ROOT/Biblioteca.rbxl"
	echo "TODO CORRECTO ✅"
else
	echo "HAY FALLOS ❌ (no se ha regenerado el .rbxl)"
fi
exit $status
