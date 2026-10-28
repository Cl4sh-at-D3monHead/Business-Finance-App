import Foundation
import SwiftData

enum LiabilityCategory: String, Codable, CaseIterable, Identifiable {
    case shortTermLoans = "Short-Term Loans"
    case taxesPayable = "Taxes Payable"
    case otherCurrent = "Other Current Liabilities"
    case longTermLoans = "Long-Term Loans"
    case leaseLiabilities = "Lease Liabilities"
    case otherNonCurrent = "Other Non-Current Liabilities"

    var id: String { rawValue }

    var isCurrent: Bool {
        switch self {
        case .shortTermLoans, .taxesPayable, .otherCurrent:
            return true
        case .longTermLoans, .leaseLiabilities, .otherNonCurrent:
            return false
        }
    }
}

@Model
final class Liability {

    var name: String
    var categoryRaw: String
    var creditor: String
    var originalAmount: Double
    var amountPaid: Double
    var currentPortion: Double
    var interestRate: Double
    var startDate: Date
    var dueDate: Date
    var referenceNumber: String
    var notes: String
    var currencyCode: String
    
    @Relationship(
        deleteRule: .cascade,
        inverse: \LiabilityPayment.liability
    )
    var payments: [LiabilityPayment] = []

    init(
        name: String,
        category: LiabilityCategory,
        creditor: String,
        originalAmount: Double,
        amountPaid: Double = 0,
        currentPortion: Double = 0,
        interestRate: Double = 0,
        startDate: Date = .now,
        dueDate: Date = .now,
        referenceNumber: String = "",
        notes: String = "",
        currencyCode: String = "TZS") {
            
        self.name = name
        self.categoryRaw = category.rawValue
        self.creditor = creditor
        self.originalAmount = originalAmount
        self.amountPaid = amountPaid
        self.currentPortion = currentPortion
        self.interestRate = interestRate
        self.startDate = startDate
        self.dueDate = dueDate
        self.referenceNumber = referenceNumber
        self.notes = notes
        self.currencyCode = currencyCode
    }

    var category: LiabilityCategory {
        get {
            LiabilityCategory(rawValue: categoryRaw)
                ?? .otherCurrent
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    var totalRecordedPayments: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    var totalAmountPaid: Double {
        amountPaid + totalRecordedPayments
    }

    var outstandingBalance: Double {
        outstandingBalance(asOf: .now)
    }

    func outstandingBalance(asOf date: Date) -> Double {
        guard startDate <= date else {
            return 0
        }

        let paymentsToDate = payments
            .filter { $0.paymentDate <= date }
            .reduce(0) { $0 + $1.amount }

        return max(
            originalAmount - amountPaid - paymentsToDate,
            0
        )
    }

    var currentBalance: Double {
        currentBalance(asOf: .now)
    }

    var nonCurrentBalance: Double {
        nonCurrentBalance(asOf: .now)
    }
    
    // MARK: - Historical Current Liability Balance

    func currentBalance(asOf date: Date) -> Double {

        let outstanding = outstandingBalance(asOf: date)

        if category.isCurrent {
            return outstanding
        }

        return min(
            max(currentPortion, 0),
            outstanding
        )
    }

    // MARK: - Historical Non-Current Liability Balance

    func nonCurrentBalance(asOf date: Date) -> Double {

        if category.isCurrent {
            return 0
        }

        return max(
            outstandingBalance(asOf: date)
            - currentBalance(asOf: date),
            0
        )
    }
}

