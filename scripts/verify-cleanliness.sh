#!/usr/bin/env bash
set -euo pipefail

cat <<'TXT'
PrismArt intentionally does not create:
  ~/Library/Application Support/io.github.prismartmac.PrismArt
  ~/Library/Preferences/io.github.prismartmac.PrismArt.plist
  ~/Library/LaunchAgents/*PrismArt*

At runtime it uses only the macOS temporary directory under a PrismArt folder,
and it deletes stale workspaces on launch and the active workspace on normal quit.
Images pasted or dragged as data are copied only into that temporary folder.

Note: macOS itself may keep system-managed metadata (for example LaunchServices,
recent-item metadata, quarantine records, or crash diagnostics). Those are not app-owned
payloads and should not be deleted by an application uninstaller.
TXT
