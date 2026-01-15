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

struct ContentView: View {
    @StateObject private var expenseStorage = ExpenseStorage()
    @StateObject private var mappingStorage = MappingStorage.shared
    @StateObject private var themeSettings = ThemeSettings.shared
    
    @State private var showingInput = false
    @State private var showingAdmin = false
    @State private var showingQueue = false
    @State private var lastParsedMessage: String?
    @State private var isError = false
    @State private var pendingCount = 0
    @State private var selectedFilter: DateFilter = DateFilter.currentMonth()
    
    private let queueStorage = SharedQueueStorage.shared
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: mappingStorage)
    }
    
    private var tintColor: Color {
        themeSettings.accentColor.color
    }
    
    // Get all unique months from expenses
    private var availableMonths: [DateFilter] {
        let calendar = Calendar.current
        var monthSet = Set<String>()
        var months: [DateFilter] = []
        
        for expense in expenseStorage.expenses {
            let year = calendar.component(.year, from: expense.date)
            let month = calendar.component(.month, from: expense.date)
            let key = "\(year)-\(month)"
            
            if !monthSet.contains(key) {
                monthSet.insert(key)
                months.append(.month(year: year, month: month))
            }
        }
        
        // Sort by date descending (newest first)
        return months.sorted { m1, m2 in
            if case .month(let y1, let mo1) = m1, case .month(let y2, let mo2) = m2 {
                if y1 != y2 { return y1 > y2 }
                return mo1 > mo2
            }
            return false
        }
    }
    
    // Filter options: current month first, then other months, then "Till Date"
    private var filterOptions: [DateFilter] {
        var options: [DateFilter] = []
        let currentMonth = DateFilter.currentMonth()
        
        // Add current month first if it has expenses or as default
        options.append(currentMonth)
        
        // Add other months (excluding current month if already added)
        for month in availableMonths {
            if case .month(let y1, let m1) = month,
               case .month(let y2, let m2) = currentMonth {
                if y1 != y2 || m1 != m2 {
                    options.append(month)
                }
            }
        }
        
        // Add "Till Date" option
        options.append(.allTime)
        
        return options
    }
    
    // Filtered expenses based on selected filter
    private var filteredExpenses: [Expense] {
        expenseStorage.expenses.filter { selectedFilter.matches(date: $0.date) }
    }
    
    private var categoryTotals: [CategoryTotal] {
        let grouped = Dictionary(grouping: filteredExpenses) { $0.category }
        return grouped.map { category, items in
            CategoryTotal(
                category: category,
                total: items.reduce(0) { $0 + $1.amount },
                count: items.count
            )
        }.sorted { $0.total > $1.total }
    }
    
    private var grandTotal: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Pending SMS Banner
                if pendingCount > 0 {
                    Section {
                        Button(action: { showingQueue = true }) {
                            Label {
                                HStack {
                                    Text("\(pendingCount) SMS\(pendingCount > 1 ? "s" : "") pending")
                                    Spacer()
                                    Text("Review")
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "tray.full.fill")
                                    .foregroundStyle(tintColor)
                            }
                        }
                    }
                }
                
                // Date Filter Section
                Section {
                    Menu {
                        ForEach(filterOptions, id: \.self) { filter in
                            Button {
                                withAnimation {
                                    selectedFilter = filter
                                }
                            } label: {
                                HStack {
                                    if filter == .allTime {
                                        Label(filter.displayName, systemImage: "calendar.badge.clock")
                                    } else {
                                        Label(filter.displayName, systemImage: "calendar")
                                    }
                                    
                                    if selectedFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label {
                                Text(selectedFilter.displayName)
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: selectedFilter == .allTime ? "calendar.badge.clock" : "calendar")
                                    .foregroundStyle(tintColor)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Summary Section
                Section {
                    VStack(spacing: 16) {
                        if categoryTotals.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.quaternary)
                                Text("No expenses")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(selectedFilter == .allTime ? "Add your first expense" : "No expenses in \(selectedFilter.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                        } else {
                            PieChartView(
                                categoryTotals: categoryTotals,
                                grandTotal: grandTotal
                            )
                            .frame(height: 180)
                        }
                        
                        // Stats row
                        HStack(spacing: 0) {
                            StatItem(
                                title: "Total",
                                value: grandTotal.currencyFormatted,
                                color: tintColor
                            )
                            
                            Divider()
                                .frame(height: 40)
                            
                            StatItem(
                                title: "Transactions",
                                value: "\(filteredExpenses.count)",
                                color: .secondary
                            )
                            
                            Divider()
                                .frame(height: 40)
                            
                            StatItem(
                                title: "Categories",
                                value: "\(categoryTotals.count)",
                                color: .secondary
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }
                
                // Categories Section
                if !categoryTotals.isEmpty {
                    Section("Categories") {
                        ForEach(categoryTotals) { item in
                            NavigationLink(destination: CategoryDetailView(
                                category: item.category,
                                expenseStorage: expenseStorage,
                                dateFilter: selectedFilter
                            )) {
                                CategoryRow(item: item, grandTotal: grandTotal)
                            }
                        }
                    }
                }
                
                // Status message
                if let message = lastParsedMessage {
                    Section {
                        Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(isError ? .red : .green)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Kharcha")
            .tint(tintColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAdmin = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingInput = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingInput) {
                SMSInputView(
                    parser: parser,
                    onSubmit: { expense in
                        addExpense(expense)
                    },
                    onCancel: { showingInput = false }
                )
                .tint(tintColor)
            }
            .sheet(isPresented: $showingAdmin) {
                AdminView(
                    mappingStorage: mappingStorage,
                    expenseStorage: expenseStorage,
                    onMappingsChanged: {
                        expenseStorage.recategorizeAll(using: parser)
                    }
                )
                .tint(tintColor)
            }
            .sheet(isPresented: $showingQueue, onDismiss: refreshPendingCount) {
                QueueReviewView(
                    expenseStorage: expenseStorage,
                    mappingStorage: mappingStorage
                )
                .tint(tintColor)
            }
            .onAppear {
                refreshPendingCount()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshPendingCount()
            }
        }
        .tint(tintColor)
    }
    
    private func refreshPendingCount() {
        pendingCount = queueStorage.pendingCount()
    }
    
    private func addExpense(_ expense: Expense) {
        expenseStorage.append(expense: expense)
        lastParsedMessage = "Added \(expense.amount.currencyFormatted) to \(expense.category)"
        isError = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { lastParsedMessage = nil }
        }
        
        showingInput = false
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
    
    private var percentage: Double {
        grandTotal > 0 ? (item.total / grandTotal) * 100 : 0
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
