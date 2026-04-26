---
name: NoteStore has zero CLI coverage — entire notes domain inaccessible to agents
description: PR #15 adds a full notes feature with no clip-tool subcommands; agents cannot create, read, edit, export, or search notes
type: todo
status: pending
priority: p1
issue_id: "004"
tags: [code-review, agent-native]
dependencies: []
---

## Problem Statement

PR #15 introduces NoteStore with JSON persistence at `~/Library/Application Support/Clip/notes.json`. Every user action — create today's note, edit body, delete, export as .md, copy to clipboard, search — is UI-only. `clip-tool` has no subcommands touching this file. An AI agent using clip-tool cannot access, create, or manipulate notes at all.

## Findings

**File:** `Sources/ClipCLI/main.swift` — no notes subcommands exist
**File:** `Sources/Models/Note.swift` — NoteStore API is fully available for CLI use

Missing CLI capabilities vs. UI capabilities in PR #15:

| UI Action | CLI command needed |
|---|---|
| Read/write today's note | `clip notes today [--body "..."]` |
| List all notes | `clip notes list` |
| Search notes | `clip notes search <query>` |
| Delete note | `clip notes delete --id <uuid>` |
| Export note | `clip notes export --id <uuid> --output <path>` |

Additionally from earlier PRs:
- PR #10: recursive vault search — no `clip search <query>` command
- PR #12: per-asset clipboard copy — no `clip vault copy --id <uuid>`

Reported by agent-native-reviewer.

## Proposed Solutions

### Option A — Add `notes` subcommand group (Recommended)
Extend `main.swift` with a `notes` command that mirrors NoteStore operations:
```
clip notes today            # print today's note body
clip notes today --set "…"  # replace today's note body
clip notes list             # print all notes as JSON
clip notes search <query>   # print matching notes
clip notes delete <uuid>    # delete by ID
clip notes export <uuid>    # write .md to stdout or --output path
```
- Pros: Full agent parity; directly reads/writes `notes.json`
- Cons: CLI must replicate NoteStore decode/encode (or import ClipCore)
- Effort: Medium | Risk: Low

### Option B — Expose NoteStore via ClipCore and import in CLI
Move NoteStore into ClipCore (alongside AssetStore) so CLI can import it directly.
- Pros: DRY — single NoteStore implementation; CLI gets full API
- Cons: Requires refactoring NoteStore out of Sources/ into ClipCore/
- Effort: Medium | Risk: Low

### Option C — Minimal: read-only today note
Add only `clip notes today` (read-only) as a quick win.
- Pros: Immediate value for the most common agent use case
- Cons: Write, search, delete still missing
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] `clip notes today` prints today's note body to stdout
- [ ] `clip notes today --set "body"` writes/replaces today's note
- [ ] `clip notes list` outputs JSON array of notes
- [ ] `clip notes search <query>` returns matching notes
- [ ] All commands handle missing notes.json gracefully

## Work Log
- 2026-04-26: Identified by agent-native-reviewer during PR #15 review
