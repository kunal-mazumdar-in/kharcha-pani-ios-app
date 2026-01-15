import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @EnvironmentObject var themeSettings: ThemeSettings
    
    private let categories = ["Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    var body: some View {
        List {
            Section {
                ForEach(categories, id: \.self) { category in
                    BudgetRow(
                        category: category,
                        currentBudget: getBudget(for: category),
                        onBudgetChange: { amount in
                            setBudget(for: category, amount: amount)
                        }
                    )
                }
            } header: {
                Text("Monthly Budget per Category")
            } footer: {
                Text("Set a monthly budget for each category. Leave at ₹0 to disable budget tracking for that category.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getBudget(for category: String) -> Double {
        budgets.first { $0.category == category }?.amount ?? 0
    }
    
    private func setBudget(for category: String, amount: Double) {
        if let existing = budgets.first(where: { $0.category == category }) {
            if amount > 0 {
                existing.amount = amount
            } else {
                modelContext.delete(existing)
            }
        } else if amount > 0 {
            let budget = Budget(category: category, amount: amount)
            modelContext.insert(budget)
        }
        try? modelContext.save()
    }
}

// MARK: - Budget Row
struct BudgetRow: View {
    let category: String
    let currentBudget: Double
    let onBudgetChange: (Double) -> Void
    
    @State private var budgetText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: AppTheme.iconForCategory(category))
                .font(.title3)
                .foregroundStyle(AppTheme.colorForCategory(category))
                .frame(width: 32)
            
            // Category name
            Text(category)
                .font(.body)
            
            Spacer()
            
            // Budget input
            HStack(spacing: 4) {
                Text("₹")
                    .foregroundStyle(.secondary)
                
                TextField("0", text: $budgetText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($isFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onAppear {
            budgetText = currentBudget > 0 ? String(Int(currentBudget)) : ""
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                // Save when focus is lost
                let filtered = budgetText.filter { $0.isNumber }
                let amount = Double(filtered) ?? 0
                onBudgetChange(amount)
            }
        }
    }
}

// MARK: - Budget Tab Wrapper
struct BudgetTabView: View {
    var body: some View {
        NavigationStack {
            BudgetView()
        }
    }
}

#Preview {
    BudgetView()
        .environmentObject(ThemeSettings.shared)
}
