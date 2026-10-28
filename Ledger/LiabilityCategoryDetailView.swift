import SwiftUI
import SwiftData

struct LiabilityCategoryDetailView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    let category: String

    @Query private var liabilities: [Liability]

    @State private var showingAddLiability = false

    private var selectedCategory: LiabilityCategory? {
        LiabilityCategory(rawValue: category)
    }

    private var categoryLiabilities: [Liability] {
        liabilities.filter {
            $0.categoryRaw == category
        }
    }

    private var totalOutstanding: Double {
        categoryLiabilities
            .filter { $0.currencyCode == ledgerCurrencyCode }
            .reduce(0) { $0 + $1.outstandingBalance }
    }

    private func money(
        _ amount: Double,
        currency: String? = nil
    ) -> String {
        "\(currency ?? ledgerCurrencyCode) " +
        amount.formatted(
            .number.precision(.fractionLength(0))
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category)
                            .font(.largeTitle.bold())

                        Text("Manage liabilities in this category")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showingAddLiability = true
                    } label: {
                        Label("Add Liability", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCategory == nil)
                }

                // MARK: - Summary

                HStack(spacing: 16) {
                    summaryCard(
                        title: "Recorded Liabilities",
                        value: "\(categoryLiabilities.count)",
                        icon: "doc.text"
                    )

                    summaryCard(
                        title: "Outstanding (\(ledgerCurrencyCode))",
                        value: money(totalOutstanding),
                        icon: "creditcard"
                    )
                }

                // MARK: - Liability Records

                if categoryLiabilities.isEmpty {
                    ContentUnavailableView(
                        "No Liabilities Recorded",
                        systemImage: "tray",
                        description: Text(
                            "Select Add Liability to record your first liability in this category."
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(
                            categoryLiabilities,
                            id: \.persistentModelID
                        ) { liability in
                            NavigationLink {
                                LiabilityDetailView(liability: liability)
                            } label: {
                                liabilityRow(liability)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if categoryLiabilities.contains(
                    where: { $0.currencyCode != ledgerCurrencyCode }
                ) {
                    Text(
                        "Foreign-currency liabilities are displayed in their original currency and excluded from the \(ledgerCurrencyCode) summary until exchange-rate conversion is implemented."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle(category)
        .sheet(isPresented: $showingAddLiability) {
            if let selectedCategory {
                AddLiabilityView(category: selectedCategory)
            }
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func liabilityRow(
        _ liability: Liability
    ) -> some View {
        HStack(spacing: 16) {

            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 50, height: 50)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 7) {
                Text(liability.name)
                    .font(.headline)

                Text(
                    liability.creditor.isEmpty
                    ? "No creditor specified"
                    : liability.creditor
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    "Due " +
                    liability.dueDate.formatted(
                        date: .abbreviated,
                        time: .omitted
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(
                    money(
                        liability.outstandingBalance,
                        currency: liability.currencyCode
                    )
                )
                .font(.headline)

                Text("Outstanding")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

