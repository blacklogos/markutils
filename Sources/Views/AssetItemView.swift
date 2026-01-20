import SwiftUI
import SwiftData

struct AssetItemView: View {
    let asset: Asset
    @Environment(AssetStore.self) private var store
    @State private var isHovering = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        ZStack {
            // Content
            Group {
                if asset.type == .image, let data = asset.imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if asset.type == .text {
                    Text(asset.textContent ?? "")
                        .font(.caption)
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(4)
                }
            }
            
            // Hover Overlay
            if isHovering {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 80, height: 80)
                    
                    // Remove Button (Top Right)
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: deleteAsset) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Remove")
                            .padding(4)
                        }
                        Spacer()
                    }
                    
                    // Copy Button (Center)
                    Button(action: copyAsset) {
                        Text(showCopiedFeedback ? "Copied" : "Copy")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(showCopiedFeedback ? Color.green : Color.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentShape(Rectangle()) // Fix hover hit testing
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
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
        store.delete(asset)
    }
}
