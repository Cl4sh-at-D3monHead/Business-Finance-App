import SwiftUI
import SwiftData

struct AddLiabilityView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var creditor = ""
    @State private var originalAmount = 0.0
    @State private var amountPaid = 0.0
    @State private var currentPortion = 0.0
    @State private var interestRate = 0.0
    @State private var startDate = Date()
    @State private var dueDate = Date()
    @State private var referenceNumber = ""
    @State private var notes = ""
    @State private var currencyCode = ""
    @State private var initializedCurrency = false

    @State private var showingError = false
    @State private var errorMessage = ""

    let category: LiabilityCategory

    private var outstanding: Double {
        max(originalAmount - amountPaid, 0)
    }

    private var isValid: Bool {
        LedgerCurrency.isValid(currencyCode) &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        originalAmount > 0 &&
        originalAmount.isFinite &&
        amountPaid.isFinite &&
        amountPaid >= 0 &&
        amountPaid <= originalAmount &&
        interestRate.isFinite &&
        interestRate >= 0 &&
        currentPortion.isFinite &&
        currentPortion >= 0 &&
        (category.isCurrent || currentPortion <= outstanding)
    }

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Add Liability")
                        .font(.title2.bold())

                    Text(category.rawValue)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save Liability") {
                    saveLiability()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding(24)

            Divider()

            Form {

                Section("Liability Information") {
                    TextField("Liability Name", text: $name)

                    TextField(
                        "Creditor / Lender / Authority",
                        text: $creditor
                    )

                    TextField(
                        "Reference Number",
                        text: $referenceNumber
                    )

                    CurrencyPicker(code: $currencyCode)
                }

                Section("Financial Details") {
                    TextField(
                        "Original Amount",
                        value: $originalAmount,
                        format: .number
                    )

                    TextField(
                        "Amount Already Paid",
                        value: $amountPaid,
                        format: .number
                    )

                    TextField(
                        "Interest Rate (%)",
                        value: $interestRate,
                        format: .number
                    )

                    if !category.isCurrent {
                        TextField(
                            "Portion Due Within 12 Months",
                            value: $currentPortion,
                            format: .number
                        )

                        Text(
                            "This portion will be classified as current liabilities. The remainder will be classified as non-current liabilities."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Outstanding Balance")

                        Spacer()

                        Text(
                            "\(currencyCode) " +
                            outstanding.formatted(
                                .number.precision(.fractionLength(0))
                            )
                        )
                        .fontWeight(.semibold)
                    }
                }

                Section("Dates") {
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        "Due Date",
                        selection: $dueDate,
                        displayedComponents: .date
                    )
                }

                Section("Additional Information") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 650, minHeight: 650)
        .alert("Unable to Save", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if !initializedCurrency {
                currencyCode = ledgerCurrencyCode
                initializedCurrency = true
            }
        }
    }

    private func saveLiability() {
        guard isValid else { return }

        let liability = Liability(
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            category: category,
            creditor: creditor,
            originalAmount: originalAmount,
            amountPaid: amountPaid,
            currentPortion: category.isCurrent ? 0 : currentPortion,
            interestRate: interestRate,
            startDate: startDate,
            dueDate: dueDate,
            referenceNumber: referenceNumber,
            notes: notes,
            currencyCode: currencyCode
        )

        modelContext.insert(liability)

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

