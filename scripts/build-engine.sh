#!/usr/bin/env bash
set -euo pipefail

OUT=${1:-"$PWD/.build/engine/primitive"}
REF=${PRIMITIVE_REF:-master}
CACHE=${PRIMITIVE_SOURCE_DIR:-"$PWD/.build/upstream/primitive"}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-engine.sh must run on macOS because it creates a Universal Binary with lipo." >&2
  exit 2
fi

mkdir -p "$(dirname "$CACHE")" "$(dirname "$OUT")"
if [[ ! -d "$CACHE/.git" ]]; then
  git clone https://github.com/fogleman/primitive.git "$CACHE"
fi

git -C "$CACHE" fetch --depth 1 origin "$REF"
git -C "$CACHE" checkout --detach FETCH_HEAD

pushd "$CACHE" >/dev/null
if [[ ! -f go.mod ]]; then
  go mod init github.com/fogleman/primitive
fi
go mod tidy
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o "$OUT.arm64" .
CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o "$OUT.x86_64" .
popd >/dev/null

lipo -create "$OUT.arm64" "$OUT.x86_64" -output "$OUT"
rm -f "$OUT.arm64" "$OUT.x86_64"
chmod +x "$OUT"
echo "Built Universal Primitive engine: $OUT"
