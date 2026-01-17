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
    
    // SMS parsing mode
    @State private var smsText: String = ""
    @State private var parsedData: ParsedSMS?
    @State private var parseError: Bool = false
    
    // Manual entry fields (always visible)
    @State private var amountText: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: String = "Housing & Rent"
    @State private var selectedDate: Date = Date()
    
    @State private var showSMSInput: Bool = false
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case amount, description, sms
    }
    
    private let categories = AppTheme.allCategories
    
    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ""))
    }
    
    private var canSubmit: Bool {
        if let amt = amount, amt > 0, !description.isEmpty {
            return true
        }
        return false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // SMS Auto-fill Section (collapsible)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSMSInput.toggle()
                            }
                        } label: {
                            HStack {
                                Label("Auto-fill from Message", systemImage: "doc.text.viewfinder")
                                Spacer()
                                Image(systemName: showSMSInput ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if showSMSInput {
                            TextEditor(text: $smsText)
                                .frame(height: 100)
                                .focused($focusedField, equals: .sms)
                                .onChange(of: smsText) { _, _ in
                                    parseCurrentSMS()
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )
                            
                            if parseError && !smsText.isEmpty {
                                Label("Could not detect amount", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else if parsedData != nil {
                                Label("Fields auto-filled", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } footer: {
                    Text("Paste SMS or Email to automatically fill the fields")
                }
                
                // Amount Section
                Section {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .focused($focusedField, equals: .amount)
                    }
                } header: {
                    Text("Amount")
                }
                
                // Description Section
                Section {
                    TextField("Merchant or description", text: $description)
                        .focused($focusedField, equals: .description)
                } header: {
                    Text("Description")
                }
                
                // Category Section
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Label(category, systemImage: AppTheme.iconForCategory(category))
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Category")
                }
                
                // Date Section
                Section {
                    DatePicker(
                        "Transaction Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                } header: {
                    Text("Date")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: submitExpense) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                    }
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                focusedField = .amount
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
            
            // Auto-fill the form fields
            amountText = String(format: "%.2f", data.amount)
            description = data.biller
            selectedCategory = data.category
            selectedDate = data.date
        } else {
            parsedData = nil
            parseError = true
        }
    }
    
    private func submitExpense() {
        guard let amt = amount, amt > 0 else { return }
        
        let rawSMS = smsText.isEmpty ? "Manual: \(description) - \(amt.currencyFormatted)" : smsText
        
        let expense = Expense(
            amount: amt,
            category: selectedCategory,
            biller: description,
            rawSMS: rawSMS,
            date: selectedDate
        )
        
        onSubmit(expense)
    }
}

#Preview {
    ContentView()
}
