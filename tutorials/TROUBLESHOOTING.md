# Troubleshooting

## “The local Metadata Helper could not be reached”

Check that **ZME** is visible in the macOS menu bar. If not:

```bash
open "$HOME/Applications/Zotero Metadata Helper.app"
```

Then check:

```bash
curl -s http://127.0.0.1:43119/health | python3 -m json.tool
```

If port 43119 is already occupied:

```bash
lsof -nP -iTCP:43119 -sTCP:LISTEN
```

Do not expose this port through port forwarding. The helper is designed for loopback use and also authenticates mutation/enrichment requests with a private token.

## Apple Intelligence says unavailable

PDF-only enrichment can still deterministically extract a DOI, but the AI portion requires Apple's model to be available.

Check that Apple Intelligence is enabled and ready in macOS. Restart the helper after changing that setting.

## The PDF has too little extractable text

Version 0.1.0 does not implement OCR for scanned-image PDFs. Confirm whether you can select/copy text from the PDF. OCR support is planned separately because it should be implemented and tested explicitly rather than silently changing the data path.

## Online enrichment finds nothing

Common reasons:

- the item has neither a DOI nor a sufficiently accurate title;
- the work is not indexed by Crossref, DataCite, or OpenAlex;
- a title search did not meet the conservative similarity threshold;
- a service is temporarily unavailable/rate-limited.

Try PDF-only enrichment first, accept a verified DOI if found, and then retry online enrichment.

## Plugin UI is missing

1. Zotero → **Tools → Plugins**.
2. Confirm **Zotero Metadata Enricher** is enabled.
3. Confirm your Zotero version is 9.0.x.
4. Restart Zotero.
5. If still missing, open **Tools → Developer → Error Console** and look for `[ZME]` messages.

## Copy BibTeX fails

Open Zotero's normal export dialog and check that **BibTeX** is available as an export format. If Zotero's translator installation itself is damaged, use Zotero's translator reset/repair process before debugging this plugin.

## What to collect for a bug report

Provide:

```text
macOS version:
Zotero version:
ZME version/build:
Action used: PDF / online / BibTeX / collection
Item type:
Does the item have a stored PDF: yes/no
Helper /health output:
Relevant [ZME] Error Console output:
Exact error message:
```

Do not send private PDF contents unless they are actually necessary to reproduce the problem.
