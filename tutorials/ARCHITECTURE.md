# Architecture

## Current design

Use a **minimal Zotero 10 plugin** for Zotero UI/review/writes and a **native macOS helper** for PDFKit, Apple Foundation Models, and scholarly network lookups.

A full Zotero fork remains unjustified for these small user-facing actions.

Zotero 10 now exposes authenticated Local API writes, which is a viable future boundary for moving more write logic out of the plugin. v0.2.0 deliberately does not perform that larger refactor while fixing the concrete helper startup bug; retaining the already-developed review/write path minimizes regression surface.

## Data flow

```text
Stage 1: existing Zotero metadata + stored PDF
                     |
          +----------+----------+
          |                     |
          v                     v
Stage 2: PDF only        Stage 3: online
PDFKit + Apple AI        Crossref/DataCite/OpenAlex
          |                     |
          +----------+----------+
                     v
        Stage 4: combined reconciliation
        - exact agreement => corroborated
        - conflicts => separate alternatives
                     |
                     v
                 review UI
                     |
               approved only
                     |
                     v
              Zotero item write
```

## Helper IPC

The helper listens on `127.0.0.1:43119`. Enrichment requests require a random private token stored at:

```text
~/Library/Application Support/Zotero Metadata Enricher/token
```

The listener is configured with one loopback `requiredLocalEndpoint`. Do not additionally pass the same explicit port to `NWListener(using:on:)`; Network.framework rejects that combination with `EINVAL`.

## Trust boundaries

The plugin determines selections, reads Zotero metadata/attachments through Zotero APIs, displays the review UI, applies explicit approvals, and uses Zotero's own BibTeX translator.

The helper returns metadata proposals only. It never writes Zotero's SQLite database or attachment storage directly.

## Replaceability

- `ScholarlySources.swift`: structured online providers
- `AppleIntelligenceAnalyzer.swift`: Apple model extraction
- `PDFTextExtractor.swift`: local PDF extraction
- plugin code: Zotero integration/review/write layer

## Failure handling

The plugin distinguishes helper connectivity failures from application-level errors. HTTP error responses from the helper are decoded and shown to the user. If the helper is genuinely stopped, the plugin attempts to launch the installed app and retries. PDF/combined requests use a longer timeout than online-only lookups because Apple Intelligence may take substantially longer than scholarly API requests.
