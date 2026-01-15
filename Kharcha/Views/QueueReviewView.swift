import SwiftUI

struct QueueReviewView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var expenseStorage: ExpenseStorage
    @ObservedObject var mappingStorage: MappingStorage
    
    @State private var pendingItems: [SharedQueueStorage.PendingSMS] = []
    @State private var parsedExpenses: [ParsedItem] = []
    @State private var showingClearConfirmation = false
    
    private let queueStorage = SharedQueueStorage.shared
    private let categories = ["Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: mappingStorage)
    }
    
    struct ParsedItem: Identifiable {
        let id: UUID
        let sms: SharedQueueStorage.PendingSMS
        var parsedSMS: ParsedSMS?
        var overrideCategory: String?
        var overrideDate: Date?
        
        var finalCategory: String {
            overrideCategory ?? parsedSMS?.category ?? "Other"
        }
        
        var finalDate: Date {
            overrideDate ?? parsedSMS?.date ?? Date()
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if parsedExpenses.isEmpty {
                    ContentUnavailableView(
                        "No Pending SMS",
                        systemImage: "tray",
                        description: Text("Share SMS from the Messages app to add expenses")
                    )
                } else {
                    List {
                        Section("Pending SMS (\(parsedExpenses.count))") {
                            ForEach($parsedExpenses) { $item in
                                PendingExpenseRow(
                                    item: $item,
                                    categories: categories,
                                    onAdd: {
                                        addExpense(item)
                                    },
                                    onDelete: {
                                        removeItem(item)
                                    }
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Review SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                if !parsedExpenses.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button {
                            showingClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .alert("Clear All?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAll()
                }
            } message: {
                Text("Remove all \(parsedExpenses.count) pending SMS?")
            }
            .onAppear {
                loadAndParse()
            }
        }
    }
    
    private func loadAndParse() {
        pendingItems = queueStorage.loadQueue()
        parsedExpenses = pendingItems.map { sms in
            ParsedItem(
                id: sms.id,
                sms: sms,
                parsedSMS: parser.parse(sms: sms.text),
                overrideCategory: nil,
                overrideDate: nil
            )
        }
    }
    
    private func removeItem(_ item: ParsedItem) {
        queueStorage.removeFromQueue(id: item.sms.id)
        withAnimation {
            parsedExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func addExpense(_ item: ParsedItem) {
        guard let parsed = item.parsedSMS else { return }
        
        let expense = Expense(
            amount: parsed.amount,
            category: item.finalCategory,
            biller: parsed.biller,
            rawSMS: parsed.rawSMS,
            date: item.finalDate
        )
        
        expenseStorage.append(expense: expense)
        queueStorage.removeFromQueue(id: item.sms.id)
        withAnimation {
            parsedExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func clearAll() {
        queueStorage.clearQueue()
        withAnimation {
            parsedExpenses = []
        }
    }
}

struct PendingExpenseRow: View {
    @Binding var item: QueueReviewView.ParsedItem
    let categories: [String]
    let onAdd: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDatePicker = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let parsed = item.parsedSMS {
                    Text(parsed.amount.currencyFormatted)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Add button
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("Could not parse", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Date and Category pickers (only for parsed items)
            if item.parsedSMS != nil {
                HStack(spacing: 8) {
                    // Date picker button
                    Button {
                        showingDatePicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(dateFormatter.string(from: item.finalDate))
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    // Category picker
                    Menu {
                        Button {
                            item.overrideCategory = nil
                        } label: {
                            Label("Auto Detect", systemImage: "wand.and.stars")
                            if item.overrideCategory == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                        
                        Divider()
                        
                        ForEach(categories, id: \.self) { category in
                            Button {
                                item.overrideCategory = category
                            } label: {
                                Label(category, systemImage: AppTheme.iconForCategory(category))
                                if item.overrideCategory == category {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if item.overrideCategory == nil {
                                Image(systemName: "wand.and.stars")
                                    .font(.caption)
                            }
                            Text(item.finalCategory)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.colorForCategory(item.finalCategory).opacity(0.15))
                        .foregroundStyle(AppTheme.colorForCategory(item.finalCategory))
                        .clipShape(Capsule())
                    }
                }
                
                // Inline date picker when expanded
                if showingDatePicker {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { item.overrideDate ?? item.parsedSMS?.date ?? Date() },
                            set: { item.overrideDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.vertical, 4)
                }
            }
            
            // SMS preview
            Text(item.sms.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(showingDatePicker ? 2 : 3)
        }
        .padding(.vertical, 4)
        .animation(.easeInOut, value: showingDatePicker)
    }
}

#Preview {
    QueueReviewView(
        expenseStorage: ExpenseStorage(),
        mappingStorage: MappingStorage.shared
    )
}
