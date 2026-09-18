#!/usr/bin/env bash
set -u

APP="$HOME/Applications/Zotero Metadata Helper.app"
BIN="$APP/Contents/MacOS/ZoteroMetadataHelper"
PORT=43119

echo "Zotero Metadata Helper diagnostics"
echo "=================================="
echo
sw_vers 2>/dev/null || true
echo
printf 'App exists: '
[[ -d "$APP" ]] && echo yes || echo no
printf 'Binary exists: '
[[ -x "$BIN" ]] && echo yes || echo no

echo
echo "Running process:"
pgrep -alf ZoteroMetadataHelper || echo "(not running)"

echo
echo "Port $PORT listener:"
lsof -nP -iTCP:$PORT -sTCP:LISTEN 2>/dev/null || echo "(nothing listening)"

echo
echo "Health endpoint:"
if curl --silent --show-error --fail --max-time 2 "http://127.0.0.1:$PORT/health"; then
  echo
else
  echo "(health request failed)"
fi

echo
echo "Recent unified-log messages for the helper (last 5 minutes):"
log show --last 5m --style compact --predicate 'process == "ZoteroMetadataHelper"' 2>/dev/null | tail -n 80 || true
