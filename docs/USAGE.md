# Usage

## Choose the correct Zotero object

For a single-item action, select the regular parent bibliographic item, not its PDF attachment, note, or annotation. For a collection action, select exactly one collection.

Actions are available in the selected item's context menu and in the Metadata Enricher item-pane section.

## Actions

### Enrich from PDF + online

Use this when the item has a stored PDF and you want the broadest evidence set.

The helper extracts PDF text locally, asks Apple's on-device model for structured proposals when available, queries Crossref, DataCite, and OpenAlex by DOI or title, then reconciles the results. Exact normalized agreement between PDF and online evidence is marked **Corroborated**. Conflicts remain separate proposals.

### Enrich from stored PDF

Use this when the PDF is the evidence you want to inspect or when online services do not have the record.

The helper:

1. opens the stored PDF with PDFKit;
2. extracts a bounded text excerpt;
3. performs deterministic DOI extraction;
4. uses Apple Foundation Models for PDF-grounded fields, authors, and tags when available;
5. returns proposals to Zotero.

This mode does not query Crossref, DataCite, or OpenAlex. It does not perform OCR, so an image-only scan may yield no useful text.

### Enrich from online sources

Use this to check the item against structured scholarly records. The helper queries Crossref, DataCite, and OpenAlex concurrently. It prefers DOI lookup when a DOI exists and otherwise searches by title. Weak title matches are rejected.

The PDF is not opened or uploaded in this mode.

### Copy BibTeX

This action uses Zotero's built-in BibTeX translator and copies the selected item to the clipboard. It does not start the helper, call Apple Intelligence, query scholarly services, or modify the item.

## Review screen

Each row shows:

| Column | Meaning |
|---|---|
| Apply | Whether the proposal will be written |
| Field | Zotero field or structured creators/tags |
| Current | Value currently in Zotero |
| Proposed | Candidate returned by the helper |
| Source | PDF extraction, Apple Intelligence, or online provider(s) |
| Status | Strength/type of evidence |
| Evidence | Supporting excerpt or match information when available |

Status meanings:

| Status | Interpretation |
|---|---|
| **Verified** | Online record matched the item's DOI |
| **Corroborated** | More than one independent path returned the same normalized value |
| **PDF extracted** | Deterministic extraction from PDF text, currently used for DOI |
| **AI from PDF** | On-device model proposal grounded in the supplied PDF excerpt; review it as a proposal, not a fact |
| **Online** | Online title-based or single-source proposal without exact DOI verification |

**Select safe missing fields** selects missing values with the safer statuses defined by the current UI. It does not make those values infallible. Review them.

The plugin does not automatically select a proposal that would replace a non-empty value. When alternatives conflict, select at most one value for that field.

## Collection enrichment

Right-click one selected collection and choose the PDF, online, or combined collection action. Version 0.2.5 processes regular child items sequentially. For each item you can review, apply, skip, or cancel the remaining run.

Collection mode is intentionally slow and interactive. Start with a small test collection and keep a current Zotero backup.

## Write behavior

- Only checked proposals are considered.
- Scalar fields are mapped to fields valid for the item's Zotero type.
- An accepted author list replaces author creators but preserves editors and other non-author roles.
- Accepted tags are merged with existing tags.
- Unsupported fields are skipped and reported.

## Practical validation

For the first test, use a duplicate or disposable item and accept one obvious missing field. Confirm the saved result in Zotero before running the tool on valuable records or collections.
