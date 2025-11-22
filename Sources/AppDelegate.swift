import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var floatingPanel: FloatingPanel!
    var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock Icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup SwiftData
        do {
            modelContainer = try ModelContainer(for: Asset.self)
        } catch {
            print("Failed to create ModelContainer: \(error)")
            // Fallback or alert could go here. For now, we just won't have persistence.
        }
        
        // Setup Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clip")
            button.action = #selector(togglePanel)
        }
        
        // Setup Floating Panel
        createFloatingPanel()
    }
    
    private func createFloatingPanel() {
        let contentView = ContentView()
        
        // Inject container if it exists
        let viewWithModel: AnyView
        if let container = modelContainer {
             viewWithModel = AnyView(contentView.modelContainer(container))
        } else {
             viewWithModel = AnyView(contentView)
        }
        
        let hostingController = NSHostingController(rootView: viewWithModel)
        
        floatingPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 750),
            backing: .buffered,
            defer: false
        )
        
        floatingPanel.contentViewController = hostingController
        floatingPanel.center()
    }
    
    @objc func togglePanel() {
        if floatingPanel.isVisible {
            floatingPanel.orderOut(nil)
        } else {
            // Position near the mouse or status item if possible, otherwise center
            // For MVP, just center or keep last position
            floatingPanel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
