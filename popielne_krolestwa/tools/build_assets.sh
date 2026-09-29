#!/usr/bin/env bash
# Generuje wszystkie grafiki gry (PNG) i TileSet, a następnie importuje je do projektu Godota.
# Uruchom po zmianie kodu w client/tools/art/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
cd "$ROOT/client"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true      # rejestr klas (ArtLib itd.)
"$GODOT" --headless --path . --script res://tools/build_art.gd
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true      # import nowych PNG
"$GODOT" --headless --path . --script res://tools/build_tileset.gd
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "Gotowe: client/assets/"
