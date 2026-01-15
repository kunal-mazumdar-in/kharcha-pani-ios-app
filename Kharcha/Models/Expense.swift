import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var amount: Double
    var category: String
    var biller: String
    var rawSMS: String
    var date: Date
    
    init(amount: Double, category: String, biller: String, rawSMS: String, date: Date = Date()) {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.biller = biller
        self.rawSMS = rawSMS
        self.date = date
    }
}

// Computed helper for category aggregation (not stored)
struct CategoryTotal: Identifiable {
    let id = UUID()
    let category: String
    let total: Double
    let count: Int
}
