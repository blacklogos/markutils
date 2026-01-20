import SwiftUI
import UniformTypeIdentifiers

struct SlideDeckView: View {
    @State private var markdownContent: String = """
    # Slide 1: Welcome to MarkSlide
    - This is a simple slide editor.
    - Write markdown on the left.
    - See slides on the right.
    
    ---
    
    # Slide 2: How it works
    1. Separate slides with `---`.
    2. Use standard markdown syntax.
    3. Enjoy your presentation!
    """
    
    @State private var currentSlideIndex: Int = 0
    @State private var selectedTheme: SlideTheme = .modern
    @State private var showExportDialog = false
    
    // File Exporter State
    @State private var exportDocument: GenericExportDocument?
    @State private var isExporting = false
    @State private var exportFilename = "Presentation"
    @State private var exportContentType: UTType?
    
    private var slides: [String] {
        markdownContent.components(separatedBy: "\n---\n")
    }
    
    var body: some View {
        HSplitView {
            // Editor Side (Left)
            VStack(spacing: 0) {
                HStack {
                    Text("Editor")
                        .font(.headline)
                    Spacer()
                    
                    Button(action: { showExportDialog = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                
                TextEditor(text: $markdownContent)
                    .font(.monospaced(.body)())
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 300)
            
            // Preview Side (Right)
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("Preview")
                        .font(.headline)
                    Spacer()
                    
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Modern").tag(SlideTheme.modern)
                        Text("Classic").tag(SlideTheme.classic)
                        Text("Dark").tag(SlideTheme.dark)
                        Text("Swiss").tag(SlideTheme.swiss)
                        Text("Midnight").tag(SlideTheme.midnight)
                        Text("Terminal").tag(SlideTheme.terminal)
                        Text("Paper").tag(SlideTheme.paper)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    
                    Text("\(currentSlideIndex + 1) / \(slides.count)")
                        .font(.monospacedDigit(.body)())
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(action: previousSlide) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentSlideIndex <= 0)
                        
                        Button(action: nextSlide) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentSlideIndex >= slides.count - 1)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                
                // Slide Content
                ZStack {
                    selectedTheme.backgroundColor
                    
                    if slides.indices.contains(currentSlideIndex) {
                        SlidePreview(content: slides[currentSlideIndex], theme: selectedTheme)
                            .padding(40)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(minWidth: 400)
        }
        .sheet(isPresented: $showExportDialog) {
            ExportOptionsView(isPresented: $showExportDialog) { format, ratio, filename in
                handleExport(format: format, ratio: ratio, filename: filename)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportContentType ?? .plainText,
            defaultFilename: exportFilename
        ) { result in
            if case .success = result {
                print("Export successful")
            } else {
                print("Export failed")
            }
        }
    }
    
    private func previousSlide() {
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
        }
    }
    
    private func nextSlide() {
        if currentSlideIndex < slides.count - 1 {
            currentSlideIndex += 1
        }
    }
    
    // MARK: - Export Logic
    
    private func handleExport(format: ExportOptionsView.ExportFormat, ratio: ExportOptionsView.AspectRatio, filename: String) {
        exportFilename = filename
        
        switch format {
        case .markdown:
            exportDocument = GenericExportDocument(text: markdownContent, format: .markdown)
            if let mdType = UTType(filenameExtension: "md") {
                exportContentType = mdType
            } else {
                exportContentType = .plainText
            }
            isExporting = true
            
        case .text:
            exportDocument = GenericExportDocument(text: markdownContent, format: .text)
            exportContentType = .plainText
            isExporting = true
            
        case .pdf:
            let pdfData = generatePDFData(size: ratio.size)
            exportDocument = GenericExportDocument(pdf: pdfData)
            exportContentType = .pdf
            isExporting = true
        }
    }
    
    @MainActor
    private func generatePDFData(size: CGSize) -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return Data() }
        
        var mediaBox = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }
        
        // Loop through all slides
        for slideContent in slides {
            context.beginPDFPage(nil)
            
            // Render the SwiftUI view for this slide
            let slideView = ZStack {
                selectedTheme.backgroundColor
                SlidePreview(content: slideContent, theme: selectedTheme)
                    .padding(40)
            }
            .frame(width: size.width, height: size.height)
            
            let renderer = ImageRenderer(content: slideView)
            
            // Important: Helper to render into the PDF Context
            renderer.render { _, renderInContext in
                renderInContext(context)
            }
            
            context.endPDFPage()
        }
        
        context.closePDF()
        return pdfData as Data
    }
}



struct SlidePreview: View {
    let content: String
    let theme: SlideTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(content.components(separatedBy: .newlines), id: \.self) { line in
                processLine(line)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func processLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("# ") {
            Text(trimmed.dropFirst(2))
                .font(.custom(theme.fontName, size: 42))
                .fontWeight(.bold)
                .foregroundStyle(theme.titleColor)
        } else if trimmed.hasPrefix("## ") {
            Text(trimmed.dropFirst(3))
                .font(.custom(theme.fontName, size: 32))
                .fontWeight(.semibold)
                .foregroundStyle(theme.bodyColor)
        } else if trimmed.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.custom(theme.fontName, size: 24))
                Text(trimmed.dropFirst(2))
                    .font(.custom(theme.fontName, size: 24))
            }
            .foregroundStyle(theme.bodyColor)
        } else if trimmed.hasPrefix("1. ") {
             HStack(alignment: .top, spacing: 8) {
                 Text("1.") 
                     .font(.custom(theme.fontName, size: 24))
                 Text(trimmed.dropFirst(3))
                     .font(.custom(theme.fontName, size: 24))
             }
             .foregroundStyle(theme.bodyColor)
        } else if !trimmed.isEmpty {
            Text(trimmed)
                .font(.custom(theme.fontName, size: 24))
                .foregroundStyle(theme.bodyColor)
        }
    }
}
