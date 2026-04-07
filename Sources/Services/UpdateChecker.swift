import Foundation

/// Checks GitHub Releases for a newer version and provides a download URL.
/// No automatic installation — just notifies and offers a link.
final class UpdateChecker: @unchecked Sendable {
    static let shared = UpdateChecker()

    private let owner = "blacklogos"
    private let repo = "markutils"

    /// The current app version from the build script (kept in sync manually).
    let currentVersion = "1.3.0"

    struct Release {
        let tagName: String
        let version: String
        let htmlURL: URL
        let dmgURL: URL?
    }

    /// Fetches the latest GitHub release. Returns `nil` if already up-to-date or on error.
    func checkForUpdate() async -> Release? {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let htmlURLString = json["html_url"] as? String,
              let htmlURL = URL(string: htmlURLString) else {
            return nil
        }

        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        guard isNewer(version, than: currentVersion) else { return nil }

        // Find DMG asset in the release
        var dmgURL: URL? = nil
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                   let downloadURL = asset["browser_download_url"] as? String {
                    dmgURL = URL(string: downloadURL)
                    break
                }
            }
        }

        return Release(tagName: tagName, version: version, htmlURL: htmlURL, dmgURL: dmgURL)
    }

    /// Semantic version comparison: returns true if `a` is newer than `b`.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        let count = max(partsA.count, partsB.count)
        for i in 0..<count {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }
}
