#!/usr/bin/env bash
# Ejecuta el simulador de equilibrio: tools/sim/run.sh [horas]
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/out/sim"
mkdir -p "$OUT"
{ echo 'local Color3 = { fromRGB = function() return {} end }'; cat "$ROOT/src/ReplicatedStorage/GameConfig.luau"; } > "$OUT/GameConfig.luau"
cp "$ROOT/tools/sim/sim.luau" "$OUT/"
cd "$OUT" && "$ROOT/tools/bin/luau" sim.luau -a "${1:-5}"
