#!/usr/bin/env bash
# Buduje APK klienta Popielnych Królestw.
#
#   tools/build_apk.sh            -> build/popielne_krolestwa-debug.apk (podpisany kluczem debug)
#   tools/build_apk.sh release    -> build/popielne_krolestwa-release.apk (wymaga klucza release, patrz README)
#
# Wymagania: Godot 4.5.1 (zmienna GODOT lub "godot" w PATH) + szablony eksportu,
# Android SDK (ANDROID_HOME) z build-tools i platform-tools, JDK 17+ (JAVA_HOME).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/client"
BUILD="$ROOT/build"
GODOT="${GODOT:-godot}"
MODE="${1:-debug}"
mkdir -p "$BUILD"

command -v "$GODOT" >/dev/null || { echo "Nie znaleziono Godota. Ustaw GODOT=/sciezka/do/godot"; exit 1; }
[ -n "${ANDROID_HOME:-}" ] || { echo "Ustaw ANDROID_HOME (ścieżka do Android SDK)"; exit 1; }
if [ -z "${JAVA_HOME:-}" ]; then
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  export JAVA_HOME
fi

# Ścieżki SDK w ustawieniach edytora Godota (tworzone przy pierwszym uruchomieniu edytora
# i wtedy nie odczytują już zmiennych środowiskowych) – aktualizujemy je automatycznie.
"$GODOT" --headless --quit >/dev/null 2>&1 || true
for EDS in "$HOME"/.config/godot/editor_settings-4*.tres; do
  [ -f "$EDS" ] || continue
  sed -i '/^export\/android\/android_sdk_path/d; /^export\/android\/java_sdk_path/d' "$EDS"
  printf 'export/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' "$ANDROID_HOME" "$JAVA_HOME" >> "$EDS"
done

# Klucz debug – generowany raz, jeśli nie istnieje (standardowe dane Androida).
DEBUG_KS="$BUILD/debug.keystore"
if [ ! -f "$DEBUG_KS" ]; then
  echo "Generuję klucz debug: $DEBUG_KS"
  keytool -genkeypair -v -keystore "$DEBUG_KS" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KS"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android

echo "Import zasobów..."
"$GODOT" --headless --path "$CLIENT" --import >/dev/null 2>&1 || true

if [ "$MODE" = "release" ]; then
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Ustaw GODOT_ANDROID_KEYSTORE_RELEASE_PATH}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Ustaw GODOT_ANDROID_KEYSTORE_RELEASE_USER (alias klucza)}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Ustaw GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD}"
  OUT="$BUILD/popielne_krolestwa-release.apk"
  "$GODOT" --headless --path "$CLIENT" --export-release "Android" "$OUT"
else
  OUT="$BUILD/popielne_krolestwa-debug.apk"
  "$GODOT" --headless --path "$CLIENT" --export-debug "Android" "$OUT"
fi

[ -f "$OUT" ] || { echo "Eksport nie powiódł się."; exit 1; }
echo "Gotowe: $OUT"
if command -v apksigner >/dev/null; then apksigner verify --print-certs "$OUT" | head -3; fi
