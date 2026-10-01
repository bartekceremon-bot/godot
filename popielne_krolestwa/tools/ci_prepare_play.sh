#!/usr/bin/env bash
# Przygotowanie projektu do wydania w Google Play (uruchamiane w GitHub Actions, ma dostęp do
# GitHuba i Maven Google, których nie ma w środowisku deweloperskim):
#  1. wtyczka GodotGooglePlayBilling (płatności) – zawsze,
#  2. wtyczka godot-admob (reklamy z nagrodą) – tylko gdy podano ADMOB_APP_ID (bez identyfikatora
#     aplikacji AdMob SDK zamyka aplikację przy starcie),
#  3. włączenie wtyczek w project.godot, ustawienia eksportu Gradle (AAB/APK), target SDK.
#
# Zmienne: ADMOB_APP_ID (ca-app-pub-…~…), ADMOB_REWARDED_ID (ca-app-pub-…/…), VERSION_CODE, FORMAT (aab|apk).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/client"
TMP="$(mktemp -d)"
FORMAT="${FORMAT:-aab}"
PLUGINS=()

echo "== Google Play Billing"
gh release download --repo godot-sdk-integrations/godot-google-play-billing --pattern "*.zip" -D "$TMP/billing" --clobber
unzip -q -o "$TMP"/billing/*.zip -d "$TMP/billing/x"
BILL_DIR="$(dirname "$(find "$TMP/billing/x" -path "*GodotGooglePlayBilling/plugin.cfg" | head -1)")"
mkdir -p "$CLIENT/addons"
cp -r "$BILL_DIR" "$CLIENT/addons/"
PLUGINS+=("res://addons/GodotGooglePlayBilling/plugin.cfg")

if [ -n "${ADMOB_APP_ID:-}" ]; then
  echo "== AdMob"
  gh release download --repo godot-sdk-integrations/godot-admob --pattern "*Android*.zip" -D "$TMP/admob" --clobber \
    || gh release download --repo godot-sdk-integrations/godot-admob --pattern "*.zip" -D "$TMP/admob" --clobber
  for z in "$TMP"/admob/*.zip; do unzip -q -o "$z" -d "$TMP/admob/x"; done
  CFG="$(find "$TMP/admob/x" -path "*/addons/*/plugin.cfg" | head -1)"
  AD_DIR="$(dirname "$CFG")"
  AD_NAME="$(basename "$AD_DIR")"
  cp -r "$AD_DIR" "$CLIENT/addons/"
  # Identyfikator aplikacji AdMob trafia do manifestu (sekcja Release, is_real=true).
  cat > "$CLIENT/addons/$AD_NAME/android_export.cfg" <<CFG
[General]
is_real=true

[Debug]
app_id="ca-app-pub-3940256099942544~3347511713"

[Release]
app_id="$ADMOB_APP_ID"
CFG
  PLUGINS+=("res://addons/$AD_NAME/plugin.cfg")
  if [ -n "${ADMOB_REWARDED_ID:-}" ]; then
    printf '\n[popielne]\n\nadmob_rewarded_id="%s"\n' "$ADMOB_REWARDED_ID" >> "$CLIENT/project.godot"
  fi
fi

echo "== Wtyczki w project.godot: ${PLUGINS[*]}"
LIST=""
for p in "${PLUGINS[@]}"; do LIST="$LIST\"$p\", "; done
LIST="${LIST%, }"
sed -i '/^\[editor_plugins\]/,/^$/d' "$CLIENT/project.godot"
printf '\n[editor_plugins]\n\nenabled=PackedStringArray(%s)\n' "$LIST" >> "$CLIENT/project.godot"

echo "== Ustawienia eksportu (Gradle, $FORMAT, target SDK 36)"
P="$CLIENT/export_presets.cfg"
sed -i 's/^gradle_build\/use_gradle_build=.*/gradle_build\/use_gradle_build=true/' "$P"
sed -i "s/^gradle_build\/export_format=.*/gradle_build\/export_format=$([ "$FORMAT" = aab ] && echo 1 || echo 0)/" "$P"
sed -i 's/^gradle_build\/min_sdk=.*/gradle_build\/min_sdk="24"/; s/^gradle_build\/target_sdk=.*/gradle_build\/target_sdk="36"/' "$P"
sed -i 's/^architectures\/armeabi-v7a=.*/architectures\/armeabi-v7a=true/; s/^architectures\/arm64-v8a=.*/architectures\/arm64-v8a=true/' "$P"
if [ -n "${VERSION_CODE:-}" ]; then
  sed -i "s/^version\/code=.*/version\/code=$VERSION_CODE/" "$P"
fi
grep -E "use_gradle_build|export_format|min_sdk|target_sdk|version/code|version/name" "$P"
