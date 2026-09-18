"use strict";

var ZME = (() => {
  const PLUGIN_ID = "zotero-metadata-enricher@conradoguimaraes.github.io";
  const HELPER_BASE = "http://127.0.0.1:43119";
  const TOKEN_RELATIVE_PATH = "/Library/Application Support/Zotero Metadata Enricher/token";
  const REQUEST_TIMEOUT_MS = 120000;
  const BIBTEX_TRANSLATOR_ID = "9cb70025-a888-4a29-a210-93ec52da40d4";
  const REVIEW_DIALOG_URL = "chrome://zotero-metadata-enricher/content/review.xhtml";

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

    cleanupStaleRegistrations();
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

  function cleanupStaleRegistrations() {
    // During in-place plugin upgrades Zotero can briefly retain DOM registrations
    // from the previous version. Remove our stable, namespaced IDs before
    // registering again so an upgrade never leaves duplicate menus or sections.
    const menuIDs = [
      `${PLUGIN_ID}-zme-item-menu`,
      `${PLUGIN_ID}-zme-collection-menu`,
    ];
    for (const menuID of menuIDs) {
      try {
        Zotero.MenuManager.unregisterMenu(menuID);
      } catch (_) {
        // Not registered is the normal cold-start case.
      }
    }

    try {
      Zotero.ItemPaneManager.unregisterSection(`${PLUGIN_ID}-zme-item-pane`);
    } catch (_) {
      // Not registered is the normal cold-start case.
    }
  }

  function registerMenus() {
    const itemVisible = (_event, context) => {
      const items = Array.isArray(context?.items) ? context.items : [];
      context.setVisible(items.length === 1 && items[0]?.isRegularItem());
    };

    const itemFromContext = (context) => {
      const items = Array.isArray(context?.items) ? context.items : [];
      return items.length === 1 && items[0]?.isRegularItem() ? items[0] : null;
    };

    // Keep the item context menu deliberately flat. Nested MenuManager submenus
    // add no value for a small action set and have proven fragile across Zotero UI
    // revisions. Direct commands are also one click faster for the user.
    const itemMenuID = Zotero.MenuManager.registerMenu({
      menuID: "zme-item-menu",
      pluginID: PLUGIN_ID,
      target: "main/library/item",
      menus: [
        {
          menuType: "menuitem",
          l10nID: "zme-menu-combined",
          onShowing: itemVisible,
          onCommand: (_event, context) => {
            const item = itemFromContext(context);
            if (item) void enrichItem(item, "combined");
          },
        },
        {
          menuType: "menuitem",
          l10nID: "zme-menu-pdf",
          onShowing: itemVisible,
          onCommand: (_event, context) => {
            const item = itemFromContext(context);
            if (item) void enrichItem(item, "pdf");
          },
        },
        {
          menuType: "menuitem",
          l10nID: "zme-menu-online",
          onShowing: itemVisible,
          onCommand: (_event, context) => {
            const item = itemFromContext(context);
            if (item) void enrichItem(item, "online");
          },
        },
        {
          menuType: "menuitem",
          l10nID: "zme-menu-copy-bibtex",
          onShowing: itemVisible,
          onCommand: (_event, context) => {
            const item = itemFromContext(context);
            if (item) void copyBibTeX(item);
          },
        },
      ],
    });

    const collectionFromContext = (context) => {
      const rows = Array.isArray(context?.collectionTreeRows)
        ? context.collectionTreeRows
        : [];
      if (rows.length !== 1 || rows[0]?.type !== "collection") {
        return null;
      }
      return rows[0].ref || null;
    };

    const collectionVisible = (_event, context) => {
      context.setVisible(Boolean(collectionFromContext(context)));
    };

    const collectionMenuID = Zotero.MenuManager.registerMenu({
      menuID: "zme-collection-menu",
      pluginID: PLUGIN_ID,
      target: "main/library/collection",
      menus: [
        {
          menuType: "menuitem",
          l10nID: "zme-menu-collection-combined",
          onShowing: collectionVisible,
          onCommand: (_event, context) => {
            const collection = collectionFromContext(context);
            if (collection) void enrichCollection(collection, "combined");
          },
        },
        {
          menuType: "menuitem",
          l10nID: "zme-menu-collection-pdf",
          onShowing: collectionVisible,
          onCommand: (_event, context) => {
            const collection = collectionFromContext(context);
            if (collection) void enrichCollection(collection, "pdf");
          },
        },
        {
          menuType: "menuitem",
          l10nID: "zme-menu-collection-online",
          onShowing: collectionVisible,
          onCommand: (_event, context) => {
            const collection = collectionFromContext(context);
            if (collection) void enrichCollection(collection, "online");
          },
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
        l10nID: "zme-pane-sidenav",
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
        container.style.gap = "8px";
        container.style.padding = "8px";

        const intro = doc.createElement("div");
        intro.textContent = "Choose how to enrich this reference. Every proposed change is reviewed before Zotero is modified.";
        intro.style.fontSize = "0.92em";
        intro.style.opacity = "0.78";
        intro.style.lineHeight = "1.4";
        intro.style.marginBottom = "2px";

        const combinedControl = createActionControl(
          doc,
          "Enrich from PDF + online",
          "Recommended · Apple Intelligence reads the stored PDF, then Crossref, DataCite and OpenAlex are checked for corroboration.",
          () => void enrichItem(item, "combined"),
          true
        );
        const pdfControl = createActionControl(
          doc,
          "Enrich from stored PDF",
          "PDF only · Apple Intelligence · No internet lookup.",
          () => void enrichItem(item, "pdf")
        );
        const onlineControl = createActionControl(
          doc,
          "Enrich from online sources",
          "Crossref · DataCite · OpenAlex · Does not read the PDF.",
          () => void enrichItem(item, "online")
        );

        const divider = doc.createElement("div");
        divider.style.height = "1px";
        divider.style.background = "color-mix(in srgb, currentColor 14%, transparent)";
        divider.style.margin = "2px 0";

        const bibtexControl = createActionControl(
          doc,
          "Copy BibTeX",
          "Copies Zotero's own BibTeX export for this reference to the clipboard.",
          () => void copyBibTeX(item)
        );

        container.append(intro, combinedControl, pdfControl, onlineControl, divider, bibtexControl);
        body.appendChild(container);
      },
    });
  }

  function createActionControl(doc, title, subtitle, onClick, recommended = false) {
    const wrapper = doc.createElement("div");
    wrapper.style.display = "grid";
    wrapper.style.gridTemplateColumns = "1fr";
    wrapper.style.gap = "3px";
    wrapper.style.minWidth = "0";

    const button = doc.createElement("button");
    button.type = "button";
    button.textContent = title;
    button.style.width = "100%";
    button.style.minHeight = "30px";
    button.style.padding = "5px 10px";
    button.style.textAlign = "left";
    button.style.fontWeight = recommended ? "650" : "600";
    button.style.cursor = "default";
    button.addEventListener("click", onClick);

    const description = doc.createElement("div");
    description.textContent = subtitle;
    description.style.fontSize = "0.82em";
    description.style.opacity = "0.68";
    description.style.lineHeight = "1.35";
    description.style.padding = "0 4px 3px";
    description.style.overflowWrap = "anywhere";

    wrapper.append(button, description);
    return wrapper;
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
    if (!pane) return null;

    // Zotero 10 supports multi-selection in the collections tree and replaced
    // getSelectedCollection() with getSelectedCollections(). Our batch command
    // deliberately requires exactly one collection.
    if (typeof pane.getSelectedCollections === "function") {
      const collections = pane.getSelectedCollections() || [];
      return collections.length === 1 ? collections[0] : null;
    }

    // Kept only as a defensive fallback for older development snapshots.
    return typeof pane.getSelectedCollection === "function"
      ? pane.getSelectedCollection()
      : null;
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
    const itemTitle = item.getField("title") || "Untitled item";
    const modeInfo = enrichmentModeInfo(mode);
    const progress = createProgress(modeInfo.preparing, itemTitle, 5);

    try {
      progress.update("Reading current Zotero metadata…", 10);
      const snapshot = await snapshotItem(item);
      let pdfPath = null;

      if (modeInfo.requiresPDF) {
        progress.update("Locating the stored PDF attachment…", 20);
        pdfPath = await findStoredPDFPath(item);
        if (!pdfPath) {
          progress.close();
          showAlert(
            "Metadata Enricher",
            mode === "combined"
              ? "This combined enrichment needs an accessible stored PDF. No PDF attachment was found for this item. Use Online enrichment instead, or attach the PDF first."
              : "This Zotero item does not have an accessible PDF attachment."
          );
          return;
        }
      }

      progress.update(modeInfo.running, mode === "online" ? 35 : 40);
      const response = await callHelperWithProgress(
        modeInfo.endpoint,
        {
          requestID: makeRequestID(),
          item: snapshot,
          pdfPath,
        },
        progress,
        modeInfo.running
      );

      const candidates = Array.isArray(response.candidates) ? response.candidates : [];
      progress.update("Preparing metadata review…", 95);
      progress.close();

      if (!candidates.length) {
        const detail = (response.notes || []).join("\n");
        showToast(
          detail || "No useful metadata candidates were found.",
          { duration: 6000 }
        );
        return;
      }

      const decision = await openReviewDialog({
        title: modeInfo.reviewTitle,
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

      const applyProgress = createProgress("Applying approved metadata…", itemTitle, 25);
      try {
        const result = await applyCandidates(item, selected);
        applyProgress.update("Metadata update complete.", 100);
        applyProgress.close();
        showToast(
          `Applied ${result.applied} field${result.applied === 1 ? "" : "s"}.` +
            (result.skipped ? ` ${result.skipped} candidate(s) could not be applied.` : ""),
          { success: result.applied > 0, duration: 4000 }
        );
      } catch (error) {
        applyProgress.close();
        throw error;
      }
    } catch (error) {
      progress.close();
      log(`Enrichment failed: ${error?.stack || error}`, 1);
      showAlert("Metadata Enricher", humanizeError(error));
    }
  }

  function enrichmentModeInfo(mode) {
    switch (mode) {
      case "combined":
        return {
          endpoint: "/v1/combined-enrich",
          requiresPDF: true,
          preparing: "Preparing combined enrichment…",
          running: "Reading the PDF with Apple Intelligence and checking scholarly sources…",
          reviewTitle: "PDF + online metadata review",
        };
      case "pdf":
        return {
          endpoint: "/v1/pdf-enrich",
          requiresPDF: true,
          preparing: "Preparing PDF analysis…",
          running: "Analyzing the stored PDF with Apple Intelligence…",
          reviewTitle: "PDF-only metadata review",
        };
      case "online":
        return {
          endpoint: "/v1/online-enrich",
          requiresPDF: false,
          preparing: "Preparing online metadata lookup…",
          running: "Checking Crossref, DataCite and OpenAlex…",
          reviewTitle: "Online metadata review",
        };
      default:
        throw new Error(`Unknown enrichment mode: ${mode}`);
    }
  }

  async function callHelperWithProgress(endpoint, payload, progress, baseMessage) {
    const mainWindow = Zotero.getMainWindow();
    const started = Date.now();
    const timer = mainWindow.setInterval(() => {
      const seconds = Math.max(1, Math.round((Date.now() - started) / 1000));
      progress.update(`${baseMessage} ${seconds}s elapsed…`);
    }, 3000);

    try {
      return await callHelper(endpoint, payload);
    } finally {
      mainWindow.clearInterval(timer);
    }
  }

  async function enrichSelectedCollection(mode) {
    const collection = getSelectedCollection();
    if (!collection) {
      showAlert("Metadata Enricher", "Select exactly one Zotero collection first.");
      return;
    }
    await enrichCollection(collection, mode);
  }

  async function enrichCollection(collection, mode) {
    const items = collection.getChildItems().filter((item) => item.isRegularItem());
    if (!items.length) {
      showAlert("Metadata Enricher", "The selected collection contains no regular items.");
      return;
    }

    const ok = Services.prompt.confirm(
      Zotero.getMainWindow(),
      "Metadata Enricher",
      `Process ${items.length} item(s) in “${collection.name}”?\n\n` +
        `Version ${state.version} deliberately reviews each item before writing changes. ` +
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
    const timeout = endpoint === "/v1/online-enrich" ? REQUEST_TIMEOUT_MS : 300000;

    const perform = () => Zotero.HTTP.request("POST", HELPER_BASE + endpoint, {
      headers: {
        "Content-Type": "application/json",
        "X-ZME-Token": token,
      },
      body: JSON.stringify(payload),
      responseType: "json",
      timeout,
    });

    try {
      const xhr = await perform();
      return validateHelperResponse(xhr);
    } catch (error) {
      const responseMessage = helperResponseErrorMessage(error);
      if (responseMessage) {
        throw new Error(responseMessage);
      }

      // Distinguish a dead helper from an application-level request failure.
      // Previous versions incorrectly reported every non-2xx PDF response as
      // "helper could not be reached", hiding the actual PDF/permission error.
      let healthy = await helperIsHealthy();
      if (!healthy) {
        const launched = launchInstalledHelper();
        if (launched) {
          healthy = await waitForHelper(7000);
          if (healthy) {
            try {
              const xhr = await perform();
              return validateHelperResponse(xhr);
            } catch (retryError) {
              const retryMessage = helperResponseErrorMessage(retryError);
              if (retryMessage) throw new Error(retryMessage);
              error = retryError;
            }
          }
        }
      }

      if (!healthy) {
        throw new Error(
          "The local Metadata Helper is not running. Metadata Enricher tried to start it automatically but could not reach it. Open “Zotero Metadata Helper” in ~/Applications and try again."
        );
      }

      const message = String(error?.message || error || "Unknown request error");
      if (/timed out|timeout/i.test(message)) {
        throw new Error(
          "The Metadata Helper is running, but this enrichment request timed out. The PDF may be unusually large or Apple Intelligence may still be processing it. Try again; if it repeats, run scripts/diagnose-helper.sh."
        );
      }

      throw new Error(`The Metadata Helper is running, but the enrichment request failed: ${message}`);
    }
  }

  function validateHelperResponse(xhr) {
    if (xhr.status < 200 || xhr.status >= 300) {
      const message = xhr.response?.error || `Metadata Helper returned HTTP ${xhr.status}.`;
      throw new Error(message);
    }
    if (xhr.response?.error) {
      throw new Error(xhr.response.error);
    }
    return xhr.response;
  }

  function helperResponseErrorMessage(error) {
    const xhr = error?.xmlhttp || error?.xhr || error?.response || null;
    const status = Number(xhr?.status || error?.status || 0);
    const raw = xhr?.response ?? xhr?.responseText ?? error?.responseText ?? null;

    if (raw && typeof raw === "object" && typeof raw.error === "string") {
      return raw.error;
    }

    if (typeof raw === "string" && raw.trim()) {
      try {
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed.error === "string") return parsed.error;
      } catch (_) {
        if (status >= 400) return raw.trim();
      }
    }

    if (status >= 400) {
      return `Metadata Helper rejected the request (HTTP ${status}).`;
    }
    return null;
  }

  async function helperIsHealthy() {
    try {
      const xhr = await Zotero.HTTP.request("GET", HELPER_BASE + "/health", {
        responseType: "json",
        timeout: 2000,
      });
      return xhr.status === 200 && xhr.response?.service === "Zotero Metadata Helper";
    } catch (_) {
      return false;
    }
  }

  function launchInstalledHelper() {
    try {
      const home = Services.dirsvc.get("Home", Components.interfaces.nsIFile).clone();
      home.append("Applications");
      home.append("Zotero Metadata Helper.app");
      if (!home.exists()) return false;
      home.launch();
      return true;
    } catch (error) {
      log(`Could not auto-launch helper: ${error?.stack || error}`, 2);
      return false;
    }
  }

  async function waitForHelper(timeoutMS) {
    const started = Date.now();
    while (Date.now() - started < timeoutMS) {
      if (await helperIsHealthy()) return true;
      await new Promise((resolve) => Zotero.getMainWindow().setTimeout(resolve, 350));
    }
    return false;
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
    const progress = createProgress(
      "Generating BibTeX with Zotero's built-in translator…",
      item.getField("title") || "Untitled item",
      20
    );

    try {
      const translation = new Zotero.Translate.Export();
      translation.setItems([item]);
      // Use Zotero's stable built-in BibTeX translator UUID directly. This avoids
      // translator discovery races and locale-dependent label matching.
      translation.setTranslator(BIBTEX_TRANSLATOR_ID);

      const output = await new Promise((resolve, reject) => {
        let settled = false;
        const resolveOnce = (value) => {
          if (settled) return;
          settled = true;
          resolve(value);
        };
        const rejectOnce = (error) => {
          if (settled) return;
          settled = true;
          reject(error instanceof Error ? error : new Error(String(error || "BibTeX export failed.")));
        };

        translation.setHandler("done", (obj, worked) => {
          if (!worked) {
            rejectOnce(new Error("Zotero's BibTeX translator reported an export failure."));
            return;
          }
          resolveOnce(obj?.string || "");
        });
        translation.setHandler("error", (_obj, error) => {
          rejectOnce(error || new Error("BibTeX export failed."));
        });

        try {
          const maybePromise = translation.translate();
          if (maybePromise?.catch) {
            maybePromise.catch(rejectOnce);
          }
        } catch (error) {
          rejectOnce(error);
        }
      });

      if (!output.trim()) {
        throw new Error("Zotero produced an empty BibTeX export.");
      }

      Components.classes["@mozilla.org/widget/clipboardhelper;1"]
        .getService(Components.interfaces.nsIClipboardHelper)
        .copyString(output.replace(/\r\n/g, "\n"));

      progress.update("BibTeX copied to the clipboard.", 100);
      progress.close();
      showToast("BibTeX copied to the clipboard.", { success: true, duration: 2500 });
    } catch (error) {
      progress.close();
      log(`Copy BibTeX failed: ${error?.stack || error}`, 1);
      showAlert("Metadata Enricher", `Could not copy BibTeX.\n\n${error.message || error}`);
    }
  }

  async function openReviewDialog(reviewData) {
    const mainWindow = Zotero.getMainWindow();
    const io = {
      data: reviewData,
      result: null,
      ready: false,
      error: null,
    };

    const dialog = mainWindow.openDialog(
      REVIEW_DIALOG_URL,
      `_blank`,
      "chrome,centerscreen,resizable,dialog=no,width=1180,height=700",
      io
    );

    // Fail fast instead of leaving the user staring at an empty window if a
    // future Zotero update breaks review-dialog loading.
    const ready = await new Promise((resolve) => {
      const started = Date.now();
      const timer = mainWindow.setInterval(() => {
        if (dialog.closed) {
          mainWindow.clearInterval(timer);
          resolve(Boolean(io.ready));
          return;
        }
        if (io.ready) {
          mainWindow.clearInterval(timer);
          resolve(true);
          return;
        }
        if (Date.now() - started > 5000) {
          mainWindow.clearInterval(timer);
          try { dialog.close(); } catch (_) {}
          resolve(false);
        }
      }, 100);
    });

    if (!ready) {
      throw new Error(
        io.error ||
          "The metadata review window failed to initialize. Open Tools → Developer → Error Console and retry."
      );
    }

    await new Promise((resolve) => {
      const timer = mainWindow.setInterval(() => {
        if (dialog.closed) {
          mainWindow.clearInterval(timer);
          resolve();
        }
      }, 100);
    });

    if (io.error) {
      throw new Error(io.error);
    }
    return io.result;
  }

  function makeRequestID() {
    return `zme-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  function createProgress(message, detail = "", initialProgress = 0) {
    // Progress feedback is UX, not a dependency of the enrichment engine. If a
    // future Zotero build changes ProgressWindow, log it and keep the actual
    // metadata operation running rather than failing because the spinner failed.
    try {
      const win = new Zotero.ProgressWindow({ closeOnClick: false });
      win.changeHeadline("Metadata Enricher");
      if (detail) {
        const shortDetail = detail.length > 90 ? `${detail.slice(0, 87)}…` : detail;
        win.addDescription(shortDetail);
      }

      const itemProgress = new win.ItemProgress();
      itemProgress.setText(message);
      if (typeof itemProgress.setProgress === "function") {
        itemProgress.setProgress(initialProgress);
      }
      win.show();

      let closed = false;
      return {
        update(text, percent = null) {
          if (closed) return;
          itemProgress.setText(text);
          if (Number.isFinite(percent) && typeof itemProgress.setProgress === "function") {
            itemProgress.setProgress(Math.max(0, Math.min(100, percent)));
          }
        },
        close() {
          if (closed) return;
          closed = true;
          try {
            win.startCloseTimer(100);
          } catch (_) {
            // Progress feedback must never break the actual operation.
          }
        },
      };
    } catch (error) {
      log(`Progress UI unavailable: ${error?.stack || error}`, 2);
      return {
        update() {},
        close() {},
      };
    }
  }

  function showToast(message, { success = false, duration = 3000 } = {}) {
    try {
      const win = new Zotero.ProgressWindow({ closeOnClick: true });
      win.changeHeadline(success ? "Metadata Enricher — Done" : "Metadata Enricher");
      win.addDescription(message);
      win.show();
      win.startCloseTimer(duration);
    } catch (error) {
      // Notifications are secondary; log failures instead of interrupting users.
      log(`Could not show notification: ${error}`, 2);
    }
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
