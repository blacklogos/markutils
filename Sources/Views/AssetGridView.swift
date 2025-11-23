import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AssetGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.creationDate, order: .reverse) private var assets: [Asset]
    @State private var draggingAsset: Asset?
    @State private var showFileImporter = false
    
    // Filtered assets
    var imageAssets: [Asset] { assets.filter { $0.type == .image } }
    var textAssets: [Asset] { assets.filter { $0.type == .text } }
    
    let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Assets")
                    .font(.headline)
                Spacer()
                Button(action: { showFileImporter = true }) {
                    Label("Add Files", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    // Images Section
                    if !imageAssets.isEmpty {
                        Section(header: sectionHeader("Images")) {
                            ForEach(imageAssets) { asset in
                                AssetItemView(asset: asset)
                                    .onDrag {
                                        draggingAsset = asset
                                        return createItemProvider(for: asset)
                                    }
                                    .onDrop(of: [.text, .image], delegate: DropViewDelegate(destinationItem: asset, assets: assets, draggingItem: $draggingAsset, modelContext: modelContext))
                            }
                        }
                    }
                    
                    // Text Section
                    if !textAssets.isEmpty {
                        Section(header: sectionHeader("Text")) {
                            ForEach(textAssets) { asset in
                                AssetItemView(asset: asset)
                                    .onDrag {
                                        draggingAsset = asset
                                        return createItemProvider(for: asset)
                                    }
                                    .onDrop(of: [.text, .image], delegate: DropViewDelegate(destinationItem: asset, assets: assets, draggingItem: $draggingAsset, modelContext: modelContext))
                            }
                        }
                    }
                }
                .padding()
            }
            .dropDestination(for: Data.self) { items, location in
                handleDrop(items: items)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image, .text, .plainText, .utf8PlainText], allowsMultipleSelection: true) { result in
                handleFileImport(result)
            }
            .overlay {
                if assets.isEmpty {
                    ContentUnavailableView("No Assets", systemImage: "square.stack.3d.up.slash", description: Text("Drag and drop files here\nor click Add Files"))
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .cornerRadius(4)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor)) // Sticky header background
    }
    
    private func createItemProvider(for asset: Asset) -> NSItemProvider {
        let provider = NSItemProvider()
        
        if asset.type == .image, let data = asset.imageData {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
        } else if asset.type == .text, let text = asset.textContent {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                completion(text.data(using: .utf8), nil)
                return nil
            }
        }
        
        return provider
    }
    
    private func handleDrop(items: [Data]) -> Bool {
        // If draggingAsset is set, it's an internal reorder, handled by DropViewDelegate
        // But wait, dropDestination catches everything.
        // We need to differentiate.
        // Actually, .dropDestination(for: Data.self) might catch internal drags too if they conform.
        // But our internal drag uses NSItemProvider with specific types.
        
        // The fix: If draggingAsset is NOT nil, it's an internal drag. Return false here to let DropDelegate handle it?
        // Or return true but do nothing?
        // If we return false, it might reject the drop.
        
        if draggingAsset != nil {
            return false // Let DropDelegate handle reordering
        }
        
        // Limit to 5 items
        let itemsToImport = items.prefix(5)
        
        for item in itemsToImport {
            // Try to determine if it's image or text
            // This is tricky with just Data.
            // Usually .dropDestination gives us Transferable items.
            // Let's stick to Data for now and guess.
            
            if let _ = NSImage(data: item) {
                let asset = Asset(type: .image, imageData: item)
                modelContext.insert(asset)
            } else if let text = String(data: item, encoding: .utf8) {
                let asset = Asset(type: .text, textContent: text)
                modelContext.insert(asset)
            }
        }
        return true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Limit to 5
            let urlsToImport = urls.prefix(5)
            
            for url in urlsToImport {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let data = try Data(contentsOf: url)
                    let type = UTType(filenameExtension: url.pathExtension) ?? .content
                    
                    if type.conforms(to: .image) {
                        let asset = Asset(type: .image, imageData: data)
                        modelContext.insert(asset)
                    } else if type.conforms(to: .text) || type.conforms(to: .plainText) {
                        let text = String(data: data, encoding: .utf8)
                        let asset = Asset(type: .text, textContent: text)
                        modelContext.insert(asset)
                    }
                } catch {
                    print("Error reading file: \(error)")
                }
            }
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
}

struct DropViewDelegate: DropDelegate {
    let destinationItem: Asset
    let assets: [Asset]
    @Binding var draggingItem: Asset?
    let modelContext: ModelContext
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem != destinationItem else { return }
        
        // Swap creation dates to reorder
        let tempDate = draggingItem.creationDate
        draggingItem.creationDate = destinationItem.creationDate
        destinationItem.creationDate = tempDate
    }
}

struct AssetItemView: View {
    let asset: Asset
    @Environment(\.modelContext) private var modelContext
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
        modelContext.delete(asset)
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
