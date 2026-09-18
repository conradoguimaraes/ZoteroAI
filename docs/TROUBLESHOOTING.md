# Troubleshooting

## Start with diagnostics

From the repository root:

```bash
./scripts/diagnose-helper.sh
```

The script checks the installed app and executable, running processes, port `43119`, the health endpoint, and recent macOS unified logs.

## Helper does not respond

```bash
open "$HOME/Applications/Zotero Metadata Helper.app"
curl --silent --show-error --fail http://127.0.0.1:43119/health
```

If the reported version/build is not `0.2.5`/`7`, reinstall the helper:

```bash
./scripts/install-helper.sh
```

## Port 43119 is already occupied

```bash
lsof -nP -iTCP:43119 -sTCP:LISTEN
```

Only `ZoteroMetadataHelper` should own this loopback port. Do not expose or forward it. Stop the unexpected process deliberately; do not kill an unidentified process.

## Apple Intelligence is unavailable

PDF mode can still perform deterministic DOI extraction, but model-based fields require Apple's model to be ready. Confirm that the Mac supports Apple Intelligence, that it is enabled for the current user/region/language, and that the model download has completed. Restart the helper after changing the setting.

## PDF mode returns little or no metadata

Version 0.2.5 does not run OCR. Confirm that the stored PDF exists and contains selectable text. Check macOS file permissions for the helper if the file is present but unreadable.

## Online mode finds no match

Common causes are a missing or wrong DOI, a short/generic title, insufficient title similarity, provider coverage, temporary provider failure, or rate limiting. Verify the current DOI/title in Zotero. If the PDF contains the correct DOI, use PDF mode first, apply the DOI after review, and retry online mode.

## Plugin is enabled but controls are missing

1. Confirm Zotero is `10.0.x`.
2. Open **Tools → Plugins** and confirm Zotero Metadata Enricher is enabled.
3. Restart Zotero.
4. Open **Tools → Developer → Error Console** and look for `[ZME]` messages.
5. Toggle the plugin off and on to reproduce startup errors.

The item context menu should show direct actions; there is no nested submenu in v0.2.5. The item-pane navigation should display only the ZME icon with a tooltip.

## Review window is blank

Confirm that the installed plugin is v0.2.5. Versions before v0.2.4 could open the review window through an unreliable raw archive URL. Rebuild the XPI, reinstall it, quit Zotero completely, and reopen it.

## `translators.find is not a function`

That error is from a pre-v0.2.4 build. Version 0.2.5 uses Zotero's built-in BibTeX translator UUID directly. Rebuild and reinstall the current XPI.

## Zotero reports that the XPI may be incompatible

Inspect the packaged manifest:

```bash
unzip -p dist/zotero-metadata-enricher-0.2.5.xpi manifest.json | jq .
```

Confirm `version` is `0.2.5`, `strict_min_version` is `10.0`, `strict_max_version` is `10.0.*`, and `update_url` is HTTPS. Also confirm the XPI has `manifest.json` and `bootstrap.js` at archive root:

```bash
unzip -Z1 dist/zotero-metadata-enricher-0.2.5.xpi | sed -n '1,40p'
```

## Helper error is shown as a connectivity error

That masking bug existed before v0.2.5. Current code decodes non-2xx helper responses and should report missing, unreadable, or unextractable PDFs directly. Confirm both plugin and helper report v0.2.5/build 7.

## Information for a useful bug report

```text
macOS version:
Mac model/architecture:
Zotero version:
Plugin version:
Helper version/build from /health:
Apple Intelligence available true/false:
Action used:
Item type:
Stored PDF yes/no:
Exact error message:
Relevant [ZME] Error Console lines:
Sanitized diagnose-helper output:
```

Do not attach a private PDF, token, complete Zotero database, or uncropped screenshot of a personal library.
