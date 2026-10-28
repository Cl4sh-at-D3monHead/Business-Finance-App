import Foundation
import SwiftData

enum FixedAssetCategory: String, Codable, CaseIterable, Identifiable {
    case furniture = "Furniture & Fixtures"
    case equipment = "Equipment"
    case vehicles = "Vehicles"
    case buildings = "Buildings & Improvements"
    case technology = "Computers & Technology"
    case other = "Other Fixed Assets"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .furniture: return "chair.lounge"
        case .equipment: return "gearshape"
        case .vehicles: return "car"
        case .buildings: return "building.2"
        case .technology: return "desktopcomputer"
        case .other: return "shippingbox"
        }
    }
}

enum AssetDepreciationMethod: String, Codable, CaseIterable, Identifiable {
    case straightLine = "Straight Line"

    var id: String { rawValue }
}



@Model
final class FixedAsset {

    // MARK: - Basic Information
    
    @Attribute(.externalStorage)
    var imageData: Data?
    var name: String
    var categoryRaw: String
    var assetDescription: String
    var supplier: String
    var referenceNumber: String

    // MARK: - Purchase Information

    var purchaseDate: Date
    var availableForUseDate: Date
    var purchaseCost: Double
    var residualValue: Double
    var usefulLifeYears: Int
    var currency: String

    // MARK: - Payment Information

    var paymentMethod: String
    var isPaid: Bool

    // MARK: - Depreciation

    var depreciationMethodRaw: String

    // MARK: - Asset Status

    var isDisposed: Bool
    var disposalDate: Date?

    init(
        name: String,
        category: FixedAssetCategory,
        purchaseCost: Double,
        purchaseDate: Date,
        availableForUseDate: Date? = nil,
        residualValue: Double = 0,
        usefulLifeYears: Int = 5,
        currency: String = "TZS",
        paymentMethod: String = "Cash",
        isPaid: Bool = true,
        supplier: String = "",
        referenceNumber: String = "",
        assetDescription: String = "",
        depreciationMethod: AssetDepreciationMethod = .straightLine
    ) {
        self.imageData = nil
        self.name = name
        self.categoryRaw = category.rawValue
        self.purchaseCost = purchaseCost
        self.purchaseDate = purchaseDate
        self.availableForUseDate = availableForUseDate ?? purchaseDate
        self.residualValue = residualValue
        self.usefulLifeYears = usefulLifeYears
        self.currency = currency
        self.paymentMethod = paymentMethod
        self.isPaid = isPaid
        self.supplier = supplier
        self.referenceNumber = referenceNumber
        self.assetDescription = assetDescription
        self.depreciationMethodRaw = depreciationMethod.rawValue
        self.isDisposed = false
        self.disposalDate = nil
    }

    // MARK: - Category

    var category: FixedAssetCategory {
        get {
            FixedAssetCategory(rawValue: categoryRaw) ?? .other
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    // MARK: - Depreciation Method

    var depreciationMethod: AssetDepreciationMethod {
        get {
            AssetDepreciationMethod(rawValue: depreciationMethodRaw)
                ?? .straightLine
        }
        set {
            depreciationMethodRaw = newValue.rawValue
        }
    }

    // MARK: - Depreciation Calculations

    var depreciableAmount: Double {
        max(purchaseCost - residualValue, 0)
    }

    var annualDepreciation: Double {
        guard usefulLifeYears > 0 else { return 0 }

        return depreciableAmount / Double(usefulLifeYears)
    }

    var monthlyDepreciation: Double {
        annualDepreciation / 12
    }

    func accumulatedDepreciation(asOf date: Date) -> Double {
        guard usefulLifeYears > 0,
              purchaseCost > 0,
              date > availableForUseDate else {
            return 0
        }

        let endDate: Date

        if isDisposed, let disposalDate {
            endDate = min(date, disposalDate)
        } else {
            endDate = date
        }

        guard endDate > availableForUseDate else {
            return 0
        }

        let calendar = Calendar.current

        let totalDays = calendar.dateComponents(
            [.day],
            from: availableForUseDate,
            to: endDate
        ).day ?? 0

        let depreciationEndDate = calendar.date(
            byAdding: .year,
            value: usefulLifeYears,
            to: availableForUseDate
        ) ?? availableForUseDate

        let usefulLifeDays = calendar.dateComponents(
            [.day],
            from: availableForUseDate,
            to: depreciationEndDate
        ).day ?? 0

        guard usefulLifeDays > 0 else {
            return 0
        }

        let proportion = min(
            max(Double(totalDays) / Double(usefulLifeDays), 0),
            1
        )

        return depreciableAmount * proportion
    }

    func carryingValue(asOf date: Date) -> Double {
        max(
            purchaseCost - accumulatedDepreciation(asOf: date),
            residualValue
        )
    }

    func depreciationExpense(
        from startDate: Date,
        to endDate: Date
    ) -> Double {
        guard endDate >= startDate else { return 0 }

        return max(
            accumulatedDepreciation(asOf: endDate)
            - accumulatedDepreciation(asOf: startDate),
            0
        )
    }

    // MARK: - Current Values

    var currentAccumulatedDepreciation: Double {
        accumulatedDepreciation(asOf: Date())
    }

    var currentCarryingValue: Double {
        carryingValue(asOf: Date())
    }

    // MARK: - Status

    var assetStatus: String {
        if isDisposed {
            return "Disposed"
        }

        if currentAccumulatedDepreciation >= depreciableAmount {
            return "Fully Depreciated"
        }

        return "Active"
    }
}
// MARK: - Historical Financial Reporting

extension FixedAsset {

    /// Carrying value of the asset at a selected reporting date.
    /// Returns zero before acquisition or on/after disposal.
    func balanceSheetValue(asOf date: Date, reportingCurrency: String) -> Double {

        // Asset did not exist yet
        guard purchaseDate <= date else {
            return 0
        }

        // Asset has been disposed of by this date
        if isDisposed,
           let disposalDate,
           disposalDate <= date {
            return 0
        }

        // Only include assets matching the reporting currency; no exchange-rate conversion.
        guard currency.uppercased() == reportingCurrency.uppercased() else {
            return 0
        }

        return max(
            carryingValue(asOf: date),
            0
        )
    }
}
