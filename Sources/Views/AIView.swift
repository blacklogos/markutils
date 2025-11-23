import SwiftUI

struct AIView: View {
    @State private var prompt = ""
    @State private var selectedTemplate: AIService.SlideTemplate = .consulting
    @State private var generatedContent = ""
    @State private var isGenerating = false
    @State private var showCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Toolbar
            HStack {
                Text("AI Slide Generator")
                    .font(.headline)
                Spacer()
                Picker("Template", selection: $selectedTemplate) {
                    ForEach(AIService.SlideTemplate.allCases, id: \.self) { template in
                        Text(template.rawValue).tag(template)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content
            HStack(spacing: 0) {
                // Input Side
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input (Notes/Outline)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $prompt)
                        .font(.body)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                    
                    Button(action: generateSlides) {
                        HStack {
                            if isGenerating {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isGenerating ? "Generating..." : "Generate Slides")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.isEmpty || isGenerating)
                }
                .padding()
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Output Side
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Output (Markdown Slides)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: copyOutput) {
                            Label(showCopied ? "Copied" : "Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .disabled(generatedContent.isEmpty)
                    }
                    
                    TextEditor(text: $generatedContent)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func generateSlides() {
        isGenerating = true
        Task {
            do {
                let result = try await AIService.shared.generateSlideDeck(from: prompt, template: selectedTemplate)
                await MainActor.run {
                    generatedContent = result
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    generatedContent = "Error: \(error.localizedDescription)"
                    isGenerating = false
                }
            }
        }
    }
    
    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedContent, forType: .string)
        
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}
