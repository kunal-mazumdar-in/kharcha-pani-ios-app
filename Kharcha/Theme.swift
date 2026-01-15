import SwiftUI

// Netflix-inspired dark theme
struct AppTheme {
    // Backgrounds
    static let background = Color(hex: "141414")
    static let cardBackground = Color(hex: "1F1F1F")
    static let cardBackgroundLight = Color(hex: "2A2A2A")
    
    // Accent
    static let accent = Color(hex: "E50914")
    static let accentLight = Color(hex: "FF3D47")
    
    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "B3B3B3")
    static let textMuted = Color(hex: "737373")
    
    // Category colors (pastel dark variants)
    static let categoryColors: [String: Color] = [
        "Banking": Color(hex: "4A90D9"),
        "Food": Color(hex: "E87D3E"),
        "Transport": Color(hex: "50C878"),
        "Shopping": Color(hex: "9B59B6"),
        "Groceries": Color(hex: "27AE60"),
        "UPI": Color(hex: "E84393"),
        "Bills": Color(hex: "F39C12"),
        "Entertainment": Color(hex: "1ABC9C"),
        "Medical": Color(hex: "E74C3C"),
        "Other": Color(hex: "7F8C8D")
    ]
    
    static func colorForCategory(_ category: String) -> Color {
        categoryColors[category] ?? Color(hex: "7F8C8D")
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

