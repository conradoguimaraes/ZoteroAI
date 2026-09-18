# Development

## Requirements

- macOS 26+;
- Xcode / Swift 6.2 toolchain with Foundation Models;
- Zotero 10.0.x;
- Node.js, `jq`, Python 3, `zip`, `unzip`, and `curl`.

## Repository layout

```text
.
├── helper/
│   ├── Package.swift
│   ├── Sources/ZoteroMetadataHelper/
│   └── Tests/ZoteroMetadataHelperTests/
├── plugin/
│   ├── bootstrap.js
│   ├── chrome/content/
│   ├── icons/
│   ├── locale/
│   └── manifest.json
├── scripts/
├── docs/
├── VERSION
├── BUILD
└── Makefile
```

`helper/.build/` and `dist/` are generated and must remain untracked.

## Verify

```bash
./scripts/verify.sh
```

The verification checks JavaScript syntax, XHTML well-formedness, manifest/version consistency, regression invariants, Swift package metadata/tests/build, XPI layout, and helper compilation on macOS.

Focused commands:

```bash
swift test --package-path helper
./scripts/build-helper.sh
./scripts/build-plugin.sh
./scripts/diagnose-helper.sh
```

## Versioning

Keep these values synchronized:

- `VERSION`;
- `BUILD`;
- `plugin/manifest.json` version;
- `BuildInfo` in `helper/Sources/ZoteroMetadataHelper/main.swift`.

The permanent public plugin ID is `zotero-metadata-enricher@conradoguimaraes.github.io`. Keep it synchronized between `plugin/manifest.json` and `PLUGIN_ID` in `plugin/chrome/content/main.js`. Do not change it after public installations exist: Zotero treats a changed ID as a different add-on.

## Public-release checklist

1. Run `git status --short` and verify there are no generated or personal files.
2. Confirm `git ls-files helper/.build dist` prints nothing.
3. Search tracked text for credentials, tokens, personal paths, and private data.
4. Run `./scripts/verify.sh` on a supported Mac.
5. Test all four item actions and all three collection modes on a disposable Zotero profile.
6. Verify the manifest's permanent ID, homepage URL, and HTTPS update URL.
7. Publish and validate the JSON update manifest at the URL declared by the plugin before calling automatic updates functional.
8. Build release assets from a clean checkout.
9. Sign and notarize any helper binary offered to general users; otherwise label it as an unsigned developer build.
10. Publish XPI/helper archives and checksums as GitHub Release assets, not as tracked source files.
11. Use demo-profile screenshots only.

## Release artifacts

```bash
./scripts/package-release.sh
```

Inspect the output under `dist/`. The current script creates the plugin XPI, helper archive on macOS, and a project source ZIP. It does not create checksums; generate and verify those separately before publishing binaries. GitHub also supplies source archives for tags, so avoid duplicating the project source ZIP unless the project has a specific reproducibility reason.

## Online provider etiquette

The public cleanup identifies requests with the project version and repository URL, but v0.2.5 has no response cache or retry/backoff policy. Before high-volume public use, implement:

- provider-specific backoff for `429` and transient `5xx` responses;
- conservative caching;
- an optional user-configured contact email rather than a maintainer's hard-coded personal address;
- an optional OpenAlex API key if public usage requires one.

## Safety invariants

- Never write directly to `zotero.sqlite`.
- Never silently replace a non-empty metadata value.
- Never label model inference as verified.
- Preserve non-author creator roles when applying an author list.
- Merge tags rather than deleting existing tags.
- Keep helper traffic bound to loopback and authenticated.
- Do not log the helper token or include it in diagnostics.
