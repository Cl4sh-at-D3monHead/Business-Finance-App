import Foundation
import SwiftData

@Model
final class RecurringExpense {
    
    var title: String
    var amount: Double
    var category: String
    var startDate: Date
    var endDate: Date?
    var notes: String
    var isActive: Bool
    
    init(
        title: String,
        amount: Double,
        category: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String = "",
        isActive: Bool = true
    ) {
        self.title = title
        self.amount = amount
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.isActive = isActive
    }
}
