# Plan: Clip CLI Companion + Branding Resolution

**Date:** 2026-04-05  
**Status:** pending  
**Scope:** CLI binary exposing 3 transformer commands + resolving app/repo branding tension.

---

## Problem

1. The app is named "Clip" but the repo is "markutils" — inconsistent surface area.
2. No CLI access to the pure-Foundation transformers (md2html, html2md, md2social).
3. Future marketing tools should fit a coherent brand umbrella.

---

## Branding Decision: Keep "Clip" — CLI binary `clip`

**Rationale:** The app is already shipped as "Clip" (v1.1.0 released, DMG distributed). Renaming incurs user-facing breakage. "Clip" already semantically covers: clipboard, clipping content, clip-style annotations. The CLI binary `clip` conflicts with nothing on macOS (`clip` is a Windows-only command). Repo name "markutils" is an internal artifact — it does not need to match the binary. Future marketing tools added to the app are "Clip features," not a separate brand.

**Rejected options:**
- "Mark" / `mark` CLI — too narrow, implies markdown-only
- `markutil` CLI — disconnected from app name, harder to remember
- New unified brand — YAGNI; renaming shipped software costs more than it gains

---

## Phases

| # | File | Status |
|---|------|--------|
| 1 | [phase-01-branding-decision.md](phase-01-branding-decision.md) | pending |
| 2 | [phase-02-package-restructure.md](phase-02-package-restructure.md) | pending |
| 3 | [phase-03-cli-commands.md](phase-03-cli-commands.md) | pending |
| 4 | [phase-04-install-and-docs.md](phase-04-install-and-docs.md) | pending |

---

## Resolved Decisions

| # | Question | Decision |
|---|----------|----------|
| 1 | `md2social --style` flag? | No flag — default to app behavior |
| 2 | `html2md` table limitation: fix or document? | **Fix** — extend `htmlToMarkdown` to convert `<table>/<tr>/<th>/<td>` → markdown table syntax |
| 3 | Homebrew tap? | Deferred (YAGNI) |

## Unresolved Questions

- Does `clip` as a binary name cause any shell alias conflicts on users' machines? (Low risk — verify with `which clip` check in install script.)
