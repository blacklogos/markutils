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
                                        .onDrag {
                                            draggingAsset = folder
                                            return createItemProvider(for: folder)
                                        }
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
                                        .onDrag {
                                            draggingAsset = folder
                                            return createItemProvider(for: folder)
                                        }
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
        } else if asset.type == .folder {
            // Create a temporary directory for the folder
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let folderURL = tempDir.appendingPathComponent(asset.name ?? "Folder")
            
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                exportAsset(asset, to: tempDir)
                
                provider.registerFileRepresentation(forTypeIdentifier: UTType.folder.identifier, fileOptions: [], visibility: .all) { completion in
                    completion(folderURL, true, nil)
                    return nil
                }
            } catch {
                print("Failed to create temporary folder: \(error)")
            }
        }
        
        return provider
    }

    private func exportAsset(_ asset: Asset, to directory: URL) {
        let fileURL = directory.appendingPathComponent(asset.name ?? "Untitled")
        
        if asset.type == .folder {
             do {
                 try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
                 if let children = asset.children {
                     for child in children {
                         exportAsset(child, to: fileURL)
                     }
                 }
             } catch {
                 print("Failed to create directory \(fileURL.path): \(error)")
             }
        } else if asset.type == .image, let data = asset.imageData {
            // Ensure extension
            let imageURL = fileURL.pathExtension.isEmpty ? fileURL.appendingPathExtension("png") : fileURL
            try? data.write(to: imageURL)
        } else if asset.type == .text, let text = asset.textContent {
             let textURL = fileURL.pathExtension.isEmpty ? fileURL.appendingPathExtension("txt") : fileURL
            try? text.write(to: textURL, atomically: true, encoding: .utf8)
        }
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
