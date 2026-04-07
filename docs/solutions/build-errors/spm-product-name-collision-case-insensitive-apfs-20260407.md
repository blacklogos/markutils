---
title: SPM Product Name Collision on APFS Case-Insensitive Filesystem
slug: spm-product-name-collision-case-insensitive-apfs
category: build-errors
tags: [swift, swift-package-manager, macos, apfs, case-insensitive, binary-collision, dmg, cli, packaging]
problem_type: filesystem-naming-collision
component:
  - Package.swift
  - scripts/build_dmg.sh
  - scripts/install_cli.sh
symptoms:
  - Clip.app in DMG launches CLI help text instead of GUI
  - App binary silently overwritten by CLI binary during release build
  - NSApp never starts — process exits immediately after printing usage
  - DMG appears valid but app is non-functional
solved: true
date: 2026-04-07
---

## Problem

On macOS APFS (case-insensitive by default), Swift Package Manager produced two executable products — `Clip` (GUI app) and `clip` (CLI tool) — whose output binaries resolved to the same filesystem path. `.build/release/Clip` and `.build/release/clip` share the same inode on a case-insensitive volume.

`build_dmg.sh` built the two products sequentially:

1. `swift build -c release --product Clip` — wrote the 2.1MB GUI binary
2. `swift build -c release --product clip` — overwrote it with the 163KB CLI binary

The resulting `Clip.app/Contents/MacOS/Clip` inside the DMG was the CLI binary. Launching the app printed `--help` and exited immediately.

Confirmed with `ls -lai`:

```
21121562 -rwxr-xr-x  162552 .build/release/clip
21121562 -rwxr-xr-x  162552 .build/release/Clip   # same inode — same file
```

## Root Cause

APFS case-insensitive filesystem collision. Two SPM executable products whose names differ only by case (`Clip` vs `clip`) share a single output path in `.build/release/`. The second `swift build` invocation silently overwrote the first product's binary with no error or warning from SPM.

## Solution

Rename the CLI product in `Package.swift` so it no longer collides with the GUI product name, then thread the new name through build and install scripts while keeping the end-user-facing binary name (`clip`) unchanged.

### Package.swift — rename CLI product

```swift
// Before
.executable(name: "clip", targets: ["ClipCLI"]),

// After
.executable(name: "clip-tool", targets: ["ClipCLI"]),
```

### scripts/build_dmg.sh — build renamed product, copy as `clip`

```bash
# Before
swift build -c release --product "clip"
cp "${BUILD_DIR}/clip" "${DMG_STAGING}/clip"

# After
swift build -c release --product "clip-tool"
cp "${BUILD_DIR}/clip-tool" "${DMG_STAGING}/clip"
```

### scripts/install_cli.sh — build renamed product when installing from source

```bash
# Before
swift build -c release --product "${BINARY_NAME}"
BUILT_PATH=".build/release/${BINARY_NAME}"

# After
swift build -c release --product "clip-tool"
BUILT_PATH=".build/release/clip-tool"
```

The end-user-facing name remains `clip` at every install destination (`/usr/local/bin/clip`, DMG staging). Only the internal SPM product name changes.

### Verification

After the fix, the two binaries are distinct inodes at distinct sizes:

```
$ ls -lai .build/release/Clip .build/release/clip-tool
<inode-A>  2100752  .build/release/Clip       # GUI app
<inode-B>   162552  .build/release/clip-tool   # CLI tool
```

## Prevention

1. **Enforce unique, case-insensitive product names.** All SPM executable product names should be distinct when lowercased. Never rely on case alone to differentiate products on macOS.

2. **Post-build binary size check in `verify_release.sh`.** Assert that each expected binary exists and exceeds a minimum size threshold. A silently-overwritten binary will be suspiciously small:

   ```bash
   APP_SIZE=$(stat -f%z ".build/release/Clip")
   if [ "$APP_SIZE" -lt 500000 ]; then
     echo "ERROR: Clip binary too small ($APP_SIZE bytes) — possible collision"
     exit 1
   fi
   ```

3. **DMG content verification before release.** Mount the DMG and check that `Clip.app/Contents/MacOS/Clip` is the GUI binary (not the CLI) by testing its size or attempting a headless launch.

4. **CI on a case-sensitive volume.** Build on a case-sensitive APFS volume to turn silent overwrites into visible two-file outputs — making collisions immediately apparent.

## Related

- [SPM Multi-Target Shared Sources Path](../build-errors/spm-multi-target-shared-sources-path.md) — the Package.swift restructure that introduced the `Clip`/`ClipCLI` split
- [Swift CLI Clipboard DMG Bundling](../best-practice/swift-cli-clipboard-dmg-bundling-20260406.md) — DMG build pipeline docs (updated with `clip-tool` product name)
- [docs/clip-cli.md](../../clip-cli.md) — end-user CLI reference showing the install flow
