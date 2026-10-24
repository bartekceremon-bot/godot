#!/usr/bin/env bash
# Buduje eksport Web do dist/ i tworzy dwa archiwa w wydanie/:
#   straznicy-iskry-gra-web.zip   — gotowy eksport (index.html w głównym katalogu archiwum)
#   straznicy-iskry-zrodla.zip    — źródła projektu Godot, narzędzia i dokumentacja
# Wymaga: godot 4.7.2 w PATH oraz szablonów eksportu 4.7.2.stable.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

"$GODOT" --version | grep -q "^4.7.2.stable" || { echo "Wymagany Godot 4.7.2.stable"; exit 1; }

cd "$ROOT/godot"
"$GODOT" --headless --import . >/dev/null 2>&1 || true
"$GODOT" --headless -s res://tests/check_all.gd
mkdir -p "$ROOT/dist"
"$GODOT" --headless --export-release "Web" "$ROOT/dist/index.html"
cp "$ROOT/docs/htaccess-przyklad.txt" "$ROOT/dist/.htaccess"

mkdir -p "$ROOT/wydanie"
rm -f "$ROOT/wydanie/straznicy-iskry-gra-web.zip" "$ROOT/wydanie/straznicy-iskry-zrodla.zip"
# Zawartość dist/ trafia bezpośrednio do korzenia archiwum (bez „folderu w folderze”).
(cd "$ROOT/dist" && zip -q -9 -r "$ROOT/wydanie/straznicy-iskry-gra-web.zip" . )
(cd "$ROOT" && zip -q -9 -r "$ROOT/wydanie/straznicy-iskry-zrodla.zip" \
	godot tools docs README.md .gitignore \
	-x "godot/.godot/*" "*/__pycache__/*")
ls -la "$ROOT/wydanie"
