# Installation — Zotero 9.0.x on macOS

This guide assumes you have downloaded/unzipped this repository onto the Mac where Zotero is installed.

## 1. Open Terminal in the repository

If the folder is in Downloads, for example:

```bash
cd ~/Downloads/zotero-metadata-enricher
```

If it is elsewhere, type `cd ` (including the trailing space), drag the repository folder into Terminal, and press Return.

## 2. Make the scripts executable

```bash
chmod +x scripts/*.sh
```

You normally need to do this only once.

## 3. Build and install the native helper

```bash
./scripts/install-helper.sh
```

The script:

1. builds the Swift helper with your installed Apple toolchain;
2. creates `dist/Zotero Metadata Helper.app`;
3. copies it to `~/Applications/Zotero Metadata Helper.app`;
4. starts it.

You should see a small **ZME** item in the macOS menu bar.

If Terminal reports that `swift` is unavailable, open/install Xcode (or the Xcode Command Line Tools) and repeat the command.

## 4. Optional: start the helper automatically when you log in

Once the helper works normally, run:

```bash
./scripts/install-launch-agent.sh
```

This creates a user LaunchAgent. It does not require administrator privileges.

## 5. Build the Zotero plugin

```bash
./scripts/build-plugin.sh
```

The resulting file is:

```text
dist/zotero-metadata-enricher-0.1.0.xpi
```

## 6. Install the plugin in Zotero

1. Open Zotero.
2. Choose **Tools → Plugins**.
3. Drag `dist/zotero-metadata-enricher-0.1.0.xpi` into the Plugins window.
4. Confirm installation if Zotero asks.
5. Restart Zotero if the new controls do not appear immediately.

Zotero's official plugin documentation supports installing an `.xpi` by dragging it into **Tools → Plugins**.

## 7. Verify the helper before changing metadata

In Terminal:

```bash
curl -s http://127.0.0.1:43119/health | python3 -m json.tool
```

Expected shape:

```json
{
  "appleIntelligenceAvailable": true,
  "build": 1,
  "service": "Zotero Metadata Helper",
  "version": "0.1.0"
}
```

`appleIntelligenceAvailable` can legitimately be `false` if Apple Intelligence is disabled/not ready/not supported. Online enrichment does not depend on the on-device model.

Continue with [FIRST_RUN.md](FIRST_RUN.md).
