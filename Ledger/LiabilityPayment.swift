import Foundation
import SwiftData

@Model
final class LiabilityPayment {

    var amount: Double
    var paymentDate: Date
    var notes: String

    var liability: Liability?

    init(
        amount: Double,
        paymentDate: Date = .now,
        notes: String = "",
        liability: Liability? = nil
    ) {
        self.amount = amount
        self.paymentDate = paymentDate
        self.notes = notes
        self.liability = liability
    }
}
