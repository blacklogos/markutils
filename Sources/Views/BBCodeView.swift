import SwiftUI
import AppKit

struct BBCodeView: View {
    @State private var inputMode: InputMode = .richText
    
    // Markdown State
    @State private var markdownInput: String = """
    # Example Title
    
    This is **bold** text and *italic* text.
    
    Here is a link: [Google](https://google.com)
    
    > This is a quote
    
    - List item 1
    - List item 2
    """
    
    // Rich Text State
    @State private var richTextEditor: NSTextView?
    @State private var richTextStorage: String = "" // Placeholder to trigger updates
    
    // Output
    @State private var output: String = ""
    @State private var showCopied = false
    
    enum InputMode: String, CaseIterable {
        case richText = "Rich Text"
        case markdown = "Markdown"
    }
    
    var body: some View {
        HSplitView {
            // Input Side
            VStack(spacing: 0) {
                HStack {
                    Picker("Input Mode", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Spacer()
                    
                    if inputMode == .markdown {
                        Button("Clear") { markdownInput = "" }
                    } else {
                        Button("Clear") { richTextEditor?.string = "" }
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                
                if inputMode == .markdown {
                    TextEditor(text: $markdownInput)
                        .font(.monospaced(.body)())
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: markdownInput) { _, _ in convertMarkdownToBBCode() }
                } else {
                    MacRichTextEditor(editor: $richTextEditor, onTextChange: { _ in
                        convertRichTextToBBCode()
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
            
            // Output Side
            VStack(spacing: 0) {
                HStack {
                    Text("BBCode Output")
                        .font(.headline)
                    Spacer()
                    Button(action: copyOutput) {
                        Label(showCopied ? "Copied" : "Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                
                TextEditor(text: $output)
                    .font(.monospaced(.body)())
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 300)
        }
        .onAppear {
            if inputMode == .markdown { convertMarkdownToBBCode() }
        }
    }
    
    private func convertRichTextToBBCode() {
        guard let editor = richTextEditor, let storage = editor.textStorage else { return }
        output = RichTextParser.convertToBBCode(storage)
    }
    
    private func convertMarkdownToBBCode() {
        // Simple Markdown to BBCode converter
        var text = markdownInput
        
        // Bold (**text** or __text__)
        text = text.replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "[b]$1[/b]", options: .regularExpression)
        
        // Italic (*text* or _text_)
        text = text.replacingOccurrences(of: "\\*(.*?)\\*", with: "[i]$1[/i]", options: .regularExpression)
        
        // Underline (custom markdown often uses __, standard is usually bold but context matters)
        text = text.replacingOccurrences(of: "__(.*?)__", with: "[u]$1[/u]", options: .regularExpression)
        
        // Strikethrough (~~text~~)
        text = text.replacingOccurrences(of: "~~(.*?)~~", with: "[s]$1[/s]", options: .regularExpression)
        
        // URL ([text](url))
        text = text.replacingOccurrences(of: "\\[(.*?)\\]\\((.*?)\\)", with: "[url=$2]$1[/url]", options: .regularExpression)
        
        // Image (![alt](url)) - Note: BBCode usually just [img]url[/img]
        text = text.replacingOccurrences(of: "!\\[.*?\\]\\((.*?)\\)", with: "[img]$1[/img]", options: .regularExpression)
        
        // Headers (# H1 -> [size=6]H1[/size], ## H2 -> [size=5]H2[/size])
        // Need to handle per line
        var lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("# ") {
                lines[index] = "[size=6][b]" + line.dropFirst(2) + "[/b][/size]"
            } else if line.hasPrefix("## ") {
                lines[index] = "[size=5][b]" + line.dropFirst(3) + "[/b][/size]"
            } else if line.hasPrefix("### ") {
                lines[index] = "[size=4][b]" + line.dropFirst(4) + "[/b][/size]"
            } else if line.hasPrefix("> ") {
                lines[index] = "[quote]" + line.dropFirst(2) + "[/quote]"
            } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                // Lists are tricky, simplified list item
                lines[index] = "[*]" + line.replacingOccurrences(of: "^\\s*-\\s", with: "", options: .regularExpression)
            }
        }
        
        text = lines.joined(separator: "\n")
        output = text
    }
    
    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}

// Minimal MacRichTextEditor specifically for this view
struct MacRichTextEditor: NSViewRepresentable {
    @Binding var editor: NSTextView?
    var onTextChange: (String) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        
        let textView = NSTextView()
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width, .height]
        
        // Enable Rich Text Paste
        textView.importsGraphics = true
        textView.allowsImageEditing = true
        
        scrollView.documentView = textView
        
        DispatchQueue.main.async {
            self.editor = textView
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacRichTextEditor
        
        init(_ parent: MacRichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onTextChange(textView.string)
        }
    }
}
