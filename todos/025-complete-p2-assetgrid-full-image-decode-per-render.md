---
name: AssetGridView decodes full-size images in body per cell per evaluation
description: NSImage(data:) inside body re-decodes full bitmaps (48 MB for a 4000×3000 shot) to draw 80×80 thumbnails on every re-evaluation
type: todo
status: complete
priority: p2
issue_id: "025"
tags: [code-review, performance, assets]
dependencies: []
---

## Problem Statement

`NSImage(data:)` runs inside `body` (AssetGridView.swift:523,723), so every re-evaluation of a visible cell (selection, hover, store mutation) re-decodes the full image to render a thumbnail. 20 visible cells re-evaluating together = visible hitching + large transient memory. Pre-existing.

## Findings

Reported by: performance-oracle (P2-2).

## Proposed Solutions

### Option A — Thumbnail cache keyed by asset id
`CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize: 160`, decode once off main, cache `[UUID: NSImage]` (invalidate on asset change).
- Effort: Small-Medium | Risk: Low

## Acceptance Criteria
- [ ] Scrolling/selecting in a grid of 20+ image assets shows no hitching
- [ ] Full decode happens once per asset, not per body eval
