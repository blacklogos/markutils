import Foundation

public struct TableTransformer {
    
    // MARK: - Markdown to TSV/CSV
    
    public static func markdownToTSV(_ markdown: String) -> String {
        let rows = parseMarkdownTable(markdown)
        return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }
    
    public static func markdownToCSV(_ markdown: String) -> String {
        let rows = parseMarkdownTable(markdown)
        return rows.map { row in
            row.map { escapeCSVField($0) }.joined(separator: ",")
        }.joined(separator: "\n")
    }
    
    // MARK: - TSV/CSV to Markdown
    
    public static func tsvToMarkdown(_ tsv: String) -> String {
        let rows = tsv.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { $0.components(separatedBy: "\t") }
        return generateMarkdownTable(rows)
    }
    
    public static func csvToMarkdown(_ csv: String) -> String {
        let rows = parseCSV(csv)
        return generateMarkdownTable(rows)
    }
    
    // MARK: - Private Helpers
    
    private static func parseMarkdownTable(_ markdown: String) -> [[String]] {
        let lines = markdown.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var rows: [[String]] = []
        
        for line in lines {
            // Skip separator lines (e.g., |---|---|)
            if line.contains("---") {
                continue
            }
            
            // Parse table row
            let cells = line
                .split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            if !cells.isEmpty {
                rows.append(cells)
            }
        }
        
        return rows
    }
    
    private static func generateMarkdownTable(_ rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "" }
        
        // Calculate column widths
        let columnCount = rows.map { $0.count }.max() ?? 0
        var columnWidths = Array(repeating: 0, count: columnCount)
        
        for row in rows {
            for (index, cell) in row.enumerated() {
                columnWidths[index] = max(columnWidths[index], cell.count)
            }
        }
        
        var result = ""
        
        // Header row
        if let header = rows.first {
            result += "| "
            for (index, cell) in header.enumerated() {
                result += cell.padding(toLength: columnWidths[index], withPad: " ", startingAt: 0)
                result += " | "
            }
            result += "\n"
            
            // Separator row
            result += "|"
            for width in columnWidths {
                result += " " + String(repeating: "-", count: width) + " |"
            }
            result += "\n"
        }
        
        // Data rows
        for row in rows.dropFirst() {
            result += "| "
            for (index, cell) in row.enumerated() {
                let width = index < columnWidths.count ? columnWidths[index] : 0
                result += cell.padding(toLength: width, withPad: " ", startingAt: 0)
                result += " | "
            }
            result += "\n"
        }
        
        return result
    }
    
    private static func parseCSV(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in csv {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if char == "\n" && !inQuotes {
                currentRow.append(currentField)
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                }
                currentRow = []
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add last field and row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
