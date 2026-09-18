"use strict";

(() => {
  const io = window.arguments?.[0];

  try {
    if (!io || !io.data) {
      throw new Error("The review window did not receive metadata from the Zotero plugin.");
    }

    const data = io.data;
    const candidates = Array.isArray(data.candidates) ? data.candidates : [];
    const fieldCounts = candidates.reduce((counts, candidate) => {
      counts[candidate.field] = (counts[candidate.field] || 0) + 1;
      return counts;
    }, {});

    const titleEl = required("dialog-title");
    const itemTitleEl = required("item-title");
    const bodyEl = required("candidate-body");
    const notesEl = required("notes");
    const notesWrapEl = required("notes-wrap");
    const countEl = required("selection-count");
    const initializingEl = required("initializing");
    const contentEl = required("review-content");

    titleEl.textContent = data.title || "Metadata review";
    itemTitleEl.textContent = data.itemTitle || "";

    if (Array.isArray(data.notes) && data.notes.length) {
      notesWrapEl.hidden = false;
      notesEl.textContent = data.notes.join("\n\n");
    }

    const conflictingFields = Object.values(fieldCounts).filter((count) => count > 1).length;
    if (conflictingFields > 0) {
      const guidance = document.querySelector(".guidance");
      if (guidance) {
        guidance.append(` ${conflictingFields} field${conflictingFields === 1 ? " has" : "s have"} conflicting alternatives; choose at most one proposal per field.`);
      }
    }

    for (const candidate of candidates) {
      bodyEl.appendChild(makeRow(candidate));
    }

    required("select-safe").addEventListener("click", () => {
      for (const checkbox of bodyEl.querySelectorAll('input[type="checkbox"]')) {
        const candidate = candidates.find((x) => x.id === checkbox.dataset.id);
        checkbox.checked = shouldDefaultSelect(candidate);
      }
      updateCount();
    });

    required("clear-all").addEventListener("click", () => {
      for (const checkbox of bodyEl.querySelectorAll('input[type="checkbox"]')) {
        checkbox.checked = false;
      }
      updateCount();
    });

    required("cancel").addEventListener("click", () => {
      io.result = null;
      window.close();
    });

    required("apply").addEventListener("click", () => {
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
    initializingEl.hidden = true;
    contentEl.hidden = false;
    io.ready = true;

    function required(id) {
      const element = document.getElementById(id);
      if (!element) throw new Error(`Review UI element #${id} is missing.`);
      return element;
    }

    function makeRow(candidate) {
      const tr = document.createElement("tr");
      const replacingExisting = Boolean(candidate.currentValue);
      const hasAlternatives = (fieldCounts[candidate.field] || 0) > 1;
      if (replacingExisting) tr.classList.add("replacement-row");
      if (hasAlternatives) tr.classList.add("conflict-row");

      const applyCell = document.createElement("td");
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.dataset.id = candidate.id;
      checkbox.dataset.field = candidate.field;
      checkbox.checked = shouldDefaultSelect(candidate);
      checkbox.setAttribute("aria-label", `Apply proposed ${prettyField(candidate.field)}`);
      checkbox.addEventListener("change", () => {
        if (checkbox.checked) {
          // Only one proposal for a Zotero field can be applied. This matters in
          // combined mode where PDF and online sources may disagree.
          for (const sibling of bodyEl.querySelectorAll('input[type="checkbox"]')) {
            if (sibling !== checkbox && sibling.dataset.field === candidate.field) {
              sibling.checked = false;
            }
          }
        }
        updateCount();
      });
      applyCell.appendChild(checkbox);

      const fieldCell = document.createElement("td");
      fieldCell.classList.add("field-cell");
      const fieldLabel = document.createElement("div");
      fieldLabel.textContent = prettyField(candidate.field);
      fieldCell.appendChild(fieldLabel);
      if (hasAlternatives) {
        const alternative = document.createElement("div");
        alternative.className = "alternative-note";
        alternative.textContent = `${fieldCounts[candidate.field]} alternatives`;
        fieldCell.appendChild(alternative);
      }

      const currentCell = td(candidate.currentValue || "—");
      const proposedCell = td(candidate.value || "—");
      proposedCell.classList.add("proposed-cell");
      const sourceCell = td(candidate.source || "—");

      const statusCell = document.createElement("td");
      const status = document.createElement("span");
      status.className = `status status-${statusClass(candidate.status)}`;
      status.textContent = prettyStatus(candidate.status);
      if (Number.isFinite(candidate.confidence)) {
        status.title = `Confidence: ${Math.round(candidate.confidence * 100)}%`;
      }
      statusCell.appendChild(status);

      const evidenceCell = td(candidate.evidence || "—");
      evidenceCell.classList.add("muted");

      if (replacingExisting) {
        currentCell.classList.add("current-nonempty");
        applyCell.title = "This would replace an existing Zotero value, so it is not selected automatically.";
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

    function shouldDefaultSelect(candidate) {
      if (!candidate || candidate.currentValue) return false;
      if ((fieldCounts[candidate.field] || 0) > 1) return false;
      return ["verified", "corroborated", "pdfExtracted"].includes(candidate.status);
    }

    function td(text) {
      const cell = document.createElement("td");
      cell.textContent = String(text ?? "");
      return cell;
    }

    function updateCount() {
      const selected = bodyEl.querySelectorAll('input[type="checkbox"]:checked').length;
      countEl.textContent = `${selected} of ${candidates.length} proposed field${candidates.length === 1 ? "" : "s"} selected`;
      required("apply").disabled = selected === 0;
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
        online: "Online match",
      };
      return names[status] || status || "Unknown";
    }

    function statusClass(status) {
      if (["verified", "corroborated", "pdfExtracted"].includes(status)) return "strong";
      if (["aiFromPDF", "aiInferred"].includes(status)) return "ai";
      return "neutral";
    }
  } catch (error) {
    const message = String(error?.message || error || "Unknown review-window error");
    if (io) {
      io.error = message;
      io.ready = false;
    }

    const initializingEl = document.getElementById("initializing");
    if (initializingEl) initializingEl.hidden = true;
    const fatalEl = document.getElementById("fatal-error");
    const fatalTextEl = document.getElementById("fatal-error-text");
    if (fatalEl) fatalEl.hidden = false;
    if (fatalTextEl) fatalTextEl.textContent = message;
  }
})();
