import SwiftUI

@main
struct ClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar-only app — all windows managed by AppDelegate/FloatingPanel.
        // Settings scene satisfies the Scene requirement without creating a visible window.
        Settings { EmptyView() }
    }
}
