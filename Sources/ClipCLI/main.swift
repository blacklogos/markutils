import Foundation
import AppKit
import ClipCore

// clip — command-line interface for Clip's text transformation utilities.
// Reads from stdin by default; --clipboard reads from and writes to the system clipboard.

// MARK: - Usage

func printUsage() {
    fputs("""
    clip — Clip CLI companion

    USAGE: clip <subcommand> [options]

    SUBCOMMANDS:
      md2html    Markdown → HTML  (stdin → stdout)
      html2md    HTML → Markdown  (stdin → stdout)
      md2social  Markdown → Unicode-styled social text  (stdin → stdout)
      export     Export asset vault as JSON  (stdout or --file)
      import     Import asset vault from JSON  (stdin or --file)
      search     Search asset vault by name/content
      notes      Manage daily notes

    OPTIONS:
      -c, --clipboard  Read from clipboard; write result back to clipboard
      -f, --file PATH  Read/write to file instead of stdin/stdout (export/import)
      -h, --help       Show this help message

    EXAMPLES:
      echo "# Hello **world**" | clip md2html
      pbpaste | clip md2social | pbcopy

      clip export > ~/backup.json
      clip import < ~/backup.json
      clip search "meeting notes"

      clip notes today              # print today's note
      clip notes today --set "..."  # replace today's note body
      clip notes list               # JSON array of all notes
      clip notes search <query>     # matching notes as JSON
      clip notes export <id>        # stdout the note body
      clip notes delete <id>        # delete by UUID

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
    let fileFormat: String?
}

func vaultFileURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("Clip/assets.json")
}

// MARK: - Notes helpers

/// Minimal Codable mirror of Note (no @Observable dependency in CLI target).
struct VaultNote: Codable {
    var id: UUID
    var body: String
    var date: Date
    var updatedAt: Date
}

func notesFileURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("Clip/notes.json")
}

func loadNotes() -> [VaultNote] {
    let url = notesFileURL()
    guard FileManager.default.fileExists(atPath: url.path),
          let data = try? Data(contentsOf: url),
          let notes = try? JSONDecoder().decode([VaultNote].self, from: data) else { return [] }
    return notes
}

func saveNotes(_ notes: [VaultNote]) {
    let url = notesFileURL()
    let dir = url.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(notes) {
        try? data.write(to: url)
    }
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

case "search":
    let remainingArgs = Array(args.dropFirst(2))
    let query = remainingArgs.filter { !$0.hasPrefix("-") }.joined(separator: " ").lowercased()
    guard !query.isEmpty else {
        fputs("clip search: provide a search query\n", stderr)
        exit(1)
    }
    let vaultURL = vaultFileURL()
    guard FileManager.default.fileExists(atPath: vaultURL.path),
          let data = try? Data(contentsOf: vaultURL),
          let assets = try? JSONDecoder().decode([VaultAsset].self, from: data) else {
        fputs("clip: vault is empty\n", stderr)
        exit(1)
    }
    func searchAssets(_ list: [VaultAsset]) -> [VaultAsset] {
        var results: [VaultAsset] = []
        for asset in list {
            let nameMatch = asset.name?.lowercased().contains(query) ?? false
            let contentMatch = asset.textContent?.lowercased().contains(query) ?? false
            if nameMatch || contentMatch {
                results.append(asset)
            } else if let children = asset.children {
                results += searchAssets(children)
            }
        }
        return results
    }
    let matches = searchAssets(assets)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let out = try? encoder.encode(matches) {
        print(String(data: out, encoding: .utf8)!, terminator: "")
    }

case "notes":
    let notesArgs = Array(args.dropFirst(2))
    let notesSubcommand = notesArgs.first ?? ""

    switch notesSubcommand {
    case "today":
        var notes = loadNotes()
        let calendar = Calendar.current
        if let setIdx = notesArgs.firstIndex(of: "--set"), setIdx + 1 < notesArgs.count {
            // Write mode: replace today's note body
            let newBody = notesArgs[setIdx + 1]
            if let idx = notes.firstIndex(where: { calendar.isDateInToday($0.date) }) {
                notes[idx].body = newBody
                notes[idx].updatedAt = Date()
            } else {
                notes.append(VaultNote(id: UUID(), body: newBody, date: Date(), updatedAt: Date()))
            }
            saveNotes(notes)
            fputs("Today's note updated.\n", stderr)
        } else {
            // Read mode
            if let note = notes.first(where: { calendar.isDateInToday($0.date) }) {
                print(note.body, terminator: "")
            } else {
                print("", terminator: "")
            }
        }

    case "list":
        let notes = loadNotes()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let out = try? encoder.encode(notes.map { ["id": $0.id.uuidString, "date": ISO8601DateFormatter().string(from: $0.date), "preview": String($0.body.prefix(80))] }) {
            print(String(data: out, encoding: .utf8)!, terminator: "")
        }

    case "search":
        let query = notesArgs.dropFirst().filter { !$0.hasPrefix("-") }.joined(separator: " ").lowercased()
        guard !query.isEmpty else {
            fputs("clip notes search: provide a query\n", stderr)
            exit(1)
        }
        let matches = loadNotes().filter {
            $0.body.lowercased().contains(query)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let out = try? encoder.encode(matches) {
            print(String(data: out, encoding: .utf8)!, terminator: "")
        }

    case "export":
        let idStr = notesArgs.dropFirst().first ?? ""
        let notes = loadNotes()
        if idStr.isEmpty {
            // Export all notes as concatenated markdown
            let out = notes.map { "# \(ISO8601DateFormatter().string(from: $0.date))\n\n\($0.body)" }.joined(separator: "\n\n---\n\n")
            print(out, terminator: "")
        } else if let uuid = UUID(uuidString: idStr), let note = notes.first(where: { $0.id == uuid }) {
            print(note.body, terminator: "")
        } else {
            fputs("clip notes export: note not found\n", stderr)
            exit(2)
        }

    case "delete":
        let idStr = notesArgs.dropFirst().first ?? ""
        guard let uuid = UUID(uuidString: idStr) else {
            fputs("clip notes delete: provide a valid UUID\n", stderr)
            exit(1)
        }
        var notes = loadNotes()
        let before = notes.count
        notes.removeAll { $0.id == uuid }
        if notes.count < before {
            saveNotes(notes)
            fputs("Note deleted.\n", stderr)
        } else {
            fputs("clip notes delete: note not found\n", stderr)
            exit(2)
        }

    default:
        fputs("""
        clip notes — daily note management

        USAGE: clip notes <subcommand>

        SUBCOMMANDS:
          today               Print today's note body
          today --set "..."   Replace today's note body
          list                List all notes (JSON)
          search <query>      Search notes (JSON)
          export [<id>]       Export note body (all notes if no id)
          delete <id>         Delete note by UUID

        """, stderr)
        exit(notesSubcommand.isEmpty ? 0 : 1)
    }

default:
    fputs("clip: unknown subcommand '\(subcommand)'\n", stderr)
    fputs("Run 'clip --help' for usage.\n", stderr)
    exit(1)
}
