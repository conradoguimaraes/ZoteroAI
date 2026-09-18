#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD")"
DIST="$ROOT/dist"
APP="$DIST/Zotero Metadata Helper.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: The native helper must be built on macOS because it links AppKit, PDFKit, Network, and FoundationModels." >&2
  exit 2
fi

command -v swift >/dev/null || {
  echo "ERROR: Swift is not available. Install/use Xcode or the Xcode Command Line Tools, then retry." >&2
  exit 2
}

swift build -c release --package-path "$ROOT/helper"
BIN="$ROOT/helper/.build/release/ZoteroMetadataHelper"
[[ -x "$BIN" ]] || { echo "ERROR: Expected helper binary not found at $BIN" >&2; exit 3; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ZoteroMetadataHelper"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>ZoteroMetadataHelper</string>
  <key>CFBundleIdentifier</key><string>local.zme.helper</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Zotero Metadata Helper</string>
  <key>CFBundleDisplayName</key><string>Zotero Metadata Helper</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP" >/dev/null
fi

echo "Built: $APP"
