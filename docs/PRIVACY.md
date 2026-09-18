# Privacy

## Summary

Zotero Metadata Enricher has local-only and networked workflows. Choosing the mode determines what leaves the Mac.

| Mode | Local data used | External recipients | PDF uploaded? |
|---|---|---|---|
| Copy BibTeX | Selected Zotero item | None | No |
| PDF | Item snapshot, local PDF path and extracted text | None by this project's code path | No |
| Online | Item snapshot, primarily DOI and/or title | Crossref, DataCite, OpenAlex | No |
| PDF + online | Both data sets above | Crossref, DataCite, OpenAlex for DOI/title lookup | No |

## Local processing

The Zotero plugin sends an item snapshot and, when required, a local PDF path to the helper over `127.0.0.1:43119`. The helper opens the PDF with PDFKit. Apple documents `SystemLanguageModel` as an on-device model powering Apple Intelligence; v0.2.5 uses that default model through Foundation Models.

The helper's `/health` endpoint is accessible on loopback without a token. Enrichment endpoints require a random local token stored at:

```text
~/Library/Application Support/Zotero Metadata Enricher/token
```

The token file is created with owner-only permissions. Do not publish it, include it in bug reports, or paste it into an issue.

## Online processing

For online and combined enrichment, the helper sends a DOI when present or a title search to:

- `api.crossref.org`;
- `api.datacite.org`;
- `api.openalex.org`.

The providers receive ordinary network metadata such as the IP address and request headers in addition to the query. Their own terms, logging, retention, availability, and rate limits apply. This project does not control those services.

The current implementation does not send the PDF file or extracted PDF text to those scholarly APIs.

## Zotero data

The helper returns proposals only. It never writes `zotero.sqlite` or attachment storage. The Zotero plugin writes through Zotero APIs after explicit user selection in the review window.

Accepted metadata can subsequently sync through Zotero if the user's Zotero account has syncing enabled. That is normal Zotero behavior, not a helper network request.

## Logs and diagnostics

The diagnostic script reports helper installation/running state, port ownership, the health response, and recent helper log entries. Review diagnostic output before sharing it publicly. Do not include private PDF contents, the token file, or a full screenshot of a personal Zotero library in an issue.

## Screenshots in this repository

Use a clean demonstration profile containing public sample records. Crop captures to the plugin interface and verify the background, collection names, tags, file paths, account names, and document titles before committing them.

The public cleanup package intentionally does not reuse the supplied full-window screenshots: their backgrounds expose a real library, and the review capture includes data derived from a locally stored paper. A clean reproducible demo is safer than partially redacting a personal screenshot.

## No privacy guarantee beyond the reviewed code

Zotero plugins execute with extensive access to Zotero and the computer. Review the source and install only builds from a trusted source. This document describes v0.2.5 at the repository revision from which it was generated; future versions may change the data flow.
