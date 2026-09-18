# Troubleshooting

## Helper does not start

Run:

```bash
cd ~/Documents/Github/ZoteroAI
./scripts/diagnose-helper.sh
```

The script reports whether the app/binary exists, whether a helper process is running, whether port 43119 is occupied, whether `/health` responds, and recent macOS unified-log messages.

## `Network.NWError error 22 - Invalid argument`

That was a v0.1.0 bug. v0.2.0 removes the conflicting Network.framework port configuration.

Confirm you are actually running the new helper:

```bash
curl -s http://127.0.0.1:43119/health
```

The response must report:

```text
version 0.2.5
build 7
```

If not, reinstall:

```bash
pkill -x ZoteroMetadataHelper 2>/dev/null || true
./scripts/install-helper.sh
```

## Port 43119 is occupied

```bash
lsof -nP -iTCP:43119 -sTCP:LISTEN
```

Only `ZoteroMetadataHelper` should own the port. Do not expose or forward this port.

## Apple Intelligence unavailable

PDF-only enrichment can still perform deterministic DOI extraction, but AI extraction requires Apple's model to be available. Confirm Apple Intelligence is enabled and ready in macOS, then restart the helper.

## PDF has too little extractable text

v0.2.5 does not yet perform OCR on scanned-image PDFs. Confirm whether the PDF contains selectable text.

## Online enrichment finds nothing

Possible causes include missing/wrong DOI/title, insufficient title similarity, provider coverage, or provider availability. Try PDF-only enrichment first and retry online enrichment after reviewing any extracted DOI/title correction.

## Plugin UI is missing

1. Zotero → **Tools → Plugins**.
2. Confirm **Zotero Metadata Enricher 0.2.5** is enabled.
3. Confirm Zotero is **10.0.x**.
4. Restart Zotero.
5. Open **Tools → Developer → Error Console** and look for `[ZME]` messages.

## Plugin installs but no Metadata Enricher UI appears

Open **Tools → Developer → Error Console**, clear it, then toggle the plugin off and on in **Tools → Plugins**.

If v0.2.1 build 3 reports:

```text
Error running bootstrap method 'startup'
console is not defined
```

upgrade to v0.2.2 build 4. The problem was in `bootstrap.js`: it tried to inject a browser-style `console` global into the subscript scope even though Zotero's bootstrapped plugin environment does not guarantee that global. v0.2.2 removes the invalid dependency and keeps logging through `Zotero.debug`.

## Metadata Enricher menu is visible but submenu does not open / side-nav label is malformed

This was fixed in v0.2.3 build 5. The item context menu now uses three direct actions instead of a nested submenu, which is simpler and avoids submenu lifecycle issues. The item-pane side navigation now uses a dedicated Fluent localization entry with `.tooltiptext` instead of reusing the section header `.label`; Zotero side-nav buttons expect tooltip localization rather than visible label text.

After upgrading, a right-click on one regular bibliographic item should show these direct entries near the bottom of the menu:

```text
Enrich Metadata from Stored PDF…
Enrich Metadata Online…
Copy BibTeX
```

The right-side navigation should show only the ZME icon, with “Metadata Enricher” as its hover tooltip.

## Bug-report information

Provide:

```text
macOS version:
Zotero version:
ZME version/build:
Action used:
Item type:
Stored PDF: yes/no
./scripts/diagnose-helper.sh output:
Relevant [ZME] Error Console output:
Exact error message:
```

## Zotero says “may be incompatible” while installing the XPI

For v0.2.0 this was caused by an incomplete Zotero add-on manifest: the XPI declared the Zotero version range but omitted `applications.zotero.update_url`. Zotero reports this as a generic compatibility/install error. v0.2.1 build 3 adds the required update URL and uses an email-like plugin ID.

Verify the package before installation:

```bash
unzip -p dist/zotero-metadata-enricher-0.2.1.xpi manifest.json | jq .
```

The manifest must contain `applications.zotero.update_url`, `strict_min_version: "10.0"`, and `strict_max_version: "10.0.*"`.

## Enrichment opens a blank window / Copy BibTeX says `translators.find is not a function`

These are v0.2.3 runtime bugs fixed in v0.2.4 build 6. The review window was opened directly from the XPI `rootURI`, which is not a reliable chrome-window registration path for Zotero 7+ bootstrapped plugins. The plugin now registers its content package at runtime and opens a stable `chrome://` URL.

The BibTeX failure came from treating `translation.getTranslators()` as synchronous even though Zotero documents it as returning a Promise. v0.2.4 uses Zotero's built-in BibTeX translator UUID directly.

After upgrading to v0.2.4, quit Zotero completely and reopen it. If the plugin was upgraded while Zotero was running, v0.2.4 also removes stale menu/item-pane registrations before registering its UI again.

Long-running enrichment now displays a Zotero progress window. If no progress window appears after clicking an enrichment action, collect the Error Console output before retrying.

## PDF enrichment says the helper cannot be reached, but `/health` works

v0.2.4 could hide a real PDF/helper error behind a generic connectivity message because Zotero HTTP exceptions for non-2xx responses were caught as if the helper were offline. v0.2.5 decodes the helper response first. Retry the PDF action: you should now see the real problem (missing file, unreadable PDF, too little extractable text, timeout, etc.).

If the helper is actually stopped, v0.2.5 attempts to launch `~/Applications/Zotero Metadata Helper.app` automatically before failing.
