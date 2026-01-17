import SwiftUI
import SwiftData

// MARK: - Admin Content View (for Tab)
struct AdminContentView: View {
    @Query private var billerMappings: [BillerMapping]
    @EnvironmentObject var themeSettings: ThemeSettings
    
    let onMappingsChanged: () -> Void
    
    private var tintColor: Color {
        themeSettings.accentColor.color
    }
    
    var body: some View {
        List {
            // Theme Section
            Section("Theme") {
                // Accent Color Picker
                NavigationLink {
                    AccentColorPickerView(themeSettings: themeSettings)
                } label: {
                    HStack {
                        Label {
                            Text("Color")
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
            }
            
            // Permissions Section
            Section("Permissions") {
                NavigationLink {
                    PermissionsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Permissions")
                            Text("Siri, Notifications & more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            
            // Configuration Section
            Section("Configuration") {
                NavigationLink {
                    BillersView(onMappingsChanged: onMappingsChanged)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Billers")
                            Text("\(billerMappings.count) configured")
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
                    DataManagementView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data")
                            Text("Clear data")
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
            }
            
            // App Info
            Section {
                VStack(spacing: 8) {
                    Text("Expense Ginie")
                        .font(.title2)
                        .fontWeight(.bold)
                    
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
        .scrollIndicators(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
        .scrollIndicators(.hidden)
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeSettings.accentColor.color)
    }
}

#Preview {
    NavigationStack {
        AdminContentView(onMappingsChanged: {})
            .environmentObject(ThemeSettings.shared)
    }
}
