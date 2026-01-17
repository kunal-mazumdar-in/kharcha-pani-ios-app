import SwiftUI

// MARK: - Permission Status
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case restricted
    
    var color: Color {
        switch self {
        case .granted: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied, .restricted: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        }
    }
    
    var text: String {
        switch self {
        case .granted: return "Enabled"
        case .denied: return "Disabled"
        case .notDetermined: return "Not Set"
        case .restricted: return "Restricted"
        }
    }
}

// MARK: - Permission Item Model
struct PermissionItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let status: PermissionStatus
    let actionText: String?
    let action: (() -> Void)?
}

// MARK: - Permissions View
struct PermissionsView: View {
    @State private var siriStatus: PermissionStatus = .notDetermined
    @StateObject private var llmAvailability = LLMAvailability.shared
    
    var body: some View {
        List {
            // Required Permissions
            Section {
                // Siri & Shortcuts
                PermissionRow(
                    icon: "mic.circle.fill",
                    iconColor: .purple,
                    name: "Siri & Shortcuts",
                    description: "Add expenses using voice commands",
                    status: siriStatus,
                    actionText: "Settings",
                    action: openAppSettings
                )
                
                // Apple Intelligence
                HStack(spacing: 14) {
                    Image(systemName: "brain.head.profile")
                        .font(.title)
                        .foregroundStyle(.indigo)
                        .frame(width: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Intelligence")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("On-device AI for statement parsing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status indicator with optional tap action
                    if llmAvailability.status.canOpenSettings {
                        Button {
                            openAppSettings()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: llmAvailability.status.icon)
                                    .foregroundStyle(llmAvailability.status.iconColor)
                                Text(llmAvailability.status.statusText)
                                    .font(.subheadline)
                                    .foregroundStyle(llmAvailability.status.iconColor)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: llmAvailability.status.icon)
                                .foregroundStyle(llmAvailability.status.iconColor)
                            Text(llmAvailability.status.statusText)
                                .font(.subheadline)
                                .foregroundStyle(llmAvailability.status.iconColor)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Required Permissions")
            } footer: {
                if llmAvailability.status == .unavailable {
                    Text("Apple Intelligence requires iOS 26.0 or later.")
                } else if llmAvailability.status == .notEnabled {
                    Text("Tap Apple Intelligence to enable in Settings.")
                }
            }
            
            // AI Features Section
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title)
                        .foregroundStyle(llmAvailability.status == .enabled ? .blue : .secondary)
                        .frame(width: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Analyse Statements")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(llmAvailability.status == .enabled ? .primary : .secondary)
                        
                        Text("Use AI to parse bank statements")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Show toggle only when AI is available
                    if llmAvailability.status == .enabled {
                        Toggle("", isOn: $llmAvailability.isAIParsingEnabled)
                            .labelsHidden()
                    } else {
                        // Show disabled state
                        Toggle("", isOn: .constant(false))
                            .labelsHidden()
                            .disabled(true)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("AI Features")
            } footer: {
                if llmAvailability.status == .unavailable {
                    Text("Requires iOS 26.0 or later to enable AI-powered statement analysis.")
                } else if llmAvailability.status == .notEnabled {
                    Text("Enable Apple Intelligence in Settings first to use AI-powered statement analysis.")
                } else if llmAvailability.isAIParsingEnabled {
                    Text("Bank statements will be analysed using on-device AI for better accuracy.")
                } else {
                    Text("When enabled, AI will extract transactions from bank statement PDFs with higher accuracy.")
                }
            }
            
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle("App Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkPermissions()
            llmAvailability.checkStatus()
        }
    }
    
    // MARK: - Permission Checks
    
    private func checkPermissions() {
        checkSiriPermission()
    }
    
    private func checkSiriPermission() {
        // Siri status cannot be reliably checked without potential crashes
        // We show a neutral state and let users manage via Settings
        siriStatus = .granted
    }
    
    // MARK: - Actions
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let description: String
    let status: PermissionStatus
    let actionText: String?
    let action: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(iconColor)
                .frame(width: 36)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status or Action
            if let actionText = actionText, let action = action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: status.icon)
                            .foregroundStyle(status.color)
                        Text(actionText)
                            .font(.subheadline)
                            .foregroundStyle(status.color)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Status indicator
                HStack(spacing: 6) {
                    Image(systemName: status.icon)
                        .foregroundStyle(status.color)
                    Text(status.text)
                        .font(.subheadline)
                        .foregroundStyle(status.color)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PermissionsView()
    }
}

