
import SwiftUI
import AppKit
import ClipCore

struct SocialMediaFormatterView: View {
    @Binding var text: String
    @State private var footer: String = "Lau1k © 2025"
    @State private var editor: NSTextView?
    @State private var selectedMode: Int = 0  // 0 = Format, 1 = Convert
    @State private var cursorRange: NSRange? = nil

    // History stacks (used by Convert mode full-text replacements)
    @State private var undoStack: [String] = []
    @State private var redoStack: [String] = []

    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Single toolbar row ────────────────────────────────────────
            HStack(spacing: 6) {
                // Format | Convert picker
                Picker("", selection: $selectedMode) {
                    Text("Format").tag(0)
                    Text("Convert").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Divider().frame(height: 20)

                if selectedMode == 0 {
                    // ── Format mode: primary actions ──
                    Group {
                        Button(action: { transformSelection { UnicodeTextFormatter.apply(.bold, to: $0) } })    { Text("𝐁") }
                        Button(action: { transformSelection { UnicodeTextFormatter.apply(.italic, to: $0) } })  { Text("𝘐") }
                        Button(action: { transformSelection { $0.uppercased() } })  { Text("ABC") }
                        Button(action: { transformSelection { $0.capitalized } })   { Text("Abc") }
                    }
                    .buttonStyle(ToolbarButtonStyle())

                    Divider().frame(height: 20)

                    Group {
                        Button(action: { addBulletList("•") })   { Text("•") }
                        Button(action: { addBulletList("✅") })  { Text("✅") }
                        Button(action: addNumberedList)          { Text("1.") }
                        Button(action: addSeparator)             { Text("———") }
                    }
                    .buttonStyle(ToolbarButtonStyle())

                    Spacer()

                    // Overflow menu for less-common actions
                    Menu {
                        Section("Bullets") {
                            Button("🔸") { addBulletList("🔸") }
                            Button("⭐️") { addBulletList("⭐️") }
                            Button("🔹") { addBulletList("🔹") }
                            Button("— (dash)") { addBulletList("-") }
                        }
                        Section("Move") {
                            Button("Move Line Up")   { moveLine(direction: -1) }
                            Button("Move Line Down") { moveLine(direction:  1) }
                        }
                        Section("Fix") {
                            Button("Fix Double Spaces") { removeDoubleSpaces() }
                            Button("Lowercase")         { transformSelection { $0.lowercased() } }
                        }
                        Section("Emojis") {
                            Button("💡 Lightbulb") { insertText("💡") }
                            Button("🚀 Rocket")    { insertText("🚀") }
                            Button("✨ Sparkles")  { insertText("✨") }
                            Button("❤️ Heart")     { insertText("❤️") }
                            Button("👉 Point")     { insertText("👉") }
                        }
                        Section("Number Emojis") {
                            ForEach(0..<10) { n in Button("\(n)") { insertNumberEmoji(n) } }
                        }
                        Divider()
                        Button("Add Footer") { addFooter() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .help("More options")

                } else {
                    // ── Convert mode ──
                    Button("MD→Unicode") { convertMarkdownToUnicode() }.buttonStyle(ToolbarButtonStyle())
                    Button("Table→ASCII") { convertTableToASCII() }.buttonStyle(ToolbarButtonStyle())

                    Divider().frame(height: 20)

                    Group {
                        Button("𝐁")  { transformSelection { UnicodeTextFormatter.apply(.bold, to: $0) } }
                        Button("𝘐")  { transformSelection { UnicodeTextFormatter.apply(.italic, to: $0) } }
                        Button("𝒃𝒊") { transformSelection { UnicodeTextFormatter.apply(.boldItalic, to: $0) } }
                        Button("𝚖")  { transformSelection { UnicodeTextFormatter.apply(.monospace, to: $0) } }
                        Button("𝒮")  { transformSelection { UnicodeTextFormatter.apply(.script, to: $0) } }
                        Button("ꜱᴄ") { transformSelection { UnicodeTextFormatter.apply(.smallCaps, to: $0) } }
                        Button("u̲")  { transformSelection { UnicodeTextFormatter.apply(.underline, to: $0) } }
                        Button("s̶")  { transformSelection { UnicodeTextFormatter.apply(.strikethrough, to: $0) } }
                    }
                    .buttonStyle(ToolbarButtonStyle())

                    Spacer()

                    Button("Revert") { revertToPlain() }
                        .buttonStyle(ToolbarButtonStyle(backgroundColor: Color.red.opacity(0.15), foregroundColor: .red))
                }

                // Copy — always visible
                Button(action: copyText) {
                    Text(showCopied ? "✓" : "Copy").foregroundStyle(.white).frame(minWidth: 44)
                }
                .buttonStyle(ToolbarButtonStyle(backgroundColor: showCopied ? .gray : AppColors.accent))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColors.toolbarBackground)

            Divider().foregroundStyle(AppColors.divider)

            // Editor
            MacEditorView(
                text: $text,
                editor: $editor,
                onTextChange: pushToHistory,
                onCursorChange: { cursorRange = $0 }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.editorBackground)

            // Status bar
            StatusBarView(text: text, cursorRange: cursorRange)

            // Footer input
            HStack {
                Text("Footer:").font(.caption).foregroundStyle(AppColors.textSecondary)
                TextField("Custom Footer", text: $footer)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
            .padding(8)
            .background(AppColors.toolbarBackground)
        }
    }
    
    // MARK: - Logic
    
    private func pushToHistory(_ newText: String) {
        if undoStack.last != newText {
            undoStack.append(newText)
            if undoStack.count > 20 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
    }
    
    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(text)
        text = previous
    }
    
    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(text)
        text = next
    }
    
    private func insertText(_ string: String) {
        guard let editor = editor else { return }
        editor.insertText(string, replacementRange: editor.selectedRange())
    }
    
    private func transformSelection(_ transformer: (String) -> String) {
        guard let editor = editor else { return }
        let range = editor.selectedRange()
        guard range.length > 0 else { return }
        
        let selectedString = (editor.string as NSString).substring(with: range)
        let transformed = transformer(selectedString)
        
        editor.insertText(transformed, replacementRange: range)
    }
    
    private func removeDoubleSpaces() {
        text = text.replacingOccurrences(of: "  ", with: " ")
    }
    
    private func addBulletList(_ bullet: String) {
        guard let editor = editor else { return }
        let range = editor.selectedRange()
        let string = editor.string as NSString
        
        // Get lines in selection
        let lineRange = string.lineRange(for: range)
        let selectedSubstring = string.substring(with: lineRange)
        
        var newLines: [String] = []
        selectedSubstring.enumerateLines { line, _ in
            let clean = line.replacingOccurrences(of: "^[•✅🔸⭐️🔹\\-\\d.]+\\s+", with: "", options: .regularExpression)
            newLines.append("\(bullet) \(clean)")
        }
        
        let replacement = newLines.joined(separator: "\n") + (selectedSubstring.hasSuffix("\n") ? "\n" : "")
        editor.insertText(replacement, replacementRange: lineRange)
    }
    
    private func addNumberedList() {
        guard let editor = editor else { return }
        let range = editor.selectedRange()
        let string = editor.string as NSString
        
        let lineRange = string.lineRange(for: range)
        let selectedSubstring = string.substring(with: lineRange)
        
        var newLines: [String] = []
        var count = 1
        selectedSubstring.enumerateLines { line, _ in
            let clean = line.replacingOccurrences(of: "^[•✅🔸⭐️🔹\\-\\d.]+\\s+", with: "", options: .regularExpression)
            newLines.append("\(count). \(clean)")
            count += 1
        }
        
        let replacement = newLines.joined(separator: "\n") + (selectedSubstring.hasSuffix("\n") ? "\n" : "")
        editor.insertText(replacement, replacementRange: lineRange)
    }
    
    private func moveLine(direction: Int) {
        guard let editor else { return }
        let nsText = editor.string as NSString
        let cursorPos = editor.selectedRange().location
        guard cursorPos <= nsText.length else { return }

        // Find range of the current line
        let currentLineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))

        if direction < 0 {
            // Move up: need a line above
            guard currentLineRange.location > 0 else { return }
            let prevLineRange = nsText.lineRange(for: NSRange(location: currentLineRange.location - 1, length: 0))
            let currentLine = nsText.substring(with: currentLineRange)
            let prevLine = nsText.substring(with: prevLineRange)
            let combinedRange = NSRange(location: prevLineRange.location, length: prevLineRange.length + currentLineRange.length)
            editor.insertText(currentLine + prevLine, replacementRange: combinedRange)
            editor.setSelectedRange(NSRange(location: prevLineRange.location, length: 0))
        } else {
            // Move down: need a line below
            let nextStart = NSMaxRange(currentLineRange)
            guard nextStart < nsText.length else { return }
            let nextLineRange = nsText.lineRange(for: NSRange(location: nextStart, length: 0))
            let currentLine = nsText.substring(with: currentLineRange)
            let nextLine = nsText.substring(with: nextLineRange)
            let combinedRange = NSRange(location: currentLineRange.location, length: currentLineRange.length + nextLineRange.length)
            editor.insertText(nextLine + currentLine, replacementRange: combinedRange)
            editor.setSelectedRange(NSRange(location: currentLineRange.location + nextLineRange.length, length: 0))
        }
        text = editor.string
    }
    
    private func addSeparator() {
        insertText("\n\n______________________\n\n")
    }
    
    private func insertNumberEmoji(_ num: Int) {
        let map = ["0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣"]
        if num >= 0 && num < map.count {
            insertText(map[num])
        }
    }
    
    private func addFooter() {
        if !text.hasSuffix("\n\n") {
            text += "\n\n"
        }
        text += footer
    }
    
    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
    
    // MARK: - Convert Mode Actions

    private func convertMarkdownToUnicode() {
        pushToHistory(text)
        text = UnicodeTextFormatter.markdownToUnicode(text)
    }

    private func convertTableToASCII() {
        pushToHistory(text)
        text = UnicodeTextFormatter.markdownTableToASCII(text)
    }

    private func revertToPlain() {
        pushToHistory(text)
        text = UnicodeTextFormatter.revertToPlain(text)
    }

}

// MARK: - MacEditorView
struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var editor: NSTextView?
    var font: NSFont = .systemFont(ofSize: 14)
    var onTextChange: (String) -> Void
    var onCursorChange: ((NSRange) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        
        let textView = NSTextView()
        textView.isRichText = false
        textView.font = font
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width, .height]
        
        scrollView.documentView = textView
        
        DispatchQueue.main.async {
            self.editor = textView
            textView.string = text
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorView
        
        init(_ parent: MacEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange(textView.string)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onCursorChange?(textView.selectedRange())
        }
    }
}


struct ToolbarButtonStyle: ButtonStyle {
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var foregroundColor: Color = .primary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
