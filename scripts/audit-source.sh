#!/usr/bin/env bash
set -euo pipefail

# 1.0 intentionally has no network client and no persistent user defaults/database.
# Fail CI if these high-signal APIs/paths are introduced without an explicit review.
for pattern in 'URLSession' 'UserDefaults' 'Application Support' 'LaunchAgents' 'SMAppService'; do
  if grep -R --line-number --fixed-strings "$pattern" Sources >/tmp/prismart-audit.txt 2>/dev/null; then
    echo "Source audit failed: found disallowed persistence/network marker: $pattern" >&2
    cat /tmp/prismart-audit.txt >&2
    exit 1
  fi
done

# Process execution must stay shell-free.
if grep -R --line-number -E '(/bin/(sh|bash|zsh)|executableURL.*shell)' Sources >/tmp/prismart-audit.txt 2>/dev/null; then
  echo "Source audit failed: shell execution marker found." >&2
  cat /tmp/prismart-audit.txt >&2
  exit 1
fi

echo "Source privacy/stateless audit passed."
