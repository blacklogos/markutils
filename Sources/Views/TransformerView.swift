import SwiftUI

struct TransformerView: View {
    // Text Mode Data
    @State private var textInput = ""
    @State private var textOutput = ""
    
    // Table Mode Data
    @State private var tableInput = ""
    @State private var tableOutput = ""
    
    @State private var selectedTransform: TransformType = .textConversion
    @State private var showHTMLPreview = true
    @State private var isReverse = false // false: Forward (MD->HTML, Table->MD), true: Reverse (HTML->MD, MD->Table)
    
    enum TransformType: String, CaseIterable, Identifiable {
        case textConversion = "Text (MD ↔ HTML)"
        case tableConversion = "Table (Spreadsheet ↔ MD)"
        
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
                // Segmented Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Picker("Transform", selection: $selectedTransform) {
                            ForEach(TransformType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(minWidth: geometry.size.width)
                    }
                }
                
                // Direction Indicator
                HStack {
                    Spacer()
                    Text(directionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.bottom, 8)
                
                // Input Area (Flexible Height)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Input")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        
                        // Clear button
                        Button(action: { currentInput.wrappedValue = "" }) {
                            Label("Clear", systemImage: "xmark.circle")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .disabled(currentInput.wrappedValue.isEmpty)
                        
                        // Clipboard button (Renamed from Paste)
                        Button(action: pasteInput) {
                            Label("Clipboard", systemImage: "clipboard")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        
                        // Sample button
                        Button(action: insertSample) {
                            Label("Sample", systemImage: "text.quote")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        
                        // Copy button
                        Button(action: copyInput) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .disabled(currentInput.wrappedValue.isEmpty)
                    }
                    
                    TextEditor(text: currentInput)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxHeight: .infinity) // Fill available space
                        .border(Color.gray.opacity(0.3))
                        .onChange(of: currentInput.wrappedValue) { _, _ in
                            transform()
                        }
                        .onChange(of: selectedTransform) { _, _ in
                            // Re-trigger transform when switching modes to ensure output is up to date if needed
                            // But since data is separate, we might just want to ensure correct state
                            transform()
                        }
                        .onChange(of: isReverse) { _, _ in
                            transform()
                        }
                }
                .frame(height: (geometry.size.height - 60) / 2) // Split height roughly in half
                
                // Swap button (Center)
                Button(action: swapInputOutput) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Swap input and output")
                .padding(.vertical, 8)
                
                // Output Area (Flexible Height)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // HTML Preview Toggle (only for MD -> HTML)
                        if selectedTransform == .textConversion && !isReverse {
                            Picker("View", selection: $showHTMLPreview) {
                                Text("Preview").tag(true)
                                Text("Raw HTML").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 160) // Slightly wider for "Raw HTML"
                            .controlSize(.small)
                        }
                        
                        Spacer()
                        
                        Button(action: copyOutput) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .disabled(currentOutput.wrappedValue.isEmpty)
                    }
                    
                    if showHTMLPreview && selectedTransform == .textConversion && !isReverse {
                        HTMLPreviewView(htmlContent: currentOutput.wrappedValue)
                            .frame(maxHeight: .infinity)
                            .border(Color.gray.opacity(0.3))
                    } else {
                        TextEditor(text: currentOutput)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxHeight: .infinity)
                            .border(Color.gray.opacity(0.3))
                    }
                }
                .frame(height: (geometry.size.height - 60) / 2) // Split height roughly in half
            }
            .padding(12)
        }
    }
    
    private var directionLabel: String {
        switch selectedTransform {
        case .textConversion:
            return isReverse ? "HTML → Markdown" : "Markdown → HTML"
        case .tableConversion:
            return isReverse ? "Markdown Table → Spreadsheet" : "Spreadsheet → Markdown Table"
        }
    }
    
    private func transform() {
        switch selectedTransform {
        case .textConversion:
            if isReverse {
                // HTML -> Markdown
                textOutput = RichTextTransformer.htmlToMarkdown(textInput)
            } else {
                // Markdown -> HTML
                textOutput = RichTextTransformer.markdownToHTML(textInput)
            }
            
        case .tableConversion:
            if isReverse {
                // Markdown Table -> TSV (Spreadsheet)
                tableOutput = TableTransformer.markdownToTSV(tableInput)
            } else {
                // Spreadsheet (TSV/CSV) -> Markdown Table
                // Auto-detect separator based on content
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
        
        // Toggle direction
        isReverse.toggle()
        
        // Re-transform with new direction
        transform()
    }
    
    private func pasteInput() {
        if let string = NSPasteboard.general.string(forType: .string) ?? NSPasteboard.general.string(forType: .init("public.utf8-plain-text")) {
            switch selectedTransform {
            case .textConversion: textInput = string
            case .tableConversion: tableInput = string
            }
        }
    }
    
    private func insertSample() {
        switch selectedTransform {
        case .textConversion:
            textInput = """
            # Vibe Coding Journal: Clip App
            
            _A chronicle of human-AI collaboration in building a Mac menu bar content creation assistant_
            
            ---
            
            ## 2025-11-22 - The Beginning
            
            ### Session 1: Vision & PRD (08:51 - 09:08)
            
            **Human:** "I want a Mac taskbar app for slides, diagrams, and pictures"
            
            **AI:** _Translates vibes into structure_
            
            - A menu bar app (not just any app)
            - An asset vault (not just a clipboard)
            - AI-powered transformations (markdown → tables, text → diagrams)
            """
            
        case .tableConversion:
            tableInput = """
            06/16/2025\tPAYPAL *PADDLE.NET\t0.00\t0.00\t1,536,449\t0.00\t0.00
            06/16/2025\tSAKURA MOBILE\t0.00\t0.00\t0\t0.00\t0.00
            06/17/2025\tIKEASHIBUYA\t0.00\t0.00\t0\t0.00\t0.00
            06/18/2025\tTODOIST\t0.00\t5.00\t0\t0.00\t0.00
            06/18/2025\tKlook Travel Tech Ltd\t0.00\t109.70\t0\t0.00\t0.00
            06/19/2025\tKOMEHYO SHINJUKU WOMEN\t0.00\t0.00\t0\t0.00\t0.00
            TOTAL\t\t0.00\t594.42\t6,317,057\t0.00\t0.00
            """
        }
    }
    
    private func copyInput() {
        NSPasteboard.general.clearContents()
        let textToCopy = selectedTransform == .textConversion ? textInput : tableInput
        NSPasteboard.general.setString(textToCopy, forType: .string)
    }
    
    private func copyOutput() {
        NSPasteboard.general.clearContents()
        let textToCopy = selectedTransform == .textConversion ? textOutput : tableOutput
        NSPasteboard.general.setString(textToCopy, forType: .string)
    }
}
