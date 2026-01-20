import SwiftUI
import UniformTypeIdentifiers

struct GenericExportDocument: FileDocument {
    var textContent: String = ""
    var pdfData: Data? = nil
    var exportFormat: ExportOptionsView.ExportFormat = .text
    
    init(text: String, format: ExportOptionsView.ExportFormat) {
        self.textContent = text
        self.exportFormat = format
    }
    
    init(pdf: Data) {
        self.pdfData = pdf
        self.exportFormat = .pdf
    }

    static var readableContentTypes: [UTType] { [.plainText, .pdf] } // .markdown might need explicit import or fallback

    init(configuration: ReadConfiguration) throws {
        // Not needed for export-only
        self.textContent = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch exportFormat {
        case .pdf:
            return FileWrapper(regularFileWithContents: pdfData ?? Data())
        case .markdown, .text:
            return FileWrapper(regularFileWithContents: textContent.data(using: .utf8) ?? Data())
        }
    }
}
