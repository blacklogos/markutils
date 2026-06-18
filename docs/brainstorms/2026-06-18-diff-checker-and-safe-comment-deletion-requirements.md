---
date: 2026-06-18
type: brainstorm
status: agreed
scope: phase-1-only
---

# Brainstorm: Markdown Diff Checker + Safe Comment Deletion

Two independent asks, brainstormed together. Agreed scope = **Phase 1 only**. Phase 2 listed but explicitly deferred.

---

## Problem Statement

1. **Safe comment removal.** Reader comment delete is one-click, instant, no undo (trash icon fires immediately). A non-technical user can lose a note by accident; there is no "start over" either.
2. **Diff checker.** No way to compare two markdown texts. Closes the comments loop: export notes → external agent revises → paste revised back → *diff vs original to verify changes before trusting them*.

---

## Scope (Phase 1)

**In:**
- Diff tab: two paste panes, line-level unified (git-style red/green) diff, pure ClipCore, WebView render.
- Comments: confirm before single delete; "Clear all" button (with confirm).

**Out (deferred → Phase 2):**
- Word-level intra-line highlight; per-pane file loading; loop-aware "Compare revised" button from Reader; side-by-side layout toggle.
- Undo-after-delete; dedicated "resolve needs-review"; bulk "clear needs-review".

**Refused (over-engineering, not planned):** markdown-AST/semantic diff, 3-way merge, char-level move detection, git integration, soft-delete/trash bin/history.

---

## Feature 1 — Safe Comment Deletion

**Decision:** confirm-on-destructive, no undo.

- Single delete → confirmation ("Delete this comment?") before removing.
- "Clear all" → header/panel action, confirm ("Clear all N comments?"), wipes the open file's comments.

**Rationale:**
- Confirm + undo together is contradictory UX — confirm already prevents the accident; undo adds transient snapshot + timer + affordance for a rare action. KISS → confirm.
- "Resolve needs-review" dropped: the ⚠️ row already has delete; resolve *is* delete (DRY). Bulk "clear needs-review" deferred until volume justifies it.
- No "Add comment" toolbar button: comments are born from a selection; a toolbar add with nothing selected is meaningless (YAGNI).

**Approaches considered:**
| Approach | Pros | Cons | Verdict |
|---|---|---|---|
| Confirm before delete | trivial, no state, stops accidents | one extra click | **chosen** |
| Undo after delete | smooth, modern | transient state, timer, redundant w/ confirm | deferred |
| Soft-delete/trash | recoverable | persistence + UI overkill for a sidecar note | refused |

**Implementation notes:** SwiftUI `confirmationDialog` / alert on the row trash + a panel-level "Clear all". `CommentStore.delete` / a new `clearAll()` already trivial. No model change. Source `.md` still never touched.

---

## Feature 2 — Markdown Diff Checker

**Decision:** new tab (⌘6), two paste panes, **line-level unified** diff, pure-ClipCore LCS, render in WebView reusing `MarkdownPreviewStyle`.

**Why line-level + unified first:** ~120 lines pure Swift, deterministic, unit-testable like `TableTransformer`; unified column is compact and the 80% use-case. Word-level (~2× algo+render) and side-by-side are polish.

**Why paste panes first:** ships in half the time; covers the loop case (paste original + paste agent-revised). File loading doubles each pane's input UI — deferred.

**Approaches considered:**
| Dimension | Options | Chosen | Why |
|---|---|---|---|
| Algorithm | line LCS / line+word / AST-semantic | line LCS | 80% value, lowest cost, testable |
| Input | paste / file / both | paste | fastest; loop case covered |
| Layout | unified / side-by-side | unified | compact, less layout work |
| Home | new tab loop-aware / plain tab / inside Transform | new tab (loop hook deferred) | clean, doesn't crowd Transform |

**Architecture (mirrors existing patterns):**
- `Sources/ClipCore/TextDiff.swift` — pure `diff(_ a:String, _ b:String) -> [DiffLine]` (LCS over lines; `DiffLine` = `.equal/.added/.removed`). No UI imports. Unit-tested.
- Render: build HTML (red/green line backgrounds via `MarkdownPreviewStyle` additions) → `HTMLPreviewView`. Diff shows RAW markdown lines, not rendered HTML.
- New `DiffView.swift` tab; register as tab index 5 (⌘6) in `ContentView` alongside the existing 5.

**Risks / honesty:**
- LCS on very large texts is O(n·m) memory — cap input size like Reader's `maxFileBytes`; chunk or guard. Low risk for this app's use.
- Unified line diff misses intra-line nuance (a 1-word change shows whole line replaced) — acceptable for v1, word-level is Phase 2.
- Pure line compare is whitespace/trailing-newline sensitive — decide trim policy (likely diff as-is; note it).

---

## Success Criteria

**Comments:** deleting requires explicit confirm; "Clear all" empties the file's sidecar after confirm; no accidental single-click loss; source `.md` bytes unchanged.

**Diff:** paste two texts → identical lines plain, removed red, added green, correctly aligned by LCS; empty/identical inputs handled without crash; large input guarded; `swift test` covers add/remove/equal/empty/reorder cases.

---

## Next Steps / Dependencies

1. Comments: small, no deps → `confirmationDialog` on row + `CommentStore.clearAll()`. Can land independently.
2. Diff: `TextDiff` (ClipCore) + tests → `DiffView` tab + `ContentView` registration + `MarkdownPreviewStyle` diff colors.
3. Both ship behind `./scripts/verify_release.sh` (needs full Xcode for `swift test`).
4. Sequencing: ship Comments-safety first (tiny), then Diff.

→ Ready for `/plan` (Diff is the meatier one; Comments-safety may not need a full plan).

---

## Unresolved Questions

- Diff whitespace policy: diff lines verbatim, or trim trailing whitespace / normalize line endings before compare? (lean: verbatim, surface a "trim whitespace" toggle only if needed — Phase 2.)
- "Clear all" placement: panel header vs preview toolbar? (lean: panel header, next to the count.)
- Diff tab empty-state + how the two panes are labeled (Original / Revised vs A / B). (lean: Original / Revised to reinforce the loop.)
