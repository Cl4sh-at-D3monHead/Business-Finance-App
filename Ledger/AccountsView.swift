import SwiftUI
import SwiftData

struct AccountsView: View {
    @Query(sort: \BankAccount.dateAdded, order: .reverse)
    private var accounts: [BankAccount]

    @Query private var bankTransactions: [BankTransaction]

    @State private var searchText = ""
    @State private var showingAddAccount = false

    private var filteredAccounts: [BankAccount] {
        guard !searchText.isEmpty else { return accounts }

        return accounts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bankName.localizedCaseInsensitiveContains(searchText) ||
            $0.accountHolder.localizedCaseInsensitiveContains(searchText) ||
            $0.accountNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var currencies: [String] {
        Array(Set(accounts.map(\.currencyCode))).sorted()
    }

    private func currentBalance(for account: BankAccount) -> Double {
        BankBalanceCalculator.balance(
            for: account,
            transactions: bankTransactions,
            asOf: .now
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Accounts")
                        .font(.largeTitle.bold())

                    Text("Manage your business bank accounts")
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

            HStack(spacing: 16) {
                summaryCard(
                    title: "Total Accounts",
                    value: "\(accounts.count)",
                    icon: "building.columns"
                )

                summaryCard(
                    title: "Currencies",
                    value: "\(currencies.count)",
                    icon: "dollarsign.circle"
                )
            }

            TextField("Search accounts...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Text("All Accounts")
                .font(.title3.bold())

            if accounts.isEmpty {
                ContentUnavailableView(
                    "No Accounts Yet",
                    systemImage: "building.columns",
                    description: Text(
                        "Add your first bank account to get started."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if filteredAccounts.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAccounts, id: \.persistentModelID) { account in
                            NavigationLink {
                                AccountDetailView(account: account)
                            } label: {
                                accountRow(account)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(24)
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
    
    
    private func bankLogo(for bankName: String) -> String? {
        let bank = bankName.lowercased()

        if bank.contains("absa") { return "bank_absa" }
        if bank.contains("crdb") { return "bank_crdb" }
        if bank.contains("nmb") { return "bank_nmb" }
        if bank.contains("nbc") { return "bank_nbc" }
        if bank.contains("exim") { return "bank_exim" }
        if bank.contains("stanbic") { return "bank_stanbic" }
        if bank.contains("standard chartered") {return "bank_standardchartered"}
        if bank.contains("diamond trust") { return "bank_dtb" }
        if bank.contains("equity") { return "bank_equity" }
        if bank.contains("selcom") { return "bank_selcom" }
        if bank.contains("kcb") { return "bank_kcb" }
        if bank.contains("azania") { return "bank_azania" }
        if bank.contains("access") { return "bank_access" }
        if bank.contains("uba") || bank.contains("united bank for africa") {return "bank_uba"}
        if bank.contains("ecobank") { return "bank_ecobank" }
        if bank.contains("dcb") { return "bank_dcb" }
        if bank.contains("bank of africa") { return "bank_boa" }

        return nil}

    private func accountRow(_ account: BankAccount) -> some View {
        HStack(spacing: 16) {
            Group {
                if let logo = bankLogo(for: account.bankName) {
                    Image(logo)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "building.columns.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(account.name)
                    .font(.headline)

                Text(account.bankName)
                    .foregroundStyle(.secondary)

                Text(account.accountNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(
                    currentBalance(for: account),
                    format: .currency(
                        code: account.currencyCode
                    ).presentation(.isoCode)
                )
                .font(.headline)

                Text(account.accountType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func summaryCard(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title2.bold())
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

