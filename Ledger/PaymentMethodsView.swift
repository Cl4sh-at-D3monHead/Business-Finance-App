import SwiftUI

// MARK: - Payment Method Types

private struct LedgerPaymentMethod: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let description: String
}

struct PaymentMethodsView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: LedgerPaymentMethod?
    @State private var showingAddMethod = false

    private let methods: [LedgerPaymentMethod] = [
        LedgerPaymentMethod(
            id: "cash",
            name: "Cash Register",
            subtitle: "Cash payments",
            icon: "banknote",
            description: "Manage cash sales and cash register transactions."
        ),
        LedgerPaymentMethod(
            id: "pos",
            name: "POS Terminal",
            subtitle: "Card payments",
            icon: "creditcard",
            description: "Track card payments received through POS terminals."
        ),
        LedgerPaymentMethod(
            id: "mobile",
            name: "Mobile Money",
            subtitle: "M-Pesa, Mixx, Airtel Money",
            icon: "iphone",
            description: "Track payments received through mobile money."
        ),
        LedgerPaymentMethod(
            id: "bank",
            name: "Bank Transfer",
            subtitle: "Direct bank payments",
            icon: "building.columns",
            description: "Track payments received directly into bank accounts."
        )
    ]

    var body: some View {

        VStack(alignment: .leading, spacing: 22) {

            // MARK: - Header

            HStack(alignment: .center) {

                VStack(alignment: .leading, spacing: 5) {

                    Text("Payment Methods")
                        .font(.largeTitle.bold())

                    Text("Manage payment channels and track sales")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("Payment APIs aren’t connected yet. Integration is still in progress.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    showingAddMethod = true
                } label: {
                    Label("Add Method", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            // MARK: - Summary Cards

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {

                summaryCard(
                    title: "Total Methods",
                    value: "\(methods.count)",
                    icon: "wallet.pass"
                )

                summaryCard(
                    title: "Total Sales",
                    value: "\(ledgerCurrencyCode) 0",
                    icon: "chart.bar"
                )

                summaryCard(
                    title: "Transactions",
                    value: "0",
                    icon: "receipt"
                )

                summaryCard(
                    title: "Average Sale",
                    value: "\(ledgerCurrencyCode) 0",
                    icon: "calculator"
                )
            }

            // MARK: - Methods List

            Text("Your Payment Methods")
                .font(.headline)

            VStack(spacing: 0) {

                ForEach(Array(methods.enumerated()), id: \.element.id) { index, method in

                    Button {
                        selectedMethod = method
                    } label: {
                        HStack(spacing: 14) {

                            Image(systemName: method.icon)
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .frame(width: 46, height: 46)
                                .background(.quaternary.opacity(0.4))
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 12)
                                )

                            VStack(alignment: .leading, spacing: 5) {

                                Text(method.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(method.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(17)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < methods.count - 1 {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
            .background(.quaternary.opacity(0.25))
            .clipShape(
                RoundedRectangle(cornerRadius: 14)
            )

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 850, minHeight: 650)
        .sheet(item: $selectedMethod) { method in
            PaymentMethodDetailView(method: method)
        }
        .sheet(isPresented: $showingAddMethod) {
            AddPaymentMethodPlaceholderView()
        }
    }

    // MARK: - Summary Card

    private func summaryCard(
        title: String,
        value: String,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 9) {

                Image(systemName: icon)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
        .padding(18)
        .background(.quaternary.opacity(0.25))
        .clipShape(
            RoundedRectangle(cornerRadius: 14)
        )
    }
}

// MARK: - Payment Method Detail View

private struct PaymentMethodDetailView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.dismiss) private var dismiss

    let method: LedgerPaymentMethod

    var body: some View {

        VStack(alignment: .leading, spacing: 24) {

            HStack {

                VStack(alignment: .leading, spacing: 6) {

                    Text(method.name)
                        .font(.largeTitle.bold())

                    Text(method.subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Text(method.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 14
            ) {

                detailCard(
                    title: "Total Sales",
                    value: "\(ledgerCurrencyCode) 0"
                )

                detailCard(
                    title: "Transactions",
                    value: "0"
                )

                detailCard(
                    title: "Average Sale",
                    value: "\(ledgerCurrencyCode) 0"
                )

                detailCard(
                    title: "Customers",
                    value: "0"
                )
            }

            Text("Transaction History")
                .font(.headline)

            ContentUnavailableView(
                "No Transactions Yet",
                systemImage: "receipt",
                description: Text(
                    "Transactions linked to this payment method will appear here once payment method tracking is connected."
                )
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 500)
    }

    private func detailCard(
        title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.quaternary.opacity(0.25))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
}

// MARK: - Add Method Placeholder

private struct AddPaymentMethodPlaceholderView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        VStack(spacing: 18) {

            Image(systemName: "plus.circle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Add Payment Method")
                .font(.title2.bold())

            Text(
                "The payment method registration form will be added next."
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(minWidth: 450, minHeight: 300)
    }
}
