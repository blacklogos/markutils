---
title: "Swift CLI Target Isolation — VaultAsset Pattern for @Observable-free Codable"
category: best-practice
date: 2026-04-08
tags: [swift, cli, observable, codable, multi-target, spm, architecture]
component: Sources/ClipCLI/main.swift, Sources/Models/Asset.swift
related:
  - docs/solutions/build-errors/spm-multi-target-shared-sources-path.md
  - docs/solutions/build-errors/spm-product-name-collision-case-insensitive-apfs-20260407.md
  - docs/solutions/best-practice/swift-cli-clipboard-dmg-bundling-20260406.md
---

## Problem

The `clip export` and `clip import` CLI subcommands need to read and write the same `assets.json` vault file as the GUI app. But the `Asset` model in the app target uses the `@Observable` macro (Observation framework), which requires SwiftUI/AppKit runtime. The CLI target (`ClipCLI`) depends only on `ClipCore` (pure Foundation) and cannot import the main `Clip` target.

Attempting to share the `Asset` type directly would pull in `@Observable` and its framework dependencies, breaking the CLI build.

## Root Cause

Swift's `@Observable` macro (from the Observation framework) generates synthesized code that depends on the Observation runtime. While Observation is technically available in Foundation on macOS 14+, the macro expansion creates a coupling that makes the type unsuitable for lightweight CLI targets that should remain free of UI framework assumptions.

The project's target graph enforces this separation:

```
ClipCore  (Foundation only)
├── Clip  (app — depends on ClipCore, uses @Observable)
└── ClipCLI  (CLI — depends on ClipCore only)
```

## Solution

Create a minimal `VaultAsset` struct in the CLI target that mirrors `Asset`'s Codable schema without `@Observable`:

```swift
// Sources/ClipCLI/main.swift

/// Minimal Codable mirror of Asset for validation.
/// ClipCLI cannot import Clip target (@Observable incompatible).
struct VaultAsset: Codable {
    let id: UUID
    let creationDate: Date
    let type: String          // "text", "image", "folder"
    let textContent: String?
    let imageData: Data?
    let name: String?
    let children: [VaultAsset]?
}
```

This type is used for:
1. **Export**: Decode `assets.json` as `[VaultAsset]`, re-encode with pretty-printing
2. **Import**: Decode input JSON as `[VaultAsset]` to validate structure, then write raw data to vault path

The vault file path is shared between app and CLI:

```swift
func vaultFileURL() -> URL {
    let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    return appSupport.appendingPathComponent("Clip/assets.json")
}
```

## Why Not Put Asset in ClipCore?

The `Asset` class uses `@Observable` for SwiftUI reactivity (`didSet` on `assets` triggers save). Moving it to ClipCore would either:
- Pull `@Observable` into the shared library (defeating the purpose of a pure-Foundation core)
- Require splitting Asset into a base Codable struct + an Observable wrapper

The VaultAsset mirror is simpler: it's ~10 lines, lives in one file, and the schema rarely changes.

## Prevention

1. **Schema drift test** — if tests are added, validate that `VaultAsset` can decode JSON produced by `Asset`:
   ```swift
   func testVaultAssetMatchesAssetSchema() {
       let asset = Asset(type: .text, textContent: "test")
       let encoded = try JSONEncoder().encode([asset])
       let decoded = try JSONDecoder().decode([VaultAsset].self, from: encoded)
       XCTAssertEqual(decoded[0].textContent, "test")
   }
   ```
2. **Comment the coupling** — the VaultAsset struct should document why it exists and which type it mirrors
3. **Build both targets in CI** — `swift build --product Clip && swift build --product clip-tool` catches import leaks early
