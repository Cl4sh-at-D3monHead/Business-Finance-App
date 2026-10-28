import SwiftUI
import SwiftData

struct AddDebtView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var annualInterestRate: Double = 0
    @State private var name = ""
    @State private var originalAmount: Double = 0
    @State private var amountPaid: Double = 0
    @State private var dueDate = Date()
    @State private var debtType: DebtType = .receivable
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section("Debt Type") {
                    Picker("Type", selection: $debtType) {
                        ForEach(DebtType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                    
                    if debtType == .receivable {
                        Text("Money owed TO your business.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Money your business owes to someone else.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Details") {
                    TextField(
                        debtType == .receivable
                            ? "Customer / Debtor"
                            : "Supplier / Lender",
                        text: $name
                    )
                    
                    TextField(
                        "Original Amount (\(ledgerCurrencyCode))",
                        value: $originalAmount,
                        format: .number
                    )
                    
                    TextField(
                        "Annual Interest Rate (%)",
                        value: $annualInterestRate,
                        format: .number
                    )
                    
                    TextField(
                        "Amount Already Paid (\(ledgerCurrencyCode))",
                        value: $amountPaid,
                        format: .number
                    )
                    
                    DatePicker(
                        "Due Date",
                        selection: $dueDate,
                        displayedComponents: .date
                    )
                }
                
                Section("Notes") {
                    TextField(
                        "Optional notes",
                        text: $notes,
                        axis: .vertical
                    )
                }
                
                Section {
                    Button("Save Debt") {
                        saveDebt()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespaces).isEmpty ||
                        originalAmount <= 0 ||
                        amountPaid < 0 ||
                        amountPaid > originalAmount
                    )
                }
            }
            .navigationTitle("Add Debt")
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveDebt() {
        let debt = Debt(
            name: name,
            originalAmount: originalAmount,
            amountPaid: amountPaid,
            dueDate: dueDate,
            type: debtType,
            annualInterestRate: annualInterestRate,
            notes: notes
        )
        
        modelContext.insert(debt)
        try? modelContext.save()
        
        dismiss()
    }
}
