import SwiftUI
import SwiftData

struct AssetCategoryDetailView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    let category: FixedAssetCategory

    @Query private var allAssets: [FixedAsset]

    @State private var showingAddAsset = false

    private var categoryAssets: [FixedAsset] {
        allAssets
            .filter { $0.category == category }
            .sorted { $0.purchaseDate > $1.purchaseDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header

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

                // MARK: - Assets List

                if categoryAssets.isEmpty {

                    ContentUnavailableView(
                        "No Assets Yet",
                        systemImage: category.icon,
                        description: Text(
                            "Click Add Asset to register your first asset."
                        )
                    )

                } else {

                    VStack(spacing: 0) {

                        ForEach(categoryAssets) { asset in

                            NavigationLink {
                                AssetDetailView(asset: asset)
                            } label: {

                                HStack(spacing: 16) {

                                    Image(systemName: category.icon)
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(.quaternary)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 10)
                                        )

                                    VStack(alignment: .leading, spacing: 5) {

                                        Text(asset.name)
                                            .font(.headline)

                                        Text(
                                            "Purchased \(asset.purchaseDate.formatted(date: .abbreviated, time: .omitted))"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 5) {

                                        Text(
                                            "\(asset.currency) \(asset.currentCarryingValue.formatted(.number.precision(.fractionLength(0))))"
                                        )
                                        .font(.headline)

                                        Text(asset.assetStatus)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }
                    }
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                }
            }
            .padding(24)
        }
        .navigationTitle(category.rawValue)
        .sheet(isPresented: $showingAddAsset) {
            AddFixedAssetView(category: category)
                .frame(minWidth: 650, minHeight: 600)
        }
    }
}

