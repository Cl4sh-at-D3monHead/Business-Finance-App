import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var recurringExpenses: [RecurringExpense]
    
    @Bindable var transaction: FinanceTransaction
    
    @State private var transactionType: TransactionType
    @State private var showingRecurringEditOptions = false
    @State private var originalTitle: String
    @State private var originalCategory: String
    @State private var showingDeleteOptions = false
    
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
    
    init(transaction: FinanceTransaction) {
        self.transaction = transaction
        _transactionType = State(initialValue: transaction.type)
        _originalTitle = State(initialValue: transaction.title)
        _originalCategory = State(initialValue: transaction.category)
    }
    
    private var categories: [String] {
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
                    
                    TextField(
                        "Description",
                        text: $transaction.title
                    )
                    
                    TextField(
                        "Amount (\(ledgerCurrencyCode))",
                        value: $transaction.amount,
                        format: .number
                    )
                    
                    DatePicker(
                        "Date",
                        selection: $transaction.date,
                        displayedComponents: .date
                    )
                }
                
                Section("Category") {
                    
                    Picker(
                        "Category",
                        selection: $transaction.category
                    ) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    
                    if transactionType == .expense {
                        Toggle(
                            "Recurring monthly expense",
                            isOn: $transaction.isRecurring
                        )
                    }
                }
                
                Section("Notes") {
                    TextField(
                        "Optional notes",
                        text: $transaction.notes,
                        axis: .vertical
                    )
                }
                
                Section {
                    Button("Save Changes") {
                        
                        if transaction.type == .expense &&
                            transaction.isRecurring {
                            
                            showingRecurringEditOptions = true
                            
                        } else {
                            saveChanges()
                        }
                    }
                }
                
                Section {
                    Button("Delete Transaction", role: .destructive) {
                        
                        if transaction.isRecurring {
                            showingDeleteOptions = true
                        } else {
                            modelContext.delete(transaction)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .confirmationDialog("Apply changes to recurring expense",
                isPresented: $showingRecurringEditOptions
            ) {
                
                Button("This Month Only") {
                    saveChanges()
                }
                
                Button("This and Future Months") {
                    saveChangesToFutureMonths()
                }
                
                Button("Stop Recurring From This Month", role: .destructive) {
                    stopRecurringFromThisMonth()
                }
                
                Button("Cancel", role: .cancel) { }
                
            } message: {
                Text("Choose how you want these changes to apply.")
            }
            .confirmationDialog(
                "Delete Recurring Expense",
                isPresented: $showingDeleteOptions
            ) {
                
                Button("Delete This Transaction Only", role: .destructive) {
                    modelContext.delete(transaction)
                    try? modelContext.save()
                    dismiss()
                }
                
                Button("Delete This & Future Recurrence", role: .destructive) {
                    deleteThisAndFutureRecurrence()
                }
                
                Button("Cancel", role: .cancel) { }
                
            } message: {
                Text("Choose whether to delete only this transaction or stop the recurring expense from this month onward.")
            }
            .onChange(of: transactionType) { _, newValue in
                
                if newValue == .revenue {
                    transaction.category = "POS Sales"
                } else {
                    transaction.category = "Other"
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    private func saveChanges() {
        transaction.type = transactionType

        if transactionType == .revenue {
            transaction.isRecurring = false
        }

        try? modelContext.save()
        dismiss()
    }

    private func saveChangesToFutureMonths() {
        
        transaction.type = transactionType
        
        guard transactionType == .expense else {
            transaction.isRecurring = false
            try? modelContext.save()
            dismiss()
            return
        }
        
        if transaction.isRecurring {
            
            if let recurring = recurringExpenses.first(where: {
                $0.title == originalTitle &&
                $0.category == originalCategory &&
                $0.isActive
            }) {
                
                recurring.title = transaction.title
                recurring.amount = transaction.amount
                recurring.category = transaction.category
                recurring.notes = transaction.notes
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
    private func stopRecurringFromThisMonth() {
        
        transaction.isRecurring = false
        
        if let recurring = recurringExpenses.first(where: {
            $0.title == originalTitle &&
            $0.category == originalCategory &&
            $0.isActive
        }) {
            recurring.endDate = transaction.date
            recurring.isActive = false
        }
        
        try? modelContext.save()
        dismiss()
    }
    private func deleteThisAndFutureRecurrence() {
        
        if let recurring = recurringExpenses.first(where: {
            $0.title == originalTitle &&
            $0.category == originalCategory &&
            $0.isActive
        }) {
            
            let calendar = Calendar.current
            
            if let previousMonth = calendar.date(
                byAdding: .month,
                value: -1,
                to: transaction.date
            ) {
                recurring.endDate = previousMonth
            }
            
            recurring.isActive = false
        }
        
        modelContext.delete(transaction)
        
        try? modelContext.save()
        dismiss()
    }
}
