#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/build-helper.sh"

SOURCE="$ROOT/dist/Zotero Metadata Helper.app"
TARGET="$HOME/Applications/Zotero Metadata Helper.app"
mkdir -p "$HOME/Applications"
rm -rf "$TARGET"
cp -R "$SOURCE" "$TARGET"

open "$TARGET"
echo
printf 'Installed and started: %s\n' "$TARGET"
echo "A menu-bar item named ZME should appear."
