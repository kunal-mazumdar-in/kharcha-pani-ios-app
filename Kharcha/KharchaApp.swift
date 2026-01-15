import SwiftUI

@main
struct KharchaApp: App {
    @StateObject private var themeSettings = ThemeSettings.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(themeSettings.accentColor.color)
                .preferredColorScheme(themeSettings.isDarkMode ? .dark : nil)
                .environmentObject(themeSettings)
        }
    }
}
