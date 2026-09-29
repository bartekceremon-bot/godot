#!/usr/bin/env bash
# Buduje przeglądarkową wersję gry (Godot Web + serwer offline w tej samej karcie).
# Wynik: build/web_play/ – play.html (silnik i serwer inline) + engine-gz.wasm (silnik, gzip) + game-pck.wasm (paczka gry).
#   tools/build_web.sh            -> wersja do grania
#   AUTOTEST=1 tools/build_web.sh -> wersja z automatycznym logowaniem (testy)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/build/web_play"
TMP="$ROOT/build/web_export"
rm -rf "$OUT" "$TMP" && mkdir -p "$OUT" "$TMP"

(cd "$ROOT/server" && npm run --silent build:web)
"$GODOT" --headless --path "$ROOT/client" --export-release "Web" "$TMP/index.html" >/dev/null 2>&1
# Hosting stron obsługuje tylko wybrane rozszerzenia – oba pliki podajemy jako .wasm.
gzip -9 -c "$TMP/index.wasm" > "$OUT/engine-gz.wasm"
cp "$TMP/index.pck" "$OUT/game-pck.wasm"

ARGS='["--audio-driver", "Dummy"]'
if [ "${AUTOTEST:-}" = "1" ]; then
  ARGS='["--audio-driver", "Dummy", "--", "--autotest=offline,Tester,haslo1", "--scenario=etap3"]'
fi
python3 - "$ROOT" "$TMP" "$OUT" "$ARGS" <<'PY'
import sys, base64, json, os
root, tmp, out, args = sys.argv[1:5]
godot_js = open(f"{tmp}/index.js", encoding="utf-8").read()
pk_js = open(f"{root}/server/dist-web/pk_offline.js", encoding="utf-8").read()
logo = base64.b64encode(open(f"{root}/client/assets/splash.png", "rb").read()).decode()
sizes = {"index.pck": os.path.getsize(f"{tmp}/index.pck"), "index.wasm": os.path.getsize(f"{tmp}/index.wasm")}
tpl = open(f"{root}/tools/web_shell.html", encoding="utf-8").read()
html = (tpl.replace("%GODOT_JS%", godot_js.replace("</script", "<\\/script"))
           .replace("%PK_JS%", pk_js.replace("</script", "<\\/script"))
           .replace("%LOGO%", logo)
           .replace("%SIZES%", json.dumps(sizes))
           .replace("%ARGS%", args))
open(f"{out}/play.html", "w", encoding="utf-8").write(html)
print("play.html:", len(html) // 1024, "KB")
PY
ls -la "$OUT"
