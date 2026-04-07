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
      export     Export asset vault as JSON  (stdout or --file)
      import     Import asset vault from JSON  (stdin or --file)

    OPTIONS:
      -c, --clipboard  Read from clipboard; write result back to clipboard
      -f, --file PATH  Read/write to file instead of stdin/stdout (export/import)
      -h, --help       Show this help message

    EXAMPLES:
      echo "# Hello **world**" | clip md2html
      pbpaste | clip md2social | pbcopy

      clip export > ~/backup.json
      clip import < ~/backup.json
      clip export --file ~/Dropbox/clip-backup.json
      clip import --file ~/Dropbox/clip-backup.json

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

// MARK: - Vault helpers

/// Minimal Codable mirror of Asset for validation (no @Observable dependency in CLI target).
struct VaultAsset: Codable {
    let id: UUID
    let creationDate: Date
    let type: String
    let textContent: String?
    let imageData: Data?
    let name: String?
    let children: [VaultAsset]?
}

func vaultFileURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("Clip/assets.json")
}

func fileArgument(_ args: [String]) -> String? {
    for (i, arg) in args.enumerated() {
        if (arg == "--file" || arg == "-f"), i + 1 < args.count {
            return args[i + 1]
        }
    }
    return nil
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

case "export":
    let remainingArgs = Array(args.dropFirst(2))
    let vaultURL = vaultFileURL()

    guard FileManager.default.fileExists(atPath: vaultURL.path) else {
        fputs("clip: vault is empty (no assets.json found)\n", stderr)
        exit(1)
    }

    let data = try! Data(contentsOf: vaultURL)

    // Pretty-print: decode then re-encode with formatting
    if let assets = try? JSONDecoder().decode([VaultAsset].self, from: data) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let pretty = try! encoder.encode(assets)
        let jsonString = String(data: pretty, encoding: .utf8)!

        if let filePath = fileArgument(remainingArgs) {
            try! jsonString.write(toFile: filePath, atomically: true, encoding: .utf8)
            fputs("Exported \(assets.count) assets to \(filePath)\n", stderr)
        } else {
            print(jsonString, terminator: "")
        }
    } else {
        // Fallback: output raw data
        if let filePath = fileArgument(remainingArgs) {
            try! data.write(to: URL(fileURLWithPath: filePath))
            fputs("Exported vault to \(filePath)\n", stderr)
        } else {
            FileHandle.standardOutput.write(data)
        }
    }

case "import":
    let remainingArgs = Array(args.dropFirst(2))

    let inputData: Data
    if let filePath = fileArgument(remainingArgs) {
        guard FileManager.default.fileExists(atPath: filePath) else {
            fputs("clip: file not found: \(filePath)\n", stderr)
            exit(2)
        }
        inputData = try! Data(contentsOf: URL(fileURLWithPath: filePath))
    } else {
        inputData = FileHandle.standardInput.readDataToEndOfFile()
    }

    // Validate JSON
    guard let _ = try? JSONDecoder().decode([VaultAsset].self, from: inputData) else {
        fputs("clip: invalid vault JSON\n", stderr)
        exit(2)
    }

    let vaultURL = vaultFileURL()
    let vaultDir = vaultURL.deletingLastPathComponent()
    try! FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)
    try! inputData.write(to: vaultURL)
    fputs("Vault imported successfully.\n", stderr)

default:
    fputs("clip: unknown subcommand '\(subcommand)'\n", stderr)
    fputs("Run 'clip --help' for usage.\n", stderr)
    exit(1)
}
