import SwiftUI
import SwiftData

struct AccountDetailView: View {

    @Bindable var account: BankAccount

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allTransactions: [BankTransaction]

    @State private var showingDeleteConfirmation = false
    @State private var showingAddTransaction = false
    @State private var initialTransactionType: BankTransactionType = .deposit
    @State private var errorMessage = ""
    @State private var showingError = false

    private var transactions: [BankTransaction] {
        allTransactions
            .filter {
                $0.accountID == account.id
                    && $0.date >= Calendar.current.startOfDay(for: account.dateAdded)
                    && $0.date <= .now
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.persistentModelID.hashValue
                        < $1.persistentModelID.hashValue
                }
                return $0.date < $1.date
            }
    }

    private var currentBalance: Double {
        BankBalanceCalculator.balance(
            for: account,
            transactions: allTransactions,
            asOf: .now
        )
    }

    private var totalMoneyIn: Double {
        transactions
            .filter {
                $0.type == .deposit || $0.type == .transferIn
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalMoneyOut: Double {
        transactions
            .filter {
                $0.type == .withdrawal || $0.type == .transferOut
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var history: [(transaction: BankTransaction, balance: Double)] {
        var runningBalance = account.openingBalance

        return transactions.map { transaction in
            runningBalance += transaction.signedAmount
            return (transaction, runningBalance)
        }
        .reversed()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header

                HStack(spacing: 16) {
                    Group {
                        if let logo = bankLogo(for: account.bankName) {
                            Image(logo)
                                .resizable()
                                .interpolation(.high)
                                .antialiased(true)
                                .scaledToFit()
                                .padding(6)
                        } else {
                            Image(systemName: "building.columns.fill")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(account.name)
                            .font(.title2.bold())

                        Text(account.bankName)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        initialTransactionType = .deposit
                        showingAddTransaction = true
                    } label: {
                        Label("Add Funds", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        initialTransactionType = .deposit
                        showingAddTransaction = true
                    } label: {
                        Label("Record Movement", systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                }

                // MARK: - Balance Summary

                HStack(spacing: 16) {
                    balanceCard(
                        "Current Balance",
                        currentBalance,
                        icon: "wallet.bifold"
                    )

                    balanceCard(
                        "Money In",
                        totalMoneyIn,
                        icon: "arrow.down.left"
                    )

                    balanceCard(
                        "Money Out",
                        totalMoneyOut,
                        icon: "arrow.up.right"
                    )
                }

                // MARK: - Account Information

                VStack(alignment: .leading, spacing: 16) {
                    Text("Account Information")
                        .font(.title3.bold())

                    detailRow("Account Name", account.name)
                    detailRow("Account Holder", account.accountHolder)
                    detailRow("Bank", account.bankName)
                    detailRow("Account Number", account.accountNumber)
                    detailRow("Account Type", account.accountType)

                    detailRow(
                        "Branch",
                        account.branch.isEmpty
                            ? "Not specified" : account.branch
                    )

                    detailRow("Currency", account.currencyCode)

                    detailRow(
                        "Opening Balance",
                        money(account.openingBalance)
                    )

                    detailRow(
                        "Date Added",
                        account.dateAdded.formatted(
                            date: .abbreviated,
                            time: .omitted
                        )
                    )
                }
                .padding(24)
                .background(.quaternary.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // MARK: - Transactions

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Account Transactions")
                            .font(.title3.bold())

                        Spacer()

                        Text("\(transactions.count) transactions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if history.isEmpty {
                        ContentUnavailableView(
                            "No Linked Transactions",
                            systemImage: "arrow.left.arrow.right",
                            description: Text(
                                "Deposits, withdrawals and transfers will appear here."
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(25)
                    } else {
                        HStack {
                            Text("Date")
                                .frame(width: 110, alignment: .leading)

                            Text("Description")

                            Spacer()

                            Text("Movement")
                                .frame(width: 150, alignment: .trailing)

                            Text("Balance")
                                .frame(width: 150, alignment: .trailing)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                        Divider()

                        ForEach(history, id: \.transaction.persistentModelID) { item in
                            HStack(spacing: 12) {
                                Text(
                                    item.transaction.date.formatted(
                                        date: .abbreviated,
                                        time: .omitted
                                    )
                                )
                                .frame(width: 110, alignment: .leading)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.transaction.title)
                                        .fontWeight(.medium)

                                    Text(
                                        item.transaction.type.rawValue
                                        + (
                                            item.transaction.reference.isEmpty
                                            ? ""
                                            : " · \(item.transaction.reference)"
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(
                                    signedMoney(
                                        item.transaction.signedAmount
                                    )
                                )
                                .foregroundStyle(
                                    item.transaction.signedAmount >= 0
                                    ? Color.green : Color.red
                                )
                                .frame(width: 150, alignment: .trailing)

                                Text(money(item.balance))
                                    .fontWeight(.semibold)
                                    .frame(width: 150, alignment: .trailing)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 7)

                            Divider()
                        }
                    }
                }
                .padding(24)
                .background(.quaternary.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // MARK: - Delete Account

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")

                        Text("Delete Account")
                            .fontWeight(.semibold)

                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .navigationTitle("Account Details")
        .sheet(isPresented: $showingAddTransaction) {
            AddBankTransactionView(
                account: account,
                initialType: initialTransactionType
            )
        }
        .confirmationDialog(
            "Delete Account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Are you sure you want to permanently delete \(account.name)? This action cannot be undone."
            )
        }
        .alert("Unable to Complete Action", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Formatting

    private func money(_ amount: Double) -> String {
        "\(account.currencyCode) " +
        amount.formatted(
            .number.precision(.fractionLength(0))
        )
    }

    private func signedMoney(_ amount: Double) -> String {
        (amount >= 0 ? "+" : "−") + money(abs(amount))
    }

    // MARK: - Summary Card

    private func balanceCard(
        _ title: String,
        _ amount: Double,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(money(amount))
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Information Row

    private func detailRow(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Text(title)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

            Divider()
        }
    }

    // MARK: - Bank Logos

    private func bankLogo(for bankName: String) -> String? {
        let bank = bankName.lowercased()

        if bank.contains("absa") { return "bank_absa" }
        if bank.contains("crdb") { return "bank_crdb" }
        if bank.contains("nmb") { return "bank_nmb" }
        if bank.contains("nbc") { return "bank_nbc" }
        if bank.contains("exim") { return "bank_exim" }
        if bank.contains("stanbic") { return "bank_stanbic" }
        if bank.contains("standard chartered") {
            return "bank_standardchartered"
        }
        if bank.contains("diamond trust") || bank.contains("dtb") {
            return "bank_dtb"
        }
        if bank.contains("equity") { return "bank_equity" }
        if bank.contains("selcom") { return "bank_selcom" }
        if bank.contains("kcb") { return "bank_kcb" }
        if bank.contains("azania") { return "bank_azania" }
        if bank.contains("access") { return "bank_access" }
        if bank.contains("uba") || bank.contains("united bank for africa") {
            return "bank_uba"
        }
        if bank.contains("ecobank") { return "bank_ecobank" }
        if bank.contains("dcb") { return "bank_dcb" }
        if bank.contains("bank of africa") { return "bank_boa" }

        return nil
    }

    // MARK: - Delete Account

    private func deleteAccount() {
        guard transactions.isEmpty else {
            errorMessage = "This account has recorded transactions. Remove or reassign those transactions before deleting the account."
            showingError = true
            return
        }

        modelContext.delete(account)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

