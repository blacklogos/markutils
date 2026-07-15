import Foundation
import CryptoKit
import ClipCore

// Handlers for the style, unstyle, table, and comments subcommands.
// Dispatch lives in main.swift; each handler receives the args after the
// subcommand name and follows the existing conventions: stdin to stdout,
// -c/--clipboard round-trip, errors to stderr, exit 1 for usage errors,
// exit 2 for file errors.

// MARK: - Shared output

func emitResult(_ output: String, toClipboard: Bool) {
    if toClipboard {
        writeClipboard(output)
        fputs("Done. Result copied to clipboard.\n", stderr)
    } else {
        print(output, terminator: "")
    }
}

// MARK: - clip style / unstyle

private let styleByName: [String: UnicodeTextFormatter.Style] = [
    "bold": .bold,
    "italic": .italic,
    "bold-italic": .boldItalic,
    "mono": .monospace,
    "script": .script,
    "small-caps": .smallCaps,
    "underline": .underline,
    "strike": .strikethrough,
]

func runStyle(_ args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printSubcommandHelp("style")
        exit(0)
    }
    guard let name = args.first(where: { !$0.hasPrefix("-") }), let style = styleByName[name] else {
        fputs("clip style: provide a style: \(styleByName.keys.sorted().joined(separator: ", "))\n", stderr)
        exit(1)
    }
    let natural = args.contains("--natural") || args.contains("-n")
    let useClipboard = args.contains("--clipboard") || args.contains("-c")
    let input = useClipboard ? readClipboard() : readStdin()
    let output = UnicodeTextFormatter.apply(style, to: input, mode: natural ? .natural : .accent)
    emitResult(output, toClipboard: useClipboard)
}

func runUnstyle(_ args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printSubcommandHelp("unstyle")
        exit(0)
    }
    let useClipboard = args.contains("--clipboard") || args.contains("-c")
    let input = useClipboard ? readClipboard() : readStdin()
    emitResult(UnicodeTextFormatter.revertToPlain(input), toClipboard: useClipboard)
}

// MARK: - clip table

func runTable(_ args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printSubcommandHelp("table")
        exit(0)
    }
    func flagValue(_ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    let fromFormats = ["md", "csv", "tsv"]
    let toFormats = ["md", "csv", "tsv", "ascii"]
    guard let from = flagValue("--from"), fromFormats.contains(from),
          let to = flagValue("--to"), toFormats.contains(to) else {
        fputs("clip table: requires --from <md|csv|tsv> and --to <md|csv|tsv|ascii>\n", stderr)
        exit(1)
    }
    guard from != to else {
        fputs("clip table: --from and --to are the same format (\(from))\n", stderr)
        exit(1)
    }

    let useClipboard = args.contains("--clipboard") || args.contains("-c")
    let input = useClipboard ? readClipboard() : readStdin()

    let output: String
    switch (from, to) {
    case ("md", "csv"):    output = TableTransformer.markdownToCSV(input)
    case ("md", "tsv"):    output = TableTransformer.markdownToTSV(input)
    case ("md", "ascii"):  output = UnicodeTextFormatter.markdownTableToASCII(input)
    case ("csv", "md"):    output = TableTransformer.csvToMarkdown(input)
    case ("csv", "tsv"):   output = TableTransformer.csvToTSV(input)
    case ("csv", "ascii"): output = UnicodeTextFormatter.markdownTableToASCII(TableTransformer.csvToMarkdown(input))
    case ("tsv", "md"):    output = TableTransformer.tsvToMarkdown(input)
    case ("tsv", "csv"):   output = TableTransformer.tsvToCSV(input)
    case ("tsv", "ascii"): output = UnicodeTextFormatter.markdownTableToASCII(TableTransformer.tsvToMarkdown(input))
    default:
        fatalError("unreachable")
    }
    emitResult(output, toClipboard: useClipboard)
}

// MARK: - clip comments

/// Sidecar location must match CommentStore: SHA-256 hex of the symlink-resolved
/// path, stored at ~/Library/Application Support/Clip/comments/<key>.json.
func commentSidecarURL(for fileURL: URL) -> URL {
    let path = fileURL.resolvingSymlinksInPath().path
    let key = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("Clip/comments/\(key).json")
}

func runComments(_ args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printSubcommandHelp("comments")
        exit(0)
    }
    let positional = args.filter { !$0.hasPrefix("-") }
    guard positional.count == 2, ["list", "export"].contains(positional[0]) else {
        fputs("clip comments: usage: clip comments <list|export> <file.md>\n", stderr)
        exit(1)
    }
    let action = positional[0]
    let filePath = positional[1]
    let fileURL = URL(fileURLWithPath: filePath)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        fputs("clip comments: file not found: \(filePath)\n", stderr)
        exit(2)
    }
    let sidecarURL = commentSidecarURL(for: fileURL)
    guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
        fputs("clip comments: no comments found for \(filePath)\n", stderr)
        exit(1)
    }

    let sidecarData: Data
    do {
        sidecarData = try Data(contentsOf: sidecarURL)
    } catch {
        fputs("clip comments: cannot read sidecar: \(error.localizedDescription)\n", stderr)
        exit(2)
    }

    switch action {
    case "list":
        print(String(data: sidecarData, encoding: .utf8) ?? "", terminator: "")

    case "export":
        guard let comments = try? JSONDecoder().decode([Comment].self, from: sidecarData) else {
            fputs("clip comments: cannot parse sidecar JSON for \(filePath)\n", stderr)
            exit(2)
        }
        let text: String
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            fputs("clip comments: cannot read \(filePath): \(error.localizedDescription)\n", stderr)
            exit(2)
        }
        print(CommentInstructionCompiler.wholeFile(comments: comments, in: text))

    default:
        fatalError("unreachable")
    }
}
