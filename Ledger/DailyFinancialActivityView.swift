import SwiftUI
import SwiftData

struct DailyFinancialActivityView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FinanceTransaction.date, order: .reverse)
    private var transactions: [FinanceTransaction]

    @Query(sort: \StockItem.name)
    private var stockItems: [StockItem]

    @Query private var debtPayments: [DebtPayment]

    let date: Date

    private var dailyTransactions: [FinanceTransaction] {
        transactions.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private var income: Double {
        dailyTransactions
            .filter { $0.type == .revenue }
            .reduce(0) { $0 + $1.amount }
    }

    private var expenses: Double {
        dailyTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var netCashFlow: Double {
        income + debtCollections - expenses - debtRepayments
    }

    private var dailyDebtPayments: [DebtPayment] {
        debtPayments.filter { Calendar.current.isDate($0.paymentDate, inSameDayAs: date) }
    }

    private var debtCollections: Double {
        dailyDebtPayments.filter { $0.debt?.type == .receivable }.reduce(0) { $0 + $1.amount }
    }

    private var debtRepayments: Double {
        dailyDebtPayments.filter { $0.debt?.type == .payable }.reduce(0) { $0 + $1.amount }
    }

    private var dailyCashInflows: Double { income + debtCollections }
    private var dailyCashOutflows: Double { expenses + debtRepayments }

    private var netProfit: Double {
        income - expenses
    }

    private var stockAdded: [StockItem] {
        stockItems.filter {
            Calendar.current.isDate($0.dateAdded, inSameDayAs: date)
        }
    }

    private var stockAddedValue: Double {
        stockAdded.reduce(0) { $0 + $1.stockValue }
    }

    private var groupedExpenses: [(String, Double)] {
        let groups = Dictionary(grouping:
            dailyTransactions.filter { $0.type == .expense },
            by: { $0.category }
        )

        return groups.map { category, items in
            (category, items.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.1 > $1.1 }
    }

    private func currency(_ value: Double) -> String {
        value.formatted(
            .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                .precision(.fractionLength(0))
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Daily Financial Activity")
                            .font(.largeTitle.bold())

                        Text(date.formatted(
                            .dateTime.weekday(.wide)
                                .day()
                                .month(.wide)
                                .year()
                        ))
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 16
                ) {
                    summaryCard(
                        title: "Cash Flow",
                        value: currency(netCashFlow),
                        subtitle: "Cash In: \(currency(dailyCashInflows)) · Out: \(currency(dailyCashOutflows))",
                        icon: "arrow.left.arrow.right"
                    )

                    summaryCard(
                        title: "Profit & Loss",
                        value: currency(netProfit),
                        subtitle: "Income: \(currency(income)) · Expenses: \(currency(expenses))",
                        icon: "chart.bar.fill"
                    )

                    summaryCard(
                        title: "Transactions",
                        value: "\(dailyTransactions.count)",
                        subtitle: "Transactions recorded on this date",
                        icon: "list.bullet.rectangle"
                    )

                    summaryCard(
                        title: "Stock Added",
                        value: "\(stockAdded.count)",
                        subtitle: "Items first recorded on this date",
                        icon: "shippingbox.fill"
                    )
                }

                sectionCard("Cash Flow Summary") {
                    detailRow("Cash Inflows", currency(dailyCashInflows))
                    detailRow("Receivable Collections", currency(debtCollections))
                    detailRow("Cash Outflows", currency(dailyCashOutflows))
                    detailRow("Payable Repayments", currency(debtRepayments))
                    Divider()
                    detailRow(
                        "Net Cash Flow",
                        currency(netCashFlow),
                        bold: true
                    )
                }

                sectionCard("Profit & Loss Summary") {
                    detailRow("Total Income", currency(income))
                    detailRow("Total Expenses", currency(expenses))
                    Divider()
                    detailRow(
                        "Net Profit / Loss",
                        currency(netProfit),
                        bold: true
                    )

                    if !groupedExpenses.isEmpty {
                        Divider()

                        Text("Expense Categories")
                            .font(.headline)

                        ForEach(groupedExpenses, id: \.0) { entry in
                            detailRow(entry.0, currency(entry.1))
                        }
                    }
                }

                sectionCard("Transactions") {
                    if dailyTransactions.isEmpty {
                        emptyMessage("No transactions recorded on this date.")
                    } else {
                        ForEach(dailyTransactions) { transaction in
                            HStack(spacing: 12) {
                                Image(systemName:
                                    transaction.type == .revenue
                                    ? "arrow.down.left.circle.fill"
                                    : "arrow.up.right.circle.fill"
                                )
                                .foregroundStyle(
                                    transaction.type == .revenue
                                    ? Color.green
                                    : Color.red
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.title)
                                        .fontWeight(.semibold)

                                    Text(transaction.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(
                                    "\(transaction.type == .revenue ? "+" : "-")\(currency(transaction.amount))"
                                )
                                .fontWeight(.semibold)
                            }

                            Divider()
                        }
                    }
                }

                sectionCard("Stock Activity") {
                    if stockAdded.isEmpty {
                        emptyMessage("No new stock items were added on this date.")
                    } else {
                        detailRow(
                            "Current Value of Items Added",
                            currency(stockAddedValue),
                            bold: true
                        )

                        Divider()

                        ForEach(stockAdded) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.name)
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Text(item.stockStatus)
                                        .foregroundStyle(.secondary)
                                }

                                detailRow(
                                    "Current Quantity",
                                    item.quantity.formatted()
                                )

                                detailRow(
                                    "Current Stock Value",
                                    currency(item.stockValue)
                                )

                                Divider()
                            }
                        }
                    }

                    Text("Stock quantities and values shown are current, not historical balances.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .frame(minWidth: 850, minHeight: 650)
    }

    private func summaryCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            Text(value)
                .font(.title2.bold())

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.bold())

            Divider()

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailRow(
        _ title: String,
        _ value: String,
        bold: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(bold ? Color.primary : Color.secondary)

            Spacer()

            Text(value)
                .fontWeight(bold ? .bold : .regular)
        }
    }

    private func emptyMessage(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 65)
    }
}
