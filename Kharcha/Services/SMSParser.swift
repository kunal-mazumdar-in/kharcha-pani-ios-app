import Foundation

class SMSParser {
    private let mappingStorage: MappingStorage
    
    init(mappingStorage: MappingStorage = .shared) {
        self.mappingStorage = mappingStorage
    }
    
    func parse(sms: String) -> Expense? {
        guard let amount = extractAmount(from: sms), amount > 0 else {
            return nil
        }
        
        let (biller, category) = detectBillerAndCategory(in: sms)
        
        return Expense(
            amount: amount,
            category: category,
            biller: biller,
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
    
    /// Detect biller by scanning SMS body for known biller keywords (case-insensitive)
    /// Returns first match if multiple found
    func detectBillerAndCategory(in sms: String) -> (biller: String, category: String) {
        // Get all billers sorted by length (longer first to match specific names before generic)
        // e.g., "APPLE SERVICES" before "APPLE"
        let sortedBillers = mappingStorage.mappings.keys.sorted { $0.count > $1.count }
        
        // Find all matching billers with their position in the SMS (case-insensitive)
        var matches: [(biller: String, position: Int, category: String)] = []
        
        for biller in sortedBillers {
            // Case-insensitive search
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
