import SwiftUI
import SwiftData

struct AddAccount: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var accountName = ""
    @State private var accountHolder = ""
    @State private var bankName = ""
    @State private var customBankName = ""
    @State private var accountNumber = ""
    @State private var accountType = "Current"
    @State private var branch = ""
    @State private var currencyCode = ""
    @State private var initializedCurrency = false
    @State private var openingBalance = 0.0
    @State private var showingSaveError = false

    private let banks = [
        "Absa Bank Tanzania",
        "AccessBank Tanzania",
        "Amana Bank",
        "Azania Bank",
        "Bank of Africa Tanzania",
        "Bank of Baroda Tanzania",
        "Citibank Tanzania",
        "CRDB Bank",
        "DCB Commercial Bank",
        "Diamond Trust Bank Tanzania",
        "Ecobank Tanzania",
        "Equity Bank Tanzania",
        "Exim Bank Tanzania",
        "Guaranty Trust Bank Tanzania",
        "I&M Bank Tanzania",
        "KCB Bank Tanzania",
        "Mkombozi Commercial Bank",
        "Mwalimu Commercial Bank",
        "National Bank of Commerce (NBC)",
        "NCBA Bank Tanzania",
        "NMB Bank",
        "Stanbic Bank Tanzania",
        "Standard Chartered Bank Tanzania",
        "Tanzania Commercial Bank (TCB)",
        "United Bank for Africa (UBA)",
        "Other"
    ]

    private let accountTypes = [
        "Current",
        "Savings",
        "Business",
        "Fixed Deposit",
        "Other"
    ]


    private var selectedBankName: String {
        bankName == "Other" ? customBankName : bankName
    }

    private var canSave: Bool {
        LedgerCurrency.isValid(currencyCode) &&
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !accountHolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedBankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        openingBalance.isFinite &&
        openingBalance >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account name", text: $accountName)

                    TextField(
                        "Account holder / business name",
                        text: $accountHolder
                    )

                    Picker("Bank", selection: $bankName) {
                        Text("Select a bank").tag("")
                        ForEach(banks, id: \.self) { bank in
                            Text(bank).tag(bank)
                        }
                    }

                    if bankName == "Other" {
                        TextField("Enter bank name", text: $customBankName)
                    }

                    TextField("Account number", text: $accountNumber)

                    Picker("Account type", selection: $accountType) {
                        ForEach(accountTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    TextField("Branch (optional)", text: $branch)
                }

                Section("Opening Balance") {
                    CurrencyPicker(code: $currencyCode)

                    TextField(
                        "Amount",
                        value: $openingBalance,
                        format: .number
                    )
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Bank Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Account") {
                        saveAccount()
                    }
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .alert("Unable to Save", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The account could not be saved. Please try again.")
            }
        }
        .frame(
            minWidth: 620,
            idealWidth: 700,
            minHeight: 520,
            idealHeight: 620
        )
        .onAppear {
            if !initializedCurrency {
                currencyCode = ledgerCurrencyCode
                initializedCurrency = true
            }
        }
    }

    private func saveAccount() {
        guard canSave else { return }

        let account = BankAccount(
            name: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountHolder: accountHolder.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: selectedBankName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountType: accountType,
            branch: branch.trimmingCharacters(in: .whitespacesAndNewlines),
            currencyCode: currencyCode,
            openingBalance: openingBalance
        )

        modelContext.insert(account)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            showingSaveError = true
        }
    }
}

