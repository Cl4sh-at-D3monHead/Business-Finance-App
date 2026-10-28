import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BankAccount.name) private var accounts: [BankAccount]
    
    @State private var title = ""
    @State private var amount: Double = 0
    @State private var date = Date()
    
    @State private var transactionType: TransactionType = .expense
    @State private var expenseType: ExpenseType = .operatingExpense
    @State private var incomeType: IncomeType = .operatingRevenue
    @State private var category = "Other"
    @State private var isRecurring = false
    @State private var notes = ""
    @State private var selectedAccountID: UUID?
    @State private var saveError: String?
    
    let expenseCategories = [
        "Rent",
        "Salaries",
        "Utilities",
        "Transport",
        "Inventory",
        "Marketing",
        "Internet",
        "Taxes",
        "Bank Charges",
        "Maintenance",
        "Other"
    ]
    
    let revenueCategories = [
        "POS Sales",
        "Cash Sales",
        "Services",
        "Other Revenue"
    ]
    
    var categories: [String] {
        transactionType == .revenue
        ? revenueCategories
        : expenseCategories
    }
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section("Transaction") {
                    
                    Picker("Type", selection: $transactionType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                    
                    TextField("Description", text: $title)
                    
                    TextField(
                        "Amount (\(ledgerCurrencyCode))",
                        value: $amount,
                        format: .number
                    )
                    
                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: .date
                    )
                }
                
                Section("Category") {
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) {
                            Text($0)
                        }
                    }
                    
                    if transactionType == .revenue {
                        Picker("Income Type", selection: $incomeType) {
                            ForEach(IncomeType.allCases, id: \.self) { type in
                                Text(type.rawValue)
                                    .tag(type)
                            }
                        }
                    }
                    
                    if transactionType == .expense {
                        Picker("Expense Type", selection: $expenseType) {
                            ForEach(ExpenseType.allCases, id: \.self) { type in
                                Text(type.rawValue)
                                    .tag(type)
                            }
                        }
                        Toggle(
                            "Recurring monthly expense",
                            isOn: $isRecurring
                        )
                    }
                }

                Section("Payment Account (Optional)") {
                    Picker("Account", selection: $selectedAccountID) {
                        Text("Not linked to an account").tag(nil as UUID?)
                        ForEach(accounts.filter { $0.currencyCode.uppercased() == ledgerCurrencyCode }) { account in
                            Text("\(account.name) · \(account.currencyCode)")
                                .tag(Optional(account.id))
                        }
                    }
                    if !accounts.isEmpty {
                        Text(transactionType == .expense
                             ? "The expense will also be recorded as a withdrawal from this account."
                             : "The revenue will also be recorded as a deposit into this account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Notes") {
                    TextField(
                        "Optional notes",
                        text: $notes,
                        axis: .vertical
                    )
                }
                
                Section {
                    Button("Save Transaction") {
                        saveTransaction()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespaces).isEmpty ||
                        amount <= 0
                    )
                }
            }
            .navigationTitle("Add Transaction")
            
            .onChange(of: transactionType) { _, newValue in
                
                if newValue == .revenue {
                    category = "POS Sales"
                    isRecurring = false
                } else {
                    category = "Other"
                }
            }
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .alert(
                "Unable to Save Transaction",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "An unknown error occurred.")
            }
        }
    }
    
    private func saveTransaction() {
        let transaction = FinanceTransaction(
            title: title,
            amount: amount,
            date: date,
            type: transactionType,
            category: category,
            expenseType: expenseType,
            incomeType: incomeType,
            isRecurring: isRecurring,
            notes: notes,
            bankAccountID: selectedAccountID
        )
        
        modelContext.insert(transaction)

        var bankMovement: BankTransaction?
        if let accountID = selectedAccountID {
            let movement = BankTransaction(
                accountID: accountID,
                title: title,
                amount: amount,
                date: date,
                type: transactionType == .expense ? .withdrawal : .deposit,
                notes: notes
            )
            modelContext.insert(movement)
            bankMovement = movement
        }
        
        var recurringRecord: RecurringExpense?
        if transactionType == .expense && isRecurring {
            
            let recurringExpense = RecurringExpense(
                title: title,
                amount: amount,
                category: category,
                startDate: date,
                notes: notes,
                isActive: true
            )
            
            modelContext.insert(recurringExpense)
            recurringRecord = recurringExpense
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(transaction)
            if let bankMovement { modelContext.delete(bankMovement) }
            if let recurringRecord { modelContext.delete(recurringRecord) }
            saveError = error.localizedDescription
        }
    }
}
