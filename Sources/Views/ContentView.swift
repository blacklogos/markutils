import SwiftUI

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @State private var selectedTab = 0
    @State private var isPinned = true
    @State private var socialInput = ""
    @State private var showOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
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
            // Custom Header
            VStack(spacing: 12) {
                // Top Row: Window Controls | Title | Pin
                HStack {
                    // Traffic Lights (Handled by System)
                    Spacer()
                        .frame(width: 60) // Placeholder for system controls
                    
                    Spacer()
                    
                    // Title
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .font(.headline)
                        Text("Clip")
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Pin Button
                    Button(action: togglePin) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                            .foregroundStyle(isPinned ? .blue : .secondary)
                            .frame(width: 24, height: 24)
                            .background(isPinned ? Color.blue.opacity(0.1) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isPinned ? "Unpin from top" : "Pin to top")
                }
                
                // Tab Navigation
            Picker("Tabs", selection: $selectedTab) {
                Text("Assets").tag(0)
                Text("Transform").tag(1)
                Text("Text Formatter").tag(2)
                Text("AI").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            }
            .padding(12)
            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            .background(WindowDragView()) // Make header draggable
            
            Divider()
            
            // Content Area
            Group {
                switch selectedTab {
                case 0:
                    AssetGridView()
                case 1:
                    TransformerView()
                case 2:
                    SocialMediaFormatterView(text: $socialInput)
                case 3:
                    AIView()
                default:
                    Text("Unknown Tab")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
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
