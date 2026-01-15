import SwiftUI

struct DataManagementView: View {
    @ObservedObject var expenseStorage: ExpenseStorage
    @Environment(\.dismiss) var dismiss
    
    @State private var showingClearConfirmation = false
    @State private var showingClearedMessage = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            List {
                // Statistics Section
                Section {
                    StatRow(label: "Total Expenses", value: "\(expenseStorage.expenses.count)")
                    StatRow(label: "Total Amount", value: "₹\(String(format: "%.2f", totalAmount))")
                    StatRow(label: "Categories", value: "\(uniqueCategories)")
                } header: {
                    Text("Statistics")
                        .foregroundColor(AppTheme.textMuted)
                }
                
                // Danger Zone
                Section {
                    Button(action: { showingClearConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.white)
                            Text("Clear All Expenses")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                } header: {
                    Text("Danger Zone")
                        .foregroundColor(AppTheme.accent)
                } footer: {
                    Text("This will permanently delete all your expense records. This action cannot be undone.")
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Clear All Expenses?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllExpenses()
            }
        } message: {
            Text("This will permanently delete all \(expenseStorage.expenses.count) expense records. This action cannot be undone.")
        }
        .overlay {
            if showingClearedMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All expenses cleared")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var totalAmount: Double {
        expenseStorage.expenses.reduce(0) { $0 + $1.amount }
    }
    
    private var uniqueCategories: Int {
        Set(expenseStorage.expenses.map { $0.category }).count
    }
    
    private func clearAllExpenses() {
        expenseStorage.clear()
        
        withAnimation {
            showingClearedMessage = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingClearedMessage = false
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .foregroundColor(AppTheme.textSecondary)
                .fontWeight(.medium)
        }
        .listRowBackground(AppTheme.cardBackground)
    }
}

#Preview {
    NavigationStack {
        DataManagementView(expenseStorage: ExpenseStorage())
    }
}

