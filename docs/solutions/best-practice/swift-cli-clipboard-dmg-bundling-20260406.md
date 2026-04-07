---
title: Swift CLI with Clipboard Flag and DMG Auto-Bundling
slug: swift-cli-clipboard-dmg-bundling
category: best-practice
tags: [swift, cli, clipboard, nspasteboard, dmg, distribution, bash, install]
problem_type: feature-implementation
component: ClipCLI, scripts/build_dmg.sh, scripts/install_cli.sh
symptoms:
  - Need a CLI companion to a macOS app with clipboard read/write support
  - DMG should include both the .app and the CLI binary so users can install the CLI without Xcode
  - Install script must work both from the DMG (using bundled binary) and from source checkout
solved: true
date: 2026-04-06
---

## Problem

The Clip app needed a `clip` CLI tool exposing its transformer pipeline (`md2html`, `html2md`, `md2social`) with an optional `--clipboard` flag to read from and write to the system clipboard in-place. The CLI also needed to be distributed inside the DMG so users could install it without building from source.

## Root Cause

Two gaps:

1. No CLI target existed; NSPasteboard is AppKit-only and needed explicit import in a command-line executable target.
2. `build_dmg.sh` only staged `Clip.app`; users had no path to install the CLI binary without Xcode.

## Solution

### 1. CLI — manual arg parsing + NSPasteboard (Sources/ClipCLI/main.swift)

Avoided adding Swift ArgumentParser (YAGNI for three subcommands). Manual parsing kept the binary small and dependency-free.

```swift
import Foundation
import AppKit  // required for NSPasteboard on a CLI target

func readClipboard() -> String {
    return NSPasteboard.general.string(forType: .string) ?? ""
}
func writeClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

let args = CommandLine.arguments.dropFirst()
let subcommand = args.first ?? ""
var remainingArgs = Array(args.dropFirst())

let useClipboard = remainingArgs.contains("--clipboard") || remainingArgs.contains("-c")
remainingArgs.removeAll { $0 == "--clipboard" || $0 == "-c" }

let input = useClipboard ? readClipboard() : readStdin()

let output: String
switch subcommand {
case "md2html":   output = RichTextTransformer.markdownToHTML(input)
case "html2md":   output = RichTextTransformer.htmlToMarkdown(input)
case "md2social": output = socialTransform(input, args: remainingArgs)
default:
    fputs("Unknown subcommand: \(subcommand)\n", stderr)
    exit(1)
}

if useClipboard {
    writeClipboard(output)
    fputs("Done. Result copied to clipboard.\n", stderr)
} else {
    print(output, terminator: "")
}
```

Exit codes: 0 = success, 1 = unknown subcommand. Progress/error messages go to stderr so stdout stays clean for piping.

### 2. DMG bundling (scripts/build_dmg.sh)

Added a `swift build -c release --product clip-tool` step before DMG staging. The CLI product is named `clip-tool` in Package.swift to avoid a case-insensitive filename collision with the `Clip` app binary on macOS (APFS default). The DMG folder contains:

```
Clip.app
clip                   # raw binary
Install CLI.command    # double-clickable script → calls install_cli.sh
install_cli.sh
```

### 3. Context-detecting install script (scripts/install_cli.sh)

```bash
BINARY_NAME="clip"
INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLED_BINARY="${SCRIPT_DIR}/${BINARY_NAME}"

if [ -f "${BUNDLED_BINARY}" ] && [ -x "${BUNDLED_BINARY}" ]; then
    echo "Using bundled clip binary..."
    BUILT_PATH="${BUNDLED_BINARY}"
else
    echo "Building ${BINARY_NAME} (release)..."
    swift build -c release --product "clip-tool"
    BUILT_PATH=".build/release/clip-tool"
fi

sudo cp "${BUILT_PATH}" "${INSTALL_DIR}/${BINARY_NAME}"
echo "Installed to ${INSTALL_DIR}/${BINARY_NAME}"
```

The `sudo cp` is intentional — `/usr/local/bin` requires root on macOS without custom PATH setup.

## Prevention

- Keep CLI targets dependency-free; manual arg parsing is fine for ≤5 subcommands.
- Always send progress/status to stderr, output to stdout — preserves pipe composability.
- Bundle the pre-built binary in the DMG so the install script never requires Xcode on the end-user machine.
- Use `SCRIPT_DIR` detection (`"$(cd "$(dirname "$0")" && pwd)"`) so install scripts work regardless of cwd.
