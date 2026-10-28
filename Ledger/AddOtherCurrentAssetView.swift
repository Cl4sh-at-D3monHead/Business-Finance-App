import SwiftUI
import SwiftData

struct AddOtherCurrentAssetView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var initialCategory: OtherCurrentAssetCategory = .prepaidExpenses

    @State private var name = ""
    @State private var category: OtherCurrentAssetCategory = .prepaidExpenses
    @State private var amount = 0.0
    @State private var dateRecorded = Date()
    @State private var hasSettlementDate = false
    @State private var settlementDate = Date()
    @State private var counterparty = ""
    @State private var reference = ""
    @State private var paymentMethod = "Not Specified"
    @State private var notes = ""
    @State private var showingError = false

    private let paymentMethods = [
        "Not Specified",
        "Cash",
        "Bank Transfer",
        "Mobile Money",
        "Credit",
        "Opening Balance",
        "Other"
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && amount > 0
        && amount.isFinite
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Add Current Asset")
                        .font(.title2.bold())

                    Text("Record a prepayment, advance, deposit or receivable")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save Asset") {
                    saveAsset()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(24)

            Divider()

            Form {
                Section("Asset Details") {
                    TextField("Asset Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(OtherCurrentAssetCategory.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    TextField(
                        "Amount (\(ledgerCurrencyCode))",
                        value: $amount,
                        format: .number
                    )

                    DatePicker(
                        "Date Recorded",
                        selection: $dateRecorded,
                        displayedComponents: .date
                    )
                }

                Section("Settlement Information") {
                    TextField(
                        "Supplier / Employee / Counterparty",
                        text: $counterparty
                    )

                    TextField(
                        "Reference Number",
                        text: $reference
                    )

                    Toggle(
                        "Expected Settlement Date",
                        isOn: $hasSettlementDate
                    )

                    if hasSettlementDate {
                        DatePicker(
                            "Expected Date",
                            selection: $settlementDate,
                            displayedComponents: .date
                        )
                    }

                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                }

                Section("Additional Information") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 85)
                }

                Section {
                    Text(
                        "This records an asset in Ledger's register. It does not automatically create a cash payment, expense or bank transaction."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 650, minHeight: 620)
        .onAppear {
            category = initialCategory
        }
        .alert("Unable to Save", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    private func saveAsset() {
        let asset = OtherCurrentAsset(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            originalAmount: amount,
            dateRecorded: dateRecorded,
            expectedSettlementDate: hasSettlementDate
                ? settlementDate : nil,
            counterparty: counterparty,
            reference: reference,
            notes: notes,
            paymentMethod: paymentMethod
        )

        modelContext.insert(asset)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(asset)
            showingError = true
        }
    }
}

