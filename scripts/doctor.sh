#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "PrismArt packaging requires macOS. Current system: $(uname -s)" >&2
  exit 2
fi

missing=0
for tool in xcrun swift git go lipo codesign hdiutil plutil shasum; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '✓ %-10s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '✗ %-10s missing\n' "$tool" >&2
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  cat >&2 <<'TXT'

Install Xcode Command Line Tools/Xcode, Git and Go, then rerun this script.
End users of the packaged PrismArt app do not need these developer tools.
TXT
  exit 1
fi

printf '\nArchitecture: %s\n' "$(uname -m)"
printf 'macOS:        %s\n' "$(sw_vers -productVersion)"
printf 'Swift:        %s\n' "$(swift --version | head -1)"
printf 'Go:           %s\n' "$(go version)"
printf 'SDK:          %s\n' "$(xcrun --sdk macosx --show-sdk-path)"
printf '\nPrismArt build prerequisites look good.\n'
