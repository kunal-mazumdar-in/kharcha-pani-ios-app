import SwiftUI

// MARK: - Review Content View (for Tab)
struct ReviewContentView: View {
    @ObservedObject var expenseStorage: ExpenseStorage
    @ObservedObject var mappingStorage: MappingStorage
    
    @State private var pendingItems: [SharedQueueStorage.PendingSMS] = []
    @State private var parsedExpenses: [ReviewParsedItem] = []
    @State private var siriExpenses: [ReviewSiriItem] = []
    @State private var showingClearConfirmation = false
    
    private let queueStorage = SharedQueueStorage.shared
    private let categories = ["Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: mappingStorage)
    }
    
    private var totalPendingCount: Int {
        parsedExpenses.count + siriExpenses.count
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
                                }
                            }
                        }
                    }
                    
                    // SMS expenses section
                    if !parsedExpenses.isEmpty {
                        Section("From SMS (\(parsedExpenses.count))") {
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
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
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
        parsedExpenses = pendingItems.map { sms in
            ReviewParsedItem(
                id: sms.id,
                sms: sms,
                parsedSMS: parser.parse(sms: sms.text),
                overrideCategory: nil,
                overrideDate: nil
            )
        }
        
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
    
    private func addSiriExpense(_ item: ReviewSiriItem) {
        let expense = Expense(
            amount: item.siriExpense.amount,
            category: item.finalCategory,
            biller: item.siriExpense.biller,
            rawSMS: "Added via Siri: \(item.siriExpense.amount.currencyFormatted) for \(item.siriExpense.biller)",
            date: item.finalDate
        )
        
        expenseStorage.append(expense: expense)
        queueStorage.removeFromSiriQueue(id: item.siriExpense.id)
        withAnimation {
            siriExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func clearAll() {
        queueStorage.clearQueue()
        queueStorage.clearSiriQueue()
        withAnimation {
            parsedExpenses = []
            siriExpenses = []
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
    
    var finalCategory: String {
        overrideCategory ?? parsedSMS?.category ?? "Other"
    }
    
    var finalDate: Date {
        overrideDate ?? parsedSMS?.date ?? Date()
    }
}

struct ReviewSiriItem: Identifiable {
    let id: UUID
    let siriExpense: SharedQueueStorage.PendingSiriExpense
    var overrideCategory: String?
    var overrideDate: Date?
    
    var finalCategory: String {
        overrideCategory ?? siriExpense.category
    }
    
    var finalDate: Date {
        overrideDate ?? siriExpense.date
    }
}

// MARK: - Review Pending Expense Row
struct ReviewPendingExpenseRow: View {
    @Binding var item: ReviewParsedItem
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
                if let parsed = item.parsedSMS {
                    Text(parsed.amount.currencyFormatted)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Accept button
                    Button(action: onAdd) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("Could not parse", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                }
            }
            
            // Date and Category pickers (only for parsed items)
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
            
            // SMS preview
            Text(item.sms.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(showingDatePicker ? 2 : 2)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut, value: showingDatePicker)
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

// MARK: - Legacy QueueReviewView (for sheet presentation if needed)
struct QueueReviewView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var expenseStorage: ExpenseStorage
    @ObservedObject var mappingStorage: MappingStorage
    
    @State private var pendingItems: [SharedQueueStorage.PendingSMS] = []
    @State private var parsedExpenses: [ParsedItem] = []
    @State private var siriExpenses: [SiriItem] = []
    @State private var showingClearConfirmation = false
    
    private let queueStorage = SharedQueueStorage.shared
    private let categories = ["Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: mappingStorage)
    }
    
    // SMS parsed item
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
    
    // Siri expense item
    struct SiriItem: Identifiable {
        let id: UUID
        let siriExpense: SharedQueueStorage.PendingSiriExpense
        var overrideCategory: String?
        var overrideDate: Date?
        
        var finalCategory: String {
            overrideCategory ?? siriExpense.category
        }
        
        var finalDate: Date {
            overrideDate ?? siriExpense.date
        }
    }
    
    private var totalPendingCount: Int {
        parsedExpenses.count + siriExpenses.count
    }
    
    var body: some View {
        NavigationStack {
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
                                    SiriExpenseRow(
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
                                    }
                                }
                            }
                        }
                        
                        // SMS expenses section
                        if !parsedExpenses.isEmpty {
                            Section("From SMS (\(parsedExpenses.count))") {
                                ForEach($parsedExpenses) { $item in
                                    PendingExpenseRow(
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
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                if totalPendingCount > 0 {
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
                Text("Remove all \(totalPendingCount) pending expenses?")
            }
            .onAppear {
                loadAndParse()
            }
        }
    }
    
    private func loadAndParse() {
        // Load SMS queue
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
        
        // Load Siri queue
        let siriPending = queueStorage.loadSiriQueue()
        siriExpenses = siriPending.map { expense in
            SiriItem(
                id: expense.id,
                siriExpense: expense,
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
    
    private func removeSiriItem(_ item: SiriItem) {
        queueStorage.removeFromSiriQueue(id: item.siriExpense.id)
        withAnimation {
            siriExpenses.removeAll { $0.id == item.id }
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
    
    private func addSiriExpense(_ item: SiriItem) {
        let expense = Expense(
            amount: item.siriExpense.amount,
            category: item.finalCategory,
            biller: item.siriExpense.biller,
            rawSMS: "Added via Siri: \(item.siriExpense.amount.currencyFormatted) for \(item.siriExpense.biller)",
            date: item.finalDate
        )
        
        expenseStorage.append(expense: expense)
        queueStorage.removeFromSiriQueue(id: item.siriExpense.id)
        withAnimation {
            siriExpenses.removeAll { $0.id == item.id }
        }
    }
    
    private func clearAll() {
        queueStorage.clearQueue()
        queueStorage.clearSiriQueue()
        withAnimation {
            parsedExpenses = []
            siriExpenses = []
        }
    }
}

struct PendingExpenseRow: View {
    @Binding var item: QueueReviewView.ParsedItem
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
                if let parsed = item.parsedSMS {
                    Text(parsed.amount.currencyFormatted)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Accept button
                    Button(action: onAdd) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("Could not parse", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                }
            }
            
            // Date and Category pickers (only for parsed items)
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
            
            // SMS preview
            Text(item.sms.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(showingDatePicker ? 2 : 2)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut, value: showingDatePicker)
    }
}

// MARK: - Siri Expense Row
struct SiriExpenseRow: View {
    @Binding var item: QueueReviewView.SiriItem
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

#Preview {
    QueueReviewView(
        expenseStorage: ExpenseStorage(),
        mappingStorage: MappingStorage.shared
    )
}
