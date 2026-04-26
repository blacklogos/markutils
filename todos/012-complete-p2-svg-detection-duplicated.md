---
name: SVG detection duplicated 3x in AssetGridView with false-positive on <?xml
description: isSVG logic repeated inline and in two computed vars; <?xml prefix matches non-SVG XML documents
type: todo
status: pending
priority: p2
issue_id: "012"
tags: [code-review, architecture, quality]
dependencies: []
---

## Problem Statement

The SVG detection expression `trimmed.hasPrefix("<svg") || trimmed.hasPrefix("<?xml")` appears 3 times across `AssetGridView`: lines 258, 665, 822 (approximately). It also exists as `isSVGAsset` computed vars on two different view structs. The `<?xml` prefix incorrectly matches non-SVG XML (RSS feeds, plists, etc.).

## Findings

**File:** `Sources/Views/AssetGridView.swift` lines 258, 665, 822
- Inline in drag provider
- `isSVGAsset` on `AssetGridView`
- `isSVGAsset` on `AssetItemView`

Reported by architecture-strategist.

## Proposed Solutions

### Option A — Move isSVG onto Asset model (Recommended)
```swift
// In Asset.swift
var isSVG: Bool {
    guard type == .text, let text = textContent else { return false }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("<svg") || (trimmed.hasPrefix("<?xml") && trimmed.contains("<svg"))
}
```
Fix the `<?xml` false-positive by also requiring `<svg` in the document body.
- Pros: Single definition; correct; accessible from CLI too
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] All three call sites replaced with `asset.isSVG`
- [ ] `<?xml` prefix only matches when document also contains `<svg`
- [ ] Existing SVG copy and drag behavior unchanged

## Work Log
- 2026-04-26: Identified by architecture-strategist during PR #15 review
