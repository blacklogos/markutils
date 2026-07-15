import Foundation
import Observation

@Observable
class AssetStore {
    static let shared = AssetStore()
    var assets: [Asset] = [] {
        didSet {
            scheduleSave()
        }
    }

    private let fileURL: URL
    // Serial queue keeps writes ordered; the work item is the debounce handle.
    @ObservationIgnored private let saveQueue = DispatchQueue(label: "clip.assetstore.save", qos: .utility)
    @ObservationIgnored private var pendingSave: DispatchWorkItem?

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
    // Removes any prior .bak first — copyItem won't overwrite, so without this
    // the "backup" would silently remain a stale earlier import.
    func backupAndImport(_ newAssets: [Asset]) {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            let backupURL = fileURL.appendingPathExtension("bak")
            try? fm.removeItem(at: backupURL)
            try? fm.copyItem(at: fileURL, to: backupURL)
        }
        assets = newAssets  // triggers save via didSet
    }

    /// Call after mutating an asset's properties (name, etc.) to persist the change.
    /// Debounced: bursts of mutations coalesce into one background write.
    func save() {
        scheduleSave()
    }

    /// Write any pending changes immediately (call from applicationWillTerminate).
    func flushPendingSave() {
        pendingSave?.cancel()
        pendingSave = nil
        let snapshot = assets
        // sync also drains any in-flight write so the app can't exit mid-save
        saveQueue.sync { self.persist(snapshot) }
    }

    // Full-vault JSON can be tens of MB with inline image data, so each mutation
    // must not encode+write synchronously on main. Snapshot on the mutating
    // (main) thread, then encode and write once per 500ms burst off main.
    private func scheduleSave() {
        pendingSave?.cancel()
        let snapshot = assets
        let work = DispatchWorkItem { [weak self] in
            self?.persist(snapshot)
        }
        pendingSave = work
        saveQueue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func persist(_ snapshot: [Asset]) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
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
