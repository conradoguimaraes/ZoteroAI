# Development

## Rules

The repository follows the engineering guidance in the root `AGENTS.md`: inspect before modifying, preserve working behavior, distinguish verification from inference, and do not call something fixed without evidence.

## Requirements

For full development/testing:

- macOS 26 or later;
- Xcode / Swift toolchain with FoundationModels;
- Zotero 9.0.x;
- Node.js for JavaScript syntax checks;
- `jq`, `zip`, and `unzip` for packaging checks.

## Verify

```bash
./scripts/verify.sh
```

On macOS this also compiles the real FoundationModels/AppKit/PDFKit code. On non-macOS hosts, conditional macOS code can be parsed but cannot be type-checked against Apple's SDK.

## Plugin development

The production package is built with:

```bash
./scripts/build-plugin.sh
```

For rapid plugin development, Zotero also documents loading a plugin directly from source/profile proxy mechanisms. Use a separate Zotero development profile if you are changing write behavior.

## Helper development

```bash
swift test --package-path helper
swift build --package-path helper
./scripts/build-helper.sh
```

The helper is a menu-bar accessory app. It listens only on the configured loopback endpoint and requires a random token for enrichment requests. The token is stored at:

```text
~/Library/Application Support/Zotero Metadata Enricher/token
```

## Logging

Plugin diagnostics are prefixed with:

```text
[ZME]
```

Use Zotero **Tools → Developer → Error Console** when diagnosing plugin failures.

## Data-safety expectations

Never:

- write directly to `zotero.sqlite`;
- edit Zotero's attachment-storage layout manually;
- silently replace non-empty metadata;
- turn AI inference into `Verified` status;
- remove provenance from a proposed field.
