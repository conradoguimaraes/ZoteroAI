#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD")"
DIST="$ROOT/dist"

mkdir -p "$DIST"
"$ROOT/scripts/build-plugin.sh"

if [[ "$(uname -s)" == "Darwin" ]]; then
  "$ROOT/scripts/build-helper.sh"
  ditto -c -k --sequesterRsrc --keepParent \
    "$DIST/Zotero Metadata Helper.app" \
    "$DIST/zotero-metadata-helper-${VERSION}-build${BUILD}-macOS.zip"
fi

OUT="$DIST/zotero-metadata-enricher-${VERSION}-build${BUILD}-source.zip"
rm -f "$OUT"
(
  cd "$ROOT/.."
  zip -qr "$OUT" "$(basename "$ROOT")" \
    -x '*/.git/*' '*/helper/.build/*' '*/dist/*' '*/.DS_Store'
)

echo "Packaged source: $OUT"
