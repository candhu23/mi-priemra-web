#!/usr/bin/env bash
# Descarga las herramientas de verificación en tools/bin (no se suben a git).
#   luau-lsp + definiciones de la API de Roblox  -> análisis de tipos
#   luau / luau-compile                           -> compilación y simulación de economía
#   rojo 7.4.4                                     -> construir DungeonAscend.rbxl y el sourcemap
#   lune 0.10.4                                    -> ejecutar el código real con instancias simuladas
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin && cd bin
get() { curl -fsSL -o "$1" "$2"; }

get luau-lsp.zip https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-linux-x86_64.zip
unzip -o -q luau-lsp.zip
get globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
get luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
unzip -o -q luau.zip
get rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-linux-x86_64.zip
unzip -o -q rojo.zip
get lune.zip https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip
unzip -o -q lune.zip
rm -f ./*.zip
chmod +x luau luau-compile luau-lsp rojo lune
echo "Herramientas listas en tools/bin"
