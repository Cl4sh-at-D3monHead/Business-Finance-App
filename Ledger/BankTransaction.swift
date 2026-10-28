import Foundation
import SwiftData

enum BankTransactionType: String, Codable, CaseIterable {
    case deposit = "Deposit"
    case withdrawal = "Withdrawal"
    case transferIn = "Transfer In"
    case transferOut = "Transfer Out"
}

@Model
final class BankTransaction {
    var accountID: UUID
    var transferID: UUID?
    var title: String
    var amount: Double
    var date: Date
    var typeRaw: String
    var reference: String
    var notes: String

    init(
        accountID: UUID,
        title: String,
        amount: Double,
        date: Date = .now,
        type: BankTransactionType,
        reference: String = "",
        notes: String = "",
        transferID: UUID? = nil
    ) {
        self.accountID = accountID
        self.transferID = transferID
        self.title = title
        self.amount = amount
        self.date = date
        self.typeRaw = type.rawValue
        self.reference = reference
        self.notes = notes
    }

    var type: BankTransactionType {
        get {
            BankTransactionType(rawValue: typeRaw) ?? .deposit
        }
        set {
            typeRaw = newValue.rawValue
        }
    }

    var signedAmount: Double {
        switch type {
        case .deposit, .transferIn:
            return amount
        case .withdrawal, .transferOut:
            return -amount
        }
    }
}

