import Foundation
import SwiftData
import Observation

struct Company: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var businessType = "Sole Proprietorship"
    var phone = ""
    var address = ""
    var tin = ""
    var usesOriginalStore = false
    var currencyCode = "TZS"
    var phoneCountryCode = "+255"

    enum CodingKeys: String, CodingKey {
        case id, name, businessType, phone, address, tin, usesOriginalStore, currencyCode, phoneCountryCode
    }

    init(id: UUID = UUID(), name: String = "", businessType: String = "Sole Proprietorship",
         phone: String = "", address: String = "", tin: String = "", usesOriginalStore: Bool = false,
         currencyCode: String = "TZS", phoneCountryCode: String = "+255") {
        self.id = id
        self.name = name
        self.businessType = businessType
        self.phone = phone
        self.address = address
        self.tin = tin
        self.usesOriginalStore = usesOriginalStore
        self.currencyCode = currencyCode
        self.phoneCountryCode = phoneCountryCode
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        businessType = try values.decode(String.self, forKey: .businessType)
        phone = try values.decode(String.self, forKey: .phone)
        address = try values.decode(String.self, forKey: .address)
        tin = try values.decode(String.self, forKey: .tin)
        usesOriginalStore = try values.decode(Bool.self, forKey: .usesOriginalStore)
        currencyCode = try values.decodeIfPresent(String.self, forKey: .currencyCode) ?? "TZS"
        phoneCountryCode = try values.decodeIfPresent(String.self, forKey: .phoneCountryCode)
            ?? LedgerCurrency.suggestedPhonePrefix(for: currencyCode) ?? ""
    }
}

@MainActor @Observable
final class CompanyStore {
    private struct Registry: Codable {
        var companies: [Company] = []
        // Never reuse the original database after its company has been deleted.
        var originalStoreClaimed = false
    }

    private var registry = Registry()
    private let directory: URL
    private let originalStoreURL: URL?
    private var containers: [UUID: ModelContainer] = [:]
    private(set) var loaded = false
    private(set) var activeCompany: Company?
    private(set) var activeContainer: ModelContainer?
    var errorMessage: String?
    var companies: [Company] { registry.companies }
    var needsInitialSetup: Bool { !registry.originalStoreClaimed }

    init(directory: URL? = nil, originalStoreURL: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appending(path: "LedgerCompanies")
        self.originalStoreURL = originalStoreURL
        reload()
    }

    func reload() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: "companies.json")
            registry = FileManager.default.fileExists(atPath: url.path)
                ? try JSONDecoder().decode(Registry.self, from: Data(contentsOf: url)) : Registry()
            loaded = true
            errorMessage = nil
        } catch {
            loaded = false
            errorMessage = "Could not load companies: \(error.localizedDescription)"
        }
    }

    func initialCompany() -> Company {
        guard needsInitialSetup else { return Company() }
        let defaults = UserDefaults.standard
        var company = Company()
        company.name = defaults.string(forKey: "settings.business.name") ?? ""
        company.businessType = defaults.string(forKey: "settings.business.type") ?? "Sole Proprietorship"
        company.phone = defaults.string(forKey: "settings.business.phone") ?? ""
        company.address = defaults.string(forKey: "settings.business.address") ?? ""
        company.tin = defaults.string(forKey: "settings.business.tin") ?? ""
        return company
    }

    @discardableResult
    func save(_ draft: Company) throws -> Company {
        guard loaded else { throw CompanyError.unavailable }
        var company = draft
        company.name = company.name.trimmingCharacters(in: .whitespacesAndNewlines)
        company.currencyCode = LedgerCurrency.normalized(company.currencyCode)
        guard LedgerCurrency.isValid(company.currencyCode) else { throw CompanyError.invalidCurrency }
        guard !company.name.isEmpty else { throw CompanyError.emptyName }
        guard !companies.contains(where: { $0.id != company.id && $0.name.compare(company.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else {
            throw CompanyError.duplicateName
        }
        var next = registry
        if let index = next.companies.firstIndex(where: { $0.id == company.id }) {
            company.usesOriginalStore = next.companies[index].usesOriginalStore
            next.companies[index] = company
        } else {
            company.usesOriginalStore = !next.originalStoreClaimed
            next.originalStoreClaimed = true
            // Check that the database opens before committing the company profile.
            _ = try container(for: company)
            next.companies.append(company)
        }
        try persist(next)
        if activeCompany?.id == company.id { activeCompany = company }
        return company
    }

    func open(_ company: Company) throws {
        guard let saved = companies.first(where: { $0.id == company.id }) else { throw CompanyError.unavailable }
        let database = try container(for: saved)
        try activeContainer?.mainContext.save()
        activeContainer = database
        activeCompany = saved
    }

    func signOut() throws {
        try activeContainer?.mainContext.save()
        activeCompany = nil
        activeContainer = nil
    }

    func delete(_ company: Company) throws {
        guard companies.contains(where: { $0.id == company.id }) else { throw CompanyError.unavailable }
        guard activeCompany?.id != company.id else { throw CompanyError.closeFirst }
        let context = try container(for: company).mainContext
        do {
            try removeAll(FinanceTransaction.self, from: context)
            try removeAll(DebtPayment.self, from: context)
            try removeAll(Debt.self, from: context)
            try removeAll(StockItem.self, from: context)
            try removeAll(BankTransaction.self, from: context)
            try removeAll(BankAccount.self, from: context)
            try removeAll(FixedAsset.self, from: context)
            try removeAll(OtherCurrentAsset.self, from: context)
            try removeAll(LiabilityPayment.self, from: context)
            try removeAll(Liability.self, from: context)
            try removeAll(RecurringExpense.self, from: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        var next = registry
        next.companies.removeAll { $0.id == company.id }
        try persist(next)
        containers[company.id] = nil
    }

    private func removeAll<T: PersistentModel>(_ type: T.Type, from context: ModelContext) throws {
        try context.fetch(FetchDescriptor<T>()).forEach { context.delete($0) }
    }

    private func persist(_ next: Registry) throws {
        try JSONEncoder().encode(next).write(to: directory.appending(path: "companies.json"), options: .atomic)
        registry = next
    }

    private func container(for company: Company) throws -> ModelContainer {
        if let cached = containers[company.id] { return cached }
        let schema = Schema([
            FinanceTransaction.self, Debt.self, DebtPayment.self, StockItem.self,
            BankAccount.self, FixedAsset.self, OtherCurrentAsset.self,
            BankTransaction.self, Liability.self, LiabilityPayment.self, RecurringExpense.self
        ])
        let configuration: ModelConfiguration
        if company.usesOriginalStore {
            // Keep SwiftData's original default URL so existing records stay in place.
            if let originalStoreURL {
                configuration = ModelConfiguration(schema: schema, url: originalStoreURL, cloudKitDatabase: .none)
            } else {
                configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            }
        } else {
            configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "\(company.id.uuidString).store"), cloudKitDatabase: .none)
        }
        let result = try ModelContainer(for: schema, configurations: [configuration])
        containers[company.id] = result
        return result
    }
}

private enum CompanyError: LocalizedError {
    case emptyName, duplicateName, unavailable, closeFirst, invalidCurrency
    var errorDescription: String? {
        switch self {
        case .invalidCurrency: return "Enter a three-letter currency code, for example CAD, AUD, or USD."
        case .emptyName: return "Enter a company name."
        case .duplicateName: return "A company with this name already exists. Choose a different name."
        case .unavailable: return "This company is unavailable. Return to the company screen and try again."
        case .closeFirst: return "Close this company before deleting it."
        }
    }
}
