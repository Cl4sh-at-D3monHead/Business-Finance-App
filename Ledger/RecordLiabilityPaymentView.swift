import SwiftUI
import SwiftData

struct RecordLiabilityPaymentView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Bindable var liability: Liability

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount = 0.0
    @State private var paymentDate = Date()
    @State private var notes = ""

    @State private var showingError = false
    @State private var errorMessage = ""

    private var currencyCode: String {
        liability.currencyCode.isEmpty ? ledgerCurrencyCode : liability.currencyCode
    }

    private var isValid: Bool {
        amount.isFinite &&
        amount > 0 &&
        amount <= liability.outstandingBalance &&
        paymentDate >= liability.startDate &&
        paymentDate <= Date()
    }

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Record Liability Payment")
                        .font(.title2.bold())

                    Text(liability.name)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save Payment") {
                    savePayment()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding(24)

            Divider()

            Form {
                Section("Liability Summary") {

                    LabeledContent(
                        "Original Amount",
                        value: money(liability.originalAmount)
                    )

                    LabeledContent(
                        "Previously Paid",
                        value: money(liability.totalAmountPaid)
                    )

                    LabeledContent(
                        "Outstanding Balance",
                        value: money(liability.outstandingBalance)
                    )
                }

                Section("Payment Details") {

                    TextField(
                        "Payment Amount",
                        value: $amount,
                        format: .number
                    )

                    DatePicker(
                        "Payment Date",
                        selection: $paymentDate,
                        in: liability.startDate...Date(),
                        displayedComponents: .date
                    )

                    TextField(
                        "Payment Notes",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section("Balance After Payment") {

                    LabeledContent(
                        "Remaining Liability",
                        value: money(
                            max(liability.outstandingBalance - amount, 0)
                        )
                    )
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 560, minHeight: 520)
        .alert("Unable to Save Payment", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(
            .currency(code: currencyCode).presentation(.isoCode)
                .precision(.fractionLength(0))
        )
    }

    private func savePayment() {
        guard isValid else { return }

        let payment = LiabilityPayment(
            amount: amount,
            paymentDate: paymentDate,
            notes: notes,
            liability: liability
        )

        modelContext.insert(payment)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
