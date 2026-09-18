#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD")"

fail() { echo "VERIFY FAILED: $*" >&2; exit 1; }

command -v node >/dev/null || fail "node is required for JavaScript syntax checks"
command -v jq >/dev/null || fail "jq is required for manifest checks"
command -v python3 >/dev/null || fail "python3 is required for XHTML well-formedness checks"
command -v swift >/dev/null || fail "swift is required for helper package checks"

for file in \
  "$ROOT/plugin/bootstrap.js" \
  "$ROOT/plugin/chrome/content/main.js" \
  "$ROOT/plugin/chrome/content/review.js"; do
  node --check "$file"
done

# The review UI is XHTML. Parse it as XML so malformed tags/attributes are
# caught before an XPI can ship a blank dialog.
python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' \
  "$ROOT/plugin/chrome/content/review.xhtml"

# Regression guard for v0.2.1: Zotero bootstrapped-plugin scopes do not
# guarantee a browser-style `console` global. Logging uses Zotero.debug.
if grep -Eq '^[[:space:]]*console,[[:space:]]*$' "$ROOT/plugin/bootstrap.js"; then
  fail "bootstrap.js reintroduced an undefined console scope dependency"
fi

jq -e . "$ROOT/plugin/manifest.json" >/dev/null
MANIFEST_VERSION="$(jq -r .version "$ROOT/plugin/manifest.json")"
[[ "$MANIFEST_VERSION" == "$VERSION" ]] || fail "manifest version $MANIFEST_VERSION != VERSION $VERSION"

PLUGIN_ID="$(jq -r '.applications.zotero.id // empty' "$ROOT/plugin/manifest.json")"
UPDATE_URL="$(jq -r '.applications.zotero.update_url // empty' "$ROOT/plugin/manifest.json")"
MAX_VERSION="$(jq -r '.applications.zotero.strict_max_version // empty' "$ROOT/plugin/manifest.json")"
[[ "$PLUGIN_ID" == *@*.* ]] || fail "plugin id must be email-like (name@domain.tld): $PLUGIN_ID"
[[ "$UPDATE_URL" == https://* ]] || fail "applications.zotero.update_url is required and must be https://"
[[ "$MAX_VERSION" == "10.0.*" ]] || fail "Zotero 10 package must declare strict_max_version 10.0.*"

grep -q "static let version = \"$VERSION\"" "$ROOT/helper/Sources/ZoteroMetadataHelper/main.swift" \
  || fail "helper BuildInfo version does not match VERSION"
grep -q "static let build = $BUILD" "$ROOT/helper/Sources/ZoteroMetadataHelper/main.swift" \
  || fail "helper BuildInfo build does not match BUILD"


# Regression guards for v0.2.3 UI issues observed on Zotero 10.0.3.
# Item actions are intentionally flat; a nested submenu previously rendered but
# failed to open in the target client.
if grep -q 'menuType: "submenu"' "$ROOT/plugin/chrome/content/main.js"; then
  fail "item/collection menus reintroduced a nested submenu; v0.2.3 uses direct MenuManager menuitems"
fi

# ItemPane side-nav localization must be a tooltip, not a visible label. Reusing
# the section-header .label causes the text to overflow vertically in the narrow
# sidenav.
grep -q '^zme-pane-sidenav =[[:space:]]*$' "$ROOT/plugin/locale/en-US/zotero-metadata-enricher.ftl" \
  || fail "missing dedicated zme-pane-sidenav localization"
grep -A2 '^zme-pane-sidenav =[[:space:]]*$' "$ROOT/plugin/locale/en-US/zotero-metadata-enricher.ftl" | grep -q '\.tooltiptext = Metadata Enricher' \
  || fail "zme-pane-sidenav must localize .tooltiptext"


# Regression guards for v0.2.4 runtime/UI failures observed on Zotero 10.0.3.
# Auxiliary plugin windows must be loaded through a runtime-registered chrome://
# package; opening a raw jar:file rootURI produced an empty review window.
grep -q 'registerChrome(manifestURI' "$ROOT/plugin/bootstrap.js" \
  || fail "bootstrap.js must runtime-register the plugin content package"
grep -q 'chromeHandle.destruct()' "$ROOT/plugin/bootstrap.js" \
  || fail "runtime chrome registration must be destroyed on shutdown"
grep -q 'REVIEW_DIALOG_URL = "chrome://zotero-metadata-enricher/content/review.xhtml"' "$ROOT/plugin/chrome/content/main.js" \
  || fail "review dialog must use the runtime chrome:// package"
if grep -q 'state.rootURI + "chrome/content/review.xhtml"' "$ROOT/plugin/chrome/content/main.js"; then
  fail "review dialog regressed to a raw rootURI URL"
fi

# Zotero's translator discovery is asynchronous. The previous synchronous
# .find() call failed at runtime with `translators.find is not a function`.
if grep -q 'translation.getTranslators()' "$ROOT/plugin/chrome/content/main.js"; then
  fail "Copy BibTeX must not use the old synchronous translator-discovery path"
fi
grep -q '9cb70025-a888-4a29-a210-93ec52da40d4' "$ROOT/plugin/chrome/content/main.js" \
  || fail "Copy BibTeX must use Zotero's built-in BibTeX translator UUID"

# Long-running enrichment actions must expose progress, and the review window
# must explicitly handshake readiness so a broken dialog cannot remain blank.
grep -q 'function createProgress' "$ROOT/plugin/chrome/content/main.js" \
  || fail "missing progress feedback helper"
grep -q 'Progress UI unavailable' "$ROOT/plugin/chrome/content/main.js" \
  || fail "progress UI must fail soft rather than abort enrichment"
grep -q 'setProgress(initialProgress)' "$ROOT/plugin/chrome/content/main.js" \
  || fail "progress feedback must expose measurable progress where Zotero supports it"
grep -q 'io.ready = true' "$ROOT/plugin/chrome/content/review.js" \
  || fail "review dialog is missing its readiness handshake"
grep -q 'cleanupStaleRegistrations' "$ROOT/plugin/chrome/content/main.js" \
  || fail "plugin must clean stale menu/item-pane registrations on in-place upgrades"

# Regression guards for v0.2.5 enrichment quality and UX.
grep -q '/v1/combined-enrich' "$ROOT/plugin/chrome/content/main.js"   || fail "plugin is missing combined PDF + online enrichment"
grep -q 'case "/v1/combined-enrich"' "$ROOT/helper/Sources/ZoteroMetadataHelper/HTTPServer.swift"   || fail "helper is missing the combined enrichment endpoint"
grep -q 'lowInformationMetadataValues' "$ROOT/helper/Sources/ZoteroMetadataHelper/Models.swift"   || fail "low-information metadata filtering is missing"
grep -q 'candidateReducesExistingSpecificity' "$ROOT/helper/Sources/ZoteroMetadataHelper/Models.swift"   || fail "date-specificity regression filter is missing"
grep -q 'helperResponseErrorMessage' "$ROOT/plugin/chrome/content/main.js"   || fail "helper application errors must be distinguished from connectivity failures"
grep -q 'launchInstalledHelper' "$ROOT/plugin/chrome/content/main.js"   || fail "plugin should attempt to auto-launch an installed helper"
grep -q 'dataset.field' "$ROOT/plugin/chrome/content/review.js"   || fail "combined review must enforce at most one selected proposal per Zotero field"
if grep -q 'button.append(titleEl, subtitleEl)' "$ROOT/plugin/chrome/content/main.js"; then
  fail "item-pane descriptions must not be embedded inside native Zotero buttons"
fi

# Regression guard for the v0.1.0 macOS startup failure: do not specify
# the same listener port both in requiredLocalEndpoint and NWListener(on:).
if grep -q 'NWListener(using: parameters, on: port)' "$ROOT/helper/Sources/ZoteroMetadataHelper/HTTPServer.swift"; then
  fail "HTTPServer reintroduced the Network.framework EINVAL listener configuration"
fi

[[ -x "$ROOT/scripts/diagnose-helper.sh" ]] || fail "diagnose-helper.sh is not executable"

swift package --package-path "$ROOT/helper" dump-package >/dev/null
swift test --package-path "$ROOT/helper"
swift build --package-path "$ROOT/helper"

"$ROOT/scripts/build-plugin.sh" >/dev/null
XPI="$ROOT/dist/zotero-metadata-enricher-${VERSION}.xpi"
unzip -t "$XPI" >/dev/null
unzip -l "$XPI" | grep -q 'manifest.json' || fail "XPI has no manifest.json"
unzip -l "$XPI" | grep -q 'bootstrap.js' || fail "XPI has no bootstrap.js"
# Zotero requires these files at the XPI root, not under a containing directory.
unzip -Z1 "$XPI" | grep -qx 'manifest.json' || fail "manifest.json is not at XPI root"
unzip -Z1 "$XPI" | grep -qx 'bootstrap.js' || fail "bootstrap.js is not at XPI root"
unzip -Z1 "$XPI" | grep -qx 'chrome/content/review.xhtml' || fail "review.xhtml is missing from XPI"
unzip -Z1 "$XPI" | grep -qx 'chrome/content/review.js' || fail "review.js is missing from XPI"
unzip -Z1 "$XPI" | grep -qx 'chrome/content/review.css' || fail "review.css is missing from XPI"
PACKAGED_UPDATE_URL="$(unzip -p "$XPI" manifest.json | jq -r '.applications.zotero.update_url // empty')"
[[ "$PACKAGED_UPDATE_URL" == https://* ]] || fail "packaged manifest is missing required Zotero update_url"

if [[ "$(uname -s)" == "Darwin" ]]; then
  "$ROOT/scripts/build-helper.sh"
fi

echo "Verification passed for source/package checks."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "NOTE: macOS-only FoundationModels/AppKit/PDFKit code was parsed but not type-checked against an Apple SDK on this host."
fi
