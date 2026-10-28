import SwiftUI
import SwiftData

struct StockView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Query(sort: \StockItem.name)
    private var stockItems: [StockItem]

    @State private var showingAddStock = false

    // MARK: - Calculations

    private var totalStockValue: Double {
        stockItems.reduce(0) { $0 + $1.stockValue }
    }

    private var totalSalesValue: Double {
        stockItems.reduce(0) { $0 + $1.potentialSalesValue }
    }

    private var potentialProfit: Double {
        stockItems.reduce(0) { $0 + $1.potentialGrossProfit }
    }

    private var totalUnits: Double {
        stockItems.reduce(0) { $0 + $1.quantity }
    }

    private var lowStockItems: [StockItem] {
        stockItems.filter { $0.isLowStock && !$0.isOutOfStock }
    }

    private var outOfStockItems: [StockItem] {
        stockItems.filter { $0.isOutOfStock }
    }
    
    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header

                    ZStack {
                        Text("Stock")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        HStack {
                            Spacer()

                            Button {
                                showingAddStock = true
                            } label: {
                                Label("Add Stock", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // MARK: Stock Overview

                    VStack(alignment: .leading, spacing: 16) {

                        Text("Stock Overview")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        HStack(spacing: 0) {

                            overviewItem(
                                title: "Stock Value",
                                value: currency(totalStockValue)
                            )

                            Divider()

                            overviewItem(
                                title: "Potential Sales",
                                value: currency(totalSalesValue)
                            )

                            Divider()

                            overviewItem(
                                title: "Potential Profit",
                                value: currency(potentialProfit)
                            )

                            Divider()

                            overviewItem(
                                title: "Products",
                                value: "\(stockItems.count)"
                            )

                            Divider()

                            overviewItem(
                                title: "Low Stock",
                                value: "\(lowStockItems.count)"
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )

                    // MARK: Inventory

                    VStack(alignment: .leading, spacing: 16) {

                        HStack {

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Inventory")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("Current products and stock levels")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(stockItems.count) Items")
                                .fontWeight(.semibold)
                        }

                        Divider()

                        if stockItems.isEmpty {

                            VStack(spacing: 12) {

                                Image(systemName: "shippingbox")
                                    .font(.system(size: 38))
                                    .foregroundStyle(.secondary)

                                Text("No stock recorded")
                                    .font(.headline)

                                Text(
                                    "Add your first product to begin tracking inventory."
                                )
                                .foregroundStyle(.secondary)

                                Button {
                                    showingAddStock = true
                                } label: {
                                    Label(
                                        "Add Stock",
                                        systemImage: "plus.circle.fill"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 260
                            )

                        } else {

                            // Column headings

                            HStack {

                                Text("Product")
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )

                                Text("Quantity")
                                    .frame(width: 120, alignment: .trailing)

                                Text("Unit Cost")
                                    .frame(width: 150, alignment: .trailing)

                                Text("Stock Value")
                                    .frame(width: 160, alignment: .trailing)

                                Text("Status")
                                    .frame(width: 120, alignment: .trailing)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Divider()

                            ForEach(stockItems) { item in

                                NavigationLink {
                                    StockItemDetailView(item: item)
                                } label: {
                                    stockRow(item)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }

                            HStack {

                                Text("Total Stock")
                                    .fontWeight(.bold)

                                Spacer()

                                Text(currency(totalStockValue))
                                    .fontWeight(.bold)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )

                    // MARK: Stock Alerts

                    VStack(alignment: .leading, spacing: 16) {

                        Text("Stock Alerts")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        if lowStockItems.isEmpty &&
                            outOfStockItems.isEmpty {

                            HStack(spacing: 10) {

                                Image(
                                    systemName:
                                        "checkmark.circle.fill"
                                )

                                VStack(
                                    alignment: .leading,
                                    spacing: 3
                                ) {
                                    Text("Stock levels are healthy")
                                        .fontWeight(.semibold)

                                    Text(
                                        "There are currently no low-stock or out-of-stock items."
                                    )
                                    .foregroundStyle(.secondary)
                                }
                            }

                        } else {

                            ForEach(outOfStockItems) { item in

                                HStack {

                                    Image(
                                        systemName:
                                            "exclamationmark.triangle.fill"
                                    )
                                    .foregroundStyle(.red)

                                    Text(item.name)
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Text("Out of Stock")
                                        .foregroundStyle(.red)
                                        .fontWeight(.semibold)
                                }
                            }

                            ForEach(lowStockItems) { item in

                                HStack {

                                    Image(
                                        systemName:
                                            "exclamationmark.circle.fill"
                                    )
                                    .foregroundStyle(.orange)

                                    Text(item.name)
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Text(
                                        "\(quantity(item.quantity)) remaining"
                                    )
                                    .foregroundStyle(.orange)
                                    .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Stock")
            .sheet(isPresented: $showingAddStock) {
                AddStockView()
            }
        }
    }

    // MARK: - Stock Row

    private func stockRow(
        _ item: StockItem
    ) -> some View {

        HStack {

            VStack(alignment: .leading, spacing: 4) {

                Text(item.name)
                    .fontWeight(.semibold)

                if !item.category.isEmpty {
                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )

            Text(quantity(item.quantity))
                .frame(
                    width: 120,
                    alignment: .trailing
                )

            Text(currency(item.unitCost))
                .frame(
                    width: 150,
                    alignment: .trailing
                )

            Text(currency(item.stockValue))
                .fontWeight(.semibold)
                .frame(
                    width: 160,
                    alignment: .trailing
                )

            stockStatus(item)
                .frame(
                    width: 120,
                    alignment: .trailing
                )
        }
        .padding(.vertical, 8)
    }

    // MARK: - Status

    @ViewBuilder
    private func stockStatus(
        _ item: StockItem
    ) -> some View {

        if item.isOutOfStock {

            Label(
                "Out",
                systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.red)
            .font(.caption)
            .fontWeight(.semibold)

        } else if item.isLowStock {

            Label(
                "Low",
                systemImage: "exclamationmark.circle.fill"
            )
            .foregroundStyle(.orange)
            .font(.caption)
            .fontWeight(.semibold)

        } else {

            Label(
                "In Stock",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
            .font(.caption)
            .fontWeight(.semibold)
        }
    }

    // MARK: - Overview Item

    private func overviewItem(
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

    // MARK: - Formatters

    private func currency(
        _ amount: Double
    ) -> String {

        amount.formatted(
            .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                .precision(.fractionLength(0))
        )
    }

    private func quantity(
        _ amount: Double
    ) -> String {

        amount.formatted(
            .number.precision(
                .fractionLength(0...2)
            )
        )
    }
}
