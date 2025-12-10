import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AssetGridView: View {
    @Environment(AssetStore.self) private var store
    
    private var assets: [Asset] {
        store.assets.sorted { $0.creationDate > $1.creationDate }
    }
    @State private var draggingAsset: Asset?
    @State private var showFileImporter = false
    @State private var isCompactMode = false
    
    // Filtered assets
    var folderAssets: [Asset] { assets.filter { $0.type == .folder } }
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
                
                Button(action: { withAnimation { isCompactMode.toggle() } }) {
                    Label("View", systemImage: isCompactMode ? "list.bullet" : "square.grid.2x2")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            ScrollView {
                if isCompactMode {
                    LazyVStack(alignment: .leading, spacing: 4) {
                         // Folders Section (Always list)
                        if !folderAssets.isEmpty {
                            Section(header: sectionHeader("Folders")) {
                                ForEach(folderAssets) { folder in
                                    FolderRowView(folder: folder)
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        
                        // Images Section
                        if !imageAssets.isEmpty {
                            Section(header: sectionHeader("Images")) {
                                ForEach(imageAssets) { asset in
                                    CompactAssetRowView(asset: asset)
                                        .onDrag {
                                            draggingAsset = asset
                                            return createItemProvider(for: asset)
                                        }
                                        .onDrop(of: [.text, .image], delegate: DropViewDelegate(destinationItem: asset, assets: assets, draggingItem: $draggingAsset, store: store))
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        
                        // Text Section
                        if !textAssets.isEmpty {
                            Section(header: sectionHeader("Text")) {
                                ForEach(textAssets) { asset in
                                    CompactAssetRowView(asset: asset)
                                        .onDrag {
                                            draggingAsset = asset
                                            return createItemProvider(for: asset)
                                        }
                                        .onDrop(of: [.text, .image], delegate: DropViewDelegate(destinationItem: asset, assets: assets, draggingItem: $draggingAsset, store: store))
                                    Divider().padding(.leading)
                                }
                            }
                        }
                    }
                    .padding()
                } else {
                    // Folders Section
                    if !folderAssets.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Section(header: sectionHeader("Folders")) {
                                ForEach(folderAssets) { folder in
                                    FolderRowView(folder: folder)
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    
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
                                        .onDrop(of: [.text, .image], delegate: DropViewDelegate(destinationItem: asset, assets: assets, draggingItem: $draggingAsset, store: store))
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
                                        .onDrop(of: [.text, .image], delegate: DropViewDelegate(destinationItem: asset, assets: assets, draggingItem: $draggingAsset, store: store))
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .dropDestination(for: URL.self) { items, location in
                handleURLDrop(items: items)
            }
            .dropDestination(for: Data.self) { items, location in
                handleDrop(items: items)
            }
            // Add onPasteCommand for macOS
            .onPasteCommand(of: [.image, .fileURL, .url, .text]) { providers in
                handlePaste(providers: providers)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.content, .folder], allowsMultipleSelection: true) { result in
                handleFileImport(result)
            }
            .overlay {
                if assets.isEmpty {
                    ContentUnavailableView("No Assets", systemImage: "square.stack.3d.up.slash", description: Text("Drag and drop files here,\npaste content, or click Add Files"))
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
        if draggingAsset != nil {
            return false // Let DropDelegate handle reordering
        }
        
        // Limit to 5 items
        let itemsToImport = items.prefix(5)
        
        for item in itemsToImport {
            if let _ = NSImage(data: item) {
                let asset = Asset(type: .image, imageData: item)
                store.add(asset)
            } else if let text = String(data: item, encoding: .utf8) {
                let asset = Asset(type: .text, textContent: text)
                store.add(asset)
            }
        }
        return true
    }

    private func handleURLDrop(items: [URL]) -> Bool {
        // Segregate file URLs and web URLs
        let fileURLs = items.filter { $0.isFileURL }
        let webURLs = items.filter { !$0.isFileURL }
        
        // Handle file URLs
        if !fileURLs.isEmpty {
            handleFileImport(.success(fileURLs))
        }
        
        // Handle web URLs
        for url in webURLs {
             let asset = Asset(type: .text, textContent: url.absoluteString, name: "Link")
             store.add(asset)
        }
        
        return true
    }
    
    private func handlePaste(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                 provider.loadObject(ofClass: NSImage.self) { image, error in
                     if let image = image as? NSImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                         DispatchQueue.main.async {
                             let asset = Asset(type: .image, imageData: png, name: "Pasted Image")
                             store.add(asset)
                         }
                     }
                 }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            handleFileImport(.success([url]))
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                 _ = provider.loadObject(ofClass: URL.self) { url, _ in
                     if let url = url {
                         DispatchQueue.main.async {
                             let asset = Asset(type: .text, textContent: url.absoluteString, name: "Pasted Link")
                             store.add(asset)
                         }
                     }
                 }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    if let text = text {
                        DispatchQueue.main.async {
                            let asset = Asset(type: .text, textContent: text, name: "Pasted Text")
                            store.add(asset)
                        }
                    }
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Limit to 5
            let urlsToImport = urls.prefix(5)
            
            for url in urlsToImport {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let asset = createAsset(from: url) {
                    store.add(asset)
                }
            }
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
    
    private func createAsset(from url: URL) -> Asset? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        
        let name = url.lastPathComponent
        
        if isDirectory.boolValue {
            var children: [Asset] = []
            let properties: [URLResourceKey] = [.nameKey, .isDirectoryKey]
            
            if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: properties, options: [.skipsHiddenFiles]) {
                for contentURL in contents {
                    if let child = createAsset(from: contentURL) {
                        children.append(child)
                    }
                }
            }
            return Asset(type: .folder, name: name, children: children)
        } else {
            let type = UTType(filenameExtension: url.pathExtension) ?? .content
            if type.conforms(to: .image) {
                if let data = try? Data(contentsOf: url) {
                    return Asset(type: .image, imageData: data, name: name)
                }
            } else if type.conforms(to: .text) || type.conforms(to: .plainText) || type.conforms(to: .sourceCode) {
                if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                    return Asset(type: .text, textContent: text, name: name)
                }
            }
        }
        return nil
    }
}

struct DropViewDelegate: DropDelegate {
    let destinationItem: Asset
    let assets: [Asset]
    @Binding var draggingItem: Asset?
    let store: AssetStore
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != destinationItem.id else { return }
        
        // Swap creation dates to reorder
        let tempDate = draggingItem.creationDate
        draggingItem.creationDate = destinationItem.creationDate
        destinationItem.creationDate = tempDate
    }
}

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
