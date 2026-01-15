import SwiftUI

struct DataManagementView: View {
    @ObservedObject var expenseStorage: ExpenseStorage
    @StateObject private var themeSettings = ThemeSettings.shared
    
    @State private var showingClearConfirmation = false
    @State private var showingClearedMessage = false
    
    private var tintColor: Color {
        themeSettings.accentColor.color
    }
    
    var body: some View {
        List {
            // Danger Zone
            Section {
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear All Expenses", systemImage: "trash.fill")
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This will permanently delete all your expense records. This action cannot be undone.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data")
        .tint(tintColor)
        .alert("Clear All Expenses?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllExpenses()
            }
        } message: {
            Text("This will permanently delete all \(expenseStorage.expenses.count) expense records.")
        }
        .overlay {
            if showingClearedMessage {
                VStack {
                    Spacer()
                    Label("All expenses cleared", systemImage: "checkmark.circle.fill")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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

#Preview {
    NavigationStack {
        DataManagementView(expenseStorage: ExpenseStorage())
    }
}
