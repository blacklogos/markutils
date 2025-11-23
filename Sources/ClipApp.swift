import SwiftUI
import SwiftData

@main
struct ClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 600, height: 475)
                .fixedSize() // Prevent resizing
        }
        .windowResizability(.contentSize) // Lock window size to content
    }
}
