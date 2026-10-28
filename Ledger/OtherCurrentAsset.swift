import Foundation
import SwiftData

enum OtherCurrentAssetCategory: String, Codable, CaseIterable, Identifiable {
    case prepaidExpenses = "Prepaid Expenses"
    case supplierAdvances = "Supplier Advances"
    case securityDeposits = "Security Deposits"
    case employeeAdvances = "Employee Advances"
    case taxReceivables = "Tax Receivables"
    case otherReceivables = "Other Receivables"
    case otherCurrentAssets = "Other Current Assets"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .prepaidExpenses: return "calendar.badge.clock"
        case .supplierAdvances: return "shippingbox"
        case .securityDeposits: return "shield"
        case .employeeAdvances: return "person.2"
        case .taxReceivables: return "doc.text"
        case .otherReceivables: return "arrow.down.left"
        case .otherCurrentAssets: return "folder"
        }
    }
}

@Model
final class OtherCurrentAsset {
    var name: String
    var categoryRaw: String
    var originalAmount: Double
    var remainingAmount: Double
    var dateRecorded: Date
    var expectedSettlementDate: Date?
    var counterparty: String
    var reference: String
    var notes: String
    var paymentMethod: String
    var isClosed: Bool

    init(
        name: String,
        category: OtherCurrentAssetCategory,
        originalAmount: Double,
        dateRecorded: Date = .now,
        expectedSettlementDate: Date? = nil,
        counterparty: String = "",
        reference: String = "",
        notes: String = "",
        paymentMethod: String = "Not Specified"
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.originalAmount = originalAmount
        self.remainingAmount = originalAmount
        self.dateRecorded = dateRecorded
        self.expectedSettlementDate = expectedSettlementDate
        self.counterparty = counterparty
        self.reference = reference
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.isClosed = false
    }

    var category: OtherCurrentAssetCategory {
        get {
            OtherCurrentAssetCategory(rawValue: categoryRaw)
                ?? .otherCurrentAssets
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    var amountUtilized: Double {
        max(originalAmount - remainingAmount, 0)
    }
}

