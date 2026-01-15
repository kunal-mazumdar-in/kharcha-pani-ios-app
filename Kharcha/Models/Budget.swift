import Foundation
import SwiftData

@Model
final class Budget {
    @Attribute(.unique) var category: String
    var amount: Double
    
    init(category: String, amount: Double) {
        self.category = category
        self.amount = amount
    }
}

// MARK: - Budget Status (computed, not stored)
enum BudgetStatus: Equatable {
    case noBudget
    case withinBudget(remaining: Double)
    case exceeded(by: Double)
    
    var isExceeded: Bool {
        if case .exceeded = self { return true }
        return false
    }
    
    var isNoBudget: Bool {
        if case .noBudget = self { return true }
        return false
    }
    
    static func calculate(budget: Double?, spent: Double) -> BudgetStatus {
        guard let budget = budget, budget > 0 else {
            return .noBudget
        }
        
        let difference = spent - budget
        if difference > 0 {
            return .exceeded(by: difference)
        } else {
            return .withinBudget(remaining: abs(difference))
        }
    }
}

