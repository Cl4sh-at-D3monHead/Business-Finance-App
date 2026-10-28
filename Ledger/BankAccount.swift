import Foundation
import SwiftData

@Model
final class BankAccount {

    var name: String
    var accountHolder: String
    var bankName: String
    var accountNumber: String
    var accountType: String
    var branch: String
    var currencyCode: String
    var openingBalance: Double
    var dateAdded: Date
    var id: UUID = UUID()

    init(
        name: String,
        accountHolder: String,
        bankName: String,
        accountNumber: String,
        accountType: String,
        branch: String = "",
        currencyCode: String = "TZS",
        openingBalance: Double = 0,
        dateAdded: Date = .now
    ) {
        self.name = name
        self.accountHolder = accountHolder
        self.bankName = bankName
        self.accountNumber = accountNumber
        self.accountType = accountType
        self.branch = branch
        self.currencyCode = currencyCode
        self.openingBalance = openingBalance
        self.dateAdded = dateAdded
    }
}
