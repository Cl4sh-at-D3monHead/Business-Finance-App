import SwiftUI
import SwiftData

struct CashBankAssetsView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    @Query(sort: \BankAccount.dateAdded, order: .reverse)
    private var accounts: [BankAccount]
    
    @Query private var bankTransactions: [BankTransaction]

    @State private var showingAddAccount = false

    private var bankAccountCount: Int {
        accounts.count
    }

    private func formattedAmount(_ amount: Double, currency: String) -> String {
        let number = amount.formatted(
            .number.precision(.fractionLength(0))
        )
        return "\(currency) \(number)"
    }
    
    private func currentBalance(
        for account: BankAccount
    ) -> Double {
        BankBalanceCalculator.balance(
            for: account,
            transactions: bankTransactions,
            asOf: .now
        )
    }

    private var totalCurrentBalanceInReportingCurrency: Double {
        accounts
            .filter { $0.currencyCode.uppercased() == ledgerCurrencyCode }
            .reduce(0) {
                $0 + currentBalance(for: $1)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cash & Bank")
                            .font(.largeTitle.bold())

                        Text("Manage your business cash and bank accounts")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showingAddAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                // MARK: - Summary

                HStack(spacing: 16) {
                    summaryCard(
                        title: "Current Balances (\(ledgerCurrencyCode))",
                        value: formattedAmount(
                            totalCurrentBalanceInReportingCurrency,
                            currency: ledgerCurrencyCode
                        ),
                        icon: "wallet.bifold"
                    )

                    summaryCard(
                        title: "Bank Accounts",
                        value: "\(bankAccountCount)",
                        icon: "building.columns"
                    )

                    summaryCard(
                        title: "Currencies",
                        value: "\(Set(accounts.map(\.currencyCode)).count)",
                        icon: "globe"
                    )
                }

                // MARK: - Accounts

                Text("Your Accounts")
                    .font(.title2.bold())

                if accounts.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)

                        Text("No Accounts Yet")
                            .font(.headline)

                        Text("Add your first bank account to start tracking your business funds.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Add Account") {
                            showingAddAccount = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(50)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(accounts, id: \.persistentModelID) { account in
                            NavigationLink {
                                AccountDetailView(account: account)
                            } label: {
                                accountCard(account)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if accounts.contains(where: { $0.currencyCode != ledgerCurrencyCode }) {
                    Text("Balances in different currencies are displayed separately. Only \(ledgerCurrencyCode) opening balances are included in the \(ledgerCurrencyCode) summary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
               
                Text(
                    "Current balances include opening balances and recorded bank movements. Transactions not yet linked to a bank account are excluded."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

            }
            .padding(24)
        }
        .navigationTitle("Cash & Bank")
        .sheet(isPresented: $showingAddAccount) {
			#if os(macOS)
			if #available(macOS 15.0, *) {
				AddAccount().presentationSizing(.fitted)
			} else {
				AddAccount()
			}
			#else
			AddAccount()
			#endif
        }
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

    // MARK: - Account Card
    
    private func bankLogoName(for bankName: String) -> String? {
        let name = bankName.lowercased()

        if name.contains("absa") { return "bank_absa" }
        if name.contains("access") { return "bank_access" }
        if name.contains("azania") { return "bank_azania" }
        if name.contains("bank of africa") { return "bank_boa" }
        if name.contains("crdb") { return "bank_crdb" }
        if name.contains("dcb") { return "bank_dcb" }
        if name.contains("diamond trust") || name.contains("dtb") { return "bank_dtb" }
        if name.contains("ecobank") { return "bank_ecobank" }
        if name.contains("equity") { return "bank_equity" }
        if name.contains("exim") { return "bank_exim" }
        if name.contains("kcb") { return "bank_kcb" }
        if name.contains("national bank of commerce") || name.contains("nbc") {
            return "bank_nbc"
        }
        if name.contains("nmb") { return "bank_nmb" }
        if name.contains("selcom") { return "bank_selcom" }
        if name.contains("stanbic") { return "bank_stanbic" }
        if name.contains("standard chartered") { return "bank_standardchartered" }
        if name.contains("united bank for africa") || name.contains("uba") {
            return "bank_uba"
        }

        return nil
    }

    
    private func accountCard(_ account: BankAccount) -> some View {
        HStack(spacing: 16) {

            Group {
                if let logoName = bankLogoName(for: account.bankName) {
                    Image(logoName)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                } else {
                    Image(systemName: "building.columns")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text(account.name)
                    .font(.headline)

                Text(account.bankName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(account.accountType)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    
                    formattedAmount(
                        currentBalance(for: account),
                        currency: account.currencyCode
                    )
                )
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
        .contentShape(Rectangle())
    }
}

