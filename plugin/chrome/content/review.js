"use strict";

(() => {
  const io = window.arguments?.[0];
  const data = io?.data || {};
  const candidates = data.candidates || [];

  const titleEl = document.getElementById("dialog-title");
  const itemTitleEl = document.getElementById("item-title");
  const bodyEl = document.getElementById("candidate-body");
  const notesEl = document.getElementById("notes");
  const countEl = document.getElementById("selection-count");

  titleEl.textContent = data.title || "Metadata review";
  itemTitleEl.textContent = data.itemTitle || "";

  if (data.notes?.length) {
    notesEl.hidden = false;
    notesEl.textContent = data.notes.join("\n");
  }

  for (const candidate of candidates) {
    bodyEl.appendChild(makeRow(candidate));
  }

  document.getElementById("select-safe").addEventListener("click", () => {
    for (const checkbox of bodyEl.querySelectorAll('input[type="checkbox"]')) {
      const candidate = candidates.find((x) => x.id === checkbox.dataset.id);
      checkbox.checked = shouldDefaultSelect(candidate, true);
    }
    updateCount();
  });

  document.getElementById("clear-all").addEventListener("click", () => {
    for (const checkbox of bodyEl.querySelectorAll('input[type="checkbox"]')) {
      checkbox.checked = false;
    }
    updateCount();
  });

  document.getElementById("cancel").addEventListener("click", () => {
    io.result = null;
    window.close();
  });

  document.getElementById("apply").addEventListener("click", () => {
    const acceptedIDs = [...bodyEl.querySelectorAll('input[type="checkbox"]:checked')]
      .map((checkbox) => checkbox.dataset.id);
    io.result = { acceptedIDs };
    window.close();
  });

  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      io.result = null;
      window.close();
    }
  });

  updateCount();

  function makeRow(candidate) {
    const tr = document.createElement("tr");

    const applyCell = document.createElement("td");
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.dataset.id = candidate.id;
    checkbox.checked = shouldDefaultSelect(candidate, false);
    checkbox.addEventListener("change", updateCount);
    applyCell.appendChild(checkbox);

    const fieldCell = td(prettyField(candidate.field));
    const currentCell = td(candidate.currentValue || "—");
    const proposedCell = td(candidate.value || "—");
    const sourceCell = td(candidate.source || "—");
    const statusCell = document.createElement("td");
    const status = document.createElement("span");
    status.className = "status";
    status.textContent = prettyStatus(candidate.status);
    statusCell.appendChild(status);
    const evidenceCell = td(candidate.evidence || "—");
    evidenceCell.classList.add("muted");

    if (candidate.currentValue) {
      currentCell.classList.add("current-nonempty");
    }

    tr.append(
      applyCell,
      fieldCell,
      currentCell,
      proposedCell,
      sourceCell,
      statusCell,
      evidenceCell
    );
    return tr;
  }

  function shouldDefaultSelect(candidate, safeOnly) {
    if (!candidate) return false;
    if (candidate.currentValue) return false;
    const safe = ["verified", "corroborated", "pdfExtracted"].includes(candidate.status);
    if (safeOnly) return safe;
    return safe;
  }

  function td(text) {
    const cell = document.createElement("td");
    cell.textContent = text;
    return cell;
  }

  function updateCount() {
    const count = bodyEl.querySelectorAll('input[type="checkbox"]:checked').length;
    countEl.textContent = `${count} selected`;
  }

  function prettyField(field) {
    const names = {
      title: "Title",
      creators: "Authors",
      abstractNote: "Abstract",
      DOI: "DOI",
      publicationTitle: "Publication",
      conferenceName: "Conference",
      proceedingsTitle: "Proceedings",
      date: "Date",
      volume: "Volume",
      issue: "Issue",
      pages: "Pages",
      publisher: "Publisher",
      place: "Place",
      ISBN: "ISBN",
      ISSN: "ISSN",
      url: "URL",
      language: "Language",
      tags: "Tags / keywords",
      extra: "Extra",
    };
    return names[field] || field;
  }

  function prettyStatus(status) {
    const names = {
      verified: "Verified",
      corroborated: "Corroborated",
      pdfExtracted: "PDF extracted",
      aiFromPDF: "AI from PDF",
      aiInferred: "AI inferred",
      online: "Online",
    };
    return names[status] || status || "Unknown";
  }
})();
