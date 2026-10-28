import SwiftUI
import SwiftData

struct CompanyRootView: View {
    @Environment(CompanyStore.self) private var store
    var body: some View {
        Group {
            if let company = store.activeCompany, let container = store.activeContainer {
                VStack(spacing: 0) {
                    HStack {
                        Label(company.name, systemImage: "building.2.fill")
                            .font(.headline)
                        Spacer()
                        Button("Switch Company") {
                            do { try store.signOut() }
                            catch { store.errorMessage = error.localizedDescription }
                        }
                    }
                    .padding()
                    Divider()
                    MainTabView()
                }
                .modelContainer(container)
                .environment(\.ledgerCurrencyCode, company.currencyCode)
                .id(company.id)
            } else {
                CompanyWelcomeView()
            }
        }
        .alert("Unable to Complete", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

struct CompanyWelcomeView: View {
    @Environment(CompanyStore.self) private var store
    @State private var editingCompany: Company?
    @State private var deletingCompany: Company?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 54)).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to Ledger").font(.largeTitle.bold())
                    Text("Choose your company to get started.")
                        .font(.title3).foregroundStyle(.secondary)
                    Text("Your companies and financial records are saved on this device.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if !store.loaded {
                    Text("Your company list could not be loaded.")
                    Button("Try Again") { store.reload() }
                } else {
                    if store.companies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Set up your company").font(.headline)
                            Text(store.needsInitialSetup
                                 ? "Add your company name and details. Any existing Ledger records will belong to this first company."
                                 : "Add a company to start keeping its accounts.")
                                .foregroundStyle(.secondary)
                        }
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    ForEach(store.companies) { company in
                        HStack(spacing: 16) {
                            Image(systemName: "building.2").font(.title2).foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(company.name).font(.headline)
                                Text("\(company.businessType) · \(company.currencyCode)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Open") {
                                do { try store.open(company) }
                                catch { store.errorMessage = error.localizedDescription }
                            }.buttonStyle(.borderedProminent)
                            Menu {
                                Button("Edit Details") { editingCompany = company }
                                Button("Delete Company…", role: .destructive) { deletingCompany = company }
                            } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .accessibilityLabel("Manage \(company.name)")
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    Button {
                        editingCompany = store.initialCompany()
                    } label: {
                        Label("Add Company", systemImage: "plus")
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(40)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 600, minHeight: 520)
        .sheet(item: $editingCompany) { company in
            CompanyDetailsView(company: company)
        }
        .confirmationDialog("Delete \(deletingCompany?.name ?? "company")?", isPresented: Binding(
            get: { deletingCompany != nil },
            set: { if !$0 { deletingCompany = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Company and Records", role: .destructive) {
                guard let company = deletingCompany else { return }
                do { try store.delete(company) }
                catch { store.errorMessage = error.localizedDescription }
                deletingCompany = nil
            }
            Button("Cancel", role: .cancel) { deletingCompany = nil }
        } message: {
            Text("This permanently deletes this company and all of its accounts, transactions, stock, debts, assets, and liabilities. Other companies are unaffected. This cannot be undone.")
        }
    }
}

struct CompanyDetailsView: View {
    @Environment(CompanyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var company: Company
    @State private var errorMessage: String?
    private var isNew: Bool { !store.companies.contains { $0.id == company.id } }
    private let types = ["Sole Proprietorship", "Partnership", "Limited Company", "Nonprofit / NGO", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isNew ? "Add Company" : "Company Details").font(.title.bold())
            Text("Company name is required. Other details are optional.").foregroundStyle(.secondary)
            Form {
                TextField("Company name", text: $company.name)
                Picker("Business type", selection: $company.businessType) {
                    ForEach(types, id: \.self) { Text($0).tag($0) }
                }
                CurrencyPicker(code: $company.currencyCode)
                    .onChange(of: company.currencyCode) { _, code in
                        company.phoneCountryCode = LedgerCurrency.suggestedPhonePrefix(for: code) ?? ""
                    }
                TextField("Phone country code", text: $company.phoneCountryCode, prompt: Text("e.g. +33"))
                TextField("Phone number", text: $company.phone)
                Text("The country code is suggested from your currency and can be changed. EUR and other currencies may cover multiple countries.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Address", text: $company.address)
                TextField("TIN / registration number", text: $company.tin)
                Text("Changing currency updates reporting labels, not exchange rates or existing account currencies. Existing amounts are not converted.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button(isNew ? "Create Company" : "Save Changes") {
                    do {
                        _ = try store.save(company)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent)
                .disabled(company.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !LedgerCurrency.isValid(company.currencyCode))
            }
        }
        .padding(28)
        .frame(width: 600, height: 680)
    }
}
