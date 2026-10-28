import SwiftUI
import SwiftData
import Charts

enum ProfitLossPeriod: String, CaseIterable {
    case month = "Month"
    case year = "Year"
    case allTime = "All Time"
}

struct MonthlyPLData: Identifiable {
    let id = UUID()
    let month: Date
    let revenue: Double
    let expenses: Double
}

struct ProfitLossView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Query private var transactions: [FinanceTransaction]
    
    @State private var selectedPeriod: ProfitLossPeriod = .month
    @State private var selectedDate = Date()
    @State private var selectedPLChartDate: Date?
    @State private var hoveredExpenseName: String? = nil
    @State private var hoveredExpenseAmount: Double? = nil
    @State private var hoveredIncomeItem: (name: String, amount: Double)? = nil
    @State private var hoveredExpenseItem: (name: String, amount: Double)? = nil
    
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
    
    
    // MARK: - CALCULATIONS
    
    private var totalRevenue: Double {
        filteredTransactions
            .filter {
                $0.type == .revenue &&
                $0.incomeType == .operatingRevenue
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    
    private var otherIncome: Double {
        filteredTransactions
            .filter {
                $0.type == .revenue &&
                $0.incomeType == .otherIncome
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    
    private var totalIncome: Double {
        totalRevenue + otherIncome
    }
    
    
    private var totalExpenses: Double {
        filteredTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .operatingExpense
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    
    private var costOfSales: Double {
        filteredTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .costOfSales
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    
    private var financeCosts: Double {
        filteredTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .financeCost
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    
    private var otherExpenses: Double {
        filteredTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .other
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    
    private var taxExpense: Double {
        filteredTransactions
            .filter {
                $0.type == .expense &&
                $0.expenseType == .tax
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    
    private var grossProfit: Double {
        totalRevenue - costOfSales
    }
    
    
    private var operatingProfit: Double {
        grossProfit - totalExpenses
    }
    
    
    private var profitBeforeTax: Double {
        operatingProfit
        + otherIncome
        - financeCosts
        - otherExpenses
    }
    
    
    private var netProfit: Double {
        profitBeforeTax - taxExpense
    }
    
    
    private var netProfitMargin: Double {
        guard totalRevenue > 0 else {
            return 0
        }
        
        return (netProfit / totalRevenue) * 100
    }
    
    
    // MARK: - BREAKDOWN DATA
    
    private var incomeBreakdownData: [(name: String, amount: Double)] {
        [
            ("Revenue", totalRevenue),
            ("Other Income", otherIncome)
        ]
            .filter { $0.amount > 0 }
    }
    
    
    private var expenseBreakdownData: [(name: String, amount: Double)] {
        [
            ("Cost of Sales", costOfSales),
            ("Operating", totalExpenses),
            ("Finance", financeCosts),
            ("Other", otherExpenses),
            ("Tax", taxExpense)
        ]
            .filter { $0.amount > 0 }
    }
    
    
    private var expenseBreakdownTotal: Double {
        expenseBreakdownData.reduce(0) {
            $0 + $1.amount
        }
    }
    
    
    private var chartData: [(name: String, amount: Double)] {
        [
            ("Revenue", totalRevenue),
            ("Cost of Sales", costOfSales),
            ("Operating Expenses", totalExpenses),
            ("Net Profit", netProfit)
        ]
    }
    
    
    // MARK: - TREND DATA
    
    private var monthlyTrendData: [MonthlyPLData] {
        let calendar = Calendar.current
        
        // MONTH VIEW:
        // Create EVERY calendar day in the selected month,
        // including days with no transactions.
        if selectedPeriod == .month {
            
            guard let monthInterval = calendar.dateInterval(
                of: .month,
                for: selectedDate
            ) else {
                return []
            }
            
            var results: [MonthlyPLData] = []
            var currentDate = monthInterval.start
            
            while currentDate < monthInterval.end {
                
                let dayStart = calendar.startOfDay(for: currentDate)
                
                guard let nextDay = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: dayStart
                ) else {
                    break
                }
                
                let dayTransactions = filteredTransactions.filter {
                    $0.date >= dayStart && $0.date < nextDay
                }
                
                let revenue = dayTransactions
                    .filter {
                        $0.type == .revenue &&
                        $0.incomeType == .operatingRevenue
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                let expenses = dayTransactions
                    .filter {
                        $0.type == .expense
                    }
                    .reduce(0) {
                        $0 + $1.amount
                    }
                
                results.append(
                    MonthlyPLData(
                        month: dayStart,
                        revenue: revenue,
                        expenses: expenses
                    )
                )
                
                currentDate = nextDay
            }
            
            return results
        }
        
        // YEAR / ALL TIME:
        // Keep these grouped monthly.
        let grouped = Dictionary(
            grouping: filteredTransactions
        ) { transaction in
            
            calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: transaction.date
                )
            ) ?? transaction.date
        }
        
        return grouped.map { date, periodTransactions in
            
            let revenue = periodTransactions
                .filter {
                    $0.type == .revenue &&
                    $0.incomeType == .operatingRevenue
                }
                .reduce(0) {
                    $0 + $1.amount
                }
            
            let expenses = periodTransactions
                .filter {
                    $0.type == .expense
                }
                .reduce(0) {
                    $0 + $1.amount
                }
            
            return MonthlyPLData(
                month: date,
                revenue: revenue,
                expenses: expenses
            )
        }
        .sorted {
            $0.month < $1.month
        }
    }
    
    private var selectedPLDayData: MonthlyPLData? {
        guard let selectedDate = selectedPLChartDate else {
            return nil
        }
        
        return monthlyTrendData.min { first, second in
            abs(first.month.timeIntervalSince(selectedDate))
            <
                abs(second.month.timeIntervalSince(selectedDate))
        }
    }
    
    
    // MARK: - PERIOD NAVIGATION
    
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
    
    
    private func changePeriod(by value: Int) {
        
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
    
    
    // MARK: - VIEW
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 24) {
                    
                    
                    // MARK: TOP HEADER
                    
                    ZStack {
                        
                        Text("Profit & Loss")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            
                            Spacer()
                            
                            Picker(
                                "Period",
                                selection: $selectedPeriod
                            ) {
                                
                                ForEach(
                                    ProfitLossPeriod.allCases,
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
                                    systemName: "chevron.left"
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
                                    systemName: "chevron.right"
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
                                title: "Total Revenue",
                                value: shortCurrency(
                                    totalRevenue
                                ),
                                icon:
                                    "arrow.up.right.circle.fill"
                            )
                            
                            
                            kpiCard(
                                title: "Total Income",
                                value: shortCurrency(
                                    totalIncome
                                ),
                                icon: "banknote.fill"
                            )
                            
                            
                            kpiCard(
                                title: "Gross Profit",
                                value: shortCurrency(
                                    grossProfit
                                ),
                                icon:
                                    "chart.line.uptrend.xyaxis"
                            )
                            
                            
                            kpiCard(
                                title: "Net Profit",
                                value: shortCurrency(
                                    netProfit
                                ),
                                icon: "banknote.fill"
                            )
                            
                            
                            kpiCard(
                                title: "Net Margin",
                                value: String(
                                    format: "%.1f%%",
                                    netProfitMargin
                                ),
                                icon: "percent"
                            )
                        }
                    }
                    
                    
                    // MARK: PERFORMANCE OVERVIEW
                    
                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {
                        
                        Text("Performance Overview")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        
                        Divider()
                        
                        
                        Chart {
                            
                            ForEach(
                                chartData,
                                id: \.name
                            ) { item in
                                
                                BarMark(
                                    x: .value(
                                        "Category",
                                        item.name
                                    ),
                                    y: .value(
                                        "Amount",
                                        item.amount
                                    )
                                )
                                .foregroundStyle(.yellow)
                            }
                        }
                        .frame(height: 240)
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
                    
                    
                    // MARK: INCOME & EXPENSE BREAKDOWN

                    HStack(alignment: .top, spacing: 24) {

                        // ============================================================
                        // MARK: INCOME CARD
                        // ============================================================

                        VStack(alignment: .leading, spacing: 16) {

                            Text("Income")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Where income came from")
                                .foregroundStyle(.secondary)

                            Divider()

                            HStack(alignment: .center, spacing: 24) {

                                // LEFT SIDE - INCOME VALUES
                                VStack(alignment: .leading, spacing: 12) {

                                    profitLossRow(
                                        "Total Revenue",
                                        amount: totalRevenue
                                    )

                                    profitLossRow(
                                        "Other Income",
                                        amount: otherIncome
                                    )

                                    Divider()

                                    totalRow(
                                        "Total Income",
                                        amount: totalIncome
                                    )
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )

                                // RIGHT SIDE - INCOME DONUT
                                if !incomeBreakdownData.isEmpty {

                                    Chart {

                                        ForEach(
                                            incomeBreakdownData,
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

                                    // CENTER OF INCOME DONUT
                                    .chartBackground { proxy in

                                        GeometryReader { geometry in

                                            if let anchor = proxy.plotFrame {

                                                let frame = geometry[anchor]

                                                VStack(spacing: 4) {

                                                    if let hovered = hoveredIncomeItem {

                                                        Text(hovered.name)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)

                                                        Text(shortCurrency(hovered.amount))
                                                            .font(.headline)
                                                            .bold()

                                                        Text(
                                                            totalIncome > 0
                                                            ? String(
                                                                format: "%.1f%% of income",
                                                                (hovered.amount / totalIncome) * 100
                                                            )
                                                            : "0.0% of income"
                                                        )
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)

                                                    } else {

                                                        Text("Total Income")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)

                                                        Text(shortCurrency(totalIncome))
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

                                    // HOVER OVER INCOME DONUT
                                    .chartOverlay { proxy in

                                        GeometryReader { geometry in

                                            Rectangle()
                                                .fill(.clear)
                                                .contentShape(Rectangle())

                                                .onContinuousHover { phase in

                                                    switch phase {

                                                    case .active(let location):

                                                        guard
                                                            let plotFrame = proxy.plotFrame
                                                        else {
                                                            return
                                                        }

                                                        let frame =
                                                            geometry[plotFrame]

                                                        let dx =
                                                            location.x -
                                                            frame.midX

                                                        let dy =
                                                            location.y -
                                                            frame.midY

                                                        let distance =
                                                            sqrt(
                                                                dx * dx +
                                                                dy * dy
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
                                                            return
                                                        }

                                                        var angle =
                                                            atan2(
                                                                dx,
                                                                -dy
                                                            )

                                                        if angle < 0 {
                                                            angle += 2 * .pi
                                                        }

                                                        guard totalIncome > 0 else {
                                                            return
                                                        }

                                                        var runningAngle = 0.0

                                                        for item in incomeBreakdownData {

                                                            let sliceAngle =
                                                                (
                                                                    item.amount /
                                                                    totalIncome
                                                                ) * 2 * .pi

                                                            if angle >= runningAngle &&
                                                               angle < runningAngle + sliceAngle {

                                                                hoveredIncomeItem = (
                                                                    name: item.name,
                                                                    amount: item.amount
                                                                )

                                                                NSCursor.pointingHand.set()

                                                                return
                                                            }

                                                            runningAngle += sliceAngle
                                                        }

                                                    case .ended:

                                                        hoveredExpenseItem = nil
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


                        // ============================================================
                        // MARK: EXPENSE CARD
                        // ============================================================

                        VStack(alignment: .leading, spacing: 16) {

                            Text("Expenses")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Where the money was spent")
                                .foregroundStyle(.secondary)

                            Divider()

                            HStack(alignment: .center, spacing: 24) {

                                // LEFT SIDE - EXPENSE VALUES
                                VStack(alignment: .leading, spacing: 12) {

                                    profitLossRow(
                                        "Cost of Sales",
                                        amount: costOfSales
                                    )

                                    profitLossRow(
                                        "Operating Expenses",
                                        amount: totalExpenses
                                    )

                                    profitLossRow(
                                        "Finance Costs",
                                        amount: financeCosts
                                    )

                                    profitLossRow(
                                        "Other Expenses",
                                        amount: otherExpenses
                                    )

                                    profitLossRow(
                                        "Tax",
                                        amount: taxExpense
                                    )

                                    Divider()

                                    totalRow(
                                        "Total Expenses",
                                        amount: expenseBreakdownTotal
                                    )
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )

                                // RIGHT SIDE - EXPENSE DONUT
                                if !expenseBreakdownData.isEmpty {

                                    Chart {

                                        ForEach(
                                            expenseBreakdownData,
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

                                    // CENTER OF EXPENSE DONUT
                                    .chartBackground { proxy in

                                        GeometryReader { geometry in

                                            if let anchor = proxy.plotFrame {

                                                let frame = geometry[anchor]

                                                VStack(spacing: 4) {

                                                    if let hovered = hoveredExpenseItem {

                                                        Text(hovered.name)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)

                                                        Text(shortCurrency(hovered.amount))
                                                            .font(.headline)
                                                            .bold()

                                                        Text(
                                                            expenseBreakdownTotal > 0
                                                            ? String(
                                                                format: "%.1f%% of expenses",
                                                                (hovered.amount / expenseBreakdownTotal) * 100
                                                            )
                                                            : "0.0% of expenses"
                                                        )
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)

                                                    } else {

                                                        Text("Total Expenses")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)

                                                        Text(shortCurrency(expenseBreakdownTotal))
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

                                    // HOVER OVER EXPENSE DONUT
                                    .chartOverlay { proxy in

                                        GeometryReader { geometry in

                                            Rectangle()
                                                .fill(.clear)
                                                .contentShape(Rectangle())

                                                .onContinuousHover { phase in

                                                    switch phase {

                                                    case .active(let location):

                                                        guard
                                                            let plotFrame = proxy.plotFrame
                                                        else {
                                                            return
                                                        }

                                                        let frame =
                                                            geometry[plotFrame]

                                                        let dx =
                                                            location.x -
                                                            frame.midX

                                                        let dy =
                                                            location.y -
                                                            frame.midY

                                                        let distance =
                                                            sqrt(
                                                                dx * dx +
                                                                dy * dy
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
                                                            return
                                                        }

                                                        var angle =
                                                            atan2(
                                                                dx,
                                                                -dy
                                                            )

                                                        if angle < 0 {
                                                            angle += 2 * .pi
                                                        }

                                                        guard expenseBreakdownTotal > 0 else {
                                                            return
                                                        }

                                                        var runningAngle = 0.0

                                                        for item in expenseBreakdownData {

                                                            let sliceAngle =
                                                                (
                                                                    item.amount /
                                                                    expenseBreakdownTotal
                                                                ) * 2 * .pi

                                                            if angle >= runningAngle &&
                                                               angle < runningAngle + sliceAngle {

                                                                hoveredExpenseItem = (
                                                                    name: item.name,
                                                                    amount: item.amount
                                                                )

                                                                NSCursor.pointingHand.set()

                                                                return
                                                            }

                                                            runningAngle += sliceAngle
                                                        }

                                                    case .ended:

                                                        hoveredIncomeItem = nil
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
                    
                    // MARK: OTHER ITEMS
                    
                    VStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        
                        Text("Other Items")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        
                        Divider()
                        
                        
                        profitLossRow(
                            "Other Income",
                            amount: otherIncome
                        )
                        
                        
                        profitLossRow(
                            "Finance Costs",
                            amount: financeCosts
                        )
                        
                        
                        profitLossRow(
                            "Other Expenses",
                            amount: otherExpenses
                        )
                        
                        
                        Divider()
                        
                        
                        totalRow(
                            "Profit Before Tax",
                            amount: profitBeforeTax
                        )
                        
                        
                        profitLossRow(
                            "Tax",
                            amount: taxExpense
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
                    
                    
                    // MARK: NET PROFIT SUMMARY
                    
                    VStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        
                        HStack {
                            
                            Text("Net Profit")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            
                            Spacer()
                            
                            
                            Text(
                                currency(netProfit)
                            )
                            .font(.title2)
                            .fontWeight(.bold)
                        }
                        
                        
                        Divider()
                        
                        
                        HStack {
                            
                            Text(
                                "Net Profit Margin"
                            )
                            
                            
                            Spacer()
                            
                            
                            Text(
                                netProfitMargin
                                    .formatted(
                                        .number
                                            .precision(
                                                .fractionLength(
                                                    1
                                                )
                                            )
                                    )
                                + "%"
                            )
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
                    
                    
                    // MARK: - REVENUE VS EXPENSES TREND
                    
                    VStack(alignment: .leading, spacing: 16) {
                        
                        Text("Revenue vs Expenses Trend")
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
                            ForEach(monthlyTrendData) { item in
                                
                                LineMark(
                                    x: .value("Date", item.month),
                                    y: .value(
                                        "Amount",
                                        item.revenue
                                    )
                                )
                                .foregroundStyle(
                                    by: .value(
                                        "Type",
                                        "Revenue"
                                    )
                                )
                                .symbol(
                                    by: .value(
                                        "Type",
                                        "Revenue"
                                    )
                                )
                                
                                LineMark(
                                    x: .value("Date", item.month),
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
                                .symbol(
                                    by: .value(
                                        "Type",
                                        "Expenses"
                                    )
                                )
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                AxisGridLine()
                                AxisTick()
                                
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(
                                            date,
                                            format: .dateTime
                                                .weekday(.abbreviated)
                                                .day()
                                        )
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing) { value in
                                AxisGridLine()
                                AxisTick()
                                
                                AxisValueLabel {
                                    if let amount = value.as(Double.self) {
                                        if amount >= 1_000_000 {
                                            Text(
                                                "\(ledgerCurrencyCode) \(amount / 1_000_000, specifier: "%.1f")M"
                                            )
                                        } else if amount >= 1_000 {
                                            Text(
                                                "\(ledgerCurrencyCode) \(amount / 1_000, specifier: "%.0f")K"
                                            )
                                        } else {
                                            Text(
                                                "\(ledgerCurrencyCode) \(amount, specifier: "%.0f")"
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .chartXScale(
                            domain: {
                                guard
                                    let firstDate = monthlyTrendData.first?.month,
                                    let lastDate = monthlyTrendData.last?.month,
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
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(
                            length: 10 * 24 * 60 * 60
                        )
                        .chartXSelection(
                            value: $selectedPLChartDate
                        )
                        .frame(height: 280)
                        
                        if let selectedDay = selectedPLDayData {
                            
                            HStack {
                                
                                Text(
                                    selectedDay.month,
                                    format: .dateTime
                                        .weekday(.abbreviated)
                                        .day()
                                        .month(.abbreviated)
                                )
                                .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text(
                                    "Revenue: \(ledgerCurrencyCode) \(selectedDay.revenue, specifier: "%.0f")"
                                )
                                
                                Divider()
                                    .frame(height: 18)
                                
                                Text(
                                    "Expenses: \(ledgerCurrencyCode) \(selectedDay.expenses, specifier: "%.0f")"
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Profit & Loss")
        }
    }
    
    // MARK: - PROFIT & LOSS HELPERS

    // MARK: - ROWS

    private func profitLossRow(
        _ title: String,
        amount: Double
    ) -> some View {

        HStack {

            Text(title)

            Spacer()

            Text(currency(amount))
                .fontWeight(.medium)
        }
    }
    
    private func breakdownRow(
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


    private func totalRow(
        _ title: String,
        amount: Double
    ) -> some View {

        HStack {

            Text(title)
                .fontWeight(.bold)

            Spacer()

            Text(currency(amount))
                .fontWeight(.bold)
        }
    }


    // MARK: - CURRENCY

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


    private func shortCurrency(
        _ amount: Double
    ) -> String {

        let absoluteAmount = abs(amount)

        let formatted: String

        if absoluteAmount >= 1_000_000_000 {

            formatted = String(
                format: "%.1fB",
                absoluteAmount / 1_000_000_000
            )

        } else if absoluteAmount >= 1_000_000 {

            formatted = String(
                format: "%.1fM",
                absoluteAmount / 1_000_000
            )

        } else if absoluteAmount >= 1_000 {

            formatted = String(
                format: "%.1fK",
                absoluteAmount / 1_000
            )

        } else {

            formatted = String(
                format: "%.0f",
                absoluteAmount
            )
        }

        return amount < 0
            ? "-\(ledgerCurrencyCode) \(formatted)"
            : "\(ledgerCurrencyCode) \(formatted)"
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

                Image(systemName: icon)
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
}
