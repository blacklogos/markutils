---
name: pasteAsPNG image conversion runs synchronously on main thread (PR #12)
description: NSImage → TIFF → NSBitmapImageRep → PNG conversion blocks UI for large retina screenshots
type: todo
status: pending
priority: p3
issue_id: "015"
tags: [code-review, performance]
dependencies: []
---

## Problem Statement

`AssetGridView.pasteAsPNG()` performs `NSImage → tiffRepresentation → NSBitmapImageRep → PNG representation` synchronously as a button action on the main thread. For a large retina screenshot (10–20 MB TIFF), this can freeze the UI for 200–500 ms.

## Findings

**File:** `Sources/Views/AssetGridView.swift` lines 412–429

Reported by performance-oracle.

## Proposed Solutions

### Option A — Task.detached for conversion, MainActor for store mutation
```swift
private func pasteAsPNG() {
    let pb = NSPasteboard.general
    guard let image = NSImage(pasteboard: pb) else { showNothingToPasteAlert(); return }
    Task.detached {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        let asset = Asset(type: .image, imageData: png, name: "Pasted Image")
        await MainActor.run { self.store.add(asset) }
    }
}
```
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] Pasting a 4K screenshot shows no UI freeze
- [ ] Asset appears in vault after conversion completes

## Work Log
- 2026-04-26: Identified by performance-oracle during PR #12 review
