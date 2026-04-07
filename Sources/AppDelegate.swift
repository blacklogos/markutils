import SwiftUI
import UniformTypeIdentifiers

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
        menu.addItem(NSMenuItem(title: "Export Vault…", action: #selector(exportVault), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "Import Vault…", action: #selector(importVault), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "u"))
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

        // Auto-check for updates on launch (silent — only shows alert if update found)
        Task {
            if let release = await UpdateChecker.shared.checkForUpdate() {
                await MainActor.run { showUpdateAlert(release) }
            }
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
    
    // MARK: - Update

    @objc func checkForUpdates() {
        Task {
            if let release = await UpdateChecker.shared.checkForUpdate() {
                await MainActor.run { showUpdateAlert(release) }
            } else {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "You're up to date"
                    alert.informativeText = "Clip \(UpdateChecker.shared.currentVersion) is the latest version."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func showUpdateAlert(_ release: UpdateChecker.Release) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Clip \(release.version) is available (you have \(UpdateChecker.shared.currentVersion))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = release.dmgURL ?? release.htmlURL
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Export / Import

    @objc func exportVault() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "clip-backup-\(formattedDate()).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(AssetStore.shared.assets)
            try data.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    @objc func importVault() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Confirm replacement
        let confirm = NSAlert()
        confirm.messageText = "Replace Vault?"
        confirm.informativeText = "This will replace all current assets with the imported data. This cannot be undone."
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Replace")
        confirm.addButton(withTitle: "Cancel")

        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        do {
            let data = try Data(contentsOf: url)
            let assets = try JSONDecoder().decode([Asset].self, from: data)
            AssetStore.shared.assets = assets
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = "Invalid backup file: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func formattedDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        return fmt.string(from: Date())
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
