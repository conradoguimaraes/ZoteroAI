# First Run

Do the first test on **one reference whose correct metadata you already know**. Do not start with a large collection.

## 1. Confirm the helper

Look for **ZME** in the macOS menu bar.

If it is missing, open:

```text
~/Applications/Zotero Metadata Helper.app
```

or run:

```bash
open "$HOME/Applications/Zotero Metadata Helper.app"
```

## 2. Confirm the Zotero UI

Select one normal bibliographic item in Zotero. In the right item pane you should find a section named **Metadata Enricher** with:

- Enrich from PDF + online
- Enrich from stored PDF
- Enrich from online sources
- Copy BibTeX

The same actions should appear when you right-click a reference. Collection enrichment actions should appear when you right-click a Zotero collection.

## 3. Test Copy BibTeX first

Click **Copy BibTeX**, paste into TextEdit or a code editor, and verify that a BibTeX entry appears. This operation does not modify the Zotero item.

## 4. Test combined enrichment

Use an item with a stored PDF and click **Enrich from PDF + online**. This is the recommended normal workflow. Zotero should immediately show progress and then one review window combining local PDF evidence and online scholarly metadata. Exact agreement is marked **Corroborated**. If two sources disagree on the same field, the review shows alternatives and lets you select at most one.

## 5. Test PDF-only enrichment

Use an item with a stored PDF.

Click **Enrich from stored PDF**. Zotero should immediately show a small **Metadata Enricher** progress window while the PDF is located and analyzed. When analysis finishes, the review window must show:

- Current value
- Proposed value
- Source
- Status
- Evidence

For the first test, select only one obviously correct missing field and apply it. Confirm the field changes in Zotero.

## 6. Test online enrichment

Click **Enrich from online sources**. Zotero should immediately show progress while Crossref, DataCite, and OpenAlex are checked. When the review opens, check that the proposed record actually corresponds to the same publication before accepting anything.

The first release intentionally favors refusing weak matches over filling fields aggressively.

## 7. Back up before bulk use

Before running the feature over an important collection, make sure your Zotero data is backed up/synchronized according to your normal Zotero workflow. The plugin only writes approved changes, but bulk metadata edits are still real data changes.
