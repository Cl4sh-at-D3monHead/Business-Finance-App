import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FinanceTransaction.date, order: .reverse)
    private var transactions: [FinanceTransaction]

    @State private var selectedDate = Date()
    @State private var selectedPeriod = "Month"
    @State private var selectedFilter = "All"
    @State private var searchText = ""

    @State private var selectedTransaction: FinanceTransaction?

    private let periods = ["Month", "Year", "All Time"]

    private let filters = [
        "All",
        "Income",
        "Expense",
        "Payments",
        "Transfers"
    ]

    // MARK: - Period Title

    private var periodTitle: String {

        switch selectedPeriod {

        case "Year":
            return selectedDate.formatted(.dateTime.year())

        case "All Time":
            return "All Time"

        default:
            return selectedDate.formatted(
                .dateTime.month(.wide).year()
            )
        }
    }

    // MARK: - Period Navigation

    private func changePeriod(_ direction: Int) {

        guard selectedPeriod != "All Time" else {
            return
        }

        let component: Calendar.Component =
            selectedPeriod == "Year" ? .year : .month

        if let newDate = Calendar.current.date(
            byAdding: component,
            value: direction,
            to: selectedDate
        ) {
            selectedDate = newDate
        }
    }

    // MARK: - Period Filter

    private var periodTransactions: [FinanceTransaction] {

        let calendar = Calendar.current

        return transactions.filter { transaction in

            switch selectedPeriod {

            case "Year":
                return calendar.isDate(
                    transaction.date,
                    equalTo: selectedDate,
                    toGranularity: .year
                )

            case "All Time":
                return true

            default:
                return calendar.isDate(
                    transaction.date,
                    equalTo: selectedDate,
                    toGranularity: .month
                )
            }
        }
    }

    // MARK: - Transaction Classification

    
    private func classification(
        for transaction: FinanceTransaction
    ) -> String {

        if transaction.notes.contains("Payment Type:") &&
           transaction.notes.contains("Provider:") {
            return "Payments"
        }

        let category = transaction.category
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if category == "business payment" {
            return "Payments"
        }

        if category == "transfer" ||
           category == "bank transfer" ||
           category == "internal transfer" {
            return "Transfers"
        }

        return transaction.type == .revenue
            ? "Income"
            : "Expense"
    }


    // MARK: - Filtered Transactions

    private var filteredTransactions: [FinanceTransaction] {

        periodTransactions.filter { transaction in

            let matchesFilter =
                selectedFilter == "All" ||
                classification(for: transaction) == selectedFilter

            let query = searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let matchesSearch =
                query.isEmpty ||
                transaction.title.localizedCaseInsensitiveContains(query) ||
                transaction.category.localizedCaseInsensitiveContains(query) ||
                transaction.notes.localizedCaseInsensitiveContains(query) ||
                transaction.type.rawValue.localizedCaseInsensitiveContains(query)

            return matchesFilter && matchesSearch
        }
    }

    // MARK: - Body

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            // MARK: Header

            HStack {

                VStack(alignment: .leading, spacing: 5) {

                    Text("Transaction History")
                        .font(.largeTitle.bold())

                    Text("View and manage business transactions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            // MARK: Period Selector

            VStack(spacing: 14) {

                Picker("Period", selection: $selectedPeriod) {

                    ForEach(periods, id: \.self) { period in
                        Text(period).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                HStack {

                    Button {
                        changePeriod(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 36, height: 36)
                    }
                    .disabled(selectedPeriod == "All Time")

                    Spacer()

                    VStack(spacing: 4) {

                        Text(periodTitle)
                            .font(.headline)

                        Text("Reporting Period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        changePeriod(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 36, height: 36)
                    }
                    .disabled(selectedPeriod == "All Time")
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.quaternary.opacity(0.25))
            .clipShape(
                RoundedRectangle(cornerRadius: 14)
            )

            // MARK: Total Transactions

            HStack(spacing: 14) {

                Image(systemName: "receipt.text")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(.quaternary.opacity(0.4))
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )

                VStack(alignment: .leading, spacing: 5) {

                    Text("Total Transactions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(periodTransactions.count)")
                        .font(.title.bold())
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.25))
            .clipShape(
                RoundedRectangle(cornerRadius: 14)
            )

            // MARK: Search

            HStack(spacing: 10) {

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    "Search transactions...",
                    text: $searchText
                )
                .textFieldStyle(.plain)

                if !searchText.isEmpty {

                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.25))
            .clipShape(
                RoundedRectangle(cornerRadius: 10)
            )

            // MARK: Categories

            HStack(spacing: 10) {

                ForEach(filters, id: \.self) { filter in

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {

                        Text(filter)
                            .font(.subheadline)
                            .fontWeight(
                                selectedFilter == filter
                                ? .semibold
                                : .regular
                            )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                selectedFilter == filter
                                ? Color.accentColor
                                : Color.primary.opacity(0.06)
                            )
                            .foregroundStyle(
                                selectedFilter == filter
                                ? Color.white
                                : Color.primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            // MARK: Transaction List Header

            HStack {

                Text("All Transactions")
                    .font(.headline)

                Spacer()

                Text("\(filteredTransactions.count) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Transaction List

            if filteredTransactions.isEmpty {

                ContentUnavailableView(
                    "No Transactions Found",
                    systemImage: "receipt.text",
                    description: Text(
                        "No matching transactions for this period or category."
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

            } else {

                ScrollView {

                    LazyVStack(spacing: 12) {

                        ForEach(filteredTransactions) { transaction in

                            Button {
                                selectedTransaction = transaction
                            } label: {
                                transactionRow(transaction)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 850, minHeight: 650)
        .sheet(item: $selectedTransaction) { transaction in

            EditTransactionView(transaction: transaction)
        }
    }

    // MARK: - Transaction Row

    private func transactionRow(
        _ transaction: FinanceTransaction
    ) -> some View {

        let category = classification(for: transaction)
        let isIncome = transaction.type == .revenue

        return HStack(spacing: 14) {

            // Transaction Icon

            Image(systemName: iconFor(category))
                .font(.title3)
                .foregroundStyle(
                    isIncome ? Color.green : Color.primary
                )
                .frame(width: 44, height: 44)
                .background(.quaternary.opacity(0.4))
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )

            // Transaction Information

            VStack(alignment: .leading, spacing: 6) {

                Text(transaction.title)
                    .font(.headline)

                Text(
                    "\(transaction.date.formatted(date: .abbreviated, time: .omitted)) • \(transaction.category)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount and Type

            VStack(alignment: .trailing, spacing: 6) {

                Text(
                    "\(isIncome ? "+" : "-")\(ledgerCurrencyCode) \(transaction.amount.formatted(.number.precision(.fractionLength(0))))"
                )
                .font(.headline)
                .foregroundStyle(
                    isIncome ? Color.green : Color.primary
                )

                Text(category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.25))
        .clipShape(
            RoundedRectangle(cornerRadius: 14)
        )
        .contentShape(
            RoundedRectangle(cornerRadius: 14)
        )
    }

    // MARK: - Category Icons

    private func iconFor(_ category: String) -> String {

        switch category {

        case "Income":
            return "arrow.down.left"

        case "Expense":
            return "arrow.up.right"

        case "Payments":
            return "creditcard"

        case "Transfers":
            return "arrow.left.arrow.right"

        default:
            return "receipt"
        }
    }
}
