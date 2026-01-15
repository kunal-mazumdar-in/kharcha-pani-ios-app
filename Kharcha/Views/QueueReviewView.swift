import SwiftUI

struct QueueReviewView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var expenseStorage: ExpenseStorage
    @ObservedObject var mappingStorage: MappingStorage
    
    @State private var pendingItems: [SharedQueueStorage.PendingSMS] = []
    @State private var parsedExpenses: [ParsedItem] = []
    
    private let queueStorage = SharedQueueStorage.shared
    private let categories = ["Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: mappingStorage)
    }
    
    private var validExpenses: [ParsedItem] {
        parsedExpenses.filter { $0.expense != nil }
    }
    
    struct ParsedItem: Identifiable {
        let id: UUID
        let sms: SharedQueueStorage.PendingSMS
        var expense: Expense?
        var overrideCategory: String?
        
        var finalCategory: String {
            overrideCategory ?? expense?.category ?? "Other"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                if parsedExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.textMuted)
                        Text("No pending SMSs")
                            .font(.headline)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Share SMS from Messages app")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textMuted)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Summary header
                        VStack(spacing: 8) {
                            Text("\(parsedExpenses.count) SMS\(parsedExpenses.count > 1 ? "s" : "") shared")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            HStack(spacing: 16) {
                                Label("\(validExpenses.count) parsed", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                if parsedExpenses.count - validExpenses.count > 0 {
                                    Label("\(parsedExpenses.count - validExpenses.count) failed", systemImage: "xmark.circle.fill")
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.cardBackground)
                        
                        // List of parsed items
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach($parsedExpenses) { $item in
                                    PendingExpenseRow(
                                        item: $item,
                                        categories: categories,
                                        onRemove: { removeItem(item) }
                                    )
                                }
                            }
                            .padding()
                        }
                        
                        // Bottom actions
                        VStack(spacing: 12) {
                            Button(action: addAllValid) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add \(validExpenses.count) Expense\(validExpenses.count != 1 ? "s" : "")")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(validExpenses.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                                .cornerRadius(12)
                            }
                            .disabled(validExpenses.isEmpty)
                            
                            Button(action: clearAll) {
                                Text("Clear All")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textMuted)
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                    }
                }
            }
            .navigationTitle("Pending SMSs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
            .onAppear {
                loadAndParse()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadAndParse() {
        pendingItems = queueStorage.loadQueue()
        parsedExpenses = pendingItems.map { sms in
            ParsedItem(
                id: sms.id,
                sms: sms,
                expense: parser.parse(sms: sms.text),
                overrideCategory: nil
            )
        }
    }
    
    private func removeItem(_ item: ParsedItem) {
        queueStorage.removeFromQueue(id: item.sms.id)
        parsedExpenses.removeAll { $0.id == item.id }
    }
    
    private func addAllValid() {
        for item in parsedExpenses {
            if var expense = item.expense {
                // Apply category override if set
                if let override = item.overrideCategory {
                    expense = Expense(
                        amount: expense.amount,
                        category: override,
                        biller: expense.biller,
                        rawSMS: expense.rawSMS,
                        date: expense.date
                    )
                }
                expenseStorage.append(expense: expense)
                queueStorage.removeFromQueue(id: item.sms.id)
            }
        }
        dismiss()
    }
    
    private func clearAll() {
        queueStorage.clearQueue()
        parsedExpenses = []
    }
}

struct PendingExpenseRow: View {
    @Binding var item: QueueReviewView.ParsedItem
    let categories: [String]
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let expense = item.expense {
                    // Parsed successfully
                    Circle()
                        .fill(AppTheme.colorForCategory(item.finalCategory))
                        .frame(width: 10, height: 10)
                    
                    Text("₹\(expense.amount, specifier: "%.2f")")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.accent)
                    
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.textMuted)
                    }
                } else {
                    // Failed to parse
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Could not parse")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            
            // Category selector (only show if parsed successfully)
            if item.expense != nil {
                Menu {
                    // Auto detect option
                    Button(action: { item.overrideCategory = nil }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Auto Detect")
                            if item.overrideCategory == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    ForEach(categories, id: \.self) { category in
                        Button(action: { item.overrideCategory = category }) {
                            HStack {
                                Text(category)
                                if item.overrideCategory == category {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if item.overrideCategory == nil {
                            Image(systemName: "wand.and.stars")
                                .font(.caption)
                                .foregroundColor(AppTheme.accent)
                            Text(item.expense?.category ?? "Other")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Text("(auto)")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textMuted)
                        } else {
                            Circle()
                                .fill(AppTheme.colorForCategory(item.overrideCategory!))
                                .frame(width: 8, height: 8)
                            Text(item.overrideCategory!)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardBackgroundLight)
                    .cornerRadius(12)
                }
            }
            
            // SMS preview
            Text(item.sms.text)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(3)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackgroundLight)
                .cornerRadius(8)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.expense != nil ? Color.clear : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    QueueReviewView(
        expenseStorage: ExpenseStorage(),
        mappingStorage: MappingStorage.shared
    )
}
