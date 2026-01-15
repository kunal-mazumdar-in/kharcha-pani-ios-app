import Foundation

class MappingStorage: ObservableObject {
    static let shared = MappingStorage()
    
    @Published var mappings: [String: String] = [:]
    
    private let fileName = "sender_mapping.json"  // Keep filename for backward compatibility
    private let mappingVersion = 2  // Increment this to force refresh from bundle
    
    private var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private var versionURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("mapping_version.txt")
    }
    
    init() {
        loadMappings()
    }
    
    func loadMappings() {
        let savedVersion = (try? String(contentsOf: versionURL, encoding: .utf8)).flatMap { Int($0) } ?? 0
        
        // If version changed, reload from bundle and merge
        if savedVersion < mappingVersion {
            loadFromBundleAndMerge()
            return
        }
        
        // Load from Documents if exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let loaded = try JSONDecoder().decode([String: String].self, from: data)
                // Normalize all keys to uppercase
                mappings = Dictionary(uniqueKeysWithValues: loaded.map { ($0.key.uppercased(), $0.value) })
                return
            } catch {
                print("Error loading mappings from Documents: \(error)")
            }
        }
        
        loadFromBundleAndMerge()
    }
    
    private func loadFromBundleAndMerge() {
        // Load existing user mappings first
        var existingMappings: [String: String] = [:]
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode([String: String].self, from: data) {
            existingMappings = Dictionary(uniqueKeysWithValues: loaded.map { ($0.key.uppercased(), $0.value) })
        }
        
        // Load bundle mappings
        if let bundleURL = Bundle.main.url(forResource: "sender_mapping", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let bundleMappings = try? JSONDecoder().decode([String: String].self, from: data) {
            // Normalize bundle keys to uppercase
            let normalizedBundle = Dictionary(uniqueKeysWithValues: bundleMappings.map { ($0.key.uppercased(), $0.value) })
            // Merge: bundle values as base, user values override
            mappings = normalizedBundle.merging(existingMappings) { _, user in user }
        } else {
            mappings = existingMappings.isEmpty ? defaultMappings() : existingMappings
        }
        
        saveMappings()
        saveVersion()
    }
    
    func saveMappings() {
        do {
            let data = try JSONEncoder().encode(mappings)
            try data.write(to: fileURL)
        } catch {
            print("Error saving mappings: \(error)")
        }
    }
    
    private func saveVersion() {
        try? String(mappingVersion).write(to: versionURL, atomically: true, encoding: .utf8)
    }
    
    func addMapping(biller: String, category: String) {
        mappings[biller.uppercased()] = category
        saveMappings()
    }
    
    func deleteMapping(biller: String) {
        mappings.removeValue(forKey: biller.uppercased())
        saveMappings()
    }
    
    func updateMapping(oldBiller: String, newBiller: String, category: String) {
        if oldBiller.uppercased() != newBiller.uppercased() {
            mappings.removeValue(forKey: oldBiller.uppercased())
        }
        mappings[newBiller.uppercased()] = category
        saveMappings()
    }
    
    private func defaultMappings() -> [String: String] {
        [
            "HDFC BANK": "Banking",
            "HDFC": "Banking",
            "SBI": "Banking",
            "ICICI": "Banking",
            "SWIGGY": "Food",
            "ZOMATO": "Food",
            "UBER": "Transport",
            "AMAZON": "Shopping",
            "PHONEPE": "UPI",
            "PAYTM": "UPI",
            "APPLE": "Entertainment"
        ]
    }
}
