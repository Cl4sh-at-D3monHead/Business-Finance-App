import Foundation
import SwiftData

@Model
final class StockItem {

    // MARK: - Basic Information

    var name: String
    var category: String
    var stockType: String
    var unitOfMeasure: String

    // MARK: - Quantity & Stock Control

    var quantity: Double
    var bufferStock: Double
    var reorderLevel: Double

    // MARK: - Pricing

    var unitCost: Double
    var sellingPrice: Double

    // MARK: - Dates

    var dateAdded: Date
    @Attribute(.externalStorage)
    var photoData: Data?

    // MARK: - Initializer

    init(
        name: String,
        quantity: Double,
        unitCost: Double,
        sellingPrice: Double = 0,
        reorderLevel: Double = 0,
        bufferStock: Double = 0,
        category: String = "",
        stockType: String = "Finished Goods",
        unitOfMeasure: String = "Pieces",
        dateAdded: Date = .now
    ) {
        self.name = name
        self.quantity = quantity
        self.unitCost = unitCost
        self.sellingPrice = sellingPrice
        self.reorderLevel = reorderLevel
        self.bufferStock = bufferStock
        self.category = category
        self.stockType = stockType
        self.unitOfMeasure = unitOfMeasure
        self.dateAdded = dateAdded
    }

    // MARK: - Financial Calculations

    var stockValue: Double {
        quantity * unitCost
    }

    var potentialSalesValue: Double {
        quantity * sellingPrice
    }

    var potentialGrossProfit: Double {
        potentialSalesValue - stockValue
    }

    var potentialProfitMargin: Double {
        guard potentialSalesValue > 0 else {
            return 0
        }

        return (
            potentialGrossProfit /
            potentialSalesValue
        ) * 100
    }

    // MARK: - Stock Availability

    /// Quantity available for normal use/sale
    /// after protecting buffer stock.
    var availableStock: Double {
        max(quantity - bufferStock, 0)
    }

    /// Value of stock reserved as buffer.
    var bufferStockValue: Double {
        min(quantity, bufferStock) * unitCost
    }

    /// Value of stock available above buffer.
    var availableStockValue: Double {
        availableStock * unitCost
    }

    // MARK: - Stock Status

    var isOutOfStock: Bool {
        quantity <= 0
    }

    var isInBufferStock: Bool {
        quantity > 0 &&
        bufferStock > 0 &&
        quantity <= bufferStock
    }

    var isLowStock: Bool {
        quantity > bufferStock &&
        reorderLevel > 0 &&
        quantity <= reorderLevel
    }

    var needsReorder: Bool {
        !isOutOfStock &&
        reorderLevel > 0 &&
        quantity <= reorderLevel
    }

    var stockStatus: String {

        if isOutOfStock {
            return "Out of Stock"
        }

        if isInBufferStock {
            return "Buffer Stock"
        }

        if isLowStock {
            return "Low Stock"
        }

        return "In Stock"
    }
}
