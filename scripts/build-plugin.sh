#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="$ROOT/dist"
OUT="$DIST/zotero-metadata-enricher-${VERSION}.xpi"

mkdir -p "$DIST"
rm -f "$OUT"

(
  cd "$ROOT/plugin"
  zip -qr "$OUT" . -x '*.DS_Store'
)

echo "Built: $OUT"
