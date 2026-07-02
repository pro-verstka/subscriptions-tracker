import SwiftUI
import SwiftData
import AppKit

/// Запускает при старте приложения проверку обновлений и планировщик напоминаний.
/// Планировщик стартует именно здесь, а не из вью меню: окно MenuBarExtra создаётся
/// только при первом клике по иконке, и привязанные к нему проверки не выполнялись бы
/// вовсе, пока пользователь не откроет меню.
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
