import SwiftUI

struct MainTabView: View {

    @State private var isSidebarExpanded = true
    @AppStorage("settings.appearance.theme") private var selectedTheme = "System"

    private var themeColorScheme: ColorScheme? {
        switch selectedTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    var body: some View {

        HStack(spacing: 0) {

            // MARK: - Sidebar
            SidebarView(
                isExpanded: $isSidebarExpanded
            )

            Divider()

            // MARK: - Main Application
            TabView {

                ContentView()
                    .tabItem {
                        Label(
                            "Dashboard",
                            systemImage: "house"
                        )
                    }

                DebtsView()
                    .tabItem {
                        Label(
                            "Debts",
                            systemImage: "person.2"
                        )
                    }

                StockView()
                    .tabItem {
                        Label(
                            "Stock",
                            systemImage: "shippingbox"
                        )
                    }

                CashFlowView()
                    .tabItem {
                        Label(
                            "Cash Flow",
                            systemImage: "arrow.left.arrow.right"
                        )
                    }

                ProfitLossView()
                    .tabItem {
                        Label(
                            "Profit & Loss",
                            systemImage: "chart.bar.doc.horizontal"
                        )
                    }
                AssetsLiabilitiesView()
                    .tabItem {
                        Label(
                            "Assets & Liabilities",
                            systemImage: "building.columns"
                        )
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(themeColorScheme)
    }
}
