import SwiftUI
import SwiftData
import AppKit

enum LedgerReport: String, CaseIterable, Identifiable {
    case balanceSheet = "Balance Sheet"
    case incomeStatement = "Income Statement"
    case cashFlow = "Cash Flow Statement"
    case profitLoss = "Profit & Loss"
    case trialBalance = "Trial Balance"

    var id: String { rawValue }
}

struct ReportsView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    @Query private var transactions: [FinanceTransaction]
    @Query private var stockItems: [StockItem]
    @Query private var debts: [Debt]
    @Query private var otherCurrentAssets: [OtherCurrentAsset]
    @Query private var fixedAssets: [FixedAsset]
    @Query private var bankAccounts: [BankAccount]
    @Query private var bankTransactions: [BankTransaction]
    @Query private var liabilities: [Liability]
    @Query private var debtPayments: [DebtPayment]
    @Query private var recurringExpenses: [RecurringExpense]

    @State private var selectedReport: LedgerReport
    @State private var period = "Month"
    @State private var selectedDate = Date()
    @State private var showingEditor = false
    @State private var editedReportText = ""
    @State private var savedReportText: String?

    init(report: LedgerReport = .trialBalance) {
        _selectedReport = State(initialValue: report)
    }

    private var filteredTransactions: [FinanceTransaction] {
        transactions.filter { transaction in
            let calendar = Calendar.current

            switch period {
            case "Month":
                return calendar.isDate(
                    transaction.date,
                    equalTo: selectedDate,
                    toGranularity: .month
                )

            case "Year":
                return calendar.isDate(
                    transaction.date,
                    equalTo: selectedDate,
                    toGranularity: .year
                )

            default:
                return true
            }
        }
    }

    private var revenue: Double {
        filteredTransactions
            .filter { $0.type == .revenue }
            .reduce(0) { $0 + $1.amount }
    }

    private var expenses: Double {
        filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var netProfit: Double {
        revenue - expenses
    }

    private var filteredDebtPayments: [DebtPayment] {
        debtPayments.filter { payment in
            switch period {
            case "Month":
                return Calendar.current.isDate(payment.paymentDate, equalTo: selectedDate, toGranularity: .month)
                    && Calendar.current.isDate(payment.paymentDate, equalTo: selectedDate, toGranularity: .year)
            case "Year":
                return Calendar.current.isDate(payment.paymentDate, equalTo: selectedDate, toGranularity: .year)
            default:
                return true
            }
        }
    }

    private var debtCollections: Double {
        filteredDebtPayments.filter { $0.debt?.type == .receivable }.reduce(0) { $0 + $1.amount }
    }

    private var debtRepayments: Double {
        filteredDebtPayments.filter { $0.debt?.type == .payable }.reduce(0) { $0 + $1.amount }
    }

    private var cashInflows: Double { revenue + debtCollections }
    private var cashOutflows: Double { expenses + debtRepayments + unrecordedRecurringExpenses }
    private var netCashFlow: Double { cashInflows - cashOutflows }

    private func recurringExpenseIsActive(_ expense: RecurringExpense, in month: Date) -> Bool {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: expense.startDate)) ?? expense.startDate
        let target = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        guard expense.isActive, target >= start else { return false }
        if let endDate = expense.endDate {
            let end = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate)) ?? endDate
            guard target <= end else { return false }
        }
        return true
    }

    private func recurringExpenseIsRecorded(_ expense: RecurringExpense, in month: Date) -> Bool {
        transactions.contains {
            $0.type == .expense && $0.title == expense.title && $0.category == expense.category
                && Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
                && Calendar.current.isDate($0.date, equalTo: month, toGranularity: .year)
        }
    }

    private var reportMonths: [Date] {
        let calendar = Calendar.current
        switch period {
        case "Month": return [selectedDate]
        case "Year":
            guard let interval = calendar.dateInterval(of: .year, for: selectedDate) else { return [] }
            return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: interval.start) }
        default:
            let dates = transactions.map(\.date) + debtPayments.map(\.paymentDate) + recurringExpenses.map(\.startDate)
            guard let first = dates.min(), let last = dates.max() else { return [] }
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: first)) ?? first
            let end = calendar.date(from: calendar.dateComponents([.year, .month], from: last)) ?? last
            var months: [Date] = []
            var month = start
            while month <= end {
                months.append(month)
                guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
                month = next
            }
            return months
        }
    }

    private var unrecordedRecurringExpenses: Double {
        reportMonths.reduce(0) { total, month in
            total + recurringExpenses.reduce(0) { subtotal, expense in
                guard recurringExpenseIsActive(expense, in: month),
                      !recurringExpenseIsRecorded(expense, in: month) else { return subtotal }
                return subtotal + expense.amount
            }
        }
    }
    
    // MARK: - Historical Debt Balances

    private func debtBalance(
        _ debt: Debt,
        asOf date: Date
    ) -> Double {
        debt.outstandingBalance(asOf: date)
    }

    // MARK: - Accounts Receivable

    private var receivablesTotal: Double {
        debts
            .filter { $0.type == .receivable }
            .reduce(0.0) { total, debt in
                total + debtBalance(
                    debt,
                    asOf: reportingDate
                )
            }
    }

    // MARK: - Accounts Payable

    private var payablesTotal: Double {
        debts
            .filter { $0.type == .payable }
            .reduce(0.0) { total, debt in
                total + debtBalance(
                    debt,
                    asOf: reportingDate
                )
            }
    }

    private var inventoryTotal: Double {
        stockItems.filter { $0.dateAdded <= reportingDate }.reduce(0) { $0 + $1.stockValue }
    }

    private var otherCurrentAssetsTotal: Double {
        otherCurrentAssets.filter { !$0.isClosed && $0.dateRecorded <= reportingDate }.reduce(0) {
            $0 + max($1.remainingAmount, 0)
        }
    }

    private var fixedAssetsTotal: Double {
        fixedAssetsValue(asOf: reportingDate)
    }
    
    private func fixedAssetsValue(asOf date: Date) -> Double {
        fixedAssets.reduce(0) { total, asset in
            total + asset.balanceSheetValue(asOf: date, reportingCurrency: ledgerCurrencyCode)
        }
    }

    private var bankBalanceInReportingCurrency: Double {
        BankBalanceCalculator.totalBalance(
            currencyCode: ledgerCurrencyCode,
            accounts: bankAccounts,
            transactions: bankTransactions,
            asOf: reportingDate
        )
    }

    private var recordedAssetsTotal: Double {
        inventoryTotal
        + receivablesTotal
        + otherCurrentAssetsTotal
        + fixedAssetsTotal
        + bankBalanceInReportingCurrency
    }
    
    // MARK: - Historical Liability Balances

    private var otherCurrentLiabilitiesTotal: Double {
        liabilities
            .filter { $0.currencyCode.uppercased() == ledgerCurrencyCode }
            .reduce(0.0) { total, liability in
                total + liability.currentBalance(asOf: reportingDate)
            }
    }

    private var nonCurrentLiabilitiesTotal: Double {
        liabilities
            .filter {
                $0.currencyCode.uppercased() == ledgerCurrencyCode
            }
            .reduce(0.0) { total, liability in
                total + liability.nonCurrentBalance(asOf: reportingDate)
            }
    }

    private var currentLiabilitiesTotal: Double {
        payablesTotal + otherCurrentLiabilitiesTotal
    }

    private var recordedLiabilitiesTotal: Double {
        currentLiabilitiesTotal + nonCurrentLiabilitiesTotal
    }

    private var netRecordedPosition: Double {
        recordedAssetsTotal - recordedLiabilitiesTotal
    }

    private var expenseGroups: [(String, Double)] {
        let groups = Dictionary(
            grouping: filteredTransactions.filter {
                $0.type == .expense
            },
            by: { $0.category }
        )

        return groups.map { category, items in
            (
                category,
                items.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.0 < $1.0 }
    }

    private var revenueGroups: [(String, Double)] {
        let groups = Dictionary(
            grouping: filteredTransactions.filter {
                $0.type == .revenue
            },
            by: { $0.category }
        )

        return groups.map { category, items in
            (
                category,
                items.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.0 < $1.0 }
    }
    
    private var reportingDate: Date {
        let calendar = Calendar.current

        switch period {
        case "Month":
            guard let interval = calendar.dateInterval(
                of: .month,
                for: selectedDate
            ) else {
                return selectedDate
            }

            return interval.end.addingTimeInterval(-1)

        case "Year":
            guard let interval = calendar.dateInterval(
                of: .year,
                for: selectedDate
            ) else {
                return selectedDate
            }

            return interval.end.addingTimeInterval(-1)

        default:
            return Date()
        }
    }

    private var periodTitle: String {
        switch period {
        case "Month":
            return selectedDate.formatted(.dateTime.month(.wide).year())
        case "Year":
            return selectedDate.formatted(.dateTime.year())
        default:
            return "All Time"
        }
    }

    private func changePeriod(_ amount: Int) {
        let component: Calendar.Component =
            period == "Year" ? .year : .month

        if let nextDate = Calendar.current.date(
            byAdding: component,
            value: amount,
            to: selectedDate
        ) {
            selectedDate = nextDate
        }
    }

    private func money(_ amount: Double) -> String {
        amount.formatted(
            .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                .precision(.fractionLength(0))
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                header

                periodSelector

                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selectedReport.rawValue)
                                .font(.title.bold())

                            Text(periodTitle)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(ledgerCurrencyCode)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    reportContent
                }
                .padding(26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack {
                    Spacer()
                    
                    Button {
                        editedReportText = savedReportText ?? reportText
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            savedReportText ?? reportText,
                            forType: .string
                        )
                    } label: {
                        Label("Copy Report", systemImage: "doc.on.doc")
                    }

                    Button {
                        printReport()
                    } label: {
                        Label("Print / Save PDF", systemImage: "printer")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
        }
        .frame(minWidth: 900, minHeight: 650)
        .sheet(isPresented: $showingEditor) {
            VStack(alignment: .leading, spacing: 16) {

                HStack {
                    Text("Edit \(selectedReport.rawValue)")
                        .font(.title2.bold())

                    Spacer()

                    Button("Cancel") {
                        showingEditor = false
                    }

                    Button("Save Changes") {
                        savedReportText = editedReportText
                        showingEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextEditor(text: $editedReportText)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(8)
                    .background(.quaternary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

            }
            .padding(24)
            .frame(minWidth: 750, minHeight: 550)
        }
        .onChange(of: selectedReport) { _, _ in
            savedReportText = nil
        }
        .onChange(of: selectedDate) { _, _ in
            savedReportText = nil
        }
        .onChange(of: period) { _, _ in
            savedReportText = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Financial Reports")
                .font(.largeTitle.bold())

            Text("Generate reports from your Ledger records")
                .foregroundStyle(.secondary)
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 16) {

            Picker("", selection: $period) {
                Text("Month").tag("Month")
                Text("Year").tag("Year")
                Text("All Time").tag("All Time")
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 260)

            Spacer()

            if period != "All Time" {
                Button {
                    changePeriod(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Text(periodTitle)
                    .fontWeight(.semibold)
                    .frame(minWidth: 150)

                Button {
                    changePeriod(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
    }

    @ViewBuilder
    private var reportContent: some View {
        switch selectedReport {
        case .incomeStatement, .profitLoss:
            incomeStatementContent

        case .cashFlow:
            cashFlowContent

        case .balanceSheet:
            balanceSheetContent

        case .trialBalance:
            trialBalanceContent
        }
    }

    private var incomeStatementContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("INCOME")

            ForEach(revenueGroups, id: \.0) { group in
                reportRow(group.0, money(group.1))
            }

            reportRow("Total Revenue", money(revenue), bold: true)

            Divider()

            sectionHeading("EXPENSES")

            ForEach(expenseGroups, id: \.0) { group in
                reportRow(group.0, money(group.1))
            }

            reportRow("Total Expenses", money(expenses), bold: true)

            Divider()

            reportRow(
                "NET PROFIT / LOSS",
                money(netProfit),
                bold: true
            )

            Text("Calculated from recorded income and expense transactions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cashFlowContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("CASH FLOW ACTIVITY")

            reportRow("Recorded Revenue Entries", money(revenue))
            reportRow("Receivable Collections", money(debtCollections))
            reportRow("Total Cash Inflows", money(cashInflows), bold: true)
            reportRow("Recorded Expense Entries", money(expenses))
            reportRow("Payable Repayments", money(debtRepayments))
            reportRow("Unrecorded Recurring Expenses (estimate)", money(unrecordedRecurringExpenses))
            reportRow("Total Cash Outflows", money(cashOutflows), bold: true)

            Divider()

            reportRow(
                "Net Cash Flow Estimate",
                money(netCashFlow),
                bold: true
            )

            Text(
                "Treats recorded revenue and expense entries as cash inflows and outflows, and includes recorded debt collections and repayments plus recurring expenses not yet recorded, consistent with the Cash Flow view. Bank transfers, opening and closing cash balances, and unrecorded receipts or payments are not included, so this is an estimate rather than a formal cash flow statement."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var balanceSheetContent: some View {
        VStack(alignment: .leading, spacing: 14) {

            sectionHeading("ASSETS")

            reportRow(
                "Cash & Bank (\(ledgerCurrencyCode))",
                money(bankBalanceInReportingCurrency)
            )

            reportRow(
                "Accounts Receivable",
                money(receivablesTotal)
            )

            reportRow(
                "Inventory",
                money(inventoryTotal)
            )

            reportRow(
                "Other Current Assets",
                money(otherCurrentAssetsTotal)
            )

            Divider()

            reportRow(
                "Total Current Assets",
                money(
                    bankBalanceInReportingCurrency
                    + receivablesTotal
                    + inventoryTotal
                    + otherCurrentAssetsTotal
                ),
                bold: true
            )

            reportRow(
                "Non-Current / Fixed Assets",
                money(fixedAssetsTotal)
            )

            Divider()

            reportRow(
                "TOTAL RECORDED ASSETS",
                money(recordedAssetsTotal),
                bold: true
            )

            sectionHeading("LIABILITIES")

            reportRow(
                "Accounts Payable",
                money(payablesTotal)
            )

            reportRow(
                "Other Current Liabilities",
                money(otherCurrentLiabilitiesTotal)
            )

            Divider()

            reportRow(
                "Total Current Liabilities",
                money(currentLiabilitiesTotal),
                bold: true
            )

            reportRow(
                "Non-Current Liabilities",
                money(nonCurrentLiabilitiesTotal)
            )

            Divider()

            reportRow(
                "TOTAL RECORDED LIABILITIES",
                money(recordedLiabilitiesTotal),
                bold: true
            )

            sectionHeading("EQUITY / RECONCILIATION")

            reportRow(
                "Net Recorded Position (Assets − Liabilities)",
                money(netRecordedPosition),
                bold: true
            )

            Text(
                "This is a partial financial position, not a complete Balance Sheet. "
                + "Cash and bank balances use recorded opening balances and dated bank transactions. "
                + "Fixed assets are valued at the selected reporting date, including depreciation. "
                + "Foreign-currency balances are excluded. "
                + "Receivables, inventory and other assets and liabilities still require historical "
                + "balance calculations. Net Recorded Position is not verified equity."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var trialBalanceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("TRIAL BALANCE")

            Text(
                "A reliable Trial Balance requires a chart of accounts and double-entry postings."
            )
            .foregroundStyle(.secondary)

            Divider()

            reportRow(
                "Recorded Revenue (activity only)",
                money(revenue)
            )

            reportRow(
                "Recorded Expenses (activity only)",
                money(expenses)
            )

            Divider()

            Text(
                "These are transaction totals, not debit and credit ledger balances. Trial Balance generation will be enabled after we add account codes and balanced journal entries."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.vertical, 4)
    }

    private func reportRow(
        _ title: String,
        _ value: String,
        bold: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .fontWeight(bold ? .bold : .regular)

            Spacer()

            Text(value)
                .fontWeight(bold ? .bold : .regular)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var reportText: String {
        var lines = [
            selectedReport.rawValue,
            periodTitle,
            "Currency: \(ledgerCurrencyCode)",
            ""
        ]

        switch selectedReport {
        case .incomeStatement, .profitLoss:
            lines.append("INCOME")
            for group in revenueGroups {
                lines.append("\(group.0): \(money(group.1))")
            }
            lines.append("Total Revenue: \(money(revenue))")
            lines.append("")
            lines.append("EXPENSES")
            for group in expenseGroups {
                lines.append("\(group.0): \(money(group.1))")
            }
            lines.append("Total Expenses: \(money(expenses))")
            lines.append("Net Profit / Loss: \(money(netProfit))")

        case .cashFlow:
            lines.append("Recorded Revenue Entries: \(money(revenue))")
            lines.append("Receivable Collections: \(money(debtCollections))")
            lines.append("Total Cash Inflows: \(money(cashInflows))")
            lines.append("Recorded Expense Entries: \(money(expenses))")
            lines.append("Payable Repayments: \(money(debtRepayments))")
            lines.append("Unrecorded Recurring Expenses (estimate): \(money(unrecordedRecurringExpenses))")
            lines.append("Total Cash Outflows: \(money(cashOutflows))")
            lines.append("Net Cash Flow Estimate: \(money(netCashFlow))")
            lines.append("Note: Excludes bank transfers and opening/closing cash balances; not a formal cash flow statement.")

        case .balanceSheet:
            lines.append("ASSETS")
            lines.append("Cash & Bank (\(ledgerCurrencyCode)): \(money(bankBalanceInReportingCurrency))")
            lines.append("Accounts Receivable: \(money(receivablesTotal))")
            lines.append("Inventory: \(money(inventoryTotal))")
            lines.append("Other Current Assets: \(money(otherCurrentAssetsTotal))")

            let currentAssets =
                bankBalanceInReportingCurrency
                + receivablesTotal
                + inventoryTotal
                + otherCurrentAssetsTotal

            lines.append("Total Current Assets: \(money(currentAssets))")
            lines.append("Fixed Assets: \(money(fixedAssetsTotal))")
            lines.append("TOTAL ASSETS: \(money(recordedAssetsTotal))")
            lines.append("")

            lines.append("LIABILITIES")
            lines.append("Accounts Payable: \(money(payablesTotal))")
            lines.append("Other Current Liabilities: \(money(otherCurrentLiabilitiesTotal))")
            lines.append("Total Current Liabilities: \(money(currentLiabilitiesTotal))")
            lines.append("Non-Current Liabilities: \(money(nonCurrentLiabilitiesTotal))")
            lines.append("TOTAL LIABILITIES: \(money(recordedLiabilitiesTotal))")
            lines.append("")

            lines.append("EQUITY / RECONCILIATION")
            lines.append("Net Recorded Position: \(money(netRecordedPosition))")
            lines.append("")
            lines.append("Note: Partial financial position. Historical balances for other asset and liability categories are not yet implemented.")

        case .trialBalance:
            lines.append("Recorded Revenue: \(money(revenue))")
            lines.append("Recorded Expenses: \(money(expenses))")
            lines.append("Note: Not a balanced Trial Balance.")
        }

        return lines.joined(separator: "\n")
    }

    private func printReport() {
        let textView = NSTextView(
            frame: NSRect(x: 0, y: 0, width: 700, height: 900)
        )

        textView.string = savedReportText ?? reportText
        textView.font = NSFont.monospacedSystemFont(
            ofSize: 12,
            weight: .regular
        )
        textView.isEditable = false

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.jobDisposition = .spool

        let operation = NSPrintOperation(
            view: textView,
            printInfo: printInfo
        )

        operation.showsPrintPanel = true
        operation.run()
    }
}

