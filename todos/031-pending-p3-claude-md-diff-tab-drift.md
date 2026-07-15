---
name: CLAUDE.md architecture section missing Diff tab (⌘6)
description: Doc lists tabs 0-4 / ⌘1-⌘5; ContentView now has a sixth Diff tab on ⌘6
type: todo
status: pending
priority: p3
issue_id: "031"
tags: [code-review, docs]
dependencies: []
---

## Problem Statement / Findings

`CLAUDE.md` "Tabs in ContentView" documents 0-4 with ⌘1-⌘5. `ContentView.swift:132` added tab 5: `DiffView` on ⌘6. Doc drift misleads future agent sessions.

Reported by: architecture-strategist (P3). Related P3 backlog note from same agent: three divergent markdown inline parsers (Utilities/RichTextTransformer.parseInlineFormatting, ClipCore/RichTextTransformer.parseInline, UnicodeTextFormatter.convertInline) render the same markdown differently — pre-existing, track separately if it bites.

## Proposed Solutions

Add tab 5 line: `5: DiffView — paste two texts, side-by-side diff with precision picker (smart/line/word/char); engine in ClipCore TextDiff*`. Update shortcut range to ⌘1-⌘6. Do it in the branch commit that ships the Diff UI.
- Effort: Small | Risk: None

## Acceptance Criteria
- [ ] CLAUDE.md tab list matches ContentView
