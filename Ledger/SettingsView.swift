import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingResetConfirmation = false
    @State private var resetResultMessage = ""
    @State private var showingResetResult = false

    @AppStorage("settings.profile.name") private var profileName = ""
    @AppStorage("settings.profile.phone") private var profilePhone = ""

    @Environment(CompanyStore.self) private var companies
    @State private var editingCompany: Company?
    @AppStorage("settings.appearance.theme") private var selectedTheme = "System"

    private var themeColorScheme: ColorScheme? {
        switch selectedTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings")
                        .font(.largeTitle.bold())
                    Text("Manage your profile, business details, and app appearance.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Form {
                Section("Profile") {
                    settingsField("Full name", text: $profileName, placeholder: "Your name")
                    settingsField("Phone", text: $profilePhone, placeholder: companies.activeCompany?.phoneCountryCode ?? "+")
                }

                Section("Business") {
                    if let company = companies.activeCompany {
                        LabeledContent("Company", value: company.name)
                        LabeledContent("Business type", value: company.businessType)
                        LabeledContent("Phone", value: company.phone.isEmpty ? "Not provided" : (company.phone.hasPrefix("+") ? company.phone : "\(company.phoneCountryCode) \(company.phone)"))
                        LabeledContent("Address", value: company.address.isEmpty ? "Not provided" : company.address)
                        LabeledContent("TIN", value: company.tin.isEmpty ? "Not provided" : company.tin)
                        Button("Edit Company Details") { editingCompany = company }
                    }
                    LabeledContent("Reporting currency", value: LedgerCurrency.displayName(companies.activeCompany?.currencyCode ?? "TZS"))
                    Text("Use Switch Company to add, open, or delete companies.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Use system setting").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    Text("Theme changes are applied throughout the app and saved on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data & About") {
                    Label("Your finance records are stored locally by the app on this Mac.", systemImage: "lock.shield")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Button(role: .destructive) {
                            showingResetConfirmation = true
                        } label: {
                            Label("Reset This Company’s Finance Data…", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)

                        Text("Permanently deletes accounts, transactions, debts, stock, assets, and liabilities. Your profile, business details, and appearance settings stay saved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text("App version")
                        Spacer()
                        Text(appVersion.isEmpty ? "Not specified" : appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding(26)
        .frame(minWidth: 700, minHeight: 680)
        .preferredColorScheme(themeColorScheme)
        .sheet(item: $editingCompany) { CompanyDetailsView(company: $0) }
        .confirmationDialog(
            "Delete this company’s finance data?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Company Finance Data", role: .destructive) {
                resetFinanceData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all saved finance records for the current company. Your profile, business details, and theme will remain.")
        }
        .alert("Finance Data Reset", isPresented: $showingResetResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetResultMessage)
        }
    }

    private func resetFinanceData() {
        do {
            try deleteAll(RecurringExpense.self)
            try deleteAll(FinanceTransaction.self)
            try deleteAll(DebtPayment.self)
            try deleteAll(Debt.self)
            try deleteAll(StockItem.self)
            try deleteAll(BankTransaction.self)
            try deleteAll(BankAccount.self)
            try deleteAll(FixedAsset.self)
            try deleteAll(OtherCurrentAsset.self)
            try deleteAll(LiabilityPayment.self)
            try deleteAll(Liability.self)
            try modelContext.save()
            resetResultMessage = "This company’s finance records were deleted. Your profile, business details, and appearance settings were kept."
        } catch {
            modelContext.rollback()
            resetResultMessage = "The reset could not be completed: \(error.localizedDescription)"
        }
        showingResetResult = true
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type) throws {
        let records = try modelContext.fetch(FetchDescriptor<Model>())
        records.forEach { modelContext.delete($0) }
    }

    private func settingsField(
        _ title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .frame(width: 150, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 3)
    }
}
