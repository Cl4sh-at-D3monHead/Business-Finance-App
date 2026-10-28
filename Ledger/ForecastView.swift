import SwiftUI
import SwiftData
import Charts

struct ForecastView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    // MARK: - Data

    @Query(sort: \FinanceTransaction.date, order: .reverse)
    private var transactions: [FinanceTransaction]

    @Query private var debtPayments: [DebtPayment]

    @Query(sort: \StockItem.name)
    private var stockItems: [StockItem]

    // MARK: - State

    @State private var selectedYear: Int =
        Calendar.current.component(.year, from: Date())

    // MARK: - Years

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var forecastYears: [Int] {
        Array(currentYear...(currentYear + 5))
    }

    // MARK: - Historical Months

    private var historicalMonths: [MonthlyForecastData] {

        let calendar = Calendar.current
        let today = Date()

        return (0..<3).compactMap { offset in

            guard let monthDate = calendar.date(
                byAdding: .month,
                value: -(2 - offset),
                to: today
            ) else {
                return nil
            }

            guard let interval = calendar.dateInterval(
                of: .month,
                for: monthDate
            ) else {
                return nil
            }

            let monthTransactions = transactions.filter {
                interval.contains($0.date)
            }

            let revenue = monthTransactions
                .filter { $0.type == .revenue }
                .reduce(0) { $0 + $1.amount }

            let expenses = monthTransactions
                .filter { $0.type == .expense }
                .reduce(0) { $0 + $1.amount }

            let monthDebtPayments = debtPayments.filter {
                interval.contains($0.paymentDate)
            }

            let collections = monthDebtPayments
                .filter {
                    $0.debt?.type == .receivable
                }
                .reduce(0) {
                    $0 + $1.amount
                }

            let repayments = monthDebtPayments
                .filter {
                    $0.debt?.type == .payable
                }
                .reduce(0) {
                    $0 + $1.amount
                }

            let cashFlow =
                (revenue + collections)
                - (expenses + repayments)

            return MonthlyForecastData(
                date: monthDate,
                revenue: revenue,
                expenses: expenses,
                profit: revenue - expenses,
                cashFlow: cashFlow,
                isForecast: false
            )
        }
    }

    // MARK: - Historical Averages

    private var monthsWithActivity: [MonthlyForecastData] {
        historicalMonths.filter {
            $0.revenue != 0 ||
            $0.expenses != 0 ||
            $0.cashFlow != 0
        }
    }

    private var averageRevenue: Double {

        guard !monthsWithActivity.isEmpty else {
            return 0
        }

        return monthsWithActivity
            .reduce(0) {
                $0 + $1.revenue
            }
            / Double(monthsWithActivity.count)
    }

    private var averageExpenses: Double {

        guard !monthsWithActivity.isEmpty else {
            return 0
        }

        return monthsWithActivity
            .reduce(0) {
                $0 + $1.expenses
            }
            / Double(monthsWithActivity.count)
    }

    private var averageCashFlow: Double {

        guard !monthsWithActivity.isEmpty else {
            return 0
        }

        return monthsWithActivity
            .reduce(0) {
                $0 + $1.cashFlow
            }
            / Double(monthsWithActivity.count)
    }

    // MARK: - Trend

    private var revenueGrowthRate: Double {

        let active = monthsWithActivity

        guard active.count >= 2 else {
            return 0
        }

        guard
            let previous = active.dropLast().last?.revenue,
            let latest = active.last?.revenue,
            previous > 0
        else {
            return 0
        }

        return (latest - previous) / previous
    }

    private var expenseGrowthRate: Double {

        let active = monthsWithActivity

        guard active.count >= 2 else {
            return 0
        }

        guard
            let previous = active.dropLast().last?.expenses,
            let latest = active.last?.expenses,
            previous > 0
        else {
            return 0
        }

        return (latest - previous) / previous
    }

    // MARK: - Forecast Months

    private var forecastMonths: [MonthlyForecastData] {

        let calendar = Calendar.current

        guard let firstMonth = calendar.date(
            from: DateComponents(
                year: selectedYear,
                month: 1,
                day: 1
            )
        ) else {
            return []
        }

        return (0..<12).compactMap { index in

            guard let date = calendar.date(
                byAdding: .month,
                value: index,
                to: firstMonth
            ) else {
                return nil
            }

            let monthNumber = Double(index + 1)

            let revenue =
                averageRevenue *
                pow(
                    1 + cappedRevenueGrowth,
                    monthNumber
                )

            let expenses =
                averageExpenses *
                pow(
                    1 + cappedExpenseGrowth,
                    monthNumber
                )

            let profit =
                revenue - expenses

            let cashFlow =
                averageCashFlow +
                (revenue - averageRevenue) -
                (expenses - averageExpenses)

            return MonthlyForecastData(
                date: date,
                revenue: max(revenue, 0),
                expenses: max(expenses, 0),
                profit: profit,
                cashFlow: cashFlow,
                isForecast: true
            )
        }
    }

    // Prevent extreme forecasts from one unusual month.

    private var cappedRevenueGrowth: Double {
        min(max(revenueGrowthRate, -0.25), 0.25)
    }

    private var cappedExpenseGrowth: Double {
        min(max(expenseGrowthRate, -0.25), 0.25)
    }

    // MARK: - Annual Forecast

    private var forecastSales: Double {
        forecastMonths.reduce(0) {
            $0 + $1.revenue
        }
    }

    private var forecastExpenses: Double {
        forecastMonths.reduce(0) {
            $0 + $1.expenses
        }
    }

    private var forecastProfit: Double {
        forecastMonths.reduce(0) {
            $0 + $1.profit
        }
    }

    private var forecastCashFlow: Double {
        forecastMonths.reduce(0) {
            $0 + $1.cashFlow
        }
    }

    private var forecastMargin: Double {

        guard forecastSales > 0 else {
            return 0
        }

        return (
            forecastProfit /
            forecastSales
        ) * 100
    }

    // MARK: - Stock

    private var healthyStockCount: Int {
        stockItems.filter {
            !$0.isLowStock &&
            !$0.isOutOfStock &&
            !$0.isInBufferStock
        }.count
    }

    private var lowStockCount: Int {
        stockItems.filter {
            $0.isLowStock
        }.count
    }

    private var bufferStockCount: Int {
        stockItems.filter {
            $0.isInBufferStock
        }.count
    }

    private var outOfStockCount: Int {
        stockItems.filter {
            $0.isOutOfStock
        }.count
    }

    // MARK: - Body

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 20
            ) {

                // MARK: Header

                VStack(spacing: 6) {

                    Text("Forecast")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(
                        "Financial outlook and business planning"
                    )
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // MARK: Year Selector

                HStack {

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text("Forecast Year")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(selectedYear)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    Picker(
                        "Forecast Year",
                        selection: $selectedYear
                    ) {

                        ForEach(
                            forecastYears,
                            id: \.self
                        ) { year in

                            Text(String(year))
                                .tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(20)
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )

                // MARK: Main Forecast Cards

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 15
                ) {

                    forecastCard(
                        title: "Forecast Sales",
                        amount: forecastSales,
                        subtitle: growthText(
                            cappedRevenueGrowth
                        ),
                        icon:
                            "chart.line.uptrend.xyaxis"
                    )

                    forecastCard(
                        title: "Forecast Expenses",
                        amount: forecastExpenses,
                        subtitle: growthText(
                            cappedExpenseGrowth
                        ),
                        icon: "creditcard"
                    )

                    forecastCard(
                        title: "Forecast Cash Flow",
                        amount: forecastCashFlow,
                        subtitle:
                            forecastCashFlow >= 0
                            ? "Positive"
                            : "Negative",
                        icon:
                            "arrow.left.arrow.right"
                    )

                    forecastCard(
                        title: "Forecast Profit",
                        amount: forecastProfit,
                        subtitle:
                            "Margin \(forecastMargin.formatted(.number.precision(.fractionLength(1))))%",
                        icon: "chart.bar.fill"
                    )
                }

                // MARK: Business Outlook

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    Label(
                        "Business Outlook",
                        systemImage:
                            "chart.xyaxis.line"
                    )
                    .font(.title2)
                    .fontWeight(.bold)

                    Divider()

                    if forecastMonths.allSatisfy({
                        $0.revenue == 0 &&
                        $0.expenses == 0
                    }) {

                        ContentUnavailableView(
                            "Not Enough Forecast Data",
                            systemImage:
                                "chart.line.uptrend.xyaxis",
                            description: Text(
                                "Record more sales and expenses to build a meaningful forecast."
                            )
                        )
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 260
                        )

                    } else {

                        Chart {

                            ForEach(
                                forecastMonths
                            ) { item in

                                LineMark(
                                    x: .value(
                                        "Month",
                                        item.date
                                    ),
                                    y: .value(
                                        "Amount",
                                        item.revenue
                                    )
                                )
                                .foregroundStyle(
                                    by: .value(
                                        "Type",
                                        "Sales"
                                    )
                                )

                                LineMark(
                                    x: .value(
                                        "Month",
                                        item.date
                                    ),
                                    y: .value(
                                        "Amount",
                                        item.expenses
                                    )
                                )
                                .foregroundStyle(
                                    by: .value(
                                        "Type",
                                        "Expenses"
                                    )
                                )

                                LineMark(
                                    x: .value(
                                        "Month",
                                        item.date
                                    ),
                                    y: .value(
                                        "Amount",
                                        item.profit
                                    )
                                )
                                .foregroundStyle(
                                    by: .value(
                                        "Type",
                                        "Profit"
                                    )
                                )

                                LineMark(
                                    x: .value(
                                        "Month",
                                        item.date
                                    ),
                                    y: .value(
                                        "Amount",
                                        item.cashFlow
                                    )
                                )
                                .foregroundStyle(
                                    by: .value(
                                        "Type",
                                        "Cash Flow"
                                    )
                                )
                            }
                        }
                        .chartXAxis {

                            AxisMarks(
                                values:
                                    .stride(
                                        by: .month
                                    )
                            ) { value in

                                AxisGridLine()
                                AxisTick()

                                AxisValueLabel {

                                    if let date =
                                        value.as(
                                            Date.self
                                        ) {

                                        Text(
                                            date,
                                            format:
                                                .dateTime
                                                .month(
                                                    .abbreviated
                                                )
                                        )
                                    }
                                }
                            }
                        }
                        .chartYAxis {

                            AxisMarks(
                                position: .trailing
                            ) { value in

                                AxisGridLine()

                                AxisValueLabel {

                                    if let amount =
                                        value.as(
                                            Double.self
                                        ) {

                                        Text(
                                            shortCurrency(
                                                amount
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .frame(height: 300)
                    }
                }
                .padding(20)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )

                // MARK: Cash + Stock Outlook

                HStack(
                    alignment: .top,
                    spacing: 15
                ) {

                    outlookCard(
                        title: "Cash Outlook",
                        icon:
                            "banknote.fill"
                    ) {

                        forecastRow(
                            "Expected Cash In",
                            forecastSales
                        )

                        forecastRow(
                            "Expected Cash Out",
                            forecastExpenses
                        )

                        Divider()

                        forecastRow(
                            "Net Cash Flow",
                            forecastCashFlow,
                            bold: true
                        )

                        Divider()

                        Label(
                            forecastCashFlow >= 0
                            ? "Positive cash position"
                            : "Negative cash position",
                            systemImage:
                                forecastCashFlow >= 0
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .fontWeight(.semibold)
                    }

                    outlookCard(
                        title: "Stock Outlook",
                        icon:
                            "shippingbox.fill"
                    ) {

                        textRow(
                            "Stock Items",
                            "\(stockItems.count)"
                        )

                        textRow(
                            "Healthy",
                            "\(healthyStockCount)"
                        )

                        textRow(
                            "Low Stock",
                            "\(lowStockCount)"
                        )

                        textRow(
                            "Buffer Stock",
                            "\(bufferStockCount)"
                        )

                        textRow(
                            "Out of Stock",
                            "\(outOfStockCount)"
                        )

                        Divider()

                        if lowStockCount +
                            bufferStockCount +
                            outOfStockCount == 0 {

                            Label(
                                "Stock levels are healthy",
                                systemImage:
                                    "checkmark.circle.fill"
                            )
                            .fontWeight(.semibold)

                        } else {

                            Label(
                                "\(lowStockCount + bufferStockCount + outOfStockCount) items need attention",
                                systemImage:
                                    "exclamationmark.triangle.fill"
                            )
                            .fontWeight(.semibold)
                        }
                    }
                }

                // MARK: Management Insight

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Label(
                        "Management Insight",
                        systemImage:
                            "lightbulb.fill"
                    )
                    .font(.title2)
                    .fontWeight(.bold)

                    Divider()

                    Text(managementInsight)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack {

                        Text("Overall Outlook")
                            .fontWeight(.semibold)

                        Spacer()

                        Text(overallOutlook)
                            .fontWeight(.bold)
                    }
                }
                .padding(20)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )

                // MARK: Monthly Breakdown

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    Text(
                        "\(selectedYear) Monthly Forecast"
                    )
                    .font(.title2)
                    .fontWeight(.bold)

                    Divider()

                    HStack {

                        Text("Month")
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                        Text("Sales")
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                        Text("Expenses")
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                        Text("Cash Flow")
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                        Text("Profit")
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()

                    ForEach(
                        forecastMonths
                    ) { month in

                        HStack {

                            Text(
                                month.date.formatted(
                                    .dateTime.month(
                                        .wide
                                    )
                                )
                            )
                            .fontWeight(.semibold)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                            Text(
                                currency(
                                    month.revenue
                                )
                            )
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                            Text(
                                currency(
                                    month.expenses
                                )
                            )
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                            Text(
                                currency(
                                    month.cashFlow
                                )
                            )
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                            Text(
                                currency(
                                    month.profit
                                )
                            )
                            .fontWeight(.semibold)
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )
                        }

                        Divider()
                    }

                    HStack {

                        Text(
                            "\(selectedYear) Total"
                        )
                        .fontWeight(.bold)

                        Spacer()

                        Text(
                            currency(
                                forecastSales
                            )
                        )
                        .frame(
                            width: 150,
                            alignment: .trailing
                        )
                        .fontWeight(.bold)

                        Text(
                            currency(
                                forecastExpenses
                            )
                        )
                        .frame(
                            width: 150,
                            alignment: .trailing
                        )
                        .fontWeight(.bold)

                        Text(
                            currency(
                                forecastCashFlow
                            )
                        )
                        .frame(
                            width: 150,
                            alignment: .trailing
                        )
                        .fontWeight(.bold)

                        Text(
                            currency(
                                forecastProfit
                            )
                        )
                        .frame(
                            width: 150,
                            alignment: .trailing
                        )
                        .fontWeight(.bold)
                    }
                }
                .padding(20)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )

                // MARK: Forecast Assumptions

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Label(
                        "Forecast Assumptions",
                        systemImage:
                            "slider.horizontal.3"
                    )
                    .font(.title2)
                    .fontWeight(.bold)

                    Divider()

                    assumptionRow(
                        "Revenue Trend",
                        percentage(
                            cappedRevenueGrowth
                        )
                    )

                    assumptionRow(
                        "Expense Trend",
                        percentage(
                            cappedExpenseGrowth
                        )
                    )

                    assumptionRow(
                        "Historical Period",
                        "Last 3 Months"
                    )

                    assumptionRow(
                        "Stock Constraints",
                        "Included"
                    )

                    assumptionRow(
                        "Cash Movements",
                        "Included"
                    )

                    Text(
                        "Forecasts are estimates based on recorded business activity and should be reviewed alongside management expectations."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(20)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Forecast")
    }

    // MARK: - Cards

    private func forecastCard(
        title: String,
        amount: Double,
        subtitle: String,
        icon: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.headline)

                Spacer()
            }

            Divider()

            Text(currency(amount))
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            minHeight: 150,
            alignment: .leading
        )
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }

    private func outlookCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                title,
                systemImage: icon
            )
            .font(.title2)
            .fontWeight(.bold)

            Divider()

            content()
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            alignment: .topLeading
        )
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }

    // MARK: - Rows

    private func forecastRow(
        _ title: String,
        _ amount: Double,
        bold: Bool = false
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(currency(amount))
                .fontWeight(
                    bold
                    ? .bold
                    : .semibold
                )
        }
    }

    private func textRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }

    private func assumptionRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Insight

    private var managementInsight: String {

        guard forecastSales > 0 ||
                forecastExpenses > 0
        else {

            return """
            There is not yet enough financial activity to produce a meaningful forecast. Continue recording sales and expenses so Ledger can build a stronger forecast.
            """
        }

        var messages: [String] = []

        if cappedRevenueGrowth > 0 {

            messages.append(
                "Sales are currently trending upward."
            )

        } else if cappedRevenueGrowth < 0 {

            messages.append(
                "Sales are currently trending downward."
            )

        } else {

            messages.append(
                "Sales are currently relatively stable."
            )
        }

        if cappedExpenseGrowth >
            cappedRevenueGrowth {

            messages.append(
                "Expenses are growing faster than sales, which could place pressure on future margins."
            )

        } else {

            messages.append(
                "Expense growth is currently being contained relative to sales."
            )
        }

        if forecastCashFlow < 0 {

            messages.append(
                "The forecast indicates a negative cash position and cash commitments should be reviewed."
            )

        } else {

            messages.append(
                "The forecast indicates a positive cash position."
            )
        }

        let stockRisks =
            lowStockCount +
            bufferStockCount +
            outOfStockCount

        if stockRisks > 0 {

            messages.append(
                "\(stockRisks) stock items currently require attention and could affect future sales if not replenished."
            )
        }

        return messages.joined(
            separator: " "
        )
    }

    private var overallOutlook: String {

        if forecastCashFlow < 0 ||
            forecastProfit < 0 {

            return "Needs Attention"
        }

        if outOfStockCount > 0 ||
            bufferStockCount > 0 {

            return "Watch"
        }

        return "Healthy"
    }

    // MARK: - Formatting

    private func currency(
        _ amount: Double
    ) -> String {

        amount.formatted(
            .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                .precision(
                    .fractionLength(0)
                )
        )
    }

    private func shortCurrency(_ amount: Double) -> String {

        if abs(amount) >= 1_000_000_000 {

            let value = String(
                format: "%.1f",
                amount / 1_000_000_000
            )

            return "\(ledgerCurrencyCode) \(value)B"

        } else if abs(amount) >= 1_000_000 {

            let value = String(
                format: "%.1f",
                amount / 1_000_000
            )

            return "\(ledgerCurrencyCode) \(value)M"

        } else if abs(amount) >= 1_000 {

            let value = String(
                format: "%.0f",
                amount / 1_000
            )

            return "\(ledgerCurrencyCode) \(value)K"
        }

        let value = String(
            format: "%.0f",
            amount
        )

        return "\(ledgerCurrencyCode) \(value)"
    }

    private func percentage(
        _ value: Double
    ) -> String {

        let percentageValue =
            value * 100

        let prefix =
            percentageValue > 0
            ? "+"
            : ""

        return "\(prefix)\(percentageValue.formatted(.number.precision(.fractionLength(1))))%"
    }

    private func growthText(
        _ value: Double
    ) -> String {

        if value > 0 {

            return "\(percentage(value)) trend"

        } else if value < 0 {

            return "\(percentage(value)) trend"
        }

        return "Stable trend"
    }
}


// MARK: - Monthly Forecast Model

private struct MonthlyForecastData:
    Identifiable {

    let id = UUID()

    let date: Date
    let revenue: Double
    let expenses: Double
    let profit: Double
    let cashFlow: Double
    let isForecast: Bool
}
