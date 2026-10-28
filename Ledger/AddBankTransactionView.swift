import SwiftUI
import SwiftData

struct AddBankTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var accounts: [BankAccount]

    let account: BankAccount

    init(account: BankAccount, initialType: BankTransactionType = .deposit) {
        self.account = account
        _transactionType = State(initialValue: initialType)
    }

    @State private var transactionType: BankTransactionType
    @State private var title = ""
    @State private var amount = 0.0
    @State private var date = Date()
    @State private var reference = ""
    @State private var notes = ""
    @State private var destinationID: UUID?
    @State private var errorMessage = ""
    @State private var showingError = false

    private var isTransfer: Bool {
        transactionType == .transferOut
    }

    private var eligibleDestinations: [BankAccount] {
        accounts.filter {
            $0.id != account.id &&
            $0.currencyCode == account.currencyCode
        }
    }

    private var canSave: Bool {
        amount > 0 &&
        amount.isFinite &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!isTransfer || destinationID != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Record Bank Transaction")
                        .font(.title2.bold())

                    Text(account.name)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save Transaction") {
                    saveTransaction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }

            Divider()

            Form {
                Picker("Transaction Type", selection: $transactionType) {
                    Text("Deposit").tag(BankTransactionType.deposit)
                    Text("Withdrawal").tag(BankTransactionType.withdrawal)
                    Text("Transfer").tag(BankTransactionType.transferOut)
                }

                TextField("Description", text: $title)

                TextField(
                    "Amount (\(account.currencyCode))",
                    value: $amount,
                    format: .number
                )

                DatePicker(
                    "Transaction Date",
                    selection: $date,
                    displayedComponents: .date
                )

                if isTransfer {
                    Picker("Destination Account", selection: $destinationID) {
                        Text("Select Account")
                            .tag(nil as UUID?)

                        ForEach(eligibleDestinations) { destination in
                            Text(destination.name)
                                .tag(Optional(destination.id))
                        }
                    }

                    if eligibleDestinations.isEmpty {
                        Text("Add another account in the same currency before recording a transfer.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                TextField("Reference Number", text: $reference)

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }

                Text(
                    "This records a cash or bank movement only. It does not automatically create revenue or an expense in Profit & Loss."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 570)
        .alert("Unable to Save Transaction", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveTransaction() {
        guard canSave else { return }

        let description = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        var records: [BankTransaction] = []

        if isTransfer {
            guard let destination = eligibleDestinations.first(
                where: { $0.id == destinationID }
            ) else {
                errorMessage = "Please select a valid destination account."
                showingError = true
                return
            }

            let transferID = UUID()

            let outgoing = BankTransaction(
                accountID: account.id,
                title: description,
                amount: amount,
                date: date,
                type: .transferOut,
                reference: reference,
                notes: notes,
                transferID: transferID
            )

            let incoming = BankTransaction(
                accountID: destination.id,
                title: description,
                amount: amount,
                date: date,
                type: .transferIn,
                reference: reference,
                notes: notes,
                transferID: transferID
            )

            records = [outgoing, incoming]

        } else {
            let record = BankTransaction(
                accountID: account.id,
                title: description,
                amount: amount,
                date: date,
                type: transactionType,
                reference: reference,
                notes: notes
            )

            records = [record]
        }

        for record in records {
            modelContext.insert(record)
        }

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

