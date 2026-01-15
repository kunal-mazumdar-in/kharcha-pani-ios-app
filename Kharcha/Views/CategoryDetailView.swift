import SwiftUI

struct CategoryDetailView: View {
    let category: String
    @ObservedObject var expenseStorage: ExpenseStorage
    
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var expenseToDelete: Expense?
    @State private var expenseToEdit: Expense?
    
    private let categories = ["Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    private var expenses: [Expense] {
        expenseStorage.expenses.filter { $0.category == category }
    }
    
    private var sortedExpenses: [Expense] {
        expenses.sorted { $0.date > $1.date }
    }
    
    private var total: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.colorForCategory(category))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(category.prefix(1)))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Text(category)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("₹\(total, specifier: "%.2f")")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.accent)
                    
                    Text("\(expenses.count) transaction\(expenses.count != 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.vertical, 24)
                
                // Transactions list
                if expenses.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.textMuted)
                        Text("No expenses in this category")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedExpenses) { expense in
                                ExpenseRow(
                                    expense: expense,
                                    categories: categories,
                                    onCategoryChange: { newCategory in
                                        withAnimation {
                                            expenseStorage.updateCategory(for: expense, to: newCategory)
                                        }
                                        // Pop back if this was the last expense in category
                                        if expenses.isEmpty {
                                            dismiss()
                                        }
                                    },
                                    onDelete: {
                                        expenseToDelete = expense
                                        showingDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete Expense?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    withAnimation {
                        expenseStorage.delete(expense: expense)
                    }
                    expenseToDelete = nil
                    
                    // Pop back if no more expenses
                    if expenses.isEmpty {
                        dismiss()
                    }
                }
            }
        } message: {
            if let expense = expenseToDelete {
                Text("Delete ₹\(String(format: "%.2f", expense.amount)) from \(expense.biller)?")
            }
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let categories: [String]
    let onCategoryChange: (String) -> Void
    let onDelete: () -> Void
    
    @State private var showingCategoryPicker = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, hh:mm a"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.biller)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(dateFormatter.string(from: expense.date))
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
                
                Text("₹\(expense.amount, specifier: "%.2f")")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accent)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent.opacity(0.7))
                }
                .padding(.leading, 8)
            }
            
            // Category change button
            Button(action: { showingCategoryPicker = true }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.colorForCategory(expense.category))
                        .frame(width: 8, height: 8)
                    Text(expense.category)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.cardBackgroundLight)
                .cornerRadius(12)
            }
            
            // SMS Preview
            Text(expense.rawSMS)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackgroundLight)
                .cornerRadius(8)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .confirmationDialog("Change Category", isPresented: $showingCategoryPicker, titleVisibility: .visible) {
            ForEach(categories, id: \.self) { category in
                Button(category) {
                    if category != expense.category {
                        onCategoryChange(category)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            category: "Food",
            expenseStorage: ExpenseStorage()
        )
    }
}
