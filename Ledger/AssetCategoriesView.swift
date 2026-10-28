import SwiftUI
import SwiftData

struct AssetCategoriesView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Query private var assets: [FixedAsset]
    @Query private var debts: [Debt]
    @Query private var stockItems: [StockItem]
    @Query private var otherCurrentAssets: [OtherCurrentAsset]
    @Query private var bankAccounts: [BankAccount]
    @Query private var bankTransactions: [BankTransaction]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var activeAssets: [FixedAsset] {
        assets.filter { !$0.isDisposed }
    }

    private var fixedAssetValue: Double {
        activeAssets.filter { $0.currency.uppercased() == ledgerCurrencyCode }.reduce(0) {
            $0 + $1.currentCarryingValue
        }
    }

    private var cashAndBankValue: Double {
        BankBalanceCalculator.totalBalance(
            currencyCode: ledgerCurrencyCode,
            accounts: bankAccounts,
            transactions: bankTransactions,
            asOf: .now
        )
    }

    private var receivablesValue: Double {
        debts
            .filter { $0.type == .receivable }
            .reduce(0) { $0 + $1.outstandingBalance }
    }

    private var inventoryValue: Double {
        stockItems.reduce(0) {
            $0 + $1.stockValue
        }
    }

    private var otherCurrentAssetsValue: Double {
        otherCurrentAssets
            .filter { !$0.isClosed }
            .reduce(0) { total, asset in
                total + max(asset.remainingAmount, 0)
            }
    }

    private var currentAssetValue: Double {
        cashAndBankValue + receivablesValue + inventoryValue + otherCurrentAssetsValue
    }
    
    private var totalAssetValue: Double {
        currentAssetValue + fixedAssetValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: Header

                VStack(alignment: .leading, spacing: 6) {
                    Text("Assets")
                        .font(.largeTitle.bold())

                    Text("Manage your business current and non-current assets")
                        .foregroundStyle(.secondary)
                }

                // MARK: Summary

                HStack(spacing: 16) {
                    summaryCard(
                        title: "Current Assets",
                        value: currency(currentAssetValue),
                        icon: "wallet.bifold"
                    )

                    summaryCard(
                        title: "Non-Current Assets",
                        value: currency(fixedAssetValue),
                        icon: "building.2"
                    )

                    summaryCard(
                        title: "Total Recorded Assets",
                        value: currency(totalAssetValue),
                        icon: "chart.bar"
                    )
                }

                // MARK: Current Assets

                VStack(alignment: .leading, spacing: 16) {

                    Text("Current Assets")
                        .font(.title2.bold())

                    LazyVGrid(columns: columns, spacing: 16) {

                        NavigationLink {
                            CashBankAssetsView()
                        } label: {
                            currentAssetCard(
                                title: "Cash & Bank",
                                subtitle: "Cash and bank balances",
                                value: currency(cashAndBankValue),
                                icon: "building.columns"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink {
                            DebtsView()
                        } label: {
                            currentAssetCard(
                                title: "Accounts Receivable",
                                subtitle: "Outstanding customer balances",
                                value: currency(receivablesValue),
                                icon: "person.crop.circle.badge.clock"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            StockView()
                        } label: {
                            currentAssetCard(
                                title: "Inventory",
                                subtitle: "\(stockItems.count) stock items",
                                value: currency(inventoryValue),
                                icon: "shippingbox"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            OtherCurrentAssetsView()
                        } label: {
                            currentAssetCard(
                                title: "Other Current Assets",
                                subtitle: "Prepayments, deposits and advances",
                                value: currency(otherCurrentAssetsValue),
                                icon: "doc.text"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // MARK: Non-Current Assets

                VStack(alignment: .leading, spacing: 16) {

                    Text("Non-Current / Fixed Assets")
                        .font(.title2.bold())

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(FixedAssetCategory.allCases) { category in

                            NavigationLink {
                                AssetCategoryDetailView(category: category)
                            } label: {
                                categoryCard(category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

            }
            .padding(24)
        }
        .navigationTitle("Assets")
    }

    // MARK: Summary Card

    private func summaryCard(
        title: String,
        value: String,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Current Asset Card

    private func currentAssetCard(
        title: String,
        subtitle: String,
        value: String,
        icon: String
    ) -> some View {

        HStack(spacing: 16) {

            Image(systemName: icon)
                .font(.title2)
                .frame(width: 45, height: 45)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.bold())
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }

    // MARK: Fixed Asset Category Card

    private func categoryCard(
        _ category: FixedAssetCategory
    ) -> some View {

        let categoryAssets = activeAssets.filter {
            $0.category == category
        }

        let value = categoryAssets.reduce(0) {
            $0 + $1.currentCarryingValue
        }

        return HStack(spacing: 16) {

            Image(systemName: category.icon)
                .font(.title2)
                .frame(width: 45, height: 45)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {

                Text(category.rawValue)
                    .font(.headline)

                Text("\(categoryAssets.count) assets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(currency(value))
                    .font(.subheadline.bold())
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }

    private func currency(_ amount: Double) -> String {
        "\(ledgerCurrencyCode) \(amount.formatted(.number.precision(.fractionLength(0))))"
    }
}

