import SwiftUI
import SwiftData
import AppIntents

@main
struct KharchaApp: App {
    @StateObject private var themeSettings = ThemeSettings.shared
    
    let modelContainer: ModelContainer
    
    init() {
        // Force Siri to update shortcuts on app launch
        KharchaShortcuts.updateAppShortcutParameters()
        
        // Setup SwiftData container
        do {
            let schema = Schema([BillerMapping.self, Expense.self, Budget.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            
            // Seed default billers on first launch
            seedDefaultBillers()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .tint(themeSettings.accentColor.color)
                .environmentObject(themeSettings)
        }
        .modelContainer(modelContainer)
    }
    
    @MainActor
    private func seedDefaultBillers() {
        let context = modelContainer.mainContext
        
        // Configure MappingStorage with the container
        MappingStorage.shared.configure(with: modelContainer)
        
        // Check if already seeded
        let descriptor = FetchDescriptor<BillerMapping>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        
        guard existingCount == 0 else { return }
        
        // Insert default billers
        for defaultBiller in BillerMapping.defaults {
            let mapping = BillerMapping(biller: defaultBiller.biller, category: defaultBiller.category)
            context.insert(mapping)
        }
        
        try? context.save()
        
        // Refresh mappings after seeding
        MappingStorage.shared.refreshMappings()
    }
}
