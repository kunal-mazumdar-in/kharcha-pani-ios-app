import SwiftUI

struct AdminView: View {
    @ObservedObject var mappingStorage: MappingStorage
    @ObservedObject var expenseStorage: ExpenseStorage
    @StateObject var themeSettings = ThemeSettings.shared
    @Environment(\.dismiss) var dismiss
    
    let onMappingsChanged: () -> Void
    
    private var tintColor: Color {
        themeSettings.accentColor.color
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Theme Section
                Section("Theme") {
                    // Accent Color Picker
                    NavigationLink {
                        AccentColorPickerView(themeSettings: themeSettings)
                    } label: {
                        HStack {
                            Label {
                                Text("Accent Color")
                            } icon: {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundStyle(tintColor)
                            }
                            Spacer()
                            Circle()
                                .fill(tintColor)
                                .frame(width: 24, height: 24)
                        }
                    }
                    
                    // Dark Mode Toggle
                    Toggle(isOn: $themeSettings.isDarkMode) {
                        Label {
                            Text("Dark Mode")
                        } icon: {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(tintColor)
                        }
                    }
                    .tint(tintColor)
                }
                
                // Configuration Section
                Section("Configuration") {
                    NavigationLink {
                        BillersView(
                            mappingStorage: mappingStorage,
                            onMappingsChanged: onMappingsChanged
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Billers")
                                Text("\(mappingStorage.mappings.count) configured")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "building.2.fill")
                                .foregroundStyle(tintColor)
                        }
                    }
                }
                
                // Data Section
                Section("Data") {
                    NavigationLink {
                        DataManagementView(expenseStorage: expenseStorage)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data")
                                Text("Export, clear data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(tintColor)
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    
                    LabeledContent("Developer", value: "Kharcha Team")
                }
                
                // App Info
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(tintColor)
                        
                        Text("Kharcha")
                            .font(.headline)
                        
                        Text("Track your expenses effortlessly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .tint(tintColor)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(tintColor)
    }
}

// MARK: - Accent Color Picker View
struct AccentColorPickerView: View {
    @ObservedObject var themeSettings: ThemeSettings
    @Environment(\.dismiss) var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 70))
    ]
    
    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AccentColorOption.allCases) { option in
                        Button {
                            withAnimation {
                                themeSettings.accentColor = option
                            }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 50, height: 50)
                                    
                                    if themeSettings.accentColor == option {
                                        Image(systemName: "checkmark")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                }
                                
                                Text(option.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(themeSettings.accentColor == option ? option.color : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            } footer: {
                Text("Choose an accent color for buttons and highlights throughout the app.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeSettings.accentColor.color)
    }
}

#Preview {
    AdminView(
        mappingStorage: MappingStorage.shared,
        expenseStorage: ExpenseStorage(),
        onMappingsChanged: {}
    )
}
