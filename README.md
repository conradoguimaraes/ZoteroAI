# Zotero Metadata Enricher

Personal-use Zotero extension for macOS that adds three workflows directly to Zotero:

1. **Keep the metadata Zotero already imported.** This is the baseline and remains untouched unless you explicitly approve a replacement.
2. **Enrich from the stored PDF only.** The helper extracts PDF text locally and asks Apple's on-device Foundation Model for candidate metadata. No scholarly web lookup is performed in this stage.
3. **Enrich from online scholarly sources.** The helper queries Crossref, DataCite, and OpenAlex, reconciles the returned records, and presents candidate values for review.

It also adds **Copy BibTeX**, which uses Zotero's own BibTeX export translator and places the result directly on the macOS clipboard.

## Current release

- Version: **0.1.0**
- Build: **1**
- Target Zotero: **9.0.x** (the user's current 9.0.6 is within this compatibility target; runtime validation on that installation is still required)
- Target macOS: **macOS 26+ with Apple Intelligence support**
- Distribution model: personal/local use

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Why this is a plugin + native helper

This repository deliberately does **not** fork Zotero.

```text
Zotero 9
  |
  | small plugin
  | - UI inside Zotero
  | - reads selected items/collections
  | - writes only user-approved changes
  | - uses Zotero's BibTeX translator
  v
localhost authenticated request
  |
  v
Zotero Metadata Helper (native macOS)
  |-- PDFKit -> stored PDF text
  |-- Apple FoundationModels -> PDF-only extraction
  `-- HTTPS -> Crossref / DataCite / OpenAlex
```

This split is intentional. Zotero 9's Local API is useful for reads, but local **write** requests are a Zotero 10+ feature. For Zotero 9, the plugin is therefore the supported place to perform local item updates through Zotero's JavaScript API. The native helper never edits `zotero.sqlite`, never guesses Zotero's storage layout, and never writes bibliographic items itself.

## Safety model

The project treats Zotero as the source of truth.

- Existing metadata is shown as **Current**.
- New values are shown as **Proposed**.
- Every proposal includes **Source**, **Status**, and evidence where available.
- Existing non-empty fields are never pre-selected for replacement.
- AI-derived PDF fields are never pre-selected automatically.
- Missing fields backed by a deterministic PDF extraction or a strong online match can be pre-selected, but the user still sees the review screen before anything is saved.
- Accepting a proposed author list preserves existing non-author creator roles such as editors or translators.
- Tags are merged rather than silently replacing existing tags.

Candidate statuses are:

- `Verified` — exact identifier-backed online record.
- `Corroborated` — at least two online sources agree on the normalized value.
- `PDF extracted` — deterministic extraction from the local PDF, currently DOI pattern matching.
- `AI from PDF` — Apple Intelligence interpretation grounded only in the stored PDF text.
- `Online` — a sufficiently strong title-matched online record that is not independently corroborated.

## What appears in Zotero

For a selected bibliographic item, the plugin adds a **Metadata Enricher** section to the right item pane and item context-menu actions:

- **Enrich from stored PDF…**
- **Enrich from online sources…**
- **Copy BibTeX**

For a selected collection, its context menu adds:

- **Enrich collection from stored PDFs…**
- **Enrich collection from online sources…**

Version 0.1.0 intentionally reviews collection items one at a time. That is slower than a blind batch write but substantially safer for a first release. A consolidated batch-review screen is a planned improvement.

## Important Siri / Apple Intelligence limitation

The app does **not** automate the macOS “Ask Siri” interface. Apple exposes the on-device model through `FoundationModels`, but does not expose a public API equivalent to “give this PDF to Siri and return Siri's web-enabled answer”.

Therefore:

- PDF-only enrichment uses `SystemLanguageModel.default` directly.
- Online bibliographic enrichment uses explicit scholarly APIs.
- The PDF itself is **not sent to Crossref, DataCite, or OpenAlex**. Stage 3 sends bibliographic identifiers/title needed for lookups.
- Generic Siri web search is not claimed or simulated.

This design is more auditable for reference metadata than allowing a language model to invent bibliographic facts from unrestricted web results.

## Quick installation

Start with [tutorials/INSTALL.md](tutorials/INSTALL.md). The short version is:

```bash
cd /path/to/zotero-metadata-enricher
chmod +x scripts/*.sh
./scripts/install-helper.sh
./scripts/build-plugin.sh
```

Then open Zotero → **Tools → Plugins** and drag `dist/zotero-metadata-enricher-0.1.0.xpi` into the Plugins window.

After both pieces are installed, follow [tutorials/FIRST_RUN.md](tutorials/FIRST_RUN.md).

## Repository layout

```text
.
├── VERSION
├── BUILD
├── CHANGELOG.md
├── plugin/                     Zotero 9 plugin
├── helper/                     native Swift helper
├── scripts/                    build/install/verification scripts
├── tutorials/                  user and developer how-to guides
└── .github/workflows/          CI verification
```

## Verification

Run:

```bash
./scripts/verify.sh
```

It checks JavaScript syntax, manifest/version consistency, Swift package/tests, builds the plugin XPI, and validates the XPI. On macOS it additionally builds the native helper against the installed Apple SDK.

A successful source build is **not** proof that the Zotero runtime integration works on your exact Zotero/macOS installation. The first-run procedure includes runtime checks, and issues should be reported with the diagnostics requested in [tutorials/TROUBLESHOOTING.md](tutorials/TROUBLESHOOTING.md).

## Development and releases

- [tutorials/DEVELOPMENT.md](tutorials/DEVELOPMENT.md)
- [tutorials/RELEASES.md](tutorials/RELEASES.md)
- [tutorials/ARCHITECTURE.md](tutorials/ARCHITECTURE.md)
- [tutorials/GITHUB.md](tutorials/GITHUB.md)

## Privacy

Stage 2 is designed to be local: PDF text is processed using PDFKit and Apple's on-device `SystemLanguageModel`.

Stage 3 makes normal HTTPS requests to Crossref, DataCite, and OpenAlex. It does not upload the PDF. Review the privacy policies and terms of those services if that matters for a particular library.

## License and affiliation

Original code in this repository is provided under the MIT License. See [LICENSE](LICENSE).

This is a private, unofficial project. It is not affiliated with, endorsed by, or distributed by Zotero or Digital Scholar. “Zotero” is used only to describe compatibility with the Zotero application.
