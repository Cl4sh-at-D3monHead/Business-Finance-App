import SwiftUI
import SwiftData

struct DebtsView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Query(sort: \Debt.dueDate)
    private var debts: [Debt]

    @State private var showingAddDebt = false

    // MARK: - DATA

    private var receivables: [Debt] {
        debts.filter {
            $0.type == .receivable && !$0.isFullyPaid
        }
    }

    private var payables: [Debt] {
        debts.filter {
            $0.type == .payable && !$0.isFullyPaid
        }
    }

    private var totalReceivables: Double {
        receivables.reduce(0) {
            $0 + $1.outstandingBalance
        }
    }

    private var totalPayables: Double {
        payables.reduce(0) {
            $0 + $1.outstandingBalance
        }
    }

    private var netPosition: Double {
        totalReceivables - totalPayables
    }

    private var overdueDebts: [Debt] {
        debts.filter {
            !$0.isFullyPaid && $0.isOverdue
        }
    }

    private var receivableAccountCount: Int {
        receivables.count
    }

    private var payableAccountCount: Int {
        payables.count
    }

    private var debtStatus: String {
        overdueDebts.isEmpty ? "Up to Date" : "\(overdueDebts.count) Overdue"
    }

    // MARK: - BODY

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 24) {

                    // MARK: - HEADER

                    ZStack {

                        Text("Debts")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        HStack {

                            Spacer()

                            Button {
                                showingAddDebt = true
                            } label: {
                                Label("Add Debt", systemImage: "plus")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)


                    // MARK: - DEBT OVERVIEW

                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {

                        Text("Debt Overview")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        HStack(spacing: 0) {

                            overviewItem(
                                title: "Total Receivables",
                                value: currency(totalReceivables)
                            )

                            Divider()
                                .frame(height: 40)

                            overviewItem(
                                title: "Total Payables",
                                value: currency(totalPayables)
                            )

                            Divider()
                                .frame(height: 40)

                            overviewItem(
                                title: "Net Position",
                                value: currency(netPosition)
                            )

                            Divider()
                                .frame(height: 40)

                            overviewItem(
                                title: "Overdue",
                                value: "\(overdueDebts.count)"
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
                        RoundedRectangle(cornerRadius: 16)
                    )


                    // MARK: - RECEIVABLES + PAYABLES

                    HStack(
                        alignment: .top,
                        spacing: 24
                    ) {

                        // RECEIVABLES

                        debtPanel(
                            title: "Receivables",
                            subtitle: "Money owed to you",
                            accountCount: receivableAccountCount,
                            totalTitle: "Total Receivables",
                            total: totalReceivables,
                            debts: receivables,
                            emptyMessage: "No outstanding receivables."
                        )


                        // PAYABLES

                        debtPanel(
                            title: "Payables",
                            subtitle: "Money you owe others",
                            accountCount: payableAccountCount,
                            totalTitle: "Total Payables",
                            total: totalPayables,
                            debts: payables,
                            emptyMessage: "No outstanding payables."
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            .sheet(isPresented: $showingAddDebt) {
                AddDebtView()
            }
        }
    }

    
    // MARK: - DEBT PANEL

    private func debtPanel(
        title: String,
        subtitle: String,
        accountCount: Int,
        totalTitle: String,
        total: Double,
        debts: [Debt],
        emptyMessage: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            // PANEL HEADER

            HStack(alignment: .top) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(subtitle)
                        .foregroundStyle(.secondary)

                    // ACCOUNT COUNT
                    Label(
                        "\(accountCount) \(accountCount == 1 ? "Account" : "Accounts")",
                        systemImage: "person.2.fill"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
                }

                Spacer()

                Text(currency(total))
                    .fontWeight(.bold)
            }


            Divider()


            // DEBT LIST

            if debts.isEmpty {

                Spacer()

                VStack(spacing: 12) {

                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)

                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Spacer()

            } else {

                VStack(spacing: 0) {

                    ForEach(debts) { debt in

                        NavigationLink {
                            DebtDetailView(debt: debt)
                        } label: {
                            debtRow(debt)
                        }
                        .buttonStyle(.plain)

                        if debt.id != debts.last?.id {
                            Divider()
                                .padding(.vertical, 10)
                        }
                    }
                }

                Spacer()
            }


            Divider()


            // PANEL TOTAL

            HStack {

                Text(totalTitle)
                    .fontWeight(.semibold)

                Spacer()

                Text(currency(total))
                    .fontWeight(.bold)
            }
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            minHeight: 430,
            alignment: .topLeading
        )
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }


    // MARK: - DEBT ROW

    private func debtRow(_ debt: Debt) -> some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            HStack {

                Text(debt.name)
                    .fontWeight(.semibold)

                Spacer()

                Text(currency(debt.outstandingBalance))
                    .fontWeight(.bold)
            }


            HStack {

                Text(
                    "Due \(debt.dueDate.formatted(date: .abbreviated, time: .omitted))"
                )

                Spacer()

                if debt.isOverdue {

                    Label(
                        "OVERDUE",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)


            Text(
                "Principal: \(currency(debt.originalAmount)) • Interest: \(currency(debt.interestAmount))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)


            if debt.annualInterestRate > 0 {

                Text(
                    "Rate: \(debt.annualInterestRate.formatted(.number.precision(.fractionLength(2))))% p.a. • Total: \(currency(debt.totalDebtWithInterest))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }


            Text("Paid: \(currency(debt.amountPaid))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }


    // MARK: - OVERVIEW ITEM

    private func overviewItem(
        title: String,
        value: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

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
        .padding(.horizontal, 20)
    }


    // MARK: - CURRENCY

    private func currency(
        _ amount: Double
    ) -> String {

        let formatted = amount.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(0))
        )

        return "\(ledgerCurrencyCode) \(formatted)"
    }
}
