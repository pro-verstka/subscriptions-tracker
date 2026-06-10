import Foundation
import SwiftData
import UserNotifications

/// Локальные уведомления о приближающемся продлении подписки.
@MainActor
enum NotificationScheduler {
    /// Снимок полей подписки — чтобы не передавать `@Model` (он не `Sendable`)
    /// через границы async-вызовов.
    private struct Snapshot {
        let id: String
        let name: String
        let amount: Decimal
        let currencyCode: String
        let nextRenewal: Date
        let notifyDaysBefore: Int
    }

    /// Запрашивает разрешение на показ уведомлений (один раз при старте).
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Фетчит подписки из общего хранилища и пересоздаёт уведомления.
    static func rescheduleFromStore() async {
        let context = AppModelContainer.shared.mainContext
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        await reschedule(for: subscriptions)
    }

    /// Сбрасывает все запланированные уведомления и пересоздаёт по одному на подписку,
    /// на дату `nextRenewal − notifyDaysBefore` (только если она в будущем).
    /// Подписки на паузе пропускаются. Если уведомления выключены в настройках —
    /// просто очищает запланированные. Вызывать при любом изменении данных.
    static func reschedule(for subscriptions: [Subscription]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard AppSettings.shared.notificationsEnabled else { return }

        let calendar = Calendar.current
        let snapshots = subscriptions.filter { !$0.isPaused }.map {
            Snapshot(
                id: "\($0.persistentModelID.hashValue)",
                name: $0.name,
                amount: $0.amount,
                currencyCode: $0.currencyCode,
                nextRenewal: $0.nextRenewal,
                notifyDaysBefore: $0.notifyDaysBefore
            )
        }

        for snapshot in snapshots {
            guard
                let fireDate = calendar.date(
                    byAdding: .day,
                    value: -snapshot.notifyDaysBefore,
                    to: snapshot.nextRenewal
                ),
                fireDate > .now
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming renewal: \(snapshot.name)"
            content.body = "\(snapshot.amount.formatted(.currency(code: snapshot.currencyCode))) renews \(snapshot.nextRenewal.formatted(date: .abbreviated, time: .omitted))."
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "sub-\(snapshot.id)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
