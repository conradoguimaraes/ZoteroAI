# How to Enrich One Reference

## Stage 1 — Existing Zotero metadata

Do nothing first. Inspect the metadata Zotero/Connector already downloaded. This is the baseline shown in the **Current** column.

If it is complete and correct, stop. There is no benefit in running AI or network requests merely because they are available.

## Recommended — PDF + online together

Use **Enrich from PDF + online…** when the item has a stored PDF and you want the richest review in one pass. The PDF is analyzed locally, structured scholarly sources are queried online, and matching values are marked **Corroborated**. If the sources disagree, both alternatives are shown and you can select at most one value for that Zotero field.

Low-information placeholders such as `Unpublished` are discarded and less-specific dates are not offered over a more precise existing date for the same year.

## Stage 2 — Stored PDF only

Use **Enrich from stored PDF…** when metadata is incomplete and the attached PDF likely contains the missing information.

This stage:

- reads the local stored PDF;
- extracts text with PDFKit;
- deterministically detects a DOI where possible;
- uses Apple's on-device Foundation Model for additional PDF-grounded fields;
- does not query Crossref, DataCite, or OpenAlex.

In the review window, PDF/AI proposals are clearly labelled. AI-derived fields are not selected automatically.

## Stage 3 — Online scholarly metadata

Use **Enrich from online sources…** when you want to verify or expand bibliographic metadata from external sources.

The helper currently checks Crossref, DataCite, and OpenAlex. Exact DOI matches receive stronger status than title-only matches. Title-only records below the configured similarity threshold are discarded.

Review every replacement of an existing field. A source being online does not make it automatically correct; databases can contain incomplete or conflicting deposits.

## Accepting changes

- Tick only fields you want written.
- Existing fields are not selected automatically.
- **Select safe missing fields** only selects missing values with statuses currently considered safer (`Verified`, `Corroborated`, `PDF extracted`).
- Click **Apply selected**.
- Cancel closes the review without writing anything.
