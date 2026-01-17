import Foundation

// Common currency symbols and codes
enum DetectedCurrency: String, Codable, CaseIterable {
    case inr = "INR"  // Indian Rupee ₹
    case usd = "USD"  // US Dollar $
    case eur = "EUR"  // Euro €
    case gbp = "GBP"  // British Pound £
    case aed = "AED"  // UAE Dirham
    case sgd = "SGD"  // Singapore Dollar
    case aud = "AUD"  // Australian Dollar
    case cad = "CAD"  // Canadian Dollar
    case jpy = "JPY"  // Japanese Yen ¥
    case unknown = "Unknown"
    
    var symbol: String {
        switch self {
        case .inr: return "₹"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .aed: return "AED"
        case .sgd: return "S$"
        case .aud: return "A$"
        case .cad: return "C$"
        case .jpy: return "¥"
        case .unknown: return "?"
        }
    }
    
    var isINR: Bool {
        self == .inr
    }
}

struct ParsedSMS {
    let amount: Double
    let biller: String
    let category: String
    let date: Date
    let rawSMS: String
    let detectedCurrency: DetectedCurrency
}

@MainActor
class SMSParser {
    private let mappingStorage: MappingStorage
    
    init(mappingStorage: MappingStorage = .shared) {
        self.mappingStorage = mappingStorage
    }
    
    func parse(sms: String) -> ParsedSMS? {
        // Try SMS parsing first (bank transaction messages)
        if let (amount, currency) = extractAmountAndCurrency(from: sms), amount > 0 {
            let (biller, category) = detectBillerAndCategory(in: sms)
            let date = extractDate(from: sms) ?? Date()
            
            return ParsedSMS(
                amount: amount,
                biller: biller,
                category: category,
                date: date,
                rawSMS: sms,
                detectedCurrency: currency
            )
        }
        
        // Fallback: Try bill/receipt parsing
        return parseAsBill(text: sms)
    }
    
    // MARK: - Bill/Receipt Parsing (Fallback)
    
    /// Fallback parser for bills, receipts, and payment screenshots
    /// Handles formats like restaurant bills, retail receipts, payment app screenshots
    private func parseAsBill(text: String) -> ParsedSMS? {
        guard let (amount, currency) = extractBillAmount(from: text), amount > 0 else {
            return nil
        }
        
        let biller = extractBillerFromBill(text: text)
        let category = BillerMapping.categorize(biller)
        let date = extractDate(from: text) ?? extractBillDate(from: text) ?? Date()
        
        return ParsedSMS(
            amount: amount,
            biller: biller,
            category: category,
            date: date,
            rawSMS: text,
            detectedCurrency: currency
        )
    }
    
    /// Extract amount from bill/receipt formats
    /// Handles: Total, Grand Total, Amount, To Pay, Net Payable, etc.
    private func extractBillAmount(from text: String) -> (Double, DetectedCurrency)? {
        let normalizedText = text.lowercased()
        
        // Bill-specific amount patterns (order matters - more specific first)
        // These look for keywords followed by amounts
        let billPatterns: [(pattern: String, currency: DetectedCurrency?)] = [
            // Payment app patterns (Paid to, Sent to, etc.)
            ("(?:paid|sent|received|transferred)\\s+(?:to|from)?[^\\d]*?(?:₹|rs\\.?|inr)?\\s*([\\d,]+\\.?\\d*)", .inr),
            
            // Total patterns with currency
            ("(?:grand\\s*total|total\\s*(?:amount|due|payable)?|net\\s*payable|to\\s*pay|amount\\s*(?:due|payable)?|bill\\s*amount|payable|subtotal)\\s*:?\\s*(?:₹|rs\\.?|inr)\\s*([\\d,]+\\.?\\d*)", .inr),
            ("(?:grand\\s*total|total\\s*(?:amount|due|payable)?|net\\s*payable|to\\s*pay|amount\\s*(?:due|payable)?|bill\\s*amount|payable|subtotal)\\s*:?\\s*(?:\\$|usd)\\s*([\\d,]+\\.?\\d*)", .usd),
            ("(?:grand\\s*total|total\\s*(?:amount|due|payable)?|net\\s*payable|to\\s*pay|amount\\s*(?:due|payable)?|bill\\s*amount|payable|subtotal)\\s*:?\\s*(?:€|eur)\\s*([\\d,]+\\.?\\d*)", .eur),
            ("(?:grand\\s*total|total\\s*(?:amount|due|payable)?|net\\s*payable|to\\s*pay|amount\\s*(?:due|payable)?|bill\\s*amount|payable|subtotal)\\s*:?\\s*(?:£|gbp)\\s*([\\d,]+\\.?\\d*)", .gbp),
            
            // Total patterns without currency (amount follows keyword)
            ("(?:grand\\s*total|total\\s*(?:amount|due|payable)?|net\\s*payable|to\\s*pay|amount\\s*(?:due|payable)?|bill\\s*amount|payable)\\s*:?\\s*([\\d,]+\\.\\d{2})", nil),
            
            // Currency symbol followed by amount (standalone)
            ("₹\\s*([\\d,]+\\.?\\d*)", .inr),
            ("(?:rs\\.?|inr)\\s*([\\d,]+\\.?\\d*)", .inr),
            ("\\$\\s*([\\d,]+\\.?\\d*)", .usd),
            ("€\\s*([\\d,]+\\.?\\d*)", .eur),
            ("£\\s*([\\d,]+\\.?\\d*)", .gbp),
            
            // Standalone decimal amount at start of line (like payment screenshots)
            // e.g., "7400.00" on its own line
            ("^\\s*([\\d,]+\\.\\d{2})\\s*$", nil),
        ]
        
        for (pattern, currency) in billPatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(text[match])
                // Extract the number from the matched string
                if let numberMatch = matchedString.range(of: "[\\d,]+\\.?\\d*$|[\\d,]+\\.\\d{2}", options: .regularExpression) {
                    let numberStr = String(matchedString[numberMatch]).replacingOccurrences(of: ",", with: "")
                    if let amount = Double(numberStr), amount > 0 {
                        // Determine currency - use detected or infer from context
                        let detectedCurrency = currency ?? inferCurrencyFromContext(text)
                        return (amount, detectedCurrency)
                    }
                }
            }
        }
        
        // Last resort: Find the largest decimal number (likely the total)
        if let largestAmount = findLargestAmount(in: text) {
            let currency = inferCurrencyFromContext(text)
            return (largestAmount, currency)
        }
        
        return nil
    }
    
    /// Find the largest amount in text (useful for bills where total is usually largest)
    private func findLargestAmount(in text: String) -> Double? {
        let pattern = "([\\d,]+\\.\\d{2})"
        var amounts: [Double] = []
        
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        
        regex?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match, let matchRange = Range(match.range(at: 1), in: text) {
                let numberStr = String(text[matchRange]).replacingOccurrences(of: ",", with: "")
                if let amount = Double(numberStr), amount > 0 {
                    amounts.append(amount)
                }
            }
        }
        
        // Return largest amount if found and reasonable (> 1 to avoid percentages)
        return amounts.filter { $0 > 1 }.max()
    }
    
    /// Infer currency from text context
    private func inferCurrencyFromContext(_ text: String) -> DetectedCurrency {
        let lowerText = text.lowercased()
        
        // Check for currency indicators in text
        if lowerText.contains("₹") || lowerText.contains("inr") || lowerText.contains("rs.") || lowerText.contains("rs ") {
            return .inr
        }
        if lowerText.contains("$") || lowerText.contains("usd") {
            return .usd
        }
        if lowerText.contains("€") || lowerText.contains("eur") {
            return .eur
        }
        if lowerText.contains("£") || lowerText.contains("gbp") {
            return .gbp
        }
        if lowerText.contains("aed") || lowerText.contains("dirham") {
            return .aed
        }
        
        // Check for Indian context clues
        let indianIndicators = ["upi", "phonepe", "paytm", "gpay", "google pay", "bhim", 
                                "neft", "imps", "rtgs", "ifsc", "hdfc", "icici", "sbi",
                                "axis", "kotak", "yes bank", "idfc", "cgst", "sgst", "gst"]
        if indianIndicators.contains(where: { lowerText.contains($0) }) {
            return .inr
        }
        
        // Default to INR for now (can be changed based on user locale)
        return .inr
    }
    
    /// Extract biller/merchant name from bill text
    private func extractBillerFromBill(text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Payment app patterns - extract recipient name
        let paymentPatterns = [
            "(?:paid|sent|transferred)\\s+to\\s+(.+)",
            "(?:received|got)\\s+from\\s+(.+)",
            "to\\s*:\\s*(.+)",
            "from\\s*:\\s*(.+)",
            "merchant\\s*:\\s*(.+)",
            "payee\\s*:\\s*(.+)",
        ]
        
        for pattern in paymentPatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(text[match])
                // Extract the captured group (name after keyword)
                let components = matchedString.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty && $0.count > 2 }
                if let name = components.dropFirst().first, !name.isEmpty {
                    return name.capitalized
                }
            }
        }
        
        // For payment screenshots, look for line after "Paid to" or similar
        for (index, line) in lines.enumerated() {
            let lowerLine = line.lowercased()
            if lowerLine.contains("paid to") || lowerLine.contains("sent to") || 
               lowerLine.contains("transferred to") || lowerLine.contains("received from") {
                // Next line might be the name
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    // Check if next line looks like a name (not a number or UPI ID)
                    if !nextLine.contains("@") && !nextLine.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) {
                        return nextLine.prefix(50).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        // Try to find known billers
        let (biller, _) = detectBillerAndCategory(in: text)
        if biller != "Unknown" {
            return biller
        }
        
        // Fallback: First non-numeric line that looks like a merchant name
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip lines that are just numbers, dates, or too short
            if trimmed.count >= 3 && 
               !trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "/" || $0 == "-" }) &&
               !trimmed.lowercased().hasPrefix("total") &&
               !trimmed.lowercased().hasPrefix("amount") &&
               !trimmed.lowercased().contains("@") {  // Skip UPI IDs
                return String(trimmed.prefix(50))
            }
        }
        
        return "Unknown"
    }
    
    /// Extract date from bill formats (additional patterns)
    private func extractBillDate(from text: String) -> Date? {
        // Additional date patterns for bills
        let billDatePatterns: [(pattern: String, format: String)] = [
            // "23 December 2025" or "23 December, 2025"
            ("\\b(\\d{1,2}\\s+(?:January|February|March|April|May|June|July|August|September|October|November|December),?\\s+\\d{4})\\b", "dd MMMM yyyy"),
            // "December 23, 2025"
            ("\\b((?:January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4})\\b", "MMMM dd, yyyy"),
            // "23 Dec 2025" or "23 Dec, 2025"
            ("\\b(\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec),?\\s+\\d{4})\\b", "dd MMM yyyy"),
            // "Dec 23 2025"
            ("\\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2},?\\s+\\d{4})\\b", "MMM dd yyyy"),
            // Date with time "23/12/2025, 12:16 pm"
            ("\\b(\\d{1,2}/\\d{1,2}/\\d{4})\\s*,?\\s*\\d{1,2}:\\d{2}", "dd/MM/yyyy"),
            // Date with time "23-12-2025 12:16"
            ("\\b(\\d{1,2}-\\d{1,2}-\\d{4})\\s+\\d{1,2}:\\d{2}", "dd-MM-yyyy"),
        ]
        
        for (pattern, format) in billDatePatterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                var dateString = String(text[range])
                // Clean up the string - remove time portion and commas
                dateString = dateString.replacingOccurrences(of: ",", with: "")
                if let spaceTimeIndex = dateString.range(of: "\\s+\\d{1,2}:\\d{2}", options: .regularExpression) {
                    dateString = String(dateString[..<spaceTimeIndex.lowerBound])
                }
                dateString = dateString.trimmingCharacters(in: .whitespaces)
                
                if let date = parseDate(dateString, format: format) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    /// Extract amount and currency from SMS - supports multiple currency formats
    private func extractAmountAndCurrency(from sms: String) -> (Double, DetectedCurrency)? {
        // Currency patterns with their corresponding currency type
        // Order matters - more specific patterns first
        let currencyPatterns: [(pattern: String, currency: DetectedCurrency)] = [
            // INR patterns
            ("(?:Rs\\.?|INR|₹)\\s*([\\d,]+\\.?\\d*)", .inr),
            ("([\\d,]+\\.?\\d*)\\s*(?:Rs\\.?|INR)", .inr),
            // USD patterns
            ("(?:USD|US\\$|\\$)\\s*([\\d,]+\\.?\\d*)", .usd),
            ("([\\d,]+\\.?\\d*)\\s*(?:USD|US\\$)", .usd),
            // EUR patterns
            ("(?:EUR|€)\\s*([\\d,]+\\.?\\d*)", .eur),
            ("([\\d,]+\\.?\\d*)\\s*(?:EUR|€)", .eur),
            // GBP patterns
            ("(?:GBP|£)\\s*([\\d,]+\\.?\\d*)", .gbp),
            ("([\\d,]+\\.?\\d*)\\s*(?:GBP|£)", .gbp),
            // AED patterns
            ("(?:AED|Dh|DH)\\s*([\\d,]+\\.?\\d*)", .aed),
            ("([\\d,]+\\.?\\d*)\\s*(?:AED|Dh|DH)", .aed),
            // SGD patterns
            ("(?:SGD|S\\$)\\s*([\\d,]+\\.?\\d*)", .sgd),
            ("([\\d,]+\\.?\\d*)\\s*(?:SGD|S\\$)", .sgd),
            // AUD patterns
            ("(?:AUD|A\\$)\\s*([\\d,]+\\.?\\d*)", .aud),
            ("([\\d,]+\\.?\\d*)\\s*(?:AUD|A\\$)", .aud),
            // CAD patterns
            ("(?:CAD|C\\$)\\s*([\\d,]+\\.?\\d*)", .cad),
            ("([\\d,]+\\.?\\d*)\\s*(?:CAD|C\\$)", .cad),
            // JPY patterns
            ("(?:JPY|¥)\\s*([\\d,]+\\.?\\d*)", .jpy),
            ("([\\d,]+\\.?\\d*)\\s*(?:JPY|¥)", .jpy),
        ]
        
        for (pattern, currency) in currencyPatterns {
            if let match = sms.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(sms[match])
                if let numberMatch = matchedString.range(of: "[\\d,]+\\.?\\d*", options: .regularExpression) {
                    let numberStr = String(matchedString[numberMatch]).replacingOccurrences(of: ",", with: "")
                    if let amount = Double(numberStr), amount > 0 {
                        return (amount, currency)
                    }
                }
            }
        }
        
        // Fallback: try to find any amount without currency marker
        let genericPatterns = [
            "(?:debited|credited|paid|spent|received).*?([\\d,]+\\.\\d{2})",
            "([\\d,]+\\.\\d{2})\\s*(?:debited|credited)"
        ]
        
        for pattern in genericPatterns {
            if let match = sms.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(sms[match])
                if let numberMatch = matchedString.range(of: "[\\d,]+\\.\\d{2}", options: .regularExpression) {
                    let numberStr = String(matchedString[numberMatch]).replacingOccurrences(of: ",", with: "")
                    if let amount = Double(numberStr), amount > 0 {
                        // Assume INR for Indian bank messages without explicit currency
                        return (amount, .inr)
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Extract date from SMS - supports multiple Indian date formats
    func extractDate(from sms: String) -> Date? {
        let datePatterns: [(pattern: String, format: String)] = [
            // DD/MM/YY or DD/MM/YYYY
            ("\\b(\\d{1,2}/\\d{1,2}/\\d{2,4})\\b", "dd/MM/yy"),
            // DD-MM-YY or DD-MM-YYYY
            ("\\b(\\d{1,2}-\\d{1,2}-\\d{2,4})\\b", "dd-MM-yy"),
            // DD.MM.YY or DD.MM.YYYY
            ("\\b(\\d{1,2}\\.\\d{1,2}\\.\\d{2,4})\\b", "dd.MM.yy"),
            // DD-Mon-YY or DD-Mon-YYYY (e.g., 15-Jan-26)
            ("\\b(\\d{1,2}-[A-Za-z]{3}-\\d{2,4})\\b", "dd-MMM-yy"),
            // DD Mon YY or DD Mon YYYY (e.g., 15 Jan 26)
            ("\\b(\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{2,4})\\b", "dd MMM yy"),
            // Mon DD, YYYY (e.g., Jan 15, 2026)
            ("\\b([A-Za-z]{3}\\s+\\d{1,2},?\\s+\\d{4})\\b", "MMM dd, yyyy"),
            // YYYY-MM-DD (ISO format)
            ("\\b(\\d{4}-\\d{2}-\\d{2})\\b", "yyyy-MM-dd"),
        ]
        
        for (pattern, format) in datePatterns {
            if let range = sms.range(of: pattern, options: .regularExpression) {
                let dateString = String(sms[range])
                if let date = parseDate(dateString, format: format) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func parseDate(_ dateString: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try the exact format first
        formatter.dateFormat = format
        if let date = formatter.date(from: dateString) {
            return adjustYearIfNeeded(date)
        }
        
        // Try with 4-digit year if 2-digit failed
        let format4Digit = format.replacingOccurrences(of: "yy", with: "yyyy")
        formatter.dateFormat = format4Digit
        if let date = formatter.date(from: dateString) {
            return adjustYearIfNeeded(date)
        }
        
        return nil
    }
    
    /// Adjust year for 2-digit years to ensure they're in a reasonable range
    private func adjustYearIfNeeded(_ date: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        // If year seems too far in future (like 2099), it's probably a parsing issue
        // Assume dates should be within last 1 year to next 1 year
        let currentYear = calendar.component(.year, from: Date())
        
        if year > currentYear + 1 {
            // Probably parsed wrong century, adjust
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            components.year = (year % 100) + 2000
            return calendar.date(from: components) ?? date
        }
        
        return date
    }
    
    /// Detect biller by scanning SMS body for known biller keywords (case-insensitive)
    /// Returns first match if multiple found
    func detectBillerAndCategory(in sms: String) -> (biller: String, category: String) {
        // Get all billers sorted by length (longer first to match specific names before generic)
        let sortedBillers = mappingStorage.mappings.keys.sorted { $0.count > $1.count }
        
        // Find all matching billers with their position in the SMS (case-insensitive)
        var matches: [(biller: String, position: Int, category: String)] = []
        
        for biller in sortedBillers {
            if let range = sms.range(of: biller, options: .caseInsensitive) {
                let position = sms.distance(from: sms.startIndex, to: range.lowerBound)
                let category = mappingStorage.mappings[biller] ?? "Other"
                matches.append((biller, position, category))
            }
        }
        
        // Return first match (by position in SMS), or default
        if let firstMatch = matches.sorted(by: { $0.position < $1.position }).first {
            return (firstMatch.biller, firstMatch.category)
        }
        
        return ("Unknown", "Other")
    }
    
    /// Recategorize an existing expense using current mappings
    func recategorize(expense: Expense) -> Expense {
        let (biller, category) = detectBillerAndCategory(in: expense.rawSMS)
        return Expense(
            amount: expense.amount,
            category: category,
            biller: biller,
            rawSMS: expense.rawSMS,
            date: expense.date
        )
    }
}
