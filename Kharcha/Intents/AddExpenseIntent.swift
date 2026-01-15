import AppIntents
import Foundation

// MARK: - Category Entity for Siri
struct ExpenseCategoryEntity: AppEntity {
    var id: String
    var name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var defaultQuery = ExpenseCategoryQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static let allCategories: [ExpenseCategoryEntity] = [
        ExpenseCategoryEntity(id: "banking", name: "Banking"),
        ExpenseCategoryEntity(id: "food", name: "Food"),
        ExpenseCategoryEntity(id: "groceries", name: "Groceries"),
        ExpenseCategoryEntity(id: "transport", name: "Transport"),
        ExpenseCategoryEntity(id: "shopping", name: "Shopping"),
        ExpenseCategoryEntity(id: "upi", name: "UPI"),
        ExpenseCategoryEntity(id: "bills", name: "Bills"),
        ExpenseCategoryEntity(id: "entertainment", name: "Entertainment"),
        ExpenseCategoryEntity(id: "medical", name: "Medical"),
        ExpenseCategoryEntity(id: "other", name: "Other")
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
    static var title: LocalizedStringResource = "Add Expense to Kharcha"
    static var description = IntentDescription("Add a new expense to your Kharcha tracker")
    
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
    
    // Map common biller names to categories
    private static let billerCategoryMap: [String: String] = [
        // Food
        "swiggy": "Food",
        "zomato": "Food",
        "dominos": "Food",
        "mcdonalds": "Food",
        "starbucks": "Food",
        "restaurant": "Food",
        "food": "Food",
        
        // Transport
        "uber": "Transport",
        "ola": "Transport",
        "rapido": "Transport",
        "metro": "Transport",
        "petrol": "Transport",
        "fuel": "Transport",
        "transport": "Transport",
        
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
        
        // Medical
        "pharmacy": "Medical",
        "medical": "Medical",
        "hospital": "Medical",
        "doctor": "Medical",
        "medicine": "Medical",
        
        // Bills
        "electricity": "Bills",
        "water": "Bills",
        "internet": "Bills",
        "phone": "Bills",
        "rent": "Bills",
        "bill": "Bills",
        "bills": "Bills",
        
        // Banking
        "bank": "Banking",
        "banking": "Banking",
        "atm": "Banking",
        
        // UPI
        "upi": "UPI",
        "phonepe": "UPI",
        "gpay": "UPI",
        "paytm": "UPI"
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
        Summary("Add \(\.$amount) rupees for \(\.$biller) to Kharcha") {
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
            // Category provided via voice command
            finalCategory = selectedCategory.name
        } else if let billerName = biller, let detectedCategory = detectCategoryFromBiller(billerName) {
            // Auto-detect from biller
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
        
        return .result(dialog: "Added \(formattedAmount) to \(finalCategory). Review in Kharcha.")
    }
}

// MARK: - App Shortcuts
struct KharchaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Shortcut with category parameter - "Add expense to Kharcha for Food"
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense to \(.applicationName) for \(\.$category)",
                "Log expense in \(.applicationName) for \(\.$category)",
                "Add \(\.$category) expense to \(.applicationName)",
                "\(\.$category) expense in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "indianrupeesign.circle.fill"
        )
    }
}

