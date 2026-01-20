import SwiftUI

@main
struct ClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = AssetStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 800, height: 600)
    }
}
