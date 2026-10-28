import SwiftUI
import SwiftData

struct RevenueView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    
    @Query(sort: \FinanceTransaction.date, order: .reverse)
    private var transactions: [FinanceTransaction]
    
    private var revenues: [FinanceTransaction] {
        transactions.filter { $0.type == .revenue }
    }
    
    private var totalRevenue: Double {
        revenues.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        totalRevenue,
                        format: .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                            .precision(.fractionLength(0))
                    )
                    .font(.largeTitle)
                    .fontWeight(.bold)
                } header: {
                    Text("Total Revenue")
                }
                
                Section("Revenue Transactions") {
                    ForEach(revenues) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.title)
                                    .fontWeight(.medium)
                                
                                Text(transaction.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(
                                transaction.amount,
                                format: .currency(code: ledgerCurrencyCode).presentation(.isoCode)
                                    .precision(.fractionLength(0))
                            )
                        }
                    }
                }
            }
            .navigationTitle("Revenue")
        }
    }
}
