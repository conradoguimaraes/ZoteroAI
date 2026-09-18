# Changelog

All notable changes to this personal project are tracked here. The project uses semantic versioning for source/plugin versions and a separate monotonically increasing build number.

## [0.2.5] - 2026-09-18 — Build 7

### Added

- Added **Enrich from PDF + Online…** for individual references and collections. The helper combines PDF-only extraction/Apple Intelligence with Crossref, DataCite, and OpenAlex results in one review.
- Exact agreement between PDF and online sources is merged into one **Corroborated** proposal. Conflicting values remain separate alternatives.
- The review window now prevents selecting more than one proposal for the same Zotero field and does not auto-select conflicted fields.

### Fixed

- Low-information values such as `Unpublished`, `Unknown`, `N/A`, `Not available`, and similar placeholders are now discarded instead of being offered as metadata.
- A coarse date from an online source (for example `2020`) is not proposed over a more precise existing date for the same year (for example `2020-08-31`).
- Fixed PDF/helper failures being incorrectly reported as “The local Metadata Helper could not be reached.” Non-2xx helper responses are now decoded and the actual PDF/permission/error message is shown.
- If the helper is genuinely not running, the plugin attempts to launch the installed helper and retries before asking the user to intervene.

### UX

- Added elapsed-time progress text during long PDF/combined Apple Intelligence requests.
- Reworked the right item-pane actions so descriptions are outside native buttons; this avoids the overlapping/clipped text seen in Zotero 10.
- Combined-mode conflicts are visually marked as alternatives.

### Verified

- JavaScript syntax checks pass.
- Review XHTML parses as XML.
- XPI structure/version checks pass.
- Swift package builds on the CI host and **8/8 unit tests pass**, including placeholder filtering, date-specificity filtering, combined corroboration, and conflict preservation.
- macOS-only FoundationModels/PDFKit runtime behavior still requires validation on the target Mac.

## [0.2.4] - 2026-09-18 — Build 6

### Fixed

- Fixed blank metadata-review windows. Zotero 7+ bootstrapped plugins no longer use `chrome.manifest`; the plugin now registers its `chrome/content/` package at runtime with `amIAddonManagerStartup.registerChrome()` and opens the review UI through `chrome://zotero-metadata-enricher/content/review.xhtml`.
- Added a review-window readiness handshake and a five-second initialization timeout. A broken dialog now fails with a concrete error instead of leaving a permanently blank window.
- Fixed **Copy BibTeX** failing with `translators.find is not a function`. `Zotero.Translate.getTranslators()` is asynchronous; v0.2.4 avoids discovery entirely and calls Zotero's current built-in BibTeX translator by its stable UUID `9cb70025-a888-4a29-a210-93ec52da40d4`.
- Added defensive cleanup of stale namespaced MenuManager and ItemPaneManager registrations before re-registering, preventing `menuID must be unique` / `paneID must be unique` errors during in-place plugin upgrades.

### UX

- PDF enrichment now shows progress states for reading Zotero metadata, finding the stored PDF, and running Apple Intelligence. Where Zotero exposes progress percentages, the indicator advances through the major stages instead of looking frozen.
- Online enrichment now shows visible progress while Crossref, DataCite, and OpenAlex are queried.
- Applying approved fields shows progress instead of appearing frozen.
- Successful writes and BibTeX copies now use non-blocking Zotero progress notifications instead of modal OK-only dialogs. Progress-window failures are fail-soft: a notification rendering problem is logged but cannot abort the metadata operation itself.
- The item-pane actions now include concise explanations of PDF-only, online, and BibTeX behavior.
- The review window now clearly distinguishes current/proposed values, flags replacements, shows source/status/evidence, and explains that AI-derived PDF values are proposals rather than verified facts.

### Verified

- JavaScript syntax checks pass.
- Manifest/version/build consistency checks pass.
- Swift unit tests pass.
- XPI package integrity checks pass, including the review UI resources. The review XHTML is parsed as XML during verification so malformed markup cannot silently ship as another blank window.
- Regression guards verify runtime chrome registration, review readiness handshaking, progress feedback, stable BibTeX translator usage, and stale-registration cleanup.
- Actual Zotero 10/macOS GUI behavior still requires runtime verification on the target Mac.

## [0.2.3] - 2026-09-18 — Build 5

### Fixed

- Replaced the three-item nested Zotero context submenu with three direct item-menu commands: **Enrich Metadata from Stored PDF…**, **Enrich Metadata Online…**, and **Copy BibTeX**. Zotero's MenuManager officially supports direct `menuitem` registrations, and this removes the submenu lifecycle path that was visibly failing to open on Zotero 10.0.3.
- Moved item visibility checks to the individual direct menu items using the documented `main/library/item` menu context.
- Updated collection menu handling to use Zotero 10's `collectionTreeRows` context and pass the exact right-clicked collection into the batch action.
- Fixed the malformed custom ItemPane side navigation entry. The section header continues to use a Fluent `.label`, while the side navigation now has a separate Fluent `.tooltiptext`, matching Zotero's ItemPane localization contract.
- Removed a duplicated stored-PDF path lookup discovered during review.

### UX

- Metadata actions are now one click directly from the item context menu; there is no nested Metadata Enricher submenu.
- The right-side navigation contains only the plugin icon; “Metadata Enricher” appears as its tooltip instead of overflowing as visible vertical text.

### Verified

- JavaScript syntax checks pass.
- Manifest/version/build consistency checks pass.
- Swift unit tests pass.
- XPI root/package integrity checks pass.
- Static regression guards check the side-nav `.tooltiptext` localization and prevent reintroduction of the nested submenu in the item context menu.
- Zotero GUI runtime verification remains required on the target Mac.

## [0.2.2] - 2026-09-18 — Build 4

### Fixed

- Fixed Zotero plugin startup failing with `console is not defined` in `bootstrap.js`. The bootstrapped Zotero scope does not guarantee a browser-style `console` global; logging already uses `Zotero.debug`, so the invalid scope injection was removed.
- Updated collection selection for Zotero 10 to use `getSelectedCollections()` and require exactly one selected collection, while retaining a defensive fallback for older development snapshots.
- Added a verification guard that fails the build if `bootstrap.js` reintroduces a bare `console` scope dependency.

### Verified

- JavaScript syntax checks pass.
- Manifest/version/build consistency checks pass.
- Swift unit tests pass.
- XPI root/package integrity checks pass.
- The exact runtime failure reported in Zotero is addressed at its source line in `bootstrap.js`; Zotero GUI runtime verification remains required on the target Mac.

## [0.2.1] - 2026-09-18 — Build 3

### Fixed

- Fixed Zotero 10 rejecting the XPI with the generic “may be incompatible” installation error.
- Added the `applications.zotero.update_url` manifest entry required by Zotero's add-on manager for manually installed bootstrapped plugins.
- Changed the plugin ID from the ambiguous `zotero-metadata-enricher@local` form to the email-like `zotero-metadata-enricher@local.invalid` form used by Gecko/Zotero add-on IDs. The `.invalid` TLD is reserved and cannot resolve to a real public host.
- Added a homepage URL so the add-on metadata is complete.
- Added verification guards so future builds fail if the packaged manifest is missing `update_url`, has a malformed add-on ID, has the wrong Zotero 10 compatibility range, or places `manifest.json` / `bootstrap.js` below the XPI root.

### Notes

- The placeholder update URL uses `example.com` only to satisfy Zotero's manifest requirement for this private/manual installation. Automatic updates are not relied upon. Replace it with the repository's real `updates.json` URL if/when the project is published to a personal GitHub repository.

## [0.2.0] - 2026-09-18 — Build 2

### Changed

- Target moved from Zotero 9 to **Zotero 10.0.x**.
- Plugin compatibility is now `10.0` through `10.0.*`.
- Collection review text now uses the running plugin version instead of a hard-coded release number.
- Installation now stops an older helper before replacement and waits for a real `/health` response before reporting success.
- Added `scripts/diagnose-helper.sh` for startup/port/process/log diagnostics.

### Fixed

- Fixed the macOS helper startup failure `Network.NWError error 22 - Invalid argument`.
- Root cause: the helper configured `NWParameters.requiredLocalEndpoint` with `127.0.0.1:43119` and also passed the same explicit port to `NWListener(using:on:)`. Network.framework treats those two simultaneous port specifications as incompatible and throws `EINVAL` before the listener starts.
- The listener now uses the required loopback endpoint as the single source of local-address/port configuration.

### Safety / scope

- The helper still listens only on `127.0.0.1:43119` and enrichment requests still require the private local token.
- Zotero remains the source of truth. Only user-approved candidates are written.
- No direct SQLite or Zotero storage-directory writes were introduced.
- Zotero 10's Local API write support is available for future refactoring, but v0.2.0 deliberately keeps the already-developed plugin write path to minimize regression surface while fixing the actual startup failure.

### Known limitations

- Scanned-image PDFs without extractable text are not OCR'd.
- Collection enrichment still reviews items sequentially rather than using one consolidated batch-review screen.
- Online enrichment uses structured scholarly sources rather than Siri's private web-search pipeline.
- macOS-specific runtime behavior must still be validated on the target Mac after this build is installed.

## [0.1.0] - 2026-09-18 — Build 1

### Added

- Initial Zotero 9 prototype.
- Metadata Enricher item-pane section and item/collection context-menu actions.
- PDF-only enrichment using PDFKit + Apple Foundation Models.
- Online enrichment using Crossref, DataCite, and OpenAlex.
- Review-before-write workflow with provenance/status.
- Zotero-native Copy BibTeX.
- Build, install, verification, packaging, tests, and tutorials.
