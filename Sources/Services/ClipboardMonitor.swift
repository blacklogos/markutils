import Foundation
import AppKit
import Observation

// Polls NSPasteboard every 1s and saves new clipboard items as Assets.
// Cap: 50 items. Toggle via ClipboardMonitor.shared.isEnabled.
@Observable
class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "clipboardHistoryEnabled")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let maxItems = 50

    private init() {
        let stored = UserDefaults.standard.bool(forKey: "clipboardHistoryEnabled")
        self.isEnabled = stored
        if stored { startMonitoring() }
    }

    private func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let store = AssetStore.shared
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)

        // Prune oldest clipboard items if at cap
        let clipItems = store.assets.filter { $0.name?.hasPrefix("Clipboard ") == true }
        if clipItems.count >= maxItems {
            let toRemove = clipItems.sorted { $0.creationDate < $1.creationDate }
                .prefix(clipItems.count - maxItems + 1)
            for item in toRemove { store.delete(item) }
        }

        let pb = NSPasteboard.general
        if let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let asset = Asset(type: .text, textContent: text, name: "Clipboard \(timestamp)")
            store.add(asset)
        } else if let data = pb.data(forType: NSPasteboard.PasteboardType("public.png"))
                    ?? pb.data(forType: NSPasteboard.PasteboardType("public.tiff")),
                  let image = NSImage(data: data) {
            let pngData: Data
            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                pngData = png
            } else {
                pngData = data
            }
            let asset = Asset(type: .image, imageData: pngData, name: "Clipboard \(timestamp)")
            store.add(asset)
        }
    }

    deinit {
        stopMonitoring()
    }
}
