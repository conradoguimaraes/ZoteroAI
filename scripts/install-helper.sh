#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/build-helper.sh"

SOURCE="$ROOT/dist/Zotero Metadata Helper.app"
TARGET="$HOME/Applications/Zotero Metadata Helper.app"
HEALTH_URL="http://127.0.0.1:43119/health"

# Stop an older helper first. This avoids a stale process keeping port 43119
# occupied while a new build is installed.
pkill -x ZoteroMetadataHelper >/dev/null 2>&1 || true
sleep 0.5

mkdir -p "$HOME/Applications"
rm -rf "$TARGET"
cp -R "$SOURCE" "$TARGET"

open -n "$TARGET"

# Do not report success just because `open` returned. Wait for the helper's
# loopback health endpoint so startup failures are caught immediately.
ready=0
for _ in {1..30}; do
  if curl --silent --fail --max-time 1 "$HEALTH_URL" >/tmp/zme-health.json 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.25
done

if [[ "$ready" -ne 1 ]]; then
  echo >&2
  echo "ERROR: Zotero Metadata Helper was installed but did not become healthy." >&2
  echo "Run the diagnostic script:" >&2
  echo "  $ROOT/scripts/diagnose-helper.sh" >&2
  exit 4
fi

echo
echo "Installed and started: $TARGET"
echo "Helper health check passed:"
cat /tmp/zme-health.json; echo
rm -f /tmp/zme-health.json
echo
echo "A menu-bar item named ZME should appear."
