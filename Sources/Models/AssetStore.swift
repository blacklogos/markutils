import Foundation
import Observation

@Observable
class AssetStore {
    static let shared = AssetStore()
    var assets: [Asset] = [] {
        didSet {
            save()
        }
    }
    
    private let fileURL: URL
    
    private init() {
        // Setup file URL
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Clip")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        self.fileURL = appDir.appendingPathComponent("assets.json")
        
        // Load initial data
        load()
    }
    
    func add(_ asset: Asset) {
        assets.append(asset)
    }
    
    func delete(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
    }

    // Backs up the current vault file before replacing in-memory assets.
    // The backup sits at <assets.json>.bak so it survives a failed import.
    func backupAndImport(_ newAssets: [Asset]) {
        let backupURL = fileURL.appendingPathExtension("bak")
        try? FileManager.default.copyItem(at: fileURL, to: backupURL)
        assets = newAssets  // triggers save via didSet
    }

    /// Call after mutating an asset's properties (name, etc.) to persist the change.
    func save() {
        do {
            let data = try JSONEncoder().encode(assets)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save assets: \(error)")
        }
    }
    
    private func load() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            assets = try JSONDecoder().decode([Asset].self, from: data)
        } catch {
            print("Failed to load assets: \(error)")
        }
    }
}
