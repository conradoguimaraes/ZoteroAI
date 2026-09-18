"use strict";

var ZME = null;
var chromeHandle = null;

async function startup({ id, version, rootURI }, reason) {
  await Promise.all([
    Zotero.initializationPromise,
    Zotero.unlockPromise,
  ]);

  // Zotero 7+ no longer reads chrome.manifest files for bootstrapped plugins.
  // Register our content package at runtime so auxiliary windows such as the
  // metadata review dialog can be opened through a stable chrome:// URL.
  const addonManagerStartup = Components.classes[
    "@mozilla.org/addons/addon-manager-startup;1"
  ].getService(Components.interfaces.amIAddonManagerStartup);
  const manifestURI = Services.io.newURI(rootURI + "manifest.json");
  chromeHandle = addonManagerStartup.registerChrome(manifestURI, [
    ["content", "zotero-metadata-enricher", "chrome/content/"],
  ]);

  // Zotero bootstrapped-plugin sandboxes expose Zotero/Services/Components,
  // but do not guarantee a browser-style `console` global. Passing an
  // undeclared `console` here aborts startup before main.js is loaded.
  const scope = {
    Zotero,
    Services,
    Components,
  };

  Services.scriptloader.loadSubScript(
    rootURI + "chrome/content/main.js",
    scope
  );

  ZME = scope.ZME;
  if (!ZME) {
    throw new Error("Zotero Metadata Enricher failed to load main.js");
  }

  await ZME.startup({ id, version, rootURI });
}

async function shutdown({ id, version, rootURI }, reason) {
  try {
    if (ZME) {
      await ZME.shutdown();
      ZME = null;
    }
  } finally {
    if (chromeHandle) {
      try {
        chromeHandle.destruct();
      } catch (error) {
        Zotero?.logError?.(error);
      }
      chromeHandle = null;
    }
  }
}

function onMainWindowLoad(args) {
  ZME?.onMainWindowLoad(args);
}

function onMainWindowUnload(args) {
  ZME?.onMainWindowUnload(args);
}

function install() {}
function uninstall() {}
