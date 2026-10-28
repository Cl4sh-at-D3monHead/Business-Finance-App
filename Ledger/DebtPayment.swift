import Foundation
import SwiftData

@Model
final class DebtPayment {
    
    var amount: Double
    var paymentDate: Date
    var notes: String
    var debt: Debt?
    
    init(
        amount: Double,
        paymentDate: Date = Date(),
        notes: String = "",
        debt: Debt? = nil
    ) {
        self.amount = amount
        self.paymentDate = paymentDate
        self.notes = notes
        self.debt = debt
    }
}
