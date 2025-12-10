# AI Agent & Developer Rules

**CRITICAL INSTRUCTIONS FOR ALL AI AGENTS**

This project follows the **Safe Development Standards** (see `.agent/workflows/safe-development.md`).
You **MUST** follow these rules without exception.

## 1. Regression Testing is MANDATORY
Before marking ANY task as complete, you must run the regression verification script:

```bash
./scripts/verify_release.sh
```

- **If it fails**: You MUST fix the issues before proceeding.
- **If it passes**: You may proceed.

## 2. Protect Core Functionality
The following features are critical. You must explicitly verify they are still working:
- **Drag and Drop**: Users must be able to drag images/files into the app.
- **App Launch**: The app must launch without crashing.

## 3. Environment Awareness (macOS/iOS)
- **Do NOT** assume `XCTest` UI testing is available if running on CommandLineTools.
- Rely on **Logic Tests** (Unit Tests) that validate behavior independent of the UI layer.

---
*Follow the "Do Not Break" Protocol.*
