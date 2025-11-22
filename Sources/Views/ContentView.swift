import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clip")
                    .font(.headline)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                ZStack {
                    WindowDragView()
                    Color.clear.background(.ultraThinMaterial)
                }
            )
            
            TabView {
                AssetGridView()
                    .tabItem {
                        Label("Assets", systemImage: "photo.stack")
                    }
                
                TransformerView()
                    .tabItem {
                        Label("Transform", systemImage: "arrow.left.arrow.right")
                    }
            }
        }
        .frame(width: 550, height: 750)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
