---
name: CLI export/import force-try on user-supplied --file paths
description: try! on file reads/writes crashes with a trap instead of clean error + exit code on unwritable or malformed paths
type: todo
status: pending
priority: p3
issue_id: "029"
tags: [code-review, quality, cli]
dependencies: []
---

## Problem Statement / Findings

`Sources/ClipCLI/main.swift:216,226,234,237,250,263-264` — `try!` on `Data(contentsOf:)`, `write(toFile:)`, encode. Non-writable path or corrupt vault file = crash trap, not error. User's own privileges, so robustness not a privilege boundary (no traversal escalation exists — verified).

Reported by: security-sentinel (P3).

## Proposed Solutions

Convert to do/catch with `fputs(...., stderr); exit(2)`, matching the existing import file-not-found handling (line 246).
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] `clip export -f /nonexistent-dir/x.json` prints error, exits 2, no crash
- [ ] Corrupt assets.json on export prints error, exits nonzero
