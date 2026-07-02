import Foundation
import SwiftData
import UserNotifications

/// Delivers renewal reminders.
///
/// Never schedules future (pending) notification requests: on macOS 26 usernoted
/// keys notification state by the binary's code-signing identity (for ad-hoc
/// signing, the per-build cdhash), so requests armed by a previous build survive
/// self-updates and dev-build runs as zombies — invisible to the new binary,
/// undeletable, unreplaceable by identifier, yet still delivered by the system.
/// Instead, a minute timer in this always-running agent posts due reminders
/// immediately, deduplicated once per renewal cycle via the persisted
/// `lastNotifiedRenewal` marker.
@MainActor
enum NotificationScheduler {
    private static var timer: Timer?

    /// Called once at launch: drains pending requests armed by older app versions
    /// (only this binary's own are visible) and starts the minute check.
    static func start() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard timer == nil else { return }
        let t = Timer(timeInterval: 60, repeats: true) { _ in
            Task { @MainActor in await checkNow() }
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Task {
            if AppSettings.shared.notificationsEnabled {
                await requestAuthorization()
            }
            await checkNow()
        }
    }

    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Runs on every timer tick and explicitly after any data mutation
    /// (form save, delete, pause, import, settings toggle) for instant reaction.
    static func checkNow() async {
        let context = AppModelContainer.shared.mainContext
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        await check(subscriptions)
    }

    private static func check(_ subscriptions: [Subscription]) async {
        let center = UNUserNotificationCenter.current()

        guard AppSettings.shared.notificationsEnabled else {
            center.removeAllDeliveredNotifications()
            return
        }

        // Backfill identity for records created before `notificationID` existed.
        var didMutate = false
        for subscription in subscriptions where subscription.notificationID == nil {
            subscription.notificationID = UUID().uuidString
            didMutate = true
        }
        if didMutate { try? AppModelContainer.shared.mainContext.save() }

        let calendar = Calendar.current
        let active = subscriptions.filter { !$0.isPaused }

        // Remove delivered notifications of deleted/paused subscriptions and stale
        // ids from old versions. Only notifications delivered by this binary's
        // source are visible here; foreign ones can't be touched.
        let validIDs = Set(active.compactMap { $0.notificationID.map { "sub-\($0)" } })
        let delivered = await center.deliveredNotifications()
        let stale = Set(delivered.map(\.request.identifier)).filter { !validIDs.contains($0) }
        if !stale.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: Array(stale))
        }

        for subscription in active {
            guard let notificationID = subscription.notificationID else { continue }
            let nextRenewal = subscription.nextRenewal
            guard let reminderDate = calendar.date(
                byAdding: .day,
                value: -subscription.notifyDaysBefore,
                to: nextRenewal
            ) else { continue }

            guard reminderDate <= .now, nextRenewal > .now else { continue }

            // Exactly once per renewal cycle. The marker is set before delivery,
            // synchronously between suspension points, closing the race of two
            // concurrent checks. Next cycle `nextRenewal` moves forward, stops
            // matching the marker, and the reminder re-arms itself.
            if subscription.lastNotifiedRenewal == nextRenewal { continue }
            subscription.lastNotifiedRenewal = nextRenewal
            try? AppModelContainer.shared.mainContext.save()

            let content = UNMutableNotificationContent()
            content.title = "Upcoming renewal: \(subscription.name)"
            content.body = "\(subscription.amount.formatted(.currency(code: subscription.currencyCode))) renews \(nextRenewal.formatted(date: .abbreviated, time: .omitted))."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "sub-\(notificationID)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
