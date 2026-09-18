# Contributing

Contributions are welcome when they preserve the project's review-first safety model and Zotero 10 compatibility.

## Before opening an issue

- Search existing issues.
- Reproduce with the current `main` branch or latest release.
- Run `./scripts/diagnose-helper.sh` for helper problems.
- Remove private titles, tags, collection names, paths, PDF text, tokens, and account data from logs and screenshots.

Use a clean Zotero profile or a disposable test library for screenshots and reproducible examples.

## Development setup

```bash
git clone https://github.com/conradoguimaraes/ZoteroAI.git
cd ZoteroAI
chmod +x scripts/*.sh
./scripts/verify.sh
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for requirements and focused commands.

## Pull requests

Keep changes narrow. Explain:

- the observed problem;
- the intended behavior;
- affected data flows or privacy boundaries;
- tests performed;
- macOS and Zotero versions used for runtime testing.

Run `./scripts/verify.sh` before submitting. For UI changes, include a sanitized capture from a demo profile. For provider changes, document the exact data sent, match criteria, rate-limit handling, and source attribution.

## Required invariants

- Metadata remains proposal-based and user-reviewed.
- Existing non-empty values are not silently overwritten.
- PDF/AI proposals are not described as verified facts.
- The helper does not write directly to Zotero's database or storage tree.
- The helper remains bound to loopback and enrichment endpoints remain token-authenticated.
- Tokens, credentials, PDFs, user libraries, and generated build trees are never committed.

## Style

- JavaScript shipped in the plugin is plain strict-mode JavaScript compatible with Zotero 10's bootstrapped-plugin environment.
- Swift code follows the existing package structure and must pass `swift test`.
- Public documentation must distinguish local PDF processing from online lookup precisely.
- Put release history in `CHANGELOG.md`, not the README.

## Generated files

Do not commit `dist/`, `helper/.build/`, source-tree dumps, local agent instructions, or personal screenshots. Release binaries belong in GitHub Releases.
