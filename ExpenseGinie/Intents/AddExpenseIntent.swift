import AppIntents
import Foundation

// MARK: - Category Entity for Siri
// Short, Siri-friendly names that map to full category names
struct ExpenseCategoryEntity: AppEntity {
    var id: String
    var name: String        // Short name for Siri voice commands
    var fullName: String    // Full category name used in app
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var defaultQuery = ExpenseCategoryQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    // Siri categories - short names for easy voice commands
    // Maps to full category names in AppTheme.allCategories
    static let allCategories: [ExpenseCategoryEntity] = [
        ExpenseCategoryEntity(id: "housing", name: "Housing", fullName: "Housing & Rent"),
        ExpenseCategoryEntity(id: "utilities", name: "Utilities", fullName: "Utilities"),
        ExpenseCategoryEntity(id: "groceries", name: "Groceries", fullName: "Groceries"),
        ExpenseCategoryEntity(id: "food", name: "Food", fullName: "Food & Dining"),
        ExpenseCategoryEntity(id: "transport", name: "Transport", fullName: "Transport & Fuel"),
        ExpenseCategoryEntity(id: "shopping", name: "Shopping", fullName: "Shopping"),
        ExpenseCategoryEntity(id: "medical", name: "Medical", fullName: "Medical & Healthcare"),
        ExpenseCategoryEntity(id: "entertainment", name: "Entertainment", fullName: "Entertainment"),
        ExpenseCategoryEntity(id: "subscriptions", name: "Subscriptions", fullName: "Subscriptions"),
        ExpenseCategoryEntity(id: "bills", name: "Bills", fullName: "Bills & Recharge"),
        ExpenseCategoryEntity(id: "insurance", name: "Insurance", fullName: "Insurance"),
        ExpenseCategoryEntity(id: "emi", name: "EMI", fullName: "Debt & EMI"),
        ExpenseCategoryEntity(id: "investments", name: "Investments", fullName: "Investments"),
        ExpenseCategoryEntity(id: "education", name: "Education", fullName: "Education & Learning"),
        ExpenseCategoryEntity(id: "business", name: "Business", fullName: "Business Operations"),
        ExpenseCategoryEntity(id: "travel", name: "Travel", fullName: "Travel & Vacation"),
        ExpenseCategoryEntity(id: "taxes", name: "Taxes", fullName: "Taxes"),
        ExpenseCategoryEntity(id: "gifts", name: "Gifts", fullName: "Gifts & Donations"),
        ExpenseCategoryEntity(id: "family", name: "Family", fullName: "Family & Dependents"),
        ExpenseCategoryEntity(id: "pet", name: "Pet", fullName: "Pet Care"),
        ExpenseCategoryEntity(id: "vehicle", name: "Vehicle", fullName: "Vehicle Maintenance"),
        ExpenseCategoryEntity(id: "banking", name: "Banking", fullName: "Banking & Fees"),
        ExpenseCategoryEntity(id: "upi", name: "UPI", fullName: "UPI / Petty Cash"),
        ExpenseCategoryEntity(id: "other", name: "Other", fullName: "Other")
    ]
}

struct ExpenseCategoryQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ExpenseCategoryEntity] {
        ExpenseCategoryEntity.allCategories.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [ExpenseCategoryEntity] {
        ExpenseCategoryEntity.allCategories
    }
}

// MARK: - Add Expense Intent
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Track Expense in Expense Ginie"
    static var description = IntentDescription("Track a new expense in Expense Ginie")
    
    // Required: Amount
    @Parameter(title: "Amount", description: "The expense amount in rupees")
    var amount: Double?
    
    // Required: Category or Biller name
    @Parameter(title: "Category", description: "The expense category")
    var category: ExpenseCategoryEntity?
    
    // Optional: Biller/merchant name
    @Parameter(title: "Biller", description: "The merchant or biller name (e.g., Swiggy, Uber)")
    var biller: String?
    
    // Optional: Date (defaults to today)
    @Parameter(title: "Date", description: "The date of the expense")
    var date: Date?
    
    // Map common biller names to full category names (from AppTheme.allCategories)
    private static let billerCategoryMap: [String: String] = [
        // Food & Dining
        "swiggy": "Food & Dining",
        "zomato": "Food & Dining",
        "dominos": "Food & Dining",
        "mcdonalds": "Food & Dining",
        "starbucks": "Food & Dining",
        "restaurant": "Food & Dining",
        "food": "Food & Dining",
        "cafe": "Food & Dining",
        "dining": "Food & Dining",
        
        // Transport & Fuel
        "uber": "Transport & Fuel",
        "ola": "Transport & Fuel",
        "rapido": "Transport & Fuel",
        "metro": "Transport & Fuel",
        "petrol": "Transport & Fuel",
        "fuel": "Transport & Fuel",
        "transport": "Transport & Fuel",
        "cab": "Transport & Fuel",
        "taxi": "Transport & Fuel",
        
        // Shopping
        "amazon": "Shopping",
        "flipkart": "Shopping",
        "myntra": "Shopping",
        "shopping": "Shopping",
        
        // Entertainment
        "netflix": "Entertainment",
        "spotify": "Entertainment",
        "prime": "Entertainment",
        "movie": "Entertainment",
        "entertainment": "Entertainment",
        
        // Groceries
        "bigbasket": "Groceries",
        "blinkit": "Groceries",
        "zepto": "Groceries",
        "grocery": "Groceries",
        "groceries": "Groceries",
        
        // Medical & Healthcare
        "pharmacy": "Medical & Healthcare",
        "medical": "Medical & Healthcare",
        "hospital": "Medical & Healthcare",
        "doctor": "Medical & Healthcare",
        "medicine": "Medical & Healthcare",
        
        // Bills & Recharge
        "electricity": "Bills & Recharge",
        "water": "Bills & Recharge",
        "internet": "Bills & Recharge",
        "phone": "Bills & Recharge",
        "recharge": "Bills & Recharge",
        "bill": "Bills & Recharge",
        "bills": "Bills & Recharge",
        
        // Housing & Rent
        "rent": "Housing & Rent",
        "housing": "Housing & Rent",
        
        // Subscriptions
        "subscription": "Subscriptions",
        "subscriptions": "Subscriptions",
        
        // Banking & Fees
        "bank": "Banking & Fees",
        "banking": "Banking & Fees",
        "atm": "Banking & Fees",
        
        // UPI / Petty Cash
        "upi": "UPI / Petty Cash",
        "phonepe": "UPI / Petty Cash",
        "gpay": "UPI / Petty Cash",
        "paytm": "UPI / Petty Cash",
        
        // Travel & Vacation
        "travel": "Travel & Vacation",
        "vacation": "Travel & Vacation",
        "hotel": "Travel & Vacation",
        "flight": "Travel & Vacation",
        
        // Insurance
        "insurance": "Insurance",
        
        // Debt & EMI
        "emi": "Debt & EMI",
        "loan": "Debt & EMI",
        
        // Education & Learning
        "education": "Education & Learning",
        "course": "Education & Learning",
        "school": "Education & Learning",
        "college": "Education & Learning"
    ]
    
    private func detectCategoryFromBiller(_ billerName: String) -> String? {
        let lowercased = billerName.lowercased()
        
        // Check for exact or partial matches
        for (keyword, category) in Self.billerCategoryMap {
            if lowercased.contains(keyword) {
                return category
            }
        }
        
        return nil
    }
    
    static var parameterSummary: some ParameterSummary {
        Summary("Track \(\.$amount) rupees for \(\.$biller) in Expense Ginie") {
            \.$category
            \.$date
        }
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate amount - this will prompt if not provided
        guard let expenseAmount = amount, expenseAmount > 0 else {
            throw $amount.needsValueError("How much was the expense?")
        }
        
        // Determine category - prompt only if not provided via voice
        var finalCategory: String
        
        if let selectedCategory = category {
            // Category provided via voice command - use full name for storage
            finalCategory = selectedCategory.fullName
        } else if let billerName = biller, let detectedCategory = detectCategoryFromBiller(billerName) {
            // Auto-detect from biller (already returns full category name)
            finalCategory = detectedCategory
        } else {
            // Ask for category
            throw $category.needsValueError("Which category should I add this to?")
        }
        
        // Determine biller name (use category name if no specific biller)
        let finalBiller = biller?.capitalized ?? finalCategory
        
        // Use today if no date specified
        let finalDate = date ?? Date()
        
        // Add to shared queue for review
        let queueStorage = SharedQueueStorage.shared
        queueStorage.addFromSiri(
            amount: expenseAmount,
            category: finalCategory,
            biller: finalBiller,
            date: finalDate
        )
        
        // Format response
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        let formattedAmount = formatter.string(from: NSNumber(value: expenseAmount)) ?? "₹\(Int(expenseAmount))"
        
        return .result(dialog: "Tracked \(formattedAmount) for \(finalCategory). Review in Expense Ginie.")
    }
}

// MARK: - App Shortcuts
struct ExpenseGinieShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Shortcut with category parameter
        // NOTE: Using "Track" to avoid conflicts with Siri's built-in Reminders ("Add")
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Track \(\.$category) expense in \(.applicationName)",
                "Track \(\.$category) in \(.applicationName)",
                "Track expense in \(.applicationName) for \(\.$category)",
                "Track my \(\.$category) expense in \(.applicationName)"
            ],
            shortTitle: "Track Expense",
            systemImageName: "indianrupeesign.circle.fill"
        )
    }
}

