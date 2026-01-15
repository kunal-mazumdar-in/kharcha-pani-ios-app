import Foundation

struct ParsedSMS {
    let amount: Double
    let biller: String
    let category: String
    let date: Date
    let rawSMS: String
}

@MainActor
class SMSParser {
    private let mappingStorage: MappingStorage
    
    init(mappingStorage: MappingStorage = .shared) {
        self.mappingStorage = mappingStorage
    }
    
    func parse(sms: String) -> ParsedSMS? {
        guard let amount = extractAmount(from: sms), amount > 0 else {
            return nil
        }
        
        let (biller, category) = detectBillerAndCategory(in: sms)
        let date = extractDate(from: sms) ?? Date()
        
        return ParsedSMS(
            amount: amount,
            biller: biller,
            category: category,
            date: date,
            rawSMS: sms
        )
    }
    
    /// Extract amount from SMS - supports Rs., Rs, INR, ₹ formats
    private func extractAmount(from sms: String) -> Double? {
        let patterns = [
            "(?:Rs\\.?|INR|₹)\\s*([\\d,]+\\.?\\d*)",
            "(?:debited|credited|paid|spent|received).*?(?:Rs\\.?|INR|₹)\\s*([\\d,]+\\.?\\d*)",
            "([\\d,]+\\.?\\d*)\\s*(?:debited|credited)"
        ]
        
        for pattern in patterns {
            if let match = sms.range(of: pattern, options: .regularExpression) {
                let matchedString = String(sms[match])
                if let numberMatch = matchedString.range(of: "[\\d,]+\\.?\\d*", options: .regularExpression) {
                    let numberStr = String(matchedString[numberMatch]).replacingOccurrences(of: ",", with: "")
                    if let amount = Double(numberStr) {
                        return amount
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
