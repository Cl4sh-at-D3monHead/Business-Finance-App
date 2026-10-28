import SwiftUI
import SwiftData
import Charts

// MARK: - PERIOD

enum CashFlowPeriod: String, CaseIterable {
    case month = "Month"
    case year = "Year"
    case allTime = "All Time"
}


// MARK: - TREND DATA

struct CashFlowTrendData: Identifiable {
    let id = UUID()
    let date: Date
    let cashInflows: Double
    let cashOutflows: Double
}


// MARK: - CASH FLOW VIEW

struct CashFlowView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Query private var transactions: [FinanceTransaction]
    @Query private var debtPayments: [DebtPayment]
    @Query private var recurringExpenses: [RecurringExpense]
    
    @State private var selectedPeriod: CashFlowPeriod = .month
    @State private var selectedDate = Date()
    @State private var selectedChartDate: Date?
    @State private var hoveredCashInflowItem: (name: String, amount: Double)? = nil
    @State private var hoveredCashOutflowItem: (name: String, amount: Double)? = nil
    
    
    // MARK: - FILTERING
    
    private var filteredTransactions: [FinanceTransaction] {
        
        let calendar = Calendar.current
        
        switch selectedPeriod {
            
        case .month:
            return transactions.filter {
                calendar.isDate(
                    $0.date,
                    equalTo: selectedDate,
                    toGranularity: .month
                ) &&
                calendar.isDate(
                    $0.date,
                    equalTo: selectedDate,
                    toGranularity: .year
                )
            }
            
        case .year:
            return transactions.filter {
                calendar.isDate(
                    $0.date,
                    equalTo: selectedDate,
                    toGranularity: .year
                )
            }
            
        case .allTime:
            return transactions
        }
    }
    
    
    private var filteredDebtPayments: [DebtPayment] {
        
        let calendar = Calendar.current
        
        switch selectedPeriod {
            
        case .month:
            return debtPayments.filter {
                calendar.isDate(
                    $0.paymentDate,
                    equalTo: selectedDate,
                    toGranularity: .month
                ) &&
                calendar.isDate(
                    $0.paymentDate,
                    equalTo: selectedDate,
                    toGranularity: .year
                )
            }
            
        case .year:
            return debtPayments.filter {
                calendar.isDate(
                    $0.paymentDate,
                    equalTo: selectedDate,
                    toGranularity: .year
                )
            }
            
        case .allTime:
            return debtPayments
        }
    }
    
    
    // MARK: - RECURRING EXPENSE HELPERS
    
    private func recurringExpenseIsActive(
        _ expense: RecurringExpense,
        on date: Date
    ) -> Bool {

        guard expense.isActive else {
            return false
        }
        
        let calendar = Calendar.current
        
        let expenseStart = calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: expense.startDate
            )
        ) ?? expense.startDate
        
        let targetMonth = calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: date
            )
        ) ?? date
        
        guard targetMonth >= expenseStart else {
            return false
        }
        
        if let endDate = expense.endDate {
            
            let expenseEnd = calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: endDate
                )
            ) ?? endDate
            
            guard targetMonth <= expenseEnd else {
                return false
            }
        }
        
        return true
    }
    
    
    private func recurringExpenseAlreadyRecorded(
        _ expense: RecurringExpense,
        in date: Date
    ) -> Bool {
        
        transactions.contains { transaction in
            
            transaction.type == .expense &&
            transaction.title == expense.title &&
            transaction.category == expense.category &&
            Calendar.current.isDate(
                transaction.date,
                equalTo: date,
                toGranularity: .month
            ) &&
            Calendar.current.isDate(
                transaction.date,
                equalTo: date,
                toGranularity: .year
            )
        }
    }
    
    
    private func scheduledRecurringExpenses(
        for date: Date
    ) -> Double {
        
        recurringExpenses.reduce(0) { total, expense in
            
            guard recurringExpenseIsActive(
                expense,
                on: date
            ) else {
                return total
            }
            
            guard !recurringExpenseAlreadyRecorded(
                expense,
                in: date
            ) else {
                return total
            }
            
            return total + expense.amount
        }
    }
    
    
    private var filteredRecurringExpenses: Double {
        
        let calendar = Calendar.current
        
        switch selectedPeriod {
            
        case .month:
            return scheduledRecurringExpenses(
                for: selectedDate
            )
            
        case .year:
            
            guard let yearInterval = calendar.dateInterval(
                of: .year,
                for: selectedDate
            ) else {
                return 0
            }
            
            var total: Double = 0
            var month = yearInterval.start
            
            while month < yearInterval.end {
                
                total += scheduledRecurringExpenses(
                    for: month
                )
                
                guard let nextMonth = calendar.date(
                    byAdding: .month,
                    value: 1,
                    to: month
                ) else {
                    break
                }
                
                month = nextMonth
            }
            
            return total
            
        case .allTime:
            
            guard let earliestDate = allRecordedDates.min(),
                  let latestDate = allRecordedDates.max()
                    else {
                return 0
            }
            
            var total: Double = 0
            
            var month = calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: earliestDate
                )
            ) ?? earliestDate
            
            let finalMonth = calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: latestDate
                )
            ) ?? latestDate
            
            while month <= finalMonth {
                
                total += scheduledRecurringExpenses(
                    for: month
                )
                
                guard let nextMonth = calendar.date(
                    byAdding: .month,
                    value: 1,
                    to: month
                ) else {
                    break
                }
                
                month = nextMonth
            }
            
            return total
        }
    }
    
    
    private var allRecordedDates: [Date] {
        
        let transactionDates = transactions.map {
            $0.date
        }
        
        let debtDates = debtPayments.map {
            $0.paymentDate
        }
        
        let recurringDates = recurringExpenses.map {
            $0.startDate
        }
        
        return transactionDates
        + debtDates
        + recurringDates
    }
    
    
    // MARK: - CASH INFLOWS
    
    private var transactionCashInflows: Double {
        
        filteredTransactions
            .filter {
                $0.type == .revenue
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }
    
    
    private var debtCollections: Double {
        
        filteredDebtPayments
            .filter {
                $0.debt?.type == .receivable
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }
    
    
    private var cashInflows: Double {
        transactionCashInflows + debtCollections
    }
    
    
    // MARK: - CASH OUTFLOWS
    
    private var transactionCashOutflows: Double {
        
        filteredTransactions
            .filter {
                $0.type == .expense
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }
    
    
    private var debtRepayments: Double {
        
        filteredDebtPayments
            .filter {
                $0.debt?.type == .payable
            }
            .reduce(0) {
                $0 + $1.amount
            }
    }
    
    
    private var cashOutflows: Double {
        
        transactionCashOutflows
        + debtRepayments
        + filteredRecurringExpenses
    }
    
    
    // MARK: - KEY CALCULATIONS
    
    private var netCashFlow: Double {
        cashInflows - cashOutflows
    }
    
    
    private var flowRatio: Double {
        
        guard cashOutflows > 0 else {
            return 0
        }
        
        return cashInflows / cashOutflows
    }
    
    
    private var cashFlowStatus: String {
        
        if netCashFlow > 0 {
            return "Positive Cash Flow"
        }
        
        if netCashFlow < 0 {
            return "Negative Cash Flow"
        }
        
        return "Break-even Cash Flow"
    }
    
    
    // MARK: - INFLOW BREAKDOWN
    
    private var cashInflowCategoryTotals: [String: Double] {
        
        let revenueTransactions = filteredTransactions.filter {
            $0.type == .revenue
        }
        
        var totals = Dictionary(
            grouping: revenueTransactions,
            by: {
                $0.category
            }
        )
            .mapValues { items in
                items.reduce(0) {
                    $0 + $1.amount
                }
            }
        
        if debtCollections > 0 {
            totals["Debt Collections"] = debtCollections
        }
        
        return totals
    }
    
    
    private var cashInflowBreakdownData:
    [(name: String, amount: Double)] {
        
        cashInflowCategoryTotals
            .map {
                (
                    name: $0.key,
                    amount: $0.value
                )
            }
            .filter {
                $0.amount > 0
            }
            .sorted {
                $0.amount > $1.amount
            }
    }
    
    
    // MARK: - OUTFLOW BREAKDOWN
    
    private var cashOutflowCategoryTotals: [String: Double] {
        
        let expenseTransactions = filteredTransactions.filter {
            $0.type == .expense
        }
        
        var totals = Dictionary(
            grouping: expenseTransactions,
            by: {
                $0.category
            }
        )
            .mapValues { items in
                items.reduce(0) {
                    $0 + $1.amount
                }
            }
        
        
        // Add scheduled recurring expenses which
        // have not already been recorded.
        
        let calendar = Calendar.current
        
        func addRecurringExpenses(for date: Date) {
            
            for expense in recurringExpenses {
                
                guard recurringExpenseIsActive(
                    expense,
                    on: date
                ) else {
                    continue
                }
                
                guard !recurringExpenseAlreadyRecorded(
                    expense,
                    in: date
                ) else {
                    continue
                }
                
                totals[
                    expense.category,
                    default: 0
                ] += expense.amount
            }
        }
        
        
        switch selectedPeriod {
            
        case .month:
            
            addRecurringExpenses(
                for: selectedDate
            )
            
        case .year:
            
            if let interval = calendar.dateInterval(
                of: .year,
                for: selectedDate
            ) {
                
                var month = interval.start
                
                while month < interval.end {
                    
                    addRecurringExpenses(
                        for: month
                    )
                    
                    guard let nextMonth = calendar.date(
                        byAdding: .month,
                        value: 1,
                        to: month
                    ) else {
                        break
                    }
                    
                    month = nextMonth
                }
            }
            
        case .allTime:
            
            if let firstDate = allRecordedDates.min(),
               let lastDate = allRecordedDates.max() {
                
                var month = calendar.date(
                    from: calendar.dateComponents(
                        [.year, .month],
                        from: firstDate
                    )
                ) ?? firstDate
                
                let finalMonth = calendar.date(
                    from: calendar.dateComponents(
                        [.year, .month],
                        from: lastDate
                    )
                ) ?? lastDate
                
                while month <= finalMonth {
                    
                    addRecurringExpenses(
                        for: month
                    )
                    
                    guard let nextMonth = calendar.date(
                        byAdding: .month,
                        value: 1,
                        to: month
                    ) else {
                        break
                    }
                    
                    month = nextMonth
                }
            }
        }
        
        
        if debtRepayments > 0 {
            
            totals[
                "Debt Repayments",
                default: 0
            ] += debtRepayments
        }
        
        return totals
    }
    
    
    private var cashOutflowBreakdownData:
    [(name: String, amount: Double)] {
        
        cashOutflowCategoryTotals
            .map {
                (
                    name: $0.key,
                    amount: $0.value
                )
            }
            .filter {
                $0.amount > 0
            }
            .sorted {
                $0.amount > $1.amount
            }
    }
    
    
    // MARK: - PERIOD TITLE
    
    private var selectedPeriodTitle: String {
        
        switch selectedPeriod {
            
        case .month:
            return selectedDate.formatted(
                .dateTime
                    .month(.wide)
                    .year()
            )
            
        case .year:
            return selectedDate.formatted(
                .dateTime.year()
            )
            
        case .allTime:
            return "All Time"
        }
    }
    
    
    // MARK: - PERIOD NAVIGATION
    
    private func changePeriod(
        by value: Int
    ) {
        
        let calendar = Calendar.current
        
        switch selectedPeriod {
            
        case .month:
            
            if let newDate = calendar.date(
                byAdding: .month,
                value: value,
                to: selectedDate
            ) {
                selectedDate = newDate
            }
            
        case .year:
            
            if let newDate = calendar.date(
                byAdding: .year,
                value: value,
                to: selectedDate
            ) {
                selectedDate = newDate
            }
            
        case .allTime:
            break
        }
    }
    
    
    // MARK: - TREND DATA
    
    private var cashFlowTrendData:
    [CashFlowTrendData] {
        
        let calendar = Calendar.current
        
        // MONTH:
        // Show every calendar day.
        
        if selectedPeriod == .month {
            
            guard let monthInterval =
                    calendar.dateInterval(
                        of: .month,
                        for: selectedDate
                    )
                    else {
                return []
            }
            
            var results:
            [CashFlowTrendData] = []
            
            var currentDate =
            monthInterval.start
            
            
            while currentDate <
                    monthInterval.end {
                
                let dayStart =
                calendar.startOfDay(
                    for: currentDate
                )
                
                guard let nextDay =
                        calendar.date(
                            byAdding: .day,
                            value: 1,
                            to: dayStart
                        )
                        else {
                    break
                }
                
                
                let dayRevenue =
                transactions
                    .filter {
                        $0.type == .revenue &&
                        $0.date >= dayStart &&
                        $0.date < nextDay
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                let dayExpenses =
                transactions
                    .filter {
                        $0.type == .expense &&
                        $0.date >= dayStart &&
                        $0.date < nextDay
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                let dayCollections =
                debtPayments
                    .filter {
                        $0.debt?.type == .receivable &&
                        $0.paymentDate >= dayStart &&
                        $0.paymentDate < nextDay
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                let dayRepayments =
                debtPayments
                    .filter {
                        $0.debt?.type == .payable &&
                        $0.paymentDate >= dayStart &&
                        $0.paymentDate < nextDay
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                var recurringForDay:
                Double = 0
                
                let dayComponents =
                calendar.dateComponents(
                    [.day],
                    from: dayStart
                )
                
                // Put monthly scheduled recurring
                // expenses on the first day of the
                // month for trend purposes.
                
                if dayComponents.day == 1 {
                    
                    recurringForDay =
                    scheduledRecurringExpenses(
                        for: dayStart
                    )
                }
                
                
                results.append(
                    CashFlowTrendData(
                        date: dayStart,
                        cashInflows:
                            dayRevenue
                        + dayCollections,
                        cashOutflows:
                            dayExpenses
                        + dayRepayments
                        + recurringForDay
                    )
                )
                
                currentDate = nextDay
            }
            
            return results
        }
        
        
        // YEAR:
        // Show each month in selected year.
        
        if selectedPeriod == .year {
            
            guard let yearInterval =
                    calendar.dateInterval(
                        of: .year,
                        for: selectedDate
                    )
                    else {
                return []
            }
            
            var results:
            [CashFlowTrendData] = []
            
            var month =
            yearInterval.start
            
            
            while month <
                    yearInterval.end {
                
                guard let nextMonth =
                        calendar.date(
                            byAdding: .month,
                            value: 1,
                            to: month
                        )
                        else {
                    break
                }
                
                
                let revenue =
                transactions
                    .filter {
                        $0.type == .revenue &&
                        $0.date >= month &&
                        $0.date < nextMonth
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                let expenses =
                transactions
                    .filter {
                        $0.type == .expense &&
                        $0.date >= month &&
                        $0.date < nextMonth
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                let collections =
                debtPayments
                    .filter {
                        $0.debt?.type == .receivable &&
                        $0.paymentDate >= month &&
                        $0.paymentDate < nextMonth
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                let repayments =
                debtPayments
                    .filter {
                        $0.debt?.type == .payable &&
                        $0.paymentDate >= month &&
                        $0.paymentDate < nextMonth
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                
                results.append(
                    CashFlowTrendData(
                        date: month,
                        cashInflows:
                            revenue
                        + collections,
                        cashOutflows:
                            expenses
                        + repayments
                        + scheduledRecurringExpenses(
                            for: month
                        )
                    )
                )
                
                month = nextMonth
            }
            
            return results
        }
        
        
        // ALL TIME:
        // Group everything by month.
        
        guard let firstDate =
                allRecordedDates.min(),
              let lastDate =
                allRecordedDates.max()
                else {
            return []
        }
        
        
        var results:
        [CashFlowTrendData] = []
        
        
        var month =
        calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: firstDate
            )
        ) ?? firstDate
        
        
        let finalMonth =
        calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: lastDate
            )
        ) ?? lastDate
        
        
        while month <= finalMonth {
            
            guard let nextMonth =
                    calendar.date(
                        byAdding: .month,
                        value: 1,
                        to: month
                    )
                    else {
                break
            }
            
            
            let revenue =
            transactions
                .filter {
                    $0.type == .revenue &&
                    $0.date >= month &&
                    $0.date < nextMonth
                }
                .reduce(0) {
                    $0 + $1.amount
                }
            
            
            let expenses =
            transactions
                .filter {
                    $0.type == .expense &&
                    $0.date >= month &&
                    $0.date < nextMonth
                }
                .reduce(0) {
                    $0 + $1.amount
                }
            
            
            let collections =
            debtPayments
                .filter {
                    $0.debt?.type == .receivable &&
                    $0.paymentDate >= month &&
                    $0.paymentDate < nextMonth
                }
                .reduce(0) {
                    $0 + $1.amount
                }
            
            
            let repayments =
            debtPayments
                .filter {
                    $0.debt?.type == .payable &&
                    $0.paymentDate >= month &&
                    $0.paymentDate < nextMonth
                }
                .reduce(0) {
                    $0 + $1.amount
                }
            
            
            results.append(
                CashFlowTrendData(
                    date: month,
                    cashInflows:
                        revenue
                    + collections,
                    cashOutflows:
                        expenses
                    + repayments
                    + scheduledRecurringExpenses(
                        for: month
                    )
                )
            )
            
            month = nextMonth
        }
        
        return results
    }
    
    
    private var selectedTrendData:
    CashFlowTrendData? {
        
        guard let selectedChartDate else {
            return nil
        }
        
        return cashFlowTrendData.min {
            abs(
                $0.date.timeIntervalSince(
                    selectedChartDate
                )
            )
            <
                abs(
                    $1.date.timeIntervalSince(
                        selectedChartDate
                    )
                )
        }
    }
    
    
    // MARK: - INSIGHT
    
    private var largestCashInflow:
    (name: String, amount: Double)? {
        
        cashInflowBreakdownData.max {
            $0.amount < $1.amount
        }
    }
    
    
    private var largestCashOutflow:
    (name: String, amount: Double)? {
        
        cashOutflowBreakdownData.max {
            $0.amount < $1.amount
        }
    }
    
    
    private var cashFlowInsight: String {
        
        if cashInflows == 0 &&
            cashOutflows == 0 {
            
            return "No cash flow activity was recorded for this period."
        }
        
        
        var parts: [String] = []
        
        
        if netCashFlow > 0 {
            
            parts.append(
                "Cash inflows exceeded cash outflows by \(currency(netCashFlow)) for this period."
            )
            
        } else if netCashFlow < 0 {
            
            parts.append(
                "Cash outflows exceeded cash inflows by \(currency(abs(netCashFlow))) for this period."
            )
            
        } else {
            
            parts.append(
                "Cash inflows and cash outflows were equal for this period."
            )
        }
        
        
        if let largestCashInflow,
           cashInflows > 0 {
            
            let percentage =
            (
                largestCashInflow.amount
                / cashInflows
            ) * 100
            
            parts.append(
                "\(largestCashInflow.name) was the largest source of cash, contributing \(percentage.formatted(.number.precision(.fractionLength(1))))% of total cash inflows."
            )
        }
        
        
        if let largestCashOutflow,
           cashOutflows > 0 {
            
            let percentage =
            (
                largestCashOutflow.amount
                / cashOutflows
            ) * 100
            
            parts.append(
                "\(largestCashOutflow.name) was the largest use of cash, accounting for \(percentage.formatted(.number.precision(.fractionLength(1))))% of total cash outflows."
            )
        }
        
        return parts.joined(
            separator: " "
        )
    }
    
    
    // MARK: - VIEW
    
    var body: some View {
        
        NavigationStack {
            
            ScrollView(.vertical) {
                
                VStack(spacing: 24) {
                    
                    
                    // MARK: TOP HEADER
                    
                    ZStack {
                        
                        Text("Cash Flow")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        
                        HStack {
                            
                            Spacer()
                            
                            
                            Picker(
                                "Period",
                                selection: $selectedPeriod
                            ) {
                                
                                ForEach(
                                    CashFlowPeriod.allCases,
                                    id: \.self
                                ) { period in
                                    
                                    Text(period.rawValue)
                                        .tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 300)
                            .padding(.top, 20)
                        }
                    }
                    
                    
                    // MARK: PERIOD NAVIGATION
                    
                    HStack {
                        
                        if selectedPeriod != .allTime {
                            
                            Button {
                                changePeriod(by: -1)
                            } label: {
                                
                                Image(
                                    systemName:
                                        "chevron.left"
                                )
                                .font(.title3)
                            }
                            
                        } else {
                            
                            Color.clear
                                .frame(
                                    width: 24,
                                    height: 24
                                )
                        }
                        
                        
                        Spacer()
                        
                        
                        Text(selectedPeriodTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        
                        Spacer()
                        
                        
                        if selectedPeriod != .allTime {
                            
                            Button {
                                changePeriod(by: 1)
                            } label: {
                                
                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .font(.title3)
                            }
                            
                        } else {
                            
                            Color.clear
                                .frame(
                                    width: 24,
                                    height: 24
                                )
                        }
                    }
                    
                    
                    // MARK: KEY FINANCIALS
                    
                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {
                        
                        Text("Key Financials")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        
                        HStack(spacing: 16) {
                            
                            
                            kpiCard(
                                title: "Cash Inflows",
                                value: shortCurrency(
                                    cashInflows
                                ),
                                icon:
                                    "arrow.down.circle.fill"
                            )
                            
                            
                            kpiCard(
                                title: "Cash Outflows",
                                value: shortCurrency(
                                    cashOutflows
                                ),
                                icon:
                                    "arrow.up.circle.fill"
                            )
                            
                            
                            kpiCard(
                                title: "Net Cash Flow",
                                value: shortCurrency(
                                    netCashFlow
                                ),
                                icon:
                                    "arrow.left.arrow.right"
                            )
                            
                            
                            kpiCard(
                                title: "Flow Ratio",
                                value:
                                    cashOutflows > 0
                                ? String(
                                    format: "%.2fx",
                                    flowRatio
                                )
                                : "—",
                                icon:
                                    "chart.bar.fill"
                            )
                            
                            
                            kpiCard(
                                title: "Status",
                                value: cashFlowStatus,
                                icon:
                                    netCashFlow >= 0
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill"
                            )
                        }
                    }
                    
                    
                    // MARK: INFLOW & OUTFLOW BREAKDOWN
                    
                    HStack(
                        alignment: .top,
                        spacing: 24
                    ) {
                        
                        // MARK: INFLOW CARD
                        
                        VStack(
                            alignment: .leading,
                            spacing: 16
                        ) {
                            
                            Text("Cash Inflows")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Where the money came from")
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            HStack(
                                alignment: .center,
                                spacing: 24
                            ) {
                                
                                VStack(
                                    alignment: .leading,
                                    spacing: 10
                                ) {
                                    
                                    ForEach(
                                        cashInflowBreakdownData,
                                        id: \.name
                                    ) { item in
                                        
                                        cashFlowRow(
                                            item.name,
                                            amount: item.amount,
                                            total: cashInflows,
                                            percentageContext: "cash inflows"
                                        )
                                    }
                                    
                                    Divider()
                                    
                                    totalRow(
                                        "Total Cash Inflows",
                                        amount: cashInflows
                                    )
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                
                                if !cashInflowBreakdownData.isEmpty {
                                    
                                    Chart {
                                        
                                        ForEach(
                                            cashInflowBreakdownData,
                                            id: \.name
                                        ) { item in
                                            
                                            SectorMark(
                                                angle: .value(
                                                    "Amount",
                                                    item.amount
                                                ),
                                                innerRadius: .ratio(0.60),
                                                angularInset: 2
                                            )
                                            .foregroundStyle(
                                                by: .value(
                                                    "Category",
                                                    item.name
                                                )
                                            )
                                        }
                                    }
                                    .chartBackground { proxy in
                                        
                                        GeometryReader { geometry in
                                            
                                            if let anchor = proxy.plotFrame {
                                                
                                                let frame = geometry[anchor]
                                                
                                                VStack(spacing: 4) {
                                                    
                                                    if let hovered = hoveredCashInflowItem {
                                                        
                                                        Text(hovered.name)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)
                                                        
                                                        Text(shortCurrency(hovered.amount))
                                                            .font(.headline)
                                                            .bold()
                                                        
                                                        Text(
                                                            cashInflows > 0
                                                            ? String(
                                                                format: "%.1f%% of inflows",
                                                                (hovered.amount / cashInflows) * 100
                                                            )
                                                            : "0.0% of inflows"
                                                        )
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        
                                                    } else {
                                                        
                                                        Text("Total Inflows")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                        
                                                        Text(shortCurrency(cashInflows))
                                                            .font(.headline)
                                                            .bold()
                                                    }
                                                }
                                                .position(
                                                    x: frame.midX,
                                                    y: frame.midY
                                                )
                                            }
                                        }
                                    }
                                    .chartOverlay { proxy in
                                        
                                        GeometryReader { geometry in
                                            
                                            Rectangle()
                                                .fill(.clear)
                                                .contentShape(Rectangle())
                                                .onContinuousHover { phase in
                                                    
                                                    switch phase {
                                                        
                                                    case .active(let location):
                                                        
                                                        guard let plotFrame = proxy.plotFrame else {
                                                            return
                                                        }
                                                        
                                                        let frame = geometry[plotFrame]
                                                        
                                                        let dx = location.x - frame.midX
                                                        let dy = location.y - frame.midY
                                                        
                                                        let distance = sqrt(
                                                            dx * dx + dy * dy
                                                        )
                                                        
                                                        let outerRadius =
                                                        min(
                                                            frame.width,
                                                            frame.height
                                                        ) / 2
                                                        
                                                        let innerRadius =
                                                        outerRadius * 0.60
                                                        
                                                        guard
                                                            distance >= innerRadius,
                                                            distance <= outerRadius
                                                                else {
                                                            hoveredCashInflowItem = nil
                                                            NSCursor.arrow.set()
                                                            return
                                                        }
                                                        
                                                        var angle = atan2(dx, -dy)
                                                        
                                                        if angle < 0 {
                                                            angle += 2 * .pi
                                                        }
                                                        
                                                        guard cashInflows > 0 else {
                                                            hoveredCashInflowItem = nil
                                                            return
                                                        }
                                                        
                                                        var runningAngle = 0.0
                                                        
                                                        for item in cashInflowBreakdownData {
                                                            
                                                            let sliceAngle =
                                                            (item.amount / cashInflows)
                                                            * 2 * .pi
                                                            
                                                            if angle >= runningAngle &&
                                                                angle < runningAngle + sliceAngle {
                                                                
                                                                hoveredCashInflowItem = (
                                                                    name: item.name,
                                                                    amount: item.amount
                                                                )
                                                                
                                                                NSCursor.pointingHand.set()
                                                                return
                                                            }
                                                            
                                                            runningAngle += sliceAngle
                                                        }
                                                        
                                                        hoveredCashInflowItem = nil
                                                        NSCursor.arrow.set()
                                                        
                                                    case .ended:
                                                        
                                                        hoveredCashInflowItem = nil
                                                        NSCursor.arrow.set()
                                                    }
                                                }
                                        }
                                    }
                                    .frame(
                                        width: 300,
                                        height: 250
                                    )
                                }
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .topLeading
                        )
                        .padding(20)
                        .background(.thinMaterial)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16
                            )
                        )
                        
                        // MARK: OUTFLOW CARD
                        
                        VStack(
                            alignment: .leading,
                            spacing: 16
                        ) {
                            
                            Text("Cash Outflows")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Where the money went")
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            HStack(
                                alignment: .center,
                                spacing: 24
                            ) {
                                
                                VStack(
                                    alignment: .leading,
                                    spacing: 10
                                ) {
                                    
                                    ForEach(
                                        cashOutflowBreakdownData,
                                        id: \.name
                                    ) { item in
                                        
                                        cashFlowRow(
                                            item.name,
                                            amount: item.amount,
                                            total: cashOutflows,
                                            percentageContext: "cash outflows"
                                        )
                                    }
                                    
                                    Divider()
                                    
                                    totalRow(
                                        "Total Cash Outflows",
                                        amount: cashOutflows
                                    )
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                
                                if !cashOutflowBreakdownData.isEmpty {
                                    
                                    Chart {
                                        
                                        ForEach(
                                            cashOutflowBreakdownData,
                                            id: \.name
                                        ) { item in
                                            
                                            SectorMark(
                                                angle: .value(
                                                    "Amount",
                                                    item.amount
                                                ),
                                                innerRadius: .ratio(0.60),
                                                angularInset: 2
                                            )
                                            .foregroundStyle(
                                                by: .value(
                                                    "Category",
                                                    item.name
                                                )
                                            )
                                        }
                                    }
                                    .chartBackground { proxy in
                                        
                                        GeometryReader { geometry in
                                            
                                            if let anchor = proxy.plotFrame {
                                                
                                                let frame = geometry[anchor]
                                                
                                                VStack(spacing: 4) {
                                                    
                                                    if let hovered = hoveredCashOutflowItem {
                                                        
                                                        Text(hovered.name)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)
                                                        
                                                        Text(shortCurrency(hovered.amount))
                                                            .font(.headline)
                                                            .bold()
                                                        
                                                        Text(
                                                            cashOutflows > 0
                                                            ? String(
                                                                format: "%.1f%% of outflows",
                                                                (hovered.amount / cashOutflows) * 100
                                                            )
                                                            : "0.0% of outflows"
                                                        )
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        
                                                    } else {
                                                        
                                                        Text("Total Outflows")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                        
                                                        Text(shortCurrency(cashOutflows))
                                                            .font(.headline)
                                                            .bold()
                                                    }
                                                }
                                                .position(
                                                    x: frame.midX,
                                                    y: frame.midY
                                                )
                                            }
                                        }
                                    }
                                    .chartOverlay { proxy in
                                        
                                        GeometryReader { geometry in
                                            
                                            Rectangle()
                                                .fill(.clear)
                                                .contentShape(Rectangle())
                                                .onContinuousHover { phase in
                                                    
                                                    switch phase {
                                                        
                                                    case .active(let location):
                                                        
                                                        guard let plotFrame = proxy.plotFrame else {
                                                            return
                                                        }
                                                        
                                                        let frame = geometry[plotFrame]
                                                        
                                                        let dx = location.x - frame.midX
                                                        let dy = location.y - frame.midY
                                                        
                                                        let distance = sqrt(
                                                            dx * dx + dy * dy
                                                        )
                                                        
                                                        let outerRadius =
                                                        min(
                                                            frame.width,
                                                            frame.height
                                                        ) / 2
                                                        
                                                        let innerRadius =
                                                        outerRadius * 0.60
                                                        
                                                        guard
                                                            distance >= innerRadius,
                                                            distance <= outerRadius
                                                                else {
                                                            hoveredCashOutflowItem = nil
                                                            NSCursor.arrow.set()
                                                            return
                                                        }
                                                        
                                                        var angle = atan2(dx, -dy)
                                                        
                                                        if angle < 0 {
                                                            angle += 2 * .pi
                                                        }
                                                        
                                                        guard cashOutflows > 0 else {
                                                            hoveredCashOutflowItem = nil
                                                            return
                                                        }
                                                        
                                                        var runningAngle = 0.0
                                                        
                                                        for item in cashOutflowBreakdownData {
                                                            
                                                            let sliceAngle =
                                                            (item.amount / cashOutflows)
                                                            * 2 * .pi
                                                            
                                                            if angle >= runningAngle &&
                                                                angle < runningAngle + sliceAngle {
                                                                
                                                                hoveredCashOutflowItem = (
                                                                    name: item.name,
                                                                    amount: item.amount
                                                                )
                                                                
                                                                NSCursor.pointingHand.set()
                                                                return
                                                            }
                                                            
                                                            runningAngle += sliceAngle
                                                        }
                                                        
                                                        hoveredCashOutflowItem = nil
                                                        NSCursor.arrow.set()
                                                        
                                                    case .ended:
                                                        
                                                        hoveredCashOutflowItem = nil
                                                        NSCursor.arrow.set()
                                                    }
                                                }
                                        }
                                    }
                                    .frame(
                                        width: 300,
                                        height: 250
                                    )
                                }
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .topLeading
                        )
                        .padding(20)
                        .background(.thinMaterial)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16
                            )
                        )
                    }
                    
                    
                    // MARK: NET CASH FLOW SUMMARY
                    
                    VStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        
                        HStack {
                            
                            Text("Net Cash Flow")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text(
                                currency(netCashFlow)
                            )
                            .font(.title2)
                            .fontWeight(.bold)
                        }
                        
                        
                        Divider()
                        
                        
                        HStack {
                            
                            Text("Flow Ratio")
                            
                            Spacer()
                            
                            Text(
                                cashOutflows > 0
                                ? String(
                                    format:
                                        "%.2fx",
                                    flowRatio
                                )
                                : "—"
                            )
                            .fontWeight(.semibold)
                        }
                        
                        
                        HStack {
                            
                            Text("Status")
                            
                            Spacer()
                            
                            Text(cashFlowStatus)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 16
                        )
                    )
                    
                    
                    // MARK: CASH FLOW INSIGHT
                    
                    VStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        
                        Text("Cash Flow Insight")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        
                        Divider()
                        
                        
                        Text(cashFlowInsight)
                            .font(.body)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 16
                        )
                    )
                    
                    
                    // MARK: CASH FLOW TREND
                    
                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {
                        
                        Text(
                            "Cash Inflows vs Cash Outflows Trend"
                        )
                        .font(.headline)
                        .fontWeight(.bold)
                        
                        
                        Text(
                            selectedPeriod == .month
                            ? "Daily trend for \(selectedPeriodTitle)"
                            : selectedPeriod == .year
                            ? "Monthly trend for \(selectedPeriodTitle)"
                            : "Historical trend across all recorded periods"
                        )
                        .foregroundStyle(.secondary)
                        
                        
                        Divider()
                        
                        
                        Chart {
                            
                            ForEach(
                                cashFlowTrendData
                            ) { item in
                                
                                
                                LineMark(
                                    x: .value(
                                        "Date",
                                        item.date
                                    ),
                                    y: .value(
                                        "Amount",
                                        item.cashInflows
                                    )
                                )
                                .foregroundStyle(
                                    by: .value(
                                        "Type",
                                        "Cash Inflows"
                                    )
                                )
                                .symbol(
                                    by: .value(
                                        "Type",
                                        "Cash Inflows"
                                    )
                                )
                                
                                
                                LineMark(
                                    x: .value(
                                        "Date",
                                        item.date
                                    ),
                                    y: .value(
                                        "Amount",
                                        item.cashOutflows
                                    )
                                )
                                .foregroundStyle(
                                    by: .value(
                                        "Type",
                                        "Cash Outflows"
                                    )
                                )
                                .symbol(
                                    by: .value(
                                        "Type",
                                        "Cash Outflows"
                                    )
                                )
                            }
                        }
                        .chartXAxis {
                            if selectedPeriod == .month {
                                AxisMarks(values: daysInSelectedMonth) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(
                                                date,
                                                format: .dateTime.day()
                                            )
                                        }
                                    }
                                }
                            } else {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisTick()
                                    
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(
                                                date,
                                                format: .dateTime
                                                    .month(.abbreviated)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            
                            AxisMarks(
                                position: .trailing
                            ) { value in
                                
                                AxisGridLine()
                                AxisTick()
                                
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
                        .chartScrollableAxes(.horizontal)
                        .chartXScale(
                            domain: {
                                guard
                                    let firstDate = cashFlowTrendData.first?.date,
                                    let lastDate = cashFlowTrendData.last?.date,
                                    let paddedEnd = Calendar.current.date(
                                        byAdding: .day,
                                        value: 1,
                                        to: lastDate
                                    )
                                else {
                                    let today = Calendar.current.startOfDay(for: Date())
                                    return today...today
                                }

                                return firstDate...paddedEnd
                            }()
                        )
                        .chartXVisibleDomain(
                            length: 10 * 24 * 60 * 60
                        )
                        .chartXSelection(
                            value: $selectedChartDate
                        )
                        .frame(height: 280)
                        
                        if let selected =
                            selectedTrendData {
                            
                            HStack {
                                
                                Text(
                                    selected.date,
                                    format:
                                        selectedPeriod ==
                                        .month
                                    ? .dateTime
                                        .weekday(
                                            .abbreviated
                                        )
                                        .day()
                                        .month(
                                            .abbreviated
                                        )
                                    : .dateTime
                                        .month(
                                            .abbreviated
                                        )
                                        .year()
                                )
                                .fontWeight(.semibold)
                                
                                
                                Spacer()
                                
                                
                                Text(
                                    "Cash In: \(currency(selected.cashInflows))"
                                )
                                
                                
                                Divider()
                                    .frame(
                                        height: 18
                                    )
                                
                                
                                Text(
                                    "Cash Out: \(currency(selected.cashOutflows))"
                                )
                            }
                            .padding(
                                .horizontal,
                                16
                            )
                            .padding(
                                .vertical,
                                12
                            )
                        }
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(.thinMaterial)
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
            .navigationTitle("Cash Flow")
        }
    }
    
    
    private var daysInSelectedMonth: [Date] {
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(
            of: .month,
            for: selectedDate
        ) else {
            return []
        }
        
        guard let dayRange = calendar.range(
            of: .day,
            in: .month,
            for: monthInterval.start
        ) else {
            return []
        }
        
        return dayRange.compactMap { day in
            calendar.date(
                byAdding: .day,
                value: day - 1,
                to: monthInterval.start
            )
        }
    }
    
    
    // MARK: - CASH FLOW ROW
    
    private func cashFlowRow(
        _ title: String,
        amount: Double,
        total: Double,
        percentageContext: String
    ) -> some View {
        
        let percentage =
        total > 0
        ? (amount / total) * 100
        : 0
        
        return HStack {
            
            Text(title)
            
            Spacer()
            
            Text(currency(amount))
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .help(
            String(
                format: "%.1f%% of %@",
                percentage,
                percentageContext
            )
        )
    }
    
    
    // MARK: - HOVER PERCENTAGE
    
    private func amountWithHoverPercentage(
        amount: Double,
        total: Double,
        context: String
    ) -> some View {
        
        let percentage =
        total > 0
        ? (amount / total) * 100
        : 0
        
        return Text(
            currency(amount)
        )
        .fontWeight(.semibold)
        .lineLimit(1)
        .help(
            String(
                format:
                    "%.1f%% of %@",
                percentage,
                context
            )
        )
    }
    
    
    // MARK: - TOTAL ROW
    
    private func totalRow(
        _ title: String,
        amount: Double
    ) -> some View {
        
        HStack {
            
            Text(title)
                .fontWeight(.bold)
            
            Spacer()
            
            Text(
                currency(amount)
            )
            .fontWeight(.bold)
            .lineLimit(1)
        }
    }
    
    
    // MARK: - KPI CARD
    
    private func kpiCard(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            
            HStack {
                
                Image(
                    systemName: icon
                )
                .font(.title2)
                
                Spacer()
            }
            
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }
    
    
    // MARK: - CURRENCY
    
    private func currency(
        _ amount: Double
    ) -> String {
        
        amount.formatted(
            .currency(
                code: ledgerCurrencyCode
            ).presentation(.isoCode)
            .precision(
                .fractionLength(0)
            )
        )
    }
    
    
    private func shortCurrency(
        _ amount: Double
    ) -> String {
        
        if abs(amount) >=
            1_000_000_000 {
            
            return String(
                format:
                    "\(ledgerCurrencyCode) %.1fB",
                amount /
                1_000_000_000
            )
            
        } else if abs(amount) >=
                    1_000_000 {
            
            return String(
                format:
                    "\(ledgerCurrencyCode) %.1fM",
                amount /
                1_000_000
            )
            
        } else if abs(amount) >=
                    1_000 {
            
            return String(
                format:
                    "\(ledgerCurrencyCode) %.1fK",
                amount /
                1_000
            )
            
        } else {
            
            return String(
                format:
                    "\(ledgerCurrencyCode) %.0f",
                amount
            )
        }
    }
}


