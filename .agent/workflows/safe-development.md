---
description: Safe Development Standards for macOS/iOS & Functional Apps
---

# Safe Development Standards (The "Do Not Break" Protocol)

This workflow defines the **MANDATORY** standards for AI agents (Antigravity, Droid Factory.ai, Claude Code) when working on ANY functional application (macOS, iOS, Web, etc.).

## 1. The Prime Directive: Non-Regression
**"Do not commit crimes against humanity"** -> **Do not break existing functionality.**

Before applying ANY changes, you must:
1.  **Identify Core Loops**: Know what the app *does*. (e.g., "It saves files when dropped", "It opens when clicked").
2.  **Protect Them**: Never refactor core logic without a verification plan.

## 2. Testing Protocol (macOS/iOS Specifics)
When working in Apple environments:
- **Check the Environment**: Run `xcrun --show-sdk-path`. If it points to `CommandLineTools`, **XCTest UI Tests will NOT work**.
  - *Action*: Adapt strategy to use **Unit Tests** or **Logic Tests** that don't require the Simulator.
- **Simulator Awareness**: If the user has a full Xcode setup, prioritize E2E (End-to-End) tests.

## 3. Deployment Checklist
Before marking a task as "Done":
- [ ] **Build Check**: Does the project still compile? (`swift build`, `xcodebuild`)
- [ ] **Regression Check**: Did you run the project's verification script (e.g., `./scripts/verify_release.sh`)?
- [ ] **Launch Check**: If you touched startup code, have you verified the app actually opens?

## 4. Implementation Rules
1.  **New Feature = New Test**: Never add code without a way to verify it.
2.  **No "Blind" Refactoring**: Do not delete "dead code" unless you are 100% sure it is unused.
3.  **Error Handling**: Crash-proof your code. Use `guard let` and `do-catch` blocks aggressively. Unhandled exceptions are unacceptable.

## 5. User Communication
- If a requested feature *might* break existing functionality, **WARN THE USER** first.
- Always provide a "Verification Plan" in your implementation design.
