import Foundation

class ExpenseStorage: ObservableObject {
    @Published var expenses: [Expense] = []
    
    private let fileName = "expenses.json"
    
    private var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }
    
    init() {
        load()
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(expenses)
            try data.write(to: fileURL)
        } catch {
            print("Error saving expenses: \(error)")
        }
    }
    
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            expenses = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            expenses = try JSONDecoder().decode([Expense].self, from: data)
        } catch {
            print("Error loading expenses: \(error)")
            expenses = []
        }
    }
    
    func append(expense: Expense) {
        expenses.append(expense)
        save()
    }
    
    func delete(expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        save()
    }
    
    func updateCategory(for expense: Expense, to newCategory: String) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            let updated = Expense(
                amount: expense.amount,
                category: newCategory,
                biller: expense.biller,
                rawSMS: expense.rawSMS,
                date: expense.date
            )
            expenses[index] = updated
            save()
        }
    }
    
    func delete(at offsets: IndexSet, from category: String) {
        let categoryExpenses = expenses.filter { $0.category == category }
        for index in offsets {
            if index < categoryExpenses.count {
                let expenseToDelete = categoryExpenses[index]
                expenses.removeAll { $0.id == expenseToDelete.id }
            }
        }
        save()
    }
    
    func clear() {
        expenses = []
        save()
    }
    
    func recategorizeAll(using parser: SMSParser) {
        expenses = expenses.map { parser.recategorize(expense: $0) }
        save()
    }
}
