# Releases and Versioning

The project uses:

- `VERSION` — semantic version, e.g. `0.2.0`;
- `BUILD` — monotonically increasing integer, e.g. `1`;
- `CHANGELOG.md` — human-readable release history.

The same semantic version must appear in `plugin/manifest.json` and `helper/Sources/ZoteroMetadataHelper/main.swift`. The build number must match the Swift `BuildInfo.build` value.

`./scripts/verify.sh` checks these invariants.

## Release checklist

1. Update code and tests.
2. Update `VERSION` and increment `BUILD` as appropriate.
3. Update plugin manifest and helper `BuildInfo`.
4. Update `CHANGELOG.md` with only changes that actually exist.
5. Run:

```bash
./scripts/verify.sh
```

6. Exercise all three runtime paths on the target Mac/Zotero version:
   - PDF-only enrichment;
   - online enrichment;
   - Copy BibTeX.
7. Test at least one small collection run.
8. Package:

```bash
./scripts/package-release.sh
```

9. Inspect `dist/` before publishing/preserving the release.

Do not advance compatibility to a new Zotero major version merely by editing `strict_max_version`; inspect Zotero's developer migration notes and rerun runtime tests first.
