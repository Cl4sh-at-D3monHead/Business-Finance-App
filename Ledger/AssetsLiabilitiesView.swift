import SwiftUI
import SwiftData

struct AssetsLiabilitiesView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    // MARK: - Data

    @Query private var debts: [Debt]
    @Query private var stockItems: [StockItem]
    @Query private var otherCurrentAssets: [OtherCurrentAsset]
    @Query private var fixedAssets: [FixedAsset]
    @Query private var bankAccounts: [BankAccount]
    @Query private var bankTransactions: [BankTransaction]
    @Query private var liabilities: [Liability]
    // MARK: - Calculations

    private var receivables: Double {
        debts
            .filter { $0.type == .receivable }
            .reduce(0) { $0 + $1.outstandingBalance }
    }

    private var payables: Double {
        debts
            .filter { $0.type == .payable }
            .reduce(0) { $0 + $1.outstandingBalance }
    }

    private var inventoryValue: Double {
        stockItems.reduce(0) { $0 + $1.stockValue }
    }

    private var otherCurrentAssetsTotal: Double {
        otherCurrentAssets.filter { !$0.isClosed }.reduce(0) { total, asset in
            total + max(asset.remainingAmount, 0)
        }
    }

    private var currentAssetsTotal: Double {
        cashAndBankTotal
        + receivables
        + inventoryValue
        + otherCurrentAssetsTotal
    }
    
    private var fixedAssetsTotal: Double {
        fixedAssets
            .filter { !$0.isDisposed && $0.currency.uppercased() == ledgerCurrencyCode }
            .reduce(0) { total, asset in
                total + max(asset.currentCarryingValue, 0)
            }
    }

    private var cashAndBankTotal: Double {
        bankAccounts
            .filter { $0.currencyCode.uppercased() == ledgerCurrencyCode }
            .reduce(0) { total, account in
                total + BankBalanceCalculator.balance(
                    for: account,
                    transactions: bankTransactions,
                    asOf: .now
                )
            }
    }

    private var knownAssets: Double {
        currentAssetsTotal + fixedAssetsTotal
    }
    
    private var otherCurrentLiabilitiesTotal: Double {
        liabilities
            .filter { $0.currencyCode.uppercased() == ledgerCurrencyCode }
            .reduce(0) { $0 + $1.currentBalance(asOf: .now) }
    }

    private var nonCurrentLiabilitiesTotal: Double {
        liabilities
            .filter { $0.currencyCode.uppercased() == ledgerCurrencyCode }
            .reduce(0) { $0 + $1.nonCurrentBalance(asOf: .now) }
    }

    private var totalCurrentLiabilities: Double {
        payables + otherCurrentLiabilitiesTotal
    }

    private var knownLiabilities: Double {
        totalCurrentLiabilities + nonCurrentLiabilitiesTotal
    }

    private var knownNetAssets: Double {
        knownAssets - knownLiabilities
    }

    // MARK: - Formatting

    private func money(_ amount: Double) -> String {
        "\(ledgerCurrencyCode) " + amount.formatted(
            .number.precision(.fractionLength(0))
        )
    }

    // MARK: - Main View

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Assets & Liabilities")
                            .font(.largeTitle.bold())

                        Text("Your business financial position")
                            .foregroundStyle(.secondary)
                    }

                    // MARK: Summary Cards

                    HStack(spacing: 16) {
                        summaryCard(
                            title: "Recorded Assets",
                            amount: knownAssets,
                            icon: "building.columns"
                        )

                        summaryCard(
                            title: "Recorded Liabilities",
                            amount: knownLiabilities,
                            icon: "creditcard"
                        )

                        summaryCard(
                            title: "Net Recorded Position",
                            amount: knownNetAssets,
                            icon: "chart.bar"
                        )
                    }

                    // MARK: Assets and Liabilities

                    HStack(alignment: .top, spacing: 18) {

                        // MARK: Assets Panel

                        VStack(alignment: .leading, spacing: 16) {

                            NavigationLink {
                                AssetCategoriesView()
                            } label: {
                                HStack(spacing: 8) {
                                    sectionTitle(
                                        "Assets",
                                        icon: "plus.circle"
                                    )

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            financialRow(
                                "Cash & Bank (\(ledgerCurrencyCode))",
                                amount: cashAndBankTotal
                            )

                            financialRow(
                                "Accounts Receivable",
                                amount: receivables
                            )

                            financialRow(
                                "Inventory",
                                amount: inventoryValue
                            )

                            financialRow(
                                "Other Current Assets",
                                amount: otherCurrentAssetsTotal
                            )

                            Divider()

                            financialRow(
                                "Total Current Assets",
                                amount: currentAssetsTotal,
                                bold: true
                            )

                            Divider()
                            
                            financialRow(
                                "Non-Current / Fixed Assets",
                                amount: fixedAssetsTotal
                            )

                            Divider()

                            financialRow(
                                "Total Recorded Assets",
                                amount: knownAssets,
                                bold: true
                            )
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.primary.opacity(0.045),
                            in: RoundedRectangle(cornerRadius: 18)
                        )

                        // MARK: Liabilities Panel

                        VStack(alignment: .leading, spacing: 16) {

                            NavigationLink {
                                LiabilitiesView()
                            } label: {
                                HStack(spacing: 8) {
                                    sectionTitle(
                                        "Liabilities",
                                        icon: "minus.circle"
                                    )

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            financialRow(
                                "Accounts Payable",
                                amount: payables
                            )

                            financialRow(
                                "Other Current Liabilities",
                                amount: otherCurrentLiabilitiesTotal
                            )

                            Divider()

                            financialRow(
                                "Total Current Liabilities",
                                amount: totalCurrentLiabilities,
                                bold: true
                            )

                            Divider()

                            financialRow(
                                "Non-Current Liabilities",
                                amount: nonCurrentLiabilitiesTotal
                            )

                            Divider()

                            financialRow(
                                "Total Recorded Liabilities",
                                amount: knownLiabilities,
                                bold: true
                            )
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.primary.opacity(0.045),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                    }

                    // MARK: Information

                    Text(
                        "This is a partial financial position. Cash & Bank currently reflects recorded \(ledgerCurrencyCode) opening balances only, not live balances. Foreign currency accounts, other liabilities and equity are not yet fully connected. The figures should not be treated as a complete Balance Sheet."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                }
                .padding(24)
            }
        }
    }

    // MARK: - Summary Card

    private func summaryCard(
        title: String,
        amount: Double,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 16) {

            Image(systemName: icon)
                .font(.title3)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(money(amount))
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Section Title

    private func sectionTitle(
        _ title: String,
        icon: String
    ) -> some View {

        HStack(spacing: 10) {
            Image(systemName: icon)

            Text(title)
                .font(.title3.bold())
        }
    }

    // MARK: - Financial Row

    private func financialRow(
        _ title: String,
        amount: Double,
        bold: Bool = false
    ) -> some View {

        HStack {

            Text(title)
                .fontWeight(bold ? .semibold : .regular)

            Spacer()

            Text(money(amount))
                .fontWeight(bold ? .bold : .medium)
        }
    }
}

