# Phase 03 — CLI Commands

**Status:** pending  
**Parent:** [plan.md](plan.md)

---

## Context Links

- `Sources/ClipCore/RichTextTransformer.swift` (after Phase 02)
- `Sources/ClipCore/UnicodeTextFormatter.swift` (after Phase 02)
- `Sources/ClipCLI/main.swift` (new file)

---

## Overview

Implement `main.swift` for the `clip` CLI binary. Three subcommands, no third-party dependencies, manual arg parsing (KISS — 3 commands don't justify adding Swift ArgumentParser).

---

## Key Insights

1. Swift ArgumentParser adds a dependency and ~500KB to binary. Manual parsing for 3 fixed subcommands is ~40 lines. YAGNI.
2. All three commands are stdin → stdout pipelines. This is the Unix contract — honor it completely.
3. `RichTextTransformer.markdownToHTML` and `htmlToMarkdown` are the exact methods needed. No wrapping logic.
4. `UnicodeTextFormatter.markdownToUnicode` is the exact method for `md2social`. No wrapping logic.
5. Exit code contract: 0 = success, 1 = usage error, 2 = transform error (e.g., empty input treated as passthrough, not error).

---

## Requirements

- Binary name: `clip`
- Three subcommands: `md2html`, `html2md`, `md2social`
- All read from stdin, write to stdout
- Errors go to stderr
- Exit 1 on bad subcommand or `--help`/`-h`
- Exit 0 on successful transform (including empty input — outputs empty string)
- No file input/output flags for now (YAGNI — pipe via shell redirection)

---

## Architecture

### Command Interface

```
clip <subcommand> [--help]

Subcommands:
  md2html     Read Markdown from stdin, write HTML to stdout
  html2md     Read HTML from stdin, write Markdown to stdout
  md2social   Read Markdown from stdin, write Unicode-styled text to stdout

Options:
  --help, -h  Show help for a subcommand or overall usage

Examples:
  echo "# Hello" | clip md2html
  pbpaste | clip md2social | pbcopy
  cat page.html | clip html2md
```

### main.swift skeleton

```swift
import Foundation
import ClipCore

func printUsage() {
    fputs("""
    clip — Clip CLI companion

    USAGE: clip <subcommand>

    SUBCOMMANDS:
      md2html    Markdown → HTML  (stdin → stdout)
      html2md    HTML → Markdown  (stdin → stdout)
      md2social  Markdown → Unicode-styled social text  (stdin → stdout)

    OPTIONS:
      -h, --help  Show this help message

    EXAMPLES:
      echo "# Hello **world**" | clip md2html
      pbpaste | clip md2social | pbcopy
      cat page.html | clip html2md
    """, stderr)
}

func readStdin() -> String {
    var lines: [String] = []
    while let line = readLine(strippingNewline: false) {
        lines.append(line)
    }
    return lines.joined()
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    printUsage()
    exit(1)
}

let subcommand = args[1]

switch subcommand {
case "--help", "-h":
    printUsage()
    exit(0)

case "md2html":
    if args.count > 2 && (args[2] == "--help" || args[2] == "-h") {
        fputs("clip md2html — Read Markdown from stdin, output HTML to stdout\n", stderr)
        exit(0)
    }
    let input = readStdin()
    print(RichTextTransformer.markdownToHTML(input), terminator: "")

case "html2md":
    if args.count > 2 && (args[2] == "--help" || args[2] == "-h") {
        fputs("clip html2md — Read HTML from stdin, output Markdown to stdout\n", stderr)
        exit(0)
    }
    let input = readStdin()
    // Strip outer <html>/<head>/<body> wrapper if present before processing
    let cleaned = stripHTMLShell(input)
    print(RichTextTransformer.htmlToMarkdown(cleaned), terminator: "")

case "md2social":
    if args.count > 2 && (args[2] == "--help" || args[2] == "-h") {
        fputs("clip md2social — Read Markdown from stdin, output Unicode-styled text to stdout\n", stderr)
        exit(0)
    }
    let input = readStdin()
    print(UnicodeTextFormatter.markdownToUnicode(input), terminator: "")

default:
    fputs("clip: unknown subcommand '\(subcommand)'\n", stderr)
    fputs("Run 'clip --help' for usage.\n", stderr)
    exit(1)
}
```

### `stripHTMLShell` helper (in main.swift)

Strips `<html>`, `<head>...</head>`, `<body>` wrapper tags that full HTML documents contain but `htmlToMarkdown` does not handle.

```swift
private func stripHTMLShell(_ html: String) -> String {
    var s = html
    // Remove <head>...</head> block (including scripts/styles)
    s = s.replacingOccurrences(of: "<head[^>]*>[\\s\\S]*?</head>",
                                with: "", options: .regularExpression)
    // Remove outer structural tags
    for tag in ["html", "body"] {
        s = s.replacingOccurrences(of: "<\(tag)[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "</\(tag)>", with: "")
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

---

## Command Details

### `md2html`

| Aspect | Detail |
|--------|--------|
| Input | Markdown via stdin |
| Output | HTML fragment (no `<html>/<head>/<body>` wrapper) to stdout |
| Method | `RichTextTransformer.markdownToHTML(_:)` |
| Empty input | Outputs empty string, exits 0 |
| Trailing newline | `print(..., terminator: "")` — caller controls newlines |

Edge cases:
- Input is already HTML: `markdownToHTML` passes non-markdown through mostly intact (it wraps bare text in `<p>` tags). Document this in `--help`.
- Very large input (>10MB): no special handling — Foundation handles it; streaming not needed for CLI content-creation use case.

### `html2md`

| Aspect | Detail |
|--------|--------|
| Input | HTML (fragment or full document) via stdin |
| Output | Markdown to stdout |
| Method | `RichTextTransformer.htmlToMarkdown(_:)` |
| Pre-processing | `stripHTMLShell` removes `<html>/<head>/<body>` before passing to transformer |
| Empty input | Outputs empty string, exits 0 |

Edge cases:
- Nested `<ul>/<ol>` (current transformer doesn't handle ordered lists — document limitation).
- `<table>` tags: **fix in Phase 02** — extend `htmlToMarkdown` in `RichTextTransformer` to convert `<table>/<thead>/<tbody>/<tr>/<th>/<td>` → markdown table syntax (`| col | col |` with `| --- | --- |` separator).

### `md2social`

| Aspect | Detail |
|--------|--------|
| Input | Markdown via stdin |
| Output | Unicode-styled plain text to stdout |
| Method | `UnicodeTextFormatter.markdownToUnicode(_:)` |
| Empty input | Outputs empty string, exits 0 |

Edge cases:
- Output contains Unicode SMP characters (U+1D400 range). Terminal must support UTF-8. If not, characters may display as `?`. Not a bug — document it.
- Copy-paste to non-Unicode apps: user responsibility.

---

## Related Code Files

- `Sources/ClipCore/RichTextTransformer.swift` — `markdownToHTML`, `htmlToMarkdown`
- `Sources/ClipCore/UnicodeTextFormatter.swift` — `markdownToUnicode`
- `Sources/ClipCLI/main.swift` — new file (full implementation above)

---

## Implementation Steps

1. Create `Sources/ClipCLI/main.swift` with content above.
2. Ensure `ClipCLI` target in Package.swift depends on `ClipCore`.
3. Run `swift build` — verify `clip` binary appears in `.build/debug/clip`.
4. Manual smoke tests:
   - `echo "# Hello" | .build/debug/clip md2html` → `<h1 id="hello">Hello</h1>`
   - `echo "<h1>Hello</h1>" | .build/debug/clip html2md` → `# Hello`
   - `echo "**bold text**" | .build/debug/clip md2social` → Unicode bold output
   - `.build/debug/clip` (no args) → usage on stderr, exit 1
   - `.build/debug/clip unknowncmd` → error on stderr, exit 1
5. Run `./scripts/verify_release.sh`.

---

## Todo

- [ ] Create `Sources/ClipCLI/main.swift`
- [ ] Smoke test all 3 commands
- [ ] Smoke test error paths (no args, bad subcommand)
- [ ] Verify exit codes: `echo "# x" | clip md2html; echo $?` → 0
- [ ] Verify stderr vs stdout separation: `clip 2>/dev/null` on error shows nothing on stdout

---

## Success Criteria

- All 3 commands produce correct output matching what the GUI app produces.
- Piping works: `pbpaste | clip md2social | pbcopy` succeeds on macOS.
- Unknown subcommand exits 1, not 0.
- No AppKit import anywhere in `ClipCLI`.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `readLine` blocks if no stdin piped (interactive TTY) | Low | Standard behavior — same as `cat`. Document that commands expect piped input. |
| `htmlToMarkdown` table limitation | High (known) | Document as limitation in --help output |
| Unicode output garbled in some terminals | Low | UTF-8 terminals are standard on macOS; document requirement |

---

## Security Considerations

- CLI processes stdin only — no file system writes, no network calls.
- No shell expansion of input content.
- Regex in transformer uses `NSRegularExpression` — catastrophic backtracking is possible on adversarial input, but CLI is a local tool (not a server). Acceptable risk.

---

## Next Steps

Proceed to Phase 04 (install + docs) once CLI commands pass smoke tests.
