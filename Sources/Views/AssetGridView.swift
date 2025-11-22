import SwiftUI
import SwiftData

struct AssetGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.creationDate, order: .reverse) private var assets: [Asset]
    
    let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100))
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(assets) { asset in
                    AssetItemView(asset: asset)
                        .onDrag {
                            let provider = NSItemProvider()
                            
                            if asset.type == .image, let data = asset.imageData, let nsImage = NSImage(data: data) {
                                // Register as multiple formats for maximum compatibility
                                
                                // PNG format
                                provider.registerDataRepresentation(forTypeIdentifier: "public.png", visibility: .all) { completion in
                                    completion(data, nil)
                                    return nil
                                }
                                
                                // TIFF format (native NSImage format, works better with some apps)
                                if let tiffData = nsImage.tiffRepresentation {
                                    provider.registerDataRepresentation(forTypeIdentifier: "public.tiff", visibility: .all) { completion in
                                        completion(tiffData, nil)
                                        return nil
                                    }
                                }
                                
                                // JPEG format (for web compatibility)
                                if let tiffData = nsImage.tiffRepresentation,
                                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                                   let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                                    provider.registerDataRepresentation(forTypeIdentifier: "public.jpeg", visibility: .all) { completion in
                                        completion(jpegData, nil)
                                        return nil
                                    }
                                }
                                
                            } else if asset.type == .text, let text = asset.textContent {
                                provider.registerDataRepresentation(forTypeIdentifier: "public.plain-text", visibility: .all) { completion in
                                    completion(text.data(using: .utf8), nil)
                                    return nil
                                }
                            }
                            
                            return provider
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                modelContext.delete(asset)
                            }
                        }
                }
            }
            .padding()
        }
        .dropDestination(for: Data.self) { items, location in
            handleDrop(items: items)
        }
        .overlay {
            if assets.isEmpty {
                ContentUnavailableView("No Assets", systemImage: "square.stack.3d.up.slash", description: Text("Drag and drop images or text here"))
            }
        }
    }
    
    private func handleDrop(items: [Data]) -> Bool {
        // Simplification: In a real app we'd check UTTypes properly.
        // Here we assume dropped Data is image data for MVP.
        // A robust implementation needs NSItemProvider handling.
        // For now, let's try to handle basic image drops via NSImage compatibility check
        
        for item in items {
            if let _ = NSImage(data: item) {
                let asset = Asset(type: .image, imageData: item)
                modelContext.insert(asset)
            }
        }
        return true
    }
}

struct AssetItemView: View {
    let asset: Asset
    
    var body: some View {
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
            }
        }
    }
}

struct AssetTransferable: Transferable {
    let asset: Asset
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { transferable in
            if transferable.asset.type == .image, let data = transferable.asset.imageData {
                return data
            }
            return Data()
        }
        
        DataRepresentation(exportedContentType: .plainText) { transferable in
            if transferable.asset.type == .text, let text = transferable.asset.textContent {
                return text.data(using: .utf8) ?? Data()
            }
            return Data()
        }
    }
}
