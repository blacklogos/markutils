import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var floatingPanel: FloatingPanel!
    var window: NSWindow!
    var mouseShakeDetector: MouseShakeDetector!

    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkSingleInstance()
        
        // Hide Dock Icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clip")
            button.action = #selector(togglePanel)
            // Right click to show menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup Menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Clip", action: #selector(togglePanel), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        
        // Theme Submenu
        let themeMenu = NSMenu()
        themeMenu.addItem(NSMenuItem(title: "System", action: #selector(setThemeSystem), keyEquivalent: ""))
        themeMenu.addItem(NSMenuItem(title: "Light", action: #selector(setThemeLight), keyEquivalent: ""))
        themeMenu.addItem(NSMenuItem(title: "Dark", action: #selector(setThemeDark), keyEquivalent: ""))
        
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Send Feedback", action: #selector(sendFeedback), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Setup Floating Panel
        createFloatingPanel()
        
        // Setup Mouse Shake Detector
        mouseShakeDetector = MouseShakeDetector()
        mouseShakeDetector.onShake = { [weak self] in
            self?.showPanel()
        }
        mouseShakeDetector.startMonitoring()
    }
    
    private func createFloatingPanel() {
        let contentView = ContentView()
        
        // Inject container if it exists
        // Inject container if it exists
        let viewWithModel = AnyView(contentView.environment(AssetStore.shared))
        
        let hostingController = NSHostingController(rootView: viewWithModel)
        
        floatingPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 750),
            backing: .buffered,
            defer: false
        )
        
        floatingPanel.contentViewController = hostingController
        floatingPanel.center()
        floatingPanel.delegate = self // Set delegate to handle closing
        floatingPanel.isReleasedWhenClosed = false // Don't release memory when closed
    }
    
    @objc func togglePanel() {
        // If event is right click, show menu (handled by statusItem.menu automatically if attached, 
        // but we want left click to toggle and right click to show menu. 
        // Standard NSStatusItem behavior is: if menu is set, click shows menu.
        // To have left-click toggle and right-click menu, we need a custom approach or just use the menu for everything.
        // For simplicity and standard behavior: Left click toggles, Right click (or Ctrl-click) shows context menu is harder with standard API.
        // Let's stick to: Click toggles. Right-click isn't standard for status items with custom action.
        // BUT user asked for: "click close, app still on tray, right click to close (quit)"
        // So we need a menu that is ONLY shown on right click? 
        // Actually, standard macOS behavior: Left click = Action, Right click = Menu is not default.
        // Let's try to detect the event in the action.
        
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            if floatingPanel.isVisible {
                floatingPanel.orderOut(nil)
            } else {
                floatingPanel.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func setThemeSystem() { UserDefaults.standard.set("System", forKey: "appTheme") }
    @objc func setThemeLight() { UserDefaults.standard.set("Light", forKey: "appTheme") }
    @objc func setThemeDark() { UserDefaults.standard.set("Dark", forKey: "appTheme") }
    
    @objc func sendFeedback() {
        let email = "mtri.vo@gmail.com"
        let subject = "Clip App Feedback"
        let body = "Hi there,\n\nI have some feedback for Clip:\n\n"
        
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // NSWindowDelegate - Handle window closing (red x button)
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of closing
        sender.orderOut(nil)
        return false // Return false to prevent actual closing
    }
    
    func showPanel() {
        if !floatingPanel.isVisible {
            floatingPanel.makeKeyAndOrderFront(nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    private func checkSingleInstance() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        
        if runningApps.count > 1 {
            // Found another instance
            // Activate the other instance(s)
            for app in runningApps where app != NSRunningApplication.current {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            
            // Terminate this instance
            NSApp.terminate(nil)
        }
    }
}
