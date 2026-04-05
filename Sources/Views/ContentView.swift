import SwiftUI

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @State private var selectedTab = 0
    @State private var isPinned = true
    @State private var socialInput = ""
    @State private var showOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var snippetStore = SnippetStore.shared
    
    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        
        var id: String { rawValue }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compressed single-row header: tabs left, spacer (draggable), controls right
            HStack(spacing: 8) {
                // Spacer for traffic-light buttons (macOS injects them on the left)
                Spacer().frame(width: 72)

                Picker("Tabs", selection: $selectedTab) {
                    Image(systemName: "square.grid.2x2")  .tag(0).help("Assets")
                    Image(systemName: "arrow.left.arrow.right").tag(1).help("Transform")
                    Image(systemName: "textformat.abc")   .tag(2).help("Text Formatter")
                    Image(systemName: "doc.text")         .tag(3).help("Snippets")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Spacer() // draggable gap

                // Theme cycle: system → light → dark → system
                Button(action: cycleTheme) {
                    Image(systemName: themeIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Theme: \(appTheme.rawValue) — click to cycle")

                // Pin button
                Button(action: togglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(isPinned ? AppColors.accent : .secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin from top" : "Pin to top")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.toolbarBackground)
            .background(WindowDragView()) // Make header draggable
            
            Divider()
            
            // Content Area
            Group {
                switch selectedTab {
                case 0:
                    AssetGridView()
                case 1:
                    QuickActionsView()
                case 2:
                    SocialMediaFormatterView(text: $socialInput)
                case 3:
                    SnippetsView()
                        .environment(snippetStore)
                default:
                    Text("Unknown Tab")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.windowBackground)
        .edgesIgnoringSafeArea(.top)
        .preferredColorScheme(appTheme.colorScheme)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .background(WindowAccessor { window in
            guard let window = window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        })
    }
    
    private func togglePin() {
        isPinned.toggle()
        if let window = NSApp.mainWindow {
            window.level = isPinned ? .floating : .normal
        }
    }

    private func cycleTheme() {
        switch appTheme {
        case .system: appTheme = .light
        case .light:  appTheme = .dark
        case .dark:   appTheme = .system
        }
    }

    private var themeIcon: String {
        switch appTheme {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}

struct CircleButton: View {
    let color: Color
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Group {
                        if isHovering {
                            Image(systemName: iconName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black.opacity(0.5))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var iconName: String {
        switch color {
        case .red: return "xmark"
        case .yellow: return "minus"
        case .green: return "plus" // Arrows usually, but plus is fine for zoom
        default: return ""
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
