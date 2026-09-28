#!/usr/bin/env bash
set -euo pipefail

SRC=${1:-"Resources/AppIcon-1024.png"}
OUT=${2:-".build/AppIcon.icns"}
ICONSET="${OUT%.icns}.iconset"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "make-icon.sh requires macOS (sips + iconutil)." >&2
  exit 2
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
  size=${spec%% *}; name=${spec#* }
  sips -z "$size" "$size" "$SRC" --out "$ICONSET/$name" >/dev/null
 done
iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$ICONSET"
