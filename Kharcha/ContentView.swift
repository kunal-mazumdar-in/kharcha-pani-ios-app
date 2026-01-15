import SwiftUI

// MARK: - Date Filter
enum DateFilter: Hashable {
    case month(year: Int, month: Int)
    case allTime
    
    var displayName: String {
        switch self {
        case .month(let year, let month):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            if let date = Calendar.current.date(from: components) {
                return formatter.string(from: date)
            }
            return "\(month)/\(year)"
        case .allTime:
            return "Till Date"
        }
    }
    
    static func currentMonth() -> DateFilter {
        let now = Date()
        let calendar = Calendar.current
        return .month(
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now)
        )
    }
    
    func matches(date: Date) -> Bool {
        switch self {
        case .month(let year, let month):
            let calendar = Calendar.current
            let dateYear = calendar.component(.year, from: date)
            let dateMonth = calendar.component(.month, from: date)
            return dateYear == year && dateMonth == month
        case .allTime:
            return true
        }
    }
}

// MARK: - Main Content View (redirects to MainTabView)
struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryRow: View {
    let item: CategoryTotal
    let grandTotal: Double
    var budget: Double? = nil
    var showBudgetIndicator: Bool = true
    
    @State private var showingBudgetTooltip = false
    
    private var percentage: Double {
        grandTotal > 0 ? (item.total / grandTotal) * 100 : 0
    }
    
    private var budgetStatus: BudgetStatus {
        BudgetStatus.calculate(budget: budget, spent: item.total)
    }
    
    private var budgetTooltipMessage: String {
        switch budgetStatus {
        case .noBudget:
            return "No budget set"
        case .withinBudget(let remaining):
            return "✓ \(remaining.currencyFormatted) left"
        case .exceeded(let amount):
            return "↑ \(amount.currencyFormatted) over"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: AppTheme.iconForCategory(item.category))
                .font(.title2)
                .foregroundStyle(AppTheme.colorForCategory(item.category))
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.category)
                    .font(.body)
                
                Text("\(item.count) transaction\(item.count > 1 ? "s" : "") • \(percentage, specifier: "%.0f")%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Budget indicator with tooltip (hidden for "Till Date" filter)
            if budget != nil, !budgetStatus.isNoBudget, showBudgetIndicator {
                Image(systemName: budgetStatus.isExceeded ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(budgetStatus.isExceeded ? .red : .green)
                    .onTapGesture {
                        showingBudgetTooltip.toggle()
                    }
                    .popover(isPresented: $showingBudgetTooltip, arrowEdge: .bottom) {
                        Text(budgetTooltipMessage)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(budgetStatus.isExceeded ? .red : .green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .fixedSize()
                            .presentationCompactAdaptation(.popover)
                    }
            }
            
            Text(item.total.currencyFormatted)
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

struct SMSInputView: View {
    let parser: SMSParser
    let onSubmit: (Expense) -> Void
    let onCancel: () -> Void
    
    @State private var smsText: String = ""
    @State private var selectedCategory: String = "Auto Detect"
    @State private var selectedDate: Date = Date()
    @State private var parsedData: ParsedSMS?
    @State private var parseError: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    private let categories = ["Auto Detect", "Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $smsText)
                        .frame(minHeight: 120)
                        .focused($isTextEditorFocused)
                        .onChange(of: smsText) { _, newValue in
                            parseCurrentSMS()
                        }
                } header: {
                    Text("SMS Content")
                } footer: {
                    if parseError && !smsText.isEmpty {
                        Label("Could not detect amount from SMS", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if let data = parsedData {
                        Label("Detected: \(data.amount.currencyFormatted) from \(data.biller)", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    } else {
                        Text("Paste a transaction SMS from your Messages app")
                    }
                }
                
                if parsedData != nil {
                    Section("Date") {
                        DatePicker(
                            "Transaction Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                    }
                    
                    Section("Category") {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                if category == "Auto Detect" {
                                    Label("Auto Detect (\(parsedData?.category ?? "Other"))", systemImage: "wand.and.stars")
                                        .tag(category)
                                } else {
                                    Label(category, systemImage: AppTheme.iconForCategory(category))
                                        .tag(category)
                                }
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                Section {
                    Button(action: submitExpense) {
                        HStack {
                            Spacer()
                            Label("Add Expense", systemImage: "plus.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(parsedData == nil)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear {
                isTextEditorFocused = true
            }
        }
    }
    
    private func parseCurrentSMS() {
        let trimmed = smsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedData = nil
            parseError = false
            return
        }
        
        if let data = parser.parse(sms: trimmed) {
            parsedData = data
            parseError = false
            selectedDate = data.date
            selectedCategory = "Auto Detect"
        } else {
            parsedData = nil
            parseError = true
        }
    }
    
    private func submitExpense() {
        guard let data = parsedData else { return }
        
        let finalCategory = selectedCategory == "Auto Detect" ? data.category : selectedCategory
        
        let expense = Expense(
            amount: data.amount,
            category: finalCategory,
            biller: data.biller,
            rawSMS: data.rawSMS,
            date: selectedDate
        )
        
        onSubmit(expense)
    }
}

#Preview {
    ContentView()
}
