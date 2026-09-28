#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Packaging PrismArt requires macOS." >&2
  exit 2
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
VERSION=${VERSION:-1.0.1}
BUILD_NUMBER=${BUILD_NUMBER:-1}
SIGNING_IDENTITY=${SIGNING_IDENTITY:--}
DIST="$ROOT/dist"
APP="$DIST/PrismArt.app"
CONTENTS="$APP/Contents"
DMG="$DIST/PrismArt-$VERSION.dmg"

rm -rf "$DIST"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources/bin"

SDK=$(xcrun --sdk macosx --show-sdk-path)
ARM_SCRATCH="$ROOT/.build/macos-arm64"
X64_SCRATCH="$ROOT/.build/macos-x86_64"

swift build -c release --triple arm64-apple-macosx13.0 --sdk "$SDK" --scratch-path "$ARM_SCRATCH"
ARM_BIN=$(swift build -c release --triple arm64-apple-macosx13.0 --sdk "$SDK" --scratch-path "$ARM_SCRATCH" --show-bin-path)
swift build -c release --triple x86_64-apple-macosx13.0 --sdk "$SDK" --scratch-path "$X64_SCRATCH"
X64_BIN=$(swift build -c release --triple x86_64-apple-macosx13.0 --sdk "$SDK" --scratch-path "$X64_SCRATCH" --show-bin-path)

lipo -create "$ARM_BIN/PrismArt" "$X64_BIN/PrismArt" -output "$CONTENTS/MacOS/PrismArt"
chmod +x "$CONTENTS/MacOS/PrismArt"

sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD_NUMBER/g" \
  Resources/Info.plist.template > "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist" >/dev/null

scripts/build-engine.sh "$CONTENTS/Resources/bin/primitive"
scripts/make-icon.sh Resources/AppIcon-1024.png "$CONTENTS/Resources/AppIcon.icns"
cp LICENSE "$CONTENTS/Resources/LICENSE.txt"
cp .build/upstream/primitive/LICENSE.md "$CONTENTS/Resources/Primitive-LICENSE.md"
git -C .build/upstream/primitive rev-parse HEAD > "$CONTENTS/Resources/Primitive-REVISION.txt"
cp THIRD_PARTY_NOTICES.md "$CONTENTS/Resources/THIRD_PARTY_NOTICES.md"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Applying ad-hoc signature (no Apple Developer account required)."
  codesign --force --sign - "$CONTENTS/Resources/bin/primitive"
  codesign --force --sign - "$APP"
else
  echo "Signing with Developer ID identity: $SIGNING_IDENTITY"
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$CONTENTS/Resources/bin/primitive"
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
lipo -info "$CONTENTS/MacOS/PrismArt"
lipo -info "$CONTENTS/Resources/bin/primitive"

STAGE="$DIST/dmg-stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/PrismArt.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "PrismArt" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
fi

shasum -a 256 "$DMG" > "$DMG.sha256"
printf '\nArtifacts:\n  %s\n  %s\n  %s\n' "$APP" "$DMG" "$DMG.sha256"
