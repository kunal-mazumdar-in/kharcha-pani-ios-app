import Foundation
import SwiftData

@Model
final class BillerMapping {
    @Attribute(.unique) var biller: String  // Stored uppercase for case-insensitive matching
    var category: String
    
    init(biller: String, category: String) {
        self.biller = biller.uppercased()
        self.category = category
    }
    
    // Default billers to seed on first launch
    static let defaults: [(biller: String, category: String)] = [
        ("HDFC BANK", "Banking"),
        ("HDFC", "Banking"),
        ("SBI", "Banking"),
        ("ICICI", "Banking"),
        ("AXIS", "Banking"),
        ("KOTAK", "Banking"),
        ("SWIGGY", "Food"),
        ("ZOMATO", "Food"),
        ("DOMINOS", "Food"),
        ("MCDONALDS", "Food"),
        ("STARBUCKS", "Food"),
        ("UBER", "Transport"),
        ("OLA", "Transport"),
        ("RAPIDO", "Transport"),
        ("AMAZON", "Shopping"),
        ("FLIPKART", "Shopping"),
        ("MYNTRA", "Shopping"),
        ("PHONEPE", "UPI"),
        ("PAYTM", "UPI"),
        ("GPAY", "UPI"),
        ("GOOGLE PAY", "UPI"),
        ("BIGBASKET", "Groceries"),
        ("BLINKIT", "Groceries"),
        ("ZEPTO", "Groceries"),
        ("INSTAMART", "Groceries"),
        ("NETFLIX", "Entertainment"),
        ("SPOTIFY", "Entertainment"),
        ("APPLE", "Entertainment"),
        ("APPLE SERVICES", "Entertainment"),
        ("HOTSTAR", "Entertainment"),
        ("PRIME VIDEO", "Entertainment"),
        ("AIRTEL", "Bills"),
        ("JIO", "Bills"),
        ("VI", "Bills"),
        ("BESCOM", "Bills"),
        ("APOLLO", "Medical"),
        ("PHARMEASY", "Medical"),
        ("NETMEDS", "Medical")
    ]
}

