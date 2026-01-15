import Foundation
import SwiftData
import SwiftUI

/// Service for accessing biller mappings from SwiftData
/// Used by SMSParser and views that need programmatic access
@MainActor
class MappingStorage: ObservableObject {
    static let shared = MappingStorage()
    
    private var modelContext: ModelContext?
    
    /// Dictionary cache for quick lookups (rebuilt on changes)
    @Published var mappings: [String: String] = [:]
    
    private init() {}
    
    /// Setup with model context - call from app startup
    func configure(with container: ModelContainer) {
        self.modelContext = container.mainContext
        refreshMappings()
    }
    
    /// Refresh the mappings dictionary from SwiftData
    func refreshMappings() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<BillerMapping>(sortBy: [SortDescriptor(\.biller)])
            let billerMappings = try context.fetch(descriptor)
            mappings = Dictionary(uniqueKeysWithValues: billerMappings.map { ($0.biller, $0.category) })
        } catch {
            print("Error fetching mappings: \(error)")
        }
    }
    
    /// Add a new biller mapping
    func addMapping(biller: String, category: String) {
        guard let context = modelContext else { return }
        
        let mapping = BillerMapping(biller: biller, category: category)
        context.insert(mapping)
        
        do {
            try context.save()
            refreshMappings()
        } catch {
            print("Error adding mapping: \(error)")
        }
    }
    
    /// Delete a biller mapping
    func deleteMapping(biller: String) {
        guard let context = modelContext else { return }
        
        do {
            let upperBiller = biller.uppercased()
            let descriptor = FetchDescriptor<BillerMapping>(
                predicate: #Predicate { $0.biller == upperBiller }
            )
            
            if let mapping = try context.fetch(descriptor).first {
                context.delete(mapping)
                try context.save()
                refreshMappings()
            }
        } catch {
            print("Error deleting mapping: \(error)")
        }
    }
    
    /// Update an existing mapping
    func updateMapping(oldBiller: String, newBiller: String, category: String) {
        guard let context = modelContext else { return }
        
        do {
            let upperOldBiller = oldBiller.uppercased()
            let descriptor = FetchDescriptor<BillerMapping>(
                predicate: #Predicate { $0.biller == upperOldBiller }
            )
            
            if let mapping = try context.fetch(descriptor).first {
                // If biller name changed, delete old and create new (due to unique constraint)
                if oldBiller.uppercased() != newBiller.uppercased() {
                    context.delete(mapping)
                    let newMapping = BillerMapping(biller: newBiller, category: category)
                    context.insert(newMapping)
                } else {
                    mapping.category = category
                }
                
                try context.save()
                refreshMappings()
            }
        } catch {
            print("Error updating mapping: \(error)")
        }
    }
    
    /// Get category for a biller (case-insensitive)
    func getCategory(for biller: String) -> String? {
        mappings[biller.uppercased()]
    }
}
