# Phase 01 — Branding Decision

**Status:** pending  
**Parent:** [plan.md](plan.md)

---

## Context Links

- CLAUDE.md: `/Users/trivo/Documents/markutils/CLAUDE.md`
- Package.swift (in-repo root)
- Existing releases: `df27da9 release: v1.1.0 DMG + Gatekeeper install guide`

---

## Overview

Resolve the naming tension between app ("Clip"), repo ("markutils"), and the new CLI binary before any code is written. A wrong decision here is expensive to undo once the binary is in users' PATH.

---

## Key Insights

1. App is already shipped as "Clip" at v1.1.0. Renaming = user-facing breakage + re-notarization.
2. macOS ships no `clip` command. `which clip` returns nothing on a clean macOS 14 system.
3. "markutils" is the git remote repo name only — not user-visible in any shipped artifact.
4. Clip's value prop already spans clipboard + content transformation + social formatting. "Clip" covers this naturally (clipping content, clipboard utility).
5. A future "Slides" or "Proposals" feature fits as "Clip > Slides" not as a separate brand.

---

## Requirements

- CLI binary name must not conflict with existing macOS/Unix commands.
- Binary name should be memorable and consistent with the GUI app.
- Branding must accommodate future marketing-focused tools (MD reports, tables, slides, proposals).
- Zero user-facing rename of the existing GUI app.

---

## Architecture (Decision)

**Chosen: `clip` binary, app stays "Clip", repo stays "markutils" (internal only).**

```
GUI App:   Clip.app  (menu bar, NSStatusItem)
CLI:       /usr/local/bin/clip
Repo:      markutils  (never user-visible)
```

No changes to: bundle ID, app name, DMG name, or any existing user-facing artifact.

---

## Related Code Files

- `Sources/ClipApp.swift` — app entry point, bundle ID `com.clip.app` (assumed; verify)
- `Sources/AppDelegate.swift` — status item setup

---

## Implementation Steps

1. Verify `com.clip.app` (or similar) is the actual bundle ID in `Sources/ClipApp.swift`.
2. Document the branding decision in a DECISIONS.md or equivalent (optional, keep brief).
3. No file renames required.

---

## Todo

- [ ] Confirm bundle ID in ClipApp.swift
- [ ] Confirm `which clip` is empty on target macOS versions (add check to install script)

---

## Success Criteria

- Team agrees on `clip` as binary name.
- No ambiguity about app name vs CLI name (they are the same word, different surfaces — acceptable).

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Shell alias conflict (`clip` already aliased by user) | Low | Install script warns if `clip` resolves to something else |
| Confusion: `clip` app vs `clip` CLI | Low | --help clearly says "Clip CLI — command-line companion to the Clip macOS app" |
| Future rename pressure as scope grows | Medium | Reassess at v2.0 milestone |

---

## Security Considerations

None specific to branding. Binary name has no security implications.

---

## Next Steps

Proceed to Phase 02 (Package restructure) once binary name is confirmed.
