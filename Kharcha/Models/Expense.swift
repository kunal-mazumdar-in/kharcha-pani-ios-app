import Foundation

struct Expense: Codable, Identifiable {
    let id: UUID
    let amount: Double
    let category: String
    let biller: String
    let rawSMS: String
    let date: Date
    
    // Support old data with "sender" key
    enum CodingKeys: String, CodingKey {
        case id, amount, category, biller = "sender", rawSMS, date
    }
    
    init(amount: Double, category: String, biller: String, rawSMS: String, date: Date = Date()) {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.biller = biller
        self.rawSMS = rawSMS
        self.date = date
    }
}

struct CategoryTotal: Identifiable {
    let id = UUID()
    let category: String
    let total: Double
    let count: Int
}
