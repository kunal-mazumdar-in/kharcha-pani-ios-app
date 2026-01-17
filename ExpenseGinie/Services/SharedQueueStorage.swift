import Foundation

/// Shared storage between main app and Share Extension using App Group
class SharedQueueStorage {
    static let shared = SharedQueueStorage()
    
    // IMPORTANT: This must match the App Group ID in both targets
    static let appGroupID = "group.com.kunalm.expenseginie"
    
    private let queueFileName = "pending_sms_queue.json"
    private let siriQueueFileName = "pending_siri_queue.json"
    private let bankStatementQueueFileName = "pending_bank_statement_queue.json"
    
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
    }
    
    private var queueFileURL: URL? {
        containerURL?.appendingPathComponent(queueFileName)
    }
    
    private var siriQueueFileURL: URL? {
        containerURL?.appendingPathComponent(siriQueueFileName)
    }
    
    private var bankStatementQueueFileURL: URL? {
        containerURL?.appendingPathComponent(bankStatementQueueFileName)
    }
    
    struct PendingSMS: Codable, Identifiable {
        let id: UUID
        let text: String
        let dateAdded: Date
        
        init(text: String) {
            self.id = UUID()
            self.text = text
            self.dateAdded = Date()
        }
    }
    
    /// Pre-parsed expense from Siri
    struct PendingSiriExpense: Codable, Identifiable {
        let id: UUID
        let amount: Double
        let category: String
        let biller: String
        let date: Date
        let dateAdded: Date
        
        init(amount: Double, category: String, biller: String, date: Date) {
            self.id = UUID()
            self.amount = amount
            self.category = category
            self.biller = biller
            self.date = date
            self.dateAdded = Date()
        }
    }
    
    /// Statement source type for categorization in review screen
    enum StatementSource: String, Codable {
        case bank = "bank"
        case creditCard = "creditCard"
        
        var displayName: String {
            switch self {
            case .bank: return "From Bank Statement"
            case .creditCard: return "From Credit Card Statement"
            }
        }
    }
    
    /// Pre-parsed expense from Bank/Credit Card Statement PDF
    struct PendingBankStatementExpense: Codable, Identifiable {
        let id: UUID
        var amount: Double
        var category: String
        var description: String
        var date: Date
        let dateAdded: Date
        let parsedWithAI: Bool
        var detectedCurrency: DetectedCurrency
        let statementSource: StatementSource
        
        init(amount: Double, category: String, description: String, date: Date, parsedWithAI: Bool = false, currency: DetectedCurrency = .inr, source: StatementSource = .bank) {
            self.id = UUID()
            self.amount = amount
            self.category = category
            self.description = description
            self.date = date
            self.dateAdded = Date()
            self.parsedWithAI = parsedWithAI
            self.detectedCurrency = currency
            self.statementSource = source
        }
        
        // Custom decoder to handle missing fields (backward compatibility)
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            amount = try container.decode(Double.self, forKey: .amount)
            category = try container.decode(String.self, forKey: .category)
            description = try container.decode(String.self, forKey: .description)
            date = try container.decode(Date.self, forKey: .date)
            dateAdded = try container.decode(Date.self, forKey: .dateAdded)
            parsedWithAI = try container.decodeIfPresent(Bool.self, forKey: .parsedWithAI) ?? false
            detectedCurrency = try container.decodeIfPresent(DetectedCurrency.self, forKey: .detectedCurrency) ?? .inr
            statementSource = try container.decodeIfPresent(StatementSource.self, forKey: .statementSource) ?? .bank
        }
        
        private enum CodingKeys: String, CodingKey {
            case id, amount, category, description, date, dateAdded, parsedWithAI, detectedCurrency, statementSource
        }
    }
    
    /// Add SMS to pending queue (called from Share Extension)
    /// Supports multiple expenses separated by blank lines or "---" delimiters
    /// Returns the number of expenses added
    @discardableResult
    func addToQueue(smsText: String) -> Int {
        let segments = splitIntoExpenses(text: smsText)
        guard !segments.isEmpty else { return 0 }
        
        var queue = loadQueue()
        for segment in segments {
            queue.append(PendingSMS(text: segment))
        }
        saveQueue(queue)
        return segments.count
    }
    
    /// Split text into multiple expense segments
    /// Delimiters: blank lines (double newline) or lines with 2+ dashes (any type)
    private func splitIntoExpenses(text: String) -> [String] {
        // Normalize line endings
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        
        // All types of dashes to recognize as separators:
        // - Hyphen-minus (-) U+002D
        // - En-dash (–) U+2013
        // - Em-dash (—) U+2014
        // - Horizontal bar (―) U+2015
        let dashCharacters: Set<Character> = ["-", "–", "—", "―"]
        
        // Replace dash-only lines (2+ dashes of any type) with empty line
        let lines = normalized.components(separatedBy: "\n")
        var processedLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Check if line contains only dash characters (2 or more)
            let isDashSeparator = trimmed.count >= 2 && trimmed.allSatisfy { dashCharacters.contains($0) }
            
            if isDashSeparator {
                // Replace dash line with empty line (becomes separator)
                processedLines.append("")
            } else {
                processedLines.append(line)
            }
        }
        
        normalized = processedLines.joined(separator: "\n")
        
        // Now split by double newlines (blank lines)
        let segments = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return segments
    }
    
    /// Load all pending SMSs
    func loadQueue() -> [PendingSMS] {
        guard let url = queueFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PendingSMS].self, from: data)
        } catch {
            print("Error loading queue: \(error)")
            return []
        }
    }
    
    /// Save queue to shared container
    private func saveQueue(_ queue: [PendingSMS]) {
        guard let url = queueFileURL else {
            print("Error: App Group container not available")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: url)
        } catch {
            print("Error saving queue: \(error)")
        }
    }
    
    /// Remove specific item from queue
    func removeFromQueue(id: UUID) {
        var queue = loadQueue()
        queue.removeAll { $0.id == id }
        saveQueue(queue)
    }
    
    /// Clear entire queue
    func clearQueue() {
        saveQueue([])
    }
    
    /// Get count of pending items
    func pendingCount() -> Int {
        loadQueue().count + loadSiriQueue().count + loadBankStatementQueue().count
    }
    
    // MARK: - Siri Queue Methods
    
    /// Add expense from Siri (pre-parsed)
    func addFromSiri(amount: Double, category: String, biller: String, date: Date) {
        var queue = loadSiriQueue()
        queue.append(PendingSiriExpense(amount: amount, category: category, biller: biller, date: date))
        saveSiriQueue(queue)
    }
    
    /// Load all pending Siri expenses
    func loadSiriQueue() -> [PendingSiriExpense] {
        guard let url = siriQueueFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PendingSiriExpense].self, from: data)
        } catch {
            print("Error loading Siri queue: \(error)")
            return []
        }
    }
    
    /// Save Siri queue to shared container
    private func saveSiriQueue(_ queue: [PendingSiriExpense]) {
        guard let url = siriQueueFileURL else {
            print("Error: App Group container not available for Siri queue")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: url)
        } catch {
            print("Error saving Siri queue: \(error)")
        }
    }
    
    /// Remove specific Siri item from queue
    func removeFromSiriQueue(id: UUID) {
        var queue = loadSiriQueue()
        queue.removeAll { $0.id == id }
        saveSiriQueue(queue)
    }
    
    /// Clear entire Siri queue
    func clearSiriQueue() {
        saveSiriQueue([])
    }
    
    /// Get count of pending Siri items
    func pendingSiriCount() -> Int {
        loadSiriQueue().count
    }
    
    // MARK: - Bank Statement Queue Methods
    
    /// Add expense from Bank Statement (pre-parsed)
    func addFromBankStatement(amount: Double, category: String, description: String, date: Date, source: StatementSource = .bank) {
        var queue = loadBankStatementQueue()
        queue.append(PendingBankStatementExpense(amount: amount, category: category, description: description, date: date, source: source))
        saveBankStatementQueue(queue)
    }
    
    /// Add multiple expenses from Bank/Credit Card Statement
    func addMultipleFromBankStatement(_ expenses: [(amount: Double, category: String, description: String, date: Date, currency: DetectedCurrency)], parsedWithAI: Bool = false, source: StatementSource = .bank) {
        var queue = loadBankStatementQueue()
        for expense in expenses {
            queue.append(PendingBankStatementExpense(
                amount: expense.amount,
                category: expense.category,
                description: expense.description,
                date: expense.date,
                parsedWithAI: parsedWithAI,
                currency: expense.currency,
                source: source
            ))
        }
        saveBankStatementQueue(queue)
    }
    
    /// Load all pending Bank Statement expenses
    func loadBankStatementQueue() -> [PendingBankStatementExpense] {
        guard let url = bankStatementQueueFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PendingBankStatementExpense].self, from: data)
        } catch {
            print("Error loading Bank Statement queue: \(error)")
            return []
        }
    }
    
    /// Save Bank Statement queue to shared container
    private func saveBankStatementQueue(_ queue: [PendingBankStatementExpense]) {
        guard let url = bankStatementQueueFileURL else {
            print("Error: App Group container not available for Bank Statement queue")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: url)
        } catch {
            print("Error saving Bank Statement queue: \(error)")
        }
    }
    
    /// Remove specific Bank Statement item from queue
    func removeFromBankStatementQueue(id: UUID) {
        var queue = loadBankStatementQueue()
        queue.removeAll { $0.id == id }
        saveBankStatementQueue(queue)
    }
    
    /// Clear entire Bank Statement queue
    func clearBankStatementQueue() {
        saveBankStatementQueue([])
    }
    
    /// Get count of pending Bank Statement items
    func pendingBankStatementCount() -> Int {
        loadBankStatementQueue().count
    }
}

