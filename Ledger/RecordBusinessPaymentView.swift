import SwiftUI
import SwiftData

struct RecordBusinessPaymentView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BankAccount.name) private var accounts: [BankAccount]

    let serviceName: String
    
    @State private var saveError: String?
    @State private var fieldValues: [String: String] = [:]
    @State private var amount: Double = 0
    private var currency: String { ledgerCurrencyCode }
    @State private var paymentDate = Date()
    @State private var paymentReference = ""
    @State private var notes = ""
    @State private var selectedProvider = ""
    @State private var selectedAccountID: UUID?

    private var config: PaymentServiceConfig {
        PaymentServiceConfig.configuration(for: serviceName)
    }

    private var canContinue: Bool {
        amount > 0 &&
        amount.isFinite &&
        !selectedProvider.isEmpty &&
        config.fields.allSatisfy {
            !(fieldValues[$0.id] ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Record \(serviceName) Payment")
                        .font(.title2.bold())

                    Text("Enter the business payment details")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
            }

            Divider()

            Form {
                Section("Payment Details") {

                    Picker(
                        "Service Provider",
                        selection: $selectedProvider
                    ) {
                        Text("Select Provider")
                            .tag("")

                        ForEach(config.providers, id: \.self) { provider in
                            Text(provider)
                                .tag(provider)
                        }
                    }

                    ForEach(config.fields) { field in
                        TextField(
                            field.label,
                            text: Binding(
                                get: {
                                    fieldValues[field.id] ?? ""
                                },
                                set: {
                                    fieldValues[field.id] = $0
                                }
                            ),
                            prompt: Text(field.placeholder)
                        )
                    }
                }

                Section("Amount") {
                    LabeledContent("Currency", value: currency)

                    TextField(
                        "Amount",
                        value: $amount,
                        format: .number
                    )
                }

                Section("Payment Information") {
                    DatePicker(
                        "Payment Date",
                        selection: $paymentDate,
                        displayedComponents: .date
                    )

                    TextField(
                        "Payment Reference",
                        text: $paymentReference
                    )

                    TextField(
                        "Notes (optional)",
                        text: $notes
                    )

                    Picker("Pay from account", selection: $selectedAccountID) {
                        Text("No account selected").tag(nil as UUID?)
                        ForEach(accounts.filter { $0.currencyCode == currency }) { account in
                            Text("\(account.name) · \(account.currencyCode)")
                                .tag(Optional(account.id))
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("Record Payment") {
                    savePayment()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
                .alert(
                    "Unable to Save Payment",
                    isPresented: Binding(
                        get: { saveError != nil },
                        set: { if !$0 { saveError = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) {
                        saveError = nil
                    }
                } message: {
                    Text(saveError ?? "An unknown error occurred.")
                }
            }
        }
        .padding(24)
        .frame(minWidth: 550, minHeight: 600)
    }
    
    private var paymentCategory: String {
        switch serviceName {

        case "Electricity", "Water", "Internet", "Business TV":
            return "Utilities"

        case "TRA Taxes", "GePG", "Licences", "Regulatory Fees":
            return "Government & Taxes"

        case "Suppliers":
            return "Supplier Payments"

        case "Rent":
            return "Rent"

        case "Payroll":
            return "Salaries"

        case "Subscriptions":
            return "Subscriptions"

        case "Fuel", "Parking", "Travel", "Freight":
            return "Transport & Logistics"

        default:
            return "Other Business Expenses"
        }
    }
    
    private func savePayment() {

        let details = config.fields.compactMap { field -> String? in

            let value = (fieldValues[field.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !value.isEmpty else {
                return nil
            }

            return "\(field.label): \(value)"
        }

        let paymentNotes = (
            [
                "Payment Type: \(serviceName)",
                "Provider: \(selectedProvider)",
                "Currency: \(currency)",
                "Payment Reference: \(paymentReference)"
            ]
            + details
            + (notes.isEmpty ? [] : ["Notes: \(notes)"])
        )
        .joined(separator: "\n")

        let transaction = FinanceTransaction(
            title: "\(serviceName) - \(selectedProvider)",
            amount: amount,
            date: paymentDate,
            type: .expense,
            category: paymentCategory,
            expenseType: .operatingExpense,
            isRecurring: false,
            notes: paymentNotes,
            bankAccountID: selectedAccountID
        )

        modelContext.insert(transaction)

        var bankMovement: BankTransaction?
        if let accountID = selectedAccountID {
            let movement = BankTransaction(
                accountID: accountID,
                title: "\(serviceName) - \(selectedProvider)",
                amount: amount,
                date: paymentDate,
                type: .withdrawal,
                reference: paymentReference,
                notes: paymentNotes
            )
            modelContext.insert(movement)
            bankMovement = movement
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(transaction)
            if let bankMovement {
                modelContext.delete(bankMovement)
            }
            saveError = error.localizedDescription
        }
    }
}


