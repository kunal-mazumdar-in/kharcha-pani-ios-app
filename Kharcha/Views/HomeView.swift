import SwiftUI

struct HomeView: View {
    @ObservedObject var expenseStorage: ExpenseStorage
    @ObservedObject var mappingStorage: MappingStorage
    @EnvironmentObject var themeSettings: ThemeSettings
    
    @State private var showingInput = false
    @State private var lastParsedMessage: String?
    @State private var isError = false
    @State private var selectedFilter: DateFilter = DateFilter.currentMonth()
    
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
                    // Summary Section with Date Filter
                    Section {
                    VStack(spacing: 12) {
                        // Date filter row at top
                        HStack {
                            // Selected date label
                            Text(selectedFilter.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            // Date picker menu
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
                                Image(systemName: selectedFilter == .allTime ? "calendar.badge.clock" : "calendar")
                                    .font(.title3)
                                    .foregroundStyle(tintColor)
                            }
                        }
                        
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
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                        } else {
                            PieChartView(
                                categoryTotals: categoryTotals,
                                grandTotal: grandTotal
                            )
                            .frame(height: 160)
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
                                color: tintColor
                            )
                            
                            Divider()
                                .frame(height: 40)
                            
                            StatItem(
                                title: "Categories",
                                value: "\(categoryTotals.count)",
                                color: tintColor
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
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
            .scrollContentBackground(.hidden)
            .background {
                VStack(spacing: 0) {
                    // Solid accent colored header - covers nav bar + just top of pie chart
                    tintColor.opacity(0.6)
                        .frame(height: 180)
                    
                    Color(.systemGroupedBackground)
                }
                .ignoresSafeArea()
            }
            .contentMargins(.top, 0) // Reduce top spacing
            .contentMargins(.bottom, 80) // Space for FAB
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Expense Ginie")
                        .font(.headline)
                        .fontWeight(.semibold)
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
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button
                Button(action: { showingInput = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(tintColor)
                        .clipShape(Circle())
                        .shadow(color: tintColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
        }
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

#Preview {
    HomeView(
        expenseStorage: ExpenseStorage(),
        mappingStorage: MappingStorage.shared
    )
    .environmentObject(ThemeSettings.shared)
}

