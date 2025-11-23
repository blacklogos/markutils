import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "paperclip.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            // Intro
            VStack(spacing: 12) {
                Text("Welcome to Clip")
                    .font(.largeTitle)
                    .bold()
                
                Text("Your essential menu bar companion for\nassets, transformations, and writing.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                hasSeenOnboarding = true
                isPresented = false
            }) {
                Text("Start Using Clip")
                    .font(.headline)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(width: 400, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
