import Foundation

/// Shared storage between main app and Share Extension using App Group
class SharedQueueStorage {
    static let shared = SharedQueueStorage()
    
    // IMPORTANT: This must match the App Group ID in both targets
    static let appGroupID = "group.com.kunalm.kharcha"
    
    private let queueFileName = "pending_sms_queue.json"
    
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
    }
    
    private var queueFileURL: URL? {
        containerURL?.appendingPathComponent(queueFileName)
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
        loadQueue().count
    }
}

