import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: String
    var dateFilter: DateFilter = .allTime
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allExpenses: [Expense]
    @Environment(\.dismiss) var dismiss
    
    @State private var showingDeleteConfirmation = false
    @State private var expenseToDelete: Expense?
    
    private let categories = AppTheme.allCategories
    
    init(category: String, dateFilter: DateFilter = .allTime) {
        self.category = category
        self.dateFilter = dateFilter
        
        // Filter by category in query
        let categoryFilter = category
        _allExpenses = Query(
            filter: #Predicate<Expense> { $0.category == categoryFilter },
            sort: \Expense.date,
            order: .reverse
        )
    }
    
    // Apply date filter on top of category filter
    private var expenses: [Expense] {
        allExpenses.filter { dateFilter.matches(date: $0.date) }
    }
    
    private var total: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    private var subtitle: String {
        if dateFilter == .allTime {
            return "\(expenses.count) transaction\(expenses.count != 1 ? "s" : "")"
        } else {
            return "\(expenses.count) transaction\(expenses.count != 1 ? "s" : "") in \(dateFilter.displayName)"
        }
    }
    
    var body: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(category, systemImage: AppTheme.iconForCategory(category))
                            .font(.headline)
                            .foregroundStyle(AppTheme.colorForCategory(category))
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(total.currencyFormatted)
                        .font(.system(.title, design: .rounded, weight: .bold))
                }
                .padding(.vertical, 8)
            }
            
            // Transactions Section
            if expenses.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Expenses",
                        systemImage: "tray",
                        description: Text(dateFilter == .allTime 
                            ? "No expenses in this category yet" 
                            : "No expenses in \(dateFilter.displayName)")
                    )
                }
            } else {
                Section("Transactions") {
                    ForEach(expenses) { expense in
                        ExpenseRow(
                            expense: expense,
                            categories: categories,
                            onCategoryChange: { newCategory in
                                withAnimation {
                                    expense.category = newCategory
                                    try? modelContext.save()
                                }
                                if expenses.isEmpty {
                                    dismiss()
                                }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                expenseToDelete = expense
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Expense?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    withAnimation {
                        modelContext.delete(expense)
                        try? modelContext.save()
                    }
                    expenseToDelete = nil
                    
                    if expenses.isEmpty {
                        dismiss()
                    }
                }
            }
        } message: {
            if let expense = expenseToDelete {
                Text("Delete \(expense.amount.currencyFormatted) from \(expense.biller)?")
            }
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let categories: [String]
    let onCategoryChange: (String) -> Void
    
    @State private var isExpanded = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.biller)
                        .font(.headline)
                    
                    Text(dateFormatter.string(from: expense.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text(expense.amount.currencyFormatted)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }
            
            // Category picker
            Menu {
                ForEach(categories, id: \.self) { category in
                    Button {
                        if category != expense.category {
                            onCategoryChange(category)
                        }
                    } label: {
                        Label(category, systemImage: AppTheme.iconForCategory(category))
                        if category == expense.category {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Label(expense.category, systemImage: AppTheme.iconForCategory(expense.category))
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.colorForCategory(expense.category).opacity(0.15))
                    .foregroundStyle(AppTheme.colorForCategory(expense.category))
                    .clipShape(Capsule())
            }
            
            // SMS Preview
            if isExpanded {
                Text(expense.rawSMS)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: "Food")
    }
}
