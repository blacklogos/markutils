import AppKit
import ImageIO

/// Decodes grid thumbnails once per asset and caches them, so SwiftUI body
/// re-evaluations never re-decode full bitmaps via NSImage(data:).
/// Main-thread only (called from view bodies). Keyed by asset id — imageData
/// is set once at Asset init and never mutated, so removal on delete is the
/// only invalidation needed.
final class AssetThumbnailCache {
    static let shared = AssetThumbnailCache()

    private var cache: [UUID: NSImage] = [:]

    func thumbnail(for asset: Asset) -> NSImage? {
        if let cached = cache[asset.id] { return cached }
        guard asset.type == .image,
              let data = asset.imageData,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 160,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache[asset.id] = image
        return image
    }

    func removeThumbnail(for id: UUID) {
        cache[id] = nil
    }
}
