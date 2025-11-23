
import SwiftUI
import AppKit

struct SocialMediaFormatterView: View {
    @Binding var text: String
    @State private var footer: String = "Lau1k © 2025"
    @State private var editor: NSTextView?
    
    // Undo/Redo stacks
    @State private var undoStack: [String] = []
    @State private var redoStack: [String] = []
    
    @State private var showCopied = false
    @State private var showAIMenu = false
    @State private var isProcessingAI = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            VStack(spacing: 8) {
                // Row 1: Undo/Redo | Styles
                HStack(spacing: 6) {
                    Group {
                        Button(action: undo) { Text("Undo") }
                            .disabled(undoStack.isEmpty)
                        Button(action: redo) { Text("Redo") }
                            .disabled(redoStack.isEmpty)
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    
                    Divider()
                        .frame(height: 20)
                    
                    Group {
                        Button(action: { transformSelection(toBold) }) { Text("B").bold() }
                        Button(action: { transformSelection(toItalic) }) { Text("I").italic() }
                        Button(action: { transformSelection { $0.uppercased() } }) { Text("ABC") }
                        Button(action: { transformSelection { $0.capitalized } }) { Text("Abc") }
                        Button(action: { transformSelection { $0.lowercased() } }) { Text("abc") }
                        Button(action: removeDoubleSpaces) { Text("Fix␣␣") }
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    
                    Spacer()
                }
                
                // Row 2: Lists | Move | Separator | Emojis
                HStack(spacing: 6) {
                    Group {
                        Button(action: { addBulletList("•") }) { Text("•") }
                        Button(action: { addBulletList("✅") }) { Text("✅") }
                        Button(action: { addBulletList("🔸") }) { Text("🔸") }
                        Button(action: { addBulletList("⭐️") }) { Text("⭐️") }
                        Button(action: { addBulletList("🔹") }) { Text("🔹") }
                        Button(action: { addBulletList("-") }) { Text("-") }
                        Button(action: addNumberedList) { Text("1.") }
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    
                    Divider()
                        .frame(height: 20)
                    
                    Group {
                        Button(action: { moveLine(direction: -1) }) { Image(systemName: "arrow.up") }
                        Button(action: { moveLine(direction: 1) }) { Image(systemName: "arrow.down") }
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    
                    Group {
                        Button(action: addSeparator) { Text("———") }
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    
                    Divider()
                        .frame(height: 20)
                    
                    Group {
                        Button(action: { insertText("💡") }) { Text("💡") }
                        Button(action: { insertText("🚀") }) { Text("🚀") }
                        Button(action: { insertText("✨") }) { Text("✨") }
                        Button(action: { insertText("❤️") }) { Text("❤️") }
                        Button(action: { insertText("👉") }) { Text("👉") }
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    
                    Spacer()
                }
                
                // Row 3: Numbers | Footer | Copy
                HStack(spacing: 6) {
                    ForEach(0..<10) { num in
                        Button(action: { insertNumberEmoji(num) }) { Text("\(num)") }
                            .buttonStyle(ToolbarButtonStyle())
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: addFooter) { Text("Footer").foregroundStyle(.white) }
                        .buttonStyle(ToolbarButtonStyle(backgroundColor: .green))
                    
                    Button(action: copyText) {
                        Text(showCopied ? "Copied" : "Copy")
                            .foregroundStyle(.white)
                            .frame(minWidth: 60)
                    }
                    .buttonStyle(ToolbarButtonStyle(backgroundColor: showCopied ? .gray : .blue))
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Editor
            MacEditorView(text: $text, editor: $editor, onTextChange: pushToHistory)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Footer Input
            HStack {
                Text("Footer:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Custom Footer", text: $footer)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
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
        // Simplified move line logic
        // This is complex to implement perfectly with NSTextView without more boilerplate
        // For now, let's skip or implement basic swap if possible
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
    
    // MARK: - Transformers
    
    private func toBold(_ input: String) -> String {
        let normal = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let bold =   "𝐚𝐛𝐜𝐝𝐞𝐟𝐠𝐡𝐢𝐣𝐤𝐥𝐦𝐧𝐨𝐩𝐪𝐫𝐬𝐭𝐮𝐯𝐰𝐱𝐲𝐳𝐀𝐁𝐂𝐃𝐄𝐅𝐆𝐇𝐈𝐉𝐊𝐋𝐌𝐍𝐎𝐏𝐐𝐑𝐒𝐓𝐔𝐕𝐖𝐗𝐘𝐙𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗"
        // Vietnamese map (simplified)
        let vietMap: [Character: String] = ["đ": "𝗱̛", "Đ": "𝗗̛"]
        
        return mapChars(input, from: normal, to: bold, extra: vietMap)
    }
    
    private func toItalic(_ input: String) -> String {
        let normal = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let italic = "𝑎𝑏𝑐𝑑𝑒𝑓𝑔ℎ𝑖𝑗𝑘𝑙𝑚𝑛𝑜𝑝𝑞𝑟𝑠𝑡𝑢𝑣𝑤𝑥𝑦𝑧𝐴𝐵𝐶𝐷𝐸𝐹𝐺𝐻𝐼𝐽𝐾𝐿𝑀𝑁𝑂𝑃𝑄𝑅𝑆𝑇𝑈𝑉𝑊𝑋𝑌𝑍"
        let vietMap: [Character: String] = ["đ": "𝘥̛", "Đ": "𝘋̛"]
        return mapChars(input, from: normal, to: italic, extra: vietMap)
    }
    
    private func mapChars(_ input: String, from: String, to: String, extra: [Character: String] = [:]) -> String {
        let fromArray = Array(from)
        let toArray = Array(to)
        var result = ""
        
        for char in input {
            if let mapped = extra[char] {
                result += mapped
            } else if let index = fromArray.firstIndex(of: char) {
                result.append(toArray[index])
            } else {
                result.append(char)
            }
        }
        return result
    }
    
    private func runAIAction(_ action: @escaping (String) async throws -> String) {
        guard !text.isEmpty else { return }
        showAIMenu = false
        isProcessingAI = true
        
        Task {
            do {
                let result = try await action(text)
                await MainActor.run {
                    pushToHistory(result)
                    text = result
                    isProcessingAI = false
                }
            } catch {
                await MainActor.run {
                    isProcessingAI = false
                }
            }
        }
    }
}

// MARK: - MacEditorView
struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var editor: NSTextView?
    var font: NSFont = .systemFont(ofSize: 14)
    var onTextChange: (String) -> Void
    
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
