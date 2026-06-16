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
    /// на дату `nextRenewal − notifyDaysBefore`. Если эта дата уже прошла, но само
    /// продление ещё впереди (подписку добавили внутри окна напоминания) — уведомление
    /// сдвигается на ближайшую минуту, а не теряется. Подписки на паузе пропускаются.
    /// Если уведомления выключены в настройках — очищает и запланированные, и уже
    /// показанные. Вызывать при любом изменении данных.
    static func reschedule(for subscriptions: [Subscription]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard AppSettings.shared.notificationsEnabled else {
            // Уведомления выключены — заодно убираем уже показанные напоминания.
            center.removeAllDeliveredNotifications()
            return
        }

        let calendar = Calendar.current
        let snapshots = subscriptions.filter { !$0.isPaused }.map {
            Snapshot(
                id: stableID(for: $0.persistentModelID),
                name: $0.name,
                amount: $0.amount,
                currencyCode: $0.currencyCode,
                nextRenewal: $0.nextRenewal,
                notifyDaysBefore: $0.notifyDaysBefore
            )
        }

        // Подчищаем «осиротевшие» доставленные уведомления: старые копии с нестабильными
        // id (см. `stableID`) и записи удалённых/паузнутых подписок. Доставленные активных
        // подписок остаются — следующая доставка заменит их по стабильному id, а не размножит.
        let validIDs = Set(snapshots.map(\.id))
        let delivered = await center.deliveredNotifications()
        let stale = delivered.map(\.request.identifier).filter { !validIDs.contains($0) }
        if !stale.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: stale)
        }

        for snapshot in snapshots {
            guard let plannedFireDate = calendar.date(
                byAdding: .day,
                value: -snapshot.notifyDaysBefore,
                to: snapshot.nextRenewal
            ) else { continue }

            // Плановая дата напоминания ещё впереди — используем её. Если она уже
            // прошла, но само продление ещё не наступило (подписку добавили внутри
            // окна напоминания), не теряем уведомление, а сдвигаем его на ближайшую
            // минуту. Если же продление уже позади — пропускаем (в норме недостижимо:
            // nextRenewal всегда в будущем, см. RenewalDate.nextOccurrence).
            let fireDate: Date
            if plannedFireDate > .now {
                fireDate = plannedFireDate
            } else if snapshot.nextRenewal > .now {
                fireDate = calendar.date(byAdding: .minute, value: 1, to: .now)
                    ?? .now.addingTimeInterval(60)
            } else {
                continue
            }

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
                identifier: snapshot.id,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Стабильный между запусками идентификатор уведомления подписки.
    /// `persistentModelID.hashValue` использовать нельзя: `Hashable` в Swift солится
    /// случайным seed'ом на каждый запуск процесса, поэтому идентификатор «плавал» —
    /// доставленные уведомления не схлопывались по id, а копились в Центре. `PersistentIdentifier`
    /// — `Codable`, и его кодированное представление сохранённой записи стабильно между запусками.
    private static func stableID(for id: PersistentIdentifier) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let token = (try? encoder.encode(id))?.base64EncodedString() ?? "unknown"
        return "sub-\(token)"
    }
}
