#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/local.zme.helper.plist"
launchctl bootout "gui/$UID/local.zme.helper" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/Applications/Zotero Metadata Helper.app"
echo "Removed helper application and LaunchAgent."
echo "The private token in ~/Library/Application Support/Zotero Metadata Enricher is intentionally retained."
