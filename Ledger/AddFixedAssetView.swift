import SwiftUI
import SwiftData

struct AddFixedAssetView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    let category: FixedAssetCategory

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var purchaseCost = ""
    @State private var purchaseDate = Date()
    @State private var availableForUseDate = Date()
    @State private var residualValue = "0"
    @State private var usefulLifeYears = 5

    @State private var supplier = ""
    @State private var referenceNumber = ""
    @State private var assetDescription = ""

    @State private var paymentMethod = "Cash"
    @State private var currency = ""
    @State private var initializedCurrency = false

    @State private var showingError = false
    @State private var errorMessage = ""

    private var cost: Double {
        let cleaned = purchaseCost
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(cleaned) ?? 0
    }

    private var residual: Double {
        let cleaned = residualValue
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(cleaned) ?? 0
    }

    private var annualDepreciation: Double {
        guard usefulLifeYears > 0 else { return 0 }
        return max(cost - residual, 0) / Double(usefulLifeYears)
    }

    private var canSave: Bool {
        LedgerCurrency.isValid(currency) &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        cost > 0 &&
        residual >= 0 &&
        residual <= cost &&
        usefulLifeYears > 0 &&
        availableForUseDate >= purchaseDate
    }

    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Add Asset")
                            .font(.largeTitle.bold())

                        Text(category.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }

                    Button("Save Asset") {
                        saveAsset()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }

                section("Asset Information") {

                    field("Asset Name") {
                        TextField(
                            "e.g. Supermarket display shelf",
                            text: $name
                        )
                    }

                    field("Supplier") {
                        TextField(
                            "Supplier name",
                            text: $supplier
                        )
                    }

                    field("Reference Number") {
                        TextField(
                            "Invoice or asset reference",
                            text: $referenceNumber
                        )
                    }

                    field("Description") {
                        TextField(
                            "Asset description",
                            text: $assetDescription,
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                    }
                }

                section("Purchase Details") {

                    field("Purchase Cost") {
                        TextField("0", text: $purchaseCost)
                    }

                    field("Currency") {
                        CurrencyPicker(code: $currency)
                        .labelsHidden()
                    }

                    field("Purchase Date") {
                        DatePicker(
                            "Purchase Date",
                            selection: $purchaseDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }

                    field("Available for Use Date") {
                        DatePicker(
                            "Available for Use",
                            selection: $availableForUseDate,
                            in: purchaseDate...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }

                    field("Payment Method") {
                        Picker("Payment Method", selection: $paymentMethod) {
                            Text("Cash").tag("Cash")
                            Text("Bank Transfer").tag("Bank Transfer")
                            Text("Mobile Money").tag("Mobile Money")
                            Text("Credit / Pay Later").tag("Credit")
                        }
                        .labelsHidden()
                    }
                }

                section("Depreciation") {

                    field("Method") {
                        Text("Straight Line")
                            .foregroundStyle(.secondary)
                    }

                    field("Useful Life (Years)") {
                        Stepper(
                            "\(usefulLifeYears) years",
                            value: $usefulLifeYears,
                            in: 1...100
                        )
                    }

                    field("Residual Value") {
                        TextField("0", text: $residualValue)
                    }

                    Divider()

                    detailRow(
                        "Annual Depreciation",
                        money(annualDepreciation)
                    )

                    detailRow(
                        "Monthly Depreciation",
                        money(annualDepreciation / 12)
                    )
                }

                Text(
                    "Fixed asset purchases are capitalised. Depreciation is recognised over the useful life rather than expensing the entire purchase immediately."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(26)
        }
        .frame(minWidth: 650, minHeight: 650)
        .alert("Unable to Save Asset", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if !initializedCurrency {
                currency = ledgerCurrencyCode
                initializedCurrency = true
            }
        }
    }

    private func saveAsset() {

        let asset = FixedAsset(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            purchaseCost: cost,
            purchaseDate: purchaseDate,
            availableForUseDate: availableForUseDate,
            residualValue: residual,
            usefulLifeYears: usefulLifeYears,
            currency: currency,
            paymentMethod: paymentMethod,
            isPaid: paymentMethod != "Credit",
            supplier: supplier,
            referenceNumber: referenceNumber,
            assetDescription: assetDescription
        )

        modelContext.insert(asset)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(asset)
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func money(_ value: Double) -> String {
        "\(currency) " +
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 16) {

            Text(title)
                .font(.title3.bold())

            Divider()

            content()
        }
        .padding(20)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        HStack(alignment: .center) {
            Text(title)
                .frame(width: 190, alignment: .leading)

            Spacer()

            content()
                .frame(maxWidth: 300, alignment: .leading)
        }
    }

    private func detailRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}

