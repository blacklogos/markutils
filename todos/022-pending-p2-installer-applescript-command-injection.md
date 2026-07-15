---
name: Command injection into root AppleScript via unescaped bundle path in CLI installer
description: installCLI embeds a POSIX-quoted path into an AppleScript double-quoted string without escaping " or \ — a bundle path containing a quote executes attacker fragments as root
type: todo
status: pending
priority: p2
issue_id: "022"
tags: [code-review, security]
dependencies: []
---

## Problem Statement

`installCLI` builds a shell string and embeds it in `NSAppleScript(source: "do shell script \"…\" with administrator privileges")`. The path goes through `shellQuotedPath` (POSIX single-quote only) but is never escaped for the outer AppleScript double-quoted layer. A bundle path containing `"` or `\` terminates the AppleScript literal early; the remainder runs as root. Low likelihood (attacker must control install location, user must click Install + auth), high impact (root RCE). Pre-existing, not part of the current branch.

## Findings

- `Sources/AppDelegate.swift:408-420`

Reported by: security-sentinel (only P2 in the audit; Diff work itself verified safe including the `</script>` breakout, tested with payloads).

## Proposed Solutions

### Option A — Process with argument array via privileged helper (correct fix)
Replace string-built shell with argument arrays (`Process`) or `SMJobBless` helper. No string interpolation at all.
- Effort: Medium | Risk: Low

### Option B — Escape both layers (quick fix)
After POSIX-quoting, escape for AppleScript: `\` → `\\`, `"` → `\"` on the final script string.
- Effort: Small | Risk: Low, but string-building remains fragile

## Acceptance Criteria
- [ ] Bundle path containing `"` and `\` installs correctly or fails cleanly, never executes injected fragments
- [ ] Install flow still works from /Applications
