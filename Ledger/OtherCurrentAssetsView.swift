import SwiftUI
import SwiftData

struct OtherCurrentAssetsView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Query(sort: \OtherCurrentAsset.dateRecorded, order: .reverse)
    private var assets: [OtherCurrentAsset]

    @State private var showingAddAsset = false
    @State private var selectedCategory: OtherCurrentAssetCategory?


    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var activeAssets: [OtherCurrentAsset] {
        assets.filter { !$0.isClosed }
    }

    private var totalValue: Double {
        activeAssets.reduce(0) { $0 + $1.remainingAmount }
    }

    private var recoverableSoon: Double {
        let today = Date()
        let next30Days = Calendar.current.date(
            byAdding: .day, value: 30, to: today
        ) ?? today

        return activeAssets
            .filter {
                guard let date = $0.expectedSettlementDate else {
                    return false
                }
                return date <= next30Days
            }
            .reduce(0) { $0 + $1.remainingAmount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Other Current Assets")
                            .font(.largeTitle.bold())

                        Text("Manage prepayments, advances, deposits and other short-term assets")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        selectedCategory = nil
                        showingAddAsset = true
                    } label: {
                        Label("Add Asset", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    summaryCard(
                        "Total Assets",
                        "\(activeAssets.count)",
                        "square.stack"
                    )

                    summaryCard(
                        "Total Value",
                        currency(totalValue),
                        "wallet.bifold"
                    )

                    summaryCard(
                        "Due Within 30 Days",
                        currency(recoverableSoon),
                        "calendar.badge.clock"
                    )
                }

                Text("Asset Categories")
                    .font(.title2.bold())

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(OtherCurrentAssetCategory.allCases) { category in
                        NavigationLink {
                            OtherCurrentAssetCategoryView(category: category)
                        } label: {
                            categoryCard(category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Other Current Assets")
        .sheet(isPresented: $showingAddAsset) {
            AddOtherCurrentAssetView(
                initialCategory: selectedCategory ?? .otherCurrentAssets
            )
        }
    }

    private func summaryCard(
        _ title: String,
        _ value: String,
        _ icon: String
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

    private func categoryCard(
        _ category: OtherCurrentAssetCategory
    ) -> some View {
        let categoryAssets = activeAssets.filter {
            $0.category == category
        }

        let value = categoryAssets.reduce(0) {
            $0 + $1.remainingAmount
        }

        return HStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.title2)
                .frame(width: 46, height: 46)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 7) {
                Text(category.rawValue)
                    .font(.headline)

                Text("\(categoryAssets.count) assets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(currency(value))
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

    private func currency(_ amount: Double) -> String {
        "\(ledgerCurrencyCode) \(amount.formatted(.number.precision(.fractionLength(0))))"
    }
}

// MARK: - Category Page

struct OtherCurrentAssetCategoryView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    let category: OtherCurrentAssetCategory

    @Query private var assets: [OtherCurrentAsset]
    @State private var showingAddAsset = false

    private var categoryAssets: [OtherCurrentAsset] {
        assets.filter {
            $0.category == category && !$0.isClosed
        }
    }

    private var totalValue: Double {
        categoryAssets.reduce(0) { $0 + $1.remainingAmount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.rawValue)
                            .font(.largeTitle.bold())

                        Text("Manage assets in this category")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showingAddAsset = true
                    } label: {
                        Label("Add Asset", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    metricCard("Active Assets", "\(categoryAssets.count)")
                    metricCard("Remaining Value", currency(totalValue))
                }

                Text("Assets")
                    .font(.title2.bold())

                if categoryAssets.isEmpty {
                    ContentUnavailableView(
                        "No Assets",
                        systemImage: category.icon,
                        description: Text("Add your first asset in this category.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(30)
                } else {
                    ForEach(categoryAssets) { asset in
                        NavigationLink {
                            OtherCurrentAssetDetailView(asset: asset)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: category.icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(.quaternary)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 12)
                                    )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(asset.name)
                                        .font(.headline)

                                    Text(asset.counterparty.isEmpty
                                         ? "No counterparty"
                                         : asset.counterparty)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(currency(asset.remainingAmount))
                                    .font(.headline)

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(20)
                            .background(.thinMaterial)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 16)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(category.rawValue)
        .sheet(isPresented: $showingAddAsset) {
            AddOtherCurrentAssetView(initialCategory: category)
        }
    }

    private func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func currency(_ amount: Double) -> String {
        "\(ledgerCurrencyCode) \(amount.formatted(.number.precision(.fractionLength(0))))"
    }
}

// MARK: - Asset Details

struct OtherCurrentAssetDetailView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    
    @Environment(\.modelContext) private var modelContext
    @Bindable var asset: OtherCurrentAsset

    @State private var showingUpdate = false
    @State private var newBalance = 0.0
    @State private var showingError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(asset.name)
                            .font(.largeTitle.bold())

                        Text(asset.category.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Update Balance") {
                        newBalance = asset.remainingAmount
                        showingUpdate = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    detailCard(
                        "Original Amount",
                        currency(asset.originalAmount)
                    )

                    detailCard(
                        "Remaining Balance",
                        currency(asset.remainingAmount)
                    )

                    detailCard(
                        "Utilized / Recovered",
                        currency(asset.amountUtilized)
                    )
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text("Asset Information")
                        .font(.headline)

                    Divider()

                    detailRow("Category", asset.category.rawValue)
                    detailRow("Counterparty", asset.counterparty)
                    detailRow("Reference", asset.reference)

                    detailRow(
                        "Date Recorded",
                        asset.dateRecorded.formatted(date: .abbreviated, time: .omitted)
                    )

                    if let date = asset.expectedSettlementDate {
                        detailRow(
                            "Expected Settlement",
                            date.formatted(date: .abbreviated, time: .omitted)
                        )
                    }

                    detailRow("Payment Method", asset.paymentMethod)
                    detailRow("Status", asset.isClosed ? "Closed" : "Active")

                    if !asset.notes.isEmpty {
                        Divider()

                        Text("Notes")
                            .font(.headline)

                        Text(asset.notes)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Asset", systemImage: "trash")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(12)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .navigationTitle("Asset Details")
        .sheet(isPresented: $showingUpdate) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Update Remaining Balance")
                    .font(.title2.bold())

                Text(asset.name)
                    .foregroundStyle(.secondary)

                TextField(
                    "Remaining Balance",
                    value: $newBalance,
                    format: .number
                )

                Text("This updates the asset register only. It does not create an expense, receipt or payment transaction.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Cancel") {
                        showingUpdate = false
                    }

                    Spacer()

                    Button("Save") {
                        let previousBalance = asset.remainingAmount
                        let previousClosed = asset.isClosed

                        asset.remainingAmount = newBalance
                        asset.isClosed = newBalance == 0

                        do {
                            try modelContext.save()
                            showingUpdate = false
                        } catch {
                            asset.remainingAmount = previousBalance
                            asset.isClosed = previousClosed
                            showingError = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !newBalance.isFinite ||
                        newBalance < 0 ||
                        newBalance > asset.originalAmount
                    )
                }
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Asset", systemImage: "trash")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(Color.red.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(28)
            .frame(width: 450)
        }
        .alert("Unable to Save", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The balance could not be updated.")
        }
        .confirmationDialog(
            "Delete \(asset.name)?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete Asset", role: .destructive) {
                modelContext.delete(asset)

                do {
                    try modelContext.save()
                    dismiss()
                } catch {
                    modelContext.rollback()
                    showingDeleteError = true
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the asset from your register.")
        }
        .alert("Unable to Delete", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The asset could not be deleted.")
        }
    }

    private func detailCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value.isEmpty ? "—" : value)
                .fontWeight(.medium)
        }
    }

    private func currency(_ amount: Double) -> String {
        "\(ledgerCurrencyCode) \(amount.formatted(.number.precision(.fractionLength(0))))"
    }
}

