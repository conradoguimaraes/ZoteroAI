# Architecture

## Design decision

Use a **minimal Zotero plugin** for integration and writes, plus a **native macOS helper** for Apple Intelligence/PDF/network work.

A Zotero fork was rejected because it would create a large upstream maintenance burden for three small UI actions. An external app alone was rejected for Zotero 9 because the Local API supports local writes only in Zotero 10+ and because the desired controls belong inside the Zotero workflow.

## Data flow

```text
Stage 1: baseline
Zotero Connector/import -> Zotero item + stored PDF
                              |
                              v
Stage 2: PDF only       plugin snapshots current item
                              |
                              +-> stored PDF path
                              |
                              v
                         native helper
                         PDFKit + FoundationModels
                              |
                         candidate fields
                              |
                              v
                         review dialog
                              |
                         approved only
                              |
                              v
                         Zotero JS API write

Stage 3: online         plugin snapshots current item
                              |
                              v
                         native helper
                    DOI/title -> Crossref/DataCite/OpenAlex
                              |
                         reconcile/provenance
                              |
                              v
                         review dialog
                              |
                         approved only
                              |
                              v
                         Zotero JS API write
```

## Trust boundaries

### Zotero plugin

Trusted with the user's Zotero library because Zotero plugins run with powerful application privileges. Responsibilities are intentionally narrow:

- determine selected item/collection;
- obtain attachment path through Zotero's API;
- snapshot metadata;
- show review UI;
- apply explicitly selected candidates;
- export BibTeX using Zotero's translator framework.

### Native helper

Does not modify Zotero. It accepts an item snapshot and, for PDF mode, a local PDF path. It returns proposals only.

The helper listens on `127.0.0.1:43119` and enrichment requests require a random token stored with user-only file permissions.

### External services

Online mode currently makes HTTPS requests to:

- Crossref;
- DataCite;
- OpenAlex.

The PDF file/body is not uploaded to these services. Queries use DOI/title-derived bibliographic information.

## Matching/reconciliation

Exact DOI lookup is preferred. Without a DOI, providers are searched by title. A title result below normalized Jaccard similarity `0.72` is discarded. Because an existing DOI can itself be wrong, a DOI-resolved record is rejected when the Zotero item already has a title and the resolved record is clearly inconsistent with it (similarity below `0.55`); that provider then falls back to a title search instead of trusting the questionable DOI. These are deliberately conservative matching heuristics, not probabilities.

Values are normalized before cross-source comparison. If two or more independent providers return the same normalized value, that proposal is marked `Corroborated`. An exact identifier-backed single-source value that passes the DOI/title sanity check is marked `Verified`. A title-only single-source value remains `Online` and is not treated as independently verified. Creator names are proposed only when a provider supplies structured given/family-name components; the helper does not split a single display name heuristically.

These labels describe the **lookup evidence**, not absolute truth. The review screen remains authoritative for writes.

## PDF model path

The PDF extractor intentionally limits the model excerpt because Apple's on-device model has a finite context window. Bibliographic metadata is normally concentrated on the first pages. The helper currently takes an excerpt from the front of the paper and, if room remains, the final pages.

The Foundation Model instruction explicitly tells the model to use only supplied PDF text and to omit uncertain values. AI candidates are still marked `AI from PDF`, not `Verified`.

## Replaceability

Provider logic lives in `ScholarlySources.swift`; model logic lives in `AppleIntelligenceAnalyzer.swift`; Zotero integration lives in the plugin. A future model or metadata provider can therefore be replaced without redesigning Zotero writes.
