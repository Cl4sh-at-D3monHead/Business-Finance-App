import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct StockItemDetailView: View {
    @Environment(\.ledgerCurrencyCode) private var ledgerCurrencyCode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: StockItem

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var showingPhotoError = false
    @State private var showingImageImporter = false

    private var hasSellingPrice: Bool {
        item.sellingPrice > 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: Header

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.largeTitle.bold())

                        Text(item.category.isEmpty
                             ? item.stockType
                             : item.category)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.stockStatus)
                        .font(.caption.bold())
                        .foregroundStyle(
                            item.isOutOfStock ? .red :
                            item.isLowStock ? .orange : .green
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                // MARK: Summary

                HStack(spacing: 16) {
                    summaryCard(
                        "Quantity",
                        quantity(item.quantity),
                        icon: "shippingbox"
                    )

                    summaryCard(
                        "Stock Value",
                        money(item.stockValue),
                        icon: "banknote"
                    )

                    summaryCard(
                        "Potential Sales",
                        hasSellingPrice
                            ? money(item.potentialSalesValue)
                            : "Not set",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }

                // MARK: Photo and Details

                HStack(alignment: .top, spacing: 18) {

                    photoPanel
                        .frame(width: 300, height: 300)
                        .offset(y: -5)

                    panel("Product Information") {
                        detailRow("Product", item.name)
                        Divider()
                        detailRow("Category", item.category)
                        Divider()
                        detailRow("Stock Type", item.stockType)
                        Divider()
                        detailRow("Unit", item.unitOfMeasure)
                        Divider()
                        detailRow(
                            "Date Added",
                            item.dateAdded.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
                    }
                }

                // MARK: Stock Quantities

                panel("Stock Control") {
                    detailRow(
                        "Total Quantity",
                        quantity(item.quantity)
                    )
                    Divider()

                    detailRow(
                        "Available Quantity",
                        quantity(item.availableStock)
                    )
                    Divider()

                    detailRow(
                        "Buffer Stock",
                        quantity(item.bufferStock)
                    )
                    Divider()

                    detailRow(
                        "Reorder Level",
                        quantity(item.reorderLevel)
                    )
                    Divider()

                    detailRow("Status", item.stockStatus)
                }

                // MARK: Financial Details

                panel("Financial Details") {
                    detailRow(
                        "Unit Cost",
                        money(item.unitCost)
                    )
                    Divider()

                    detailRow(
                        "Selling Price",
                        hasSellingPrice
                            ? money(item.sellingPrice)
                            : "Not set"
                    )
                    Divider()

                    detailRow(
                        "Total Stock Value",
                        money(item.stockValue)
                    )
                    Divider()

                    detailRow(
                        "Potential Sales",
                        hasSellingPrice
                            ? money(item.potentialSalesValue)
                            : "Not available"
                    )
                    Divider()

                    detailRow(
                        "Potential Gross Profit",
                        hasSellingPrice
                            ? money(item.potentialGrossProfit)
                            : "Not available"
                    )
                    Divider()

                    detailRow(
                        "Potential Profit Margin",
                        hasSellingPrice
                            ? String(
                                format: "%.1f%%",
                                item.potentialProfitMargin
                            )
                            : "Not available"
                    )
                }

                // MARK: Delete

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label(
                        "Delete Stock Item",
                        systemImage: "trash"
                    )
                    .fontWeight(.semibold)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(Color.red.opacity(0.10))
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
                )
            }
            .padding(24)
        }
        .navigationTitle(item.name)
        .confirmationDialog(
            "Delete \(item.name)?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button(
                "Delete Stock Item",
                role: .destructive
            ) {
                modelContext.delete(item)

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
            Text(
                "This permanently removes the stock item from your inventory."
            )
        }
        .alert(
            "Unable to Delete",
            isPresented: $showingDeleteError
        ) {
            Button("OK", role: .cancel) {}
        }
        .alert(
            "Unable to Save Photo",
            isPresented: $showingPhotoError
        ) {
            Button("OK", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $showingImageImporter,
            allowedContentTypes: [.png, .jpeg, .heic, .webP],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let imageData = try Data(contentsOf: url)

                    guard NSImage(data: imageData) != nil else {
                        showingPhotoError = true
                        return
                    }

                    let previousData = item.photoData
                    item.photoData = imageData

                    do {
                        try modelContext.save()
                    } catch {
                        item.photoData = previousData
                        showingPhotoError = true
                    }

                } catch {
                    showingPhotoError = true
                }
                
            case .failure(let error):
                print("Image selection failed: \(error)")
            }
        }
    }

    // MARK: - Photo

    private var photoPanel: some View {
        Group {
            if let data = item.photoData,
               let image = NSImage(data: data) {

                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 288, height: 288)
                    .clipped()
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                    .contextMenu {
                        Button {
                            showingImageImporter = true
                        } label: {
                            Label("Change Photo", systemImage: "photo")
                        }

                        Button(role: .destructive) {
                            removeStockPhoto()
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    }

            } else {

                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                    .frame(width: 300, height: 300)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))

                            Text("Add Product Photo")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button {
                            showingImageImporter = true
                        } label: {
                            Label("Upload Photo", systemImage: "folder")
                        }
                    }
            }
        }
    }

    private func removeStockPhoto() {
        let previousData = item.photoData

        item.photoData = nil

        do {
            try modelContext.save()
        } catch {
            item.photoData = previousData
            showingPhotoError = true
        }
    }
    
    
    // MARK: Summary Card

    private func summaryCard(
        _ title: String,
        _ value: String,
        icon: String
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
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(20)
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }

    // MARK: Panel

    private func panel<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            Divider()

            content()
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(20)
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }

    private func detailRow(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value.isEmpty ? "—" : value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func money(_ amount: Double) -> String {
        let formattedAmount = amount.formatted(
            .number.precision(.fractionLength(0))
        )

        return "\(ledgerCurrencyCode) \(formattedAmount)"
    }
    
    private func quantity(_ amount: Double) -> String {
        amount.formatted(
            .number.precision(.fractionLength(0...2))
        )
    }
}
