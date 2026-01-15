import SwiftUI

struct MainTabView: View {
    @StateObject private var expenseStorage = ExpenseStorage()
    @StateObject private var mappingStorage = MappingStorage.shared
    @EnvironmentObject var themeSettings: ThemeSettings
    
    @State private var selectedTab = 0
    @State private var pendingCount = 0
    
    private let queueStorage = SharedQueueStorage.shared
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: mappingStorage)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView(
                expenseStorage: expenseStorage,
                mappingStorage: mappingStorage
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            // Review Tab
            ReviewTabView(
                expenseStorage: expenseStorage,
                mappingStorage: mappingStorage,
                onAppear: refreshPendingCount
            )
            .tabItem {
                Label("Review", systemImage: "tray.full.fill")
            }
            .tag(1)
            .badge(pendingCount > 0 ? pendingCount : 0)
            
            // Settings Tab
            SettingsTabView(
                mappingStorage: mappingStorage,
                expenseStorage: expenseStorage,
                onMappingsChanged: {
                    expenseStorage.recategorizeAll(using: parser)
                }
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
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
}

// MARK: - Review Tab Wrapper
struct ReviewTabView: View {
    @ObservedObject var expenseStorage: ExpenseStorage
    @ObservedObject var mappingStorage: MappingStorage
    let onAppear: () -> Void
    
    var body: some View {
        NavigationStack {
            ReviewContentView(
                expenseStorage: expenseStorage,
                mappingStorage: mappingStorage
            )
            .onAppear {
                onAppear()
            }
        }
    }
}

// MARK: - Settings Tab Wrapper
struct SettingsTabView: View {
    @ObservedObject var mappingStorage: MappingStorage
    @ObservedObject var expenseStorage: ExpenseStorage
    let onMappingsChanged: () -> Void
    
    var body: some View {
        NavigationStack {
            AdminContentView(
                mappingStorage: mappingStorage,
                expenseStorage: expenseStorage,
                onMappingsChanged: onMappingsChanged
            )
        }
    }
}


#Preview {
    MainTabView()
        .environmentObject(ThemeSettings.shared)
}

