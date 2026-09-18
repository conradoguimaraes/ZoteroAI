#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD")"

fail() { echo "VERIFY FAILED: $*" >&2; exit 1; }

command -v node >/dev/null || fail "node is required for JavaScript syntax checks"
command -v jq >/dev/null || fail "jq is required for manifest checks"
command -v swift >/dev/null || fail "swift is required for helper package checks"

for file in \
  "$ROOT/plugin/bootstrap.js" \
  "$ROOT/plugin/chrome/content/main.js" \
  "$ROOT/plugin/chrome/content/review.js"; do
  node --check "$file"
done

jq -e . "$ROOT/plugin/manifest.json" >/dev/null
MANIFEST_VERSION="$(jq -r .version "$ROOT/plugin/manifest.json")"
[[ "$MANIFEST_VERSION" == "$VERSION" ]] || fail "manifest version $MANIFEST_VERSION != VERSION $VERSION"

grep -q "static let version = \"$VERSION\"" "$ROOT/helper/Sources/ZoteroMetadataHelper/main.swift" \
  || fail "helper BuildInfo version does not match VERSION"
grep -q "static let build = $BUILD" "$ROOT/helper/Sources/ZoteroMetadataHelper/main.swift" \
  || fail "helper BuildInfo build does not match BUILD"

swift package --package-path "$ROOT/helper" dump-package >/dev/null
swift test --package-path "$ROOT/helper"
swift build --package-path "$ROOT/helper"

"$ROOT/scripts/build-plugin.sh" >/dev/null
XPI="$ROOT/dist/zotero-metadata-enricher-${VERSION}.xpi"
unzip -t "$XPI" >/dev/null
unzip -l "$XPI" | grep -q 'manifest.json' || fail "XPI has no manifest.json"
unzip -l "$XPI" | grep -q 'bootstrap.js' || fail "XPI has no bootstrap.js"

if [[ "$(uname -s)" == "Darwin" ]]; then
  "$ROOT/scripts/build-helper.sh"
fi

echo "Verification passed for source/package checks."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "NOTE: macOS-only FoundationModels/AppKit/PDFKit code was parsed but not type-checked against an Apple SDK on this host."
fi
