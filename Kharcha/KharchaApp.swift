import SwiftUI
import AppIntents

@main
struct KharchaApp: App {
    @StateObject private var themeSettings = ThemeSettings.shared
    
    init() {
        // Force Siri to update shortcuts on app launch
        KharchaShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(themeSettings.accentColor.color)
                .preferredColorScheme(themeSettings.isDarkMode ? .dark : nil)
                .environmentObject(themeSettings)
        }
    }
}
