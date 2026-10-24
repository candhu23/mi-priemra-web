#!/usr/bin/env bash
# Copia las skills de los 10 plugins a .claude/skills/ (para usarlas en este repo) y rehace los .zip
# para subirlas a claude.ai (así salen en TODAS las sesiones nuevas, de cualquier proyecto).
# Ejecútalo después de cambiar cualquier cosa dentro de plugins/<nombre>/skills/<nombre>/.
set -euo pipefail
cd "$(dirname "$0")"
RAIZ=$(cd .. && pwd)
mkdir -p zips-para-claude-ai "$RAIZ/.claude/skills"
for dir in roblox-*/; do
	n=${dir%/}
	src="$n/skills/$n"
	[ -f "$src/SKILL.md" ] || continue
	rm -rf "$RAIZ/.claude/skills/$n"
	cp -r "$src" "$RAIZ/.claude/skills/$n"
	rm -f "zips-para-claude-ai/$n.zip"
	(cd "$n/skills" && zip -qr -X "../../zips-para-claude-ai/$n.zip" "$n" -x "*/__pycache__/*")
	echo "✓ $n"
done
echo "Listo: .claude/skills/ actualizado y zips en plugins/zips-para-claude-ai/"
