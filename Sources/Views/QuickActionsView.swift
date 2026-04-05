import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ClipCore

// Unified Transform tab: paste text → auto-detect type → show action buttons → output with copy + drag.
struct QuickActionsView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var outputMode: OutputMode = .text
    @State private var showCopied = false

    enum OutputMode { case text, htmlPreview }

    enum ContentType: String {
        case markdown = "Markdown"
        case markdownTable = "MD Table"
        case tsv = "TSV / Spreadsheet"
        case csv = "CSV"
        case html = "HTML"
        case plainText = "Plain Text"
    }

    var body: some View {
        VStack(spacing: 0) {
            inputPane
                .frame(maxHeight: .infinity)

            if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                actionBar
            }

            if !output.isEmpty || outputMode == .htmlPreview {
                Divider()
                outputPane
                    .frame(maxHeight: .infinity)
            }

            StatusBarView(text: input, cursorRange: nil)
        }
        .background(AppColors.windowBackground)
    }

    // MARK: - Input Pane

    private var inputPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Input")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let type = detectedType
                    Text(type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor(for: type).opacity(0.15))
                        .foregroundStyle(badgeColor(for: type))
                        .clipShape(Capsule())
                }

                Spacer()

                Button(action: pasteFromClipboard) {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.plain)
                .help("Paste from clipboard")

                Button(action: { input = ""; output = ""; outputMode = .text }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear")
                .disabled(input.isEmpty)
            }
            .padding(8)
            .background(AppColors.toolbarBackground)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)

            TextEditor(text: $input)
                .font(.system(size: 12, design: .monospaced))
                .onChange(of: input) { _, _ in
                    output = ""
                    outputMode = .text
                }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                actionButtons
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(AppColors.toolbarBackground)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .top)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch detectedType {
        case .markdown:
            actionButton("Preview") { outputMode = .htmlPreview }
            actionButton("Copy HTML") {
                let html = RichTextTransformer.markdownToHTML(input)
                copyText(html)
            }
            actionButton("Copy Rich Text") { copyRichText() }

        case .markdownTable:
            actionButton("To CSV") { output = TableTransformer.markdownToCSV(input); outputMode = .text }
            actionButton("To TSV") { output = TableTransformer.markdownToTSV(input); outputMode = .text }
            actionButton("Preview") { outputMode = .htmlPreview }

        case .tsv:
            actionButton("To Markdown Table") { output = TableTransformer.tsvToMarkdown(input); outputMode = .text }
            actionButton("To CSV") { output = tsvToCSV(input); outputMode = .text }
            actionButton("Copy") { copyText(input) }

        case .csv:
            actionButton("To Markdown Table") { output = TableTransformer.csvToMarkdown(input); outputMode = .text }
            actionButton("To TSV") { output = csvToTSV(input); outputMode = .text }
            actionButton("Copy") { copyText(input) }

        case .html:
            actionButton("To Markdown") { output = RichTextTransformer.htmlToMarkdown(input); outputMode = .text }
            actionButton("Copy") { copyText(input) }

        case .plainText:
            actionButton("To Bullet List") { output = toBulletList(input); outputMode = .text }
            actionButton("To Numbered List") { output = toNumberedList(input); outputMode = .text }
            actionButton("Copy") { copyText(input) }
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    // MARK: - Output Pane

    private var outputPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Output")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if outputMode == .htmlPreview {
                    Text("Drag to export rich text")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button(action: copyOutput) {
                    Label(showCopied ? "Copied" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(AppColors.toolbarBackground)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)

            if outputMode == .htmlPreview {
                // 2.1: drag preview to export RTF to other apps
                HTMLPreviewView(htmlContent: RichTextTransformer.markdownToHTML(input))
                    .onDrag { makeRTFProvider() }
            } else {
                TextEditor(text: .constant(output))
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    // MARK: - Content Detection

    private var detectedType: ContentType {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plainText }

        let lines = trimmed.components(separatedBy: .newlines)

        if trimmed.contains("\t") { return .tsv }

        let pipeLines = lines.filter { $0.contains("|") }
        let hasSeparator = lines.contains { line in
            let s = line.filter { !$0.isWhitespace }
            return s.contains("|--") || s.contains("|:-")
        }
        if pipeLines.count >= 2 && hasSeparator { return .markdownTable }

        if trimmed.hasPrefix("<") && trimmed.contains("</") { return .html }

        let hasHeader = lines.contains { $0.hasPrefix("#") }
        let hasBold = trimmed.contains("**")
        let hasList = lines.contains { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
        if hasHeader || hasBold || hasList { return .markdown }

        if trimmed.contains(",") {
            let rows = lines.filter { !$0.isEmpty }
            if rows.count >= 2 {
                let counts = rows.map { $0.components(separatedBy: ",").count }
                if counts.allSatisfy({ $0 == counts[0] }) && counts[0] >= 2 { return .csv }
            }
        }

        return .plainText
    }

    private func badgeColor(for type: ContentType) -> Color {
        switch type {
        case .markdown: return .blue
        case .markdownTable: return .purple
        case .tsv: return .green
        case .csv: return .orange
        case .html: return .red
        case .plainText: return .secondary
        }
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            input = text
        }
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        flash()
    }

    private func copyRichText() {
        let attrStr = RichTextTransformer.markdownToRichText(input)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([attrStr])
        flash()
    }

    private func copyOutput() {
        if outputMode == .htmlPreview {
            copyText(RichTextTransformer.markdownToHTML(input))
        } else {
            copyText(output)
        }
    }

    private func flash() {
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }

    /// Creates an NSItemProvider with RTF (and plain text fallback) for drag-and-drop to rich-text apps.
    private func makeRTFProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        let attrStr = RichTextTransformer.markdownToRichText(input)
        let range = NSRange(location: 0, length: attrStr.length)
        if let rtfData = try? attrStr.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier, visibility: .all) { completion in
                completion(rtfData, nil)
                return nil
            }
        }
        let plainData = input.data(using: .utf8)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
            completion(plainData, nil)
            return nil
        }
        return provider
    }

    // MARK: - Conversion Helpers

    private func toBulletList(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "- " + $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    private func toNumberedList(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { "\($0.offset + 1). \($0.element.trimmingCharacters(in: .whitespaces))" }
            .joined(separator: "\n")
    }

    private func tsvToCSV(_ tsv: String) -> String {
        tsv.components(separatedBy: .newlines).map { line in
            line.components(separatedBy: "\t").map { field in
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return field
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }

    private func csvToTSV(_ csv: String) -> String {
        csv.components(separatedBy: .newlines).map { line in
            var fields: [String] = []
            var current = ""
            var inQuotes = false
            for char in line {
                if char == "\"" {
                    inQuotes.toggle()
                } else if char == "," && !inQuotes {
                    fields.append(current); current = ""
                } else {
                    current.append(char)
                }
            }
            fields.append(current)
            return fields.joined(separator: "\t")
        }.joined(separator: "\n")
    }
}
