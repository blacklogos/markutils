import SwiftUI
import SwiftData

struct CompactAssetRowView: View {
    let asset: Asset
    @Environment(AssetStore.self) private var store
    @State private var isHovering = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        HStack {
            // Icon/Thumbnail
            if asset.type == .image, let data = asset.imageData, let nsImage = NSImage(data: data) {
                 Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: asset.type == .text ? "doc.text" : "doc")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            
            // Name/Content Preview
            Text(assetName)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Hover Actions
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: copyAsset) {
                         Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(showCopiedFeedback ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to Clipboard")
                    
                    Button(action: deleteAsset) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    // Helper to get a display name
    private var assetName: String {
        if let name = asset.name { return name }
        if let text = asset.textContent { return text.prefix(50).replacingOccurrences(of: "\n", with: " ") }
        return "Asset"
    }
    
    private func copyAsset() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if asset.type == .image, let data = asset.imageData {
            pasteboard.setData(data, forType: .png)
        } else if asset.type == .text, let text = asset.textContent {
            pasteboard.setString(text, forType: .string)
        }
        
        withAnimation {
            showCopiedFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
    
    private func deleteAsset() {
        withAnimation {
            store.delete(asset)
        }
    }
}
