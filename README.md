# Zotero Metadata Enricher

Personal-use Zotero extension for macOS with four workflows:

1. keep the metadata Zotero already imported;
2. enrich from the stored PDF only using PDFKit + Apple Foundation Models;
3. enrich from structured online scholarly sources and review every proposed field before writing it;
4. run **PDF + online** together and reconcile/corroborate the results in one review.

It also adds one-click **Copy BibTeX** using Zotero's own BibTeX translator.

## Current release

- Version: **0.2.5**
- Build: **7**
- Target Zotero: **10.0.x**
- Target macOS: **macOS 26+ with Apple Intelligence support**
- Distribution: personal/local use

## Architecture

The project intentionally remains a small Zotero plugin plus a native macOS helper:

```text
Zotero 10
  |
  | plugin
  | - buttons/context menus
  | - selected item/collection
  | - review UI
  | - approved Zotero writes
  | - Zotero-native BibTeX export
  v
127.0.0.1:43119 + private token
  |
  v
Zotero Metadata Helper
  |-- PDFKit
  |-- Apple FoundationModels
  `-- Crossref / DataCite / OpenAlex
```

The helper never edits `zotero.sqlite` and never guesses Zotero's storage layout.


## v0.2.5 filtering, combined enrichment, and error handling

v0.2.5 focuses on the first real enrichment results and PDF error report:

- low-information placeholders such as **Unpublished**, **Unknown**, `N/A`, and similar values are discarded before they reach the review window;
- a less-specific date such as `2020` is no longer proposed over an existing `2020-08-31`;
- a new **Enrich from PDF + online** action runs both evidence paths and marks exact cross-source agreement as **Corroborated**;
- conflicting PDF/online alternatives remain separate and the review UI enforces at most one accepted value per Zotero field;
- helper HTTP errors are no longer all misreported as “helper could not be reached”; PDF/open/permission errors are surfaced directly;
- if the helper is actually stopped, the plugin attempts to launch `~/Applications/Zotero Metadata Helper.app` and retries;
- PDF/combined operations use a longer timeout and show elapsed time while Apple Intelligence is working;
- item-pane controls use normal Zotero buttons with descriptions outside the button, avoiding text overlap/clipping.

## v0.2.4 UI/runtime hardening

v0.2.4 fixes the first real Zotero 10 runtime issues found during testing:

- the metadata review window is now loaded from a runtime-registered `chrome://` package instead of a raw XPI `jar:file` URL;
- review windows use a readiness handshake and fail with a useful error instead of remaining blank indefinitely;
- PDF and online enrichment now show visible progress while the helper is working;
- Copy BibTeX uses Zotero's built-in BibTeX translator UUID directly, avoiding the asynchronous `getTranslators()` misuse that caused `translators.find is not a function`;
- success notifications are non-blocking;
- in-place plugin upgrades proactively remove stale menu/item-pane registrations before re-registering them;
- the item-pane controls now explain exactly what each action does.

## v0.2.0 startup fix

v0.1.0 could fail immediately with:

```text
Network.NWError error 22 - Invalid argument
```

The cause was an invalid Network.framework listener configuration: the same listener port was specified both in `requiredLocalEndpoint` and in `NWListener(using:on:)`. v0.2.0 uses the loopback `requiredLocalEndpoint` as the single address/port definition.

## Safety model

- Existing values are shown as **Current**.
- New values are shown as **Proposed**.
- Every proposal has a source/status/evidence where available.
- Existing non-empty fields are not pre-selected for replacement.
- AI-from-PDF fields are not automatically treated as verified.
- Metadata is written only after user approval.
- Tags are merged rather than silently replaced.
- Existing non-author creator roles are preserved when accepting a proposed author list.

## Install

Read [tutorials/INSTALL.md](tutorials/INSTALL.md). In short:

```bash
cd /path/to/ZoteroAI
chmod +x scripts/*.sh
./scripts/install-helper.sh
./scripts/build-plugin.sh
```

Then install `dist/zotero-metadata-enricher-0.2.5.xpi` from Zotero **Tools → Plugins**.

## Repository layout

```text
.
├── VERSION
├── BUILD
├── CHANGELOG.md
├── plugin/
├── helper/
├── scripts/
├── tutorials/
└── .github/workflows/
```

## Verification

Run:

```bash
./scripts/verify.sh
```

On macOS this builds the native helper against the installed Apple SDK. Runtime Zotero integration still needs to be exercised on the actual Mac/Zotero installation.

## Documentation

- [Installation](tutorials/INSTALL.md)
- [First run](tutorials/FIRST_RUN.md)
- [Enrich one reference](tutorials/HOW_TO_ENRICH_ONE_REFERENCE.md)
- [Enrich a collection](tutorials/HOW_TO_ENRICH_COLLECTION.md)
- [Copy BibTeX](tutorials/HOW_TO_COPY_BIBTEX.md)
- [Troubleshooting](tutorials/TROUBLESHOOTING.md)
- [Architecture](tutorials/ARCHITECTURE.md)
- [Development](tutorials/DEVELOPMENT.md)
- [Releases](tutorials/RELEASES.md)

## Privacy

PDF-only enrichment is designed to remain local: PDF text is extracted locally and processed with Apple's on-device Foundation Model.

Online enrichment sends bibliographic identifiers/title information to Crossref, DataCite, and OpenAlex. The PDF itself is not uploaded to those services.

## License and affiliation

Original code in this repository is provided under the MIT License. This is an unofficial personal project and is not affiliated with or endorsed by Zotero or Digital Scholar.
