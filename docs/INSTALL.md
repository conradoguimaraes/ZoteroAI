# Installation

## Supported environment

Version 0.2.5 targets Zotero `10.0.*` on macOS 26 or later. The helper requires an Apple SDK that contains PDFKit and Foundation Models.

This repository currently supports source installation. A public prebuilt helper should not be described as production-ready until it is Developer ID signed and notarized.

## 1. Install prerequisites

Install Zotero 10 and Xcode, then verify the required command-line tools:

```bash
xcode-select -p
swift --version
node --version
jq --version
zip -v | head -n 1
unzip -v | head -n 1
curl --version | head -n 1
```

## 2. Clone the repository

```bash
git clone https://github.com/conradoguimaraes/ZoteroAI.git
cd ZoteroAI
chmod +x scripts/*.sh
```

## 3. Build and install the helper

```bash
./scripts/install-helper.sh
```

The script builds the Swift executable, creates an app bundle, ad-hoc signs it, installs it at `~/Applications/Zotero Metadata Helper.app`, starts it, and checks the health endpoint.

Expected health fields for this release:

```json
{
  "appleIntelligenceAvailable": true,
  "build": 7,
  "service": "Zotero Metadata Helper",
  "version": "0.2.5"
}
```

`appleIntelligenceAvailable` may be `false` when the device, region, language, operating-system configuration, or model state is unsupported. Deterministic PDF extraction and online mode can still work.

If installation fails, run:

```bash
./scripts/diagnose-helper.sh
```

## 4. Build and install the Zotero plugin

```bash
./scripts/build-plugin.sh
```

The output is:

```text
dist/zotero-metadata-enricher-0.2.5.xpi
```

In Zotero:

1. Open **Tools → Plugins**.
2. Open the gear menu.
3. Choose **Install Plugin From File…**.
4. Select the generated `.xpi`.
5. Restart Zotero if requested.

### One-time migration from the private/local build

The public package uses the permanent add-on ID:

```text
zotero-metadata-enricher@conradoguimaraes.github.io
```

Earlier private builds used `zotero-metadata-enricher@local.invalid`. Zotero treats those as different add-ons. Before installing the first public-ID build, remove the old Metadata Enricher entry from **Tools → Plugins**, restart Zotero, and then install the newly built XPI. This does not delete or alter Zotero library data. The native helper can remain installed.

## 5. Verify a safe first run

Check the helper:

```bash
curl --silent --show-error --fail http://127.0.0.1:43119/health
```

Then select one regular bibliographic item in Zotero and test **Copy BibTeX**. It does not require the helper and does not change metadata. Next, test enrichment on a disposable item whose correct metadata you know. Review every proposal and accept only one unambiguous missing field.

Do not begin with a collection-wide run.

## Normal use after reboot

Open Zotero and use the buttons. You do not need to rebuild or reinstall anything. When enrichment needs the helper, the plugin attempts to launch the installed app automatically. **Copy BibTeX** never needs the helper.

If automatic launch fails:

```bash
open "$HOME/Applications/Zotero Metadata Helper.app"
```

`scripts/install-launch-agent.sh` is optional. The normal on-demand launch path does not require it.

## Upgrade

```bash
cd /path/to/ZoteroAI
git pull --ff-only
chmod +x scripts/*.sh
./scripts/install-helper.sh
./scripts/build-plugin.sh
```

Install the new `.xpi` through **Tools → Plugins**. Keep the helper and plugin on the same version/build.

## Uninstall

Remove the plugin in Zotero's Plugins Manager, then run:

```bash
./scripts/uninstall-helper.sh
```

The uninstaller intentionally retains the local token directory. To remove it as well, inspect it first and delete it manually only if no installation needs it:

```bash
ls -la "$HOME/Library/Application Support/Zotero Metadata Enricher"
```
