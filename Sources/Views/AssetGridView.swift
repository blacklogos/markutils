import SwiftUI
import UniformTypeIdentifiers

struct AssetGridView: View {
    @Environment(AssetStore.self) private var store

    @State private var searchText = ""
    @State private var draggingAsset: Asset?
    @State private var showFileImporter = false
    @State private var isCompactMode = false

    private var allAssets: [Asset] {
        store.assets.sorted { $0.creationDate > $1.creationDate }
    }

    // Applies search filter when active — recursively searches into folder children
    private var assets: [Asset] {
        guard !searchText.isEmpty else { return allAssets }
        return Self.searchAssets(allAssets, query: searchText)
    }

    /// Recursively searches assets and their children, flattening matches into a single list.
    /// Folders that directly match are included. Non-matching folders have their matching
    /// descendants surfaced to the top level.
    static func searchAssets(_ assets: [Asset], query: String) -> [Asset] {
        let q = query.lowercased()
        var results: [Asset] = []
        for asset in assets {
            collectMatches(asset, query: q, into: &results)
        }
        return results
    }

    private static func collectMatches(_ asset: Asset, query q: String, into results: inout [Asset]) {
        let selfMatches =
            (asset.name?.lowercased().contains(q) ?? false) ||
            (asset.textContent?.lowercased().contains(q) ?? false)

        if selfMatches {
            results.append(asset)
            return
        }

        if asset.type == .folder, let children = asset.children {
            for child in children {
                collectMatches(child, query: q, into: &results)
            }
        }
    }

    // Filtered sections
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
                Button(action: pasteAsPNG) {
                    Label("Paste PNG", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

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

            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search assets…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppColors.toolbarBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
            .padding(.horizontal)
            .padding(.bottom, 6)
            
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
                if store.assets.isEmpty {
                    ContentUnavailableView("No Assets", systemImage: "square.stack.3d.up.slash", description: Text("Drag and drop files here,\npaste content, or click Add Files"))
                } else if assets.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
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
                .background(AppColors.windowBackground.opacity(0.9))
                .cornerRadius(4)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(AppColors.windowBackground) // Sticky header background
    }
    
    private func createItemProvider(for asset: Asset) -> NSItemProvider {
        let provider = NSItemProvider()
        
        if asset.type == .image, let data = asset.imageData {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
        } else if asset.type == .text, let text = asset.textContent {
            // Register SVG type for drag-out to design tools
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<svg") || trimmed.hasPrefix("<?xml") {
                provider.registerDataRepresentation(forTypeIdentifier: "public.svg-image", visibility: .all) { completion in
                    completion(text.data(using: .utf8), nil)
                    return nil
                }
            }
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
    
    private func pasteAsPNG() {
        let pb = NSPasteboard.general
        guard let objects = pb.readObjects(forClasses: [NSImage.self], options: nil),
              let image = objects.first as? NSImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]),
              !png.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Nothing to paste"
            alert.informativeText = "Clipboard doesn't contain an image."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }
        let asset = Asset(type: .image, imageData: png, name: "Pasted Image")
        store.add(asset)
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
                    let ext = url.pathExtension.lowercased()
                    return Asset(type: .text, textContent: text, name: name, fileFormat: ext.isEmpty ? nil : ext)
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
    @State private var isRenaming = false
    @State private var editName = ""
    @State private var confirmDelete = false

    private var displayName: String {
        asset.name ?? (asset.type == .text ? String(asset.textContent?.prefix(20) ?? "Text") : "Image")
    }

    // Clipboard history items show a clock overlay badge
    private var isClipboardItem: Bool {
        asset.name?.hasPrefix("Clipboard ") == true
    }

    private var isMarkdownAsset: Bool {
        guard asset.type == .text else { return false }
        let fmt = asset.fileFormat ?? ""
        return fmt == "md" || fmt == "markdown"
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
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

                // Clipboard badge
                if isClipboardItem {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.gray.opacity(0.7))
                        .clipShape(Circle())
                        .padding(4)
                }

                // Markdown badge
                if isMarkdownAsset {
                    Text("MD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(4)
                }

                // Hover overlay
                if isHovering {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 80, height: 80)

                        VStack {
                            HStack {
                                Spacer()
                                Button { confirmDelete = true } label: {
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
            .frame(width: 80, height: 80)

            // Name label / rename field
            if isRenaming {
                TextField("Name", text: $editName)
                    .textFieldStyle(.plain)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 80)
                    .onTapGesture(count: 2) { startRename() }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy") { copyAsset() }
            if isSVGAsset {
                Button("Copy as SVG") { copyAsset() }
            }
            if isMarkdownAsset {
                Button("Preview Rendered") {
                    if let text = asset.textContent {
                        MarkdownPreviewRouter.shared.request(text)
                    }
                }
            }
            Divider()
            Button("Rename") { startRename() }
            Button("Delete", role: .destructive) { confirmDelete = true }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .alert("Delete asset?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { deleteAsset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func startRename() {
        editName = asset.name ?? displayName
        isRenaming = true
    }

    private func commitRename() {
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { asset.name = trimmed }
        store.save()
        isRenaming = false
    }

    private var isSVGAsset: Bool {
        guard asset.type == .text, let text = asset.textContent else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<svg") || trimmed.hasPrefix("<?xml")
    }

    private func copyAsset() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if asset.type == .image, let data = asset.imageData {
            pasteboard.setData(data, forType: .png)
        } else if asset.type == .text, let text = asset.textContent {
            if isSVGAsset {
                pasteboard.setString(text, forType: NSPasteboard.PasteboardType("public.svg-image"))
            }
            pasteboard.setString(text, forType: .string)
        }

        withAnimation { showCopiedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopiedFeedback = false }
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
    @State private var isRenaming = false
    @State private var editName = ""
    @State private var confirmDelete = false

    private var isClipboardItem: Bool { asset.name?.hasPrefix("Clipboard ") == true }

    var body: some View {
        HStack {
            // Icon/Thumbnail
            ZStack(alignment: .bottomTrailing) {
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
                if isClipboardItem {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(Color.gray.opacity(0.7))
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }

            // Name/Content Preview — double-click to rename
            if isRenaming {
                TextField("Name", text: $editName)
                    .textFieldStyle(.plain)
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(assetName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) { startRename() }
            }

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

                    Button { confirmDelete = true } label: {
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
        .alert("Delete asset?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { deleteAsset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var assetName: String {
        if let name = asset.name { return name }
        if let text = asset.textContent { return text.prefix(50).replacingOccurrences(of: "\n", with: " ") }
        return "Asset"
    }

    private func startRename() {
        editName = assetName
        isRenaming = true
    }

    private func commitRename() {
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { asset.name = trimmed }
        store.save()
        isRenaming = false
    }
    
    private var isSVGAsset: Bool {
        guard asset.type == .text, let text = asset.textContent else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<svg") || trimmed.hasPrefix("<?xml")
    }

    private func copyAsset() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if asset.type == .image, let data = asset.imageData {
            pasteboard.setData(data, forType: .png)
        } else if asset.type == .text, let text = asset.textContent {
            if isSVGAsset {
                pasteboard.setString(text, forType: NSPasteboard.PasteboardType("public.svg-image"))
            }
            pasteboard.setString(text, forType: .string)
        }

        withAnimation { showCopiedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopiedFeedback = false }
        }
    }

    private func deleteAsset() {
        withAnimation {
            store.delete(asset)
        }
    }
}
