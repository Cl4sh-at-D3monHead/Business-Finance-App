import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Query(sort: \FinanceTransaction.date, order: .reverse)
    private var transactions: [FinanceTransaction]
    
    private var expenses: [FinanceTransaction] {
        transactions.filter { $0.type == .expense }
    }
    
    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            List {
                
                Section {
                    Text(
                        totalExpenses,
                        format: .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                            .precision(.fractionLength(0))
                    )
                    .font(.largeTitle)
                    .fontWeight(.bold)
                } header: {
                    Text("Total Expenses")
                }
                
                Section("Expenses") {
                    ForEach(expenses) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.title)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Text(expense.category)
                                    
                                    if expense.isRecurring {
                                        Label(
                                            "Recurring",
                                            systemImage: "repeat"
                                        )
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(
                                expense.amount,
                                format: .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                                    .precision(.fractionLength(0))
                            )
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
        }
    }
}
