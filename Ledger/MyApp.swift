import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct MyApp: App {

#if os(macOS)
    @NSApplicationDelegateAdaptor(LedgerAppDelegate.self) private var appDelegate
#endif

    @State private var companies = CompanyStore()

    var body: some Scene {
        WindowGroup {
            CompanyRootView()
                .environment(companies)
        }

    }
}

#if os(macOS)
private final class LedgerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }
}
#endif
