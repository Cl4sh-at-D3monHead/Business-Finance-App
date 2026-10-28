import Foundation
import SwiftData

enum DebtType: String, Codable, CaseIterable {
    case receivable = "Receivable"
    case payable = "Payable"
}

@Model
final class Debt {
    
    var name: String
    var originalAmount: Double
    var amountPaid: Double
    
    var createdDate: Date
    var dueDate: Date
    
    var typeRaw: String
    var notes: String
    
    // Interest
    var annualInterestRate: Double
    @Relationship(deleteRule: .cascade, inverse: \DebtPayment.debt)
    var payments: [DebtPayment] = []
    
    init(
        name: String,
        originalAmount: Double,
        amountPaid: Double = 0,
        dueDate: Date,
        type: DebtType,
        annualInterestRate: Double = 0,
        notes: String = ""
    ) {
        self.name = name
        self.originalAmount = originalAmount
        self.amountPaid = amountPaid
        self.createdDate = Date()
        self.dueDate = dueDate
        self.typeRaw = type.rawValue
        self.annualInterestRate = annualInterestRate
        self.notes = notes
    }
    
    var type: DebtType {
        get {
            DebtType(rawValue: typeRaw) ?? .receivable
        }
        set {
            typeRaw = newValue.rawValue
        }
    }
    
    // MARK: - Interest
    
    var interestAmount: Double {
        
        guard annualInterestRate > 0 else {
            return 0
        }
        
        let calendar = Calendar.current
        
        let days = calendar.dateComponents(
            [.day],
            from: createdDate,
            to: dueDate
        ).day ?? 0
        
        let positiveDays = max(days, 0)
        
        let years = Double(positiveDays) / 365.0
        
        return originalAmount
            * (annualInterestRate / 100)
            * years
    }
    
    var totalDebtWithInterest: Double {
        originalAmount + interestAmount
    }
    
    var totalPayments: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    var totalAmountPaid: Double {
        amountPaid + totalPayments
    }

    var outstandingBalance: Double {
        outstandingBalance(asOf: .now)
    }

    /// Remaining balance after interest accrued through the requested date
    /// and payments made on or before that date.
    func outstandingBalance(asOf date: Date) -> Double {
        guard createdDate <= date else { return 0 }

        let interestEndDate = min(date, dueDate)
        let days = max(
            Calendar.current.dateComponents(
                [.day],
                from: createdDate,
                to: interestEndDate
            ).day ?? 0,
            0
        )
        let accruedInterest = originalAmount
            * (annualInterestRate / 100)
            * (Double(days) / 365)
        let paymentsToDate = payments
            .filter { $0.paymentDate <= date }
            .reduce(0) { $0 + $1.amount }

        return max(originalAmount + accruedInterest - amountPaid - paymentsToDate, 0)
    }
    
    var isFullyPaid: Bool {
        outstandingBalance <= 0
    }
    
    var isOverdue: Bool {
        !isFullyPaid &&
        dueDate < Calendar.current.startOfDay(for: Date())
    }
}
