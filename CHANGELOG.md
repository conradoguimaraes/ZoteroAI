# Changelog

All notable changes to this personal project are tracked here. The project uses semantic versioning for source/plugin versions and a separate monotonically increasing build number.

## [0.1.0] - 2026-09-18 — Build 1

### Added

- Zotero 9 plugin targeting `9.0.*`.
- Metadata Enricher item-pane section.
- Item context-menu actions for PDF-only enrichment, online enrichment, and Copy BibTeX.
- Collection context-menu actions for PDF-only and online enrichment.
- Field-by-field review dialog showing current value, proposed value, source, status, and evidence.
- Conservative defaults that do not pre-select replacements of existing metadata or AI-derived PDF fields.
- Native macOS helper with authenticated localhost communication.
- PDFKit extraction from stored PDFs.
- Apple Foundation Models structured PDF-only metadata extraction.
- Deterministic DOI extraction from PDF text.
- Crossref, DataCite, and OpenAlex online metadata providers.
- Multi-source reconciliation and provenance/status tracking.
- DOI/title consistency guard before trusting identifier-resolved records.
- Conservative creator handling that avoids guessing family-name boundaries from undivided display names.
- Zotero-native BibTeX export to clipboard.
- Build, install, verification, packaging, and optional login-helper scripts.
- Unit tests for pure metadata-normalization/matching logic.
- Installation, first-run, usage, troubleshooting, architecture, development, and release tutorials.

### Known limitations

- Scanned-image PDFs without extractable text are not OCR'd in 0.1.0.
- Collection enrichment reviews items sequentially rather than using one consolidated batch-review screen.
- Online enrichment uses structured scholarly sources rather than Siri's private web-search pipeline.
- OpenAlex anonymous access is suitable for light personal use; a free API key may be useful for larger batch workloads, but key configuration is not implemented yet.
- macOS-specific FoundationModels/Zotero runtime behavior must be validated on the target Mac; CI/source checks cannot prove real Zotero integration on every installation.
