# Development

## Requirements

- macOS 26+;
- Xcode / Swift toolchain with FoundationModels;
- Zotero 10.0.x;
- Node.js;
- `jq`, `zip`, `unzip`, `curl`.

## Verify

```bash
./scripts/verify.sh
```

On macOS this also builds the native helper against the installed Apple SDK.

## Helper

```bash
swift test --package-path helper
./scripts/build-helper.sh
./scripts/install-helper.sh
```

Health check:

```bash
curl -s http://127.0.0.1:43119/health
```

Diagnostics:

```bash
./scripts/diagnose-helper.sh
```

## Plugin

```bash
./scripts/build-plugin.sh
```

Install the resulting `.xpi` from Zotero **Tools → Plugins**.

## Data safety

Never write directly to `zotero.sqlite`, manually rewrite Zotero storage, silently replace non-empty metadata, or label AI inference as verified.
