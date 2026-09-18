"use strict";

var ZME = null;

async function startup({ id, version, rootURI }, reason) {
  await Promise.all([
    Zotero.initializationPromise,
    Zotero.unlockPromise,
  ]);

  const scope = {
    Zotero,
    Services,
    Components,
    console,
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
  if (ZME) {
    await ZME.shutdown();
    ZME = null;
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
