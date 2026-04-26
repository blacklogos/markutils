---
name: Shell injection via AppleScript CLI installer
description: String interpolation of bundle path into privileged shell command — attacker-controlled path escapes single-quote quoting
type: todo
status: pending
priority: p1
issue_id: "001"
tags: [code-review, security]
dependencies: []
---

## Problem Statement

`AppDelegate.installCLITool()` builds a shell command by interpolating `sourcePath` (derived from `Bundle.main.path`) into an AppleScript string executed with administrator privileges. If `sourcePath` contains a single-quote or shell metacharacter (e.g., via a symlink attack or unusual install location), an attacker can escape the quoting and inject arbitrary commands run as root.

## Findings

**File:** `Sources/AppDelegate.swift` ~line 368

```swift
let script = "mkdir -p /usr/local/bin && cp '\(sourcePath)' '\(dest)' && chmod +x '\(dest)' && xattr -rd com.apple.quarantine '\(dest)'"
let appleScript = NSAppleScript(source: "do shell script \"\(script)\" with administrator privileges")
```

Pattern is structurally unsafe regardless of today's exploitation realism: arbitrary string interpolation into a privileged shell command. Reported by security-sentinel.

## Proposed Solutions

### Option A — Use Process + SMJobBless helper (Recommended)
Replace the AppleScript shell string with a `Process` that takes an explicit argument array. Use `SMJobBless` or `AuthorizationExecuteWithPrivileges` for privilege elevation.
- Pros: No shell injection surface; macOS-idiomatic pattern for privileged helpers
- Cons: More boilerplate; SMJobBless requires a separate helper bundle
- Effort: Large | Risk: Low

### Option B — Shell-escape the path before interpolation
Use `ProcessInfo.processInfo.arguments` style quoting: percent-encode or `shellescape()` the path before embedding.
- Pros: Minimal change; quick fix
- Cons: Custom escaping is error-prone; still using privileged AppleScript shell
- Effort: Small | Risk: Medium

### Option C — Remove in-app CLI install, document manual install
Remove the installer entirely; document `cp` command in README.
- Pros: Zero attack surface; simplest
- Cons: Degrades UX for CLI users
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] No user-controlled string is interpolated into a shell command
- [ ] Privileged operation uses argument array, not shell string
- [ ] Unit test or manual verification: path with single-quote in bundle location does not execute injected command

## Work Log
- 2026-04-26: Identified by security-sentinel during PR #15 review
