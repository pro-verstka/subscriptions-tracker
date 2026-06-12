import SwiftUI
import SwiftData
import AppKit

/// Запускает периодическую проверку обновлений при старте приложения.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateService.shared.startPeriodicChecks()
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
        .modelContainer(AppModelContainer.shared) // форме нужен modelContext для insert/save
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
