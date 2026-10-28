import Foundation
import SwiftUI

enum LedgerCurrency {
    static let presets: [(code: String, name: String)] = [
        ("CAD", "Canadian Dollar"), ("GBP", "British Pound"),
        ("EUR", "Euro"), ("USD", "US Dollar"), ("TZS", "Tanzanian Shilling")
    ]

    static func normalized(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValid(_ code: String) -> Bool {
        let value = normalized(code)
        return value.utf8.count == 3 && value.utf8.allSatisfy { (65...90).contains($0) }
    }

    static func suggestedPhonePrefix(for code: String) -> String? {
        switch normalized(code) {
        case "CAD", "USD": return "+1"
        case "GBP": return "+44"
        case "TZS": return "+255"
        case "AUD": return "+61"
        case "AED": return "+971"
        default: return nil
        }
    }

    static func displayName(_ code: String) -> String {
        let code = normalized(code)
        guard let preset = presets.first(where: { $0.code == code }) else { return code }
        return "\(code) — \(preset.name)"
    }
}

private struct LedgerCurrencyKey: EnvironmentKey {
    static let defaultValue = "TZS"
}

extension EnvironmentValues {
    var ledgerCurrencyCode: String {
        get { self[LedgerCurrencyKey.self] }
        set { self[LedgerCurrencyKey.self] = newValue }
    }
}

struct CurrencyPicker: View {
    @Binding var code: String
    @State private var customEntry = false
    private var isCustom: Bool {
        customEntry || !LedgerCurrency.presets.contains { $0.code == code }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Currency", selection: Binding(
                get: { isCustom ? "custom" : code },
                set: { selection in
                    customEntry = selection == "custom"
                    code = customEntry ? "" : selection
                }
            )) {
                ForEach(LedgerCurrency.presets, id: \.code) { currency in
                    Text("\(currency.code) — \(currency.name)").tag(currency.code)
                }
                Text("Enter currency…").tag("custom")
            }
            if isCustom {
                TextField("Three-letter code (e.g. AUD)", text: Binding(
                    get: { code },
                    set: { code = LedgerCurrency.normalized($0) }
                ))
                if !code.isEmpty && !LedgerCurrency.isValid(code) {
                    Text("Use exactly three letters, for example AUD or USD.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
    }
}
