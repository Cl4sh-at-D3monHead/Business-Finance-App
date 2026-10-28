import SwiftUI
import SwiftData

struct RecordDebtPaymentView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let debt: Debt
    
    @State private var amount: Double = 0
    @State private var paymentDate = Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section("Debt") {
                    LabeledContent(
                        "Name",
                        value: debt.name
                    )
                    
                    LabeledContent(
                        "Outstanding",
                        value: currency(debt.outstandingBalance)
                    )
                }
                
                Section("Payment") {
                    
                    TextField(
                        "Payment Amount",
                        value: $amount,
                        format: .number
                    )
                    
                    DatePicker(
                        "Payment Date",
                        selection: $paymentDate,
                        displayedComponents: .date
                    )
                    
                    TextField(
                        "Notes (Optional)",
                        text: $notes
                    )
                }
                
                Section {
                    Button(
                        debt.type == .receivable
                            ? "Save Payment Received"
                            : "Save Payment Made"
                    ) {
                        savePayment()
                    }
                    .disabled(
                        amount <= 0 ||
                        amount > debt.outstandingBalance
                    )
                }
            }
            .navigationTitle("Record Payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 400)
    }
    
    private func savePayment() {
        
        guard amount > 0,
              amount <= debt.outstandingBalance
        else {
            return
        }
        
        let payment = DebtPayment(
            amount: amount,
            paymentDate: paymentDate,
            notes: notes,
            debt: debt
        )
        
        modelContext.insert(payment)
        
        debt.payments.append(payment)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save debt payment: \(error)")
        }
    }
    
    private func currency(_ amount: Double) -> String {
        amount.formatted(
            .currency(code: ledgerCurrencyCode).presentation(.isoCode)
            .precision(.fractionLength(0))
        )
    }
}
