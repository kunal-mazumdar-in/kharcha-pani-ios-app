import SwiftUI

// Apple UI Kit - Native iOS Design System
// Uses system colors that automatically adapt to light/dark mode
struct AppTheme {
    // All expense categories (single source of truth)
    static let allCategories = [
        "Housing & Rent",
        "Utilities",
        "Groceries",
        "Food & Dining",
        "Transport & Fuel",
        "Shopping",
        "Medical & Healthcare",
        "Entertainment",
        "Subscriptions",
        "Bills & Recharge",
        "Insurance",
        "Debt & EMI",
        "Investments",
        "Education & Learning",
        "Business Operations",
        "Marketing & Ads",
        "Inventory & Supplies",
        "Professional Fees",
        "Travel & Vacation",
        "Taxes",
        "Gifts & Donations",
        "Family & Dependents",
        "Pet Care",
        "Vehicle Maintenance",
        "Banking & Fees",
        "UPI / Petty Cash",
        "Other"
    ]
    
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
        "Housing & Rent": .brown,
        "Utilities": .yellow,
        "Groceries": .mint,
        "Food & Dining": .orange,
        "Transport & Fuel": .green,
        "Shopping": .purple,
        "Medical & Healthcare": .red,
        "Entertainment": .pink,
        "Subscriptions": .cyan,
        "Bills & Recharge": .indigo,
        "Insurance": .teal,
        "Debt & EMI": Color(red: 0.8, green: 0.4, blue: 0.4),
        "Investments": Color(red: 0.2, green: 0.6, blue: 0.4),
        "Education & Learning": .blue,
        "Business Operations": .gray,
        "Marketing & Ads": Color(red: 1.0, green: 0.5, blue: 0.0),
        "Inventory & Supplies": Color(red: 0.6, green: 0.4, blue: 0.2),
        "Professional Fees": Color(red: 0.4, green: 0.4, blue: 0.6),
        "Travel & Vacation": Color(red: 0.0, green: 0.7, blue: 0.9),
        "Taxes": Color(red: 0.5, green: 0.0, blue: 0.0),
        "Gifts & Donations": Color(red: 0.9, green: 0.3, blue: 0.5),
        "Family & Dependents": Color(red: 0.6, green: 0.3, blue: 0.6),
        "Pet Care": Color(red: 0.8, green: 0.6, blue: 0.4),
        "Vehicle Maintenance": Color(red: 0.3, green: 0.3, blue: 0.3),
        "Banking & Fees": .blue,
        "UPI / Petty Cash": .pink,
        "Other": .gray
    ]
    
    static func colorForCategory(_ category: String) -> Color {
        categoryColors[category] ?? .gray
    }
    
    // SF Symbol for category
    static func iconForCategory(_ category: String) -> String {
        switch category {
        case "Housing & Rent": return "house.fill"
        case "Utilities": return "bolt.fill"
        case "Groceries": return "cart.fill"
        case "Food & Dining": return "fork.knife"
        case "Transport & Fuel": return "car.fill"
        case "Shopping": return "bag.fill"
        case "Medical & Healthcare": return "cross.case.fill"
        case "Entertainment": return "tv.fill"
        case "Subscriptions": return "play.rectangle.fill"
        case "Bills & Recharge": return "phone.fill"
        case "Insurance": return "shield.fill"
        case "Debt & EMI": return "creditcard.fill"
        case "Investments": return "chart.line.uptrend.xyaxis"
        case "Education & Learning": return "book.fill"
        case "Business Operations": return "briefcase.fill"
        case "Marketing & Ads": return "megaphone.fill"
        case "Inventory & Supplies": return "shippingbox.fill"
        case "Professional Fees": return "person.text.rectangle.fill"
        case "Travel & Vacation": return "airplane"
        case "Taxes": return "doc.text.fill"
        case "Gifts & Donations": return "gift.fill"
        case "Family & Dependents": return "figure.2.and.child.holdinghands"
        case "Pet Care": return "pawprint.fill"
        case "Vehicle Maintenance": return "wrench.and.screwdriver.fill"
        case "Banking & Fees": return "building.columns.fill"
        case "UPI / Petty Cash": return "indianrupeesign.circle.fill"
        default: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Accent Color Options (Pastel Variants)
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
        // Pastel versions of each color family
        case .blue: return Color(red: 0.64, green: 0.82, blue: 1.0)         // Pastel Blue #A2D2FF
        case .purple: return Color(red: 0.76, green: 0.69, blue: 0.88)      // Pastel Purple #C3B1E1
        case .pink: return Color(red: 1.0, green: 0.71, blue: 0.76)         // Pastel Pink #FFB6C1
        case .red: return Color(red: 1.0, green: 0.71, blue: 0.64)          // Pastel Coral #FFB4A2
        case .orange: return Color(red: 1.0, green: 0.85, blue: 0.73)       // Pastel Peach #FFD9BA
        case .yellow: return Color(red: 1.0, green: 0.96, blue: 0.73)       // Pastel Yellow #FFF5BA
        case .green: return Color(red: 0.60, green: 0.85, blue: 0.67)       // Pastel Green #98D8AA
        case .mint: return Color(red: 0.71, green: 0.92, blue: 0.84)        // Pastel Mint #B5EAD7
        case .teal: return Color(red: 0.60, green: 0.88, blue: 0.85)        // Pastel Teal #99E1D9
        case .cyan: return Color(red: 0.64, green: 0.89, blue: 0.95)        // Pastel Cyan #A3E4F1
        case .indigo: return Color(red: 0.80, green: 0.80, blue: 0.98)      // Pastel Indigo #CCCCFA
        }
    }
    
    var icon: String {
        "circle.fill"
    }
}

// MARK: - Theme Settings
class ThemeSettings: ObservableObject {
    static let shared = ThemeSettings()
    
    @AppStorage("accentColor") var accentColorRaw: String = AccentColorOption.blue.rawValue {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("isDarkMode") var isDarkMode: Bool = true {
        didSet { objectWillChange.send() }
    }
    
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
