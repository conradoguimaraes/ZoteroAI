# How to Enrich a Collection

In Zotero, right-click a collection and choose either:

- **Metadata Enricher → Enrich collection from stored PDFs…**, or
- **Metadata Enricher → Enrich collection from online sources…**.

v0.2.5 still processes regular bibliographic items sequentially and asks for review before each write. This is intentionally conservative.

For each item:

1. Zotero shows which item is next.
2. Continue or cancel to stop the run.
3. The helper generates candidates.
4. Review/accept/reject the fields.
5. Zotero writes only selected fields.

Start with a small test collection before using it on a large library.

For collections, **Enrich Collection from PDFs + Online…** uses the same combined evidence path item-by-item. Collection processing remains deliberately sequential in v0.2.5.
