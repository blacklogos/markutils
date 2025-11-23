import SwiftUI

struct TransformerView: View {
    // Text Mode Data
    @State private var textInput = ""
    @State private var textOutput = ""
    
    // Table Mode Data
    @State private var tableInput = ""
    @State private var tableOutput = ""
    
    // Social Mode Data
    @State private var socialInput = ""
    
    @State private var selectedTransform: TransformType = .textConversion
    @State private var isReverse = false // false: Forward (MD->HTML, Table->MD), true: Reverse (HTML->MD, MD->Table)
    
    // View Mode for Live Preview
    @State private var viewMode: ViewMode = .edit
    
    enum TransformType: String, CaseIterable, Identifiable {
        case textConversion = "Text (MD ↔ HTML)"
        case tableConversion = "Table (Spreadsheet ↔ MD)"
        
        var id: String { rawValue }
    }
    
    enum ViewMode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case preview = "Preview"
        case split = "Split"
        
        var id: String { rawValue }
    }
    
    // Computed properties for current mode's data
    private var currentInput: Binding<String> {
        switch selectedTransform {
        case .textConversion: return $textInput
        case .tableConversion: return $tableInput
        }
    }
    
    private var currentOutput: Binding<String> {
        switch selectedTransform {
        case .textConversion: return $textOutput
        case .tableConversion: return $tableOutput
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top Toolbar: Transform Type & View Mode
                VStack(spacing: 8) {
                    // Transform Type Picker
                    Picker("Transform", selection: $selectedTransform) {
                        ForEach(TransformType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    
                    // View Mode Picker (Only for Text Conversion)
                    if selectedTransform == .textConversion {
                        Picker("View Mode", selection: $viewMode) {
                            ForEach(ViewMode.allCases) { mode in
                                Image(systemName: iconFor(mode)).tag(mode)
                                    .help(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider()
                
                // Main Content Area
                if selectedTransform == .textConversion {
                    textConversionContent(geometry: geometry)
                } else {
                    tableConversionContent(geometry: geometry)
                }
            }
        }
    }
    
    private func iconFor(_ mode: ViewMode) -> String {
        switch mode {
        case .edit: return "pencil"
        case .preview: return "eye"
        case .split: return "rectangle.split.3x1"
        }
    }
    
    @State private var editor: NSTextView? // For MacEditorView
    
    // MARK: - Text Conversion (Markdown ↔ HTML) with Live Preview
    
    private func textConversionContent(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Editor Side
            if viewMode == .edit || viewMode == .split {
                VStack(spacing: 0) {
                    editorToolbar(title: "Markdown Input", text: $textInput, isInput: true)
                    MacEditorView(
                        text: $textInput,
                        editor: $editor,
                        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                        onTextChange: { _ in transform() }
                    )
                }
                .frame(maxWidth: viewMode == .split ? geometry.size.width / 2 : .infinity)
            }
            
            // Divider for Split View
            if viewMode == .split {
                Divider()
            }
            
            // Preview Side
            if viewMode == .preview || viewMode == .split {
                VStack(spacing: 0) {
                    editorToolbar(title: "Preview", text: $textOutput, isInput: false)
                    
                    // Use MarkdownPreviewView for rendered markdown
                    MarkdownPreviewView(attributedString: RichTextTransformer.markdownToRichText(textInput))
                        .background(Color(NSColor.textBackgroundColor))
                }
                .frame(maxWidth: viewMode == .split ? geometry.size.width / 2 : .infinity)
            }
        }
    }
    
    // MARK: - Table Conversion (Legacy Split)
    
    private func tableConversionContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Input
            VStack(spacing: 0) {
                editorToolbar(title: "Input", text: $tableInput, isInput: true)
                TextEditor(text: $tableInput)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: tableInput) { _, _ in transform() }
            }
            .frame(height: (geometry.size.height - 100) / 2)
            
            // Swap Button
            HStack {
                Spacer()
                Button(action: swapInputOutput) {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .buttonStyle(.plain)
                .padding(4)
                Spacer()
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            // Output
            VStack(spacing: 0) {
                editorToolbar(title: "Output", text: $tableOutput, isInput: false)
                TextEditor(text: $tableOutput)
                    .font(.system(size: 11, design: .monospaced))
            }
            .frame(height: (geometry.size.height - 100) / 2)
        }
    }
    
    // MARK: - Toolbars
    
    private func editorToolbar(title: String, text: Binding<String>, isInput: Bool) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if isInput {
                Button(action: { text.wrappedValue = "" }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear")
                
                Button(action: insertSample) {
                    Image(systemName: "text.quote")
                }
                .buttonStyle(.plain)
                .help("Insert Sample")
            }
            
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text.wrappedValue, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .bottom)
    }
    
    // MARK: - Logic
    
    private func transform() {
        switch selectedTransform {
        case .textConversion:
            // For text conversion, we rely on the Preview view to render, 
            // but we still update output for copy purposes if needed (HTML export)
             textOutput = RichTextTransformer.markdownToHTML(textInput)
            
        case .tableConversion:
            if isReverse {
                tableOutput = TableTransformer.markdownToTSV(tableInput)
            } else {
                if tableInput.contains("\t") {
                    tableOutput = TableTransformer.tsvToMarkdown(tableInput)
                } else {
                    tableOutput = TableTransformer.csvToMarkdown(tableInput)
                }
            }
        }
    }
    
    private func swapInputOutput() {
        switch selectedTransform {
        case .textConversion:
            let temp = textInput
            textInput = textOutput
            textOutput = temp
        case .tableConversion:
            let temp = tableInput
            tableInput = tableOutput
            tableOutput = temp
        }
        isReverse.toggle()
        transform()
    }
    
    private func insertSample() {
        switch selectedTransform {
        case .textConversion:
            textInput = """
            # Welcome to Clip
            
            This is a **live preview** of your markdown.
            
            - Edit on the left
            - See changes on the right
            - Supports *italics*, `code`, and more.
            
            ## Try it out!
            Type something here...
            """
            
        case .tableConversion:
            tableInput = """
            Item\tPrice\tQty
            Apple\t$1.00\t5
            Banana\t$0.50\t10
            """
        }
    }
}
