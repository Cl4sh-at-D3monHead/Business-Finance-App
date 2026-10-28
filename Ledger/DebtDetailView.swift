import SwiftUI
import SwiftData

struct DebtDetailView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.modelContext) private var modelContext

    let debt: Debt

    @State private var showingPaymentSheet = false

    // MARK: - STATUS

    private var statusText: String {
        if debt.isFullyPaid {
            return "Settled"
        } else if debt.isOverdue {
            return "Overdue"
        } else {
            return "Outstanding"
        }
    }

    private var debtTypeText: String {
        debt.type == .receivable ? "Receivable" : "Payable"
    }

    private var paymentButtonTitle: String {
        debt.type == .receivable
            ? "Record Payment Received"
            : "Record Payment Made"
    }

    // MARK: - BODY

    var body: some View {

        ScrollView {

            VStack(spacing: 24) {

                // MARK: - HEADER

                VStack(spacing: 6) {

                    Text(debt.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(debtTypeText)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)


                // MARK: - OUTSTANDING BALANCE

                VStack(spacing: 10) {

                    Text("Outstanding Balance")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(currency(debt.outstandingBalance))
                        .font(.system(size: 38, weight: .bold))

                    HStack(spacing: 8) {

                        Image(
                            systemName: debt.isFullyPaid
                                ? "checkmark.circle.fill"
                                : debt.isOverdue
                                    ? "exclamationmark.triangle.fill"
                                    : "clock.fill"
                        )

                        Text(statusText)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(
                        debt.isFullyPaid
                            ? .green
                            : debt.isOverdue
                                ? .red
                                : .secondary
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 16)
                )


                // MARK: - SUMMARY + DETAILS

                HStack(
                    alignment: .top,
                    spacing: 24
                ) {

                    // MARK: DEBT SUMMARY

                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {

                        Text("Debt Summary")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        detailRow(
                            title: "Principal",
                            value: currency(debt.originalAmount)
                        )

                        Divider()

                        detailRow(
                            title: "Interest",
                            value: currency(debt.interestAmount)
                        )

                        Divider()

                        detailRow(
                            title: "Total Debt",
                            value: currency(debt.totalDebtWithInterest),
                            bold: true
                        )

                        Divider()

                        detailRow(
                            title: "Total Paid",
                            value: currency(debt.totalAmountPaid)
                        )

                        Divider()

                        detailRow(
                            title: "Outstanding",
                            value: currency(debt.outstandingBalance),
                            bold: true
                        )
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 310,
                        alignment: .topLeading
                    )
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )


                    // MARK: DEBT DETAILS

                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {

                        Text("Debt Details")
                            .font(.title2)
                            .fontWeight(.bold)

                        Divider()

                        detailRow(
                            title: "Type",
                            value: debtTypeText
                        )

                        Divider()

                        detailRow(
                            title: "Interest Rate",
                            value: "\(debt.annualInterestRate.formatted(.number.precision(.fractionLength(2))))% p.a."
                        )

                        Divider()

                        detailRow(
                            title: "Due Date",
                            value: debt.dueDate.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )

                        Divider()

                        HStack {

                            Text("Status")
                                .foregroundStyle(.secondary)

                            Spacer()

                            HStack(spacing: 6) {

                                Image(
                                    systemName: debt.isFullyPaid
                                        ? "checkmark.circle.fill"
                                        : debt.isOverdue
                                            ? "exclamationmark.triangle.fill"
                                            : "clock.fill"
                                )

                                Text(statusText)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(
                                debt.isFullyPaid
                                    ? .green
                                    : debt.isOverdue
                                        ? .red
                                        : .primary
                            )
                        }
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 310,
                        alignment: .topLeading
                    )
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                }


                // MARK: - PAYMENT HISTORY

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    HStack {

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text("Payment History")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(
                                debt.payments.isEmpty
                                    ? "No payments recorded"
                                    : "\(debt.payments.count) \(debt.payments.count == 1 ? "payment" : "payments") recorded"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(currency(debt.totalAmountPaid))
                            .font(.title3)
                            .fontWeight(.bold)
                    }


                    Divider()


                    if debt.payments.isEmpty {

                        VStack(spacing: 12) {

                            Image(systemName: "creditcard")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)

                            Text("No payments recorded yet.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)

                    } else {

                        VStack(spacing: 0) {

                            ForEach(
                                debt.payments.sorted {
                                    $0.paymentDate > $1.paymentDate
                                }
                            ) { payment in

                                HStack(
                                    alignment: .center,
                                    spacing: 16
                                ) {

                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)

                                    VStack(
                                        alignment: .leading,
                                        spacing: 5
                                    ) {

                                        Text(
                                            payment.paymentDate.formatted(
                                                date: .long,
                                                time: .omitted
                                            )
                                        )
                                        .fontWeight(.semibold)

                                        if !payment.notes.isEmpty {

                                            Text(payment.notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Text(currency(payment.amount))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                .padding(.vertical, 14)

                                Divider()
                            }
                        }
                    }


                    // MARK: PAYMENT BUTTON

                    HStack {

                        Spacer()

                        Button {

                            showingPaymentSheet = true

                        } label: {

                            Label(
                                paymentButtonTitle,
                                systemImage: "plus.circle.fill"
                            )
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .disabled(debt.isFullyPaid)
                    }
                    .padding(.top, 4)
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

        .navigationTitle("")
        .sheet(isPresented: $showingPaymentSheet) {
            RecordDebtPaymentView(debt: debt)
        }
    }


    // MARK: - DETAIL ROW

    private func detailRow(
        title: String,
        value: String,
        bold: Bool = false
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(bold ? .bold : .semibold)
        }
    }


    // MARK: - CURRENCY

    private func currency(_ amount: Double) -> String {

        let formatted = amount.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(0))
        )

        return "\(ledgerCurrencyCode) \(formatted)"
    }
}
