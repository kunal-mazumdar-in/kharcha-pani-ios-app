import SwiftUI
import SwiftData

// MARK: - Review Content View (for Tab)
struct ReviewContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var pendingItems: [SharedQueueStorage.PendingSMS] = []
    @State private var parsedExpenses: [ReviewParsedItem] = []
    @State private var siriExpenses: [ReviewSiriItem] = []
    @State private var bankStatementExpenses: [ReviewBankStatementItem] = []
    @State private var showingClearConfirmation = false
    
    private let queueStorage = SharedQueueStorage.shared
    private let categories = AppTheme.allCategories
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: MappingStorage.shared)
    }
    
    private var totalPendingCount: Int {
        parsedExpenses.count + siriExpenses.count + bankStatementExpenses.count
    }
    
    var body: some View {
        Group {
            if totalPendingCount == 0 {
                ContentUnavailableView(
                    "No Pending Expenses",
                    systemImage: "tray",
                    description: Text("Share SMS from Messages or use Siri to add expenses")
                )
            } else {
                List {
                    // Siri expenses section
                    if !siriExpenses.isEmpty {
                        Section("From Siri (\(siriExpenses.count))") {
                            ForEach($siriExpenses) { $item in
                                ReviewSiriExpenseRow(
                                    item: $item,
                                    categories: categories,
                                    onAdd: {
                                        addSiriExpense(item)
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        removeSiriItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    }
                    
                    // SMS expenses section
                    if !parsedExpenses.isEmpty {
                        Section("Shared From Other Apps (\(parsedExpenses.count))") {
                            ForEach($parsedExpenses) { $item in
                                ReviewPendingExpenseRow(
                                    item: $item,
                                    categories: categories,
                                    onAdd: {
                                        addExpense(item)
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        removeItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    }
                    
                    // Bank Statement expenses section
                    if !bankStatementExpenses.isEmpty {
                        Section("From Bank Statement (\(bankStatementExpenses.count))") {
                            ForEach($bankStatementExpenses) { $item in
                                ReviewBankStatementExpenseRow(
                                    item: $item,
                                    categories: categories,
                                    onAdd: {
                                        addBankStatementExpense(item)
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        removeBankStatementItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if totalPendingCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            Text("Remove all \(totalPendingCount) pending expenses?")
        }
        .onAppear {
            loadAndParse()
        }
    }
    
    private func loadAndParse() {
        // Load SMS queue
        pendingItems = queueStorage.loadQueue()
        
        // Parse and filter out unparseable items
        var validExpenses: [ReviewParsedItem] = []
        var invalidIds: [UUID] = []
        
        for sms in pendingItems {
            if let parsed = parser.parse(sms: sms.text) {
                validExpenses.append(ReviewParsedItem(
                    id: sms.id,
                    sms: sms,
                    parsedSMS: parsed,
                    overrideCategory: nil,
                    overrideDate: nil
                ))
            } else {
                // Can't parse - remove from queue silently
                invalidIds.append(sms.id)
            }
        }
        
        // Remove unparseable items from queue
        for id in invalidIds {
            queueStorage.removeFromQueue(id: id)
        }
        
        parsedExpenses = validExpenses
        
        // Load Siri queue
        let siriPending = queueStorage.loadSiriQueue()
        siriExpenses = siriPending.map { expense in
            ReviewSiriItem(
                id: expense.id,
                siriExpense: expense,
                overrideCategory: nil,
                overrideDate: nil
            )
        }
        
        // Load Bank Statement queue
        let bankStatementPending = queueStorage.loadBankStatementQueue()
        bankStatementExpenses = bankStatementPending.map { expense in
            ReviewBankStatementItem(
                id: expense.id,
                bankStatementExpense: expense,
                overrideCategory: nil,
                overrideDate: nil
            )
        }
    }
    
    private func removeItem(_ item: ReviewParsedItem) {
        queueStorage.removeFromQueue(id: item.sms.id)
        withAnimation {
            parsedExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func removeSiriItem(_ item: ReviewSiriItem) {
        queueStorage.removeFromSiriQueue(id: item.siriExpense.id)
        withAnimation {
            siriExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func addExpense(_ item: ReviewParsedItem) {
        guard let parsed = item.parsedSMS else { return }
        
        let expense = Expense(
            amount: item.finalAmount,
            category: item.finalCategory,
            biller: parsed.biller,
            rawSMS: parsed.rawSMS,
            date: item.finalDate
        )
        
        modelContext.insert(expense)
        try? modelContext.save()
        
        queueStorage.removeFromQueue(id: item.sms.id)
        withAnimation {
            parsedExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func addSiriExpense(_ item: ReviewSiriItem) {
        let expense = Expense(
            amount: item.finalAmount,
            category: item.finalCategory,
            biller: item.siriExpense.biller,
            rawSMS: "Added via Siri: \(item.finalAmount.currencyFormatted) for \(item.siriExpense.biller)",
            date: item.finalDate
        )
        
        modelContext.insert(expense)
        try? modelContext.save()
        
        queueStorage.removeFromSiriQueue(id: item.siriExpense.id)
        withAnimation {
            siriExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func removeBankStatementItem(_ item: ReviewBankStatementItem) {
        queueStorage.removeFromBankStatementQueue(id: item.bankStatementExpense.id)
        withAnimation {
            bankStatementExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func addBankStatementExpense(_ item: ReviewBankStatementItem) {
        let expense = Expense(
            amount: item.finalAmount,
            category: item.finalCategory,
            biller: item.finalDescription,
            rawSMS: "Bank Statement: \(item.finalDescription) - \(item.finalAmount.currencyFormatted)",
            date: item.finalDate
        )
        
        modelContext.insert(expense)
        try? modelContext.save()
        
        queueStorage.removeFromBankStatementQueue(id: item.bankStatementExpense.id)
        withAnimation {
            bankStatementExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func clearAll() {
        queueStorage.clearQueue()
        queueStorage.clearSiriQueue()
        queueStorage.clearBankStatementQueue()
        withAnimation {
            parsedExpenses = []
            siriExpenses = []
            bankStatementExpenses = []
        }
    }
}

// MARK: - Review Item Types
struct ReviewParsedItem: Identifiable {
    let id: UUID
    let sms: SharedQueueStorage.PendingSMS
    var parsedSMS: ParsedSMS?
    var overrideCategory: String?
    var overrideDate: Date?
    var overrideAmount: Double?
    
    var finalCategory: String {
        overrideCategory ?? parsedSMS?.category ?? "Other"
    }
    
    var finalDate: Date {
        overrideDate ?? parsedSMS?.date ?? Date()
    }
    
    var finalAmount: Double {
        overrideAmount ?? parsedSMS?.amount ?? 0
    }
    
    var detectedCurrency: DetectedCurrency {
        parsedSMS?.detectedCurrency ?? .inr
    }
    
    var isNonINR: Bool {
        !detectedCurrency.isINR
    }
}

struct ReviewSiriItem: Identifiable {
    let id: UUID
    let siriExpense: SharedQueueStorage.PendingSiriExpense
    var overrideCategory: String?
    var overrideDate: Date?
    var overrideAmount: Double?
    
    var finalCategory: String {
        overrideCategory ?? siriExpense.category
    }
    
    var finalDate: Date {
        overrideDate ?? siriExpense.date
    }
    
    var finalAmount: Double {
        overrideAmount ?? siriExpense.amount
    }
    
    // Siri expenses are always INR
    var isNonINR: Bool { false }
}

struct ReviewBankStatementItem: Identifiable {
    let id: UUID
    var bankStatementExpense: SharedQueueStorage.PendingBankStatementExpense
    var overrideCategory: String?
    var overrideDate: Date?
    var overrideAmount: Double?
    var overrideDescription: String?
    
    var finalCategory: String {
        overrideCategory ?? bankStatementExpense.category
    }
    
    var finalDate: Date {
        overrideDate ?? bankStatementExpense.date
    }
    
    var finalAmount: Double {
        overrideAmount ?? bankStatementExpense.amount
    }
    
    var finalDescription: String {
        overrideDescription ?? bankStatementExpense.description
    }
    
    var detectedCurrency: DetectedCurrency {
        bankStatementExpense.detectedCurrency
    }
    
    var isNonINR: Bool {
        !detectedCurrency.isINR
    }
}

// MARK: - Review Pending Expense Row
struct ReviewPendingExpenseRow: View {
    @Binding var item: ReviewParsedItem
    let categories: [String]
    let onAdd: () -> Void
    
    @State private var showingDatePicker = false
    @State private var isTextExpanded = false
    @State private var showingEditSheet = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    // Get first line of SMS text
    private var firstLine: String {
        let text = item.sms.text
        if let newlineIndex = text.firstIndex(of: "\n") {
            return String(text[..<newlineIndex])
        }
        // If no newline, truncate to ~60 chars
        if text.count > 60 {
            return String(text.prefix(60)) + "..."
        }
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.finalAmount.currencyFormatted)
                    .font(.headline)
                
                Spacer()
                
                // Currency warning icon for non-INR (next to accept button)
                if item.isNonINR {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
                
                // Accept button
                Button(action: onAdd) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
            
            // Date and Category pickers
            if item.parsedSMS != nil {
                HStack(spacing: 6) {
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
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
                    .padding(.vertical, 2)
                }
            }
            
            // SMS preview - always show first line, full text when expanded
            HStack(alignment: .top, spacing: 4) {
                Text(isTextExpanded ? item.sms.text : firstLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isTextExpanded ? nil : 1)
                
                Spacer(minLength: 0)
                
                Image(systemName: isTextExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextExpanded.toggle()
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showingEditSheet) {
            EditExpenseSheet(
                amount: item.finalAmount,
                category: item.finalCategory,
                date: item.finalDate,
                description: item.parsedSMS?.biller ?? "Unknown",
                detectedCurrency: item.detectedCurrency,
                categories: categories,
                onSave: { newAmount, newCategory, newDate, _ in
                    item.overrideAmount = newAmount
                    item.overrideCategory = newCategory
                    item.overrideDate = newDate
                }
            )
        }
    }
}

// MARK: - Review Siri Expense Row
struct ReviewSiriExpenseRow: View {
    @Binding var item: ReviewSiriItem
    let categories: [String]
    let onAdd: () -> Void
    
    @State private var showingDatePicker = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Siri icon
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.purple)
                
                Text(item.siriExpense.amount.currencyFormatted)
                    .font(.headline)
                
                Text("• \(item.siriExpense.biller)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Accept button
                Button(action: onAdd) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
            
            // Date and Category pickers
            HStack(spacing: 6) {
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Category picker
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            item.overrideCategory = category
                        } label: {
                            Label(category, systemImage: AppTheme.iconForCategory(category))
                            if item.finalCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(item.finalCategory)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
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
                        get: { item.overrideDate ?? item.siriExpense.date },
                        set: { item.overrideDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut, value: showingDatePicker)
    }
}

// MARK: - Review Bank Statement Expense Row
struct ReviewBankStatementExpenseRow: View {
    @Binding var item: ReviewBankStatementItem
    let categories: [String]
    let onAdd: () -> Void
    
    @State private var showingDatePicker = false
    @State private var isTextExpanded = false
    @State private var showingEditSheet = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    // Get first line of description
    private var firstLine: String {
        let text = item.finalDescription
        if let newlineIndex = text.firstIndex(of: "\n") {
            return String(text[..<newlineIndex])
        }
        // If no newline, truncate to ~50 chars
        if text.count > 50 {
            return String(text.prefix(50)) + "..."
        }
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Source icon - AI sparkle or document icon
                if item.bankStatementExpense.parsedWithAI {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                        .font(.body)
                } else {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                }
                
                Text(item.finalAmount.currencyFormatted)
                    .font(.headline)
                
                Spacer()
                
                // Currency warning icon for non-INR (next to accept button)
                if item.isNonINR {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
                
                // Accept button
                Button(action: onAdd) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
            
            // Date and Category pickers
            HStack(spacing: 6) {
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Category picker
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            item.overrideCategory = category
                        } label: {
                            Label(category, systemImage: AppTheme.iconForCategory(category))
                            if item.finalCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(item.finalCategory)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.colorForCategory(item.finalCategory).opacity(0.15))
                    .foregroundStyle(AppTheme.colorForCategory(item.finalCategory))
                    .clipShape(Capsule())
                }
            }
            
            // Description - always show first line, full text when expanded
            HStack(alignment: .top, spacing: 4) {
                Text(isTextExpanded ? item.finalDescription : firstLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isTextExpanded ? nil : 1)
                
                Spacer(minLength: 0)
                
                Image(systemName: isTextExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextExpanded.toggle()
            }
            
            // Inline date picker when expanded
            if showingDatePicker {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { item.overrideDate ?? item.bankStatementExpense.date },
                        set: { item.overrideDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showingEditSheet) {
            EditExpenseSheet(
                amount: item.finalAmount,
                category: item.finalCategory,
                date: item.finalDate,
                description: item.finalDescription,
                detectedCurrency: item.detectedCurrency,
                categories: categories,
                onSave: { newAmount, newCategory, newDate, newDescription in
                    item.overrideAmount = newAmount
                    item.overrideCategory = newCategory
                    item.overrideDate = newDate
                    item.overrideDescription = newDescription
                }
            )
        }
    }
}

// MARK: - Edit Expense Sheet
struct EditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State var amount: Double
    @State var category: String
    @State var date: Date
    @State var description: String
    let detectedCurrency: DetectedCurrency
    let categories: [String]
    let onSave: (Double, String, Date, String) -> Void
    
    @State private var amountText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Currency Warning Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Non-INR Currency Detected")
                                .font(.headline)
                            Text("Original amount is in \(detectedCurrency.rawValue) (\(detectedCurrency.symbol)). Please convert to INR manually.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Amount Section
                Section("Amount") {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        TextField("Amount in INR", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                    
                    // Original amount reference
                    HStack {
                        Text("Original:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(detectedCurrency.symbol)\(amount, specifier: "%.2f")")
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
                
                // Description Section
                Section("Description") {
                    TextField("Description", text: $description)
                }
                
                // Category Section
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat, systemImage: AppTheme.iconForCategory(cat))
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Date Section
                Section("Date") {
                    DatePicker("Transaction Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        let newAmount = Double(amountText) ?? amount
                        onSave(newAmount, category, date, description)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                amountText = String(format: "%.2f", amount)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        ReviewContentView()
    }
}
