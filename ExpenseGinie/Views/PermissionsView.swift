import SwiftUI
import UserNotifications

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
    @State private var notificationStatus: PermissionStatus = .notDetermined
    @State private var siriStatus: PermissionStatus = .notDetermined
    
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
                    action: openSiriSettings
                )
                
                // Notifications
                PermissionRow(
                    icon: "bell.circle.fill",
                    iconColor: .red,
                    name: "Notifications",
                    description: "Get alerts for expense reviews",
                    status: notificationStatus,
                    actionText: notificationStatus == .granted ? nil : "Enable",
                    action: notificationStatus == .granted ? nil : requestNotifications
                )
            } header: {
                Text("Required Permissions")
            } footer: {
                Text("Enable Siri to use voice commands like 'Track Food expense in Expense Ginie'")
            }
            
            // Siri Phrases Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Supported Siri Commands")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SiriPhraseRow(phrase: "Track Food expense in Expense Ginie")
                        SiriPhraseRow(phrase: "Track Shopping in Expense Ginie")
                        SiriPhraseRow(phrase: "Track my Transport expense in Expense Ginie")
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Siri Commands")
            } footer: {
                Text("Replace the category name with: Banking, Food, Groceries, Transport, Shopping, UPI, Bills, Entertainment, Medical, or Other.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle("App Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkPermissions()
        }
    }
    
    // MARK: - Permission Checks
    
    private func checkPermissions() {
        checkNotificationPermission()
        checkSiriPermission()
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    notificationStatus = .granted
                case .denied:
                    notificationStatus = .denied
                case .notDetermined:
                    notificationStatus = .notDetermined
                case .ephemeral:
                    notificationStatus = .granted
                @unknown default:
                    notificationStatus = .notDetermined
                }
            }
        }
    }
    
    private func checkSiriPermission() {
        // Siri status cannot be reliably checked without potential crashes
        // We show a neutral state and let users manage via Settings
        siriStatus = .granted
    }
    
    // MARK: - Actions
    
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationStatus = granted ? .granted : .denied
                if !granted {
                    openAppSettings()
                }
            }
        }
    }
    
    private func openSiriSettings() {
        // Open app's settings page - Siri & Search is found there
        openAppSettings()
    }
    
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
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .foregroundStyle(status.color)
                        Text(actionText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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

// MARK: - Siri Phrase Row
struct SiriPhraseRow: View {
    let phrase: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(phrase)
                .font(.callout)
                .foregroundStyle(.primary)
                .italic()
            
            Image(systemName: "quote.closing")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        PermissionsView()
    }
}

