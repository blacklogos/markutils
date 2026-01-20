import SwiftUI

struct ExportOptionsView: View {
    @Binding var isPresented: Bool
    var onExport: (ExportFormat, AspectRatio, String) -> Void
    
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var selectedAspectRatio: AspectRatio = .ratio16_9
    @State private var filename: String = "Presentation"
    
    enum AspectRatio: String, CaseIterable, Identifiable {
        case ratio16_9 = "16:9 (Landscape)"
        case ratio9_16 = "9:16 (Portrait)"
        case ratio4_3 = "4:3 (Standard)"
        case ratio3_4 = "3:4 (Portrait)"
        case ratio1_1 = "1:1 (Square)"
        
        var id: String { rawValue }
        
        var size: CGSize {
            switch self {
            case .ratio16_9: return CGSize(width: 960, height: 540)
            case .ratio9_16: return CGSize(width: 540, height: 960)
            case .ratio4_3: return CGSize(width: 960, height: 720)
            case .ratio3_4: return CGSize(width: 720, height: 960)
            case .ratio1_1: return CGSize(width: 800, height: 800)
            }
        }
    }
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case pdf = "PDF Document"
        case markdown = "Markdown Source"
        case text = "Plain Text"
        
        var id: String { rawValue }
        
        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .markdown: return "md"
            case .text: return "txt"
            }
        }
        
        var icon: String {
            switch self {
            case .pdf: return "doc.richtext"
            case .markdown: return "doc.text"
            case .text: return "text.alignleft"
            }
        }
        
        var description: String {
            switch self {
            case .pdf: return "Vector-based slides ready for sharing."
            case .markdown: return "Raw content for other editors."
            case .text: return "Simple text output."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Export Slides")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Filename
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filename")
                        .fontWeight(.medium)
                    TextField("Presentation", text: $filename)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
                
                // Format Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format")
                        .fontWeight(.medium)
                    
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(format.rawValue, systemImage: format.icon).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    
                    Text(selectedFormat.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Aspect Ratio (Only for PDF)
                if selectedFormat == .pdf {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dimensions")
                            .fontWeight(.medium)
                        
                        Picker("Dimensions", selection: $selectedAspectRatio) {
                            ForEach(AspectRatio.allCases) { ratio in
                                Text(ratio.rawValue).tag(ratio)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
            .padding()
            
            Spacer()
            
            Divider()
            
            // Footer Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: {
                    onExport(selectedFormat, selectedAspectRatio, filename)
                    isPresented = false
                }) {
                    Text("Export \(selectedFormat.fileExtension.uppercased())")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 400, height: selectedFormat == .pdf ? 450 : 380)
    }
}
