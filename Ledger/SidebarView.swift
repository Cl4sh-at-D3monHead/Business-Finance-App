import SwiftUI

struct SidebarView: View {

    @Binding var isExpanded: Bool
    @State private var reportsExpanded = false
    @State private var showingAddAccount = false
    @State private var showingAccounts = false
    @State private var showingMakePayment = false
    @State private var showingTransactionHistory = false
    @State private var showingCalendar = false
    @State private var showingPaymentMethods = false
    @State private var showingSettings = false
    @State private var selectedReport: LedgerReport?

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            // MARK: - Header

            HStack {

                if isExpanded {

                    Text("Business")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 30)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                } else {

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            Divider()
                .opacity(0.4)

            // MARK: - Accounts

            sidebarButton(
                title: "Accounts",
                icon: "building.columns",
                action: {
                    showingAccounts = true
                }
            )

            // MARK: - Payments

            // MARK: - Payments

            sidebarButton(
                title: "Make Payment",
                icon: "creditcard",
                action: {
                    showingMakePayment = true
                }
            )

            sidebarButton(
                title: "Transaction History",
                icon: "clock.arrow.circlepath",
                action: {
                    showingTransactionHistory = true
                }
            )

            sidebarButton(
                title: "Calendar",
                icon: "calendar",
                action: {
                    showingCalendar = true
                }
            )

            Divider()
                .opacity(0.4)
                .padding(.vertical, 8)

            // MARK: - Reports

            Button {
                withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
                    reportsExpanded.toggle()
                }
            } label: {

                HStack(spacing: 12) {

                    Image(systemName: "doc.text")
                        .frame(width: 22)

                    if isExpanded {

                        Text("Reports")

                        Spacer()

                        Image(
                            systemName: reportsExpanded
                            ? "chevron.down"
                            : "chevron.right"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)

            // MARK: - Report Dropdown

            if reportsExpanded && isExpanded {
                VStack(alignment: .leading, spacing: 6) {

                    reportDropdownButton("Balance Sheet") {
                        selectedReport = .balanceSheet
                    }

                    reportDropdownButton("Income Statement") {
                        selectedReport = .incomeStatement
                    }

                    reportDropdownButton("Cash Flow Statement") {
                        selectedReport = .cashFlow
                    }

                    reportDropdownButton("Profit & Loss") {
                        selectedReport = .profitLoss
                    }

                    reportDropdownButton("Trial Balance") {
                        selectedReport = .trialBalance
                    }
                }
                
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.015))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 20)

            Divider()
                .opacity(0.4)

            // MARK: - Payment Methods

            sidebarButton(
                title: "Payment Methods",
                icon: "wallet.pass",
                action: {
                    showingPaymentMethods = true
                }
            )

            sidebarButton(
                title: "Settings",
                icon: "gearshape",
                action: {
                    showingSettings = true
                }
            )
        }
        .padding(14)
        .frame(
            width: isExpanded ? 250 : 72,
            alignment: .topLeading
        )
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.08),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.10),
            radius: 16,
            x: 0,
            y: 5
        )
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingAddAccount) {
			#if os(macOS)
			if #available(macOS 15.0, *) {
				AddAccount().presentationSizing(.fitted)
			} else {
				AddAccount()
			}
			#else
			AddAccount()
			#endif
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: isExpanded
        )
        .sheet(isPresented: $showingAccounts) {
            NavigationStack {
                AccountsView()
            }
            .frame(width: 900, height: 480)
        }
        .sheet(isPresented: $showingMakePayment) {
            MakePaymentView()
                .frame(minWidth: 900, minHeight: 650)
        }
        .sheet(isPresented: $showingTransactionHistory) {
            NavigationStack {
                TransactionHistoryView()
            }
            .frame(minWidth: 900, minHeight: 650)
        }
        .sheet(isPresented: $showingCalendar) {
            NavigationStack {
                CalendarView()
            }
            .frame(minWidth: 900, minHeight: 650)
        }
        .sheet(isPresented: $showingPaymentMethods) {
            NavigationStack {
                PaymentMethodsView()
            }
            .frame(minWidth: 900, minHeight: 650)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $selectedReport) { report in
            ReportsView(report: report)
        }
    }

    // MARK: - Main Sidebar Button
    
    private func reportDropdownButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    private func sidebarButton(
        title: String,
        icon: String,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {

            if isExpanded {

                // Expanded layout
                HStack(spacing: 12) {

                    Image(systemName: icon)
                        .frame(width: 22)

                    Text(title)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

            } else {

                // Collapsed layout
                Image(systemName: icon)
                    .frame(width: 40, height: 40)
                    .frame(maxWidth: .infinity)
                    .contentShape(
                        RoundedRectangle(cornerRadius: 10)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    // MARK: - Sub Button

    private func subButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {

            HStack(spacing: 10) {

                Image(systemName: icon)

                Text(title)

                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Report Button

    private func reportButton(
        _ title: String
    ) -> some View {

        Button {
            // Report generation later
        } label: {

            HStack {

                Text(title)
                    .font(.callout)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(
                RoundedRectangle(cornerRadius: 9)
            )
        }
        .buttonStyle(.plain)
    }
}
