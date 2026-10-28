import SwiftUI
import SwiftData

struct LiabilitiesView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Query private var debts: [Debt]
    @Query private var liabilities: [Liability]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    // MARK: - Calculations

    private var accountsPayable: Double {
        debts
            .filter { $0.type == .payable }
            .reduce(0) { $0 + $1.outstandingBalance }
    }

    private var currentLiabilities: Double {
        accountsPayable
        + liabilities
            .filter { $0.currencyCode == ledgerCurrencyCode }
            .reduce(0) { $0 + $1.currentBalance }
    }

    private var nonCurrentLiabilities: Double {
        liabilities
            .filter { $0.currencyCode == ledgerCurrencyCode }
            .reduce(0) { $0 + $1.nonCurrentBalance }
    }

    private var totalLiabilities: Double {
        currentLiabilities + nonCurrentLiabilities
    }

    private func currency(_ amount: Double) -> String {
        "\(ledgerCurrencyCode) " + amount.formatted(
            .number.precision(.fractionLength(0))
        )
    }
    
    private func categoryBalance(
        _ category: LiabilityCategory
    ) -> Double {
        liabilities
            .filter {
                $0.category == category &&
                $0.currencyCode == ledgerCurrencyCode
            }
            .reduce(0) { $0 + $1.outstandingBalance }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header

                VStack(alignment: .leading, spacing: 6) {
                    Text("Liabilities")
                        .font(.largeTitle.bold())

                    Text(
                        "Manage your business current and non-current liabilities"
                    )
                    .foregroundStyle(.secondary)
                }

                // MARK: - Summary Cards

                HStack(spacing: 16) {
                    summaryCard(
                        title: "Current Liabilities",
                        value: currency(currentLiabilities),
                        icon: "calendar"
                    )

                    summaryCard(
                        title: "Non-Current Liabilities",
                        value: currency(nonCurrentLiabilities),
                        icon: "building.columns"
                    )

                    summaryCard(
                        title: "Total Recorded Liabilities",
                        value: currency(totalLiabilities),
                        icon: "chart.bar"
                    )
                }

                // MARK: - Current Liabilities

                VStack(alignment: .leading, spacing: 16) {
                    Text("Current Liabilities")
                        .font(.title2.bold())

                    LazyVGrid(columns: columns, spacing: 16) {

                        // Accounts Payable

                        NavigationLink {
                            DebtsView()
                        } label: {
                            liabilityCard(
                                title: "Accounts Payable",
                                subtitle: "Outstanding amounts owed",
                                value: currency(accountsPayable),
                                icon: "person.crop.circle.badge.clock"
                            )
                        }
                        .buttonStyle(.plain)

                        // Short-Term Loans

                        NavigationLink {
                            LiabilityCategoryDetailView(
                                category: "Short-Term Loans"
                            )
                        } label: {
                            liabilityCard(
                                title: "Short-Term Loans",
                                subtitle: "Borrowings due within 12 months",
                                value: currency(categoryBalance(.shortTermLoans)),
                                icon: "banknote"
                            )
                        }
                        .buttonStyle(.plain)

                        // Taxes Payable

                        NavigationLink {
                            LiabilityCategoryDetailView(
                                category: "Taxes Payable"
                            )
                        } label: {
                            liabilityCard(
                                title: "Taxes Payable",
                                subtitle: "Outstanding tax obligations",
                                value: currency(categoryBalance(.taxesPayable)),
                                icon: "doc.text"
                            )
                        }
                        .buttonStyle(.plain)

                        // Other Current Liabilities

                        NavigationLink {
                            LiabilityCategoryDetailView(
                                category: "Other Current Liabilities"
                            )
                        } label: {
                            liabilityCard(
                                title: "Other Current Liabilities",
                                subtitle: "Accruals, deposits and other obligations",
                                value: currency(categoryBalance(.otherCurrent)),
                                icon: "tray.full"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // MARK: - Non-Current Liabilities

                VStack(alignment: .leading, spacing: 16) {
                    Text("Non-Current Liabilities")
                        .font(.title2.bold())

                    LazyVGrid(columns: columns, spacing: 16) {

                        // Long-Term Loans

                        NavigationLink {
                            LiabilityCategoryDetailView(
                                category: "Long-Term Loans"
                            )
                        } label: {
                            liabilityCard(
                                title: "Long-Term Loans",
                                subtitle: "Borrowings due after 12 months",
                                value: currency(categoryBalance(.longTermLoans)),
                                icon: "building.columns"
                            )
                        }
                        .buttonStyle(.plain)

                        // Lease Liabilities

                        NavigationLink {
                            LiabilityCategoryDetailView(
                                category: "Lease Liabilities"
                            )
                        } label: {
                            liabilityCard(
                                title: "Lease Liabilities",
                                subtitle: "Long-term lease obligations",
                                value: currency(categoryBalance(.leaseLiabilities)),
                                icon: "building.2"
                            )
                        }
                        .buttonStyle(.plain)

                        // Other Non-Current Liabilities

                        NavigationLink {
                            LiabilityCategoryDetailView(
                                category: "Other Non-Current Liabilities"
                            )
                        } label: {
                            liabilityCard(
                                title: "Other Non-Current Liabilities",
                                subtitle: "Other long-term obligations",
                                value: currency(categoryBalance(.otherNonCurrent)),
                                icon: "doc.plaintext"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(
                    "Only outstanding payables from the Debts module are currently included in the totals. Other liability categories will be connected as records are added."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("Liabilities")
    }

    // MARK: - Summary Card

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

    // MARK: - Liability Card

    private func liabilityCard(
        title: String,
        subtitle: String,
        value: String,
        icon: String
    ) -> some View {
        HStack(spacing: 16) {

            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 50, height: 50)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.bold())
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

