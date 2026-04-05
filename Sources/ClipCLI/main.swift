import Foundation
import AppKit
import ClipCore

// clip — command-line interface for Clip's text transformation utilities.
// Reads from stdin by default; --clipboard reads from and writes to the system clipboard.

// MARK: - Usage

func printUsage() {
    fputs("""
    clip — Clip CLI companion

    USAGE: clip <subcommand> [--clipboard]

    SUBCOMMANDS:
      md2html    Markdown → HTML  (stdin → stdout)
      html2md    HTML → Markdown  (stdin → stdout)
      md2social  Markdown → Unicode-styled social text  (stdin → stdout)

    OPTIONS:
      -c, --clipboard  Read from clipboard; write result back to clipboard
      -h, --help       Show this help message

    EXAMPLES:
      echo "# Hello **world**" | clip md2html
      pbpaste | clip md2social | pbcopy
      cat page.html | clip html2md

      clip md2html --clipboard          # transforms clipboard in-place
      clip md2social -c                 # style clipboard text for social media

    NOTES:
      md2social output uses Unicode SMP characters. Requires a UTF-8 terminal.
      html2md strips <html>/<head>/<body> wrappers automatically.

    """, stderr)
}

func printSubcommandHelp(_ sub: String) {
    switch sub {
    case "md2html":
        fputs("clip md2html — Markdown → HTML fragment (no <html>/<head>/<body> wrapper)\n", stderr)
    case "html2md":
        fputs("clip html2md — HTML → Markdown. Full documents supported; <head> is stripped.\n", stderr)
    case "md2social":
        fputs("clip md2social — Markdown → Unicode-styled text for social media platforms.\n", stderr)
    default:
        break
    }
}

// MARK: - I/O helpers

func readStdin() -> String {
    var lines: [String] = []
    while let line = readLine(strippingNewline: false) {
        lines.append(line)
    }
    return lines.joined()
}

func readClipboard() -> String {
    return NSPasteboard.general.string(forType: .string) ?? ""
}

func writeClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

// Strips <html>/<head>/<body> shell from full HTML documents before transforming.
func stripHTMLShell(_ html: String) -> String {
    var s = html
    s = s.replacingOccurrences(of: "<head[^>]*>[\\s\\S]*?</head>",
                                with: "", options: .regularExpression)
    for tag in ["html", "body"] {
        s = s.replacingOccurrences(of: "<\(tag)[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "</\(tag)>", with: "")
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Argument parsing

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

case "md2html", "html2md", "md2social":
    let remainingArgs = Array(args.dropFirst(2))

    if remainingArgs.contains("--help") || remainingArgs.contains("-h") {
        printSubcommandHelp(subcommand)
        exit(0)
    }

    let useClipboard = remainingArgs.contains("--clipboard") || remainingArgs.contains("-c")

    let input = useClipboard ? readClipboard() : readStdin()

    let output: String
    switch subcommand {
    case "md2html":
        output = RichTextTransformer.markdownToHTML(input)
    case "html2md":
        output = RichTextTransformer.htmlToMarkdown(stripHTMLShell(input))
    case "md2social":
        output = UnicodeTextFormatter.markdownToUnicode(input)
    default:
        fatalError("unreachable")
    }

    if useClipboard {
        writeClipboard(output)
        fputs("Done. Result copied to clipboard.\n", stderr)
    } else {
        print(output, terminator: "")
    }

default:
    fputs("clip: unknown subcommand '\(subcommand)'\n", stderr)
    fputs("Run 'clip --help' for usage.\n", stderr)
    exit(1)
}
