import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @EnvironmentObject var themeSettings: ThemeSettings
    
    @State private var selectedTab = 0
    @State private var pendingCount = 0
    
    private let queueStorage = SharedQueueStorage.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Review Tab
            ReviewTabView(onAppear: refreshPendingCount)
                .tabItem {
                    Label("Review", systemImage: "tray.full.fill")
                }
                .tag(1)
                .badge(pendingCount > 0 ? pendingCount : 0)
            
            // Budget Tab
            BudgetTabView()
                .tabItem {
                    Label("Budget", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            // Settings Tab
            SettingsTabView(onMappingsChanged: recategorizeAllExpenses)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .onAppear {
            refreshPendingCount()
            configureBadgeAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshPendingCount()
        }
    }
    
    private func configureBadgeAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Set badge background color to black (matches icon color)
        let badgeColor = UIColor.black
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = badgeColor
        appearance.stackedLayoutAppearance.selected.badgeBackgroundColor = badgeColor
        appearance.inlineLayoutAppearance.normal.badgeBackgroundColor = badgeColor
        appearance.inlineLayoutAppearance.selected.badgeBackgroundColor = badgeColor
        appearance.compactInlineLayoutAppearance.normal.badgeBackgroundColor = badgeColor
        appearance.compactInlineLayoutAppearance.selected.badgeBackgroundColor = badgeColor
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func refreshPendingCount() {
        pendingCount = queueStorage.pendingCount()
    }
    
    private func recategorizeAllExpenses() {
        let parser = SMSParser(mappingStorage: MappingStorage.shared)
        for expense in expenses {
            let (biller, category) = parser.detectBillerAndCategory(in: expense.rawSMS)
            expense.biller = biller
            expense.category = category
        }
        try? modelContext.save()
    }
}

// MARK: - Review Tab Wrapper
struct ReviewTabView: View {
    let onAppear: () -> Void
    
    var body: some View {
        NavigationStack {
            ReviewContentView()
                .onAppear {
                    onAppear()
                }
        }
    }
}

// MARK: - Settings Tab Wrapper
struct SettingsTabView: View {
    let onMappingsChanged: () -> Void
    
    var body: some View {
        NavigationStack {
            AdminContentView(onMappingsChanged: onMappingsChanged)
        }
    }
}


#Preview {
    MainTabView()
        .environmentObject(ThemeSettings.shared)
}
