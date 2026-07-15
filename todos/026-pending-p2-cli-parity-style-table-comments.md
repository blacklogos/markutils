---
name: CLI parity gaps — style/unstyle, table conversions, comment instruction export
description: UI-only capabilities whose ClipCore APIs are already public — three thin subcommands close all P2 gaps
type: todo
status: pending
priority: p2
issue_id: "026"
tags: [code-review, agent-native, cli]
dependencies: []
---

## Problem Statement

Agent-native parity audit: 7 of 12 user-facing transform capabilities are agent-accessible. Gaps, all packaging (ClipCore functions are public):
1. Single Unicode styles + revertToPlain — UI buttons only. Revert is the strongest case: nothing else on the system can undo mathematical-alphanumeric styling.
2. Table ↔ CSV/TSV (6 TableTransformer directions) — QuickActionsView buttons only; most-used family for this user's marketing/report workload.
3. Comment instruction export (`CommentInstructionCompiler`) — the most agent-shaped feature in the app (its output is agent instructions) yet only deliverable via manual Copy. Comments persist as JSON sidecars at `~/Library/Application Support/Clip/comments/<key>.json`; compiler takes `(comments, text)`.

## Findings

Current CLI surface (Sources/ClipCLI/main.swift): md2html, html2md, md2social [--natural], export, import, search, notes. Reported by: agent-native-reviewer (3×P2, 1×P3).

## Proposed Solutions

### Option A — Three subcommands (recommended shapes)
```
clip style <bold|italic|bold-italic|mono|script|small-caps|underline|strike> [-n] [-c]
clip unstyle [-c]
clip table --from md|csv|tsv --to md|csv|tsv|ascii [-c]
clip comments list <file.md>
clip comments export <file.md>
```
Reuses existing stdin/stdout + -c conventions. `--to ascii` folds the Table→ASCII gap in.
- Effort: Small-Medium | Risk: Low

P3 skippable: `clip diff` (agents already have git diff; only unique value is smart/word/char intraline matching the UI).

## Acceptance Criteria
- [ ] Each new subcommand: stdin→stdout, --help text, exit codes consistent with existing
- [ ] `clip unstyle` round-trips `clip style bold` output including Vietnamese accent mode
- [ ] `clip comments export` output matches UI "Copy for AI" for the same file
