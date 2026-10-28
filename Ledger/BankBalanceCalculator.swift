import Foundation

enum BankBalanceCalculator {

    static func balance(
        for account: BankAccount,
        transactions: [BankTransaction],
        asOf date: Date
    ) -> Double {

        let accountStart = Calendar.current.startOfDay(for: account.dateAdded)

        guard accountStart <= date else {
            return 0
        }

        let movement = transactions
            .filter {
                $0.accountID == account.id &&
                $0.date >= accountStart &&
                $0.date <= date
            }
            .reduce(0.0) {
                $0 + $1.signedAmount
            }

        return account.openingBalance + movement
    }

    static func totalBalance(
        currencyCode: String,
        accounts: [BankAccount],
        transactions: [BankTransaction],
        asOf date: Date
    ) -> Double {

        accounts
            .filter {
                $0.currencyCode.uppercased() == currencyCode.uppercased()
            }
            .reduce(0.0) { total, account in

                total + balance(
                    for: account,
                    transactions: transactions,
                    asOf: date
                )
            }
    }
}
