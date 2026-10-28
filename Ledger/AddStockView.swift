import SwiftUI
import SwiftData

struct AddStockView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BankAccount.name) private var accounts: [BankAccount]

    @State private var name = ""
    @State private var category = ""
    @State private var quantity = ""
    @State private var unitCost = ""
    @State private var sellingPrice = ""
    @State private var reorderLevel = ""
    @State private var targetMargin = "30"
    @State private var recordPurchasePayment = false
    @State private var selectedAccountID: UUID?

    // MARK: - Calculations

    private var quantityValue: Double {
        Double(quantity) ?? 0
    }

    private var unitCostValue: Double {
        Double(unitCost) ?? 0
    }
    
    private var targetMarginValue: Double {
        Double(targetMargin) ?? 0
    }

    private var recommendedSellingPrice: Double {
        guard unitCostValue > 0 else { return 0 }

        let margin = targetMarginValue / 100

        guard margin >= 0 && margin < 1 else { return 0 }

        return unitCostValue / (1 - margin)
    }

    private var sellingPriceValue: Double {
        Double(sellingPrice) ?? 0
    }

    private var reorderLevelValue: Double {
        Double(reorderLevel) ?? 0
    }

    private var stockValue: Double {
        quantityValue * unitCostValue
    }

    private var potentialSalesValue: Double {
        quantityValue * sellingPriceValue
    }

    private var potentialProfit: Double {
        potentialSalesValue - stockValue
    }

    private var profitMargin: Double {
        guard potentialSalesValue > 0 else { return 0 }
        return (potentialProfit / potentialSalesValue) * 100
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        quantityValue > 0 &&
        unitCostValue >= 0 &&
        sellingPriceValue >= 0 &&
        (!recordPurchasePayment || (stockValue > 0 && selectedAccountID != nil))
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header

                    VStack(spacing: 6) {

                        Text("Add Stock")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Add a product to your inventory")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // MARK: Product Information

                    VStack(alignment: .leading, spacing: 16) {

                        Text("Product Information")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {

                            Text("Product Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(
                                "e.g. Cooking Oil 5L",
                                text: $name
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {

                            Text("Category")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(
                                "e.g. Food, Electronics, Clothing",
                                text: $category
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Purchase Payment")
                            .font(.title2.bold())

                        Toggle("Record this stock as a paid purchase", isOn: $recordPurchasePayment)

                        if recordPurchasePayment {
                            Picker("Paid from account", selection: $selectedAccountID) {
                                Text("Select a \(ledgerCurrencyCode) account").tag(nil as UUID?)
                                ForEach(accounts.filter { $0.currencyCode.uppercased() == ledgerCurrencyCode }) { account in
                                    Text(account.name).tag(Optional(account.id))
                                }
                            }

                            Text("The stock cost (\(currency(stockValue))) will be recorded as cost of sales and a withdrawal from the selected account.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // MARK: Stock Details

                    VStack(alignment: .leading, spacing: 16) {

                        Text("Stock Details")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        HStack(spacing: 20) {

                            numberField(
                                title: "Quantity",
                                placeholder: "0",
                                text: $quantity
                            )

                            numberField(
                                title: "Reorder Level",
                                placeholder: "0",
                                text: $reorderLevel
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )

                    // MARK: Pricing

                    VStack(alignment: .leading, spacing: 16) {

                        Text("Pricing")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        // Cost + Target Margin
                        HStack(spacing: 20) {

                            numberField(
                                title: "Unit Cost (\(ledgerCurrencyCode))",
                                placeholder: "0",
                                text: $unitCost
                            )

                            numberField(
                                title: "Target Margin (%)",
                                placeholder: "30",
                                text: $targetMargin
                            )
                        }

                        Divider()

                        // Recommended Selling Price
                        HStack {

                            VStack(alignment: .leading, spacing: 6) {

                                Text("Recommended Selling Price")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(currency(recommendedSellingPrice))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            Button {
                                sellingPrice = String(
                                    format: "%.0f",
                                    recommendedSellingPrice
                                )
                            } label: {
                                Label(
                                    "Use Recommended Price",
                                    systemImage: "wand.and.stars"
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(recommendedSellingPrice <= 0)
                        }

                        Divider()

                        numberField(
                            title: "Selling Price (\(ledgerCurrencyCode))",
                            placeholder: "0",
                            text: $sellingPrice
                        )
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )

                    // MARK: Financial Preview

                    VStack(alignment: .leading, spacing: 16) {

                        HStack {

                            Image(systemName: "chart.bar.fill")

                            Text("Stock Financial Preview")
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Divider()

                        HStack(spacing: 0) {

                            previewItem(
                                title: "Stock Cost",
                                value: currency(stockValue)
                            )

                            Divider()

                            previewItem(
                                title: "Potential Sales",
                                value: currency(potentialSalesValue)
                            )

                            Divider()

                            previewItem(
                                title: "Potential Gross Profit",
                                value: currency(potentialProfit)
                            )

                            Divider()

                            previewItem(
                                title: "Potential Margin",
                                value: String(
                                    format: "%.1f%%",
                                    profitMargin
                                )
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )

                    // MARK: Actions

                    HStack {

                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            saveStock()
                        } label: {

                            Label(
                                "Save Stock",
                                systemImage: "checkmark.circle.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Add Stock")
        }
    }

    // MARK: - Number Field

    private func numberField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                placeholder,
                text: text
            )
            .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preview Item

    private func previewItem(
        title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(.horizontal, 18)
    }

    // MARK: - Save Stock

    private func saveStock() {

        let cleanedName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanedCategory =
            category.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let newItem = StockItem(
            name: cleanedName,
            quantity: quantityValue,
            unitCost: unitCostValue,
            sellingPrice: sellingPriceValue,
            reorderLevel: reorderLevelValue,
            category: cleanedCategory
        )

        modelContext.insert(newItem)

        var purchaseTransaction: FinanceTransaction?
        var bankMovement: BankTransaction?
        if recordPurchasePayment, let accountID = selectedAccountID {
            let purchase = FinanceTransaction(
                title: "Stock purchase - \(cleanedName)",
                amount: stockValue,
                type: .expense,
                category: "Inventory",
                expenseType: .costOfSales,
                notes: "Stock quantity: \(quantityValue.formatted()). Unit cost: \(currency(unitCostValue)).",
                bankAccountID: accountID
            )
            modelContext.insert(purchase)
            let movement = BankTransaction(
                accountID: accountID,
                title: purchase.title,
                amount: stockValue,
                type: .withdrawal,
                notes: purchase.notes
            )
            modelContext.insert(movement)
            purchaseTransaction = purchase
            bankMovement = movement
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(newItem)
            if let purchaseTransaction {
                modelContext.delete(purchaseTransaction)
            }
            if let bankMovement {
                modelContext.delete(bankMovement)
            }
            print(
                "Unable to save stock item: \(error)"
            )
        }
    }

    // MARK: - Currency

    private func currency(
        _ amount: Double
    ) -> String {

        amount.formatted(
            .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                .precision(.fractionLength(0))
        )
    }
}
