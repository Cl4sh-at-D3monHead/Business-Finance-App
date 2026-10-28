import SwiftUI
import SwiftData

struct LiabilityDetailView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    @Bindable var liability: Liability

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var showingRecordPayment = false

    private var currencyCode: String {
        liability.currencyCode.isEmpty ? ledgerCurrencyCode : liability.currencyCode
    }

    private func money(_ amount: Double) -> String {
        amount.formatted(
            .currency(code: currencyCode).presentation(.isoCode)
                .precision(.fractionLength(0))
        )
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var status: String {
        if liability.outstandingBalance <= 0 {
            return "Fully Paid"
        }

        if liability.dueDate < Date() {
            return "Overdue"
        }

        return "Outstanding"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: Header

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(liability.name)
                            .font(.largeTitle.bold())

                        Text(liability.category.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(status)
                        .font(.caption.bold())
                        .foregroundStyle(
                            status == "Fully Paid" ? .green :
                            status == "Overdue" ? .red : .orange
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Color.primary.opacity(0.07),
                            in: Capsule()
                        )
                }

                // MARK: Summary Cards

                HStack(spacing: 16) {
                    summaryCard(
                        "Original Amount",
                        value: money(liability.originalAmount),
                        icon: "banknote"
                    )

                    summaryCard(
                        "Amount Paid",
                        value: money(liability.totalAmountPaid),
                        icon: "checkmark.circle"
                    )

                    summaryCard(
                        "Outstanding Balance",
                        value: money(liability.outstandingBalance),
                        icon: "creditcard"
                    )
                }

                // MARK: Information

                HStack(alignment: .top, spacing: 18) {

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Liability Information")
                            .font(.title3.bold())

                        detailRow("Name", liability.name)
                        detailRow("Category", liability.category.rawValue)
                        detailRow("Creditor", liability.creditor)
                        detailRow("Currency", currencyCode)

                        detailRow(
                            "Reference Number",
                            liability.referenceNumber.isEmpty
                                ? "Not specified"
                                : liability.referenceNumber
                        )

                        detailRow(
                            "Start Date",
                            dateText(liability.startDate)
                        )

                        detailRow(
                            "Due Date",
                            dateText(liability.dueDate)
                        )
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 18)
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Financial Details")
                            .font(.title3.bold())

                        detailRow(
                            "Original Amount",
                            money(liability.originalAmount)
                        )

                        detailRow(
                            "Amount Paid",
                            money(liability.totalAmountPaid)
                        )

                        detailRow(
                            "Outstanding Balance",
                            money(liability.outstandingBalance)
                        )

                        detailRow(
                            "Interest Rate",
                            liability.interestRate.formatted(
                                .number.precision(.fractionLength(2))
                            ) + "%"
                        )

                        detailRow(
                            "Current Portion",
                            money(liability.currentBalance)
                        )

                        detailRow(
                            "Non-Current Portion",
                            money(liability.nonCurrentBalance)
                        )
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                }
                
                VStack(alignment: .leading, spacing: 16) {

                    HStack {
                        Text("Payment History")
                            .font(.title3.bold())

                        Spacer()

                        Button {
                            showingRecordPayment = true
                        } label: {
                            Label("Record Payment", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(liability.outstandingBalance <= 0)
                    }

                    if liability.payments.isEmpty {
                        Text("No individually dated payments recorded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(
                            liability.payments.sorted {
                                $0.paymentDate > $1.paymentDate
                            }
                        ) { payment in

                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(
                                        payment.paymentDate.formatted(
                                            date: .abbreviated,
                                            time: .omitted
                                        )
                                    )
                                    .fontWeight(.medium)

                                    if !payment.notes.isEmpty {
                                        Text(payment.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(money(payment.amount))
                                    .fontWeight(.semibold)
                            }

                            Divider()
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 18)
                )


                // MARK: Notes

                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.title3.bold())

                    Text(
                        liability.notes.isEmpty
                            ? "No additional notes recorded."
                            : liability.notes
                    )
                    .foregroundStyle(
                        liability.notes.isEmpty
                            ? .secondary : .primary
                    )
                    .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(
                    Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 18)
                )

                // MARK: Delete

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Liability", systemImage: "trash")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .foregroundStyle(.red)
                        .background(
                            Color.red.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .navigationTitle("Liability Details")
        .sheet(isPresented: $showingRecordPayment) {
            RecordLiabilityPaymentView(liability: liability)
        }
        .confirmationDialog(
            "Delete Liability?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Liability", role: .destructive) {
                deleteLiability()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Are you sure you want to delete \(liability.name)? This cannot be undone."
            )
        }
    }

    // MARK: Helpers

    private func summaryCard(
        _ title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
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

    private func detailRow(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Text(title)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 16)

                Text(value)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

            Divider()
        }
    }

    private func deleteLiability() {
        modelContext.delete(liability)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print(
                "Failed to delete liability: \(error.localizedDescription)"
            )
        }
    }
}

