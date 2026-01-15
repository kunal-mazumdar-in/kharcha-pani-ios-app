import SwiftUI

struct SplashScreenView: View {
    @State private var isPounding = false
    @State private var isActive = false
    
    // Primary blue #2196F3
    private let primaryBlue = Color(red: 33/255, green: 150/255, blue: 243/255)
    
    var body: some View {
        Group {
            if isActive {
                MainTabView()
            } else {
                ZStack {
                    // Glassmorphic background with #2196F3 blue tones
                    LinearGradient(
                        colors: [
                            Color(red: 13/255, green: 71/255, blue: 161/255),   // Blue 900
                            Color(red: 21/255, green: 101/255, blue: 192/255),  // Blue 800
                            primaryBlue,                                         // #2196F3
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    // Large blurred orb - top left
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 350, height: 350)
                        .blur(radius: 60)
                        .offset(x: -120, y: -250)
                    
                    // Medium blurred orb - bottom right
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    primaryBlue.opacity(0.6),
                                    primaryBlue.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 50)
                        .offset(x: 100, y: 200)
                    
                    // Small accent orb - top right
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 100/255, green: 181/255, blue: 246/255).opacity(0.5), // Blue 300
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                        .offset(x: 100, y: -320)
                    
                    // App name
                    Text("Expense Ginie")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .scaleEffect(isPounding ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: isPounding
                        )
                }
                .onAppear {
                    isPounding = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isActive = true
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(ThemeSettings.shared)
}
