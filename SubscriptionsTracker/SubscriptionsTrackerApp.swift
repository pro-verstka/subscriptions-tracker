import SwiftUI
import SwiftData
import AppKit

/// Starts update checks and the reminder scheduler. The scheduler must start here,
/// not in the menu view: the MenuBarExtra content view doesn't exist until the
/// icon is first clicked.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateService.shared.startPeriodicChecks()
        MainActor.assumeIsolated { NotificationScheduler.start() }
    }
}

@main
struct SubscriptionsTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Subscriptions", systemImage: "creditcard") {
            MenuContentView()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(AppModelContainer.shared)

        Window("Subscription", id: "subscriptionForm") {
            SubscriptionFormScene()
        }
        .modelContainer(AppModelContainer.shared) // the form needs a modelContext for insert/save
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("About", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
