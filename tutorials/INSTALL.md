# Installation — Zotero 10.0.x on macOS

Use this release only after upgrading Zotero to 10.0.x.

## 1. Open Terminal in the repository

For your current folder:

```bash
cd ~/Documents/Github/ZoteroAI
```

## 2. Make scripts executable

```bash
chmod +x scripts/*.sh
```

## 3. Build and install the helper

```bash
./scripts/install-helper.sh
```

The installer now:

1. builds the Swift helper;
2. stops an older helper process if one exists;
3. installs the app at `~/Applications/Zotero Metadata Helper.app`;
4. starts it;
5. waits for `http://127.0.0.1:43119/health` before reporting success.

A successful run ends with a JSON health response showing version `0.2.5` and build `7`.

If this step fails, run:

```bash
./scripts/diagnose-helper.sh
```

and keep the output.

## 4. Build the Zotero plugin

```bash
./scripts/build-plugin.sh
```

This creates:

```text
dist/zotero-metadata-enricher-0.2.5.xpi
```

## 5. Install the plugin

In Zotero:

1. **Tools → Plugins**
2. remove/disable the old an older `Zotero Metadata Enricher` version if it is still installed;
3. drag `dist/zotero-metadata-enricher-0.2.5.xpi` into the Plugins window;
4. confirm installation;
5. restart Zotero if requested.

## 6. Verify the helper manually

```bash
curl -s http://127.0.0.1:43119/health
```

Expected fields include:

```json
{"service":"Zotero Metadata Helper","version":"0.2.5","build":7}
```

Then follow [FIRST_RUN.md](FIRST_RUN.md).
