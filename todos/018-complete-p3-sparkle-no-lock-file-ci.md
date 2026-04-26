---
name: Sparkle SPM dependency not lock-file enforced in CI (PR #13)
description: Package.swift uses minimum-version constraint; a compromised Sparkle 2.x tag would be pulled silently on next swift package update
type: todo
status: pending
priority: p3
issue_id: "018"
tags: [code-review, security]
dependencies: []
---

## Problem Statement

`Package.swift` pins Sparkle as `from: "2.6.0"`, resolving the minimum compatible version at build time. `Package.resolved` exists (added in PR #13) but there is no CI step that fails when `Package.resolved` changes unexpectedly (i.e., no lock-file enforcement). A Sparkle compromise pushing a new `2.x` tag would be pulled silently on the next `swift package update`.

**Known issue from institutional memory:** `docs/solutions/build-errors/sparkle-framework-rpath-dyld-library-not-loaded-20260409.md` documents that after updating Sparkle, `build_dmg.sh` must re-run `install_name_tool -add_rpath` — meaning a silent Sparkle version bump can also silently break the release build.

## Findings

**File:** `Package.swift` line 15
**File:** `Package.resolved` — present but not enforced in CI

Reported by security-sentinel and learnings-researcher.

## Proposed Solutions

### Option A — Add CI check for Package.resolved drift
In `scripts/verify_release.sh`, add:
```bash
# Fail if Package.resolved has uncommitted changes after resolve
swift package resolve
git diff --exit-code Package.resolved || (echo "Package.resolved drift detected" && exit 1)
```
- Pros: Simple; catches silent updates
- Effort: Small | Risk: Low

### Option B — Pin to exact revision in Package.swift
```swift
.package(url: "...", exact: "2.9.1")
```
- Pros: Zero drift possible
- Cons: Must manually bump for security fixes
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] CI fails if `Package.resolved` changes without being committed
- [ ] `scripts/verify_release.sh` checks for Package.resolved drift

## Work Log
- 2026-04-26: Identified by security-sentinel and learnings-researcher during PR #13 review
