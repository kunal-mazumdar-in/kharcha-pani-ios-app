import Foundation

/// Shared storage between main app and Share Extension using App Group
class SharedQueueStorage {
    static let shared = SharedQueueStorage()
    
    // IMPORTANT: This must match the App Group ID in both targets
    static let appGroupID = "group.com.kunalm.kharcha"
    
    private let queueFileName = "pending_sms_queue.json"
    private let siriQueueFileName = "pending_siri_queue.json"
    
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
    }
    
    private var queueFileURL: URL? {
        containerURL?.appendingPathComponent(queueFileName)
    }
    
    private var siriQueueFileURL: URL? {
        containerURL?.appendingPathComponent(siriQueueFileName)
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
    
    /// Add SMS to pending queue (called from Share Extension)
    func addToQueue(smsText: String) {
        var queue = loadQueue()
        queue.append(PendingSMS(text: smsText))
        saveQueue(queue)
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
        loadQueue().count + loadSiriQueue().count
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
}

