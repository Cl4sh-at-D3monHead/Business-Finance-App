import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case revenue = "Revenue"
    case expense = "Expense"
}

enum IncomeType: String, Codable, CaseIterable {
    case operatingRevenue = "Operating Revenue"
    case otherIncome = "Other Income"
}

enum ExpenseType: String, Codable, CaseIterable {
    case costOfSales = "Cost of Sales"
    case operatingExpense = "Operating Expense"
    case financeCost = "Finance Cost"
    case tax = "Tax"
    case other = "Other"
}

@Model
final class FinanceTransaction {
    
    var title: String
    var amount: Double
    var date: Date
    
    // Stored as text so SwiftData remains simple
    var typeRaw: String
    var category: String
    var expenseTypeRaw: String = ExpenseType.operatingExpense.rawValue
    var incomeTypeRaw: String = IncomeType.operatingRevenue.rawValue
    
    // For things such as rent, salaries and subscriptions
    var isRecurring: Bool
    
    var notes: String
    // Optional link to the account used for this cash transaction.
    var bankAccountID: UUID?
    
    init(
        title: String,
        amount: Double,
        date: Date = Date(),
        type: TransactionType,
        category: String,
        expenseType: ExpenseType = .operatingExpense,
        incomeType: IncomeType = .operatingRevenue,
        isRecurring: Bool = false,
        notes: String = "",
        bankAccountID: UUID? = nil
    ) {
        self.title = title
        self.amount = amount
        self.date = date
        self.typeRaw = type.rawValue
        self.category = category
        self.expenseTypeRaw = expenseType.rawValue
        self.incomeTypeRaw = incomeType.rawValue
        self.isRecurring = isRecurring
        self.notes = notes
        self.bankAccountID = bankAccountID
    }
    
    var type: TransactionType {
        get {
            TransactionType(rawValue: typeRaw) ?? .expense
        }
        set {
            typeRaw = newValue.rawValue
        }
    }
    
    var expenseType: ExpenseType {
        get {
            ExpenseType(rawValue: expenseTypeRaw) ?? .operatingExpense
        }
        set {
            expenseTypeRaw = newValue.rawValue
        }
    }
    
    var incomeType: IncomeType {
        get {
            IncomeType(rawValue: incomeTypeRaw) ?? .operatingRevenue
        }
        set {
            incomeTypeRaw = newValue.rawValue
        }
    }
}
