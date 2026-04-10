---
title: "Sparkle.framework dyld 'Library not loaded' — missing @rpath in SPM-built binary"
category: build-errors
date: 2026-04-09
tags: [sparkle, dyld, rpath, framework-bundling, spm, codesign, macos]
component: scripts/build_dmg.sh, Package.swift
related:
  - docs/solutions/best-practice/cloudflare-pages-direct-upload-wrangler-20260408.md
  - docs/solutions/best-practice/swift-cli-target-isolation-observable-pattern-20260408.md
  - docs/solutions/build-errors/spm-product-name-collision-case-insensitive-apfs-20260407.md
---

## Problem

After adding Sparkle as an SPM dependency, building the DMG, and installing `Clip.app`, the app refused to launch with:

```
dyld[52876]: Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle
  Referenced from: /Applications/Clip.app/Contents/MacOS/Clip
  Reason: tried: '/usr/lib/swift/Sparkle.framework/...' (no such file)
```

The `Sparkle.framework` was correctly copied into `Clip.app/Contents/Frameworks/` and code-signed. The binary simply couldn't find it.

## Root Cause

When `swift build -c release` links against Sparkle's XCFramework binary target, it embeds `@rpath/Sparkle.framework/Versions/B/Sparkle` as the framework's install name in the Mach-O binary. However, SPM's default rpaths for an executable target are:

```
/usr/lib/swift
@loader_path
/Applications/Xcode.app/.../swift-6.2/macosx
```

None of these include `@executable_path/../Frameworks`, which is where macOS app bundles conventionally store embedded frameworks. Since `build_dmg.sh` hand-rolls the `.app` bundle (no Xcode project), the rpath is never set automatically.

## Solution

Add `install_name_tool -add_rpath` to `build_dmg.sh` **after** copying the binary but **before** code-signing:

```bash
# 5. Fix rpath so the binary finds Sparkle.framework at runtime
install_name_tool -add_rpath @executable_path/../Frameworks \
    "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# 6. Ad-hoc Signing — sign framework FIRST, then outer bundle
codesign --force --deep --sign - \
    "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework" 2>/dev/null
codesign --force --deep --sign - "${APP_BUNDLE}"
```

Verification:

```bash
otool -l Clip.app/Contents/MacOS/Clip | grep -A2 LC_RPATH
# Should include: path @executable_path/../Frameworks
```

### Why order matters

1. `install_name_tool` modifies the Mach-O binary, invalidating any existing signature
2. `codesign` must run after all binary modifications
3. The inner framework must be signed before the outer bundle (nested code signing)

## Prevention

1. **Always verify rpaths after adding a new framework dependency:**
   ```bash
   otool -l .build/release/Clip | grep -A2 LC_RPATH | grep Frameworks
   ```
   If `@executable_path/../Frameworks` is missing, add the `install_name_tool` step.

2. **Test the app bundle directly before creating the DMG:**
   ```bash
   ./Clip.app/Contents/MacOS/Clip
   ```
   A dyld error here catches the problem before packaging.

3. **This applies to ANY XCFramework binary target added via SPM** when building outside Xcode. Xcode projects set this rpath automatically; `swift build` does not.
