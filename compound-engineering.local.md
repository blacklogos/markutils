---
review_agents:
  - compound-engineering:review:security-sentinel
  - compound-engineering:review:performance-oracle
  - compound-engineering:review:architecture-strategist
  - compound-engineering:review:code-simplicity-reviewer
---

# Review Context

This is a macOS menu bar app (Clip) built with Swift 5.9, SwiftUI + AppKit hybrid, targeting macOS 14+.
No third-party dependencies except Sparkle for auto-update and WebKit for preview.
Data persisted as JSON files in ~/Library/Application Support/Clip/.
No database, no network except update checks.
