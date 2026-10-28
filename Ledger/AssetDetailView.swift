import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Charts

struct AssetDetailView: View {

    @Bindable var asset: FixedAsset
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false

    private var today: Date { Date() }

    private var accumulated: Double {
        asset.accumulatedDepreciation(asOf: today)
    }

    private var carryingValue: Double {
        asset.carryingValue(asOf: today)
    }

    private var depreciationRate: Double {
        guard asset.usefulLifeYears > 0 else { return 0 }
        return 100 / Double(asset.usefulLifeYears)
    }

    private var schedule: [AssetDepreciationPoint] {
        let calendar = Calendar.current

        return (0...max(asset.usefulLifeYears, 1)).map { year in
            let date = calendar.date(
                byAdding: .year,
                value: year,
                to: asset.availableForUseDate
            ) ?? asset.availableForUseDate

            return AssetDepreciationPoint(
                year: year,
                value: asset.carryingValue(asOf: date),
                accumulated: asset.accumulatedDepreciation(asOf: date)
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(asset.name)
                            .font(.largeTitle.bold())

                        Text(asset.category.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(asset.assetStatus)
                        .font(.caption.bold())
                        .foregroundStyle(
                            asset.isDisposed ? Color.gray : Color.green
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            asset.isDisposed
                                ? Color.gray.opacity(0.15)
                                : Color.green.opacity(0.12)
                        )
                        .clipShape(Capsule())
                }

                // MARK: - Financial Summary

                HStack(spacing: 16) {
                    metricCard(
                        "Purchase Cost",
                        asset.purchaseCost,
                        icon: "banknote"
                    )

                    metricCard(
                        "Accumulated Depreciation",
                        accumulated,
                        icon: "arrow.down.right"
                    )

                    metricCard(
                        "Current Carrying Value",
                        carryingValue,
                        icon: "chart.bar"
                    )
                }

                // MARK: - Image and Information

                HStack(alignment: .top, spacing: 18) {

                    AssetImageView(asset: asset)
                        .frame(width: 285, height: 285)
                        
                    
                    panel("Asset Information") {
                        infoRow("Category", asset.category.rawValue)

                        infoRow(
                            "Supplier",
                            asset.supplier.isEmpty
                                ? "—" : asset.supplier
                        )

                        infoRow(
                            "Reference",
                            asset.referenceNumber.isEmpty
                                ? "—" : asset.referenceNumber
                        )

                        infoRow(
                            "Purchase Date",
                            formatDate(asset.purchaseDate)
                        )

                        infoRow(
                            "Available for Use",
                            formatDate(asset.availableForUseDate)
                        )

                        infoRow("Payment Method", asset.paymentMethod)

                        infoRow(
                            "Payment Status",
                            asset.isPaid ? "Paid" : "Unpaid"
                        )
                    }

                    panel("Depreciation") {
                        infoRow(
                            "Method",
                            asset.depreciationMethod.rawValue
                        )

                        infoRow(
                            "Useful Life",
                            "\(asset.usefulLifeYears) years"
                        )

                        infoRow(
                            "Residual Value",
                            money(asset.residualValue)
                        )

                        infoRow(
                            "Annual Rate",
                            String(
                                format: "%.1f%%",
                                depreciationRate
                            )
                        )

                        infoRow(
                            "Annual Depreciation",
                            money(asset.annualDepreciation)
                        )

                        infoRow(
                            "Monthly Depreciation",
                            money(asset.monthlyDepreciation)
                        )
                    }
                }

                // MARK: - Chart

                panel("Asset Carrying Value Over Time") {

                    Text("Projected straight-line depreciation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Chart(schedule) { point in
                        LineMark(
                            x: .value("Year", point.year),
                            y: .value("Carrying Value", point.value)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("Year", point.year),
                            y: .value("Carrying Value", point.value)
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 1)) { value in
                            AxisGridLine()
                            AxisTick()

                            AxisValueLabel {
                                if let year = value.as(Int.self) {
                                    Text(
                                        year == 0
                                        ? "Purchase"
                                        : "Year \(year)"
                                    )
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisTick()

                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(
                                        amount.formatted(
                                            .number.notation(.compactName)
                                        )
                                    )
                                }
                            }
                        }
                    }
                    .frame(height: 290)
                }

                // MARK: - Depreciation Schedule

                panel("Depreciation Schedule") {

                    HStack {
                        Text("Period")

                        Spacer()

                        Text("Depreciation")
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                        Text("Carrying Value")
                            .frame(
                                width: 170,
                                alignment: .trailing
                            )
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                    Divider()

                    ForEach(schedule) { point in

                        HStack {
                            Text(
                                point.year == 0
                                ? "Purchase"
                                : "Year \(point.year)"
                            )

                            Spacer()

                            Text(
                                money(
                                    depreciationForYear(point.year)
                                )
                            )
                            .frame(
                                width: 150,
                                alignment: .trailing
                            )

                            Text(money(point.value))
                                .frame(
                                    width: 170,
                                    alignment: .trailing
                                )
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 5)

                        Divider()
                    }
                }

                // MARK: - Description

                if !asset.assetDescription.isEmpty {
                    panel("Description & Notes") {
                        Text(asset.assetDescription)
                            .foregroundStyle(.secondary)
                    }
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
            .padding(24)
        }
        .navigationTitle(asset.name)
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

    // MARK: - Depreciation Helper

    private func depreciationForYear(_ year: Int) -> Double {
        guard year > 0,
              year < schedule.count else {
            return 0
        }

        return max(
            schedule[year].accumulated
            - schedule[year - 1].accumulated,
            0
        )
    }

    // MARK: - Summary Card

    private func metricCard(
        _ title: String,
        _ amount: Double,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

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
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Panel

    private func panel<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 16) {

            Text(title)
                .font(.title3.bold())

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

    // MARK: - Information Row

    private func infoRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    // MARK: - Formatting

    private func money(_ amount: Double) -> String {
        "\(asset.currency) " +
        amount.formatted(
            .number.precision(.fractionLength(0))
        )
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(
            date: .abbreviated,
            time: .omitted
        )
    }
}

// MARK: - Chart Data

private struct AssetDepreciationPoint: Identifiable {
    let year: Int
    let value: Double
    let accumulated: Double

    var id: Int { year }
}

