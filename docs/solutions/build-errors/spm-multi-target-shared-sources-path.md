---
title: SPM multi-target cohabitation with shared Sources/ path
slug: spm-multi-target-shared-sources-path
category: build-errors
tags: [swift, spm, package.swift, multi-target, exclude]
problem_type: build_error
component: Package.swift / SPM target layout
symptoms:
  - "error: target 'Clip' has sources at 'Sources/ClipCore' which are already claimed by target 'ClipCore'"
  - Build fails when two SPM targets share overlapping source paths
  - Adding a library or CLI target alongside an existing executable target that owns Sources/
solved: true
date: 2026-04-05
---

## Problem

When adding `ClipCore` (library) and `ClipCLI` (CLI executable) targets to a Swift package where the existing `Clip` app target already owned the entire `Sources/` directory via `path: "Sources"`, SPM complains that source files are claimed by multiple targets.

```
error: target 'Clip' has sources at 'Sources/ClipCore' which are already claimed by target 'ClipCore'
```

## Root Cause

SPM resolves source files by scanning the `path` directory recursively. Without explicit exclusions, the app target (`path: "Sources"`) claimed everything — including subdirectories intended for other targets.

## Solution

Use the `exclude:` parameter on the broad-path target to tell SPM which subdirectories belong to other targets:

```swift
.executableTarget(
    name: "Clip",
    dependencies: ["ClipCore"],
    path: "Sources",
    exclude: ["ClipCore", "ClipCLI"]   // exclude subdirs owned by other targets
),
.target(
    name: "ClipCore",
    path: "Sources/ClipCore"
),
.executableTarget(
    name: "ClipCLI",
    dependencies: ["ClipCore"],
    path: "Sources/ClipCLI"
),
```

`exclude:` entries are relative to the target's `path`, not the package root.

## Applied Context

This project split `RichTextTransformer`, `TableTransformer`, and `UnicodeTextFormatter` into a `ClipCore` Foundation-only library so a new `clip` CLI could share them without importing AppKit. The `Clip` GUI app target retained its broad `Sources/` path and just excludes the two new subdirs.

## File Split Strategy for Mixed-Platform Dependencies

When a file contains both AppKit and Foundation code, don't use `#if canImport(AppKit)` guards — split cleanly:

| File | Location | Imports |
|------|----------|---------|
| `RichTextTransformer.swift` (HTML methods) | `Sources/ClipCore/` | Foundation only |
| `RichTextTransformer.swift` (AppKit methods, extension) | `Sources/Utilities/` | Foundation + AppKit |

The ClipCore version defines the struct; the app-target version adds an `extension RichTextTransformer` with AppKit methods. SPM resolves this because they're in separate targets — no duplicate type error.

## Alternative: Move app sources to Sources/Clip/

The cleaner long-term structure is:

```
Sources/
  Clip/        ← app executable
  ClipCore/    ← shared library
  ClipCLI/     ← CLI executable
```

This eliminates the need for `exclude:` entirely. Cost: rename/move every app source file. Higher churn. The `exclude:` approach is lower risk for an existing codebase.

## Prevention

When planning a new SPM library extraction from an existing executable-only package:
1. Decide up-front: use `exclude:` (lower churn) or restructure to subdirectory (cleaner long-term).
2. Add subdirs to `exclude:` before adding the new `target` entry — prevents intermediate build failures.
3. Verify with `swift build` after each Package.swift change.
4. Ensure executable product names are unique under case-insensitive comparison — see [SPM Product Name Collision on APFS](spm-product-name-collision-case-insensitive-apfs-20260407.md).
