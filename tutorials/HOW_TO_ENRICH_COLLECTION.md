# How to Enrich a Collection

In Zotero, right-click a collection and choose either:

- **Metadata Enricher → Enrich collection from stored PDFs…**, or
- **Metadata Enricher → Enrich collection from online sources…**.

Version 0.1.0 processes regular bibliographic items sequentially and asks for review before each write. This is intentionally conservative.

For each item:

1. Zotero shows which item is next.
2. Continue to process it or cancel to stop the collection run.
3. The helper generates candidates.
4. Review/accept/reject the fields.
5. Zotero writes only the selected fields.

At the end Zotero reports changed, unchanged, and failed items.

## Practical recommendation

First run collection enrichment on a small test collection of 5–10 items. Only after you have checked the behavior with your own library should you use it on a large collection.

A future version is intended to add one consolidated batch-review table with progress/cancellation. That is deliberately not implemented as an unreviewed bulk overwrite in 0.1.0.
