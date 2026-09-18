"use strict";

var ZME = (() => {
  const PLUGIN_ID = "zotero-metadata-enricher@local";
  const HELPER_BASE = "http://127.0.0.1:43119";
  const TOKEN_RELATIVE_PATH = "/Library/Application Support/Zotero Metadata Enricher/token";
  const REQUEST_TIMEOUT_MS = 120000;

  const state = {
    rootURI: null,
    version: null,
    menuIDs: [],
    sectionID: null,
  };

  function log(message, level = 3) {
    Zotero.debug(`[ZME] ${message}`, level);
  }

  async function startup({ id, version, rootURI }) {
    state.rootURI = rootURI;
    state.version = version;

    // Fluent resources in plugin locale folders are registered by Zotero, but the
    // already-open main window still needs the resource inserted explicitly.
    for (const win of Zotero.getMainWindows()) {
      win.MozXULElement?.insertFTLIfNeeded("zotero-metadata-enricher.ftl");
    }

    registerMenus();
    registerItemPaneSection();

    log(`Started version ${version}`);
  }

  function onMainWindowLoad({ window }) {
    window?.MozXULElement?.insertFTLIfNeeded("zotero-metadata-enricher.ftl");
  }

  function onMainWindowUnload() {
    // This plugin does not retain main-window DOM references. MenuManager and
    // ItemPaneManager registrations are plugin-scoped and cleaned up at shutdown.
  }

  async function shutdown() {
    for (const id of state.menuIDs) {
      try {
        Zotero.MenuManager.unregisterMenu(id);
      } catch (error) {
        log(`Failed to unregister menu ${id}: ${error}`, 2);
      }
    }
    state.menuIDs = [];

    if (state.sectionID) {
      try {
        Zotero.ItemPaneManager.unregisterSection(state.sectionID);
      } catch (error) {
        log(`Failed to unregister item pane section: ${error}`, 2);
      }
      state.sectionID = null;
    }
  }

  function registerMenus() {
    const itemMenuID = Zotero.MenuManager.registerMenu({
      menuID: "zme-item-menu",
      pluginID: PLUGIN_ID,
      target: "main/library/item",
      menus: [
        {
          menuType: "submenu",
          l10nID: "zme-menu-root",
          onShowing: (_event, context) => {
            const items = context.items || [];
            context.setVisible(items.length === 1 && items[0].isRegularItem());
          },
          menus: [
            {
              menuType: "menuitem",
              l10nID: "zme-menu-pdf",
              onCommand: () => void enrichSelectedItem("pdf"),
            },
            {
              menuType: "menuitem",
              l10nID: "zme-menu-online",
              onCommand: () => void enrichSelectedItem("online"),
            },
            {
              menuType: "menuitem",
              l10nID: "zme-menu-copy-bibtex",
              onCommand: () => void copySelectedBibTeX(),
            },
          ],
        },
      ],
    });

    const collectionMenuID = Zotero.MenuManager.registerMenu({
      menuID: "zme-collection-menu",
      pluginID: PLUGIN_ID,
      target: "main/library/collection",
      menus: [
        {
          menuType: "submenu",
          l10nID: "zme-menu-root",
          onShowing: (_event, context) => {
            context.setVisible(Boolean(getSelectedCollection()));
          },
          menus: [
            {
              menuType: "menuitem",
              l10nID: "zme-menu-collection-pdf",
              onCommand: () => void enrichSelectedCollection("pdf"),
            },
            {
              menuType: "menuitem",
              l10nID: "zme-menu-collection-online",
              onCommand: () => void enrichSelectedCollection("online"),
            },
          ],
        },
      ],
    });

    state.menuIDs.push(itemMenuID, collectionMenuID);
  }

  function registerItemPaneSection() {
    state.sectionID = Zotero.ItemPaneManager.registerSection({
      paneID: "zme-item-pane",
      pluginID: PLUGIN_ID,
      header: {
        l10nID: "zme-pane-header",
        icon: state.rootURI + "icons/zme-16.svg",
      },
      sidenav: {
        l10nID: "zme-pane-header",
        icon: state.rootURI + "icons/zme-20.svg",
      },
      onRender: ({ body, item }) => {
        body.replaceChildren();
        if (!item || !item.isRegularItem()) {
          const text = body.ownerDocument.createElement("div");
          text.textContent = "Select a regular bibliographic item.";
          text.style.padding = "8px";
          body.appendChild(text);
          return;
        }

        const doc = body.ownerDocument;
        const container = doc.createElement("div");
        container.style.display = "grid";
        container.style.gridTemplateColumns = "1fr";
        container.style.gap = "6px";
        container.style.padding = "8px";

        const pdfButton = createButton(doc, "Enrich from stored PDF", () => {
          void enrichItem(item, "pdf");
        });
        const onlineButton = createButton(doc, "Enrich from online sources", () => {
          void enrichItem(item, "online");
        });
        const bibtexButton = createButton(doc, "Copy BibTeX", () => {
          void copyBibTeX(item);
        });

        const note = doc.createElement("div");
        note.textContent = "Nothing is written to the Zotero item until you approve proposed fields.";
        note.style.fontSize = "0.9em";
        note.style.opacity = "0.75";
        note.style.lineHeight = "1.35";
        note.style.marginTop = "2px";

        container.append(pdfButton, onlineButton, bibtexButton, note);
        body.appendChild(container);
      },
    });
  }

  function createButton(doc, label, onClick) {
    const button = doc.createElement("button");
    button.textContent = label;
    button.style.padding = "6px 10px";
    button.style.textAlign = "left";
    button.addEventListener("click", onClick);
    return button;
  }

  function getSelectedRegularItem() {
    const pane = Zotero.getActiveZoteroPane();
    const items = pane?.getSelectedItems() || [];
    if (items.length !== 1 || !items[0].isRegularItem()) {
      return null;
    }
    return items[0];
  }

  function getSelectedCollection() {
    const pane = Zotero.getActiveZoteroPane();
    return pane?.getSelectedCollection() || null;
  }

  async function enrichSelectedItem(mode) {
    const item = getSelectedRegularItem();
    if (!item) {
      showAlert("Metadata Enricher", "Select exactly one bibliographic item first.");
      return;
    }
    await enrichItem(item, mode);
  }

  async function enrichItem(item, mode) {
    try {
      const snapshot = await snapshotItem(item);
      let pdfPath = null;

      if (mode === "pdf") {
        pdfPath = await findStoredPDFPath(item);
        if (!pdfPath) {
          showAlert(
            "Metadata Enricher",
            "This Zotero item does not have an accessible PDF attachment."
          );
          return;
        }
      }

      const endpoint = mode === "pdf" ? "/v1/pdf-enrich" : "/v1/online-enrich";
      const response = await callHelper(endpoint, {
        requestID: makeRequestID(),
        item: snapshot,
        pdfPath,
      });

      const candidates = Array.isArray(response.candidates) ? response.candidates : [];
      if (!candidates.length) {
        const detail = (response.notes || []).join("\n");
        showAlert(
          "Metadata Enricher",
          detail || "No new metadata candidates were found."
        );
        return;
      }

      const decision = await openReviewDialog({
        title: mode === "pdf" ? "PDF-only metadata review" : "Online metadata review",
        itemTitle: snapshot.fields.title || "Untitled item",
        candidates: candidates.map((candidate) => ({
          ...candidate,
          currentValue: currentValueForCandidate(snapshot, candidate),
        })),
        notes: response.notes || [],
      });

      if (!decision || !decision.acceptedIDs?.length) {
        return;
      }

      const selected = candidates.filter((candidate) =>
        decision.acceptedIDs.includes(candidate.id)
      );
      const result = await applyCandidates(item, selected);

      showAlert(
        "Metadata Enricher",
        `Applied ${result.applied} field${result.applied === 1 ? "" : "s"}.` +
          (result.skipped ? ` ${result.skipped} candidate(s) could not be applied.` : "")
      );
    } catch (error) {
      log(`Enrichment failed: ${error?.stack || error}`, 1);
      showAlert("Metadata Enricher", humanizeError(error));
    }
  }

  async function enrichSelectedCollection(mode) {
    const collection = getSelectedCollection();
    if (!collection) {
      showAlert("Metadata Enricher", "Select a Zotero collection first.");
      return;
    }

    const items = collection.getChildItems().filter((item) => item.isRegularItem());
    if (!items.length) {
      showAlert("Metadata Enricher", "The selected collection contains no regular items.");
      return;
    }

    const ok = Services.prompt.confirm(
      Zotero.getMainWindow(),
      "Metadata Enricher",
      `Process ${items.length} item(s) in “${collection.name}”?\n\n` +
        "Version 0.1.0 deliberately reviews each item before writing changes. " +
        "This is slower, but prevents silent corruption of a collection."
    );
    if (!ok) return;

    let appliedItems = 0;
    let skippedItems = 0;
    let failedItems = 0;

    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const title = item.getField("title") || `Item ${index + 1}`;
      const proceed = Services.prompt.confirm(
        Zotero.getMainWindow(),
        `Metadata Enricher — ${index + 1}/${items.length}`,
        `Process:\n${title}\n\nChoose Cancel to stop the collection run.`
      );
      if (!proceed) break;

      try {
        const before = item.version;
        await enrichItem(item, mode);
        const refreshed = await Zotero.Items.getAsync(item.id);
        if (refreshed.version !== before) {
          appliedItems++;
        } else {
          skippedItems++;
        }
      } catch (error) {
        failedItems++;
        log(`Collection item failed (${item.key}): ${error?.stack || error}`, 1);
      }
    }

    showAlert(
      "Metadata Enricher",
      `Collection run finished.\n\nChanged: ${appliedItems}\nNo changes: ${skippedItems}\nFailed: ${failedItems}`
    );
  }

  async function snapshotItem(item) {
    const json = item.toJSON();
    const fields = {};

    for (const [key, value] of Object.entries(json)) {
      if (["key", "version", "itemType", "creators", "tags", "collections", "relations"].includes(key)) {
        continue;
      }
      if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
        fields[key] = String(value ?? "");
      }
    }

    return {
      itemID: item.id,
      itemKey: item.key,
      libraryID: item.libraryID,
      itemType: json.itemType || Zotero.ItemTypes.getName(item.itemTypeID),
      fields,
      creators: (json.creators || []).map((creator) => ({
        firstName: creator.firstName || "",
        lastName: creator.lastName || creator.name || "",
        creatorType: creator.creatorType || "author",
      })),
      tags: (json.tags || []).map((tag) => (typeof tag === "string" ? tag : tag.tag)).filter(Boolean),
    };
  }

  function currentValueForCandidate(snapshot, candidate) {
    if (candidate.field === "creators") {
      return snapshot.creators
        .map((creator) => [creator.firstName, creator.lastName].filter(Boolean).join(" "))
        .join("; ");
    }
    if (candidate.field === "tags") {
      return snapshot.tags.join("; ");
    }
    return snapshot.fields[candidate.field] || "";
  }

  async function findStoredPDFPath(item) {
    const attachmentIDs = item.getAttachments();
    for (const id of attachmentIDs) {
      const attachment = await Zotero.Items.getAsync(id);
      if (!attachment || attachment.attachmentContentType !== "application/pdf") {
        continue;
      }
      try {
        const path = await attachment.getFilePathAsync();
        if (path) return path;
      } catch (error) {
        log(`PDF path lookup failed for attachment ${id}: ${error}`, 2);
      }
    }
    return null;
  }

  async function callHelper(endpoint, payload) {
    const token = await readHelperToken();

    let xhr;
    try {
      xhr = await Zotero.HTTP.request("POST", HELPER_BASE + endpoint, {
        headers: {
          "Content-Type": "application/json",
          "X-ZME-Token": token,
        },
        body: JSON.stringify(payload),
        responseType: "json",
        timeout: REQUEST_TIMEOUT_MS,
      });
    } catch (error) {
      throw new Error(
        "The local Metadata Helper could not be reached. Start “Zotero Metadata Helper” from ~/Applications and try again."
      );
    }

    if (xhr.status < 200 || xhr.status >= 300) {
      const message = xhr.response?.error || `Helper returned HTTP ${xhr.status}`;
      throw new Error(message);
    }
    return xhr.response;
  }

  async function readHelperToken() {
    const home = Services.dirsvc.get("Home", Components.interfaces.nsIFile).path;
    const tokenPath = home + TOKEN_RELATIVE_PATH;
    try {
      const token = (await Zotero.File.getContentsAsync(tokenPath)).trim();
      if (!token) throw new Error("empty token");
      return token;
    } catch (error) {
      throw new Error(
        "The Metadata Helper is not installed or has never been started. Run scripts/install-helper.sh from the repository, then launch the helper once."
      );
    }
  }

  async function applyCandidates(item, candidates) {
    let applied = 0;
    let skipped = 0;

    await Zotero.DB.executeTransaction(async () => {
      for (const candidate of candidates) {
        try {
          if (candidate.field === "creators") {
            const creators = JSON.parse(candidate.structuredValue || "[]");
            if (!Array.isArray(creators) || !creators.length) {
              skipped++;
              continue;
            }
            const proposedAuthors = creators.map((creator) => ({
              firstName: creator.firstName || "",
              lastName: creator.lastName || "",
              creatorType: creator.creatorType || "author",
            }));
            // Metadata providers return authors, not editors/translators. Preserve
            // existing non-author creator roles when the user accepts a replacement
            // author list.
            const existingNonAuthors = item.getCreators().filter(
              (creator) => creator.creatorType !== "author"
            );
            item.setCreators([...proposedAuthors, ...existingNonAuthors]);
            applied++;
            continue;
          }

          if (candidate.field === "tags") {
            const tags = JSON.parse(candidate.structuredValue || "[]");
            if (!Array.isArray(tags) || !tags.length) {
              skipped++;
              continue;
            }
            const existing = item.getTags().map((tag) => tag.tag);
            const merged = Array.from(new Set([...existing, ...tags])).map((tag) => ({ tag }));
            item.setTags(merged);
            applied++;
            continue;
          }

          const fieldID = Zotero.ItemFields.getID(candidate.field);
          if (!fieldID) {
            skipped++;
            continue;
          }

          // Zotero has base fields that map to type-specific fields. Prefer the
          // candidate field directly when valid; otherwise ask Zotero for the
          // appropriate mapping instead of inventing our own schema rules.
          let targetFieldID = fieldID;
          if (!Zotero.ItemFields.isValidForType(fieldID, item.itemTypeID)) {
            targetFieldID = Zotero.ItemFields.getFieldIDFromTypeAndBase(
              item.itemTypeID,
              candidate.field
            );
          }
          if (!targetFieldID) {
            skipped++;
            continue;
          }

          item.setField(targetFieldID, candidate.value);
          applied++;
        } catch (error) {
          skipped++;
          log(`Could not apply ${candidate.field}: ${error}`, 2);
        }
      }

      if (applied) {
        await item.save();
      }
    });

    return { applied, skipped };
  }

  async function copySelectedBibTeX() {
    const item = getSelectedRegularItem();
    if (!item) {
      showAlert("Metadata Enricher", "Select exactly one bibliographic item first.");
      return;
    }
    await copyBibTeX(item);
  }

  async function copyBibTeX(item) {
    try {
      const translation = new Zotero.Translate.Export();
      translation.setItems([item]);
      const translators = translation.getTranslators();
      const bibTeX = translators.find((translator) => translator.label === "BibTeX");
      if (!bibTeX) {
        throw new Error("Zotero's built-in BibTeX translator was not found.");
      }

      translation.setTranslator(bibTeX);
      const output = await new Promise((resolve, reject) => {
        translation.setHandler("done", (obj, success) => {
          if (!success) {
            reject(new Error("BibTeX export failed."));
            return;
          }
          resolve(obj.string || "");
        });
        try {
          translation.translate();
        } catch (error) {
          reject(error);
        }
      });

      if (!output.trim()) {
        throw new Error("Zotero produced an empty BibTeX export.");
      }

      const clipboard = Components.classes["@mozilla.org/widget/clipboardhelper;1"].getService(
        Components.interfaces.nsIClipboardHelper
      );
      clipboard.copyString(output);
    } catch (error) {
      log(`Copy BibTeX failed: ${error?.stack || error}`, 1);
      showAlert("Metadata Enricher", `Could not copy BibTeX.\n\n${error.message || error}`);
    }
  }

  async function openReviewDialog(reviewData) {
    const mainWindow = Zotero.getMainWindow();
    const io = {
      data: reviewData,
      result: null,
    };

    const dialog = mainWindow.openDialog(
      state.rootURI + "chrome/content/review.xhtml",
      "zme-review",
      "chrome,centerscreen,resizable,width=1150,height=650",
      io
    );

    await new Promise((resolve) => {
      const timer = mainWindow.setInterval(() => {
        if (dialog.closed) {
          mainWindow.clearInterval(timer);
          resolve();
        }
      }, 100);
    });

    return io.result;
  }

  function makeRequestID() {
    return `zme-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  function showAlert(title, message) {
    Services.prompt.alert(Zotero.getMainWindow(), title, message);
  }

  function humanizeError(error) {
    const message = String(error?.message || error || "Unknown error");
    if (message.includes("401") || message.includes("403")) {
      return "The local helper rejected the request. Restart the helper and Zotero, then try again.";
    }
    return message;
  }

  return {
    startup,
    shutdown,
    onMainWindowLoad,
    onMainWindowUnload,
    enrichSelectedItem,
    enrichSelectedCollection,
    copySelectedBibTeX,
  };
})();
