# Security Policy

## Supported version

Security fixes are applied to the current development line. At the time of this document, that is 0.2.x for Zotero 10. Older development builds may contain known runtime and packaging defects and should be upgraded.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose a Zotero library, local files, the helper token, or execute code unexpectedly.

Use GitHub's private vulnerability reporting for this repository:

<https://github.com/conradoguimaraes/ZoteroAI/security/advisories/new>

Include the affected version/build, Zotero and macOS versions, reproduction steps, impact, and a minimal proof of concept. Remove real library data and credentials.

If private vulnerability reporting is unavailable, open a minimal public issue asking the maintainer to enable a private contact channel. Do not include exploit details.

## Security model

- The native helper listens only on `127.0.0.1:43119`.
- Enrichment endpoints require a random token stored locally with mode `0600`.
- The unauthenticated health endpoint reports service/version/build and Apple Intelligence availability only.
- The helper returns proposals and does not write Zotero's database.
- The Zotero plugin applies only proposals explicitly selected in the review UI.

These controls reduce risk but do not sandbox the Zotero plugin. Zotero plugins run with broad access to Zotero and the computer; install only code and builds you trust.

## Out of scope

- Incorrect metadata proposals that are clearly marked for review, unless they bypass review or cause unauthorized writes;
- provider availability or inaccurate third-party records;
- unsupported operating systems or Zotero versions;
- social-engineering reports without a technical vulnerability.

Privacy leaks, authentication bypasses, unintended external data transmission, path traversal, arbitrary file access, unsafe update behavior, and code execution are in scope.
