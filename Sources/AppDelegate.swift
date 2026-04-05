import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var floatingPanel: FloatingPanel!
    var window: NSWindow!
    var mouseShakeDetector: MouseShakeDetector!

    private var globalHotkeyMonitor: Any?
    private var clipboardHistoryMenuItem: NSMenuItem?

    
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

        // Clipboard History toggle
        let cbEnabled = ClipboardMonitor.shared.isEnabled
        let cbItem = NSMenuItem(
            title: cbEnabled ? "Clipboard History: On" : "Clipboard History: Off",
            action: #selector(toggleClipboardHistory),
            keyEquivalent: ""
        )
        cbItem.state = cbEnabled ? .on : .off
        menu.addItem(cbItem)
        clipboardHistoryMenuItem = cbItem

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

        // Global hotkey: Cmd+Shift+C (keyCode 8 = C)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.command, .shift],
                  event.keyCode == 8 else { return }
            DispatchQueue.main.async { self?.togglePanel() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        ClipboardMonitor.shared.stopMonitoring()
    }
    
    private func createFloatingPanel() {
        let contentView = ContentView()
        
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
        // Left click toggles the panel; right click shows the context menu.
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
    
    @objc func toggleClipboardHistory() {
        ClipboardMonitor.shared.isEnabled.toggle()
        let enabled = ClipboardMonitor.shared.isEnabled
        clipboardHistoryMenuItem?.title = enabled ? "Clipboard History: On" : "Clipboard History: Off"
        clipboardHistoryMenuItem?.state = enabled ? .on : .off
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func setThemeSystem() { UserDefaults.standard.set("System", forKey: "appTheme") }
    @objc func setThemeLight() { UserDefaults.standard.set("Light", forKey: "appTheme") }
    @objc func setThemeDark() { UserDefaults.standard.set("Dark", forKey: "appTheme") }
    
    @objc func sendFeedback() {
        if let url = URL(string: "https://github.com/blacklogos/markutils/issues") {
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
