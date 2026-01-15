import SwiftUI

// Apple UI Kit - Native iOS Design System
// Uses system colors that automatically adapt to light/dark mode
struct AppTheme {
    // System-adaptive colors
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    
    // Text colors - automatically adapt
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    
    // Semantic colors
    static let destructive = Color.red
    static let success = Color.green
    
    // Separator
    static let separator = Color(.separator)
    
    // Category colors - Vibrant iOS-style colors
    static let categoryColors: [String: Color] = [
        "Banking": .blue,
        "Food": .orange,
        "Transport": .green,
        "Shopping": .purple,
        "Groceries": .mint,
        "UPI": .pink,
        "Bills": .yellow,
        "Entertainment": .cyan,
        "Medical": .red,
        "Other": .gray
    ]
    
    static func colorForCategory(_ category: String) -> Color {
        categoryColors[category] ?? .gray
    }
    
    // SF Symbol for category
    static func iconForCategory(_ category: String) -> String {
        switch category {
        case "Banking": return "building.columns.fill"
        case "Food": return "fork.knife"
        case "Transport": return "car.fill"
        case "Shopping": return "bag.fill"
        case "Groceries": return "cart.fill"
        case "UPI": return "indianrupeesign.circle.fill"
        case "Bills": return "doc.text.fill"
        case "Entertainment": return "tv.fill"
        case "Medical": return "cross.case.fill"
        default: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Accent Color Options
enum AccentColorOption: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case mint = "Mint"
    case teal = "Teal"
    case cyan = "Cyan"
    case indigo = "Indigo"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .indigo: return .indigo
        }
    }
    
    var icon: String {
        "circle.fill"
    }
}

// MARK: - Theme Settings
class ThemeSettings: ObservableObject {
    static let shared = ThemeSettings()
    
    @AppStorage("accentColor") var accentColorRaw: String = AccentColorOption.blue.rawValue
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
    
    var accentColor: AccentColorOption {
        get { AccentColorOption(rawValue: accentColorRaw) ?? .blue }
        set { accentColorRaw = newValue.rawValue }
    }
    
    var colorScheme: ColorScheme? {
        isDarkMode ? .dark : nil  // nil means follow system
    }
}

// MARK: - Currency Formatter
extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "₹0"
    }
    
    var compactFormatted: String {
        if self >= 100000 {
            return String(format: "₹%.1fL", self / 100000)
        } else if self >= 1000 {
            return String(format: "₹%.1fK", self / 1000)
        } else {
            return String(format: "₹%.0f", self)
        }
    }
}
