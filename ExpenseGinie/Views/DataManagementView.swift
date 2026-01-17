import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
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
                Button {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear All Expenses", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This will permanently delete all your expense records. This action cannot be undone.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle("Data")
        .alert("Clear All Expenses?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllExpenses()
            }
        } message: {
            Text("This will permanently delete all \(expenses.count) expense records.")
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
        do {
            try modelContext.delete(model: Expense.self)
            try modelContext.save()
        } catch {
            print("Error clearing expenses: \(error)")
        }
        
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
        DataManagementView()
    }
}
