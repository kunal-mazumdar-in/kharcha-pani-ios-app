import SwiftUI

struct ContentView: View {
    @StateObject private var expenseStorage = ExpenseStorage()
    @StateObject private var mappingStorage = MappingStorage.shared
    
    @State private var smsText: String = ""
    @State private var showingInput = false
    @State private var showingAdmin = false
    @State private var showingQueue = false
    @State private var lastParsedMessage: String?
    @State private var isError = false
    @State private var pendingCount = 0
    
    private let queueStorage = SharedQueueStorage.shared
    
    private var parser: SMSParser {
        SMSParser(mappingStorage: mappingStorage)
    }
    
    private var categoryTotals: [CategoryTotal] {
        let grouped = Dictionary(grouping: expenseStorage.expenses) { $0.category }
        return grouped.map { category, items in
            CategoryTotal(
                category: category,
                total: items.reduce(0) { $0 + $1.amount },
                count: items.count
            )
        }.sorted { $0.total > $1.total }
    }
    
    private var grandTotal: Double {
        expenseStorage.expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Pending queue banner
                    if pendingCount > 0 {
                        Button(action: { showingQueue = true }) {
                            HStack {
                                Image(systemName: "tray.full.fill")
                                    .foregroundColor(AppTheme.accent)
                                Text("\(pendingCount) SMS\(pendingCount > 1 ? "s" : "") pending")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("Review")
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding()
                            .background(AppTheme.accent.opacity(0.15))
                        }
                    }
                    
                    // Header with Pie Chart
                    VStack(spacing: 16) {
                        Text("Total Expenses")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        if categoryTotals.isEmpty {
                            // Empty state
                            Circle()
                                .stroke(AppTheme.cardBackgroundLight, lineWidth: 20)
                                .frame(width: 160, height: 160)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Text("₹0")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Text("No data")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.textMuted)
                                    }
                                )
                        } else {
                            PieChartView(
                                categoryTotals: categoryTotals,
                                grandTotal: grandTotal
                            )
                            .frame(width: 180, height: 180)
                        }
                        
                        Text("\(expenseStorage.expenses.count) transactions")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(AppTheme.cardBackground)
                    
                    // Category List
                    if categoryTotals.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.textMuted)
                            Text("No expenses yet")
                                .font(.headline)
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Tap + to paste an SMS")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            // Legend
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                ForEach(categoryTotals) { item in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(AppTheme.colorForCategory(item.category))
                                            .frame(width: 8, height: 8)
                                        Text(item.category)
                                            .font(.caption)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            
                            // Category rows
                            LazyVStack(spacing: 12) {
                                ForEach(categoryTotals) { item in
                                    NavigationLink(destination: CategoryDetailView(
                                        category: item.category,
                                        expenseStorage: expenseStorage
                                    )) {
                                        CategoryRow(item: item, grandTotal: grandTotal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                        }
                    }
                    
                    // Status message
                    if let message = lastParsedMessage {
                        Text(message)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isError ? AppTheme.accent : .green)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                (isError ? AppTheme.accent : Color.green)
                                    .opacity(0.15)
                            )
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Kharcha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAdmin = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingInput = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingInput) {
                SMSInputView(
                    onSubmit: { sms, category in
                        parseSMS(sms: sms, overrideCategory: category)
                    },
                    onCancel: { showingInput = false }
                )
            }
            .sheet(isPresented: $showingAdmin) {
                AdminView(
                    mappingStorage: mappingStorage,
                    expenseStorage: expenseStorage,
                    onMappingsChanged: {
                        expenseStorage.recategorizeAll(using: parser)
                    }
                )
            }
            .sheet(isPresented: $showingQueue, onDismiss: refreshPendingCount) {
                QueueReviewView(
                    expenseStorage: expenseStorage,
                    mappingStorage: mappingStorage
                )
            }
            .onAppear {
                refreshPendingCount()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshPendingCount()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func refreshPendingCount() {
        pendingCount = queueStorage.pendingCount()
    }
    
    private func parseSMS(sms: String, overrideCategory: String?) {
        guard !sms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showingInput = false
            return
        }
        
        if var expense = parser.parse(sms: sms) {
            // Override category if user selected one
            if let category = overrideCategory {
                expense = Expense(
                    amount: expense.amount,
                    category: category,
                    biller: expense.biller,
                    rawSMS: expense.rawSMS,
                    date: expense.date
                )
            }
            
            expenseStorage.append(expense: expense)
            lastParsedMessage = "Added ₹\(String(format: "%.2f", expense.amount)) to \(expense.category)"
            isError = false
        } else {
            lastParsedMessage = "Could not parse amount from SMS"
            isError = true
        }
        
        // Clear message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            lastParsedMessage = nil
        }
        
        showingInput = false
    }
}

struct CategoryRow: View {
    let item: CategoryTotal
    let grandTotal: Double
    
    private var percentage: Double {
        grandTotal > 0 ? (item.total / grandTotal) * 100 : 0
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Category color indicator
            Circle()
                .fill(AppTheme.colorForCategory(item.category))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.category)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                HStack(spacing: 8) {
                    Text("\(item.count) txn\(item.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                    
                    Text("•")
                        .foregroundColor(AppTheme.textMuted)
                    
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("₹\(item.total, specifier: "%.2f")")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

struct SMSInputView: View {
    let onSubmit: (String, String?) -> Void
    let onCancel: () -> Void
    
    @State private var smsText: String = ""
    @State private var selectedCategory: String = "Auto Detect"
    
    private let categories = ["Auto Detect", "Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.accent)
                        
                        Text("Paste SMS")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Copy a transaction SMS from Messages and paste below")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    TextEditor(text: $smsText)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBackgroundLight, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    // Category selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CATEGORY")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.horizontal)
                        
                        Menu {
                            ForEach(categories, id: \.self) { category in
                                Button(action: { selectedCategory = category }) {
                                    HStack {
                                        if category != "Auto Detect" {
                                            Circle()
                                                .fill(AppTheme.colorForCategory(category))
                                                .frame(width: 10, height: 10)
                                        }
                                        Text(category)
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if selectedCategory == "Auto Detect" {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundColor(AppTheme.accent)
                                    Text("Auto Detect")
                                        .foregroundColor(AppTheme.textPrimary)
                                } else {
                                    Circle()
                                        .fill(AppTheme.colorForCategory(selectedCategory))
                                        .frame(width: 12, height: 12)
                                    Text(selectedCategory)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let category = selectedCategory == "Auto Detect" ? nil : selectedCategory
                        onSubmit(smsText, category)
                    }) {
                        Text("Add Expense")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.accent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
