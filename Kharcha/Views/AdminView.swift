import SwiftUI

struct AdminView: View {
    @ObservedObject var mappingStorage: MappingStorage
    @ObservedObject var expenseStorage: ExpenseStorage
    @Environment(\.dismiss) var dismiss
    
    let onMappingsChanged: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                List {
                    // Billers Section
                    Section {
                        NavigationLink(destination: BillersView(
                            mappingStorage: mappingStorage,
                            onMappingsChanged: onMappingsChanged
                        )) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(AppTheme.accent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Billers")
                                        .font(.body)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("\(mappingStorage.mappings.count) billers configured")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    } header: {
                        Text("Configuration")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    
                    // Data Management Section
                    Section {
                        NavigationLink(destination: DataManagementView(expenseStorage: expenseStorage)) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "externaldrive.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Data Management")
                                        .font(.body)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Export, import, clear data")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    } header: {
                        Text("Data")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    
                    // About Section
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    } header: {
                        Text("About")
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AdminView(
        mappingStorage: MappingStorage.shared,
        expenseStorage: ExpenseStorage(),
        onMappingsChanged: {}
    )
}

