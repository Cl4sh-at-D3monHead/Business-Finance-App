import SwiftUI

struct MakePaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedService: PaymentService?
    @State private var showingManualPayment = false

    private let sections: [PaymentSection] = [
        PaymentSection(title: "Utilities & Bills", services: [
            .init(name: "Electricity", icon: "bolt.fill", color: .yellow),
            .init(name: "Water", icon: "drop.fill", color: .cyan),
            .init(name: "Internet", icon: "wifi", color: .purple),
            .init(name: "Business TV", icon: "tv.fill", color: .green)
        ]),
        PaymentSection(title: "Government & Taxes", services: [
            .init(name: "TRA Taxes", icon: "building.columns.fill", color: .green),
            .init(name: "GePG", icon: "doc.text.fill", color: .blue),
            .init(name: "Licences", icon: "checkmark.seal.fill", color: .orange),
            .init(name: "Regulatory Fees", icon: "shield.fill", color: .purple)
        ]),
        PaymentSection(title: "Business Operations", services: [
            .init(name: "Suppliers", icon: "truck.box.fill", color: .green),
            .init(name: "Rent", icon: "building.2.fill", color: .orange),
            .init(name: "Payroll", icon: "person.2.fill", color: .blue),
            .init(name: "Subscriptions", icon: "desktopcomputer", color: .purple)
        ]),
        PaymentSection(title: "Transport & Logistics", services: [
            .init(name: "Fuel", icon: "fuelpump.fill", color: .orange),
            .init(name: "Parking", icon: "car.fill", color: .blue),
            .init(name: "Travel", icon: "airplane", color: .purple),
            .init(name: "Freight", icon: "shippingbox.fill", color: .green)
        ])
    ]

    private var filteredSections: [PaymentSection] {
        sections.compactMap { section in
            let matches = section.services.filter {
                searchText.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            return matches.isEmpty ? nil :
                PaymentSection(title: section.title, services: matches)
        }
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 20),
        count: 4
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Make Payment")
                        .font(.largeTitle.bold())

                    Text("Manage your business payments")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
            }

            Button {
                showingManualPayment = true
            } label: {
                Label("Record Manual Payment", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)

            Text("Use this when a payment service or bank API is unavailable. The entry updates expenses, cash flow, and the selected account balance.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search payment services...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(filteredSections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(section.title)
                                .font(.title3.bold())

                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(section.services) { service in
                                    Button {
                                        selectedService = service
                                    } label: {
                                        VStack(spacing: 12) {
                                            Image(systemName: service.icon)
                                                .font(.system(size: 25))
                                                .foregroundStyle(service.color)
                                                .frame(width: 76, height: 76)
                                                .background(.quaternary.opacity(0.5))
                                                .clipShape(Circle())

                                            Text(service.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 600)
        .sheet(item: $selectedService) { service in
            RecordBusinessPaymentView(
                serviceName: service.name
            )
        }
        .sheet(isPresented: $showingManualPayment) {
            RecordBusinessPaymentView(serviceName: "Other")
        }
    }
}

private struct PaymentService: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}

private struct PaymentSection: Identifiable {
    let id = UUID()
    let title: String
    let services: [PaymentService]
}

private struct PaymentServicePlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    let service: PaymentService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: service.icon)
                .font(.system(size: 44))
                .foregroundStyle(service.color)

            Text(service.name)
                .font(.title.bold())

            Text("Payment recording form coming next.")
                .foregroundStyle(.secondary)

            Button("Close") {
                dismiss()
            }
        }
        .padding(40)
        .frame(width: 480, height: 340)
    }
}
