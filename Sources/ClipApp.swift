import SwiftUI

@main
struct ClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = AssetStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(width: 600, height: 475)
                .fixedSize() // Prevent resizing
        }
        .windowResizability(.contentSize) // Lock window size to content
    }
}
