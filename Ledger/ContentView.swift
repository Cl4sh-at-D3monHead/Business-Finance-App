import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    // MARK: - Data

    @Query(sort: \FinanceTransaction.date, order: .reverse)
    private var transactions: [FinanceTransaction]

    @Query private var debts: [Debt]

    @Query private var debtPayments: [DebtPayment]

    @Query private var recurringExpenses: [RecurringExpense]

    @Query(sort: \StockItem.name)
    private var stockItems: [StockItem]

    // MARK: - State

    @State private var showingAddTransaction = false
    @State private var transactionToEdit: FinanceTransaction?

    @State private var selectedMonth = Date()

    // MARK: - Selected Period

    private var selectedMonthTitle: String {
        selectedMonth.formatted(
            .dateTime.month(.wide).year()
        )
    }

    private var selectedMonthInterval: DateInterval? {
        Calendar.current.dateInterval(
            of: .month,
            for: selectedMonth
        )
    }

    private var monthlyTransactions: [FinanceTransaction] {
        guard let interval = selectedMonthInterval else {
            return []
        }

        return transactions.filter {
            interval.contains($0.date)
        }
    }

    private var monthlyDebtPayments: [DebtPayment] {
        guard let interval = selectedMonthInterval else {
            return []
        }

        return debtPayments.filter {
            interval.contains($0.paymentDate)
        }
    }

    // MARK: - Month Navigation

    private func changeMonth(by value: Int) {
        guard let newMonth = Calendar.current.date(
            byAdding: .month,
            value: value,
            to: selectedMonth
        ) else {
            return
        }

        selectedMonth = newMonth
    }

    private var canMoveForward: Bool {
        let calendar = Calendar.current

        let selectedComponents = calendar.dateComponents(
            [.year, .month],
            from: selectedMonth
        )

        let currentComponents = calendar.dateComponents(
            [.year, .month],
            from: Date()
        )

        guard
            let selectedYear = selectedComponents.year,
            let selectedMonthNumber = selectedComponents.month,
            let currentYear = currentComponents.year,
            let currentMonthNumber = currentComponents.month
        else {
            return false
        }

        if selectedYear < currentYear {
            return true
        }

        if selectedYear == currentYear &&
            selectedMonthNumber < currentMonthNumber {
            return true
        }

        return false
    }

    // MARK: - Sales

    private var salesTransactions: [FinanceTransaction] {
        monthlyTransactions.filter {
            $0.type == .revenue
        }
    }

    private var numberOfSales: Int {
        salesTransactions.count
    }

    private var totalRevenue: Double {
        salesTransactions.reduce(0) {
            $0 + $1.amount
        }
    }

    private var averageSaleValue: Double {
        guard numberOfSales > 0 else {
            return 0
        }

        return totalRevenue / Double(numberOfSales)
    }

    // MARK: - Expenses

    private var costOfSales: Double {
        monthlyTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .costOfSales
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    private var grossProfit: Double {
        totalRevenue - costOfSales
    }

    private var operatingExpenses: Double {
        monthlyTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .operatingExpense
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    private var operatingProfit: Double {
        grossProfit - operatingExpenses
    }

    private var financeCosts: Double {
        monthlyTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .financeCost
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    private var taxExpenses: Double {
        monthlyTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .tax
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    private var otherExpenses: Double {
        monthlyTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .other
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    private var totalExpenses: Double {
        monthlyTransactions
            .filter {
                $0.type == .expense
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    // MARK: - Profit

    private var netProfit: Double {
        operatingProfit
            - financeCosts
            - taxExpenses
            - otherExpenses
    }

    private var netMargin: Double {
        guard totalRevenue > 0 else {
            return 0
        }

        return (netProfit / totalRevenue) * 100
    }

    // MARK: - Cash Flow

    private var debtCollections: Double {
        monthlyDebtPayments
            .filter {
                $0.debt?.type == .receivable
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    private var debtRepayments: Double {
        monthlyDebtPayments
            .filter {
                $0.debt?.type == .payable
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }

    private var unrecordedRecurringExpenses: Double {
        let calendar = Calendar.current
        let selected = calendar.date(
            from: calendar.dateComponents([.year, .month], from: selectedMonth)
        ) ?? selectedMonth

        return recurringExpenses.reduce(0) { total, expense in
            let start = calendar.date(
                from: calendar.dateComponents([.year, .month], from: expense.startDate)
            ) ?? expense.startDate
            guard expense.isActive, selected >= start else { return total }

            if let endDate = expense.endDate {
                let end = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: endDate)
                ) ?? endDate
                guard selected <= end else { return total }
            }

            let alreadyRecorded = transactions.contains {
                $0.type == .expense && $0.title == expense.title && $0.category == expense.category
                    && calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
                    && calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .year)
            }
            return total + (alreadyRecorded ? 0 : expense.amount)
        }
    }

    private var cashInflows: Double {
        totalRevenue + debtCollections
    }

    private var cashOutflows: Double {
        totalExpenses + debtRepayments + unrecordedRecurringExpenses
    }

    private var netCashFlow: Double {
        cashInflows - cashOutflows
    }

    // MARK: - Stock

    private var stockItemCount: Int {
        stockItems.count
    }

    private var lowStockItems: [StockItem] {
        stockItems.filter {
            $0.isLowStock && !$0.isOutOfStock
        }
    }

    private var outOfStockItems: [StockItem] {
        stockItems.filter {
            $0.isOutOfStock
        }
    }

    private var stockHealth: String {

        if stockItems.isEmpty {
            return "No Stock"
        }

        if !outOfStockItems.isEmpty {
            return "\(outOfStockItems.count) Out of Stock"
        }

        if !lowStockItems.isEmpty {
            return "\(lowStockItems.count) Low Stock"
        }

        return "Healthy"
    }

    private var stockHealthIcon: String {

        if stockItems.isEmpty {
            return "shippingbox"
        }

        if !outOfStockItems.isEmpty {
            return "exclamationmark.triangle.fill"
        }

        if !lowStockItems.isEmpty {
            return "exclamationmark.circle.fill"
        }

        return "checkmark.circle.fill"
    }

    // MARK: - Recent Transactions

    private var recentTransactions: [FinanceTransaction] {
        Array(monthlyTransactions.prefix(5))
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 20) {

                    // MARK: Header

                    HStack(alignment: .center) {

                        VStack(alignment: .leading, spacing: 5) {

                            Text("Business Finance")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Financial Overview")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // MARK: Month Selector

                    HStack {

                        Button {
                            changeMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        VStack(spacing: 3) {

                            Text(selectedMonthTitle)
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("Reporting Period")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            changeMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canMoveForward)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 15)
                    )

                    // MARK: Dashboard Cards

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 15
                    ) {

                        // STOCK

                        DashboardInfoCard(
                            title: "Stock",
                            icon: "shippingbox.fill",
                            primaryLabel: "Stock Items",
                            primaryValue: "\(stockItemCount)",
                            secondaryLabel: "Stock Health",
                            secondaryValue: stockHealth,
                            secondaryIcon: stockHealthIcon
                        )

                        // SALES

                        DashboardInfoCard(
                            title: "Sales",
                            icon: "cart.fill",
                            primaryLabel: "Total Sales",
                            primaryValue: "\(numberOfSales)",
                            secondaryLabel: "Average Sale",
                            secondaryValue: currency(averageSaleValue)
                        )

                        // CASH FLOW

                        DashboardInfoCard(
                            title: "Cash Flow",
                            icon: "arrow.left.arrow.right",
                            primaryLabel: "Net Cash Flow",
                            primaryValue: currency(netCashFlow),
                            secondaryLabel: "Cash In / Out",
                            secondaryValue:
                                "\(currency(cashInflows)) / \(currency(cashOutflows))"
                        )

                        // PROFIT & LOSS

                        DashboardInfoCard(
                            title: "Profit & Loss",
                            icon: "chart.bar.fill",
                            primaryLabel:
                                netProfit >= 0
                                ? "Net Profit"
                                : "Net Loss",
                            primaryValue: currency(netProfit),
                            secondaryLabel: "Net Margin",
                            secondaryValue:
                                "\(netMargin.formatted(.number.precision(.fractionLength(1))))%"
                        )
                    }

                    // MARK: Financial Insight

                    VStack(alignment: .leading, spacing: 10) {

                        Label(
                            "Financial Insight",
                            systemImage: "lightbulb"
                        )
                        .font(.headline)

                        Text(financialInsight)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 15)
                    )

                    // MARK: Forecast

                    NavigationLink {
                        ForecastView()
                    } label: {

                        VStack(alignment: .leading, spacing: 10) {

                            HStack {

                                Label(
                                    "Next Month Forecast",
                                    systemImage: "chart.xyaxis.line"
                                )
                                .font(.headline)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }

                            Text(
                                "Forecast Revenue: \(currency(totalRevenue))"
                            )

                            Text(
                                "Forecast Expenses: \(currency(totalExpenses))"
                            )

                            Text(
                                "Forecast Cash Flow: \(currency(netCashFlow))"
                            )
                        }
                        .padding()
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .background(.regularMaterial)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 15)
                        )
                    }
                    .buttonStyle(.plain)

                    // MARK: Recent Transactions

                    VStack(alignment: .leading, spacing: 12) {

                        HStack {

                            Text("Recent Transactions")
                                .font(.headline)

                            Spacer()

                            Text(selectedMonthTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if recentTransactions.isEmpty {

                            VStack(
                                alignment: .leading,
                                spacing: 6
                            ) {

                                Text(
                                    "No transactions recorded for \(selectedMonthTitle)."
                                )
                                .foregroundStyle(.secondary)

                                Text(
                                    "Use the + button to add a transaction."
                                )
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            }

                        } else {

                            ForEach(
                                Array(recentTransactions.enumerated()),
                                id: \.element.id
                            ) { index, transaction in

                                Button {

                                    transactionToEdit = transaction

                                } label: {

                                    HStack(spacing: 15) {

                                        VStack(
                                            alignment: .leading,
                                            spacing: 5
                                        ) {

                                            Text(transaction.title)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.primary)

                                            HStack(spacing: 8) {

                                                Text(
                                                    transaction.date.formatted(
                                                        date: .abbreviated,
                                                        time: .omitted
                                                    )
                                                )

                                                Text("•")

                                                Text(transaction.category)

                                                if transaction.isRecurring {

                                                    Label(
                                                        "Recurring",
                                                        systemImage: "repeat"
                                                    )
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        VStack(
                                            alignment: .trailing,
                                            spacing: 4
                                        ) {

                                            Text(
                                                currency(
                                                    transaction.amount
                                                )
                                            )
                                            .fontWeight(.semibold)
                                            .foregroundStyle(
                                                transaction.type == .revenue
                                                ? .green
                                                : .primary
                                            )

                                            Text(
                                                transaction.type == .revenue
                                                ? "Sale"
                                                : "Expense"
                                            )
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)

                                if index <
                                    recentTransactions.count - 1 {

                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 15)
                    )
                }
                .padding()
            }
            .navigationTitle("Dashboard")

            // MARK: Add Button

            .toolbar {

                ToolbarItem(
                    placement: .primaryAction
                ) {

                    Button {

                        showingAddTransaction = true

                    } label: {

                        Label(
                            "Add Transaction",
                            systemImage: "plus"
                        )
                    }
                }
            }

            .sheet(
                isPresented: $showingAddTransaction
            ) {

                AddTransactionView()
            }

            .sheet(
                item: $transactionToEdit
            ) { transaction in

                EditTransactionView(
                    transaction: transaction
                )
            }
        }
    }

    // MARK: - Financial Insight

    private var financialInsight: String {

        guard !monthlyTransactions.isEmpty else {

            return """
            No financial activity has been recorded for \(selectedMonthTitle). Add transactions or select another month to view insights.
            """
        }

        if totalRevenue == 0 && totalExpenses > 0 {

            return """
            \(selectedMonthTitle) has \(currency(totalExpenses)) of expenses but no recorded revenue.
            """
        }

        if totalExpenses > totalRevenue {

            let deficit =
                totalExpenses - totalRevenue

            return """
            Expenses exceeded revenue by \(currency(deficit)) in \(selectedMonthTitle). Review the largest expense categories and cash commitments.
            """
        }

        if totalRevenue > 0 {

            let expenseRatio =
                (totalExpenses / totalRevenue) * 100

            if netCashFlow < 0 {

                return """
                Expenses represent \(expenseRatio.formatted(.number.precision(.fractionLength(1))))% of revenue. Profit is \(currency(netProfit)), but net cash flow is negative at \(currency(netCashFlow)). Review collections, debt repayments and other cash movements.
                """
            }

            return """
            Expenses represent \(expenseRatio.formatted(.number.precision(.fractionLength(1))))% of revenue. Net profit is \(currency(netProfit)) and net cash flow is \(currency(netCashFlow)) for \(selectedMonthTitle).
            """
        }

        return """
        Continue recording transactions to improve your financial analysis.
        """
    }

    // MARK: - Currency Formatter

    private func currency(
        _ amount: Double
    ) -> String {

        amount.formatted(
            .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                .precision(.fractionLength(0))
        )
    }
}


// MARK: - Dashboard Info Card

struct DashboardInfoCard: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    let title: String
    let icon: String

    let primaryLabel: String
    let primaryValue: String

    let secondaryLabel: String
    let secondaryValue: String

    var secondaryIcon: String? = nil

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            Divider()

            HStack(
                alignment: .bottom,
                spacing: 20
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(primaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(primaryValue)
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 5
                ) {

                    Text(secondaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 5) {

                        if let secondaryIcon {

                            Image(
                                systemName: secondaryIcon
                            )
                            .font(.caption)
                        }

                        Text(secondaryValue)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            minHeight: 145,
            alignment: .leading
        )
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 15)
        )
    }
}
