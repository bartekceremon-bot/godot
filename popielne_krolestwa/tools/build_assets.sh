#!/usr/bin/env bash
# Generuje grafiki interfejsu (PNG), a następnie importuje je do projektu Godota.
# Uruchom po zmianie kodu w client/tools/art/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
cd "$ROOT/client"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true      # rejestr klas (ArtLib itd.)
"$GODOT" --headless --path . --script res://tools/build_art.gd
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true      # import nowych PNG
echo "Gotowe: client/assets/"
