#!/usr/bin/env bash
set -euo pipefail

APP="$HOME/Applications/Zotero Metadata Helper.app"
PLIST="$HOME/Library/LaunchAgents/local.zme.helper.plist"
BINARY="$APP/Contents/MacOS/ZoteroMetadataHelper"

[[ -x "$BINARY" ]] || {
  echo "ERROR: Helper is not installed at: $APP" >&2
  echo "Run ./scripts/install-helper.sh first." >&2
  exit 2
}

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.zme.helper</string>
  <key>ProgramArguments</key>
  <array><string>${BINARY}</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$UID/local.zme.helper" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"
launchctl kickstart -k "gui/$UID/local.zme.helper"
echo "Installed login helper: $PLIST"
